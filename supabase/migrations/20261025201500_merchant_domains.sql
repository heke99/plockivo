-- DOMAIN-008: customer requests only. No activation API and no DNS side effects.
create table private.merchant_domains (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.merchants(id),
 hostname text not null check(length(hostname)<=253 and hostname=lower(hostname)),
 status text not null default 'pending' check(status in ('pending','verified','removed')),
 version integer not null default 1 check(version>0),created_at timestamptz not null default now(),
 verified_at timestamptz,verification_reference text,
 check(status<>'verified' or (verified_at is not null and length(verification_reference)>0))
);
-- Unverified requests must not let another tenant squat on a hostname globally.
create unique index merchant_domain_request_unique on private.merchant_domains(tenant_id,hostname) where status<>'removed';
create unique index merchant_domain_verified_unique on private.merchant_domains(hostname) where status='verified';
alter table private.merchant_domains enable row level security;
revoke all on private.merchant_domains from public,anon,authenticated;
insert into public.role_permissions values('merchant_admin','merchant.domains.manage');
create function private.domain_admin(p_tenant uuid) returns void language plpgsql security definer set search_path='' as $$begin
 if not private.mfa_satisfied() or not private.allowed(p_tenant,null,null,null,'merchant.domains.manage') or not exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.role='merchant_admin' and m.status='active' and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())) then raise exception 'PERMISSION_DENIED';end if;
end$$;
create function private.list_merchant_domains(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform private.domain_admin(p_tenant);
 return coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from private.merchant_domains d where d.tenant_id=p_tenant and d.status<>'removed'),'[]');
end$$;
create function private.request_merchant_domain(p_tenant uuid,p_hostname text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare d private.merchant_domains;begin
 perform private.domain_admin(p_tenant);
 if p_hostname is null or length(p_hostname)>253 or p_hostname !~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' or p_hostname='plockivo.com' or p_hostname like '%.plockivo.com' or p_hostname ~ '\.(local|localhost|internal)$' then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_tenant::text||':domains',0));
 select * into d from private.merchant_domains where tenant_id=p_tenant and hostname=p_hostname and status<>'removed';
 if found then return to_jsonb(d);end if;
 if (select count(*) from private.merchant_domains where tenant_id=p_tenant and status<>'removed')>=10 then raise exception 'RATE_LIMITED';end if;
 insert into private.merchant_domains(tenant_id,hostname) values(p_tenant,p_hostname) returning * into d;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(p_tenant,auth.uid(),'merchant.domain.request',d.id,p_correlation);
 return to_jsonb(d);
end$$;
create function private.remove_merchant_domain(p_tenant uuid,p_id uuid,p_version integer,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare d private.merchant_domains;begin
 perform private.domain_admin(p_tenant);
 select * into d from private.merchant_domains where id=p_id and tenant_id=p_tenant for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if d.version<>p_version then raise exception 'VERSION_CONFLICT';end if;
 -- Verified domains require platform deprovisioning first, not a customer-side deletion.
 if d.status<>'pending' then raise exception 'PERMISSION_DENIED';end if;
 update private.merchant_domains set status='removed',version=version+1 where id=p_id returning * into d;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(p_tenant,auth.uid(),'merchant.domain.remove',d.id,p_correlation);
 return to_jsonb(d);
end$$;
create function public.list_merchant_domains(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_merchant_domains(p_tenant)$$;
create function public.request_merchant_domain(p_tenant uuid,p_hostname text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.request_merchant_domain(p_tenant,p_hostname,p_correlation)$$;
create function public.remove_merchant_domain(p_tenant uuid,p_id uuid,p_version integer,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.remove_merchant_domain(p_tenant,p_id,p_version,p_correlation)$$;
revoke all on function private.domain_admin(uuid),private.list_merchant_domains(uuid),private.request_merchant_domain(uuid,text,uuid),private.remove_merchant_domain(uuid,uuid,integer,uuid),public.list_merchant_domains(uuid),public.request_merchant_domain(uuid,text,uuid),public.remove_merchant_domain(uuid,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function private.list_merchant_domains(uuid),private.request_merchant_domain(uuid,text,uuid),private.remove_merchant_domain(uuid,uuid,integer,uuid),public.list_merchant_domains(uuid),public.request_merchant_domain(uuid,text,uuid),public.remove_merchant_domain(uuid,uuid,integer,uuid) to authenticated;
