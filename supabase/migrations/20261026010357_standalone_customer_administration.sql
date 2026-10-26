-- Standalone account preparation only. Creation never approves credit or shopping.
insert into public.role_permissions values('merchant_admin','customers.manage');
create function private.customers_authorized(p_tenant uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.profile_authorized(p_tenant) and private.allowed(p_tenant,null,null,null,'customers.manage')
$$;
create function private.customer_admin_dto(a public.customer_accounts) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',a.id,'tenant_id',a.tenant_id,'name',a.name,'organization_number',a.organization_number,'status',a.status,'purchase_blocked',a.purchase_blocked,'credit_limit_minor',a.credit_limit_minor::text,'verification_status','unverified')
$$;
create function private.valid_organization_number(p_number text) returns boolean language plpgsql immutable set search_path='' as $$
declare total integer;begin
 if p_number is null or p_number !~ '^[0-9]{10}$' or substring(p_number,3,1)<'2' then return false;end if;
 select sum((d/10)+(d%10)) into total from (select substring(p_number,i,1)::integer * case when i%2=1 then 2 else 1 end d from generate_series(1,10)i)q;
 return total%10=0;
end$$;
create function private.list_merchant_customers(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_mfa();if not private.customers_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 return coalesce((select jsonb_agg(private.customer_admin_dto(x)) from (select * from public.customer_accounts where tenant_id=p_tenant order by name,id limit 200)x),'[]');
end$$;
create function private.create_merchant_customer(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=(p_body->>'tenant_id')::uuid;a public.customer_accounts;cmd private.commands;r jsonb;n text:=trim(p_body->>'name');org text:=p_body->>'organization_number';begin
 perform private.assert_mfa();if not private.customers_authorized(tid) then raise exception 'PERMISSION_DENIED';end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or p_body-'tenant_id'-'name'-'organization_number'<>'{}'::jsonb or n is null or length(n) not between 1 and 160 or org is null or not private.valid_organization_number(org) or p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(tid::text||':customer-create',0));
 select * into cmd from private.commands where tenant_id=tid and actor_id=auth.uid() and operation='customers.create' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if exists(select 1 from public.customer_accounts where tenant_id=tid and regexp_replace(organization_number,'[^0-9]','','g')=org) then raise exception 'CUSTOMER_EXISTS';end if;
 insert into public.customer_accounts(tenant_id,name,organization_number,status,purchase_blocked,credit_limit_minor,exposure_minor) values(tid,n,org,'suspended',true,0,0) returning * into a;
 r:=private.customer_admin_dto(a);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(tid,auth.uid(),'customers.create',a.id,p_correlation);
 insert into private.commands values(tid,auth.uid(),'customers.create',p_key,p_body,r,now());return r;
end$$;
create function public.list_merchant_customers(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_merchant_customers(p_tenant)$$;
create function public.create_merchant_customer(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.create_merchant_customer(p_body,p_key,p_correlation)$$;
revoke all on function private.customers_authorized(uuid),private.customer_admin_dto(public.customer_accounts),private.valid_organization_number(text),private.list_merchant_customers(uuid),private.create_merchant_customer(jsonb,text,uuid),public.list_merchant_customers(uuid),public.create_merchant_customer(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.list_merchant_customers(uuid),private.create_merchant_customer(jsonb,text,uuid),public.list_merchant_customers(uuid),public.create_merchant_customer(jsonb,text,uuid) to authenticated;
