# Engineering Startkit

Version 3.0.0 · 2026-10-22 · Språk: svenska

Ett portabelt arbetssätt för att starta, bygga vidare på och granska mjukvaruprojekt. Agenten väljer relevanta krav efter verklig produkt, stack och risk och bygger sedan en fungerande användarresa. Paketet innehåller instruktioner och mallar; inga externa skills, applikationsberoenden eller tjänster installeras automatiskt.

## Snabbstart för ett nytt projekt

1. Packa upp ZIP-filen och kopiera innehållet i `engineering-startkit/` till den avsedda projektroten. Bevara eventuell befintlig projektkod och instruktioner.
2. Ge agenten texten i [START_PROMPT.txt](START_PROMPT.txt), tillsammans med vad du vill bygga och redan beslutade förutsättningar.
3. Agenten följer [AGENTS.md](AGENTS.md) och [startprotokollet](docs/START_HERE.md), inventerar förutsättningarna och väljer tillämpliga områden.
4. Agenten skapar minsta nödvändiga projektkontext och aktuell status från mallarna, verifierar ett första komplett flöde och bygger vidare därifrån.

Att lägga filerna i en chatt eller mapp är inte bevis på att ett visst agentverktyg laddar dem automatiskt. Codex har stöd för `AGENTS.md`. För andra verktyg: använd den explicita startprompten och dokumentera hur projektets instruktioner kopplas in i verktyget. Kontrollera upptäckten i den miljö du faktiskt använder. Paketet ändrar ingen global agentkonfiguration.

## Införande i ett befintligt projekt

Packa först upp paketet i en separat mapp. Slå samman relevanta instruktioner och dokument med projektets befintliga motsvarigheter. Skriv inte över en befintlig `AGENTS.md` eller projektdokument genom blind uppackning.

Ett valfritt importverktyg kräver Python 3.10 eller senare och endast standardbiblioteket. Det visar ändringarna utan att skriva som standard:

```bash
python3 /sokvag/engineering-startkit/tools/engineering/bootstrap.py --project /sokvag/mitt-projekt
```

När den visade filkopieringen är rätt kan du eller agenten inom uppdragets mandat tillämpa den:

```bash
python3 /sokvag/engineering-startkit/tools/engineering/bootstrap.py --project /sokvag/mitt-projekt --apply
```

Ersätt exempelsökvägarna med verkliga sökvägar. Verktyget lämnar likadana filer, avvisar konflikter före kopiering och följer inte målstrukturens symlänkar. En befintlig avvikande `AGENTS.md` bevaras; kompletteringen får namnet `AGENTS.engineering.md`. Den alternativa filen är ett underlag för sammanslagning och blir inte automatiskt aktiv. Filsystemfel kan fortfarande avbryta en kopiering; kommandot kan köras om efter att orsaken åtgärdats. Importverktyget är ingen generell installations- eller uppgraderingshanterare.

## Vad filerna gör

| Fil | Ansvar |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Kort ingång, läsordning, grundregler och avslut |
| [docs/START_HERE.md](docs/START_HERE.md) | Hur agenten inför standarden och börjar bygga |
| [docs/ENGINEERING_STANDARD.md](docs/ENGINEERING_STANDARD.md) | Detaljerade regler och verifiering per område |
| [docs/PROJECT_PROFILES.md](docs/PROJECT_PROFILES.md) | Valbara profiler för bland annat white-label, betalning, mobil och AI |
| [docs/CI_INTEGRATION.md](docs/CI_INTEGRATION.md) | Projektanpassat verifieringskontrakt och CI-införande |
| [docs/SKILLS_CATALOG.md](docs/SKILLS_CATALOG.md) | Kandidater, licenser, kompatibilitet och verkliga installationer |
| [docs/PROJECT_CONTEXT.template.md](docs/PROJECT_CONTEXT.template.md) | Stabila projektfakta och dokumentkarta |
| [docs/PROJECT_STATE.template.md](docs/PROJECT_STATE.template.md) | Kort aktuellt läge och nästa handling |
| [docs/DECISIONS.template.md](docs/DECISIONS.template.md) | Bestående produkt- och arkitekturbeslut |
| [docs/WORK_ITEM.template.md](docs/WORK_ITEM.template.md) | Större uppdrags plan, fynd, evidens och checkpoints |
| [docs/PRODUCT_REQUIREMENTS.template.md](docs/PRODUCT_REQUIREMENTS.template.md) | Tillämpliga krav och produktregister |
| [tools/engineering/check_standard.py](tools/engineering/check_standard.py) | Statisk kontroll av paketets struktur och dokumentlänkar |
| [tools/engineering/bootstrap.py](tools/engineering/bootstrap.py) | Valfri filkopiering utan överskrivning |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Paketets ändringshistorik |

Mallarnas filnamn slutar på `.template.md`. Kopiera bara de mallar som behövs till deras faktiska projektdokument, eller använd projektets befintliga motsvarigheter. Fyll okända värden som okända. Tomma exempel och mallrubriker är inga fattade beslut.

## Kontrollera införandet

I det uppackade paketet:

```bash
python3 tools/engineering/check_standard.py --project . --mode package
```

I målprojektet efter import:

```bash
python3 tools/engineering/check_standard.py --project . --mode project
```

Denna kontroll verifierar filstruktur och lokala dokumenthänvisningar i paketets kända dokument. Den kör inte appens tester, validerar inte juridik och bevisar inte säkerhet, instruktionsupptäckt eller fungerande produktion. Dessa kontroller finns i projektets verifieringskontrakt.

## Anpassning och uppdatering

- Teknikval och organisationsnamn ska hämtas från projektet. Paketet föreskriver ingen viss bransch, leverantör eller monorepo.
- Funktioner kan vara tillämpliga, senarelagda med dokumenterad konsekvens eller inte tillämpliga med skäl. Säkerhetsgränser för befintliga verkliga data och effekter får inte beskrivas som lösta genom att skjutas upp.
- Nya standardversioner granskas som en diff. Bevara projektets egna beslut, testa berörd ändring och uppdatera antagen version. Skriv inte över lokal anpassning med importverktyget.
- `STARTKIT_MANIFEST.json` identifierar levererade filer och deras SHA-256. Det visar paketets bytes; det är ingen signerad leveranskedja eller säkerhetscertifiering. `VALIDATION_REPORT.md` gäller paketets utgivning och ska inte förväxlas med målprojektets tester.

Primärkällor för agentupptäckt: [OpenAI: AGENTS.md](https://developers.openai.com/codex/guides/agents-md). Tekniska och juridiska primärkällor finns i byggstandarden och katalogen. Paketet innehåller egen standardtext och hänvisningar; externa skillpaket och deras licenser följer inte automatiskt med.
