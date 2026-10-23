# Identitet och drift — utvecklingsbaseline

## Sessionskontrakt

Supabase Auth, stabil auth.users.id. Inloggning sker med personligt lösenord. Webbens server använder @supabase/ssr med host-only HttpOnly, SameSite=Lax och Secure i produktion. Inga tokens eller service keys exponeras till webbens JavaScript. BFF transporterar endast sessionens token utan eget affärsbeslut. API verifierar token med getUser före varje verksamhetsanrop; databasoperationerna använder auth.uid och aktuella giltiga medlemskap. Skrivande webbvägar kräver rätt Origin. När Origin saknas används betrodd samma-origin Fetch Metadata eller en explicit icke-enkel JSON-header, utan cross-origin CORS, tillsammans med konfigurerad origin. Främmande och null Origin nekas alltid. Utloggning avser aktuell enhet; lösenordsåterställning avslutar samtliga sessioner. Endast konfigurerad callbackadress används för återställning.

Återställning är implementerad via Supabases PKCE-flöde men inte leveransverifierad med e-post. TOTP-aktivering, MFA-inloggning och faktorbyte finns i MFA-005. Inbjudan, verifierat första företagsmandat, återställning av förlorad MFA och säkert administratörsbyte är ej färdiga. Därför exponeras inga kredit-, ekonomi- eller plattformsadminmutationer. Aktuellt återkallat medlemskap stoppar nya verksamhetshandlingar även med giltig token. JWT-återkallelse efter global logout är inte samma sak som omedelbar åtkomsttokeninvalidering; känslig sessionskontroll före pilot återstår.

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

POST confirm committar outbox före svar. `/internal/outbox` kräver CRON_SECRET och worker key; Cron var femte minut hittar högst 20 köade testjobb och startar Workflows med endast jobb-ID. Databasens worker låser jobbet, skapar högst ett JSON-dokument och avslutar i samma transaktion. Dubbla Workflow-starter kan inte skapa dubbla dokument. Notification går till manual_review eftersom ingen leverantör finns; den markeras aldrig skickad. unknown/manuell handläggning återköas inte automatiskt. Verkliga effekter behöver senare inbox, provider-idempotens, avstämning och claim/fencing innan de får aktiveras.

Worker-nyckel och CRON_SECRET finns endast server-side i API-projektet. WORKER-004 verifierar verklig Workflow-start, schemaläggning, bestående backlog genom deployment och idempotens vid parallella starter. Workflow-stegen observerades i arn1; någon generell regional garanti för alla API-anrop påstås inte. Kontovillkor och retention ska fastställas före pilot.

## Före pilot

Masterplanens kapitel 38 är den fullständiga startkontrollen. Verkliga köp ska förbli avstängda tills ERP-pris/kredit, inventerad exponering, utlämning och mängdanspråk, fakturering/retur, MFA, juridik, telefonprov, backup, incidentövning och relevant E2E är verifierade. Återställning får inte återaktivera tidigare spärrar eller engångsbevis. Ingen återställningsövning är genomförd här.

## Driftsatt testmiljö

Se [DEPLOY-003](work/DEPLOY-003.md) för projekt, kodcommits, deployments, verifiering och städning. Webbens server använder en dedikerad API-automationhemlighet för Vercels skydd; person-JWT och mandatkontroll kvarstår. Trusted Sources-konfiguration svarade 404. Detta är en testkoppling, ingen öppning av API för anonyma verksamhetsanrop.

## MFA-kontrakt — MFA-005

Supabase Auth TOTP är den valda andra faktorn. SQL kräver MFA för aktiva merchant_admin-mandat och reserverade framtida roller platform_admin/support/credit_manager/finance. Inga nya administrativa permissions införs. Kundadministratörens pilotpolicy är öppen; vanliga köpare kan aktivera MFA frivilligt. Efter aktivering krävs aal2 samt en aktuell aal2-session för samma person och fortfarande verifierad faktor. Återkallat medlemskap kontrolleras separat. Ett administrativt mandat hos en handlare gör MFA obligatoriskt för personkontot även hos andra handlare.

Säkerhetsstatus går att läsa före MFA med public.get_security_state(), men lämnar bara required/enrolled/level/satisfied för den verifierade personen. Affärs-RPC och direkt RLS-åtkomst spärras utan tillräcklig MFA. Webbens /api/mfa har GET för egen status och POST enroll/verify/cancel/remove, strikt JSON, CSRF och no-store. Ny ytterligare app kräver aktuell kod från en verifierad app. Remove kräver kod från en annan verifierad app och följs av tokenrefresh. Leverantörens egna kontofunktioner är inte ersatta; obligatoriska roller förblir spärrade om faktorer tas bort där.

Setupnyckeln visas endast under påbörjad aktivering och sparas inte av Plockivo. Auth-leverantören äger faktorhemligheten och autentiseringsaudit. Verifierat första MFA-tillfälle återkallar andra sessioner enligt leverantörens beteende. Säkerhetsnotiser och verifierat ärendeflöde vid förlorad MFA återstår. Lösenordsåterställning eller enbart befintlig session får inte hoppa över MFA.
