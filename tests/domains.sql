begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000005','e2e-buyer@plockivo.invalid'),('00000000-0000-4000-8000-000000000007','e2e-approver@plockivo.invalid'),('00000000-0000-4000-8000-000000000011','e2e-other@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
('00000000-0000-4000-8000-000000000001','e2e-nord','E2E Nord Test','E2E Nord Test AB','TEST-ONLY',false),('00000000-0000-4000-8000-000000000008','e2e-syd','E2E Syd Test','E2E Syd Test AB','TEST-ONLY',false);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false),('00000000-0000-4000-8000-000000000009','00000000-0000-4000-8000-000000000001','E2E El Test AB','TEST-B','active','test-v1',100000,false),('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000008','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','E2E Butik Test','TEST',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','E2E Projekt Test',100000);
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','buyer',100000,100000),('00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','approver',100000,0),('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000010',null,null,'buyer',100000,100000);
insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan) values('00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','TEST-001','E2E Skruv Test','st',1,true);
insert into public.product_barcodes values('00000000-0000-4000-8000-000000000001','7350000000001','00000000-0000-4000-8000-000000000006',10);
insert into private.test_prices values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000006',10000,2500,1);


insert into public.memberships(user_id,tenant_id,role) values('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000021"}',true);
do $$declare r jsonb;d uuid;t uuid:='00000000-0000-4000-8000-000000000001';begin
 r:=public.request_merchant_domain(t,'shop.example.com',gen_random_uuid());d:=(r->>'id')::uuid;
 assert r->>'status'='pending';
 assert public.request_merchant_domain(t,'shop.example.com',gen_random_uuid())->>'id'=d::text;
 assert jsonb_array_length(public.list_merchant_domains(t))=1;
 begin perform public.request_merchant_domain(t,'https://evil.example.com',gen_random_uuid());raise exception 'url accepted';exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin perform public.list_merchant_domains('00000000-0000-4000-8000-000000000008');raise exception 'tenant leaked';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform public.remove_merchant_domain(t,d,2,gen_random_uuid());raise exception 'stale accepted';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 assert public.remove_merchant_domain(t,d,1,gen_random_uuid())->>'status'='removed';
 assert jsonb_array_length(public.list_merchant_domains(t))=0;
 begin update private.merchant_domains set status='verified';raise exception 'direct activation';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin assert (select count(*) from private.audit_events where operation like 'merchant.domain.%')=2;end$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated","aal":"aal1"}',true);
do $$begin
 begin perform public.list_merchant_domains('00000000-0000-4000-8000-000000000001');raise exception 'buyer allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
select 'DOMAIN-008 permission, idempotency, pending-only, conflict and removal PASS' as result;
rollback;
