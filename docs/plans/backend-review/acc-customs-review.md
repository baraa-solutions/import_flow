# Accounting (customs duties, VAT, tariff, landed cost estimate + actual): backend review

Status: 2026-10-05, static review only (grep / read). No pytest, no `import main`, no DB access, no code edits.
Reviewer lens: accounting / money math (formulas, order of operations, rounding, FX, allocation, reconciliation, estimate vs actual).
Rules checked: `.agents/rules/CORE_RULES.md`, `.agents/rules/DOMAIN_RULES.md` sections 2-3, `.claude/rules/backend.md`, `.claude/rules/customs-domain.md`.

Same-wave reports already cover much of this scope (`be-06-07-review.md` = BE67, `be-01-review.md` = BE01, `be-09-review.md` = BE09,
`be-cross-review.md` = BEX, `frontend-review/phase-01-frontend-review.md` = F01). Those items are **not repeated as new tasks**: section 2.1
lists them with the accounting check result, and the new ACC1 tasks name them as dependencies. Every ACC1 finding below is new.

| File | Lines | Depth |
|---|---|---|
| `modules/customs_tariff/service.py` | 1,563 | full (engines l.178-276, 436-846, simulate 1290-1559, versions 885-1193, origin check 1196-1287) |
| `modules/customs_tariff/repository.py` | 349 | full |
| `modules/customs_tariff/model.py` | 219 | full |
| `modules/customs_tariff/schemas.py` | 532 | money fields + responses (l.21-150, 189-225, 312-532) |
| `modules/customs_tariff/router.py` | 314 | full (auth, cache) |
| `modules/customs_tariff/nafeza_text_parser.py` | 277 | rate / agreement extraction (l.80-277) |
| `modules/customs_consultation/service.py` | 956 | full math (l.270-956); price-list CRUD skimmed |
| `modules/customs_consultation/repository.py` | 531 | create / update / code generator (l.265-500) |
| `modules/customs_consultation/model.py`, `schemas.py` | 278 / 367 | money columns and fields |
| `modules/customs_clearance/service.py` | 1,559 | duty total, CL-02, CL-03, CL-05 money (l.80-150, 348-507, 895-1125, 1324-1559) |
| `modules/customs_clearance/validators.py`, `schemas.py` | 206 / 466 | duty components, payment guard, money fields |
| `modules/recalculation/service.py` | 975 | fetchers, aggregation, FOB scaling (l.50-340) |
| `modules/recalculation/seed_dependencies.py` | 161 | full |
| `modules/import_requirements/service.py`, `model.py`, `validators.py` | 689 / 100 / 68 | money / value fields (prefill l.546-680) |
| `modules/currencies/service.py` | - | `_get_rate_to_egp` only (callers' behaviour) |
| `modules/financial_approval/service.py`, `financial_settlement/service.py` | - | consumers of the estimate / actual only (l.1215-1260; l.480-520, 1475-1545) |
| Flutter `customs_tariff/widgets/duty_calculator_dialog.dart`, `customs_consultation/screens/customs_consultation_screen.dart`, `import_requirements/screens/import_requirements_screen.dart` | - | trace of the same numbers (payloads, client formulas) |

Verified correct (no finding): VAT base = CIF + import duty only (`customs_tariff/service.py:234`, `:732`), schedule tax / development fee /
import fee / service fee on CIF (`:228-231`, `:721-728`), missing tariff on the date is a 422 with no fallback rate (`:185-194`, `:638-646`),
consultation re-estimation refuses a missing customs FX rate (`customs_consultation/service.py:863-891`) and mixed PO currencies
(`:849-860`), CL-03 refuses an under-payment (`customs_clearance/validators.py:88-104`), CL-02 never defaults the customs rate to 1.0
(`customs_clearance/service.py:941`).

## 1. Summary

| Severity | New (ACC1) | Same-wave items re-confirmed (section 2.1) |
|---|---|---|
| BLOCKER | 1 | 8 |
| CRITICAL | 3 | 7 |
| MAJOR | 7 | 5 |
| MINOR | 4 | 2 |

Top points:
1. **Freight in a foreign currency is converted at the invoice rate** (ACC1-F01). The engine falls back to the goods exchange rate when no
   freight rate is sent, and the Flutter calculator sends the invoice rate as the default freight rate. EUR invoice + USD freight overstates
   CIF and every tax that follows (worked example: +2,640 EGP on a 20,000 EUR shipment).
2. **Line CIF does not reconcile with the header** (ACC1-F02). Freight / insurance are allocated by gross value while the goods part uses
   the taxable value; the "declared CIF" path ignores exempted value; an exempted value larger than the line value gives a negative CIF;
   per-line rounding loses piastres with no remainder line.
3. **The phase-1 estimate is not owned by the server** (ACC1-F05, F03). `estimated_duties_egp` (which feeds the budget and the
   settlement) is whatever the client sends, today computed by a Flutter formula with invented rates; and the two server estimators
   (`simulate-file` vs consultation re-estimation) apply different insurance rules, so the "variance" between them is method, not data.
4. **Actual phase totals need not match their components** (ACC1-F06). CL-02 accepts a claimed total that differs from the 7 components
   with no reason, and the clearance `estimated_duty_total` used for the phase-7 variance is typed by the user, not taken from phase 1.
5. **Tariff history can be corrupted by a back-dated save, and the version diff hides VAT / fee changes** (ACC1-F08, F09).

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| ACC1-F01 | BLOCKER | `customs_tariff/service.py:476-479`, `:619-621`; `schemas.py:320-322`, `:413-415`; Flutter `duty_calculator_dialog.dart:31`, `:96`, `:1335-1338` | Actual freight in a foreign currency uses `freight_exchange_rate` from the request, else the **invoice** exchange rate. The rate is never resolved from the customs rate table for `freight_currency`. Flutter sends the invoice rate (or a typed `50.7917`) as the freight rate default, so this is the normal UI path. Example: invoice 20,000 EUR at customs EUR 55.00, freight 2,000 USD (customs USD 50.00), insurance 27,500 EGP actual, duty 10% / VAT 14% / service fee 1%. Now: freight 110,000, CIF 1,237,500, duty 123,750.00, VAT 190,575.00, service fee 12,375.00, total 326,700.00. Correct: freight 100,000, CIF 1,227,500, duty 122,750.00, VAT 189,035.00, service fee 12,275.00, total 324,060.00 (overstated by 2,640.00). | Resolve the freight rate with the customs-rate helper of BE67-T03 for `freight_currency` on the estimate date (EGP = 1; freight currency == invoice currency = the invoice rate). A client `freight_exchange_rate` is an explicit override, reported as `freight_rate_source="manual"`. No rate -> 422 `CT_CUSTOMS_RATE_MISSING`. Task ACC1-T01. |
| ACC1-F02 | CRITICAL | `customs_tariff/service.py:698-705`; `schemas.py:397-404` | Line CIF is built from two different bases: insurance + freight + packaging allocated by **gross** `value_fc / invoice_total`, goods by **taxable** value (`value_fc - exempted_value_fc - value_without_payment_fc`). (a) A fully exempted line still gets duty / VAT / service fee on its share of freight. Example (EGP, rate 1): line A 60,000 with `exempted_value_fc=60,000`, line B 40,000, insurance 5,000, freight 10,000, duty 10%, VAT 14%, service fee 1%: A CIF 9,000 -> duty 900.00, VAT 1,386.00, service fee 90.00; consistent result (gross CIF x taxable fraction) is A CIF 0 and no tax. (b) With `cif_declared_total_egp` (sent by the Flutter calculator, `duty_calculator_dialog.dart:1342-1343`) line CIF = declared x share and exempted / unpaid value is ignored completely: same lines, declared 100,000 -> A CIF 60,000, duty 6,000.00 (other path: 0). (c) No check that `exempted_value_fc + value_without_payment_fc <= value_fc`: line 1,000 USD with 1,500 exempted at rate 50 -> CIF -25,000 + allocation, negative duty / VAT. (d) Per-line `_round` with no remainder line: 3 lines x 1,000 USD at 50.00, insurance 50 + freight 50 -> each CIF 50,033.33, sum 150,099.99 instead of 150,100.00. | One allocation routine: gross line CIF (value x rate + allocated share, largest-remainder rounding so shares sum exactly to the total), then dutiable CIF = gross x taxable fraction, in both paths; 422 when exempted + unpaid > value; response adds `cif_total_egp` (sum of gross lines) and `dutiable_cif_total_egp`. Whether `value_without_payment_fc` is dutiable: Q1. Task ACC1-T02. |
| ACC1-F03 | MAJOR | `customs_tariff/service.py:1433-1447` + `:468-473`; `customs_consultation/service.py:936-944` | The two server estimators of the same file disagree. `simulate-file` (writes `estimated_duties_egp`) adds deemed insurance 2.5% of FOB when no insurance is entered; the consultation re-estimation (BP-009) uses deemed rates 0 and missing insurance = 0. Same file, PO 20,000 USD at 50.00 (FOB 1,000,000 EGP), freight 50,000 EGP entered, no insurance, duty 10% / VAT 14% / service fee 1%: simulate CIF 1,075,000, total taxes 283,800.00 (107,500 + 165,550 + 10,750); re-estimation CIF 1,050,000, total 277,200.00 (105,000 + 161,700 + 10,500). The screen reports a 6,600.00 "variance" with no data change. The Flutter consultation screen uses a third rule (0.5% / 1% of C&F). | One shared function for estimate CIF inputs (insurance / freight actual vs deemed) used by both server paths; the deemed policy is a CTO decision (Q2), read from `system_parameters`, not literals. Depends on BE01-T17 and BE67-T04. Task ACC1-T03. |
| ACC1-F04 | MAJOR | `customs_tariff/service.py:1207-1210`; `:196-197`, `:229-235`; `schemas.py:318-323` | (a) The origin / document check (`POST /check-duty-for-origin`) looks up the tariff with `strict=False` and then `get_tariff_by_hs_code` (any date): a check dated before the first version returns a rate that was not in force. (b) The single-item engine (`POST /estimate`) accepts `freight`, `freight_currency`, `freight_foreign_amount`, `freight_exchange_rate`, `packaging_egp`, echoes them, but computes every tax on `cif_value` only; the multi-item engine adds packaging to CIF. Example: `cif_value` 100,000, `packaging_egp` 5,000, duty 10% / VAT 14% / service fee 1%: single engine duty 10,000.00, VAT 15,400.00, service 1,000.00; multi engine (and correct) duty 10,500.00, VAT 16,170.00, service 1,050.00. | (a) `strict=True`; none -> 422 with the same Arabic message as the engines. (b) CIF base = `cif_value + packaging_egp`; freight fields documented as informational (CIF already includes freight) and returned as `cif_base_egp`. Task ACC1-T04. |
| ACC1-F05 | CRITICAL | `customs_consultation/schemas.py:224-225`, `:244-245`; `repository.py:311-313`, `:419-424`; consumers `recalculation/seed_dependencies.py:41-50`, `:112-121`; `financial_approval/service.py:1219-1227` | `estimated_duties_egp` is a free client field on create and PUT. It is the phase-1 customs estimate copied into the import budget and the settlement (`max` over sessions). Flutter fills it from its own client tax engine with duty 5% / VAT 14% / service fee 1% fallbacks (F01-01, `customs_consultation_screen.dart:812-835`, `:1522`). Example: engine (simulate) says 283,800.00, the user or the client formula sends 50,000 -> budget customs duties 50,000 (understated by 233,800.00). | The server owns the number: create / PUT ignore `estimated_duties_egp`; it is written only by `simulate-file` (`save_to_consultation`) or a new `POST /customs-consultation/{id}/estimate-duties` that runs the same engine. A manual override, if wanted, is Q3. Task ACC1-T05. |
| ACC1-F06 | MAJOR | `customs_clearance/service.py:923-927`, `:945-946`; `schemas.py:44`, `:140`, `:337`; `service.py:386`; consumer `financial_settlement/service.py:511-518`, `:582-583` | Actual phase: (a) CL-02 stores a claimed `actual_duty_total` that may differ from the sum of the 7 components with no reason and no record of the difference; the settlement then cannot split the duty per component (DOMAIN_RULES section 3: keep each component). Example: duty 100,000 + VAT 154,000 + service 10,000 = 264,000, claim 250,000 -> stored total 250,000, components 264,000, difference 14,000 unexplained. (b) The clearance `estimated_duty_total` (base of the phase-7 variance) is typed on create / PUT, never taken from the phase-1 consultation estimate, so the variance compares the claim with a typed number. | (a) When `|actual_duty_total - components_sum| > MONEY_TOLERANCE`, require `duty_override_reason` (400 otherwise) and keep `{components_total, claimed_total, difference, reason}` in `nafeza_assessment_json["override"]`. (b) Snapshot `estimated_duty_total` from the active consultation's `estimated_duties_egp` at create / CL-02 when it is 0; PUT of `estimated_duty_total` after assessment -> 409. Task ACC1-T06. |
| ACC1-F07 | MAJOR | `import_requirements/model.py:19-21`; `schemas.py:64`, `:142`; `service.py:341`, `:368-369`; Flutter `import_requirements_screen.dart:615-616` | `shipment_value_usd` is never converted: Flutter sends the same number as `shipment_value` whatever `currency` is, and the backend stores it as USD. Example: 10,000 EUR (commercial EUR 55.00, USD 50.00) -> stored USD 10,000.00; correct 11,000.00. An EGP file of 500,000 is stored as USD 500,000. | Server computes `shipment_value_usd = shipment_value x rate(currency) / rate(USD)` (rate type and date: Q7) and ignores the client value; missing rate -> 409 `SETTLEMENT_FX_RATE_MISSING` (existing code). Task ACC1-T07. |
| ACC1-F08 | CRITICAL | `customs_tariff/repository.py:245-283`, `:259-262`; `schemas.py:266` | `POST /with-agreements` with an `update_date` earlier than the active version's `effective_from` closes that version with `effective_to < effective_from` (an invalid range) and opens the new version from the earlier date, open-ended: estimates for dates after the old start are silently repriced. Example: version A duty 30% from 2026-09-01; save duty 20% with `update_date=2026-08-01` -> A becomes [2026-09-01, 2026-08-01], B 20% from 2026-08-01 -> an estimate dated 2026-09-15 now uses 20% (was 30%). The same-day path hard-deletes the agreements of the day (`.delete()`), losing what was applied to estimates made earlier that day. | `update_date < existing.effective_from` -> 422 (Arabic). Same day: close the replaced agreements (`effective_to = eff_date - 1 day`, never matched) and write the replaced rows into the audit log `old_data` instead of deleting. Task ACC1-T08. |
| ACC1-F09 | MAJOR | `customs_tariff/service.py:925-941` | The version comparison shown before saving a parsed Nafeza text only diffs `customs_duty_rate`. A VAT 14 -> 10, a new schedule tax, or a service / development / import fee change is reported as "0 modified", so a rate change is saved without warning. | Diff all six rate fields (same list as BE67-T08 `RATE_FIELDS`), one `TariffDiffItem` per changed field. Task ACC1-T09. |
| ACC1-F10 | MAJOR | `customs_tariff/service.py:536-541` | Derived fee codes are evaluated once, in `fee_code_id` order. A derived code whose base contains another derived code listed after it is computed on 0. Example: `77` flat 500 (id 1), `394` derived 14% of `77,392` (id 2), `392` derived 10% of `77` (id 3): now `394 = 70.00`, correct `14% x 550 = 77.00`; Nafeza fee grand total 620.00 instead of 627.00. A cycle is not detected. | Evaluate derived codes in dependency (topological) order; a cycle or an unknown base code -> 422 `CT_FEE_CODE_FORMULA_INVALID`. Task ACC1-T10. |
| ACC1-F11 | MAJOR | Flutter `duty_calculator_dialog.dart:1314`; backend `customs_tariff/service.py:661-688` | The calculator sends `is_exemption_conditions_met: m[...] == true`, i.e. `false` when the user never touched it. The engine treats `false` as "conditions explicitly not met" and skips the preferential-agreement lookup, so DB agreements are never applied from the calculator. Example: HS 30% with a GAFTA 100% agreement, origin JO, CIF 1,000,000 -> duty 300,000.00 + VAT 42,000.00 extra. | Flutter sends `null` until the user decides (tri-state). Backend contract unchanged (document the tri-state in the schema description). Task ACC1-T11. |
| ACC1-F12 | MINOR | `customs_tariff/service.py:465`, `:625`, `:827-830`, `:1545`, `:1476` | `fob_value_egp` already includes packaging and `packaging_egp` is returned too: a client that rebuilds CIF as fob + insurance + freight + packaging double counts packaging (10,000 USD x 50 + packaging 5,000 + insurance 5,000 + freight 10,000: lines CIF 520,000, rebuilt 525,000). The simulation summary labels the grand total "إجمالي سيف" (CIF). `simulate-file` creates a consultation with code `CONS-<file code>`: if a soft-deleted consultation has that code the unique index raises a 500. | Add `goods_value_egp` and `cif_total_egp` (sum of lines) to the response; fix the summary label; generate the code with the module's generator (after BE01-T03). Task ACC1-T12. |
| ACC1-F13 | MINOR | `recalculation/service.py:319-329`, `:154`, `:230` | Scaling `total_fob_egp` skips items with `qty <= 0`, so items no longer sum to the new total (items 600 [qty 0] + 400, new total 1,100 -> 600 + 440 = 1,040). Scenario freight uses `quotation_currency or "USD"` (invented currency). An unknown `aggregation_function` silently becomes `max`. | Scale every item's `fob_total_egp` (unit recomputed only when qty > 0); missing currency -> skip with `SourceRateMissing`-style status; unknown aggregation -> 400 at seed / apply. Task ACC1-T13. |
| ACC1-F14 | MINOR | `customs_tariff/service.py:556`, `:563-567`; `customs_consultation/service.py:703-727`; `customs_clearance/model.py` (Float money) | Money leaves `Decimal` early: fee-code amounts are converted to `float` per code then summed; the re-estimation sums `float` per line; clearance and consultation money columns are `Float`. The rounding policy (each tax per line, HALF_UP, 0.01) is nowhere written or locked by a test. | Keep `Decimal` until the response, round totals once; write the policy in `docs/` and lock it with a test. Float -> Numeric columns: Q9. Task ACC1-T14. |
| ACC1-F15 | MINOR | `customs_tariff/service.py:804-808` | `additional_fees_egp > 0` **replaces** the computed Nafeza extra fees instead of adding to them; the response does not say which one was used. | Return both `computed_nafeza_fees_egp` and `manual_additional_fees_egp`; replace-vs-add is Q6. Part of Task ACC1-T12. |

### 2.1 Same-wave items re-confirmed by the accounting check (no new task)

| Same-wave id | Accounting check result | Task that fixes it |
|---|---|---|
| BE67-F01 (BLOCKER) | Any logged-in user can change VAT / duty rates, fee codes, upload tariffs: every number in this report can be changed without `customs_tariff.edit`. | BE67-T01 |
| BE67-F02 (BLOCKER) | Confirmed with numbers: Mercosur fixed 3% stored as `reduction_percentage=1.00` -> multi engine duty 1% (CIF 1,000,000: 10,000 instead of 30,000; VAT 1,414,000 vs 1,442,000 base). Also covers the agreement HS format and origin substring match (`repository.py:217-225`). | BE67-T02 |
| BE67-F03 (CRITICAL) | `reduction_percentage=50` -> rate `30 x (1-50) = -1470%`, negative duty. | BE67-T02 |
| BE67-F04 / BEX-F03 (BLOCKER) | `_get_rate_to_egp` fallback (USD 48.50, or 1.0) used silently by `estimate-multi` and `simulate-file`; JPY with no rate row = 1.0 -> 100,000 JPY priced as 100,000 EGP. | BE67-T03, BEX-T07 |
| BE67-F05, F13 (BLOCKER / CRITICAL) | Simulation invents HS / values / currency; mixed PO currencies converted at the last PO's rate; origin truncated to 2 letters. | BE67-T04 |
| BE67-F09 (CRITICAL) | Multi engine agreement lookup has no date filter and takes an unordered `[0]`. | BE67-T02 |
| BE67-F10 (CRITICAL) | Extra Nafeza fees understated by the schedule tax. | BE67-T10 |
| BE67-F11, F12 (CRITICAL) | `verify` drops `customs_service_fee_rate` from the new version (reverts to 1.00) and does not version a service-fee-only change; PUT / upload overwrite rates in place; upload cannot map a service-fee column (always 1.00). | BE67-T08, BE67-T09 |
| BE67-F17, F19, F20, F21 (MAJOR) | Soft-deleted tariff still priced; VAT override 0 ignored; service fee 1% fallback; parser VAT 14% default; exemption flag forces 0. | BE67-T12, T13, T14 |
| BE01-F01 (BLOCKER) | `total_broker_fees_egp` sums USD and EGP quote lines as EGP (5,000 EGP + 100 USD = 5,100 "EGP"; correct at 50.00: 10,000). | BE01-T01 |
| BE01-F07 (CRITICAL) | Prefill `shipment_value` adds amounts in different currencies. | BE01-T06 |
| BE01-F19 (MAJOR) | Re-estimation: missing freight / insurance = 0 with no warning. | BE01-T17 (+ ACC1-T03) |
| BE09-F03 (BLOCKER) | Settlement (actual) recalculation pulls `customs_duties_egp` from the consultation **estimate**. | BE09-T03 |
| BE67-F07 (BLOCKER) | `is_assessed` true on create without CL-02; negative components accepted on create / PUT. | BE67-T06 |
| F01-01 (FE BLOCKER) | Flutter consultation screen computes duties with invented rates and hard-coded agreements per country. | FE task in `phase-01-frontend-review.md` (+ ACC1-T05 server side) |
| BE67-F37, F41 (MINOR) | History shows NULL VAT as 14.0 / service fee as 1.0; multi request currency defaults to USD. | BE67-T21, T13 |

## 3. Tasks

### ACC1-T01: Freight converted at the freight currency's customs rate
- Title: Freight in a foreign currency uses its own customs rate, never the invoice rate
- Severity: BLOCKER (ACC1-F01)
- Depends on: BE67-T03 (the `_customs_rate(db, currency, on_date)` helper; if T03 is not merged yet, add the helper exactly as T03 step 1 describes)
- Schema/migration needed: no
- API contract change: yes. `POST /api/v1/customs-tariff/estimate-multi` response gains `freight_exchange_rate_used: Optional[Decimal]` and
  `freight_rate_source: Optional[str]` (`"invoice_currency" | "table" | "manual"`; None when freight is EGP or deemed). A foreign freight currency
  with no rate and no manual rate -> 422 `CT_CUSTOMS_RATE_MISSING` (code from BE67-T03). Before: silently the invoice rate.
  Flutter: `frontend/lib/features/customs_tariff/widgets/duty_calculator_dialog.dart` (l.31, 96, 1335-1338: stop defaulting the freight rate to the
  invoice rate / `50.7917`; send `freight_exchange_rate` only when the user typed it), `customs_tariff/models/customs_tariff_model.dart` (new fields, optional).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_customs_engine_freight_fx.py` (new)
- Steps:
  1. In `resolve_insurance_freight` (`service.py:447-488`) add parameters `invoice_currency: str` and `db: Session`, `on_date: date`
     (or pass a resolved `Decimal` rate from the caller; preferred: resolve in the caller and pass `freight_rate: Optional[Decimal]`).
  2. In `estimate_multi_item_customs_duty_service` before step 1 (`:603`): if `freight_currency` is not EGP and `freight_foreign_amount > 0`:
     - `freight_currency.upper() == request.currency.upper()` -> rate = `effective_exchange_rate`, source `"invoice_currency"`;
     - else if `request.freight_exchange_rate` and > 0 -> that rate, source `"manual"`;
     - else -> `_customs_rate(db, freight_currency, on_date)[0]`, source `"table"` (422 when missing).
  3. In `resolve_insurance_freight` remove the fallback `else exchange_rate` at `:478`; use the passed rate.
  4. Add the two response fields to `MultiItemCustomsBreakdown` (`schemas.py:483`) with default None.
- Acceptance criteria: an EUR invoice with USD freight and no `freight_exchange_rate` uses the USD customs rate of the estimate date; with no USD
  rate row the call returns 422; a USD invoice with USD freight keeps using the invoice rate.
- Tests to add (`tests/unit/test_customs_engine_freight_fx.py`, scratch `DATABASE_PATH`):
  - Tariff HS `8471.30.00`: duty 10, VAT 14, schedule 0, development 0, import fee 0, service fee 1, valid on 2026-06-01. Customs rate row USD 50.00 dated 2026-05-30.
    Request: `currency="EUR"`, `exchange_rate=55`, one line `value_fc=20000`, `insurance_egp=27500`, `has_insurance_document=True`,
    `freight_currency="USD"`, `freight_foreign_amount=2000`, `has_freight_document=True`, no `freight_exchange_rate`, `estimate_date=2026-06-01`, no fee codes.
    Assert `freight_egp == 100000.00`, `lines[0].cif_value_egp == 1227500.00`, `total_duty_egp == 122750.00`, `total_vat_egp == 189035.00`,
    `total_customs_service_fee_egp == 12275.00`, `items_taxes_total_egp == 324060.00`, `freight_rate_source == "table"` (today: 110000.00 / 326700.00).
  - Same request with `freight_exchange_rate=51` -> `freight_egp == 102000.00`, source `"manual"`.
  - No USD rate row -> 422, `detail.code == "CT_CUSTOMS_RATE_MISSING"`.
  - `currency="USD"`, `exchange_rate=50`, freight 2,000 USD -> `freight_egp == 100000.00`, source `"invoice_currency"`.
- Out of scope: deemed freight / insurance policy (ACC1-T03), the currency service fallback (BEX-T07).

### ACC1-T02: Line CIF allocation that reconciles
- Title: One allocation routine: gross CIF, dutiable CIF, exact remainder
- Severity: CRITICAL (ACC1-F02)
- Depends on: CTO Q1 for `value_without_payment_fc` (implement with it treated like `exempted_value_fc` = not dutiable, as today, unless Q1 says otherwise)
- Schema/migration needed: no
- API contract change: yes. Request: a line with `exempted_value_fc + value_without_payment_fc > value_fc` -> 422 (Arabic: "القيمة المعفاة والقيمة بدون دفع أكبر من قيمة الصنف.").
  Response (additive): `MultiItemCustomsBreakdown.cif_total_egp`, `dutiable_cif_total_egp`; `MultiItemCustomsLineBreakdown.gross_cif_value_egp`.
  `cif_value_egp` keeps its meaning (dutiable CIF of the line); values change for exempted lines and the declared-CIF path.
  Flutter: `customs_tariff/models/customs_tariff_model.dart` (optional new fields), `duty_calculator_dialog.dart` (show `cif_total_egp` instead of summing).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_customs_engine_allocation.py` (new)
- Steps:
  1. `schemas.py:394-405`: add a `model_validator(mode="after")` on `MultiItemCustomsEstimateLine`: exempted + unpaid <= value_fc, else ValueError (422).
  2. `service.py`: add `_allocate(total: Decimal, weights: List[Decimal]) -> List[Decimal]` (2-dp shares, largest-remainder so `sum == _round(total)`).
  3. Replace `:698-705`: `alloc = _allocate(total_insurance_freight_packaging_egp, [l.value_fc for l in lines])`;
     gross line CIF = `_round(line.value_fc * rate) + alloc[i]`, or with `cif_declared_total_egp` > 0: `_allocate(cif_declared_total_egp, values)[i]`;
     `taxable_fraction = (value_fc - exempted - unpaid) / value_fc`; `cif_line_egp = _round(gross * taxable_fraction)`.
  4. Keep the rest of the line math on `cif_line_egp` (unchanged formulas). Sum `gross` into `cif_total_egp`, `cif_line_egp` into `dutiable_cif_total_egp`.
- Acceptance criteria: line CIFs add up exactly to FOB(EGP) + packaging + insurance + freight (or to the declared total); an exempted value never
  creates tax on freight alone; negative CIF is impossible.
- Tests to add (`tests/unit/test_customs_engine_allocation.py`; tariff duty 10, VAT 14, service fee 1, others 0; `currency="EGP"`, `exchange_rate=1`,
  `has_*_document=True`, no fee codes):
  - Lines A 60,000 (`exempted_value_fc=60000`) and B 40,000; insurance 5,000, freight 10,000 -> A `cif_value_egp == 0.00`, `duty_egp == 0.00`, `vat_egp == 0.00`,
    `customs_service_fee_egp == 0.00`, `gross_cif_value_egp == 69000.00`; B `cif_value_egp == 46000.00`, `duty_egp == 4600.00`, `vat_egp == 7084.00` ((46000+4600) x 0.14),
    `cif_total_egp == 115000.00` (today A is 9000.00 with duty 900.00, VAT 1386.00).
  - Same lines with `cif_declared_total_egp=100000` -> A `cif_value_egp == 0.00`, B `== 40000.00` (today A 60000.00, duty 6000.00).
  - `currency="USD"`, `exchange_rate=50`, 3 lines x `value_fc=1000`, insurance 50, freight 50 -> CIFs `[50033.33, 50033.33, 50033.34]`, `cif_total_egp == 150100.00`.
  - Line `value_fc=1000`, `exempted_value_fc=1500` -> 422.
- Out of scope: the legal semantics of `value_without_payment_fc` (Q1), `EXEMPTIONS_REGISTRY` (BE67-T13).

### ACC1-T03: One insurance / freight rule for every server estimate
- Title: `simulate-file` and the consultation re-estimation build CIF the same way
- Severity: MAJOR (ACC1-F03)
- Depends on: CTO Q2 (deemed policy), BE01-T17, BE67-T04
- Schema/migration needed: no (deemed rates become `system_parameters` keys; if the keys do not exist, add them through the existing
  `modules/common/system_parameters.py` defaults mechanism; values from Q2, never literals in services)
- API contract change: yes (values only). Both `POST /customs-tariff/simulate-file/{id}` and `POST /customs-consultation/recalculate` report
  `insurance_source` / `freight_source` (`"actual" | "deemed" | "missing"`). Flutter: `customs_consultation/widgets/recalculation_variance_comparison_card.dart`
  (show the source), `customs_tariff/providers/customs_tariff_provider.dart:198` (no change in call).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_consultation/service.py`, `modules/customs_consultation/schemas.py`,
  `tests/unit/test_estimate_cif_consistency.py` (new)
- Steps:
  1. In `customs_tariff/service.py` add `estimate_cif_inputs(db, fob_egp: Decimal, freight_egp: Optional[Decimal], insurance_egp: Optional[Decimal], on_date) -> (freight, insurance, freight_source, insurance_source)`
     implementing the Q2 policy (deemed rates read from `system_parameters`).
  2. `simulate_import_file_customs_duty_service` (`:1409-1447`) and `customs_consultation/service.py:_engine_taxes` (`:936-944`) both call it and pass the
     result to the engine with `has_*_document=True` and deemed rates 0 (the deemed amount is already resolved).
  3. Add `insurance_source` / `freight_source` to `CustomsRecalculationResponse` (`customs_consultation/schemas.py`) and to the simulation response.
- Acceptance criteria: for the same file, date, rate and freight / insurance inputs, `simulate-file` and the re-estimation return the same CIF and the
  same total taxes.
- Tests to add (`tests/unit/test_estimate_cif_consistency.py`): one PO line 20,000 USD, customs rate USD 50.00, tariff duty 10 / VAT 14 / service 1 / others 0,
  freight 50,000 EGP, no insurance.
  - If Q2 = "deemed 2.5% of FOB when no insurance": both paths CIF 1,075,000.00, duty 107,500.00, VAT 165,550.00, service 10,750.00, total 283,800.00.
  - If Q2 = "actual only, missing = 0 + warning": both paths CIF 1,050,000.00, duty 105,000.00, VAT 161,700.00, service 10,500.00, total 277,200.00, `insurance_source == "missing"`.
  - Assert the two paths are equal (today: 283,800.00 vs 277,200.00).
- Out of scope: the Flutter client engine (F01-01 FE task).

### ACC1-T04: Origin check and single-item engine use the same rules as the multi-item engine
- Title: Date-strict tariff in the origin check; packaging inside CIF in `/estimate`
- Severity: MAJOR (ACC1-F04)
- Depends on: BE67-T02 (shared agreement rate helper)
- Schema/migration needed: no
- API contract change: yes. `POST /check-duty-for-origin`: no tariff valid on `check_date` -> 422 (was: a rate from another period).
  `POST /estimate`: taxes computed on `cif_value + packaging_egp`; response gains `cif_base_egp`. Flutter: `customs_tariff/providers/customs_tariff_provider.dart:167`, `:308`;
  `customs_tariff/screens/hs_code_search_screen.dart:65` (label: CIF includes freight; show `cif_base_egp`).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_customs_tariff.py`
- Steps:
  1. `service.py:1208-1210`: `get_active_tariff_on_date(db, req.hs_code, target_date, strict=True)`; None -> `HTTPException(422, "لا يوجد بند تعريفة فعّال لكود {hs} بتاريخ {date}.")`; remove the `get_tariff_by_hs_code` fallback.
  2. `estimate_customs_duty_service`: `cif_base = request.cif_value + (request.packaging_egp or 0)`; use `cif_base` in `:227-235`; return `cif_base_egp=cif_base`.
  3. `schemas.py:318-323`: descriptions: `cif_value` = full CIF in EGP including freight and insurance; `freight*` fields "informational, not added to CIF".
- Acceptance criteria: as in the tests.
- Tests to add (`tests/unit/test_customs_tariff.py`):
  - Tariff duty 10 / VAT 14 / service 1, `cif_value=100000`, `packaging_egp=5000` -> `import_duty_amount == 10500.00`, `vat_amount == 16170.00`, `customs_service_fee_amount == 1050.00`, `cif_base_egp == 105000.00`
    (today 10000.00 / 15400.00 / 1000.00).
  - Tariff only from 2026-07-01, origin check with `check_date=2026-06-15` -> 422.
- Out of scope: agreement rate semantics (BE67-T02).

### ACC1-T05: The consultation's estimated duties come from the engine only
- Title: `estimated_duties_egp` is server-computed, never client input
- Severity: CRITICAL (ACC1-F05)
- Depends on: BE67-T03, BE67-T04 (the simulation must not invent data before it becomes the only writer); CTO Q3 for a manual override
- Schema/migration needed: no
- API contract change: yes. `POST/PUT /api/v1/customs-consultation...`: `estimated_duties_egp` in the body is ignored (kept in the schema as deprecated
  for one release so old clients do not 422). New `POST /api/v1/customs-consultation/{consultation_id}/estimate-duties` (permission `customs_consultation.manage`,
  body = `ImportFileCustomsSimulationRequest` minus `save_to_consultation`) returns `ImportFileCustomsSimulationResponse` and stores
  `grand_total_payable_egp` in `estimated_duties_egp`. Flutter: `customs_consultation/screens/customs_consultation_screen.dart:1522` (stop sending),
  `customs_consultation/providers/customs_consultation_provider.dart` (call the new endpoint), `customs_tariff/providers/customs_tariff_provider.dart:198`.
- Files to change: `modules/customs_consultation/repository.py`, `modules/customs_consultation/service.py`, `modules/customs_consultation/router.py`,
  `modules/customs_consultation/schemas.py`, `tests/unit/test_customs_consultation_estimate_owner.py` (new)
- Steps:
  1. `repository.py:311`: create with `estimated_duties_egp=0.0`; `update` (`:419-424`): add `"estimated_duties_egp"` to the `exclude` set.
  2. `schemas.py:224`, `:244`: `Field(..., description="Deprecated: ignored; computed by estimate-duties")`.
  3. `service.py`: `estimate_duties(db, consultation_id, request, modified_by)`: load the consultation (404), require `import_file_id` (400), call
     `customs_tariff.service.simulate_import_file_customs_duty_service(db, import_file_id, request.copy(update={"save_to_consultation": False}))`,
     set `estimated_duties_egp = float(breakdown.grand_total_payable_egp)`, `updated_by`, one commit, then `_sync_file_side_effects` (best effort, after the commit).
  4. Router: one thin route calling the service with `current_user.username`.
- Acceptance criteria: a PUT with `estimated_duties_egp=50000` leaves the stored value unchanged; after `estimate-duties` the stored value equals the
  engine's `grand_total_payable_egp`; the budget dependency (`seed_dependencies.py:41-50`) then reads the engine number.
- Tests to add (`tests/unit/test_customs_consultation_estimate_owner.py`): file with one PO line 20,000 USD, customs rate 50.00, tariff duty 10 / VAT 14 / service 1,
  request `freight_egp=50000`, `insurance_egp=25000` -> stored `estimated_duties_egp == 283800.00`; then PUT `{"estimated_duties_egp": 50000}` -> still 283800.00.
- Out of scope: manual override (Q3), the Flutter client engine removal (F01-01).

### ACC1-T06: Actual duty total reconciles with its components; the estimate comes from phase 1
- Title: CL-02 override needs a reason and keeps the difference; clearance estimate snapshotted from the consultation
- Severity: MAJOR (ACC1-F06)
- Depends on: BE67-T06; CTO Q8 (whether an override is allowed at all)
- Schema/migration needed: no (the override detail is stored in the existing JSON column `nafeza_assessment_json`)
- API contract change: yes. `FinalDutyAssessmentSubmit` gains `duty_override_reason: Optional[str]`; a claimed total different from the component sum
  by more than 0.01 without a reason -> 400 (Arabic: "إجمالي المطالبة يختلف عن مجموع البنود؛ يجب إدخال سبب الفرق."). `estimated_duty_total` on PUT after
  assessment -> 409. Flutter: `customs_clearance/widgets/final_duty_assessment_dialog.dart` (reason field when totals differ).
- Files to change: `modules/customs_clearance/service.py`, `modules/customs_clearance/schemas.py`, `modules/customs_clearance/validators.py`,
  `tests/unit/test_customs_clearance_variance_and_extraction.py`
- Steps:
  1. `schemas.py:140`: add `duty_override_reason: Optional[str] = Field(None, max_length=500)`.
  2. `validators.py`: `validate_duty_override(computed_total, claimed_total, reason)` using `MONEY_TOLERANCE`.
  3. `service.py:923-927`: call it; when an override is used set
     `record.nafeza_assessment_json = {**(json or {}), "override": {"components_total": computed_total, "claimed_total": actual_total, "difference": round(actual_total - computed_total, 2), "reason": reason}}`.
  4. Add `_estimate_from_consultation(db, import_file_id) -> float` (active consultation `estimated_duties_egp`, else 0). In `create_customs_clearance_service`
     (`:386`) and in CL-02 `write()` (`:933`): when `estimated_duty_total` is 0, set it from that helper before the variance.
  5. `update_customs_clearance_service`: `estimated_duty_total` in the data and `is_assessed(record)` -> 409 (same pattern as `:468-475`).
  New coded errors: register in `modules/common/system_messages.py` + `docs/system_message_codes.json` in the same change, or use plain Arabic
  `HTTPException` details and record the codes in `docs/plans/review-shared-needs.md`.
- Acceptance criteria: as in the tests.
- Tests to add (`tests/unit/test_customs_clearance_variance_and_extraction.py`):
  - Components duty 100,000 / VAT 154,000 / service 10,000 (sum 264,000), `actual_duty_total=250000`, no reason -> 400; with reason "Nafeza rounding" -> 200,
    `nafeza_assessment_json["override"]["difference"] == -14000.00`.
  - Consultation `estimated_duties_egp=283800`, clearance created with `estimated_duty_total=0`, CL-02 total 300,000 -> `estimated_duty_total == 283800.00`,
    `duty_variance_amount == 16200.00`, `duty_variance_percentage == 5.71`.
  - PUT `estimated_duty_total` on an assessed record -> 409.
- Out of scope: settlement row split (BE09-T03 / T04).

### ACC1-T07: `shipment_value_usd` is converted on the server
- Title: Import requirement USD value computed from value + currency
- Severity: MAJOR (ACC1-F07)
- Depends on: CTO Q7 (rate type and date); BE01-T18 (currency validated against the master)
- Schema/migration needed: no (existing rows are corrected on their next save)
- API contract change: yes. `shipment_value_usd` in the request is ignored; the response value is computed. Missing rate -> 409 `SETTLEMENT_FX_RATE_MISSING` (existing code).
  Flutter: `frontend/lib/features/import_requirements/screens/import_requirements_screen.dart:616` (stop sending), `models/import_requirement_model.dart:711`.
- Files to change: `modules/import_requirements/service.py`, `modules/import_requirements/schemas.py`, `tests/unit/test_import_requirements.py`
- Steps:
  1. `service.py`: `_usd_value(db, value, currency, on_date) -> float`: `fx = SettlementFx(db, "commercial")` (rate type per Q7); `round(value * fx.rate(currency, on_date) / fx.rate("USD", on_date), 2)`; USD -> value.
  2. In `create_assessment_service` (`:338`) and `update_assessment_service` (`:359`, when `shipment_value` or `currency` changes) set `shipment_value_usd` from it; `on_date = cairo_today()`.
  3. `schemas.py:64`, `:142`: description "ignored; computed by the server".
- Acceptance criteria / tests (`tests/unit/test_import_requirements.py`): commercial rates EUR 55.00, USD 50.00 on today; create with `shipment_value=10000`, `currency="EUR"`, `shipment_value_usd=10000`
  -> stored `shipment_value_usd == 11000.00`; `currency="EGP"`, 500,000 -> `10000.00`; no EUR rate -> 409.
- Out of scope: prefill per currency (BE01-T06).

### ACC1-T08: Tariff save with agreements keeps a valid history
- Title: No back-dated version overlap, no hard delete of agreements
- Severity: CRITICAL (ACC1-F08)
- Depends on: BE67-T08, BE67-T11 (commit placement)
- Schema/migration needed: no
- API contract change: yes. `POST /api/v1/customs-tariff/with-agreements` with `update_date < active version effective_from` -> 422
  ("تاريخ السريان الجديد يسبق بداية الإصدار الحالي للبند."). Flutter: the save caller of `/with-agreements` (grep `with-agreements` in `frontend/lib/features/customs_tariff`) shows the message.
- Files to change: `modules/customs_tariff/repository.py`, `modules/customs_tariff/service.py`, `tests/unit/test_customs_tariff_agreements.py`
- Steps:
  1. `service.save_tariff_with_agreements_service`: before the repository call, if `existing_before` and `eff_date < existing_before.effective_from` -> 422.
  2. `repository.py:259-262`: replace `.delete()` with: load the rows, set `effective_to = eff_date - timedelta(days=1)` on each, return them so the service
     writes them into the audit `old_data` (list of `{agreement_name, reduction_type, reduction_percentage, preferential_duty_rate, origin_countries}`).
  3. Audit `performed_by` = acting user (router passes `current_user.username`; coordinate with BE67-T12 / F18).
- Acceptance criteria / tests (`tests/unit/test_customs_tariff_agreements.py`):
  - Version duty 30 from 2026-09-01; save duty 20 with `update_date=2026-08-01` -> 422; `POST /estimate` dated 2026-09-15, CIF 1,000 -> duty 300.00 (unchanged).
  - Same-day save twice with different agreements -> the first day's agreements still exist with `effective_to = today - 1 day`; an estimate today applies only the second set.
- Out of scope: versioning on PUT / verify (BE67-T08).

### ACC1-T09: Version comparison diffs every rate
- Title: Tariff version diff covers VAT, schedule tax and all fees
- Severity: MAJOR (ACC1-F09)
- Depends on: BE67-T08 (`RATE_FIELDS`)
- Schema/migration needed: no
- API contract change: no (more `diff_items`, `modified_count` changes). Flutter consumer `customs_tariff` parse-text preview (no code change).
- Files to change: `modules/customs_tariff/service.py`, `tests/unit/test_customs_tariff.py`
- Steps: in `compare_tariff_versions_service` (`:925-941`) loop over `RATE_FIELDS` with an Arabic label map (`customs_duty_rate`: "ضريبة الوارد",
  `vat_rate`: "ضريبة القيمة المضافة", `schedule_tax_rate`: "ضريبة الجدول", `development_fee_rate`: "رسم التنمية", `import_fee_rate`: "رسم الوارد",
  `customs_service_fee_rate`: "رسم الخدمات الجمركية"); a field missing from the new data is not a change.
- Acceptance criteria / tests: existing VAT 14, duty 10; new data VAT 10, duty 10 -> `modified_count == 1`, one item whose `old_value_desc == "14.00%"` and
  `new_value_desc == "10.00%"` (today 0 items); new data equal -> 0.
- Out of scope: agreement diff logic.

### ACC1-T10: Derived Nafeza fee codes in dependency order
- Title: Topological evaluation of derived fee codes
- Severity: MAJOR (ACC1-F10)
- Depends on: BE67-T10 (same function)
- Schema/migration needed: no
- API contract change: yes (values; new 422 `CT_FEE_CODE_FORMULA_INVALID` on a cycle / unknown base code). Flutter: `duty_calculator_dialog.dart` shows the message.
- Files to change: `modules/customs_tariff/service.py`, `tests/unit/test_customs_engine.py`
- Steps: in `calc_collection_fees` (`:536-541`) build the graph of derived codes; evaluate with Kahn's algorithm; a base code not present in the active
  fee codes or a cycle -> `HTTPException(422, detail={"code": "CT_FEE_CODE_FORMULA_INVALID", "message": "...", "fee_code": code})` (register the code, or record it in `review-shared-needs.md`).
- Acceptance criteria / tests: fee codes `77` flat 500 (id 1), `394` derived 14% of `77,392` (id 2), `392` derived 10% of `77` (id 3) ->
  `by_code["392"] == 50.0`, `by_code["394"] == 77.0` (today 70.0), `grand_total == 627.0`; a cycle `A -> B -> A` -> 422.
- Out of scope: which codes count as taxes (BE67-T10).

### ACC1-T11: Calculator sends "not decided" as null
- Title: Tri-state exemption flag from the duty calculator
- Severity: MAJOR (ACC1-F11)
- Depends on: none
- Schema/migration needed: no
- API contract change: no (backend already accepts `null`; document the tri-state in `schemas.py:405` description: null = look up agreements, true = user confirms conditions, false = user confirms not met).
- Files to change: `frontend/lib/features/customs_tariff/widgets/duty_calculator_dialog.dart`, `modules/customs_tariff/schemas.py` (description only)
- Steps: line state `is_exemption_conditions_met` starts `null`; payload `'is_exemption_conditions_met': m['is_exemption_conditions_met']` (bool?) instead of `== true`; the toggle offers three states.
- Acceptance criteria: a line with origin JO under a GAFTA full-exemption agreement, untouched toggle -> response `preferential_agreement_applied` is the agreement name and duty 0.
- Tests to add: Flutter widget/unit test on the payload builder (null when untouched); backend: `tests/unit/test_po_country_of_origin_and_customs_exemption.py` case
  `is_exemption_conditions_met=None`, agreement full exemption, CIF 1,000,000, duty 30, VAT 14 -> `duty_egp == 0.00`, `vat_egp == 140000.00`.
- Out of scope: `true` semantics (BE67-T13).

### ACC1-T12: Clear totals in engine and simulation responses
- Title: `goods_value_egp` / `cif_total_egp`, fee source, summary label, safe consultation code
- Severity: MINOR (ACC1-F12, F15)
- Depends on: ACC1-T02 (adds `cif_total_egp`), BE01-T03 (code generator), CTO Q6
- Schema/migration needed: no
- API contract change: yes (additive): `MultiItemCustomsBreakdown.goods_value_egp`, `computed_nafeza_fees_egp`, `manual_additional_fees_egp`; `fob_value_egp` description "goods + packaging".
  Flutter: `customs_tariff/models/customs_tariff_model.dart` (optional fields).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_pl07_customs_duty_simulation.py`
- Steps: `goods_value_egp = _round(invoice_total_value_fc * rate)`; return both fee amounts (replace-vs-add per Q6, default unchanged = replace); summary at `:1545`
  "إجمالي الضرائب والرسوم" instead of "إجمالي سيف"; consultation code at `:1476` from `CustomsConsultationRepository.generate_consultation_code(db)`.
- Acceptance criteria / tests: invoice 10,000 USD at 50, packaging 5,000, insurance 5,000, freight 10,000 -> `goods_value_egp == 500000.00`, `fob_value_egp == 505000.00`,
  `cif_total_egp == 520000.00`; a soft-deleted consultation coded `CONS-<file>` does not 500 the simulation.
- Out of scope: other simulation defaults (BE67-T04).

### ACC1-T13: Recalculation FOB scaling and source currency
- Title: Scaled items sum to the new FOB; no invented scenario currency
- Severity: MINOR (ACC1-F13)
- Depends on: none
- Schema/migration needed: no
- API contract change: no (values; a seeded dependency with an unknown aggregation is rejected at seed time).
- Files to change: `modules/recalculation/service.py`, `modules/recalculation/seed_dependencies.py`, `tests/unit/test_recalculation_engine.py`
- Steps: `:319-329` scale `fob_total_egp` of every item, recompute `fob_unit_egp` only when qty > 0, put the rounding remainder on the last item;
  `:154` currency None -> raise `SourceRateMissing(None, on_date)`; `:230` unknown function -> `ValueError` caught by the seed / apply as 400.
- Acceptance criteria / tests: items `[{fob_total_egp: 600, qty: 0}, {fob_total_egp: 400, qty: 10}]`, new total 1,100 -> `[660.00, 440.00]` (today `[600, 440]`), sum 1,100.00; scenario item with no `quotation_currency` -> dependency skipped with the rate-missing status.
- Out of scope: estimate-vs-actual mapping (BE09-T03).

### ACC1-T14: Decimal until the response and a written rounding policy
- Title: Money math in Decimal; rounding policy documented and tested
- Severity: MINOR (ACC1-F14)
- Depends on: CTO Q5, Q9
- Schema/migration needed: no (Float -> Numeric columns only after Q9, separate task)
- API contract change: no (same JSON number types)
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_consultation/service.py`, `docs/phase_06_customs_preparation.md` (rounding section), `tests/unit/test_customs_engine.py`
- Steps: `calc_collection_fees` keeps `Decimal` internally and converts once when building the dict; `_Side` sums `Decimal(str(x))` and rounds the totals once;
  document: "each tax per line, ROUND_HALF_UP to 0.01; totals = sum of rounded lines" (or the Q5 decision).
- Acceptance criteria / tests: fee codes 0.10 + 0.20 flat -> `grand_total == 0.30` exactly; a 3-line estimate whose line duties are 33.335 each -> each 33.34, total 100.02 (documents per-line rounding).
- Out of scope: column type migration.

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| `POST /customs-tariff/estimate-multi`: `freight_exchange_rate` | Send only when the user typed it; never default to the invoice rate or `50.7917`. New response `freight_exchange_rate_used`, `freight_rate_source`; 422 `CT_CUSTOMS_RATE_MISSING`. | `customs_tariff/widgets/duty_calculator_dialog.dart:31,96,1335-1338`, `customs_tariff/models/customs_tariff_model.dart` |
| `estimate-multi`: line `is_exemption_conditions_met` | Send `null` until the user decides (tri-state). | `duty_calculator_dialog.dart:1314` |
| `estimate-multi`: new `cif_total_egp`, `dutiable_cif_total_egp`, `goods_value_egp`, line `gross_cif_value_egp`, `computed_nafeza_fees_egp`, `manual_additional_fees_egp`; 422 when exempted + unpaid > value | Display these totals instead of rebuilding CIF on the client (`fob + insurance + freight` at `duty_calculator_dialog.dart:110` must go; preview deemed insurance on FOB is also a client formula). | `duty_calculator_dialog.dart`, `customs_tariff_model.dart` |
| `POST /customs-tariff/estimate`: `cif_base_egp`; packaging now inside CIF | Label "CIF includes freight and insurance"; show `cif_base_egp`. | `customs_tariff/screens/hs_code_search_screen.dart:65`, `customs_tariff_provider.dart:167` |
| `POST /customs-tariff/check-duty-for-origin` | 422 when no tariff on the date. | `customs_tariff_provider.dart:308` |
| Consultation `estimated_duties_egp` | Stop sending (ignored); call new `POST /customs-consultation/{id}/estimate-duties`; remove the client tax engine (F01-01). | `customs_consultation/screens/customs_consultation_screen.dart:760-1080,1522`, `customs_consultation/providers/customs_consultation_provider.dart` |
| Re-estimation `insurance_source` / `freight_source` | Show the source next to CIF. | `customs_consultation/widgets/recalculation_variance_comparison_card.dart`, `customs_consultation_model.dart` |
| CL-02 `duty_override_reason` | Required when the claimed total differs from the components; 409 on editing the estimate after assessment. | `customs_clearance/widgets/final_duty_assessment_dialog.dart` |
| Import requirements `shipment_value_usd` | Stop sending; display the server value. | `import_requirements/screens/import_requirements_screen.dart:616`, `models/import_requirement_model.dart:711` |
| `POST /customs-tariff/with-agreements` | 422 on a back-dated `update_date`. | `customs_tariff` save-with-agreements caller |

## 5. Open questions for the CTO

1. **Q1 Unpaid / exempted value:** is `value_without_payment_fc` (free-of-charge goods) dutiable at customs value (Egyptian practice usually yes), or excluded as today? Is `exempted_value_fc` excluded from duty only, or from VAT and fees too?
2. **Q2 Deemed insurance / freight for estimates:** when no insurance (or freight) document exists, use deemed 2.5% / 2% of FOB (`simulate-file` today), 0 with a warning (re-estimation today), or 0.5% / 1% of C&F (Flutter consultation today)? Base FOB with or without packaging? Values must live in `system_parameters`.
3. **Q3 Manual estimate:** may a user override the engine's `estimated_duties_egp` (e.g. broker's figure)? If yes: which permission, and keep both numbers (engine + manual + reason)?
4. **Q4 VAT and WHT in landed cost:** DOMAIN_RULES section 3 adds import VAT to landed cost, and CL-02 adds WHT (advance commercial-profits tax) to the duty total. For a VAT-registered importer both are recoverable / creditable and normally excluded from inventory cost. Keep them in landed cost, or post them to receivable accounts?
5. **Q5 Rounding:** each tax per line ROUND_HALF_UP to 0.01 then summed (today), or per declaration, or to the whole pound as on the Nafeza claim?
6. **Q6 Additional fees:** should a manual `additional_fees_egp` replace the computed Nafeza fee codes (today) or be added to them?
7. **Q7 USD value of import requirements:** commercial or customs rate, and which date (assessment date, PO date, invoice date)?
8. **Q8 CL-02 override:** is a claimed total different from the component sum allowed at all (Nafeza total is authoritative), and with what tolerance?
9. **Q9 Money column types:** migrate `Float` money columns of `customs_clearance_records` and `customs_consultation_sessions` (and quote items) to `Numeric(14,2)`? This needs an Alembic migration with backfill and touches every consumer.
