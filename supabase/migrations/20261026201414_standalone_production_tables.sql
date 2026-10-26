-- Standalone production authorities and explicit, versioned administrative writes.
create table private.production_setups(
 tenant_id uuid primary key references public.merchants(id),version integer not null check(version>0),
 price_authority text not null check(price_authority='plockivo'),credit_authority text not null check(credit_authority='merchant-manual'),
 inventory_authority text not null check(inventory_authority='plockivo'),billing_authority text not null check(billing_authority='manual-export'),
 reason text not null,evidence_reference text not null,updated_at timestamptz not null default now()
);
create table private.production_catalog_map(
 source_item_id uuid primary key references private.standalone_catalog_items(id),tenant_id uuid not null references public.merchants(id),
 product_id uuid not null,source_version integer not null check(source_version>0),unique(tenant_id,product_id),
 foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create table private.production_prices(
 tenant_id uuid not null,customer_account_id uuid not null,product_id uuid not null,
 unit_price_minor bigint not null check(unit_price_minor between 0 and 999999999999),vat_bps integer not null check(vat_bps between 0 and 10000),revision integer not null check(revision>0),
 primary key(tenant_id,customer_account_id,product_id),foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create table private.production_stock(
 tenant_id uuid not null,store_id uuid not null,product_id uuid not null,on_hand numeric(20,6) not null,reserved numeric(20,6) not null default 0,
 version integer not null check(version>0),check(on_hand>=reserved and reserved>=0),primary key(tenant_id,store_id,product_id),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id),foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create table private.production_stock_adjustments(
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,store_id uuid not null,product_id uuid not null,actor_id uuid not null,
 previous_on_hand numeric(20,6) not null,new_on_hand numeric(20,6) not null,reserved numeric(20,6) not null,stock_version integer not null,
 reason text not null,evidence_reference text not null,correlation_id uuid not null,created_at timestamptz not null default now(),
 foreign key(tenant_id,store_id,product_id) references private.production_stock(tenant_id,store_id,product_id)
);
create table private.production_store_versions(
 store_id uuid primary key,tenant_id uuid not null,version integer not null check(version>0),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id)
);
create table private.production_project_versions(
 project_id uuid primary key,tenant_id uuid not null,customer_account_id uuid not null,version integer not null check(version>0),
 foreign key(tenant_id,customer_account_id,project_id) references public.projects(tenant_id,customer_account_id,id)
);
alter table private.production_setups enable row level security;
alter table private.production_catalog_map enable row level security;
alter table private.production_prices enable row level security;
alter table private.production_stock enable row level security;
alter table private.production_stock_adjustments enable row level security;
alter table private.production_store_versions enable row level security;
alter table private.production_project_versions enable row level security;
revoke all on private.production_setups,private.production_catalog_map,private.production_prices,private.production_stock,private.production_stock_adjustments,private.production_store_versions,private.production_project_versions from public,anon,authenticated;
