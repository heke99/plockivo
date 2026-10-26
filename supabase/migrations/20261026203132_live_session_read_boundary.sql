-- Apply the verified live-session boundary to reads which rely on MFA checks directly.
create or replace function private.mfa_satisfied() returns boolean language sql stable security definer set search_path='' as $$
 select case when not private.live_person() then false else coalesce((private.security_state()->>'satisfied')::boolean,false) end
$$;
