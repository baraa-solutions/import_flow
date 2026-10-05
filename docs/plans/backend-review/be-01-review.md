# Phase 01 Import planning (`purchase_orders`, `cbm_calculator`, `shipping_scenarios`, `customs_consultation`, `import_requirements`, `freight_quotations`): backend review

Status: 2026-10-05, static review only (no pytest, no `import main`, no DB access). Baseline: the fixes of
`docs/plans/phase-01-quality-simplify-plan.md` (PO-01..18, CBM-01..06, SS-01..04, CC-01..04, IR-01..04, FQ-01, D-01..11) and
`docs/plans/phase-01-progress.md` are in the code (permissions on every route, PO line upsert by `item_id`, `cargo_math`,
`next_yearly_code`, CC-01 recalculation on the tariff engine, IR prefill without fabricated HS). They are not re-reported unless still broken.
Severity: **BLOCKER** = wrong money / data corruption / security / auth bypass. **CRITICAL** = wrong result or 500 on a
normal path. **MAJOR** = rule violation, real risk. **MINOR** = hygiene.

| File | Lines | Depth |
|---|---|---|
| `modules/purchase_orders/service.py` | 1097 | Full, line by line |
| `modules/purchase_orders/{router,repository,validators,schemas,model}.py` | 144 / 149 / 146 / 339 / 248 | Full |
| `modules/cbm_calculator/{router,service,repository,validators,schemas}.py` | 130 / 359 / 135 / 62 / 182 | Full |
| `modules/cbm_calculator/model.py` | 95 | Columns / nullability only |
| `modules/shipping_scenarios/{router,service,repository,validators}.py` | 111 / 275 / 182 / 149 | Full |
| `modules/shipping_scenarios/schemas.py`, `model.py` | 322 / 193 | Item fields (l.1-140), model columns |
| `modules/customs_consultation/{router,service,repository,validators}.py` | 366 / 956 / 531 / 50 | Full (repository and recalculation helpers were "not audited" in the previous wave) |
| `modules/customs_consultation/schemas.py`, `model.py` | 367 / 278 | Grep scan + price list / quote / consultation / recalculation classes read |
| `modules/import_requirements/{router,service,repository,validators}.py` | 103 / 689 / 128 / 68 | Full, including `sync_regulatory_tasks_and_alerts` (l.52-314, not audited before) |
| `modules/import_requirements/schemas.py`, `model.py` | 267 / 100 | Grep scan (currency, value, status fields) |
| `modules/freight_quotations/{router,service,repository,validators}.py` | 148 / 361 / 201 / 93 | Full (previous wave: router grep only) |
| `modules/freight_quotations/schemas.py`, `model.py` | 140 / 131 | Grep scan + model columns |
| Context read | n/a | `freight_booking/model.py:26`, `freight_booking/service.py:93-115`, `financial_approval/service.py:1210-1232`, `financial_settlement/service.py:340-375,398-407`, `file_closure/service.py:425-450`, `recalculation/service.py:108-160`, `common/sequence_generator.py:32-60`, `common/validators.py:58-99`, `import_files/model.py:34,82`, Flutter `purchase_order_model.dart:485-639`, `customs_consultation_model.dart:32-247` |

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 4 |
| MAJOR | 16 |
| MINOR | 11 |

Top points:
1. **Broker fees summed across currencies as EGP (BE01-F01)**: `total_broker_fees_egp` adds `unit_price x qty` of every applicable
   quote item whatever its `currency`. A USD 100 x 2 line counts as EGP 200. The value feeds the financial-approval budget
   (`financial_approval/service.py:1225`).
2. **Scenario edit orphans freight bookings (BE01-F02)**: every PUT of a shipping-scenario study hard-deletes all scenario items and
   inserts new ids. `freight_bookings.scenario_item_id` keeps pointing at deleted rows, so the booking loses its quoted rates
   (savings / variance engine, `freight_booking/service.py:97-115`). Same bug class as PO-01, still open in this module.
3. **Create breaks after a clone (BE01-F03)**: clones get codes like `CUS-2026-005-COPY`. The consultation / price-list code
   generators read the newest row, fail to parse `COPY`, restart at `001`, and the unique index returns a 500 on every later create.
4. **Freight quotations compare different currencies as one number (BE01-F05)** and **an RFQ edit drops the award (BE01-F04)**:
   lowest / average cost and the benchmark ranking mix USD, EUR and EGP totals; any PUT with quotations deletes the awarded row
   while `selected_quotation_id` keeps the old id.
5. **Import-requirements prefill mixes currencies (BE01-F07)**: PO lines of several POs (and invoice rows) are summed and labelled
   with the first PO's currency.

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE01-F01 | BLOCKER | `customs_consultation/repository.py:300-302,456-475`; `service.py:303-305`; consumer `financial_approval/service.py:1225` | `total_broker_fees_egp` = sum of `unit_price*qty` of applicable quote items, ignoring each item's `currency` (`model.py:270`). Non-EGP lines are added as EGP. Client may also send `total_broker_fees_egp` (create fallback l.316). | Compute in the service only: each applicable line converted to EGP with `SettlementFx(db, "commercial")` on the session date; missing rate -> 409 `SETTLEMENT_FX_RATE_MISSING`. Ignore the client total. (T01) |
| BE01-F02 | BLOCKER | `shipping_scenarios/repository.py:129-134`; `freight_booking/model.py:26`; `freight_booking/service.py:97-115` | Update deletes all `ShippingScenarioItem` rows and re-inserts them (new `item_id`). Freight bookings referencing `scenario_item_id` dangle (SQLite FK not enforced), so original quote rates fall back to 0 / stale values. | Upsert items by `item_id` (like PO `_sync_children`); a removed item referenced by a booking -> 409. (T02) |
| BE01-F03 | CRITICAL | `customs_consultation/repository.py:270-293,121-137`; `service.py:206-212,460-466` | Code generators take the row with the highest id and `int(code.split("-")[-1])`. After a default clone (`<code>-COPY`) the parse fails, the sequence restarts at `001`, and the next create hits the unique index -> 500. | Use `next_yearly_code` (ignores non-digit suffixes) + IntegrityError retry. (T03) |
| BE01-F04 | CRITICAL | `freight_quotations/repository.py:152-180`; `model.py:63`; `service.py:49-52` | PUT with `quotations` deletes all quotation rows; `selected_quotation_id` (plain int, no FK) keeps the deleted id. The award survives only if the client re-sends `is_awarded`. | Upsert quotations by `quotation_id`; keep `selected_quotation_id` consistent; award only via the award endpoint. (T04) |
| BE01-F05 | CRITICAL | `freight_quotations/service.py:46-56,248-254,298,344-348,356`; `schemas.py:136` | Lowest / average cost, cost score, "saving vs average" and the recommendation compare `total_cost` across quotes with different `currency_code`. `average_cost_usd` and `$` are labels, not conversions. | Compare on an EGP base converted per quote (`SettlementFx`, commercial, RFQ `crd_date`); expose `total_cost_egp`. (T05) |
| BE01-F06 | MAJOR | `shipping_scenarios/service.py:259`; `customs_consultation/service.py:482` | Clone keeps (or sets) `import_file_id` without the one-active-study-per-file check that create / update / restore apply. Downstream readers aggregate every active study of a file (`recalculation/service.py:117-125`, `financial_approval/service.py:1210-1217`). | Run `_check_one_per_file` on clone when the clone keeps a file; validate `target_import_file_id` is active. (T12, T13) |
| BE01-F07 | CRITICAL | `import_requirements/service.py:584-588,594-596,610-614,636-639` | Prefill `shipment_value` = sum of all PO lines (and invoice `amount`s) across POs / invoices of different currencies, labelled with `pos[0]` currency; an HS bucket adds values of different currencies. | Sum per currency; mixed -> `shipment_value=None`, `currency=None`, message `PREFILL_MIXED_CURRENCY`; HS bucket keyed by (hs, currency). (T06) |
| BE01-F08 | MAJOR | `purchase_orders/schemas.py:181`; `model.py:43`; `service.py:685` | `exchange_rate` defaults to 1.0 on create and on clone (`or 1.0`). An invented rate; downstream code treats 1.0 as "not set" (`financial_settlement/service.py:398-407`) while `file_closure/service.py:444` shows it as a real rate. Flutter also defaults 1.0 (`purchase_order_model.dart:536,586`). | Required on create (no default), clone copies the stored value only. (T07) |
| BE01-F09 | MAJOR | `customs_consultation/repository.py:62,101,109,173,250,258`; `import_requirements/repository.py:73,83,92,101`; `import_requirements/service.py:74,311`; `freight_quotations/repository.py:93,183,191,199` | Repositories commit; IR sync commits twice mid-way (ACID copy at l.74 before tasks). Breaks "single commit per use case, no commit in repository". | Repositories flush; the service commits once; side effects stay `best_effort` after the core commit. (T08, T04) |
| BE01-F10 | MAJOR | `freight_quotations/model.py:68-73`, `router.py:39,94,108,121,134`; `customs_consultation/router.py:104,131,144,193,220,233,248`, `model.py:11-45,47-92` | No `created_by` / `updated_by` on RFQs, quotation items, broker price lists, expense types; routers do not pass the user. | Additive migration + pass `current_user.username`. (T09, T10) |
| BE01-F11 | MAJOR | `purchase_orders/validators.py:129-134`, `service.py:744,750-752,969`; `freight_quotations/service.py:156-183`, `schemas.py:54`; `customs_consultation/validators.py:43`, `service.py:290-298` | Status workflows unguarded: PO status any -> any (CANCELLED -> DRAFT, manual FULLY_SHIPPED), edits / allocations accepted on CLOSED / CANCELLED POs; RFQ award on a Cancelled or soft-deleted RFQ, RFQ status free text; consultation statuses are English labels (CC-03 code part still open). | Transition table in validators; reject edits on final / inactive rows. (T11, T04) |
| BE01-F12 | MAJOR | `customs_consultation/validators.py:11-25`, `service.py:369-373,420-425,482`; `freight_quotations/validators.py:10-24` | Consultation `import_file_id`, `po_id`, `project_id`, `broker_price_list_id`, quote / price-list `expense_type_id` never validated; broker and carrier checks ignore `is_active`. | `require_active` for each FK (same pattern as `shipping_scenarios/validators.py`). (T12, T04) |
| BE01-F13 | MAJOR | `shipping_scenarios/schemas.py:28-117`, `model.py:102-191`; `customs_consultation/schemas.py:20,58,153`; `freight_quotations/schemas.py:15`; `import_requirements/schemas.py:62`, `model.py:20` | Currency is free text with invented defaults (`"USD"`, `"EGP"`). A EUR quote saved without a currency becomes USD; `recalculation/service.py:150` converts it as USD. | Validate against the `currencies` master codes, no default (required when a price > 0). (T18) |
| BE01-F14 | MAJOR | `freight_quotations/service.py:49-52` | `_compute_rfq_metrics` (used by GET / list) sets `q.is_awarded = True` on read; flushed by whatever commits next. | Pure response builder; award state written only by `award_quotation`. (T04) |
| BE01-F15 | MAJOR | `freight_quotations/repository.py:59-60,87,176`; `schemas.py:54` | Create / update accept client `status`, `selected_quotation_id`, `is_awarded`: several awarded quotes, or "Awarded" without the award side effects on the import file. | Drop these from Create / Update (ignored), award through `/award`. (T04) |
| BE01-F16 | MAJOR | `cbm_calculator/service.py:207-227,230-255` | Create pushes totals to the linked PO, update does not (new items or a new `po_id` leave the PO stale); link pushes even for a soft-deleted calc. | Push after update when items or `po_id` changed; reject link / update of an inactive calc. (T14) |
| BE01-F17 | MAJOR | `purchase_orders/repository.py:49-90`, `router.py:29-48`; `freight_quotations/service.py:62-67` | PO list is unbounded and eager-loads every line and packing row of every PO; no `skip/limit/total`. RFQ list runs one ImportFile query per RFQ (N+1). Same unbounded lists in CBM, scenarios, consultations, assessments. | Additive `skip`/`limit` + `X-Total-Count` on PO list; batch file codes in RFQ list. (T15, T04) |
| BE01-F18 | MAJOR | `customs_consultation/repository.py:96-99,226-228,419-424`; `freight_quotations/repository.py:147-150` | Update `setattr`s explicit nulls: `{"title": null}` / `broker_id` / `name_ar` / `effective_from` / `crd_date` / `pol_name` on NOT NULL columns -> IntegrityError 500 (PO-02 analog, still open here). | Reject clearing NOT NULL columns with 400 (`not_null_columns` helper). (T12, T04) |
| BE01-F19 | MAJOR | `customs_consultation/schemas.py:297-298`; `service.py:546-547,563-564,936-944,649` | Recalculation: missing `freight_egp` / `insurance_egp` silently become 0 with `has_freight_document=True` and deemed rates 0, so CIF = FOB with no warning; negatives accepted; `import_file_code or f"IMP-{id:04d}"` fabricates a code. | `ge=0`; response flag + message when freight / insurance were not given; return the real code (NOT NULL column). (T17) |
| BE01-F20 | MAJOR | `purchase_orders/service.py:779-782,877-891` | Soft delete has no guard (PO with shipment allocations or used by a later stage is silently dropped from settlement); restore re-links to an inactive import file; update of a soft-deleted PO re-adds it to `import_files.po_ids`. | Guard delete (409 when allocations exist), active-only update, restore checks the file. (T11) |
| BE01-F21 | MAJOR | `purchase_orders/schemas.py:46,50,80,84-85,181` (inherited by `*Response`); `customs_consultation/schemas.py:15-19,54-56,94-96,149-150,176,215`; `freight_quotations/schemas.py:16` + `model.py:112-121` | Response schemas inherit input rules (`min_length`, `gt=0`, required `ocean_freight_cost` on a nullable column). One legacy row out of range -> the whole list 500s. | Response classes declare plain / Optional types (or `LegacyRowTolerantModel`). (T16) |
| BE01-F22 | MAJOR | `customs_consultation/schemas.py:57-60,152-154`; `shipping_scenarios/schemas.py:29-117` | Money inputs have no `ge=0`: negative broker prices, quantities, min/max, scenario charges are stored and summed into budgets. | `Field(ge=0)` on Create schemas only. (T01, T12, T13) |
| BE01-F23 | MINOR | `customs_consultation/repository.py:33-46`; `freight_quotations/repository.py:15-38`; `cbm_calculator/repository.py:36-65` (create), `shipping_scenarios/repository.py:49-72`, `import_requirements/repository.py:70-75` | Expense / RFQ codes from the newest id, no retry; CBM / scenario / assessment creates have no IntegrityError retry (two concurrent creates -> 500). | `next_yearly_code` / max-suffix + one retry. (T03) |
| BE01-F24 | MINOR | `cbm_calculator/validators.py:21,27,32,37`, `service.py:263`; `shipping_scenarios/validators.py:34-76`, `service.py:222`; `customs_consultation/validators.py:23,35,49`; `freight_quotations/service.py` (all 404 / 400 details), `validators.py:10-92` | English user-facing error / success messages. | Arabic `detail` (or coded). (T20) |
| BE01-F25 | MINOR | `import_requirements/service.py:68,226-231,241,245,259-264` | Task dedupe `notes ILIKE '%REQ_TYPE:COO%'` also matches `REQ_TYPE:COO_<hs>` (and `_` is a LIKE wildcard), so auto-close can close the wrong task; invented assignee `"Import Specialist"`, due date = today, fabricated `FILE-<id>` code. | Exact token match; leave assignee / due date empty when unknown. (T19) |
| BE01-F26 | MINOR | `freight_quotations/service.py:269,278` | Benchmark: hard-coded scoring constants; "reliability" 10 vs 8.5 depends on `is_awarded` (the awarded quote ranks itself higher). | Named constants; reliability not derived from the award. (T05) |
| BE01-F27 | MINOR | `purchase_orders/service.py:640-656,1074` | Clone invents `quantity or 1.0`, `qty_pcs/qty_pkg or 1.0`; balance falls back to `"USD"` when the PO has no currency. | Copy stored values; currency `None` -> `currency_code` Optional. (T21) |
| BE01-F28 | MINOR | `shipping_scenarios/service.py:202-205`, `validators.py:30-46` | Changing `cargo_ready_date` without resending items skips the sailing >= CRD check on stored items; negative `avg_form4_days` / `avg_clearance_days` checked on create only. | Re-validate stored items; check on update. (T13) |
| BE01-F29 | MINOR | `purchase_orders/schemas.py:272`, `model.py:230` | Allocation `status` free text (default "In Transit"). | Enum code set. (T11) |
| BE01-F30 | MINOR | `shipping_scenarios/service.py:150-157`; `freight_quotations/service.py:186-200` | `import_files.selected_scenario` written as free text by two modules, never cleared when the study / RFQ is deleted; award writes free-text `port_of_loading` / `port_of_discharge` instead of the location FK. | One owner; clear on delete; write location ids. (T22) |
| BE01-F31 | MINOR | `customs_consultation/schemas.py:99-100`; `repository.py:203-222` | Price list `effective_from > effective_to` accepted; overlapping active lists for one broker resolved silently by "newest wins". | Date order check; 409 on overlap (CTO Q6). (T12) |
| BE01-F32 | MINOR | `import_requirements/model.py:76`; `service.py:69,96-99` | ACID number stored and copied into task message params in plaintext; CORE_RULES forbid plaintext ACID storage. Project-wide pattern (`import_files/model.py:82`). | CTO decision (Q7). No task here. |
| BE01-F33 | MINOR | `cbm_calculator/service.py:305-317` (clone, legacy `length_cm=0` -> `CBMItemCreate` gt=0 ValidationError -> 500); `cbm_calculator/service.py:246` (`db.get(PurchaseOrder)` in service) | Clone of a legacy calc with a zero dimension 500s; direct model query in the service. | Skip zero-dimension items with a message; read through the repository. (T14) |

---

## 3. Tasks

Order: T01, T02, T03 first (independent). T04 before T05 and T10. T07, T11, T15, T21 touch `purchase_orders/*`: run in that order.
T12, T08, T09, T16, T17 touch `customs_consultation/*`: run after T01 and T03, in the order listed. New message codes: register in
`modules/common/system_messages.py` + `docs/system_message_codes.json` (+ Flutter catalogs) in the same change, or add a row to
`docs/plans/review-shared-needs.md` if those files are owned by another package (`tests/unit/test_review_wave_codes.py` fails otherwise).

### BE01-T01: Broker fees converted to EGP per line
- **Severity**: BLOCKER (BE01-F01, part of F22)
- **Depends on**: none
- **Schema/migration needed**: no (existing rows are corrected on their next save; see Out of scope)
- **API contract change**: no field change. `total_broker_fees_egp` in the request is ignored (it was already overwritten on update);
  a session with a non-EGP applicable quote item and no rate now returns 409 `SETTLEMENT_FX_RATE_MISSING` (existing code).
  Flutter: `frontend/lib/features/customs_consultation/providers/customs_consultation_provider.dart` must show the coded 409 as a SnackBar.
- **Files to change**: `modules/customs_consultation/service.py`, `modules/customs_consultation/repository.py`,
  `modules/customs_consultation/schemas.py`, `tests/unit/test_be01_broker_fees_egp.py` (new)
- **Steps**:
  1. `repository.py:299-302,316`: delete the `total_broker_fees` sum in `create`; set `total_broker_fees_egp=0.0` (the service fills it).
     In `update` (l.456-475) delete the `total_broker_fees` accumulation and the assignment at l.475. Keep `total_amount = unit_price*qty`
     per line (line amount in the line currency).
  2. `service.py:_recompute_metrics` (l.283-305): add parameter `fx` (a `SettlementFx`); replace l.303-305 with
     `sum(q.total_amount * fx.rate(q.currency, on_date) for q in items if q.is_applicable)` where `on_date = cairo_date(db_session.created_at)`
     or `cairo_today()` when NULL (import both from `modules.financial_settlement.service`). `fx.rate("EGP")` is 1.0; a missing rate raises
     409 `SETTLEMENT_FX_RATE_MISSING` before commit. Round the total to 2 decimals.
  3. Callers (`create_consultation` l.377, `update_consultation` l.429, `clone_consultation` l.538): pass `SettlementFx(db, "commercial")`
     (rate type: CTO Q1; commercial until decided).
  4. `schemas.py:152-154`: `unit_price: float = Field(0.0, ge=0)`, `qty: float = Field(1.0, gt=0)` on `CustomsBrokerQuoteItemBase`
     but move them to the Create class so the Response class keeps plain floats (see T16).
- **Acceptance criteria**: `total_broker_fees_egp` equals the EGP sum of applicable lines; non-applicable lines excluded; a USD line
  without a USD commercial rate -> 409 `SETTLEMENT_FX_RATE_MISSING` and nothing is saved.
- **Tests to add** (`tests/unit/test_be01_broker_fees_egp.py`, scratch SQLite + a `currency_rates` row USD commercial 50.0 on today):
  - Create with items `[EGP 1000 x 1 applicable, USD 100 x 2 applicable, EGP 500 x 1 not applicable]` -> `total_broker_fees_egp == 11000.00`
    (today's code gives 1200.0).
  - Same payload without the USD rate row -> 409, `detail["code"] == "SETTLEMENT_FX_RATE_MISSING"`, `detail["currency"] == "USD"`, no session row.
  - Payload `total_broker_fees_egp=99999` with one EGP 300 x 1 line -> stored 300.0.
  - `unit_price=-5` -> 422.
- **Out of scope**: rewriting existing stored totals (CTO Q1: run a read-only count of sessions with applicable non-EGP lines first);
  `financial_approval` consumer.

### BE01-T02: Shipping-scenario items upserted by id (bookings keep their quote)
- **Severity**: BLOCKER (BE01-F02)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes, additive. `ShippingScenarioItemCreate.item_id: Optional[int]` (existing row id on update; omit for a new
  option). Removing an option referenced by a freight booking -> 409 `SCENARIO_ITEMS_BOOKED` (new code, params `item_ids`).
  Flutter: `frontend/lib/features/shipping_scenarios/models/shipping_scenario_model.dart` (`toJson` sends `item_id`),
  `shipping_scenarios_provider.dart` (409 SnackBar).
- **Files to change**: `modules/shipping_scenarios/schemas.py`, `repository.py`, `validators.py`, `service.py`,
  `tests/unit/test_be01_scenario_item_upsert.py` (new); message code registration (see header).
- **Steps**:
  1. `schemas.py:120-126`: add `item_id: Optional[int] = None` to `ShippingScenarioItemCreate`; build
     `SCENARIO_ITEM_FIELDS = tuple(f for f in ShippingScenarioItemCreate.model_fields if f != "item_id")`.
  2. `repository.py:129-134`: replace the bulk delete with an upsert: load `session_obj.items` into `{item_id: row}`; a payload item with
     a known id updates the row in place (`_item_row` values via `setattr`); no id -> new row; stored rows not sent are deleted with
     `db.delete(row)`. Add `booked_item_ids(db, item_ids) -> set` querying `FreightBooking.scenario_item_id.in_(...)`.
  3. `validators.py`: add `validate_item_ids_belong(stored_ids, sent_ids)` (400 on foreign / duplicate ids, Arabic detail) and
     `validate_removed_not_booked(booked_ids)` raising `CodedHTTPException(409, "SCENARIO_ITEMS_BOOKED", ...)`.
  4. `service.py:update_session_service` (l.197-214): when `payload.items is not None`, call both validators before the repository update.
- **Acceptance criteria**: after a PUT that re-sends the same options with their ids, every `item_id` is unchanged and a booking's
  `scenario_item_id` still resolves; deleting a booked option returns 409 and changes nothing.
- **Tests to add** (`tests/unit/test_be01_scenario_item_upsert.py`): create a study with 2 options; insert a `FreightBooking` with
  `scenario_item_id` = option 1; PUT both options with ids and a changed `container_40ft_price` -> ids equal, price updated, booking's
  item exists. PUT only option 2 -> 409 `SCENARIO_ITEMS_BOOKED`. PUT option 1 + a new option without id -> 2 rows, option 2 deleted.
- **Out of scope**: clone (copies stay new rows), freight booking module.

### BE01-T03: Collision-safe codes for consultations, price lists, expense types, RFQs
- **Severity**: CRITICAL (BE01-F03, F23)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: no (same formats `CUS-YYYY-NNN`, `PL-YYYY-NNN`, `EXP-NNN`, `RFQ-YYYY-NNN`).
- **Files to change**: `modules/customs_consultation/repository.py`, `modules/customs_consultation/service.py`,
  `modules/freight_quotations/repository.py`, `tests/unit/test_be01_code_generators.py` (new)
- **Steps**:
  1. `customs_consultation/repository.py:270-293`: `return next_yearly_code(db, CustomsConsultationSession.consultation_code, "CUS", pad=3)`.
     l.121-137: same with `BrokerPriceList.price_list_code, "PL"`. `freight_quotations/repository.py:15-38`: `FreightRFQRequest.rfq_code, "RFQ"`.
  2. Expense code (l.33-46): query `max(cast(substr(expense_code, 5), Integer))` over codes `LIKE 'EXP-%'` whose suffix is digits only
     (copy the `NOT GLOB '*[^0-9]*'` filter of `common/sequence_generator.py:50-57`), +1, `EXP-{n:03d}`.
  3. In the services that create these rows, wrap add + flush in a loop of 3 attempts: on `IntegrityError` rollback, and retry only when
     the generated code now exists (pattern `purchase_orders/service.py:589-612`); after 3 attempts raise 409 with an Arabic detail.
- **Acceptance criteria**: clone (default `-COPY` code) then create -> new `CUS-<year>-<max+1>`; no 500.
- **Tests to add**: create CUS-2026-001..003, clone 003 (`CUS-2026-003-COPY`), create -> `CUS-2026-004`. Same for price lists. Expense
  codes `EXP-001`, `EXP-CUSTOM`, `EXP-007` -> next `EXP-008`.
- **Out of scope**: CBM / scenario / assessment retry (already `next_yearly_code`; add retry only if T08 touches those services).

### BE01-T04: RFQ integrity: quotation upsert, award only through `/award`, read without side effects
- **Severity**: CRITICAL (BE01-F04, F14, F15, F18 freight part, F11 RFQ part, F12 carrier part, F09 freight part, F17 N+1)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. Request: `FreightQuotationItemCreate.quotation_id: Optional[int]` (additive); `status`,
  `selected_quotation_id`, `is_awarded` in Create / Update are ignored (`extra="ignore"` style: remove the fields from the request
  classes, keep them on the Response). Award of an inactive or Cancelled RFQ -> 409. Flutter:
  `frontend/lib/features/freight_quotations/models/freight_quotation_model.dart` (`toJson` sends `quotation_id`, stops sending
  `is_awarded` / `status`), `freight_quotations_provider.dart`, `screens/freight_quotations_screen.dart` (status changes via `/award`).
- **Files to change**: `modules/freight_quotations/schemas.py`, `repository.py`, `service.py`, `validators.py`,
  `tests/unit/test_be01_freight_rfq_integrity.py` (new)
- **Steps**:
  1. Repository `update` (l.152-180): upsert by `quotation_id` (update in place, insert new, delete missing). If the awarded quotation is
     missing from the payload -> service raises 409 (`"لا يمكن حذف العرض المعتمد"`). Repository methods flush only (remove the commits
     at l.93,183,191,199); the service commits once per method.
  2. Service `_compute_rfq_metrics` (l.30-77): remove the `q.is_awarded = True` write; `awarded_name` from
     `selected_quotation_id` only. Batch import-file codes in `list_rfqs` with `codes_by_ids(db, ids)` and pass them in.
  3. `award_quotation` (l.156-204): `get_or_404(..., active_only=True)`; reject status `Cancelled` with 409.
  4. Update: reject explicit null for NOT NULL columns (`not_null_columns(FreightRFQRequest)`) with 400 Arabic detail.
  5. `validators.validate_carrier_exists`: use `require_active(db, ExternalServiceProvider, provider_id, "مقدم خدمة الشحن")`.
- **Acceptance criteria**: award -> PUT with the same quotation ids -> `selected_quotation_id` still resolves, `awarded_provider_name`
  unchanged; GET never changes `is_awarded`; create with `is_awarded=true` on two quotes stores none awarded.
- **Tests to add**: the three criteria above; award a soft-deleted RFQ -> 404; PUT `{"title": null}` -> 400.
- **Out of scope**: currency comparison (T05), audit columns (T10).

### BE01-T05: Freight comparison in one currency
- **Severity**: CRITICAL (BE01-F05, F26)
- **Depends on**: T04
- **Schema/migration needed**: no
- **API contract change**: yes, additive. `FreightQuotationItemResponse.total_cost_egp: Optional[float]`, `RankedForwarderQuote.total_cost_egp`,
  `RFQBenchmarkResponse.average_cost_egp`, `FreightRFQRequestResponse.comparison_currency = "EGP"`. `lowest_freight_cost` /
  `average_freight_cost` / `cost_saving_vs_average` become EGP values. `average_cost_usd` kept, deprecated, now = `average_cost_egp / USD rate`
  (or `None` when no USD rate). Flutter: `freight_quotations_comparison_screen.dart`, `widgets/rfq_benchmark_dialog.dart`, `freight_quotation_model.dart`.
- **Files to change**: `modules/freight_quotations/service.py`, `schemas.py`, `tests/unit/test_be01_freight_currency.py` (new)
- **Steps**:
  1. Helper `_egp_totals(db, rfq) -> Dict[quotation_id, float]` with `SettlementFx(db, "commercial").rate(q.currency_code, rfq.crd_date)`;
     a missing rate raises 409 `SETTLEMENT_FX_RATE_MISSING`.
  2. Use the EGP totals for min / avg / cost score / saving / sort key / recommendation text (remove `$`; print the currency code).
  3. Constants `COST_WEIGHT=50`, `FREE_DAYS_WEIGHT=25`, `FREE_DAYS_CAP=28`, `TRANSIT_WEIGHT=15`, `RELIABILITY_WEIGHT=10` at module top;
     reliability must not depend on `is_awarded` (use 10 for all until a provider rating exists, CTO Q5).
- **Acceptance criteria / Tests** (USD commercial 50.0, EUR 55.0 on the CRD date): quote A USD 1000 (ocean 1000), quote B EUR 950 ->
  `total_cost_egp` A 50,000.00, B 52,250.00; `lowest_freight_cost == 50000.00` (today: 950); `average_freight_cost == 51125.00`;
  benchmark rank 1 = A with `cost_score == 50.0`, B `cost_score == 0.0`. Without the EUR rate -> 409.
- **Out of scope**: currency master validation (T18).

### BE01-T06: Prefill sums values per currency
- **Severity**: CRITICAL (BE01-F07)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. `ImportRequirementPrefillResponse.shipment_value: Optional[float]` (None when the sources use several
  currencies) and new message `PREFILL_MIXED_CURRENCY` (params `currencies`); HS items may now appear once per (hs_code, currency).
  Flutter: `frontend/lib/features/import_requirements/models/import_requirement_model.dart` (nullable value),
  `widgets/prefill_messages_banner.dart` (render the code), `screens/import_requirements_screen.dart`.
- **Files to change**: `modules/import_requirements/service.py`, `schemas.py`, `tests/unit/test_be01_prefill_currency.py` (new); code registration.
- **Steps**:
  1. `service.py:584-639`: keep `totals: Dict[currency, float]`; PO line currency = `po.currency.currency_code` (no fallback);
     invoice row currency = `inv.get("currency")` (None stays None). Key `hs_items` by `(hs, currency)`.
  2. After the loops: one currency -> `shipment_value = totals[c]`, `currency = c`; several -> both None + `to_item(PREFILL_MIXED_CURRENCY, currencies=", ".join(sorted))`.
  3. l.587: `unit_price * quantity` (no `or 1.0` on quantity).
- **Tests**: PO1 USD lines 600 + 400, PO2 USD 500 -> `shipment_value == 1500.0`, `currency == "USD"`. PO1 USD 1000 + PO2 EUR 500 ->
  `shipment_value is None`, `currency is None`, message `PREFILL_MIXED_CURRENCY` with `currencies == "EUR, USD"`, two HS items when both
  lines share HS `8415820010` (one USD 1000, one EUR 500).
- **Out of scope**: `shipment_value_usd` conversion (CTO Q3).

### BE01-T07: PO exchange rate is required, never 1.0 by default
- **Severity**: MAJOR (BE01-F08)
- **Depends on**: none
- **Schema/migration needed**: no (column stays NOT NULL; CTO Q2 for nullable + backfill)
- **API contract change**: yes. `PurchaseOrderCreate.exchange_rate` required (`Field(..., gt=0)`); a create without it -> 422.
  An EGP PO sends 1.0 explicitly. Flutter: `purchase_order_model.dart:536,586` (no 1.0 default; `null` when not entered),
  `widgets/po_form_dialog.dart` (required field validator).
- **Files to change**: `modules/purchase_orders/schemas.py`, `service.py`, `tests/unit/test_be01_po_exchange_rate.py` (new)
- **Steps**: move `exchange_rate` out of `PurchaseOrderBase` into `PurchaseOrderCreate` as required; `PurchaseOrderResponse` declares
  `exchange_rate: Optional[float]`. Clone (l.685): `exchange_rate=float(original.exchange_rate)`; when it is 1.0 and the currency is not
  EGP, raise 400 `"سعر الصرف لأمر الشراء الأصلي غير مسجل. أدخل سعر الصرف قبل النسخ."`.
- **Tests**: create without `exchange_rate` -> 422; create USD with 48.5 -> stored 48.5; clone of a USD PO with 1.0 -> 400; clone of EGP PO 1.0 -> ok.
- **Out of scope**: `file_closure` display, `financial_settlement` sentinel.

### BE01-T08: One commit per use case (consultation, import requirements)
- **Severity**: MAJOR (BE01-F09)
- **Depends on**: T01, T03, T06
- **Schema/migration needed**: no
- **API contract change**: no
- **Files to change**: `modules/customs_consultation/repository.py`, `modules/customs_consultation/service.py`,
  `modules/import_requirements/repository.py`, `modules/import_requirements/service.py`, `tests/unit/test_be01_single_commit.py` (new)
- **Steps**: replace `db.commit(); db.refresh(x)` in the listed repository methods by `db.flush()`; each service method commits once
  and refreshes; IR `sync_regulatory_tasks_and_alerts` (l.72-74, 311) does not commit (the caller `best_effort` commits its own unit);
  `create_assessment_service` commits the assessment before `_sync_tasks_safely` (already the order).
- **Tests**: monkeypatch `Session.commit` with a counter: each create / update / delete of expense type, price list, assessment calls
  commit exactly once before the side-effect phase; a forced exception in the side effect leaves the core row saved.
- **Out of scope**: freight (T04), shipping scenarios (already flush-only).

### BE01-T09: Audit columns for broker price lists and expense types
- **Severity**: MAJOR (BE01-F10)
- **Depends on**: T08
- **Schema/migration needed**: yes: new Alembic revision adding nullable `created_by`, `updated_by` String(100) to
  `clearance_expense_types`, `broker_price_lists`; no backfill (unknown author stays NULL). Compatible with `schema_upgrade_service`.
- **API contract change**: additive response fields `created_by`, `updated_by` (Optional).
- **Files to change**: `alembic/versions/<new>_consultation_masters_audit_by.py`, `modules/customs_consultation/model.py`,
  `router.py` (pass `current_user.username` at l.104,131,144,193,220,233,248), `service.py`, `tests/unit/test_be01_consultation_audit.py`
- **Tests**: create / update / delete / clone as user `alice` -> `created_by` / `updated_by == "alice"`; old rows read with NULL.

### BE01-T10: Audit columns for freight RFQs
- **Severity**: MAJOR (BE01-F10)
- **Depends on**: T04
- **Schema/migration needed**: yes: nullable `created_by`, `updated_by` on `freight_rfq_requests` (same migration style as T09).
- **API contract change**: additive response fields.
- **Files to change**: new Alembic revision, `modules/freight_quotations/model.py`, `router.py`, `service.py`, `tests/unit/test_be01_freight_audit.py`
- **Tests**: create / update / award / delete / restore record the token user.

### BE01-T11: PO status workflow and lifecycle guards
- **Severity**: MAJOR (BE01-F11 PO part, F20, F29)
- **Depends on**: T07
- **Schema/migration needed**: no (allocation status code set: add `PO_ALLOCATION_STATUS` = IN_TRANSIT, ARRIVED, CUSTOMS_CLEARED,
  RECEIVED to `modules/common/enum_codes.py` + `docs/enum_codes.json`; legacy labels normalized on read)
- **API contract change**: yes. PUT with a forbidden transition -> 400; PUT / allocation on CLOSED / CANCELLED / soft-deleted PO -> 409
  `PO_NOT_EDITABLE` (new code, param `status`); DELETE of a PO with allocations -> 409 `PO_HAS_ALLOCATIONS`; allocation `status`
  returns a code. Flutter: `purchase_orders_provider.dart`, `widgets/po_balance_ledger_dialog.dart`, `po_message_snackbar.dart`.
- **Files to change**: `modules/purchase_orders/validators.py`, `service.py`, `schemas.py`, `tests/unit/test_be01_po_workflow.py`; enum / message registration.
- **Steps**: `ALLOWED = {DRAFT: {APPROVED, CANCELLED}, APPROVED: {DRAFT, CANCELLED, CLOSED}, PARTIALLY_SHIPPED: {CLOSED},
  FULLY_SHIPPED: {CLOSED}, CLOSED: {}, CANCELLED: {}}` (shipped states are set only by `_sync_po_fulfillment_status`; CTO Q4 confirms the
  table); `update` loads with `active_only=True` and rejects final statuses; `allocate_shipment` rejects final statuses; `soft_delete`
  rejects when `repo.list_allocations(po_id)` is not empty; `restore` calls `require_active(ImportFile)` before `_link_import_file`.
- **Tests**: DRAFT -> FULLY_SHIPPED via PUT -> 400; CANCELLED -> DRAFT -> 400 / 409; allocation on CLOSED PO -> 409; delete with one
  allocation -> 409; update of a soft-deleted PO -> 404 and `import_files.po_ids` unchanged.

### BE01-T12: Consultation validation (FKs, clone guard, null clearing, money inputs, price-list dates)
- **Severity**: MAJOR (BE01-F06 consultation part, F12, F18 consultation part, F22, F31)
- **Depends on**: T01, T03
- **Schema/migration needed**: no
- **API contract change**: yes, stricter: 400 for inactive / unknown FKs, 409 `CONSULTATION_EXISTS` on clone into a file that already
  has an active study, 400 on explicit null of NOT NULL fields, 422 for negative prices and `effective_to < effective_from`.
  Flutter: `customs_consultation_provider.dart`, `widgets/search_and_clone_consultation_dialog.dart`, `widgets/price_list_form_dialog.dart`.
- **Files to change**: `modules/customs_consultation/validators.py`, `service.py`, `schemas.py`, `tests/unit/test_be01_consultation_validation.py`
- **Steps**: `validate_broker_exists` -> `require_active(db, ExternalServiceProvider, id, "المخلص الجمركي")`; new
  `validate_references(db, import_file_id, po_id, project_id, broker_price_list_id, expense_type_ids)` with `require_active`; clone: target
  file = `schema.target_import_file_id or original.import_file_id`, `require_active` + `_check_one_per_file(db, file_id)`; update / price-list
  update / expense-type update reject explicit nulls for `not_null_columns(Model)`; `Field(ge=0)` on `standard_price`, `min_price`,
  `max_price`, `unit_price`, `qty (gt=0)` in Create classes; `model_validator` on price list Create / Update: `effective_to >= effective_from`.
- **Tests**: one per rule above.

### BE01-T13: Scenario clone guard and update re-validation
- **Severity**: MAJOR (BE01-F06 scenario part, F22 scenario part, F28)
- **Depends on**: T02
- **Schema/migration needed**: no
- **API contract change**: stricter (409 `SCENARIO_SESSION_EXISTS` on clone that keeps the file; 422 negative prices).
  Flutter: `shipping_scenarios_provider.dart`, `widgets/saved_scenarios_registry_tab.dart`.
- **Files to change**: `modules/shipping_scenarios/service.py`, `validators.py`, `schemas.py`, `tests/unit/test_be01_scenario_guards.py`
- **Steps**: clone (service l.236-275): when the clone keeps `import_file_id`, call `_check_one_per_file`; re-validate FKs with
  `validate_foreign_keys(db, cloned_header, source.items)`. Update: when `cargo_ready_date` changes and `items is None`, run
  `validate_scenario_items(new_crd, stored items)`; run the `avg_*_days >= 0` checks on update. `Field(ge=0)` on every `*_price`, `*_qty`,
  `total_quotation_amount`, `free_time_days` in the Create class only.

### BE01-T14: CBM totals pushed on update and link consistently
- **Severity**: MAJOR (BE01-F16, F33)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: no (PUT on an inactive calc -> 404)
- **Files to change**: `modules/cbm_calculator/service.py`, `repository.py`, `tests/unit/test_be01_cbm_po_push.py`
- **Steps**: `update_calculation_service`: `get_or_404(..., active_only=True)`; after `CBMRepository.update`, if `calc.po_id` and
  (`payload.items is not None` or `po_id` changed) call `_push_to_po` before the single commit. `link_to_po_service`: `active_only=True`;
  read the PO through a new `CBMRepository.get_po(db, po_id)`. Clone: a stored item with a zero dimension raises 400
  `"لا يمكن نسخ بند بأبعاد صفرية"` instead of a 500 (catch the `ValidationError` when building `CBMItemCreate`).
- **Tests**: create calc linked to PO (CBM 2.0) -> update items to CBM 3.0 -> `PurchaseOrder.total_cbm == 3.0` and `version` +1; update
  a soft-deleted calc -> 404.

### BE01-T15: Paginated PO list
- **Severity**: MAJOR (BE01-F17)
- **Depends on**: T11
- **Schema/migration needed**: no
- **API contract change**: additive query params `skip` (default 0) and `limit` (default None = all, max 500) on `GET /api/v1/purchase-orders`;
  header `X-Total-Count`. Body stays `List[PurchaseOrderResponse]`. Flutter: `purchase_orders_provider.dart` (may adopt paging later).
- **Files to change**: `modules/purchase_orders/router.py`, `service.py`, `repository.py`, `tests/unit/test_be01_po_pagination.py`
- **Steps**: repository returns `(rows, total)` with `query.count()` before `offset/limit`; router sets `response.headers["X-Total-Count"]`.
- **Tests**: 7 POs, `skip=5&limit=5` -> 2 rows and header 7. Same shape later for CBM / scenarios / consultations / assessments (backlog).

### BE01-T16: Legacy-tolerant response schemas
- **Severity**: MAJOR (BE01-F21)
- **Depends on**: T07, T12, T04
- **Schema/migration needed**: no
- **API contract change**: no (same fields; values that used to 500 now serialize)
- **Files to change**: `modules/purchase_orders/schemas.py`, `modules/customs_consultation/schemas.py`,
  `modules/freight_quotations/schemas.py`, `tests/unit/test_be01_legacy_responses.py`
- **Steps**: Response classes (`POLineItemResponse`, `PackingListItemResponse`, `PurchaseOrderResponse`, all consultation `*Response`,
  `FreightQuotationItemResponse`) stop inheriting `Field(min_length / gt / ge / ...)`: declare the response fields as plain or Optional types
  (money `Optional[float]`, never a fabricated 0), or derive from `LegacyRowTolerantModel` (`modules/common/legacy_rows.py`).
- **Tests**: insert raw rows with `description_ar="A"`, `quantity=0`, `hs_code="8"`, consultation `title="X"`, quotation
  `ocean_freight_cost=NULL` -> list endpoints return 200 and include the row.

### BE01-T17: Recalculation: no silent zero freight / insurance, no fabricated file code
- **Severity**: MAJOR (BE01-F19)
- **Depends on**: T12
- **Schema/migration needed**: no
- **API contract change**: additive response fields `freight_provided: bool`, `insurance_provided: bool`, `messages` with
  `RECALC_FREIGHT_MISSING` (new code); request `freight_egp` / `insurance_egp` `Optional[float] = Field(None, ge=0)`.
  Flutter: `widgets/recalculation_variance_comparison_card.dart`, `customs_consultation_model.dart`.
- **Files to change**: `modules/customs_consultation/schemas.py`, `service.py`, `tests/unit/test_be01_recalc_freight.py`; code registration.
  Route the diff through `customs-rules-reviewer`.
- **Steps**: keep CIF = FOB + entered freight + insurance (DOMAIN_RULES section 2); when freight is None, still compute with 0 but set
  `freight_provided=False` and add the message; `import_file_code=imp_file.import_file_code` (column NOT NULL, no `IMP-` fallback).
  Deemed freight / insurance when no document: CTO Q8 (do not add without a decision).
- **Tests**: tariff fixture valid on the date (rates from the fixture), PO line USD 1000, customs rate 50.0, no freight -> `final_fob_egp
  == 50000.00`, `final_cif_egp == 50000.00`, `freight_provided is False`, message present; with `freight_egp=5000`, `insurance_egp=500` ->
  `final_cif_egp == 55500.00`; `freight_egp=-1` -> 422.

### BE01-T18: Currency fields validated against the currency master (no invented defaults)
- **Severity**: MAJOR (BE01-F13)
- **Depends on**: T13, T12, T05, T06 (same files)
- **Schema/migration needed**: no for option A (validated codes, column unchanged); option B (FK `currency_id`) needs a migration: CTO Q9.
- **API contract change**: yes. Currency fields lose their default; required when the related price / value is > 0; unknown code -> 400.
  Flutter: `shipping_scenario_model.dart`, `customs_consultation_model.dart` (`'EGP'` fallbacks at l.32,75,91,214,230),
  `freight_quotation_model.dart`, `import_requirement_model.dart`.
- **Files to change**: `modules/common/validators.py` (add `require_currency_code(db, code, label_ar)` using the `currencies` table,
  active only), `modules/shipping_scenarios/schemas.py` + `validators.py`, `modules/customs_consultation/schemas.py`,
  `modules/freight_quotations/schemas.py`, `modules/import_requirements/schemas.py` (split into two PRs if > 5 files).
- **Tests**: scenario option with `container_40ft_price=1200` and no currency -> 400; `"usd"` normalized to `USD`; `"XYZ"` -> 400.

### BE01-T19: Requirement task sync hygiene
- **Severity**: MINOR (BE01-F25)
- **Depends on**: T08
- **Files to change**: `modules/import_requirements/service.py`, `tests/unit/test_be01_requirement_tasks.py`
- **Steps**: store the requirement key in a dedicated token `REQ_TYPE:<key>|` and match with `notes.like(f"%REQ_TYPE:{key}|%", escape="\\")`
  after escaping `_` and `%`; `assigned_user=import_file.owner` or None; `due_date=None` when unknown; `file_code` from the import file only.
- **Tests**: open tasks `COO` and `COO_8415820010`; completing global `COO` closes only the `COO` task.

### BE01-T20: Arabic user-facing messages in Phase 01 validators
- **Severity**: MINOR (BE01-F24)
- **Depends on**: T12, T13, T14, T04
- **Files to change**: `modules/cbm_calculator/validators.py`, `modules/shipping_scenarios/validators.py`,
  `modules/customs_consultation/validators.py`, `modules/freight_quotations/validators.py` + `service.py` (404 details)
- **Tests**: assert each detail contains Arabic text (regex `[؀-ۿ]`).

### BE01-T21: PO invented fallbacks
- **Severity**: MINOR (BE01-F27)
- **Depends on**: T15
- **API contract change**: `POBalanceSummaryResponse.currency_code: Optional[str]`. Flutter: `po_balance_ledger_dialog.dart`.
- **Files to change**: `modules/purchase_orders/service.py`, `schemas.py`, `tests/unit/test_be01_po_fallbacks.py`
- **Steps**: clone copies `quantity`, `qty_pcs`, `qty_pkg` as stored (they are NOT NULL); balance `currency_code=None` when no currency.

### BE01-T22: One owner for `import_files.selected_scenario`, ports by id
- **Severity**: MINOR (BE01-F30)
- **Depends on**: T04, T13
- **Files to change**: `modules/shipping_scenarios/service.py`, `modules/freight_quotations/service.py`, tests
- **Steps**: CTO Q10 picks the owner (scenario recommendation vs RFQ award vs freight booking). Clear the value on soft delete of the
  owning record; award writes `pol_id` / `pod_id` to the import file location FK columns when they exist (verify `import_files` columns first),
  otherwise leave the free-text fields untouched.

---

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| `POST/PUT /customs-consultations` | `total_broker_fees_egp` is server-computed (request value ignored); 409 `SETTLEMENT_FX_RATE_MISSING`; stricter FK / null / negative checks; clone 409 `CONSULTATION_EXISTS` | `customs_consultation_provider.dart`, `customs_consultation_model.dart`, `search_and_clone_consultation_dialog.dart`, `price_list_form_dialog.dart` |
| `PUT /shipping-scenarios/{id}` | items carry `item_id`; 409 `SCENARIO_ITEMS_BOOKED`; clone 409 `SCENARIO_SESSION_EXISTS` | `shipping_scenario_model.dart`, `shipping_scenarios_provider.dart`, `saved_scenarios_registry_tab.dart` |
| `POST/PUT /freight-quotations` | quotations carry `quotation_id`; `status`, `selected_quotation_id`, `is_awarded` ignored (use `/award`); new `total_cost_egp`, `comparison_currency`, `average_cost_egp`; costs compared in EGP | `freight_quotation_model.dart`, `freight_quotations_provider.dart`, `freight_quotations_screen.dart`, `freight_quotations_comparison_screen.dart`, `rfq_benchmark_dialog.dart` |
| `GET /import-requirements/prefill/{id}` | `shipment_value` nullable; message `PREFILL_MIXED_CURRENCY`; HS items per (hs, currency) | `import_requirement_model.dart`, `prefill_messages_banner.dart`, `import_requirements_screen.dart` |
| `POST /purchase-orders` | `exchange_rate` required (no 1.0 default); workflow 400 / 409 codes `PO_NOT_EDITABLE`, `PO_HAS_ALLOCATIONS`; allocation `status` codes; list `skip/limit` + `X-Total-Count`; balance `currency_code` nullable | `purchase_order_model.dart`, `po_form_dialog.dart`, `purchase_orders_provider.dart`, `po_balance_ledger_dialog.dart`, `po_message_snackbar.dart` |
| `POST /customs-consultations/recalculate-from-reconciliation` | `freight_provided`, `insurance_provided`, `messages` | `recalculation_variance_comparison_card.dart` |
| All Phase 01 currency fields | no default currency; required with a price | the four models above |

New message codes to add to the Flutter catalogs: `SCENARIO_ITEMS_BOOKED`, `PREFILL_MIXED_CURRENCY`, `PO_NOT_EDITABLE`,
`PO_HAS_ALLOCATIONS`, `RECALC_FREIGHT_MISSING` (+ enum `PO_ALLOCATION_STATUS`).

---

## 5. Open questions for the CTO

1. **Broker fees rate type (T01)**: convert non-EGP broker quote lines with the commercial or the customs rate, and on which date (study
   date or today)? Should existing sessions with non-EGP lines be recomputed by a one-off script?
2. **PO exchange rate (T07)**: keep the column NOT NULL and require it on create, or make it nullable (migration + set 1.0 on non-EGP POs to
   NULL) so "not known yet" is explicit?
3. **Assessment `shipment_value_usd` (T06)**: who fills it, and with which rate? Today it is a client-typed number next to a free-text currency.
4. **PO status table (T11)**: confirm the allowed manual transitions and whether a PO with shipments may be deleted at all.
5. **Freight benchmark reliability (T05)**: is there a provider rating source, or should the 10-point reliability criterion be removed?
6. **Broker price lists (T12)**: block overlapping active date ranges for the same broker, or keep "newest effective_from wins"?
7. **ACID plaintext (F32)**: CORE_RULES forbid plaintext ACID storage, but `import_files.acid_number` and assessments store it in clear and
   tasks copy it into message params. Encrypt / mask at rest, or amend the rule?
8. **Deemed freight / insurance (T17)**: when the user gives no freight document, must the preliminary customs estimate add a statutory
   deemed percentage, or stay at CIF = FOB + 0 with a warning?
9. **Currency master (T18)**: validated ISO codes on the existing String columns (no migration), or FK `currency_id` columns (migration + backfill)?
10. **`import_files.selected_scenario` (T22)**: which module owns it (scenario study, RFQ award, or freight booking)?
