create function private.save_production_setup(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;v integer;m public.merchants;s private.production_setups;r jsonb;reason_value text;evidence text;begin
 t:=private.production_request(p_body,array['tenant_id','version','price_authority','credit_authority','inventory_authority','billing_authority','activate_production','sales_enabled','reason','evidence_reference'],p_key,p_correlation);
 v:=private.production_integer(p_body,'version');reason_value:=private.production_text(p_body,'reason',10,1000);evidence:=private.production_text(p_body,'evidence_reference',1,200);
 if p_body->>'price_authority' is distinct from 'plockivo' or p_body->>'credit_authority' is distinct from 'merchant-manual' or p_body->>'inventory_authority' is distinct from 'plockivo' or p_body->>'billing_authority' is distinct from 'manual-export'
 or jsonb_typeof(p_body->'activate_production') is distinct from 'boolean' or jsonb_typeof(p_body->'sales_enabled') is distinct from 'boolean' then raise exception 'VALIDATION_ERROR';end if;
 select * into m from public.merchants where id=t for update;if not found then raise exception 'NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':production-admin',0));
 r:=private.production_replay(t,'production.setup.save',p_body,p_key);if r is not null then return r;end if;
 select * into s from private.production_setups where tenant_id=t;
 if coalesce(s.version,0)<>v then raise exception 'VERSION_CONFLICT';end if;
 if m.mode<>'production' then
  if not (p_body->>'activate_production')::boolean then raise exception 'INTEGRATION_NOT_READY';end if;
  if exists(select 1 from public.purchase_intents where tenant_id=t) or exists(select 1 from public.orders where tenant_id=t)
   or exists(select 1 from public.customer_accounts where tenant_id=t and exposure_minor<>0)
   or exists(select 1 from private.credit_reservations cr join public.orders o on o.id=cr.order_id where o.tenant_id=t)
  then raise exception 'INTEGRATION_NOT_READY';end if;
 end if;
 update public.merchants set mode='production',sales_paused=not (p_body->>'sales_enabled')::boolean where id=t;
 insert into private.production_setups(tenant_id,version,price_authority,credit_authority,inventory_authority,billing_authority,reason,evidence_reference,updated_at)
 values(t,v+1,'plockivo','merchant-manual','plockivo','manual-export',reason_value,evidence,now())
 on conflict(tenant_id) do update set version=excluded.version,reason=excluded.reason,evidence_reference=excluded.evidence_reference,updated_at=excluded.updated_at;
 r:=private.get_production_setup(t);perform private.production_record(t,'production.setup.save',t,p_body,p_key,p_correlation,r);return r;
end$$;

revoke all on function private.save_production_setup(jsonb,text,uuid) from public,anon,authenticated;
