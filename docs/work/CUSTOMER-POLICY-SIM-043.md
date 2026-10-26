# CUSTOMER-POLICY-SIM-043 — verklig kundpolicy, isolerad simulation

Status: **Förberedd; hosted-resultat PENDING.** [SQL-test](../../tests/customer-policy-simulation.sql). Förutsätter tillämpad kundpolicymigration från del042. Ingen migration, hosted SQL, build eller publicering utförd av denna delagent.

| Scenario | Förväntat | Resultat |
| --- | --- | --- |
| Production-kund före manuell granskning | suspended, blocked, kredit 0, policy_version 0/pending | PENDING |
| Pending review till active | VALIDATION_ERROR | PENDING |
| Pending review med positiv kredit | VALIDATION_ERROR | PENDING |
| Granskad manuell aktivering | active, unblocked, kredit 100000, villkor sim043-v1, policy_version 1 | PENDING |
| GET och samma nyckel igen | Identiskt svar; ingen extra version/audit | PENDING |
| Samma nyckel, ändrad body | IDEMPOTENCY_CONFLICT | PENDING |
| Ny nyckel, gammal version | VERSION_CONFLICT | PENDING |
| Produktions-checkout efter legitim aktivering | Fortsatt INTEGRATION_NOT_READY | PENDING |
| Kreditram sänks till 10000 under exponering 20000 | Policy_version 2; exponering oförändrad | PENDING |
| Suspended/blocked efter aktivering | Policy_version 3; exponering oförändrad | PENDING |
| Testkonto med befintlig reservation spärras | Policy_version 1; exponering/reservation/projektåtagande 30000 oförändrade | PENDING |
| Annan tenant läs/skriv | PERMISSION_DENIED | PENDING |
| Auktoriserad tenant men annan tenants konto | NOT_FOUND | PENDING |
| Köparroll med riktig AAL2-session | PERMISSION_DENIED för läs/skriv | PENDING |
| Admin med AAL1 | MFA_REQUIRED för läs/skriv | PENDING |
| Avstämning | Två sidecars; audit/commands A=3, B=1; inget nytt köp/outbox | PENDING |
| Rollback/readback | Alla 15 cleanup-räkningar 0 | PENDING |

## Avgränsning och fixtures

Namespace `34000000` innehåller två syntetiska auth-användare, två verifierade MFA-faktorer/sessioner, production- och testhandlare samt en främmande tenant. Inga mejl eller verkliga konton skapas. Alla policyoperationer körs via appens publika RPC under rollen authenticated; privilegier används bara för setup och slutlig avstämning.

Production-fixturen har 20000 i befintlig syntetisk exponering redan före policyn. Testfixturen har en direkt insatt syntetisk testorder/reservation och projektåtagande på 30000 för att upptäcka felaktig ekonomisk återföring vid spärr. Testet skapar ingen produktionsorder och ändrar inte en befintlig handlares mode. Administrationsbeslutets auktoritet kontrolleras som merchant-manual; extern kreditupplysning eller generell produktionsberedskap påstås inte.

Prepare-försöket görs när production-kunden faktiskt är active/unblocked med villkor och legitimt köparmandat, så att den kvarstående mode-spärren provas efter administration. Ingen generell checkout-spärr tas bort av testet. Det befintliga produktionsflödet är fortfarande ofärdigt även om kundpolicy kan administreras.

Förväntad rad: `CUSTOMER-POLICY-SIM-043 production policy/review/credit/replay/version/tenant/role/MFA/preserved reservations/production checkout guard PASS (rollback follows)`. Filen gör sedan ROLLBACK och returnerar cleanup-objekt med 15 nollor. Sista CTE/SELECT kan köras separat efter timeout eller okänt utfall. Befintliga fixture-ID:n orsakar konflikt, inte återanvändning. Ingen generell DELETE-städning ingår.

Separata samtidiga sessioner, HTTP/UI, importer, fysisk utlämning och externa ekonomisystem ingår inte. Huvudagenten kör hosted, redovisar faktiskt utfall och kompletterar med användarflödesverifiering.

Parent2026-10-26: hela SQL-filen körd hosted utan fel. Alla assertions PASS, efterROLLBACK cleanup15fält0. Produktionsläge bevisat för kundpolicy, inte för checkout; productionprepare nekades fortfarande enligt kodens ofärdiga checkoutprofil.
