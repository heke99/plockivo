# READINESS-018 — kapacitetsinventering före ERP-val

2026-10-26. Versionsstyrd inventering av implementationens faktiska testkapacitet enligt TECH-2001/2002/2003 och E2E-330. Ingen extern leverantör har anslutits. Inga credentials, miljövariabler eller användardeklarationer räknas som verifierad förmåga.

API-modulen integrationReadiness() lämnar en färsk, ofarlig beskrivning av testpris/testkredit, frånvarande lager/fakturering/extern avstämning och manuell granskning av affärsmeddelanden. production_sales_enabled är uttryckligen false. Modulen är informationsunderlag och ersätter aldrig databasens försäljningsspärr.

Webbsidan /integration-readiness är serverrenderad och visar tydligt att det är versionsstyrd produktstatus, inte faktisk anslutnings-/hemlighetskontroll eller handlarens verifierade ERP-profil. Ingen aktiveringsknapp, inga mutationer, inga externa hämtningar och inga tenantuppgifter. Färre komplexa element och befintlig responsiv layout används. Parent lägger hjälp-länk.

capabilities.json är en genererad statisk konsumentartefakt. Uppdatera från API-roten med:

`node --experimental-strip-types --input-type=module -e "import {integrationReadiness} from './src/lib/integration-readiness.ts';process.stdout.write(JSON.stringify(integrationReadiness(),null,2))" > ../web/src/app/integration-readiness/capabilities.json`

Detta är ett utvecklingskommando mellan checkouts, inte en runtime-import eller monorepo. Levererad webb bygger utan API-källkoden.

Verifierat: två riktade API-tester PASS, API typecheck PASS; sammanförd web npm run verify PASS (26 tester, typkontroll, dokumentkontroll, produktionsbygge). Chromium på separat3548 PASS: innehåll och försäljningsspärr, inga knappar, mobil390/768/1440 utan overflow, navigering tillbaka till /app, inga pageerrors. Första testet saknade väntan på klientnavigation; korrigerat med waitForURL och slutomkörning PASS. Inga bestående testdata eller utskick. Ingen publicering av delagenten.

Nästa exakta externa steg: välj pilot-ERP, namnge auktoriteter, dokumentera fältmappning och kör riktiga kapacitetsprov inklusive osäkert utfall. Inventeringen ger ingen tillåtelse till verkliga köp.
