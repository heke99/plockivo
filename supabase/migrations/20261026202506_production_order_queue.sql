-- Staff/admin queue, separate from buyer-oriented intent history permissions.
create function private.list_production_orders(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;begin
 perform private.assert_mfa();if coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'MFA_REQUIRED';end if;
 if not exists(select 1 from public.memberships m where m.tenant_id=p_tenant and m.user_id=auth.uid()
  and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
  and private.allowed(p_tenant,m.customer_account_id,m.store_id,m.project_id,'production.fulfillment.read'))
 then raise exception 'PERMISSION_DENIED';end if;
 if not exists(select 1 from public.merchants where id=p_tenant and mode='production') then raise exception 'INTEGRATION_NOT_READY';end if;
 with candidates as materialized (
  select o.id as order_id,o.purchase_intent_id,o.total_minor::text,o.created_at,coalesce(f.state,'reserved') as state
  from public.orders o left join private.production_fulfillment f on f.tenant_id=o.tenant_id and f.order_id=o.id
  where o.tenant_id=p_tenant and private.production_order_authorized(o,'production.fulfillment.read',false)
  order by o.created_at desc,o.id desc limit 51
 ), page as (select * from candidates order by created_at desc,order_id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(p) order by p.created_at desc,p.order_id desc) from page p),'[]'::jsonb),
  'limit',50,'has_more',(select count(*)>50 from candidates)) into r;
 return r;
end$$;
create function public.list_production_orders(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_production_orders(p_tenant)$$;
revoke all on function private.list_production_orders(uuid),public.list_production_orders(uuid) from public,anon,authenticated;
grant execute on function private.list_production_orders(uuid),public.list_production_orders(uuid) to authenticated;
