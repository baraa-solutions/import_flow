---
name: ruling-phase04-05-insurance-demurrage
description: 2026-10-05 rulings on Phase 4-5 money (cargo insurance premium params, demurrage tariff/FX/radar/push-to-settlement, BK-02 free-days override gap)
metadata:
  type: project
---

Phase 4-5 review (uncommitted diff, 2026-10-05). Rulings to keep consistent next time:

- Insurance premium order is CIF=inv+frt+other -> insured=CIF*(1+markup) -> base & war rounded separately
  -> net=max(base+war, min) -> tax=(net+fee)*tax_rate -> total. Accepted as correct and pinned.
  In-code defaults equal to the seeded values are an acceptable documented fallback ONLY once the keys are
  actually in `DEFAULT_PARAMETERS`/migration; until seeded, flag MAJOR (rates are de facto still hard-coded).
- Demurrage FX = commercial (bank) rate at discharge date (plan Q12). Not a customs value, so the customs-rate
  rule 5 does not apply. Accepted.
- Gap found: BK-02 agreed free days live only on `ShipmentBooking.free_demurrage_days` (detention agreed days
  not stored at all). Only tracking create and BK-02 apply them; PUT tracking, single-container update,
  dual clock and radar use the policy free days -> a later PUT reverts waived demurrage. Pre-existing for PUT,
  ruled MAJOR-with-money-impact (treat as BLOCKER if it reappears after the §6 deferred columns land).
- Push-to-settlement row mixes carrier USD (amount_fx) and port storage EGP in one amount_egp: itemisation
  issue (rule 6), pre-existing. No double count with CLO-01/CLO-02: those read DemurrageTracking directly,
  not settlement.expense_invoices.

**Why:** these were judgement calls on plan-sanctioned defaults vs domain rules.
**How to apply:** reuse when Phase 4-5 or Phase 9 demurrage/insurance code is reviewed again. See [[ruling-phase09-settlement]].
