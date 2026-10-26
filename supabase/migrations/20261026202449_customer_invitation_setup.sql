-- TASK051: an explicit, account-scoped invitation mandate for first-run owners.
create table private.customer_invitation_setups(
 tenant_id uuid not null references public.merchants(id),customer_account_id uuid not null,
 actor_id uuid not null references auth.users(id),source_membership_id uuid not null references public.memberships(id),
 membership_id uuid not null unique references public.memberships(id),body jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(tenant_id,customer_account_id,actor_id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id)
);
alter table private.customer_invitation_setups enable row level security;
revoke all on private.customer_invitation_setups from public,anon,authenticated;
create function private.customer_invitation_setup_live(p_membership uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare x private.customer_invitation_setups;m public.memberships;begin
 select * into x from private.customer_invitation_setups where membership_id=p_membership for share;
 if not found then return true;end if;
 select * into m from public.memberships where id=x.source_membership_id for share;
 return found and m.user_id=x.actor_id and m.tenant_id=x.tenant_id and m.role='merchant_admin'
 and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.status='active'
 and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
 and exists(select 1 from public.role_permissions rp where rp.role=m.role and rp.permission='customers.manage');
end$$;
create function private.setup_customer_invitation_access(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=(p_body->>'tenant_id')::uuid;aid uuid:=(p_body->>'customer_account_id')::uuid;
 cap bigint;threshold bigint;ends timestamptz;source public.memberships;mid uuid;cmd private.commands;setup private.customer_invitation_setups;r jsonb;
begin
 if not private.live_person() or not exists(select 1 from auth.users u where u.id=auth.uid() and (u.banned_until is null or u.banned_until<=now())) then raise exception 'PERMISSION_DENIED';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.mfa_satisfied() then raise exception 'MFA_REQUIRED';end if;
 if not private.customers_authorized(tid) then raise exception 'PERMISSION_DENIED';end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or p_body-'tenant_id'-'customer_account_id'-'per_purchase_minor'-'approval_threshold_minor'-'valid_to'-'reason'<>'{}'::jsonb
 or coalesce(p_body->>'per_purchase_minor','') !~ '^[0-9]{1,15}$' or coalesce(p_body->>'approval_threshold_minor','') !~ '^[0-9]{1,15}$'
 or length(trim(coalesce(p_body->>'reason',''))) not between 5 and 500
 or p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$' or p_correlation is null then raise exception 'VALIDATION_ERROR';end if;
 cap:=(p_body->>'per_purchase_minor')::bigint;threshold:=(p_body->>'approval_threshold_minor')::bigint;ends:=(p_body->>'valid_to')::timestamptz;
 if cap<=0 or threshold<0 or threshold>cap or ends is null or ends<=now()+interval '5 minutes' or ends>now()+interval '366 days' then raise exception 'VALIDATION_ERROR';end if;
 select * into source from public.memberships m where m.user_id=auth.uid() and m.tenant_id=tid and m.role='merchant_admin'
 and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.status='active'
 and m.valid_from<=now() and (m.valid_to is null or m.valid_to>=ends) order by m.valid_to desc nulls first,m.id limit 1 for share;
 if not found then raise exception 'PERMISSION_DENIED';end if;
 perform 1 from public.customer_accounts a where a.id=aid and a.tenant_id=tid for share;if not found then raise exception 'PERMISSION_DENIED';end if;
 perform pg_advisory_xact_lock(hashtextextended('customer-invitation-setup:'||tid::text||':'||aid::text||':'||auth.uid()::text,0));
 select * into cmd from private.commands where tenant_id=tid and actor_id=auth.uid() and operation='members.invitation_access.setup' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if not private.quota() then raise exception 'RATE_LIMITED';end if;
 select * into setup from private.customer_invitation_setups where tenant_id=tid and customer_account_id=aid and actor_id=auth.uid();
 if found then
  if setup.body<>p_body or not private.customer_invitation_setup_live(setup.membership_id) then raise exception 'VERSION_CONFLICT';end if;
  r:=setup.result;
 else
  insert into public.memberships(user_id,tenant_id,customer_account_id,role,valid_to) values(auth.uid(),tid,aid,'customer_admin',ends) returning id into mid;
  insert into private.member_delegations(membership_id,role,per_purchase_minor,approval_threshold_minor,valid_to)
  values(mid,'buyer',cap,threshold,ends),(mid,'approver',cap,threshold,ends);
  r:=jsonb_build_object('membership_id',mid,'tenant_id',tid,'customer_account_id',aid,'per_purchase_minor',cap::text,'approval_threshold_minor',threshold::text,'valid_to',ends);
  insert into private.customer_invitation_setups(tenant_id,customer_account_id,actor_id,source_membership_id,membership_id,body,result) values(tid,aid,auth.uid(),source.id,mid,p_body,r);
  insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(tid,auth.uid(),'members.invitation_access.setup',mid,p_correlation);
 end if;
 insert into private.commands values(tid,auth.uid(),'members.invitation_access.setup',p_key,p_body,r,now());return r;
end$$;
create function public.setup_customer_invitation_access(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.setup_customer_invitation_access(p_body,p_key,p_correlation)$$;
revoke all on function private.customer_invitation_setup_live(uuid),private.setup_customer_invitation_access(jsonb,text,uuid),public.setup_customer_invitation_access(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.setup_customer_invitation_access(jsonb,text,uuid),public.setup_customer_invitation_access(jsonb,text,uuid) to authenticated;

create or replace function private.inviter(p_membership uuid) returns public.memberships language plpgsql security definer set search_path='' as $$
declare m public.memberships;s jsonb;begin
 if not private.live_person() or not exists(select 1 from auth.users u where u.id=auth.uid() and (u.banned_until is null or u.banned_until<=now())) then raise exception 'PERMISSION_DENIED';end if;
 s:=private.security_state();
 if not(s->>'satisfied')::boolean or not(s->>'enrolled')::boolean or s->>'level'<>'aal2' then raise exception 'MFA_REQUIRED';end if;
 select * into m from public.memberships where id=p_membership for share;
 if not found or m.user_id<>auth.uid() or m.role<>'customer_admin' or m.customer_account_id is null
 or m.status<>'active' or m.valid_from>now() or (m.valid_to is not null and m.valid_to<=now())
 or not exists(select 1 from public.role_permissions r where r.role=m.role and r.permission='members.invite') then raise exception 'PERMISSION_DENIED';end if;
 if not private.customer_invitation_setup_live(m.id) then raise exception 'PERMISSION_DENIED';end if;
 return m;
end$$;

create or replace function private.validate_invitation_scope(i private.invitations) returns void language plpgsql security definer set search_path='' as $$
declare m public.memberships;d private.member_delegations;begin
 select * into m from public.memberships where id=i.issuer_membership_id for share;
 if not found or m.user_id<>i.issuer_id or m.role<>'customer_admin' or m.status<>'active' or m.valid_from>now()
 or (m.valid_to is not null and (m.valid_to<=now() or i.valid_to>m.valid_to))
 or m.tenant_id<>i.tenant_id or m.customer_account_id is distinct from i.customer_account_id
 or (m.store_id is not null and m.store_id is distinct from i.store_id)
 or (m.project_id is not null and m.project_id is distinct from i.project_id)
 or not exists(select 1 from public.role_permissions r where r.role=m.role and r.permission='members.invite') then raise exception 'INVITATION_UNAVAILABLE';end if;
 if not private.customer_invitation_setup_live(m.id) then raise exception 'INVITATION_UNAVAILABLE';end if;
 select * into d from private.member_delegations where membership_id=m.id and role=i.role for share;
 if not found or d.valid_to<=now() or i.valid_to>d.valid_to or i.per_purchase_minor>d.per_purchase_minor
 or i.approval_threshold_minor>d.approval_threshold_minor then raise exception 'INVITATION_UNAVAILABLE';end if;
 if (i.store_id is not null and not exists(select 1 from public.stores s where s.id=i.store_id and s.tenant_id=i.tenant_id)) or not exists(select 1 from public.customer_accounts a where a.id=i.customer_account_id and a.tenant_id=i.tenant_id and a.status<>'suspended')
 or (i.project_id is not null and not exists(select 1 from public.projects p where p.id=i.project_id and p.tenant_id=i.tenant_id and p.customer_account_id=i.customer_account_id and p.active)) then raise exception 'INVITATION_UNAVAILABLE';end if;
end$$;
