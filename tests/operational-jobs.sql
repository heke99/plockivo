begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email) values ('81000000-0000-4000-8000-000000000005','e2e-buyer-jobs@plockivo.invalid'),('81000000-0000-4000-8000-000000000007','e2e-approver-jobs@plockivo.invalid'),('81000000-0000-4000-8000-000000000011','e2e-other-jobs@plockivo.invalid');
-- Verified synthetic identities and matching live sessions: authorization uses real Auth state.
update auth.users set email_confirmed_at=now() where id in ('81000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000007','81000000-0000-4000-8000-000000000011');
insert into auth.sessions(id,user_id,aal,created_at,updated_at) values
('81000000-0000-4000-8000-000000000069','81000000-0000-4000-8000-000000000005','aal1',now(),now()),('81000000-0000-4000-8000-00000000006b','81000000-0000-4000-8000-000000000007','aal1',now(),now()),('81000000-0000-4000-8000-000000000075','81000000-0000-4000-8000-000000000011','aal1',now(),now());

insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
('81000000-0000-4000-8000-000000000001','e2e-jobs-nord','E2E Nord Test','E2E Nord Test AB','TEST-ONLY',false),('81000000-0000-4000-8000-000000000008','e2e-jobs-syd','E2E Syd Test','E2E Syd Test AB','TEST-ONLY',false);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('81000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false),('81000000-0000-4000-8000-000000000009','81000000-0000-4000-8000-000000000001','E2E El Test AB','TEST-B','active','test-v1',100000,false),('81000000-0000-4000-8000-000000000010','81000000-0000-4000-8000-000000000008','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('81000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000001','E2E Butik Test','TEST',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('81000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000002','E2E Projekt Test',100000);
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('81000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','buyer',100000,100000),('81000000-0000-4000-8000-000000000007','81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','approver',100000,0),('81000000-0000-4000-8000-000000000011','81000000-0000-4000-8000-000000000008','81000000-0000-4000-8000-000000000010',null,null,'buyer',100000,100000);
insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan) values('81000000-0000-4000-8000-000000000006','81000000-0000-4000-8000-000000000001','TEST-001','E2E Skruv Test','st',1,true);
insert into public.product_barcodes values('81000000-0000-4000-8000-000000000001','7350000000001','81000000-0000-4000-8000-000000000006',10);
insert into private.test_prices values('81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000006',10000,2500,1);


set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000005","role":"authenticated","session_id":"81000000-0000-4000-8000-000000000069","aal":"aal1"}',true);
do $$declare i jsonb;o jsonb;c jsonb;begin
 i:=public.prepare_purchase('{"tenant_id":"81000000-0000-4000-8000-000000000001","customer_account_id":"81000000-0000-4000-8000-000000000002","store_id":"81000000-0000-4000-8000-000000000003","project_id":"81000000-0000-4000-8000-000000000004","reference":"DOCS-013 TEST","lines":[{"product_id":"81000000-0000-4000-8000-000000000006","quantity":"2"}]}','docs-prepare-00001',gen_random_uuid());
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'docs-confirm-00001',gen_random_uuid());
 perform set_config('test.docs.intent',i->>'id',true);
 c:=public.get_order_confirmation((i->>'id')::uuid);
 assert c->>'status'='pending' and c->'document'='null'::jsonb,'pending state';
 assert c->>'mode'='test' and c->>'order_id'=o->>'id','order identity';
 begin perform public.get_order_confirmation(gen_random_uuid());raise exception 'unknown visible';exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
end$$;
reset role;
insert into public.memberships(user_id,tenant_id,role) values('81000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('81000000-0000-4000-8000-000000000020','81000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('81000000-0000-4000-8000-000000000021','81000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"81000000-0000-4000-8000-000000000021"}',true);
do $$declare j jsonb;begin
 j:=public.list_merchant_jobs('81000000-0000-4000-8000-000000000001');assert jsonb_array_length(j->'jobs')=2;assert j->>'limit'='100';
 assert not exists(select 1 from jsonb_array_elements(j->'jobs') x where x ? 'claim_token' or x ? 'content' or x ? 'payload');
 begin perform public.list_merchant_jobs('81000000-0000-4000-8000-000000000008');raise exception 'tenant leaked';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin update private.outbox set status='queued';raise exception 'direct update allowed';exception when insufficient_privilege then null;end;
end$$;
reset role;
update private.outbox set status='manual_review',attempts=1 where kind='notification' and tenant_id='81000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$declare j jsonb;begin
 j:=public.list_merchant_jobs('81000000-0000-4000-8000-000000000001');
 assert exists(select 1 from jsonb_array_elements(j->'jobs') x where x->>'action'='delivery_not_configured');
end$$;
select set_config('request.jwt.claims','{"sub":"81000000-0000-4000-8000-000000000011","role":"authenticated","session_id":"81000000-0000-4000-8000-000000000075","aal":"aal1"}',true);
do $$begin
 begin perform public.list_merchant_jobs('81000000-0000-4000-8000-000000000008');raise exception 'buyer allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
set local role anon;
do $$begin begin perform public.list_merchant_jobs('81000000-0000-4000-8000-000000000001');raise exception 'anon allowed';exception when insufficient_privilege then null;end;end$$;
reset role;
select 'OPERATIONS-016 real role inspection, tenant/buyer/anonymous denial, safe fields, direct write denied PASS' as result;
rollback;
