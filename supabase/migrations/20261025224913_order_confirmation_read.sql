-- DOCS-013: read the generated confirmation under the caller's existing order RLS.
-- No service role, new permission, document generation or delivery on this read path.
create function public.get_order_confirmation(p_intent uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare o public.orders;d public.documents;
begin
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 perform private.assert_mfa();
 select * into o from public.orders where purchase_intent_id=p_intent;
 if not found then raise exception 'NOT_FOUND';end if;
 select * into d from public.documents where order_id=o.id and tenant_id=o.tenant_id and kind='purchase_confirmation';
 return jsonb_build_object('order_id',o.id,'mode',o.mode,'status',case when d.id is null then 'pending' else 'ready' end,
 'document',case when d.id is null then null else jsonb_build_object('id',d.id,'kind',d.kind,'template_version',d.template_version,
 'created_at',d.created_at,'content_hash',d.content_hash,'content',d.content) end);
end$$;
revoke all on function public.get_order_confirmation(uuid) from public,anon,authenticated;
grant execute on function public.get_order_confirmation(uuid) to authenticated;
