# Plockivo — projektkontext

Produkt: white label B2B-självskanning för bemannade butiker. Källa: [masterplan v2.2](MASTERPLAN_v2.2.txt). Engineering Startkit 3.0.0 är infört; planens äldre versionsreferenser ersätts av det faktiskt bifogade paketet enligt D001.

## Dokumentkarta

- [Projektstatus](PROJECT_STATE.md): checkpoint och nästa handling.
- [Beslut](DECISIONS.md): bestående teknik- och omfattningsbeslut.
- [Kravregister](PRODUCT_REQUIREMENTS.md): varje krav-ID och verklig leveransstatus.
- [Aktivt uppdrag](work/BOOTSTRAP-001.md): testmatris, fynd och kvarvarande arbete.
- [Verifieringsrapport](VERIFICATION.md): faktiskt körda kontroller och begränsningar.
- [API-kontrakt](../contracts/openapi.json): auktoritativ version 0.1.0.
- [Identitet och drift](IDENTITY_AND_OPERATIONS.md): session, integrationer, integritet och återställning.

## Verifierade resurser

GitHub: heke99/plockivo, ursprungligen tomt **publikt** repo. Lokal rot är API-projektet. Webbens separata checkout heter plockivo-web; GitHub-repot för webb saknas och kunde inte skapas av anslutningens verktyg. Ingen monorepo eller relativ import mellan projekt används.

Supabase: plockivo, projekt cqznytuyutrqenbbyczc, PostgreSQL 17, region eu-north-1. Tabellen var tom före uppdraget. Miljön behandlas som enbart syntetisk utveckling; inga verkliga handlare är provisionerade. Migrationer har tillämpats där och rolltestats. Vercel är beslutad drift, inte provisionerad eller driftsatt i denna leverans. Railway används inte.

## Ägarskap

SQL i `supabase/migrations` äger permissions och atomiska köpregler. TypeScript i `src/lib/input.ts` validerar transportschema. API:t verifierar Supabase-identitet och skickar användarens bearer-token vidare. Ingen service key används i personanrop. Privilegierade funktioner ligger i oexponerat private-schema med fast search_path, begränsad execute och explicita mandatkontroller. Public wrappers är invoker. Direkta tabellskrivningar är nekade.

Handlare är tenant. Kundkonto är handlarbunden köparrelation. En medlemsrad har explicit konto-, butik- och projektomfattning samt giltighetsintervall. Beloppsgräns och attesttröskel anges inkl. moms i SEK-ören. Projektbudgeten i första testflödet är en total projektbudget, inte en periodbudget.

Testprisadaptern är den enda implementationen; verklig ERP-auktoritet är **inte** ansluten. Den kan bara acceptera testorder hos testhandlare. Ekonomiska värden överförs som strängar. Exponering, projektåtagande, orderrader, audit och outbox ändras i samma transaktion. Låsordning anges i confirm-funktionen.

## Kommandon

Node 24 användes i byggmiljön. Låsta npm-beroenden och package-lock.json per repo. `npm ci`, `npm run typecheck`, `npm test`, `npm run build`, `npm run standard`, `npm run verify`. Lokal API-port 3001, webbport 3000. Lägg till `-- --hostname 127.0.0.1` vid nätverksbegränsad miljö.

Databastest på en **tom isolerad testdatabas**: `npx supabase db query --local --file tests/database.sql`. Filerna innehåller syntetiska UUID:n och rollback. Kör inte samma fixture ovanpå en annan testkörnings kvarvarande fixtures. Docker behövs för lokal Supabase. I uppdraget kördes SQL via den anslutna utvecklingsdatabasen.

## Kontrakt och beroenden

`npm run contract:generate` genererar TypeScript från OpenAPI med låst openapi-typescript. Webbprojektet levereras med samma genererade fil och kontraktets SHA-256 i contracts.lock.json; det behöver inte lokal API-checkout. Uppdatering kräver ny kopia från samma verifierade kontraktsartefakt.

Next.js/React/Supabase-SDK/Workflow är npm-beroenden, ingen Medusa-, Casbin-, ERPNext- eller Docuseal-kod har portats. Inbyggd BarcodeDetector används där tillgänglig, manuell kod finns alltid. ZXing-fallback och prov på verkliga iPhones återstår.
