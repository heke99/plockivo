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


set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
do $$declare i jsonb;o jsonb;begin
 i:=public.prepare_purchase('{"tenant_id":"00000000-0000-4000-8000-000000000001","customer_account_id":"00000000-0000-4000-8000-000000000002","store_id":"00000000-0000-4000-8000-000000000003","project_id":"00000000-0000-4000-8000-000000000004","reference":"CANCEL-021 TEST","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"2"}]}','cancel-prepare-00001',gen_random_uuid());
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'cancel-confirm-00001',gen_random_uuid());perform set_config('test.cancel.order',o->>'id',true);
end$$;
reset role;
insert into public.memberships(user_id,tenant_id,role) values('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000021"}',true);
select public.get_test_fulfillment(current_setting('test.cancel.order')::uuid);
reset role;
select private.fulfillment_lock(current_setting('test.cancel.order')::uuid,'orders.cancel.test');
update private.order_line_disposition set claimed_quantity=1 where order_id=current_setting('test.cancel.order')::uuid;
set local role authenticated;
do $$declare b jsonb:='{"version":0,"reason":"test cancellation","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"1"}]}';r jsonb;begin
 r:=public.cancel_test_order_lines(current_setting('test.cancel.order')::uuid,b,'cancel-test-key-0001',gen_random_uuid());
 assert (r->>'version')::integer=1;
 assert public.cancel_test_order_lines(current_setting('test.cancel.order')::uuid,b,'cancel-test-key-0001',gen_random_uuid())=r;
 begin perform public.cancel_test_order_lines(current_setting('test.cancel.order')::uuid,b,'cancel-test-key-0002',gen_random_uuid());raise exception 'stale accepted';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 b:=jsonb_set(b,'{version}','1');
 begin perform public.cancel_test_order_lines(current_setting('test.cancel.order')::uuid,b,'cancel-test-key-0003',gen_random_uuid());raise exception 'claimed cancelled';exception when raise_exception then if sqlerrm<>'QUANTITY_CONFLICT' then raise;end if;end;
end$$;
reset role;
do $$begin
 assert (select cancelled_quantity=1 and claimed_quantity=1 and fulfilled_quantity=0 from private.order_line_disposition where order_id=current_setting('test.cancel.order')::uuid);
 assert (select count(*) from private.order_cancellations)=1;
 assert (select count(*) from private.audit_events where operation='fulfillment.cancel')=1;
 assert (select count(*) from private.credit_reservations)=1;
 assert (select inspection_status from private.fulfillment_orders where order_id=current_setting('test.cancel.order')::uuid)='pending';
end$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000011","role":"authenticated"}',true);
do $$begin
 begin perform public.cancel_test_order_lines(current_setting('test.cancel.order')::uuid,'{"version":1,"reason":"cross tenant","lines":[]}','cancel-test-key-0004',gen_random_uuid());raise exception 'tenant allowed';exception when raise_exception then if sqlerrm not in ('PERMISSION_DENIED','MFA_REQUIRED','NOT_FOUND') then raise;end if;end;
end$$;
reset role;
select 'CANCEL-021 remaining-only, claimed conservation, version/replay, audit and no financial release PASS' as result;
rollback;
