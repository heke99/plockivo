-- MEMBERS-015: administrative mandate revocation, never user/account deletion.
alter table public.memberships add column version integer not null default 0 check(version>=0);
insert into public.role_permissions values('merchant_admin','members.manage');
create function private.members_authorized(p_tenant uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.profile_authorized(p_tenant) and private.allowed(p_tenant,null,null,null,'members.manage')
$$;
create function private.member_dto(m public.memberships) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',m.id,'user_id',m.user_id,'email',(select email from auth.users where id=m.user_id),'role',m.role,'status',m.status,'version',m.version,'customer_account_id',m.customer_account_id,'store_id',m.store_id,'project_id',m.project_id,'valid_to',m.valid_to,'can_revoke',m.user_id<>auth.uid() and m.role in ('buyer','approver','customer_admin','store_staff') and m.status<>'revoked')
$$;
create function private.list_merchant_members(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();if not private.members_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 return coalesce((select jsonb_agg(private.member_dto(x)) from (select * from public.memberships where tenant_id=p_tenant order by id limit 200)x),'[]');
end$$;
create function private.revoke_merchant_member(p_tenant uuid,p_member uuid,p_version integer,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.memberships;b jsonb;cmd private.commands;r jsonb;begin
 perform private.assert_mfa();if not private.members_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 if p_version is null or p_version<0 or p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 b:=jsonb_build_object('tenant_id',p_tenant,'membership_id',p_member,'version',p_version);
 perform 1 from public.merchants where id=p_tenant for update;
 select * into cmd from private.commands where tenant_id=p_tenant and actor_id=auth.uid() and operation='members.revoke' and key=p_key;
 if found then if cmd.body<>b then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 select * into m from public.memberships where id=p_member and tenant_id=p_tenant for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if m.user_id=auth.uid() or m.role not in ('buyer','approver','customer_admin','store_staff') then raise exception 'PERMISSION_DENIED';end if;
 if m.version<>p_version then raise exception 'VERSION_CONFLICT';end if;
 if m.status='revoked' then raise exception 'MEMBERSHIP_INACTIVE';end if;
 update public.memberships set status='revoked',version=version+1 where id=m.id returning * into m;
 r:=private.member_dto(m);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(p_tenant,auth.uid(),'members.revoke',m.id,p_correlation);
 insert into private.commands values(p_tenant,auth.uid(),'members.revoke',p_key,b,r,now());return r;
end$$;
create function public.list_merchant_members(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_merchant_members(p_tenant)$$;
create function public.revoke_merchant_member(p_tenant uuid,p_member uuid,p_version integer,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.revoke_merchant_member(p_tenant,p_member,p_version,p_key,p_correlation)$$;
revoke all on function private.members_authorized(uuid),private.member_dto(public.memberships),private.list_merchant_members(uuid),private.revoke_merchant_member(uuid,uuid,integer,text,uuid),public.list_merchant_members(uuid),public.revoke_merchant_member(uuid,uuid,integer,text,uuid) from public,anon,authenticated;
grant execute on function private.list_merchant_members(uuid),private.revoke_merchant_member(uuid,uuid,integer,text,uuid),public.list_merchant_members(uuid),public.revoke_merchant_member(uuid,uuid,integer,text,uuid) to authenticated;
