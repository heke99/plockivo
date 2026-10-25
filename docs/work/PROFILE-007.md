# PROFILE-007 — beständig administrativ handlarprofil

2026-10-25. Implementerat i API: GET/POST merchant-profile, fullständigt merchant_admin-mandat med MFA, permission merchants.profile.manage. Kund-, butik- eller projektbegränsade medlemskap räcker inte. All åtkomst sker genom användaridentitet och RPC, inga direkta tabellskrivningar.

Profil: display_name (1–80), primary_color (#hex), logo_data_url (PNG/JPEG/WebP data URL, högst 16 KiB avkodad och 22000 tecken). Detta är en liten rasterlogotyp, inte generell filuppladdning. Ingen fjärr-URL/SVG/HTML. Ingen bildbehandlingspipeline eller faktisk pixelavkodning på servern har påståtts verifierad.

Merchants.profile och profile_version sparas med radlås och förväntad revision. Konflikt ger VERSION_CONFLICT. Nyckelbaserad replay returnerar tidigare resultat utan ny revision eller audit; annan body med samma nyckel nekas. Profiländring, audit och idempotensresultat sparas atomiskt. Försäljning, legalt bolagsnamn, kredit och domänstatus kan inte ändras genom operationen.

Migrationer tillämpade och lokala filnamn synkade till Supabase: 20261025201415 merchant_profile, 20261025201515 profile_logo_limit. SQL tests/profile.sql PASS på riktig authenticated-roll med rollback: save/readback, versionkonflikt, idempotent replay, korshandlare nekas, inköpare nekas och exakt en audit. Typecheck och tolv enhetstester PASS. Parent verifierar sammanförd browser/build/release.

Scope: administrativ sparad profil. Offentlig handlarprofil från Host, kundernas faktiska branding, egna PWA-manifest och aktivering av verifierad domän återstår; domänregistreringens separata del beskrivs i DOMAIN-008. Full kundpilot fortsatt spärrad.
