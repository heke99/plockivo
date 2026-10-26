# CATALOG-IMPORT-SIM-031 — katalogsimulering

Status 2026-10-26: **Förberedd, ej körd.** Resultaten är PENDING tills huvudagenten har kört SQL och kontrollerat resultatet. Inga drifts- eller säkerhetspåståenden bygger på filens existens.

Källa: [rollback-only SQL](../../tests/catalog-import-simulation.sql), befintlig `save_standalone_catalog` och `list_standalone_catalog`. Detta provar en sekvens av verkliga artikel-RPC-anrop; det är ingen CSV-parser eller atomisk batchimport. Katalogen är fortsatt förberedelseregister med checkout_enabled=false.

| Scenario | Förväntat | Resultat |
| --- | --- | --- |
| Tre separata artiklar | Tre olika ID, version 1 | PENDING |
| Exakta belopp | 12345, 999999999999 och 0 öre bevaras som strängar | PENDING |
| Decimal kvantitet | 0.125 steg och 2.5 förpackning bevaras | PENDING |
| Skapa replay | Exakt samma svar, ingen extra rad/audit | PENDING |
| Samma nyckel, ändrat innehåll | IDEMPOTENCY_CONFLICT | PENDING |
| Dubbelt SKU med nytt barcode | CATALOG_DUPLICATE | PENDING |
| Dubbelt barcode med nytt SKU | CATALOG_DUPLICATE | PENDING |
| Giltig artikeländring | Version 2, nytt pris 12999 | PENDING |
| Ändring replay | Exakt samma svar, ingen extra audit | PENDING |
| Gammal version | VERSION_CONFLICT | PENDING |
| Främmande tenant läs/skriv | PERMISSION_DENIED, inga sidoeffekter | PENDING |
| Admin med AAL1 i stället för AAL2 | MFA_REQUIRED för läs och skriv | PENDING |
| Slutlig avstämning | Tre artiklar, fyra audit och fyra commands i A; inga i B | PENDING |
| Rollback/readback | users, sessions, factors, merchants, memberships, catalog_items, audit_events, commands alla 0 | PENDING |

## Säker körning och evidens

Filen startar en enda transaktion, skapar syntetiska fixture-ID:n i namespace `31000000`, växlar till `authenticated`, sätter explicit JWT och använder appens publika RPC:er. AAL2-sessionen är kopplad till en verifierad syntetisk faktor. Endast slutlig räkning av privata tabeller görs med återställd ägarroll. Syntetiska handlare har sales_paused=true. Inga riktiga användare, mejl, köp eller fakturor skapas.

Förväntad resultatrad: `CATALOG-IMPORT-SIM-031 three items/exact prices/replay/duplicates/version/tenant/MFA/audit PASS (rollback follows)`.

`ROLLBACK` följer alltid på lyckad körning och filens sista SELECT ger ett cleanup-objekt med åtta nollor. Vid SQL-fel avbryts transaktionen och anslutningen måste rulla tillbaka innan fortsatt bruk. Vid timeout/okänt utfall körs den sista readback-frågan separat innan återförsök; inga generella DELETE-städningar får göras. Om en namespace redan finns ska fixtureinsert misslyckas, så en annan körnings data aldrig återanvänds.

Samtidighet mellan separata DB-sessioner ingår inte. Varken HTTP/UI-import, verklig SMTP eller en användares fulla inköpsresa är verifierad av detta SQL-test. Delagenten kör inte hosted SQL och bygger/publicerar inte.

Parent-resultat 2026-10-26: hela SQL-filen exekverad via ansluten databas utan fel. Alla assertions PASS, efter rollback returnerades cleanup med åtta nollor. Ingen bestående fixture eller användare. Detta ersätter PENDING för SQL-provet; browser/API-E2E ej ingående.
