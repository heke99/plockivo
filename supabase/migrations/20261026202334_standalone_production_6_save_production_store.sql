create function private.save_production_store(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;sid uuid;v integer;current_version integer;s public.stores;r jsonb;name_value text;code_value text;begin
 t:=private.production_request(p_body,array['tenant_id','id','version','name','code','sales_paused'],p_key,p_correlation);
 sid:=private.production_uuid(p_body,'id',true);v:=private.production_integer(p_body,'version');name_value:=private.production_text(p_body,'name',1,160);code_value:=private.production_text(p_body,'code',1,80);
 if jsonb_typeof(p_body->'sales_paused') is distinct from 'boolean' or (sid is null and v<>0) then raise exception 'VALIDATION_ERROR';end if;
 perform 1 from public.merchants where id=t and mode='production' for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform 1 from private.production_setups where tenant_id=t for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 if sid is not null then select * into s from public.stores where tenant_id=t and id=sid for update;if not found then raise exception 'NOT_FOUND';end if;end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':production-admin',0));
 r:=private.production_replay(t,'production.store.save',p_body,p_key);if r is not null then return r;end if;
 if sid is null then
  insert into public.stores(tenant_id,name,code,sales_paused) values(t,name_value,code_value,(p_body->>'sales_paused')::boolean) returning * into s;
 else
  select version into current_version from private.production_store_versions where tenant_id=t and store_id=sid;
  if coalesce(current_version,0)<>v then raise exception 'VERSION_CONFLICT';end if;
  update public.stores set name=name_value,code=code_value,sales_paused=(p_body->>'sales_paused')::boolean where tenant_id=t and id=sid returning * into s;
 end if;
 insert into private.production_store_versions(store_id,tenant_id,version) values(s.id,t,v+1)
 on conflict(store_id) do update set version=excluded.version;
 r:=jsonb_build_object('id',s.id,'tenant_id',t,'name',s.name,'code',s.code,'sales_paused',s.sales_paused,'version',v+1);
 perform private.production_record(t,'production.store.save',s.id,p_body,p_key,p_correlation,r);return r;
 exception when unique_violation then raise exception 'VERSION_CONFLICT';
end$$;

revoke all on function private.save_production_store(jsonb,text,uuid) from public,anon,authenticated;
