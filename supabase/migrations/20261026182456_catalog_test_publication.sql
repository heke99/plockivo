-- Explicit create-only snapshot from the preparation register into TEST only.
-- One source item may be published once, for one customer account. No resync.
create table private.catalog_test_publications(
 source_item_id uuid primary key references private.standalone_catalog_items(id),
 tenant_id uuid not null references public.merchants(id),
 customer_account_id uuid not null,product_id uuid not null,
 source_version integer not null check(source_version>0),
 created_at timestamptz not null default now(),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,product_id) references public.products(tenant_id,id),
 unique(tenant_id,product_id)
);
alter table private.catalog_test_publications enable row level security;
revoke all on private.catalog_test_publications from public,anon,authenticated;
create function private.publish_catalog_test(
 p_tenant uuid,p_item uuid,p_version integer,p_account uuid,p_key text,p_correlation uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare merchant public.merchants;account public.customer_accounts;
 source private.standalone_catalog_items;command private.commands;
 body jsonb;result jsonb;new_product uuid:=gen_random_uuid();
begin
 perform private.assert_mfa();
 if not private.standalone_catalog_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 if p_version is null or p_version<1 or p_key is null or length(p_key) not between 16 and 128
 or p_key !~ '^[a-zA-Z0-9:_-]+$' or p_item is null or p_account is null or p_correlation is null
 then raise exception 'VALIDATION_ERROR';end if;
 -- Same ordering as checkout: merchant, customer account, then source/product.
 select * into merchant from public.merchants where id=p_tenant for share;
 if not found then raise exception 'NOT_FOUND';end if;
 if merchant.mode<>'test' then raise exception 'INTEGRATION_NOT_READY';end if;
 select * into account from public.customer_accounts where tenant_id=p_tenant and id=p_account for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if account.status<>'active' or account.purchase_blocked or account.terms_version is null
 then raise exception 'CREDIT_UNAVAILABLE';end if;
 -- Serialize with source edits and all publications for this merchant.
 perform pg_advisory_xact_lock(hashtextextended(p_tenant::text||':standalone-catalog',0));
 body:=jsonb_build_object('tenant_id',p_tenant,'source_item_id',p_item,'source_version',p_version,'customer_account_id',p_account);
 select * into command from private.commands
 where tenant_id=p_tenant and actor_id=auth.uid() and operation='catalog.test.publish' and key=p_key;
 if found then
  if command.body<>body then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return command.result;
 end if;
 select * into source from private.standalone_catalog_items where id=p_item and tenant_id=p_tenant for share;
 if not found then raise exception 'NOT_FOUND';end if;
 if source.version<>p_version then raise exception 'VERSION_CONFLICT';end if;
 if not source.active or not source.self_scan then raise exception 'VALIDATION_ERROR';end if;
 if exists(select 1 from private.catalog_test_publications where source_item_id=p_item)
 then raise exception 'CATALOG_DUPLICATE';end if;
 insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan,active)
 values(new_product,p_tenant,source.sku,source.name,source.unit,source.quantity_step,true,true);
 if source.barcode is not null then
  insert into public.product_barcodes(tenant_id,code,product_id,package_quantity)
  values(p_tenant,source.barcode,new_product,source.package_quantity);
 end if;
 insert into private.test_prices(tenant_id,customer_account_id,product_id,unit_price_minor,vat_bps,revision)
 values(p_tenant,p_account,new_product,source.unit_price_minor,source.vat_bps,1);
 insert into private.catalog_test_publications(source_item_id,tenant_id,customer_account_id,product_id,source_version)
 values(p_item,p_tenant,p_account,new_product,p_version);
 result:=jsonb_build_object('product_id',new_product,'customer_account_id',p_account,
  'source_item_id',p_item,'source_version',p_version,'mode','test',
  'unit_price_minor',source.unit_price_minor::text,'vat_bps',source.vat_bps);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id)
 values(p_tenant,auth.uid(),'catalog.test.publish',new_product,p_correlation);
 insert into private.commands(tenant_id,actor_id,operation,key,body,result)
 values(p_tenant,auth.uid(),'catalog.test.publish',p_key,body,result);
 return result;
exception when unique_violation then raise exception 'CATALOG_DUPLICATE';
end$$;
create function public.publish_catalog_test(
 p_tenant uuid,p_item uuid,p_version integer,p_account uuid,p_key text,p_correlation uuid
) returns jsonb language sql security invoker set search_path='' as $$
 select private.publish_catalog_test(p_tenant,p_item,p_version,p_account,p_key,p_correlation)
$$;
revoke all on function private.publish_catalog_test(uuid,uuid,integer,uuid,text,uuid),public.publish_catalog_test(uuid,uuid,integer,uuid,text,uuid) from public,anon,authenticated;
grant execute on function private.publish_catalog_test(uuid,uuid,integer,uuid,text,uuid),public.publish_catalog_test(uuid,uuid,integer,uuid,text,uuid) to authenticated;
