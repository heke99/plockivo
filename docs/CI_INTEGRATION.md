# Projektets verifieringskontrakt och CI

Version 3.0.0 · 2026-10-22

Detta dokument beskriver hur [byggstandarden](ENGINEERING_STANDARD.md) görs återkommande och körbar. Paketets statiska dokumentkontroll är en separat kontroll av själva standarden. Inget applikationskommando eller externt testresultat är fastställt av denna mall.

## Upprätta kontraktet vid införande

1. Inventera faktisk pakethanterare, scripts, testverktyg, databasmiljö och existerande CI. Bekräfta att dokumenterade kommandon verkligen finns.
2. Välj en tydlig ingång för relevanta lokala kvalitetskontroller. Återanvänd befintlig ingång; skapa en projektspecifik om det behövs. Ett namn som `verify` är ett möjligt mönster, inte ett påstående om ett existerande kommando.
3. Koppla riskområden till verkliga kommandon, miljöer, nödvändiga förutsättningar och evidens. Skilj automatiska kontroller från manuella kontroller.
4. För in relevanta återkommande kontroller i projektets verkliga CI. Ange vilka resultat som blockerar merge eller release enligt projektets risk och åtkomstmodell. Kontrollera faktiskt aktiverade regler; en YAML-fil bevisar inte att en branch är skyddad.
5. Dokumentera eventuella luckor och ansvarig för dem. Tillgängliga, oberoende kontroller ska fortsätta även när en specifik testmiljö är blockerad.

Använd tabellen i [projektkontexten](PROJECT_CONTEXT.template.md) eller motsvarande auktoritativa register. Skapa inte en extra handredigerad kopia av samma kommando här.

| Område | Vad som ska kunna fastställas |
| --- | --- |
| Kommando | Exakt existerande kommando och rätt arbetskatalog |
| Förutsättning | Runtime, tjänster och icke-hemliga miljökrav |
| Testdata | Isolerade syntetiska data, roller och städning |
| Miljö | Lokal, CI, staging eller annan namngiven miljö |
| Resultat | Verkligt utfall, evidensreferens och kodläge |
| Leveransregel | När kontrollen krävs och vad ett fel blockerar |
| Ägare | Vem som underhåller kontroll och hanterar fynd |

## Risknivå väljer kontroller

| Nivå | Typiskt innehåll | Normal kontroll |
| --- | --- | --- |
| Låg | Text och layout utan ändrat beteende | Relevant visuell/funktionell kontroll och befintliga berörda kontroller |
| Normal | Affärsregel, API-kontrakt, status eller integration | Riktade regel- och integrationstester samt verklig användarväg |
| Hög | Identitet, tenantgräns, känsliga data, pengar, kritisk mutation eller migration | Relevanta negativa fall, verkliga approller, samtidighet, återförsök och återhämtning |

Bedöm efter konsekvens, spridning, reversibilitet och exponering. Ett litet kodbyte kan ha hög risk. Matrisen anger exempel; den kräver inte att varje hög risk testar varje typ av fel när mekanismen är irrelevant.

## Vad som kan automatiseras när det behövs

- Build, typkontroll, kodkontroller och riktade tester enligt projektets språk och verktyg.
- Scheman, genererade typer/klienter och kompatibilitet mot verkliga konsumenter.
- Uppbyggnad från migrationshistorik och relevant uppgradering av representativa befintliga data.
- RLS, grants, RPC, vyer och kritiska flöden under de roller som applikationen använder, inklusive nekade fall.
- Samtidighet, idempotens, fel före/efter commit och avstämning när detta är kärnan i risken.
- Relevanta hemlighets- och beroendekontroller med en verklig process för att bedöma och rätta fynd.
- Lokala dokumentlänkar och paketstruktur med `tools/engineering/check_standard.py`.

Statisk SQL-granskning kan upptäcka vissa avvikelser men ersätter inte policytester. En mockad databas bevisar inte RLS. Automatiska tillgänglighetskontroller täcker bara delar av gränssnittets krav. Ett godkänt testbevis ska ha tydlig räckvidd.

## Säker test- och leveransmiljö

Kör tester isolerat med avsedda identiteter, syntetiska data och begränsade rättigheter. Förhindra oavsiktliga kundutskick och riktiga betalningar. Återställ inte en delad miljö på ett sätt som stör andra uppdrag. Ange deterministiska fixtures och städning där det behövs; hemligheter hör inte hemma i kod, testartefakter eller dokument.

Begränsa CI-token och deployidentiteter efter jobbets behov. Kör inte obetrodd PR-kod med produktionshemligheter. Lås granskade tredjepartsactions till avsedd revision. Verifiera artefaktens koppling till testad kodversion och dokumentera migrationsordning. Förvaltning av dessa rättigheter följer faktiskt uppdrag och åtkomst; detta dokument ger inga nya behörigheter.

Hantering av kända brister ska ange konsekvens och omfattning. Gör inte om ett felande test till grönt genom att ta bort det avsedda kravet. Markera oförutsägbar testinstabilitet som en lucka med orsak och åtgärd; upprepade omkörningar utan diagnos är inte ny evidens.

## Evidens och slutligt resultat

Knyt resultat till commit och relevanta ocommittade ändringar, miljö, körning och observerat utfall. För större flöden kopplas detta till krav-ID i [arbetsdokumentet](WORK_ITEM.template.md) eller [produktkraven](PRODUCT_REQUIREMENTS.template.md). En ny förändring gör inte all gammal evidens ogiltig, men påverkade påståenden behöver bedömas igen.

Efter parallellt arbete ska huvudagenten granska samlad diff, gemensamma kontrakt och relevanta kontroller på den sammanförda versionen. Skilj lokal verifiering från driftsatt beteende. Om deploy ingår i uppdraget ska relevanta kontroller även bekräfta målmiljön; ändra inte drift enbart för att skapa ett testbevis utanför uppdraget.

Primärkällor: [OWASP ASVS](https://asvs.owasp.org/), [GitHub Actions: säker användning](https://docs.github.com/en/actions/reference/security/secure-use). Välj aktuella verktygsdetaljer för projektets faktiska version.
