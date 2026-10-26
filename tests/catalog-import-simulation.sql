begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
-- Rollback-only synthetic simulation. UUID namespace 31000000 is reserved for this test.
-- Fail on existing fixtures instead of touching another run's data.
insert into auth.users(id,email) values
 ('31000000-0000-4000-8000-000000000005','catalog-sim-031@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
 ('31000000-0000-4000-8000-000000000001','catalog-sim-031-a','Catalog simulation A','Catalog simulation A','SIM-031-A',true),
 ('31000000-0000-4000-8000-000000000002','catalog-sim-031-b','Catalog simulation B','Catalog simulation B','SIM-031-B',true);
insert into public.memberships(user_id,tenant_id,role) values
 ('31000000-0000-4000-8000-000000000005','31000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
 ('31000000-0000-4000-8000-000000000020','31000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values
 ('31000000-0000-4000-8000-000000000021','31000000-0000-4000-8000-000000000005','31000000-0000-4000-8000-000000000020','aal2',now(),now());

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"31000000-0000-4000-8000-000000000021"}',true);
do $$
declare
 base jsonb := '{"tenant_id":"31000000-0000-4000-8000-000000000001","id":null,"version":0,"sku":"SIM-031-01","name":"Simulation skruv","unit":"st","quantity_step":"1","barcode":"SIM031000001","package_quantity":"10","unit_price_minor":"12345","vat_bps":2500,"active":true,"self_scan":false}';
 second_body jsonb; third_body jsonb; edit_body jsonb;
 first_result jsonb; second_result jsonb; third_result jsonb; edited_result jsonb; listed jsonb;
begin
 -- Three distinct rows through the actual app RPC as authenticated AAL2 merchant admin.
 first_result := public.save_standalone_catalog(base,'catalog-sim-031-create-01',gen_random_uuid());
 second_body := base || '{"sku":"SIM-031-02","name":"Simulation kabel","barcode":"SIM031000002","unit_price_minor":"999999999999","quantity_step":"0.125","package_quantity":"2.5"}';
 second_result := public.save_standalone_catalog(second_body,'catalog-sim-031-create-02',gen_random_uuid());
 third_body := base || '{"sku":"SIM-031-03","name":"Simulation bricka","barcode":"SIM031000003","unit_price_minor":"0","active":false}';
 third_result := public.save_standalone_catalog(third_body,'catalog-sim-031-create-03',gen_random_uuid());
 if first_result->>'unit_price_minor' is distinct from '12345' or second_result->>'unit_price_minor' is distinct from '999999999999' or third_result->>'unit_price_minor' is distinct from '0' then raise exception 'SIM031 exact price failed';end if;
 if (first_result->>'version')::int is distinct from 1 or first_result->>'id'=second_result->>'id' or first_result->>'id'=third_result->>'id' or second_result->>'id'=third_result->>'id' then raise exception 'SIM031 distinct identities/version failed';end if;
 if (second_result->>'quantity_step')::numeric is distinct from 0.125 or (second_result->>'package_quantity')::numeric is distinct from 2.5 then raise exception 'SIM031 quantity precision failed';end if;
 if public.save_standalone_catalog(base,'catalog-sim-031-create-01',gen_random_uuid())<>first_result then raise exception 'SIM031 create replay failed';end if;
 begin
  perform public.save_standalone_catalog(base || '{"name":"Changed replay"}','catalog-sim-031-create-01',gen_random_uuid());raise exception 'SIM031 changed replay accepted';
 exception when raise_exception then if sqlerrm<>'IDEMPOTENCY_CONFLICT' then raise;end if;end;
 -- Duplicate SKU with a new barcode and duplicate barcode with a new SKU are separate cases.
 begin
  perform public.save_standalone_catalog(base || '{"barcode":"SIM031000099"}','catalog-sim-031-duplicate-sku',gen_random_uuid());raise exception 'SIM031 duplicate SKU accepted';
 exception when raise_exception then if sqlerrm<>'CATALOG_DUPLICATE' then raise;end if;end;
 begin
  perform public.save_standalone_catalog(base || '{"sku":"SIM-031-99"}','catalog-sim-031-duplicate-barcode',gen_random_uuid());raise exception 'SIM031 duplicate barcode accepted';
 exception when raise_exception then if sqlerrm<>'CATALOG_DUPLICATE' then raise;end if;end;
 -- Valid update then stale version and update replay.
 edit_body := base || jsonb_build_object('id',first_result->>'id','version',1,'name','Simulation skruv uppdaterad','unit_price_minor','12999');
 edited_result := public.save_standalone_catalog(edit_body,'catalog-sim-031-update-01',gen_random_uuid());
 if (edited_result->>'version')::int is distinct from 2 or edited_result->>'unit_price_minor' is distinct from '12999' then raise exception 'SIM031 update failed';end if;
 if public.save_standalone_catalog(edit_body,'catalog-sim-031-update-01',gen_random_uuid())<>edited_result then raise exception 'SIM031 update replay failed';end if;
 begin
  perform public.save_standalone_catalog(edit_body,'catalog-sim-031-stale-update',gen_random_uuid());raise exception 'SIM031 stale version accepted';
 exception when raise_exception then if sqlerrm<>'VERSION_CONFLICT' then raise;end if;end;
 -- Scope must be checked on both reads and writes, not just the UI.
 begin
  perform public.list_standalone_catalog('31000000-0000-4000-8000-000000000002');raise exception 'SIM031 foreign list accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.save_standalone_catalog(base || '{"tenant_id":"31000000-0000-4000-8000-000000000002"}','catalog-sim-031-foreign-save',gen_random_uuid());raise exception 'SIM031 foreign write accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 listed := public.list_standalone_catalog('31000000-0000-4000-8000-000000000001');
 if jsonb_array_length(listed->'items') is distinct from 3 or listed->>'checkout_enabled' is distinct from 'false' or listed->>'authority' is distinct from 'standalone-preparation' then raise exception 'SIM031 list/authority failed';end if;
end$$;

-- Same real admin/session, but unverified AAL1 claim: list and save must both fail.
select set_config('request.jwt.claims','{"sub":"31000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"31000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin
  perform public.list_standalone_catalog('31000000-0000-4000-8000-000000000001');raise exception 'SIM031 AAL1 list accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
 begin
  perform public.save_standalone_catalog('{"tenant_id":"31000000-0000-4000-8000-000000000001"}','catalog-sim-031-aal1-save',gen_random_uuid());raise exception 'SIM031 AAL1 write accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
reset role;
-- Privileged inspection is only the final evidence readback; all mutations above use app RPC role.
do $$begin
 if (select count(*) from private.standalone_catalog_items where tenant_id='31000000-0000-4000-8000-000000000001')<>3 then raise exception 'SIM031 final item count failed';end if;
 if exists(select 1 from private.standalone_catalog_items where tenant_id='31000000-0000-4000-8000-000000000002') then raise exception 'SIM031 foreign tenant mutated';end if;
 if (select count(*) from private.audit_events where tenant_id='31000000-0000-4000-8000-000000000001' and operation='catalog.standalone.save')<>4 then raise exception 'SIM031 audit count failed';end if;
 if (select count(*) from private.commands where tenant_id='31000000-0000-4000-8000-000000000001' and operation='catalog.standalone.save')<>4 then raise exception 'SIM031 command count failed';end if;
 if exists(select 1 from private.audit_events where tenant_id='31000000-0000-4000-8000-000000000002') or exists(select 1 from private.commands where tenant_id='31000000-0000-4000-8000-000000000002') then raise exception 'SIM031 denied write produced audit/command';end if;
end$$;
select 'CATALOG-IMPORT-SIM-031 three items/exact prices/replay/duplicates/version/tenant/MFA/audit PASS (rollback follows)' as result;
rollback;
-- Independent post-rollback readback: every count must be zero.
select jsonb_build_object(
 'users',(select count(*) from auth.users where id='31000000-0000-4000-8000-000000000005'),
 'sessions',(select count(*) from auth.sessions where user_id='31000000-0000-4000-8000-000000000005'),
 'factors',(select count(*) from auth.mfa_factors where user_id='31000000-0000-4000-8000-000000000005'),
 'merchants',(select count(*) from public.merchants where id in ('31000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002')),
 'memberships',(select count(*) from public.memberships where user_id='31000000-0000-4000-8000-000000000005'),
 'catalog_items',(select count(*) from private.standalone_catalog_items where tenant_id in ('31000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002')),
 'audit_events',(select count(*) from private.audit_events where tenant_id in ('31000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002')),
 'commands',(select count(*) from private.commands where tenant_id in ('31000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002'))
) as cleanup;
