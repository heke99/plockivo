# INVITES-006 — personinbjudningar och gränssnitt

2026-10-23. API och webb är separata projekt. Verksamhetsmiljö: endast syntetisk test, Supabase cqznytuyutrqenbbyczc. Publiceringsbas: API 58740a6, webb e8b3abd. Full pilot: RED.

## Implementation

Explicit, handlarbundet delegationsmandat krävs för kundadministratör. Administratören måste passera MFA. Endast inköpare och attestant kan bjudas in; konto-, butik-, projekt-, belopps- och giltighetsgränser verkställs i SQL. En inbjudan gäller högst 72 timmar och kräver en verifierad mottagaridentitet. 256-bitars token sparas endast hashad i databasen. Länken visas en gång; idempotent replay avslöjar inte token igen. Acceptans låser raden och skapar högst ett medlemskap med audit. Återkallelse gäller väntande inbjudan, inte redan accepterat mandat.

Webb: skapa, kopiera, lista, återkalla, förhandsgranska och acceptera. Länktoken ligger i fragment, tas bort ur adressfältet efter att React läst den och skickas i POST-body. Ingen webbläsarlagring av inbjudningstoken. Vid omladdning före acceptans behöver mottagaren öppna originallänken igen. Inga inbjudningsmejl skickas. Nya kontons e-postverifiering/provisionering återstår; UI anger detta uttryckligen.

Framsida på /, app på /app. Illustration märkt som fiktiv, produktförklaring, pilotinformation och vanliga frågor om app, profil och domän. Ingen ny kunddrift eller färdig ERP utlovas. Kontrast, klickytor, namngiven navigation och tangentbordsgenväg till innehåll ingår.

## Matris och evidens

| ID | Prioritet | Kontroll | Resultat |
| --- | --- | --- | --- |
| I006-01 | P0 | Delegation, MFA, scopes, rolleskalering och beloppsgränser | PASS: tests/invitations.sql med authenticated-roll och rollback |
| I006-02 | P0 | Rätt/fel mottagare, token, utgången länk, återkallad utställare | PASS: SQL |
| I006-03 | P0 | Idempotent skapande/acceptans och nekad direkt tabellskrivning | PASS: SQL |
| I006-04 | P0 | Browser: MFA → skapa → fel mottagare nekas → rätt mottagare accepterar → replay | PASS |
| I006-05 | P1 | Framsida, navigation, tangentbord, 320/390/768/1440 px | PASS |
| I006-06 | P0 | Städning och readback | PASS: merchants/users/invitations/sessions/factors = 0 |

API npm run verify PASS: standard, typkontroll, nio tester, produktionsbygge. Webb npm run verify PASS: standard, typkontroll, fyra tester, produktionsbygge. SQL-migration finns i serverhistoriken. Testharness kör separata portar 3100/3101 för att undvika äldre lokala servrar. Tidigare testomkörning mötte kvarvarande syntetisk MFA-faktor; denna nollställdes endast för fixture-identiteten. Fragmentkontrollen väntar nu på klienthydrering innan assertion. En separat rättning klipper vald sista giltighetsdag till delegationsmandatets exakta sluttid.

## Kvarstående

Verkliga utskick, kontoaktivering, MFA-förlust, handlaradministration/profil och verifierad domänbindning återstår. Inga riktiga köp eller kunduppgifter användes. Driftsatt verifiering och ren migrationsreplay får inte räknas som PASS utan nya bevis.

Fynd I006-UI01: att öppna en inbjudan med fragmentnavigation i redan monterad app körde inte mount-effekten igen. Hashchange-hanterare infördes med cleanup. Skapande, fel mottagare, korrekt acceptans och mobil passerade före rättningen; replay och framsida körs om på slutbygget.

## Slutlig lokal evidens

Browser på slutbygget PASS: fel mottagare nekas, accepterad inbjudan återöppnas, fortsättning till konto och upprepad acceptans utan dubbelt mandat. Mobil 390px PASS. Framsidan vid 320/390/768/1440px utan horisontell scroll; tangentbordets första fokus är Hoppa till innehåll. Desktop- och mobilskärmbilder visuellt granskade. Inga pageerrors. Första acceptansen samt administratörens MFA/skapa verifierades på föregående bygge; slutbygget ändrar endast hashchange-hanteringen, giltighetstidsklippning och framsida. Samtliga fyra SQL-sviter (köp, korg, MFA, inbjudningar) PASS efter migration. Databasreadback: en accepterad inbjudan gav exakt ett medlemskap och en accept-audithändelse.

Security Advisor: avsiktliga deny-all-tabeller utan direktpolicy (INFO), befintlig Leaked Password Protection WARN kvarstår. React-granskning: serverrenderad framsida, ingen ny UI-biblioteksdependency, städade event listeners och genererade API-typer.

## Publicering och drift

API c45facd1607299495abf55dd62c5092269c2bade, Vercel dpl_n2hqCb3HFYad9XfLU7RKoCov9Zdt READY. Webb 9d5065cbc23bab9a9724b5d7836ef8b1dd2c6ffa, Vercel dpl_2NzYvam5943ZBzTeovsVVGPoZAZZ READY. Framsidans HTTP 200, ny titel, FAQ och /app-länk verifierade via skyddad Vercel-fetch. Full inbjudningsresa testad lokalt mot riktig Auth/API/databas; inte omkörd genom driftsatt webb. Ingen ny driftsatt browser-PASS påstås.

GitHub Actions API 40029071861 och webb 40029076457 står i kö vid slutkontroll. Ren migrationsreplay i CI är därför ännu inte verifierad för denna release. Befintlig lokal verify samt alla fyra SQL-sviter PASS. Detta är en begränsad testleverans, full pilot fortsatt RED.

Guardad invitations-cleanup.sql körd. Readback: fem testkategorier ovan =0. Temporära testlösenord och länkar tas bort ur /tmp. Inga riktiga mejl skickade. Nästa exakta produktsteg: komplett kontoaktivering/avsändaranslutning och handlarkonfiguration med profil och verifierade domäner. Skydd mot läckta lösenord och MFA-förlust kvarstår före pilot.


Slutkontroll 2026-10-24: GitHub Actions API 40029071861 och webb 40029076457 completed/success för ovanstående kodcommits. Ren migrationsreplay och CI-kvalitetskontroller PASS. Vercel-webbdeployment bekräftad READY med rätt commit och alias plockivo-web.vercel.app. Ny SQL-readback bekräftar återigen noll syntetiska users/merchants/invitations/sessions/factors i fixture-namespace. Ingen ytterligare full driftsatt browserresa har körts.
