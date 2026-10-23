# WORKER-004 — verklig Workflow-körning för testjobb

2026-10-23. Återuppta nästa overifierade steg i masterplanen kapitel 19/26/28 och DEPLOY-003. SUPABASE_SECRET_KEY registrerad av produktägaren i API-projektets production-miljö. Ingen nyckel har lästs tillbaka. CRON_SECRET genererad kryptografiskt och lagrad som sensitive endast i API-projektet. Systemmiljövariabler aktiverade för Workflow World. Ingen förändring av approller eller ekonomiska regler.

Kod: autentiserad dispatcher, 15 s anslutningstimeout, region arn1, jobb-/Workflow-ID i skyddad respons och strukturerade loggar. Tillfälliga workerfel får tre återförsök med fem sekunders väntan; behörighets-/konfigurations-/domänfel är FatalError. Pending-jobb ligger beständigt i databasen före start; SQL:s radlås/unikhet skyddar dokument vid dubbla körningar. Ingen generell exakt-en-gång-garanti för Workflow-starter påstås.

| ID | Trigger | Förväntat bestående resultat | Status |
| --- | --- | --- | --- |
| W004-01 | Saknad/fel/svag/fel byte-längd Cron-hemlighet | 401, ingen start | Enhetstest |
| W004-02 | Tillfälligt nätverks-/DB-fel respektive permanent fel | Återförsök respektive FatalError; inga privata feltexter i logg | Enhetstest |
| W004-03 | Order committas medan cron är avstängt, sedan ny deployment | Två queued jobb finns kvar, nya deploymenten kan behandla dem | PASS: ac511b3 behandlade båda | |
| W004-04 | Två samtidiga autentiserade scans | Samma jobb kan startas flera gånger men exakt ett dokument, en statusövergång | PASS: fyra starter, ett dokument, attempts=1 | |
| W004-05 | Ny scan efter färdiga jobb | started=0, inga nya dokument eller försök | PASS: HTTP 200, started=0 | |
| W004-06 | Schemalagd cron efter verifierad manuell körning | Ny testorder behandlas utan manuell trigger | PASS: cron 08:35 UTC | |
| W004-07 | Städning | 0 fixtures/order/job/dokument/auth-identiteter kvar | PASS med readback | |

Release för verklig pilot är fortsatt RED: PDF/Storage, riktiga avsändare, integrationer, MFA och övriga pilotflöden saknas. Notification-jobb går till manual_review och inga externa utskick görs. Mid-step process kill, bortfall av Vercels lagring och godtyckliga externa leverantörseffekter är inte verifierade av en SQL-replay eller denna testresa.

## Manuell driftevidens

API ac511b382d6e99f4428526d89ca7d6efe5ab2c44, deployment dpl_2WS9jNAc8BN5WkMYXmGiz7cS3p7r. 08:30 UTC: två samtidiga skyddade GET-anrop gav HTTP 200 med started=2 vardera. Workflow-loggar bekräftar fyra körda steg i arn1. Köpbekräftelsejobbet 633e14c3-fdea-481b-ab84-2cba32004097 blev succeeded; notification 6ec9c207-7466-43da-9bc1-410d5978ebc9 blev manual_review. Båda attempts=1, documents=1. Körnings-ID:n: wrun_41M5KY4BS060HV4CPAPXGVQ0DQ, wrun_41M5KY4BRX60P6FDXVMWXH0W2Q, wrun_41M5KY4CDF60R4CWMMZJJMHRX9, wrun_41M5KY4CD460GNBEZPAQD0RXBG. Saknad/fel Authorization gav 401. Ny scan 08:33 UTC gav started=0.

Lokala quality gates: standard, typkontroll, 7 tester och rent Next-produktionsbygge PASS. Första bygget stoppades av korrupt befintlig Turbopack-cache; cachen flyttades undan och nytt bygge passerade utan kodändring. GitHub kod-CI 39925021159 PASS. Ingen schemaändring.

## Automatisk körning och avslut

Cron-kod b1cf517500fa862b9146191a6fcef8ab1a008ad2, deployment dpl_AjpSypbQbBBTwWe44dwGzAPJb3V4 READY. Schemat */5 * * * * anropade dispatchern 08:35:33 UTC utan manuell trigger. started=2, failed=0. Jobb 1876bdec-5527-48d0-9d4b-d37a9cca68bc blev succeeded och 423f89b7-b9d0-4c94-8f9c-e327fb4fb17d manual_review; båda attempts=1. Workflow-ID wrun_41M5KYDB2D60ZKX8JMCJT1K79A och wrun_41M5KYDB2B60SDJVZJNQX7B8EK. Totalt två avsiktliga testorder gav två dokument. Workflow-stegen kördes i arn1; observerade dispatch-anrop kördes i cle1/iad1, så ingen generell regional garanti för alla API-anrop påstås.

Fixtures städade med den versionshanterade guardade tests/cleanup-fixtures.sql. Readback: merchants=0, orders=0, carts=0, jobs=0, documents=0, test_users=0. Tillfällig automation bypass återkallad; lokal testhemlighetsfil borttagen. Den permanenta BFF-kopplingen och API:s Cron-hemlighet är kvar. Inga riktiga mejl eller andra externa affärseffekter utfördes.

Nästa avgränsade produktsteg: personinbjudan/provisionering och MFA enligt masterplanen; därefter handlarkonfiguration inklusive profil och verifierad domän.

GitHub CI för cron-kod b1cf517: [39925581856](https://github.com/heke99/plockivo/actions/runs/39925581856) PASS, inklusive quality och databasreplay.
