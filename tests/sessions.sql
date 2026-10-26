begin;
-- Synthetic fixtures, isolated UUID namespace. Never real business data.

insert into auth.users(id,email,email_confirmed_at) values ('00000000-0000-4000-8000-000000000005','e2e-buyer@plockivo.invalid',now()),('00000000-0000-4000-8000-000000000007','e2e-approver@plockivo.invalid',now()),('00000000-0000-4000-8000-000000000011','e2e-other@plockivo.invalid',now());
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


insert into auth.sessions(id,user_id,created_at,updated_at,aal) values
('00000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000005',now(),now(),'aal1'),
('00000000-0000-4000-8000-000000000052','00000000-0000-4000-8000-000000000005',now(),now(),'aal1'),
('00000000-0000-4000-8000-000000000053','00000000-0000-4000-8000-000000000011',now(),now(),'aal1');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000051"}',true);
do $$declare r jsonb;begin
 perform public.get_context();r:=public.revoke_my_sessions();assert (r->>'revoked')::int=2;
 assert not (public.get_security_state()->>'satisfied')::boolean;
 begin perform public.get_context();raise exception 'revoked allowed';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 assert (public.revoke_my_sessions()->>'replayed')::boolean;
end$$;
reset role;
do $$begin assert (select count(*) from private.revoked_sessions where user_id='00000000-0000-4000-8000-000000000005')=2;assert not exists(select 1 from private.revoked_sessions where user_id='00000000-0000-4000-8000-000000000011');end$$;
insert into auth.sessions(id,user_id,created_at,updated_at,aal) values('00000000-0000-4000-8000-000000000054','00000000-0000-4000-8000-000000000005',now(),now(),'aal1');
set local role authenticated;
do $$begin perform public.revoke_my_sessions();end$$;
reset role;
do $$begin assert not exists(select 1 from private.revoked_sessions where session_id='00000000-0000-4000-8000-000000000054');end$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000054"}',true);
do $$begin perform public.get_context();end$$;
reset role;
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000055','00000000-0000-4000-8000-000000000005','totp','verified',now(),now());
set local role authenticated;
do $$begin
 begin perform public.revoke_my_sessions();raise exception 'MFA bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin insert into private.revoked_sessions(session_id,user_id) values(gen_random_uuid(),auth.uid());raise exception 'direct write allowed';exception when insufficient_privilege then null;end;
end$$;
reset role;
select 'SESSIONS-012 own sessions revoked, replay safe, new login allowed, cross-user isolation and MFA PASS' as result;
rollback;
