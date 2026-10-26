begin;
insert into auth.users(id,email,email_confirmed_at) values('49000000-0000-4000-8000-000000000001','e2e-bootstrap-049@plockivo.invalid',now());
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values('49000000-0000-4000-8000-000000000011','49000000-0000-4000-8000-000000000001','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values('49000000-0000-4000-8000-000000000021','49000000-0000-4000-8000-000000000001','49000000-0000-4000-8000-000000000011','aal2',now(),now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"49000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2","session_id":"49000000-0000-4000-8000-000000000021"}',true);
do $$declare b jsonb:='{"slug":"e2e-bootstrap-049","name":"Bootstrap test","legal_name":"Bootstrap Test AB","organization_number":"5568554884","reason":"Syntetisk onboarding"}';r jsonb;begin
 r:=public.bootstrap_merchant(b,'bootstrap-task049-key-0001',gen_random_uuid());
 assert r->>'mode'='production';assert (r->>'sales_paused')::boolean;assert (r->>'self_declared_business')::boolean;
 assert public.bootstrap_merchant(b,'bootstrap-task049-key-0001',gen_random_uuid())=r;
 begin perform public.bootstrap_merchant(b||'{"role":"platform_admin"}','bootstrap-task049-key-0002',gen_random_uuid());raise exception 'injected role accepted';exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin perform public.bootstrap_merchant(b||'{"name":"Changed"}','bootstrap-task049-key-0001',gen_random_uuid());raise exception 'conflicting replay accepted';exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 begin perform public.bootstrap_merchant(b,'bootstrap-task049-key-0003',gen_random_uuid());raise exception 'duplicate slug accepted';exception when unique_violation then null;end;
 begin perform public.bootstrap_merchant(b||'{"slug":"admin"}','bootstrap-task049-key-0004',gen_random_uuid());raise exception 'reserved slug accepted';exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin perform result from private.merchant_bootstrap_commands;raise exception 'direct command read allowed';exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$declare tid uuid:=(select id from public.merchants where slug='e2e-bootstrap-049');begin
 assert (select count(*) from public.memberships where tenant_id=tid)=1;
 assert exists(select 1 from public.memberships where tenant_id=tid and user_id='49000000-0000-4000-8000-000000000001' and role='merchant_admin' and customer_account_id is null and store_id is null and project_id is null);
 assert not exists(select 1 from public.memberships where user_id='49000000-0000-4000-8000-000000000001' and role='platform_admin');
 assert (select count(*) from private.audit_events where tenant_id=tid and operation='merchant.bootstrap')=1;
 assert (select count(*) from private.merchant_bootstrap_commands where actor_id='49000000-0000-4000-8000-000000000001')=1;
 assert not exists(select 1 from public.stores where tenant_id=tid);assert not exists(select 1 from public.customer_accounts where tenant_id=tid);
end$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"49000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1","session_id":"49000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin perform public.bootstrap_merchant('{"slug":"e2e-bootstrap-aal1","name":"X","legal_name":"X AB","organization_number":"5568554884","reason":"Test only"}','bootstrap-task049-key-aal1',gen_random_uuid());raise exception 'aal1 allowed';exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
reset role;
update auth.users set email_confirmed_at=null where id='49000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"49000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2","session_id":"49000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin perform public.bootstrap_merchant('{"slug":"e2e-bootstrap-unverified","name":"X","legal_name":"X AB","organization_number":"5568554884","reason":"Test only"}','bootstrap-task049-unverified',gen_random_uuid());raise exception 'unverified email allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
update auth.users set email_confirmed_at=now() where id='49000000-0000-4000-8000-000000000001';
update auth.sessions set not_after=now()-interval '1 minute' where id='49000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$begin
 begin perform public.bootstrap_merchant('{"slug":"e2e-bootstrap-dead","name":"X","legal_name":"X AB","organization_number":"5568554884","reason":"Test only"}','bootstrap-task049-dead-session',gen_random_uuid());raise exception 'dead session allowed';exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
end$$;
reset role;
select 'TASK049 isolated bootstrap, no existing privilege, idempotency, MFA and verified identity PASS' as result;
rollback;
