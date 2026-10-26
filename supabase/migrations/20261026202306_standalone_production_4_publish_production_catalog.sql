create function private.publish_production_catalog(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;item uuid;account_id_value uuid;source_version_value integer;v integer;m public.merchants;a public.customer_accounts;s private.production_setups;source private.standalone_catalog_items;mapping private.production_catalog_map;price private.production_prices;pid uuid;r jsonb;begin
 t:=private.production_request(p_body,array['tenant_id','item_id','source_version','customer_account_id','version'],p_key,p_correlation);
 item:=private.production_uuid(p_body,'item_id');account_id_value:=private.production_uuid(p_body,'customer_account_id');v:=private.production_integer(p_body,'version');source_version_value:=private.production_integer(p_body,'source_version');if source_version_value<1 then raise exception 'VALIDATION_ERROR';end if;
 select * into m from public.merchants where id=t for share;if m.mode is distinct from 'production' then raise exception 'INTEGRATION_NOT_READY';end if;
 select * into a from public.customer_accounts where tenant_id=t and id=account_id_value for update;if not found then raise exception 'NOT_FOUND';end if;
 if a.status<>'active' or a.purchase_blocked or a.terms_version is null then raise exception 'CREDIT_UNAVAILABLE';end if;
 select * into s from private.production_setups where tenant_id=t for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':production-admin',0));
 r:=private.production_replay(t,'production.catalog.publish',p_body,p_key);if r is not null then return r;end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':standalone-catalog',0));
 select * into source from private.standalone_catalog_items where tenant_id=t and id=item for share;if not found then raise exception 'NOT_FOUND';end if;
 if source.version<>source_version_value then raise exception 'VERSION_CONFLICT';end if;
 if not source.active or not source.self_scan then raise exception 'VALIDATION_ERROR';end if;
 select * into mapping from private.production_catalog_map where tenant_id=t and source_item_id=item;
 if found then
  pid:=mapping.product_id;perform 1 from public.products where tenant_id=t and id=pid for update;
  if exists(select 1 from public.products where tenant_id=t and id=pid and (unit<>source.unit or quantity_step<>source.quantity_step)) then raise exception 'VALIDATION_ERROR';end if;
 else pid:=gen_random_uuid();end if;
 select * into price from private.production_prices where tenant_id=t and product_id=pid and customer_account_id=account_id_value for update;
 if coalesce(price.revision,0)<>v then raise exception 'VERSION_CONFLICT';end if;
 if mapping.product_id is null then
  insert into public.products(id,tenant_id,sku,name,unit,quantity_step,self_scan,active) values(pid,t,source.sku,source.name,source.unit,source.quantity_step,true,true);
  insert into private.production_catalog_map(source_item_id,tenant_id,product_id,source_version) values(item,t,pid,source.version);
 elsif mapping.source_version<>source.version then
  update public.products set sku=source.sku,name=source.name,unit=source.unit,quantity_step=source.quantity_step,self_scan=true,active=true where tenant_id=t and id=pid;
  update private.production_catalog_map set source_version=source.version where source_item_id=item and tenant_id=t;
  -- Shared product metadata changes invalidate every customer's frozen quote.
  update private.production_prices set revision=revision+1 where tenant_id=t and product_id=pid and customer_account_id<>account_id_value;
 end if;
 delete from public.product_barcodes where tenant_id=t and product_id=pid;
 if source.barcode is not null then insert into public.product_barcodes(tenant_id,code,product_id,package_quantity) values(t,source.barcode,pid,source.package_quantity);end if;
 insert into private.production_prices(tenant_id,customer_account_id,product_id,unit_price_minor,vat_bps,revision)
 values(t,account_id_value,pid,source.unit_price_minor,source.vat_bps,v+1)
 on conflict(tenant_id,customer_account_id,product_id) do update set unit_price_minor=excluded.unit_price_minor,vat_bps=excluded.vat_bps,revision=excluded.revision;
 r:=jsonb_build_object('product_id',pid,'customer_account_id',account_id_value,'source_item_id',item,'source_version',source.version,'mode','production','unit_price_minor',source.unit_price_minor::text,'vat_bps',source.vat_bps,'revision',v+1);
 perform private.production_record(t,'production.catalog.publish',pid,p_body,p_key,p_correlation,r);return r;
 exception when unique_violation then raise exception 'CATALOG_DUPLICATE';
end$$;

revoke all on function private.publish_production_catalog(jsonb,text,uuid) from public,anon,authenticated;
