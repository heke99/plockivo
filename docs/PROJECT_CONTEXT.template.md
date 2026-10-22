# Projektkontext — mall

Mallversion: 3.0.0

Använd denna mall för stabila, verifierade projektfakta. Skapa `PROJECT_CONTEXT.md` endast om projektet saknar en motsvarighet. Ersätt platshållare med verkliga uppgifter; skriv `okänt` där underlag saknas. Aktuellt arbete hör hemma i [statusmallen](PROJECT_STATE.template.md) och större uppdrag i [arbetsmallen](WORK_ITEM.template.md). Följ [byggstandarden](ENGINEERING_STANDARD.md).

## 1. Produkt och omfattning

- Produktnamn och ändamål: [fyll i].
- Användare, målmarknader och språk: [fyll i].
- Avtalspart och verifierad källa för bolagsuppgifter: [fyll i].
- Verksamhetsägare och tekniskt ansvar: [fyll i].
- Produktens viktigaste sammanhängande användarresa: [fyll i].
- Avgränsningar och sådant som uttryckligen inte ingår: [fyll i].
- Kravkälla och var produktens tillämplighetsbedömning finns: [fyll i; använd vid behov produktmallen nedan].

## 2. Källor och fakta

| Uppgift | Värde | Klassning: verifierat / antagande / okänt | Källa och senast kontrollerad |
| --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] |

## 3. Kodbas och teknik

| Repo eller komponent | Ansvar | Auktoritativ källa | Teknik och faktisk version | Kontrakt till andra komponenter |
| --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

- Pakethanterare, låsfil och runtime: [fyll i utifrån kodbasen].
- Standardbranch och arbetsflöde för ändringar: [fyll i].
- Separata repos och deras distributionsväg för gemensamma kontrakt, om relevant: [fyll i eller ange ej tillämpligt med skäl].
- Databas, migrationskälla och ordning mellan kod och schema: [fyll i].
- Tillämpad version av byggstandarden, källa och lokala avvikelser: [fyll i].

## 4. Miljöer och åtkomst

| Miljö | Syfte och data | Projekt-/miljöidentifierare | Tillåtna externa effekter | Åtkomstkälla och ansvarig |
| --- | --- | --- | --- | --- |
| [fyll i] | [syntetiska/verkliga data enligt verifierat underlag] | [fyll i] | [fyll i] | [referens; inga hemligheter] |

- Obligatoriska konfigurationsnamn och var de valideras: [fyll i; aldrig hemliga värden].
- Hur agenten kontrollerar att rätt miljö används: [fyll i].
- Leverantörer, rättigheter och test-/produktionsseparation: [fyll i].
- Kända åtkomstbegränsningar: [fyll i].

## 5. Identitet, domäner och regelägare

- Identitetsleverantör, identitetsnyckel och sessionsmodell: [fyll i].
- Organisationsgräns och medlemskap, om relevant: [fyll i].
- Auktoritativ permissionmodell och tilldelningsväg: [fyll i].
- Aktör, delegering, integrationer och tekniska exekverare: [fyll i].
- Hur spärrar, återkallelse och historisk åtkomst hanteras: [fyll i].

| Regel-ID eller domän | Regel och invariant | Auktoritativ ägare/definition | Anropande ingångar | Verifieringens hemvist |
| --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

## 6. Verkliga arbets- och verifieringskommandon

Skriv endast kommandon som finns i projektet. Skilj att ett kommando identifierats från att det faktiskt körts och godkänts. Lägg inte in påhittade paketnamn, testskript eller miljöer.

| Syfte | Arbetskatalog och exakt kommando | Förutsättningar och miljö | Urval och leveransregel | Ägare | Senast faktiskt verifierat, kodläge och evidens |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i; kommando eller okänt] | [fyll i] | [när kontrollen krävs och vad ett fel blockerar] | [fyll i] | [fyll i eller ej kört] |

## 7. Mandat och ansvar

- Aktuellt uppdrag och redan givna instruktioner: [referens till källa och omfattning].
- Tillåtna målmiljöer och externa effekter enligt uppdraget: [fyll i].
- Faktiska beslut eller åtkomster som ännu saknas: [fyll i].
- Ansvarig för produktbeslut, juridiskt underlag och drift: [fyll i].

Denna sammanställning återger befintligt mandat. Den ger inga nya åtkomsträttigheter och inför inga egna godkännandesteg för redan auktoriserat arbete.

## 8. Dokumentens ansvar

| Information | Projektets faktiska fil eller system | Ansvarig |
| --- | --- | --- |
| Stabil projektkontext | [fyll i] | [fyll i] |
| Aktuellt läge och nästa handling | [fyll i; se statusmallen] | [fyll i] |
| Bestående beslut | [fyll i; se beslutsmallen] | [fyll i] |
| Större uppdrag och evidens | [fyll i; se arbetsmallen] | [fyll i] |
| Produktkrav och eventuella register | [fyll i; se produktmallen] | [fyll i] |

Använd [beslutsmallen](DECISIONS.template.md) och [produktmallen](PRODUCT_REQUIREMENTS.template.md) vid behov. Bevara en källa per uppgift och länka till den; duplicera inte aktuell status här.
