-- Immediate business-access revocation complements provider refresh-token logout.
create table private.revoked_sessions (
 session_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 revoked_at timestamptz not null default now()
);
create index revoked_sessions_user_idx on private.revoked_sessions(user_id);
alter table private.revoked_sessions enable row level security;
revoke all on private.revoked_sessions from public,anon,authenticated;
create or replace function private.security_state() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare required boolean; enrolled boolean; satisfied boolean; level text:=coalesce(auth.jwt()->>'aal','aal1');
begin
 if auth.uid() is null then raise exception 'PERMISSION_DENIED';end if;
 select exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now()) and m.role in ('platform_admin','support','merchant_admin','credit_manager','finance')) into required;
 select exists(select 1 from auth.mfa_factors f where f.user_id=auth.uid() and f.status='verified') into enrolled;
 satisfied:=not exists(select 1 from private.revoked_sessions r where r.user_id=auth.uid() and r.session_id::text=auth.jwt()->>'session_id') and (not(required or enrolled) or (level='aal2' and exists(select 1 from auth.sessions s join auth.mfa_factors f on f.id=s.factor_id and f.user_id=s.user_id where s.id::text=auth.jwt()->>'session_id' and s.user_id=auth.uid() and s.aal='aal2' and (s.not_after is null or s.not_after>now()) and f.status='verified')));
 return jsonb_build_object('required',required,'enrolled',enrolled,'level',level,'satisfied',satisfied);
end$$;
create function private.revoke_my_sessions() returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid;n integer;begin
 if auth.uid() is null or coalesce(auth.jwt()->>'session_id','') !~ '^[a-fA-F0-9-]{36}$' then raise exception 'PERMISSION_DENIED';end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':session-revocation',0));
 -- Repeating an already completed operation must not revoke newer sessions.
 if exists(select 1 from private.revoked_sessions r where r.session_id=sid and r.user_id=auth.uid()) then return jsonb_build_object('revoked',0,'replayed',true);end if;
 if not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=auth.uid() and (s.not_after is null or s.not_after>now())) then raise exception 'PERMISSION_DENIED';end if;
 perform private.assert_mfa();
 insert into private.revoked_sessions(session_id,user_id) select s.id,s.user_id from auth.sessions s where s.user_id=auth.uid() on conflict do nothing;
 get diagnostics n=row_count;
 return jsonb_build_object('revoked',n,'replayed',false);
end$$;
create function public.revoke_my_sessions() returns jsonb language sql security invoker set search_path='' as $$select private.revoke_my_sessions()$$;
revoke all on function private.revoke_my_sessions(),public.revoke_my_sessions() from public,anon,authenticated;
grant execute on function private.revoke_my_sessions(),public.revoke_my_sessions() to authenticated;
