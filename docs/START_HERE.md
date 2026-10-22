# Startprotokoll för agenten

Version 3.0.0 · 2026-10-22

Använd detta vid första införande, en ny produkt eller ett större uppdrag. Vid små ändringar används relevanta befintliga instruktioner och dokument. Syftet är att förstå, välja, bygga och verifiera. En färdig plan utan implementation är inte en färdig bygguppgift.

## 1. Identifiera uppdrag och arbetsyta

- Läs [AGENTS.md](../AGENTS.md), tillämpliga lokala instruktioner och användarens aktuella mål. Notera vad som redan beslutats och vilken åtkomst som faktiskt finns.
- Kontrollera repo/projektrot, branch, diff och ocommittade ändringar. Respektera andra personers och agenters arbete. Kartlägg existerande appar och repos; kräv inget monorepo.
- Hitta befintlig projektkontext, status, beslutslogg, produktkrav och aktivt arbetsdokument. Återanvänd motsvarigheter och registrera en dokumentkarta. Skapa inte parallella minnessystem.
- Vid återupptagning: kontrollera checkpoint mot verklig kod och berörd miljö. Kontrollera särskilt externa operationer med okänt utfall innan du eventuellt försöker igen.

## 2. Inventera det som faktiskt finns

Läs relevanta manifest, låsfiler, miljöexempel utan hemligheter, migrationshistorik, schemas, API-kontrakt, tester och CI. Kontrollera versionsberoende teknik mot officiell dokumentation. Skilj tillgänglig tjänst från planerad integration och fungerande test från ett dokumenterat kommando som ännu inte körts.

Inventeringen ska kunna besvara:

| Område | Beslut eller verifierad uppgift |
| --- | --- |
| Produkt | Målgrupp, huvudresa, marknader, språk och första leverans |
| Domän | Begrepp, livscykler, invariants och befintliga regelägare |
| Identitet | Användare, organisationer, integrationer, roller och delegering |
| Data | Källa, ägarskap, isolation, historik och känslighet |
| Teknik | Verkliga versioner, repos, driftkomponenter och kontrakt |
| Externa effekter | Betalning, mejl, meddelanden, datautbyte och kostnader |
| Verifiering | Befintliga kommandon, tillgängliga testmiljöer och luckor |
| Mandat | Uppdragets omfattning, faktiska åtkomster och begränsningar |

Spara stabila verifierade fakta med [kontextmallen](PROJECT_CONTEXT.template.md) när större arbete saknar motsvarande dokumentation. När mallar blir verkliga projektdokument ska exempel tas bort och relevanta länkar riktas mot projektets faktiska dokument och källor; behåll mallhänvisningar bara när de avser själva mallen. Okända fakta markeras som okända. Avgränsa frågor som faktiskt blockerar; fortsätt oberoende auktoriserat arbete.

## 3. Välj tillämplig omfattning

Läs [byggstandarden](ENGINEERING_STANDARD.md) i sin helhet vid projektstart eller större ombyggnad. Välj relevanta [projektprofiler](PROJECT_PROFILES.md). Skapa en liten områdesbedömning i befintliga produktkrav eller med [produktmallen](PRODUCT_REQUIREMENTS.template.md).

Varje berört område ska vara:

- **Tillämpligt:** behövs för produktens beslutade funktion, data eller risk.
- **Senarelagt:** ange vad som avstår, konsekvens, ägare och utlösande villkor för att genomföra det.
- **Inte tillämpligt:** ange kort varför.
- **Ej bedömt:** en synlig osäkerhet, inte ett dolt beslut att hoppa över området.

Tillämplighet och arbetsstatus är olika uppgifter. Ett krav kan vara tillämpligt och ännu inte implementerat. En produkt med verkliga känsliga data kan inte behandla nödvändig åtkomstkontroll som en framtida kosmetisk förbättring.

Inventera även stödflöden runt huvudfunktionen: konto, återställning, kontakt, hjälp, relevanta juridiska dokument, mallar och avslut. Ett internt verktyg behöver inte offentlig registrering eller betalning om produkten saknar sådana behov. Om endast nödvändig lagring används ska cookiehanteringen följa den faktiska bedömningen.

## 4. Gör genomförandet konkret

För större flöden dokumenteras i ett befintligt arbetsdokument eller [arbetsmallen](WORK_ITEM.template.md):

1. Aktör, ingång, målobjekt, förutsättningar och önskat observerbart resultat.
2. Regelägare, permission, tenant-/objekt-/fält-/tidsgränser.
3. Invariants, transaktionsgräns, samtidighet och tillåtna tillståndsövergångar.
4. Externa effekter, återförsök, osäkra utfall och återhämtning.
5. Krav-ID, risknivå och tillräcklig verifiering enligt [verifieringskontraktet](CI_INTEGRATION.md).
6. Kontrakts- och filansvar vid parallellt arbete samt vem som integrerar resultatet.

Välj få komponenter och tydliga domängränser. Om teknik ännu inte valts: föreslå och genomför ett rimligt val utifrån produkt och befintliga förutsättningar. Hårdkoda inte en leverantör bara för att den förekommer i en profil eller skill.

## 5. Bygg ett verifierbart första flöde

Bygg först en komplett, representativ användarresa genom klient, API, behörighet, databas och relevant bakgrundsarbete. Använd verkliga ingångar och avsedd testmiljö. Ett snyggt gränssnitt med mockade kritiska effekter ska beskrivas som en prototyp tills dessa vägar är implementerade och verifierade.

När mönstret fungerar används samma regelägare och kontrakt i nästa flöde. Rätta grundorsaker. Undvik nya parallella moduler för samma verksamhetsregel. Håll instruktioner, API-kontrakt och projektdokument synkroniserade med förändrade beslut.

## 6. Verifiera, integrera och fortsätt

- Utför riskbaserade kontroller och koppla relevanta återkommande kontroller till verklig CI. Rapportera blockerad miljöåtkomst som en avgränsad lucka.
- Granska den slutliga diffen efter samordning av delagenters arbete. Kör relevanta kontroller på den sammanförda versionen.
- Skriv checkpoints vid betydande beslut, fynd, implementeringssteg och verifiering. En oväntad kontextförlust ska inte kräva en ny gissning om vad som hände.
- Håll [projektstatusen](PROJECT_STATE.template.md) kort. Länka skyddad evidens där det behövs; kopiera inte stora råloggar eller hemligheter.
- Skilj implementerat, verifierat och driftsatt och ange kodläge/miljö. Avsluta när det avgränsade uppdraget är klart eller när ett faktiskt hinder kräver användarens medverkan; redovisa exakt vad som återstår.

## 7. Verifiera att arbetsminnet går att använda

Vid större överlämning: låt mottagande agent återge mål, verifierat läge, öppna risker och nästa handling från projektdokumenten. Kontrollera svaret mot arbetsytan. Rätta dokumentkartan eller checkpointen om återupptagningen kräver gissningar. Dokumentera inte interna resonemangstranskript.

En standard kan förbättra disciplin och spårbarhet. Projektets faktiska kod, testresultat och driftobservationer avgör om beteendet fungerar.
