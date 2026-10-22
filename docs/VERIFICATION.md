# Verifieringsrapport — Plockivo 0.2.0

## Utlåtande

**RED för verklig pilot.** Ett sammanhängande testflöde är implementerat och systemverifierat för de gränser som anges nedan. Saknade P0-flöden får inte beskrivas som färdiga eller driftsatta. Ingen Vercelrelease har gjorts.

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
| Vercel Workflow | Delvis | SDK bygger 1 workflow; service key/körmiljö saknas för verklig återstarts- och deployverifiering |
| Säkerhetsadvisors | 1 konfigurationsvarning kvar | Leaked Password Protection är avstängd i Supabase Auth. [Åtgärd](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Därutöver avsiktliga INFO om deny-all-tabeller utan appgrants. |
| Browser desktop/mobil | PASS för första fulla testresan | Chromium/Playwright: inloggning, manuell streckkod, underlag, order, reload, historik, återupptagning, logout, 401 efter logout, HttpOnly host-only cookies och 390px utan horisontell overflow. Inga pageerrors. Slutomkörningen passerade efter explicit local logout och optimerad sessionsproxy. |
| Fysisk kamera/PWA-installation | NOT RUN | Verkliga pilottelefoner och etiketter återstår. |
| Verklig ERP/Creditsafe/e-post | BLOCKERAT | Avtal, produkt och testanslutning saknas |
| Fysisk utlämning/faktura/retur | NOT RUN | Ej implementerade i denna grundleverans |
| Backup/MFA/inbjudningar/domäner | NOT RUN | Återstår före pilot |
| GitHub CI | Omgång 1 delvis godkänd | Quality och migrationsreplay PASS på 339123f; testscript rättat från db query till psql. Ny körning inväntas |

## Databas och migrering

De fem lokala migrationsfilernas namn är synkade mot serverns migrationshistorik. Testerna körs under verkliga approller och provar förbjudna direktvägar, inte bara owner-anrop. Lokal Docker saknas i arbetsmiljön. GitHub CI:s första körning byggde om databasen från de fyra dåvarande migrationerna; quality PASS, testscript FAIL eftersom CLI db query inte stöder transaktionsskript. Testkommandot är rättat till psql i Supabase-containern; ny CI-körning inväntas. Inga riktiga kunddata eller utskick har använts. Manuell SQL-provisionering av auth-identitet användes endast för temporär isolerad testidentitet, inte som produktens onboarding.

## Kvarstående produktionsrisker

Testpris och lokal kreditreservation bevisar inte samordnad kredit över en handlares andra säljkanaler. API-kvoten är ett transportskydd; direkta skyddade RPC-vägar behöver egen kostnads-/kapacitetsbedömning före pilot. Operativa larm, verklig jobbrecovery, PDF/Storage, återställning och komplett kundlivscykel är inte verifierade. Masterplanens kapitel 38 styr verklig start.

## Observerade externa beroenden

Leaked Password Protection måste aktiveras och verifieras i Supabase Auth före verkliga konton; ingen stödjande inställningsmutation fanns i anslutna verktyg. [Officiell konfiguration](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Offentlig publicering är nu uttryckligen godkänd; API-grunden är publicerad. GitHub-inloggning saknas i shell/browser för att skapa webb-repot.

## Slutkontroll och städning

2026-10-22: sista browserresan passerade på de byggda API-/webbkodbaserna med HttpOnly cookies, enbart localhost som cookiedomän, inga pageerrors, skyddad endpoint 401 efter logout och mobil 390px utan overflow. Temporära browserhandlare, order och auth-identiteter är borttagna; readback visade 0 handlare, 0 order och 0 E2E-identiteter. Rolltesterna använder rollback och lämnar inga verksamhetsrader.

## CARTS-002 — 0.2.0

Migration 20261022210808 tillämpad i utvecklingsprojektet. tests/carts.sql PASS med authenticated: sparande, tom korg, replay, annan person/samma konto, fel konto/tenant, återkallat mandat, gammal version, en quote per revision, invalidation och atomisk rollback vid felaktig mängd. Två samtidigt inskickade version-1-ändringar: en version 2, en VERSION_CONFLICT; ingen överskrivning. Browser PASS för sparad referens/mängd efter reload, underlag, order, återupptagen order och nästa tomma korg samt logout/mobil. Slutlig browseromkörning efter mandat-/logoutjustering PASS; inga pageerrors, host-only HttpOnly cookies, 401 efter logout och mobilvy utan overflow. Testdata städade: 0 handlare, order, korgar och E2E-identiteter. Produktionsrisker ovan kvarstår.
