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
- [BEW0-01 FX resolver (PR #18)](ruling_bew0_01_fx_resolver.md) — 2026-10-07: 48.50 leftover in freight_data_connector; CI 401 flake from main
- [CC-01 service fee / deemed CIF / air 167](ruling_cc01_service_fee_deemed_cif.md) — 2026-10-05: 1.00 fallback OK; deemed=0 compliant but understates
- [BEW0-06 settlement gate](ruling_bew0_06_settlement_gate.md) — 2026-10-07 PR#20: CL-05 totals on amount_egp via engine; CI 401 not from diff
- [BE810-T01 inland resync (PR #21)](ruling_be810_t01_inland_resync.md) — 2026-10-07: file cost = sum active fares; TR-IMP fallback safe; CI 401 not from diff
- [BE810-T06 dossier FOB (PR #26)](ruling_be810_t06_dossier_fob.md) — 2026-10-07: per-currency FOB OK; estimate USD default left to T07
- [BE810-T07 dossier no-invented (PR #33)](ruling_be810_t07_dossier_no_invented.md) — 2026-10-07: re-review 787ca4fa 3 MAJORs fixed; settlement 1.0 leftover
- [ACC3-T02 booking insurance (PR #42)](ruling_acc3_t02_booking_insurance.md) — 2026-10-07: 422 OK; legacy INSURANCE still in freight total on recalc
- [BE45-T01 booking FX (PR #41)](ruling_be45_t01_booking_fx.md) — 2026-10-07: re-review e7437ae2 fixes OK; cross-size dropdown drops freight line
- [ACC2-T01 PO shares (PR #39)](ruling_acc2_t01_po_shares.md) — 2026-10-07: re-review aecc1095 both MAJORs fixed; mixed-FOB PO-level allocs minor
- [BE67-T02 agreement rate (PR #40)](ruling_be67_t02_agreement_rate.md) — 2026-10-07: re-review approve_with_minor; 10-digit fixed; _customs_rate dropped
- [BE67-T04 simulate-file (PR #44)](ruling_be67_t04_simulate_file.md) — 2026-10-07: re-review 72f91d38 all fixed; new warning codes unregistered
- [ACC1-T01 freight FX (PR #43)](ruling_acc1_t01_freight_fx.md) — 2026-10-07: card order OK; deemed freight still 422s on missing rate; Flutter 1.0 preview
- [ACC3-T03 ocean freight CIF (PR #45)](ruling_acc3_t03_ocean_freight_cif.md) — 2026-10-07: ocean-only freight OK; history text claims total_cost fallback
