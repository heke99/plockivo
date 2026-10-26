begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email,email_confirmed_at) values ('70000000-0000-4000-8000-000000000005','e2e-buyer-docs@plockivo.invalid',now()),('70000000-0000-4000-8000-000000000007','e2e-approver-docs@plockivo.invalid',now()),('70000000-0000-4000-8000-000000000011','e2e-other-docs@plockivo.invalid',now());
-- Verified personal Auth sessions for legitimate actors; negative MFA/session probes below stay intact.
insert into auth.sessions(id,user_id,aal,created_at,updated_at) values ('70000000-0000-4000-8000-000000000105','70000000-0000-4000-8000-000000000005','aal1',now(),now()),('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000007','aal1',now(),now()),('70000000-0000-4000-8000-000000000111','70000000-0000-4000-8000-000000000011','aal1',now(),now());
insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
('70000000-0000-4000-8000-000000000001','e2e-doc-nord','E2E Nord Test','E2E Nord Test AB','TEST-ONLY',false),('70000000-0000-4000-8000-000000000008','e2e-doc-syd','E2E Syd Test','E2E Syd Test AB','TEST-ONLY',false);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('70000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000001','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false),('70000000-0000-4000-8000-000000000009','70000000-0000-4000-8000-000000000001','E2E El Test AB','TEST-B','active','test-v1',100000,false),('70000000-0000-4000-8000-000000000010','70000000-0000-4000-8000-000000000008','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('70000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000001','E2E Butik Test','TEST',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('70000000-0000-4000-8000-000000000004','70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002','E2E Projekt Test',100000);
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('70000000-0000-4000-8000-000000000005','70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000004','buyer',100000,100000),('70000000-0000-4000-8000-000000000007','70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000004','approver',100000,0),('70000000-0000-4000-8000-000000000011','70000000-0000-4000-8000-000000000008','70000000-0000-4000-8000-000000000010',null,null,'buyer',100000,100000);
insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan) values('70000000-0000-4000-8000-000000000006','70000000-0000-4000-8000-000000000001','TEST-001','E2E Skruv Test','st',1,true);
insert into public.product_barcodes values('70000000-0000-4000-8000-000000000001','7350000000001','70000000-0000-4000-8000-000000000006',10);
insert into private.test_prices values('70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000006',10000,2500,1);


set local role authenticated;
select set_config('request.jwt.claims','{"sub":"70000000-0000-4000-8000-000000000005","role":"authenticated","session_id":"70000000-0000-4000-8000-000000000105","aal":"aal1"}',true);
do $$declare i jsonb;o jsonb;c jsonb;begin
 i:=public.prepare_purchase('{"tenant_id":"70000000-0000-4000-8000-000000000001","customer_account_id":"70000000-0000-4000-8000-000000000002","store_id":"70000000-0000-4000-8000-000000000003","project_id":"70000000-0000-4000-8000-000000000004","reference":"DOCS-013 TEST","lines":[{"product_id":"70000000-0000-4000-8000-000000000006","quantity":"2"}]}','docs-prepare-00001',gen_random_uuid());
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'docs-confirm-00001',gen_random_uuid());
 perform set_config('test.docs.intent',i->>'id',true);
 c:=public.get_order_confirmation((i->>'id')::uuid);
 assert c->>'status'='pending' and c->'document'='null'::jsonb,'pending state';
 assert c->>'mode'='test' and c->>'order_id'=o->>'id','order identity';
 begin perform public.get_order_confirmation(gen_random_uuid());raise exception 'unknown visible';exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
end$$;
reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$declare j jsonb;begin
 for j in select value from jsonb_array_elements(public.pending_test_jobs()) loop perform public.process_test_job((j#>>'{}')::uuid);end loop;
end$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"70000000-0000-4000-8000-000000000005","role":"authenticated","session_id":"70000000-0000-4000-8000-000000000105","aal":"aal1"}',true);
do $$declare c jsonb;begin
 c:=public.get_order_confirmation(current_setting('test.docs.intent')::uuid);
 assert c->>'status'='ready','ready after worker';
 assert c->'document'->>'kind'='purchase_confirmation','correct document kind';
 assert c->'document'->'content'->>'reference'='DOCS-013 TEST','frozen content';
 assert c->'document'->'content'->>'total_minor'='25000','exact total';
 assert c=public.get_order_confirmation(current_setting('test.docs.intent')::uuid),'read replay no side effects';
 assert (select count(*) from public.documents)=1,'one visible document';
end$$;
select set_config('request.jwt.claims','{"sub":"70000000-0000-4000-8000-000000000011","role":"authenticated","session_id":"70000000-0000-4000-8000-000000000111","aal":"aal1"}',true);
do $$begin
 begin perform public.get_order_confirmation(current_setting('test.docs.intent')::uuid);raise exception 'cross tenant visible';exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
 assert (select count(*) from public.documents)=0,'cross tenant document RLS';
end$$;
reset role;
update public.memberships set status='revoked' where user_id='70000000-0000-4000-8000-000000000005';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"70000000-0000-4000-8000-000000000005","role":"authenticated","session_id":"70000000-0000-4000-8000-000000000105","aal":"aal1"}',true);
do $$begin
 begin perform public.get_order_confirmation(current_setting('test.docs.intent')::uuid);raise exception 'revoked visible';exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
 assert (select count(*) from public.documents)=0,'revoked document RLS';
end$$;
reset role;
set local role anon;
do $$begin
 begin perform public.get_order_confirmation(current_setting('test.docs.intent')::uuid);raise exception 'anonymous visible';exception when insufficient_privilege then null;end;
end$$;
reset role;
select 'DOCS-013 authorized pending/ready read, exact snapshot, tenant/revoked/anon denial and rollback PASS' as result;
rollback;
