# Valbara projektprofiler

Version: 3.0.0 · 2026-10-22

Profilerna kompletterar [byggstandarden](ENGINEERING_STANDARD.md) med beslut och kontroller för återkommande produkttyper. De är inte färdiga implementationer eller en beställning på alla funktioner. Välj endast profiler som motsvarar projektets faktiska krav; kombinera dem när samma flöde berör flera områden.

Ange vald profil, omfattning, beslut och ansvarig källa i projektets befintliga kontext eller kravregister. Markera övriga som `inte tillämpligt` med kort skäl när en bedömning behövs. En aktiverad profil betyder inte att tjänster har provisionerats eller beteenden verifierats. Återanvänd projektets komponenter, kontroller och driftmiljöer.

| Profil | När den hjälper |
| --- | --- |
| 1. Next.js/React och Supabase/Postgres | När projektets faktiska stack innehåller dessa delar |
| 2. White-label och organisationsisolering | När flera organisationer eller separata kundinstallationer ska hanteras |
| 3. Abonnemang och betalningar | När pengar, betalningsstatus eller betalda funktioner ingår |
| 4. PWA, mobil och frånkopplad användning | När mobil användning, installation eller offlinebeteende påverkar produkten |
| 5. AI-funktioner och verktygsanrop | När modeller läser verksamhetsdata, föreslår beslut eller utför handlingar |
| 6. Importer och externt datautbyte | När externa filer, API-flöden eller återkommande synkronisering ingår |

## 1. Next.js/React och Supabase/Postgres

### När profilen gäller

Använd relevanta delar när projektet faktiskt använder Next.js, React eller Supabase/Postgres. Profilen gör inte dessa tekniker obligatoriska och förutsätter ingen viss hosting. Kontrollera installerade versioner och aktuell officiell dokumentation före versionsberoende implementation.

### Beslut att dokumentera

- Vilka klienter som finns, vad som körs på servern och vilka publika API-, serverfunktions- och RPC-gränser de använder.
- Vilka schemas, tabeller, vyer och funktioner som exponeras; vilka databasroller och nyckeltyper som används vid varje ingång.
- Autentiserings- och sessionsmodell samt källa för aktuell medlemsstatus, permissions och återkallelse.
- Vilka skrivningar som är enkel CRUD respektive verksamhetskommandon med gemensam transaktion och skyddade förvillkor.
- Cacheomfång, invalidation och beteende vid organisationsbyte, utloggning och behörighetsändring.
- Migrationsväg, utvecklingsmiljö, anslutningsmodell och relevanta kapacitetsgränser.

### Vad agenten ska bygga

- Håll skyddad serverkod och privilegierade nycklar utanför klientpaket. En publik nyckel är inte ett behörighetsbevis; använd avsiktliga grants och policyer.
- Kontrollera behörighet nära data och mutationer även när navigation eller middleware redan har kontrollerat inloggning.
- Aktivera RLS på tabeller i Data API-exponerade schemas. Kontrollera schemaåtkomst, grants, vyers körkontext, Storage och alternativa åtkomstvägar tillsammans.
- Uttryck relevanta läs- och skrivvillkor med korrekt `USING`/`WITH CHECK`-semantik. PostgreSQL kan återanvända `USING` när separat `WITH CHECK` saknas; granska faktisk policy i stället för att anta öppet eller stängt beteende.
- Föredra `SECURITY INVOKER`; motivera och begränsa privilegierade funktioner enligt byggstandarden. Kritiska kommandon får inte kringgås via direkt tabellskrivning.
- Använd serververifierad identitet och aktuell behörighetsmodell. Användarredigerbar metadata är ingen auktoritativ rättighetskälla; JWT-anspråk kan vara inaktuella.
- Versionera schema och genererade kontrakt enligt projektets arbetssätt. Mät relevanta frågor och policyfilter före prestandaåtgärder.

### Nödvändiga riskbaserade kontroller

- Verifiera avsedd och nekad åtkomst genom verkliga klient-/API-/RPC-ingångar med faktiska approller, inklusive annan organisation och avstängd medlem.
- Kontrollera att uppdateringen faktiskt ändrar avsett antal rader; ett lyckat HTTP-svar eller ett ägartest bevisar inte approllens beteende.
- Prova manipulerade organisations-, ägar-, roll- och statusfält samt direkt skrivning runt kritiska kommandon.
- Kontrollera att cache och serverrenderat innehåll inte återanvänds mellan obehöriga kontexter.
- Verifiera relevant migration från historik och mot representativa befintliga data samt berörda grants, funktioner och indirekta beroenden.

### Vad små projekt inte behöver

Skapa inte ett extra API-lager, RPC för all CRUD, mikrotjänster eller monorepo utan ett konkret behov. Använd befintliga bibliotek och få tydliga domänoperationer. En separat mobilklient kan använda ett versionerat kontrakt från ett eget repo.

## 2. White-label och organisationsisolering

### När profilen gäller

Använd när flera organisationer använder en gemensam plattform eller får separata installationer med samma produkt. Ett varumärke är inte automatiskt en datagräns. Bestäm först vilken isolering verksamheten och driften behöver.

### Beslut att dokumentera

- Vald modell: gemensam databas med avgränsning, separata schemas/databaser eller separata installationer. Beskriv säkerhetsgräns, driftkostnad och återställning.
- Vilka data och identiteter som är globala, organisationsägda eller uttryckligen delade; om samma användare kan tillhöra flera organisationer.
- Vem som får etablera en organisation, verifiera domän/juridiska uppgifter, utse första ägare och överföra ägarskap.
- Vad organisationsavslut innebär för åtkomst, abonnemang, export, laglig bevaring, leverantörer och domäner.
- Ansvar för varumärke, avtal, databehandling, avsändare, support och eventuella driftavtal.

### Vad agenten ska bygga

- Härled organisation från verifierad kontext. Ett domännamn, organisations-ID i begäran eller känt objekt-ID ger inte ensamt rätt att agera.
- Verkställ datagränsen i alla relevanta relationer, lagringsobjekt, exporter, sökindex, realtidskanaler, cache och jobb. Modellera avsiktlig delning uttryckligen.
- Gör etablering återupptagbar där flera steg ingår. Registrera vilka steg som lyckats och undvik dubbla ägare, avtal eller resurser vid upprepning.
- Hämta profil och juridiska uppgifter från kontrollerad konfiguration. Verifiera egna domäner innan de används för autentisering eller avsändaridentitet.
- Ge ofärdig profil en uttrycklig fallback. Använd inte en annan organisations profil, data eller hemligheter som reserv.
- Skilj organisationens avstängning, användarens medlemskap, fakturering och faktisk radering. Återkalla relevanta integrationsidentiteter och behörigheter vid avslut.
- Hantera domänbortkoppling och eventuell senare återanvändning utan att gamla länkar eller sessionsomfång ger tillgång till den nya organisationen.

### Nödvändiga riskbaserade kontroller

- Använd två organisationer med överlappande namn och externa identifierare; testa korsade objektkopplingar, export, sökning, filer och jobb.
- Prova organisationsbyte med öppna flikar, aktiva jobb, gammal cache och tidigare utfärdade länkar enligt deras beslutade giltighet.
- Avbryt etablering mellan steg och återuppta; kontrollera att inga felaktiga eller dubbla resurser lämnas kvar.
- Prova avstängning och avslut utan att andra organisationer påverkas; kontrollera relevant bevarande och export.
- Kontrollera obekräftad domän, saknad profil, fel juridisk part och återanvänt domännamn.

### Vad små projekt inte behöver

Bygg inte en generell installationsplattform eller självbetjänad domänhantering om manuell, dokumenterad etablering räcker. En vald isoleringsmodell behöver inte stödja alla andra modeller som dynamiska alternativ.

## 3. Abonnemang och betalningar

### När profilen gäller

Använd när produkten tar betalt, registrerar betalningsutfall eller begränsar funktioner efter ett köpt paket. Välj leverantör efter projektets behov; denna profil förutsätter ingen viss betaltjänst.

### Beslut att dokumentera

- Faktisk säljare, betalningsmottagare, kundtyp, valuta, skattehantering och beslutade priser/villkor. Okända affärsvillkor får inte uppfinnas.
- Källan för pris, abonnemangsstatus, betalningsutfall och interna funktionsrättigheter samt hur dessa stäms av.
- Tillämpliga flöden: köp, förnyelse, betalningsfel, uppgradering, nedgradering, uppsägning, återbetalning och eventuell tvist.
- När köpta funktioner börjar/slutar gälla, eventuell respit och beteende vid leverantörsavbrott. Skilj detta från användarens säkerhetspermissions.
- Idempotens, transaktionsgräns, avstämningsintervall, rättelsemodell och nödvändig retention.

### Vad agenten ska bygga

- Beräkna eller verifiera debiteringsunderlag från betrodda serverkällor. Klientens belopp, produktkod eller betalningsbekräftelse får inte ensamt styra utfallet.
- Koppla betalning till rätt kund, organisation, beställning och miljö. Skydda engångseffekten även när olika idempotensnycklar används.
- Verifiera leverantörsmeddelanden enligt leverantörens aktuella modell. Hantera dubletter, ordning, återförsök och osäkra resultat.
- Skilj initierat köp, leverantörens mottagande och bekräftat betalningsutfall. En retur till en framgångssida är inte i sig betalningsbevis.
- Registrera tillräckliga referenser för avstämning och spårbar rättelse. Ändra inte tidigare ekonomiska dokument utan vald korrigeringsmodell.
- Låt uppsägning, åtkomst och datalivscykel följa dokumenterade regler. Avslutad betalning betyder inte automatiskt att allt konto- eller verksamhetsdata ska raderas.
- Använd etablerade betalningskomponenter så att produkten inte samlar in fler betalningsuppgifter än den behöver.

### Nödvändiga riskbaserade kontroller

- Prova manipulerat belopp, fel valuta, fel organisationskoppling och försök att aktivera någon annans köp.
- Testa dubbelklick, dubbla leveranser, äldre händelse efter nyare, timeout efter extern framgång och avbruten betalningsresa.
- Kontrollera att missad händelse kan upptäckas genom avstämning och rättas utan dubbeldebitering.
- Prova relevanta förnyelse-/avslutsgränser och att otillåten användare saknar åtkomst även när organisationen har betalt.
- Använd avsedd testmiljö och syntetiska uppgifter; verkliga betalningar kräver faktiskt mandat.

### Vad små projekt inte behöver

Bygg inte egen betalningsmotor, huvudbok, skatteprodukt eller generell leverantörsväxling om ett begränsat köpflöde räcker. Marknadsplatser och förmedlade utbetalningar behöver en separat bedömning av parter, pengar och leverantörskrav.

## 4. PWA, mobil och frånkopplad användning

### När profilen gäller

Använd när mobil åtkomst, installerbar webbapp, nativeklient, lokal lagring eller frånkopplad användning ingår. Mobilanpassning, installation och fungerande offlineoperationer är skilda krav; välj dem uttryckligen.

### Beslut att dokumentera

- Valda klienter, målplattformar och faktisk offlineomfattning: ingen, utvalda läsningar eller utvalda skrivningar.
- Vilka data som får lagras på enheten, åtkomstskydd, retention och risk vid delade eller förlorade enheter.
- Cachemodell, lokala utkast, köade kommandon, konflikter och serverns slutliga auktoritet.
- Vad logout, organisationsbyte, kontospärr och appuppdatering innebär för lokal data och väntande arbete.
- Vilka plattformsfunktioner som behövs och vilka begränsningar som finns i valda webbläsare/enheter.

### Vad agenten ska bygga

- Gör grundflödet användbart på relevanta skärmstorlekar med tydliga laddnings-, frånkopplings- och feltillstånd.
- Klassificera cachebart innehåll. Spara inte känsliga API-svar i en generell delad cache; separera eller undvik lokala kopior efter valt skyddsbehov.
- Märk lokal data och köade operationer med rätt identitet/organisation. Ett tidigare utkast får inte skickas som nästa inloggade användare.
- Skilj lokalt sparat, köat, synkroniserat och bekräftat av servern. Visa konflikt och tillåt begriplig återhämtning utan tyst dataförlust.
- Ge köade mutationer beständig identitet och låt servern kontrollera aktuellt mandat, förvillkor och idempotens vid synkronisering.
- Rensa eller gör skyddade lokala data otillgängliga enligt vald modell vid logout/kontextbyte. En frånkopplad enhet kan inte lovas omedelbar fjärrradering.
- Hantera klient-/serviceworkeruppdatering så att gamla köade kommandon och API-kontrakt inte omedvetet får ny betydelse.

### Nödvändiga riskbaserade kontroller

- Prova frånkoppling före, under och efter en mutation samt återanslutning med dubbla försök.
- Testa två enheter som ändrar samma objekt och en köad åtgärd efter ändrad behörighet eller serverstatus.
- Logga ut och in som en annan användare/organisation; kontrollera cache, lagring, utkast, bakåtknapp och väntande kö.
- Prova uppdatering med osynkroniserat arbete och kontrollera att viktiga användaruppgifter inte försvinner eller skickas dubbelt.
- Verifiera valda funktioner på faktiska målplattformar; ett manifest eller en mobil skärmbild bevisar inte hela beteendet.

### Vad små projekt inte behöver

En responsiv webbapp kan räcka. Inför inte offlineändringar, pushnotiser, nativeappar eller en synkmotor utan behov. Betalning eller annan känslig realtidshandling behöver inte erbjudas offline.

## 5. AI-funktioner och verktygsanrop

### När profilen gäller

Använd när en modell läser verksamhetsdata, producerar innehåll, påverkar beslut eller använder verktyg. Vanlig sökning eller fasta regler behöver inte ersättas av AI. En modell får inte vara systemets auktoritativa behörighetskontroll.

### Beslut att dokumentera

- Avsedd uppgift, kvalitetsmått, tillåtna datakällor och vilka fel som är oacceptabla.
- Leverantörer, faktisk databehandling, lagring, modell-/promptversioner och tillåtna överföringar.
- Om funktionen endast föreslår, skapar utkast eller utför avgränsade handlingar; vilka befintliga mandat som krävs.
- Resursbudget per uppdrag och relevant användare/organisation: tid, anrop, tokens, verktyg och kostnad.
- Källa för utvärderingsfall, hantering av feedback, förändringsgranskning, återställning och mänsklig eskalering när den behövs.

### Vad agenten ska bygga

- Begränsa hämtning innan data når modellen. Sökindex, embeddings, filer, minne och cache ska följa samma organisation-/objektgränser som ursprungsdata.
- Behandla dokument, webbinnehåll, verktygssvar och modellutdata som obetrodda. Deras instruktioner får inte utöka mandat eller byta organisation.
- Verkställ schema, tillåtna verktyg, argumentkontroller, scope, budget och relevanta verksamhetsförvillkor utanför modellen.
- Låt verkliga mutationer gå genom ordinarie domänoperationer med audit, idempotens och återhämtning. En pågående session ger inte fritt mandat till alla verktyg.
- Ge användaren relevant källstöd och tydlig osäkerhet där uppgiften behöver det. Skilj hämtade fakta, modellförslag och verifierade systemutfall.
- Versionera förändringar och utvärdera representativa fall före införande. Feedback är underlag; ändra inte produktionsregler, prompts eller behörigheter automatiskt utan en uttrycklig kontrollerad process.
- Begränsa loggar och utvärderingsdata; använd inte kunddata för annan träning eller delning genom ett odokumenterat antagande.

### Nödvändiga riskbaserade kontroller

- Testa promptinjektion i hämtat material, försök till datauttag från annan organisation och ändring av verktygsargument/mandat.
- Prova felaktigt format, påhittad källa, motstridigt underlag, tomt sökresultat och leverantörsfel.
- Kontrollera stopp vid budget/tidsgräns, begränsad återförsökning och avbrott under en verktygsoperation.
- Kör representativa kvalitets- och säkerhetsfall vid relevant modell-, prompt-, retrieval- eller verktygsändring. Ett exempel med bra svar räcker inte.
- Verifiera att förbjudna handlingar nekas av systemet även när modellen uttryckligen begär dem.

### Vad små projekt inte behöver

Bygg inte en autonom agent, vektordatabas, fleragentsystem eller självlärande loop om ett avgränsat modellsteg räcker. Välj en liten men relevant utvärderingsmängd och dokumentera återstående osäkerhet.

## 6. Importer och externt datautbyte

### När profilen gäller

Använd för filer, API-import, webhookflöden eller synkronisering där externa data blir verksamhetsunderlag. Profilen passar även datamigrering från ett äldre system. Import, validering, accept och publicering är olika steg när konsekvensen kräver det.

### Beslut att dokumentera

- Källa, åtkomsträtt, tillåten användning, avtal/licens och eventuell personuppgiftsbehandling.
- Format-/kontraktsversion, fältmappning, enheter, tidszoner, identifierare och vem som äger respektive uppgift.
- Hur externa identiteter kopplas till interna objekt och organisationsgränser; definiera skillnaden mellan dubblett, rättelse och ny post.
- Vald felmodell: avvisa hela leveransen eller acceptera säkra delar med tydlig resultatrapport. Definiera atomisk gräns och återupptagningspunkt.
- Konfliktregler, radering/avpublicering, avstämning, originalunderlag och retention.

### Vad agenten ska bygga

- Autentisera källan där det är relevant och validera kontrakt, storlek och innehåll före verksamhetsskrivning. Externa organisations-ID:n måste mappas genom en betrodd relation.
- Begränsa nätverkshämtning, filbearbetning, arkivexpansion och externa referenser efter hotbild. Ett filnamn eller deklarerad innehållstyp räcker inte som säkerhetsbevis.
- Bevara källreferens och bearbetningsversion när spårbarhet behövs. Visa rad-/objektfel utan att avslöja andras data eller hemligheter.
- Gör återkörning och samtidiga leveranser säkra. Tillåt inte äldre data att oavsiktligt skriva över nyare eller lokalt auktoritativa uppgifter.
- Håll publicering och externa följdeffekter bakom samma domänregler som manuellt inmatade data. Import får inte bli en genväg runt permissions eller statusregler.
- Hantera partiella utfall, borttagna källobjekt, ändrade format och osäkra leverantörsresultat genom synlig avstämning och återhämtning.

### Nödvändiga riskbaserade kontroller

- Prova fel organisation, kolliderande externa identifierare, dubbla leveranser och samma identitet med ändrat innehåll.
- Testa ogiltiga enheter/datum, saknade obligatoriska fält, blandade giltiga/felaktiga rader och avbrott mitt i bearbetning.
- Kontrollera att återupptagning ger avsett slutresultat och att rapporterade antal stämmer med bestående data.
- Prova otillåtna hämtmål, skadligt/överstort innehåll och arkivexpansion när sådana funktioner stöds.
- Testa relevant ändring av källa eller kontraktsversion utan tyst datakorruption.

### Vad små projekt inte behöver

Bygg inte en generell integrationsplattform om ett känt format och ett begränsat flöde räcker. En enkel validerad batch kan vara bättre än kontinuerlig synkronisering. Etablera inte extra leverantörer eller inhämta data som projektet saknar rätt och behov att använda.

## Tillämpning och verifiering

Profiler kompletterar varandra; de ersätter inte byggstandardens proportionalitet, transaktioner, datalivscykel eller dokumentation. Registrera valda beslut nära projektets auktoritativa fakta och koppla riskkontroller till verkliga testkommandon eller annan konkret evidens. Markera tydligt vad som är planerat, implementerat, verifierat och driftsatt. Använd aktuella officiella dokument för den teknik och leverantör som faktiskt har valts.
