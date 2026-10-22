begin;

insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000005','e2e-buyer@plockivo.invalid'),('00000000-0000-4000-8000-000000000007','e2e-approver@plockivo.invalid'),('00000000-0000-4000-8000-000000000011','e2e-other@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
('00000000-0000-4000-8000-000000000001','e2e-nord','E2E Nord Test','E2E Nord Test AB','TEST-ONLY',false),('00000000-0000-4000-8000-000000000008','e2e-syd','E2E Syd Test','E2E Syd Test AB','TEST-ONLY',false);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false),('00000000-0000-4000-8000-000000000009','00000000-0000-4000-8000-000000000001','E2E El Test AB','TEST-B','active','test-v1',100000,false),('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000008','E2E Bygg Test AB','TEST-A','active','test-v1',100000,false);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','E2E Butik Test','TEST',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','E2E Projekt Test',100000);
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','buyer',100000,1000),('00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','approver',100000,0),('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000010',null,null,'buyer',100000,100000);
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor) values('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','approver',100000);
insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan) values('00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','TEST-001','E2E Skruv Test','st',1,true);
insert into public.product_barcodes values('00000000-0000-4000-8000-000000000001','7350000000001','00000000-0000-4000-8000-000000000006',10);
insert into private.test_prices values('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000006',10000,2500,1);

set local role authenticated;select set_config('request.jwt.claims','{"sub": "00000000-0000-4000-8000-000000000005", "role": "authenticated"}',true);

do $$declare i jsonb;o jsonb;again jsonb;b jsonb:='{"tenant_id": "00000000-0000-4000-8000-000000000001", "customer_account_id": "00000000-0000-4000-8000-000000000002", "store_id": "00000000-0000-4000-8000-000000000003", "project_id": "00000000-0000-4000-8000-000000000004", "reference": "E2E-BOOTSTRAP", "lines": [{"product_id": "00000000-0000-4000-8000-000000000006", "quantity": "2"}]}';begin
 assert jsonb_array_length(public.get_context()->'memberships')=2,'context membership';
 assert jsonb_array_length(public.get_context()->'projects')=1,'scoped project';
 assert jsonb_array_length(public.lookup_products('00000000-0000-4000-8000-000000000001','7350000000001'))=1,'barcode lookup';
 assert (select count(*) from public.merchants)=1,'tenant merchant RLS';
 begin perform public.lookup_products('00000000-0000-4000-8000-000000000008','');raise exception 'expected denial';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin update public.customer_accounts set credit_limit_minor=999999;raise exception 'direct write allowed';exception when insufficient_privilege then null;end;
 begin perform public.pending_test_jobs();raise exception 'worker allowed';exception when insufficient_privilege then null;end;
 begin perform public.prepare_purchase(jsonb_set(b,'{customer_account_id}','"00000000-0000-4000-8000-000000000009"'),'wrong-account0001',gen_random_uuid());raise exception 'wrong account allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 i:=public.prepare_purchase(b,'prepare-0000000001',gen_random_uuid());
 assert i->'quote'->>'total_minor'='25000','exact money';
 assert public.prepare_purchase(b,'prepare-0000000001',gen_random_uuid())=i,'prepare replay';
 begin perform public.prepare_purchase(jsonb_set(b,'{reference}','"different"'),'prepare-0000000001',gen_random_uuid());raise exception 'expected conflict';exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 begin perform public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',99,'quote_hash',i->>'quote_hash'),'confirm-wrong0001',gen_random_uuid());raise exception 'expected version';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 begin perform public.confirm_purchase((i->>'id')::uuid,'{"version":1}','confirm-missing01',gen_random_uuid());raise exception 'expected hash';exception when raise_exception then if sqlerrm<>'PRICE_CHANGED' then raise;end if;end;
 begin perform public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'approval-required01',gen_random_uuid());raise exception 'expected approval';exception when raise_exception then if sqlerrm<>'APPROVAL_REQUIRED' then raise;end if;end;
 begin perform public.decide_approval((i->>'id')::uuid,'{"version":1,"decision":"approved"}','approval-self0001',gen_random_uuid());raise exception 'self approved';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated"}',true);
 perform public.decide_approval((i->>'id')::uuid,'{"version":1,"decision":"approved"}','approval-valid001',gen_random_uuid());
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
 o:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'confirm-000000001',gen_random_uuid());
 again:=public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'confirm-000000002',gen_random_uuid());
 assert o->>'id'=again->>'id','one intent one order';
 assert (select count(*) from public.orders)=1,'one visible order';
 assert public.get_purchase_intent((i->>'id')::uuid)->>'status'='completed','status readback';
 perform set_config('test.intent',i->>'id',true);
end$$;
reset role;
do $$begin
 assert (select exposure_minor from public.customer_accounts where id='00000000-0000-4000-8000-000000000002')=25000,'credit once';
 assert (select committed_minor from public.projects where id='00000000-0000-4000-8000-000000000004')=25000,'budget once';
 assert (select count(*) from private.outbox where tenant_id='00000000-0000-4000-8000-000000000001')=2,'durable jobs';
 assert (select count(*) from private.audit_events where tenant_id='00000000-0000-4000-8000-000000000001' and operation='purchases.confirm')=1,'audit once';
end$$;
set local role authenticated;select set_config('request.jwt.claims','{"sub": "00000000-0000-4000-8000-000000000011", "role": "authenticated"}',true);
do $$begin
 assert (select count(*) from public.orders)=0,'cross tenant orders';
 assert public.get_purchase_intent(current_setting('test.intent')::uuid) is null,'cross tenant intent';
end$$;
reset role;
update public.memberships set status='suspended' where user_id='00000000-0000-4000-8000-000000000005';
set local role authenticated;select set_config('request.jwt.claims','{"sub": "00000000-0000-4000-8000-000000000005", "role": "authenticated"}',true);
do $$begin
 assert (select count(*) from public.orders)=0,'revoked historical access';
 begin perform public.prepare_purchase('{"tenant_id": "00000000-0000-4000-8000-000000000001", "customer_account_id": "00000000-0000-4000-8000-000000000002", "store_id": "00000000-0000-4000-8000-000000000003", "project_id": "00000000-0000-4000-8000-000000000004", "reference": "E2E-BOOTSTRAP", "lines": [{"product_id": "00000000-0000-4000-8000-000000000006", "quantity": "2"}]}','prepare-suspend01',gen_random_uuid());raise exception 'suspended allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
do $$declare j jsonb;x jsonb;begin
 for j in select value from jsonb_array_elements(public.pending_test_jobs()) loop
  x:=public.process_test_job((j#>>'{}')::uuid);
  assert public.process_test_job((j#>>'{}')::uuid)=x,'worker replay';
 end loop;
end$$;
reset role;
do $$begin
 assert (select count(*) from public.documents where tenant_id='00000000-0000-4000-8000-000000000001')=1,'document unique';
 assert (select count(*) from private.outbox where tenant_id='00000000-0000-4000-8000-000000000001' and status='succeeded')=1,'doc success';
 assert (select count(*) from private.outbox where tenant_id='00000000-0000-4000-8000-000000000001' and status='manual_review')=1,'notification not fake sent';
end$$;
select 'PASS: role isolation, scoped context, exact prices, version/hash checks, idempotency, reservation, revocation, document job and worker replay' as result;
rollback;
