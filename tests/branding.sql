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


update public.merchants set profile='{"display_name":"Nord butik","primary_color":"#123456","logo_data_url":null,"secret":"not-for-browser"}' where id='00000000-0000-4000-8000-000000000001';
update public.merchants set profile='{"display_name":"Syd hemlig","primary_color":"invalid","logo_data_url":"https://evil.invalid/image"}' where id='00000000-0000-4000-8000-000000000008';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1"}',true);
do $$declare c jsonb:=public.get_context();b jsonb;begin
 assert jsonb_array_length(c->'memberships')=1;
 b:=c->'memberships'->0->'branding';assert b->>'display_name'='Nord butik';assert b->>'primary_color'='#123456';assert b->>'logo_data_url' is null;assert not b ? 'secret';assert c::text not like '%Syd hemlig%';
end$$;
reset role;
update public.memberships set status='revoked' where user_id='00000000-0000-4000-8000-000000000005';
set local role authenticated;
do $$begin assert public.get_context()->'memberships'='[]'::jsonb;end$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000011","role":"authenticated","aal":"aal1"}',true);
do $$declare c jsonb:=public.get_context();b jsonb;begin
 b:=c->'memberships'->0->'branding';assert b->>'display_name'='Syd hemlig';assert b->>'primary_color'='#244e3c';assert b->>'logo_data_url' is null;assert c::text not like '%Nord butik%';
end$$;
reset role;
update public.merchants set profile='{}';
set local role authenticated;
do $$begin assert public.get_context()->'memberships'->0->'branding'->>'display_name'='E2E Syd Test';end$$;
reset role;
select 'BRANDING-009 authenticated context scope, revocation, safe fallback and whitelist PASS' as result;
rollback;
