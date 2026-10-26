# CANCELLATION-021 — annullera kvarvarande testmängd

Testoperationen public.cancel_test_order_lines delar orderlås och radbalanser med utlämning. Den kräver aktuell aal2/session och separat orders.cancel.test-mandat enligt core-helpern. Order och handlare måste vara test. Body innehåller förväntad version, orsak och unika positiva rader. SQL validerar transporten igen.

Aktiva och oklara anspråk kan inte annulleras. Endast accepterat minus anspråk, bekräftat utlämnat och tidigare annullerat är tillgängligt. Hela operationen är atomisk med audit och nyckelbaserad replay. Ändrad mängd ogiltigförklarar tidigare kontroll genom inspection_status=pending. Varken kreditreservation, projektbudget, lager eller ekonomiska externa system ändras; ekonomisk frigöring kräver separat bekräftad auktoritet.

API-kontrakt: POST /fulfillment/{order_id}/cancel, Idempotency-Key, {version,reason,lines:[{product_id,quantity}]}. Resultat är samma fulfillment-state som läsning. UI ägs av fulfillment_ui.

Verifiering: tests/cancellation-input.test.mjs PASS. tests/cancellation.sql förberett med riktig authenticated-roll, claim-conservation, revision, replay, audit, cross-tenant-denial och oförändrad kreditreservation. SQL-resultat ännu ej observerat av denna delagent. Core först; migrationsordning20261026004250 core,20261026004349 cancellation. Ingen verklig utlämning eller ekonomisk korrigering är aktiverad.

## Hosted-verifiering blockerad

apply_migration avvisades av automatisk godkännandegranskning: "This applies a persistent Supabase schema and permission change, including granting cancellation authority to merchant roles, which is not explicitly authorized for this database or blast radius." Ingen omväg eller ny exekvering gjordes. Migrationen är inte tillämpad; riktig SQL-rollmatris är därmed ännu inte körd. Funktionen måste hållas avstängd med TEST_CANCELLATION_ENABLED=false och behöver exakt godkännande av migrationen och rollmandatet innan liveprov.
