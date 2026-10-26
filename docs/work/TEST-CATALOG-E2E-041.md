# Testpublicering039–041 — verifiering

2026-10-26, separata API/web main, Supabase plockivo, Vercel Div3rsa production med syntetiskt verksamhetsläge. Ny migration20261026182456_catalog_test_publication är tillämpad. Exakta publicerade Gitrevisioner och deployments hör till releasecommit för detta dokument.

Release verdict RED för full kunddrift: ny kod och databaskedja verifierade, men autentiserad browserresa och SMTP→annanenhet inte bevisade. Ingen verklig försäljning eller kredit öppnas.

| Scenario | Resultat |
|---|---|
| Ny aktiv självskanningsartikel via save_standalone_catalog | PASS hosted actual RPC |
| Explicit create-only testpublicering till rätt kund | PASS hosted actual RPC |
| Streckkodssökning→prepare med exaktpris→confirm | PASS hosted actual RPC |
| Fryst testpris efter sourceversion2 | PASS hosted actual RPC |
| Samma publish/prepare/confirm replay utan dubbel effekt | PASS hosted actual RPC |
| Stale source/nyckelkonflikt/duplicate publication | PASS hosted actual RPC |
| Fel tenant/källa, AAL1 och legitim prodadmin/prodkund | PASS nekanden |
| Suspended/blocked/termsnull konto | PASS CREDIT_UNAVAILABLE |
| Rollback cleanup | PASS20fält0 |
| API input/testregression |35 tester PASS |
| Webb testregression |52 tester PASS |
| Lokala första byggförsök |FAIL Turbopack-cache, inga kompilerings-/testfel; rena ombyggen PASS för båda repon |
| Inloggad browser→publicering→testköp |NOT RUN utan permanent testkonto |
| Fysisk kamera, SMTP och reala sidoeffekter |NOT RUN |

Testets referensbelopp:2×12345öre net=24690, VAT25% avrundat half-up=6173, total30863. Assert exakt en testprodukt/barcode/price/publication/order/orderline/reservation och två köade outboxjobb före rollback. Testkällans senare prisändring ändrade inte den publicerade testkopian. Worker eller mejlleverans kördes inte; outbox är bara verifierad som köad.

Mutationer utfördes under authenticated med befintliga mandat och aktuell syntetisk AAL2-session. Privilegierade fixtureinlägg och slutreadback var avgränsade till33000000-namnrymden. Efter rollback0 audit/users/orders/outbox/stores/factors/intents/accounts/barcodes/commands/products/projects/sessions/merchants/memberships/order_lines/test_prices/publications/reservations/catalog_items. Testet täcker inte separata parallella DB-sessioner eller UI-kedjan.

SQL-enforcement: merchant.mode=test, aktuell admin/MFA, konto active&&!purchase_blocked&&terms_version, källa tillhör tenant och version, active+self_scan, en oföränderlig publicering per source totalt. Inget write till account/kredit, medlemskap, lager, invoice eller merchant.mode. Accountlåset föregår product; save/register-publication delar katalog-advisorylock. Alla source/pris/produkt/audit/idempotenswrites i samma transaktion. Public invoker/private definer, RLS och inga direkta tabellgrants. Befintligt confirmation-domänflöde återanvänds.
