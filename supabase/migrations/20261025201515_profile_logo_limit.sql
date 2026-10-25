create or replace function private.save_merchant_profile(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=(p_body->>'tenant_id')::uuid;v integer:=(p_body->>'version')::integer;p jsonb:=p_body->'profile';m public.merchants;cmd private.commands;r jsonb;begin
 perform private.assert_mfa();if not private.profile_authorized(tid) then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p is null or jsonb_typeof(p)<>'object' or p-'display_name'-'primary_color'-'logo_data_url'<>'{}'::jsonb or length(coalesce(p->>'display_name','')) not between 1 and 80 or coalesce(p->>'primary_color','') !~ '^#[0-9a-fA-F]{6}$' or (p->>'logo_data_url' is not null and (length(p->>'logo_data_url')>22000 or p->>'logo_data_url' !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$')) then raise exception 'VALIDATION_ERROR';end if;
 if p->>'logo_data_url' is not null and octet_length(decode(split_part(p->>'logo_data_url',',',2),'base64'))>16384 then raise exception 'VALIDATION_ERROR';end if;
 select * into m from public.merchants where id=tid for update;
 select * into cmd from private.commands where tenant_id=tid and actor_id=auth.uid() and operation='merchant.profile' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if v is null or m.profile_version<>v then raise exception 'VERSION_CONFLICT';end if;
 update public.merchants set profile=profile||p,profile_version=profile_version+1 where id=tid;
 r:=private.merchant_profile(tid);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(tid,auth.uid(),'merchant.profile',tid,p_correlation);
 insert into private.commands values(tid,auth.uid(),'merchant.profile',p_key,p_body,r,now());return r;
end$$;
