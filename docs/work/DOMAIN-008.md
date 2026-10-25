# DOMAIN-008 — registrering av önskad handlaradress

2026-10-25. Implementerat: MFA-skyddad merchant_admin kan lista, registrera och ta bort egna väntande domänönskemål. Kräver obegränsat handlaradministrativt mandat. Inga direkta tabellrättigheter. Idempotent registrering per handlare/domän, max tio aktiva önskemål, audit och versionskontroll vid borttagning. Overifierade önskemål reserverar inte adressen globalt; verifierad adress är globalt unik.

API validerar rena publika ASCII-värdnamn och nekar URL, port, wildcard, IP och Plockivos egna adresser. SQL upprepar gränsskyddet. Domäner får enbart status pending från användaroperationer. Det finns ingen användarstyrd aktivering och ingen automatisk routing från Host-header.

Verklig anslutning är inte färdig: plattformens Vercelanslutning, TXT-ägarkontroll, rätt projektkoppling, certifikat, verifierad tenant-resolver, autentiseringens origin/returadress, sessionsavgränsning och PWA-identitet måste verifieras tillsammans före aktivering. Ingen DNS-post har ändrats och ingen verklig kunddomän har registrerats i Vercel. Verifierade bindningar får inte tas bort innan plattformen avprovisionerat dem.

Verifiering: npm test PASS (12 API-tester inklusive profil/domäntransport). tests/domains.sql PASS i anslutet syntetiskt Supabaseprojekt under riktig authenticated-roll: rätt admin, kors-tenant nekad, vanlig roll nekad, idempotent begäran, väntande status, direktaktivering nekad, gammal version nekad, borttagning, två audithändelser. Rollback. Migration tillämpad efter profilmigration. Ren migrationsreplay och webbläsarresa återstår för huvudagentens integrerade verifiering.

Serverhistorik kontrollerad: merchant_domains är version 20261025201500. Lokal migrationsfil är synkad till `20261025201500_merchant_domains.sql` utan innehållsändring.
