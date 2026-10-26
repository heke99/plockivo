create table private.order_cancellations(id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,actor_id uuid not null references auth.users(id),reason text not null check(length(trim(reason)) between 1 and 500),lines jsonb not null,created_at timestamptz not null default now(),foreign key(tenant_id,order_id) references public.orders(tenant_id,id));
alter table private.order_cancellations enable row level security;
revoke all on private.order_cancellations from public,anon,authenticated;
create index order_cancellations_order_idx on private.order_cancellations(order_id,created_at);
insert into public.role_permissions values('merchant_admin','orders.cancel.test'),('store_staff','orders.cancel.test');
create function private.cancel_test_order_lines(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;cmd private.commands;item jsonb;b private.order_line_disposition;q numeric;res jsonb;v integer;eid uuid:=gen_random_uuid();begin
 o:=private.fulfillment_lock(p_order,'orders.cancel.test');
 if p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$' then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation='fulfillment.cancel' and key=p_key;
 if found then if cmd.body<>jsonb_build_object('order_id',p_order,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or p_body-'version'-'reason'-'lines'<>'{}'::jsonb or jsonb_typeof(p_body->'version') is distinct from 'number' or coalesce(p_body->>'version','') !~ '^(0|[1-9][0-9]{0,9})$' or length(trim(coalesce(p_body->>'reason',''))) not between 1 and 500 or jsonb_typeof(p_body->'lines') is distinct from 'array' then raise exception 'VALIDATION_ERROR';end if;
 if jsonb_array_length(p_body->'lines') not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 if (select count(distinct lower(value->>'product_id')) from jsonb_array_elements(p_body->'lines'))<>jsonb_array_length(p_body->'lines') then raise exception 'VALIDATION_ERROR';end if;
 v:=(p_body->>'version')::integer;
 if v<>(select version from private.fulfillment_orders where order_id=p_order) then raise exception 'VERSION_CONFLICT';end if;
 for item in select value from jsonb_array_elements(p_body->'lines') order by value->>'product_id' loop
  if jsonb_typeof(item)<>'object' or item-'product_id'-'quantity'<>'{}'::jsonb or coalesce(item->>'product_id','') !~ '^[a-fA-F0-9-]{36}$' or jsonb_typeof(item->'quantity') is distinct from 'string' or coalesce(item->>'quantity','') !~ '^(0|[1-9][0-9]{0,5})(\.[0-9]{1,6})?$' then raise exception 'VALIDATION_ERROR';end if;
  q:=(item->>'quantity')::numeric;if q<=0 then raise exception 'VALIDATION_ERROR';end if;
  select d.* into b from private.order_line_disposition d join public.order_lines l on l.id=d.order_line_id where d.order_id=p_order and l.product_id=(item->>'product_id')::uuid for update of d;
  if not found or q>b.accepted_quantity-b.claimed_quantity-b.fulfilled_quantity-b.cancelled_quantity then raise exception 'QUANTITY_CONFLICT';end if;
  update private.order_line_disposition set cancelled_quantity=cancelled_quantity+q where order_line_id=b.order_line_id;
 end loop;
 insert into private.order_cancellations(id,tenant_id,order_id,actor_id,reason,lines) values(eid,o.tenant_id,p_order,auth.uid(),trim(p_body->>'reason'),p_body->'lines');
 update private.fulfillment_orders set version=version+1,inspection_status='pending' where order_id=p_order;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),'fulfillment.cancel',eid,p_correlation);
 res:=private.fulfillment_state(p_order);
 insert into private.commands values(o.tenant_id,auth.uid(),'fulfillment.cancel',p_key,jsonb_build_object('order_id',p_order,'body',p_body),res,now());return res;
end$$;
create function public.cancel_test_order_lines(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.cancel_test_order_lines(p_order,p_body,p_key,p_correlation)$$;
revoke all on function private.cancel_test_order_lines(uuid,jsonb,text,uuid),public.cancel_test_order_lines(uuid,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.cancel_test_order_lines(uuid,jsonb,text,uuid),public.cancel_test_order_lines(uuid,jsonb,text,uuid) to authenticated;
