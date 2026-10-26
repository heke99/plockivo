begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000005','e2e-buyer@plockivo.invalid'),('00000000-0000-4000-8000-000000000007','e2e-approver@plockivo.invalid'),('00000000-0000-4000-8000-000000000011','e2e-other@plockivo.invalid');
-- Verified synthetic identities and matching live sessions: authorization uses real Auth state.
update auth.users set email_confirmed_at=now() where id in ('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000011');
insert into auth.sessions(id,user_id,aal,created_at,updated_at) values
('00000000-0000-4000-8000-000000000069','00000000-0000-4000-8000-000000000005','aal1',now(),now()),('00000000-0000-4000-8000-00000000006b','00000000-0000-4000-8000-000000000007','aal1',now(),now()),('00000000-0000-4000-8000-000000000075','00000000-0000-4000-8000-000000000011','aal1',now(),now());

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


set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","session_id":"00000000-0000-4000-8000-000000000069","aal":"aal1"}',true);
do $$declare i jsonb;o jsonb;begin
 i:=public.prepare_purchase('{"tenant_id":"00000000-0000-4000-8000-000000000001","customer_account_id":"00000000-0000-4000-8000-000000000002","store_id":"00000000-0000-4000-8000-000000000003","project_id":"00000000-0000-4000-8000-000000000004","reference":"RETURN-TEST","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"4"}]}','returns-prepare-key01',gen_random_uuid());
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'returns-confirm-key01',gen_random_uuid());perform set_config('test.return.order',o->>'id',true);
end$$;
reset role;
insert into public.memberships(user_id,tenant_id,role) values('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000021"}',true);
do $$declare oid uuid:=current_setting('test.return.order')::uuid;s jsonb;c uuid;lid uuid;b jsonb;r jsonb;begin
 s:=public.inspect_test_order(oid,'{"version":0,"result":"passed","reason":"Testkontroll","recipient_reference":"TEST-MOTTAGARE","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"2"}]}','returns-inspect-key01',gen_random_uuid());
 s:=public.claim_test_order(oid,jsonb_build_object('version',(s->>'version')::integer,'recipient_reference','TEST-MOTTAGARE','lines','[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"2"}]'::jsonb),'returns-claim-key001',gen_random_uuid());
 c:=(s->'claims'->0->>'id')::uuid;lid:=(s->'lines'->0->>'order_line_id')::uuid;
 b:=jsonb_build_object('version',(s->>'version')::integer,'claim_id',c,'order_line_id',lid,'quantity','1','condition','opened','reason','Testretur');
 begin perform public.receive_test_return(oid,b,'returns-pending-key1',gen_random_uuid());raise exception 'pending claim returned';exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
 s:=public.confirm_test_claim(oid,c,jsonb_build_object('version',(s->>'version')::integer),'returns-fulfill-key1',gen_random_uuid());
 b:=b||jsonb_build_object('version',(s->>'version')::integer);
 r:=public.receive_test_return(oid,b,'returns-receive-key1',gen_random_uuid());
 assert r->'receipt'->>'status'='received' and r->'receipt'->>'financial_status'='not_requested';
 assert (r->'state'->'lines'->0->>'returned_quantity')::numeric=1;
 assert public.receive_test_return(oid,b,'returns-receive-key1',gen_random_uuid())=r,'replay stable';
 begin perform public.receive_test_return(oid,b,'returns-stale-key001',gen_random_uuid());raise exception 'stale accepted';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 -- A second fulfilled source leaves aggregate room, but first source must remain capped.
 s:=public.inspect_test_order(oid,jsonb_build_object('version',(r->'state'->>'version')::integer,'result','passed','reason','Test andra källan','recipient_reference','TEST-MOTTAGARE','lines','[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"1"}]'::jsonb),'returns-inspect-key02',gen_random_uuid());
 s:=public.claim_test_order(oid,jsonb_build_object('version',(s->>'version')::integer,'recipient_reference','TEST-MOTTAGARE','lines','[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"1"}]'::jsonb),'returns-claim-key002',gen_random_uuid());
 s:=public.confirm_test_claim(oid,(select (x->>'id')::uuid from jsonb_array_elements(s->'claims')x where x->>'id'<>c::text limit 1),jsonb_build_object('version',(s->>'version')::integer),'returns-fulfill-key2',gen_random_uuid());
 b:=b||jsonb_build_object('version',(s->>'version')::integer,'quantity','2');
 begin perform public.receive_test_return(oid,b,'returns-exceed-key01',gen_random_uuid());raise exception 'excess accepted';exception when raise_exception then if sqlerrm<>'RETURN_QUANTITY_EXCEEDED' then raise;end if;end;
 perform set_config('test.return.body',b::text,true);
end$$;
reset role;
do $$begin
 assert (select count(*) from private.test_return_receipts)=1;
 assert (select count(*) from private.audit_events where operation='returns.receive.test')=1;
 assert (select amount_minor from private.credit_reservations where order_id=current_setting('test.return.order')::uuid)=50000,'return must not release credit';
end$$;
insert into public.memberships(user_id,tenant_id,role) values('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000008','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000011','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000023','00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000022','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000011","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000023"}',true);
do $$begin
 begin perform public.receive_test_return(current_setting('test.return.order')::uuid,current_setting('test.return.body')::jsonb,'returns-cross-key001',gen_random_uuid());raise exception 'cross tenant accepted';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform 1 from private.test_return_receipts;raise exception 'direct receipt visible';exception when insufficient_privilege then null;end;
end$$;
reset role;
select 'RETURNS-022 confirmed source, quantity cap, replay, version, audit, no credit release and tenant isolation PASS' as result;
rollback;
