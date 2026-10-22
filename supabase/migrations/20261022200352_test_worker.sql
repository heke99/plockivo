-- Durable job references only; no real provider configured.
create function private.pending_test_jobs() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if (select auth.role()) is distinct from 'service_role' then raise exception 'PERMISSION_DENIED';end if;
 return coalesce((select jsonb_agg(id) from (select b.id from private.outbox b join public.merchants m on m.id=b.tenant_id where b.status='queued' and m.mode='test' order by b.created_at,b.id limit 20)x),'[]');
end$$;
create function private.process_test_job(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.outbox;o public.orders;
begin
 if (select auth.role()) is distinct from 'service_role' then raise exception 'PERMISSION_DENIED';end if;
 select * into j from private.outbox where id=p_id for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if j.status<>'queued' then return jsonb_build_object('id',j.id,'status',j.status);end if;
 select * into o from public.orders where id=j.order_id and tenant_id=j.tenant_id and mode='test';
 if not found or not exists(select 1 from public.merchants where id=j.tenant_id and mode='test') then raise exception 'INTEGRATION_NOT_READY';end if;
 if j.kind='purchase_confirmation' then
  insert into public.documents(tenant_id,order_id,kind,template_version,content,content_hash)
  values(j.tenant_id,o.id,'purchase_confirmation','test-json-v1',o.snapshot,md5(o.snapshot::text)) on conflict(order_id,kind) do nothing;
  update private.outbox set status='succeeded',attempts=attempts+1 where id=j.id;
 else
  update private.outbox set status='manual_review',attempts=attempts+1 where id=j.id;
 end if;
 return jsonb_build_object('id',j.id,'status',(select status from private.outbox where id=j.id));
end$$;
create function public.pending_test_jobs() returns jsonb language sql security invoker set search_path='' as $$select private.pending_test_jobs()$$;
create function public.process_test_job(p_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.process_test_job(p_id)$$;
revoke all on function private.pending_test_jobs(),private.process_test_job(uuid),public.pending_test_jobs(),public.process_test_job(uuid) from public,anon,authenticated;
grant usage on schema private to service_role;
grant execute on function private.pending_test_jobs(),private.process_test_job(uuid),public.pending_test_jobs(),public.process_test_job(uuid) to service_role;
drop policy merchant_read on public.merchants;
create policy merchant_read on public.merchants for select to authenticated using(exists(select 1 from public.memberships m where m.tenant_id=merchants.id and m.user_id=(select auth.uid()) and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())));
