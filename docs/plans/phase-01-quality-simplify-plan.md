# Phase 1 "Import Planning": quality audit and simplification plan

Status: proposed (2026-10-05). Nothing implemented. Based on static reading only: no pytest, flutter test, or import of `main` was run.

## Audit coverage

| Area | Depth |
|---|---|
| `modules/purchase_orders` (BP-001..003) | Full: all 6 files read line by line |
| `modules/cbm_calculator` (BP-004/005) | Service, model, router, validators, and schemas read fully. Repository read only up to `create` |
| `modules/shipping_scenarios` (BP-006/007) | Service, validators, and router read fully. Repository read for create/update |
| `modules/customs_consultation` (BP-009/010) | Router read fully. Service read for metrics, create, and recalculation. Schemas and repository not audited |
| `modules/import_requirements` (BP-011) | Router, validators, and CRUD/prefill parts of the service read. `sync_regulatory_tasks_and_alerts` (l.36-294) not audited |
| `modules/freight_quotations` (BP-008) | Grep scan only |
| Frontend | Grep-based rule scan of the 5 features. Not read line by line, so findings there are counts plus spots to verify |
| Tests | Test names inventoried. Two tests read where they pin bugs |

Severity scale:
- **BLOCKER**: breaks a non-negotiable rule, or can corrupt money, customs data, or references.
- **CRITICAL**: a wrong result or a 500 on a normal user path.
- **MAJOR**: a rule violation or real risk without immediate data loss.
- **MINOR**: hygiene.

---

## 1. Findings

### 1a. Correctness and rule violations

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| PO-01 | BLOCKER | `modules/purchase_orders/repository.py:310-352` | PUT with `items` deletes every `POLineItem` and recreates it (`po.line_items.clear()` plus `delete-orphan` on `model.py:84`). This creates new `item_id`s. Other modules keep `po_item_id` references: `po_shipment_allocations.po_item_id` (`model.py:218`), `import_documentation/service.py:1012-1013` and `:4543`, and `cargox/service.py:706,1476`. Those rows end up pointing to deleted ids. The rebuild also drops the columns that the schema does not carry (`invoice_number`, `invoice_line_number`, `customs_unit_price`, `model.py:116-118`). The CGX-003 extraction writes those columns, and `cargox/service.py:1536` reads `customs_unit_price`. | code path | Upsert line items by `item_id`. Add an optional `item_id` to `POLineItemCreate` (additive contract change). Rows with an id are updated in place. Rows without an id are inserted. Rows missing from the payload are deleted only if no allocation references them; otherwise return 409 with an Arabic detail. Columns the payload does not carry are left untouched. Packing list items get the same upsert by `packing_item_id`, which preserves `pallet_number` and `carton_numbers`. |
| PO-02 | CRITICAL | `repository.py:299-302` and `schemas.py:156-182` | Update calls `setattr` for every field that was set, including an explicit `null`. Sending `"project_id": null` (or `company_id`, `supplier_id`, `incoterm_id`, `currency_id`) makes the NOT NULL column fail on commit, which returns a 500. The service validates `data.project_id or po.project_id` (`service.py:444-448`), so the null slips past validation. | code | Drop `None` values for the NOT NULL FK fields before `setattr`, in the service, which builds the update dict. |
| PO-03 | CRITICAL | `schemas.py:170`, `repository.py:299-302`, `service.py:545-558` | `status` is free text with no validation and no transition rules. `_sync_po_fulfillment_status` overwrites any status, even Cancelled or Closed, with "Fully Shipped" or "Partially Shipped". Values are mixed English labels, not T3 codes. | code | Add a `PO_STATUS` code set to `modules/common/enum_codes.py`: DRAFT, APPROVED, PARTIALLY_SHIPPED, FULLY_SHIPPED, CLOSED, CANCELLED. Map legacy labels with `normalize()` on write. Validate in `validators.py`. The fulfillment sync must not touch CLOSED or CANCELLED. Open question Q3 asks whether the API keeps returning the legacy labels. |
| PO-04 | CRITICAL | `service.py:501-543` | `allocate_shipment` has these problems:<br>(a) No check that `import_file_id` exists or is active.<br>(b) No over-allocation guard: shipped quantity can exceed ordered quantity.<br>(c) Allocations are accepted on a soft-deleted PO, because `repo.get_by_id` does not filter `is_active`.<br>(d) `status` is a free string (`schemas.py:223`).<br>(e) ORM writes happen in the service instead of the repository.<br>(f) Two commits: allocation, then status. | code | Move persistence to `repository.add_allocation`. Validate the FK and reject an inactive PO in `validators.py`. Reject over-allocation with 400 and an Arabic detail. Open question Q4 asks whether over-shipment should be allowed with a warning instead. Use a single commit. |
| PO-05 | MAJOR | `router.py:92-109`, `schemas.py:179` | Delete and restore use `purchase_orders.edit`. The catalog has no delete permission (`modules/auth/seed_rbac.py:33-35`). `PurchaseOrderUpdate.is_active` also lets PUT soft-delete or restore. | code | Remove `is_active` from `PurchaseOrderUpdate`: delete and restore have their own endpoints. This is a contract change (the field is ignored, or rejected). Adding a `purchase_orders.delete` permission is left to the user (Q5). |
| PO-06 | MAJOR | `repository.py:17-20` | `generate_po_number` uses `count()+1` across all years. It collides with any user-typed `PO-YYYY-NNN`, and the IntegrityError becomes a 500. Two concurrent creates can get the same number. | code | Use a per-year max-suffix lookup like `CBMRepository.generate_calc_code` (`cbm_calculator/repository.py:12-28`), plus a retry on IntegrityError. Put the shared helper in `modules/common/sequence_generator.py` (new function `next_yearly_code(db, column, prefix)`). |
| PO-07 | MAJOR | `service.py:388-406`, `366-386` | `create` commits the PO, then `_sync_import_file_po_link` commits again: two transactions. If the link fails, the PO exists without the file link. `update`, `soft_delete`, and `restore` have the same pattern. | code | The repository methods `flush`, and the service commits once at the end. |
| PO-08 | MAJOR | `service.py:676-790` | Clone has these problems:<br>(a) It does not re-validate master-data FKs. A PO whose supplier or tariff is now inactive clones without error, while create would reject it.<br>(b) It clones soft-deleted POs.<br>(c) It silently drops `invoice_number`, `customs_unit_price`, `pallet_number`, and `carton_numbers`.<br>(d) `except Exception: pass` at l.759 hides a corrupt `pallet_plan`.<br>(e) It reads a non-existent attribute `p.unit` (l.737). | code | Clone builds a `PurchaseOrderCreate` and goes through `self.create()`, so every create validation applies. Reject an inactive source with 404 and an Arabic detail. Read `pallet_plan` through one helper (`_load_pallet_plan`). |
| PO-09 | MAJOR | `model.py:20-85` | No `created_by` or `updated_by` on `purchase_orders`, which breaks the Audit Trail rule. `service.py:441` and `repository.py:287` read `getattr(po, "updated_by", None)`, which is always None, so the 409 conflict payload never names who edited. | code | Additive Alembic migration: `created_by` and `updated_by` String(100) nullable on `purchase_orders` and `po_shipment_allocations`. Router passes `current_user.username` to the service on create, update, delete, restore, allocate, and clone. |
| PO-10 | MAJOR | `repository.py:259-288` vs `service.py:416-442` | The optimistic-lock check runs twice, in service and repo, with the same code. The repository holds business logic (the conflict decision). | code | Keep the check in the service only. The repository just bumps `version`. |
| PO-11 | MAJOR | `repository.py:108-252` and `:304-475` | The repository holds all CBM, weight, FOB, pallet, and chargeable-weight business math, copied twice (create and update), against the Router→Service→Repository rule. | code | Extract the math to pure functions (section 3). The repository only persists. |
| PO-12 | MAJOR | `repository.py:169,386` vs `cbm_calculator/service.py:41-45` | Volumetric factor conflict: PO uses `CBM × 167` (as in `DOMAIN_RULES.md` §7), while the CBM calculator uses `L×W×H(cm)/6000` (= CBM × 166.667). The same cargo gets two different chargeable weights. | code | Use one constant, `AIR_VOLUMETRIC_KG_PER_CBM`, in the new `modules/common/cargo_math.py`. **The CTO must choose the value (Q1).** Until then the refactor keeps both results byte-identical (factor passed as a parameter). |
| PO-13 | MAJOR | `schemas.py:51`, `repository.py:152-165,367-380` | The packing-list `unit` accepts any string. Anything other than `mm` or `m` silently counts as cm, so `"in"` gives wrong CBM. `unit` is never persisted, and the response default is "cm". Weight units (`weight_unit` = KGM/GRM/TON) are stored but never converted: a GRM row is summed as kg. | code | Restrict `unit` to `Literal["mm","cm","m"]` in the schema. Restrict `weight_unit` to the `MEASURE_UNIT` codes and convert to kg in `cargo_math`. Q6: confirm GRM/TON conversion is wanted, since it changes stored totals for existing GRM rows. |
| PO-14 | MAJOR | `service.py:50-227` | The packing-list report returns English free-text errors and warnings (l.70, 92, 96, 100, 151, 158, 181, 201) to an Arabic UI. Under the single-language rule, system messages should be `msg_code`+`params`. | code | Add `messages: List[{code, params}]` next to the existing `errors` and `warnings` (additive). Keep the English render in `errors` and `warnings` for old clients. Register the codes in `modules/common/system_messages.py`. |
| PO-15 | MINOR | `service.py:649-653`, `schemas.py:270` | `executive_summary_ar` is an Arabic sentence built on the backend. It is presentation and only works in Arabic. | code | Keep the field (contract) but have Flutter render from the numeric fields. Deprecate it in the docs. |
| PO-16 | MINOR | `validators.py:14-58`, `service.py:521,697` vs `:55,362,413,...` | Error `detail` mixes English and Arabic. The brief standard is an Arabic detail. | code | Use one `_not_found(po_id)` helper and Arabic details everywhere in the module. |
| PO-17 | MINOR | `model.py:61`, `98` | `country_of_origin` is free text (String 100), but the master-data rule requires an FK. | code | Out of scope for this refactor (needs data migration). Listed for the backlog (Q7). |
| PO-18 | MINOR | `repository.py:122` | `total_pkgs += int(quantity)` counts commercial units as packages when there is no packing list, and truncates decimals. | code | Keep the behaviour (pinned). Note in a code comment. Q8. |
| CBM-01 | BLOCKER | `modules/cbm_calculator/router.py:21-114` | No `require_permission` on any route, including create, update, delete, link, and clone. `/link` overwrites PO totals (`service.py:305-313`): any authenticated user, a viewer included, can change a PO's CBM and weight. | code | Add permissions. Simplest option with no new catalog codes: view routes get `purchase_orders.view`, mutating routes get `purchase_orders.edit`. Q5 covers dedicated codes. |
| CBM-02 | CRITICAL | `cbm_calculator/service.py:179-186`, `305-313` | CBM create and link write straight into `PurchaseOrder.total_cbm`, `total_gross_weight_kg`, and `total_packages_count`. They do not bump `version` and do not record who made the change. The next PO save (edit form) recomputes and silently overwrites the values, and stale-form detection fails. `link` commits the PO before validating the calc update (two commits). | code | Route the push through a new `PurchaseOrderService.apply_measurements(po_id, cbm, gross, pkgs, user)`, which bumps the version, then commit once. |
| CBM-03 | MAJOR | `cbm_calculator/service.py:100-121` | Stores bilingual free text in DB columns: `recommended_shipping_method = "Air Freight (شحن جوي)"`, plus `recommended_container_type` (model l.39-40), against single-language T3. The thresholds (1.5 CBM / 300 kg, 15, 33, 67, 76, 74, 53) are hard-coded. | code | Add codes `SHIPPING_METHOD` (AIR, LCL, FCL) and `CONTAINER_TYPE` (C20_ST, C40_ST, C40_HC, LCL) to `enum_codes.py`. Store the codes and normalize legacy rows on read. Move the thresholds to named constants in `cargo_math.py`. This is a contract change: Flutter maps the codes to l10n labels. |
| CBM-04 | MINOR | `cbm_calculator/schemas.py:12,28-38` vs `service.py:26-34` | An unknown `unit` is treated as cm by `convert_to_meter` but as metres by the `length_cm` property, so validation and calculation disagree. | code | `unit: Literal["mm","cm","m"]` and a single conversion function. |
| CBM-05 | MINOR | `cbm_calculator/validators.py:36-50` | FK checks ignore `is_active`. | code | `modules.common.validators.validate_active_foreign_key`. |
| CBM-06 | MINOR | `cbm_calculator/service.py:384-417` | Clone with `copy_items=False` keeps the old recommendation but zeroes the totals, which is inconsistent. | code | Set the recommendation to None when there are no items. |
| SS-01 | BLOCKER | `modules/shipping_scenarios/router.py:22-100` | No `require_permission` on any route. | code | Mutating routes get `quotations.manage`; GET routes get `quotations.view`. This uses existing codes; confirm in Q5. |
| SS-02 | MAJOR | `shipping_scenarios/service.py:226-235`, `297-321` | The duplicate-per-file guard runs on create only. Update can move a session onto a file that already has one. Update validates items only when the list is non-empty (`if payload.items:`). `selected_scenario` is written to `import_files` in a second commit. | code | Run the duplicate guard on update when `import_file_id` changes. Validate on `is not None`. Use one commit. |
| SS-03 | MAJOR | `shipping_scenarios/validators.py` | No FK validation for `po_id`, `project_id`, `import_file_id`, port ids, or provider ids. | code | `validate_active_foreign_key`. |
| SS-04 | MINOR | `shipping_scenarios/service.py:166-167` | `min_days` is computed and never used (dead). | code | Delete it. |
| CC-01 | BLOCKER | `modules/customs_consultation/service.py:612,671-706,785-789` | `recalculate_from_reconciliation_service` hard-codes `fx 50.0`, `duty 10.0%`, `VAT 14.0%`, `service fee 1.0%`, a default HS `"6802.99"`, and origin `"CN"` whenever a tariff or rate is missing. This breaks DOMAIN_RULES §2 ("no hard-coded rate; VAT ≠ 14%"). It also re-implements the customs engine instead of `customs_tariff/service.py:575 estimate_multi_item_customs_duty_service`, which resolves the customs FX rate by date. Preliminary and final lines are matched by list position (`idx`, l.690-693), not by item. | code | Missing tariff or rate: return the line with `status=TARIFF_MISSING` and exclude it from the totals, with no fallback rate. Get the FX rate from `CurrencyService._get_rate_to_egp(..., rate_type="customs")`. Compute duties through the multi-item engine. Match by `po_item_id`/`item_code`, then fall back to HS. **Route through `customs-rules-reviewer` before merge.** |
| CC-02 | BLOCKER | `customs_consultation/router.py:44-348` | No `require_permission` on any route. This includes expense-type CRUD (master data) and price-list clone. | code | Read routes get `customs_clearance.view`. Mutating routes get `customs_clearance.update`. Expense types get `master_data.view` and `master_data.edit`. |
| CC-03 | MAJOR | `customs_consultation/service.py:280-344` | `_compute_session_metrics` is a response builder that mutates the entity (`overall_status`, `readiness_percentage`, `total_broker_fees_egp`) on GET. The changes are flushed by whatever commits next. Status values are English labels (`"Blocked"`, `"Clearance Ready"`), not T3 codes. | code | Split it into `_recompute_metrics(entity)` (called on create and update only) and a pure `_to_response`. |
| CC-04 | MINOR | `customs_consultation/router.py:244-251,302-309`, `service.py:368-381` | Each route re-resolves the user from raw headers instead of using `Depends(get_current_user)`, with a fake fallback `"Customs Specialist"`. `print()` plus a swallowed exception on lifecycle and budget sync. | code | Use `current_user: User = Depends(get_current_user)` and `logging`. |
| IR-01 | CRITICAL | `modules/import_requirements/service.py:306-311`, `router.py:23-26` | The duplicate-assessment check raises `ValueError`, which the router does not catch. The global handler turns it into a 500 "Internal Server Error". The user never sees the Arabic message. `tests/unit/test_import_requirements.py:231-253` pins the bug with `pytest.raises(Exception)`. | code + test | Raise `HTTPException(409, Arabic detail)` from `validators.py`. Change the test to assert 409. |
| IR-02 | CRITICAL | `import_requirements/service.py:396,404,598-607` | The prefill invents customs data when nothing is found: HS `"8415820010"` (air conditioners), commodity "آلات وأجهزة تكييف ووحدات تبريد", `item_code "ITEM-01"`, a default COO type "EUR.1 …", and the regulator "جهاز شئون البيئة (EEAA)". Arabic literals then reach stored values when the user saves the prefill. Decree-43 detection checks whether the substring "43" appears anywhere in `regulatory_authority` (l.513, 558, 600). | code | Return empty fields plus `messages=[{code:"PREFILL_NO_HS"}]` and never fabricate. Store codes for COO type and authority (enum_codes `REGULATORY_BODY` already exists). Base Decree-43 on a tariff flag; Q9 asks whether the column exists. |
| IR-03 | MAJOR | `import_requirements/router.py:14-78` | No permissions. Logic in the router: None → 404 mapping, `ValueError` → 404. | code | Service raises `HTTPException`. Permissions: `import_files.view` and `import_files.edit`. |
| IR-04 | MAJOR | `import_requirements/service.py:320-325,343-347,353-357` | `except Exception: pass` on task sync hides failures. Update drops explicit nulls (`if v is not None`), so a field cannot be cleared. | code | Log the exception. Use `exclude_unset=True`. |
| FQ-01 | BLOCKER | `modules/freight_quotations/router.py:26-138` | No `require_permission` (grep). | grep | `freight_booking.view` and `freight_booking.create`. |
| FE-01 | MAJOR | `frontend/lib/features/purchase_orders/**` | No `ref.invalidate` anywhere in the feature (0 hits), while CORE_RULES require it after every mutation. **Verify** whether `purchase_orders_provider.dart` refreshes through a notifier method instead. If it does not, lists stay stale after add, edit, delete, clone, and allocate. cbm_calculator and shipping_scenarios have the same zero. | grep count | After every mutation call in screens and dialogs, run `ref.invalidate(purchaseOrdersProvider)` (plus the balance and report providers). |
| FE-02 | MAJOR | PO 362 / CBM 232 / SS 223 / CC 387 / IR 83 `Colors.x` hits; PO 33 `Color(0x` | Colours outside `AppTheme`. | grep count | Replace with `AppTheme.*`. This is a mechanical sweep. |
| FE-03 | MAJOR | `ElevatedButton`: PO 38, CBM 40, SS 24, CC 75, IR 20. `OutlinedButton` also present | `AppButton` is mandatory. | grep count | Replace with `AppButton` variants. |
| FE-04 | MAJOR | `isAr ?` ternaries: PO 205, CBM 87, CC 111 | Inline language ternaries instead of l10n. They break if a third locale is added, and invite storing UI-language strings. | grep count | Move them to ARB keys (`context.l10n`). |
| FE-05 | MAJOR | `po_form_dialog.dart` (4484 lines), `purchase_orders_screen.dart` (4659), `shipping_scenarios_screen.dart` (4428), `customs_consultation_screen.dart` (3806) | God widgets. Not read line by line in this audit. | wc | Split them in package F (section 3). |
| FE-06 | MINOR | `po_report_preview_dialog.dart` | Export goes through `FileSaveHelper` once per feature (1 hit). Check that every PDF/Excel export uses it with the `[Stage] - [File code].ext` file name. | grep | Verify during package F. |

No `DropdownButtonFormField`, physical `EdgeInsets.only(left/right)`, `Alignment.centerLeft`, or `TextAlign.left/right` hits were found in the 5 features.

### 1b. Duplication and simplification

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| D-01 | MAJOR | `purchase_orders/repository.py:108-252` ≡ `:304-475` | About 140 lines of totals, unit-conversion, packing, and pallet math copied between create and update. The copies differ slightly: update does not strip `item_code`, `description_en`, or `unit_of_measure` (l.337, 340, 344), while create does (l.125-132). | One `compute_po_totals(items, packing_items, pallet_plan, pallet_fallback)` in `cargo_math.py`. |
| D-02 | MAJOR | `purchase_orders/repository.py:157-165` ≡ `:372-380` ≡ `cbm_calculator/service.py:26-34` ≡ `cbm_calculator/schemas.py:28-38` | Four unit-conversion implementations. | `cargo_math.to_metres(l, w, h, unit)` and `to_cm(...)`. |
| D-03 | MAJOR | `purchase_orders/repository.py:200,207,417,423,455`, `service.py:125-134` | "Snap to integer if within 0.005" rounding copied 7 times. | `cargo_math.snap_weight(x)`. |
| D-04 | MAJOR | `shipping_scenarios/service.py:57-151`, `396-485`, `repository.py:60-150`, `225-325` | The ~90-field `ShippingScenarioItem` mapping is written out 4 times. | Use a `SCENARIO_ITEM_FIELDS` tuple derived from `ShippingScenarioItemCreate.model_fields`. Create and update use `ShippingScenarioItem(**item.model_dump(include=FIELDS))`. The response uses `ShippingScenarioItemCalculated.model_validate(item, from_attributes=True).model_copy(update=computed)`. Clone copies with `{f: getattr(src, f) for f in FIELDS}`. About 350 lines are removed. |
| D-05 | MAJOR | `purchase_orders/validators.py:14-58`, `cbm_calculator/validators.py:36-50` | Hand-written FK existence checks that ignore `modules/common/validators.py:validate_active_foreign_key`, which no Phase-1 module uses. | Use the helper, wrapped once into `HTTPException(400, Arabic detail)` by a new `require_active(db, model, id, label_ar)` in `modules/common/validators.py`. |
| D-06 | MINOR | `purchase_orders/service.py:51-56,358-363,409-414,473-478,486-491,506-511,565-570`, plus the same in CBM (5×) and shipping scenarios (5×) | "get or 404" repeated about 17 times. | A per-service `_get_or_404(id)` (simplest, no shared base class). |
| D-07 | MINOR | `cbm_calculator/repository.py:12-28`, `shipping_scenarios/repository.py:22-36`, `purchase_orders/repository.py:17-20`, `import_requirements` `repo.generate_assessment_code` | 4 yearly-code generators. | `modules/common/sequence_generator.next_yearly_code(db, column, prefix, pad=3)`. Formats stay identical: PO-YYYY-NNN, CALC-YYYY-NNN, SCE-YYYY-NNN. |
| D-08 | MINOR | `cbm_calculator/service.py:236-241,460-464`, `shipping_scenarios/service.py:186-190,280-287`, `customs_consultation/service.py:325-332`, `purchase_orders/service.py:286-288` | The import-file-code lookup (`import_file_code or custom_file_number`) is written 6 times. | `modules/import_files/repository.py`: add `codes_by_ids(db, ids) -> dict`. This is the one cross-module file edit; backend-A owns it. |
| D-09 | MAJOR | `customs_consultation/service.py:718-733` ≡ `:795-801` | The duty/VAT/fee formula is copied twice and also duplicates `customs_tariff/service.py`. | See CC-01: reuse the customs_tariff engine. |
| D-10 | MINOR | `purchase_orders/service.py:313-323` | `getattr(po, "x", default) or default` on mapped columns that always exist (dead defensive code). The `pallet_plan` JSON is parsed in 3 places (l.319-323, 753-760, `repository.py:432-436`). | `_to_response` uses plain attributes. Add one `_load_pallet_plan(po)`. |
| D-11 | MINOR | `purchase_orders/service.py:524` | Re-imports `datetime` already imported at l.2. | Delete it. |

---

## 2. Duplication map: what to reuse or create

| Concern | Today | Reuse or create | Home |
|---|---|---|---|
| CBM, unit conversion, chargeable weight, weight snap, pallet CBM | PO repo ×2, CBM service, CBM schemas | **New** pure module, no DB access | `modules/common/cargo_math.py` |
| Container and shipping-method recommendation | `cbm_calculator/service.py:99-126` | Move into `cargo_math.recommend_container(total_cbm, total_gross)` returning codes | `modules/common/cargo_math.py` |
| Active FK check plus HTTP 400 | PO and CBM validators | Existing `validate_active_foreign_key`, plus a new thin `require_active` | `modules/common/validators.py` |
| Yearly business code | 4 repos | New `next_yearly_code` | `modules/common/sequence_generator.py` |
| Import-file code lookup | 6 places | New `codes_by_ids` | `modules/import_files/repository.py` |
| Duty, VAT, and fees | `customs_consultation/service.py` ×2 | Existing `estimate_multi_item_customs_duty_service` | `modules/customs_tariff/service.py` (unchanged) |
| Optimistic lock | PO service and repo | Existing `ConcurrencyConflictException` / `log_concurrency_conflict`, called once in the service | `modules/common/concurrency.py` (unchanged) |
| Status and recommendation codes | Free text | New enum types `PO_STATUS`, `SHIPPING_METHOD`, `CONTAINER_TYPE` | `modules/common/enum_codes.py` + `docs/enum_codes.json` |
| Report and prefill messages | English or Arabic strings | `msg(code, params)` | `modules/common/system_messages.py` + `docs/system_message_codes.json` |

---

## 3. Simplification design (6-file layout kept)

### purchase_orders

- `repository.py`: only queries and persistence: `get_by_id(active_only=False)`, `get_all` (unchanged), `add(po)`, `upsert_line_items(po, rows)`, `upsert_packing_items(po, rows)`, `add_allocation`, `list_allocations`, `soft_delete`/`restore` (flush only), and `next_po_number` (via `next_yearly_code`). All math and the version check move out. The target is about 180 lines, down from 495.
- `service.py`: owns `create`, `update`, `clone` (which calls `create`), `allocate_shipment`, `compute_po_balance`, `get_packing_list_report`, and `apply_measurements` (for CBM-02).
  - Totals come from `cargo_math.compute_po_totals(...)`.
  - There is one commit per public method.
  - The audit user is passed down from the router.
  - `_to_response` is simplified (D-10).
- `validators.py`: `validate_foreign_keys` uses `require_active`. Adds `validate_status`, `validate_allocation(po, data, already_shipped)`, and `validate_item_ids_belong(po, rows)`.
- `schemas.py` changes, all additive except the last item:
  - `POLineItemCreate.item_id: Optional[int]` and `PackingListItemCreate.packing_item_id: Optional[int]`, for the PO-01 upsert.
  - `unit: Literal["mm","cm","m"]`.
  - `PackingListValidationReport.messages`.
  - `is_active` removed from `PurchaseOrderUpdate`.
- `model.py`: adds `created_by` and `updated_by` (PO-09).
- `router.py`: unchanged paths. Passes `current_user.username` to all mutating calls.
- Dead code to delete: `get_by_number` (repo l.25) unless grep finds callers, `unit` getattr at service l.737, the duplicate version check, and the re-import at l.524.

### cbm_calculator

- `service.py`: the math moves to `cargo_math`. The service keeps orchestration only. The PO push goes through `PurchaseOrderService.apply_measurements`.
- `router.py`: adds `require_permission` and `current_user`.
- `validators.py`: uses `require_active`.
- Recommendation codes (CBM-03): read path normalizes legacy text to codes.

### shipping_scenarios

- Field-list mapping (D-04) in `schemas.py` (constant) and `repository.py`.
- `service.py`: the response is built by `model_validate` plus computed fields. Clone uses the field list. `min_days` is deleted.
- `router.py` adds permissions. `validators.py` adds FK checks and the update duplicate guard.

### customs_consultation

- `recalculate_from_reconciliation_service` is rewritten on top of the customs_tariff engine (CC-01). The response schema `CustomsRecalculationResponse` is unchanged, plus an additive `lines[].status`.
- Split `_compute_session_metrics` (CC-03).
- Router: `Depends(get_current_user)` plus permissions.

### import_requirements

- Errors become `HTTPException` in validators (IR-01). Prefill stops fabricating values (IR-02). Router logic moves to the service (IR-03). Exceptions are logged (IR-04).
- The prefill service function (l.360-690, about 330 lines) is not refactored structurally in this round; only the fabrication fixes.

### Contract changes, listed explicitly

1. `PurchaseOrderUpdate.is_active` removed. Old clients that send it get the field ignored (set `extra="ignore"`).
2. `POLineItemCreate.item_id` and `PackingListItemCreate.packing_item_id`, optional and additive. Flutter must send them on edit, or edits fall back to delete-and-insert (allowed only when no allocation references the row).
3. `unit` is restricted to mm, cm, or m. Other values now get 422 instead of being treated as cm.
4. `status` on PO and `recommended_*` on CBM return codes (Q3 decides whether to keep the legacy label in a parallel `*_label` field).
5. `PackingListValidationReport.messages` and recalc `lines[].status` are additive.
6. Mutating CBM, scenario, consultation, requirement, and freight endpoints now return 403 for roles without the permission.

---

## 4. Behaviour preservation

### Must stay byte-identical (same floats, same rounding order)

- PO line `total_price = round(q*p, 2)` and `total_cbm = round(q*cbm_unit, 4)`. These are summed unrounded into `total_amount_fob` (`repository.py:115-122`).
- Packing row values:
  - `tot_net`/`tot_gross = round(qty_pkg*unit_w, 16)`.
  - `tot_cbm = round(qty_pkg*l*w*h(m), 4)`, else `total_cbm` as entered directly.
  - `chg = max(tot_gross, round(tot_cbm*167.0, 2))`.
- Precedence of PO totals, in order:
  1. Packing CBM > line CBM.
  2. Gross: keep the line gross if it is within 0.1 kg of the packing gross.
  3. Snap at 0.005.
  4. The pallet plan overrides CBM, gross, and packages.
  5. Pallet fallback from the PO pallet dims.
- On update, the stored `pallet_plan` is re-applied when no new plan is sent (`repository.py:431-436`).
- `compute_po_balance`: single-line fallback allocation (l.595-597), `round(...,1)` percentages, status thresholds.
- Packing report: totals, HS map, 0.001 and 0.01 tolerances, and the unchanged English text of warnings and errors (the frontend may parse it; verify).
- CBM calculator: `/6000` volumetric, the rounding points (l.86-97), and every recommendation bracket and hybrid/flat count.
- Shipping-scenario day arithmetic (`service.py:46-55`), the average rounded with `round()` (banker's rounding), and earliest/latest selection.

### Existing tests that pin some of it

`tests/unit/test_purchase_orders.py` (8, including 16-decimal weights and clone), `test_pl03_purchase_order_registration.py` (4), `test_packing_list.py` (5), `test_packing_list_weights.py` (2), `test_po_partial_shipments_balance.py` (2), `test_concurrency_control.py` (PO OCC 409), `test_cbm_calculator.py` (7), `test_pl05_cbm_container_loading.py` (4), `test_shipping_scenarios.py` (11), and `test_customs_consultation_recalculation.py` (2). The last one will change by design under CC-01.

### Characterization tests to add BEFORE any refactor (package T, first)

New file `tests/unit/test_phase01_characterization.py`:

1. PO create with a pallet plan: CBM, gross, and packages come from the pallets, and `pallet_count` is overwritten.
2. PO create with pallet dims only and no plan: the fallback CBM applies.
3. Packing gross within 0.1 kg of the line gross keeps the line gross. At 0.2 kg it takes the packing gross.
4. A packing row with zero dims and a direct `total_cbm` keeps the direct value. `chargeable_weight_kg` uses the ×167 factor (golden value).
5. Units mm and m produce the same stored `length_cm` and the same CBM as the cm input.
6. Update without `pallet_plan` re-applies the stored plan.
7. Update with only header fields leaves the totals unchanged.
8. Balance with a single line item plus a PO-level allocation (no `po_item_id`) uses the fallback path. Over-shipped status appears when shipped > ordered (current behaviour; PO-04 will change it, so mark it xfail when the fix lands).
9. CBM golden values: 1 CBM gives volumetric weight 166.67 (/6000), and the 15.0, 33.0, 67.0, 76.0, and 76.01 CBM boundary brackets.
10. Shipping scenario: average-days banker's rounding, using a case with an average of x.5.
11. Clone keeps `exchange_rate`, `payment_terms`, and copied items and recomputes the totals.

Regression tests for the fixes (written with each fix):

- PO-01: item_id is stable across an update, and an allocation keeps resolving to its item.
- PO-02: a null FK on update gives 400, not 500.
- PO-03 and PO-04: no status overwrite on a cancelled PO, and over-allocation gives 400.
- PO-06: a number collision is retried.
- CBM-01, SS-01, CC-02, FQ-01, IR-03: a viewer role gets 403 on POST. Use the `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)` seam.
- IR-01: duplicate gives 409. Fix `test_import_requirements.py:231-253`.
- CC-01: missing tariff gives a line status of `TARIFF_MISSING` and no 14% VAT.

Flutter: `frontend/test/features/purchase_orders/purchase_order_model_test.dart` (round-trip including the new `item_id` and `packing_item_id`), and a provider test that `invalidate` is called after a mutation.

---

## 5. Work split (4 packages, disjoint files)

| Package | Owner | Files (exclusive) | Depends on |
|---|---|---|---|
| **T: characterization tests** | backend-developer #1 | new `tests/unit/test_phase01_characterization.py`; edit `tests/unit/test_import_requirements.py` | none; **runs first and must be green on the current code** |
| **A: PO core + shared math** | backend-developer #1 (after T) | `modules/purchase_orders/*` (6 files); new `modules/common/cargo_math.py`; `modules/common/sequence_generator.py`; `modules/common/validators.py`; `modules/import_files/repository.py` (add `codes_by_ids` only); `modules/common/enum_codes.py` + `docs/enum_codes.json` (PO_STATUS, SHIPPING_METHOD, CONTAINER_TYPE); `modules/common/system_messages.py` + `docs/system_message_codes.json`; new Alembic migration `add_po_audit_by_columns`; PO regression tests in `tests/unit/test_purchase_orders.py` | T |
| **B: other Phase-1 modules** | backend-developer #2 | `modules/cbm_calculator/*`, `modules/shipping_scenarios/*`, `modules/customs_consultation/*`, `modules/import_requirements/*`, `modules/freight_quotations/router.py`; their test files | A's `cargo_math.py`, `require_active`, `next_yearly_code`, enum codes, and `PurchaseOrderService.apply_measurements`. **B starts with the routers (permissions), CC-01, and IR-01/02, which do not depend on A, and takes A's helpers after A merges step A1.** |
| **F: Flutter** | flutter-developer | `frontend/lib/features/{purchase_orders,cbm_calculator,shipping_scenarios,customs_consultation,import_requirements}/**`, `frontend/lib/l10n/*.arb`, `frontend/test/features/...` | Contract changes 1-4 from A and B. F can start immediately on FE-01..04 (invalidate, AppTheme, AppButton, l10n), which have no contract impact. |

### Order

1. **T**: characterization tests, green on the current code.
2. **A1**: `cargo_math.py` + `require_active` + `next_yearly_code` + enum and message codes. Pure helpers, with their own unit tests in `tests/unit/test_cargo_math.py`. Merge.
3. **A2** (PO-01..18) and **B** run in parallel. F runs in parallel from the start.
4. F wires the contract changes (item ids on edit, status/recommendation codes to labels, `messages` rendering) after A2 and B land.
5. Reviews: diff-reviewer (all), `customs-rules-reviewer` (CC-01, CBM-03, PO-12), and `security-reviewer` (permissions, router changes).

### Shared-file conflicts

- `modules/common/enum_codes.py`, `system_messages.py`, and both JSON contracts belong to A only. B asks A for any code it needs; there is a single message-code PR in A1.
- `modules/purchase_orders/service.py` belongs to A only. B calls `apply_measurements` and never edits the PO module.

### Risks

- **PO-01 on the live DB**: existing allocations may already point to deleted `po_line_items` ids. Before deploying, run a read-only orphan count (`po_shipment_allocations.po_item_id NOT IN po_line_items.item_id`) and report it. Do not auto-repair.
- **CBM-03 / PO-03 codes**: legacy text rows remain, so read paths must `normalize()`. Exports and search that match on the label text need a check.
- **Permissions (6)**: roles that today rely on authentication alone (e.g. viewer creating a CBM calc) will get 403. Check the role matrix in `seed_rbac.py:122-204` with the user before merging.
- **The migration** must be additive and compatible with `database/schema_upgrade_service.py` (nullable columns, no backfill).
- **Flutter god files** (4-4.6k lines): splitting while also wiring contract changes risks merge pain. F must do the mechanical sweeps (FE-02, FE-03) in separate commits per file.
- **CC-01 changes customs numbers** for files with missing tariffs, which is intended. Communicate it as a behaviour change.

### Open questions for the CTO

- **Q1**: Volumetric factor: 167 (DOMAIN_RULES, used by PO) or /6000 (used by the CBM calculator)? Until decided, both keep their current value.
- **Q2**: Should CBM link and create still overwrite PO totals at all, or only suggest the values?
- **Q3**: Return codes only, or codes plus legacy labels, for PO status and CBM recommendations?
- **Q4**: Over-shipment: block it, or allow it with an OVER_SHIPPED warning?
- **Q5**: Add dedicated permission codes (`purchase_orders.delete`, `cbm.manage`, `shipping_scenarios.manage`, `customs_consultation.manage`, `import_requirements.manage`), or reuse the existing codes proposed above?
- **Q6**: Convert GRM and TON packing weights to kg? This changes stored totals for such rows.
- **Q7**: `country_of_origin` as an FK: in scope now, or backlog?
- **Q8**: The package count from commercial quantity when there is no packing list: keep it?
- **Q9**: Does `customs_tariffs` have a Decree-43 flag column, or is one needed?

### Not audited

- `customs_consultation` repository and schemas.
- `import_requirements.sync_regulatory_tasks_and_alerts` (service l.36-294).
- `freight_quotations` beyond the router auth grep.
- Every Flutter file line by line: only grep sweeps were done.
- `frontend/test` coverage for these features.
