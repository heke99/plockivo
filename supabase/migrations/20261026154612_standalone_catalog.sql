-- Standalone preparation register; never consumed by current synthetic checkout.
create table private.standalone_catalog_items(
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.merchants(id),version integer not null default 1 check(version>0),
 sku text not null check(length(trim(sku)) between 1 and 80),name text not null check(length(trim(name)) between 1 and 200),unit text not null check(length(trim(unit)) between 1 and 30),
 quantity_step numeric(20,6) not null check(quantity_step>0),barcode text check(length(trim(barcode)) between 1 and 100),package_quantity numeric(20,6) not null check(package_quantity>0),
 unit_price_minor bigint not null check(unit_price_minor between 0 and 999999999999),vat_bps integer not null check(vat_bps between 0 and 10000),active boolean not null,self_scan boolean not null,
 unique(tenant_id,sku),unique(tenant_id,barcode)
);
alter table private.standalone_catalog_items enable row level security;
revoke all on private.standalone_catalog_items from public,anon,authenticated;
insert into public.role_permissions values('merchant_admin','catalog.manage.standalone');
create function private.standalone_catalog_dto(i private.standalone_catalog_items) returns jsonb language sql immutable set search_path='' as $$select to_jsonb(i)||jsonb_build_object('unit_price_minor',i.unit_price_minor::text,'quantity_step',i.quantity_step::text,'package_quantity',i.package_quantity::text)$$;
create function private.standalone_catalog_authorized(t uuid) returns boolean language sql stable security definer set search_path='' as $$select private.profile_authorized(t) and private.allowed(t,null,null,null,'catalog.manage.standalone')$$;
create function private.list_standalone_catalog(p_tenant uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform private.assert_mfa();if not private.standalone_catalog_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 return jsonb_build_object('authority','standalone-preparation','checkout_enabled',false,'items',coalesce((select jsonb_agg(private.standalone_catalog_dto(x)) from (select * from private.standalone_catalog_items where tenant_id=p_tenant order by sku,id limit 200)x),'[]'));
end$$;
create function private.save_standalone_catalog(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid:=(p_body->>'tenant_id')::uuid;i private.standalone_catalog_items;cmd private.commands;v integer:=(p_body->>'version')::integer;r jsonb;begin
 perform private.assert_mfa();if not private.standalone_catalog_authorized(t) then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_body-'tenant_id'-'id'-'version'-'sku'-'name'-'unit'-'quantity_step'-'barcode'-'package_quantity'-'unit_price_minor'-'vat_bps'-'active'-'self_scan'<>'{}'::jsonb
 or length(trim(coalesce(p_body->>'sku',''))) not between 1 and 80 or length(trim(coalesce(p_body->>'name',''))) not between 1 and 200 or length(trim(coalesce(p_body->>'unit',''))) not between 1 and 30
 or coalesce(p_body->>'quantity_step','') !~ '^(0|[1-9][0-9]{0,5})(\.[0-9]{1,6})?$' or coalesce(p_body->>'package_quantity','') !~ '^(0|[1-9][0-9]{0,5})(\.[0-9]{1,6})?$' or coalesce(p_body->>'unit_price_minor','') !~ '^(0|[1-9][0-9]{0,11})$'
 or jsonb_typeof(p_body->'active') is distinct from 'boolean' or jsonb_typeof(p_body->'self_scan') is distinct from 'boolean' then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':standalone-catalog',0));
 select * into cmd from private.commands where tenant_id=t and actor_id=auth.uid() and operation='catalog.standalone.save' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if p_body->>'id' is null then
 if v is distinct from 0 then raise exception 'VERSION_CONFLICT';end if;
 i.id:=gen_random_uuid();i.version:=1;
 else
 select * into i from private.standalone_catalog_items where id=(p_body->>'id')::uuid and tenant_id=t for update;
 if not found then raise exception 'NOT_FOUND';end if;if i.version is distinct from v then raise exception 'VERSION_CONFLICT';end if;i.version:=i.version+1;
 end if;
 i.tenant_id:=t;i.sku:=trim(p_body->>'sku');i.name:=trim(p_body->>'name');i.unit:=trim(p_body->>'unit');i.quantity_step:=(p_body->>'quantity_step')::numeric;i.barcode:=case when p_body->>'barcode' is null then null else trim(p_body->>'barcode') end;i.package_quantity:=(p_body->>'package_quantity')::numeric;i.unit_price_minor:=(p_body->>'unit_price_minor')::bigint;i.vat_bps:=(p_body->>'vat_bps')::integer;i.active:=(p_body->>'active')::boolean;i.self_scan:=(p_body->>'self_scan')::boolean;
 insert into private.standalone_catalog_items select i.* on conflict(id) do update set version=excluded.version,sku=excluded.sku,name=excluded.name,unit=excluded.unit,quantity_step=excluded.quantity_step,barcode=excluded.barcode,package_quantity=excluded.package_quantity,unit_price_minor=excluded.unit_price_minor,vat_bps=excluded.vat_bps,active=excluded.active,self_scan=excluded.self_scan;
 r:=private.standalone_catalog_dto(i);
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),'catalog.standalone.save',i.id,p_correlation);
 insert into private.commands values(t,auth.uid(),'catalog.standalone.save',p_key,p_body,r,now());return r;
exception when unique_violation then raise exception 'CATALOG_DUPLICATE';
end$$;
create function public.list_standalone_catalog(p_tenant uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_standalone_catalog(p_tenant)$$;
create function public.save_standalone_catalog(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.save_standalone_catalog(p_body,p_key,p_correlation)$$;
revoke all on function private.standalone_catalog_dto(private.standalone_catalog_items),private.standalone_catalog_authorized(uuid),private.list_standalone_catalog(uuid),private.save_standalone_catalog(jsonb,text,uuid),public.list_standalone_catalog(uuid),public.save_standalone_catalog(jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.list_standalone_catalog(uuid),private.save_standalone_catalog(jsonb,text,uuid),public.list_standalone_catalog(uuid),public.save_standalone_catalog(jsonb,text,uuid) to authenticated;
