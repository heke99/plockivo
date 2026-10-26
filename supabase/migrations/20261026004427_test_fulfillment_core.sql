-- Synthetic fulfillment only. No physical release, inventory or financial side effects.
insert into public.role_permissions(role,permission) select r,p from unnest(array['merchant_admin','store_staff'])r cross join unnest(array['fulfillment.read.test','fulfillment.inspect.test','fulfillment.claim.test','fulfillment.confirm.test'])p;
create table private.fulfillment_orders(order_id uuid primary key references public.orders(id),version integer not null default 0 check(version>=0),inspection_status text not null default 'pending' check(inspection_status in ('pending','passed','blocked')),inspection_lines jsonb,recipient_reference text,inspection_reason text);
create table private.order_line_disposition(order_line_id uuid primary key references public.order_lines(id),tenant_id uuid not null,order_id uuid not null,accepted_quantity numeric(20,6) not null check(accepted_quantity>0),claimed_quantity numeric(20,6) not null default 0 check(claimed_quantity>=0),fulfilled_quantity numeric(20,6) not null default 0 check(fulfilled_quantity>=0),cancelled_quantity numeric(20,6) not null default 0 check(cancelled_quantity>=0),returned_quantity numeric(20,6) not null default 0 check(returned_quantity>=0),check(claimed_quantity+fulfilled_quantity+cancelled_quantity<=accepted_quantity),check(returned_quantity<=fulfilled_quantity),foreign key(tenant_id,order_id) references public.orders(tenant_id,id));
create table private.fulfillment_claims(id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,actor_id uuid not null references auth.users(id),status text not null default 'pending' check(status in ('pending','confirmed')),lines jsonb not null,recipient_reference text not null,created_at timestamptz not null default now(),confirmed_at timestamptz,foreign key(tenant_id,order_id) references public.orders(tenant_id,id),check((status='confirmed')=(confirmed_at is not null)));
alter table private.fulfillment_orders enable row level security;
alter table private.order_line_disposition enable row level security;
alter table private.fulfillment_claims enable row level security;
revoke all on private.fulfillment_orders,private.order_line_disposition,private.fulfillment_claims from public,anon,authenticated;
create function private.fulfillment_authorized(o public.orders,p_permission text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (auth.jwt()->>'aal')='aal2' and private.mfa_satisfied() and o.mode='test' and exists(select 1 from public.merchants m where m.id=o.tenant_id and m.mode='test') and private.allowed(o.tenant_id,o.customer_account_id,o.store_id,null,p_permission)
$$;
create function private.fulfillment_lock(p_order uuid,p_permission text) returns public.orders language plpgsql security definer set search_path='' as $$
declare o public.orders;begin
 select * into o from public.orders where id=p_order for update;
 if not found or not private.fulfillment_authorized(o,p_permission) then raise exception 'PERMISSION_DENIED';end if;
 insert into private.fulfillment_orders(order_id) values(o.id) on conflict do nothing;
 insert into private.order_line_disposition(order_line_id,tenant_id,order_id,accepted_quantity) select id,tenant_id,order_id,quantity from public.order_lines where order_id=o.id order by id on conflict do nothing;
 return o;
end$$;
create function private.fulfillment_normalize_lines(p_lines jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare r jsonb;begin
 if p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 if exists(select 1 from jsonb_array_elements(p_lines)x where jsonb_typeof(x)<>'object' or x-'product_id'-'quantity'<>'{}'::jsonb or coalesce(x->>'product_id','') !~ '^[a-fA-F0-9-]{36}$' or coalesce(x->>'quantity','') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (x->>'quantity')::numeric<=0) then raise exception 'VALIDATION_ERROR';end if;
 if (select count(*)<>count(distinct (x->>'product_id')::uuid) from jsonb_array_elements(p_lines)x) then raise exception 'VALIDATION_ERROR';end if;
 select jsonb_agg(jsonb_build_object('product_id',(x->>'product_id')::uuid,'quantity',(x->>'quantity')::numeric::text) order by (x->>'product_id')::uuid) into r from jsonb_array_elements(p_lines)x;return r;
end$$;
create function private.fulfillment_state(p_order uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.fulfillment_orders;begin
 select * into o from public.orders where id=p_order;
 if not found or not private.fulfillment_authorized(o,'fulfillment.read.test') then raise exception 'PERMISSION_DENIED';end if;
 select * into f from private.fulfillment_orders where order_id=o.id;
 return jsonb_build_object('order_id',o.id,'tenant_id',o.tenant_id,'mode','test','version',coalesce(f.version,0),'inspection_status',coalesce(f.inspection_status,'pending'),'lines',coalesce((select jsonb_agg(jsonb_build_object('order_line_id',l.id,'product_id',l.product_id,'name',l.snapshot->>'name','quantity',l.quantity::text,'claimed_quantity',coalesce(d.claimed_quantity,0)::text,'fulfilled_quantity',coalesce(d.fulfilled_quantity,0)::text,'cancelled_quantity',coalesce(d.cancelled_quantity,0)::text,'returned_quantity',coalesce(d.returned_quantity,0)::text,'remaining_quantity',(l.quantity-coalesce(d.claimed_quantity,0)-coalesce(d.fulfilled_quantity,0)-coalesce(d.cancelled_quantity,0))::text) order by l.id) from public.order_lines l left join private.order_line_disposition d on d.order_line_id=l.id where l.order_id=o.id),'[]'),'claims',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'status',c.status,'lines',c.lines,'recipient_reference',c.recipient_reference,'created_at',c.created_at,'confirmed_at',c.confirmed_at) order by c.created_at,c.id) from private.fulfillment_claims c where c.order_id=o.id),'[]'));
end$$;
create function private.inspect_test_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.fulfillment_orders;cmd private.commands;r jsonb;ls jsonb;begin
 o:=private.fulfillment_lock(p_order,'fulfillment.inspect.test');
 if p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation='fulfillment.inspect' and key=p_key;
 if found then if cmd.body<>p_body||jsonb_build_object('order_id',p_order) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 select * into f from private.fulfillment_orders where order_id=o.id;
 if (p_body->>'version')::integer is distinct from f.version then raise exception 'VERSION_CONFLICT';end if;
 ls:=private.fulfillment_normalize_lines(p_body->'lines');
 if coalesce(p_body->>'result','') not in ('passed','blocked') or length(trim(coalesce(p_body->>'reason',''))) not between 1 and 500 or length(trim(coalesce(p_body->>'recipient_reference',''))) not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 if exists(select 1 from jsonb_array_elements(ls)x left join public.order_lines l on l.order_id=o.id and l.product_id=(x->>'product_id')::uuid left join private.order_line_disposition d on d.order_line_id=l.id where l.id is null or (x->>'quantity')::numeric>d.accepted_quantity-d.claimed_quantity-d.fulfilled_quantity-d.cancelled_quantity) then raise exception 'QUANTITY_CONFLICT';end if;
 update private.fulfillment_orders set version=version+1,inspection_status=p_body->>'result',inspection_lines=ls,recipient_reference=trim(p_body->>'recipient_reference'),inspection_reason=trim(p_body->>'reason') where order_id=o.id;
 r:=private.fulfillment_state(o.id);insert into private.commands values(o.tenant_id,auth.uid(),'fulfillment.inspect',p_key,p_body||jsonb_build_object('order_id',p_order),r,now());insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),'fulfillment.inspect',o.id,p_correlation);return r;
end$$;
create function private.claim_test_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.fulfillment_orders;cmd private.commands;r jsonb;ls jsonb;x jsonb;l public.order_lines;cid uuid;begin
 o:=private.fulfillment_lock(p_order,'fulfillment.claim.test');
 if p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation='fulfillment.claim' and key=p_key;
 if found then if cmd.body<>p_body||jsonb_build_object('order_id',p_order) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 select * into f from private.fulfillment_orders where order_id=o.id;ls:=private.fulfillment_normalize_lines(p_body->'lines');
 if (p_body->>'version')::integer is distinct from f.version then raise exception 'VERSION_CONFLICT';end if;
 if f.inspection_status<>'passed' or f.inspection_lines<>ls or f.recipient_reference is distinct from trim(p_body->>'recipient_reference') then raise exception 'INSPECTION_REQUIRED';end if;
 for x in select value from jsonb_array_elements(ls) order by value->>'product_id' loop
 select * into l from public.order_lines where order_id=o.id and product_id=(x->>'product_id')::uuid;
 if not found then raise exception 'QUANTITY_CONFLICT';end if;
 update private.order_line_disposition set claimed_quantity=claimed_quantity+(x->>'quantity')::numeric where order_line_id=l.id and (x->>'quantity')::numeric<=accepted_quantity-claimed_quantity-fulfilled_quantity-cancelled_quantity;
 if not found then raise exception 'QUANTITY_CONFLICT';end if;
 end loop;
 insert into private.fulfillment_claims(tenant_id,order_id,actor_id,lines,recipient_reference) values(o.tenant_id,o.id,auth.uid(),ls,f.recipient_reference) returning id into cid;
 update private.fulfillment_orders set version=version+1,inspection_status='pending',inspection_lines=null where order_id=o.id;
 r:=private.fulfillment_state(o.id);insert into private.commands values(o.tenant_id,auth.uid(),'fulfillment.claim',p_key,p_body||jsonb_build_object('order_id',p_order),r,now());insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),'fulfillment.claim',cid,p_correlation);return r;
end$$;
create function private.confirm_test_claim(p_order uuid,p_claim uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.fulfillment_orders;c private.fulfillment_claims;cmd private.commands;r jsonb;x jsonb;begin
 o:=private.fulfillment_lock(p_order,'fulfillment.confirm.test');
 if p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation='fulfillment.confirm' and key=p_key;
 if found then if cmd.body<>p_body||jsonb_build_object('order_id',p_order,'claim_id',p_claim) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 select * into c from private.fulfillment_claims where id=p_claim and order_id=o.id for update;
 if not found then raise exception 'NOT_FOUND';end if;
 select * into f from private.fulfillment_orders where order_id=o.id;
 if c.status='confirmed' then return private.fulfillment_state(o.id);end if;
 if (p_body->>'version')::integer is distinct from f.version then raise exception 'VERSION_CONFLICT';end if;
 for x in select value from jsonb_array_elements(c.lines) order by value->>'product_id' loop
 update private.order_line_disposition d set claimed_quantity=claimed_quantity-(x->>'quantity')::numeric,fulfilled_quantity=fulfilled_quantity+(x->>'quantity')::numeric from public.order_lines l where d.order_line_id=l.id and l.order_id=o.id and l.product_id=(x->>'product_id')::uuid;
 end loop;
 update private.fulfillment_claims set status='confirmed',confirmed_at=now() where id=c.id;
 update private.fulfillment_orders set version=version+1,inspection_status='pending',inspection_lines=null where order_id=o.id;
 r:=private.fulfillment_state(o.id);insert into private.commands values(o.tenant_id,auth.uid(),'fulfillment.confirm',p_key,p_body||jsonb_build_object('order_id',p_order,'claim_id',p_claim),r,now());insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),'fulfillment.confirm',c.id,p_correlation);return r;
end$$;
create function public.get_test_fulfillment(p_order uuid) returns jsonb language sql security invoker set search_path='' as $$select private.fulfillment_state(p_order)$$;
create function public.inspect_test_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.inspect_test_order(p_order,p_body,p_key,p_correlation)$$;
create function public.claim_test_order(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.claim_test_order(p_order,p_body,p_key,p_correlation)$$;
create function public.confirm_test_claim(p_order uuid,p_claim uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.confirm_test_claim(p_order,p_claim,p_body,p_key,p_correlation)$$;
revoke all on function private.fulfillment_authorized(public.orders,text),private.fulfillment_lock(uuid,text),private.fulfillment_normalize_lines(jsonb),private.fulfillment_state(uuid),private.inspect_test_order(uuid,jsonb,text,uuid),private.claim_test_order(uuid,jsonb,text,uuid),private.confirm_test_claim(uuid,uuid,jsonb,text,uuid),public.get_test_fulfillment(uuid),public.inspect_test_order(uuid,jsonb,text,uuid),public.claim_test_order(uuid,jsonb,text,uuid),public.confirm_test_claim(uuid,uuid,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.fulfillment_state(uuid),private.inspect_test_order(uuid,jsonb,text,uuid),private.claim_test_order(uuid,jsonb,text,uuid),private.confirm_test_claim(uuid,uuid,jsonb,text,uuid),public.get_test_fulfillment(uuid),public.inspect_test_order(uuid,jsonb,text,uuid),public.claim_test_order(uuid,jsonb,text,uuid),public.confirm_test_claim(uuid,uuid,jsonb,text,uuid) to authenticated;
