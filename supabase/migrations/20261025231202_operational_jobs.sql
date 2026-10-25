-- Read-only operational inspection. Never requeues unknown or external outcomes.
insert into public.role_permissions values('merchant_admin','operations.read');
create function private.list_merchant_jobs(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();
 if not private.allowed(p_tenant,null,null,null,'operations.read') or not exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.role='merchant_admin' and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())) then raise exception 'PERMISSION_DENIED';end if;
 return jsonb_build_object('jobs',coalesce((select jsonb_agg(jsonb_build_object('id',j.id,'order_id',j.order_id,'kind',j.kind,'status',j.status,'attempts',j.attempts,'created_at',j.created_at,'lease_expired',j.status='claimed' and j.claimed_until<now(),'action',case when j.status='manual_review' and j.kind='notification' then 'delivery_not_configured' when j.status in ('unknown','manual_review') then 'manual_review' when j.status='claimed' and j.claimed_until<now() then 'lease_review' else 'none' end) order by j.created_at desc,j.id) from (select * from private.outbox where tenant_id=p_tenant order by created_at desc,id limit 100)j),'[]'), 'limit',100);
end$$;
create function public.list_merchant_jobs(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_merchant_jobs(p_tenant)$$;
revoke all on function private.list_merchant_jobs(uuid),public.list_merchant_jobs(uuid) from public,anon,authenticated;
grant execute on function private.list_merchant_jobs(uuid),public.list_merchant_jobs(uuid) to authenticated;
