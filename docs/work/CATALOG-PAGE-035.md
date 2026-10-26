# CATALOG-PAGE-035 — Sökning och serverpaginering

Ny read-only RPC `public.page_standalone_catalog(p_tenant uuid,p_query text,p_after_sku text default null,p_after_id uuid default null,p_limit integer default 50)`. SQL-invokerwrapper anropar privat definer med tom search_path, aktuellt assert_mfa och befintlig tenant-/catalog-permission. Ingen ny tabellgrants eller ändring av äldre list-RPC.

DTO: `{authority:"standalone-preparation",checkout_enabled:false,items:[befintlig artikel-DTO],total:<antal som matchar hela sökningen>,next_cursor:null|{sku:string,id:uuid}}`. Exakta pengasträngar bevaras av befintlig dto-funktion. `total` avser hela sökningen, inte bara rader efter cursor. Cursor kommer från sista returnerade raden endast om en extra rad finns. Sidan och antalet räknas i samma SQL-statement/snapshot. Stabil `(sku,id)`-ordning och keysetvillkor; ingen offset.

Sökning är bokstavlig skiftlägesokänslig delsträng av sku/name/barcode med strpos(lower(...),lower(query)). Procent/underscore/backslash är vanliga tecken. Tom/NULL-query ger alla tillåtna rader. Query max100 tecken; limit1..100; cursor måste ha både sku (1..80) och UUID eller inget. Rader som ändras mellan sidläsningar kan flytta sorteringsposition: detta är aktuell registervy, inte fryst exportsnapshot.

API-integration: använd `catalogPageInput.parse({tenant_id,query,after_sku,after_id,limit})`. Defaults query:'', cursor:null, limit50. Från URL ska utelämnade fält vara undefined; använd inte `null` för utelämnad limit/query. Skicka till RPC som `p_tenant:input.tenant_id,p_query:input.query,p_after_sku:input.after_sku,p_after_id:input.after_id,p_limit:input.limit`. Behåll befintlig auth och catalog feature gate för `/standalone-catalog/page`. Inga gamla routes ändrade av delagent.

CLI2.121.0 migration new skapade `20261026180352_standalone_catalog_page.sql`. Migration ej tillämpad av delagenten. Tre schemaenhetstester PASS; full SQL-rollmatris med över200 artiklar ägs av separat verifieringsagent. Tom search_path, inga dynamiska SQL-strängar, inga JWT-user_metadata-behörigheter, inga writes. Grants är enbart execute till authenticated efter revoke public/anon/authenticated på båda nya funktionerna.

Parent 2026-10-26: migrationen tillämpad hosted som20261026180352. Rollbacktest207 artiklar/fem sidor/literal sökning/tenant/MFA/validering PASS. Wrapper invoker, private definer med fast search_path, anon execute false och authenticated true verifierat.
