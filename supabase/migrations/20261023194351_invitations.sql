-- INVITES-006: explicit delegation only; never infer authority from email/domain.
create table private.member_delegations (
 membership_id uuid not null references public.memberships(id), role text not null check(role in ('buyer','approver')),
 per_purchase_minor bigint not null check(per_purchase_minor>0), approval_threshold_minor bigint not null check(approval_threshold_minor between 0 and per_purchase_minor),
 valid_to timestamptz not null, primary key(membership_id,role)
);
create table private.invitations (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.merchants(id),
 issuer_membership_id uuid not null references public.memberships(id),issuer_id uuid not null references auth.users(id),
 recipient_email text not null check(recipient_email=lower(trim(recipient_email)) and length(recipient_email) between 3 and 254),
 recipient_id uuid references auth.users(id),customer_account_id uuid not null,store_id uuid,project_id uuid,
 role text not null check(role in ('buyer','approver')),per_purchase_minor bigint not null check(per_purchase_minor>0),
 approval_threshold_minor bigint not null check(approval_threshold_minor between 0 and per_purchase_minor),
 token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 status text not null default 'pending' check(status in ('pending','accepted','revoked')),
 expires_at timestamptz not null,valid_to timestamptz not null,created_at timestamptz not null default now(),
 accepted_by uuid references auth.users(id),accepted_at timestamptz,membership_id uuid references public.memberships(id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id),
 foreign key(tenant_id,customer_account_id,project_id) references public.projects(tenant_id,customer_account_id,id),
 check(expires_at<=valid_to),check((status='accepted')=(accepted_by is not null and accepted_at is not null and membership_id is not null))
);
create index invitations_issuer_created_idx on private.invitations(issuer_membership_id,created_at desc);
create index invitations_tenant_idx on private.invitations(tenant_id);
create index invitations_recipient_idx on private.invitations(recipient_id);
create index invitations_membership_idx on private.invitations(membership_id);
create index invitations_accepted_by_idx on private.invitations(accepted_by);
create index invitations_account_idx on private.invitations(tenant_id,customer_account_id,project_id);
create index invitations_store_idx on private.invitations(tenant_id,store_id);
alter table public.memberships add column invitation_id uuid unique references private.invitations(id);
alter table private.member_delegations enable row level security;
alter table private.invitations enable row level security;
revoke all on private.member_delegations,private.invitations from public,anon,authenticated;
insert into public.role_permissions values('customer_admin','members.invite');

create function private.live_person() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users u join auth.sessions s on s.user_id=u.id
 where u.id=auth.uid() and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)
 and s.id::text=auth.jwt()->>'session_id' and (s.not_after is null or s.not_after>now()))
$$;
create function private.inviter(p_membership uuid) returns public.memberships language plpgsql security definer set search_path='' as $$
declare m public.memberships;s jsonb;begin
 if not private.live_person() then raise exception 'PERMISSION_DENIED';end if;
 s:=private.security_state();
 if not(s->>'satisfied')::boolean or not(s->>'enrolled')::boolean or s->>'level'<>'aal2' then raise exception 'MFA_REQUIRED';end if;
 select * into m from public.memberships where id=p_membership for share;
 if not found or m.user_id<>auth.uid() or m.role<>'customer_admin' or m.customer_account_id is null
 or m.status<>'active' or m.valid_from>now() or (m.valid_to is not null and m.valid_to<=now())
 or not exists(select 1 from public.role_permissions r where r.role=m.role and r.permission='members.invite') then raise exception 'PERMISSION_DENIED';end if;
 return m;
end$$;
create function private.invitation_dto(i private.invitations) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',i.id,'tenant_id',i.tenant_id,'customer_account_id',i.customer_account_id,
 'merchant',(select name from public.merchants where id=i.tenant_id),'account',(select name from public.customer_accounts where id=i.customer_account_id),
 'recipient_email',i.recipient_email,'role',i.role,'store_id',i.store_id,'project_id',i.project_id,
 'store',(select name from public.stores where id=i.store_id),'project',(select name from public.projects where id=i.project_id),
 'per_purchase_minor',i.per_purchase_minor::text,'approval_threshold_minor',i.approval_threshold_minor::text,
 'status',case when i.status='pending' and i.expires_at<=now() then 'expired' else i.status end,
 'expires_at',i.expires_at,'valid_to',i.valid_to,'created_at',i.created_at,'membership_id',i.membership_id)
$$;
create function private.validate_invitation_scope(i private.invitations) returns void language plpgsql security definer set search_path='' as $$
declare m public.memberships;d private.member_delegations;begin
 select * into m from public.memberships where id=i.issuer_membership_id for share;
 if not found or m.user_id<>i.issuer_id or m.role<>'customer_admin' or m.status<>'active' or m.valid_from>now()
 or (m.valid_to is not null and (m.valid_to<=now() or i.valid_to>m.valid_to))
 or m.tenant_id<>i.tenant_id or m.customer_account_id is distinct from i.customer_account_id
 or (m.store_id is not null and m.store_id is distinct from i.store_id)
 or (m.project_id is not null and m.project_id is distinct from i.project_id)
 or not exists(select 1 from public.role_permissions r where r.role=m.role and r.permission='members.invite') then raise exception 'INVITATION_UNAVAILABLE';end if;
 select * into d from private.member_delegations where membership_id=m.id and role=i.role for share;
 if not found or d.valid_to<=now() or i.valid_to>d.valid_to or i.per_purchase_minor>d.per_purchase_minor
 or i.approval_threshold_minor>d.approval_threshold_minor then raise exception 'INVITATION_UNAVAILABLE';end if;
 if (i.store_id is not null and not exists(select 1 from public.stores s where s.id=i.store_id and s.tenant_id=i.tenant_id)) or not exists(select 1 from public.customer_accounts a where a.id=i.customer_account_id and a.tenant_id=i.tenant_id and a.status<>'suspended')
 or (i.project_id is not null and not exists(select 1 from public.projects p where p.id=i.project_id and p.tenant_id=i.tenant_id and p.customer_account_id=i.customer_account_id and p.active)) then raise exception 'INVITATION_UNAVAILABLE';end if;
end$$;
create function private.invitation_options(p_membership uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.memberships;begin
 m:=private.inviter(p_membership);
 return jsonb_build_object('delegations',coalesce((select jsonb_agg(jsonb_build_object('role',d.role,'per_purchase_minor',d.per_purchase_minor::text,'approval_threshold_minor',d.approval_threshold_minor::text,'valid_to',least(d.valid_to,coalesce(m.valid_to,d.valid_to)))) from private.member_delegations d where d.membership_id=m.id and d.valid_to>now()),'[]'),
 'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name)) from public.stores s where s.tenant_id=m.tenant_id and (m.store_id is null or m.store_id=s.id)),'[]'),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name)) from public.projects p where p.tenant_id=m.tenant_id and p.customer_account_id=m.customer_account_id and p.active and (m.project_id is null or m.project_id=p.id)),'[]'),
 'invitations',coalesce((select jsonb_agg(private.invitation_dto(x)) from (select * from private.invitations i where i.issuer_membership_id=m.id order by i.created_at desc,i.id limit 50)x),'[]'));
end$$;
create function private.create_invitation(p_body jsonb,p_token text,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.memberships;i private.invitations;cmd private.commands;begin
 m:=private.inviter((p_body->>'membership_id')::uuid);
 if not private.quota() then raise exception 'RATE_LIMITED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_token is null or p_token !~ '^[a-f0-9]{64}$'
 or coalesce(p_body->>'role','') not in ('buyer','approver') or length(coalesce(p_body->>'recipient_email','')) not between 3 and 254
 or coalesce(p_body->>'per_purchase_minor','') !~ '^[0-9]{1,15}$' or coalesce(p_body->>'approval_threshold_minor','') !~ '^[0-9]{1,15}$' then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(m.id::text||':invitations',0));
 select * into cmd from private.commands where tenant_id=m.tenant_id and actor_id=auth.uid() and operation='members.invite' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result||'{"replayed":true}'::jsonb;end if;
 if (select count(*) from private.invitations where issuer_membership_id=m.id and status='pending' and expires_at>now())>=50 then raise exception 'RATE_LIMITED';end if;
 i.id:=gen_random_uuid();i.tenant_id:=m.tenant_id;i.issuer_membership_id:=m.id;i.issuer_id:=auth.uid();i.customer_account_id:=m.customer_account_id;
 i.recipient_email:=lower(trim(p_body->>'recipient_email'));i.role:=p_body->>'role';i.store_id:=(p_body->>'store_id')::uuid;i.project_id:=(p_body->>'project_id')::uuid;
 select id into i.recipient_id from auth.users where lower(email)=i.recipient_email order by created_at limit 1;
 if i.recipient_id=auth.uid() or i.recipient_email=(select lower(email) from auth.users where id=auth.uid()) then raise exception 'PERMISSION_DENIED';end if;
 i.per_purchase_minor:=(p_body->>'per_purchase_minor')::bigint;i.approval_threshold_minor:=(p_body->>'approval_threshold_minor')::bigint;
 i.valid_to:=(p_body->>'valid_to')::timestamptz;i.expires_at:=least(now()+interval '72 hours',i.valid_to);
 if i.valid_to is null or i.valid_to<=now()+interval '5 minutes' or i.valid_to>now()+interval '366 days' or i.per_purchase_minor<=0 or i.approval_threshold_minor<0 or i.approval_threshold_minor>i.per_purchase_minor then raise exception 'VALIDATION_ERROR';end if;
 perform private.validate_invitation_scope(i);
 i.token_hash:=encode(extensions.digest(p_token,'sha256'),'hex');i.status:='pending';i.created_at:=now();
 insert into private.invitations select i.*;
 insert into private.commands values(m.tenant_id,auth.uid(),'members.invite',p_key,p_body,jsonb_build_object('id',i.id,'replayed',false),now());
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(m.tenant_id,auth.uid(),'members.invite',i.id,p_correlation);
 return jsonb_build_object('id',i.id,'replayed',false);
end$$;
create function private.read_invitation(p_token text) returns private.invitations language plpgsql security definer set search_path='' as $$
declare i private.invitations;begin
 if not private.live_person() or not private.mfa_satisfied() then raise exception 'PERMISSION_DENIED';end if;
 if not private.quota() then raise exception 'RATE_LIMITED';end if;
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception 'INVITATION_INVALID';end if;
 select * into i from private.invitations where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or i.recipient_email is distinct from (select lower(email) from auth.users where id=auth.uid())
 or (i.recipient_id is not null and i.recipient_id<>auth.uid()) then raise exception 'INVITATION_INVALID';end if;
 if i.status='accepted' then if i.accepted_by<>auth.uid() then raise exception 'INVITATION_INVALID';end if;return i;end if;
 if i.status<>'pending' or i.expires_at<=now() or i.valid_to<=now() then raise exception 'INVITATION_UNAVAILABLE';end if;
 perform private.validate_invitation_scope(i);return i;
end$$;
create function private.preview_invitation(p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare i private.invitations;begin i:=private.read_invitation(p_token);return private.invitation_dto(i);end$$;
create function private.accept_invitation(p_token text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i private.invitations;mid uuid;begin
 i:=private.read_invitation(p_token);
 if i.status='accepted' then return private.invitation_dto(i);end if;
 insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,valid_to,per_purchase_minor,approval_threshold_minor,invitation_id)
 values(auth.uid(),i.tenant_id,i.customer_account_id,i.store_id,i.project_id,i.role,i.valid_to,i.per_purchase_minor,i.approval_threshold_minor,i.id) returning id into mid;
 update private.invitations set status='accepted',accepted_by=auth.uid(),accepted_at=now(),membership_id=mid where id=i.id returning * into i;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(i.tenant_id,auth.uid(),'members.accept',i.id,p_correlation);
 return private.invitation_dto(i);
end$$;
create function private.revoke_invitation(p_id uuid,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i private.invitations;m public.memberships;begin
 select * into i from private.invitations where id=p_id for update;
 if not found then raise exception 'NOT_FOUND';end if;
 m:=private.inviter(i.issuer_membership_id);
 if i.issuer_id<>auth.uid() then raise exception 'PERMISSION_DENIED';end if;
 if i.status='accepted' then raise exception 'INVITATION_FINAL';end if;
 if i.status='pending' then
  update private.invitations set status='revoked' where id=i.id returning * into i;
  insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(i.tenant_id,auth.uid(),'members.invitation_revoke',i.id,p_correlation);
 end if;
 return private.invitation_dto(i);
end$$;
create function public.invitation_options(p_membership uuid) returns jsonb language sql security invoker set search_path='' as $$select private.invitation_options(p_membership)$$;
create function public.create_invitation(p_body jsonb,p_token text,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.create_invitation(p_body,p_token,p_key,p_correlation)$$;
create function public.preview_invitation(p_token text) returns jsonb language sql security invoker set search_path='' as $$select private.preview_invitation(p_token)$$;
create function public.accept_invitation(p_token text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.accept_invitation(p_token,p_correlation)$$;
create function public.revoke_invitation(p_id uuid,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.revoke_invitation(p_id,p_correlation)$$;
revoke all on function private.live_person(),private.inviter(uuid),private.invitation_dto(private.invitations),private.validate_invitation_scope(private.invitations),private.invitation_options(uuid),private.create_invitation(jsonb,text,text,uuid),private.read_invitation(text),private.preview_invitation(text),private.accept_invitation(text,uuid),private.revoke_invitation(uuid,uuid),public.invitation_options(uuid),public.create_invitation(jsonb,text,text,uuid),public.preview_invitation(text),public.accept_invitation(text,uuid),public.revoke_invitation(uuid,uuid) from public,anon,authenticated;
grant execute on function private.invitation_options(uuid),private.create_invitation(jsonb,text,text,uuid),private.preview_invitation(text),private.accept_invitation(text,uuid),private.revoke_invitation(uuid,uuid),public.invitation_options(uuid),public.create_invitation(jsonb,text,text,uuid),public.preview_invitation(text),public.accept_invitation(text,uuid),public.revoke_invitation(uuid,uuid) to authenticated;
-- Only a capability precheck for signup. No identity, organization DTO or membership grant.
create function private.invitation_signup_allowed(p_token text,p_email text) returns boolean language plpgsql security definer set search_path='' as $$
declare i private.invitations;begin
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' or p_email is null or length(p_email)>254 then return false;end if;
 select * into i from private.invitations where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 if not found or i.status<>'pending' or i.expires_at<=now() or i.valid_to<=now() or i.recipient_email<>lower(trim(p_email)) then return false;end if;
 perform private.validate_invitation_scope(i);return true;
 exception when raise_exception then return false;
end$$;
create function public.invitation_signup_allowed(p_token text,p_email text) returns boolean language sql security invoker set search_path='' as $$select private.invitation_signup_allowed(p_token,p_email)$$;
revoke all on function private.invitation_signup_allowed(text,text),public.invitation_signup_allowed(text,text) from public,anon,authenticated;
grant usage on schema private to anon;
grant execute on function private.invitation_signup_allowed(text,text),public.invitation_signup_allowed(text,text) to anon,authenticated;

