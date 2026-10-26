# BILLING-023 — read-only synthetic billing underlay

Read-only cumulative allocation of original frozen order-line net/vat to confirmed fulfilled quantity. No invoice, posting, billed counter, credit/budget release or return credit is created. Repeated reads cannot bill twice because there is no posting operation. Full fulfilled row allocates exactly original totals; cumulative partial half-up prevents summed per-claim rounding drift.

Only full merchant_admin with billing.read.test, current MFA/session and test order/merchant can read. Single order FOR SHARE serializes with fulfillment order FOR UPDATE. Original financial totals are used, not current catalog prices. Returns shown independently and never automatically subtract money.

Pending migration20261026005219_test_billing_underlay.sql was rejected by automatic review: persistent shared schema+merchant-admin permission expansion not explicitly authorized for exact billing access/blast radius. No retry or workaround. TEST_BILLING_UNDERLAY_ENABLED defaults false before RPC. SQL real-role test prepared but UNRUN. Two exact allocation unit tests PASS; remaining typecheck/browser checks below. No external systems, emails or persistent fixtures used.

Public API GET /v1/fulfillment/{id}/billing-underlay, TestBillingUnderlay UI component. Parent owns workspace integration. Need exact migration approval before apply and real SQL test, then optional test-only activation. No production billing capability implied.

## Slutlig verifiering

API verify PASS22 tester, typkontroll, standard och produktionsbygge. Webb verify PASS28 tester, typkontroll, standard och produktionsbygge. Chromium UI-only prov på port3723 PASS: frysta belopp, inte-faktura-märkning, gated503 rensar gammalt underlag,390/768/1440 utan overflow, inga pageerrors. Kontrollerade API-svar ger inte SQL-/Auth-bevis. SQL-rollmatris fortfarande UNRUN på grund av avvisad migration. Inga persistenta testdata eller externa effekter skapade.
