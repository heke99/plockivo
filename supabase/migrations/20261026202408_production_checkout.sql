-- PRODUCTION-046: explicit standalone production authority, same cart/approval/order contracts.
-- Keep the deployed synthetic implementation intact; authenticated callers use the dispatchers only.
alter function private.prepare(jsonb,text,uuid) rename to prepare_synthetic;
alter function private.confirm(uuid,jsonb,text,uuid) rename to confirm_synthetic;
revoke all on function private.prepare_synthetic(jsonb,text,uuid),private.confirm_synthetic(uuid,jsonb,text,uuid) from public,anon,authenticated;
alter table public.orders drop constraint orders_mode_check;
alter table public.orders add constraint orders_mode_check check(mode in ('test','production'));
create function private.production_prepare(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid:=(p_body->>'tenant_id')::uuid;a uuid:=(p_body->>'customer_account_id')::uuid;s uuid:=(p_body->>'store_id')::uuid;pr uuid:=(p_body->>'project_id')::uuid;
 m public.memberships;item jsonb;prod public.products;price private.production_prices;cfg private.production_setups;stock private.production_stock;account public.customer_accounts;project public.projects;q numeric;net bigint;vat bigint;total bigint:=0;lines jsonb:='[]';quote jsonb;i public.purchase_intents;cmd private.commands;res jsonb;requires_approval boolean;
begin
 if not private.allowed(t,a,s,pr,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_key!~'^[a-zA-Z0-9:_-]+$' or jsonb_typeof(p_body) is distinct from 'object' or jsonb_typeof(p_body->'reference') is distinct from 'string' or jsonb_typeof(p_body->'lines') is distinct from 'array' or jsonb_array_length(p_body->'lines') not between 1 and 100 or length(trim(p_body->>'reference')) not between 1 and 100 then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||auth.uid()::text||'prepare'||p_key,0));
 select * into cmd from private.commands where tenant_id=t and actor_id=auth.uid() and operation='prepare' and key=p_key;
 if found then if cmd.body<>p_body then raise exception 'IDEMPOTENCY_CONFLICT';end if;if cmd.result->>'mode' is distinct from 'production' then raise exception 'PRICE_CHANGED';end if;return cmd.result;end if;
 select mm.* into m from public.memberships mm join public.role_permissions rp on rp.role=mm.role and rp.permission='purchases.checkout'
 where mm.user_id=auth.uid() and mm.tenant_id=t and mm.customer_account_id=a and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and (mm.store_id is null or mm.store_id=s) and (mm.project_id is null or mm.project_id=pr) order by mm.per_purchase_minor desc limit 1 for share of mm;
 if not found then raise exception 'BUDGET_EXCEEDED';end if;
 perform 1 from public.merchants where id=t and mode='production' and not sales_paused for share;
 if not found then raise exception 'SALES_PAUSED';end if;
 perform 1 from public.stores where tenant_id=t and id=s and not sales_paused for share;
 if not found then raise exception 'SALES_PAUSED';end if;
 select * into account from public.customer_accounts where tenant_id=t and id=a for update;
 if not found or account.status<>'active' or account.purchase_blocked or account.terms_version is null then raise exception 'CREDIT_UNAVAILABLE';end if;
 select * into project from public.projects where tenant_id=t and customer_account_id=a and id=pr and active for update;
 if not found then raise exception 'BUDGET_EXCEEDED';end if;
 select * into cfg from private.production_setups where tenant_id=t for share;
 if not found or cfg.price_authority<>'plockivo' or cfg.credit_authority<>'merchant-manual' or cfg.inventory_authority<>'plockivo' or cfg.billing_authority<>'manual-export' then raise exception 'INTEGRATION_NOT_READY';end if;
 if (select count(*) from jsonb_array_elements(p_body->'lines'))<>(select count(distinct x->>'product_id') from jsonb_array_elements(p_body->'lines')x) then raise exception 'VALIDATION_ERROR';end if;
 for item in select value from jsonb_array_elements(p_body->'lines') order by value->>'product_id' loop
  if jsonb_typeof(item) is distinct from 'object' or jsonb_typeof(item->'quantity') is distinct from 'string' or (item->>'quantity')!~'^(0|[1-9][0-9]{0,5})([.][0-9]{1,6})?$' then raise exception 'VALIDATION_ERROR';end if;
  q:=(item->>'quantity')::numeric;
  select * into prod from public.products where tenant_id=t and id=(item->>'product_id')::uuid and active and self_scan for share;
  if not found or q<=0 or mod(q,prod.quantity_step)<>0 then raise exception 'VALIDATION_ERROR';end if;
  select * into price from private.production_prices where tenant_id=t and customer_account_id=a and product_id=prod.id for share;
  if not found then raise exception 'INTEGRATION_NOT_READY';end if;
  net:=round(q*price.unit_price_minor);vat:=round(net::numeric*price.vat_bps/10000);total:=total+net+vat;
  lines:=lines||jsonb_build_array(jsonb_build_object('product_id',prod.id,'sku',prod.sku,'name',prod.name,'unit',prod.unit,'quantity',q::text,'unit_price_minor',price.unit_price_minor::text,'vat_bps',price.vat_bps,'net_minor',net::text,'vat_minor',vat::text,'price_revision',price.revision));
 end loop;
 if account.credit_limit_minor-account.exposure_minor<total then raise exception 'CREDIT_UNAVAILABLE';end if;
 if project.budget_minor-project.committed_minor<total then raise exception 'BUDGET_EXCEEDED';end if;
 if total<=0 or total>10000000000 then raise exception 'VALIDATION_ERROR';end if;
 if total>m.per_purchase_minor then raise exception 'BUDGET_EXCEEDED';end if;
 for item in select value from jsonb_array_elements(lines) order by value->>'product_id' loop
  select * into stock from private.production_stock where tenant_id=t and store_id=s and product_id=(item->>'product_id')::uuid for share;
  if not found or stock.on_hand-stock.reserved<(item->>'quantity')::numeric then raise exception 'STOCK_UNAVAILABLE';end if;
 end loop;
 requires_approval:=total>m.approval_threshold_minor;
 quote:=jsonb_build_object('lines',lines,'total_minor',total::text,'currency','SEK','reference',p_body->>'reference','terms_version',(select terms_version from public.customer_accounts where id=a),'seller',(select jsonb_build_object('name',legal_name,'organization_number',organization_number) from public.merchants where id=t),'buyer',(select jsonb_build_object('name',name,'organization_number',organization_number) from public.customer_accounts where id=a),'price_authority','plockivo-standalone','credit_authority',cfg.credit_authority,'inventory_authority',cfg.inventory_authority,'billing_authority',cfg.billing_authority,'configuration_version',cfg.version,'store_id',s,'customer_account_id',a,'project_id',pr,'rounding','row_net_then_row_vat_half_up');
 insert into public.purchase_intents(tenant_id,customer_account_id,store_id,project_id,actor_id,status,request,quote,quote_hash,total_minor,expires_at)
 values(t,a,s,pr,auth.uid(),case when requires_approval then 'awaiting_approval' else 'ready_for_confirmation' end,p_body,quote,md5(quote::text),total,now()+interval '15 minutes') returning * into i;
 res:=jsonb_build_object('id',i.id,'version',i.version,'status',i.status,'quote',quote,'quote_hash',i.quote_hash,'expires_at',i.expires_at,'mode','production');
 insert into private.commands values(t,auth.uid(),'prepare',p_key,p_body,res,now());
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),'purchases.prepare',i.id,p_correlation);
 return res;
end$$;
create function private.production_confirm(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.purchase_intents;a public.customer_accounts;pr public.projects;m public.memberships;cmd private.commands;o public.orders;res jsonb;line jsonb;cfg private.production_setups;stock private.production_stock;
begin
 perform pg_advisory_xact_lock(hashtextextended(coalesce(auth.uid()::text,'anonymous')||coalesce(p_key,''),0));
 select * into i from public.purchase_intents where id=p_id for update;
 if not found or i.actor_id<>auth.uid() or not private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'purchases.checkout') then raise exception 'PERMISSION_DENIED';end if;
 if i.quote->>'price_authority' is distinct from 'plockivo-standalone' then raise exception 'PRICE_CHANGED';end if;
 if p_key is null or length(p_key) not between 16 and 128 or p_key!~'^[a-zA-Z0-9:_-]+$' or jsonb_typeof(p_body) is distinct from 'object' then raise exception 'VALIDATION_ERROR';end if;
 select mm.* into m from public.memberships mm join public.role_permissions rp on rp.role=mm.role and rp.permission='purchases.checkout'
 where mm.user_id=auth.uid() and mm.tenant_id=i.tenant_id and mm.customer_account_id=i.customer_account_id and mm.status='active' and mm.valid_from<=now() and (mm.valid_to is null or mm.valid_to>now()) and (mm.store_id is null or mm.store_id=i.store_id) and (mm.project_id is null or mm.project_id=i.project_id) order by mm.per_purchase_minor desc limit 1 for share of mm;
 if not found then raise exception 'MEMBERSHIP_INACTIVE';end if;
 select * into cmd from private.commands where tenant_id=i.tenant_id and actor_id=auth.uid() and operation='confirm' and key=p_key;
 if found then if cmd.body<>jsonb_build_object('id',p_id,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;if cmd.result->>'mode' is distinct from 'production' then raise exception 'PRICE_CHANGED';end if;return cmd.result;end if;
 if i.version is distinct from (p_body->>'version')::int then raise exception 'VERSION_CONFLICT';end if;
 if i.quote_hash is distinct from (p_body->>'quote_hash') then raise exception 'PRICE_CHANGED';end if;
 select * into o from public.orders where purchase_intent_id=i.id;
 if found then return jsonb_build_object('id',o.id,'purchase_intent_id',i.id,'status','accepted','mode','production','total_minor',o.total_minor::text);end if;
 if i.expires_at<=now() then raise exception 'PRICE_CHANGED';end if;
 if i.status='awaiting_approval' or (i.total_minor>m.approval_threshold_minor and not exists(select 1 from public.approvals where purchase_intent_id=i.id and version=i.version and decision='approved' and actor_id<>auth.uid())) then raise exception 'APPROVAL_REQUIRED';end if;
 if i.status<>'ready_for_confirmation' then raise exception 'VERSION_CONFLICT';end if;
 if i.total_minor>m.per_purchase_minor then raise exception 'BUDGET_EXCEEDED';end if;
 perform 1 from public.merchants where id=i.tenant_id and mode='production' for share;
 if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 if exists(select 1 from public.merchants where id=i.tenant_id and sales_paused) then raise exception 'SALES_PAUSED';end if;
 perform 1 from public.stores where id=i.store_id and not sales_paused for share;
 if not found then raise exception 'SALES_PAUSED';end if;
 -- Fixed lock order: intent -> membership -> merchant/store -> account -> project -> setup -> products/prices -> stock.
 select * into a from public.customer_accounts where id=i.customer_account_id and tenant_id=i.tenant_id for update;
 if not found or a.status<>'active' or a.purchase_blocked or a.terms_version is null or a.credit_limit_minor-a.exposure_minor<i.total_minor then raise exception 'CREDIT_UNAVAILABLE';end if;
 if a.terms_version<>i.quote->>'terms_version' then raise exception 'PRICE_CHANGED';end if;
 select * into pr from public.projects where id=i.project_id and tenant_id=i.tenant_id and customer_account_id=a.id for update;
 if not found or not pr.active or pr.budget_minor-pr.committed_minor<i.total_minor then raise exception 'BUDGET_EXCEEDED';end if;
 select * into cfg from private.production_setups where tenant_id=i.tenant_id for share;
 if not found or cfg.price_authority<>'plockivo' or cfg.credit_authority<>'merchant-manual' or cfg.inventory_authority<>'plockivo' or cfg.billing_authority<>'manual-export' then raise exception 'INTEGRATION_NOT_READY';end if;
 if cfg.version is distinct from (i.quote->>'configuration_version')::integer then raise exception 'PRICE_CHANGED';end if;
 for line in select value from jsonb_array_elements(i.quote->'lines') order by value->>'product_id' loop
  perform 1 from public.products p join private.production_prices tp on tp.tenant_id=p.tenant_id and tp.product_id=p.id
  where p.tenant_id=i.tenant_id and p.id=(line->>'product_id')::uuid and p.active and p.self_scan and p.unit=line->>'unit' and p.sku=line->>'sku' and p.name=line->>'name'
  and mod((line->>'quantity')::numeric,p.quantity_step)=0 and tp.customer_account_id=a.id and tp.revision=(line->>'price_revision')::int
  and tp.unit_price_minor=(line->>'unit_price_minor')::numeric and tp.vat_bps=(line->>'vat_bps')::int for share of p,tp;
  if not found then raise exception 'PRICE_CHANGED';end if;
 end loop;
 -- All stock rows lock in product-id order, after account/project and current prices.
 for line in select value from jsonb_array_elements(i.quote->'lines') order by value->>'product_id' loop
  select * into stock from private.production_stock where tenant_id=i.tenant_id and store_id=i.store_id and product_id=(line->>'product_id')::uuid for update;
  if not found or stock.on_hand-stock.reserved<(line->>'quantity')::numeric then raise exception 'STOCK_UNAVAILABLE';end if;
 end loop;
 update public.customer_accounts set exposure_minor=exposure_minor+i.total_minor where id=a.id;
 update public.projects set committed_minor=committed_minor+i.total_minor where id=pr.id;
 insert into public.orders(tenant_id,purchase_intent_id,customer_account_id,actor_id,store_id,snapshot,total_minor,mode)
 values(i.tenant_id,i.id,a.id,auth.uid(),i.store_id,i.quote,i.total_minor,'production') returning * into o;
 for line in select value from jsonb_array_elements(i.quote->'lines') order by value->>'product_id' loop
 insert into public.order_lines(tenant_id,order_id,product_id,snapshot,quantity,net_minor,vat_minor)
 values(i.tenant_id,o.id,(line->>'product_id')::uuid,line,(line->>'quantity')::numeric,(line->>'net_minor')::bigint,(line->>'vat_minor')::bigint);
 end loop;
 for line in select value from jsonb_array_elements(i.quote->'lines') order by value->>'product_id' loop
  update private.production_stock set reserved=reserved+(line->>'quantity')::numeric,version=version+1
  where tenant_id=i.tenant_id and store_id=i.store_id and product_id=(line->>'product_id')::uuid;
 end loop;
 insert into private.credit_reservations(tenant_id,order_id,amount_minor) values(i.tenant_id,o.id,i.total_minor);
 update public.purchase_intents set status='completed' where id=i.id;
 insert into public.documents(tenant_id,order_id,kind,template_version,content,content_hash)
 values(i.tenant_id,o.id,'purchase_confirmation','standalone-json-v1',o.snapshot,md5(o.snapshot::text));
 -- Production JSON confirmation is synchronous. No synthetic worker or email delivery claim.
 insert into private.outbox(tenant_id,order_id,kind,status) values(i.tenant_id,o.id,'notification','manual_review');
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(i.tenant_id,auth.uid(),'purchases.confirm',o.id,p_correlation);
 res:=jsonb_build_object('id',o.id,'purchase_intent_id',i.id,'status','accepted','mode','production','total_minor',o.total_minor::text);
 insert into private.commands values(i.tenant_id,auth.uid(),'confirm',p_key,jsonb_build_object('id',p_id,'body',p_body),res,now());
 return res;
end$$;

create function private.prepare(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare mode text;res jsonb;
begin
 if not private.allowed((p_body->>'tenant_id')::uuid,(p_body->>'customer_account_id')::uuid,(p_body->>'store_id')::uuid,(p_body->>'project_id')::uuid,'purchases.prepare') then raise exception 'PERMISSION_DENIED';end if;
 select m.mode into mode from public.merchants m where m.id=(p_body->>'tenant_id')::uuid;
 if mode='production' then res:=private.production_prepare(p_body,p_key,p_correlation);
 elsif mode='test' then res:=private.prepare_synthetic(p_body,p_key,p_correlation);
 else raise exception 'INTEGRATION_NOT_READY';end if;
 if res->>'mode' is distinct from mode then raise exception 'PRICE_CHANGED';end if;
 return res;
end$$;
create function private.confirm(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.purchase_intents;mode text;
begin
 select * into i from public.purchase_intents where id=p_id;
 if not found or i.actor_id<>auth.uid() or not private.allowed(i.tenant_id,i.customer_account_id,i.store_id,i.project_id,'purchases.checkout') then raise exception 'PERMISSION_DENIED';end if;
 select m.mode into mode from public.merchants m where m.id=i.tenant_id;
 if mode='production' and i.quote->>'price_authority'='plockivo-standalone' then return private.production_confirm(p_id,p_body,p_key,p_correlation);
 elsif mode='test' and i.quote->>'price_authority'='synthetic-test-adapter' then return private.confirm_synthetic(p_id,p_body,p_key,p_correlation);
 else raise exception 'PRICE_CHANGED';end if;
end$$;
-- Rebind SQL wrapper bodies to the new named dispatcher, retaining their OIDs/grants.
create or replace function public.prepare_purchase(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.prepare(p_body,p_key,p_correlation)$$;
create or replace function public.confirm_purchase(p_id uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.confirm(p_id,p_body,p_key,p_correlation)$$;
revoke all on function private.production_prepare(jsonb,text,uuid),private.production_confirm(uuid,jsonb,text,uuid),private.prepare(jsonb,text,uuid),private.confirm(uuid,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.prepare(jsonb,text,uuid),private.confirm(uuid,jsonb,text,uuid) to authenticated;
-- Clear cached PL/pgSQL plans which could retain the renamed synthetic function OID.
-- Read the deployed definition rather than overwrite later cart/security hardening.
do $$begin
 execute pg_get_functiondef('private.submit_cart(uuid,integer,text,uuid)'::regprocedure);
end$$;
-- Preserve scope/RLS and derive provenance from the frozen quote, never current merchant mode.
create or replace function public.get_purchase_intent(p_id uuid) returns jsonb language sql security invoker set search_path='' as $$
 select jsonb_build_object('id',i.id,'tenant_id',i.tenant_id,'customer_account_id',i.customer_account_id,'store_id',i.store_id,'project_id',i.project_id,
 'mode',case when i.quote->>'price_authority'='plockivo-standalone' then 'production' else 'test' end,
 'version',i.version,'status',i.status,'quote',i.quote,'quote_hash',i.quote_hash,'expires_at',i.expires_at,
 'order',(select jsonb_build_object('id',o.id,'status',o.status,'mode',o.mode,'total_minor',o.total_minor::text) from public.orders o where o.purchase_intent_id=i.id))
 from public.purchase_intents i where i.id=p_id
$$;
