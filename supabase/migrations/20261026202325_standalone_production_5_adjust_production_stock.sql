create function private.adjust_production_stock(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;store_value uuid;product_value uuid;v integer;q numeric(20,6);s private.production_stock;previous numeric(20,6);r jsonb;reason_value text;evidence text;begin
 t:=private.production_request(p_body,array['tenant_id','store_id','product_id','version','on_hand','reason','evidence_reference'],p_key,p_correlation);
 store_value:=private.production_uuid(p_body,'store_id');product_value:=private.production_uuid(p_body,'product_id');v:=private.production_integer(p_body,'version');reason_value:=private.production_text(p_body,'reason',10,1000);evidence:=private.production_text(p_body,'evidence_reference',1,200);
 if jsonb_typeof(p_body->'on_hand') is distinct from 'string' or coalesce(p_body->>'on_hand','') !~ '^(0|[1-9][0-9]{0,11})(\.[0-9]{1,6})?$' then raise exception 'VALIDATION_ERROR';end if;q:=(p_body->>'on_hand')::numeric;
 perform 1 from public.merchants where id=t and mode='production' for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform 1 from private.production_setups where tenant_id=t for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform 1 from public.stores where tenant_id=t and id=store_value for share;if not found then raise exception 'NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':production-admin',0));
 perform 1 from public.products p join private.production_catalog_map map on map.tenant_id=p.tenant_id and map.product_id=p.id where p.tenant_id=t and p.id=product_value for share of p;if not found then raise exception 'NOT_FOUND';end if;
 r:=private.production_replay(t,'production.stock.adjust',p_body,p_key);if r is not null then return r;end if;
 select * into s from private.production_stock where tenant_id=t and store_id=store_value and product_id=product_value for update;
 if coalesce(s.version,0)<>v then raise exception 'VERSION_CONFLICT';end if;
 if q<coalesce(s.reserved,0) then raise exception 'QUANTITY_CONFLICT';end if;previous:=coalesce(s.on_hand,0);
 insert into private.production_stock(tenant_id,store_id,product_id,on_hand,reserved,version) values(t,store_value,product_value,q,coalesce(s.reserved,0),v+1)
 on conflict(tenant_id,store_id,product_id) do update set on_hand=excluded.on_hand,version=excluded.version returning * into s;
 insert into private.production_stock_adjustments(tenant_id,store_id,product_id,actor_id,previous_on_hand,new_on_hand,reserved,stock_version,reason,evidence_reference,correlation_id)
 values(t,store_value,product_value,auth.uid(),previous,s.on_hand,s.reserved,s.version,reason_value,evidence,p_correlation);
 r:=jsonb_build_object('tenant_id',t,'store_id',store_value,'product_id',product_value,'on_hand',s.on_hand::text,'reserved',s.reserved::text,'version',s.version);
 perform private.production_record(t,'production.stock.adjust',product_value,p_body,p_key,p_correlation,r);return r;
end$$;

revoke all on function private.adjust_production_stock(jsonb,text,uuid) from public,anon,authenticated;
