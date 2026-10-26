# STANDALONE-CUSTOMERS-025 — kundkonton utan externt ERP

2026-10-26. Första fristående kundadministrationen: full merchant_admin med aktuell MFA och customers.manage kan lista högst 200 handlarbundna kundkonton och skapa ett nytt konto. Namn och svenskt organisationsnummer har format-/kontrollsiffervalidering. Det är INTE kontroll av registrering, bolagsform, firmatecknare eller kreditvärdighet. DTO markerar verification_status=unverified; ingen tidigare extern verifiering finns i denna modell.

Nya konton är alltid suspended, purchase_blocked=true, credit_limit_minor=0, exposure_minor=0 och terms_version=null. Operationen skapar inga personkonton, medlemskap, projekt eller inbjudningar. Inga uppdaterings-/aktiverings-/kreditvägar införs. Verkliga köp förblir spärrade.

Tenant härleds mot aktuell verifierad administratörsidentitet, inte ett godtaget tenant_id. SQL kontrollerar separat scoped admin/MFA. Listan är begränsad till rätt handlare. Skapande serialiseras per handlare med advisory transaction lock; normaliserat organisationsnummer förhindrar dubblett även mot gamla formaterade nummer. Audit, kundkonto och idempotensresultat sparas atomiskt. Samma nyckel/body ger samma resultat utan extra audit; annan body med samma nyckel nekas.

Migration 20261026010357_standalone_customer_administration.sql tillämpad, serverhistorik synkad. tests/standalone-customers.sql körd med riktig authenticated-roll och terminal PASS: suspended/default blocked/zero credit/no mandate, replay, duplicate/extra-field/key-conflict denial, tenant/buyer/anon denial, exactly one audit. Alla fixtures rollback. Två TS transporttester PASS. API-typkontroll körd separat. Ingen verklig kundregistrering eller kreditupplysning gjordes.

API-ägaren integrerar GET /merchant-customers?tenant_id samt POST /merchant-customers med customerCreateInput, Idempotency-Key och gate STANDALONE_CUSTOMERS_ENABLED=false tills samlad aktivering. RPC public.list_merchant_customers(p_tenant), public.create_merchant_customer(p_body,p_key,p_correlation). CUSTOMER_EXISTS bör returneras som409. Ingen publicering av denna delagent.
