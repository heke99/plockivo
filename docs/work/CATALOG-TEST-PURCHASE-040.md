# CATALOG-TEST-PURCHASE-040 — katalog till syntetisk testorder

Status: **Förberedd, hosted-körning PENDING.** [SQL](../../tests/catalog-test-purchase.sql). Förutsätter tillämpad migrationsversion för `publish_catalog_test`. Ingen apply, build, deployment, kontoprovisionering eller hosted-körning gjord av denna delagent.

| Scenario | Förväntat | Resultat |
| --- | --- | --- |
| Skapa aktiv självskanningsartikel via app-RPC | Källa version 1, 12345 öre, 25 % moms | PENDING |
| Explicit testpublicering | En produkt, barcode, kundbundet testpris och mapping | PENDING |
| Samma publiceringsnyckel | Identiskt svar utan dubbla effekter | PENDING |
| Spärrat/suspended kundkonto eller saknade villkor | CREDIT_UNAVAILABLE, kreditram och exponering fortsatt 0 | PENDING |
| Barcode-läsning | Testprodukten hittas med kopierad barcode | PENDING |
| Prepare quantity 2 | Net 24690, moms 6173, total 30863 öre; ready_for_confirmation | PENDING |
| Prepare replay | Samma underlag, inga extra effekter | PENDING |
| Ändra förberedelsekälla | Version 2/12999; tidigare snapshot/quote är fortsatt 12345 | PENDING |
| Publicera gammal version med ny nyckel | VERSION_CONFLICT | PENDING |
| Publicera aktuell version en gång till | CATALOG_DUPLICATE, ingen tyst synkronisering | PENDING |
| Ursprunglig replay efter källändring | Ursprungligt publiceringssvar | PENDING |
| Production-handlare med legitim admin och källartikel | INTEGRATION_NOT_READY, ingen produkt/order | PENDING |
| Annan tenants source i testtenant | NOT_FOUND | PENDING |
| Annan tenant utan mandat | PERMISSION_DENIED | PENDING |
| Confirm, replay och andra nyckeln | En order, en rad, total 30863, status completed | PENDING |
| Publicering som AAL1 | MFA_REQUIRED | PENDING |
| Reservationer/outbox/audit | En reservation 30863, två queued-jobb, en audit per publish/prepare/confirm | PENDING |
| Rollback/readback | Alla 20 cleanup-räkningar 0 | PENDING |

Fixtures använder en syntetisk användare i namespace `33000000`, separat testhandlare, production-mode guard-fixture och främmande testtenant. Legitima appoperationer körs med `authenticated`, explicit AAL2 och riktig koppling mellan fixture-session och verifierad MFA-faktor. Endast setup och avstämning använder privilegierad testroll. Inga riktiga kunder, inbjudningar, e-postleveranser eller externa köp skapas.

Fixture-kundens kreditram är 100000 och ändras inte. Testordern reserverar syntetiskt 30863 i exponering och projektåtagande inom transaktionen; detta är förväntad testeffekt, inget kreditbeslut eller verklig bokföring. Production-fixture har separat aktivt konto och egen källa så att mode-spärren provas under annars legitim administration. Den befintliga testhandlarens mode ändras aldrig för att kringgå spärren.

Resultatraden ska vara `CATALOG-TEST-PURCHASE-040 source/publish/prepare/confirm/exact rounding/replay/snapshot/tenant/MFA/production guard PASS (rollback follows)`, följd av rollback och cleanup-objekt där alla 20 fält är 0. Sista CTE/SELECT får köras separat vid okänt utfall. Inga generella DELETE-operationer används; befintliga fixture-ID:n orsakar fel i stället för återanvändning.

Detta bevisar SQL-kedjan från preparerad/importmotsvarande artikel till syntetisk order. CSV-parser, HTTP-proxy, webbläsare, leveransmejl, workerbehandling, fysisk utlämning och separat-session-samtidighet ingår inte. Huvudagenten behöver dokumentera verkligt hosted-utfall och separat UI/E2E-evidens.

Parent-resultat2026-10-26: hela SQL-testet kördes hosted utan fel. Källa→publish→barcode→prepare→confirm och samtliga negativa assertions PASS. Efter ROLLBACK returnerades20cleanupfält med0, inklusive orders/outbox/products/prices/publications/reservations/users. Ingen bestående testanvändare eller order.
