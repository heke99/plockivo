# PRODUCTION-API-050 — HTTP-integration för fristående drift

## Endpoints

Alla endpoints ligger under /v1. GET production/setup tar tenant_id i query. POST production/setup, production/catalog, production/stock, production/stores, production/projects använder respektive strikt production*Input och befintligt Idempotency-Key/correlation. POST merchant-bootstrap använder merchantBootstrapInput. POST production/invitation-access använder customerInvitationSetupInput och RPC setup_customer_invitation_access.

GET production/orders/:id och GET production/orders/:id/billing validerar path-UUID innan RPC. POST production/orders/:id/complete tar strikt version0..2147483646, recipient_reference1..100 och checked:true. POST .../cancel tar strikt version och reason1..500. Ingen klientstyrd tenant/actor/roll, lagerkvantitet eller kreditfrigöring accepteras för dessa orderoperationer.

## Säkerhet och fel

Inga nya produktions-featuregates. Verifierad användaridentitet, befintlig API-kvot och JSON-/storleksgränser gäller för alla. Användarens JWT går till RPC; inga service keys. Aktuell admin-/personalbehörighet och MFA verkställs av befintliga SQL-entrypoints. POST kräver application/json, bodyhögst32768bytes och validerad idempotensnyckel. Svar no-store med correlation ID.

SQL-fel matchas centralt exakt mot messages-map via knownSqlErrorCode. Nya fasta meddelanden för STOCK_UNAVAILABLE, INVENTORY_CONFLICT, FULFILLMENT_REQUIRED, FULFILLMENT_STATE_CONFLICT. Okända SQL-/leverantörsfel ger INTERNAL_ERROR, aldrig rå stack/details. API-schemafel400, auth401, permission/MFA403, notfound404, kvot429 och domänkonflikter409.

## Verifiering

Tre nya schema-/feltester PASS. Samlad API typecheck och47 Node-tester PASS före051-importen (se huvudagent för slutlig sammanförd kontroll). Route/API-kontraktens generering ägs av separat agent. Inga SQL-migrationer, publiceringar eller externa utskick gjorda i detta steg.

## Administrativ orderkö — efter 051

GET production/orders?tenant_id läser list_production_orders. Egen kö behövs eftersom handlaradmin saknar den äldre köphistorikens orders.read.store. Ny SQL-migration 20261026202506_production_order_queue.sql återanvänder production.fulfillment.read och filtrerar varje order med befintlig production_order_authorized utan owner-fallback. Current AAL2 och aktivt scopedmandat krävs. DTO items[{order_id,purchase_intent_id,total_minor,state,created_at}],limit50,has_more. Senaste50 enligt created_at/id; inga tysta obegränsade exporter, inga nya permissionsgrants. Separat verifieringsagent kör SQL-rolltester och apply; API-route är integrerad utan featuregate.
