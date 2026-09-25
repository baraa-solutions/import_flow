---
paths:
  - "modules/customs_tariff/**"
  - "modules/customs_clearance/**"
  - "modules/customs_consultation/**"
  - "modules/customs_clearance_quotations/**"
  - "modules/financial_settlement/**"
  - "modules/demurrage_detention/**"
  - "modules/currencies/**"
  - "modules/cbm_calculator/**"
---

# Customs, landed-cost and measurement rules

Read `.agents/rules/DOMAIN_RULES.md` and AGENTS.md sections 7.1-7.3 before changing any calculation here.

- Every rate (import duty, VAT, schedule tax, development fee, service fees) comes from the HS-code tariff
  record (MD-008) valid at the declaration date (`effective_from` / `effective_to`). Never hard-code a rate;
  VAT is not always 14%.
- A charge that does not apply to the HS code is zero/skipped, not defaulted.
- CIF = FOB + Freight + Insurance; duty on CIF; VAT base = CIF + duty + applicable fees.
- Use the official customs exchange-rate snapshot for the declaration date.
- Persist each charge and each landed-cost component separately, not only totals.
- CBM / weights: normalise units (mm/cm/m, kg/lb) before calculating.
- After changing math here, the `customs-rules-reviewer` subagent reviews the diff.
