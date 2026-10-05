---
name: ruling-cl03-duty-total-override
description: 2026-10-05 Phase 6-7 rulings - 7-component duty total accepted, CL-02 override must survive PUT, settlement remaining must use the assessed total, lab fee double count
metadata:
  type: project
---

Rulings from the 2026-10-05 review of the uncommitted Phase 6-7 diff (modules/customs_clearance).

- The CL-03 total (service.duty_components_total) sums 7 fields: duty, VAT, schedule tax, development fee, customs service fees, WHT, lab fees.
  Accepted as "amount payable to customs". T-3: 149,000.68 (7 components) vs 135,500.35 (5 components) checks out arithmetically.
  Gap: DOMAIN_RULES import fee and basic fees have no columns, so they get lumped into customs_service_fees (itemisation, follow-up).
- Once assessment_status == "Assessed", a generic PUT must not rewrite total_duty_payable / actual_duty_total,
  even when a component changes. A component change after CL-02 means re-assessment via CL-02 (or a 409).
  "Keep the override only when no component changed" is not enough.
- Settlement remaining balance must use assessed_duty_total (actual_duty_total), not total_duty_payable.
- financial_settlement auto-fetch adds actual_duty_total (which includes lab_service_fees) AND a separate lab-fee line,
  so lab fees are counted twice. This predates the wave. Flag it until fixed.

**Why:** these are money-path decisions the rules leave open. Fixing them here keeps reviews consistent.
**How to apply:** re-check these points on any later clearance/settlement diff. Related: [[ruling-cc01-service-fee-deemed-cif]].
