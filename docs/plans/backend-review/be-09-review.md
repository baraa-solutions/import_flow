# Phase 09 Financial settlement (workflow): backend review

Status: 2026-10-05, static review only (no pytest, no `import main`, no DB access). Scope: the settlement **workflow**
(create / PUT / recalculate / delete / restore, CLO-01 confirm, CLO-02 approve, Odoo export gating, recalculation
engine apply/preview), not the landed-cost math. Baseline: `docs/plans/phase-09-quality-plan.md` FS-01..18 and
RC-01..07 are in the code; items verified fixed are not re-reported. "Still open from <id>" marks a partial fix.

| File | Lines | Depth |
|---|---|---|
| `modules/financial_settlement/service.py` | 2646 | full for l.1-730 (engine helpers, create, recalc, PUT, delete, restore), 1886-2005 (confirm), 2409-2646 (approve); l.730-1290 (PL-08) and 1290-1860 (CLO-01 aggregation), 2047-2400 (CLO-02 math) by read-through for workflow only (no math audit) |
| `modules/financial_settlement/router.py`, `repository.py`, `validators.py`, `model.py`, `schemas.py` | 222 / 150 / 123 / 90 / 414 | full |
| `modules/financial_settlement/odoo_export_service.py` | 501 | l.56-81 (load / status), 486-501 (filename); journal math not audited |
| `modules/recalculation/service.py`, `router.py`, `seed_dependencies.py`, `schemas.py` | 976 / 101 / 148 / 98 | full |
| `modules/recalculation/repository.py`, `model.py` | 160 / 140 | `create_log`, logs query, model columns |
| Cross-module facts | - | `customs_clearance/service.py:171-177,1379-1406` (settlement snapshot), `demurrage_detention/service.py:257-267,745-800` (push to settlement), `file_closure/validators.py:23,136-140` (gate), `file_closure/service.py:116,520-547`, `import_files/service.py:485,497-532` (close / reopen), `lifecycle_board/service.py:279-320`, `tests/unit/test_recalculation_engine.py:590-662`, `common/system_messages.py` (codes registered) |
| Business docs | - | `docs/phase_09_financial_settlement.md`, `docs/phase_09/tasks/BP-036..039` (names only) |

Verified fixed (not re-reported): permissions on every FS route (view / calculate), actor from token (FS-04), Approved
frozen for PUT / recalc / delete (FS-03), PUT `status` limited to Draft/Calculated, restore duplicate check (FS-11),
single commit + `best_effort` follow-ups in create / update / approve (FS-13), repository flush-only, collision-safe
`LCS` code with savepoint retry, confirm idempotent (409) and closes TSK-0901 by code only (FS-12), invoices_overrides
ignored, FS-01 canonical rows on approve, journal 409 when unbalanced (FS-14), filename by import file code (FS-15),
RC-01 adjustment row, RC-04 flush-only logs, RC-05 service-level view permission, RC-07 one query, coded errors
registered in `system_messages.py`.

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 4 |
| CRITICAL | 1 |
| MAJOR | 9 |
| MINOR | 8 |

Top points:

1. **A justified recalculation silently un-approves an Approved settlement (BLOCKER).** `recalculation.apply` sets
   `status = "Calculated"` while the file stays `COST_ALLOCATED`: the settlement becomes editable / deletable by PUT /
   DELETE, and it can never be re-approved (approve is refused because the file is already `COST_ALLOCATED`).
2. **A Closed file's settlement is still writable (BLOCKER).** No module checks `ImportFile.status == "Closed"`; the
   settlement status `Closed` that the guards rely on is never set by any code, and the closure gate accepts a
   `Calculated` settlement. PUT / recalc / delete / restore / recalculation apply all work after closure.
3. **The recalculation engine replaces actual costs with planning estimates (BLOCKER).** The seeded settlement
   dependencies pull customs duties, freight and clearance from the customs consultation / shipping scenario
   estimates and write an adjustment row = estimate - actual into the settlement.
4. **Customs clearance writes into an Approved settlement and breaks its totals (BLOCKER, cross-module).**
   `_sync_settlement_snapshot` has no editable guard and sets `total_expenses_egp` to the sum of `net_payable_egp`,
   which non-clearance rows do not carry (counted as 0); `total_landed_cost_egp` and items are not recomputed.
5. **Approve drops manually entered settlement rows (CRITICAL)** and has no precondition (CLO-01 not confirmed, zero
   items, zero invoices all approve to `COST_ALLOCATED`).

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE09-F01 | BLOCKER | `recalculation/service.py:453-469`, `:846-849`, `:653-661`; `financial_settlement/validators.py:43-54,68-84`; pinned by `tests/unit/test_recalculation_engine.py:659` | Apply on an `Approved` settlement (with justification) recalculates in place and sets `status = "Calculated"`. The file keeps `financial_settlement_status = "COST_ALLOCATED"`. Result: `ensure_settlement_editable` now passes, so PUT / `/recalculate` / DELETE work on the formerly approved cost; `ensure_cost_not_approved` refuses a new approve because of the file status, so the record can never return to Approved. `_refresh_file_landed_cost` updates total + markup but not `actual_landed_cost_variance_egp/pct`, and a later PUT never refreshes the file KPIs, so file and settlement diverge. | Keep `status = "Approved"` after a justified recalculation of an Approved settlement (the log already records `recalculated_approved`). `_refresh_file_landed_cost` also refreshes variance: `estimated = old_total - old_variance_egp`; `variance_egp = new_total - estimated`; `variance_pct = variance_egp / estimated * 100` (0 when estimated <= 0). Update the pinned assertion. |
| BE09-F02 | BLOCKER | `financial_settlement/service.py:552-555,650-654,665-671,710-713,717-723,1902-1903,2473-2474`; `recalculation/service.py:671-703`; `validators.py:14`; `file_closure/validators.py:23,136-140` | No Closed-file guard anywhere in Phase 9. `require_active(ImportFile)` only checks `is_active`; a closed file stays active. Settlement status `Closed` (in `LOCKED_SETTLEMENT_STATUSES` and the recalc `Closed` refusal) is never assigned by any module (grep `settlement.status =`: only `Approved` at `service.py:2523`). The closure gate accepts a `Calculated` settlement, so a typical closed file has a fully editable settlement: PUT, `/recalculate`, DELETE, restore, a new create (after delete), and recalculation apply all change the landed cost of a closed file. | `ensure_file_open(imp)` (409 `IMPORT_FILE_CLOSED`, same code and message as BE810-T02) in `financial_settlement/validators.py`; call it at the start of create, PUT, recalculate, delete, restore, confirm, approve, and in `recalculation.apply` for `financial_settlement` (load the file by `entity.import_file_id`). Preview stays allowed but returns `can_apply=False`. |
| BE09-F03 | BLOCKER | `recalculation/seed_dependencies.py:84-141`; `recalculation/service.py:311-335`; `financial_settlement/service.py:133-152,184-204` | The settlement dependencies map **estimates** onto the **actual** settlement: `customs_duties_egp` <- `customs_consultation.estimated_duties_egp`, `freight_cost_egp` <- recommended shipping-scenario quotation, `clearance_fees_egp` <- consultation `total_broker_fees_egp`. A settlement already holds the actual Form-46 duty rows (create auto-fetch `service.py:570-587`, approve rows). Apply writes `RECALC-ADJ-<field>` = estimate - actual, so the actual landed cost becomes the planning estimate (soft variance < threshold: no justification needed on a Calculated settlement). | Safe default (Q1): settlement recalculation keeps only `total_fob_egp` <- purchase orders. Remove the three expense seeds for `financial_settlement` and deactivate existing rows at seed time (`upsert_dependency` re-activates every seeded row, so add an explicit deactivate list). Budgets keep their dependencies. |
| BE09-F04 | BLOCKER | `customs_clearance/service.py:1379-1406` (called at `:1503`, `:1558` via `_follow_up`) | CL-05 invoice create / update rewrites the active settlement's `expense_invoices` with no `ensure_settlement_editable` (the demurrage push has it, `demurrage_detention/service.py:765-767`), so an Approved settlement changes behind the accountant. It then sets `total_expenses_egp = sum(net_payable_egp)` over **all** rows; rows from other sources (freight, duty, demurrage) have no `net_payable_egp` and count 0. `total_landed_cost_egp`, `average_markup_factor` and item allocations are not recomputed. Example: freight 50,000 + duty 100,000 + FOB 500,000; record a broker invoice net 5,000 -> `total_expenses_egp` = 5,000 while `total_landed_cost_egp` stays 650,000. | Skip the snapshot (log a warning) when the settlement is Approved / locked; otherwise replace the rows and call the settlement module's `_recalculate_in_place(settlement, actor)` (expose it as public `recalculate_settlement_totals`) instead of writing totals by hand. |
| BE09-F05 | CRITICAL | `financial_settlement/service.py:2486-2529` | Approve replaces `expense_invoices` with the CLO-02 aggregation only. Rows that exist only on the settlement (entered through create / PUT, e.g. bank charges, inspection, a manual freight correction, `RECALC-ADJ-*` rows) are dropped without notice; the approved landed cost is lower than what the accountant reviewed. Example: settlement has manual row `BANK-1` Bank Charges 2,500 EGP; approve -> row gone, landed cost 2,500 lower. | Safe default (Q3): before writing, compute the stored rows whose `invoice_no` is not in the aggregated set and is not an auto row (`note` "Auto-fetched ...", `RECALC-ADJ-*` handled per Q3); if any, 409 `SETTLEMENT_MANUAL_ROWS_NOT_AGGREGATED` with `invoice_nos`. No silent loss. |
| BE09-F06 | MAJOR | `financial_settlement/service.py:2473-2481`; `validators.py:35-40` (unused) | Approve has no precondition: the file need not be `INVOICES_SETTLED` (CLO-01 can be skipped), and zero item lines or zero expense invoices still approve. Approve on a file with no PO lines -> `COST_ALLOCATED`, FOB 0, and the closure gate then passes on the status alone (`file_closure/validators.py:136-140`). | `ensure_invoices_settled(imp)` (409 `INVOICES_NOT_SETTLED` when `financial_settlement_status` not in `("INVOICES_SETTLED",)`) and `validate_items_allocation_readiness(calc.items_breakdown)` turned into a coded 409 `SETTLEMENT_NO_ITEMS` before any write. |
| BE09-F07 | MAJOR | `financial_settlement/service.py:1902-1916`, `:1847` | CLO-01 confirm locks the invoices with no readiness gate: UNPAID / PARTIAL invoices (`settlement_readiness_percent` < 100) and `unsettled_warnings` are accepted silently. | Q2. Safe default: confirm returns 409 `INVOICES_NOT_READY` (`readiness`, `unpaid_count`) when readiness < 100, unless the request sets the new optional `acknowledge_unpaid: true` (recorded in the task notes and the audit log). |
| BE09-F08 | MAJOR | `financial_settlement/service.py:557-562`, `:2487-2514`; `repository.py:42-46`; `demurrage_detention/service.py:765-777` | "One active settlement per file" is a read-then-insert with no DB constraint. Two concurrent creates / approves / demurrage pushes (double click, two users) both pass and insert two active settlements; `get_settlement_by_import_file_id` has no `order_by`, so later reads pick an arbitrary one. | Alembic migration: partial unique index `uq_fs_records_active_file` on `financial_settlement_records(import_file_id) WHERE is_active = 1` (migration first reports / deactivates duplicates, keeping the newest Approved, else newest). Catch `IntegrityError` in create / approve -> 409 `SETTLEMENT_DUPLICATE_ACTIVE`. Add `order_by(settlement_id.desc())`. |
| BE09-F09 | MAJOR | `financial_settlement/service.py:650-658`, `:710-726`, `:1886-1984`, `:2456-2605` | Audit trail gaps: recalculate, soft delete, restore, CLO-01 confirm and CLO-02 approve write no `AuditLogService` row (only create / update do, `:645`, `:688`). Approve overwrites money fields with no old/new snapshot. | `best_effort(db, _audit, ...)` after the commit in each, with `old_data` (totals, status, row count) and `new_data`. Confirm audits on the ImportFile entity (`financial_settlement_status`, totals). |
| BE09-F10 | MAJOR | `financial_settlement/service.py:2543-2551` | Still open from FS-12 (fixed for confirm only): approve closes tasks by `task_code ILIKE '%0902%' OR title ILIKE '%تكلفة الوصول الفعلية%' OR title ILIKE '%CLO-02%'` with no `status != 'Completed'` filter: unrelated tasks whose title mentions CLO-02 are closed, and notes of already completed tasks are overwritten. | Same filter as confirm (`:1924-1928`): `task_code ILIKE 'TSK-0902%'` and `status != 'Completed'`. |
| BE09-F11 | MAJOR | `financial_settlement/schemas.py:35-41`; `service.py:470-476`, `:678-680` | Clients may send rows whose `invoice_no` starts with `RECALC-ADJ-`: the schema then allows negative amounts and `_validate_client_expenses` skips them. Any `financial_settlement.calculate` user can PUT `{"invoice_no":"RECALC-ADJ-x","amount_fx":-100000,...}` and lower the landed cost, bypassing the "> 0" rule and the recalculation audit. | In create: refuse any client row with the prefix (422 `SETTLEMENT_RESERVED_INVOICE_NO`). In PUT: a prefixed row is accepted only if an identical row (`invoice_no`, `amount_egp`) is already stored; otherwise 422. |
| BE09-F12 | MAJOR | `financial_settlement/odoo_export_service.py:76-81`; `router.py:115-159` | Odoo journal, CSV and Excel export work for `Draft` / `Calculated` settlements: an unapproved landed cost can be imported into the GL. | Q4. Safe default: CSV / Excel export require `status == "Approved"` (409 `SETTLEMENT_NOT_APPROVED`, `status`); the JSON journal preview stays allowed. |
| BE09-F13 | MAJOR | `demurrage_detention/service.py:765-777`; `financial_settlement/service.py:557-562,570-592` | The demurrage push creates a shell settlement (no items, no PO auto-population, no customs auto-fetch, status Draft). After that, POST create is 400 "duplicate", so the create-time auto-population is unreachable for that file; the recalculated shell has FOB 0 and landed cost = demurrage only until someone PUTs items by hand. | Extract `build_initial_settlement(db, imp_file, actor) -> LandedCostSettlementRecord` in the FS service (customs duty rows + PO items + engine) and use it from both create and the demurrage push. |
| BE09-F14 | MAJOR | `financial_settlement/schemas.py:76-96`; `model.py:47-55` | `FinancialSettlementResponse` is a plain `BaseModel` with non-null `status`, `created_by`, `updated_by`, `is_active`, `created_at`, `updated_at`, while those columns are nullable. One legacy row with a NULL makes `GET /financial-settlement` 500 for everyone (rule: `.claude/rules/backend.md` legacy rows). | `LegacyRowTolerantModel` + `@read_model`; those fields `Optional[...]`. |
| BE09-F15 | MINOR | `financial_settlement/service.py:557-562` | Duplicate create returns 400 with a free Arabic string; the coded `SETTLEMENT_DUPLICATE_ACTIVE` (409) exists and is registered. | Raise `coded_error(409, SETTLEMENT_DUPLICATE_ACTIVE, ..., settlement_code=...)`. |
| BE09-F16 | MINOR | `financial_settlement/router.py:54-63`; `repository.py:48-68` | List is unbounded and returns the full JSON blobs (`expense_invoices`, `item_landed_costs`) of every settlement. | Optional `skip` (>=0) / `limit` (1..500) query params, additive; default unchanged. |
| BE09-F17 | MINOR | `financial_settlement/model.py:51-55`; `repository.py:122-133` | Soft delete sets only `is_active`; no `deleted_at` / `deleted_by` (rule: soft delete fields). | Migration adding nullable `deleted_at`, `deleted_by`; set on delete, cleared on restore. |
| BE09-F18 | MINOR | `financial_settlement/schemas.py:62,69`; `service.py:564` | `incoterm_code` is free text on create / PUT (any string stored). | Validate against the incoterms master / enum (422 on unknown), uppercase. |
| BE09-F19 | MINOR | `financial_settlement/service.py:1909-1914` | Confirm stamps `financial_settlement_date` with the UTC date; the rest of the module uses `cairo_today()`. Between 00:00 and 02:00/03:00 Cairo the date is the previous day. | `today_date = cairo_today()`. |
| BE09-F20 | MINOR | `recalculation/service.py:786`; `schemas.py:52-56` | The hard-block check accepts a whitespace-only justification (`not justification`), unlike the Approved check (`:774` strips). | `(justification or "").strip()` in both; optional `max_length=1000`. |
| BE09-F21 | MINOR | `recalculation/service.py:925-933` | Unfiltered `GET /recalculation/dependencies` is open to any logged-in user (configuration metadata incl. permission codes). | Return only the target types the user can view (filter by `TARGET_VIEW_PERMISSIONS`). |
| BE09-F22 | MINOR | `financial_settlement/service.py:37`; `odoo_export_service.py:76-79,490-496` | Hygiene: `generate_settlement_code` imported but unused in the service; the Odoo export service queries the ORM directly instead of the repository. | Remove the import; use `repository.get_settlement_by_id`. |

## 3. Tasks

### BE09-T01: Closed import file makes the settlement read-only
- **Severity:** BLOCKER (F02)
- **Depends on:** BE810-T02 (shares code `IMPORT_FILE_CLOSED`; if it has not landed, register the code here).
- **Schema/migration needed:** no
- **API contract change:** yes: create / PUT / recalculate / DELETE / restore / confirm / approve on a Closed file:
  200/201/204 -> 409 `{code:"IMPORT_FILE_CLOSED", message, import_file_code}`; `POST /recalculation/apply` for a
  settlement of a Closed file -> 409 same code; preview returns `can_apply=false`. Flutter:
  `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`,
  `frontend/lib/core/widgets/recalculate_button.dart`, `frontend/lib/core/localization/api_error_text.dart`.
- **Files to change:** `modules/financial_settlement/validators.py`, `modules/financial_settlement/service.py`,
  `modules/recalculation/service.py`, (`modules/common/system_messages.py` + `docs/system_message_codes.json` only if
  BE810-T02 has not registered the code).
- **Steps:**
  1. `validators.py`: `ensure_file_open(imp)` -> `coded_error(409, "IMPORT_FILE_CLOSED", f"ملف الشحنة {imp.import_file_code} مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً.", import_file_code=imp.import_file_code)` when `(imp.status or "") in ("Closed", "Archived")`.
  2. `service.py`: call it after loading the file in create (`:555`), confirm (`:1902`), approve (`:2473`); for
     recalculate / PUT / delete / restore load `record.import_file` (or query by `import_file_id`) and call it before
     any write.
  3. `recalculation/service.py`: in `apply` for `financial_settlement`, load the ImportFile by `entity.import_file_id`
     and refuse through `_log_refusal_and_raise(... result_status="blocked_file_closed")`; in `preview` set
     `blocked_by_status=True, can_apply=False` when the file is closed.
- **Acceptance criteria:** every settlement write on a Closed file is 409 `IMPORT_FILE_CLOSED` and changes nothing;
  GET / simulate / aggregation / actual calculation / exports still work; after `reopen_shipment_service` writes work.
- **Tests to add:** `tests/unit/test_phase09_closed_file.py`: file `status="Closed"` with a Calculated settlement:
  PUT, POST recalculate, DELETE, PATCH restore, POST create (after the settlement is inactive), confirm, approve -> 409
  code `IMPORT_FILE_CLOSED`, `total_landed_cost_egp` unchanged; recalculation `apply` -> 409 and one log row
  `result_status="blocked_file_closed"`; preview `can_apply is False`; after reopen PUT -> 200.
- **Out of scope:** setting settlement status `Closed` on file closure (Q5), the closure gate.

### BE09-T02: A justified recalculation keeps an Approved settlement Approved
- **Severity:** BLOCKER (F01)
- **Depends on:** none (decide with Q1; this is the safe default)
- **Schema/migration needed:** no
- **API contract change:** yes: `POST /recalculation/apply` on an Approved settlement: settlement `status` stays
  `"Approved"` (was reset to `"Calculated"`); `action_taken` in the response unchanged (`recalculated`), log
  `recalculated_approved` unchanged. Flutter: `frontend/lib/core/widgets/recalculate_button.dart` (re-reads status only).
- **Files to change:** `modules/recalculation/service.py`, `tests/unit/test_recalculation_engine.py`.
- **Steps:**
  1. `_apply_in_place_to_entity` (`:453-469`): set `entity.status = "Calculated"` only when the previous status was
     not `"Approved"`; keep `"Approved"` otherwise (pass `current_status` in).
  2. `_refresh_file_landed_cost` (`:653-661`): before overwriting, read `old_total = imp.actual_landed_cost_total_egp`
     and `old_var = imp.actual_landed_cost_variance_egp`; when both are not None:
     `estimated = old_total - old_var`; `imp.actual_landed_cost_variance_egp = round(new_total - estimated, 2)`;
     `imp.actual_landed_cost_variance_pct = round((new_total - estimated) / estimated * 100, 2)` if `estimated > 0`
     else `0.0`. Then total / markup / calculated_at as today.
  3. Change the pinned assertion at `tests/unit/test_recalculation_engine.py:659` to `"Approved"`.
- **Acceptance criteria:** after a justified apply the settlement is still Approved; PUT / DELETE / `/recalculate` on it
  are 409 `SETTLEMENT_NOT_EDITABLE`; file KPIs equal the settlement totals.
- **Tests to add:** in `tests/unit/test_recalculation_engine.py`: Approved settlement, file `actual_landed_cost_total_egp
  = 150,000`, `actual_landed_cost_variance_egp = 10,000` (estimated 140,000); apply with justification making the new
  total 155,000 -> `settlement.status == "Approved"`, `imp.actual_landed_cost_total_egp == 155000.0`,
  `imp.actual_landed_cost_variance_egp == 15000.0`, `imp.actual_landed_cost_variance_pct == 10.71`; then
  `update_settlement_service` -> 409.
- **Out of scope:** revision records for settlements (Q1 alternative).

### BE09-T03: Settlement recalculation no longer overwrites actual costs with estimates
- **Severity:** BLOCKER (F03)
- **Depends on:** Q1 (safe default below)
- **Schema/migration needed:** no (seed data only)
- **API contract change:** yes: preview / apply for `financial_settlement` return only the `total_fob_egp` item
  (freight / customs / clearance items disappear). Flutter: `frontend/lib/core/widgets/recalculate_button.dart`
  (renders the list; no code change expected).
- **Files to change:** `modules/recalculation/seed_dependencies.py`, `modules/recalculation/repository.py`,
  `tests/unit/test_recalculation_engine.py`.
- **Steps:**
  1. Move the three `financial_settlement` expense seeds (`freight_cost_egp`, `customs_duties_egp`,
     `clearance_fees_egp`) out of `DEPENDENCY_SEEDS` into `RETIRED_DEPENDENCY_SEEDS` (same keys).
  2. `repository.deactivate_dependency(db, target_entity_type, target_field, source_entity_type, source_field)`:
     set `is_active=False` (flush only).
  3. `run_seed`: after upserting, deactivate every retired seed.
  4. Keep `SETTLEMENT_RECALC_FIELDS` / `apply_settlement_field_total` (still used to classify existing
     `RECALC-ADJ-*` rows); do not delete stored adjustment rows.
- **Acceptance criteria:** after `run_seed`, `get_active_dependencies_for_target(db, "financial_settlement")` returns
  only `total_fob_egp`; budgets keep their 4 dependencies.
- **Tests to add:** settlement with a `Customs Duty` row 100,000 EGP (actual) and a customs consultation
  `estimated_duties_egp = 80,000`: after `run_seed`, `preview` has no `customs_duties_egp` item and `apply` is
  `no_op` (when PO FOB matches); `settlement_field_total(rows, "customs_duties_egp") == 100000.0` unchanged.
- **Out of scope:** budget dependencies; repairing settlements that already carry adjustment rows (report count, Q1).

### BE09-T04: Customs clearance snapshot respects the settlement lock and its engine
- **Severity:** BLOCKER (F04)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** no (follow-up side effect only)
- **Files to change:** `modules/customs_clearance/service.py`, `modules/financial_settlement/service.py`,
  `tests/unit/test_phase09_regressions.py`.
- **Steps:**
  1. FS service: public `recalculate_settlement_totals(record, actor)` = current `_recalculate_in_place` body but
     keeping `status` when it is `Draft` (do not promote) - simplest: wrapper that calls `_recalculate_in_place`.
  2. `_sync_settlement_snapshot` (`:1379-1406`): if `settlement.status in LOCKED_SETTLEMENT_STATUSES` -> `logger.warning`
     and return (no change). Otherwise build the rows as today, assign, then call
     `recalculate_settlement_totals(settlement, actor)`; delete the hand-written `total_expenses_egp` line.
  3. Rows: keep `amount_egp` as the engine amount (gross); keep `net_payable_egp` as an extra key only.
- **Acceptance criteria:** after a CL-05 invoice on a Calculated settlement, the header equals the engine result over all
  rows; an Approved settlement is byte-identical before and after.
- **Tests to add:** settlement Calculated: Freight 50,000 (EGP), Customs Duty 100,000, one item FOB 500,000; record
  CL-05 invoice `amount_egp` 5,000 -> `total_expenses_egp == 155000.0`, `total_landed_cost_egp == 655000.0`. Same with
  settlement Approved -> `expense_invoices` and totals unchanged, invoice itself saved.
- **Out of scope:** CL-05 WHT math; aggregation (CLO-01) reading of clearance invoices.

### BE09-T05: Approve never drops manual settlement rows
- **Severity:** CRITICAL (F05)
- **Depends on:** Q3 (safe default below)
- **Schema/migration needed:** no
- **API contract change:** yes: `POST /approve-actual-landed-cost` -> 409 `{code:"SETTLEMENT_MANUAL_ROWS_NOT_AGGREGATED",
  message, invoice_nos:[...]}` when the active settlement has rows the aggregation does not produce. Flutter:
  `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`,
  `frontend/lib/core/localization/api_error_text.dart`.
- **Files to change:** `modules/financial_settlement/service.py`, `modules/financial_settlement/validators.py`,
  `modules/common/system_messages.py` + `docs/system_message_codes.json` (or `docs/plans/review-shared-needs.md`),
  `tests/unit/test_clo02_actual_landed_cost.py`.
- **Steps:**
  1. In approve, after `_calculate_actual_landed_cost`, when a settlement exists: `aggregated = {inv.invoice_no for inv in expense_invoices}`;
     `manual = [e for e in settlement.expense_invoices if e.get("invoice_no") not in aggregated and not str(e.get("note","")).startswith("Auto-fetched") and not (e.get("invoice_no") or "").startswith(RECALC_ADJUSTMENT_PREFIX)]`.
  2. `validators.ensure_no_manual_rows(manual)` -> 409 with `invoice_nos`. Raised before any write.
- **Acceptance criteria:** approve never reduces the expense rows silently; with no manual rows behaviour is identical.
- **Tests to add:** settlement Calculated with row `BANK-1` "Bank Charges" 2,500 EGP plus aggregated sources ->
  approve 409, `invoice_nos == ["BANK-1"]`, settlement status still `Calculated`, file status unchanged. Without
  `BANK-1` -> 200 as today.
- **Out of scope:** carrying manual rows into the CLO-02 allocation (Q3 option b; math change).

### BE09-T06: Approve preconditions (CLO-01 confirmed, items present)
- **Severity:** MAJOR (F06)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** yes: approve -> 409 `INVOICES_NOT_SETTLED` (`status`) when the file is not `INVOICES_SETTLED`;
  409 `SETTLEMENT_NO_ITEMS` when the calculation has no item line. Flutter: `financial_settlement_provider.dart`,
  the approve button in `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`
  (disable until CLO-01 confirmed), `api_error_text.dart`.
- **Files to change:** `modules/financial_settlement/validators.py`, `modules/financial_settlement/service.py`,
  `modules/common/system_messages.py` + `docs/system_message_codes.json`, `tests/unit/test_clo02_actual_landed_cost.py`.
- **Steps:** 1. `ensure_invoices_settled(imp)`: status must be `"INVOICES_SETTLED"`. 2. Replace the unused
  `validate_items_allocation_readiness` with a coded 409 `SETTLEMENT_NO_ITEMS`. 3. Call both in approve after
  `ensure_cost_not_approved` and after the calculation respectively, before any write.
- **Acceptance criteria:** approve only succeeds after confirm and with >= 1 item line.
- **Tests to add:** file `PENDING_SETTLEMENT` -> 409 `INVOICES_NOT_SETTLED`; file `INVOICES_SETTLED` with no PO lines ->
  409 `SETTLEMENT_NO_ITEMS`; normal flow confirm -> approve -> 200. Update existing CLO-02 tests that approve without
  confirm (call confirm first).
- **Out of scope:** closure gate (`file_closure/validators.py`).

### BE09-T07: One active settlement per file at DB level
- **Severity:** MAJOR (F08)
- **Depends on:** none
- **Schema/migration needed:** yes: Alembic revision creating partial unique index `uq_fs_records_active_file` on
  `financial_settlement_records(import_file_id)` `WHERE is_active = 1` (`sqlite_where=text("is_active = 1")`). Upgrade
  first deactivates duplicates (keep newest `Approved`, else highest `settlement_id`) and prints the count.
- **API contract change:** no (concurrent duplicate now 409 `SETTLEMENT_DUPLICATE_ACTIVE` instead of a second row).
- **Files to change:** `alembic/versions/<new>_fs_active_file_unique.py`, `modules/financial_settlement/model.py`
  (`__table_args__` Index), `modules/financial_settlement/repository.py`, `modules/financial_settlement/service.py`,
  `tests/unit/test_financial_settlement.py`.
- **Steps:** 1. Migration + model index. 2. `get_settlement_by_import_file_id`: `order_by(settlement_id.desc())`.
  3. `add_with_new_code`: on `IntegrityError` whose message names `uq_fs_records_active_file`, raise 409
  `SETTLEMENT_DUPLICATE_ACTIVE` (no retry); code collisions keep the retry.
- **Acceptance criteria:** inserting a second active row for the same file fails at DB level; restore of a duplicate
  still 409 via validator.
- **Tests to add:** insert two active records for one file via the session -> `IntegrityError`; `add_with_new_code` for
  a file that already has an active row -> HTTP 409 code `SETTLEMENT_DUPLICATE_ACTIVE`.
- **Out of scope:** demurrage shell logic (T10).

### BE09-T08: Audit rows and task closure for every settlement transition
- **Severity:** MAJOR (F09, F10)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** no
- **Files to change:** `modules/financial_settlement/service.py`, `tests/unit/test_phase09_regressions.py`.
- **Steps:** 1. After the commit of recalculate, delete, restore, confirm and approve: `best_effort(db, _audit, ...)`
  with actions `RECALCULATE`, `SOFT_DELETE`, `RESTORE`, `CONFIRM_INVOICES` (entity ImportFile via a small variant of
  `_audit`), `APPROVE`; old/new = `{status, total_expenses_egp, total_landed_cost_egp, rows: len(expense_invoices)}`
  captured before the change. 2. Approve task query (`:2544-2547`) -> `SmartTask.task_code.ilike("TSK-0902%")`,
  `SmartTask.status != "Completed"`.
- **Acceptance criteria:** each transition leaves exactly one audit row; a completed TSK-0902 keeps its notes; a task
  titled "... CLO-02 ..." with another code stays open.
- **Tests to add:** approve -> one `AuditLog` with action `APPROVE` and `old_data.total_landed_cost_egp`; delete /
  restore -> one row each; task `TSK-9999` titled "Review CLO-02" untouched.
- **Out of scope:** audit log schema.

### BE09-T09: Reserved RECALC-ADJ invoice numbers are server-only
- **Severity:** MAJOR (F11)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** yes: create with a `RECALC-ADJ-*` row, or PUT with a new / changed one -> 422
  `SETTLEMENT_RESERVED_INVOICE_NO` (`invoice_no`). Flutter: `widgets/settlement_form_dialog.dart` must
  resend stored adjustment rows unchanged (or omit `expense_invoices`).
- **Files to change:** `modules/financial_settlement/validators.py`, `modules/financial_settlement/service.py`,
  `tests/unit/test_financial_settlement.py`.
- **Steps:** 1. `ensure_no_client_adjustment_rows(rows, stored_rows)`: each prefixed row must match a stored row with the
  same `invoice_no` and `round(amount_egp, 2)`. 2. Call in create (stored = []) and in PUT before
  `_resolve_client_expense_rates`.
- **Acceptance criteria:** only the recalculation engine creates or changes adjustment rows.
- **Tests to add:** PUT with `{"invoice_no":"RECALC-ADJ-freight_cost_egp","amount_fx":-100000,"amount_egp":-100000,...}`
  not stored -> 422, totals unchanged; PUT resending a stored adjustment row of -2,500 -> 200, `total_expenses_egp`
  unchanged.
- **Out of scope:** schema-level negative check.

### BE09-T10: Demurrage push and create share one initial-settlement builder
- **Severity:** MAJOR (F13)
- **Depends on:** BE09-T07 (duplicate handling)
- **Schema/migration needed:** no
- **API contract change:** no (the shell now has items and duty rows)
- **Files to change:** `modules/financial_settlement/service.py`, `modules/demurrage_detention/service.py`,
  `tests/unit/test_phase09_regressions.py`.
- **Steps:** 1. Extract from create (`:564-606`) `build_initial_settlement(db, imp_file, actor, expenses_in=[], items_in=[], incoterm=None, notes=None)`
  returning an unflushed, calculated record. 2. Create calls it. 3. Demurrage push (`:769-777`) calls it instead of the
  empty record, then `add_with_new_code`.
- **Acceptance criteria:** a settlement first created by the demurrage push has the PO items and the Final-Release
  duty rows exactly as a manual create would.
- **Tests to add:** file with 1 PO line (qty 10, unit 100 USD, PO rate 50) and a Final Release clearance with
  `actual_duty_total` 20,000; push demurrage 3,000 EGP -> settlement items `fob_total_egp == 50000.0`, rows contain the
  duty row(s) totalling 20,000 and the demurrage rows; `total_landed_cost_egp == 73000.0`.
- **Out of scope:** demurrage math.

### BE09-T11: Odoo export only for approved settlements
- **Severity:** MAJOR (F12)
- **Depends on:** Q4
- **Schema/migration needed:** no
- **API contract change:** yes: `GET /{id}/export-odoo-csv` and `/export-odoo-excel` on a non-Approved settlement ->
  409 `SETTLEMENT_NOT_APPROVED` (`status`). `/odoo-journal-entry` unchanged. Flutter:
  `frontend/lib/features/financial_settlement/screens/odoo_journal_entry_dialog.dart` (disable export buttons unless
  Approved), `api_error_text.dart`.
- **Files to change:** `modules/financial_settlement/odoo_export_service.py`, `modules/financial_settlement/validators.py`,
  `modules/common/system_messages.py` + `docs/system_message_codes.json`, `tests/unit/test_odoo_gl_export.py`.
- **Steps:** `ensure_settlement_approved(settlement)` at the start of `export_odoo_csv_service` /
  `export_odoo_excel_service`; load the record through `repository.get_settlement_by_id` (F22).
- **Acceptance criteria / tests:** Calculated settlement -> CSV 409 `SETTLEMENT_NOT_APPROVED`; Approved -> CSV text
  identical to the existing golden test.
- **Out of scope:** journal math.

### BE09-T12: Response tolerance, coded duplicate, optional paging
- **Severity:** MAJOR (F14) + MINOR (F15, F16)
- **Depends on:** none
- **Schema/migration needed:** no
- **API contract change:** yes: duplicate create 400 (string) -> 409 `SETTLEMENT_DUPLICATE_ACTIVE`; list gains optional
  `skip` / `limit` (additive); response fields `status`, `created_by`, `updated_by`, `created_at`, `updated_at`,
  `is_active` may be null. Flutter: `frontend/lib/features/financial_settlement/models/financial_settlement_model.dart`
  (null-safe parsing), `financial_settlement_provider.dart` (409 message).
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/service.py`,
  `modules/financial_settlement/repository.py`, `modules/financial_settlement/router.py`,
  `tests/unit/test_financial_settlement.py`.
- **Steps:** 1. `FinancialSettlementResponse(LegacyRowTolerantModel)` + `@read_model`; listed fields `Optional`.
  2. Duplicate -> `coded_error(409, SETTLEMENT_DUPLICATE_ACTIVE, ...)`. 3. `skip: int = Query(0, ge=0)`,
  `limit: Optional[int] = Query(None, ge=1, le=500)` passed to the repository (`offset/limit`).
- **Acceptance criteria / tests:** a row with `status=NULL, created_by=NULL` inserted by SQL -> list 200 and that row
  `status is None`; second create -> 409 code; `limit=1` returns 1 row.
- **Out of scope:** a `total` count wrapper (would break the list contract).

### BE09-T13: CLO-01 confirm readiness gate and Cairo date
- **Severity:** MAJOR (F07) + MINOR (F19)
- **Depends on:** Q2
- **Schema/migration needed:** no
- **API contract change:** yes: `ConfirmInvoicesSettlementRequest.acknowledge_unpaid: bool = False` (additive);
  confirm with readiness < 100 and no acknowledgement -> 409 `INVOICES_NOT_READY` (`readiness`, `unpaid_count`).
  Flutter: `frontend/lib/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart` (confirm checkbox),
  `financial_settlement_provider.dart`, `api_error_text.dart`.
- **Files to change:** `modules/financial_settlement/schemas.py`, `modules/financial_settlement/validators.py`,
  `modules/financial_settlement/service.py`, `modules/common/system_messages.py` + `docs/system_message_codes.json`,
  `tests/unit/test_clo01_invoices_aggregation.py`.
- **Steps:** after aggregation: if `agg.settlement_readiness_percent < 100 and not payload.acknowledge_unpaid` -> 409;
  when acknowledged, append "unpaid acknowledged" to the TSK-0901 notes. `today_date = cairo_today()`.
- **Acceptance criteria / tests:** one UNPAID invoice of 5,000 out of 105,000 -> readiness 95.2, confirm 409
  `INVOICES_NOT_READY` (`unpaid_count == 1`); with `acknowledge_unpaid=true` -> 200; `financial_settlement_date ==
  cairo_today()` (freeze time at 23:30 UTC -> next Cairo day).
- **Out of scope:** payment status rules (Q8 of the phase plan).

### BE09-T14: Hygiene (soft-delete fields, incoterm, justification, dependency list)
- **Severity:** MINOR (F17, F18, F20, F21, F22)
- **Depends on:** none
- **Schema/migration needed:** yes: nullable `deleted_at DATETIME`, `deleted_by VARCHAR(100)` on
  `financial_settlement_records` (no backfill needed: active rows stay NULL; inactive legacy rows keep NULL).
- **API contract change:** yes: unknown `incoterm_code` -> 422; `/recalculation/dependencies` without a filter lists
  only viewable target types. Flutter: none expected (the add dialog already sends valid codes; verify).
- **Files to change:** `alembic/versions/<new>_fs_soft_delete_fields.py`, `modules/financial_settlement/model.py`,
  `modules/financial_settlement/repository.py`, `modules/financial_settlement/schemas.py`,
  `modules/recalculation/service.py` (split into two commits if the 5-file budget is tight).
- **Steps:** set / clear `deleted_at`, `deleted_by` in `soft_delete_settlement` / `restore_settlement`; incoterm
  validator against the incoterms master code list (uppercase); `(justification or "").strip()` in the hard-block
  check; filter `list_dependencies` by `has_user_permission`; remove the unused `generate_settlement_code` import.
- **Acceptance criteria / tests:** delete sets `deleted_by == actor`, restore clears it; `incoterm_code="XYZ"` -> 422;
  hard block with justification `"   "` -> 400; user without `financial_approval.view` does not see budget rows.
- **Out of scope:** response schema changes for the new columns (optional additive).

## 4. Frontend impact

- New / changed error codes to render (`frontend/lib/core/localization/api_error_text.dart`): `IMPORT_FILE_CLOSED`,
  `SETTLEMENT_MANUAL_ROWS_NOT_AGGREGATED` (`invoice_nos`), `INVOICES_NOT_SETTLED`, `SETTLEMENT_NO_ITEMS`,
  `SETTLEMENT_RESERVED_INVOICE_NO`, `SETTLEMENT_NOT_APPROVED`, `INVOICES_NOT_READY` (`readiness`, `unpaid_count`),
  `SETTLEMENT_DUPLICATE_ACTIVE` now also on create (was a 400 string).
- `financial_settlement_provider.dart`: approve only after confirm; confirm sends `acknowledge_unpaid` after an explicit
  user tick; after a justified recalculation the settlement stays `Approved` (do not offer edit / delete).
- `odoo_journal_entry_dialog.dart`: CSV / Excel buttons enabled only for `status == "Approved"`.
- `widgets/settlement_form_dialog.dart` (add / edit dialog): resend stored `RECALC-ADJ-*` rows unchanged or omit them; never
  create them.
- `financial_settlement_model.dart`: `status`, `created_by`, `updated_by`, `created_at`, `updated_at`, `is_active` may be
  null.
- `recalculate_button.dart`: for settlements only the FOB line appears after T03; `can_apply=false` on closed files.
- Screens must hide write actions when the file is Closed (read `ImportFile.status`).

## 5. Open questions for the CTO

1. **Q1 Recalculation on settlements:** should the settlement follow planning estimates at all? Safe default: only FOB
   from POs (T03); an Approved settlement stays Approved after a justified recalculation (T02). Alternative: forbid
   recalculation of Approved settlements entirely (409) and require a re-approval flow.
2. **Q2 CLO-01 with unpaid invoices:** block, or allow with an explicit acknowledgement? Safe default: 409 unless
   `acknowledge_unpaid=true` (T13).
3. **Q3 Manual settlement rows at approve:** (a) refuse approve until they are recorded in their source module or removed
   (safe default, T05), or (b) carry them into the CLO-02 allocation (math change, customs-rules-reviewer needed).
4. **Q4 Odoo export of unapproved settlements:** allow for preview only (safe default: JSON journal yes, CSV / Excel only
   when Approved).
5. **Q5 Settlement status `Closed`:** should file closure set the active settlement to `Closed` (making the existing
   guards live), and should the closure gate stop accepting a `Calculated` settlement (`file_closure/validators.py:23`)?
   Safe default: T01 guards on the file status; gate unchanged pending this answer.
6. **Q6 Segregation of duties:** approve and confirm use `financial_settlement.calculate` (phase plan Q3). Keep, or add
   `financial_settlement.approve` so the preparer cannot approve their own settlement?
7. **Q7 Existing data:** run read-only counts before deploying: active duplicate settlements per file (T07), settlements
   with `RECALC-ADJ-customs_duties_egp` / `-freight_cost_egp` / `-clearance_fees_egp` rows (T03), Approved settlements
   whose `status` was reset to `Calculated` while the file is `COST_ALLOCATED` (T02). Repair or report only?
