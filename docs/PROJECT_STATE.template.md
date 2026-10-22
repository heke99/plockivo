# Projektstatus — mall

Mallversion: 3.0.0

Skapa `PROJECT_STATE.md` endast om en motsvarighet saknas. Håll den kort; länka detaljer till ett befintligt arbetsdokument. Detta är aktuell status, inte en full historik. Följ [byggstandarden](ENGINEERING_STANDARD.md); stabila fakta hör hemma i [projektkontexten](PROJECT_CONTEXT.template.md).

## Aktuell checkpoint

- Uppdaterad och ansvarig: [datum/tid med tidszon; namn eller agent].
- Aktivt mål och avgränsning: [fyll i].
- Aktivt arbetsdokument och relevanta krav-/besluts-ID:n: [fyll i].
- Repo, branch, commit och arbetskatalog: [fyll i].
- Ocommittade/halvfärdiga ändringar och deras ägare: [fyll i].
- Berörd miljö och hur den identifierats: [fyll i].
- Riskklass, motivering och relevant verifiering: [fyll i enligt projektets riskmodell].

## Observerat läge

Arbetsstatus: `ej bedömt`, `planerat`, `pågår`, `implementerat`, `verifierat`, `blockerat` eller `inte tillämpligt`. `Verifierat` kräver evidens. Driftstatus anges separat som `ej driftsatt`, `driftsatt`, `okänt` eller `inte tillämpligt` och gäller en namngiven miljö.

| Krav eller arbetsdel | Arbetsstatus | Verifierat resultat och evidens | Driftstatus och miljö |
| --- | --- | --- | --- |
| [ID och kort namn] | [fyll i] | [källa, testat kodläge, miljö; annars ej verifierat] | [fyll i] |

- Senast körda relevanta kontroller: [exakta kommandon, utfall och evidensreferens].
- Verifiering efter sammanförda agentändringar: [testat samlat kodläge och utfall, ej utfört eller ej tillämpligt med skäl].
- Tillämplighet/uppskjutet: [referens; ange konsekvens för varje senarelagt relevant krav].

## Kvarstående frågor och osäkra utfall

| Fynd eller blockerare | Konsekvens och ansvarig | Nästa kontroll eller beslut |
| --- | --- | --- |
| [fyll i eller inga kända inom uppdraget] | [fyll i] | [fyll i] |

- Externa operationer med okänt utfall: [säker referens och kontroll före omkörning; eller inga kända].
- Relevant mandat eller åtkomst som behöver återkontrolleras: [referens; skapa inga nya rättigheter].

## Fortsätt här

1. Kontrollera [exakt fil/diff/miljö/extern status] mot checkpointen.
2. Genomför [nästa konkreta handling och förväntat resultat].
3. Verifiera med [verkligt kommando eller observerbar kontroll].

Vid återupptagning: kontrollera verklig arbetsyta och miljö innan statusen används. Se [arbetsmallen](WORK_ITEM.template.md) för detaljer och [beslutsmallen](DECISIONS.template.md) för bestående beslut.
