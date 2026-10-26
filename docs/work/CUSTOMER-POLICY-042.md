# CUSTOMER-POLICY-042 — Manuellt kundbeslut i produktion och test

## Levererat kontrakt

`public.get_customer_policy(p_tenant uuid,p_account uuid)` returnerar `{id,tenant_id,name,status,purchase_blocked,credit_limit_minor:string,exposure_minor:string,terms_version:string|null,policy_version:number,review_status:"pending"|"reviewed",reason:string,evidence_reference:string,decision_authority:"merchant-manual"}`. Utan sidecar används policy_version0, review_status pending, tom reason/evidence_reference. Befintligt kundkonto ändras inte vid läsning. Name kommer från kundkontot, inte klienten.

`public.save_customer_policy(p_body jsonb,p_key text,p_correlation uuid)` tar strikt `{tenant_id,customer_account_id,version,status,purchase_blocked,credit_limit_minor,terms_version,review_status,reason,evidence_reference}`. API använder `customerPolicyInput` med exakt samma fält. Version är heltal0..2147483646. Pengar är exakta icke-negativa heltalsöressträngar högst999999999999. Tillåtna status pending/active/suspended; review pending/reviewed. Aktivering kräver reviewed och terms_version. Positiv kreditram kräver reviewed. Granskning aktiverar inte automatiskt och ändrar inte köpblockeringen om det inte uttryckligen valts i samma begäran. Zero credit/active/blocked är tillåtet, eftersom köpauktoriteten ligger kvar i befintlig prepare/confirm.

## Auktoritet och integritet

Aktuell MFA + befintlig customers_authorized, som kräver profile_authorized och customers.manage. Ingen merchant.mode-spärr: handlarens uttryckliga manuella beslut är tillgängligt för både production och test. reviewed är ingen extern register-/kreditverifiering. Behörighet är oförändrad merchant_admin, inga nya roller eller JWT-metadata används.

Kundkontot låses FOR UPDATE före versionkontroll och skrivning, vilket serialiserar med befintlig köpbekräftelse. Kreditram, köpblockering, status och terms_version skrivs på kontot, beslutsskäl/referens/version på privat sidecar. Exposure, reservationer, projekt och order berörs aldrig. Minskning under befintlig exponering är uttryckligen tillåten; nästa köp prövas mot den nya lägre ramen av befintliga regler.

Idempotens serialiseras per actor/tenant/key med advisory lock, konto låses och aktuell auth krävs även vid replay. Samma fullständiga body och nyckel returnerar tidigare DTO före versionkontroll; ändrad body => IDEMPOTENCY_CONFLICT. Ny nyckel med fel version => VERSION_CONFLICT. Vid framgång ökar sidecarversionen en gång samt audit + private.commands operation customer.policy.save skrivs i samma transaktion. Sidecar är tenant-FK till kundkonto, RLS-aktiverad och utan direkta auth-rättigheter. Definer ligger privat med tom search_path, public invoker wrappers, execute bara authenticated.

## Verifiering och status

Migration skapad med Supabase CLI migration new: `20261026184104_customer_policy.sql`. Tre inputtester PASS: exakta pengar, aktiv/review/terms-koppling, injicerade authorityfält nekas och ingen automatisk aktivering/blockupphävning. Hosted migration, riktig SQL-rollmatris och route/UI integration ägs av huvudagent/verifieringsagent. Ingen apply, build eller publicering gjord av denna delagent.

Parent2026-10-26: migration tillämpad som20261026184104. Hosted043 productionkundaktivering/kredit/terms/replay/version/tenant/roll/MFA/reservationer PASS,15cleanupnollor. API38 tester och båda byggen PASS; webb52 tester. Inga riktiga kundbeslut eller bulkaktivering utförda.
