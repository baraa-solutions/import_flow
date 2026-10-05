# Accounting (logistics costs: freight, insurance, demurrage/detention, inland, clearance quotes, cost allocation): backend review

Status: 2026-10-05, static review only (grep / read). No pytest, no `import main`, no DB access, no code edits.
Lens: money math (formulas, order of operations, rounding, currency conversion, allocation, double counting,
estimate vs actual) on top of the general checklist. Rules: `.agents/rules/CORE_RULES.md`, `.agents/rules/DOMAIN_RULES.md`
§2-3 and §7, `.claude/rules/backend.md`, `.claude/rules/customs-domain.md`.

Baseline: the fixes of `docs/plans/phase-01-quality-simplify-plan.md` (CBM-*, SS-*, FQ-01),
`docs/plans/phase-04-05-quality-plan.md` (FB-*, INS-*, DD-*), `docs/plans/phase-06-07-quality-plan.md` (CCQ-*),
`docs/plans/phase-08-10-quality-plan.md` (IT-*) are in the code (permissions on every route, server-side insurance
premium through `/cargo-insurance/calculate`, contiguous demurrage tiers, no FX default of 50, CCQ total = sum of
components, ...). They are not re-reported. The same-wave reports `be-01-review.md`, `be-04-05-review.md`,
`be-06-07-review.md`, `be-08-10-review.md` already hold these money items, which are **still open** in the code and
are not repeated here (only cross-referenced):

| Still open (owner report) | What | Checked at |
|---|---|---|
| BE45-F01 | Booking charges summed into `total_freight_cost_usd` whatever their `currency` | `freight_booking/service.py:68-90` |
| BE45-F02 / F03 | Demurrage push writes stale totals; re-push without settlement permission | `demurrage_detention/service.py:729-787` |
| BE45-F04 | `free_demurrage_days` default 14 overwrites agreed days | `freight_booking/schemas.py:48` |
| BE45-F05 | Several active insurance certificates (DRAFT included) all summed by the settlement | `cargo_insurance/service.py:147-231` |
| BE45-F08 / F26 | Insurance `exchange_rate` / `tax_rate` without bounds on update | `cargo_insurance/schemas.py:101,111` |
| BE45-F09 | EIR damage fee never reaches totals | `demurrage_detention/service.py:1503-1507` |
| BE45-F20 | Savings engine matches charge types by substring (`"40" in c_type`) | `freight_booking/service.py:131-142` |
| BE01-F05 / F13 | Freight quote comparison across currencies; currency free text | `freight_quotations/service.py:46-56,248-255` |
| BE810-F01 | `imp.inland_transport_cost_egp` not resynced on PUT / delete | `inland_transport/service.py:88,272-324` |
| DD-08 / Q11 | Day-count convention (last free day flagged OVERDUE) | `demurrage_detention/service.py:839-843` |

Coverage:

| File(s) | Lines | Depth |
|---|---|---|
| `modules/freight_booking/service.py` | 671 | full read 1-260 (cost engine), grep 260-671 (workflow) |
| `modules/freight_booking/schemas.py`, `model.py`, `validators.py` | 337 | read (money fields), grep |
| `modules/cargo_insurance/*` (6 files) | 913 | full read service / schemas / validators |
| `modules/demurrage_detention/service.py` | 1,665 | full read 1-1,665 |
| `modules/demurrage_detention/schemas.py`, `validators.py`, `router.py` | 621 | read money fields, validators full |
| `modules/inland_transport/*` | 837 | schemas / model full, service money lines |
| `modules/customs_clearance_quotations/*` | 1,223 | service 1-130 full, rest grep; schemas money fields |
| `modules/freight_quotations/*` | 1,074 | service full (metrics + benchmark), schemas, repository totals |
| `modules/shipping_scenarios/*` | 1,232 | service / model money columns (grep), consumers |
| `modules/cbm_calculator/service.py`, `schemas.py`, `modules/common/cargo_math.py` | ~900 | compute path full |
| Consumers: `financial_settlement/service.py:255-300, 884-945, 1380-1470, 1730-1760, 2210-2290`; `financial_approval/service.py:1180-1240` | ~400 | targeted read |
| Flutter: `freight_booking/widgets/freight_booking_form_dialog.dart:470-560`, `freight_booking_cost_row.dart`, `shipping_scenarios/screens/shipping_scenarios_screen.dart:373-475`, `cargo_insurance/screens/cargo_insurance_screen.dart:200-215`, `cargo_insurance/services/cargo_insurance_export_service.dart:245-356`, `demurrage_detention/widgets/demurrage_form_dialogs.dart:75-100,335-352`, `freight_data_monitor_dialog.dart:1050-1070` | ~600 | targeted read |

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 3 |
| CRITICAL | 2 |
| MAJOR | 6 |
| MINOR | 8 |

Top points:

1. **Booking freight multiplied by every container** (ACC3-F01, BLOCKER). Every charge with unit "Per Container" gets
   `quantity = all containers of the booking`. The Flutter form sends "Sea Freight 40ft" with the 40' count and "Sea
   Freight 20ft" with the 20' count, so on a mixed booking each line is multiplied by the total. 2 x 40HC @ 2,000 +
   1 x 20GP @ 1,200 = 5,200 USD becomes 9,600 USD, and the settlement books 9,600 USD.
2. **Insurance and storage counted twice** (ACC3-F02, BLOCKER). The booking form adds a "Marine Insurance" charge
   (and port storage charges) into `total_freight_cost_usd`. The settlement adds the booking total **and** the
   insurance certificate premium **and** the demurrage storage rows.
3. **Phase-1 estimate inflates the customs CIF** (ACC3-F03, BLOCKER). The estimate takes the freight RFQ winner's
   `total_cost` (ocean + local charges + inland) as the CIF freight. Customs duty and VAT are computed on local and
   inland charges, and THC / inland are also estimated again as separate lines.
4. **Demurrage keeps running after the container is back** (ACC3-F04, CRITICAL). When an empty-return date exists
   without a gate-out date (allowed by the validator, and the normal EIR path), demurrage and port storage accrue
   until today, forever, and detention is 0.
5. **Tariff currency ignored** (ACC3-F05, CRITICAL). A demurrage policy has its own `currency`, but the tracking
   takes the request currency (always "USD" from Flutter). EUR tiers are converted at the USD rate.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| ACC3-F01 | BLOCKER | `modules/freight_booking/service.py:61-86`; `schemas.py:16-22`; FE `freight_booking/widgets/freight_booking_form_dialog.dart:494-513` | `unit == "Per Container"` replaces the line quantity by `total_containers` (all container types). FE sends one line per size with its own count. 2 x 40HC @ 2,000 + 1 x 20GP @ 1,200: correct 4,000 + 1,200 = **5,200 USD**; current 2,000 x 3 + 1,200 x 3 = **9,600 USD** (settlement +4,400 USD = +220,000 EGP at 50). | Optional `container_type` on the charge: a "Per Container" line with a `container_type` uses the count of that type; without it, the total count (today's behaviour for SOLAS / VGM). FE sends `container_type` on the sea-freight lines (ACC3-T01). |
| ACC3-F02 | BLOCKER | FE `freight_booking_form_dialog.dart:529,532,550`; `freight_booking/service.py:68-90`; consumer `financial_settlement/service.py:1396-1468` (+ demurrage rows `demurrage_detention/service.py:212-223`) | "Marine Insurance", "Storage per one week" and "Extra day storage" become booking charges and are summed into `total_freight_cost_usd`. The settlement adds that total as freight, **plus** each active insurance certificate premium, **plus** the demurrage storage row. Example: freight 4,000 + Marine Insurance 350 = 4,350 USD booked; certificate premium 346.50 USD also booked: insurance paid once (346.50) is counted 696.50 USD (+17,500 EGP at 50). | Booking charges carry a `charge_category` code (FREIGHT, ORIGIN_LOCAL, DESTINATION_LOCAL, INSURANCE, STORAGE, OTHER). 422 on INSURANCE (insurance belongs to cargo_insurance). STORAGE pending Q2. FE stops building the insurance line (ACC3-T02). |
| ACC3-F03 | BLOCKER | consumer `modules/financial_settlement/service.py:893-911`; source `modules/freight_quotations/repository.py:69,158` (`total_cost = ocean + local + inland`); separate THC / inland estimate lines `financial_settlement/service.py:1044-1064` | The estimate uses the awarded freight quote `total_cost` as the CIF freight. DOMAIN_RULES §2: CIF = FOB + freight + insurance, where freight is the international freight. Local (destination THC) and inland costs enter the customs base, and are estimated again as "Port & Terminal Handling" and "Inland Transport". Worked example below (§3, T03): estimate overstated by 62,700 EGP. | Use `winning_q.ocean_freight_cost` for the freight line and the CIF. Keep `local_charges_cost` / `inland_cost` out of CIF (ACC3-T03). |
| ACC3-F04 | CRITICAL | `modules/demurrage_detention/service.py:431-459` (end date = `gate_out or calc_date`), `validators.py:52-56` (empty return allowed without gate-out), EIR `service.py:1494-1517`, single container `:945-959` | Container with an empty-return date and no gate-out date: demurrage and storage accrue from discharge to **today** and keep growing; detention = 0. Discharge 2026-09-01, return 2026-09-10, free 14 / storage free 5 / 250 EGP, default tiers, rate 50, today 2026-10-06: current 21 overdue days = 7x40 + 7x70 + 7x120 = 1,610 USD + 30 x 250 = 7,500 EGP = **88,000 EGP** and rising. With the real gate-out (2026-09-08): demurrage 0, storage 2 x 250 = 500 EGP, detention 0 = **500 EGP**. | 422 when an empty-return date is set without a gate-out date (tracking, PUT, single container, EIR per container). Engine: demurrage / storage end date = `min(gate_out or calc_date, empty_return)` as a guard (ACC3-T04). |
| ACC3-F05 | CRITICAL | `modules/demurrage_detention/service.py:626,649` (tracking currency = request currency), `model.py:38` (policy `currency`, never read); FE `demurrage_detention/widgets/demurrage_form_dialogs.dart:88,346` (`'currency': 'USD'` hard-coded) | Tiers are in the policy currency, the tracking converts them in the request currency. EUR policy, tiers 100 EUR/day, 5 overdue days, EUR 54 / USD 50 (example rates): current 500 "USD" x 50 = **25,000 EGP**; correct 500 EUR x 54 = **27,000 EGP**. | Tracking currency = tariff currency (policy currency; default-tariff currency from a system parameter). 422 when the request sends another currency. FE stops sending `currency` (ACC3-T05). |
| ACC3-F06 | MAJOR | `modules/freight_booking/schemas.py:19` (`quantity: int`), `service.py:75` (`int(...)`); FE `freight_booking_form_dialog.dart:515-523` | LCL is priced per CBM but the quantity is an integer. FE sends `ceil(cbm)` with `total = price x cbm`. 12.3 CBM @ 45 USD: FE preview **553.50**, stored **585.00** (13 x 45). An API client sending 12.3 gets 422. | `quantity: float = Field(1, gt=0)`; no `int()` cast; FE sends the exact CBM (ACC3-T01). |
| ACC3-F07 | MAJOR | FE `shipping_scenarios/screens/shipping_scenarios_screen.dart:373-475`; `modules/shipping_scenarios/schemas.py:29,151` (client `total_quotation_amount`); consumers `freight_booking/service.py:102-109`, `financial_approval/service.py:1194-1206` | The scenario total exists only in Flutter: latest rate (no date), missing rate = 1.0, rounded to an integer, and it includes clearance, inspection, inland, port expenses, insurance and storage. SOLAS is not multiplied by containers (the booking multiplies it). Consumers read it as **freight**: the booking "savings" and the financial-approval freight estimate (clearance then counted again via broker fees). Example below (§3, T06). | Backend computes the scenario totals (`total_quotation_amount` server-side, client value ignored) and a new response field `freight_total_amount` (international freight only), both in `quotation_currency` at the commercial rate of the session date, 409 when a rate is missing. Consumers use `freight_total_amount` (ACC3-T06). |
| ACC3-F08 | MAJOR | `modules/cargo_insurance/service.py:36-46,90-114` | Minimum premium (30) and issuance fee (15) are applied as plain numbers in the certificate currency. EGP certificate, invoice 20,000 EGP, ICC_C 0.10 %, no war, markup 10 %: insured 22,000; base 22.00 -> min **30 EGP**; fee 15 EGP; tax 5 % x 45 = 2.25; total **47.25 EGP**. If the parameters are USD (Q4): min 1,500 EGP, fee 750 EGP, tax 112.50, total **2,362.50 EGP**. | Parameter `INSURANCE_FIXED_AMOUNTS_CURRENCY` (default "USD"); min premium and fee converted to the certificate currency at the commercial rate of the certificate date; 409 when the rate is missing (ACC3-T07). |
| ACC3-F09 | MINOR | `modules/cargo_insurance/service.py:95-97` | (a) Insured value = 110 % x (invoice + freight + other costs). Standard: 110 % x CIF, where CIF includes the premium. (b) `other_logistics_costs` (inland, packing) are put into a value labelled `cif_value`. Invoice 100,000, freight 5,000, ICC_A 0.25 % + war 0.05 %: current insured 115,500, premium 346.50; with premium in CIF: CIF = 105,000 / (1 - 1.1 x 0.003) = 105,347.66, insured 115,882.42, premium 347.65 (under-insured by 382.42). | CTO decision (Q5). If confirmed: gross-up formula, `other_logistics_costs` kept out of `cif_value` (ACC3-T12). |
| ACC3-F10 | MINOR | `modules/demurrage_detention/service.py:626` | Demurrage / detention FX is frozen at the **discharge date**, while the carrier invoices at gate-out / empty return; freight uses the confirmation date, insurance the creation date. Three rate dates for one file. | CTO decision (Q3); no task until answered. |
| ACC3-F11 | MAJOR | `modules/freight_quotations/service.py:248-255,285` vs `:37,54-56` | The RFQ metrics average leaves out `is_excluded_from_avg` quotes, the benchmark average does not. Quotes 2,000 / 2,200 / 9,000 (excluded outlier): metrics average **2,100**; benchmark average **4,400**, and the 2,200 quote shows "saving 2,200 vs average" while it is 100 above the real average. The outlier also stretches `cost_score` (max 9,000). | Benchmark uses the same included set for average, min / max of the cost score and `cost_saving_vs_average`; excluded quotes are still ranked (ACC3-T08). |
| ACC3-F12 | MINOR | `modules/cargo_insurance/service.py:264-292` | A DRAFT update recomputes the base and war rates from the **current** system parameters, but markup / minimum / fee / tax from the **stored** values. After ICC_A moves 0.25 % -> 0.30 %, editing only `remarks` reprices 115,500 x 0.30 % = 346.50 instead of 288.75, with the old fee and tax. | Recompute with the stored `base_rate` / `war_rate` unless `coverage_clause` or `include_war_and_strikes` changes (ACC3-T07). |
| ACC3-F13 | MAJOR | FE `cargo_insurance/screens/cargo_insurance_screen.dart:208-209`; `cargo_insurance/services/cargo_insurance_export_service.dart:251-258,349-356` | Dashboard sums insured value and premium across currencies. Export "USD totals" multiply non-USD amounts by `exchange_rate`, which is the **EGP** rate. USD premium 10,000 + EUR premium 300 at 54 EGP: export says **26,200 USD**; correct about **10,324 USD** (300 x 54 / 50). | Totals per currency (map currency -> sum), no cross-currency sum in the UI (ACC3-T09). |
| ACC3-F14 | MINOR | FE `demurrage_detention/widgets/freight_data_monitor_dialog.dart:1065` | Carrier tier rates are labelled EGP; tiers are in the policy currency. | Label with the policy / tracking currency (ACC3-T09). |
| ACC3-F15 | MINOR | FE `freight_booking/widgets/freight_booking_cost_row.dart:53` | The rate field shows `price.toStringAsFixed(0)`: 1,250.50 displays "1251"; any edit stores the rounded value. | `toStringAsFixed(2)` or the raw value (ACC3-T09). |
| ACC3-F16 | MINOR | `modules/demurrage_detention/service.py:1312-1332,1362-1364` | Radar "accrued" totals skip returned containers. A container returned with 1,610 USD of fines that are not yet pushed counts 0 in `total_accrued_carrier_fx_by_currency` and `total_estimated_exposure_egp`. | Returned containers: use the stored per-container `demurrage_fx` / `detention_fx` / `storage_egp` (final), flag `is_final=True` (ACC3-T10). |
| ACC3-F17 | MINOR | `modules/customs_clearance_quotations/service.py:72-74` (update), `validators.py:85` (create only), `:86-93` | Update can set all five components to 0 (total 0), which create rejects. Mixed currencies without an EGP quote write `lowest_clearance_cost = 0.0`, an invented "lowest = 0". | Same "> 0" rule on the merged update values; mixed currencies: keep the last value and expose `lowest_cost_currency` (ACC3-T11). |
| ACC3-F18 | MINOR | `modules/cbm_calculator/schemas.py:16`; `service.py:76,90-93` | (a) Weight is kg only, DOMAIN_RULES §7 requires kg / lb: a 55 lb carton typed as 55 kg is 2.2x too heavy, so the air chargeable weight is wrong. (b) `gross_weight_per_unit_kg` defaults to 0: chargeable weight = volumetric silently. (c) Line volumetric weights are rounded per line, the total is from the unrounded sum: lines do not add up to the total (difference <= 0.01 kg per line). | `weight_unit: Literal["kg","lb"]` (default "kg", 1 lb = 0.45359237 kg) converted before the math; weight required (`gt=0`) when `shipment_mode` is AIR (ACC3-T13). |
| ACC3-F19 | MAJOR | `modules/freight_booking/model.py:58` (`freight_terms`); consumer `financial_settlement/service.py:1396-1468`, `:217-218` (Incoterm-aware exclusion is backlog Q11) | Under CFR / CIF / CPT / CIP the supplier pays the freight (and under CIF / CIP the insurance), already inside the invoice value. The settlement still adds the booking freight and the certificate premium as importer cost. CIF PO 100,000 USD + booking 4,000 USD "Prepaid": landed cost +4,000 USD (+200,000 EGP at 50). | Aggregated freight / insurance rows get `is_seller_paid=True` by the file Incoterm (mapping in Q1), which the engine already honours (`is_seller_paid_expense`) (ACC3-T14). |

## 3. Tasks

### ACC3-T01: Booking charge quantity per container type and decimal quantities

- **Severity:** BLOCKER (F01), MAJOR (F06)
- **Depends on:** none. Do before BE45-T01 (charge currency) or in the same branch; both touch `calculate_transit_time_and_costs`.
- **Schema / migration needed:** no (`cost_charges_data` is JSON).
- **API contract change:** yes. `BookingChargeItem` gets `container_type: Optional[str] = None` (codes as in
  `ContainerAllocationItem.container_type`, e.g. `40HC`, `20GP`). `quantity` changes `int` -> `float` (`gt=0`).
  Before: `{"charge_type":"Sea Freight 40ft","unit":"Per Container","quantity":2,...}` -> 3 x rate on a 2+1 booking.
  After: same body plus `"container_type":"40HC"` -> 2 x rate. Old bodies without `container_type` keep today's
  behaviour (total count). Flutter: `frontend/lib/features/freight_booking/models/freight_booking_model.dart`
  (`BookingChargeModel` around lines 100-130: add `containerType`, `quantity` as `double`),
  `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart:494-523`.
- **Files to change:** `modules/freight_booking/schemas.py`, `modules/freight_booking/service.py`,
  `frontend/lib/features/freight_booking/models/freight_booking_model.dart`,
  `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`,
  `tests/unit/test_freight_booking.py`.
- **Steps:**
  1. `schemas.py:16-22`: `quantity: float = Field(default=1, gt=0)`; add `container_type: Optional[str] = None`.
  2. `service.py:60-66`: build `counts_by_type: Dict[str, float]` from `containers_data` (key = `container_type`
     upper-cased, value = sum of `quantity`) and `total_containers = sum(counts_by_type.values())`.
  3. `service.py:73-80`: `qty = float(c_dict.get("quantity", 1))` (no `int()`). If `unit == "Per Container"`:
     when `c_dict.get("container_type")` is set, `calc_qty = counts_by_type.get(type.upper(), 0)`; if that is 0,
     raise 422 `"نوع الحاوية {type} في بند {charge_type} غير موجود في توزيع الحاويات."`; when not set and
     `total_containers > 0`, `calc_qty = total_containers` (unchanged). Otherwise `calc_qty = qty`.
  4. `item_total = round(rate * calc_qty, 2)`; keep `total_cost` as the sum of the rounded line totals and
     `booking.total_freight_cost_usd = round(total_cost, 2)`.
  5. Savings block `:126`: `exec_qty = float(c_dict.get("quantity", 1))` already reads the recalculated quantity: no change.
  6. FE form: "Sea Freight 40ft" sends `containerType: '40HC'`, "Sea Freight 20ft" sends `containerType: '20GP'`;
     "LCL CBM Freight" sends `quantity: _lclCbmQty` (double, not `ceil`) and `total: _lclCbmPrice * _lclCbmQty`.
- **Acceptance criteria:** mixed 2 x 40HC + 1 x 20GP booking with the two sea-freight lines gives 5,200.00; SOLAS
  (Per Container, no type, rate 25) on the same booking gives 75.00; LCL 12.3 CBM @ 45 gives 553.50; legacy rows
  with integer quantities still load and recalculate identically.
- **Tests to add:** `tests/unit/test_freight_booking.py`:
  - `test_per_container_charge_uses_its_container_type`: containers `[{40HC,2},{20GP,1}]`, charges 40HC rate 2000 and
    20GP rate 1200 with `container_type` -> `total_freight_cost_usd == 5200.0`, line quantities 2 and 1.
  - `test_per_container_charge_without_type_uses_all_containers`: SOLAS rate 25 -> total 75.0.
  - `test_lcl_decimal_quantity`: unit "Per CBM", quantity 12.3, rate 45 -> 553.5.
  - `test_unknown_container_type_on_charge_422`.
- **Out of scope:** charge currency conversion (BE45-F01 / BE45-T01), substring savings matching (BE45-F20).

### ACC3-T02: Keep insurance (and storage) out of the booking freight total

- **Severity:** BLOCKER (F02)
- **Depends on:** Q2 for storage. The insurance part can ship alone.
- **Schema / migration needed:** no (JSON field).
- **API contract change:** yes. `BookingChargeItem` gets `charge_category: Optional[str]` with codes `FREIGHT`,
  `ORIGIN_LOCAL`, `DESTINATION_LOCAL`, `INSURANCE`, `STORAGE`, `OTHER` (null = derived from `charge_type` for legacy
  rows). A charge with category `INSURANCE` -> 422. Flutter:
  `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart:525-560`,
  `frontend/lib/features/freight_booking/models/freight_booking_model.dart`.
- **Files to change:** `modules/freight_booking/schemas.py`, `modules/freight_booking/validators.py`,
  `modules/freight_booking/service.py`, `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`,
  `tests/unit/test_freight_booking.py`.
- **Steps:**
  1. `validators.py`: `CHARGE_CATEGORIES` tuple and `infer_charge_category(charge_type)` for legacy text
     (`"insurance"` -> INSURANCE, `"storage"` -> STORAGE, `"freight"` -> FREIGHT, `"thc"`/`"dthc"` ->
     DESTINATION_LOCAL, else OTHER). `validate_charges(charges)`: 422
     `"التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز."` for INSURANCE.
  2. Call `validate_charges` on create and update before `calculate_transit_time_and_costs`.
  3. Storage (after Q2): either 422 like insurance, or keep it and expose `storage_charges_usd`; do not leave both
     the booking storage and the demurrage storage row in the settlement.
  4. FE: remove the "Marine Insurance" line from `_rebuildChargesFromQuoteBreakdown` (line 549-551); show a hint
     "سجل التأمين في شاشة التأمين" instead.
- **Acceptance criteria:** booking with a Marine Insurance charge -> 422 with the Arabic detail; a legacy booking
  that already holds an insurance charge still loads (no validation on read); a new booking from a scenario with
  insurance applicable has no insurance line.
- **Tests to add:** `tests/unit/test_freight_booking.py`: `test_insurance_charge_rejected` (422);
  `test_legacy_insurance_charge_still_reads`; settlement double count guard:
  `tests/unit/test_financial_settlement.py::test_booking_without_insurance_line_counts_insurance_once` with booking
  freight 4,000 USD + certificate 346.50 USD at rate 50 -> freight row 200,000.00 EGP, insurance row 17,325.00 EGP,
  no other insurance amount.
- **Out of scope:** the insurance certificate uniqueness (BE45-F05).

### ACC3-T03: Estimate uses the ocean freight, not the quote total, for CIF

- **Severity:** BLOCKER (F03)
- **Depends on:** none. Coordinate with the settlement owner (file outside the 8 modules; change limited to one block).
- **Schema / migration needed:** no.
- **API contract change:** no (the estimate response keeps its shape; the freight line value changes).
- **Files to change:** `modules/financial_settlement/service.py` (lines 893-911 only), `tests/unit/test_financial_settlement.py`.
- **Steps:**
  1. In the awarded-RFQ branch, replace `q_cost = float(winning_q.total_cost)` by
     `q_cost = float(winning_q.ocean_freight_cost or 0.0)`; the branch condition becomes `if winning_q and q_cost > 0`.
  2. Also filter the RFQ on `FreightRFQRequest.is_active == True` and check the winning quote belongs to it
     (`winning_q.rfq_id == awarded_rfq.rfq_id`), else fall back to the deemed rate.
  3. Change the source text to say "ocean freight of the awarded quote". The THC and inland estimate lines stay as
     they are (they are the estimate of local and inland costs).
- **Acceptance criteria:** worked example. FOB 100,000 USD, customs rate 50, awarded quote ocean 3,000 + local 400 +
  inland 600 (total 4,000), deemed insurance 2.5 % of FOB (2,500 USD = 125,000 EGP), duty 10 %, VAT 14 %, all lines
  sent to customs:
  - before: freight 200,000; CIF 5,325,000; duty 532,500; VAT base 5,857,500; VAT 820,050;
  - after: freight 150,000; CIF 5,275,000; duty 527,500; VAT base 5,802,500; VAT 812,350.
  Duty -5,000, VAT -7,700, freight line -50,000 (local + inland no longer double counted): estimate -62,700 EGP.
- **Tests to add:** `tests/unit/test_financial_settlement.py::test_estimate_freight_uses_ocean_cost_only` with the
  numbers above (assert the freight line = 150,000.00 and the CIF passed to the tariff engine = 5,275,000.00).
- **Out of scope:** quote currency handling (already converted at lines 906-911), deemed rates.

### ACC3-T04: No demurrage / storage after empty return; gate-out required

- **Severity:** CRITICAL (F04)
- **Depends on:** none (BE45-T02 recalculation on push benefits from it).
- **Schema / migration needed:** no.
- **API contract change:** yes (validation only). Create / PUT tracking, PATCH container and EIR return 422 when an
  empty-return date would exist without a gate-out date. Flutter:
  `frontend/lib/features/demurrage_detention/widgets/demurrage_form_dialogs.dart` and the EIR dialog must ask for the
  gate-out date when missing (show the backend Arabic detail).
- **Files to change:** `modules/demurrage_detention/validators.py`, `modules/demurrage_detention/service.py`,
  `tests/unit/test_demurrage_detention_engine.py`.
- **Steps:**
  1. `validators.py:46-56`: replace the `elif not gate_out_date` branch with a 422
     `"لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء (Gate-Out)."`.
  2. `service.py` `simulate_demurrage_and_detention` (431, 456): `end = req.gate_out_date or calc_date`; if
     `req.empty_return_date` and `req.empty_return_date < end`: `end = req.empty_return_date` (defensive cap, also
     for legacy rows that already hold a return without gate-out).
  3. EIR (`service.py:1490-1498`): for each target container, the per-container or tracking gate-out must exist;
     collect the missing ones and raise one 422 listing them.
- **Acceptance criteria:** example of F04: return without gate-out -> 422; legacy row (return 2026-09-10, no
  gate-out, recalculated on 2026-10-06) -> demurrage days consumed 9, overdue 0, storage 4 x 250 = 1,000.00 EGP (cap),
  not 88,000; with gate-out 2026-09-08 -> storage 500.00 EGP, detention 0.
- **Tests to add:** `tests/unit/test_demurrage_detention_engine.py`:
  `test_empty_return_without_gate_out_rejected`; `test_legacy_return_caps_demurrage_and_storage` (discharge
  2026-09-01, return 2026-09-10, calc 2026-10-06, default tiers, free 14 / 5, storage 250, rate 50 ->
  `demurrage_fee_fx == 0`, `storage_fee_egp == 1000.0`); `test_eir_requires_gate_out_per_container`.
- **Out of scope:** the day-count convention (Q11 / DD-08).

### ACC3-T05: Tracking currency = tariff currency

- **Severity:** CRITICAL (F05)
- **Depends on:** none.
- **Schema / migration needed:** no (system parameter `DD_DEFAULT_TARIFF_CURRENCY`, default "USD", added to
  `modules/common/system_parameters.py` `DEFAULT_PARAMETERS` and to `default_tariff`).
- **API contract change:** yes. `DemurrageTrackingCreate.currency` becomes optional (null = tariff currency); a value
  different from the tariff currency -> 422. Flutter: `demurrage_form_dialogs.dart:88` stops sending `currency`;
  policy create dialog (`:346`) gets a currency picker (SearchableDropdownField from the currencies master).
- **Files to change:** `modules/demurrage_detention/service.py`, `modules/demurrage_detention/schemas.py`,
  `modules/common/system_parameters.py`, `frontend/lib/features/demurrage_detention/widgets/demurrage_form_dialogs.dart`,
  `tests/unit/test_demurrage_detention_engine.py`.
- **Steps:**
  1. Add `currency: str` to the `Tariff` dataclass; `_resolve_tariff` sets `policy.currency`, `default_tariff` the parameter.
  2. `create_demurrage_tracking_service`: resolve the policy first, then `currency = tariff.currency`; if
     `req.currency` is set and differs -> 422 `"عملة جلسة التتبع ({req}) تختلف عن عملة سياسة الخط الملاحي ({tariff})."`;
     resolve the rate with that currency.
  3. Recalculations (`_tracking_tariff` callers) keep the stored tracking currency; if the policy currency changed
     after creation, log a warning and keep the tracking currency (no silent re-labelling).
- **Acceptance criteria:** EUR policy with 100 EUR/day, 5 overdue days, EUR rate 54 on the discharge date ->
  `currency == "EUR"`, `exchange_rate == 54`, `total_cost_egp == 27000.00`.
- **Tests to add:** `test_tracking_currency_follows_policy` (above numbers); `test_tracking_currency_mismatch_422`;
  `test_default_tariff_currency_parameter`.
- **Out of scope:** FX date choice (Q3).

### ACC3-T06: Scenario totals computed by the backend, freight separated

- **Severity:** MAJOR (F07)
- **Depends on:** none. Consumers changed in the same task (2 lines each).
- **Schema / migration needed:** no (`total_quotation_amount` column kept, now written by the server;
  `freight_total_amount` is computed on read).
- **API contract change:** yes. `ShippingScenarioItem` responses gain `freight_total_amount: Optional[float]`
  (international freight only: 40', 20', LCL, express courier) and `totals_rate_date`. A client
  `total_quotation_amount` is ignored on create / update. Flutter:
  `frontend/lib/features/shipping_scenarios/screens/shipping_scenarios_screen.dart:373-475` (`_calculateTotalQuoteValue`
  becomes a display of the server value after save, or a call to a preview endpoint), model
  `frontend/lib/features/shipping_scenarios/models/shipping_scenario_model.dart:282,398`.
- **Files to change:** `modules/shipping_scenarios/service.py`, `modules/shipping_scenarios/schemas.py`,
  `modules/freight_booking/service.py` (lines 102-109), `modules/financial_approval/service.py` (line 1196),
  `tests/unit/test_shipping_scenarios.py`.
- **Steps:**
  1. `service.py`: `scenario_item_totals(db, item, on_date) -> (total, freight_total)`. Each applicable component =
     price x quantity (40' x `container_40ft_qty`, 20' x `container_20ft_qty`, LCL x `lcl_cbm_qty`, SOLAS and VGM
     notification x (40' qty + 20' qty), others x 1), converted into `quotation_currency` with
     `SettlementFx(db, "commercial")`-style rates on `on_date` (session `created_at` date); 409
     `SS_FX_RATE_MISSING` (register the code) when a rate is missing; round each component to 2 decimals and the sums
     to 2 decimals (no integer rounding).
  2. On create / update, write `total_quotation_amount = total`; add `freight_total_amount` to the response.
  3. `freight_booking/service.py:104`: use `freight_total_amount` converted to USD (scenario currency) instead of
     `total_quotation_amount`.
  4. `financial_approval/service.py:1196`: use `freight_total_amount`.
- **Acceptance criteria:** example: 2 x 40HC @ 2,000 USD, SOLAS 25 USD, clearance 15,000 EGP, insurance 100 USD,
  USD rate 50, quotation currency USD -> `total_quotation_amount == 4450.00` (4,000 + 50 + 300 + 100),
  `freight_total_amount == 4000.00`. Today the Flutter total is 4,425 (SOLAS counted once) and a booking executing
  2 x 2,000 + SOLAS 2 x 25 = 4,050 USD reports "savings 375 USD". After the fix the booking variance compares the
  booking FREIGHT lines (category from T02) with `freight_total_amount`: 4,000 vs 4,000 = 0.00. Financial approval
  freight estimate = 4,000 x 50 = 200,000 EGP (today 4,425 x 50 = 221,250, which also holds the 15,000 EGP clearance
  counted again through the broker fees).
- **Tests to add:** `tests/unit/test_shipping_scenarios.py::test_server_computes_totals` (numbers above),
  `test_missing_rate_409`, `test_client_total_ignored`.
- **Out of scope:** scenario currency master FK (BE01-F13).

### ACC3-T07: Insurance fixed amounts in a defined currency; stable draft recalculation

- **Severity:** MAJOR (F08), MINOR (F12)
- **Depends on:** Q4 (currency of the fixed amounts).
- **Schema / migration needed:** no (system parameter `INSURANCE_FIXED_AMOUNTS_CURRENCY`).
- **API contract change:** no (values change for non-USD certificates). `InsuranceCalculationResult` may add
  `fixed_amounts_fx_rate: Optional[float]` (additive).
- **Files to change:** `modules/cargo_insurance/service.py`, `modules/common/system_parameters.py`,
  `tests/unit/test_cargo_insurance.py`.
- **Steps:**
  1. `load_insurance_rates` reads `INSURANCE_FIXED_AMOUNTS_CURRENCY` (default "USD").
  2. In `calculate_cargo_insurance_engine` (when the request does not override them), convert `minimum_premium` and
     `issuance_fee` from that currency into `input_data.currency` with the commercial rate of the certificate date
     (inject a `fx(currency_from, currency_to, on_date)` callable from the service; same currency -> 1.0); 409
     `INS_FX_RATE_MISSING` when missing.
  3. `update_certificate`: pass `base_rate=cert.base_rate`, `war_rate=cert.war_rate` to the engine unless the update
     changes `coverage_clause` or `include_war_and_strikes` (engine accepts optional rate overrides).
- **Acceptance criteria:** F08 example with USD fixed amounts and rate 50 -> EGP certificate total 2,362.50 EGP;
  USD certificate unchanged (today's results identical); F12 example -> remarks-only edit keeps base 288.75.
- **Tests to add:** `tests/unit/test_cargo_insurance.py::test_fixed_amounts_converted_to_certificate_currency`
  (invoice 20,000 EGP, ICC_C, no war -> net 1,500.00, fee 750.00, tax 112.50, total 2,362.50);
  `test_draft_edit_keeps_stored_rates`.
- **Out of scope:** insured value formula (T12, Q5).

### ACC3-T08: Freight benchmark average on the included quotes

- **Severity:** MAJOR (F11)
- **Depends on:** none (currency comparison is BE01-T05).
- **Schema / migration needed:** no.
- **API contract change:** no (values change).
- **Files to change:** `modules/freight_quotations/service.py`, `tests/unit/test_freight_quotations.py`.
- **Steps:** in the benchmark (`service.py:248-255`), compute `included = [q for q in quotes if not q.is_excluded_from_avg] or quotes`;
  `min_cost`, `max_cost`, `avg_cost` from `included`; clamp `cost_score` to [0, 50] for excluded quotes outside the
  range; `cost_saving` vs that average.
- **Acceptance criteria:** quotes 2,000 / 2,200 / 9,000 (excluded): `average_cost_usd == 2100.0`; the 2,200 quote has
  `cost_saving_vs_average == -100.0`; the 9,000 quote has `cost_score == 0.0`; RFQ metrics and benchmark agree.
- **Tests to add:** `tests/unit/test_freight_quotations.py::test_benchmark_ignores_excluded_quotes_in_average`.
- **Out of scope:** reliability score (BE01-F26).

### ACC3-T09: Flutter money display fixes (insurance totals, tier currency, rate field)

- **Severity:** MAJOR (F13), MINOR (F14, F15)
- **Depends on:** none.
- **Schema / migration needed:** no.
- **API contract change:** no.
- **Files to change:** `frontend/lib/features/cargo_insurance/screens/cargo_insurance_screen.dart`,
  `frontend/lib/features/cargo_insurance/services/cargo_insurance_export_service.dart`,
  `frontend/lib/features/demurrage_detention/widgets/freight_data_monitor_dialog.dart`,
  `frontend/lib/features/freight_booking/widgets/freight_booking_cost_row.dart`, a Flutter test under
  `frontend/test/features/cargo_insurance/`.
- **Steps:** (1) replace the two `fold<double>` totals with `Map<String,double>` per currency and render one chip per
  currency; (2) export: drop the "USD" conversion, print per-currency totals; (3) tier label uses the policy
  currency field instead of `l10n.egpCurrency`; (4) rate field `initialValue: price > 0 ? price.toString() : ''`.
- **Acceptance criteria:** USD 10,000 + EUR 300 certificates show "10,000.00 USD · 300.00 EUR"; no multiplication by
  `exchangeRate` anywhere in the feature.
- **Tests to add:** `frontend/test/features/cargo_insurance/insurance_totals_test.dart`: per-currency totals helper
  returns `{USD: 10000.0, EUR: 300.0}`.
- **Out of scope:** l10n sweep (FE-06 of the 04-05 plan).

### ACC3-T10: Radar totals include returned, unsettled containers

- **Severity:** MINOR (F16)
- **Depends on:** ACC3-T04.
- **Schema / migration needed:** no.
- **API contract change:** yes (additive): `ContainerRadarItem.is_final: bool = False`.
  Flutter: `frontend/lib/features/demurrage_detention/models/demurrage_model.dart` (optional read).
- **Files to change:** `modules/demurrage_detention/service.py`, `modules/demurrage_detention/schemas.py`,
  `tests/unit/test_tr02_demurrage_detention_radar.py`.
- **Steps:** for `c_empty_ret`, read `c["demurrage_fx"] + c["detention_fx"]`, `c["storage_egp"]`, `c["total_egp"]`
  (stored by the last recalculation); add them to the totals unless the tracking `is_pushed_to_settlement`; set `is_final=True`.
- **Acceptance criteria:** a returned container with stored 1,610 USD / 7,500 EGP on an unpushed tracking adds 1,610
  to the USD carrier total.
- **Tests to add:** `test_radar_counts_returned_unpushed_fines`.
- **Out of scope:** radar day-count (Q11).

### ACC3-T11: Clearance quotation totals on update and mixed currencies

- **Severity:** MINOR (F17)
- **Depends on:** none.
- **Schema / migration needed:** no.
- **API contract change:** yes (additive): RFQ response `lowest_cost_currency: Optional[str]`. Flutter:
  `frontend/lib/features/customs_clearance_quotations/` RFQ model (optional read).
- **Files to change:** `modules/customs_clearance_quotations/service.py`, `validators.py`, `schemas.py`,
  `tests/unit/test_customs_clearance_quotations.py`.
- **Steps:** (1) after merging the update, `if quote_total(updated) <= 0` -> same 400 as create; (2)
  `recalculate_rfq_metrics`: when no EGP quote exists in a mixed set, keep the previous `lowest_clearance_cost`
  and set the response `lowest_cost_currency=None`; single currency -> that currency.
- **Acceptance criteria:** update with all five fees 0 -> 400; RFQ with one USD and one EUR quote returns
  `lowest_cost_currency == None`, not a "0" lowest cost.
- **Tests to add:** `test_update_quote_zero_total_rejected`, `test_mixed_currency_lowest_cost_currency_none`.
- **Out of scope:** award locking (BE67-F31).

### ACC3-T12: Insured value formula (after CTO answer)

- **Severity:** MINOR (F09)
- **Depends on:** Q5.
- **Schema / migration needed:** no.
- **API contract change:** no (values change for new / draft certificates; ISSUED certificates are locked).
- **Files to change:** `modules/cargo_insurance/service.py`, `tests/unit/test_cargo_insurance.py`.
- **Steps:** if Q5 = "gross-up": `rate_total = base_rate + war_rate`; `cif = (invoice + freight) / (1 - (1 + markup) * rate_total)`;
  `insured = round(cif * (1 + markup), 2)`; `other_logistics_costs` added after the markup only if the CTO says
  they are insured, and never inside `cif_value`.
- **Acceptance criteria:** invoice 100,000, freight 5,000, ICC_A 0.25 % + war 0.05 %, markup 10 % -> `cif_value`
  105,347.66, `insured_value` 115,882.42, `base_premium` 289.71, `war_strikes_premium` 57.94.
- **Tests to add:** `test_insured_value_includes_premium_gross_up` (numbers above).
- **Out of scope:** clause rates.

### ACC3-T13: CBM weight units and required weight for air

- **Severity:** MINOR (F18)
- **Depends on:** none.
- **Schema / migration needed:** no (the stored weight stays in kg).
- **API contract change:** yes (additive): `CBMItemBase.weight_unit: Literal["kg","lb"] = "kg"`. Flutter:
  `frontend/lib/features/cbm_calculator/` item form (optional unit picker).
- **Files to change:** `modules/cbm_calculator/schemas.py`, `modules/cbm_calculator/service.py`,
  `modules/common/cargo_math.py` (add `to_kg(value, unit)`), `tests/unit/test_cbm_calculator.py`.
- **Steps:** convert `gross_weight_per_unit_kg` with `to_kg` before line totals; if the calculation
  `shipment_mode` is AIR and any line weight is 0 -> 422 `"الوزن الإجمالي مطلوب لحساب الوزن المحاسب للشحن الجوي."`.
- **Acceptance criteria:** 10 cartons of 55 lb -> `total_gross_weight_kg == 249.48`.
- **Tests to add:** `test_weight_in_pounds_converted` (above), `test_air_requires_weight`.
- **Out of scope:** IATA 0.5 kg rounding of chargeable weight (Q6).

### ACC3-T14: Seller-paid freight / insurance by Incoterm (after CTO answer)

- **Severity:** MAJOR (F19)
- **Depends on:** Q1 (mapping). Shared with the settlement owner (backlog Q11 there).
- **Schema / migration needed:** no (`is_seller_paid` already exists on aggregated rows).
- **API contract change:** no (aggregated invoice rows get `is_seller_paid=True` where the mapping says so).
- **Files to change:** `modules/financial_settlement/service.py` (aggregation lines 1396-1468 only),
  `modules/freight_booking/validators.py` (export `SELLER_PAID_FREIGHT_INCOTERMS`),
  `modules/cargo_insurance/validators.py` (export `SELLER_PAID_INSURANCE_INCOTERMS`),
  `tests/unit/test_financial_settlement.py`.
- **Steps:** read `imp.incoterm_code`; freight rows: `is_seller_paid = incoterm in SELLER_PAID_FREIGHT_INCOTERMS`
  (proposal CFR, CIF, CPT, CIP, DAP, DPU, DDP); insurance rows: `incoterm in SELLER_PAID_INSURANCE_INCOTERMS`
  (proposal CIF, CIP). Keep the row (visible) but excluded by `is_seller_paid_expense`.
- **Acceptance criteria:** CIF file, PO 100,000 USD, booking 4,000 USD, rate 50 -> importer total excludes the
  200,000 EGP freight row; FOB file unchanged.
- **Tests to add:** `test_cif_file_freight_row_seller_paid` (numbers above), `test_fob_file_freight_counted`.
- **Out of scope:** Incoterm-aware estimate (deemed freight) - settlement owner.

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| `POST/PUT /api/v1/freight-booking` `cost_charges_data[].container_type` (new, optional), `quantity` (float) | T01 | `freight_booking/models/freight_booking_model.dart`, `widgets/freight_booking_form_dialog.dart:494-523` |
| same, `cost_charges_data[].charge_category`; 422 on insurance | T02 | `freight_booking_form_dialog.dart:525-560` (remove Marine Insurance line) |
| Demurrage create / PUT / container / EIR: 422 when empty return has no gate-out | T04 | `demurrage_detention/widgets/demurrage_form_dialogs.dart`, EIR dialog: ask for gate-out, show detail |
| `POST /api/v1/demurrage-detention/trackings` `currency` optional (= tariff currency) | T05 | `demurrage_form_dialogs.dart:88` (stop sending), `:346` (currency picker on policy) |
| Shipping scenario items: `total_quotation_amount` server-computed, new `freight_total_amount`, 409 `SS_FX_RATE_MISSING` | T06 | `shipping_scenarios/screens/shipping_scenarios_screen.dart:373-475`, model `:282,398` |
| Insurance list totals per currency | T09 | `cargo_insurance_screen.dart:208-209`, `cargo_insurance_export_service.dart:251-258,349-356` |
| Radar `is_final` | T10 | `demurrage_detention/models/demurrage_model.dart` |
| CCQ RFQ `lowest_cost_currency` | T11 | customs_clearance_quotations RFQ model / list |
| CBM `weight_unit` | T13 | cbm_calculator item form |

Rule for all: the UI never recomputes these money values (booking totals, scenario totals, premiums, demurrage);
it displays what the backend returns or calls a preview endpoint.

## 5. Open questions for the CTO

1. **Q1 (T14): seller-paid mapping.** Which Incoterms make the freight booking and the insurance premium a supplier
   cost (excluded from the importer's landed cost)? Proposal: freight excluded for CFR, CIF, CPT, CIP, DAP, DPU,
   DDP; insurance excluded for CIF, CIP. What when the booking says "Collect" on a CIF file?
2. **Q2 (T02): storage in freight quotes.** "Storage per one week" / "Extra day storage" from the forwarder: is this
   the same port storage as the demurrage module's storage row (then reject it in the booking), or a forwarder CFS
   storage that is a separate cost (then keep it with category STORAGE and never also push demurrage storage for
   those days)?
3. **Q3 (F10): FX date per logistics cost.** Freight at booking confirmation date, insurance at certificate date,
   demurrage at discharge date. Should demurrage / detention use the gate-out / empty-return (invoice) date, and should
   all actual costs use the carrier invoice date?
4. **Q4 (T07): currency of the insurance fixed amounts.** Are `INSURANCE_MIN_PREMIUM` (30) and
   `INSURANCE_ISSUANCE_FEE` (15) USD? Is the 5 % tax applied on premium + fee (today) or on the premium only?
5. **Q5 (T12): insured value.** 110 % of CIF including the premium (gross-up), or 110 % of (invoice + freight) as
   today? Are inland / packing costs (`other_logistics_costs`) insured?
6. **Q6 (T13): air chargeable weight rounding.** Round up to the next 0.5 kg (IATA practice) or keep 2 decimals?
7. **Q7: clearance quote VAT.** Broker quotes have no VAT field; are quoted fees VAT-inclusive? The awarded clearance
   quote is not used by any estimate or variance today (`grep` finds no consumer outside the module): should the
   phase-9 actual clearance fees be compared with it?
8. **Q8: allocation of demurrage.** The push writes `allocation_rule = "Volume-Based"` on the rows
   (`demurrage_detention/service.py:209,221`); the expense engine honours it (`financial_settlement/service.py:266-276`),
   the actual-landed-cost breakdown uses the file preference instead (`:2222`). Which one is the rule?
