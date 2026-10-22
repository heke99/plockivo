# Plockivo API

Första verifierbara grunden enligt masterplan v2.2. Engineering Startkit 3.0.0 ingår. **Testflöde, inte godkänt för verklig försäljning.**

Börja i [projektkontexten](docs/PROJECT_CONTEXT.md), [aktuell status](docs/PROJECT_STATE.md) och [verifieringsrapporten](docs/VERIFICATION.md).

```sh
npm ci
cp .env.example .env.local
# Ange Supabases publishable key. Använd inte worker key för personanrop.
npm run dev
npm run verify
```

API: port 3001. Webb är ett separat projekt. [OpenAPI 0.2.0](contracts/openapi.json) är kontraktskällan. `npm run contract:generate` uppdaterar klienttyper. Databasens migrationsnamn följer de faktiskt tillämpade versionerna från Supabase.

```sh
npx supabase start
npx supabase db reset --local
npm run db:test
```

Lokala databastester använder isolerade syntetiska fixtures och rollback. Docker krävs. GitHub CI körs efter publicering. Databastester körs i lokal Supabase-container via psql med ON_ERROR_STOP. Se verifieringsrapporten för aktuellt resultat.

Behövliga externa integrationer, MFA, utlämning, fakturering, returer, PDF, avtal, white label-domäner och pilotprov beskrivs som kvarstående arbete i statusen. Ingen Railway.
