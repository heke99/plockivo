-- RETURNS-022: physical receipt only. Never credit, approval or stock destination.
insert into public.role_permissions(role,permission) values ('merchant_admin','returns.receive.test'),('store_staff','returns.receive.test');
create table private.test_return_receipts(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.merchants(id),
 order_id uuid not null references public.orders(id),claim_id uuid not null references private.fulfillment_claims(id),
 order_line_id uuid not null references public.order_lines(id),quantity numeric(20,6) not null check(quantity>0),
 condition text not null check(condition in ('unopened','opened','damaged','unknown')),reason text not null check(length(trim(reason)) between 1 and 500),
 received_by uuid not null references auth.users(id),created_at timestamptz not null default now()
);
create index test_return_receipts_source_idx on private.test_return_receipts(claim_id,order_line_id);
create index test_return_receipts_order_idx on private.test_return_receipts(order_id);
alter table private.test_return_receipts enable row level security;
revoke all on private.test_return_receipts from public,anon,authenticated;
create function private.receive_test_return(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;c private.fulfillment_claims;l public.order_lines;d private.order_line_disposition;cmd private.commands;
 q numeric;source_quantity numeric;already_received numeric;rid uuid;r jsonb;v integer;
begin
 o:=private.fulfillment_lock(p_order,'returns.receive.test');
 if p_body is null or jsonb_typeof(p_body)<>'object' or p_body-'version'-'claim_id'-'order_line_id'-'quantity'-'condition'-'reason'<>'{}'::jsonb
 or jsonb_typeof(p_body->'version') is distinct from 'number' or coalesce(p_body->>'version','') !~ '^[0-9]{1,10}$' or jsonb_typeof(p_body->'quantity') is distinct from 'string' or jsonb_typeof(p_body->'reason') is distinct from 'string'
 or p_key is null or length(p_key) not between 16 and 128 or coalesce(p_body->>'quantity','') !~ '^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$'
 or coalesce(p_body->>'condition','') not in ('unopened','opened','damaged','unknown') or length(trim(coalesce(p_body->>'reason',''))) not between 1 and 500 then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation='returns.receive.test' and key=p_key;
 if found then if cmd.body<>jsonb_build_object('order_id',p_order,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 v:=(p_body->>'version')::integer;q:=(p_body->>'quantity')::numeric;
 if v is null or q<=0 then raise exception 'VALIDATION_ERROR';end if;
 if v<>(select version from private.fulfillment_orders where order_id=p_order) then raise exception 'VERSION_CONFLICT';end if;
 select * into c from private.fulfillment_claims where id=(p_body->>'claim_id')::uuid and order_id=p_order and tenant_id=o.tenant_id and status='confirmed';
 if not found then raise exception 'NOT_FOUND';end if;
 select * into l from public.order_lines where id=(p_body->>'order_line_id')::uuid and order_id=p_order and tenant_id=o.tenant_id;
 if not found then raise exception 'NOT_FOUND';end if;
 select * into d from private.order_line_disposition where order_line_id=l.id for update;
 select sum((x->>'quantity')::numeric) into source_quantity from jsonb_array_elements(c.lines)x where (x->>'product_id')::uuid=l.product_id;
 select coalesce(sum(quantity),0) into already_received from private.test_return_receipts where claim_id=c.id and order_line_id=l.id;
 if source_quantity is null or q+already_received>source_quantity or q+d.returned_quantity>d.fulfilled_quantity then raise exception 'RETURN_QUANTITY_EXCEEDED';end if;
 insert into private.test_return_receipts(tenant_id,order_id,claim_id,order_line_id,quantity,condition,reason,received_by)
 values(o.tenant_id,p_order,c.id,l.id,q,p_body->>'condition',trim(p_body->>'reason'),auth.uid()) returning id into rid;
 update private.order_line_disposition set returned_quantity=returned_quantity+q where order_line_id=l.id;
 update private.fulfillment_orders set version=version+1 where order_id=p_order;
 r:=jsonb_build_object('receipt',jsonb_build_object('id',rid,'claim_id',c.id,'order_line_id',l.id,'quantity',q::text,'condition',p_body->>'condition','status','received','financial_status','not_requested'),'state',private.fulfillment_state(p_order));
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),'returns.receive.test',rid,p_correlation);
 insert into private.commands values(o.tenant_id,auth.uid(),'returns.receive.test',p_key,jsonb_build_object('order_id',p_order,'body',p_body),r,now());
 return r;
end$$;
create function public.receive_test_return(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.receive_test_return(p_order,p_body,p_key,p_correlation)$$;
revoke all on function private.receive_test_return(uuid,jsonb,text,uuid),public.receive_test_return(uuid,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.receive_test_return(uuid,jsonb,text,uuid),public.receive_test_return(uuid,jsonb,text,uuid) to authenticated;
