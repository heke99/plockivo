# WORKER-004 — verklig Workflow-körning för testjobb

2026-10-23. Återuppta nästa overifierade steg i masterplanen kapitel 19/26/28 och DEPLOY-003. SUPABASE_SECRET_KEY registrerad av produktägaren i API-projektets production-miljö. Ingen nyckel har lästs tillbaka. CRON_SECRET genererad kryptografiskt och lagrad som sensitive endast i API-projektet. Systemmiljövariabler aktiverade för Workflow World. Ingen förändring av approller eller ekonomiska regler.

Kod: autentiserad dispatcher, 15 s anslutningstimeout, region arn1, jobb-/Workflow-ID i skyddad respons och strukturerade loggar. Tillfälliga workerfel får tre återförsök med fem sekunders väntan; behörighets-/konfigurations-/domänfel är FatalError. Pending-jobb ligger beständigt i databasen före start; SQL:s radlås/unikhet skyddar dokument vid dubbla körningar. Ingen generell exakt-en-gång-garanti för Workflow-starter påstås.

| ID | Trigger | Förväntat bestående resultat | Status |
| --- | --- | --- | --- |
| W004-01 | Saknad/fel/svag/fel byte-längd Cron-hemlighet | 401, ingen start | Enhetstest |
| W004-02 | Tillfälligt nätverks-/DB-fel respektive permanent fel | Återförsök respektive FatalError; inga privata feltexter i logg | Enhetstest |
| W004-03 | Order committas medan cron är avstängt, sedan ny deployment | Två queued jobb finns kvar, nya deploymenten kan behandla dem | Väntar |
| W004-04 | Två samtidiga autentiserade scans | Samma jobb kan startas flera gånger men exakt ett dokument, en statusövergång | Väntar |
| W004-05 | Ny scan efter färdiga jobb | started=0, inga nya dokument eller försök | Väntar |
| W004-06 | Schemalagd cron efter verifierad manuell körning | Ny testorder behandlas utan manuell trigger | Väntar |
| W004-07 | Städning | 0 fixtures/order/job/dokument/auth-identiteter kvar | Väntar |

Release för verklig pilot är fortsatt RED: PDF/Storage, riktiga avsändare, integrationer, MFA och övriga pilotflöden saknas. Notification-jobb går till manual_review och inga externa utskick görs. Mid-step process kill, bortfall av Vercels lagring och godtyckliga externa leverantörseffekter är inte verifierade av en SQL-replay eller denna testresa.
