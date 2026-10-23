# Checkpoint — 2026-10-23

## Mål och faktisk leverans

Påbörja Plockivo enligt masterplan v2.2 och startkit 3.0.0 med DEL-3603:s sammanhängande grundflöde. **Inte pilotklart.** API och separat webb är implementerade. Produktägaren har uttryckligen godkänt offentlig publicering; API-grunden finns i heke99/plockivo. Webbens separata repo heke99/plockivo-web är skapat av produktägaren och version 0.2.0 publicerad. Skyddad Vercel-testdrift är genomförd: https://plockivo-web.vercel.app och https://plockivo-api.vercel.app. Inga egna domäner eller DNS-ändringar.

## Verifierat

- Båda apparna typkontrolleras och bygger. 7 API-tester och 4 webb-/CSRF-tester passerar.
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
2. API och webb 0.2.0 är publicerade i heke99/plockivo respektive heke99/plockivo-web. Webbens källkod motsvarar kodcommit abbb0ed381d2473ec0125e0dac0dc2d5ed0df1f1; webbens GitHub CI 39857451898 PASS.
3. [DEPLOY-003](work/DEPLOY-003.md) PASS för det begränsade driftsatta testköpet. WORKER-004: servernycklar konfigurerade; verkliga Workflow-starter, kvarvarande jobb efter ny deployment och parallell idempotens verifierade. Cron var femte minut verifierad 08:35 UTC. Två testorder gav exakt två dokument; alla testdata städade. Se [WORKER-004](work/WORKER-004.md).
4. [MFA-005](work/MFA-005.md) verifierat och driftsatt: TOTP, kodkrav vid ny login, aktuell MFA/session i SQL och faktorbyte. API 0d609fe, webb 9e1a63f; båda kod-CI PASS. Testdata/faktorer/sessioner städade. Nästa produktsteg är personinbjudan/provisionering, därefter handlarkonfiguration och verklig ERP-kapacitetsprofil. Därefter utlämningsanspråk, delutlämning/annullering, ekonomisk radallokering och returer.

## Blockerare före verkliga köp

ERP och kreditauktoritet ej valda; Creditsafe och avsändaravtal saknas; juridiskt plattformsbolag/pilotprofil ej verifierade; inga riktiga utskick, fakturor, PDF:er, lager- eller utlämningseffekter. MFA-förlust/återställning och säkerhetsnotiser, backupövning, per-handlardomän/PWA-identitet, fysisk telefonkamera och full pilot-E2E återstår. Databasoperationen vägrar production-mode. Bevara denna spärr tills berörda krav är verifierade.


## INVITES-006 — aktivt arbete

Säkra personinbjudningar och UI/framsida implementerade. SQL-rollmatris och lokala kvalitetskontroller PASS. Slutlig browser, publicering och städning följs i [INVITES-006](work/INVITES-006.md). Kontoaktivering och riktiga utskick återstår.
