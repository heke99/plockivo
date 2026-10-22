# CARTS-002 — beständig varukorg

Godkänd fortsatt utveckling 2026-10-22. Offentlig publicering godkänd av produktägaren; använd GitHub-anslutningen eftersom shell saknar GitHub-credentials.

Mål: ägd serverlagrad varukorg per inköpssammanhang, aktuell versionskontroll, återupptagning efter reload och idempotent omvandling till ett köpunderlag. Pris och kredit beslutas fortsatt i befintlig prepare/confirm.

Invariants: rätt aktör + aktuellt mandat vid varje operation, sammanhang bundet till tenant/kundkonto/butik/projekt, högst en öppen korg per aktör/sammanhang, inget gammalt versionsnummer får skriva över nyare rader, samma korgversion ger ett köpunderlag även med olika tekniska nycklar. Ny korg efter accepterad order får ny identitet. Redigering efter underlag måste skapa ny explicit version och ny attest; gamla underlag spärras för bekräftelse. Ingen direkt tabellskrivning.

Verifiering: riktiga approller för replay, gammal version, annan person/konto/tenant, återkallat mandat, samma korgversion med nya nycklar, ändring av tidigare attesterat underlag, atomiskt fel och serveråterupptagning. Webb: spara, reload, återuppta, skapa underlag, order och ny tom korg. Full masterplan kvarstår.

Resultat: 4 API- och 4 webbtester, typkontroll och produktionsbyggen PASS. Databasfall inklusive atomiskt fel och återkallat mandat PASS. Två samtidiga ändringar av samma revision gav exakt en ny revision och en konflikt. Browser verifierade reload, order och ny tom korg; slutomkörning av senaste UI-gränser PASS, testdata städade. GitHub CI hittade testkörarfelet i CLI db query; psql-körare införd.
