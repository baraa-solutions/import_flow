---
name: ruling-clearance-category-codes
description: 2026-09-29 ruling on CLEARANCE_EXPENSE_CATEGORY codes vs legacy labels in landed-cost / Odoo keyword classifiers
metadata:
  type: project
---

Clearance invoice `expense_category` moved to codes. Classifiers (`actual_expense_bucket`, `classify_odoo_cost_category`)
map code/English label back to the legacy bilingual label before keyword matching. Verified 2026-09-29: all 7 codes give the
same bucket as HEAD for legacy, code, and English-label rows, in both classifiers, including old "Clearance / <legacy>" snapshots.

Known quirks carried over from before the change (kept on purpose for identical money, not new bugs):
- PORT_DUES_WHARFAGE (legacy contains "نولون") -> Freight in both classifiers; STEVEDORING_HANDLING ("الشحن") -> Freight in actual landed cost.
- BROKER_FEES "Clearance / ..." -> Odoo Customs account, because "customs" is checked before "broker".
- `wht_amt = amt * 0.01` hard-coded in aggregate_shipment_invoices_service (withholding tax, pre-existing).

**Why:** future reviews should not flag these as regressions of the code migration.
**How to apply:** if a later diff changes these buckets, treat it as a money change that needs sign-off and a test update.
