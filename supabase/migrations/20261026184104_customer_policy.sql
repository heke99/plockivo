-- Explicit merchant decisions. No production/test mode restriction; no external
-- credit verification is implied, and existing exposure/reservations are untouched.
create table private.customer_policies(
 account_id uuid primary key,tenant_id uuid not null,
 version integer not null check(version>0),
 review_status text not null check(review_status in ('pending','reviewed')),
 reason text not null check(length(trim(reason)) between 10 and 1000),
 evidence_reference text not null check(length(trim(evidence_reference)) between 1 and 200),
 updated_at timestamptz not null default now(),
 foreign key(tenant_id,account_id) references public.customer_accounts(tenant_id,id)
);
alter table private.customer_policies enable row level security;
revoke all on private.customer_policies from public,anon,authenticated;
create function private.customer_policy_dto(a public.customer_accounts,p private.customer_policies)
 returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'tenant_id',a.tenant_id,'name',a.name,
  'status',a.status,'purchase_blocked',a.purchase_blocked,
  'credit_limit_minor',a.credit_limit_minor::text,'exposure_minor',a.exposure_minor::text,
  'terms_version',a.terms_version,'policy_version',coalesce(p.version,0),
  'review_status',coalesce(p.review_status,'pending'),'reason',coalesce(p.reason,''),
  'evidence_reference',coalesce(p.evidence_reference,''),'decision_authority','merchant-manual')
$$;
create function private.get_customer_policy(p_tenant uuid,p_account uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare r jsonb;begin
 perform private.assert_mfa();
 if not private.customers_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 select private.customer_policy_dto(a,p) into r from public.customer_accounts a
 left join private.customer_policies p on p.tenant_id=a.tenant_id and p.account_id=a.id
 where a.tenant_id=p_tenant and a.id=p_account;
 if not found then raise exception 'NOT_FOUND';end if;
 return r;
end$$;
create function private.save_customer_policy(p_body jsonb,p_key text,p_correlation uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare t uuid;requested_account uuid;a public.customer_accounts;policy private.customer_policies;
 command private.commands;r jsonb;v integer;next_version integer;
 status_value text;terms text;review text;decision_reason text;evidence text;credit bigint;
begin
 if p_body is null or jsonb_typeof(p_body)<>'object' then raise exception 'VALIDATION_ERROR';end if;
 begin t:=(p_body->>'tenant_id')::uuid;requested_account:=(p_body->>'customer_account_id')::uuid;
 exception when invalid_text_representation then raise exception 'VALIDATION_ERROR';end;
 perform private.assert_mfa();
 if not private.customers_authorized(t) then raise exception 'PERMISSION_DENIED';end if;
 if p_body-'tenant_id'-'customer_account_id'-'version'-'status'-'purchase_blocked'-'credit_limit_minor'-'terms_version'-'review_status'-'reason'-'evidence_reference'<>'{}'::jsonb
 or not (p_body ?& array['tenant_id','customer_account_id','version','status','purchase_blocked','credit_limit_minor','terms_version','review_status','reason','evidence_reference'])
 or t is null or requested_account is null or p_correlation is null
 or p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$'
 or jsonb_typeof(p_body->'version') is distinct from 'number'
 or coalesce(p_body->>'version','') !~ '^(0|[1-9][0-9]{0,9})$'
 or coalesce(p_body->>'status','') not in ('pending','active','suspended')
 or coalesce(p_body->>'review_status','') not in ('pending','reviewed')
 or jsonb_typeof(p_body->'purchase_blocked') is distinct from 'boolean'
 or jsonb_typeof(p_body->'credit_limit_minor') is distinct from 'string'
 or coalesce(p_body->>'credit_limit_minor','') !~ '^(0|[1-9][0-9]{0,11})$'
 or jsonb_typeof(p_body->'reason') is distinct from 'string'
 or length(trim(coalesce(p_body->>'reason',''))) not between 10 and 1000
 or jsonb_typeof(p_body->'evidence_reference') is distinct from 'string'
 or length(trim(coalesce(p_body->>'evidence_reference',''))) not between 1 and 200
 or (jsonb_typeof(p_body->'terms_version') is distinct from 'null' and
  (jsonb_typeof(p_body->'terms_version') is distinct from 'string'
   or length(trim(coalesce(p_body->>'terms_version',''))) not between 1 and 100))
 then raise exception 'VALIDATION_ERROR';end if;
 if (p_body->>'version')::numeric>2147483646 then raise exception 'VALIDATION_ERROR';end if;
 v:=(p_body->>'version')::integer;status_value:=p_body->>'status';review:=p_body->>'review_status';
 credit:=(p_body->>'credit_limit_minor')::bigint;terms:=case when p_body->>'terms_version' is null then null else trim(p_body->>'terms_version') end;
 decision_reason:=trim(p_body->>'reason');evidence:=trim(p_body->>'evidence_reference');
 if (status_value='active' and (review<>'reviewed' or terms is null)) or (credit>0 and review<>'reviewed')
 then raise exception 'VALIDATION_ERROR';end if;
 -- Serialize command identity too, so cross-account same-key races are explicit.
 perform pg_advisory_xact_lock(hashtextextended(t::text||':'||auth.uid()::text||':customer.policy.save:'||p_key,0));
 select * into a from public.customer_accounts where tenant_id=t and id=requested_account for update;
 if not found then raise exception 'NOT_FOUND';end if;
 select * into command from private.commands where tenant_id=t and actor_id=auth.uid() and operation='customer.policy.save' and key=p_key;
 if found then
  if command.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return command.result;
 end if;
 select * into policy from private.customer_policies where tenant_id=t and private.customer_policies.account_id=a.id;
 if coalesce(policy.version,0)<>v then raise exception 'VERSION_CONFLICT';end if;
 next_version:=v+1;
 update public.customer_accounts set status=status_value,purchase_blocked=(p_body->>'purchase_blocked')::boolean,
  credit_limit_minor=credit,terms_version=terms where tenant_id=t and id=a.id returning * into a;
 insert into private.customer_policies(account_id,tenant_id,version,review_status,reason,evidence_reference,updated_at)
 values(a.id,t,next_version,review,decision_reason,evidence,now())
 on conflict(account_id) do update set version=excluded.version,review_status=excluded.review_status,
  reason=excluded.reason,evidence_reference=excluded.evidence_reference,updated_at=excluded.updated_at
 returning * into policy;
 r:=private.customer_policy_dto(a,policy);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id)
 values(t,auth.uid(),'customer.policy.save',a.id,p_correlation);
 insert into private.commands(tenant_id,actor_id,operation,key,body,result)
 values(t,auth.uid(),'customer.policy.save',p_key,p_body,r);
 return r;
end$$;
create function public.get_customer_policy(p_tenant uuid,p_account uuid) returns jsonb
 language sql security invoker set search_path='' as $$select private.get_customer_policy(p_tenant,p_account)$$;
create function public.save_customer_policy(p_body jsonb,p_key text,p_correlation uuid) returns jsonb
 language sql security invoker set search_path='' as $$select private.save_customer_policy(p_body,p_key,p_correlation)$$;
revoke all on function private.customer_policy_dto(public.customer_accounts,private.customer_policies),private.get_customer_policy(uuid,uuid),private.save_customer_policy(jsonb,text,uuid),public.get_customer_policy(uuid,uuid),public.save_customer_policy(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.get_customer_policy(uuid,uuid),private.save_customer_policy(jsonb,text,uuid),public.get_customer_policy(uuid,uuid),public.save_customer_policy(jsonb,text,uuid) to authenticated;
