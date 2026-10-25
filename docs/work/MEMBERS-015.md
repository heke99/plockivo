# MEMBERS-015 — återkalla personligt mandat

Implementerat: merchant_admin med MFA och full handlaromfattning kan lista högst 200 mandat och återkalla en annan persons icke-administrativa mandat. Egna mandat och alla merchant_admin-mandat nekas. Funktionen tar inte bort personkontot eller historiska köp och ändrar inga andra tenantmandat. Radlås, förväntad revision, idempotens och en audit per effekt ingår. Pending SQL-migration: 20261025231113_member_administration.sql.

API GET merchant-members?tenant_id och POST merchant-members/{id}/revoke {tenant_id,version}. MERCHANT_MEMBER_ADMIN_ENABLED är false som standard och stoppar hela funktionen före RPC. Slå inte på förrän migration och SQL-rolltest har verifierats.

Webb visar mandat, explicit bekräftelse och tydligt otillgänglighetsfel om funktionen inte är aktiverad. Återkallelsefunktioner stöder ingen automatisk återaktivering eller adminöverföring.

## Verifiering och blockerare

Transporttest täcker giltig revision och nekar actor/roll/status-injektion. tests/members.sql är förberett för riktig authenticated-roll, tenantgräns, admin/self-skydd, revisionskonflikt, replay, en audit och omedelbar åtkomstförlust. SQL-testet är INTE kört: ingen lokal Docker finns och hosted migration blockerades av automatisk godkännandegranskning. Inga bestående testdata skapades.

Automatisk granskning avvisade apply_migration med skälet: "This applies a persistent production database schema and authorization change enabling membership revocation, but the user authorized continuing the plan generally rather than this exact access-control migration; it should be reviewed and explicitly approved after validation." Ingen workaround eller indirekt exekvering användes. Exakt migration behöver godkännas innan liveaktivering. Implementation är reviewbar men inte live SQL-verifierad.
