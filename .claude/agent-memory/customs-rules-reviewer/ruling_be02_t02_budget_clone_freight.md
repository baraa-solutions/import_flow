---
name: ruling-be02-t02-budget-clone-freight
description: PR #54 BE02-T02 (2026-10-09, 075ea3b0) budget clone freight FX ruling - approve_with_minor
metadata:
  type: project
---

PR #54 BE02-T02 (commit 075ea3b0), reviewed 2026-10-09: approve_with_minor.
- `_budget_egp_amounts` in financial_approval/service.py: freight rate = 1.0 for EGP, invoice rate if same currency, otherwise `_require_rate` (latest commercial). Task-card figures verified (730,000 total; mixed-source freight 150,000).
- `_require_rate` lost its "USD" fallback. Accepted as an extension in the same area: the prefill callers already pass a resolved currency.
- MINOR left open: a legacy budget with freight_foreign > 0 and a NULL freight_currency raises FA_FX_RATE_MISSING with the text "None" instead of FA_CURRENCY_MISSING (`_require_currency`).
- `_commercial_rate_to_egp` still has `currency_code or "USD"` inside it; the guard in `_require_rate` hides it, but direct callers do not.

**Why:** keeps later BE02-T03 (create/update using the same helper) reviews consistent.
**How to apply:** when T03 reuses the helper, check that NULL currency gives FA_CURRENCY_MISSING and that client EGP is ignored.
