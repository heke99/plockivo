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
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","user_metadata":{"role":"merchant_admin","aal":"aal2"}}',true);
do $$begin
 assert (public.get_security_state()->>'satisfied')::boolean,'optional buyer';
 assert not (public.get_security_state()->>'required')::boolean,'metadata cannot set policy';
 perform public.get_context();
end$$;
reset role;
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000005','totp','unverified',now(),now());
set local role authenticated;
do $$begin assert (public.get_security_state()->>'satisfied')::boolean,'pending factor does not lock out';end$$;
reset role;
update auth.mfa_factors set status='verified' where id='00000000-0000-4000-8000-000000000020';
set local role authenticated;
do $$begin
 assert not (public.get_security_state()->>'satisfied')::boolean,'enrolled aal1 blocked';
 begin perform public.get_context();raise exception 'context bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin perform public.lookup_products('00000000-0000-4000-8000-000000000001','');raise exception 'catalog bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin perform public.consume_api_quota();raise exception 'api bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin perform public.get_current_cart('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004');raise exception 'cart bypass';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 assert (select count(*) from public.memberships)=0,'membership RLS';
 assert (select count(*) from public.merchants)=0,'merchant RLS';
 assert jsonb_array_length(public.list_purchase_intents())=0,'history RLS';
 begin perform * from auth.mfa_factors;raise exception 'factor read allowed';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000021"}',true);
do $$begin assert not (public.get_security_state()->>'satisfied')::boolean,'aal2 without live session rejected';end$$;
reset role;
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000020','aal2',now(),now());
set local role authenticated;
do $$begin
 assert (public.get_security_state()->>'satisfied')::boolean,'live verified session';
 perform public.get_context();
 assert jsonb_array_length(public.lookup_products('00000000-0000-4000-8000-000000000001',''))=1,'verified access';
 assert (select count(*) from public.memberships)=1,'verified RLS';
 begin perform public.lookup_products('00000000-0000-4000-8000-000000000008','');raise exception 'cross tenant';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
update auth.sessions set user_id='00000000-0000-4000-8000-000000000007' where id='00000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$begin assert not (public.get_security_state()->>'satisfied')::boolean,'another persons session';end$$;
reset role;
update auth.sessions set user_id='00000000-0000-4000-8000-000000000005',aal='aal1' where id='00000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$begin assert not (public.get_security_state()->>'satisfied')::boolean,'JWT aal2 with downgraded session';end$$;
reset role;
update auth.sessions set aal='aal2' where id='00000000-0000-4000-8000-000000000021';
update auth.sessions set not_after=now()-interval '1 minute' where id='00000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$begin assert not (public.get_security_state()->>'satisfied')::boolean,'expired session';end$$;
reset role;
update auth.sessions set not_after=null where id='00000000-0000-4000-8000-000000000021';
update public.memberships set status='revoked' where user_id='00000000-0000-4000-8000-000000000005';
set local role authenticated;
do $$begin assert jsonb_array_length(public.get_context()->'memberships')=0,'MFA cannot restore revoked membership';end$$;
reset role;
update public.memberships set status='active',role='merchant_admin' where user_id='00000000-0000-4000-8000-000000000005';
update auth.mfa_factors set status='unverified' where id='00000000-0000-4000-8000-000000000020';
set local role authenticated;
do $$begin
 assert (public.get_security_state()->>'required')::boolean,'admin mandatory';
 assert not (public.get_security_state()->>'satisfied')::boolean,'removed factor invalidates privileged access';
end$$;
reset role;
delete from auth.sessions where id='00000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$begin assert not (public.get_security_state()->>'satisfied')::boolean,'revoked session';end$$;
reset role;
set local role anon;
do $$begin
 begin perform public.get_security_state();raise exception 'anon access';exception when insufficient_privilege then null;end;
end$$;
select 'PASS: MFA policy, direct RPC/RLS, live session, revoked membership/factor/session and optional enrollment' as result;
rollback;
