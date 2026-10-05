SIMPLIFY-COMMON DONE: validators.get_or_404(db, model, id, label_ar, *, active_only=False) -> 404 "<label> رقم <id> غير موجود."; validators.not_found(label_ar, id) -> the same HTTPException (for services that load through their repository); validators.not_null_columns(model) -> frozenset[str]; errors.CodedHTTPException(status_code, code, message_ar, **params) (detail = {code, message, **params}, same flat shape as today's IR_ASSESSMENT_EXISTS / CUSTOMS_FX_RATE_MISSING); errors.best_effort(db, fn, label, *args, **kwargs) -> result or None (rollback + log); system_messages.SystemMessageItem + system_messages.to_item(code, severity="warning", **params); cargo_math.LengthUnit (Annotated Literal mm/cm/m: None/blank -> cm, strip+lower, else 422) - use it instead of your unit validator; kg_per_cbm is required everywhere in cargo_math; enum_codes: kilogram = KG only (KGM/KGS/KILOGRAM are aliases), enum_codes.normalize(CONTAINER_TYPE, "N/A (Air Freight Cargo)") -> None (backend-only; the API returns null, docs/enum_codes.json is unchanged), so no special case in the CBM service; next_yearly_code is one SQL scalar (same outputs).
A1 DONE: cargo_math.{to_metres, to_cm, normalize_length_unit, snap_weight, volumetric_weight_kg(cbm, kg_per_cbm), chargeable_weight_kg(gross, cbm, kg_per_cbm), line_totals, packing_row_totals, pallet_plan_totals, PalletFallback, compute_po_totals, recommend_container(total_cbm, total_gross) -> ContainerRecommendation(shipping_method, container_type, container_count), container_counts_40hc(total_cbm) -> (hybrid, flat, savings)}; system_parameters.{get_float_parameter(db, key, default), air_volumetric_kg_per_cbm(db), seed_default_parameters(db)}; validators.require_active(db, model, id, label_ar, field_name=None, status_code=400); sequence_generator.next_yearly_code(db, column, prefix, pad=3, year=None); import_files.repository.codes_by_ids(db, ids) -> {id: code}; enum types PO_STATUS / SHIPPING_METHOD / CONTAINER_TYPE (+ MEASURE_UNIT KGM/GRM/STN/SET); permission codes purchase_orders.delete, cbm.manage, shipping_scenarios.manage, customs_consultation.manage, import_requirements.manage

# Phase 1 progress (package A: purchase orders + shared helpers)

Scratch note owned by package A. Plan: `docs/plans/phase-01-quality-simplify-plan.md`.

## A1 helpers (merged in the worktree, tests: tests/unit/test_cargo_math.py, tests/unit/test_system_parameters.py)

| Helper | Module | Notes |
|---|---|---|
| `to_metres(l, w, h, unit="cm")`, `to_cm(...)` | `modules/common/cargo_math.py` | unit mm / cm / m (case-insensitive, None = cm); anything else raises `ValueError` (map it to 422/400 at the edge) |
| `chargeable_weight_kg(gross, cbm, kg_per_cbm)` | same | `max(gross, round(cbm * factor, 2))`; `volumetric_weight_kg(cbm, factor)` = `cbm * factor` |
| `recommend_container(total_cbm, total_gross_kg)` | same | returns CODES: method AIR / LCL / FCL, container None (air) / LCL / C20_ST / C40_ST / C40_HC, count. Thresholds are the module constants (`AIR_MAX_CBM` ...) = the current CBM calculator brackets |
| `container_counts_40hc(total_cbm)` | same | (ceil(cbm/74), ceil(cbm/53), savings); 1/1/0 for 0 CBM |
| `air_volumetric_kg_per_cbm(db)` | `modules/common/system_parameters.py` | read ONCE per request and pass to cargo_math. Default 167 when the row is missing/invalid/<=0 |
| `require_active(db, Model, id, "<Arabic label>")` | `modules/common/validators.py` | `HTTPException(400, "<label> رقم <id> غير موجود أو غير نشط.")`; `status_code=404` optional |
| `next_yearly_code(db, Model.code_column, "CALC")` | `modules/common/sequence_generator.py` | `CALC-2026-004` (max numeric suffix of the year + 1). Unique constraint stays the guard: retry on IntegrityError |
| `codes_by_ids(db, ids)` | `modules/import_files/repository.py` | `{import_file_id: import_file_code or custom_file_number}` in one query |

Enum codes (`modules/common/enum_codes.py`, `docs/enum_codes.json` regenerated):
- `SHIPPING_METHOD`: AIR, LCL, FCL (legacy bilingual labels of `cbm_calculator/service.py` mapped).
- `CONTAINER_TYPE`: C20_ST, C40_ST, C40_HC, LCL (legacy labels mapped, incl. the plural "40FT High Cube Containers (40' HC)").
  `"N/A (Air Freight Cargo)"` is NOT mapped: air has no container, store NULL and treat that legacy text as NULL on read.
- `PO_STATUS`: DRAFT, APPROVED, PARTIALLY_SHIPPED, FULLY_SHIPPED, CLOSED, CANCELLED ("In Transit" legacy -> PARTIALLY_SHIPPED).

Permission codes (`modules/auth/seed_rbac.py`): `cbm.manage`, `shipping_scenarios.manage`, `customs_consultation.manage`,
`import_requirements.manage` (+ `purchase_orders.delete`). Granted to ADMIN, GENERAL_MANAGER and to the roles holding
the old code (cbm <- purchase_orders.edit, scenarios <- quotations.manage, consultation <- customs_clearance.update,
requirements <- import_files.edit). Existing DBs get the same grants once (custom roles + user overrides) on startup.

Migration: `alembic/versions/e5f6a7b8c9d0_system_parameters_and_po_audit_by.py` (new head).

## A2 (purchase orders) - for package B

A2 DONE: `PurchaseOrderService(db).apply_measurements(po_id, cbm, gross_kg, packages, user, commit=True)`: active PO
only (404 otherwise); `None` keeps a value; bumps `version`, sets `updated_at` / `updated_by`; one commit (or
`commit=False` = flush only, so the CBM service commits its own row in the same transaction). Returns PurchaseOrderResponse.
Header-only PO updates never recompute totals, so values pushed here survive a later PO edit of notes / status / terms.

## B needs codes:

Package B uses these code strings today (as plain `{code, params}` dicts / `detail["code"]`, not through `msg()`),
so nothing fails while they are unregistered. Please register them in `modules/common/system_messages.py`
+ `docs/system_message_codes.json`:

| Code | Where | Params | English template (suggested) |
|---|---|---|---|
| `PREFILL_NO_HS` | `GET /api/v1/import-requirements/prefill/{id}` -> `messages[]` | `import_file_code` | "No HS code found for import file {import_file_code}: add the tariff on the PO lines or the consultation." |
| `PREFILL_LINE_NO_HS` | same | `po_number`, `item_code` | "PO {po_number} line {item_code} has no tariff (HS code) and was skipped." |
| `IR_ASSESSMENT_EXISTS` | `POST/PUT /api/v1/import-requirements` 409 `detail.code` | `assessment_code` (also in detail) | "An active import-requirements assessment ({assessment_code}) already exists for this import file." |
| `CUSTOMS_FX_RATE_MISSING` | `POST /api/v1/customs-consultations/recalculate-from-reconciliation` 409 `detail.code` | `currency`, `on_date` | "No customs exchange rate for {currency} on {on_date}." |

Line status codes (not messages): recalculation `comparison_lines[].status` = `OK` / `TARIFF_MISSING`.

B round 2 (enum codes): new enum type `SHIPMENT_MODE` = `AIR` ("Air Freight"), `SEA` ("Sea Freight"), stored in
`cbm_calculations.shipment_mode` (Alembic f6a7b8c9d0e1). Legacy input "air" / "sea" (any case) maps to the code;
NULL = unknown (legacy rows). The schema validates the two codes itself, so nothing fails before registration.

B round 3 (simplify): new message code for package A to register:
| `SCENARIO_SESSION_EXISTS` | `POST/PUT /api/v1/shipping-scenarios` 409 `detail.code` (was a plain 400) | `session_code`, `session_id` | "An active shipping-scenario study ({session_code}) already exists for this import file." |
Raised through `CodedHTTPException`, so it fails with KeyError (500) until registered.

B round 4 (review): new message code for package A to register:
| `CONSULTATION_EXISTS` | `POST/PUT /api/v1/customs-consultations`, `POST .../{id}/restore` 409 `detail.code` (was a plain 400 on create) | `consultation_code`, `consultation_id` | "An active customs consultation ({consultation_code}) already exists for this import file." |

## Decisions recorded by package A

- Permissions: `freight_quotations` routes use `quotations.view` / `quotations.manage` instead of the plan's
  `freight_booking.*` codes (lead decision 2026-10-05: RFQs and quotes belong to the quotations permission family).
- Read grants: CUSTOMS_OFFICER gets `quotations.view` (consultation screen reads GET /shipping-scenarios) and
  LOGISTICS_OPERATOR gets `customs_clearance.view` (requirements / shipment-update screens read GET /customs-consultations).
  Existing DBs receive them once through `seed_rbac.ONE_TIME_ROLE_GRANTS` (batch id recorded in
  `system_parameters.RBAC_ONE_TIME_GRANT_BATCHES`). Built-in roles are no longer re-linked to every configured code on
  each boot: only new roles and codes inserted in that run, so an admin's removal survives a restart.
- Message code `CONSULTATION_EXISTS` (params consultation_code, consultation_id; template uses consultation_code) is registered.


B round 5 (customs review): new message code for package A to register:
| `CUSTOMS_MIXED_CURRENCY` | `POST /api/v1/customs-consultations/recalculate-from-reconciliation` 409 `detail.code` | `currencies` | "The purchase orders of this import file use different currencies ({currencies}): recalculation needs one currency per side." |
