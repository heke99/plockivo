-- TASK054: manual receivable allocation only. No bank transfer, invoice or credit note issuance.
insert into public.role_permissions(role,permission) values('merchant_admin','production.receivables.manage');
create table private.production_receivables(
 order_id uuid primary key,tenant_id uuid not null,version integer not null check(version>=0),
 foreign key(tenant_id,order_id) references public.orders(tenant_id,id)
);
create table private.production_payment_receipts(
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,
 actor_id uuid not null references auth.users(id),amount_minor bigint not null check(amount_minor>0),
 payment_reference text not null check(length(trim(payment_reference)) between 1 and 120),
 evidence_reference text not null check(length(trim(evidence_reference)) between 1 and 200),
 reason text not null check(length(trim(reason)) between 10 and 500),recorded_at timestamptz not null default now(),
 foreign key(tenant_id,order_id) references public.orders(tenant_id,id),unique(tenant_id,order_id,id),unique(tenant_id,payment_reference,id)
);
create index production_payment_receipts_order_idx on private.production_payment_receipts(tenant_id,order_id,recorded_at desc,id);
create table private.production_payment_reversals(
 id uuid primary key default gen_random_uuid(),tenant_id uuid not null,order_id uuid not null,
 receipt_id uuid not null unique,actor_id uuid not null references auth.users(id),
 evidence_reference text not null check(length(trim(evidence_reference)) between 1 and 200),
 reason text not null check(length(trim(reason)) between 10 and 500),reversed_at timestamptz not null default now(),
 foreign key(tenant_id,order_id,receipt_id) references private.production_payment_receipts(tenant_id,order_id,id)
);
create index production_payment_reversals_order_idx on private.production_payment_reversals(tenant_id,order_id);
create table private.production_payment_active_references(
 tenant_id uuid not null,payment_reference text not null,receipt_id uuid not null unique,
 primary key(tenant_id,payment_reference),
 foreign key(tenant_id,payment_reference,receipt_id) references private.production_payment_receipts(tenant_id,payment_reference,id)
);
alter table private.production_receivables enable row level security;
alter table private.production_payment_receipts enable row level security;
alter table private.production_payment_reversals enable row level security;
alter table private.production_payment_active_references enable row level security;
revoke all on private.production_receivables,private.production_payment_receipts,private.production_payment_reversals,private.production_payment_active_references from public,anon,authenticated;
create function private.reject_receivable_ledger_mutation() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'RECEIVABLE_LEDGER_IMMUTABLE';end$$;
create trigger production_payment_receipts_immutable before update or delete on private.production_payment_receipts for each row execute function private.reject_receivable_ledger_mutation();
create trigger production_payment_reversals_immutable before update or delete on private.production_payment_reversals for each row execute function private.reject_receivable_ledger_mutation();
create function private.production_receivable_authorized(o public.orders) returns boolean language sql stable security definer set search_path='' as $$
 select private.live_person() and coalesce(auth.jwt()->>'aal','')='aal2' and private.mfa_satisfied()
 and o.mode='production' and private.profile_authorized(o.tenant_id)
 and private.allowed(o.tenant_id,null,null,null,'production.receivables.manage')
 and exists(select 1 from public.merchants m where m.id=o.tenant_id and m.mode='production')
$$;
create function private.production_receivable_dto(o public.orders) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare reserved bigint;released bigint;paid bigint;revision integer;receipt_rows jsonb;begin
 select amount_minor into reserved from private.credit_reservations where order_id=o.id and tenant_id=o.tenant_id;
 select credit_released_minor into released from private.production_fulfillment where order_id=o.id and tenant_id=o.tenant_id;
 if reserved is null or released is null or reserved<>o.total_minor or released>reserved then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 select coalesce(sum(r.amount_minor),0)::bigint into paid from private.production_payment_receipts r
 where r.tenant_id=o.tenant_id and r.order_id=o.id and not exists(select 1 from private.production_payment_reversals x where x.receipt_id=r.id);
 if paid>reserved-released then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 select version into revision from private.production_receivables where order_id=o.id and tenant_id=o.tenant_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'amount_minor',r.amount_minor::text,'payment_reference',r.payment_reference,
 'evidence_reference',r.evidence_reference,'reason',r.reason,'recorded_at',r.recorded_at,'reversed',x.id is not null,
 'reversal',case when x.id is null then null else jsonb_build_object('id',x.id,'evidence_reference',x.evidence_reference,'reason',x.reason,'reversed_at',x.reversed_at) end)
 order by r.recorded_at desc,r.id desc),'[]'::jsonb) into receipt_rows
 from (select * from private.production_payment_receipts where tenant_id=o.tenant_id and order_id=o.id order by recorded_at desc,id desc limit 100)r
 left join private.production_payment_reversals x on x.receipt_id=r.id;
 return jsonb_build_object('order_id',o.id,'tenant_id',o.tenant_id,'mode','production','version',coalesce(revision,0),
 'manual_reconciliation',true,'currency','SEK','total_minor',o.total_minor::text,'reservation_minor',reserved::text,
 'cancelled_released_minor',released::text,'paid_minor',paid::text,'balance_minor',(reserved-released-paid)::text,
 'receipts',receipt_rows,'receipts_truncated',(select count(*)>100 from private.production_payment_receipts where tenant_id=o.tenant_id and order_id=o.id));
end$$;
create function private.get_production_receivables(p_order uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;begin
 -- Stabilize revision, totals and receipt page against concurrent payment/reversal.
 select * into o from public.orders where id=p_order for share;
 if not found or not private.production_receivable_authorized(o) then raise exception 'PERMISSION_DENIED';end if;
 if not exists(select 1 from private.production_fulfillment f where f.order_id=o.id and f.tenant_id=o.tenant_id and f.state='fulfilled') then raise exception 'FULFILLMENT_REQUIRED';end if;
 return private.production_receivable_dto(o);
end$$;
create function private.mutate_production_payment(p_order uuid,p_body jsonb,p_key text,p_correlation uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.orders;f private.production_fulfillment;res private.credit_reservations;cmd private.commands;
 receipt private.production_payment_receipts;revision integer;paid bigint;amount bigint;remaining bigint;
 op_name text;result jsonb;rid uuid;reference_value text;evidence text;reason_value text;
begin
 if p_action not in ('record','reverse') then raise exception 'VALIDATION_ERROR';end if;
 if not private.live_person() then raise exception 'PERMISSION_DENIED';end if;
 if coalesce(auth.jwt()->>'aal','')<>'aal2' or not private.mfa_satisfied() then raise exception 'MFA_REQUIRED';end if;
 op_name:='production.payment.'||p_action;
 if p_key is null or length(p_key) not between 16 and 128 or p_key !~ '^[a-zA-Z0-9:_-]+$' or p_correlation is null then raise exception 'VALIDATION_ERROR';end if;
 -- Command -> order -> membership -> merchant -> account -> reservation. Never lock a second order.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||op_name||':'||p_key,0));
 select * into o from public.orders where id=p_order for update;
 if not found or not private.production_receivable_authorized(o) then raise exception 'PERMISSION_DENIED';end if;
 perform 1 from public.memberships m where m.user_id=auth.uid() and m.tenant_id=o.tenant_id and m.role='merchant_admin'
 and m.customer_account_id is null and m.store_id is null and m.project_id is null and m.status='active'
 and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) order by m.id for share;
 if not found then raise exception 'PERMISSION_DENIED';end if;
 select * into f from private.production_fulfillment where tenant_id=o.tenant_id and order_id=o.id;
 if not found or f.state<>'fulfilled' then raise exception 'FULFILLMENT_REQUIRED';end if;
 select * into cmd from private.commands where tenant_id=o.tenant_id and actor_id=auth.uid() and operation=op_name and key=p_key;
 if found then if cmd.body<>jsonb_build_object('order_id',o.id,'body',p_body) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return cmd.result;end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or jsonb_typeof(p_body->'version') is distinct from 'number'
 or coalesce(p_body->>'version','') !~ '^(0|[1-9][0-9]{0,9})$' or (p_body->>'version')::numeric>2147483646
 or jsonb_typeof(p_body->'evidence_reference') is distinct from 'string' or length(trim(coalesce(p_body->>'evidence_reference',''))) not between 1 and 200
 or jsonb_typeof(p_body->'reason') is distinct from 'string' or length(trim(coalesce(p_body->>'reason',''))) not between 10 and 500 then raise exception 'VALIDATION_ERROR';end if;
 evidence:=trim(p_body->>'evidence_reference');reason_value:=trim(p_body->>'reason');
 if p_action='record' then
  if p_body-'version'-'amount_minor'-'payment_reference'-'evidence_reference'-'reason'<>'{}'::jsonb
  or jsonb_typeof(p_body->'amount_minor') is distinct from 'string' or coalesce(p_body->>'amount_minor','') !~ '^[0-9]{1,15}$'
  or jsonb_typeof(p_body->'payment_reference') is distinct from 'string' or length(trim(coalesce(p_body->>'payment_reference',''))) not between 1 and 120 then raise exception 'VALIDATION_ERROR';end if;
  amount:=(p_body->>'amount_minor')::bigint;reference_value:=trim(p_body->>'payment_reference');if amount<=0 then raise exception 'VALIDATION_ERROR';end if;
 else
  if p_body-'version'-'receipt_id'-'evidence_reference'-'reason'<>'{}'::jsonb or jsonb_typeof(p_body->'receipt_id') is distinct from 'string'
  or coalesce(p_body->>'receipt_id','') !~ '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$' then raise exception 'VALIDATION_ERROR';end if;
 end if;
 select version into revision from private.production_receivables where order_id=o.id and tenant_id=o.tenant_id;
 if coalesce(revision,0)<>(p_body->>'version')::integer then raise exception 'VERSION_CONFLICT';end if;
 perform 1 from public.merchants where id=o.tenant_id for share;
 perform 1 from public.customer_accounts where id=o.customer_account_id and tenant_id=o.tenant_id for update;
 if not found then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 select * into res from private.credit_reservations where tenant_id=o.tenant_id and order_id=o.id for update;
 if not found or res.amount_minor<>o.total_minor or f.credit_released_minor>res.amount_minor then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 select coalesce(sum(r.amount_minor),0)::bigint into paid from private.production_payment_receipts r
 where r.tenant_id=o.tenant_id and r.order_id=o.id and not exists(select 1 from private.production_payment_reversals x where x.receipt_id=r.id);
 remaining:=res.amount_minor-f.credit_released_minor-paid;
 if remaining<0 then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 if p_action='record' then
  if amount>remaining then raise exception 'PAYMENT_EXCEEDS_BALANCE';end if;
  insert into private.production_payment_receipts(tenant_id,order_id,actor_id,amount_minor,payment_reference,evidence_reference,reason)
  values(o.tenant_id,o.id,auth.uid(),amount,reference_value,evidence,reason_value) returning id into rid;
  begin
   insert into private.production_payment_active_references(tenant_id,payment_reference,receipt_id) values(o.tenant_id,reference_value,rid);
  exception when unique_violation then raise exception 'PAYMENT_REFERENCE_CONFLICT';end;
  update public.customer_accounts set exposure_minor=exposure_minor-amount
  where tenant_id=o.tenant_id and id=o.customer_account_id and exposure_minor>=amount;
  if not found then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 else
  select * into receipt from private.production_payment_receipts where id=(p_body->>'receipt_id')::uuid and order_id=o.id and tenant_id=o.tenant_id for update;
  if not found then raise exception 'PERMISSION_DENIED';end if;
  if exists(select 1 from private.production_payment_reversals where receipt_id=receipt.id) then raise exception 'PAYMENT_ALREADY_REVERSED';end if;
  amount:=receipt.amount_minor;
  if amount>paid then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
  insert into private.production_payment_reversals(tenant_id,order_id,receipt_id,actor_id,evidence_reference,reason)
  values(o.tenant_id,o.id,receipt.id,auth.uid(),evidence,reason_value);
  delete from private.production_payment_active_references where tenant_id=o.tenant_id and payment_reference=receipt.payment_reference and receipt_id=receipt.id;
  if not found then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
  -- Truthful restoration may exceed the current credit limit; no cap or new buying mandate is implied.
  update public.customer_accounts set exposure_minor=exposure_minor+amount where tenant_id=o.tenant_id and id=o.customer_account_id;
  if not found then raise exception 'RECEIVABLE_STATE_CONFLICT';end if;
 end if;
 insert into private.production_receivables(order_id,tenant_id,version) values(o.id,o.tenant_id,coalesce(revision,0)+1)
 on conflict(order_id) do update set version=excluded.version;
 insert into private.audit_events(tenant_id,actor_id,operation,object_id,correlation_id) values(o.tenant_id,auth.uid(),op_name,o.id,p_correlation);
 result:=private.production_receivable_dto(o);
 insert into private.commands(tenant_id,actor_id,operation,key,body,result) values(o.tenant_id,auth.uid(),op_name,p_key,jsonb_build_object('order_id',o.id,'body',p_body),result);
 return result;
end$$;
create function public.get_production_receivables(p_order uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_production_receivables(p_order)$$;
create function public.record_production_payment(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.mutate_production_payment(p_order,p_body,p_key,p_correlation,'record')$$;
create function public.reverse_production_payment(p_order uuid,p_body jsonb,p_key text,p_correlation uuid) returns jsonb language sql security invoker set search_path='' as $$select private.mutate_production_payment(p_order,p_body,p_key,p_correlation,'reverse')$$;
revoke all on function private.reject_receivable_ledger_mutation(),private.production_receivable_authorized(public.orders),private.production_receivable_dto(public.orders),private.get_production_receivables(uuid),private.mutate_production_payment(uuid,jsonb,text,uuid,text),public.get_production_receivables(uuid),public.record_production_payment(uuid,jsonb,text,uuid),public.reverse_production_payment(uuid,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function private.get_production_receivables(uuid),private.mutate_production_payment(uuid,jsonb,text,uuid,text),public.get_production_receivables(uuid),public.record_production_payment(uuid,jsonb,text,uuid),public.reverse_production_payment(uuid,jsonb,text,uuid) to authenticated;
