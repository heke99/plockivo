begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
-- Synthetic namespace35000000. Genuine production SQL path, rollback-only fixtures.
insert into auth.users(id,email,email_confirmed_at) values ('54000000-0000-4000-8000-000000000005','receivables-sim054-5@plockivo.invalid',now()),('54000000-0000-4000-8000-000000000006','receivables-sim054-6@plockivo.invalid',now()),('54000000-0000-4000-8000-000000000007','receivables-sim054-7@plockivo.invalid',now()),('54000000-0000-4000-8000-000000000011','receivables-sim054-11@plockivo.invalid',now());
insert into public.merchants(id,slug,name,legal_name,organization_number,mode,sales_paused) values ('54000000-0000-4000-8000-000000000001','receivables-sim054','Production simulation','Production simulation','SIM047-A','test',true),('54000000-0000-4000-8000-000000000008','receivables-foreign054','Foreign simulation','Foreign simulation','SIM047-B','test',true);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,purchase_blocked) values ('54000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000001','Synthetic customer','SIM047-C','suspended',null,0,true),('54000000-0000-4000-8000-000000000009','54000000-0000-4000-8000-000000000008','Foreign customer','SIM047-F','suspended',null,0,true);
insert into public.stores(id,tenant_id,name,code,sales_paused) values('54000000-0000-4000-8000-000000000003','54000000-0000-4000-8000-000000000001','Simulation store','SIM047',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor) values('54000000-0000-4000-8000-000000000004','54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002','Simulation project',1000000);
insert into public.memberships(user_id,tenant_id,role) values('54000000-0000-4000-8000-000000000005','54000000-0000-4000-8000-000000000001','merchant_admin'),('54000000-0000-4000-8000-000000000011','54000000-0000-4000-8000-000000000008','merchant_admin');
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values('54000000-0000-4000-8000-000000000006','54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000003','54000000-0000-4000-8000-000000000004','buyer',1000000,1),('54000000-0000-4000-8000-000000000007','54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000003','54000000-0000-4000-8000-000000000004','approver',1000000,0);
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values ('54000000-0000-4000-8000-000000000020','54000000-0000-4000-8000-000000000005','totp','verified',now(),now()),('54000000-0000-4000-8000-000000000024','54000000-0000-4000-8000-000000000006','totp','verified',now(),now()),('54000000-0000-4000-8000-000000000026','54000000-0000-4000-8000-000000000007','totp','verified',now(),now()),('54000000-0000-4000-8000-000000000028','54000000-0000-4000-8000-000000000011','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values ('54000000-0000-4000-8000-000000000021','54000000-0000-4000-8000-000000000005','54000000-0000-4000-8000-000000000020','aal2',now(),now()),('54000000-0000-4000-8000-000000000025','54000000-0000-4000-8000-000000000006','54000000-0000-4000-8000-000000000024','aal2',now(),now()),('54000000-0000-4000-8000-000000000027','54000000-0000-4000-8000-000000000007','54000000-0000-4000-8000-000000000026','aal2',now(),now()),('54000000-0000-4000-8000-000000000029','54000000-0000-4000-8000-000000000011','54000000-0000-4000-8000-000000000028','aal2',now(),now());
insert into auth.users(id,email,email_confirmed_at) values('54000000-0000-4000-8000-000000000012','receivables-staff054@plockivo.invalid',now());
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('54000000-0000-4000-8000-000000000030','54000000-0000-4000-8000-000000000012','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('54000000-0000-4000-8000-000000000031','54000000-0000-4000-8000-000000000012','54000000-0000-4000-8000-000000000030','aal2',now(),now());
insert into public.memberships(user_id,tenant_id,store_id,role) values('54000000-0000-4000-8000-000000000012','54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000003','store_staff');
set local role authenticated;
do $$
declare
 source jsonb; published jsonb; setup_body jsonb; policy_body jsonb; cart_body jsonb; cart jsonb;
 prepared jsonb; confirm_body jsonb; order_result jsonb; state jsonb; billing jsonb; second_intent jsonb; second_order jsonb; stale_intent jsonb; receipt_state jsonb; first_receipt jsonb; full_receipt jsonb; reused_receipt jsonb; payment_body jsonb; reversal_body jsonb; first_id uuid; full_id uuid; reused_id uuid;
begin
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 policy_body:='{"tenant_id":"54000000-0000-4000-8000-000000000001","customer_account_id":"54000000-0000-4000-8000-000000000002","version":0,"status":"active","purchase_blocked":false,"credit_limit_minor":"1000000","terms_version":"sim047-v1","review_status":"reviewed","reason":"Reviewed synthetic production simulation customer","evidence_reference":"SIM047-POLICY"}';
 perform public.save_customer_policy(policy_body,'sim047-customer-policy-01',gen_random_uuid());
 source:=public.save_standalone_catalog('{"tenant_id":"54000000-0000-4000-8000-000000000001","id":null,"version":0,"sku":"SIM047-001","name":"Imported production simulation item","unit":"st","quantity_step":"1","barcode":"SIM047000001","package_quantity":"1","unit_price_minor":"12345","vat_bps":2500,"active":true,"self_scan":true}','sim047-source-create-01',gen_random_uuid());
 setup_body:='{"tenant_id":"54000000-0000-4000-8000-000000000001","version":0,"price_authority":"plockivo","credit_authority":"merchant-manual","inventory_authority":"plockivo","billing_authority":"manual-export","activate_production":true,"sales_enabled":true,"reason":"Explicit production simulation authority selection","evidence_reference":"SIM047-CONFIG"}';
 perform public.save_production_setup(setup_body,'sim047-setup-activate-01',gen_random_uuid());
 published:=public.publish_production_catalog(jsonb_build_object('tenant_id','54000000-0000-4000-8000-000000000001','item_id',source->>'id','source_version',1,'customer_account_id','54000000-0000-4000-8000-000000000002','version',0),'sim047-production-publish-01',gen_random_uuid());
 perform public.adjust_production_stock(jsonb_build_object('tenant_id','54000000-0000-4000-8000-000000000001','store_id','54000000-0000-4000-8000-000000000003','product_id',published->>'product_id','version',0,'on_hand','10','reason','Counted opening simulation stock','evidence_reference','SIM047-STOCK'),'sim047-opening-stock-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 cart_body:=jsonb_build_object('id',null,'version',0,'tenant_id','54000000-0000-4000-8000-000000000001','customer_account_id','54000000-0000-4000-8000-000000000002','store_id','54000000-0000-4000-8000-000000000003','project_id','54000000-0000-4000-8000-000000000004','reference','SIM047-MAIN','lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','2')));
 cart:=public.save_cart(cart_body,'sim047-cart-create-01',gen_random_uuid());
 if public.save_cart(cart_body,'sim047-cart-create-01',gen_random_uuid()) is distinct from cart then raise exception 'SIM047 cart replay';end if;
 prepared:=public.submit_cart((cart->>'id')::uuid,(cart->>'version')::integer,'sim047-cart-submit-01',gen_random_uuid());
 if prepared->>'mode' is distinct from 'production' or prepared->'quote'->>'price_authority' is distinct from 'plockivo-standalone' or prepared->'quote'->>'total_minor' is distinct from '30863' or prepared->>'status' is distinct from 'awaiting_approval' then raise exception 'SIM047 production quote/approval';end if;
 confirm_body:=jsonb_build_object('version',(prepared->>'version')::integer,'quote_hash',prepared->>'quote_hash');
 begin
  perform public.confirm_purchase((prepared->>'id')::uuid,confirm_body,'sim047-no-approval-denied',gen_random_uuid());raise exception 'SIM047 approval bypass';
 exception when raise_exception then if sqlerrm<>'APPROVAL_REQUIRED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000007','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000027')::text,true);
 perform public.decide_approval((prepared->>'id')::uuid,jsonb_build_object('version',(prepared->>'version')::integer,'decision','approved'),'sim047-approval-main-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 begin
  perform public.confirm_purchase((prepared->>'id')::uuid,confirm_body||'{"version":99}','sim047-stale-confirm-denied',gen_random_uuid());raise exception 'SIM047 stale confirm accepted';
 exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 order_result:=public.confirm_purchase((prepared->>'id')::uuid,confirm_body,'sim047-confirm-main-01',gen_random_uuid());
 if order_result->>'mode' is distinct from 'production' or order_result->>'total_minor' is distinct from '30863' then raise exception 'SIM047 production order';end if;
 if public.confirm_purchase((prepared->>'id')::uuid,confirm_body,'sim047-confirm-main-01',gen_random_uuid()) is distinct from order_result then raise exception 'SIM047 confirm replay';end if;
 state:=public.get_order_confirmation((prepared->>'id')::uuid);
 if state->>'mode' is distinct from 'production' or state->>'status' is distinct from 'ready' or state->'document'->'content'->>'total_minor' is distinct from '30863' then raise exception 'SIM047 buyer receipt';end if;
 state:=public.get_production_order((order_result->>'id')::uuid);
 if state->>'state' is distinct from 'reserved' or (state->>'version')::integer is distinct from 0 then raise exception 'SIM047 owner read';end if;
 begin
  perform public.complete_production_order((order_result->>'id')::uuid,'{"version":0,"recipient_reference":"Buyer may not fulfill","checked":true}','sim047-buyer-fulfill-denied',gen_random_uuid());raise exception 'SIM047 buyer fulfill allowed';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 begin
  perform public.get_production_billing((order_result->>'id')::uuid);raise exception 'SIM047 billing before receipt';
 exception when raise_exception then if sqlerrm<>'FULFILLMENT_REQUIRED' then raise;end if;end;
 begin
  perform public.complete_production_order((order_result->>'id')::uuid,'{"version":0,"recipient_reference":"SIM047-RECIPIENT","checked":false}','sim047-unchecked-denied',gen_random_uuid());raise exception 'SIM047 unchecked receipt';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 state:=public.complete_production_order((order_result->>'id')::uuid,'{"version":0,"recipient_reference":"SIM047-RECIPIENT","checked":true}','sim047-fulfill-main-01',gen_random_uuid());
 if state->>'state' is distinct from 'fulfilled' or (state->>'version')::integer is distinct from 1 or state->>'credit_released_minor' is distinct from '0' then raise exception 'SIM047 fulfillment';end if;
 if public.complete_production_order((order_result->>'id')::uuid,'{"version":0,"recipient_reference":"SIM047-RECIPIENT","checked":true}','sim047-fulfill-main-01',gen_random_uuid()) is distinct from state then raise exception 'SIM047 fulfillment replay';end if;
 begin
  perform public.cancel_production_order((order_result->>'id')::uuid,'{"version":1,"reason":"Cannot cancel already fulfilled order"}','sim047-fulfilled-cancel-denied',gen_random_uuid());raise exception 'SIM047 cancelled fulfilled';
 exception when raise_exception then if sqlerrm<>'FULFILLMENT_STATE_CONFLICT' then raise;end if;end;
 billing:=public.get_production_billing((order_result->>'id')::uuid);
 if billing->>'status' is distinct from 'ready_for_manual_export' or billing->>'total_minor' is distinct from '30863' or billing->'snapshot'->>'total_minor' is distinct from '30863' then raise exception 'SIM047 billing snapshot';end if;
 if public.get_production_billing((order_result->>'id')::uuid) is distinct from billing then raise exception 'SIM047 billing repeat';end if;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 -- Snapshot stock now8; quantity9 must fail without oversell or a reservation.
 begin
  perform public.prepare_purchase((cart_body-'id'-'version')||jsonb_build_object('lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','9'))),'sim047-oversell-denied',gen_random_uuid());raise exception 'SIM047 oversell allowed';
 exception when raise_exception then if sqlerrm<>'STOCK_UNAVAILABLE' then raise;end if;end;
 second_intent:=public.prepare_purchase((cart_body-'id'-'version')||jsonb_build_object('reference','SIM047-CANCEL','lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','1'))),'sim047-prepare-cancel-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000007','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000027')::text,true);
 perform public.decide_approval((second_intent->>'id')::uuid,jsonb_build_object('version',(second_intent->>'version')::integer,'decision','approved'),'sim047-approve-cancel-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 second_order:=public.confirm_purchase((second_intent->>'id')::uuid,jsonb_build_object('version',(second_intent->>'version')::integer,'quote_hash',second_intent->>'quote_hash'),'sim047-confirm-cancel-01',gen_random_uuid());
 if second_order->>'total_minor' is distinct from '15431' then raise exception 'SIM047 cancel amount';end if;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 state:=public.cancel_production_order((second_order->>'id')::uuid,'{"version":0,"reason":"Recipient cancelled before any physical handover"}','sim047-cancel-order-01',gen_random_uuid());
 if state->>'state' is distinct from 'cancelled' or state->>'credit_released_minor' is distinct from '15431' then raise exception 'SIM047 cancellation';end if;
 if public.cancel_production_order((second_order->>'id')::uuid,'{"version":0,"reason":"Recipient cancelled before any physical handover"}','sim047-cancel-order-01',gen_random_uuid()) is distinct from state then raise exception 'SIM047 cancellation replay';end if;
 begin
  perform public.get_production_billing((second_order->>'id')::uuid);raise exception 'SIM047 cancelled billing';
 exception when raise_exception then if sqlerrm<>'FULFILLMENT_REQUIRED' then raise;end if;end;
 perform public.save_customer_policy(policy_body||'{"version":1,"credit_limit_minor":"30863","reason":"Simulation exhausted available credit to verify denial"}','sim047-credit-reduce-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 begin
  perform public.prepare_purchase((cart_body-'id'-'version')||jsonb_build_object('lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','1'))),'sim047-no-credit-denied',gen_random_uuid());raise exception 'SIM047 exhausted credit allowed';
 exception when raise_exception then if sqlerrm<>'CREDIT_UNAVAILABLE' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 perform public.save_customer_policy(policy_body||'{"version":2,"reason":"Restore simulation credit after negative case"}','sim047-credit-restore-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 stale_intent:=public.prepare_purchase((cart_body-'id'-'version')||jsonb_build_object('reference','SIM047-STALE-CONFIG','lines',jsonb_build_array(jsonb_build_object('product_id',published->>'product_id','quantity','1'))),'sim047-prepare-old-config',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000007','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000027')::text,true);
 perform public.decide_approval((stale_intent->>'id')::uuid,jsonb_build_object('version',(stale_intent->>'version')::integer,'decision','approved'),'sim047-approve-old-config',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 perform public.save_production_setup(setup_body||'{"version":1,"activate_production":false,"reason":"Simulation configuration change invalidates prior quote"}','sim047-config-change-01',gen_random_uuid());
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 begin
  perform public.confirm_purchase((stale_intent->>'id')::uuid,jsonb_build_object('version',(stale_intent->>'version')::integer,'quote_hash',stale_intent->>'quote_hash'),'sim047-old-config-denied',gen_random_uuid());raise exception 'SIM047 stale configuration allowed';
 exception when raise_exception then if sqlerrm<>'PRICE_CHANGED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000011','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000029')::text,true);
 begin
  perform public.get_production_order((order_result->>'id')::uuid);raise exception 'SIM047 foreign order read';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.get_production_billing((order_result->>'id')::uuid);raise exception 'SIM047 foreign billing read';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal1','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 begin
  perform public.get_production_billing((order_result->>'id')::uuid);raise exception 'SIM047 AAL1 billing';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin
  perform public.complete_production_order((order_result->>'id')::uuid,'{"version":1,"recipient_reference":"SIM047","checked":true}','sim047-aal1-fulfill-denied',gen_random_uuid());raise exception 'SIM047 AAL1 fulfill';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
 state:=public.list_production_orders('54000000-0000-4000-8000-000000000001');
 if jsonb_array_length(state->'items')<>2 or state->>'has_more'<>'false' or (state->>'limit')::int<>50 then raise exception 'SIM052 staff queue mismatch';end if;
 if not exists(select 1 from jsonb_array_elements(state->'items') x where x->>'state'='fulfilled') or not exists(select 1 from jsonb_array_elements(state->'items') x where x->>'state'='cancelled') then raise exception 'SIM052 queue states';end if;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
 begin perform public.list_production_orders('54000000-0000-4000-8000-000000000001');raise exception 'SIM052 buyer queue allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
receipt_state:=public.get_production_receivables((order_result->>'id')::uuid);if receipt_state->>'balance_minor'<>'30863' or receipt_state->>'paid_minor'<>'0' or receipt_state->>'version'<>'0' then raise exception 'SIM054 initial balance';end if;
payment_body:='{"version":0,"amount_minor":"10000","payment_reference":"BANK-054-A","evidence_reference":"SIM054-CHECKED-A","reason":"Verified local simulation receipt"}';
first_receipt:=public.record_production_payment((order_result->>'id')::uuid,payment_body,'sim054-record-partial-01',gen_random_uuid());
if first_receipt->>'balance_minor'<>'20863' or first_receipt->>'paid_minor'<>'10000' or first_receipt->>'version'<>'1' then raise exception 'SIM054 partial balance';end if;
first_id:=(first_receipt->'receipts'->0->>'id')::uuid;
if public.record_production_payment((order_result->>'id')::uuid,payment_body,'sim054-record-partial-01',gen_random_uuid())<>first_receipt then raise exception 'SIM054 record replay';end if;
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"amount_minor":"9999"}','sim054-record-partial-01',gen_random_uuid());raise exception 'SIM054 changed replay allowed';exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body,'sim054-stale-partial-01',gen_random_uuid());raise exception 'SIM054 stale receipt allowed';exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":1,"amount_minor":"1"}','sim054-duplicate-bank-01',gen_random_uuid());raise exception 'SIM054 duplicate payment reference allowed';exception when raise_exception then if sqlerrm<>'PAYMENT_REFERENCE_CONFLICT' then raise;end if;end;
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":1,"amount_minor":"20864","payment_reference":"BANK-054-TOO-MUCH"}','sim054-overpayment-01',gen_random_uuid());raise exception 'SIM054 overpayment allowed';exception when raise_exception then if sqlerrm<>'PAYMENT_EXCEEDS_BALANCE' then raise;end if;end;
begin perform public.record_production_payment((second_order->>'id')::uuid,payment_body,'sim054-cancelled-order-01',gen_random_uuid());raise exception 'SIM054 cancelled order payment allowed';exception when raise_exception then if sqlerrm<>'FULFILLMENT_REQUIRED' then raise;end if;end;
full_receipt:=public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":1,"amount_minor":"20863","payment_reference":"BANK-054-B"}','sim054-record-full-01',gen_random_uuid());if full_receipt->>'balance_minor'<>'0' or full_receipt->>'paid_minor'<>'30863' then raise exception 'SIM054 full balance';end if;
select (x->>'id')::uuid into full_id from jsonb_array_elements(full_receipt->'receipts')x where x->>'payment_reference'='BANK-054-B';
perform public.save_customer_policy(policy_body||'{"version":3,"credit_limit_minor":"5000","reason":"Lowered limit after fully paid simulation order"}','sim054-lower-paid-limit-01',gen_random_uuid());
reversal_body:=jsonb_build_object('version',2,'receipt_id',first_id,'evidence_reference','SIM054-CORRECTION-A','reason','Correct wrongly allocated simulation receipt');
receipt_state:=public.reverse_production_payment((order_result->>'id')::uuid,reversal_body,'sim054-reverse-first-01',gen_random_uuid());if receipt_state->>'balance_minor'<>'10000' or receipt_state->>'version'<>'3' then raise exception 'SIM054 reversal balance';end if;
state:=public.get_customer_policy('54000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000002');if state->>'exposure_minor'<>'10000' or state->>'credit_limit_minor'<>'5000' then raise exception 'SIM054 reversal must restore truthful overlimit exposure';end if;
perform public.save_customer_policy(policy_body||'{"version":4,"credit_limit_minor":"1000000","reason":"Restored reviewed simulation limit after correction"}','sim054-restore-limit-01',gen_random_uuid());
if public.reverse_production_payment((order_result->>'id')::uuid,reversal_body,'sim054-reverse-first-01',gen_random_uuid())<>receipt_state then raise exception 'SIM054 reversal replay';end if;
begin perform public.reverse_production_payment((order_result->>'id')::uuid,reversal_body||'{"version":3}','sim054-double-reversal-01',gen_random_uuid());raise exception 'SIM054 double reversal allowed';exception when raise_exception then if sqlerrm<>'PAYMENT_ALREADY_REVERSED' then raise;end if;end;
reused_receipt:=public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":3}','sim054-reallocate-corrected-01',gen_random_uuid());if reused_receipt->>'paid_minor'<>'30863' or reused_receipt->>'version'<>'4' then raise exception 'SIM054 reference not reusable after reversal';end if;
select (x->>'id')::uuid into reused_id from jsonb_array_elements(reused_receipt->'receipts')x where x->>'payment_reference'='BANK-054-A' and not (x->>'reversed')::boolean;
perform public.reverse_production_payment((order_result->>'id')::uuid,reversal_body||jsonb_build_object('version',4,'receipt_id',full_id),'sim054-reverse-full-01',gen_random_uuid());
receipt_state:=public.reverse_production_payment((order_result->>'id')::uuid,reversal_body||jsonb_build_object('version',5,'receipt_id',reused_id),'sim054-reverse-reused-01',gen_random_uuid());
if receipt_state->>'paid_minor'<>'0' or receipt_state->>'balance_minor'<>'30863' or receipt_state->>'version'<>'6' or jsonb_array_length(receipt_state->'receipts')<>3 then raise exception 'SIM054 final restored state';end if;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000012','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000031')::text,true);
 begin perform public.get_production_receivables((order_result->>'id')::uuid);raise exception 'SIM054 storestaff ledger allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal1','session_id','54000000-0000-4000-8000-000000000021')::text,true);
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":6}','sim054-aal1-payment-01',gen_random_uuid());raise exception 'SIM054 AAL1 payment allowed';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000006','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000025')::text,true);
begin perform public.get_production_receivables((order_result->>'id')::uuid);raise exception 'SIM054 buyer ledger read allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
begin perform public.record_production_payment((order_result->>'id')::uuid,payment_body||'{"version":6}','sim054-buyer-payment-01',gen_random_uuid());raise exception 'SIM054 buyer payment allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000011','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000029')::text,true);
begin perform public.get_production_receivables((order_result->>'id')::uuid);raise exception 'SIM054 foreign ledger read allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
perform set_config('request.jwt.claims',jsonb_build_object('sub','54000000-0000-4000-8000-000000000005','role','authenticated','aal','aal2','session_id','54000000-0000-4000-8000-000000000021')::text,true);
begin perform id from private.production_payment_receipts;raise exception 'SIM054 direct ledger read allowed';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin
 if (select mode from public.merchants where id='54000000-0000-4000-8000-000000000001') is distinct from 'production' then raise exception 'SIM047 not actual production path';end if;
 if (select count(*) from public.orders where tenant_id='54000000-0000-4000-8000-000000000001' and mode='production')<>2 then raise exception 'SIM047 duplicate/missing production order';end if;
 if exists(select 1 from public.orders where tenant_id='54000000-0000-4000-8000-000000000001' and mode<>'production') then raise exception 'SIM047 synthetic fallback';end if;
 if (select count(*) from public.order_lines where tenant_id='54000000-0000-4000-8000-000000000001')<>2 then raise exception 'SIM047 duplicate order lines';end if;
 if (select count(*) from public.documents where tenant_id='54000000-0000-4000-8000-000000000001' and kind='purchase_confirmation')<>2 then raise exception 'SIM047 confirmation not durable';end if;
 if (select count(*) from private.outbox where tenant_id='54000000-0000-4000-8000-000000000001' and status='manual_review')<>2 or (select count(*) from private.outbox where tenant_id='54000000-0000-4000-8000-000000000001')<>2 then raise exception 'SIM047 notification fake delivery/duplicate';end if;
 if (select exposure_minor from public.customer_accounts where id='54000000-0000-4000-8000-000000000002') is distinct from 30863::bigint or (select committed_minor from public.projects where id='54000000-0000-4000-8000-000000000004') is distinct from 30863::bigint then raise exception 'SIM047 credit/project double effect';end if;
 if (select on_hand from private.production_stock where tenant_id='54000000-0000-4000-8000-000000000001') is distinct from 8::numeric or (select reserved from private.production_stock where tenant_id='54000000-0000-4000-8000-000000000001') is distinct from 0::numeric or (select version from private.production_stock where tenant_id='54000000-0000-4000-8000-000000000001') is distinct from 5 then raise exception 'SIM047 stock double effect';end if;
 if (select count(*) from private.production_fulfillment where tenant_id='54000000-0000-4000-8000-000000000001' and state='fulfilled' and credit_released_minor=0)<>1 or (select count(*) from private.production_fulfillment where tenant_id='54000000-0000-4000-8000-000000000001' and state='cancelled' and credit_released_minor=15431)<>1 then raise exception 'SIM047 release ledger/state';end if;
 if (select sum(amount_minor) from private.credit_reservations where tenant_id='54000000-0000-4000-8000-000000000001') is distinct from 46294::numeric then raise exception 'SIM047 immutable reservation history changed';end if;
 if (select sum(amount_minor) from private.credit_reservations where tenant_id='54000000-0000-4000-8000-000000000001')-(select sum(credit_released_minor) from private.production_fulfillment where tenant_id='54000000-0000-4000-8000-000000000001') is distinct from 30863::numeric then raise exception 'SIM047 net active reservation mismatch';end if;
 if (select count(*) from private.audit_events where tenant_id='54000000-0000-4000-8000-000000000001' and operation='purchases.confirm')<>2 or (select count(*) from private.audit_events where tenant_id='54000000-0000-4000-8000-000000000001' and operation='production.fulfill')<>1 or (select count(*) from private.audit_events where tenant_id='54000000-0000-4000-8000-000000000001' and operation='production.cancel')<>1 then raise exception 'SIM047 audit repeat';end if;
 if exists(select 1 from public.orders where tenant_id='54000000-0000-4000-8000-000000000008') or exists(select 1 from private.production_stock where tenant_id='54000000-0000-4000-8000-000000000008') then raise exception 'SIM047 foreign mutation';end if;
end$$;
do $$begin
 if (select count(*) from private.production_payment_receipts where tenant_id='54000000-0000-4000-8000-000000000001')<>3 or (select count(*) from private.production_payment_reversals where tenant_id='54000000-0000-4000-8000-000000000001')<>3 or exists(select 1 from private.production_payment_active_references where tenant_id='54000000-0000-4000-8000-000000000001') then raise exception 'SIM054 ledger effects duplicated';end if;
 begin update private.production_payment_receipts set amount_minor=1 where tenant_id='54000000-0000-4000-8000-000000000001';raise exception 'SIM054 ledger mutable';exception when raise_exception then if sqlerrm<>'RECEIVABLE_LEDGER_IMMUTABLE' then raise;end if;end;
end$$;
select 'PRODUCTION-RECEIVABLES-SIM-054 explicit activation/policy/catalog/stock/cart/approval/checkout/receipt/fulfillment/billing/cancellation/replay/negative guards PASS (rollback follows)' as result;
rollback;
with tenants(id) as(values('54000000-0000-4000-8000-000000000001'::uuid),('54000000-0000-4000-8000-000000000008'::uuid))
select jsonb_build_object(
 'receivable_versions',(select count(*) from private.production_receivables where tenant_id in(select id from tenants)),
 'payment_receipts',(select count(*) from private.production_payment_receipts where tenant_id in(select id from tenants)),
 'payment_reversals',(select count(*) from private.production_payment_reversals where tenant_id in(select id from tenants)),
 'payment_refs',(select count(*) from private.production_payment_active_references where tenant_id in(select id from tenants)),
 'users',(select count(*) from auth.users where id::text like '54000000-%'),
 'sessions',(select count(*) from auth.sessions where user_id::text like '54000000-%'),
 'factors',(select count(*) from auth.mfa_factors where user_id::text like '54000000-%'),
 'merchants',(select count(*) from public.merchants where id in(select id from tenants)),
 'accounts',(select count(*) from public.customer_accounts where tenant_id in(select id from tenants)),
 'stores',(select count(*) from public.stores where tenant_id in(select id from tenants)),
 'projects',(select count(*) from public.projects where tenant_id in(select id from tenants)),
 'memberships',(select count(*) from public.memberships where tenant_id in(select id from tenants)),
 'policies',(select count(*) from private.customer_policies where tenant_id in(select id from tenants)),
 'setup',(select count(*) from private.production_setups where tenant_id in(select id from tenants)),
 'catalog',(select count(*) from private.standalone_catalog_items where tenant_id in(select id from tenants)),
 'map',(select count(*) from private.production_catalog_map where tenant_id in(select id from tenants)),
 'products',(select count(*) from public.products where tenant_id in(select id from tenants)),
 'prices',(select count(*) from private.production_prices where tenant_id in(select id from tenants)),
 'stock',(select count(*) from private.production_stock where tenant_id in(select id from tenants)),
 'stock_adjustments',(select count(*) from private.production_stock_adjustments where tenant_id in(select id from tenants)),
 'carts',(select count(*) from public.carts where tenant_id in(select id from tenants)),
 'intents',(select count(*) from public.purchase_intents where tenant_id in(select id from tenants)),
 'orders',(select count(*) from public.orders where tenant_id in(select id from tenants)),
 'order_lines',(select count(*) from public.order_lines where tenant_id in(select id from tenants)),
 'documents',(select count(*) from public.documents where tenant_id in(select id from tenants)),
 'reservations',(select count(*) from private.credit_reservations where tenant_id in(select id from tenants)),
 'fulfillment',(select count(*) from private.production_fulfillment where tenant_id in(select id from tenants)),
 'outbox',(select count(*) from private.outbox where tenant_id in(select id from tenants)),
 'audit',(select count(*) from private.audit_events where tenant_id in(select id from tenants)),
 'commands',(select count(*) from private.commands where tenant_id in(select id from tenants))
) as cleanup;
