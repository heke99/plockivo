# Artikelimport via API

POST /v1/standalone-catalog/import, JSON, Authorization: Bearer <personlig aktuell AAL2-session>, Idempotency-Key: unik-sträng-16-till-128-tecken. Tillåtna nyckeltecken A-Z a-z 0-9 : _ -. Driftmiljöns Vercel-skydd gäller separat; kopiera inte skyddsnycklar till klientkod. Obemannad service-/maskinidentitet är inte provisionerad. Använd aldrig service_role för att kringgå personmandatet.

```json
{"tenant_id":"00000000-0000-4000-8000-000000000001","items":[{"sku":"SKU-001","name":"Montageskruv","unit":"fp","quantity_step":"1","barcode":"735000000001","package_quantity":"1","unit_price_minor":"12990","vat_bps":2500,"active":true,"self_scan":false}]}
```

1–10 artiklar per anrop. Tenant härleds inte som behörighet från body utan kontrolleras i SQL med verifierad identitet, aktivt mandat och MFA. Ny artikel har alltid id:null/version:0; dessa fält får inte skickas i items. Varje rad konsumerar API-kvot och använder samma befintliga audit/idempotens/unikhetsregler som manuell artikelhantering. Max body32 KiB.

200: data.status completed. 207: data.status stopped; saved anger redan sparade eller återspelade rader, failure anger första obekräftade/nekade rad (index1-baserat), remaining anger aldrig påbörjade rader efter felet. atomic:false: ingen gemensam batchtransaktion. Okänt utfall betyder att raden kan ha sparats.

Återförsök skickar HELA OFÖRÄNDRADE batchen med URSPRUNGLIG nyckel och radordning. Ändra inte innehåll eller flytta rader under samma import. Skapa inte automatiskt ny nyckel efter timeout. Om en tidigare sparad rad ändras ger den SQL-idempotenskonflikt. Reconciliation krävs innan man startar en korrigerad import. API:t genererar ingen bakgrundsimport eller extern webhook.

För mer än tio artiklar: skapa separata stabila batch-ID:n, lagra varje begäran och dess radstatus i integrationssystemet, invänta bekräftat utfall och fortsätt först därefter. Vid429 vänta och återanvänd originalnyckeln. Vid401/403 återställ behörig personlig session/MFA; kringgå inte spärren.

Singeluppdateringar: POST /v1/standalone-catalog med aktuellt id/version. Ingen automatisk matchning efter SKU. Detta register är preparation-authority, inte produktionscheckout, kreditauktoritet eller lagerbokföring.
