-- Buyer-safe branding follows the authenticated membership; never arbitrary Host.
create or replace function private.context() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 return jsonb_build_object('memberships',coalesce((select jsonb_agg(jsonb_build_object(
 'id',m.id,'tenant_id',m.tenant_id,'customer_account_id',m.customer_account_id,'role',m.role,'merchant',t.name,'merchant_slug',t.slug,'mode',t.mode,
 'branding',jsonb_build_object('display_name',case when length(trim(t.profile->>'display_name')) between 1 and 80 then t.profile->>'display_name' else t.name end,'primary_color',case when t.profile->>'primary_color' ~ '^#[0-9a-fA-F]{6}$' then t.profile->>'primary_color' else '#244e3c' end,'logo_data_url',case when length(t.profile->>'logo_data_url')<=22000 and t.profile->>'logo_data_url' ~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$' then t.profile->>'logo_data_url' else null end),
 'account',a.name,'store_id',m.store_id,'project_id',m.project_id,
 'permissions',(select jsonb_agg(r.permission) from public.role_permissions r where r.role=m.role)))
 from public.memberships m join public.merchants t on t.id=m.tenant_id left join public.customer_accounts a on a.id=m.customer_account_id
 where m.user_id=auth.uid() and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())), '[]'),
 'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'tenant_id',s.tenant_id,'name',s.name)) from public.stores s where private.allowed(s.tenant_id,null,s.id,null,'orders.read.store') or exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=s.tenant_id and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and (m.store_id is null or m.store_id=s.id))), '[]'),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'tenant_id',p.tenant_id,'customer_account_id',p.customer_account_id,'name',p.name)) from public.projects p where p.active and exists(select 1 from public.memberships mm join public.role_permissions rr on rr.role=mm.role where mm.user_id=auth.uid() and mm.tenant_id=p.tenant_id and mm.customer_account_id=p.customer_account_id and (mm.project_id is null or mm.project_id=p.id) and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and rr.permission in ('purchases.prepare','purchases.approve'))), '[]'));
end$$;
