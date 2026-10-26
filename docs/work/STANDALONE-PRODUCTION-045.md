# STANDALONE-PRODUCTION-045 — Explicit fristående produktion

## Auktoriteter och aktivering

`productionSetupInput` kräver tenant_id, version, de fasta auktoriteterna price_authority plockivo, credit_authority merchant-manual, inventory_authority plockivo, billing_authority manual-export, samt uttryckliga activate_production/sales_enabled booleans och reason10..1000/evidence_reference1..200. Inga externa kreditbeslut eller automatiska fakturor utlovas.

`save_production_setup(p_body,p_key,p_correlation)` låser handlaren FOR UPDATE och kontrollerar aktuell admin-MFA. Första övergången till production kräver activate_production=true och avsaknad av tidigare testköpunderlag/order, kundexponering och kreditreservationer. Inget tidigare ekonomiflöde konverteras. Mode växlas aldrig tillbaka till test. sales_paused blir enbart motsatsen till det uttryckliga sales_enabled. Butiker öppnas separat. Setupversion börjar1 och ökar vid varje lyckad ny begäran; frysta offerter måste bära/checka denna version. Senare setupändring på befintlig production kräver ingen ny modeövergång.

## Privata register

production_setups: tenant_id PK, version, auktoriteterna, reason, evidence_reference, updated_at.
production_catalog_map: source_item_id PK FK registerkälla, tenant_id, product_id FK handlarprodukt, source_version; unik tenant/product.
production_prices: PK tenant_id/customer_account_id/product_id, unit_price_minor bigint, vat_bps, revision.
production_stock: PK tenant_id/store_id/product_id, on_hand/reserved numeric20,6, version; on_hand>=reserved>=0.
production_stock_adjustments: separat ledger med actor, före/efter on_hand, bevarad reserved, stockversion, skäl, referens och correlation.
production_store_versions och production_project_versions: tenantbundna FK-sidecars med version för befintliga publika butiker/projekt.

Alla nya tabeller har RLS och saknar direkta authenticated-grants. Privata funktioner har tom search_path; public wrappers är invoker. Endast specifika wrappers/private domänentrypoints är execute-granted authenticated. Generiska validation/replay/recordhelpers är aldrig exponerade till caller. Befintlig profile_authorized kräver aktuell handlaradmin och merchants.profile.manage, tillsammans med assert_mfa.

## RPC-kontrakt

GET `get_production_setup(p_tenant)` -> tenant_id, mode, sales_paused, setup:null|{version,authorities,reason,evidence_reference,...}, accounts, stores, projects, products, prices, stock, limits, truncated. Alla listor är högst200 med explicita begränsningar och perlista truncated-bool. Accounts innehåller bara active, unblocked, termsnonnull. Stores/projekt har version0 utan sidecar. Penning-/mängdfält är strängar.

Alla mutationer har SQL-signaturen `(p_body jsonb,p_key text,p_correlation uuid)` och returnerar beständigt replaybart resultat. Idempotens serialiseras per handlaren under production-admin-advisory lock efter nödvändiga merchant/account/setup-lås. Samma fulla body+actor+tenant+key ger tidigare resultat utan nya effekter, även om aktuell version gått vidare. Aktuell MFA, behörighet och produktionskonfiguration kontrolleras fortfarande.

- publish_production_catalog: body tenant_id,item_id,source_version,customer_account_id,version (förväntad kundprisrevision0nytt). Aktiv självskanningskälla måste ha exakt version; kundkonto active/unblocked/termsnonnull; modeproduction+setup. Ny källa skapar en ägd handlarprodukt. Samma mapping kan användas för fler kundkonton. Pris upsert revision+1, exakta ören. Källans metadata-/streckkodsändring bump:ar även andra kunders prisrevisioner för att invalidera gamla offerter. Enhet och mängdsteg får inte bytas för en redan publicerad produkt, eftersom befintliga lagermängder och historik annars kan omtolkas. SKU-/streckkodskollision med någon annans produkt ger CATALOG_DUPLICATE; inga testpriser eller oägda produkter skrivs över. Resultat product_id,customer_account_id,source_item_id,source_version,mode production,unit_price_minor,vat_bps,revision.
- adjust_production_stock: body tenant_id,store_id,product_id,version,on_hand (absolut icke-negativ decimalsträng max12+6 siffror),reason,evidence_reference. Förevisad version ska matcha, reserved bevaras, under-reserverad nivå nekas QUANTITY_CONFLICT. Stockversion och justeringsledger ökar en gång. Resultat tenant/store/product,on_hand,reserved,version. Checkout/utlämning måste också öka stockversion när reservation/fysiskt lager ändras.
- save_production_store: body tenant_id,id:null|uuid,version,name,code,sales_paused. Nytt id:null kräver version0. Befintlig handlarbutik med sidecar0 får uppdateras med0. Nyttresultat id,tenant,name,code,sales_paused,version. Ingen automatisk öppning.
- save_production_project: body tenant_id,id:null|uuid,version,customer_account_id,name,budget_minor,active. Konto låses före projektet; account kan inte flyttas på befintligt projekt. committed_minor ändras aldrig. Budget under committed tillåts och stoppar nya köp via checkout. Resultat id,tenant,account,name,budget_minor,committed_minor,active,version.

## Lås och verifiering

Setup: merchant UPDATE, därefter ingen account/project. Publicering: merchant SHARE, account UPDATE, setup SHARE, production-admin-advisory, register-advisory, source SHARE, product UPDATE, price UPDATE. Stock: merchant SHARE, setup SHARE, store SHARE, advisory, product SHARE, stock UPDATE; ingen account/project efter produktlåset. Projekt: merchant SHARE, account UPDATE, setup SHARE, advisory, project UPDATE. Butik: merchant SHARE, setup SHARE, store UPDATE, advisory. Produktmetadataändring kan inte gå förbi checkouts delade produktlås. Förändringar av stock och kredit ligger i framtida checkout/utlämningsdomäner; dessa foundations skapar inga order eller fakturor.

Migration CLI-genererad standalone_production_* (nine staged migrations). Fyra inputtester PASS. SQL-simulering, hosted apply, full build och publicering ägs av huvudagenten. Ingen riktig handlare, användare eller ekonomisk effekt har skapats av delagenten.

Butikslås tas före det gemensamma admin-advisorylåset även för lagerjustering. Annars kan store-update vänta på en checkouts store-SHARE medan checkout väntar på ett kontolås från en publicering som väntar på advisorylåset. Inga radlås på befintliga butiker tas efter det gemensamma advisorylåset.
