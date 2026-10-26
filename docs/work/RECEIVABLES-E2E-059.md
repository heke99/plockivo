# Verification054–059 — manual production receivables

## Release verdict
RED for unrestricted full production verification: actual Strato SMTP, portable email verification and authenticated physical-device browser checkout are not proven. The newly implemented manual receivables boundary is tested separately below. No actual funds transfer or invoice is initiated.

## Execution identity
Repositories heke99/plockivo and heke99/plockivo-web, main. Local API/web Next production builds plus hosted Supabase cqznytuyutrqenbbyczc. Database migration20261026205522_production_receivables. Source/deployment/CI identities recorded in final checkpoint below.

## Implemented domain
Only a current live verified full merchant administrator with AAL2 can record/reverse receipts for fully fulfilled production orders. Partial/full allocation releases exact order exposure, rejects an amount above remaining balance, and preserves immutable receipts/reversals. Corrections restore exposure even above a subsequently reduced credit limit. Project spending, physical inventory, original credit reservation and original order snapshot stay unchanged. No bank transfer, refund, invoice issuance, credit note or ERP payment status is asserted. References are trimmed exact case-sensitive values; one active allocation per tenant/reference. Reversal releases the active reference claim but preserves all historical entries.

## Quality gates and scenarios
| ID | Boundary | Result | Evidence |
|---|---|---|---|
| REC-001 | API standard/typecheck/unit/production build | PASS |50 unit tests |
| REC-002 | Web standard/typecheck/unit/production build | PASS |59 unit tests; webpack local build |
| REC-003 | Contract generation and API/web lock | PASS |matching generated artifacts; SHA256 ab440533adf9b8f2aa3269121d33a9294421a401df4480977f9d745bd640b539 |
| REC-004 | Hosted actual production checkout→fulfill→receipt/reversal | PASS |tests/production-receivables-simulation.sql, real authenticated roles |
| REC-005 | Replay, conflict, stale revision, overpayment, duplicate reference, repeated reversal | PASS |same hosted rollback simulation |
| REC-006 | Buyer/staff/foreign/AAL1/direct-table denials | PASS |same hosted rollback simulation |
| REC-007 | Immutable ledger, exact aggregate and cleanup assertions | PASS |30 cleanup categories all0 |
| REC-008 | Real Chromium153 rendered UI,390/768/1440 | PASS UI-ONLY |Auth/BFF intercepted; administration/fulfillment/JSON export/partial payment/reversal/cancellation, no pageerrors/overflow |
| REC-009 | Failed refresh freezes writes and preserves form draft | PASS UI-ONLY |same browser scenario, no POST until successful explicit readback |
| REC-010 | Real local Auth/TOTP→HTTP→API→PostgREST→DB, competing payments and closed-session denial | PASS CI |tests/http-production.mjs, disposable loopback Supabase only |
| REC-011 | Hosted Strato SMTP and authenticated full browser/device journey | NOT RUN |requires actual personal verified user session and delivery test |

## P0 accounting evidence
Order total30863öre. Partial10000 leaves20863. Full settlement leaves0. Reversing10000 restores10000 even when current limit is5000; reviewed limit restored afterward. Reusing the bank reference is permitted after explicit reversal, not while active. Three receipt entries and three separate reversals ultimately restore the original30863 exposure. Project committed30863 and stock8/reserved0/version5 remain unchanged. Existing cancellation branch remains separate with15431 release. History cannot be updated or deleted, including an attempted privileged update. The simulation then rolls back; all30 independently counted fixture categories are0.

## UI review/remediation
Independent review identified stale writable balances after failed reload and older active receipts omitted by the latest100 list. Failed reload now freezes writes while preserving drafts; successful refresh is required. Known receipt UUID can be entered explicitly when history is truncated, with server ownership/state validation and no amount override. Scoped single-column forms and reduced nested padding were visually verified in actual Chromium. Browser snapshots contain synthetic information only.

## Isolation and cleanup
Hosted tests use namespace54000000 and rollback. Local HTTP test refuses without explicit PLOCKIVO_LOCAL_HTTP_TEST=1 and validates a loopback-only Supabase status URL. It uses real ephemeral Auth signup and TOTP challenge; only the buyer business membership is seeded. Local email confirmation is deliberately disabled in the disposable local configuration; this is not a production email-delivery claim. Local TOTP enrollment/verification is enabled for that test; hosted Auth configuration is unchanged. Keys, tokens, random passwords and TOTP secrets are never printed. CI always stops the isolated stack without backup, removing local fixture/Auth data.

## Remaining limitations
No external bank integration, automated reconciliation, production credit-note/return flow or full invoice issuance is included. Latest100 receipts are listed, with explicit truncation and known-ID correction support. Browser UI proof uses mocked API responses; the real local HTTP integration is a separate boundary. Neither proves actual production SMTP delivery or a real phone camera. Full release remains RED until the untested P0 external/browser flow is completed.

## Actual CI outcome
API726a9dd3a263630175d980973ac63fcb13651a9f / Actions40401350268: quality PASS, clean database replay and all23 SQL suites PASS, actual Auth/TOTP/HTTP production flow PASS, disposable stack teardown PASS. HTTP check covers two concurrent same-key requests causing one payment effect, two competing full-balance requests producing one success and one version conflict, and a still-signed JWT denied by direct RPC after real Auth signout. Exact final DB exposure10000, project committed30863, stock8/reserved0 and one original order/reservation. Web8eca16a5f548f2c1d60ab8c58444e960544e0fe0 / Actions40401356778: quality PASS. Production deployment identities and public live-readback follow below.

## Deploy Result
- API production: dpl_5e3Gr1bfcKjN9t66qkP6eA1DHnAo, commit726a9dd3a263630175d980973ac63fcb13651a9f, READY.
- Web production: https://www.plockivo.com, dpl_3PBkFvbBAnTdBWeAqpSzBMiFfXFC, commit8eca16a5f548f2c1d60ab8c58444e960544e0fe0, READY.
- Framework: Next.js16.4.2; separate API/web repositories and projects.

### Post-Deploy Observability
Grouped error/fatal runtime-log queries for each new deployment returned no groups in the initial15-minute window. This short empty window is not proof of an exercised production business journey. Cloud browser verified the published integration overview version3 contains manual receivables, and navigation to /app renders the normal logged-out workspace at1363px without horizontal overflow. No production credentials entered. Monitoring/drain configuration was not changed or asserted. Final hosted namespace readback users0/merchants0/paymentreceipts0.

Documentation checkpoint only follows the tested/deployed runtime commits. Remaining unrestricted-release verdict stays RED solely where critical actual external/device/user-session verification is still not run; the new manual accounting subsystem has the SQL, local-HTTP and UI-only evidence above.
