# Produktkrav och register — mall

Mallversion: 3.0.0

Använd endast de avsnitt produkten behöver. Skapa `PRODUCT_REQUIREMENTS.md` om en motsvarande kravkälla saknas; skapa inte parallella register. Detta dokument beskriver produkten, inte agentens dagliga arbete. Följ [byggstandarden](ENGINEERING_STANDARD.md), [projektkontexten](PROJECT_CONTEXT.template.md) och relevanta [beslut](DECISIONS.template.md).

## 1. Produktens första kompletta resa

- Målgrupp, problem och önskat resultat: [fyll i].
- Första leveransens omfattning och uttryckliga avgränsningar: [fyll i].
- Marknader, språk, avtalspart och faktisk affärsmodell: [fyll i utifrån källor].
- Aktörer och relevanta roller: [fyll i; inför inte roller utan behov].
- Mätbart acceptansvillkor för den sammanhängande användarresan: [fyll i].
- Beslutskällor, ansvariga och kritiska okända uppgifter: [fyll i].

## 2. Tillämplighet och risk

Bedöm relevanta områden såsom identitet, behörighet, databas, integrationer, personuppgifter, cookies, villkor, mallar, gränssnitt och drift. Registrera inte varje möjlig funktion som ett krav.

| Område eller krav-ID | Tillämplighet | Skäl eller konsekvens av senareläggning | Riskklass och motivering | Ansvarig och villkor för omprövning |
| --- | --- | --- | --- | --- |
| [fyll i] | [tillämpligt/inte tillämpligt/senarelagt/ej bedömt] | [fyll i] | [enligt projektets riskmodell] | [fyll i] |

Tillämplighet, arbetsstatus och driftstatus är olika uppgifter. Ett senarelagt säkerhetskrav kan begränsa vad som får levereras; det blir inte uppfyllt genom att senareläggas.

## 3. Krav, ägarskap och evidens

Ge relevanta krav stabila ID:n. Beskriv observerbart beteende, inte enbart önskade sidor eller tabeller. Om krav redan finns i ett annat system ska denna tabell länka dit.

| Krav-ID | Aktör, ingång och förvillkor | Önskat resultat och felväg | Regelägare/definition | Kodreferens | Test/kontroll och evidens | Arbetsstatus | Driftstatus och miljö |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i eller ej verifierat] | [fyll i] | [fyll i] |

Arbetsstatus: `ej bedömt`, `planerat`, `pågår`, `implementerat`, `verifierat`, `blockerat`, `inte tillämpligt`. Driftstatus: `ej driftsatt`, `driftsatt`, `okänt`, `inte tillämpligt`. Verifiering kräver evidens som anger kodläge, miljö och faktiskt resultat. Exakta kommandon kan ägas av [projektkontexten](PROJECT_CONTEXT.template.md), och uppdragets körningar av [arbetsdokumentet](WORK_ITEM.template.md).

## 4. Identitet och tillåtna verksamhetshandlingar — vid behov

- Konto- och medlemslivscykler som produkten faktiskt ska erbjuda: [fyll i].
- Identitet, tenant, objekt, fält, tillstånd och historikvillkor: [fyll i eller referens].
- Skillnad mellan säkerhetsbehörighet och abonnemangsfunktioner: [fyll i].

| Handling eller permission | Tilldelning och omfattning | Förvillkor och regelägare | Otillåtet fall som ska nekas | Krav/testreferens |
| --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

## 5. Datakarta och retention — vid personuppgiftsbehandling

Dokumentera verklig behandling och verifierat ansvar. Integritetsinformation, avtalsaccept och ändamålsspecifikt samtycke ska bedömas var för sig. Följande tabell är inget färdigt juridiskt ställningstagande.

| Behandlings-ID och ändamål | Uppgifter och källa | Ansvarig/biträde och ägare | Rättslig grund och beslutskälla | System, mottagare och relevanta överföringar | Lagringstid eller kriterium | Gallring, bevarande och verifiering |
| --- | --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i eller olöst fråga] | [fyll i] | [fyll i eller olöst fråga] | [fyll i] |

- Export/rättighetsbegäranden, identitetskontroll, ansvar och skyddad leverans: [fyll i].
- Omfattning i cache, sökindex, objektlagring, leverantörer och säkerhetskopior: [fyll i].
- Återställning utan obemärkt återinförande av raderingar eller återkallad åtkomst: [fyll i].
- Incidentprocess och ansvarig: [fyll i].
- Särskilda kategorier, barn eller branschkrav som behöver bedömas: [fyll i eller motivera ej tillämpligt].

## 6. Lagring i användarens utrustning och samtycke — vid behov

| Funktion/cookie/lagring | Leverantör och ändamål | Varaktighet | Bedömd nödvändighet och underlag | Aktivering före/efter val | Återkallelse och verifiering |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

- Beslutad modell, marknad och ansvarig för bedömning: [fyll i].
- Kontroller före val, efter neka, selektiv accept och återkallelse: [evidens eller planerat och ej verifierat].
- Om endast undantagna funktioner används: [verifierat underlag; inför inte en banner utan bedömt behov].

## 7. Juridiskt dokumentregister — vid behov

Fyll med beslutade fakta och aktuellt underlag. Denna mall fastställer inte priser, avtalsvillkor, lagval, lagringstider, konsumenträtt eller juridisk fullständighet.

| Dokument-ID och syfte | Produkt, målgrupp och marknad | Faktisk juridisk part | Språk, version och giltighet | Ägare och granskningsstatus | Faktaunderlag och öppna frågor | Publicering/accept och verifiering |
| --- | --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

- Vilka dokument kräver information respektive accept, och på vilket underlag: [fyll i].
- Hur rätt part, dokumentversion och relevant handling kan visas i efterhand: [fyll i].
- Öppna frågor som hindrar publicering av ett berört dokument: [fyll i; oberoende utveckling kan fortsätta].
- Koppling mellan dokumentens löften och verifierat systembeteende: [kravreferenser].

## 8. Mall- och meddelanderegister — vid behov

| Mall-ID och syfte | Utlösande bestående händelse | Ägare, språk och version | Datakontrakt och obligatoriska variabler | Mottagare, avsändare och tenantprofil | Rendering, leverans och evidens |
| --- | --- | --- | --- | --- | --- |
| [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] | [fyll i] |

- Behov av oföränderlig historik och retention: [fyll i].
- Tillåtna tenantanpassningar, domänverifiering och fallback: [fyll i].
- Uppdelning mellan säkerhetsinformation, transaktion och marknadsföring: [fyll i].
- Testunderlag och avsedda mottagare som förhindrar oavsiktliga skarpa utskick: [fyll i].

## 9. Produktkvalitet och drift — relevanta krav

- Tillgänglighetsmål, mobilstöd och relevanta gränssnittstillstånd: [fyll i].
- Kapacitets-/kostnadsantaganden, mätpunkter och begränsningar: [fyll i].
- Driftansvar, verksamhetslarm och återhämtningsmål: [fyll i].
- Backupomfattning och separat skydd för filer/identitetsdata/konfiguration: [fyll i].
- Externa integrationer, API-kontrakt och ansvar för avstämning: [fyll i].
- AI-funktioners datakällor, verktygsscope, budget och verifierade gränser, om relevant: [fyll i].

Varje relevant punkt ska antingen ha ett krav-ID med evidens eller en motiverad tillämplighetsbedömning. Aktuellt arbetsläge hör hemma i [projektstatusen](PROJECT_STATE.template.md); undvik en andra framstegslogg här.
