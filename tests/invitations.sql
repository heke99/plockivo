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


update auth.users set email_confirmed_at=now() where id in ('00000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000011');
insert into public.memberships(id,user_id,tenant_id,customer_account_id,role,valid_to) values('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','customer_admin',now()+interval '30 days');
insert into private.member_delegations values('00000000-0000-4000-8000-000000000030','buyer',50000,20000,now()+interval '30 days');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000007','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('00000000-0000-4000-8000-000000000032','00000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000031','aal2',now(),now()),('00000000-0000-4000-8000-000000000033','00000000-0000-4000-8000-000000000005',null,'aal1',now(),now()),('00000000-0000-4000-8000-000000000034','00000000-0000-4000-8000-000000000011',null,'aal1',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000032"}',true);
do $$begin
 begin perform public.invitation_options('00000000-0000-4000-8000-000000000030');raise exception 'MFA bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated","aal":"aal2","session_id":"00000000-0000-4000-8000-000000000032"}',true);
do $$declare body jsonb;res jsonb;begin
 assert jsonb_array_length(public.invitation_options('00000000-0000-4000-8000-000000000030')->'delegations')=1,'explicit delegation';
 body:=jsonb_build_object('membership_id','00000000-0000-4000-8000-000000000030','recipient_email','e2e-buyer@plockivo.invalid','role','buyer','store_id','00000000-0000-4000-8000-000000000003','project_id','00000000-0000-4000-8000-000000000004','per_purchase_minor','40000','approval_threshold_minor','10000','valid_to',now()+interval '7 days');
 res:=public.create_invitation(body,repeat('a',64),'invitations-test-0001',gen_random_uuid());
 perform set_config('test.invite',res->>'id',true);
 assert not(res->>'replayed')::boolean,'first create';
 assert (public.create_invitation(body,repeat('b',64),'invitations-test-0001',gen_random_uuid())->>'replayed')::boolean,'replay';
 begin perform public.create_invitation(body||'{"role":"merchant_admin"}',repeat('b',64),'invitations-test-0002',gen_random_uuid());raise exception 'role escalation';exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin perform public.create_invitation(body||'{"per_purchase_minor":"50001"}',repeat('b',64),'invitations-test-0002',gen_random_uuid());raise exception 'limit escalation';exception when raise_exception then if sqlerrm<>'INVITATION_UNAVAILABLE' then raise;end if;end;
 begin perform public.create_invitation(body||'{"recipient_email":"e2e-approver@plockivo.invalid"}',repeat('b',64),'invitations-test-0002',gen_random_uuid());raise exception 'self invite';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin perform public.create_invitation(body||'{"store_id":"00000000-0000-4000-8000-000000000008"}',repeat('b',64),'invitations-test-0002',gen_random_uuid());raise exception 'cross tenant';exception when raise_exception then if sqlerrm<>'INVITATION_UNAVAILABLE' then raise;end if;end;
 perform public.create_invitation(body,repeat('b',64),'invitations-test-0002',gen_random_uuid());
end$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000011","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000034"}',true);
do $$begin
 begin perform public.preview_invitation(repeat('a',64));raise exception 'wrong recipient';exception when raise_exception then if sqlerrm<>'INVITATION_INVALID' then raise;end if;end;
 begin perform public.revoke_invitation(current_setting('test.invite')::uuid,gen_random_uuid());raise exception 'revoke bypass';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin perform * from private.invitations;raise exception 'table access';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"00000000-0000-4000-8000-000000000033"}',true);
do $$declare before_count int;mid text;begin
 select count(*) into before_count from public.memberships;
 assert public.preview_invitation(repeat('a',64))->>'status'='pending','preview';
 assert (select count(*) from public.memberships)=before_count,'preview cannot grant';
 mid:=public.accept_invitation(repeat('a',64),gen_random_uuid())->>'membership_id';
 assert mid is not null,'membership created';
 assert public.accept_invitation(repeat('a',64),gen_random_uuid())->>'membership_id'=mid,'stable replay';
 assert (select count(*) from public.memberships)=before_count+1,'one membership';
end$$;
reset role;
do $$begin
 assert (select count(*) from private.audit_events where operation='members.accept')=1,'one accept event';
 assert not exists(select 1 from private.invitations where token_hash=repeat('a',64)),'raw token not stored';
end$$;
update private.invitations set status='revoked' where token_hash=encode(extensions.digest(repeat('b',64),'sha256'),'hex');
set local role authenticated;
do $$begin
 begin perform public.accept_invitation(repeat('b',64),gen_random_uuid());raise exception 'revoked accepted';exception when raise_exception then if sqlerrm<>'INVITATION_UNAVAILABLE' then raise;end if;end;
end$$;
reset role;
update private.invitations set status='pending',expires_at=now()-interval '1 second' where token_hash=encode(extensions.digest(repeat('b',64),'sha256'),'hex');
set local role authenticated;
do $$begin
 begin perform public.accept_invitation(repeat('b',64),gen_random_uuid());raise exception 'expired accepted';exception when raise_exception then if sqlerrm<>'INVITATION_UNAVAILABLE' then raise;end if;end;
end$$;
reset role;
update private.invitations set expires_at=now()+interval '1 hour' where token_hash=encode(extensions.digest(repeat('b',64),'sha256'),'hex');
update public.memberships set status='revoked' where id='00000000-0000-4000-8000-000000000030';
set local role authenticated;
do $$begin
 begin perform public.accept_invitation(repeat('b',64),gen_random_uuid());raise exception 'issuer revoked accepted';exception when raise_exception then if sqlerrm<>'INVITATION_UNAVAILABLE' then raise;end if;end;
end$$;
reset role;
select 'INVITES-006 role matrix PASS; transaction rolled back' as result;
rollback;
