# Checkpoint — 2026-10-22

## Mål och faktisk leverans

Påbörja Plockivo enligt masterplan v2.2 och startkit 3.0.0 med DEL-3603:s sammanhängande grundflöde. **Inte pilotklart.** API och separat webb är implementerade lokalt. API har lokal Git-historik; publik push stoppades av automatisk approval review. Webbens separata GitHub-repo saknas. Ingen Verceldeploy eller DNS-ändring är genomförd.

## Verifierat

- Båda apparna typkontrolleras och bygger. 3 API-tester och 4 webb-/CSRF-tester passerar.
- Komplett browserresa på slutbygget passerar inklusive återupptagen order, local logout, 401 efter logout och mobilvy.
- Transportvalidering och versionslåst genererad klient finns.
- Riktiga authenticated-rolltester i Supabase: tenantisolering, scopes, spärr, attest utan självattest, låsta priser, versions-/hashkonflikt, replay, ett köp → en order, kredit/projektbudget, audit/outbox och idempotent testdokument.
- Två parallella SQL-sessioner: en accepterad order på 75000 öre och ett nekat köp; kredit och projektåtagande 75000 öre.
- HTTP genom verklig Auth, webbproxy, API och databas: login, kontext, streckkod, underlag, order, replay, läsning, Origin-skydd, authkrav och logout.

Detaljer och kvarstående verifieringsluckor finns i [verifieringsrapporten](VERIFICATION.md).

## Miljö och version

Supabase cqznytuyutrqenbbyczc, utveckling med endast syntetiska testdata. Migrationer: 20261022194600 foundation, 20261022200352 test_worker, 20261022200506 boundary_hardening, 20261022201304 query_indexes. Filnamnen har synkats till serverns tillämpade versioner utan innehållsändring. API-kontrakt 0.1.0.

## Nästa exakta handling

1. Browserresan är omkörd och godkänd; testkonton och affärsrader är städade och readback verifierar 0 kvar. Läs leveransmanifestet för exakt kodläge och testa ny berörd ändring innan fortsatt leverans.
2. Läs [BOOTSTRAP-001](work/BOOTSTRAP-001.md) och [besluten](DECISIONS.md).
3. Vid uttryckligt godkänd offentlig publicering: granska source ZIP, skapa separat plockivo-web-remote och publicera de två självständiga kodbaserna. Push får inte köras före detta godkännande.
4. Provisionera separata Vercelprojekt och testmiljöer, konfigurera worker key/cron och verifiera verklig Workflow-recovery. Webb får inga workerhemligheter.
5. Bygg serverlagrad redigerbar varukorg, inbjudan/MFA, handlarkonfiguration och verklig ERP-kapacitetsprofil innan nästa produktflöde. Implementera sedan utlämningsanspråk, delutlämning/annullering, ekonomisk radallokering och returer.

## Blockerare före verkliga köp

ERP och kreditauktoritet ej valda; Creditsafe och avsändaravtal saknas; juridiskt plattformsbolag/pilotprofil ej verifierade; inga riktiga utskick, fakturor, PDF:er, lager- eller utlämningseffekter. MFA, backupövning, per-handlardomän/PWA-identitet, fysisk telefonkamera och full pilot-E2E återstår. Databasoperationen vägrar production-mode. Bevara denna spärr tills berörda krav är verifierade.
