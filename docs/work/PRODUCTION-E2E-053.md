# Production completion and verification — 2026-10-26

## Release verdict

RED for an unrestricted, fully verified production release. The standalone database business flow is verified; the actual signup → SMTP delivery → email verification → MFA → browser checkout chain has not been run. This is an evidence limitation, not a feature gate. No permanent test account or real order was created.

## Execution identity

Repositories: heke99/plockivo and heke99/plockivo-web, main. Environment: local code checks plus hosted Supabase cqznytuyutrqenbbyczc. Production website: www.plockivo.com. Exact source commits and deployment IDs are recorded after publication below.

## Implemented behavior

Explicit production configuration; customer-specific catalog publication and prices; absolute inventory adjustments; stores/projects; atomic credit/project/stock reservations; separate approval; purchase confirmation; full-order fulfillment or cancellation before fulfillment; immutable billing snapshot for manual JSON/CSV export. Personal registration checks current provider email-confirmation policy. Verified people with current MFA can bootstrap an isolated merchant; explicit scoped delegation permits customer invitations. Staff queue is scoped and bounded to latest50 with has_more.

Production source selection searches the whole preparation register with 50-row pages and preserves the selected source version. Preparation edits do not automatically change published prices or unpublish a product. Product unit/quantity_step cannot be reinterpreted after mapping.

## Quality gates

| Gate | Result | Evidence |
|---|---|---|
| API standard/typecheck/unit/build | PASS | 48 tests, Next production build |
| Web standard/typecheck/unit | PASS | 58 tests, contract lock |
| Web production build | PASS | next build --webpack; local Turbopack persistence database failed independently of code |
| Contract generation/copy | PASS | generated API/web types equal; SHA-256 locked |
| Hosted migration installation | PASS | 15 migrations after customer_policy; staged foundation and protective live-session prerequisite |
| Hosted production business simulation | PASS | tests/production-flow-simulation.sql; real authenticated roles, rollback, 26 cleanup zeros |
| Hosted merchant bootstrap | PASS | tests/merchant-bootstrap.sql |
| Hosted invitation setup | PASS | tests/customer-invitation-setup.sql |
| Hosted synthetic checkout regression | PASS | tests/catalog-test-purchase.sql; 20 cleanup zeros |
| Hosted session boundary regression | PASS | tests/live-session-authorization.sql, users_left0/merchants_left0 |
| Security advisor | PASS with INFO | 37 RLS/no-policy informational findings, intentionally no direct table access; no warning/error finding |
| Authenticated browser flow/mobile | NOT RUN | no authenticated test identity; local Chromium missing |
| Live SMTP/provider delivery | NOT RUN | templates configured by user; actual delivery not evidenced |
| True simultaneous checkout sessions | NOT RUN | lock ordering reviewed; sequential stale/oversell/replay cases verified |

## Scenario summary and P0 evidence

| ID | Priority | Flow | Result |
|---|---|---|---|
| PROD-001 | P0 | policy/setup/source/publication/stock/cart/approval/confirm | PASS in hosted SQL |
| PROD-002 | P0 | buyer receipt, staff full fulfillment, billing readback | PASS in hosted SQL |
| PROD-003 | P0 | separate order cancellation and exact reservation release | PASS in hosted SQL |
| PROD-004 | P0 | stale/version/approval/credit/stock/config/tenant/MFA denials, repeat request | PASS in hosted SQL |
| PROD-005 | P0 | verified owner isolated merchant bootstrap/replay/invalid authority | PASS in hosted SQL |
| PROD-006 | P0 | account-scoped invitation setup, source revocation, no credit mutation | PASS in hosted SQL |
| PROD-007 | P0 | optional-MFA buyer: live session allowed; expired/missing/banned/unverified denied | PASS in hosted SQL |
| PROD-008 | P1 | staff queue state/readback, buyer denied queue | PASS in hosted SQL |
| PROD-009 | P0 | actual registration, SMTP, portable verification, MFA, checkout in browser | NOT RUN |

PROD001–004: authenticated buyer creates a real production quote with separate approver. Two-unit order totals30863öre; a second one-unit order totals15431öre. One order fulfilled and the second cancelled. Final stock8/reserved0/version5; active exposure and project committed30863öre. Original immutable reservations46294öre less release marker15431öre equal30863öre. Exactly two purchase audits, one fulfillment and one cancellation, synchronous documents, notification outbox manual_review. Replay has no duplicate effects. All fixture data rolls back; 26 independently counted categories are zero.

## Failure and remediation

Automatic review rejected the initial foundation installation while a known direct-RPC live-session gap existed. Fixed centrally: private.live_person now checks banned_until; private.allowed requires a verified existing non-expired Auth session before existing MFA and mandate checks. Regression under real authenticated role passes, including existing prepare_purchase rejecting expired session. The protective migration was installed and tested before financial authority migration retry. Several connector calls returned Invalid or expired requestState; authoritative migration readback was checked, and the foundation was installed in smaller stages with all new helpers revoked before commit and public entrypoints granted last. No rejected action was bypassed.

## External integrations and limitations

Manual credit decisions and manual accounting export are the selected standalone authorities. No external invoice, accounting entry, email delivery, ERP synchronization or Creditsafe result is claimed. Fulfillment is full-order only; no production partial fulfillment or return implementation is asserted. No live external side effects were generated by simulations. No saved template or unit test is treated as proof that an email reached its recipient.

## Cleanup and remaining blockers

No permanent identity was created. Isolated hosted tests use rollback. Remaining P0 evidence requires an actual verified user session and a real email delivery test. Public live-page checks and deployment readback are recorded after publication; these do not substitute for authenticated checkout or physical device/camera verification.
