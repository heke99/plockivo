-- Protective prerequisite: every scoped authorization needs a verified live person.
create or replace function private.live_person() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users u join auth.sessions s on s.user_id=u.id
 where u.id=auth.uid() and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)
 and (u.banned_until is null or u.banned_until<=now())
 and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now()))
$$;
create or replace function private.allowed(p_tenant uuid,p_account uuid,p_store uuid,p_project uuid,p_permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select private.live_person() and private.mfa_satisfied() and exists(
 select 1 from public.memberships m join public.role_permissions r on r.role=m.role
 where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
 and r.permission=p_permission and (m.customer_account_id is null or m.customer_account_id=p_account)
 and (m.store_id is null or m.store_id=p_store) and (m.project_id is null or m.project_id=p_project));
$$;
