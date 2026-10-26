# Beslut

| ID | Datum | Status | Beslut och konsekvens |
| --- | --- | --- | --- |
| D001 | 2026-10-22 | Genomfört | Använd bifogat startkit 3.0.0, trots masterplanens äldre 2.0-referenser. Kraven i planen ändras inte. |
| D002 | 2026-10-22 | Arbetsbeslut | Befintligt plockivo är scan-api. Separat plockivo-web är scan-web. Webb får egen GitHub-remote när den kan skapas. Ingen monorepo. |
| D003 | 2026-10-22 | Genomfört | Första leveransen är DEL-3603:s grundflöde med uttryckligt märkt testadapter. Verkliga köp är hårt spärrade i databasoperationen. |
| D004 | 2026-10-22 | Genomfört | Användar-JWT hela vägen till RLS/RPC. Service key bara för den begränsade testworkern. Inga generella adminendpoints eller klientstyrd actor. |
| D005 | 2026-10-22 | Genomfört | Låst offert med 15 min testgiltighet, separat attest och slutbekräftelse. Redigering skapar nytt underlag i detta inkrement; Versionsstyrd serverkorg och invalidation av tidigare underlag finns i 0.2.0. |
| D006 | 2026-10-22 | Delvis | Vercel Workflow med beständig outbox och autentiserad återhämtningsscan implementerad. Worker skapar JSON-bevis; PDF/Storage och riktig e-post återstår. |
| D007 | 2026-10-22 | Öppet | ERP, kreditauktoritet över andra kanaler, Creditsafe-produkt, säljbolag, pilotbutik, avsändare och juridisk information kräver verkligt pilotunderlag. |
| D008 | 2026-10-22 | Godkänt och publicerat | Produktägaren godkände uttryckligen offentlig publicering och fortsatt arbete. API publicerat via GitHub-anslutningen; shell saknar GitHub-inloggning. Produktägaren skapade separat heke99/plockivo-web; webb 0.2.0 publicerad. |
| D009 | 2026-10-22 | Genomfört | Ingen analys/marknadsföring. Host-only HttpOnly sessionskakor; ingen cookie delar session mellan handlardomäner. Cookieinformation ska följa verklig domänkonfiguration. |

D010: Sparad korg ägs av personen och inköpssammanhanget. Versionskonflikter får inte skriva över en annan flik. En korgversion ger ett underlag; redigering invaliderar gammalt underlag atomiskt. Accepterat köp kräver ny korgidentitet.

D011: MFA-005 använder Supabase TOTP. MFA verkställs i SQL mot aktuella faktorer och levande aal2-session, inte bara i webbgränssnittet. Mandatkravet är globalt för personen när något aktivt mandat kräver MFA. Ingen automatisk faktoråterställning eller ny administrativ permission införs.


D012 — 2026-10-26, godkänt av produktägaren: Plockivo ska stödja två driftprofiler: fristående (egna handlarbundna register och verksamhetsregler) och ansluten (verifierad ERP-adapter). ERP är inte ett generellt krav för kundanslutning. Varje profil måste namnge auktoritet för artikel/pris, kredit, lager, order, fakturering och avstämning; ingen blandad eller tyst fallback. Nuvarande synthetic-test är fortsatt separat från båda produktionsprofilerna. Fristående register ska inte automatiskt aktivera försäljning, kredit eller fakturering.

D013 — 2026-10-26, implementation inom godkänd fristående drift: betalningsavstämning i Plockivo är en uttrycklig, underlagsbunden administrativ registrering efter helutlämning. Ingen banköverföring, fakturautställning eller automatisk bankverifiering sker. Del-/helbetalning återför exakt motsvarande kreditexponering; separat rättelse återställer exponeringen även om kreditgränsen senare sänkts. Projektets redan förbrukade budget och fysiskt lager ändras inte. Referens är trim:ad, exakt och skiftlägeskänslig med en aktiv allokering per handlare; återförd referens kan återanvändas med ny spårbar registrering. Ansluten ERP-betalningsauktoritet ingår inte i denna manuella driftprofil.
