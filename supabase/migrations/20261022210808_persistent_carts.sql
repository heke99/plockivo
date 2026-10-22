-- FLOW-1004/1007: actor-owned durable carts. No prices or credit decisions in draft writes.
create table public.carts (
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,customer_account_id uuid not null,store_id uuid not null,project_id uuid not null,
 actor_id uuid not null references auth.users(id),version integer not null default 1 check(version>0),
 reference text not null default '' check(length(reference)<=100),status text not null default 'draft' check(status in ('draft','quoted','completed')),
 purchase_intent_id uuid,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(tenant_id,id),
 foreign key(tenant_id,customer_account_id) references public.customer_accounts(tenant_id,id),
 foreign key(tenant_id,store_id) references public.stores(tenant_id,id),
 foreign key(tenant_id,customer_account_id,project_id) references public.projects(tenant_id,customer_account_id,id),
 foreign key(tenant_id,purchase_intent_id) references public.purchase_intents(tenant_id,id)
);
create unique index carts_open_scope_idx on public.carts(tenant_id,customer_account_id,actor_id,store_id,project_id) where status in ('draft','quoted');
create index carts_actor_idx on public.carts(actor_id,updated_at desc);
create index carts_project_idx on public.carts(tenant_id,customer_account_id,project_id);
create index carts_store_idx on public.carts(tenant_id,store_id);
create index carts_intent_idx on public.carts(tenant_id,purchase_intent_id);
create table public.cart_lines (
 tenant_id uuid not null,cart_id uuid not null,product_id uuid not null,position smallint not null check(position between 1 and 100),
 quantity numeric(20,6) not null check(quantity>0 and quantity<=999999.999999),primary key(cart_id,product_id),unique(cart_id,position),
 foreign key(tenant_id,cart_id) references public.carts(tenant_id,id),foreign key(tenant_id,product_id) references public.products(tenant_id,id)
);
create index cart_lines_parent_idx on public.cart_lines(tenant_id,cart_id);
create index cart_lines_product_idx on public.cart_lines(tenant_id,product_id);
create table private.cart_quotes (
 tenant_id uuid not null,cart_id uuid not null,version integer not null,purchase_intent_id uuid not null unique,
 primary key(cart_id,version),foreign key(tenant_id,cart_id) references public.carts(tenant_id,id),
 foreign key(tenant_id,purchase_intent_id) references public.purchase_intents(tenant_id,id)
);
alter table public.carts enable row level security;
alter table public.cart_lines enable row level security;
alter table private.cart_quotes enable row level security;
revoke all on public.carts,public.cart_lines,private.cart_quotes from public,anon,authenticated;
-- Tables intentionally have no direct app grants. Every operation rechecks current mandate and owner.
alter table public.purchase_intents add column invalidated_at timestamptz,add column invalidated_reason text;
create function private.cart_dto(p_cart uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.id,'tenant_id',c.tenant_id,'customer_account_id',c.customer_account_id,'store_id',c.store_id,'project_id',c.project_id,
 'version',c.version,'reference',c.reference,'status',c.status,'updated_at',c.updated_at,'intent',case when c.purchase_intent_id is null then null else public.get_purchase_intent(c.purchase_intent_id) end,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('quantity',l.quantity::text,'product',jsonb_build_object('id',p.id,'sku',p.sku,'name',p.name,'unit',p.unit,'quantity_step',p.quantity_step::text,'self_scan',p.self_scan and p.active,
 'barcodes',coalesce((select jsonb_agg(jsonb_build_object('code',b.code,'package_quantity',b.package_quantity::text)) from public.product_barcodes b where b.tenant_id=p.tenant_id and b.product_id=p.id),'[]'))) order by l.position)
 from public.cart_lines l join public.products p on p.id=l.product_id and p.tenant_id=l.tenant_id where l.cart_id=c.id and l.tenant_id=c.tenant_id),'[]')) from public.carts c where c.id=p_cart
$$;
create function private.current_cart(p_tenant uuid,p_account uuid,p_store uuid,p_project uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare id uuid;begin
 if not private.allowed(p_tenant,p_account,p_store,p_project,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 select c.id into id from public.carts c where c.tenant_id=p_tenant and c.customer_account_id=p_account and c.store_id=p_store and c.project_id=p_project and c.actor_id=auth.uid() and c.status in ('draft','quoted');
 return private.cart_dto(id);
end$$;
create function private.save_cart(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid:=(p_body->>'tenant_id')::uuid;a uuid:=(p_body->>'customer_account_id')::uuid;s uuid:=(p_body->>'store_id')::uuid;pr uuid:=(p_body->>'project_id')::uuid;
 c public.carts;prev public.carts;i public.purchase_intents;cmd private.commands;item jsonb;prod public.products;q numeric;pos smallint:=0;res jsonb;
begin
 if not private.allowed(t,a,s,pr,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or p_key!~'^[a-zA-Z0-9:_-]{16,128}$' or jsonb_typeof(p_body) is distinct from 'object' or jsonb_typeof(p_body->'lines') is distinct from 'array' or jsonb_array_length(p_body->'lines')>100
 or jsonb_typeof(p_body->'reference') is distinct from 'string' or length(p_body->>'reference')>100 or (p_body->>'version') is null then raise exception 'VALIDATION_ERROR';end if;
 -- Lock order: command key -> actor/scope -> cart -> prior intent -> product rows.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||'cart.save'||p_key,0));
 perform pg_advisory_xact_lock(hashtextextended(t::text||a::text||s::text||pr::text||auth.uid()::text,0));
 select * into cmd from private.commands where tenant_id=t and actor_id=auth.uid() and operation='cart.save' and key=p_key;
 if found then if cmd.body is distinct from p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if not exists(select 1 from public.customer_accounts where id=a and tenant_id=t and status='active') or not exists(select 1 from public.stores where id=s and tenant_id=t) or not exists(select 1 from public.projects where id=pr and tenant_id=t and customer_account_id=a and active) then raise exception 'PERMISSION_DENIED';end if;
 if p_body->>'id' is null then
  if (p_body->>'version')::int<>0 then raise exception 'VERSION_CONFLICT';end if;
  select * into prev from public.carts where tenant_id=t and customer_account_id=a and store_id=s and project_id=pr and actor_id=auth.uid() and status in ('draft','quoted') for update;
  if found then
   if not exists(select 1 from public.purchase_intents where id=prev.purchase_intent_id and tenant_id=t and status='completed') then raise exception 'VERSION_CONFLICT';end if;
   update public.carts set status='completed',updated_at=now() where id=prev.id;
  end if;
  insert into public.carts(tenant_id,customer_account_id,store_id,project_id,actor_id,reference) values(t,a,s,pr,auth.uid(),p_body->>'reference') returning * into c;
 else
  select * into c from public.carts where id=(p_body->>'id')::uuid and tenant_id=t and customer_account_id=a and store_id=s and project_id=pr and actor_id=auth.uid() for update;
  if not found then raise exception 'PERMISSION_DENIED';end if;
  if c.version is distinct from (p_body->>'version')::int or c.status='completed' then raise exception 'VERSION_CONFLICT';end if;
  if c.purchase_intent_id is not null then
   select * into i from public.purchase_intents where id=c.purchase_intent_id and tenant_id=t for update;
   if i.status='completed' then raise exception 'VERSION_CONFLICT';end if;
   update public.purchase_intents set status='rejected',invalidated_at=now(),invalidated_reason='cart_revision_changed' where id=i.id;
   insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),'carts.invalidate_quote',i.id,p_correlation);
  end if;
  update public.carts set version=version+1,reference=p_body->>'reference',status='draft',purchase_intent_id=null,updated_at=now() where id=c.id returning * into c;
  delete from public.cart_lines where cart_id=c.id and tenant_id=t;
 end if;
 if jsonb_array_length(p_body->'lines')<>(select count(distinct x->>'product_id') from jsonb_array_elements(p_body->'lines')x) then raise exception 'VALIDATION_ERROR';end if;
 for item in select * from jsonb_array_elements(p_body->'lines') loop
  if jsonb_typeof(item) is distinct from 'object' or jsonb_typeof(item->'quantity') is distinct from 'string' or (item->>'quantity')!~'^(0|[1-9][0-9]{0,5})(\.[0-9]{1,6})?$' then raise exception 'VALIDATION_ERROR';end if;
  q:=(item->>'quantity')::numeric;
  select * into prod from public.products where id=(item->>'product_id')::uuid and tenant_id=t and active and self_scan for share;
  if not found or q<=0 or mod(q,prod.quantity_step)<>0 then raise exception 'VALIDATION_ERROR';end if;
  pos:=pos+1;insert into public.cart_lines values(t,c.id,prod.id,pos,q);
 end loop;
 res:=private.cart_dto(c.id);
 insert into private.commands values(t,auth.uid(),'cart.save',p_key,p_body,res,now());
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),'carts.save',c.id,p_correlation);
 return res;
end$$;
create function private.submit_cart(p_id uuid,p_version int,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.carts;cmd private.commands;body jsonb;res jsonb;existing uuid;begin
 if auth.uid() is null or p_key is null or p_key!~'^[a-zA-Z0-9:_-]{16,128}$' or p_version is null then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||'cart.submit'||p_key,0));
 select * into c from public.carts where id=p_id for update;
 if not found or c.actor_id is distinct from auth.uid() or not private.allowed(c.tenant_id,c.customer_account_id,c.store_id,c.project_id,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 body:=jsonb_build_object('id',p_id,'version',p_version);
 select * into cmd from private.commands where tenant_id=c.tenant_id and actor_id=auth.uid() and operation='cart.submit' and key=p_key;
 if found then if cmd.body is distinct from body then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if c.version<>p_version or c.status='completed' then raise exception 'VERSION_CONFLICT';end if;
 select purchase_intent_id into existing from private.cart_quotes where cart_id=c.id and version=c.version;
 if found then res:=public.get_purchase_intent(existing);
 else
  body:=jsonb_build_object('tenant_id',c.tenant_id,'customer_account_id',c.customer_account_id,'store_id',c.store_id,'project_id',c.project_id,'reference',c.reference,
   'lines',coalesce((select jsonb_agg(jsonb_build_object('product_id',l.product_id,'quantity',l.quantity::text) order by l.position) from public.cart_lines l where l.cart_id=c.id and l.tenant_id=c.tenant_id),'[]'));
  res:=private.prepare(body,'cart:'||c.id::text||':'||c.version::text,p_correlation);
  existing:=(res->>'id')::uuid;
  insert into private.cart_quotes values(c.tenant_id,c.id,c.version,existing);
  update public.carts set status='quoted',purchase_intent_id=existing,updated_at=now() where id=c.id;
 end if;
 insert into private.commands values(c.tenant_id,auth.uid(),'cart.submit',p_key,jsonb_build_object('id',p_id,'version',p_version),res,now());
 return res;
end$$;
create function public.get_current_cart(p_tenant uuid,p_account uuid,p_store uuid,p_project uuid) returns jsonb language sql security invoker set search_path='' as $$select private.current_cart(p_tenant,p_account,p_store,p_project)$$;
create function public.save_cart(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.save_cart(p_body,p_key,p_correlation)$$;
create function public.submit_cart(p_id uuid,p_version int,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.submit_cart(p_id,p_version,p_key,p_correlation)$$;
revoke all on function private.cart_dto(uuid),private.current_cart(uuid,uuid,uuid,uuid),private.save_cart(jsonb,text,uuid),private.submit_cart(uuid,int,text,uuid),public.get_current_cart(uuid,uuid,uuid,uuid),public.save_cart(jsonb,text,uuid),public.submit_cart(uuid,int,text,uuid) from public,anon,authenticated;
grant execute on function private.current_cart(uuid,uuid,uuid,uuid),private.save_cart(jsonb,text,uuid),private.submit_cart(uuid,int,text,uuid),public.get_current_cart(uuid,uuid,uuid,uuid),public.save_cart(jsonb,text,uuid),public.submit_cart(uuid,int,text,uuid) to authenticated;
