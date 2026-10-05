---
name: ruling-phase09-settlement
description: 2026-10-05 Phase-9 financial_settlement/recalculation review rulings - FX source, 1.0-as-unset rate convention, deemed % float equality, seller-paid in recalc totals, customs subset freight
metadata:
  type: project
---

Phase-9 review (uncommitted diff over 4d22473), 2026-10-05.

- FX: `SettlementFx` refuses CurrencyService's built-in fallback (rate_id None) with 409 SETTLEMENT_FX_RATE_MISSING.
  Commercial rate for actual invoices, customs rate for the PL-08 simulation (CTO Q2). Accepted.
- Deemed % moved to system_parameters: `x * (2.0/100.0)` equals the old `x * 0.02` exactly (same for 2.5 -> 0.025),
  so the WHT float trap from [[ruling-wht-tax-rates]] does not apply here.
- "Stored rate 1.0 on a foreign currency = not set" convention: applied to PO and cargo insurance only. Clearance
  expense invoices (column default 1.0), invoices_data JSON and DemurrageTracking (column default 50.0 NOT NULL)
  do not follow it. Flag new code that trusts those column defaults.
- Simulation sends only lines with an HS code to the customs engine but passes the FULL freight/insurance, so the
  included lines' CIF absorbs the excluded lines' share (duty/VAT overstated). Flagged MAJOR.
- Recalc `settlement_field_total` counts seller-paid rows while the engine skips them, so the RECALC-ADJ row is
  short by the seller-paid amount. Flagged MAJOR.

**Why:** these were the judgement calls in the review; keep later reviews consistent.
**How to apply:** check these points again when the settlement / recalculation code changes. See also [[ruling-cc01-service-fee-deemed-cif]].
