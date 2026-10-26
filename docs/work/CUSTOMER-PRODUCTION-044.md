# Kundadministration042–044 — fyra produktionsdelar

2026-10-26: kundstatus/aktivering, manuell kredit/köpstopp, villkorsversion/manuell granskning samt versionskontroll/idempotens/audit. Verkliga administratörsoperationer, ingen mode=test-spärr. Merchant-manual är uttrycklig beslutskälla; inga Creditsafe-resultat eller kundacceptanser fabriceras. Inga befintliga kundkonton ändrades genom själva migrationen.

## Resultat
API38 tester, webb52 tester, typkontroll/standard och båda produktionsbyggen PASS. Nya migrationen20261026184104 tillämpad. Hosted tests/customer-policy-simulation.sql PASS med riktiga authenticated/AAL2-roller. Privat tabell saknar direkt authenticated read/write; anon kan inte köra mutation. Befintligt customers.manage och aktuell MFA krävs även för produktionshandlare.

| Scenario | Resultat |
|---|---|
| Prod-kund suspended/blocked0 → explicit aktiv/reviewed/unblocked/termsv1/limit100000 |PASS hosted |
| GET rätt konto/tenant + aktuella policyfält |PASS hosted |
| Samma key/body replay och ändrat body/idempotenskonflikt |PASS hosted |
| Stale policyversion och otillräckligt underlag |PASS hosted nekanden |
| Minska limit under befintlig exposure |PASS exposure oförändrad |
| Suspendera testkund med befintlig reservation |PASS order/project/reservation/exposure oförändrade |
| Fel tenant/konto, riktig buyer AAL2 och admin AAL1 |PASS nekanden |
| Policy aktiverar inte productioncheckout automatiskt |PASS fortsatt INTEGRATION_NOT_READY |
| Rollback |PASS15cleanupfält0 |
| Inloggad browserresa och extern SMTP |NOT RUN utan testkonto |

Alla mutationer är atomiska med kundradlås, policyversion, command replay och audit. Kreditram, status, köpblockering och terms_version uppdateras bara genom uttrycklig manuell begäran; exposure och existerande reservationer påverkas inte. Granskning ger inte automatiskt aktiv status eller öppet köp. Den nya adminvyn bevarar konflikt-draft, använder samma nyckel vid oförändrat återförsök, varnar vid kundbyte med osparade ändringar och skiljer manuell bedömning från extern verifiering.

Syntetisk isolerad testnamnrymd34000000. Slutreadback efter rollback: audit/users/orders/outbox/stores/factors/intents/accounts/commands/policies/projects/sessions/merchants/memberships/reservations0. Inget permanent testkonto eller verkligt kredittillstånd har skapats. Ingen låtsasproduktion genom att avlägsna mode-kontroller i gamla testpriser/order/worker.

Release verdict RED för full försäljning: kundadministration fungerar i produktionsläge, men produktionens pris-/lager-/order-/fakturaauktoriteter, worker och helbrowserkedja är inte färdigverifierade. Produktionsköp och fakturering får inte beskrivas som färdiga. Följande implementeringsetapp behöver färdigställa standalone-produktionsprofil och dess genomgående order-/ekonomiflöde.
