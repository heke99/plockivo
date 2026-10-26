create function private.get_production_setup(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;begin
 perform private.assert_mfa();if not private.profile_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 select jsonb_build_object('tenant_id',m.id,'mode',m.mode,'sales_paused',m.sales_paused,
 'setup',(select to_jsonb(s) from private.production_setups s where s.tenant_id=m.id),
 'accounts',coalesce((select jsonb_agg(to_jsonb(x) order by x.name,x.id) from (select a.id,a.name,a.status,a.purchase_blocked,a.terms_version from public.customer_accounts a where a.tenant_id=m.id and a.status='active' and not a.purchase_blocked and a.terms_version is not null order by a.name,a.id limit 200)x),'[]'::jsonb),
 'stores',coalesce((select jsonb_agg(to_jsonb(x) order by x.name,x.id) from (select s.id,s.name,s.code,s.sales_paused,coalesce(v.version,0) as version from public.stores s left join private.production_store_versions v on v.tenant_id=s.tenant_id and v.store_id=s.id where s.tenant_id=m.id order by s.name,s.id limit 200)x),'[]'::jsonb),
 'projects',coalesce((select jsonb_agg(to_jsonb(x) order by x.name,x.id) from (select p.id,p.customer_account_id,p.name,p.budget_minor::text,p.committed_minor::text,p.active,coalesce(v.version,0) as version from public.projects p left join private.production_project_versions v on v.tenant_id=p.tenant_id and v.project_id=p.id where p.tenant_id=m.id order by p.name,p.id limit 200)x),'[]'::jsonb),
 'products',coalesce((select jsonb_agg(to_jsonb(x) order by x.sku,x.id) from (select p.id,p.sku,p.name,p.unit,p.quantity_step::text,map.source_item_id,map.source_version from private.production_catalog_map map join public.products p on p.tenant_id=map.tenant_id and p.id=map.product_id where p.tenant_id=m.id order by p.sku,p.id limit 200)x),'[]'::jsonb),
 'prices',coalesce((select jsonb_agg(to_jsonb(x) order by x.customer_account_id,x.product_id) from (select p.customer_account_id,p.product_id,p.unit_price_minor::text,p.vat_bps,p.revision from private.production_prices p where p.tenant_id=m.id order by p.customer_account_id,p.product_id limit 200)x),'[]'::jsonb),
 'stock',coalesce((select jsonb_agg(to_jsonb(x) order by x.store_id,x.product_id) from (select s.store_id,s.product_id,s.on_hand::text,s.reserved::text,s.version from private.production_stock s where s.tenant_id=m.id order by s.store_id,s.product_id limit 200)x),'[]'::jsonb),
 'limits',jsonb_build_object('accounts',200,'stores',200,'projects',200,'products',200,'prices',200,'stock',200),
 'truncated',jsonb_build_object(
 'accounts',(select count(*)>200 from public.customer_accounts a where a.tenant_id=m.id and a.status='active' and not a.purchase_blocked and a.terms_version is not null),
 'stores',(select count(*)>200 from public.stores s where s.tenant_id=m.id),
 'projects',(select count(*)>200 from public.projects p where p.tenant_id=m.id),
 'products',(select count(*)>200 from private.production_catalog_map p where p.tenant_id=m.id),
 'prices',(select count(*)>200 from private.production_prices p where p.tenant_id=m.id),
 'stock',(select count(*)>200 from private.production_stock s where s.tenant_id=m.id)))
 into r from public.merchants m where m.id=p_tenant;
 if not found then raise exception 'NOT_FOUND';end if;return r;
end$$;

revoke all on function private.get_production_setup(uuid) from public,anon,authenticated;
