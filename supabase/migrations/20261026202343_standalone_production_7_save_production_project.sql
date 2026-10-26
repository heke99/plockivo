create function private.save_production_project(p_body jsonb,p_key text,p_correlation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;pid uuid;account_value uuid;v integer;current_version integer;p public.projects;r jsonb;name_value text;budget bigint;begin
 t:=private.production_request(p_body,array['tenant_id','id','version','customer_account_id','name','budget_minor','active'],p_key,p_correlation);
 pid:=private.production_uuid(p_body,'id',true);account_value:=private.production_uuid(p_body,'customer_account_id');v:=private.production_integer(p_body,'version');name_value:=private.production_text(p_body,'name',1,160);budget:=private.production_money(p_body,'budget_minor');
 if jsonb_typeof(p_body->'active') is distinct from 'boolean' or (pid is null and v<>0) then raise exception 'VALIDATION_ERROR';end if;
 perform 1 from public.merchants where id=t and mode='production' for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform 1 from public.customer_accounts where tenant_id=t and id=account_value for update;if not found then raise exception 'NOT_FOUND';end if;
 perform 1 from private.production_setups where tenant_id=t for share;if not found then raise exception 'INTEGRATION_NOT_READY';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||':production-admin',0));
 r:=private.production_replay(t,'production.project.save',p_body,p_key);if r is not null then return r;end if;
 if pid is null then
  insert into public.projects(tenant_id,customer_account_id,name,budget_minor,active) values(t,account_value,name_value,budget,(p_body->>'active')::boolean) returning * into p;
 else
  select * into p from public.projects where tenant_id=t and id=pid for update;if not found then raise exception 'NOT_FOUND';end if;
  if p.customer_account_id<>account_value then raise exception 'VALIDATION_ERROR';end if;
  select version into current_version from private.production_project_versions where tenant_id=t and project_id=pid;
  if coalesce(current_version,0)<>v then raise exception 'VERSION_CONFLICT';end if;
  update public.projects set name=name_value,budget_minor=budget,active=(p_body->>'active')::boolean where tenant_id=t and id=pid returning * into p;
 end if;
 insert into private.production_project_versions(project_id,tenant_id,customer_account_id,version) values(p.id,t,account_value,v+1)
 on conflict(project_id) do update set version=excluded.version;
 r:=jsonb_build_object('id',p.id,'tenant_id',t,'customer_account_id',p.customer_account_id,'name',p.name,'budget_minor',p.budget_minor::text,'committed_minor',p.committed_minor::text,'active',p.active,'version',v+1);
 perform private.production_record(t,'production.project.save',p.id,p_body,p_key,p_correlation,r);return r;
end$$;

revoke all on function private.save_production_project(jsonb,text,uuid) from public,anon,authenticated;
