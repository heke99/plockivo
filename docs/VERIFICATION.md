# Verifieringsrapport — Plockivo 0.1.0

## Utlåtande

**RED för verklig pilot.** Ett sammanhängande testflöde är implementerat och systemverifierat för de gränser som anges nedan. Saknade P0-flöden får inte beskrivas som färdiga eller driftsatta. Ingen Vercelrelease har gjorts.

Miljö: lokala produktionsbyggen av API och webb, Supabase utvecklingsprojekt cqznytuyutrqenbbyczc, syntetiska handlare och testidentiteter. API-kontrakt 0.1.0. Engineering Startkit 3.0.0. Releasecommits registreras vid avslut i leveransmanifestet.

## Resultat

| Kontroll | Resultat | Evidens och begränsning |
| --- | --- | --- |
| API/webb typecheck och build | PASS | npm run typecheck, npm run build i respektive projekt |
| API:s transportvalidering | PASS | 3 tester: otillåtna actor/prisfält, exakt decimalformat/gränser, immutable bekräftelse |
| Webbens kontraktslåsning och CSRF | PASS | 4 tester: kontraktslåsning och origin/metadata/custom-headergräns.  Genererad OpenAPI-klient med version och SHA-256 |
| RLS/RPC/transactions | PASS | tests/database.sql körd i verklig authenticated- och service-roll, rollback |
| Attest | PASS i DB | Krävd attest, självattest nekas, annan behörig person godkänner; slutbekräftelse separat |
| Samtidig kredit | PASS | 2 parallella sessioner med 75000 öre vardera mot 100000; en order, exponering och projektåtagande 75000 |
| HTTP med verklig Auth/BFF/API/DB | PASS | Personlogin → kontext → barcode → quote → confirm → replay med ny nyckel → orderreadback; Origin 403, auth 401, logout 200 |
| HttpOnly och cookieomfång | PASS via HTTP | Set-Cookie kontrollerad för HttpOnly och avsaknad av Domain. Webbläsarbeteende dokumenteras separat. |
| Dokumentworker i databas | PASS | En JSON-köpbekräftelse, inga dubbletter; notifiering stannar manual_review |
| Vercel Workflow | Delvis | SDK bygger 1 workflow; service key/körmiljö saknas för verklig återstarts- och deployverifiering |
| Säkerhetsadvisors | 1 konfigurationsvarning kvar | Leaked Password Protection är avstängd i Supabase Auth. [Åtgärd](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Därutöver avsiktliga INFO om deny-all-tabeller utan appgrants. |
| Browser desktop/mobil | PASS för första fulla testresan | Chromium/Playwright: inloggning, manuell streckkod, underlag, order, reload, historik, återupptagning, logout, 401 efter logout, HttpOnly host-only cookies och 390px utan horisontell overflow. Inga pageerrors. Slutomkörningen passerade efter explicit local logout och optimerad sessionsproxy. |
| Fysisk kamera/PWA-installation | NOT RUN | Verkliga pilottelefoner och etiketter återstår. |
| Verklig ERP/Creditsafe/e-post | BLOCKERAT | Avtal, produkt och testanslutning saknas |
| Fysisk utlämning/faktura/retur | NOT RUN | Ej implementerade i denna grundleverans |
| Backup/MFA/inbjudningar/domäner | NOT RUN | Återstår före pilot |
| GitHub CI | NOT RUN | Workflow-filer finns; push stoppad och inget kört GitHub-jobb påstås |

## Databas och migrering

De fyra lokala migrationsfilernas namn är synkade mot serverns migrationshistorik. Testerna körs under verkliga approller och provar förbjudna direktvägar, inte bara owner-anrop. Lokal full replay med Docker är inte körd i denna miljö; CI-jobb för replay finns. Inga riktiga kunddata eller utskick har använts. Manuell SQL-provisionering av auth-identitet användes endast för temporär isolerad testidentitet, inte som produktens onboarding.

## Kvarstående produktionsrisker

Testpris och lokal kreditreservation bevisar inte samordnad kredit över en handlares andra säljkanaler. API-kvoten är ett transportskydd; direkta skyddade RPC-vägar behöver egen kostnads-/kapacitetsbedömning före pilot. Operativa larm, verklig jobbrecovery, PDF/Storage, återställning och komplett kundlivscykel är inte verifierade. Masterplanens kapitel 38 styr verklig start.

## Observerade externa beroenden

Leaked Password Protection måste aktiveras och verifieras i Supabase Auth före verkliga konton; ingen stödjande inställningsmutation fanns i anslutna verktyg. [Officiell konfiguration](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Den automatiska GitHub-publiceringsgranskningen nekade push till publikt repo; detta är en publiceringsblockerare, inte ett testfel i köptran­saktionen.

## Slutkontroll och städning

2026-10-22: sista browserresan passerade på de byggda API-/webbkodbaserna med HttpOnly cookies, enbart localhost som cookiedomän, inga pageerrors, skyddad endpoint 401 efter logout och mobil 390px utan overflow. Temporära browserhandlare, order och auth-identiteter är borttagna; readback visade 0 handlare, 0 order och 0 E2E-identiteter. Rolltesterna använder rollback och lämnar inga verksamhetsrader.
