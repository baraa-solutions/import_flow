# Accounting (financial approval, payments, FX, final settlement): backend review

Status: 2026-10-05, static review only (grep / read; no pytest, no `import main`, no DB access). Lens: money math
(formulas, order of operations, rounding, FX, allocation, reconciliation, estimate vs actual, GL posting). Workflow,
auth and transaction findings of the same modules are owned by the sibling reviews and are **not** repeated here:
`be-02-review.md` (BE02-F01..F26), `be-09-review.md` (BE09-F01..F22), `be-cross-review.md` (BEX-F02 currencies
routes without `master_data.edit`, BEX-F03 hard-coded `fallback_rates` in `currencies/service.py:170-189`, BEX-F27
`ExchangeRateCreate.created_by` from the body). Items verified fixed by `phase-02-quality-plan.md` / `phase-09-quality-plan.md`
(FS-01 canonical rows, FS-02 no literal FX in settlement, FS-07 estimate parameters, FS-08 reconciliation reported,
RC-01 single adjustment row, RC-03 rate missing -> skip) are not re-reported.

| File | Lines | Depth |
|---|---|---|
| `modules/financial_settlement/service.py` | 2645 | full for l.1-730 (engine, FX, create/PUT), 730-1230 (PL-08 estimate math), 1288-1883 (CLO-01 aggregation math), 2005-2530 (CLO-02 math, approve write) |
| `modules/financial_settlement/odoo_export_service.py` | 501 | full (journal math and classifier) |
| `modules/financial_settlement/schemas.py`, `validators.py` | 413 / 122 | input schemas, Odoo config, tolerance |
| `modules/financial_approval/service.py` | 2072 | l.370-830 (payment, SWIFT receipt, paid, clone), 1082-1400 (budget prefill, variance math) |
| `modules/financial_approval/repository.py`, `schemas.py`, `validators.py`, `model.py` | 481 / 429 / 236 / 293 | money fields, rate defaults, EGP derivation |
| `modules/currencies/*` | 728 | full |
| `modules/recalculation/service.py` | 975 | l.50-340 (fetchers, aggregation, apply to settlement), 474-485, 650-662, 836-850 |
| `modules/recalculation/seed_dependencies.py` | 161 | settlement seeds |
| Cross-module facts | - | `customs_clearance/service.py:1380-1480` (CL-05 net payable, settlement snapshot), `customs_tariff/service.py:575-845` (multi-item totals), `purchase_orders/model.py:21-44,91-110,218-245`, `purchase_orders/service.py:890-1090`, `common/enum_codes.py:100-110,577-585,874-937` |
| Flutter | - | `financial_settlement/screens/landed_cost_comparison_screen.dart`, `services/landed_cost_comparison_export_service.dart`, `widgets/settlement_form_dialog.dart`, `models/financial_settlement_model.dart`, `financial_approval/screens/financial_approval_screen.dart` (l.78-92, 186-197, 625-645, 2195-2235), `services/financial_export_service.dart` (l.20-50, 485-500, 1015-1080) |
| Business docs | - | `.agents/rules/DOMAIN_RULES.md` §2-3, `docs/phase_02_financial_approval.md`, `docs/phase_09_financial_settlement.md` (BP-036..039) |

Not audited: SWIFT MT103 parser regexes, `customs_tariff` per-line duty math (owned by BE67), PDF/Excel layout code.

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 1 |
| CRITICAL | 3 |
| MAJOR | 14 |
| MINOR | 5 |

Top points:

1. **Partially shipped POs are costed in full on every file (BLOCKER, ACC2-F01).** The settlement items, the CLO-02
   item lines, the PL-08 estimate and the recalculation FOB all read the **whole** PO; `po_shipment_allocations`
   (LOG-PART-004) is never used. A PO split over two files puts the full FOB into both files' landed cost.
2. **Clearance categories land in the wrong bucket and the wrong GL account (CRITICAL, F02/F03).** Keyword matching on the
   legacy Arabic label sends "Port Dues & Wharfage (نولون ...)" and "Stevedoring (... الشحن ...)" to **Freight**
   (allocated by CBM), and the Odoo journal credits "Clearance / Customs Broker Fees" to the **customs authority**
   account 210500 and port dues to the **freight** account 210200.
3. **The Flutter comparison screen divides EGP by a foreign amount (CRITICAL, F04):** variance % = (EGP total -
   `estimated_cost` in USD) / USD. 10,000 USD estimate vs 500,000 EGP FOB shows +4,900 %.
4. **Three FOB definitions that never reconcile (MAJOR, F08/F09):** CLO-02 header = commercial invoices at the invoice-date
   commercial rate; CLO-02 items = PO lines at the PO rate; recalculation = PO header at the PO rate. Approve stores a
   header and items that differ, and a later recalculation rewrites the approved FOB.
5. **The actual cost ignores what was really paid (MAJOR, F10/F11/F12):** goods are "PAID" because the file has a SWIFT
   number (a 30,000 USD transfer against 50,000 USD is still Paid), the bank debit in EGP is never captured, the
   payment-request EGP amount trusts any client rate (an EGP request at rate 48.75 is booked x48.75), and nothing stops
   cumulative payments above the PO value.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| ACC2-F01 | BLOCKER | `financial_settlement/service.py:410-427` (`_purchase_orders_of_file`), `:434-456` (create items), `:2142-2160` (CLO-02 items), `:768-811` (PL-08 lines); `recalculation/service.py:170-209`; `purchase_orders/model.py:218-228` | PO lines are taken in full for every import file that links the PO (`import_file_id` or `po_ids`). `POShipmentAllocation(import_file_id, po_item_id, shipped_quantity, shipped_amount_fob)` exists for partial shipments but no landed-cost path reads it. Example: PO 1,000 units x 10 USD, PO rate 50 -> 500,000 EGP; file A ships 400 (allocation), file B ships 600; both files list the PO. Settlement A: FOB 500,000 (correct 200,000); file A expenses 60,000 are spread over 1,000 units -> 60 EGP/unit instead of 150 EGP/unit; the same 500,000 FOB is costed again in file B. | One helper `file_po_line_shares(db, imp)` returning per line `(line, qty_share, ratio)`: item-level allocations of this file give the shipped qty; a PO-level allocation of this file gives `ratio = shipped_amount_fob / total_amount_fob`; a PO with allocations but none for this file is excluded (message); a PO without allocations stays 100 %. Used by create, CLO-02, PL-08, recalculation. Task ACC2-T01. |
| ACC2-F02 | CRITICAL | `financial_settlement/service.py:100-122` (`actual_expense_bucket`), `:2103-2106`, `:2282-2289`, `:2409-2428`; `common/enum_codes.py:578-584` | Broker categories are matched through their legacy label, then by substring. `PORT_DUES_WHARFAGE` -> "Port Dues & Wharfage (نولون ورسوم الميناء والرصيف)" contains "نولون" -> **Freight**; `STEVEDORING_HANDLING` -> "(مصاريف العتالة والشحن والتفريغ)" contains "شحن" -> **Freight**; `INSPECTION_WEIGHING` and `LABORATORY_TESTING` -> Other & Admin. Freight is allocated by CBM, so item costs change, the Freight/Clearance category variances are wrong, and approve stores the rows with category "Freight". Example: items A (FOB 90,000, 1 CBM) and B (FOB 10,000, 9 CBM), port dues 10,000: today A 1,000 / B 9,000 (CBM); correct as Clearance & Port with the default Value-Based rule: A 9,000 / B 1,000. | Code-first classification: an explicit `CLEARANCE_CATEGORY_BUCKET` map from the `CLEARANCE_EXPENSE_CATEGORY` code to the bucket; keywords only for free text. Task ACC2-T02. |
| ACC2-F03 | CRITICAL | `financial_settlement/odoo_export_service.py:30-54`, `:151-179`; rows written by `customs_clearance/service.py:1388-1404` | `classify_odoo_cost_category` tests "customs" before "broker/clearance" and "نولون" before anything else. Snapshot row "Clearance / Customs Broker Fees (أتعاب التخليص الجمركي)" -> **Customs** -> credit 210500 (customs authority) instead of 210300 (broker); "Clearance / Port Dues & Wharfage (نولون ...)" -> **Freight** -> 210200. Rows stored by approve inherit F02 ("Freight" for port dues). Example: broker invoice 8,000 + port dues 3,000: today 210500 Cr 8,000, 210200 Cr 3,000; correct 210300 Cr 11,000. The journal still balances, so `ensure_journal_balanced` does not catch it. | Same code-first map as F02 (one table in `financial_settlement/model.py` shared by both classifiers); a `Clearance / ` prefix maps to Clearance unless its code maps to Demurrage. Task ACC2-T02. |
| ACC2-F04 | CRITICAL | Flutter `financial_settlement/screens/landed_cost_comparison_screen.dart:89`, `:324-325`, `:371`, `:580-584`; `services/landed_cost_comparison_export_service.dart:35-36` | The screen holds its own variance formula and compares the settlement EGP totals with `import_files.estimated_cost`, which is in `estimated_cost_currency` (e.g. USD). Example: estimated_cost 10,000 USD, FOB 500,000 EGP -> FOB variance (500,000-10,000)/10,000 = +4,900 %; landed 600,000 -> +5,900 %. The same numbers go to the exported file. | Use the backend numbers: `import_files.actual_landed_cost_variance_egp/pct` (set by approve) or the CLO-02 calculation response (`estimated_total_*`, `*_variance_pct`); no client formula. Task ACC2-T16. |
| ACC2-F05 | MAJOR | `financial_settlement/service.py:1470-1508`, `:2092-2106`, `:2112-2137`; compare create path `:479-518` | CLO-01 emits one "Customs Duties & Taxes" row per declaration for the whole assessed total (duty + VAT + schedule + development + service + WHT + lab). `actual_expense_bucket` puts it all in **Customs Duty**; **VAT & Taxes** is always 0 actual, while the estimate splits duty vs VAT. The create path already splits components (`_customs_duty_rows`). Example: assessed 250,000 = duty 100,000 + VAT 150,000; estimate duty 100,000, VAT 150,000 -> Customs Duty variance +150,000 (+150 %), VAT & Taxes -150,000 (-100 %); correct: both 0. | Carry the components on the aggregated customs row (additive `components`), split them into buckets in CLO-02 and store one settlement row per component at approve (same categories as `DUTY_COMPONENT_CATEGORIES`). Task ACC2-T03. |
| ACC2-F06 | MAJOR | `financial_settlement/service.py:1600-1606`, `:1690`, `:1732-1733`, `:1767`, `:1837-1847` | Paid amounts are on the **net payable** basis (broker: amount + VAT - WHT, `customs_clearance/service.py:1457`; transport: amount - WHT) while `amount_egp` / `total_amount_egp` are gross of WHT and exclude VAT. `settlement_readiness_percent = total_paid / total_amt` is therefore below 100 for every fully paid file with WHT and above 100 with broker VAT. Example: goods 100,000 paid + broker 50,000 with stored WHT 1,500 (net 48,500, Paid) -> readiness 148,500 / 150,000 = 99.0 % although nothing is owed. BE09-T13 (confirm gate "readiness < 100 -> 409") would then block every such file. | Readiness on one basis: `paid / net_payable`; add `total_net_payable_egp`; party summary gets `net_payable_egp`. Must land before BE09-T13. Task ACC2-T04. |
| ACC2-F07 | MAJOR | `financial_settlement/schemas.py:23-41` (`currency="USD"`, `amount_egp` free), `service.py:259-262`, `:459-476`; `odoo_export_service.py:141-143`, `:202-205`; `validators.py:19` | Client expense rows: when `amount_egp` is non-zero it is used as is, never checked against `amount_fx x exchange_rate`; the currency defaults to "USD"; EGP amounts are not rounded per row. Example 1: `{amount_fx: 1000, currency: "USD", exchange_rate: 50, amount_egp: 10}` -> landed cost +10 EGP instead of +50,000. Example 2: four rows of 100.004 EGP: engine `total_expenses` = round(400.016) = 400.02; journal credits 4 x 100.00 = 400.00 -> difference 0.02 > tolerance 0.01 -> CSV/Excel export 409 for valid data. | Server derives `amount_egp = round(amount_fx x rate, 2)` for foreign rows (EGP rows: rate 1, `amount_egp = amount_fx` when > 0), currency required, every stored `amount_egp` rounded to 2 so engine and journal sum the same cents. Task ACC2-T05. |
| ACC2-F08 | MAJOR | `financial_settlement/service.py:2081-2089`, `:2152-2177`, `:2369-2372`, `:2490-2522`; `recalculation/service.py:170-209`, `seed_dependencies.py:86-90`; PL-08 `:786-788`, `:867-880` | FOB is defined five ways: create = sum(qty x unit_price) x PO rate; CLO-02 header = commercial invoices x invoice-date commercial rate (fallback: the **PL-08 estimate** or `estimated_cost`); CLO-02 items = sum(total_price) x PO rate; PL-08 = sum(total_price) x customs rate; recalculation = PO `total_amount_fob` x PO rate. Approve stores a header and items that do not reconcile (FS-08 only reports the gap), and stores an estimate as "actual" FOB when no goods invoice exists. Example: PO 10,000 USD at PO rate 48.00 = 480,000; invoice 10,000 USD at 50.00 = 500,000; expenses 100,000 -> header 600,000, items 580,000, `reconciliation_difference_egp` 20,000; then recalculation preview FOB 480,000 vs 500,000, apply rescales the items and the approved landed cost becomes 580,000. | Q1 decides the FOB basis. Safe default (invoice basis for actual): CLO-02 scales item FOB to the header FOB (largest remainder to the cent) so items sum to the header; approve refuses an estimated FOB (409 `SETTLEMENT_ACTUAL_FOB_MISSING`). Task ACC2-T06. |
| ACC2-F09 | MAJOR | `financial_settlement/service.py:2316`, `:2431-2453` (stored `fob_unit_egp` rounded to 2), engine `:237-240` (`fob_total = qty x fob_unit`) | Approve stores `fob_unit_egp` rounded to 2 decimals; every later engine run (recalculation on an Approved settlement, allowed by RC-02) recomputes `fob_total = qty x rounded unit`. Example: qty 100,000, FOB total 12,345.60 -> unit 0.123456 stored as 0.12 -> engine FOB 12,000.00 (-345.60, -2.8 %), landed cost and markup change without any cost change. | Store the unrounded unit (`fob_total / qty`) in the canonical key; the rounded display value stays in the `actual_*` keys. Task ACC2-T06. |
| ACC2-F10 | MAJOR | `financial_approval/service.py:516-571`, `:678-693`; `financial_settlement/service.py:1334-1337`, `:1367-1370` | The actual cost and the payment status ignore the SWIFT money: (a) CLO-01 marks every goods invoice PAID when `imp.swift_no` is set; (b) a Deficit SWIFT still marks the request Paid; (c) the EGP actually debited by the bank is never stored, so the realised FX difference never reaches the settlement. Example: invoice 50,000 USD; SWIFT 30,000 USD (variance -20,000, Deficit) -> request Paid, file `swift_no` set, CLO-01 goods 50,000 USD = PAID, readiness 100 %, 20,000 USD still owed but invisible. | Q2. Schema: nullable `paid_amount_egp`, `paid_exchange_rate` on `payment_request_sessions`; CLO-01 goods paid = sum of Paid requests' transferred FC of the file, status by coverage (PAID / PARTIAL / UNPAID); additive `fx_difference_egp`. Task ACC2-T07. |
| ACC2-F11 | MAJOR | `financial_approval/repository.py:89`, `:211`; `schemas.py:49`; Flutter `financial_approval_screen.dart:194-195`, `:637-638` | `requested_amount_egp = requested_amount x exchange_rate` with a client rate that is never checked: an EGP request accepts any rate; Flutter shows and sends the rate rounded to 2 decimals (`toStringAsFixed(2)`), while rates are stored with 4. Example 1: 100,000 EGP request with rate 48.75 -> `requested_amount_egp` 4,875,000. Example 2: commercial rate 48.7523 -> 48.75 sent; 200,000 USD -> 9,750,000 instead of 9,750,460 (-460 EGP). | EGP currency: rate forced to 1.0 (422 `FA_EGP_RATE_NOT_ONE` when another value is sent); `requested_amount_egp` rounded to 2; Flutter shows/sends 4 decimals. Task ACC2-T08. |
| ACC2-F12 | MAJOR | `financial_approval/validators.py:218-236`; `service.py:388-402`; Flutter `financial_approval_screen.dart:83-91` | Nothing limits cumulative payments to the PO value: only one *open* request per type is enforced, so after a Paid advance a new one can be raised; `advance_percentage` is stored but never reconciled with `requested_amount`; the request currency is not checked against the PO currency. Example: PO 100,000 USD; advance 30 % Paid (30,000), new advance 80,000 Approved -> 110,000 USD committed (110 %). | 409 `FA_PAYMENT_EXCEEDS_PO` when sum(active, non-Rejected requests of the PO, same currency) + new > PO `total_amount_fob`; 422 when the currency differs from the PO; `advance_percentage` recomputed server-side. Q3 for an override. Task ACC2-T08. |
| ACC2-F13 | MAJOR | `financial_settlement/service.py:2213-2230`, `:2267-2289`; engine `:268-278`; PL-08 `:1105-1140`; doc `docs/phase_09_financial_settlement.md` BP-038 | Allocation deviates from BP-038: Demurrage & Storage uses the primary rule (Value by default) instead of CBM; freight is always CBM, also for air freight (doc: weight); there is no Quantity rule. A basis is used as soon as its **total** is > 0, so lines with a missing CBM / weight get 0. Example: items A (10 CBM) and B (CBM not entered), freight 20,000 -> A 20,000, B 0; B's unit landed cost is understated. | Use a basis only when every line has a value > 0, else fall back to Value-Based with message `ALLOCATION_BASIS_INCOMPLETE` (bucket, missing item codes); Demurrage & Storage -> Volume-Based; air vs sea per Q4. Task ACC2-T09. |
| ACC2-F14 | MAJOR | `financial_settlement/service.py:1288-1820`; estimate `:1030-1031`, `:1066-1086`; doc BP-036 items 7-8 | CLO-01 has no source for bank charges / Form 4 and for inspection / certificates (BP-036 items 7 and 8), while PL-08 always estimates them (defaults 2,500 + 2,000 EGP). Actual "Other & Admin" is 0 on every file and shows a systematic saving; the approved landed cost omits real bank charges. | Q5 (where bank charges come from). Meanwhile CLO-02 emits `ACTUAL_SOURCE_MISSING` (bucket, estimated_egp) when an estimated bucket has no actual source. Task ACC2-T14. |
| ACC2-F15 | MAJOR | `financial_settlement/service.py:993-1024`, `:1125-1136`, `:1181-1185`, `:1228`; `customs_tariff/service.py:810-819` | PL-08 totals use `items_taxes_total_egp` (duty + schedule + service + VAT + development + import fee + inspection), but the "VAT & Taxes" breakdown line has VAT + schedule + service only, and the item allocation adds development + import fee but not inspection. Example: duty 10,000, VAT 15,000, service 500, development 300, inspection 200 -> `total_customs_and_taxes_egp` 26,000; breakdown lines 10,000 + 15,500 = 25,500; `total_vat_and_fees_egp` 16,000 vs line 15,500; items' customs sum 25,800 -> sum(item totals) is 200 below `total_landed_cost_egp`. | "VAT & Taxes" line = total - duty; inspection fees allocated by value to the included lines; tests assert breakdown sum = `total_expenses_egp` and item sum = `total_landed_cost_egp` (+-0.01 per line). Task ACC2-T10. |
| ACC2-F16 | MAJOR | `financial_settlement/service.py:775`, `:818`, `:836`, `:1311`, `:1323`, `:2074` | Missing currencies become "USD" (estimate, CLO-01 goods invoices, CLO-02). Example: `invoices_data=[{"amount": 10000}]` for a EUR invoice, commercial USD 48.50 / EUR 52.80 -> 485,000 EGP instead of 528,000 (-43,000). Rule: no invented defaults. | Missing currency -> 409 `SETTLEMENT_CURRENCY_MISSING` (source, invoice_no); the reported currency of an empty file is `None`. Task ACC2-T11. |
| ACC2-F17 | MAJOR | `financial_settlement/service.py:2060-2068`, `:2113-2126`, `:2237-2238`, `:2338-2355`, `:2534-2535` | When the estimate fails (e.g. no customs rate) `sim=None`, then `est_total_fob = actual FOB`, `est_total_expenses = 0`, so `landed_variance` = all actual expenses, labelled OVER_BUDGET and written to `import_files.actual_landed_cost_variance_*` at approve. Example: FOB 500,000, expenses 100,000, estimate unavailable -> variance +100,000 (+20 %) "OVER_BUDGET"; every category shows +100 %. | Estimated and variance fields `None` (and status `NO_ESTIMATE`) when the estimate is unavailable; approve stores `None`. Task ACC2-T12. |
| ACC2-F18 | MAJOR | `financial_settlement/odoo_export_service.py:98-199`; `service.py:2409-2428` | The journal debits Goods in Transit with the full landed cost, including import VAT and the customs advance WHT, and credits each broker / transport row with the gross amount excluding VAT, not the payable. Example: broker 10,000 + VAT 1,400 - WHT 300 -> today Dr inventory 10,000 / Cr broker 10,000; payable is 11,100, WHT payable 300, input VAT 1,400. Customs VAT 150,000 is capitalised into inventory. Conflicts with recoverable input VAT for a VAT-registered importer (DOMAIN_RULES §3 lists VAT inside landed cost). | Q6. Behind `OdooExportConfig.import_vat_recoverable` (default False = unchanged): VAT components -> input VAT account, WHT advance -> tax receivable, broker/transport credit = net payable + WHT payable line. Stored rows carry `vat_amount_egp`, `wht_amount_egp`, `net_payable_egp`. Task ACC2-T13. |
| ACC2-F19 | MINOR | `financial_settlement/service.py:224-234`, `:259-264` | Engine edge cases: with no items, expenses are summed from `amount_egp` only (a row with `amount_egp=0`, `amount_fx=1000`, rate 50 counts 0 here but 50,000 with items) and not rounded; a stored row with `amount_egp: null` raises `TypeError` (`None == 0.0` is False, then `+= None`) -> 500. | One row-amount helper (`row_amount_egp(exp)`) used in both branches; totals rounded to 2. Task ACC2-T15. |
| ACC2-F20 | MINOR | `financial_settlement/service.py:2301-2306`, `:2347-2355`, `:2238`; `recalculation/service.py:224-231` | Hard-coded variance thresholds (+-0.05 EGP per unit, +-100 EGP per file; a category with no estimate is "+100 %"); `_aggregate` falls back to `max` for an unknown aggregation name. | Thresholds from `system_parameters` (defaults unchanged); unknown aggregation -> `ValueError` at seed / 422 at use. Task ACC2-T15. |
| ACC2-F21 | MINOR | `financial_settlement/service.py:1004-1086` | PL-08 expense lines for customs, clearance, port, transport, bank and other are labelled `currency="EGP"` while `amount_fc` holds the amount divided by the goods rate (a foreign amount). | `currency` = the goods currency on every line (as freight / insurance already do). Task ACC2-T10. |
| ACC2-F22 | MINOR | Flutter `financial_approval/services/financial_export_service.dart:33-47`, `:488-495`, `:1018-1023`, `:1076-1080`; `financial_approval_screen.dart:2204-2227` | The budget PDF/Excel recomputes EGP client-side: freight EGP = freight foreign x the **invoice** rate (wrong when freight is in another currency), and a stored 0 is replaced by the live prefill value, so the printed "approved budget" is not the stored one; the grand total is summed in Dart instead of `total_budget_egp`. Server side is BE02-F02/F03. | Print the stored `*_egp` and `total_budget_egp` only (show "-" for null). Task ACC2-T16. |
| ACC2-F23 | MINOR | `currencies/service.py:112-149`; `repository.py:43-55`, `:81-106`; `schemas.py:12` | Several currencies can be flagged `is_base_currency` (each then shows rate 1.0 without a rate row); two active rate rows for the same currency and date are both kept and the newest `created_at` wins silently, with no way to deactivate a wrong rate; `get_latest_rate` defaults to the server-local `date.today()`. | Single base currency (409); adding a rate for a date with an active row requires `replace=true` and deactivates the old row; callers pass the Cairo date. Task ACC2-T17. |

## 3. Tasks

### ACC2-T01: Landed cost uses the file's share of partially shipped POs
- **Severity:** BLOCKER (F01)
- **Depends on:** none (coordinate with BE09-T03 that keeps only the FOB recalculation seed)
- **Schema/migration needed:** no (`po_shipment_allocations` exists)
- **API contract change:** additive: settlement / CLO-02 / PL-08 responses may contain message `SETTLEMENT_PO_NOT_ALLOCATED` (po_number); item `qty` / FOB now reflect the shipped share. Flutter consumers: `financial_settlement/models/*` (no shape change).
- **Files to change:** `modules/financial_settlement/service.py`, `modules/recalculation/service.py`, `modules/common/system_messages.py`, `docs/system_message_codes.json`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. In `financial_settlement/service.py` add `file_po_line_shares(db, imp) -> List[Tuple[POLineItem, float, float]]` (line, qty for this file, ratio of the line). For each PO of `_purchase_orders_of_file`: load `POShipmentAllocation` rows of the PO. No rows -> every line `(line, line.quantity, 1.0)`. Rows for this file with `po_item_id` -> `qty = sum(shipped_quantity)` for that line, ratio = qty / line.quantity (0 when quantity 0). A row for this file with `po_item_id is None` -> ratio = `shipped_amount_fob / po.total_amount_fob` for every line not covered by an item row. Rows exist but none for this file -> skip the PO and add message `SETTLEMENT_PO_NOT_ALLOCATED`.
  2. `_items_from_purchase_orders`: qty = share qty, `fob_unit_egp` unchanged, `gross_weight_kg` and `cbm` x ratio.
  3. CLO-02 (`:2142-2160`): same helper; `fob_tot_egp = unit_price x qty_share x rate` (not `total_price`).
  4. PL-08 (`:768-811`): use `_purchase_orders_of_file` + the helper (today it reads `PurchaseOrder.import_file_id` only).
  5. `recalculation/service.py:_fetch_from_purchase_orders`: for `total_amount_fob`, value = sum over lines of `unit_price x qty_share` x PO rate.
  6. Register the message code (system_messages + json).
- **Acceptance criteria:** a PO without allocations gives today's numbers; a split PO gives each file only its share; the two files' FOB add up to the PO FOB.
- **Tests to add:** `tests/unit/test_financial_settlement.py::test_partial_shipment_fob_share`: PO 1 line 1,000 units x 10 USD, PO rate 50, CBM 20, weight 5,000; allocation file A 400, file B 600. Settlement A items: qty 400, FOB 200,000.00, CBM 8.0, weight 2,000; B: 600, 300,000.00; A expense 60,000 Value-Based -> A unit landed cost (200,000+60,000)/400 = 650.00. PO-level allocation 40 % (shipped_amount_fob 4,000) -> same FOB 200,000. PO with allocations only for file B -> file A excludes it and returns `SETTLEMENT_PO_NOT_ALLOCATED`. Recalculation fetch for A = 200,000.
- **Out of scope:** creating allocations from Flutter; PO balance screens.

### ACC2-T02: Code-first expense classification (landed-cost bucket and Odoo account)
- **Severity:** CRITICAL (F02, F03)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** no shape change; CLO-02 `categories_breakdown` amounts and Odoo `lines[].account_code` / `cost_category` change for broker categories.
- **Files to change:** `modules/financial_settlement/model.py` (constants next to `WHT_*`), `modules/financial_settlement/service.py`, `modules/financial_settlement/odoo_export_service.py`, `tests/unit/test_financial_settlement.py`, `tests/unit/test_odoo_gl_export.py`
- **Steps:**
  1. In `model.py` add `CLEARANCE_CATEGORY_BUCKET = {"BROKER_FEES": "Clearance & Port", "PORT_DUES_WHARFAGE": "Clearance & Port", "STEVEDORING_HANDLING": "Clearance & Port", "INSPECTION_WEIGHING": "Clearance & Port", "LABORATORY_TESTING": "Clearance & Port", "STORAGE_DEMURRAGE": "Demurrage & Storage", "OTHER_CLEARANCE": "Clearance & Port"}` and `CLEARANCE_CATEGORY_ODOO = {code: "Demurrage" if bucket == "Demurrage & Storage" else "Clearance"}`.
  2. `actual_expense_bucket`: if `party_type == "BROKER"` or the category (after stripping a `Clearance / ` prefix) normalises to a `CLEARANCE_EXPENSE_CATEGORY` code (`enum_codes.normalize` + `is_code`), return the map value; keyword matching only otherwise.
  3. `classify_odoo_cost_category`: same normalisation first; a `Clearance / ` row whose body is not a known code -> "Clearance"; keyword chain only for other free text. Keep "Customs"/"VAT"/"Taxes" engine categories -> Customs.
  4. `settlement_field_total` / RC-01 read the same classifier (no change needed beyond step 2; add a test).
- **Acceptance criteria:** no broker category is classified Freight or Customs; existing keyword tests for free text still pass.
- **Tests to add:** test_financial_settlement: parametrised `actual_expense_bucket(label_en(code), "BROKER")` for the 7 codes -> map above (today PORT_DUES and STEVEDORING give "Freight"). CLO-02 with items A (FOB 90,000, CBM 1) and B (FOB 10,000, CBM 9) and one broker invoice PORT_DUES_WHARFAGE 10,000, preference Value-Based -> A `allocated_clearance_egp` 9,000.00, B 1,000.00, `allocated_freight_egp` 0. test_odoo_gl_export: settlement rows "Clearance / Customs Broker Fees" 8,000 and "Clearance / Port Dues & Wharfage" 3,000 -> two lines on 210300, none on 210500 / 210200; journal balanced.
- **Out of scope:** renaming stored categories of existing settlements (they reclassify on read).

### ACC2-T03: Customs components in CLO-01 / CLO-02 / approve
- **Severity:** MAJOR (F05)
- **Depends on:** ACC2-T02
- **Schema/migration needed:** no
- **API contract change:** additive `components: [{component, category, amount_egp}]` on `AggregatedInvoiceItemSchema` (customs rows only, else `[]`). Flutter: `financial_settlement/models/invoices_aggregation_model.dart` (ignore or show), `widgets/final_settlement_invoices_dialog.dart` (optional).
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/service.py`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. In CLO-01 (`:1476-1508`) build `components` with `_customs_duty_rows(cl)` (already sums to `actual_duty_total` or falls back to one row); amounts rounded to 2.
  2. Bucket map for components: `import_duty_amount` -> Customs Duty; `vat_amount`, `schedule_tax_amount`, `development_fee_amount`, `customs_service_fees`, `wht_amount` -> VAT & Taxes (Q7 for WHT); `lab_service_fees` -> Clearance & Port.
  3. CLO-02 (`:2103-2106`): a row with components adds each component to its bucket instead of the whole row.
  4. Approve (`:2491-2494`): a row with components is stored as one settlement row per component (`invoice_no = <decl>/<component>`, category from `DUTY_COMPONENT_CATEGORIES`).
- **Acceptance criteria:** customs bucket split identical in create, CLO-02 and approve; total landed cost unchanged.
- **Tests to add:** clearance with import_duty 100,000, VAT 150,000, actual_duty_total 250,000; estimate mocked duty 100,000 / VAT 150,000 -> CLO-02 Customs Duty actual 100,000 variance 0.00; VAT & Taxes actual 150,000 variance 0.00; approve stores 2 rows (100,000 "Customs Duty", 150,000 "VAT"). Components not adding up (override 260,000) -> one row 260,000 in Customs Duty (today's fallback).
- **Out of scope:** paid-amount split per component (the paid amount stays on the declaration row).

### ACC2-T04: CLO-01 readiness on the net-payable basis
- **Severity:** MAJOR (F06)
- **Depends on:** none; **must land before BE09-T13**
- **Schema/migration needed:** no
- **API contract change:** `settlement_readiness_percent` semantics (paid / net payable, capped at 100); additive `total_net_payable_egp` and `parties_summary[].net_payable_egp`. Flutter: `invoices_aggregation_model.dart`, `final_settlement_invoices_dialog.dart`.
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/service.py`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. In the totals (`:1843-1847`): `total_net = round(sum(inv.net_payable_egp), 2)`; `readiness = min(100.0, round(total_paid / total_net * 100, 1))` when `total_net > 0`, else 100.0.
  2. Party map adds `net_payable_egp`.
  3. Keep `total_amount_egp` (cost basis) unchanged.
- **Acceptance criteria:** a file where every invoice is Paid has readiness 100.0 whatever WHT / VAT it carries.
- **Tests to add:** goods 100,000 PAID + CL-05 invoice amount 50,000, wht_amount 1,500, net 48,500, Paid -> readiness 100.0 (today 99.0), `total_net_payable_egp` 148,500.00. Broker 10,000 + VAT 1,400 - WHT 300 (net 11,100) Paid + goods 100,000 PAID -> 100.0 (today 111,100 / 110,000 = 101.0). Goods 100,000 PAID + transport 5,000 UNPAID (WHT rate 0) -> 100,000 / 105,000 = 95.2.
- **Out of scope:** the confirm gate itself (BE09-T13).

### ACC2-T05: Server-derived EGP amounts on settlement expense rows
- **Severity:** MAJOR (F07)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** `ExpenseInvoiceSchema.currency` becomes required (before: default "USD"); a client `amount_egp` on a foreign row is ignored (recomputed). Flutter `financial_settlement/models/financial_settlement_model.dart` and `widgets/settlement_form_dialog.dart` already send `currency` (verify `_currency` is non-null).
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/service.py`, `tests/unit/test_financial_settlement.py`, `tests/unit/test_odoo_gl_export.py`
- **Steps:**
  1. Schema: `currency: str = Field(..., min_length=3, max_length=3)`.
  2. New `_derive_expense_egp(rows)` run after `_resolve_client_expense_rates` in create and PUT: EGP -> `exchange_rate = 1.0`, `amount_egp = round(amount_fx, 2) if amount_fx > 0 else round(amount_egp, 2)`; foreign -> `amount_egp = round(amount_fx x exchange_rate, 2)` (require `amount_fx > 0`, 400 otherwise). `RECALC-ADJ-*` rows only rounded.
  3. Engine (`:259-262`): keep the fallback for legacy rows but round it to 2.
- **Acceptance criteria:** stored `amount_egp` always equals `round(amount_fx x rate, 2)` for foreign rows; journal of any settlement built through create/PUT is balanced within 0.01.
- **Tests to add:** row USD 1,000 x 50 with `amount_egp` 10 -> stored 50,000.00, `total_expenses_egp` 50,000.00. Four EGP rows 100.004 -> stored 100.00 each, `total_expenses_egp` 400.00, Odoo export 200 (today 409). Missing currency -> 422.
- **Out of scope:** stored legacy rows (left as is; T15 makes the engine tolerant).

### ACC2-T06: One FOB basis for the actual landed cost
- **Severity:** MAJOR (F08, F09)
- **Depends on:** Q1 (safe default below), ACC2-T01
- **Schema/migration needed:** no
- **API contract change:** CLO-02 additive `fob_basis` ("INVOICE" / "PO"); `reconciliation_difference_egp` becomes rounding-only (|x| <= 0.01 x items); approve may return 409 `SETTLEMENT_ACTUAL_FOB_MISSING`. Flutter: `financial_settlement/models/actual_landed_cost_model.dart`, `widgets/actual_landed_cost_dialog.dart` (error SnackBar).
- **Files to change:** `modules/financial_settlement/service.py`, `modules/financial_settlement/schemas.py`, `modules/common/system_messages.py`, `docs/system_message_codes.json`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. CLO-02: `fob_basis = "INVOICE"` when goods invoices exist, else `"PO"` when PO lines exist, else `"ESTIMATE"`.
  2. When the basis is INVOICE and `total_items_fob > 0`: scale every item `fob_total_egp` by `actual_total_fob_egp / total_items_fob`; distribute cents with largest remainder so the rounded item FOB sum equals the rounded header; `fob_unit = fob_total / qty` (unrounded internally).
  3. `settlement_item_row`: canonical `fob_unit_egp = line.fob_total_egp / qty` (unrounded), `fob_total_egp = line.fob_total_egp`.
  4. Approve: `fob_basis == "ESTIMATE"` -> 409 `SETTLEMENT_ACTUAL_FOB_MISSING` before any write.
  5. Q1 answer may switch the basis to PO; keep the scaling helper generic.
- **Acceptance criteria:** after approve, `sum(item total_landed_cost_egp)` = `total_landed_cost_egp` within 0.01 x item count; re-running the engine on the approved rows keeps FOB to the cent.
- **Tests to add:** PO 10,000 USD at 48.00 (480,000), invoice 10,000 USD at 50.00 (500,000), expenses 100,000 -> header 600,000.00, item FOB 500,000.00, items sum 600,000.00, `reconciliation_difference_egp` 0.00. Two items 1/3 - 2/3 of 100,000.01 -> 33,333.34 + 66,666.67 = 100,000.01. qty 100,000, FOB 12,345.60 -> approve then `_recalculate_in_place` -> FOB 12,345.60 (today 12,000.00). No goods invoice and no PO -> 409.
- **Out of scope:** recalculation FOB seed for Approved settlements (BE09-T03 / Q1).

### ACC2-T07: Realised payment in EGP and payment coverage
- **Severity:** MAJOR (F10)
- **Depends on:** Q2; BE02-T04 (SWIFT ref required)
- **Schema/migration needed:** yes: Alembic revision adding nullable `paid_amount_egp` (Float) and `paid_exchange_rate` (Float) to `payment_request_sessions`; no backfill (legacy rows stay NULL = unknown).
- **API contract change:** additive: `PaymentRequestResponse.paid_amount_egp`, `paid_exchange_rate` (Optional); reconcile requests accept optional `swift_debit_amount_egp` (gt=0); CLO-01 goods rows get real `paid_amount_egp` / PARTIAL; aggregation additive `fx_difference_egp`. Flutter: `financial_approval/models/financial_approval_model.dart`, `financial_settlement/models/invoices_aggregation_model.dart`.
- **Files to change:** `modules/financial_approval/model.py`, `modules/financial_approval/service.py`, `alembic/versions/<new>_payment_paid_egp.py`, `modules/financial_settlement/service.py`, `tests/unit/test_financial_approval.py`
- **Steps:**
  1. `_mark_paid`: `paid_exchange_rate = swift_debit_amount_egp / transferred` when given, else the commercial rate on the receipt date (`SettlementFx(db).rate`); `paid_amount_egp = round(transferred x rate, 2)`.
  2. CLO-01 goods (`:1334-1337`): per currency, `paid_fc = sum(swift_transferred_amount)` of the file's Paid requests in that currency (supplier payments, not duty); per invoice allocate `paid_fc` in invoice order; `paid_egp = paid_fc x c_rate`; status PAID / PARTIAL / UNPAID by coverage; `imp.swift_no` no longer decides.
  3. `fx_difference_egp = sum(paid_amount_egp) - sum(paid FC x invoice rate)` (reported only; landed-cost treatment per Q2).
- **Acceptance criteria:** a Deficit transfer leaves the goods invoice PARTIAL with the real remaining amount.
- **Tests to add:** invoice 50,000 USD at 50.00 (2,500,000); one Paid request with transfer 30,000 USD, bank debit 1,530,000 EGP -> `paid_exchange_rate` 51.00, `paid_amount_egp` 1,530,000.00; CLO-01 goods paid 1,500,000.00, remaining 1,000,000.00, PARTIAL; `fx_difference_egp` 30,000.00; readiness < 100.
- **Out of scope:** posting the FX difference to the GL.

### ACC2-T08: Payment request rate and PO ceiling
- **Severity:** MAJOR (F11, F12)
- **Depends on:** BE02-T11 (currency master check), BE02-T12
- **Schema/migration needed:** no
- **API contract change:** new 422 `FA_EGP_RATE_NOT_ONE`, 409 `FA_PAYMENT_EXCEEDS_PO` (po_number, po_total, committed, requested), 422 `FA_PAYMENT_CURRENCY_MISMATCH`. Flutter: `financial_approval/screens/financial_approval_screen.dart` (rate text 4 decimals; SnackBar for the codes), `widgets/supplier_advance_payment_dialog.dart`.
- **Files to change:** `modules/financial_approval/validators.py`, `modules/financial_approval/service.py`, `modules/financial_approval/repository.py`, `tests/unit/test_financial_approval.py`, `frontend/lib/features/financial_approval/screens/financial_approval_screen.dart`
- **Steps:**
  1. `validate_payment_rate(currency, rate)`: EGP and rate != 1.0 -> 422.
  2. `repository`: `requested_amount_egp = round(amount x rate, 2)` (`:89`, `:211`).
  3. `validate_po_ceiling(db, po_id, currency, amount, exclude_id)`: PO currency != request currency -> 422; committed = sum(requested_amount of active, non-Rejected requests of the PO); committed + amount > `total_amount_fob` + 0.01 -> 409 (Q3 override). Call in create, PUT (amount / po change) and clone.
  4. Server recomputes `advance_percentage = amount / po_total x 100` (2 decimals) when a PO is set.
  5. Flutter `_rateText`: `toStringAsFixed(4)`.
- **Acceptance criteria:** no request can push the PO above 100 %; EGP requests always have rate 1.
- **Tests to add:** EGP request 100,000 with rate 48.75 -> 422; with 1.0 -> `requested_amount_egp` 100,000.00. PO 100,000 USD: Paid 30,000 + new 80,000 -> 409 (committed 30,000, requested 80,000); new 70,000 -> 201, `advance_percentage` 70.00. Rate 48.7523 x 200,000 -> 9,750,460.00.
- **Out of scope:** L/C margin rules.

### ACC2-T09: Allocation bases per BP-038 with a completeness rule
- **Severity:** MAJOR (F13)
- **Depends on:** ACC2-T02; Q4 for air freight
- **Schema/migration needed:** no
- **API contract change:** additive message `ALLOCATION_BASIS_INCOMPLETE` (bucket, rule, item_codes) in CLO-02 / PL-08 `messages`; `categories_breakdown[].allocation_rule` reports the rule actually used.
- **Files to change:** `modules/financial_settlement/service.py`, `modules/common/system_messages.py`, `docs/system_message_codes.json`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. Helper `allocation_ratios(items, rule) -> (ratios, rule_used, missing_codes)`: Weight / Volume used only when every item value > 0; else Value-Based (Equal when total FOB is 0) and the missing codes.
  2. Use it in the engine (`:268-278`), CLO-02 (`:2213-2289`) and PL-08 (`:1105-1140`).
  3. CLO-02 rules: Demurrage & Storage -> Volume-Based; Freight -> Volume-Based (Weight-Based for air per Q4, from the file's shipping mode).
- **Acceptance criteria:** no item gets 0 of a CBM / weight bucket because its value is missing.
- **Tests to add:** items A (CBM 10, FOB 60,000) and B (CBM 0, FOB 40,000), freight 20,000 -> rule used Value-Based, A 12,000.00, B 8,000.00, message lists "B" (today A 20,000, B 0). Both CBM present (10 / 30), demurrage 4,000 -> A 1,000.00, B 3,000.00.
- **Out of scope:** a Quantity rule (Q4).

### ACC2-T10: PL-08 estimate reconciles with its lines
- **Severity:** MAJOR (F15), MINOR (F21)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** values only: the "VAT & Taxes" expense line amount; `currency` of the EGP-based lines becomes the goods currency. Flutter `financial_settlement/models/estimated_landed_cost_model.dart`, `widgets/estimated_landed_cost_dialog.dart` (no change expected).
- **Files to change:** `modules/financial_settlement/service.py`, `tests/unit/test_financial_settlement.py`
- **Steps:**
  1. "VAT & Taxes" line amount = `total_taxes_and_fees_egp - total_customs_duty_egp`.
  2. Per item, add `total_inspection_fees_egp x val_ratio` (included lines only) to `alloc_vat`.
  3. `currency=currency` on every expense line.
- **Acceptance criteria:** `sum(expenses_breakdown.amount_egp) == total_expenses_egp` (+-0.01 x lines); `sum(items.total_landed_cost_egp) == total_landed_cost_egp` (+-0.01 x items).
- **Tests to add:** mock `estimate_multi_item_customs_duty_service`: duty 10,000, VAT 15,000, service 500, development 300, import 0, inspection 200, items_taxes_total 26,000 -> "VAT & Taxes" line 16,000.00; `total_vat_and_fees_egp` 16,000.00; items' customs sum 26,000.00.
- **Out of scope:** the default parameters themselves (FS-07).

### ACC2-T11: No invented currency in estimate / aggregation
- **Severity:** MAJOR (F16)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** new 409 `SETTLEMENT_CURRENCY_MISSING` (source, invoice_no); CLO-01 / CLO-02 `currency` may be `null` for a file without goods (`InvoicesAggregationResponse.currency` and `ActualLandedCostCalculationResponse.currency` become Optional). Flutter: `invoices_aggregation_model.dart`, `actual_landed_cost_model.dart` (null-safe).
- **Files to change:** `modules/financial_settlement/service.py`, `modules/financial_settlement/validators.py`, `modules/financial_settlement/schemas.py`, `modules/common/system_messages.py` (+ `docs/system_message_codes.json`), `tests/unit/test_financial_settlement.py`
- **Steps:** replace `or "USD"` at `:775`, `:818`, `:836`, `:1311`, `:1323`, `:2074` by: a row with amount > 0 and no currency -> `currency_missing_error(source, invoice_no)`; the file-level reported currency is the goods currency or `None`.
- **Acceptance criteria:** grep `or "USD"` in `financial_settlement/service.py` returns nothing.
- **Tests to add:** `invoices_data=[{"invoice_no":"CI-1","amount":10000}]` -> CLO-01 409 with `invoice_no` "CI-1"; with `"currency":"EUR"` and EUR 52.80 -> 528,000.00.
- **Out of scope:** import file data entry.

### ACC2-T12: No fabricated variance when the estimate is unavailable
- **Severity:** MAJOR (F17)
- **Depends on:** ACC2-T06
- **Schema/migration needed:** no (`import_files.actual_landed_cost_variance_*` are nullable; verify)
- **API contract change:** CLO-02 `estimated_*`, `*_variance_*`, `categories_breakdown[].estimated_egp/variance_*`, `items_breakdown[].estimated_unit_landed_cost_egp/unit_cost_variance_*` become `Optional`; `variance_status` gets `NO_ESTIMATE`. Flutter: `financial_settlement/models/actual_landed_cost_model.dart`, `widgets/actual_landed_cost_dialog.dart`, `screens/landed_cost_comparison_screen.dart` (show "-").
- **Files to change:** `modules/financial_settlement/service.py`, `modules/financial_settlement/schemas.py`, `frontend/lib/features/financial_settlement/models/actual_landed_cost_model.dart`, `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `tests/unit/test_financial_settlement.py`
- **Steps:** when `sim is None`: all estimated and variance fields `None`, status `NO_ESTIMATE`, message `ESTIMATE_UNAVAILABLE` kept; approve writes `None` to the two file variance columns.
- **Acceptance criteria:** no variance number is shown or stored without an estimate.
- **Tests to add:** estimate raises 409 (no customs rate); FOB 500,000, expenses 100,000 -> `landed_variance_egp is None`, status `NO_ESTIMATE`; approve -> `imp.actual_landed_cost_variance_egp is None`, `actual_landed_cost_total_egp` 600,000.00.
- **Out of scope:** comparing with the Phase 2 approved budget (Q8).

### ACC2-T13: Tax-aware Odoo journal (behind a flag)
- **Severity:** MAJOR (F18)
- **Depends on:** Q6, ACC2-T02, ACC2-T03
- **Schema/migration needed:** no
- **API contract change:** additive `OdooExportConfig.import_vat_recoverable` (default False), `vat_input_account_code`, `wht_receivable_account_code`, `wht_payable_account_code`; additive keys `vat_amount_egp`, `wht_amount_egp`, `net_payable_egp` on stored expense rows. Flutter `financial_settlement/screens/odoo_journal_entry_dialog.dart` (no change with the flag off).
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/service.py` (`settlement_expense_row` copies vat / wht / net from the aggregated invoice), `modules/financial_settlement/odoo_export_service.py`, `tests/unit/test_odoo_gl_export.py`
- **Steps:** with the flag on: (1) customs component rows `vat_amount` -> Dr VAT input instead of inventory; customs `wht_amount` -> Dr WHT receivable; inventory debit = landed - those amounts; (2) broker / transport rows: Cr partner = `net_payable_egp`, Cr WHT payable = `wht_amount_egp`, Dr VAT input = `vat_amount_egp`; (3) balance check unchanged. Flag off: today's output byte for byte.
- **Acceptance criteria:** flag off -> existing tests unchanged; flag on -> balanced entry with the tax lines.
- **Tests to add:** flag on: FOB 500,000; customs duty 100,000 + VAT 150,000; broker 10,000 + VAT 1,400 - WHT 300 -> Dr inventory 610,000, Dr VAT input 151,400; Cr supplier 500,000, Cr customs 250,000, Cr broker 11,100, Cr WHT payable 300; totals 761,400 = 761,400.
- **Out of scope:** changing `total_landed_cost_egp` (stays per DOMAIN_RULES until Q6).

### ACC2-T14: Report missing actual sources
- **Severity:** MAJOR (F14)
- **Depends on:** Q5
- **Schema/migration needed:** no (until Q5 adds a bank-charge source)
- **API contract change:** additive message `ACTUAL_SOURCE_MISSING` (bucket, estimated_egp) in CLO-02 `messages`. Flutter `actual_landed_cost_dialog.dart` renders messages already (verify).
- **Files to change:** `modules/financial_settlement/service.py`, `modules/common/system_messages.py`, `docs/system_message_codes.json`, `tests/unit/test_financial_settlement.py`
- **Steps:** after bucketing, for each bucket with `estimated > 0` and `count == 0`, append the message.
- **Acceptance criteria:** a file without bank-charge invoices shows the warning for "Other & Admin".
- **Tests to add:** estimate other 4,500, no Other invoices -> one message with `estimated_egp` 4,500.00.
- **Out of scope:** the bank-charge data source itself.

### ACC2-T15: Engine robustness and configurable thresholds
- **Severity:** MINOR (F19, F20)
- **Depends on:** ACC2-T05
- **Schema/migration needed:** no
- **API contract change:** no
- **Files to change:** `modules/financial_settlement/service.py`, `modules/recalculation/service.py`, `tests/unit/test_financial_settlement.py`, `tests/unit/test_recalculation_engine.py`
- **Steps:** `row_amount_egp(exp)` = `amount_egp` when not None and != 0, else `amount_fx x (exchange_rate or 1.0 if EGP else 0)`, rounded to 2; used in both engine branches; no-items totals rounded. Parameters `settlement.variance_unit_tolerance_egp` (0.05) and `settlement.variance_file_tolerance_egp` (100.0) through `get_float_parameter`. `_aggregate`: unknown name -> `ValueError`.
- **Acceptance criteria:** engine never raises on a `None` amount; same totals with and without items for the same rows.
- **Tests to add:** no items, rows `{amount_egp: 0, amount_fx: 1000, currency: USD, exchange_rate: 50}` -> `total_expenses_egp` 50,000.00 (today 0); row `amount_egp: None` -> no exception. `_aggregate([1,2], "avg")` -> ValueError.
- **Out of scope:** none.

### ACC2-T16: Flutter shows backend money, no client formulas
- **Severity:** CRITICAL (F04), MINOR (F22)
- **Depends on:** ACC2-T12 (nullable variance)
- **Schema/migration needed:** no
- **API contract change:** no (reads existing fields: `import_files.actual_landed_cost_variance_egp/pct`, CLO-02 response, `total_budget_egp`)
- **Files to change:** `frontend/lib/features/financial_settlement/screens/landed_cost_comparison_screen.dart`, `frontend/lib/features/financial_settlement/services/landed_cost_comparison_export_service.dart`, `frontend/lib/features/financial_approval/services/financial_export_service.dart`, `frontend/test/features/financial_settlement/landed_cost_comparison_test.dart` (new), `frontend/test/features/financial_approval/financial_export_rate_test.dart`
- **Steps:** comparison: load the estimate from `GET /financial-settlement/...actual-landed-cost` (CLO-02 calculation) or the file's `actual_landed_cost_variance_*`; delete `_fobVariance` / `_landedVariance` formulas; show "-" when null. Budget export: print the stored `invoice_amount_egp`, `freight_cost_egp`, `customs_duties_egp`, `clearance_inland_egp`, `total_budget_egp`; no `x rate`, no prefill fallback.
- **Acceptance criteria:** grep `/ estimatedCost` and `* rate` in those files returns nothing.
- **Tests to add:** widget/unit: estimated_cost 10,000 (USD) and FOB 500,000 EGP no longer produce 4,900 %; the card shows the backend `landed_variance_pct` (e.g. 3.25). Export with freight 1,000 EUR, invoice rate USD 48.5, stored freight_cost_egp 52,800 -> prints 52,800.00 (today 48,500.00).
- **Out of scope:** layout changes.

### ACC2-T17: Currency master integrity
- **Severity:** MINOR (F23)
- **Depends on:** BEX-T04 (permissions), BEX-T07 (fallback removal)
- **Schema/migration needed:** no (app-level checks)
- **API contract change:** `POST /currencies/rates` additive `replace: bool = False`; 409 `CURRENCY_RATE_EXISTS` (currency, effective_date) when an active row exists and `replace` is false; 409 `CURRENCY_BASE_EXISTS` on a second base currency. Flutter `currencies/providers/currencies_provider.dart` (pass `replace` on confirm).
- **Files to change:** `modules/currencies/validators.py`, `modules/currencies/service.py`, `modules/currencies/repository.py`, `modules/currencies/schemas.py`, `tests/unit/test_currencies.py`
- **Steps:** validator checks; with `replace=true` the old row gets `is_active=False` in the same commit; `get_latest_rate` callers in this module pass the Cairo date (`financial_settlement.service.cairo_today`).
- **Acceptance criteria:** at most one active rate per (currency, date) and one base currency.
- **Tests to add:** add USD 2026-10-01 48.50, again 48.60 -> 409; with replace -> `_get_rate_to_egp("USD", as_of_date=2026-10-01)` = 48.60 and the first row inactive. Second base currency -> 409.
- **Out of scope:** `fallback_rates` (BEX-T07), route permissions (BEX-T04).

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| CLO-01 `GET .../invoices-aggregation` | `settlement_readiness_percent` = paid / net payable (T04); additive `total_net_payable_egp`, `parties_summary[].net_payable_egp`, `invoices[].components` (T03), `fx_difference_egp` (T07); `currency` may be null (T11) | `financial_settlement/models/invoices_aggregation_model.dart`, `widgets/final_settlement_invoices_dialog.dart` |
| CLO-02 calculate / approve | additive `fob_basis`; estimated / variance fields nullable + `NO_ESTIMATE`; new messages `ALLOCATION_BASIS_INCOMPLETE`, `ACTUAL_SOURCE_MISSING`, `SETTLEMENT_PO_NOT_ALLOCATED`; approve 409 `SETTLEMENT_ACTUAL_FOB_MISSING` | `models/actual_landed_cost_model.dart`, `widgets/actual_landed_cost_dialog.dart` |
| Settlement create / PUT | `expense_invoices[].currency` required; `amount_egp` server-derived (do not compute it in Dart) | `models/financial_settlement_model.dart`, `widgets/settlement_form_dialog.dart` |
| Comparison screen | stop the client variance formula; read backend variance (T16) | `screens/landed_cost_comparison_screen.dart`, `services/landed_cost_comparison_export_service.dart` |
| Payment requests | EGP rate must be 1; send the rate with 4 decimals; handle `FA_EGP_RATE_NOT_ONE`, `FA_PAYMENT_EXCEEDS_PO`, `FA_PAYMENT_CURRENCY_MISMATCH`; additive `paid_amount_egp`, `paid_exchange_rate` | `financial_approval/screens/financial_approval_screen.dart`, `widgets/supplier_advance_payment_dialog.dart`, `models/financial_approval_model.dart` |
| Budget export | print stored EGP fields and `total_budget_egp` only | `financial_approval/services/financial_export_service.dart` |
| Currencies rates | `replace` flag, 409 codes | `currencies/providers/currencies_provider.dart` |

New codes to register (system_messages + `docs/system_message_codes.json` + Flutter catalogs): `SETTLEMENT_PO_NOT_ALLOCATED`, `SETTLEMENT_ACTUAL_FOB_MISSING`, `SETTLEMENT_CURRENCY_MISSING`, `ALLOCATION_BASIS_INCOMPLETE`, `ACTUAL_SOURCE_MISSING`, `FA_EGP_RATE_NOT_ONE`, `FA_PAYMENT_EXCEEDS_PO`, `FA_PAYMENT_CURRENCY_MISMATCH`, `CURRENCY_RATE_EXISTS`, `CURRENCY_BASE_EXISTS`.

## 5. Open questions for the CTO

1. **Q1 FOB basis of the actual landed cost:** commercial invoice x invoice-date commercial rate (today's CLO-02 header), PO lines x PO rate (create / recalculation), or the SWIFT bank debit (T07)? Safe default in T06: invoice basis, items scaled to it; recalculation FOB seed should then follow the same basis.
2. **Q2 Realised FX difference:** is the difference between the invoice-date rate and the bank debit part of the landed cost (inventory) or posted to FX gain/loss? Is a Deficit SWIFT a "Partially Paid" request instead of Paid?
3. **Q3 PO ceiling:** may a payment exceed the PO value (price increase, bank charges OUR)? If yes, who overrides and with which tolerance?
4. **Q4 Allocation per BP-038:** air freight by weight (needs the shipment mode), a Quantity rule for fixed fees, broker fees Equal or Value?
5. **Q5 Bank charges / Form 4 and inspection certificates (BP-036 items 7-8):** which module records the actual amounts? Until then the actual cost omits them.
6. **Q6 VAT and WHT in landed cost:** DOMAIN_RULES §3 puts import VAT in landed cost and the Phase 9 doc lists "WHT 1%" with the customs taxes. For a VAT-registered importer both are recoverable (input VAT, advance income tax). Keep them in the inventory cost, or post them to tax accounts (T13 flag)?
7. **Q7 Customs WHT bucket:** VAT & Taxes (T03 default) or a separate "Advance tax" bucket?
8. **Q8 Which estimate does "Actual vs Estimated" compare with (BP-039)?** Today CLO-02 compares with the PL-08 simulation run at approval time (customs rate, current parameters), not with the Phase 2 approved budget (`import_budget_approvals.total_budget_egp`), which also uses different bases (highest freight quote, max duties, latest commercial rate, no insurance / inland transport).
9. **Q9 CIF / CFR files:** the goods invoice already includes freight (and insurance for CIF), while CLO-01 still adds freight bookings and insurance certificates. Should CLO-01 drop seller-paid freight / insurance by Incoterm (backlog Q11 of the Phase 9 plan)?
