---
name: ruling-wht-tax-rates
description: 2026-10-05 ruling on commit c40574a (WHT from tax_rates table) - float rounding drift trap, seed constant OK, no-rate->0 policy
metadata:
  type: project
---

Commit c40574a moved withholding tax (WHT) 1% to the effective-dated `tax_rates` table (codes WHT_CLEARANCE_SERVICES / WHT_TRANSPORT_SERVICES).

Rulings:
- Seed constant 1% in `database/master_data_sync_service.py` is acceptable (data seed, not calc-time literal); the seed skips a code with any existing row, so edited rates are never reset.
- WHT is not HS-driven, so a separate tax_rates table (not MD-008) is fine.
- Float trap: `round(amt * rate / 100.0, 2)` is NOT identical to the old `round(amt * 0.01, 2)`. They differ on ~0.13% of cent amounts (e.g. 17.5 -> old 0.18, new 0.17). `amt * (rate / 100.0)` matches the old result exactly for 1%. Check this pattern whenever a literal rate becomes a percent lookup.
- No configured rate -> 0 is acceptable for synthetic fallback rows only if it is logged or flagged; for invoices with wht_deducted=True it should fail or flag.

**Why:** "Totals unchanged" claims after de-hard-coding have to be checked at half-cent boundaries, because the test fixtures usually miss them.
**How to apply:** For any future rate-table refactor, brute-force compare the old and new rounding over cent values. Related: [[ruling-clearance-category-codes]].
