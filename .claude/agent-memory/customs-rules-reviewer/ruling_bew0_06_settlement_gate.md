---
name: ruling-bew0-06-settlement-gate
description: 2026-10-07 PR #20 BEW0-06 - CL-05 settlement totals use amount_egp (ex-VAT, pre-WHT) via engine, not net_payable_egp; itemless settlements via engine are normal
metadata:
  type: project
---

PR #20 (BEW0-06, 2026-10-07): `_sync_settlement_snapshot` now calls `recalculate_settlement_totals` (engine) instead of
summing `net_payable_egp`. Ruled correct: landed cost counts clearance invoices at `amount_egp` (net of recoverable
input VAT, WHT is a payment split not a cost reduction). Example: amount 4,200 + VAT - WHT = net 4,788 -> total 4,200.

- Engine on a settlement with empty `item_landed_costs` sets `total_fob_egp = 0`; this is already the norm (demurrage
  push creates itemless Draft settlements and recalculates), so not a new data-loss issue.
- Settlement statuses are only Draft / Calculated / Approved / Closed; the Draft-preserving wrapper is enough.
- CI 401 "Missing Authorization header" in TestClient tests (cl05 REST, clo04) comes from ALLOW_DEV_AUTH_BYPASS being
  off at run time on main's suite, not from settlement diffs.

**Why:** keeps later settlement reviews consistent on which invoice amount feeds landed cost.
**How to apply:** flag any code that feeds `net_payable_egp` or VAT-inclusive amounts into landed cost totals. See [[ruling-phase09-settlement]].
