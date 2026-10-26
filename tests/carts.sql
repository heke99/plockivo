begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email,email_confirmed_at) values ('00000000-0000-4000-8000-000000000005','e2e-buyer@plockivo.invalid',now()),('00000000-0000-4000-8000-000000000007','e2e-approver@plockivo.invalid',now()),('00000000-0000-4000-8000-000000000011','e2e-other@plockivo.invalid',now());
-- Real verified identity/session fixtures required by the live-person boundary.
insert into auth.sessions(id,user_id,aal,created_at,updated_at) values
('00000000-0000-4000-8000-000000000105','00000000-0000-4000-8000-000000000005','aal1',now(),now()),
('00000000-0000-4000-8000-000000000107','00000000-0000-4000-8000-000000000007','aal1',now(),now()),
('00000000-0000-4000-8000-000000000111','00000000-0000-4000-8000-000000000011','aal1',now(),now());
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
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000105"}',true);
do $$declare b jsonb:='{"id":null,"version":0,"tenant_id":"00000000-0000-4000-8000-000000000001","customer_account_id":"00000000-0000-4000-8000-000000000002","store_id":"00000000-0000-4000-8000-000000000003","project_id":"00000000-0000-4000-8000-000000000004","reference":"CART-TEST","lines":[{"product_id":"00000000-0000-4000-8000-000000000006","quantity":"2"}]}';c jsonb;c2 jsonb;i jsonb;i2 jsonb;o jsonb;begin
 c:=public.save_cart(b,'cart-create-000001',gen_random_uuid());
 assert c->>'version'='1','initial revision';
 assert public.save_cart(b,'cart-create-000001',gen_random_uuid())=c,'create replay';
 assert public.get_current_cart((b->>'tenant_id')::uuid,(b->>'customer_account_id')::uuid,(b->>'store_id')::uuid,(b->>'project_id')::uuid)=c,'server resume';
 begin perform public.save_cart(jsonb_set(b,'{reference}','"different"'),'cart-create-000001',gen_random_uuid());raise exception 'missing conflict';exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 begin perform public.save_cart(b,'cart-second-00001',gen_random_uuid());raise exception 'overwrote live cart';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 begin update public.carts set reference='bypass';raise exception 'direct cart write allowed';exception when insufficient_privilege then null;end;
 i:=public.submit_cart((c->>'id')::uuid,1,'cart-submit-00001',gen_random_uuid());
 i2:=public.submit_cart((c->>'id')::uuid,1,'cart-submit-00002',gen_random_uuid());assert i->>'id'=i2->>'id','one quote per cart revision';
 -- An invalid edit must roll back quote invalidation and preserve all saved lines.
 begin perform public.save_cart(b||jsonb_build_object('id',c->>'id','version',1,'lines',jsonb_build_array(jsonb_build_object('product_id','00000000-0000-4000-8000-000000000006','quantity','0.5'))),'cart-invalid-0001',gen_random_uuid());raise exception 'invalid quantity accepted';exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 assert public.get_purchase_intent((i->>'id')::uuid)->>'status'=i->>'status','failed save preserves quote';
 assert public.get_current_cart((b->>'tenant_id')::uuid,(b->>'customer_account_id')::uuid,(b->>'store_id')::uuid,(b->>'project_id')::uuid)->>'version'='1','failed save preserves revision';
 b:=b||jsonb_build_object('id',c->>'id','version',1,'reference','REVISION-2');
 c2:=public.save_cart(b,'cart-update-00001',gen_random_uuid());assert c2->>'version'='2','revision increment';
 assert public.get_purchase_intent((i->>'id')::uuid)->>'status'='rejected','prior quote invalidated';
 begin perform public.confirm_purchase((i->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i->>'quote_hash'),'cart-oldconfirm01',gen_random_uuid());raise exception 'stale quote confirmed';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 begin perform public.save_cart(b,'cart-stale-000001',gen_random_uuid());raise exception 'stale tab overwrote';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 begin perform public.submit_cart((c->>'id')::uuid,1,'cart-stalequote01',gen_random_uuid());raise exception 'stale version submitted';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 i2:=public.submit_cart((c->>'id')::uuid,2,'cart-submit-new01',gen_random_uuid());assert i2->>'id'<>i->>'id','new revision new quote';
 o:=public.confirm_purchase((i2->>'id')::uuid,jsonb_build_object('version',1,'quote_hash',i2->>'quote_hash'),'cart-confirm-0001',gen_random_uuid());
 begin perform public.save_cart(b||jsonb_build_object('version',2),'cart-afterorder01',gen_random_uuid());raise exception 'accepted cart edited';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 perform set_config('test.cart',c->>'id',true);
 b:=b||jsonb_build_object('id',null,'version',0,'reference','','lines','[]'::jsonb);
 c2:=public.save_cart(b,'cart-next-order01',gen_random_uuid());assert c2->>'id'<>c->>'id','next purchase is new cart';
 assert jsonb_array_length(c2->'lines')=0,'empty cart saved';
end$$;
reset role;
-- A second person in the same account still cannot edit the first person's cart.
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor)
values('00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','buyer',100000,100000);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000107"}',true);
do $$begin
 assert public.get_current_cart('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004') is null,'person isolation';
 begin perform public.submit_cart(current_setting('test.cart')::uuid,2,'cart-wrongowner01',gen_random_uuid());raise exception 'wrong owner allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
do $$begin
 assert (select count(*) from public.orders where tenant_id='00000000-0000-4000-8000-000000000001')=1,'one order';
 assert (select exposure_minor from public.customer_accounts where id='00000000-0000-4000-8000-000000000002')=25000,'one credit reservation';
end$$;
-- Current mandate is checked before reading or replaying any saved cart.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000105"}',true);
do $$begin
 begin perform public.get_current_cart('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000009','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004');raise exception 'wrong account allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform public.get_current_cart('00000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004');raise exception 'wrong tenant allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
update public.memberships set status='revoked' where user_id='00000000-0000-4000-8000-000000000005';
set local role authenticated;
do $$begin
 begin perform public.get_current_cart('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004');raise exception 'revoked read allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform public.submit_cart(current_setting('test.cart')::uuid,2,'cart-submit-new01',gen_random_uuid());raise exception 'revoked replay allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
select 'PASS: durable cart, owner isolation, version conflict, replay, one quote per revision, invalidated quote, next purchase' as result;
rollback;

