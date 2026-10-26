# TASK049 — initial merchant workspace bootstrap

Implemented SQL RPC and strict transport schema plus `/start` UI for an already authenticated person. Input: slug, name, legal_name, organization_number (Swedish format/checksum only), reason. The verified email is read from current Auth state, not user metadata. Explicit JWT AAL2, live session and satisfied current MFA are mandatory even when the actor has no existing memberships.

Creation is one transaction: a new merchant in production mode with sales paused, one unrestricted merchant_admin membership for the current person, audit event and actor/key command result. No existing tenant or membership is updated. Business identity remains self-declared in profile and response; no organization or signing-authority verification is claimed. No stores, customers, invitations or transactions are implicitly created. Org number isn't globally unique: separate declared workspaces do not prove company control.

Actor advisory lock and private actor/key command table provide replay before a tenant exists. A changed body with the same key fails. Slug remains globally unique; reserved names fail. Direct table access is denied by grants and RLS. Shared API quota plus direct RPC quota applies; there is no invented commercial workspace limit.

UI requires personal login, verified MFA, mandatory declaration checkbox and stable retry key for unchanged inputs. It does not implement public signup, send mail, accept commercial terms, activate a domain or open sales. Success links to /app. Parent integrates API route/OpenAPI/navigation.

Validation: two transport tests PASS. SQL rollback matrix prepared in tests/merchant-bootstrap.sql; not executed or applied by this agent per ownership instruction. Parent owns full build, SQL role execution and E2E on the integrated application.
