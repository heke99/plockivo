# Identitet och drift — utvecklingsbaseline

## Sessionskontrakt

Supabase Auth, stabil auth.users.id. Inloggning sker med personligt lösenord. Webbens server använder @supabase/ssr med host-only HttpOnly, SameSite=Lax och Secure i produktion. Inga tokens eller service keys exponeras till webbens JavaScript. BFF transporterar endast sessionens token utan eget affärsbeslut. API verifierar token med getUser före varje verksamhetsanrop; databasoperationerna använder auth.uid och aktuella giltiga medlemskap. Skrivande webbvägar kräver rätt Origin. När Origin saknas används betrodd samma-origin Fetch Metadata eller en explicit icke-enkel JSON-header, utan cross-origin CORS, tillsammans med konfigurerad origin. Främmande och null Origin nekas alltid. Utloggning avser aktuell enhet; lösenordsåterställning avslutar samtliga sessioner. Endast konfigurerad callbackadress används för återställning.

Återställning är implementerad via Supabases PKCE-flöde men inte leveransverifierad med e-post. MFA, faktorbyte, inbjudan, verifierat första företagsmandat och säkert administratörsbyte är ej färdiga. Därför exponeras inga kredit-, ekonomi- eller plattformsadminmutationer. Aktuellt återkallat medlemskap stoppar nya verksamhetshandlingar även med giltig token. JWT-återkallelse efter global logout är inte samma sak som omedelbar åtkomsttokeninvalidering; känslig sessionskontroll före pilot återstår.

## Dataflöden och lagring

| Data | Källa och syfte | Åtkomst och kvarstående beslut |
| --- | --- | --- |
| Identitet/session | Supabase Auth, personlig inloggning | Host-only session. Retention och återkallelsepolicy ska fastställas. |
| Medlemskap | Verifierat mandat från handlare | SQL kontrollerar aktuell status, giltighet, konto, butik och projekt. Provisioneringsgränssnitt återstår. |
| Testköp | Syntetisk katalog och prisadapter | Testtenant, person, kundkonto och objektbaserad läsrätt. Inga verkliga varor/fakturor. |
| Audit/outbox | Affärstransaktion | Private-schema utan appskrivrätt. Retention och ansvarig operatör före pilot. |
| Dokument | Låst ordersnapshot | JSON-bevis i RLS-tabell. PDF och privat objektlagring återstår. |

Ingen extern spårning används. Service worker lagrar inga affärssvar, dokument eller kreditbesked och gör ingen offlineutcheckning. Den tvingar ingen uppdatering under pågående köp. APP_ORIGIN/API_URL är betrodd konfiguration. Per-handlardomän, verifierad domänbindning, manifest och profil ska byggas före white label-pilot.

Plattformsbolag/personuppgiftsansvarig, avtal, laglig grund, gallring, rättighetsärenden och faktisk supportkontakt är öppna uppgifter, inte färdiga juridiska villkor. Inga påhittade avtalstider eller garantier har publicerats.

## Jobb och integrationer

POST confirm committar outbox före svar. `/internal/outbox` kräver CRON_SECRET och worker key; cron hittar högst 20 köade testjobb och startar Workflows med endast jobb-ID. Databasens worker låser jobbet, skapar högst ett JSON-dokument och avslutar i samma transaktion. Dubbla Workflow-starter kan inte skapa dubbla dokument. Notification går till manual_review eftersom ingen leverantör finns; den markeras aldrig skickad. unknown/manuell handläggning återköas inte automatiskt. Verkliga effekter behöver senare inbox, provider-idempotens, avstämning och claim/fencing innan de får aktiveras.

Worker-miljö saknar secret key i denna körning: Workflow-SDK:t bygger men verklig Workflow-exekvering är inte verifierad. Regionsönskemål arn1 i Vercel-konfig är inte ett bevis på Workflows lagringsregion. Kontovillkor, retention och körregion måste kontrolleras vid provisionering.

## Före pilot

Masterplanens kapitel 38 är den fullständiga startkontrollen. Verkliga köp ska förbli avstängda tills ERP-pris/kredit, inventerad exponering, utlämning och mängdanspråk, fakturering/retur, MFA, juridik, telefonprov, backup, incidentövning och relevant E2E är verifierade. Återställning får inte återaktivera tidigare spärrar eller engångsbevis. Ingen återställningsövning är genomförd här.
