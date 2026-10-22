-- Foundation 0.1.0. Synthetic test adapter only. Production sales fail closed.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
alter default privileges in schema private revoke execute on functions from public;
create table public.merchants (
 id uuid primary key default gen_random_uuid(), slug text not null unique check(slug ~ '^[a-z][a-z0-9-]{2,40}$' and slug not in ('app','api','admin','auth','www','support','status','mail')),
 name text not null, legal_name text not null, organization_number text not null,
 mode text not null default 'test' check(mode in ('test','production')), sales_paused boolean not null default true,
 currency text not null default 'SEK' check(currency='SEK'), timezone text not null default 'Europe/Stockholm',
 profile jsonb not null default '{}', created_at timestamptz not null default now()
);
create table public.customer_accounts (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.merchants(id),
 name text not null, organization_number text not null, external_customer_id text,
 status text not null default 'pending' check(status in ('pending','active','suspended')), terms_version text,
 credit_limit_minor bigint not null default 0 check(credit_limit_minor>=0), exposure_minor bigint not null default 0 check(exposure_minor>=0),
 purchase_blocked boolean not null default true, unique(tenant_id,id), unique(tenant_id,organization_number)
);
create table public.stores (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.merchants(id), name text not null,
 code text not null, sales_paused boolean not null default true, unique(tenant_id,id), unique(tenant_id,code)
);
create table public.projects (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null, customer_account_id uuid not null,
 name text not null, budget_minor bigint not null check(budget_minor>=0), committed_minor bigint not null default 0 check(committed_minor>=0),
 active boolean not null default true, unique(tenant_id,customer_account_id,id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id)
);
create table public.role_permissions(role text not null, permission text not null, primary key(role,permission));
insert into public.role_permissions values
 ('buyer','catalog.read'),('buyer','purchases.prepare'),('buyer','purchases.checkout'),('buyer','orders.read.own'),
 ('approver','catalog.read'),('approver','purchases.approve'),('approver','orders.read.project'),
 ('customer_admin','catalog.read'),('customer_admin','orders.read.account'),
 ('store_staff','catalog.read'),('store_staff','orders.read.store'),
 ('merchant_admin','catalog.read');
create table public.memberships (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id), tenant_id uuid not null references public.merchants(id),
 customer_account_id uuid, store_id uuid, project_id uuid, role text not null,
 status text not null default 'active' check(status in ('active','suspended','revoked')),
 valid_from timestamptz not null default now(), valid_to timestamptz,
 per_purchase_minor bigint not null default 0 check(per_purchase_minor>=0), approval_threshold_minor bigint not null default 0 check(approval_threshold_minor>=0),
 check(valid_to is null or valid_to>valid_from), check(project_id is null or customer_account_id is not null),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id),
 foreign key(tenant_id,customer_account_id,project_id) references public.projects(tenant_id,customer_account_id,id)
);
create index memberships_actor_idx on public.memberships(user_id,tenant_id,status);
create table public.products (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.merchants(id),
 sku text not null, name text not null, unit text not null, quantity_step numeric(20,6) not null check(quantity_step>0),
 self_scan boolean not null default false, active boolean not null default true,
 unique(tenant_id,id),unique(tenant_id,sku)
);
create table public.product_barcodes (
 tenant_id uuid not null, code text not null check(length(code) between 1 and 100),product_id uuid not null,
 package_quantity numeric(20,6) not null check(package_quantity>0),primary key(tenant_id,code),
 foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create table private.test_prices (
 tenant_id uuid not null,customer_account_id uuid not null,product_id uuid not null,
 unit_price_minor numeric(20,6) not null check(unit_price_minor>=0),vat_bps integer not null check(vat_bps between 0 and 10000),
 revision integer not null default 1,primary key(tenant_id,customer_account_id,product_id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create table public.purchase_intents (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,customer_account_id uuid not null,store_id uuid not null,project_id uuid not null,
 actor_id uuid not null references auth.users(id),version integer not null default 1,
 status text not null check(status in ('awaiting_approval','ready_for_confirmation','completed','rejected')),
 request jsonb not null,quote jsonb not null,quote_hash text not null,total_minor bigint not null check(total_minor>0),
 expires_at timestamptz not null,created_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id),
 foreign key(tenant_id,customer_account_id,project_id) references public.projects(tenant_id,customer_account_id,id)
);
create index intents_actor_idx on public.purchase_intents(actor_id,created_at desc);
create table public.approvals (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,purchase_intent_id uuid not null,
 version integer not null,actor_id uuid not null references auth.users(id),decision text not null check(decision in ('approved','rejected')),
 created_at timestamptz not null default now(),unique(purchase_intent_id,version),
 foreign key(tenant_id,purchase_intent_id) references public.purchase_intents(tenant_id,id)
);
create table public.orders (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,purchase_intent_id uuid not null unique,
 customer_account_id uuid not null,actor_id uuid not null references auth.users(id),store_id uuid not null,
 status text not null default 'accepted' check(status='accepted'),snapshot jsonb not null,total_minor bigint not null check(total_minor>0),
 currency text not null default 'SEK' check(currency='SEK'),mode text not null check(mode='test'),created_at timestamptz not null default now(),
 unique(tenant_id,id),foreign key(tenant_id,purchase_intent_id) references public.purchase_intents(tenant_id,id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),foreign key(tenant_id,store_id) references public.stores(tenant_id,id)
);
create table public.order_lines (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,product_id uuid not null,
 snapshot jsonb not null,quantity numeric(20,6) not null check(quantity>0),net_minor bigint not null,vat_minor bigint not null,
 foreign key(tenant_id,order_id) references public.orders(tenant_id,id),foreign key(tenant_id,product_id) references public.products(tenant_id,id),
 unique(order_id,product_id)
);
create table private.credit_reservations (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null unique,amount_minor bigint not null check(amount_minor>0),
 foreign key(tenant_id,order_id) references public.orders(tenant_id,id)
);
create table private.commands (
 tenant_id uuid not null,actor_id uuid not null,operation text not null,key text not null,body jsonb not null,
 result jsonb not null,created_at timestamptz not null default now(),primary key(tenant_id,actor_id,operation,key)
);
create table private.audit_events (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.merchants(id),actor_id uuid not null,
 operation text not null,object_id uuid not null,correlation_id uuid not null,created_at timestamptz not null default now()
);
create table private.outbox (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,kind text not null,
 status text not null default 'queued' check(status in ('queued','claimed','succeeded','unknown','manual_review')),
 claim_token uuid,claimed_until timestamptz,attempts integer not null default 0,created_at timestamptz not null default now(),
 unique(order_id,kind),foreign key(tenant_id,order_id) references public.orders(tenant_id,id)
);
create table public.documents (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,kind text not null,
 template_version text not null,content jsonb not null,content_hash text not null,created_at timestamptz not null default now(),
 unique(order_id,kind),foreign key(tenant_id,order_id) references public.orders(tenant_id,id)
);
create table private.api_quotas(user_id uuid primary key references auth.users(id),window_start timestamptz not null,count integer not null);
-- Explicit permission lookup avoids recursive RLS. Definer helpers use locked search paths.
create function private.allowed(p_tenant uuid,p_account uuid,p_store uuid,p_project uuid,p_permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(
 select 1 from public.memberships m join public.role_permissions r on r.role=m.role
 where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())
 and r.permission=p_permission and (m.customer_account_id is null or m.customer_account_id=p_account)
 and (m.store_id is null or m.store_id=p_store) and (m.project_id is null or m.project_id=p_project));
$$;
create function private.can_read_intent(i public.purchase_intents) returns boolean language sql stable security definer set search_path='' as $$
 select (i.actor_id=auth.uid() and private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'orders.read.own'))
 or private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'orders.read.account')
 or private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'orders.read.project')
 or private.allowed(i.tenant_id,null,i.store_id,null,'orders.read.store');
$$;
-- All application tables are RLS protected, and no direct business writes are granted.
do $$declare t text;begin
 for t in select tablename from pg_tables where schemaname in ('public','private') loop
  if exists(select 1 from pg_tables where schemaname='public' and tablename=t) then
   execute format('alter table public.%I enable row level security',t);
   execute format('revoke all on public.%I from anon,authenticated',t);
  end if;
 end loop;
end$$;
create policy memberships_self on public.memberships for select to authenticated using(user_id=(select auth.uid()));
grant select on public.memberships to authenticated;
create policy permissions_read on public.role_permissions for select to authenticated using(true);
grant select on public.role_permissions to authenticated;
create policy merchant_read on public.merchants for select to authenticated using(exists(select 1 from public.memberships m where m.tenant_id=id and m.user_id=(select auth.uid()) and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())));
grant select on public.merchants to authenticated;
create policy intent_read on public.purchase_intents for select to authenticated using(private.can_read_intent(purchase_intents));
grant select on public.purchase_intents to authenticated;
create policy order_read on public.orders for select to authenticated using(exists(select 1 from public.purchase_intents i where i.id=purchase_intent_id and private.can_read_intent(i)));
grant select on public.orders to authenticated;
create policy lines_read on public.order_lines for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
grant select on public.order_lines to authenticated;
create policy document_read on public.documents for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
grant select on public.documents to authenticated;
-- No public SELECT grants on accounts, projects, catalog: DTO functions provide minimum fields.
create function private.context() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 return jsonb_build_object('memberships',coalesce((select jsonb_agg(jsonb_build_object(
 'id',m.id,'tenant_id',m.tenant_id,'customer_account_id',m.customer_account_id,'role',m.role,'merchant',t.name,'merchant_slug',t.slug,'mode',t.mode,
 'account',a.name,'store_id',m.store_id,'project_id',m.project_id,
 'permissions',(select jsonb_agg(r.permission) from public.role_permissions r where r.role=m.role)))
 from public.memberships m join public.merchants t on t.id=m.tenant_id left join public.customer_accounts a on a.id=m.customer_account_id
 where m.user_id=auth.uid() and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())), '[]'),
 'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'tenant_id',s.tenant_id,'name',s.name)) from public.stores s where private.allowed(s.tenant_id,null,s.id,null,'orders.read.store') or exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=s.tenant_id and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and (m.store_id is null or m.store_id=s.id))), '[]'),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'tenant_id',p.tenant_id,'customer_account_id',p.customer_account_id,'name',p.name)) from public.projects p where p.active and (private.allowed(p.tenant_id,p.customer_account_id,null,p.id,'purchases.prepare') or private.allowed(p.tenant_id,p.customer_account_id,null,p.id,'purchases.approve'))), '[]'));
end$$;
create function private.catalog(p_tenant uuid,p_query text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.memberships m join public.role_permissions r on r.role=m.role where m.user_id=auth.uid() and m.tenant_id=p_tenant and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and r.permission='catalog.read') then raise exception 'PERMISSION_DENIED';end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from (select p.id,p.sku,p.name,p.unit,p.quantity_step::text,p.self_scan,
 coalesce((select jsonb_agg(jsonb_build_object('code',b.code,'package_quantity',b.package_quantity::text)) from public.product_barcodes b where b.tenant_id=p.tenant_id and b.product_id=p.id),'[]') as barcodes
 from public.products p where p.tenant_id=p_tenant and p.active and (p_query='' or p.sku ilike '%'||p_query||'%' or p.name ilike '%'||p_query||'%' or exists(select 1 from public.product_barcodes b where b.tenant_id=p_tenant and b.product_id=p.id and b.code=p_query)) order by p.sku limit 50)x),'[]');
end$$;
create function private.prepare(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid:=(p_body->>'tenant_id')::uuid;a uuid:=(p_body->>'customer_account_id')::uuid;s uuid:=(p_body->>'store_id')::uuid;pr uuid:=(p_body->>'project_id')::uuid;
 m public.memberships;item jsonb;prod public.products;price private.test_prices;q numeric;net bigint;vat bigint;total bigint:=0;lines jsonb:='[]';quote jsonb;i public.purchase_intents;cmd private.commands;res jsonb;requires_approval boolean;
begin
 if not private.allowed(t,a,s,pr,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or jsonb_typeof(p_body->'lines')<>'array' or jsonb_array_length(p_body->'lines') not between 1 and 100 or length(trim(p_body->>'reference')) not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||auth.uid()::text||'prepare'||p_key,0));
 select * into cmd from private.commands where tenant_id=t and actor_id=auth.uid() and operation='prepare' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if not exists(select 1 from public.merchants where id=t and mode='test') then raise exception 'INTEGRATION_NOT_READY';end if;
 if not exists(select 1 from public.customer_accounts where tenant_id=t and id=a and status='active' and terms_version is not null) or not exists(select 1 from public.stores where tenant_id=t and id=s) or not exists(select 1 from public.projects where tenant_id=t and customer_account_id=a and id=pr and active) then raise exception 'PERMISSION_DENIED';end if;
 if (select count(*) from jsonb_array_elements(p_body->'lines'))<>(select count(distinct x->>'product_id') from jsonb_array_elements(p_body->'lines')x) then raise exception 'VALIDATION_ERROR';end if;
 for item in select * from jsonb_array_elements(p_body->'lines') loop
  if (item->>'quantity')!~'^(0|[1-9][0-9]{0,5})(\.[0-9]{1,6})?$' then raise exception 'VALIDATION_ERROR';end if;
  q:=(item->>'quantity')::numeric;
  select * into prod from public.products where tenant_id=t and id=(item->>'product_id')::uuid and active and self_scan;
  if not found or q<=0 or mod(q,prod.quantity_step)<>0 then raise exception 'VALIDATION_ERROR';end if;
  select * into price from private.test_prices where tenant_id=t and customer_account_id=a and product_id=prod.id;
  if not found then raise exception 'INTEGRATION_NOT_READY';end if;
  net:=round(q*price.unit_price_minor);vat:=round(net::numeric*price.vat_bps/10000);total:=total+net+vat;
  lines:=lines||jsonb_build_array(jsonb_build_object('product_id',prod.id,'sku',prod.sku,'name',prod.name,'unit',prod.unit,'quantity',q::text,'unit_price_minor',price.unit_price_minor::text,'vat_bps',price.vat_bps,'net_minor',net::text,'vat_minor',vat::text,'price_revision',price.revision));
 end loop;
 if total<=0 or total>10000000000 then raise exception 'VALIDATION_ERROR';end if;
 select mm.* into m from public.memberships mm join public.role_permissions rp on rp.role=mm.role and rp.permission='purchases.checkout'
 where mm.user_id=auth.uid() and mm.tenant_id=t and mm.customer_account_id=a and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and (mm.store_id is null or mm.store_id=s) and (mm.project_id is null or mm.project_id=pr) order by mm.per_purchase_minor desc limit 1;
 if not found or total>m.per_purchase_minor then raise exception 'BUDGET_EXCEEDED';end if;
 requires_approval:=total>m.approval_threshold_minor;
 quote:=jsonb_build_object('lines',lines,'total_minor',total::text,'currency','SEK','reference',p_body->>'reference','terms_version',(select terms_version from public.customer_accounts where id=a),'seller',(select jsonb_build_object('name',legal_name,'organization_number',organization_number) from public.merchants where id=t),'buyer',(select jsonb_build_object('name',name,'organization_number',organization_number) from public.customer_accounts where id=a),'price_authority','synthetic-test-adapter','rounding','row_net_then_row_vat_half_up');
 insert into public.purchase_intents(tenant_id,customer_account_id,store_id,project_id,actor_id,status,request,quote,quote_hash,total_minor,expires_at)
 values(t,a,s,pr,auth.uid(),case when requires_approval then 'awaiting_approval' else 'ready_for_confirmation' end,p_body,quote,md5(quote::text),total,now()+interval '15 minutes') returning * into i;
 res:=jsonb_build_object('id',i.id,'version',i.version,'status',i.status,'quote',quote,'quote_hash',i.quote_hash,'expires_at',i.expires_at,'mode','test');
 insert into private.commands values(t,auth.uid(),'prepare',p_key,p_body,res,now());
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),'purchases.prepare',i.id,p_correlation);
 return res;
end$$;
create function private.confirm(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.purchase_intents;a public.customer_accounts;pr public.projects;m public.memberships;cmd private.commands;o public.orders;res jsonb;line jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(coalesce(auth.uid()::text,'anonymous')||coalesce(p_key,''),0));
 select * into i from public.purchase_intents where id=p_id for update;
 if not found or i.actor_id<>auth.uid() or not private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'purchases.checkout') then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 then raise exception 'VALIDATION_ERROR';end if;
 select mm.* into m from public.memberships mm join public.role_permissions rp on rp.role=mm.role and rp.permission='purchases.checkout'
 where mm.user_id=auth.uid() and mm.tenant_id=i.tenant_id and mm.customer_account_id=i.customer_account_id and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and (mm.store_id is null or mm.store_id=i.store_id) and (mm.project_id is null or mm.project_id=i.project_id) order by mm.per_purchase_minor desc limit 1 for share of mm;
 if not found then raise exception 'MEMBERSHIP_INACTIVE';end if;
 select * into cmd from private.commands where tenant_id=i.tenant_id and actor_id=auth.uid() and operation='confirm' and key=p_key;
 if found then if cmd.body<>jsonb_build_object('id',p_id,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if i.version is distinct from (p_body->>'version')::int then raise exception 'VERSION_CONFLICT';end if;
 if i.quote_hash is distinct from (p_body->>'quote_hash') then raise exception 'PRICE_CHANGED';end if;
 select * into o from public.orders where purchase_intent_id=i.id;
 if found then return jsonb_build_object('id',o.id,'purchase_intent_id',i.id,'status','accepted','mode','test','total_minor',o.total_minor::text);end if;
 if i.expires_at<=now() then raise exception 'PRICE_CHANGED';end if;
 if i.status='awaiting_approval' or (i.total_minor>m.approval_threshold_minor and not exists(select 1 from public.approvals where purchase_intent_id=i.id and version=i.version and decision='approved' and actor_id<>auth.uid())) then raise exception 'APPROVAL_REQUIRED';end if;
 if i.status<>'ready_for_confirmation' then raise exception 'VERSION_CONFLICT';end if;
 if i.total_minor>m.per_purchase_minor then raise exception 'BUDGET_EXCEEDED';end if;
 perform 1 from public.merchants where id=i.tenant_id and mode='test' for share;
 if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 if exists(select 1 from public.merchants where id=i.tenant_id and sales_paused) then raise exception 'SALES_PAUSED';end if;
 perform 1 from public.stores where id=i.store_id and not sales_paused for share;
 if not found then raise exception 'SALES_PAUSED';end if;
 -- Fixed lock order: intent -> membership -> merchant/store -> account -> project -> prices.
 select * into a from public.customer_accounts where id=i.customer_account_id and tenant_id=i.tenant_id for update;
 if a.status<>'active' or a.purchase_blocked or a.terms_version is null or a.credit_limit_minor-a.exposure_minor<i.total_minor then raise exception 'CREDIT_UNAVAILABLE';end if;
 if a.terms_version<>i.quote->>'terms_version' then raise exception 'PRICE_CHANGED';end if;
 select * into pr from public.projects where id=i.project_id and tenant_id=i.tenant_id and customer_account_id=a.id for update;
 if not pr.active or pr.budget_minor-pr.committed_minor<i.total_minor then raise exception 'BUDGET_EXCEEDED';end if;
 for line in select * from jsonb_array_elements(i.quote->'lines') loop
  perform 1 from public.products p join private.test_prices tp on tp.tenant_id=p.tenant_id and tp.product_id=p.id
  where p.tenant_id=i.tenant_id and p.id=(line->>'product_id')::uuid and p.active and p.self_scan and p.unit=line->>'unit'
  and mod((line->>'quantity')::numeric,p.quantity_step)=0 and tp.customer_account_id=a.id and tp.revision=(line->>'price_revision')::int
  and tp.unit_price_minor=(line->>'unit_price_minor')::numeric and tp.vat_bps=(line->>'vat_bps')::int for share of p,tp;
  if not found then raise exception 'PRICE_CHANGED';end if;
 end loop;
 update public.customer_accounts set exposure_minor=exposure_minor+i.total_minor where id=a.id;
 update public.projects set committed_minor=committed_minor+i.total_minor where id=pr.id;
 insert into public.orders(tenant_id,purchase_intent_id,customer_account_id,actor_id,store_id,snapshot,total_minor,mode)
 values(i.tenant_id,i.id,a.id,auth.uid(),i.store_id,i.quote,i.total_minor,'test') returning * into o;
 for line in select * from jsonb_array_elements(i.quote->'lines') loop
 insert into public.order_lines(tenant_id,order_id,product_id,snapshot,quantity,net_minor,vat_minor)
 values(i.tenant_id,o.id,(line->>'product_id')::uuid,line,(line->>'quantity')::numeric,(line->>'net_minor')::bigint,(line->>'vat_minor')::bigint);
 end loop;
 insert into private.credit_reservations(tenant_id,order_id,amount_minor) values(i.tenant_id,o.id,i.total_minor);
 update public.purchase_intents set status='completed' where id=i.id;
 insert into private.outbox(tenant_id,order_id,kind) values(i.tenant_id,o.id,'purchase_confirmation'),(i.tenant_id,o.id,'notification');
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(i.tenant_id,auth.uid(),'purchases.confirm',o.id,p_correlation);
 res:=jsonb_build_object('id',o.id,'purchase_intent_id',i.id,'status','accepted','mode','test','total_minor',o.total_minor::text);
 insert into private.commands values(i.tenant_id,auth.uid(),'confirm',p_key,jsonb_build_object('id',p_id,'body',p_body),res,now());
 return res;
end$$;
create function private.approve(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.purchase_intents;cmd private.commands;res jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(coalesce(auth.uid()::text,'anonymous')||coalesce(p_key,''),0));
 select * into i from public.purchase_intents where id=p_id for update;
 if not found or i.actor_id=auth.uid() or not private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'purchases.approve') then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_body->>'decision' not in ('approved','rejected') then raise exception 'VALIDATION_ERROR';end if;
 select * into cmd from private.commands where tenant_id=i.tenant_id and actor_id=auth.uid() and operation='approve' and key=p_key;
 if found then if cmd.body<>jsonb_build_object('id',p_id,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if i.version is distinct from (p_body->>'version')::int or i.status<>'awaiting_approval' then raise exception 'VERSION_CONFLICT';end if;
 if i.expires_at<=now() then raise exception 'PRICE_CHANGED';end if;
 if not exists(select 1 from public.memberships m join public.role_permissions r on r.role=m.role where r.permission='purchases.approve' and m.user_id=auth.uid() and m.tenant_id=i.tenant_id and m.customer_account_id=i.customer_account_id and (m.store_id is null or m.store_id=i.store_id) and (m.project_id is null or m.project_id=i.project_id) and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and m.per_purchase_minor>=i.total_minor) then raise exception 'BUDGET_EXCEEDED';end if;
 insert into public.approvals(tenant_id,purchase_intent_id,version,actor_id,decision) values(i.tenant_id,i.id,i.version,auth.uid(),p_body->>'decision');
 update public.purchase_intents set status=case when p_body->>'decision'='approved' then 'ready_for_confirmation' else 'rejected' end where id=i.id;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(i.tenant_id,auth.uid(),'purchases.approve',i.id,p_correlation);
 res:=jsonb_build_object('id',i.id,'decision',p_body->>'decision');
 insert into private.commands values(i.tenant_id,auth.uid(),'approve',p_key,jsonb_build_object('id',p_id,'body',p_body),res,now());return res;
end$$;
create function public.get_context() returns jsonb language sql security invoker set search_path='' as $$select private.context()$$;
create function public.lookup_products(p_tenant uuid,p_query text) returns jsonb language sql security invoker set search_path='' as $$select private.catalog(p_tenant,p_query)$$;
create function public.prepare_purchase(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.prepare(p_body,p_key,p_correlation)$$;
create function public.confirm_purchase(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.confirm(p_id,p_body,p_key,p_correlation)$$;
create function public.decide_approval(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.approve(p_id,p_body,p_key,p_correlation)$$;
create function public.get_purchase_intent(p_id uuid) returns jsonb language sql security invoker set search_path='' as $$
 select jsonb_build_object('id',i.id,'tenant_id',i.tenant_id,'customer_account_id',i.customer_account_id,'store_id',i.store_id,'project_id',i.project_id,'version',i.version,'status',i.status,'quote',i.quote,'quote_hash',i.quote_hash,'expires_at',i.expires_at,'order',(select jsonb_build_object('id',o.id,'status',o.status,'total_minor',o.total_minor::text) from public.orders o where o.purchase_intent_id=i.id)) from public.purchase_intents i where i.id=p_id
$$;
create function public.list_purchase_intents() returns jsonb language sql security invoker set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select i.id,i.tenant_id,i.customer_account_id,i.store_id,i.project_id,i.version,i.status,i.total_minor::text,i.created_at from public.purchase_intents i order by i.created_at desc,i.id limit 50)x
$$;
create function private.quota() returns boolean language plpgsql security definer set search_path='' as $$
declare n int;begin
 if auth.uid() is null then return false;end if;
 insert into private.api_quotas as q values(auth.uid(),date_trunc('minute',now()),1)
 on conflict(user_id) do update set window_start=excluded.window_start,count=case when q.window_start=excluded.window_start then q.count+1 else 1 end returning count into n;
 return n<=120;
end$$;
create function public.consume_api_quota() returns boolean language sql security invoker set search_path='' as $$select private.quota()$$;
-- Each helper is a checked business boundary. Private schema is not exposed via PostgREST.
revoke all on all functions in schema public from public,anon,authenticated;
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.allowed(uuid,uuid,uuid,uuid,text),private.can_read_intent(public.purchase_intents),private.context(),private.catalog(uuid,text),private.prepare(jsonb,text,uuid),private.confirm(uuid,jsonb,text,uuid),private.approve(uuid,jsonb,text,uuid),private.quota() to authenticated;
grant execute on function public.get_context(),public.lookup_products(uuid,text),public.prepare_purchase(jsonb,text,uuid),public.confirm_purchase(uuid,jsonb,text,uuid),public.decide_approval(uuid,jsonb,text,uuid),public.get_purchase_intent(uuid),public.list_purchase_intents(),public.consume_api_quota() to authenticated;
-- Defense in depth on private persistence; accessed only through checked definers / worker.
do $$declare t text;begin for t in select tablename from pg_tables where schemaname='private' loop execute format('alter table private.%I enable row level security',t);end loop;end$$;
