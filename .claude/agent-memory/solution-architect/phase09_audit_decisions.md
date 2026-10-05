---
name: phase09-audit-decisions
description: 2026-10-05 Phase-9 (landed cost) audit - approve corrupts settlement JSON, hard-coded FX 48.5, recalc double-count trap, open CTO Q1-Q12
metadata:
  type: project
---

Phase-9 audit plan: docs/plans/phase-09-quality-plan.md (proposed 2026-10-05; check git for status).

Non-obvious facts found (verify before relying on them):
- approve_actual_landed_cost writes the category breakdown into `expense_invoices` and ActualLandedCostItemLine keys into `item_landed_costs`. Any later engine run (PUT, /recalculate, recalculation.apply) or Odoo export on that record reads zeros. Approved records on the live DB may already be corrupted.
- create_settlement auto-populate references POLineItem columns that do not exist (is_active, unit_price_egp...). The swallowed except means items are always empty. The simulation reads `itm.cbm` (real column total_cbm).
- base_exchange_rate = 48.5 is hard-coded in the CLO-01 aggregation and flows into CLO-02 item FOB.
- recalculation `_get/_apply_field_to_entity` for settlements: the read sums substring matches, the write updates only the first match. This is non-idempotent and double counts. "customs" also matches "Customs Clearance".
- test_recalculation_engine.py test 12 pins "Approved settlement + justification -> recalculated, status Calculated".
- The 1% WHT item was already resolved by c40574a/274f360 (see [[ruling-wht-tax-rates]]).

**Why:** these shape any future Phase-9 plan, landed-cost math change, or recalculation work.
**How to apply:** read the plan's Q1-Q12 answers before touching settlement status, FX, allocation, or the Odoo export. Related: [[phase01-audit-decisions]].
