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


## INVITES-006 — publicerad testleverans

Säkra personinbjudningar och UI/framsida implementerade. SQL-rollmatris och lokala kvalitetskontroller PASS. Browser, mobil/framsida, säker replay och städning PASS; API och webb publicerade och Vercel READY. Actions står i kö vid slutkontroll. Evidens finns i [INVITES-006](work/INVITES-006.md). Kontoaktivering och riktiga utskick återstår.

## PROFILE-007 / DOMAIN-008 — 2026-10-25

Administrativ handlarprofil med revisionskontroll, MFA, idempotens och audit implementerad. Domänönskemål kan registreras/listas/tas bort; ingen kundstyrd verifiering eller aktivering. Riktade SQL-rolltester och 12 API-tester PASS. Båda produktionsbyggena PASS. Browser: MFA, spara namn/färg/logotyp, readback, reload, samtidig ändring med behållen draft, återhämtning, nekad bildtyp och domänregistrering/borttagning PASS. Responsivitet och inga pageerrors PASS. Bred SQL-regression hängde och avbröts utan resultat; får inte räknas som PASS. Offentlig branding, domänaktivering, hostresolver och PWA-bindning återstår. Se API-arbetsdokument PROFILE-007 och DOMAIN-008.

## Fyra delar 010–013 — 2026-10-25

ONBOARDING-010: inbjudningsbunden kontoaktivering implementerad, gated av verifierad leverans och bekräftelsepolicy. Ingen verklig e-postleverans eller signup-email-callback kedja testad. RECOVERY-011: fasta callbacklägen/origin, no-referrer, explicit leveransspärr, MFA-skyddat lösenordsbyte och auktoritativ sessionsspärr. SESSIONS-012: egen global utloggning med beständig SQL-spärr; SQL-rolltest PASS. DOCS-013: läsning av sparad testköpbekräftelse med order/doc RLS; verkligt SQL-worker-readback PASS. UI-prov med intercepted API är separata visningsbevis. Webb verify 21 tester och API verify 12 tester/build PASS. Inga nya persistenta fixtures; SQL-sviter rollback. Domänaktivering, verkliga utskick, MFA-förlust och verklig pilot återstår.

## Delar 014–017 — 2026-10-26

EMAIL-014: avsändarvalidering och mailmallar testade; verklig e-postaktivering BLOCKED. Resend403 domängräns, ingen verifierad plockivo.com och ingen ansluten SMTP-konfiguration. MEMBERS-015: kod och tester för mandatåterkallelse förberedda, hosted migration auto-review avvisad, ingen SQL-rolltest; MERCHANT_MEMBER_ADMIN_ENABLED=false. OPERATIONS-016: read-only MFA/tenant-jobböversikt, riktig SQL och UI PASS. HISTORY-017: tydligt begränsad senaste50 lista, sökning/status/pagination inom hämtad mängd. API verify PASS; sammanförd webbkontroll i arbetsdokumenten. Ingen domänaktivering eller verkliga köp.

## Godkänt MEMBERS-015 och READINESS-018 — 2026-10-26

Exakt mandatmigration godkänd av användaren, tillämpad som20261025231731_member_administration och rolltestad PASS (scope/self/admin/version/replay/audit/omedelbar åtkomstförlust). Vercel API production MERCHANT_MEMBER_ADMIN_ENABLED=true inför nästa deployment. READINESS-018 informativ versionsstyrd integrationsinventering implementerad, länk från hjälp. API verify/build PASS, webb verify26 tester/build och browser mobil/dator PASS. Inga verkliga integrationsförmågor aktiveras av inventeringen. E-post kräver fortfarande verifierad avsändare/SMTP.
