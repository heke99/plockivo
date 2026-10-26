-- Read-only cumulative allocation; never an invoice/posting/credit operation.
insert into public.role_permissions values('merchant_admin','billing.read.test');
create function private.test_billing_underlay(p_order uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders; result jsonb;begin
 select * into o from public.orders where id=p_order for share;
 if not found or o.mode<>'test' or not private.profile_authorized(o.tenant_id) or not private.fulfillment_authorized(o,'billing.read.test') then raise exception 'PERMISSION_DENIED';end if;
 with rows as (select l.id,l.product_id,l.snapshot,l.quantity,coalesce(d.fulfilled_quantity,0) fulfilled,coalesce(d.returned_quantity,0) returned,l.net_minor,l.vat_minor from public.order_lines l left join private.order_line_disposition d on d.order_line_id=l.id where l.order_id=o.id), allocated as (select *,round(net_minor::numeric*fulfilled/quantity)::bigint allocated_net,round(vat_minor::numeric*fulfilled/quantity)::bigint allocated_vat from rows)
 select jsonb_build_object('order_id',o.id,'tenant_id',o.tenant_id,'mode','test','status','not_posted','currency',o.currency,'allocation_policy','cumulative_original_row_half_up','returns_create_credit',false,'lines',coalesce(jsonb_agg(jsonb_build_object('order_line_id',id,'product_id',product_id,'name',snapshot->>'name','ordered_quantity',quantity::text,'fulfilled_quantity',fulfilled::text,'returned_quantity',returned::text,'net_minor',allocated_net::text,'vat_minor',allocated_vat::text) order by id),'[]'),'net_minor',coalesce(sum(allocated_net),0)::text,'vat_minor',coalesce(sum(allocated_vat),0)::text,'total_minor',coalesce(sum(allocated_net+allocated_vat),0)::text) into result from allocated;
 return result;
end$$;
create function public.get_test_billing_underlay(p_order uuid) returns jsonb language sql security invoker set search_path='' as $$select private.test_billing_underlay(p_order)$$;
revoke all on function private.test_billing_underlay(uuid),public.get_test_billing_underlay(uuid) from public,anon,authenticated;
grant execute on function private.test_billing_underlay(uuid),public.get_test_billing_underlay(uuid) to authenticated;
