# Beslut

| ID | Datum | Status | Beslut och konsekvens |
| --- | --- | --- | --- |
| D001 | 2026-10-22 | Genomfört | Använd bifogat startkit 3.0.0, trots masterplanens äldre 2.0-referenser. Kraven i planen ändras inte. |
| D002 | 2026-10-22 | Arbetsbeslut | Befintligt plockivo är scan-api. Separat plockivo-web är scan-web. Webb får egen GitHub-remote när den kan skapas. Ingen monorepo. |
| D003 | 2026-10-22 | Genomfört | Första leveransen är DEL-3603:s grundflöde med uttryckligt märkt testadapter. Verkliga köp är hårt spärrade i databasoperationen. |
| D004 | 2026-10-22 | Genomfört | Användar-JWT hela vägen till RLS/RPC. Service key bara för den begränsade testworkern. Inga generella adminendpoints eller klientstyrd actor. |
| D005 | 2026-10-22 | Genomfört | Låst offert med 15 min testgiltighet, separat attest och slutbekräftelse. Redigering skapar nytt underlag i detta inkrement; versionsstyrd utkastredigering återstår. |
| D006 | 2026-10-22 | Delvis | Vercel Workflow med beständig outbox och autentiserad återhämtningsscan implementerad. Worker skapar JSON-bevis; PDF/Storage och riktig e-post återstår. |
| D007 | 2026-10-22 | Öppet | ERP, kreditauktoritet över andra kanaler, Creditsafe-produkt, säljbolag, pilotbutik, avsändare och juridisk information kräver verkligt pilotunderlag. |
| D008 | 2026-10-22 | Blockerat | Automatisk approval review nekade push till publika GitHub-repot eftersom offentlig publicering inte var uttryckligen godkänd. Ingen alternativ publiceringsväg används. Kod bevaras privat för granskning. |
| D009 | 2026-10-22 | Genomfört | Ingen analys/marknadsföring. Host-only HttpOnly sessionskakor; ingen cookie delar session mellan handlardomäner. Cookieinformation ska följa verklig domänkonfiguration. |
