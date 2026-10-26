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

update auth.users set email_confirmed_at=now() where id='00000000-0000-4000-8000-000000000005';
insert into public.memberships(id,user_id,tenant_id,role) values('51000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('51000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('51000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000005','51000000-0000-4000-8000-000000000011','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"51000000-0000-4000-8000-000000000021"}',true);
do $$declare b jsonb:=jsonb_build_object('tenant_id','00000000-0000-4000-8000-000000000001','customer_account_id','00000000-0000-4000-8000-000000000002','per_purchase_minor','50000','approval_threshold_minor','10000','valid_to',now()+interval '10 days','reason','Syntetiskt inbjudningsmandat');r jsonb;o jsonb;begin
 r:=public.setup_customer_invitation_access(b,'invitation-setup-051-key1',gen_random_uuid());
 assert public.setup_customer_invitation_access(b,'invitation-setup-051-key1',gen_random_uuid())=r;
 assert public.setup_customer_invitation_access(b,'invitation-setup-051-key2',gen_random_uuid())=r;
 o:=public.invitation_options((r->>'membership_id')::uuid);assert jsonb_array_length(o->'delegations')=2;
 begin perform public.setup_customer_invitation_access(b||'{"customer_account_id":"00000000-0000-4000-8000-000000000010"}','invitation-setup-051-cross',gen_random_uuid());raise exception 'cross account allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform public.setup_customer_invitation_access(b||'{"per_purchase_minor":"60000"}','invitation-setup-051-key1',gen_random_uuid());raise exception 'changed replay allowed';exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 perform public.create_invitation(jsonb_build_object('membership_id',r->>'membership_id','recipient_email','new-person@plockivo.invalid','role','buyer','store_id',null,'project_id',null,'per_purchase_minor','40000','approval_threshold_minor','10000','valid_to',now()+interval '9 days'),repeat('a',64),'invitation-setup-051-invite',gen_random_uuid());
end$$;
reset role;
do $$declare m public.memberships;begin
 select * into m from public.memberships where role='customer_admin' and user_id='00000000-0000-4000-8000-000000000005';
 assert m.customer_account_id='00000000-0000-4000-8000-000000000002';assert m.per_purchase_minor=0;assert m.store_id is null and m.project_id is null;
 assert (select count(*) from private.customer_invitation_setups where actor_id=m.user_id)=1;
 assert (select count(*) from private.audit_events where operation='members.invitation_access.setup' and actor_id=m.user_id)=1;
 assert (select credit_limit_minor from public.customer_accounts where id=m.customer_account_id)=100000;
end$$;
update public.memberships set status='revoked' where id='51000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$declare mid uuid;begin
 select id into mid from public.memberships where role='customer_admin' and user_id=auth.uid();
 begin perform public.invitation_options(mid);raise exception 'revoked source allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
select 'TASK051 account-scoped invitation setup, replay, source revocation and no credit mutation PASS' as result;
rollback;
