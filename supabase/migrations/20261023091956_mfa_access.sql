-- SEC-2303/2304: current Auth state, never user_metadata or a client role.
create function private.security_state() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare required boolean; enrolled boolean; satisfied boolean; level text:=coalesce(auth.jwt()->>'aal','aal1');
begin
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 select exists(select 1 from public.memberships m where m.user_id=auth.uid()
  and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
  and m.role in ('platform_admin','support','merchant_admin','credit_manager','finance')) into required;
 select exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') into enrolled;
 satisfied:=not(required or enrolled) or (level='aal2' and exists(
  select 1 from auth.sessions s join auth.mfa_factors f on f.id=s.factor_id and f.user_id=s.user_id
  where s.id::text=auth.jwt()->>'session_id' and s.user_id=auth.uid() and s.aal='aal2'
  and (s.not_after is null or s.not_after>now()) and f.status='verified'));
 return jsonb_build_object('required',required,'enrolled',enrolled,'level',level,'satisfied',satisfied);
end$$;
create function private.mfa_satisfied() returns boolean language sql stable security definer set search_path='' as $$
 select case when auth.uid() is null then false else (private.security_state()->>'satisfied')::boolean end
$$;
create function private.assert_mfa() returns void language plpgsql stable security definer set search_path='' as $$
begin if not private.mfa_satisfied() then raise exception 'MFA_REQUIRED';end if;end$$;
create function public.get_security_state() returns jsonb language sql stable security invoker set search_path='' as $$select private.security_state()$$;
revoke all on function private.security_state(),private.mfa_satisfied(),private.assert_mfa(),public.get_security_state() from public,anon,authenticated;
grant execute on function private.security_state(),private.mfa_satisfied(),private.assert_mfa(),public.get_security_state() to authenticated;

create or replace function private.allowed(p_tenant uuid,p_account uuid,p_store uuid,p_project uuid,p_permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select private.mfa_satisfied() and exists(
 select 1 from public.memberships m join public.role_permissions r on r.role=m.role
 where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
 and r.permission=p_permission and (m.customer_account_id is null or m.customer_account_id=p_account)
 and (m.store_id is null or m.store_id=p_store) and (m.project_id is null or m.project_id=p_project));
$$;
alter policy memberships_self on public.memberships using(user_id=(select auth.uid()) and (select private.mfa_satisfied()));
alter policy merchant_read on public.merchants using((select private.mfa_satisfied()) and exists(select 1 from public.memberships m where m.tenant_id=id and m.user_id=(select auth.uid()) and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())));

create or replace function private.context() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 return jsonb_build_object('memberships',coalesce((select jsonb_agg(jsonb_build_object(
 'id',m.id,'tenant_id',m.tenant_id,'customer_account_id',m.customer_account_id,'role',m.role,'merchant',t.name,'merchant_slug',t.slug,'mode',t.mode,
 'account',a.name,'store_id',m.store_id,'project_id',m.project_id,
 'permissions',(select jsonb_agg(r.permission) from public.role_permissions r where r.role=m.role)))
 from public.memberships m join public.merchants t on t.id=m.tenant_id left join public.customer_accounts a on a.id=m.customer_account_id
 where m.user_id=auth.uid() and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())), '[]'),
 'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'tenant_id',s.tenant_id,'name',s.name)) from public.stores s where private.allowed(s.tenant_id,null,s.id,null,'orders.read.store') or exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=s.tenant_id and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and (m.store_id is null or m.store_id=s.id))), '[]'),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'tenant_id',p.tenant_id,'customer_account_id',p.customer_account_id,'name',p.name)) from public.projects p where p.active and exists(select 1 from public.memberships mm join public.role_permissions rr on rr.role=mm.role where mm.user_id=auth.uid() and mm.tenant_id=p.tenant_id and mm.customer_account_id=p.customer_account_id and (mm.project_id is null or mm.project_id=p.id) and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and rr.permission in ('purchases.prepare','purchases.approve'))), '[]'));
end$$;


create or replace function private.catalog(p_tenant uuid,p_query text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();
 if auth.uid() is null or not exists(select 1 from public.memberships m join public.role_permissions r on r.role=m.role where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and r.permission='catalog.read') then raise exception 'PERMISSION_DENIED';end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from (select p.id,p.sku,p.name,p.unit,p.quantity_step::text,p.self_scan,
 coalesce((select jsonb_agg(jsonb_build_object('code',b.code,'package_quantity',b.package_quantity::text)) from public.product_barcodes b where b.tenant_id=p.tenant_id and b.product_id=p.id),'[]') as barcodes
 from public.products p where p.tenant_id=p_tenant and p.active and (p_query='' or p.sku ilike '%'||p_query||'%' or p.name ilike '%'||p_query||'%' or exists(select 1 from public.product_barcodes b where b.tenant_id=p_tenant and b.product_id=p.id and b.code=p_query)) order by p.sku limit 50)x),'[]');
end$$;


create or replace function private.quota() returns boolean language plpgsql security definer set search_path='' as $$
declare n int;begin
 perform private.assert_mfa();
 if auth.uid() is null then return false;end if;
 insert into private.api_quotas as q values(auth.uid(),date_trunc('minute',now()),1)
 on conflict(user_id) do update set window_start=excluded.window_start,count=case when q.window_start=excluded.window_start then q.count+1 else 1 end returning count into n;
 return n<=120;
end$$;

