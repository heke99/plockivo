begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
-- Namespace33000000. Entire synthetic source-to-test-order journey is rolled back.
insert into auth.users(id,email) values('33000000-0000-4000-8000-000000000005','catalog-purchase-sim040@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,mode,sales_paused) values
('33000000-0000-4000-8000-000000000001','catalog-purchase-sim040','Catalog test A','Catalog test A','SIM040-A','test',false),
('33000000-0000-4000-8000-000000000008','catalog-production-sim040','Catalog production guard','Catalog production guard','SIM040-P','production',true),
('33000000-0000-4000-8000-000000000030','catalog-foreign-sim040','Foreign catalog guard','Foreign catalog guard','SIM040-B','test',true);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('33000000-0000-4000-8000-000000000002','33000000-0000-4000-8000-000000000001','Synthetic buyer','SIM040-BUY','active','sim040-v1',100000,false),
('33000000-0000-4000-8000-000000000009','33000000-0000-4000-8000-000000000008','Production guard buyer','SIM040-PBUY','active','sim040-v1',100000,false);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values
('33000000-0000-4000-8000-000000000010','33000000-0000-4000-8000-000000000001','Suspended guard','SIM040-SUSP','suspended','sim040-v1',0,false),
('33000000-0000-4000-8000-000000000011','33000000-0000-4000-8000-000000000001','Blocked guard','SIM040-BLOCK','active','sim040-v1',0,true),
('33000000-0000-4000-8000-000000000012','33000000-0000-4000-8000-000000000001','Missing terms guard','SIM040-TERMS','active',null,0,false);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('33000000-0000-4000-8000-000000000003','33000000-0000-4000-8000-000000000001','Simulation store','SIM040',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('33000000-0000-4000-8000-000000000004','33000000-0000-4000-8000-000000000001','33000000-0000-4000-8000-000000000002','Simulation project',100000);
insert into public.memberships(user_id,tenant_id,role) values
('33000000-0000-4000-8000-000000000005','33000000-0000-4000-8000-000000000001','merchant_admin'),
('33000000-0000-4000-8000-000000000005','33000000-0000-4000-8000-000000000008','merchant_admin');
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('33000000-0000-4000-8000-000000000005','33000000-0000-4000-8000-000000000001','33000000-0000-4000-8000-000000000002','33000000-0000-4000-8000-000000000003','33000000-0000-4000-8000-000000000004','buyer',100000,100000);
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('33000000-0000-4000-8000-000000000020','33000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('33000000-0000-4000-8000-000000000021','33000000-0000-4000-8000-000000000005','33000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"33000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"33000000-0000-4000-8000-000000000021"}',true);
do $$
declare
 source_body jsonb:='{"tenant_id":"33000000-0000-4000-8000-000000000001","id":null,"version":0,"sku":"SIM040-001","name":"Importerad simulationsartikel","unit":"st","quantity_step":"1","barcode":"SIM040000001","package_quantity":"1","unit_price_minor":"12345","vat_bps":2500,"active":true,"self_scan":true}';
 guard_account uuid; source jsonb; production_source jsonb; published jsonb; prepared jsonb; confirmed jsonb; body jsonb; confirmation_body jsonb; edited jsonb;
begin
 source:=public.save_standalone_catalog(source_body,'sim040-source-create-01',gen_random_uuid());
 production_source:=public.save_standalone_catalog(source_body||'{"tenant_id":"33000000-0000-4000-8000-000000000008","sku":"SIM040-PRODUCTION","barcode":"SIM040000008"}','sim040-prod-source-01',gen_random_uuid());
 published:=public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-valid-01',gen_random_uuid());
 if published->>'mode' is distinct from 'test' or published->>'unit_price_minor' is distinct from '12345' or (published->>'vat_bps')::int is distinct from 2500 or published->>'product_id' is null then raise exception 'SIM040 publication DTO failed';end if;
 if public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-valid-01',gen_random_uuid()) is distinct from published then raise exception 'SIM040 publication replay failed';end if;
 -- Invalid customer states are rejected before publication/replay/source effects.
 for guard_account in select unnest(array['33000000-0000-4000-8000-000000000010'::uuid,'33000000-0000-4000-8000-000000000011'::uuid,'33000000-0000-4000-8000-000000000012'::uuid]) loop
  begin
   perform public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,1,guard_account,'sim040-customer-state-'||right(guard_account::text,2),gen_random_uuid());raise exception 'SIM040 invalid customer accepted';
  exception when raise_exception then if sqlerrm<>'CREDIT_UNAVAILABLE' then raise;end if;end;
 end loop;
 -- Catalog lookup must expose the published snapshot using the copied barcode.
 if not exists(select 1 from jsonb_array_elements(public.lookup_products('33000000-0000-4000-8000-000000000001','SIM040000001')) item where item->>'id'=published->>'product_id') then raise exception 'SIM040 published barcode lookup failed';end if;
 body:=jsonb_build_object('tenant_id','33000000-0000-4000-8000-000000000001','customer_account_id','33000000-0000-4000-8000-000000000002','store_id','33000000-0000-4000-8000-000000000003','project_id','33000000-0000-4000-8000-000000000004','reference','SIM040-IMPORTED-TEST','lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','2')));
 prepared:=public.prepare_purchase(body,'sim040-prepare-valid-01',gen_random_uuid());
 if prepared->>'mode' is distinct from 'test' or prepared->>'status' is distinct from 'ready_for_confirmation' or prepared->'quote'->>'total_minor' is distinct from '30863' or prepared->'quote'->'lines'->0->>'net_minor' is distinct from '24690' or prepared->'quote'->'lines'->0->>'vat_minor' is distinct from '6173' then raise exception 'SIM040 exact quote/rounding failed';end if;
 if public.prepare_purchase(body,'sim040-prepare-valid-01',gen_random_uuid()) is distinct from prepared then raise exception 'SIM040 prepare replay failed';end if;
 -- Editing preparation data must not silently change the explicit test snapshot or frozen quote.
 edited:=public.save_standalone_catalog(source_body||jsonb_build_object('id',source->>'id','version',1,'name','Ny förberedelseversion','unit_price_minor','12999'),'sim040-source-edit-01',gen_random_uuid());
 if (edited->>'version')::int is distinct from 2 then raise exception 'SIM040 prep edit failed';end if;
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-stale-01',gen_random_uuid());raise exception 'SIM040 stale source publish accepted';
 exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,2,'33000000-0000-4000-8000-000000000002','sim040-publish-duplicate-01',gen_random_uuid());raise exception 'SIM040 second snapshot accepted';
 exception when raise_exception then if sqlerrm<>'CATALOG_DUPLICATE' then raise;end if;end;
 -- Original command replay remains exact even after source edits.
 if public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-valid-01',gen_random_uuid()) is distinct from published then raise exception 'SIM040 post-edit publish replay failed';end if;
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000008',(production_source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000009','sim040-publish-production',gen_random_uuid());raise exception 'SIM040 production publish accepted';
 exception when raise_exception then if sqlerrm<>'INTEGRATION_NOT_READY' then raise;end if;end;
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000001',(production_source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-other-source',gen_random_uuid());raise exception 'SIM040 foreign source accepted';
 exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000030',(source->>'id')::uuid,1,'33000000-0000-4000-8000-000000000002','sim040-publish-wrong-tenant',gen_random_uuid());raise exception 'SIM040 wrong tenant accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 confirmation_body:=jsonb_build_object('version',(prepared->>'version')::int,'quote_hash',prepared->>'quote_hash');
 confirmed:=public.confirm_purchase((prepared->>'id')::uuid,confirmation_body,'sim040-confirm-valid-01',gen_random_uuid());
 if confirmed->>'mode' is distinct from 'test' or confirmed->>'total_minor' is distinct from '30863' then raise exception 'SIM040 confirmation failed';end if;
 if public.confirm_purchase((prepared->>'id')::uuid,confirmation_body,'sim040-confirm-valid-01',gen_random_uuid()) is distinct from confirmed then raise exception 'SIM040 confirm replay failed';end if;
 if public.confirm_purchase((prepared->>'id')::uuid,confirmation_body,'sim040-confirm-new-key-01',gen_random_uuid())->>'id' is distinct from confirmed->>'id' then raise exception 'SIM040 second order created';end if;
 if public.get_purchase_intent((prepared->>'id')::uuid)->>'status' is distinct from 'completed' then raise exception 'SIM040 status readback failed';end if;
 perform set_config('sim040.source',source->>'id',true);
end$$;
select set_config('request.jwt.claims','{"sub":"33000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"33000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin
  perform public.publish_catalog_test('33000000-0000-4000-8000-000000000001',current_setting('sim040.source')::uuid,2,'33000000-0000-4000-8000-000000000002','sim040-publish-aal1-denied',gen_random_uuid());raise exception 'SIM040 AAL1 accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
reset role;
do $$begin
 if (select count(*) from public.products where tenant_id='33000000-0000-4000-8000-000000000001')<>1 or (select count(*) from public.product_barcodes where tenant_id='33000000-0000-4000-8000-000000000001')<>1 or (select count(*) from private.test_prices where tenant_id='33000000-0000-4000-8000-000000000001')<>1 or (select count(*) from private.catalog_test_publications where tenant_id='33000000-0000-4000-8000-000000000001')<>1 then raise exception 'SIM040 publication duplication';end if;
 if (select unit_price_minor from private.test_prices where tenant_id='33000000-0000-4000-8000-000000000001') is distinct from 12345::bigint then raise exception 'SIM040 source edit changed snapshot';end if;
 if (select count(*) from public.orders where tenant_id='33000000-0000-4000-8000-000000000001')<>1 or (select count(*) from public.order_lines where tenant_id='33000000-0000-4000-8000-000000000001')<>1 then raise exception 'SIM040 order/line duplication';end if;
 if (select snapshot->>'total_minor' from public.orders where tenant_id='33000000-0000-4000-8000-000000000001') is distinct from '30863' or (select total_minor from public.orders where tenant_id='33000000-0000-4000-8000-000000000001') is distinct from 30863::bigint then raise exception 'SIM040 frozen order amount';end if;
 if (select exposure_minor from public.customer_accounts where id='33000000-0000-4000-8000-000000000002') is distinct from 30863::bigint or (select committed_minor from public.projects where id='33000000-0000-4000-8000-000000000004') is distinct from 30863::bigint or (select credit_limit_minor from public.customer_accounts where id='33000000-0000-4000-8000-000000000002') is distinct from 100000::bigint then raise exception 'SIM040 reservation repeated or credit limit changed';end if;
 if (select count(*) from private.credit_reservations where tenant_id='33000000-0000-4000-8000-000000000001')<>1 or (select amount_minor from private.credit_reservations where tenant_id='33000000-0000-4000-8000-000000000001') is distinct from 30863::bigint then raise exception 'SIM040 credit reservation';end if;
 if (select count(*) from private.outbox where tenant_id='33000000-0000-4000-8000-000000000001')<>2 or (select count(*) from private.outbox where tenant_id='33000000-0000-4000-8000-000000000001' and status='queued')<>2 then raise exception 'SIM040 outbox duplicated';end if;
 if (select count(*) from private.audit_events where tenant_id='33000000-0000-4000-8000-000000000001' and operation='catalog.test.publish')<>1 or (select count(*) from private.audit_events where tenant_id='33000000-0000-4000-8000-000000000001' and operation='purchases.prepare')<>1 or (select count(*) from private.audit_events where tenant_id='33000000-0000-4000-8000-000000000001' and operation='purchases.confirm')<>1 then raise exception 'SIM040 audit duplicated';end if;
 if exists(select 1 from public.products where tenant_id in ('33000000-0000-4000-8000-000000000008','33000000-0000-4000-8000-000000000030')) or exists(select 1 from public.orders where tenant_id in ('33000000-0000-4000-8000-000000000008','33000000-0000-4000-8000-000000000030')) or exists(select 1 from private.test_prices where tenant_id in ('33000000-0000-4000-8000-000000000008','33000000-0000-4000-8000-000000000030')) then raise exception 'SIM040 production/foreign effects';end if;
 if exists(select 1 from public.customer_accounts where id in ('33000000-0000-4000-8000-000000000010','33000000-0000-4000-8000-000000000011','33000000-0000-4000-8000-000000000012') and (credit_limit_minor<>0 or exposure_minor<>0)) then raise exception 'SIM040 invalid account credit changed';end if;
 if (select exposure_minor from public.customer_accounts where id='33000000-0000-4000-8000-000000000009') is distinct from 0::bigint then raise exception 'SIM040 production credit effects';end if;
end$$;
select 'CATALOG-TEST-PURCHASE-040 source/publish/prepare/confirm/exact rounding/replay/snapshot/tenant/MFA/production guard PASS (rollback follows)' as result;
rollback;
-- Expected all-zero result. Rerun this SELECT alone after unknown outcome before retrying.
with tenants(id) as (values('33000000-0000-4000-8000-000000000001'::uuid),('33000000-0000-4000-8000-000000000008'::uuid),('33000000-0000-4000-8000-000000000030'::uuid))
select jsonb_build_object(
 'users',(select count(*) from auth.users where id='33000000-0000-4000-8000-000000000005'),
 'sessions',(select count(*) from auth.sessions where user_id='33000000-0000-4000-8000-000000000005'),
 'factors',(select count(*) from auth.mfa_factors where user_id='33000000-0000-4000-8000-000000000005'),
 'merchants',(select count(*) from public.merchants where id in(select id from tenants)),
 'accounts',(select count(*) from public.customer_accounts where tenant_id in(select id from tenants)),
 'stores',(select count(*) from public.stores where tenant_id in(select id from tenants)),
 'projects',(select count(*) from public.projects where tenant_id in(select id from tenants)),
 'memberships',(select count(*) from public.memberships where tenant_id in(select id from tenants)),
 'catalog_items',(select count(*) from private.standalone_catalog_items where tenant_id in(select id from tenants)),
 'publications',(select count(*) from private.catalog_test_publications where tenant_id in(select id from tenants)),
 'products',(select count(*) from public.products where tenant_id in(select id from tenants)),
 'barcodes',(select count(*) from public.product_barcodes where tenant_id in(select id from tenants)),
 'test_prices',(select count(*) from private.test_prices where tenant_id in(select id from tenants)),
 'intents',(select count(*) from public.purchase_intents where tenant_id in(select id from tenants)),
 'orders',(select count(*) from public.orders where tenant_id in(select id from tenants)),
 'order_lines',(select count(*) from public.order_lines where tenant_id in(select id from tenants)),
 'reservations',(select count(*) from private.credit_reservations where tenant_id in(select id from tenants)),
 'outbox',(select count(*) from private.outbox where tenant_id in(select id from tenants)),
 'audit',(select count(*) from private.audit_events where tenant_id in(select id from tenants)),
 'commands',(select count(*) from private.commands where tenant_id in(select id from tenants))
) as cleanup;
