# TASK054 — manual production receivable reconciliation

## Scope and authority

Adds internal payment allocations for fulfilled production orders only. This records an administrator's manual reconciliation against cited evidence. It does not contact a bank, transfer funds, issue invoices/credit notes or confirm that evidence exists externally. No return/credit-note subsystem is inferred from these receipts.

New permission `production.receivables.manage` is assigned only to merchant_admin. Reads and writes additionally require a live verified person, current AAL2 MFA, the existing full unscoped merchant_admin profile authorization, and order/merchant production mode. Purchase actors, store staff and scoped administrators do not acquire this permission through order ownership. Authorization is rechecked before idempotent replay.

## Persistence and financial invariants

Immutable receipt rows record positive exact minor units, trimmed bank/payment reference, evidence reference, actor and reason. Immutable reversal rows reference exactly one receipt; uniqueness prevents reversing a receipt twice. A separate active-reference sidecar claims a trimmed exact-case reference once per merchant across all orders. Reversal deletes only this claim, preserving the original receipt and reversal forever and permitting a later explicit reallocation.

A per-order receivable revision is separate from fulfillment revision. Original credit_reservations stays unchanged as the order's immutable commitment source. Active paid total is the sum of unreversed receipts. Balance is original reservation less cancellation release less active payments. Only fulfilled orders are eligible (cancellation release is normally zero). Payment cannot exceed this residual. It reduces customer exposure exactly once; reversal restores exactly the receipt amount even if the customer is blocked or exposure then exceeds the current credit limit. No project commitment, stock, order snapshot or fulfillment status is modified.

Mutations lock command identity, then one order, current full admin membership, merchant, account and original reservation. Different orders cannot be acquired by the same mutation. Account locking serializes concurrent allocations with checkout. Active-reference uniqueness is transactional; a collision rolls back the new receipt and maps to PAYMENT_REFERENCE_CONFLICT. Revision conflicts and body/key conflicts have no financial effect.

DTO bounds history to newest 100 receipt rows and explicitly flags truncation. Paid/balance totals always aggregate the entire active history, not the returned page. Reversal details are attached to their original receipt. Clients can reverse a known receipt identifier without any direct table access; ledger tables have RLS, no client grants, and immutable update/delete triggers.

## Contract

GET `get_production_receivables(p_order)`. Mutations `record_production_payment(p_order,p_body,p_key,p_correlation)` and `reverse_production_payment(...)` return the same ledger DTO. Input helper exports productionPaymentInput and productionPaymentReversalInput. All money is a string of integer minor units; mutation body cannot inject tenant, actor or computed financial state.

## Verification handoff

Migration generated with the project CLI: 20261026205522_production_receivables.sql. Two transport tests PASS, covering exact money, bounds, evidence, version and injected fields. This agent does not apply or publish. Parent owns SQL role simulation, concurrency, migration replay, API/BFF/UI and release checks. These are not reported as PASS merely because the SQL or transport tests exist.
