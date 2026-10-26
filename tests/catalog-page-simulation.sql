begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
-- Rollback-only synthetic simulation. UUID namespace 32000000 is reserved for this test.
-- Fail on existing fixtures instead of touching another run's data.
insert into auth.users(id,email) values
 ('32000000-0000-4000-8000-000000000005','catalog-page-sim-037@plockivo.invalid');
insert into public.merchants(id,slug,name,legal_name,organization_number,sales_paused) values
 ('32000000-0000-4000-8000-000000000001','catalog-page-sim-037-a','Catalog simulation A','Catalog simulation A','SIM-037-A',true),
 ('32000000-0000-4000-8000-000000000002','catalog-page-sim-037-b','Catalog simulation B','Catalog simulation B','SIM-037-B',true);
insert into public.memberships(user_id,tenant_id,role) values
 ('32000000-0000-4000-8000-000000000005','32000000-0000-4000-8000-000000000001','merchant_admin');
insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
 ('32000000-0000-4000-8000-000000000020','32000000-0000-4000-8000-000000000005','totp','verified',now(),now());
insert into auth.sessions(id,user_id,factor_id,aal,created_at,updated_at) values
 ('32000000-0000-4000-8000-000000000021','32000000-0000-4000-8000-000000000005','32000000-0000-4000-8000-000000000020','aal2',now(),now());

-- Fixture insertion is privileged and rollback-only; every page request below uses app role.
insert into private.standalone_catalog_items(tenant_id,sku,name,unit,quantity_step,barcode,package_quantity,unit_price_minor,vat_bps,active,self_scan)
select '32000000-0000-4000-8000-000000000001', 'SIM-'||lpad(n::text,3,'0'),
 case when n=7 then 'Literal 100% säker' when n=8 then 'Literal under_score' else 'Simulation artikel '||n end,
 'st',1,'SIM037-'||lpad(n::text,3,'0'),1,n*100,2500,true,false from generate_series(1,207) n;
insert into private.standalone_catalog_items(tenant_id,sku,name,unit,quantity_step,barcode,package_quantity,unit_price_minor,vat_bps,active,self_scan)
select '32000000-0000-4000-8000-000000000002','FOREIGN-'||n,'Hemlig annan tenant','st',1,null,1,100,2500,true,false from generate_series(1,2)n;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"32000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2","session_id":"32000000-0000-4000-8000-000000000021"}',true);
do $$
declare
 page jsonb; item jsonb; cursor_sku text:=null; cursor_id uuid:=null;
 seen uuid[]:='{}'; last_sku text:=null; last_id uuid:=null; pages integer:=0;
begin
 loop
  page:=public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','',cursor_sku,cursor_id,50);
  pages:=pages+1;if pages>5 then raise exception 'SIM037 pagination did not terminate';end if;
  if page->>'authority' is distinct from 'standalone-preparation' or page->>'checkout_enabled' is distinct from 'false' or (page->>'total')::int is distinct from 207 then raise exception 'SIM037 page authority/total failed';end if;
  if jsonb_array_length(page->'items') is distinct from (case when pages<5 then 50 else 7 end) then raise exception 'SIM037 page size failed';end if;
  for item in select value from jsonb_array_elements(page->'items') loop
   if item->>'tenant_id' is distinct from '32000000-0000-4000-8000-000000000001' then raise exception 'SIM037 tenant leak';end if;
   if (item->>'id')::uuid=any(seen) then raise exception 'SIM037 repeated item';end if;
   if last_sku is not null and row(item->>'sku',(item->>'id')::uuid)<=row(last_sku,last_id) then raise exception 'SIM037 unstable order';end if;
   seen:=array_append(seen,(item->>'id')::uuid);last_sku:=item->>'sku';last_id:=(item->>'id')::uuid;
  end loop;
  exit when page->'next_cursor'='null'::jsonb;
  if page->'next_cursor' is null then raise exception 'SIM037 absent cursor';end if;
  cursor_sku:=page->'next_cursor'->>'sku';cursor_id:=(page->'next_cursor'->>'id')::uuid;
  if cursor_sku is distinct from last_sku or cursor_id is distinct from last_id then raise exception 'SIM037 cursor mismatch';end if;
 end loop;
 if cardinality(seen)<>207 or pages<>5 then raise exception 'SIM037 missing rows';end if;
 -- SQL wildcard characters are literal substring searches, not LIKE patterns.
 page:=public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','%',null,null,50);
 if (page->>'total')::int is distinct from 1 or page->'items'->0->>'sku' is distinct from 'SIM-007' or jsonb_array_length(page->'items') is distinct from 1 then raise exception 'SIM037 percent was not literal';end if;
 page:=public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','_',null,null,50);
 if (page->>'total')::int is distinct from 1 or page->'items'->0->>'sku' is distinct from 'SIM-008' then raise exception 'SIM037 underscore was not literal';end if;
 page:=public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','SIM037-207',null,null,50);
 if (page->>'total')::int is distinct from 1 or page->'items'->0->>'sku' is distinct from 'SIM-207' then raise exception 'SIM037 barcode search failed';end if;
 begin
  perform public.page_standalone_catalog('32000000-0000-4000-8000-000000000002','',null,null,50);raise exception 'SIM037 foreign tenant accepted';
 exception when raise_exception then if sqlerrm<>'PERMISSION_DENIED' then raise;end if;end;
 begin
  perform public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','',null,null,0);raise exception 'SIM037 zero limit accepted';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin
  perform public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','',null,null,101);raise exception 'SIM037 oversized limit accepted';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
 begin
  perform public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','', 'SIM-050',null,50);raise exception 'SIM037 half cursor accepted';
 exception when raise_exception then if sqlerrm<>'VALIDATION_ERROR' then raise;end if;end;
end$$;
select set_config('request.jwt.claims','{"sub":"32000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1","session_id":"32000000-0000-4000-8000-000000000021"}',true);
do $$begin
 begin
  perform public.page_standalone_catalog('32000000-0000-4000-8000-000000000001','',null,null,50);raise exception 'SIM037 AAL1 accepted';
 exception when raise_exception then if sqlerrm<>'MFA_REQUIRED' then raise;end if;end;
end$$;
reset role;
do $$begin
 if (select count(*) from private.standalone_catalog_items where tenant_id='32000000-0000-4000-8000-000000000001')<>207 or (select count(*) from private.standalone_catalog_items where tenant_id='32000000-0000-4000-8000-000000000002')<>2 then raise exception 'SIM037 fixture count changed';end if;
 if exists(select 1 from private.audit_events where tenant_id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')) or exists(select 1 from private.commands where tenant_id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')) then raise exception 'SIM037 read created side effects';end if;
end$$;
select 'CATALOG-PAGE-SIM-037 207 rows/five pages/order/uniqueness/literal search/tenant/MFA/limits PASS (rollback follows)' as result;
rollback;
-- Independent post-rollback readback: every count must be zero.
select jsonb_build_object(
 'users',(select count(*) from auth.users where id='32000000-0000-4000-8000-000000000005'),
 'sessions',(select count(*) from auth.sessions where user_id='32000000-0000-4000-8000-000000000005'),
 'factors',(select count(*) from auth.mfa_factors where user_id='32000000-0000-4000-8000-000000000005'),
 'merchants',(select count(*) from public.merchants where id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')),
 'memberships',(select count(*) from public.memberships where user_id='32000000-0000-4000-8000-000000000005'),
 'catalog_items',(select count(*) from private.standalone_catalog_items where tenant_id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')),
 'audit_events',(select count(*) from private.audit_events where tenant_id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')),
 'commands',(select count(*) from private.commands where tenant_id in ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002'))
) as cleanup;
