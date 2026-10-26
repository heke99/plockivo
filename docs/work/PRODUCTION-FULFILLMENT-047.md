# PRODUCTION-FULFILLMENT-047 — full utlämning, annullering och exportunderlag

Status: **Implementerat, ej tillämpat eller hosted-verifierat av delagenten.** Migration skapad med projektets Supabase CLI: [production_fulfillment](../../supabase/migrations/20261026202429_production_fulfillment.sql). [Rollback-simulation](../../tests/production-flow-simulation.sql). Kräver foundation045 och checkout046 före denna migration.

## RPC och affärsregler

- `get_production_order(p_order)` är read-only. Personlig orderägare med aktuellt köparmandat eller butikspersonal med aktuell scope kan läsa. Staff kräver AAL2. Default före fysisk åtgärd: version 0, state reserved; läsningen skapar ingen rad.
- `complete_production_order(p_order,p_body,p_key,p_correlation)`: strikt body `{version,recipient_reference,checked:true}`. Mottagarreferens 1–100 trimmande tecken, hela orderns alla rader omfattas. Aktuell personalbehörighet och AAL2 krävs. Varje lagerpost låses/uppdateras i produktordning; on_hand och reserved minskas exakt med orderkvantiteten, version ökar en gång. Exponering, reservation och projektåtagande ändras inte vid fysisk utlämning.
- `cancel_production_order(p_order,p_body,p_key,p_correlation)`: strikt body `{version,reason}` med skäl 1–500 tecken. Endast hela ordern före utlämning. Reserved lager frisläpps och exakt fullorderbelopp återförs från kundexponering/projektåtagande en gång. Immutable order och original credit_reservations-rad behålls. Den oföränderliga ursprungliga reservationen avstäms mot `production_fulfillment.credit_released_minor`; den senare registrerar exakt återföring. Summan av ursprungliga reservationer är alltså historik, inte aktuell nettoexponering.
- `get_production_billing(p_order)` kräver personalbehörighet/AAL2 och fulfilled. Returnerar oföränderlig ordersnapshot och totalsumma som `ready_for_manual_export`. Ingen faktura, bokföring eller ny kreditreservation skapas av läsningen.

Permissioner på merchant_admin/store_staff: production.fulfillment.read, production.fulfillment.confirm, production.fulfillment.cancel, production.billing.read. Actor/scope kommer från verifierad identitet och memberships, aldrig klientroll. Buyer kan läsa sin egen order men inte bekräfta fysisk utlämning eller läsa personalens faktureringsunderlag.

Mutationslås: serialiserad actor/operation/nyckel → order → merchant → vid annullering account/project/reservation → stock sorterad per product. Same-key replay kräver samma fullständiga body och ger ursprungligt svar. Fullorderstatus och revisionsnummer förhindrar upprepad frisläppning med nya nycklar. Kommandon/audit och alla effekter ligger i samma transaktion. Inga tidsstyrda releases, delutlämningar, delannulleringar eller returer ingår. Befintliga syntetiska fulfillment-tabeller/funktioner återanvänds inte.

## Hosted-matris — PENDING

| Scenario | Förväntat | Status |
| --- | --- | --- |
| Kundpolicy → explicit production-aktivering → katalogpris → lager | Manuellt valda auktoriteter; produktion utan synthetic fallback | PENDING |
| Personlig varukorg → submit → separat attest → confirm | Fryst production-quote, 2 ×12345 +6173 moms =30863 | PENDING |
| Saknad attest/gammal version | APPROVAL_REQUIRED / VERSION_CONFLICT | PENDING |
| Köparens bekräftelse och orderläsning | Ready production-dokument, reserved version0 | PENDING |
| Köpare försöker fysisk utlämning | PERMISSION_DENIED | PENDING |
| Ogranskad utlämning eller billing före fulfil | VALIDATION_ERROR / FULFILLMENT_REQUIRED | PENDING |
| Full utlämning + replay | Stock10→8/reserved2→0, kreditexponering30863 kvar | PENDING |
| Annullering av redan utlämnat | FULFILLMENT_STATE_CONFLICT | PENDING |
| Exportläsning + upprepad läsning | Samma frysta total30863; ingen faktura/extraeffekt | PENDING |
| Översäljning och slut på kredit | STOCK_UNAVAILABLE / CREDIT_UNAVAILABLE | PENDING |
| Separat order1st, annullering + replay | Släpper lager1 och15431 öre exakt en gång | PENDING |
| Ny konfigversion efter quote | PRICE_CHANGED, ingen order/reservation | PENDING |
| Främmande tenant och AAL1 | PERMISSION_DENIED / MFA_REQUIRED | PENDING |
| Slutlig avstämning | Två produktionsorder, en fulfilled/en cancelled; stock8/reserved0/v5; nettoexponering30863 | PENDING |
| Rollback/readback | 26 cleanup-fält alla0 | PENDING |

Simulationen använder isolerat namespace35000000 med syntetiska användare och MFA-sessioner. Verkliga admin/köpare/attestant-RPC körs under authenticated; endast fixture-setup och slutlig avstämning är privilegierad. En separat person godkänner köpen. Inga mejl eller externa fakturor skickas. Två notification-outboxrader ska stå i manual_review, aldrig påstådd leverans.

Förväntad terminalrad: `PRODUCTION-FLOW-SIM-047 explicit activation/policy/catalog/stock/cart/approval/checkout/receipt/fulfillment/billing/cancellation/replay/negative guards PASS (rollback follows)`. Därefter ROLLBACK och 26 cleanup-räkningar noll. Vid fel/timeout ska anslutningen rullas tillbaka och sista CTE/SELECT köras separat för readback innan återförsök. Befintliga fixture-ID:n ersätts aldrig.

Avgränsning: ingen separat-session-samtidighet, extern SMTP, fysisk telefon/kamera eller verklig fysisk utlämning provas av SQL. Huvudagenten äger hosted-tillämpning, faktiskt resultat, kontrakt/API/UI-integration och publicering. Produktionsmarkering i isolerad simulation är inte ett påstående att riktig kunddrift har verifierats.
