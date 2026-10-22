# BOOTSTRAP-001 — verifierbar grund

Aktör: person med handlarbundet inköpsmandat. Ingång: webb → sessionsproxy → /v1 → Supabase JWT/RPC. Mål: låst testunderlag, eventuell oberoende attest, explicit bekräftelse och högst en accepterad testorder med exakt kredit-/projektbelastning samt beständigt dokument-/meddelandeuppdrag.

## Regelägare och avgränsning

Permissions och ekonomisk transaktion: versionsstyrd SQL. Transport: API:s Zod-scheman och OpenAPI 0.1.0. Webb hanterar presentation och session. Testprisadapter kan inte användas för production-handlare. Databas- och API-gränser kontrollerar samma aktör; service key är worker-identitet, inte köparmandat.

## Verifieringsmatris

| ID | Risk | Scenario | Metod |
| --- | --- | --- | --- |
| B001 | P0 | Tillåtet testköp och bestående order | DB + HTTP + browser |
| B002 | P0 | Fel handlare och fel kundkonto | Riktig authenticated-roll, RLS/RPC |
| B003 | P0 | Aktuellt spärrat medlemskap | Äldre JWT-subjekt, nytt anrop nekas |
| B004 | P0 | Atomisk kredit och projektbudget | Två parallella DB-sessioner + readback |
| B005 | P0 | Samma nyckel/olika kropp och samma köp/olika nycklar | SQL + HTTP |
| B006 | P0 | Underlag ändrat, saknad hash, för gammal version | SQL + Zod |
| B007 | P0 | Krävd attest och förbjuden självattest | SQL med köpare/attestant |
| B008 | P0 | Direkta tabellskrivningar och workeråtkomst | authenticated nekas |
| B009 | P0 | Dokument och audit/outbox utan dubbletter | Service-rolltest, readback |
| B010 | P0 | Sessions-/Origin-skydd | HTTP via webbproxy |
| B011 | P1 | Mobilvy och återupptagen order | Browser |
| B012 | P0 | Verkliga leverantörer, okänt utfall, fysisk utlämning | Blockerat — ej implementerat för verklig drift |
| B013 | P0 | Workflow-körning efter avbrott/deploy | SDK bygger; verklig körmiljö saknas |
| B014 | P0 | Backup, MFA, inbjudningar och pilottelefoner | Planerat före pilot |

## Fynd och rättningar

- F001: Otydligt korrelerad merchant-policy kunde använda membership-id. Kvalificerad outer row korrigerad i test_worker-migration och RLS-rolltest.
- F002: Null-jämförelse vid direkt RPC kunde missa saknad quote_hash. IS DISTINCT FROM samt test för saknad hash infördes innan foundation tillämpades.
- F003: Store-scopat medlemskap tappade projekt i context-DTO. Korrigerad scopefråga i boundary_hardening; rolltest verifierar resultat.
- F004: Auth-E2E-fixtur saknade identity timestamps. Syntetisk fixture rättad; normal personprovisionering måste gå via leverantörens stödda gränssnitt.
- F005: Avsaknad av relevanta FK-/tenantindex. Query-indexmigration tillagd; inget skalbarhetslöfte härleds från detta.
- F006: Sen katalogrespons kan hamna efter mandatbyte. Webb avgränsar respons till aktivt medlemskap och låser byte under pågående kommando.
- F007: Supabase/transport kunde vänta obegränsat. Tidsgränser införda; kunden instrueras kontrollera samma köp vid oklart svar.
- F009: Vissa browseranrop saknade Origin; avgränsad same-origin metadata-/custom-headerkontroll och tre CSRF-regressionstester införda. Ordinarie logout är explicit local, återställning global.
- F008: Första publika pushen krävde uttryckligt godkännande. Godkännande inkom och API-grunden publicerades via GitHub-anslutningen.

## Kvarvarande arkitekturarbete

Beständig varukorg levereras i CARTS-002. Kvarstår: per-person-periodbudget, robust generell integrationsinbox/outbox med unknown/avstämning, dokument-PDF/privat Storage, notismottagare och avsändare, verifierade domäner, MFA/inbjudan och full tilldelningsadministration. Återanvänd nuvarande domänoperationer; skapa inga alternativa ekonomiska CRUD-vägar.
