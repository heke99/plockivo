# RECEIVABLES-TRANSPORT-056 — API, BFF och typkontrakt

Tre exakta endpoints: GET /v1/production/orders/:id/receivables, POST /v1/production/orders/:id/payments och POST /v1/production/orders/:id/payments/reverse. Path-UUID valideras före RPC. Record och reversal använder de strikta productionPaymentInput/productionPaymentReversalInput som ägs av SQL-domänen. Befintlig verifierad användaridentitet, API-kvot, application/json, 32KB bodytak, Idempotency-Key och correlation gäller. Inga nya featuregates eller service-role-anrop.

API forwards till get_production_receivables(p_order), record_production_payment(p_order,p_body,p_key,p_correlation) respektive reverse_production_payment med samma argument. Tenant-, behörighets- och aktuell MFA-kontroll ligger i SQL. Matchande BFF-allowlist öppnar endast GET för receivables och endast POST för payments(/reverse); inga godtyckliga extra segment eller metoder.

Alla mutationer returnerar samma ProductionReceivables-DTO som läsningen. Nya fasta felmeddelanden och exakta koder PAYMENT_EXCEEDS_BALANCE, PAYMENT_REFERENCE_CONFLICT, PAYMENT_ALREADY_REVERSED, RECEIVABLE_STATE_CONFLICT; okända provider-/SQL-detaljer lämnar inte API:t. Beskrivningen i OpenAPI gör tydligt att detta är handlarens manuella avstämning av en externt mottagen betalning. Ingen betalning initieras, inga bankanrop eller pengaröverföringar görs och ingen faktura utfärdas av transporten.

OpenAPI har ProductionReceivables, ProductionPaymentReceipt, ProductionPaymentReversal och de två strikta inputschemana. Alla belopp är strängar. Ledger visar senaste100 kvittenser med receipts_truncated. API generated.ts regenereras med låsta openapi-typescript7.13.0, kopieras till fristående webbsrc/generated/api.ts och kontraktets SHA256 uppdateras i webblocksfilen.

Verifiering: BFF3 tester PASS; API orderinput/felsanering3 tester PASS. Slutliga API-/webbtypechecks rapporteras separat till huvudagenten. SQL/apply, banksaldo-/krediteffekter och UI verifieras av andra deluppgifter; denna delagent gör inga externa finansiella anrop, migrationer eller publiceringar.

Slutlig avgränsad kontroll: API typecheck PASS efter att domänens helper färdigställts; fem API input-/sanitizationtester PASS. Webb typecheck och fyra BFF-/kontraktstester PASS. Genererad kopia är byteidentisk mellan API och webb, och hash låst till OpenAPI. Fullt sammanfört produktionsbygge och domänens verkliga SQL-tester återstår hos huvudagenten.
