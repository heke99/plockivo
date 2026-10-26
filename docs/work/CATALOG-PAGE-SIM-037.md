# CATALOG-PAGE-SIM-037 — pagination och sökning

Status: **Förberedd, hosted-körning PENDING.** [SQL-test](../../tests/catalog-page-simulation.sql). Förutsätter tillämpad migration med `public.page_standalone_catalog(p_tenant,p_query,p_after_sku,p_after_id,p_limit)` från parallell delagent. Ingen migration applicerad av denna delagent.

| Scenario | Förväntat | Resultat |
| --- | --- | --- |
| 207 artiklar, 50 per sida | Fem sidor 50/50/50/50/7, total 207 på varje sida | PENDING |
| Keyset-ordning | Exakt stigande (sku,id), inga dubbletter, alla ID med | PENDING |
| Next-cursor | Sista raden på varje sida, null på sista sidan | PENDING |
| `%` och `_` | Bokstavlig sökning: endast SIM-007 respektive SIM-008 | PENDING |
| Streckkod på sista artikeln | SIM-207 hittas även utanför första sidan | PENDING |
| Annan tenant | PERMISSION_DENIED | PENDING |
| AAL1 för samma admin/session | MFA_REQUIRED | PENDING |
| Limit 0 eller 101; halv cursor | VALIDATION_ERROR | PENDING |
| Slutlig avstämning | 207 A-rader, 2 B-rader; inga skapade audit/commands | PENDING |
| Rollback | Alla åtta cleanup-räkningar 0 | PENDING |

Testet skapar syntetiska auth/merchant/MFA-fixtures i namespace `32000000`, aldrig riktiga konton eller utskick. Artiklarna sätts upp direkt med privilegierad fixtureinsert för att isolera läsoperationen. Alla list-/sökanrop körs med `authenticated` och explicit AAL2-JWT, därefter nekad AAL1. Handlare har sales_paused=true; ingen försäljning öppnas.

Förväntad resultatrad: `CATALOG-PAGE-SIM-037 207 rows/five pages/order/uniqueness/literal search/tenant/MFA/limits PASS (rollback follows)`. Därefter `ROLLBACK`, sedan cleanup-objekt för users/sessions/factors/merchants/memberships/catalog_items/audit_events/commands med alla värden 0. Sista SELECT kan köras separat som cleanup-readback efter timeout/okänt utfall. Befintliga fixture-ID:n får testet att misslyckas före återanvändning; ingen generisk DELETE-städning används.

Detta är inte en snapshot av ett samtidigt föränderligt register: testet kör en stabil katalog i en session. HTTP/UI, Excel-nedladdning, samtidiga ändringar och verklig katalogdrift ingår inte i SQL-beviset. Huvudagenten kör hosted-test, granskar resultat och uppdaterar status.

Parent-resultat2026-10-26: första SQL-körningen stoppade på ett syntaxfel i testets CASE-uttryck. Parent rättade parenteserna; därefter passerade alla assertions. Hosted-provet returnerade åtta cleanup-nollor efter ROLLBACK. Ingen bestående användare eller data.
