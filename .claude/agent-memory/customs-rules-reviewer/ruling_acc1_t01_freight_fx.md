---
name: ruling-acc1-t01-freight-fx
description: ACC1-T01 (PR #43, 2026-10-07) freight customs-rate resolution review; deemed-freight 422 regression and Flutter 1.0 preview rate
metadata:
  type: project
---

PR #43 (base fix/be67-t02-preferential-agreement-rate) reviewed 2026-10-07: approve_with_minor-level money math is correct.
- Card order honoured: invoice_currency -> manual -> table (_customs_rate, 422 CT_CUSTOMS_RATE_MISSING). Card example 324,060.00 verified by test.
- Gap: freight rate resolved BEFORE resolve_insurance_freight, so deemed freight (has_freight_document=False) with a foreign
  non-invoice freight currency and no table rate still 422s although the amount is unused. Flutter always sends freight_foreign_amount.
- Flutter preview `duty_calculator_dialog.dart:97` falls back to 1.0 for a different freight currency (display only; backend is authoritative).
- Same-currency freight ignores a manual freight_exchange_rate (per card step 2 ordering; not a defect).

**Why:** consistent rulings on freight FX for later ACC1-T03 (deemed policy) reviews.
**How to apply:** when ACC1-T03 lands, check the rate lookup is skipped for deemed freight.
