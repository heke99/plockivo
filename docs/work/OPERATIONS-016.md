# OPERATIONS-016 — dokument- och notifieringsstatus

Full merchant_admin-scope, aktuell MFA och operations.read krävs. GET merchant-jobs lämnar de senaste 100 radernas jobb-ID, order-ID, typ, status, försök och skaptid. Claim-token, innehåll och payload lämnas aldrig ut. Statusen succeeded betyder inte mottagarleverans. Notification/manual_review markeras delivery_not_configured, unknown och utgången claim kräver manuell kontroll.

Ingen retryfunktion exponeras: befintlig worker saknar verifierad klassificering av säkert retrybara externa fel. Inga okända utfall eller notifieringar skickas om. Endast läsning byggd, med uppdateringsknapp och tydliga states i UI.

Migration server 20261025231202 tillämpad, filnamn synkat. SQL tests/operational-jobs.sql terminal PASS 2026-10-26: real authenticated admin gets two queued jobs, safe field whitelist, cross tenant/buyer/anonymous denial, direct write denial, manual-review reason. Transaction rollback; inga persistenta fixtures eller utskick. Parent äger final integration/build/browser/publicering.

Final integrated browser tests/e2e/merchant-jobs.cjs PASS on fresh port3537: manual-review status/reason, no resend button, provider error clears stale job display, 390/768/1440 widths without overflow and no pageerrors. This is intercepted API UI-only evidence, separate from real SQL role proof. Earlier stale build lacked component; final rebuilt source passed.
