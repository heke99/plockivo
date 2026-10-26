create function private.production_uuid(b jsonb,k text,nullable boolean default false) returns uuid language plpgsql immutable set search_path='' as $$
begin
 if nullable and jsonb_typeof(b->k)='null' then return null;end if;
 if jsonb_typeof(b->k) is distinct from 'string' then raise exception 'VALIDATION_ERROR';end if;
 begin return (b->>k)::uuid;exception when invalid_text_representation then raise exception 'VALIDATION_ERROR';end;
end$$;
create function private.production_integer(b jsonb,k text) returns integer language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(b->k) is distinct from 'number' or coalesce(b->>k,'') !~ '^(0|[1-9][0-9]{0,9})$' then raise exception 'VALIDATION_ERROR';end if;
 if (b->>k)::numeric>2147483646 then raise exception 'VALIDATION_ERROR';end if;
 return (b->>k)::integer;
end$$;
create function private.production_money(b jsonb,k text) returns bigint language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(b->k) is distinct from 'string' or coalesce(b->>k,'') !~ '^(0|[1-9][0-9]{0,11})$' then raise exception 'VALIDATION_ERROR';end if;
 return (b->>k)::bigint;
end$$;
create function private.production_text(b jsonb,k text,minlen integer,maxlen integer) returns text language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(b->k) is distinct from 'string' or length(trim(coalesce(b->>k,''))) not between minlen and maxlen then raise exception 'VALIDATION_ERROR';end if;
 return trim(b->>k);
end$$;
create function private.production_request(b jsonb,keys text[],k text,c uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare t uuid;begin
 if b is null or jsonb_typeof(b)<>'object' or b-keys<>'{}'::jsonb or not(b ?& keys)
 or k is null or length(k) not between 16 and 128 or k !~ '^[a-zA-Z0-9:_-]+$' or c is null then raise exception 'VALIDATION_ERROR';end if;
 t:=private.production_uuid(b,'tenant_id');perform private.assert_mfa();
 if not private.profile_authorized(t) then raise exception 'PERMISSION_DENIED';end if;
 return t;
end$$;
create function private.production_replay(t uuid,op text,b jsonb,k text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare cmd private.commands;begin
 select * into cmd from private.commands where tenant_id=t and actor_id=auth.uid() and operation=op and key=k;
 if not found then return null;end if;
 if cmd.body<>b then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 return cmd.result;
end$$;
create function private.production_record(t uuid,op text,obj uuid,b jsonb,k text,c uuid,r jsonb) returns void language plpgsql security definer set search_path='' as $$begin
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(t,auth.uid(),op,obj,c);
 insert into private.commands(tenant_id,actor_id,operation,key,body,result) values(t,auth.uid(),op,k,b,r);
end$$;
revoke all on function private.production_uuid(jsonb,text,boolean),private.production_integer(jsonb,text),private.production_money(jsonb,text),private.production_text(jsonb,text,integer,integer),private.production_request(jsonb,text[],text,uuid),private.production_replay(uuid,text,jsonb,text),private.production_record(uuid,text,uuid,jsonb,text,uuid,jsonb) from public,anon,authenticated;
