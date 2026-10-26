# RETURNS-022 — testreturmottagning

Fysisk returmottagning registreras mot en bekräftad utlämningsclaim och ursprunglig orderrad. Endast synthetic test-mode med explicit returns.receive.test och aal2. Inga verkliga varor, lagerdestinationer eller kreditfakturor.

Gemensamt orderlås från fulfillment_lock följs av radlås. Kumulativ mottagen mängd per källclaim/rad får inte överstiga claimens bekräftade mängd. Total returned_quantity får inte överstiga fulfilled_quantity. Rad- och orderidentitet härleds från verifierad order/claim, aldrig klientens tenant. Versionskontroll, idempotensresultat och audit committas med mottagningsraden. Retry med samma nyckel returnerar samma resultat utan ytterligare receipt/audit. Tillstånd är received, financial_status not_requested; mottagning betyder varken godkännande, återlager eller ekonomisk korrigering.

RPC receive_test_return(p_order,p_body,p_key,p_correlation). Body version, claim_id, order_line_id, quantity decimalsträng högst6 decimaler, condition unopened/opened/damaged/unknown, reason1–500. Svar receipt+state. Transportvalidering nekar actor/tenant/credit/status-injektion.

## Verifierat

Migration APPLY terminal success; serverversion20261026004455_test_return_receipts.sql synkad. tests/returns.sql med riktiga authenticated-rollkontexter terminal PASS: pending claim nekad, confirmed mottagen, source/aggregate cap, versionkonflikt, replay, exakt en receipt/audit, kreditreservation50000 oförändrad, cross-tenant och direkt tabellåtkomst nekade. Transaktionen rollback, inga persistenta fixtures.

Två tests/return-input.test.mjs PASS; API typecheck PASS. Sammanförd build/UI/OpenAPI ägs av core/parent. Ingen browser eller concurrent multi-session return race påstås testad här; orderlås serialiserar samma order i SQL. Ingen automatisk timeout eller ekonomisk release.

Slutomkörning utökad: en andra bekräftad källclaim lämnar utrymme i aggregate men överretur på första claimen nekas fortfarande. Cross-tenant-provet använder egen verifierad MFA-session och merchant_admin i tenant B, så nekandet bevisar tenantgränsen snarare än bara saknad MFA. Utökad SQL-svit terminal PASS.
