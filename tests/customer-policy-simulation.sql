begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
-- Rollback-only synthetic fixture namespace34000000. No real auth accounts or purchases.
insert into auth.users(id,email) values
('34000000-0000-4000-8000-000000000005','customer-policy-admin043@plockivo.invalid'),
('34000000-0000-4000-8000-000000000006','customer-policy-buyer043@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,mode,sales_paused) values
('34000000-0000-4000-8000-000000000001','customer-policy-prod043','Production policy guard','Production policy guard','SIM043-P','production',false),
('34000000-0000-4000-8000-000000000008','customer-policy-test043','Test policy guard','Test policy guard','SIM043-T','test',false),
('34000000-0000-4000-8000-000000000030','customer-policy-foreign043','Foreign policy guard','Foreign policy guard','SIM043-F','test',true);
insert into public.customer_accounts(id,tenant_id,name,organization_number,status,terms_version,credit_limit_minor,exposure_minor,purchase_blocked) values
('34000000-0000-4000-8000-000000000002','34000000-0000-4000-8000-000000000001','Production policy customer','SIM043-PC','suspended',null,0,20000,true),
('34000000-0000-4000-8000-000000000009','34000000-0000-4000-8000-000000000008','Test policy customer','SIM043-TC','active','sim043-old',100000,30000,false),
('34000000-0000-4000-8000-000000000031','34000000-0000-4000-8000-000000000030','Foreign untouched customer','SIM043-FC','suspended',null,0,0,true);
insert into public.stores(id,tenant_id,name,code,sales_paused) values
('34000000-0000-4000-8000-000000000003','34000000-0000-4000-8000-000000000001','Production guard store','SIM043-P',false),
('34000000-0000-4000-8000-000000000010','34000000-0000-4000-8000-000000000008','Test guard store','SIM043-T',false);
insert into public.projects(id,tenant_id,customer_account_id,name,budget_minor,committed_minor) values
('34000000-0000-4000-8000-000000000004','34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002','Production guard project',100000,0),
('34000000-0000-4000-8000-000000000011','34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000009','Test guard project',100000,30000);
insert into public.memberships(user_id,tenant_id,role) values
('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000001','merchant_admin'),
('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000008','merchant_admin');
insert into public.memberships(user_id,tenant_id,customer_account_id,store_id,project_id,role,per_purchase_minor,approval_threshold_minor) values
('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002','34000000-0000-4000-8000-000000000003','34000000-0000-4000-8000-000000000004','buyer',100000,100000),
('34000000-0000-4000-8000-000000000006','34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000009','34000000-0000-4000-8000-000000000010','34000000-0000-4000-8000-000000000011','buyer',100000,100000);
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
('34000000-0000-4000-8000-000000000020','34000000-0000-4000-8000-000000000005','totp','verified',now(),now()),
('34000000-0000-4000-8000-000000000024','34000000-0000-4000-8000-000000000006','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values
('34000000-0000-4000-8000-000000000021','34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000020','aal2',now(),now()),
('34000000-0000-4000-8000-000000000025','34000000-0000-4000-8000-000000000006','34000000-0000-4000-8000-000000000024','aal2',now(),now());
-- Existing synthetic order/reservation fixture on TEST tenant only; policy must preserve it.
insert into public.purchase_intents(id,tenant_id,customer_account_id,store_id,project_id,actor_id,status,request,quote,quote_hash,total_minor,expires_at) values
('34000000-0000-4000-8000-000000000013','34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000009','34000000-0000-4000-8000-000000000010','34000000-0000-4000-8000-000000000011','34000000-0000-4000-8000-000000000006','completed','{}','{"total_minor":"30000"}','sim043-fixture',30000,now()+interval '1 hour');
insert into public.orders(id,tenant_id,purchase_intent_id,customer_account_id,actor_id,store_id,snapshot,total_minor,mode) values
('34000000-0000-4000-8000-000000000014','34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000013','34000000-0000-4000-8000-000000000009','34000000-0000-4000-8000-000000000006','34000000-0000-4000-8000-000000000010','{"total_minor":"30000"}',30000,'test');
insert into private.credit_reservations(id,tenant_id,order_id,amount_minor) values('34000000-0000-4000-8000-000000000015','34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000014',30000);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"34000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"34000000-0000-4000-8000-000000000021"}',true);
do $$
declare
 body jsonb:='{"tenant_id":"34000000-0000-4000-8000-000000000001","customer_account_id":"34000000-0000-4000-8000-000000000002","version":0,"status":"active","purchase_blocked":false,"credit_limit_minor":"100000","terms_version":"sim043-v1","review_status":"reviewed","reason":"Manuell granskning i syntetisk simulation","evidence_reference":"SIM043-MANUAL-REVIEW"}';
 initial jsonb; activated jsonb; reduced jsonb; suspended jsonb; test_policy jsonb;
begin
 initial:=public.get_customer_policy('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002');
 if (initial->>'policy_version')::int is distinct from 0 or initial->>'review_status' is distinct from 'pending' or initial->>'status' is distinct from 'suspended' or initial->>'purchase_blocked' is distinct from 'true' or initial->>'credit_limit_minor' is distinct from '0' or initial->>'exposure_minor' is distinct from '20000' then raise exception 'SIM043 baseline failed';end if;
 begin
  perform public.save_customer_policy(body||'{"review_status":"pending"}','sim043-pending-active-01',gen_random_uuid());raise exception 'SIM043 unreviewed activation accepted';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin
  perform public.save_customer_policy(body||'{"status":"suspended","purchase_blocked":true,"terms_version":null,"credit_limit_minor":"1000","review_status":"pending"}','sim043-pending-credit-01',gen_random_uuid());raise exception 'SIM043 unreviewed positive credit accepted';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 activated:=public.save_customer_policy(body,'sim043-activate-policy-01',gen_random_uuid());
 if (activated->>'policy_version')::int is distinct from 1 or activated->>'status' is distinct from 'active' or activated->>'purchase_blocked' is distinct from 'false' or activated->>'credit_limit_minor' is distinct from '100000' or activated->>'terms_version' is distinct from 'sim043-v1' or activated->>'review_status' is distinct from 'reviewed' or activated->>'decision_authority' is distinct from 'merchant-manual' or activated->>'exposure_minor' is distinct from '20000' then raise exception 'SIM043 reviewed activation failed';end if;
 if public.get_customer_policy('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002') is distinct from activated then raise exception 'SIM043 activation GET differs';end if;
 if public.save_customer_policy(body,'sim043-activate-policy-01',gen_random_uuid()) is distinct from activated then raise exception 'SIM043 replay differs';end if;
 begin
  perform public.save_customer_policy(body||'{"reason":"Annan granskning med samma nyckel"}','sim043-activate-policy-01',gen_random_uuid());raise exception 'SIM043 changed replay accepted';
 exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 begin
  perform public.save_customer_policy(body,'sim043-stale-policy-01',gen_random_uuid());raise exception 'SIM043 stale policy accepted';
 exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 -- Production administration is allowed, but existing production checkout still fails closed.
 begin
  perform public.prepare_purchase('{"tenant_id":"34000000-0000-4000-8000-000000000001","customer_account_id":"34000000-0000-4000-8000-000000000002","store_id":"34000000-0000-4000-8000-000000000003","project_id":"34000000-0000-4000-8000-000000000004","reference":"SIM043-PRODUCTION-GUARD","lines":[{"product_id":"34000000-0000-4000-8000-000000000099","quantity":"1"}]}','sim043-production-prepare',gen_random_uuid());raise exception 'SIM043 production checkout opened';
 exception when raise_exception then if sqlerrm<>'INTEGRATION_NOT_READY' then raise;end if;end;
 reduced:=public.save_customer_policy(body||'{"version":1,"credit_limit_minor":"10000","reason":"Syntetisk sänkning under befintlig exponering"}','sim043-reduce-policy-01',gen_random_uuid());
 if (reduced->>'policy_version')::int is distinct from 2 or reduced->>'credit_limit_minor' is distinct from '10000' or reduced->>'exposure_minor' is distinct from '20000' then raise exception 'SIM043 reduction changed exposure';end if;
 suspended:=public.save_customer_policy(body||'{"version":2,"status":"suspended","purchase_blocked":true,"credit_limit_minor":"10000","reason":"Syntetisk spärr utan återföring av exponering"}','sim043-suspend-policy-01',gen_random_uuid());
 if (suspended->>'policy_version')::int is distinct from 3 or suspended->>'status' is distinct from 'suspended' or suspended->>'purchase_blocked' is distinct from 'true' or suspended->>'exposure_minor' is distinct from '20000' then raise exception 'SIM043 suspension changed exposure';end if;
 test_policy:=public.save_customer_policy(body||'{"tenant_id":"34000000-0000-4000-8000-000000000008","customer_account_id":"34000000-0000-4000-8000-000000000009","version":0,"status":"suspended","purchase_blocked":true,"credit_limit_minor":"10000","terms_version":"sim043-old","reason":"Syntetisk spärr med befintlig reservation"}','sim043-test-suspend-01',gen_random_uuid());
 if (test_policy->>'policy_version')::int is distinct from 1 or test_policy->>'exposure_minor' is distinct from '30000' then raise exception 'SIM043 test reservation exposure changed';end if;
 begin
  perform public.get_customer_policy('34000000-0000-4000-8000-000000000030','34000000-0000-4000-8000-000000000031');raise exception 'SIM043 foreign GET accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.save_customer_policy(body||'{"tenant_id":"34000000-0000-4000-8000-000000000030","customer_account_id":"34000000-0000-4000-8000-000000000031"}','sim043-foreign-save-01',gen_random_uuid());raise exception 'SIM043 foreign save accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.get_customer_policy('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000009');raise exception 'SIM043 mismatched account accepted';
 exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise;end if;end;
end$$;
-- A real AAL2 buyer session must not inherit policy administrator authority.
select set_config('request.jwt.claims','{"sub":"34000000-0000-4000-8000-000000000006","role":"authenticated","aal":"aal2","session_id":"34000000-0000-4000-8000-000000000025"}',true);
do $$begin
 begin
  perform public.get_customer_policy('34000000-0000-4000-8000-000000000008','34000000-0000-4000-8000-000000000009');raise exception 'SIM043 buyer read accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.save_customer_policy('{"tenant_id":"34000000-0000-4000-8000-000000000008","customer_account_id":"34000000-0000-4000-8000-000000000009"}','sim043-buyer-write-denied',gen_random_uuid());raise exception 'SIM043 buyer write accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
select set_config('request.jwt.claims','{"sub":"34000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"34000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin
  perform public.get_customer_policy('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000002');raise exception 'SIM043 AAL1 read accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin
  perform public.save_customer_policy('{"tenant_id":"34000000-0000-4000-8000-000000000001","customer_account_id":"34000000-0000-4000-8000-000000000002"}','sim043-aal1-write-denied',gen_random_uuid());raise exception 'SIM043 AAL1 write accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
reset role;
do $$begin
 if (select count(*) from private.customer_policies where tenant_id in ('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000008'))<>2 then raise exception 'SIM043 sidecar count';end if;
 if (select count(*) from private.audit_events where tenant_id='34000000-0000-4000-8000-000000000001' and operation='customer.policy.save')<>3 or (select count(*) from private.audit_events where tenant_id='34000000-0000-4000-8000-000000000008' and operation='customer.policy.save')<>1 then raise exception 'SIM043 audit duplicated';end if;
 if (select count(*) from private.commands where tenant_id='34000000-0000-4000-8000-000000000001' and operation='customer.policy.save')<>3 or (select count(*) from private.commands where tenant_id='34000000-0000-4000-8000-000000000008' and operation='customer.policy.save')<>1 then raise exception 'SIM043 commands duplicated';end if;
 if (select exposure_minor from public.customer_accounts where id='34000000-0000-4000-8000-000000000002') is distinct from 20000::bigint or (select exposure_minor from public.customer_accounts where id='34000000-0000-4000-8000-000000000009') is distinct from 30000::bigint then raise exception 'SIM043 stored exposures changed';end if;
 if (select amount_minor from private.credit_reservations where id='34000000-0000-4000-8000-000000000015') is distinct from 30000::bigint or (select count(*) from private.credit_reservations where tenant_id='34000000-0000-4000-8000-000000000008')<>1 or (select committed_minor from public.projects where id='34000000-0000-4000-8000-000000000011') is distinct from 30000::bigint then raise exception 'SIM043 reservation/project changed';end if;
 if exists(select 1 from public.orders where tenant_id='34000000-0000-4000-8000-000000000001') or exists(select 1 from public.purchase_intents where tenant_id='34000000-0000-4000-8000-000000000001') or exists(select 1 from private.outbox where tenant_id in ('34000000-0000-4000-8000-000000000001','34000000-0000-4000-8000-000000000008')) then raise exception 'SIM043 policy created purchase side effects';end if;
 if (select count(*) from public.orders where tenant_id='34000000-0000-4000-8000-000000000008')<>1 then raise exception 'SIM043 existing test order changed';end if;
 if exists(select 1 from private.customer_policies where tenant_id='34000000-0000-4000-8000-000000000030') or exists(select 1 from private.audit_events where tenant_id='34000000-0000-4000-8000-000000000030') or exists(select 1 from private.commands where tenant_id='34000000-0000-4000-8000-000000000030') then raise exception 'SIM043 foreign effects';end if;
 if not exists(select 1 from public.customer_accounts where id='34000000-0000-4000-8000-000000000031' and status='suspended' and terms_version is null and credit_limit_minor=0 and exposure_minor=0 and purchase_blocked) then raise exception 'SIM043 foreign account changed';end if;
end$$;
select 'CUSTOMER-POLICY-SIM-043 production policy/review/credit/replay/version/tenant/role/MFA/preserved reservations/production checkout guard PASS (rollback follows)' as result;
rollback;
with tenants(id) as (values('34000000-0000-4000-8000-000000000001'::uuid),('34000000-0000-4000-8000-000000000008'::uuid),('34000000-0000-4000-8000-000000000030'::uuid))
select jsonb_build_object(
 'users',(select count(*) from auth.users where id in ('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000006')),
 'sessions',(select count(*) from auth.sessions where user_id in ('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000006')),
 'factors',(select count(*) from auth.mfa_factors where user_id in ('34000000-0000-4000-8000-000000000005','34000000-0000-4000-8000-000000000006')),
 'merchants',(select count(*) from public.merchants where id in(select id from tenants)),
 'accounts',(select count(*) from public.customer_accounts where tenant_id in(select id from tenants)),
 'stores',(select count(*) from public.stores where tenant_id in(select id from tenants)),
 'projects',(select count(*) from public.projects where tenant_id in(select id from tenants)),
 'memberships',(select count(*) from public.memberships where tenant_id in(select id from tenants)),
 'policies',(select count(*) from private.customer_policies where tenant_id in(select id from tenants)),
 'intents',(select count(*) from public.purchase_intents where tenant_id in(select id from tenants)),
 'orders',(select count(*) from public.orders where tenant_id in(select id from tenants)),
 'reservations',(select count(*) from private.credit_reservations where tenant_id in(select id from tenants)),
 'outbox',(select count(*) from private.outbox where tenant_id in(select id from tenants)),
 'audit',(select count(*) from private.audit_events where tenant_id in(select id from tenants)),
 'commands',(select count(*) from private.commands where tenant_id in(select id from tenants))
) as cleanup;
