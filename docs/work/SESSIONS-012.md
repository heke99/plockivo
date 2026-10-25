# SESSIONS-012 — spärr av egna befintliga inloggningar

2026-10-25. Administrativt självbetjäningsflöde i kontosäkerhet. Bekräftad POST `/api/sessions/revoke-all`, strikt JSON, samma-origin, no-store och verifierad personidentitet. Ingen klientstyrd user_id eller roll accepteras.

## Regelägare och effekt

RPC `revoke_my_sessions()` härleder användare/session från verifierad JWT. Nuvarande session måste vara levande i Auth och gällande MFA-policy uppfylld. RPC lägger endast samma användares befintliga session-ID:n i en privat revocation-tabell. `security_state`/`mfa_satisfied` nekar omedelbart dessa JWT:n även för inköpare utan frivillig MFA. Det kompletterar Supabase global signOut, eftersom redan utfärdade JWT annars kan leva till utgång. Gamla köp-, korg-, attest- och RLS-kontroller använder denna befintliga säkerhetsgräns.

Upprepad operation från samma spärrade session returnerar replay utan att spärra en senare ny login. Ingen medlemsrad, inköpsram, korg eller MFA-faktor ändras. Nya inloggningar efter snapshot får nytt session-ID och är tillåtna. Samtidiga nya inloggningar under provider-global-signOut kan också loggas ut av leverantören; UI lovar ingen sessionslista eller selektiv utloggning.

BFF committar verksamhetsspärren först och försöker sedan provider-global-signOut. Vid leverantörsfel rapporteras provider_revoked=false, medan SQL-spärren består. Lokala domänbundna Auth-kakor rensas efter beständig spärr. Klienten navigerar till ny inloggning och visar ingen kvarvarande företagsvy. Inga service_role-nycklar används.

Revocation-rader behålls utan automatisk tidsbaserad rensning tills tokenlivslängd/retention fastställts. De tas bort om användaren raderas via FK. Ingen ny MFA-förlust- eller supportbypass.

## Verifiering

Migration tillämpad med terminal success; serverversion `20261025224902_session_revocation.sql` bekräftad via list_migrations.

`tests/sessions.sql` terminal PASS på riktig authenticated-roll med rollback: två egna sessioner spärras, annan persons session påverkas inte, gammal optional-MFA-JWT nekas för get_context, replay spärrar inte en senare login, ny login tillåts, MFA-krav och direkt tabellskrivning nekas. Inga bestående testidentiteter skapas av sviten.

Webb typecheck och 20 integrerade unit-/kontraktstester PASS (fyra riktade sessionstester: mutationsordning, anonym/otillgänglig identitet, MFA-nekande, providerfel efter SQL-spärr). Enhetsproven använder isolerad klientstub och ersätter inte verklig Auth-leverantörseffekt. Integrerad runtime/browser och slutligt produktionsbygge körs av recovery11/huvudagenten. Global providerutloggning på två verkliga Auth-sessioner är inte separat verifierad i denna del; SQL-spärren är verkligt rolltestad.
