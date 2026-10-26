# Katalog035–038 — verifieringscheckpoint

Release verdict: RED för full kunddrift (P0 Auth/browser→API/write→DB och SMTP fortfarande ej körda med testkonto). Avgränsade katalogfunktioner är implementerade, kodtestade och read-RPC:n live-rolltestad.

Miljö2026-10-26: heke99/plockivo + heke99/plockivo-web separata main, Vercel Div3rsa production, Supabase plockivo eu-north-1. Migration standalone_catalog_page20261026180352 tillämpad, inga befintliga funktioner borttagna. Auth/session/MFA behåller tidigare auktoritet. Ny read-funktion har ingen anonym execute; publik wrapper är invoker, private definer har fast search_path och kontrollerar assert_mfa + befintlig handlarauktorisation.

| Scenario | Resultat | Evidens |
|---|---|---|
| Fullregistersökning/pagination >200 | PASS hosted SQL |207 A-rader över5 sidor utan dubbletter/bortfall |
| Literal %/_ samt sista artikelns barcode | PASS hosted SQL |tests/catalog-page-simulation.sql assertions |
| Fel tenant/AAL1/gränser/cursorpar | PASS hosted SQL |Nekanden innan data returneras |
| Inga read-sidoeffekter | PASS hosted SQL |Audit/commands0 |
| Rollback/städning | PASS hosted SQL |users/factors/sessions/merchants/memberships/catalog/audit/commands0 |
| Journal återställning/tenant/payload/key/replay | PASS kodtester |4 journal +3 batchtester |
| CSV exakt pris/quoting/formelskydd | PASS kodtester |5 exporttester |
| API kvalitet | PASS |33 tester +typkontroll/standard/produktionsbygge |
| Webb kvalitet | PASS |52 tester +typkontroll/standard/produktionsbygge |
| Autentiserad verklig filväljare+import | NOT RUN |Testkonto saknas enligt tidigare beslut |
| Fysisk telefon och SMTP-två-enhetskedja | NOT RUN |Behöver separat test |

SQL-testets första körning hade CASE-syntaxfel; parenteserna rättades och hela körningen gjordes om till PASS. Inga fixtures finns kvar. Tidigare uppdragets live-browserkontroll gällde publik enhetskontroll/importguide och får inte räknas som autentiserad import-E2E. Listans sida är en aktuell läsning, inte ett låst exportsnapshot; samtidiga SKU-ändringar kan påverka bläddring. CSV-export omfattar endast aktuell sida och transformerar formelliknande text med apostrof, inte hela registret. Export innehåller inte status/ID/behörigheter. Journalen är lokal, manipulerbar och får aldrig användas som serverbevis. Inget verkligt köp, kredit, bokföring eller utlämning öppnas av dessa delar.
