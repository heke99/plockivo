# Import — E2E-verifiering 034

## Release verdict
RED för full kunddrift: autentiserad browser→API→DB-kedja, leverans av e-post och fysisk telefon kräver fortfarande testkontot. Avgränsad importimplementation har godkända kodtester och riktiga DB-rollprov; detta är inte en fullständig P0-friskförklaring.

## Execution identity
2026-10-26. API heke99/plockivo main; separat webb heke99/plockivo-web main, Next16.4.2/React19.2/Node24, låsta npm-beroenden. Supabase plockivo eu-north-1. Vercel Div3rsa API+web production deployment, verksamhetsdata syntetiska. Exakta slutrevisioner finns i publicerade Git-commits/deployments; lokala träd rekonstruerade med äldre Git-bas och därför diffas utvalda publiceringsfiler mot aktuell remote.

## Quality gates
API typkontroll och30 tester PASS. Första API-bygge hade trasig lokal Turbopack-persistens; cache flyttad och separat ombygge PASS. Webb typkontroll och43 tester PASS. API och webb produktionsbyggen PASS; webbsidans slutliga felpresentation kontrolleras på nytt före release. Ingen schemaändring eller ny dependency. OpenAPI genererad och hash/version synkad till webben.

## Scenario summary
| ID | Priority | Flow | Result |
|---|---|---|---|
| IMP01 | P1 | CSV BOM/CRLF/citat/ledande nollor/exakt pris/gränser | PASS kodtest |
| IMP02 | P0 | Full filvalidering före första write | PASS injicerad transport |
| IMP03 | P0 | Commit→timeout→samma key replay, ingen nästa rad | PASS injicerad transport |
| IMP04 | P1 | Paus väntar på aktuellt svar | PASS injicerad transport |
| IMP05 | P0 | 3 riktiga artiklar via authenticated SQL RPC | PASS hosted rollback |
| IMP06 | P0 | Replay/ändrat body/versionskonflikt/unikhet | PASS hosted rollback |
| IMP07 | P0 | Fel tenant, AAL1, audit/commands utan dubblering | PASS hosted rollback |
| IMP08 | P1 | Webbläsarstöd med manuell reservväg | PASS live cloud browser |
| IMP09 | P0 | Autentiserad filväljare→batch→API→DB→UI | NOT RUN, konto ej skapat |
| IMP10 | P0 | Nya bulkendpointen med riktig personlig MFA-session | NOT RUN, konto ej skapat |
| IMP11 | P1 | Fysisk telefon / verklig kamera / mobil filväljare | NOT RUN |
| IMP12 | P0 | SMTP till annan enhet och kontoaktivering | NOT RUN, leverans ej bevisad |

## Database evidence / cleanup
Parent körde hela tests/catalog-import-simulation.sql mot anslutet projekt. Assertions passerade: tre artiklar i A,0 i B;4 audit och4 commands efter update+replays. Alla mutationer skedde genom public.save_standalone_catalog under authenticated AAL2; privilegierad åtkomst användes enbart till fixtures och slutlig readback. Rollback följdes av users0/sessions0/factors0/merchants0/memberships0/catalog_items0/audit_events0/commands0. Inga persistenta testkonton skapade. Proven omfattar inte två samtidiga separata DB-sessioner.

## Browser evidence
Cloud Chrome öppnade /device-check och klickade Kontrollera webbläsarstöd. Säker anslutning/kameraAPI finns; ingen bekräftad BarcodeDetector, korrekt manuell reservväg visas. Ingen kamera eller mikrofon öppnad. ImportUI kräver administrativt konto, så detta är inte ett bevis för autentiserat importflöde.

## Boundaries
UI-import: max2000 rader/2MiB, preview första100 och separat felista, sekventiella individuella transaktioner, stoppa på okänt utfall, samma nyckel i samma flik. Resultat-JSON kan laddas ned. Ingen automatisk bakgrundsresume efter omladdning. API-batch:1–10 nya artiklar, per-row återspelning, HTTP207 stoppad med explicit partial result; ingen batchatomicitet. Alla writes kräver befintliga personmandat/MFA. Ingen maskinidentitet eller automatiskt ERP-utbyte provisionerat. Listvyn hämtar fortfarande högst200 poster. Standalone-registret är inte verklig checkout-auktoritet.
