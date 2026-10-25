# BRANDING-009 — kundsynlig profil i autentiserad kontext

2026-10-25. `Membership.branding` innehåller endast `display_name`, `primary_color`, `logo_data_url`. Profil följer en aktiv, giltig medlemsrad i `get_context`; ingen godtycklig Host-header eller domän aktiverar en handlare. Befintlig MFA-kontroll och scoped context bevaras. Ogiltiga/äldre profilvärden får namn-/färg-/logotypfallback; inga okända profilnycklar serialiseras.

Migration `buyer_branding` tillämpad i syntetiskt Supabase-projekt, terminal success från apply_migration. Lokal fil skapad med CLI 20261025223951; serverns tillämpade timestamp behöver bekräftas innan publicering om den skiljer sig.

`tests/branding.sql` är tillagd i SQL-runnern: riktig authenticated-roll, handlarisolering, återkallat medlemskap, whitelist och fallback, med rollback. Körningen hängde och avbröts efter 142.8 sekunder utan terminalresultat. Därför **inte verifierad PASS**. TypeScript- och OpenAPI-artefakter synkade till webbrepot; UI-agenten verifierar klientdelen separat. Ingen domänaktivering, DNS eller offentlig branding innan inloggning införs.

Parent slutkontroll: riktig authenticated SQL-matris PASS (scope, revocation, fallback, whitelist). Servermigration 20261025224041 synkad. Guardad gammal profilfixture-städning lyckades; readback följs i projektstatus. UI-test med intercepted context är endast visningsbevis, SQL utgör separat behörighetsbevis. Ingen domänaktivering.
