# Arbetsdokument — mall

Mallversion: 3.0.0

Använd för ett större uppdrag som behöver plan, fynd och återupptagning. Återanvänd en befintlig motsvarighet. Små ändringar kräver normalt inte ett nytt dokument. Följ [byggstandarden](ENGINEERING_STANDARD.md) och länka från projektets korta [status](PROJECT_STATE.template.md).

## 1. Uppdrag och gränser

- Arbets-ID, datum och ansvarig samordnare: [fyll i].
- Användarens mål, uppdragskälla och klart när: [fyll i].
- Omfattning och uttryckliga avgränsningar: [fyll i].
- Repo, branch, utgångscommit och berörda miljöer: [fyll i].
- Befintliga ändringar som ska bevaras och deras ägare: [fyll i].
- Redan givet mandat och eventuella faktiska åtkomstbegränsningar: [källa och omfattning; inga hemligheter].
- Riskklass och motivering: [fyll i enligt projektets riskmodell].
- Okända uppgifter och reversibla antaganden: [fyll i].

## 2. Krav och spårbarhet

Tillämplighet: `tillämpligt`, `inte tillämpligt` med skäl, `senarelagt` med konsekvens eller `ej bedömt`. Tillämplighet är separat från arbetsstatus. Om en auktoritativ kravtabell redan finns, länka till den och registrera bara detta uppdrags ändringar här.

| Krav-ID | Observerbart krav | Tillämplighet och skäl/konsekvens | Regelägare/definition | Kodreferens | Test eller kontroll och evidens | Arbetsstatus | Driftstatus och miljö |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i eller ej verifierat] | [fyll i] | [fyll i] |

Arbetsstatus följer byggstandarden: `ej bedömt`, `planerat`, `pågår`, `implementerat`, `verifierat`, `blockerat`, `inte tillämpligt`. Driftstatus: `ej driftsatt`, `driftsatt`, `okänt`, `inte tillämpligt`. Ange alltid berörd miljö. `Senarelagt` är ingen verifiering och inget bevis på leveransberedskap.

## 3. Operationskontrakt för berörda kritiska flöden

Fyll endast relevanta delar. Länka befintliga domänspecifikationer hellre än att kopiera dem.

- Aktör, autentisering och eventuell delegering: [fyll i].
- Organisation, målobjekt, fält, historisk period och permissions: [fyll i].
- Förvillkor, tillåtna tillståndsövergångar och regelägare: [fyll i].
- Invariants, transaktionsgräns och samtidighetsskydd: [fyll i].
- Idempotens, dubbletter, externa effekter och återhämtning: [fyll i].
- Kompatibilitet, datamigrering och återställningsväg: [fyll i].
- Förväntade fel och observerbart användarresultat: [fyll i].

## 4. Plan och parallellt arbete

| Steg | Förväntat resultat | Ansvarig | Berörda filer/kontrakt | Beroende och status |
| --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

- Ägare för gemensamma kontrakt och sammanförande: [fyll i].
- Hur samtidiga ändringar i gemensamma filer undviks: [fyll i om relevant].
- Varje delagents överlämning: [ändrade filer, kontrakt, körda kontroller, kvarstående fynd, nästa handling].
- Samordnarens verifiering efter sammanförande: [slutligt samlat kodläge, relevanta kontroller och verkligt utfall; ej utfört innan det har skett].

## 5. Fynd och avvikelser

| Fynd-ID | Observerat respektive förväntat beteende | Konsekvens och risk | Evidens | Ansvarig och status | Rättning och återkontroll |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

Skilj befintliga fel från nya regressioner. Ändra inte krav eller tester för att dölja en avvikelse. Registrera bestående beslut enligt [beslutsmallen](DECISIONS.template.md).

## 6. Verifiering

Välj kontroller efter identifierad risk. Skriv verkliga kommandon från projektet; markera planerade kontroller som ej körda. Använd riktiga applikationsroller när databasskyddet är det som prövas.

| Krav/fynd | Kontroll och förväntat beteende | Exakt kommando eller manuella steg | Arbetskatalog och förutsättningar | Miljö och testat kodläge | Verkligt utfall, tid och evidens |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [commit och relevanta ocommittade ändringar] | [ej kört tills det faktiskt körts] |

- Relevanta tillåtna och nekade fall: [fyll i eller motivera ej tillämpligt].
- Relevanta samtidighets-, upprepnings- och avbrottsfall: [fyll i eller motivera ej tillämpligt].
- Sammanhängande användarresa genom faktiska ingångar: [fyll i].
- Testdata, isolering, externa testmiljöer och städning: [fyll i].
- Kvarstående verifieringsluckor och deras konsekvenser: [fyll i].

## 7. Externa operationer och okända utfall

Dokumentera betydande externa operationer före och efter genomförandet. En timeout bevisar inte att operationen misslyckats. Inga tokens, hemliga värden eller onödiga personuppgifter får sparas här.

| Operations-ID och avsikt | Målsystem och miljö | Mandatkälla | Säker begäran-/idempotensreferens | Senast observerade utfall och tid | Kontroll före eventuell omkörning |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [planerad/påbörjad/bekräftad/misslyckad/okänd med evidens] | [fyll i] |

## 8. Senaste checkpoint

Ersätt den aktuella sammanfattningen när läget ändras; behåll viktig historik i Git eller avsedd logg. Uppdatera vid betydande fynd, beslut, implementation och verifiering samt före överlämning.

- Tid och ansvarig: [fyll i med tidszon].
- Mål och första otillräckligt verifierade punkt: [fyll i].
- Repo/branch/commit, arbetskatalog och ocommittat arbete: [fyll i].
- Berörd miljö och faktiskt observerat läge: [fyll i].
- Senast verifierat och evidens: [fyll i].
- Externa operationer med okänt utfall: [referens till tabellen ovan eller inga kända].
- Blockerare, ansvarig och vad som krävs för att lösa dem: [fyll i].
- Nästa exakta handling och förväntat resultat: [fyll i].
- Vid återupptagning ska följande först kontrolleras: [diff, artefakt, miljö eller extern status].

## 9. Leveransanteckning

- Ändrat beteende och skäl: [fyll i].
- Verifierade krav och samlat testat kodläge: [referenser].
- Kodens placering och driftstatus per miljö: [fyll i; skilj lokalt, sparat i repo, driftsatt och verifierat].
- Kvarstående brister, senarelagda krav och konkreta konsekvenser: [fyll i].
- Uppdaterad kontext, beslut och kort projektstatus: [referenser].
- Nästa handling eller klart inom uttryckligen angiven omfattning: [fyll i].

Använd [produktmallen](PRODUCT_REQUIREMENTS.template.md) endast om produktens krav/register behöver en egen hemvist. Stabil fakta ska återanvändas från projektets [kontext](PROJECT_CONTEXT.template.md).
