# DEPLOY-003 — skyddad testdrift på Vercel

Team Div3rsa, team_e3htkJPyBNSw3Ix1KQLlf180. Separata projekt plockivo-api och plockivo-web, Node 24, arn1. Vercels target heter production men verksamhetsmiljön är enbart syntetisk testmiljö mot Supabase cqznytuyutrqenbbyczc. Databasens production-mode-spärr är kvar.

API: prj_deCpzRlSUKzfmCoS18aL3ZLGwZyN, kod b245c5d36a7425ae6e8e2018452c4e44efb2089e, deployment dpl_94Be5EgxakGVF8c9dMWaQadM2kgU. Webb: prj_omZF3kAvFKYosZxo7KoVRNl5UgcU, kod 93567328981334fa7ba2ea8ca8f7732ab54eca24, deployment dpl_AexmaZPS8xStXoxXXLUCAyyP1Mbo. URL: https://plockivo-web.vercel.app, API https://plockivo-api.vercel.app.

Vercels Trusted Sources kunde inte konfigureras: PATCH returnerade 404 Deployment Protection Trusted Sources not found. Ingen CLI är installerad/authentiserad. Alternativ: dedikerad API-automationhemlighet endast i webbens servermiljö. Inga skydd har stängts av. BFF följer inte redirects; behörighetskontroll sker fortfarande med användar-JWT och aktuella medlemskap. Hemligheter finns aldrig i Git eller klientkod.

Cron stängd i vercel.json eftersom SUPABASE_SECRET_KEY och CRON_SECRET saknas. Verklig Workflow-exekvering, recovery och leverantörseffekter är BLOCKED. Dessa får inte beskrivas som verifierade.

| ID | Prioritet | Trigger och förväntat resultat | Status |
| --- | --- | --- | --- |
| D003-01 | P0 | Båda builds READY, rätt commit och region, API health 200 no-store | PASS |
| D003-02 | P0 | Saknad appsession ger 401 även bakom Vercels åtkomstskydd | PASS via skyddad fetch |
| D003-03 | P0 | Browser login → katalog → autospara → reload återger rätt rader/referens | PASS |
| D003-04 | P0 | Bekräfta testköp → en order/reservation/audit/outbox → UI återupptar order | PASS |
| D003-05 | P0 | Ny korg efter order, logout, 401, Secure HttpOnly host-only cookie | PASS |
| D003-06 | P1 | Mobil 390px utan overflow, inga pageerrors | PASS |
| D003-07 | P0 | Worker/Workflow → JSON-dokument och recovery | BLOCKED: separat worker-nyckel saknas |
| D003-08 | P0 | Verklig ERP/kredit/utlämning/faktura/retur/MFA | BLOCKED: tidigare dokumenterade pilotkrav |

Testidentiteter och fixtures använder reserverade 00000000-0000-4000-8000-... UUID:n, endast e2e-*@plockivo.invalid, inga utskick. tests/cleanup-fixtures.sql städar i FK-ordning och kontrollerar att tenants är syntetiska. Readback måste visa 0 testdata innan avslut. Browserbilder är endast intern evidens.

## Release verdict

**RED för verklig pilot.** Det begränsade testköpsflödet är verifierat i driftsatt miljö. Worker, verkliga integrationer och andra P0-pilotkrav saknas; detta är inte en produktionsgodkänd produkt.

## Quality gates

Båda slutbyggen READY i arn1, Node 24. Webbens npm run verify PASS (4 tester); API:s affärskod oförändrad, cron-konfiguration avstängd. GitHub [API CI 39858667391](https://github.com/heke99/plockivo/actions/runs/39858667391) och [webb CI 39858678412](https://github.com/heke99/plockivo-web/actions/runs/39858678412) PASS för angivna kodcommits. Senare dokumentation och E2E-körarens nätverksanrop ändrar inte runtime-koden.

## P0 evidence

HTTP: riktig Auth → webb-BFF → skyddat API → Supabase → quote → bekräftelse → annan nyckel återger samma order → readback PASS. Host-only HttpOnly cookies, främmande Origin 403 och logout PASS. Skyddad API-fetch utan appsession 401.

Chromium: personlig login → streckkod → mängd 2 → referens → autospara → reload med samma mängd/referens → låst underlag → testorder → reload och återupptagen order → nästa tomma sparade korg → historik → logout → browser-fetch 401. Desktop 1440px och mobil 390px, ingen overflow eller pageerror. Secure/HttpOnly cookies endast på plockivo-web.vercel.app. Ingen fysisk kamera eller PWA-installation på telefon är testad.

Databasreadback efter en HTTP-resa och två browserresor: 3 avsiktliga order, 3 orderrader, exponering och projektåtagande 75000 öre. Audit: 3 purchases.prepare, 3 purchases.confirm, 4 carts.save. Outbox: 3 purchase_confirmation och 3 notification, samtliga queued eftersom worker är avstängd. Ingen påstådd dokument-/meddelandeleverans. Replay av HTTP-bekräftelsen skapade ingen extra order.

## Failures and remediation

- Trusted Sources API 404: ersatt med dedikerad servernyckel för test-API, utan att stänga av Deployment Protection. Byte till kortlivad projektidentitet kvarstår när funktionen går att konfigurera.
- Testbrowser saknade arbetsmiljöns redan betrodda CA-kedja: befintliga miljöcertifikat importerades till testbrowserns NSS-lager. TLS-verifiering var påslagen. Temporära certifikatposter borttagna efter test.
- Playwright APIRequestContext använde en annan nätverksväg än browsern och misslyckades med DNS efter logout. Testet använder nu fetch från den riktiga browsern; slutomkörningen PASS.

## Security and tenancy

Tidigare authenticated-roll-/tenant-/scope-/versions-/samtidighetstester PASS enligt VERIFICATION.md; ingen schemaändring här. API-automationhemligheten är sensitive och enbart i webbserverns production-miljö. SUPABASE_SECRET_KEY finns inte i webbappen. Endast syntetisk utvecklingsdatabas används; previews får inte ärva denna konfiguration utan separat miljöbeslut. Vercel Deployment Protection är kvar, Supabase-identitet/mandat kontrolleras separat.

## Runtime observability and performance

Inga error/fatal-loggar returnerades för de två slutdeployments under testfönstret. Detta är en avgränsad kontroll, inte verifierade kontinuerliga larm. Drains, avbrottslarm och belastningsprov är inte verifierade. Browser och HTTP genomförde fulla testresor; inga prestanda-SLA påstås.

## Cleanup

Syntetiska merchants/order/cart/outbox/auth-identiteter städade med tests/cleanup-fixtures.sql. Readback: merchants=0, orders=0, carts=0, jobs=0, test_users=0. Tillfällig browseråtkomst återkallad och lokala testinloggningar raderade. Den permanenta serverkopplingen mellan webb och test-API är kvar och behövs för appflödet.

## Remaining blockers and next action

Lägg endast i API-projektets känsliga Vercelmiljö: separat Supabase worker-nyckel SUPABASE_SECRET_KEY för cqznytuyutrqenbbyczc. Den anslutna Supabase-tjänsten exponerar enbart publishable keys; ingen administrativ nyckel har hämtats eller loggats. Generera sedan CRON_SECRET, deploya och verifiera en riktig Workflow-start, avbrott, recovery och idempotent dokument. Aktivera cron först efter detta. Nycklar ska inte skickas i chatt, läggas i Git eller i webbprojektet.

Oberoende nästa produktarbete: verifierad inbjudan/personprovisionering och MFA, handlarkonfiguration och verklig ERP-kapacitetsprofil. Fulla pilotkrav enligt masterplan kapitel 38 kvarstår.
