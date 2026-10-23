-- Explicit outer reference: an unqualified id resolves to memberships.id.
alter policy merchant_read on public.merchants using((select private.mfa_satisfied()) and exists(
 select 1 from public.memberships m where m.tenant_id=merchants.id and m.user_id=(select auth.uid())
 and m.status='active' and m.valid_from<=now() and (m.valid_to is null or m.valid_to>now())));
