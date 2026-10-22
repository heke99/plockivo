# Checkpoint — 2026-10-22

## Mål och faktisk leverans

Påbörja Plockivo enligt masterplan v2.2 och startkit 3.0.0 med DEL-3603:s sammanhängande grundflöde. **Inte pilotklart.** API och separat webb är implementerade. Produktägaren har uttryckligen godkänt offentlig publicering; API-grunden finns i heke99/plockivo. Webbens separata GitHub-repo saknas. Ingen Verceldeploy eller DNS-ändring är genomförd.

## Verifierat

- Båda apparna typkontrolleras och bygger. 4 API-tester och 4 webb-/CSRF-tester passerar.
- Komplett browserresa på slutbygget passerar inklusive återupptagen order, local logout, 401 efter logout och mobilvy.
- Transportvalidering och versionslåst genererad klient finns.
- Riktiga authenticated-rolltester i Supabase: tenantisolering, scopes, spärr, attest utan självattest, låsta priser, versions-/hashkonflikt, replay, ett köp → en order, kredit/projektbudget, audit/outbox och idempotent testdokument.
- Två parallella SQL-sessioner: en accepterad order på 75000 öre och ett nekat köp; kredit och projektåtagande 75000 öre.
- HTTP genom verklig Auth, webbproxy, API och databas: login, kontext, streckkod, underlag, order, replay, läsning, Origin-skydd, authkrav och logout.

Detaljer och kvarstående verifieringsluckor finns i [verifieringsrapporten](VERIFICATION.md).

## Miljö och version

Supabase cqznytuyutrqenbbyczc, utveckling med endast syntetiska testdata. Migrationer: 20261022194600 foundation, 20261022200352 test_worker, 20261022200506 boundary_hardening, 20261022201304 query_indexes, 20261022210808 persistent_carts. Filnamnen har synkats till serverns tillämpade versioner utan innehållsändring. API-kontrakt 0.2.0.

## Nästa exakta handling

1. [CARTS-002](work/CARTS-002.md) verifierat: ägd serverkorg, versionskontroll, en quote per revision, atomisk invalidation och ny korg efter order. SQL-rolltester, samtidiga ändringar, slutlig browseromkörning och GitHub CI passerar. API-kodcommit 0dd58b9; se verifieringsrapporten.
2. API 0.2.0 är publicerat. Skapa separat plockivo-web-repo: anslutningen saknar create-repository; GitHub-sidan avvisade ett säkert inloggningsförsök med fel användarnamn/lösenord. Webbens testade källkod bevaras som separat ZIP.
3. Provisionera separata Vercelprojekt och testmiljöer; konfigurera worker och verifiera Workflow-recovery. Webb får inga workerhemligheter.
4. Fortsätt med inbjudan/MFA, handlarkonfiguration och verklig ERP-kapacitetsprofil. Därefter utlämningsanspråk, delutlämning/annullering, ekonomisk radallokering och returer.

## Blockerare före verkliga köp

ERP och kreditauktoritet ej valda; Creditsafe och avsändaravtal saknas; juridiskt plattformsbolag/pilotprofil ej verifierade; inga riktiga utskick, fakturor, PDF:er, lager- eller utlämningseffekter. MFA, backupövning, per-handlardomän/PWA-identitet, fysisk telefonkamera och full pilot-E2E återstår. Databasoperationen vägrar production-mode. Bevara denna spärr tills berörda krav är verifierade.
