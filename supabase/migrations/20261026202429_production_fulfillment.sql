-- Full-order production receipt/cancellation. No partial quantities or automatic release.
create table private.production_fulfillment(
 order_id uuid primary key,tenant_id uuid not null,
 version integer not null check(version>=0),state text not null check(state in ('reserved','fulfilled','cancelled')),
 recipient_reference text,reason text,credit_released_minor bigint not null default 0 check(credit_released_minor>=0),
 updated_at timestamptz not null default now(),
 foreign key(tenant_id,order_id) references public.orders(tenant_id,id),
 check(state<>'fulfilled' or (recipient_reference is not null and length(trim(recipient_reference)) between 1 and 100)),
 check(state<>'cancelled' or (reason is not null and length(trim(reason)) between 1 and 500)),
 check((state='cancelled')=(credit_released_minor>0))
);
alter table private.production_fulfillment enable row level security;
revoke all on private.production_fulfillment from public,anon,authenticated;
insert into public.role_permissions(role,permission)
 select r,p from unnest(array['merchant_admin','store_staff'])r cross join unnest(array['production.fulfillment.read','production.fulfillment.confirm','production.fulfillment.cancel','production.billing.read'])p;
create function private.production_order_authorized(o public.orders,p_permission text,p_owner boolean default false)
 returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.mfa_satisfied() and o.mode='production'
 and exists(select 1 from public.merchants m where m.id=o.tenant_id and m.mode='production')
 and ((p_owner and o.actor_id=auth.uid() and private.allowed(o.tenant_id,o.customer_account_id,o.store_id,(select i.project_id from public.purchase_intents i where i.id=o.purchase_intent_id),'orders.read.own'))
 or (auth.jwt()->>'aal'='aal2' and private.allowed(o.tenant_id,o.customer_account_id,o.store_id,(select i.project_id from public.purchase_intents i where i.id=o.purchase_intent_id),p_permission)))
$$;
create function private.production_order_dto(o public.orders) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('order_id',o.id,'tenant_id',o.tenant_id,'mode','production',
 'version',coalesce(f.version,0),'state',coalesce(f.state,'reserved'),'recipient_reference',f.recipient_reference,
 'credit_released_minor',coalesce(f.credit_released_minor,0)::text,'snapshot',o.snapshot,'total_minor',o.total_minor::text,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('order_line_id',l.id,'product_id',l.product_id,'name',l.snapshot->>'name','quantity',l.quantity::text) order by l.product_id) from public.order_lines l where l.order_id=o.id),'[]'::jsonb))
 from (select 1) seed left join private.production_fulfillment f on f.order_id=o.id
$$;
create function private.get_production_order(p_order uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;begin
 select * into o from public.orders where id=p_order;
 if not found or not private.production_order_authorized(o,'production.fulfillment.read',true) then raise exception 'PERMISSION_DENIED';end if;
 return private.production_order_dto(o);
end$$;
create function private.mutate_production_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid,p_action text)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.production_fulfillment;cmd private.commands;l public.order_lines;
 project_id uuid;reservation private.credit_reservations;result jsonb;op_name text;permission_name text;
begin
 if p_action not in ('fulfill','cancel') then raise exception 'VALIDATION_ERROR';end if;
 perform private.assert_mfa();if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'MFA_REQUIRED';end if;
 op_name:='production.'||p_action;permission_name:=case when p_action='fulfill' then 'production.fulfillment.confirm' else 'production.fulfillment.cancel' end;
 -- Serialize actor/operation command identity across different orders too.
 perform pg_advisory_xact_lock(hashtextextended(coalesce(auth.uid()::text,'anonymous')||':'||op_name||':'||coalesce(p_key,''),0));
 select * into o from public.orders where id=p_order for update;
 if not found or not private.production_order_authorized(o,permission_name,false) then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$' or p_correlation is null then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and private.commands.operation=op_name and key=p_key;
 if found then
  if cmd.body<>jsonb_build_object('order_id',p_order,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return cmd.result;
 end if;
 if p_body is null or jsonb_typeof(p_body)<>'object'
 or jsonb_typeof(p_body->'version') is distinct from 'number'
 or coalesce(p_body->>'version','') !~ '^(0|[1-9][0-9]{0,9})$'
 then raise exception 'VALIDATION_ERROR';end if;
 if (p_body->>'version')::numeric>2147483646 then raise exception 'VALIDATION_ERROR';end if;
 if p_action='fulfill' then
  if p_body-'version'-'recipient_reference'-'checked'<>'{}'::jsonb
  or jsonb_typeof(p_body->'checked') is distinct from 'boolean' or p_body->>'checked'<>'true'
  or jsonb_typeof(p_body->'recipient_reference') is distinct from 'string'
  or length(trim(coalesce(p_body->>'recipient_reference',''))) not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 else
  if p_body-'version'-'reason'<>'{}'::jsonb or jsonb_typeof(p_body->'reason') is distinct from 'string'
  or length(trim(coalesce(p_body->>'reason',''))) not between 1 and 500 then raise exception 'VALIDATION_ERROR';end if;
 end if;
 select * into f from private.production_fulfillment where order_id=o.id;
 if coalesce(f.version,0)<>(p_body->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
 if coalesce(f.state,'reserved')<>'reserved' then raise exception 'FULFILLMENT_STATE_CONFLICT';end if;
 if not exists(select 1 from public.order_lines where order_id=o.id) then raise exception 'INVENTORY_CONFLICT';end if;
 -- Same ordering as checkout: order -> merchant -> account -> project -> stock, sorted by product.
 perform 1 from public.merchants where id=o.tenant_id for share;
 if p_action='cancel' then
  perform 1 from public.customer_accounts where tenant_id=o.tenant_id and id=o.customer_account_id for update;
  if not found then raise exception 'INVENTORY_CONFLICT';end if;
  select i.project_id into project_id from public.purchase_intents i where i.id=o.purchase_intent_id;
  perform 1 from public.projects p where p.id=project_id and p.tenant_id=o.tenant_id and p.customer_account_id=o.customer_account_id for update;
  if not found then raise exception 'INVENTORY_CONFLICT';end if;
  select * into reservation from private.credit_reservations where order_id=o.id and tenant_id=o.tenant_id for update;
  if not found or reservation.amount_minor<>o.total_minor then raise exception 'INVENTORY_CONFLICT';end if;
 end if;
 for l in select * from public.order_lines where order_id=o.id order by product_id loop
  if p_action='fulfill' then
   update private.production_stock s set on_hand=s.on_hand-l.quantity,reserved=s.reserved-l.quantity,version=s.version+1
   where s.tenant_id=o.tenant_id and s.store_id=o.store_id and s.product_id=l.product_id and s.reserved>=l.quantity and s.on_hand>=l.quantity;
  else
   update private.production_stock s set reserved=s.reserved-l.quantity,version=s.version+1
   where s.tenant_id=o.tenant_id and s.store_id=o.store_id and s.product_id=l.product_id and s.reserved>=l.quantity;
  end if;
  if not found then raise exception 'INVENTORY_CONFLICT';end if;
 end loop;
 if p_action='cancel' then
  update public.customer_accounts set exposure_minor=exposure_minor-reservation.amount_minor
  where tenant_id=o.tenant_id and id=o.customer_account_id and exposure_minor>=reservation.amount_minor;
  if not found then raise exception 'INVENTORY_CONFLICT';end if;
  update public.projects p set committed_minor=p.committed_minor-reservation.amount_minor
  where p.id=project_id and p.tenant_id=o.tenant_id and p.customer_account_id=o.customer_account_id and p.committed_minor>=reservation.amount_minor;
  if not found then raise exception 'INVENTORY_CONFLICT';end if;
 end if;
 insert into private.production_fulfillment(order_id,tenant_id,version,state,recipient_reference,reason,credit_released_minor)
 values(o.id,o.tenant_id,coalesce(f.version,0)+1,case when p_action='fulfill' then 'fulfilled' else 'cancelled' end,
 case when p_action='fulfill' then trim(p_body->>'recipient_reference') else null end,
 case when p_action='cancel' then trim(p_body->>'reason') else null end,
 case when p_action='cancel' then reservation.amount_minor else 0 end)
 on conflict(order_id) do update set version=excluded.version,state=excluded.state,recipient_reference=excluded.recipient_reference,
 reason=excluded.reason,credit_released_minor=excluded.credit_released_minor,updated_at=now();
 result:=private.production_order_dto(o);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),op_name,o.id,p_correlation);
 insert into private.commands(tenant_id,actor_id,operation,key,body,result) values(o.tenant_id,auth.uid(),op_name,p_key,jsonb_build_object('order_id',p_order,'body',p_body),result);
 return result;
end$$;
create function private.get_production_billing(p_order uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;begin
 perform private.assert_mfa();if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'MFA_REQUIRED';end if;
 select * into o from public.orders where id=p_order;
 if not found or not private.production_order_authorized(o,'production.billing.read',false) then raise exception 'PERMISSION_DENIED';end if;
 if not exists(select 1 from private.production_fulfillment f where f.order_id=o.id and f.state='fulfilled') then raise exception 'FULFILLMENT_REQUIRED';end if;
 return jsonb_build_object('order_id',o.id,'mode','production','status','ready_for_manual_export','snapshot',o.snapshot,'total_minor',o.total_minor::text);
end$$;
create function public.get_production_order(p_order uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_production_order(p_order)$$;
create function public.complete_production_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.mutate_production_order(p_order,p_body,p_key,p_correlation,'fulfill')$$;
create function public.cancel_production_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.mutate_production_order(p_order,p_body,p_key,p_correlation,'cancel')$$;
create function public.get_production_billing(p_order uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_production_billing(p_order)$$;
revoke all on function private.production_order_authorized(public.orders,text,boolean),private.production_order_dto(public.orders),private.get_production_order(uuid),private.mutate_production_order(uuid,jsonb,text,uuid,text),private.get_production_billing(uuid),public.get_production_order(uuid),public.complete_production_order(uuid,jsonb,text,uuid),public.cancel_production_order(uuid,jsonb,text,uuid),public.get_production_billing(uuid) from public,anon,authenticated;
grant execute on function private.get_production_order(uuid),private.mutate_production_order(uuid,jsonb,text,uuid,text),private.get_production_billing(uuid),public.get_production_order(uuid),public.complete_production_order(uuid,jsonb,text,uuid),public.cancel_production_order(uuid,jsonb,text,uuid),public.get_production_billing(uuid) to authenticated;
