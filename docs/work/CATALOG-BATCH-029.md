# CATALOG-BATCH-029 — Begränsad import av nya artiklar

`catalogBatchInput` tar strikt `{tenant_id,items}` med 1–10 nya artiklar. Varje artikel innehåller samma verksamhetsfält som `standaloneCatalogInput`, men utan tenant_id/id/version. Alla rader och parentnyckeln valideras före första mutation. Runnern sätter samma tenant_id på alla rader samt id:null/version:0.

`runCatalogBatch(raw,parentKey,save)` anropar `save(body,rowKey)` sekventiellt. Save ska använda den befintliga autentiserade användarens db.rpc('save_standalone_catalog', {p_body:body,p_key:rowKey,p_correlation:correlation}) och returnera `{data,error}`. Behåll befintlig feature gate, getUser, current MFA/SQL-permissions, JSON-gräns och validerad Idempotency-Key före runnern. Ingen service-role eller klientbestämd actor.

RowKey är catalog-batch: + SHA256(parentKey + ':' + ettbaserat index). Returnerat resultat innehåller status completed/stopped, atomic:false, saved:[{index,data}], failure:null eller {index,code,message,outcome}, remaining. Index är ettbaserat, remaining räknar efterföljande orörda rader (felraden redovisas separat). Detta är separata radtransaktioner och får inte presenteras som atomisk import. Stoppar på första nekade/okända utfall; tidigare rader kan vara sparade.

Vid återförsök ska hela oförändrade batchen skickas med samma parentnyckel. SQL replayar tidigare radresultat och upptäcker ändrat innehåll. Skapa inte ny nyckel automatiskt efter timeout och ta inte bort redan sparade rader före retry: då skulle index byta betydelse. Unknown response/null/exception behandlas som okänt utfall, inga råa fel returneras. Godkända SQL-felkoder matchas exakt och har fasta svenska meddelanden.

Riktade Node-tester: 5 PASS. Validering före effekter; låsta nyfält/tenant; stopp vid dubblett/idempotens/behörighetsfel; sanitiserade fel; commit följt av timeout och lyckad samma-nyckel-replay. Inga DB-mutationer, routes, kontrakt, builds eller publicering gjorda av delagenten.
