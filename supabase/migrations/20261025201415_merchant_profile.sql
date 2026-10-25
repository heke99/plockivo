alter table public.merchants add column profile_version integer not null default 0 check(profile_version>=0);
insert into public.role_permissions values('merchant_admin','merchants.profile.manage');
create function private.profile_authorized(p_tenant uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.allowed(p_tenant,null,null,null,'merchants.profile.manage') and exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.role='merchant_admin' and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()))
$$;
create function private.merchant_profile(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.merchants;begin
 perform private.assert_mfa();if not private.profile_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 select * into m from public.merchants where id=p_tenant;
 return jsonb_build_object('tenant_id',m.id,'name',m.name,'version',m.profile_version,'profile',jsonb_build_object('display_name',coalesce(m.profile->>'display_name',m.name),'primary_color',coalesce(m.profile->>'primary_color','#244e3c'),'logo_data_url',m.profile->>'logo_data_url'));
end$$;
create function private.save_merchant_profile(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=(p_body->>'tenant_id')::uuid;v integer:=(p_body->>'version')::integer;p jsonb:=p_body->'profile';m public.merchants;cmd private.commands;r jsonb;begin
 perform private.assert_mfa();if not private.profile_authorized(tid) then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p is null or jsonb_typeof(p)<>'object' or p-'display_name'-'primary_color'-'logo_data_url'<>'{}'::jsonb or length(coalesce(p->>'display_name','')) not between 1 and 80 or coalesce(p->>'primary_color','') !~ '^#[0-9a-fA-F]{6}$' or (p->>'logo_data_url' is not null and (length(p->>'logo_data_url')>22000 or p->>'logo_data_url' !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$')) then raise exception 'VALIDATION_ERROR';end if;
 select * into m from public.merchants where id=tid for update;
 select * into cmd from private.commands where tenant_id=tid and actor_id=auth.uid() and operation='merchant.profile' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if v is null or m.profile_version<>v then raise exception 'VERSION_CONFLICT';end if;
 update public.merchants set profile=profile||p,profile_version=profile_version+1 where id=tid;
 r:=private.merchant_profile(tid);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(tid,auth.uid(),'merchant.profile',tid,p_correlation);
 insert into private.commands values(tid,auth.uid(),'merchant.profile',p_key,p_body,r,now());return r;
end$$;
create function public.get_merchant_profile(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.merchant_profile(p_tenant)$$;
create function public.save_merchant_profile(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.save_merchant_profile(p_body,p_key,p_correlation)$$;
revoke all on function private.profile_authorized(uuid),private.merchant_profile(uuid),private.save_merchant_profile(jsonb,text,uuid),public.get_merchant_profile(uuid),public.save_merchant_profile(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.merchant_profile(uuid),private.save_merchant_profile(jsonb,text,uuid),public.get_merchant_profile(uuid),public.save_merchant_profile(jsonb,text,uuid) to authenticated;
