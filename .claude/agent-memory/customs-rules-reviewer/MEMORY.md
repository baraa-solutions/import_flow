# customs-rules-reviewer memory

- Reference worked example (engine fixture; VAT = 14% x (CIF + duty)): FOB 623,000; import duty 62,300 (10% of CIF); VAT 95,942;
  schedule tax 6,230; import fee 0; customs service fees 78,286.90; basic fees 1,329.50; total 165,801.50 EGP.
  Use it as a sanity fixture when reviewing the calculation engine.
- Record here each ruling you make on an ambiguous rule (with file:line and date) so reviews stay consistent.
- [WHT tax_rates ruling](ruling_wht_tax_rates.md) — 2026-10-05 c40574a: amt*r/100 vs amt*0.01 rounding drift; no-rate->0 policy
- [Clearance category codes ruling](ruling_clearance_category_codes.md) — 2026-09-29: buckets identical to HEAD; legacy quirks kept on purpose
- [CL-03 duty total / override / settlement](ruling_cl03_duty_total_override.md) — 2026-10-05: 7 components OK; assessed total locked after CL-02; lab double count
- [VAT base + Phase-3 non-column writes](ruling_vat_base_and_phase03.md) — 2026-10-05: VAT base = CIF+duty only; ImportFile.total_amount etc. not columns
- [Phase 9 settlement rulings](ruling_phase09_settlement.md) — 2026-10-05: Q6 OK; rate-1.0 gaps; Q1 recalc gaps; total_fob apply loop; RFQ FX
- [Phase 4-5 insurance / demurrage](ruling_phase04_05_insurance_demurrage.md) — 2026-10-05: premium order OK; params unseeded; BK-02 free-days lost on PUT
- [Phase-9 settlement rulings](ruling_phase09_settlement.md) — 2026-10-05: FX refusal, 1.0-unset gaps, HS-subset freight, seller-paid recalc
- [Legacy NULL money in responses](ruling_legacy_null_money_responses.md) — 2026-10-05: backend safe; smart_checklists crash; Dart ?? 1.0 rate
- [CC-01 service fee / deemed CIF / air 167](ruling_cc01_service_fee_deemed_cif.md) — 2026-10-05: 1.00 fallback OK; deemed=0 compliant but understates
