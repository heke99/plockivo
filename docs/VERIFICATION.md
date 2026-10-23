# Verifieringsrapport — Plockivo 0.2.0

## Utlåtande

**RED för verklig pilot.** Ett sammanhängande testflöde är implementerat och systemverifierat för de gränser som anges nedan. Saknade P0-flöden får inte beskrivas som färdiga eller driftsatta. Skyddad Vercel-testdrift är verifierad för det begränsade testköpsflödet; full pilot är inte godkänd.

Miljö: lokala produktionsbyggen av API och webb, Supabase utvecklingsprojekt cqznytuyutrqenbbyczc, syntetiska handlare och testidentiteter. API-kontrakt 0.2.0. Engineering Startkit 3.0.0. Releasecommits registreras vid avslut i leveransmanifestet.

## Resultat

| Kontroll | Resultat | Evidens och begränsning |
| --- | --- | --- |
| API/webb typecheck och build | PASS | npm run typecheck, npm run build i respektive projekt |
| API:s transportvalidering | PASS | 4 tester: tom utkastkorg, revisionsfält, otillåtna actor/prisfält, exakt decimalformat/gränser, immutable bekräftelse |
| Webbens kontraktslåsning och CSRF | PASS | 4 tester: kontraktslåsning och origin/metadata/custom-headergräns.  Genererad OpenAPI-klient med version och SHA-256 |
| RLS/RPC/transactions | PASS | tests/database.sql körd i verklig authenticated- och service-roll, rollback |
| Attest | PASS i DB | Krävd attest, självattest nekas, annan behörig person godkänner; slutbekräftelse separat |
| Samtidig kredit | PASS | 2 parallella sessioner med 75000 öre vardera mot 100000; en order, exponering och projektåtagande 75000 |
| HTTP med verklig Auth/BFF/API/DB | PASS | Personlogin → kontext → barcode → quote → confirm → replay med ny nyckel → orderreadback; Origin 403, auth 401, logout 200 |
| HttpOnly och cookieomfång | PASS via HTTP | Set-Cookie kontrollerad för HttpOnly och avsaknad av Domain. Webbläsarbeteende dokumenteras separat. |
| Dokumentworker i databas | PASS | En JSON-köpbekräftelse, inga dubbletter; notifiering stannar manual_review |
| Vercel Workflow | PASS för avgränsat test | WORKER-004: verklig start i arn1, bestående backlog genom deployment, parallella starter utan dubbla dokument. Processavbrott mitt i steg och externa effekter ej verifierade. |
| Säkerhetsadvisors | 1 konfigurationsvarning kvar | Leaked Password Protection är avstängd i Supabase Auth. [Åtgärd](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Därutöver avsiktliga INFO om deny-all-tabeller utan appgrants. |
| Browser desktop/mobil | PASS för första fulla testresan | Chromium/Playwright: inloggning, manuell streckkod, underlag, order, reload, historik, återupptagning, logout, 401 efter logout, HttpOnly host-only cookies och 390px utan horisontell overflow. Inga pageerrors. Slutomkörningen passerade efter explicit local logout och optimerad sessionsproxy. |
| Fysisk kamera/PWA-installation | NOT RUN | Verkliga pilottelefoner och etiketter återstår. |
| Verklig ERP/Creditsafe/e-post | BLOCKERAT | Avtal, produkt och testanslutning saknas |
| Fysisk utlämning/faktura/retur | NOT RUN | Ej implementerade i denna grundleverans |
| Backup/inbjudningar/domäner | NOT RUN | Återstår före pilot; MFA hanteras i MFA-005 |
| GitHub CI | PASS | [Körning 39856574892](https://github.com/heke99/plockivo/actions/runs/39856574892), kodcommit 0dd58b9a449115f87cf7199d949ded8f1d4da632: quality samt database PASS; alla fem migrationer och båda SQL-sviterna |

## Databas och migrering

De fem lokala migrationsfilernas namn är synkade mot serverns migrationshistorik. Testerna körs under verkliga approller och provar förbjudna direktvägar, inte bara owner-anrop. Lokal Docker saknas i arbetsmiljön. GitHub CI:s första körning hittade att CLI db query inte stöder transaktionsskript. Efter rättning till psql i Supabase-containern passerade full replay av alla fem migrationer samt båda SQL-sviterna. Inga riktiga kunddata eller utskick har använts. Manuell SQL-provisionering av auth-identitet användes endast för temporär isolerad testidentitet, inte som produktens onboarding.

## Kvarstående produktionsrisker

Testpris och lokal kreditreservation bevisar inte samordnad kredit över en handlares andra säljkanaler. API-kvoten är ett transportskydd; direkta skyddade RPC-vägar behöver egen kostnads-/kapacitetsbedömning före pilot. Operativa larm, processavbrott mitt i jobb, PDF/Storage, återställning och komplett kundlivscykel är inte verifierade. Masterplanens kapitel 38 styr verklig start.

## Observerade externa beroenden

Leaked Password Protection måste aktiveras och verifieras i Supabase Auth före verkliga konton; ingen stödjande inställningsmutation fanns i anslutna verktyg. [Officiell konfiguration](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Offentlig publicering är nu uttryckligen godkänd; API-grunden är publicerad. Produktägaren har skapat heke99/plockivo-web och testad webb 0.2.0 är publicerad; webbens GitHub CI PASS.

## Slutkontroll och städning

2026-10-22: sista browserresan passerade på de byggda API-/webbkodbaserna med HttpOnly cookies, enbart localhost som cookiedomän, inga pageerrors, skyddad endpoint 401 efter logout och mobil 390px utan overflow. Temporära browserhandlare, order och auth-identiteter är borttagna; readback visade 0 handlare, 0 order och 0 E2E-identiteter. Rolltesterna använder rollback och lämnar inga verksamhetsrader.

## CARTS-002 — 0.2.0

Migration 20261022210808 tillämpad i utvecklingsprojektet. tests/carts.sql PASS med authenticated: sparande, tom korg, replay, annan person/samma konto, fel konto/tenant, återkallat mandat, gammal version, en quote per revision, invalidation och atomisk rollback vid felaktig mängd. Två samtidigt inskickade version-1-ändringar: en version 2, en VERSION_CONFLICT; ingen överskrivning. Browser PASS för sparad referens/mängd efter reload, underlag, order, återupptagen order och nästa tomma korg samt logout/mobil. Slutlig browseromkörning efter mandat-/logoutjustering PASS; inga pageerrors, host-only HttpOnly cookies, 401 efter logout och mobilvy utan overflow. Testdata städade: 0 handlare, order, korgar och E2E-identiteter. Produktionsrisker ovan kvarstår.

## Separat webbpublicering

Webbens kodcommit abbb0ed381d2473ec0125e0dac0dc2d5ed0df1f1 i heke99/plockivo-web motsvarar exakt lokalt testat Git-tree b16614bef95f048d84696700eba2a8c5b7166d87. [Webb-CI 39857451898](https://github.com/heke99/plockivo-web/actions/runs/39857451898) PASS: npm ci, standardkontroll, typkontroll, 4 tester och produktionsbygge. Vercel-testdrift tillkom i DEPLOY-003. Endast dokumentation uppdateras efter denna kodcommit.

## Vercel-testdrift

API b245c5d och webb 9356732 driftsatta i separata Div3rsa-projekt, Node 24, arn1, med skydd kvar. HTTP och browser hela vägen till DB PASS, inklusive sparad korg, testorder, replay, Secure HttpOnly host-only cookies, logout/401 och mobil. Tre avsiktliga testorder gav 75000 öre exponering/projektåtagande och sex köade outboxjobb. Worker avstängd; inga externa leveranser påstås. Testdata städade med readback 0. Kvalitetskontroller och båda reponas CI PASS. Se API-repots docs/work/DEPLOY-003.md för komplett scenariomatris och begränsningar.

## WORKER-004 — 2026-10-23

Se [arbetsdokumentet](work/WORKER-004.md) för aktuell workerdrift; tidigare uppgifter om saknade worker-nycklar och avstängd cron avser DEPLOY-003:s testfönster. Sju API-tester, typkontroll och rent produktionsbygge PASS. Kod-CI [39925021159](https://github.com/heke99/plockivo/actions/runs/39925021159) PASS för ac511b3. Två samtidiga scans startade fyra Workflow-körningar för två jobb; databasreadback visade ett JSON-dokument och attempts=1 per jobb. Ny scan gav started=0.

Automatisk cron 08:35 UTC PASS på b1cf517: två nya jobb behandlades utan manuell trigger, exakt ett ytterligare dokument. Efter städning: 0 handlare/order/korgar/jobb/dokument/testidentiteter. Tillfällig teståtkomst återkallad. Inga riktiga utskick.

## MFA-005 — 2026-10-23

TOTP-flöden och aktuell MFA-kontroll i SQL/API tillagda; se [arbetsdokumentet](work/MFA-005.md). Samtliga tre SQL-sviter PASS efter de två nya migrationerna. Sju API-tester och produktionsbygge PASS. MFA-förlust, säkerhetsnotiser och inbjudningar återstår.

MFA-005: driftsatt aktivering, ny login med kodkrav, API 403→200, mobil 390px, Secure HttpOnly host-only cookies och utloggning/401 PASS på API 0d609fe och webb 9e1a63f. CI 39942123792/39955297867 PASS. Åtta städreadbacks inklusive Auth-faktorer och sessioner =0. Full pilot fortsatt RED.
