-- TASK-049: verified people bootstrap only a new isolated workspace.
-- A business declaration is not external verification or a production-sales approval.
create table private.merchant_bootstrap_commands(
 actor_id uuid not null references auth.users(id), key text not null,
 body jsonb not null,result jsonb not null,created_at timestamptz not null default now(),
 primary key(actor_id,key)
);
alter table private.merchant_bootstrap_commands enable row level security;
revoke all on private.merchant_bootstrap_commands from public,anon,authenticated;
create function private.bootstrap_merchant(p_body jsonb,p_key text,p_correlation uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n text:=trim(p_body->>'name');l text:=trim(p_body->>'legal_name');s text:=p_body->>'slug';
 org text:=p_body->>'organization_number';reason text:=trim(p_body->>'reason');
 tid uuid;mid uuid;cmd private.merchant_bootstrap_commands;r jsonb;
begin
 -- AAL2 is explicit even before the person has any administrative membership.
 if not private.live_person() or not exists(select 1 from auth.users u where u.id=auth.uid() and (u.banned_until is null or u.banned_until<=now())) then raise exception 'PERMISSION_DENIED';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.mfa_satisfied() then raise exception 'MFA_REQUIRED';end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or p_body-'slug'-'name'-'legal_name'-'organization_number'-'reason'<>'{}'::jsonb
 or s is null or s !~ '^[a-z][a-z0-9-]{2,40}$' or s in ('app','api','admin','auth','www','support','status','mail')
 or n is null or length(n) not between 1 and 160 or l is null or length(l) not between 1 and 200
 or org is null or not private.valid_organization_number(org)
 or reason is null or length(reason) not between 5 and 500
 or p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$'
 or p_correlation is null then raise exception 'VALIDATION_ERROR';end if;
 -- Serialize an actor's concurrent retries before the new tenant exists.
 perform pg_advisory_xact_lock(hashtextextended('merchant-bootstrap:'||auth.uid()::text,0));
 select * into cmd from private.merchant_bootstrap_commands where actor_id=auth.uid() and key=p_key;
 if found then
  if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return cmd.result;
 end if;
 -- Quota also protects direct RPC use; authenticated API uses its shared quota as well.
 if not private.quota() then raise exception 'RATE_LIMITED';end if;
 insert into public.merchants(slug,name,legal_name,organization_number,mode,sales_paused,profile)
 values(s,n,l,org,'production',true,jsonb_build_object('display_name',n,'primary_color','#244e3c','business_identity_status','self_declared')) returning id into tid;
 insert into public.memberships(user_id,tenant_id,role) values(auth.uid(),tid,'merchant_admin') returning id into mid;
 r:=jsonb_build_object('tenant_id',tid,'membership_id',mid,'slug',s,'name',n,'mode','production','sales_paused',true,'self_declared_business',true);
 insert into private.merchant_bootstrap_commands(actor_id,key,body,result) values(auth.uid(),p_key,p_body,r);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id)
 values(tid,auth.uid(),'merchant.bootstrap',tid,p_correlation);
 return r;
end$$;
create function public.bootstrap_merchant(p_body jsonb,p_key text,p_correlation uuid) returns jsonb
language sql security invoker set search_path='' as $$select private.bootstrap_merchant(p_body,p_key,p_correlation)$$;
revoke all on function private.bootstrap_merchant(jsonb,text,uuid),public.bootstrap_merchant(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.bootstrap_merchant(jsonb,text,uuid),public.bootstrap_merchant(jsonb,text,uuid) to authenticated;
