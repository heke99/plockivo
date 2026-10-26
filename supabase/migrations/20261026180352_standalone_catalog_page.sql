-- Read-only, tenant-authorized keyset pagination. Legacy list RPC stays intact.
create function private.page_standalone_catalog(
 p_tenant uuid,p_query text,p_after_sku text default null,
 p_after_id uuid default null,p_limit integer default 50
) returns jsonb language plpgsql security definer set search_path='' as $$
declare q text:=lower(coalesce(p_query,''));r jsonb;
begin
 perform private.assert_mfa();
 if not private.standalone_catalog_authorized(p_tenant) then raise exception 'PERMISSION_DENIED';end if;
 if length(q)>100 or p_limit is null or p_limit not between 1 and 100
 or (p_after_sku is null)<>(p_after_id is null)
 or (p_after_sku is not null and length(p_after_sku) not between 1 and 80)
 then raise exception 'VALIDATION_ERROR';end if;
 with filtered as materialized (
  select i.* from private.standalone_catalog_items i
  where i.tenant_id=p_tenant and (q='' or strpos(lower(i.sku),q)>0
   or strpos(lower(i.name),q)>0 or strpos(lower(coalesce(i.barcode,'')),q)>0)
 ), candidates as materialized (
  select f.* from filtered f
  where p_after_sku is null or (f.sku,f.id)>(p_after_sku,p_after_id)
  order by f.sku,f.id limit p_limit+1
 ), page as materialized (
  select c.* from candidates c order by c.sku,c.id limit p_limit
 )
 select jsonb_build_object(
  'authority','standalone-preparation','checkout_enabled',false,
  'items',coalesce((select jsonb_agg(private.standalone_catalog_dto(p::private.standalone_catalog_items) order by p.sku,p.id) from page p),'[]'::jsonb),
  'total',(select count(*) from filtered),
  'next_cursor',case when (select count(*) from candidates)>p_limit
   then (select jsonb_build_object('sku',p.sku,'id',p.id) from page p order by p.sku desc,p.id desc limit 1)
   else null end
 ) into r;
 return r;
end$$;
create function public.page_standalone_catalog(
 p_tenant uuid,p_query text,p_after_sku text default null,
 p_after_id uuid default null,p_limit integer default 50
) returns jsonb language sql security invoker set search_path='' as $$
 select private.page_standalone_catalog(p_tenant,p_query,p_after_sku,p_after_id,p_limit)
$$;
revoke all on function private.page_standalone_catalog(uuid,text,text,uuid,integer),public.page_standalone_catalog(uuid,text,text,uuid,integer) from public,anon,authenticated;
grant execute on function private.page_standalone_catalog(uuid,text,text,uuid,integer),public.page_standalone_catalog(uuid,text,text,uuid,integer) to authenticated;
