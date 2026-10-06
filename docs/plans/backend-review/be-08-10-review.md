# Phases 08 + 10 (Warehouse receiving, inland transport, file closure): backend review

Status: 2026-10-05, static review only (no pytest, no `import main`, no DB access). Baseline: the fixes from
`docs/plans/phase-08-10-quality-plan.md` (WR-01..11, IT-01..07, FC-01..13) are in the code; items verified fixed are not
re-reported. "Still open from <id>" marks a plan item that is only partly fixed.

| File | Lines | Depth |
|---|---|---|
| `modules/warehouse_receiving/service.py` | 619 | full |
| `modules/warehouse_receiving/router.py`, `repository.py`, `validators.py`, `schemas.py`, `model.py` | 132 / 84 / 149 / 156 / 87 | full |
| `modules/inland_transport/service.py`, `router.py`, `repository.py`, `validators.py`, `schemas.py`, `model.py` | 325 / 111 / 130 / 139 / 71 / 66 | full |
| `modules/file_closure/service.py` | 992 | full |
| `modules/file_closure/router.py`, `repository.py`, `validators.py`, `schemas.py`, `model.py` | 151 / 163 / 229 / 226 / 49 | full |
| Cross-module facts | - | `financial_settlement/service.py:1701-1760` (transport lines), `customs_clearance/service.py:1273-1319` (lab result / lock lift), `import_files/service.py:497-532` (reopen), `common/legacy_rows.py`, `common/sequence_generator.py`, `common/errors.py`, `common/enum_codes.normalize`, `common/system_messages.py:1277-1306`, `auth/seed_rbac.py` (codes exist) |
| Business docs | - | `docs/phase_08_warehouse_receiving.md`, `docs/phase_10_file_closure.md` (6-point gate, read-only after close, audited re-open) |

Verified fixed (not re-reported): permissions on all routes (WR/IT/FC), `grn_code` bug, verdict validation, GRN line
balance, single commit + `best_effort` follow-ups, collision-safe `next_yearly_code` + retry, restore duplicate checks,
IT duplicate waybill guard, IT `is_active` filter, IT state machine, notification columns, FC server-side gate shared by
precheck and close, no hard-coded 48.5 FX, FC_ALREADY_CLOSED, `closed_at_phase` set, dossier GRN `is_active`, coded
errors registered in `system_messages.py`.

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 4 |
| MAJOR | 18 |
| MINOR | 12 |

Top points:

1. **Phantom inland transport cost in the landed cost (BLOCKER).** The file field `inland_transport_cost_egp` is written
   only on booking create and never resynced on PUT or delete; financial settlement falls back to it when no active
   booking has a fare (`financial_settlement/service.py:1743`). A corrected or deleted fare is still charged.
2. **A Closed file is not read-only (BLOCKER).** GRN create/PUT/inspection/delete and every inland transport write work
   on a Closed file; an IT booking even moves a closed file's stage back to Phase 8.
3. **The warehouse quarantine lock can never be lifted (CRITICAL).** Customs lifts its lock after the lab result, but
   nothing clears `quarantine_lock_active` / `dispatch_blocked` on the GRN, so dispatch is refused forever and the closure
   gate blocks the file forever.
4. **Legacy rows can 500 the inland transport list (CRITICAL)**: the response schema inherits the create `min_length`
   rules and is not `LegacyRowTolerantModel`.
5. **Dossier FOB sums different currencies into one number (CRITICAL)** labelled with the last PO's currency, and a PO
   without currency is valued as USD.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE810-F01 | BLOCKER | `inland_transport/service.py:88`, `:272-314`, `:317-324`; `financial_settlement/service.py:1743-1744` | `imp.inland_transport_cost_egp` (and booking no / carrier / truck / driver / dates) is set from the newest booking on create only. PUT of `transport_fare_egp` and soft delete never resync it. Settlement adds a TRANSPORT line from this field whenever no active booking has fare > 0. Booking fare 5000 then PUT fare 0 (or delete) -> settlement still charges 5000 EGP. | One helper `sync_file_inland_fields(db, imp)` in the IT service, called by create, PUT, gate-out, arrival, delete (and restore, T15): cost = sum of active fares, other fields from the newest active booking, cleared (None) when no active booking remains. |
| BE810-F02 | BLOCKER | WR `service.py:101,297,318,362,369,426`; IT `validators.py:127-138`, `service.py:188,222,278,322` | No Closed-file guard in WR or IT. Phase 10 doc: a closed file is read-only. GRN quantities, claims, verdicts and inland fares (which feed the settlement) can change after closure; IT create on a Closed file sets `current_module` = Phase 8, stage `INLAND_TRANSPORT_BOOKED`, progress kept while `status` stays Closed. | `ensure_file_open(imp)` in both validators: 409 `IMPORT_FILE_CLOSED` (pattern of `smart_document_upload/validators.py:247` `SDU_FILE_CLOSED`). Called at the start of every write service. |
| BE810-F03 | CRITICAL | WR `service.py:145-150,388,472`; FC `service.py:125`, `validators.py:129-131`; `customs_clearance/service.py:1291-1295` | LOG-BOND-003 lock is set on the GRN at create, but no code ever clears `quarantine_lock_active` / `dispatch_blocked` (grep: only `= True`). Customs lifts its own `quarantine_lock` after a conforming lab result; the GRN keeps the lock: `validate-dispatch` is 400 forever, inspection is forced to REJECTED_QUARANTINED, and the closure gate blocks with `warehouse_quarantine` forever. | WR helper `release_quarantine_lock_for_file(db, import_file_id, user)` called by the customs lab service in the same transaction, plus a lazy refresh (`refresh_quarantine_lock(db, record)`) in validate-dispatch, inspection and the closure facts, using the latest active clearance's `quarantine_lock`. |
| BE810-F04 | CRITICAL | `inland_transport/schemas.py:61-70` (inherits `:5-25`) | `InlandTransportBookingResponse` inherits the Create rules (`min_length=2/5`) and is a plain `BaseModel`: one legacy row with a 4-char phone or NULL `created_by` / `is_active` makes `GET /bookings` and `by-file` 500. | Response = `LegacyRowTolerantModel` + `@read_model`. |
| BE810-F05 | CRITICAL | `warehouse_receiving/service.py:326-338` | PUT with new `grn_items` recomputes totals but not `discrepancy_rate_percent` / `discrepancy_type`, and checks verdict consistency only when the PUT also sends a verdict. A protocol filed as ACCEPTED_FULL stays ACCEPTED_FULL after a PUT adds shortage 3; the rate stays 0.0. | On item change: recompute the rate (same formula as inspection), re-run `validate_verdict_consistency` with the stored verdict when a protocol exists, and recompute `discrepancy_type` with the create rule when no protocol exists. |
| BE810-F06 | CRITICAL | `file_closure/service.py:428-437`, `:702` | `total_fob_fc` adds PO amounts across currencies (10,000 USD + 5,000 EUR = 15,000) and `fob_currency` is the last PO's currency, so the dossier and `summary_notes` show "15,000 EUR". A PO with no currency is assumed USD (`:433`) and converted at the USD rate. | Return `fob_by_currency` (additive). `total_fob_fc` / `fob_currency` only when exactly one currency, else `None`. A PO without a currency makes `total_fob_egp` = None (never USD). |
| BE810-F07 | MAJOR | `warehouse_receiving/service.py:321-324`, `validators.py:8-17` | PUT may set any status label (`Inspection Passed / Clean Receipt`, `Closed`, `Goods Received` on a quarantined GRN) and any verdict without the inspection protocol, the file stage sync or the TR-04 task resolution. | PUT: `inspection_verdict` not editable (400 `WR_FIELD_NOT_EDITABLE`); status limited to `PUT_STATUS_CHANGES` pairs (Q3). |
| BE810-F08 | MAJOR | `warehouse_receiving/schemas.py:25`, `service.py:110-113` | A GRN with zero lines is accepted (`grn_items = []`): totals 0, type "None", and the closure gate counts it as "warehouse received". | `grn_items: List[GrnItemSchema] = Field(..., min_length=1)`; `item_code` / `item_name` non-blank. |
| BE810-F09 | MAJOR | WR `schemas.py:18`; IT `schemas.py:12,18,23`; FC `schemas.py:20` | Invented defaults stored as real data: `warehouse_name`/`destination_warehouse` "Main Warehouse - Cairo", `truck_type` "FLATBED", fare 0.0, `archive_location` "Digital Archive Vault - 2026" (hard-coded year). | Make them required (no default). Fare required (`ge=0`). |
| BE810-F10 | MAJOR | `warehouse_receiving/service.py:101-110` | GRN create does not check customs release. Phase 8 = goods released by customs; only the under-bond path may receive before final release. | Require (clearance released / permit / `is_customs_released`) or an active under-bond clearance, else 400 `WR_CUSTOMS_NOT_RELEASED` (Q2). |
| BE810-F11 | MAJOR | WR `schemas.py:53-54,74-75`, `service.py:463-464` | `claim_amount_estimated` has no `ge=0` (negative claims) and `claim_currency` is free text defaulting to "EGP" (master data not validated, invented currency). | `ge=0`; currency default None, must be an active currency code from `currencies` when amount > 0 (400 `WR_CLAIM_CURRENCY_INVALID`). |
| BE810-F12 | MAJOR | WR `service.py:287-309,361-379,408-589`; IT `service.py` (whole); FC `service.py:163-368` | Audit trail: WR logs only create/update. No audit log for GRN delete/restore/report/inspection, any IT write, or any closure event (official close, delete, restore). Phase 10 doc requires audited close / re-open. | `best_effort(db, _audit, ...)` after each commit via `AuditLogService.log_activity`. |
| BE810-F13 | MAJOR | `inland_transport/router.py:102-110` | IT has soft delete but no restore endpoint (soft-delete rule requires restore). | `PATCH /bookings/{id}/restore` with duplicate-waybill check and file resync. |
| BE810-F14 | MAJOR | `warehouse_receiving/service.py:361-365` | GRN delete has no guard: a GRN with a filed inspection protocol / claims, or under quarantine lock, can be deleted; file stays at "GOODS_RECEIVED" / progress 98-99 with no GRN. | 409 `WR_GRN_LOCKED` when `inspection_protocol_number` is set or a claim is filed (Q5). |
| BE810-F15 | MAJOR | IT `schemas.py:21-24`, `validators.py:81-84`, `service.py:59-81` | Create accepts any status (`Arrived at Warehouse`, `Delivered`) and `actual_arrival_at` without `validate_actual_times`; the file is still synced as BOOKED/IN_TRANSIT. Skips the gate-out / arrival workflow. | Create status only Booking Confirmed / Dispatched (In Transit when `actual_departure_at`); `actual_arrival_at` on create -> 400 (use the arrival endpoint). |
| BE810-F16 | MAJOR | IT `schemas.py:9-10`, `model.py:30-31`, `service.py:54-77` | `carrier_id` is never checked (exists, active, is a carrier) and `carrier_name` is free text even when the id is given. `truck_type` unknown values pass `enum_codes.normalize` unchanged (`:61,281`). | Validate `carrier_id` against `external_service_providers` (active); take the name from it. Unknown truck type -> 400. |
| BE810-F17 | MAJOR | IT `schemas.py:52,57-58`, `service.py:182-248` | Gate-out `gate_pass_no` and arrival `seal_intact` / `seal_number` are accepted and silently dropped; a broken seal at arrival leaves no trace. Dates in the future accepted. | Append to `tracking_notes` (no migration) and require `seal_number` when `seal_intact` is false; reject dates > now + 1 day. |
| BE810-F18 | MAJOR | `file_closure/service.py:790-815` | Dossier export confirm has no precondition: it can run before GRN / customs / settlement, sets progress 99.5, stage CLOSURE_IN_PROGRESS and advances STEP_20 -> STEP_21. The gate then accepts this stale export. `dossier_exported_at` survives a reopen. | Require the gate items customs + warehouse + landed cost (400 `FC_EXPORT_BLOCKED`). Q6 for reset on reopen. |
| BE810-F19 | MAJOR | `file_closure/service.py:212-217`, `:220` | A draft closure POST at any phase overwrites `current_module` ("... (Draft)") and the stage to CLOSURE_IN_PROGRESS. `closed_at_phase` then captures that text, so a reopen goes back to "Phase 10 (Draft)". | Draft stores the record only; it changes the file tracking only when the dossier is already exported. |
| BE810-F20 | MAJOR | FC `service.py:86-88,182,338-339,805`; WR `service.py:114,465-466`, `schemas.py:27,55` | Still open from FC-10/WR-06: `auditor_name`, `exported_by`, `inspector_name` accept any client text (only blank / legacy defaults fall back to the user). `.claude/rules/backend.md`: the acting user comes from the token only. | Record `current_user.username`; a different signer (Q4) goes into a separate field or the notes. |
| BE810-F21 | MAJOR | WR `repository.py:36-58`, IT `repository.py:91-116`, `router.py` list routes | List endpoints are unbounded (`.all()`, GRN rows carry the JSON lines). | `skip`/`limit` (default 200, max 1000) + `X-Total-Count` header (body shape unchanged). |
| BE810-F22 | MAJOR | `file_closure/service.py:444,458,470-473,530-534,736,700-705,933` | Still open from FC-07/FC-13: dossier invents values: PO `exchange_rate` 1.0, `item_code` "ITM-001", the file's *estimated* cost shown as FOB, markup factor 1.0, net weight = sum of gross weights, `summary_notes` states "complete all ten phases, ready to archive" for any file. | Return None / "" for unknown values, mark the estimated fallback (`fob_source = "ESTIMATE"`), build `summary_notes` from the real status (or drop it). |
| BE810-F23 | MAJOR | `file_closure/service.py:689-698` vs `validators.py:106-175` | `closure_readiness` re-implements the gate with different rules (docs = ACID AND Form4/SWIFT; landed = cost > 0 AND status) and `tasks_closed` is hard-coded `True`. The dossier screen can say "not ready" while close succeeds, and the reverse. | Build `closure_readiness` from `evaluate_file_closure_gate(db, imp).checklist` (keep `eir_returned` alias). |
| BE810-F24 | MAJOR | `file_closure/schemas.py:31-47` | `FileClosureResponse` is not legacy tolerant: NULL `status` / `created_by` / `closed_at` or a non-bool checklist value in an old row 500s the closure list. | `LegacyRowTolerantModel` + `closure_checklist: Dict[str, Optional[bool]]`, `closed_at: Optional[datetime]`. |
| BE810-F25 | MAJOR | `import_files/service.py:497-532` (outside scope) | Reopen leaves the active closure record "Closed", writes no audit log, does not reset `dossier_exported_at`. Phase 10 doc: audited re-open. | Shared need (section 5); not a task here. |
| BE810-F26 | MINOR | `warehouse_receiving/validators.py:123-133` | `validate_verdict_matches` raises `WR_VERDICT_INCONSISTENT` with `{verdict, expected_verdict}`; the registered template for that code needs `shortage_qty`/`damaged_qty`. `WR_VERDICT_INCONSISTENT_EXPECTED` exists (`system_messages.py:1288`). | Use `WR_VERDICT_INCONSISTENT_EXPECTED`. |
| BE810-F27 | MINOR | IT `service.py:115`; FC `service.py:102-110` | Legacy title matches are too broad: `%نقل%` auto-completes any task with "transport" in the title; `"إغلاق" in title` auto-completes any "closing" task (e.g. LC closure) at file close. | Keep msg_code / task_type / task_code matches; legacy title match only for exact legacy titles (`TR-01`, `CLO-04`). |
| BE810-F28 | MINOR | IT `service.py:138-139` | Task `assigned_user="Warehouse Manager"` (not a user) and `phase_name="Phase 6: Inbound & Final Closure"`. | Assign to `user`; phase name for Phase 8. |
| BE810-F29 | MINOR | WR `schemas.py:33`, `service.py:294-305` | Report-discrepancy defaults `quarantine_zone_assigned=True` and sets status "Discrepancy Reported" even when type is "None". | Default False; type "None" -> 400. |
| BE810-F30 | MINOR | `file_closure/repository.py:60` | `add_closure` sets `closed_at=now` on a Draft record. | `closed_at` only when status is Closed (response field Optional, F24). |
| BE810-F31 | MINOR | `file_closure/service.py:91-94` | `_require_any_permission` returns (fail-open) when `actor is None`; any internal caller of `close_import_file_service` skips the write permission. | Internal callers pass the actor; `None` only for `official_close` (route-guarded) via an explicit flag. |
| BE810-F32 | MINOR | `file_closure/service.py:943-945` | Precheck returns `can_close=False` for a Closed file with empty `blocking_reasons`. | Add an "already closed" blocking reason / key. |
| BE810-F33 | MINOR | `file_closure/service.py:432-467` | N+1 in the dossier: `po.currency`, `po.line_items`, `itm.tariff` lazy-loaded per PO / item. | `selectinload` in `repo.active_purchase_orders`. |
| BE810-F34 | MINOR | `warehouse_receiving/service.py:319` | `exclude_none=True` on PUT: optional text fields (notes, root_cause, claim ref) can never be cleared. | `exclude_unset=True` only, keep the NOT NULL filter for non-nullable columns. |
| BE810-F35 | MINOR | `file_closure/service.py:817-875` | Repeated dossier export overwrites notes of already completed TSK-0903 tasks and posts a new notification each time. | Filter tasks on open statuses; notify only on the first export (or on format change). |
| BE810-F36 | MINOR | WR `service.py:455` | `inspection_date` can be in the future. | Reject > now + 1 day. |

## 3. Tasks

Conventions for every task: run tests only with a scratch `DATABASE_PATH`; read results from `--junitxml` + exit code;
never edit `.env` / `*.db`; Python 3.12 (import every typing name used in signatures); no business logic in routers;
Arabic `detail` for user-facing errors; a new coded error must be registered in `modules/common/system_messages.py` +
`docs/system_message_codes.json` + Flutter catalogs in the same change (if you do not own those files, add the code to
`docs/plans/review-shared-needs.md` and use the existing `coded_error` helpers meanwhile).

### BE810-T01: Resync the file's inland transport fields from the active bookings
- **Severity:** BLOCKER (F01). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** no (response shapes unchanged). Behaviour: `ImportFile.inland_transport_cost_egp` becomes the
  sum of active booking fares.
- **Files to change:** `modules/inland_transport/service.py`, `modules/inland_transport/repository.py`,
  `tests/unit/test_tr01_inland_transport_coordination.py`.
- **Steps:**
  1. Repository: `list_active_bookings_for_file(db, import_file_id)` ordered by `transport_id desc`.
  2. Service: `_sync_file_inland_fields(db, imp)`: bookings = active list. If empty: set `inland_transport_cost_egp=0.0`,
     `inland_transport_booking_no`, `inland_carrier_name`, `inland_truck_plate_no`, `inland_driver_name`,
     `inland_driver_phone`, `inland_departure_date`, `inland_expected_arrival_date` to None (do not touch status /
     stage). Else cost = `round(sum(b.transport_fare_egp or 0), 2)`; the other fields from `bookings[0]`
     (departure = `actual_departure_at or planned_departure_at`).
  3. Call it in create (replace lines 83-92 except status), update (before commit), gate-out, arrival, soft delete.
  4. Do not flush-before-query issues: call after `apply_changes` and `db.flush()`.
- **Acceptance criteria:** the file cost always equals the sum of active fares; settlement fallback
  (`financial_settlement/service.py:1743`) can no longer charge a deleted or corrected fare.
- **Tests to add** (`tests/unit/test_tr01_inland_transport_coordination.py`):
  - Booking A fare 3000, booking B fare 2000 (different waybills) -> `imp.inland_transport_cost_egp == 5000.0`.
  - PUT B fare 0 -> 3000.0. Delete A -> 0.0 and `inland_transport_booking_no` == B's waybill (B is still active).
    Then delete B -> cost 0.0 and `inland_transport_booking_no is None`.
  - Settlement aggregation (`financial_settlement` invoice aggregation service) after A fare 5000 then PUT fare 0:
    no TRANSPORT line with amount 5000.
- **Out of scope:** settlement code, Q9 policy beyond "sum".

### BE810-T02: Closed file is read-only for warehouse receiving and inland transport
- **Severity:** BLOCKER (F02). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: every WR/IT write on a file with `status == "Closed"` returns 409
  `{code: "IMPORT_FILE_CLOSED", message, import_file_code}`. Flutter: `warehouse_receiving_provider.dart`,
  `inland_transport_provider.dart` (show `ApiErrorText.of`).
- **Files to change:** `modules/warehouse_receiving/validators.py`, `modules/warehouse_receiving/service.py`,
  `modules/inland_transport/validators.py`, `modules/inland_transport/service.py`,
  `tests/unit/test_phase08_10_regressions.py`.
- **Steps:**
  1. In each validators: `ensure_file_open(imp)` -> raise `coded_error(409, "IMPORT_FILE_CLOSED", "ملف الشحنة <code> مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً.", import_file_code=...)` when `imp.status == "Closed"`.
  2. WR: call in create, update, report-discrepancy, inspection, delete, restore (load the file by `record.import_file_id`).
  3. IT: call in create (`validate_import_file_for_transport` returns the file), update, gate-out, arrival, delete.
  4. Register `IMPORT_FILE_CLOSED` (shared need if not your file).
- **Acceptance criteria:** no WR/IT write succeeds on a Closed file; reads still work.
- **Tests to add:** close a file (set `status="Closed"`), then: GRN PUT -> 409 code IMPORT_FILE_CLOSED; inspection -> 409;
  IT create -> 409 and `imp.current_module` unchanged; IT gate-out -> 409. GET list still 200.
- **Out of scope:** other modules' writes; reopen flow.

### BE810-T03: Release the GRN quarantine lock when customs lifts it
- **Severity:** CRITICAL (F03). **Depends on:** T02 (guard order only).
- **Schema/migration needed:** no.
- **API contract change:** no new fields; behaviour: `quarantine_lock_active`/`dispatch_blocked` become false after a
  conforming lab result; `validate-dispatch` then returns 200.
- **Files to change:** `modules/warehouse_receiving/service.py`, `modules/customs_clearance/service.py` (one call),
  `modules/file_closure/service.py`, `tests/unit/test_under_bond_and_quarantine.py` (or the regressions file).
- **Steps:**
  1. WR service: `release_quarantine_lock_for_file(db, import_file_id, user)` (no commit): for each active GRN of the
     file with `quarantine_lock_active`: set `quarantine_lock_active=False`, `dispatch_blocked=False`; if status is
     "Under Bond Quarantine" set "Goods Received"; append " | Quarantine lock lifted after lab approval" to notes;
     `updated_by=user`.
  2. WR service: `refresh_quarantine_lock(db, record, user)`: if `record.quarantine_lock_active` and the latest active
     `CustomsClearanceRecord` of the file has `quarantine_lock == False`, apply step 1 to this record and commit.
     Call it at the start of `validate_warehouse_dispatch_authorization` and `submit_warehouse_inspection_protocol_service`.
  3. `customs_clearance/service.py` `record_lab_result_and_lift_quarantine_service`: after `record.quarantine_lock = False`
     (line 1293), call the WR helper before `db.commit()` (local import to avoid cycles).
  4. File closure `_closure_facts`: `locked_grn_count` counts a GRN only when the clearance lock is still active (read
     only, no write).
- **Acceptance criteria:** under-bond file -> GRN locked -> lab CONFORMING + lift -> GRN unlocked, dispatch 200,
  closure gate no longer reports `warehouse_quarantine`. Non-conforming result keeps the lock.
- **Tests to add:** the flow above; plus a legacy locked GRN whose clearance is already unlocked -> `validate-dispatch`
  returns 200 and the record is unlocked.
- **Out of scope:** lab certificate columns on the GRN (Q1).

### BE810-T04: Legacy-tolerant response schemas (IT, FC)
- **Severity:** CRITICAL (F04) + MAJOR (F24). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** `FileClosureResponse.closed_at` and checklist values become nullable (`closed_at: datetime -> datetime|null`).
  Flutter: `frontend/lib/features/file_closure/models/file_closure_model.dart` must accept null `closed_at`.
- **Files to change:** `modules/inland_transport/schemas.py`, `modules/file_closure/schemas.py`,
  `tests/unit/test_phase08_10_regressions.py`.
- **Steps:** IT: define `InlandTransportBookingResponse(LegacyRowTolerantModel)` with the same fields as the base but
  decorate with `@read_model` (or inherit Base + `LegacyRowTolerantModel` and `@read_model`); money `transport_fare_egp`
  becomes `Optional[float]`. FC: `FileClosureResponse(LegacyRowTolerantModel)`, `closure_checklist: Dict[str, Optional[bool]]`,
  `closed_at: Optional[datetime]`.
- **Acceptance criteria:** a row with `driver_phone="123"` and NULL `created_by` lists fine; a closure row with NULL
  `status` lists fine.
- **Tests to add:** insert such rows with raw SQL into a scratch DB; `GET /api/v1/inland-transport/bookings` and
  `GET /api/v1/file-closure` return 200 with the row.
- **Out of scope:** create/update validation (unchanged).

### BE810-T05: GRN PUT keeps rate, type and verdict consistent; PUT cannot bypass the workflow
- **Severity:** CRITICAL (F05) + MAJOR (F07, F34). **Depends on:** T02.
- **Schema/migration needed:** no.
- **API contract change:** yes: PUT `inspection_verdict` -> 400 `WR_FIELD_NOT_EDITABLE`; PUT `status` limited to the
  allowed pairs -> 409 `WR_STATUS_CHANGE_NOT_ALLOWED`. Flutter: `warehouse_receiving_screen.dart` (edit save) and
  `warehouse_receiving_provider.dart`.
- **Files to change:** `modules/warehouse_receiving/service.py`, `modules/warehouse_receiving/validators.py`,
  `tests/unit/test_warehouse_receiving.py`.
- **Steps:**
  1. Extract `_discrepancy_rate(totals)` = `round((short+dmg)/invoiced*100, 2)` or 0.0 when invoiced is 0; use it in
     inspection and PUT.
  2. PUT with `grn_items`: set the rate; if `existing.inspection_protocol_number` is set, run
     `validate_verdict_consistency(existing.inspection_verdict, new_short, new_dmg)` and, when the protocol verdict is
     ACCEPTED_WITH_DISCREPANCY and the new totals have no discrepancy, 400 (re-file the protocol). Without a protocol set
     `discrepancy_type = _create_discrepancy_type(totals)` unless the PUT sends one.
  3. `inspection_verdict` in the PUT body -> 400 (field set only by the inspection protocol).
  4. Status: allowed PUT changes `{("Draft / Pending Warehouse Count","Goods Received"), ("Goods Received","GRN Audited"), ("GRN Audited","Closed")}` (confirm Q3); anything else 409.
  5. Use `exclude_unset=True` only; drop None only for NOT NULL columns (`warehouse_name`, `seal_intact`, `inspector_name`, `status`, `discrepancy_type`).
- **Acceptance criteria / tests** (`tests/unit/test_warehouse_receiving.py`):
  - GRN line invoiced 100 / accepted 100, protocol ACCEPTED_FULL; PUT line accepted 95 shortage 3 damaged 2 -> 400
    `WR_VERDICT_INCONSISTENT`.
  - GRN without protocol, PUT line invoiced 100 accepted 95 shortage 3 damaged 2 -> `discrepancy_rate_percent == 5.0`,
    `discrepancy_type == "Shortage"`.
  - PUT `{"inspection_verdict": "ACCEPTED_FULL"}` -> 400; PUT status "Inspection Passed / Clean Receipt" -> 409.
  - PUT `{"notes": null}` clears notes.
- **Out of scope:** enum codes for statuses (later wave).

### BE810-T06: Dossier FOB per currency
- **Severity:** CRITICAL (F06). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes (additive + nullable): new `fob_by_currency: Dict[str, float]`; `total_fob_fc` and
  `fob_currency` become `null` when POs use more than one currency or a PO has no currency. Flutter:
  `frontend/lib/features/comprehensive_report/models/comprehensive_dossier_model.dart`,
  `.../widgets/comprehensive_dossier_export_dialog.dart`.
- **Files to change:** `modules/file_closure/service.py`, `modules/file_closure/schemas.py`,
  `tests/unit/test_clo03_comprehensive_dossier_export.py`.
- **Steps:** in the PO loop use `curr = po.currency.currency_code if po.currency else None`; a PO with None currency
  sets a flag `unknown_currency`. After the loop: single currency and no unknown -> `total_fob_fc = sum`, `fob_currency =
  curr`; otherwise both None. `total_fob_egp`: settlement value first; else None when `unknown_currency`; else
  `_stored_clearance_fob_egp` / `_fob_egp` as today. SEC-01 details and `summary_notes` use `fob_by_currency`.
- **Acceptance criteria / tests:** rates seeded USD customs 50.50 and EUR 55.20 on the Form 46 date; PO1 10,000 USD,
  PO2 5,000 EUR, no settlement, clearance rate 1.0 -> `fob_by_currency == {"USD": 10000.0, "EUR": 5000.0}`,
  `total_fob_fc is None`, `total_fob_egp == 781000.0` (505,000 + 276,000). Single PO 10,000 USD -> `total_fob_fc ==
  10000.0`, `fob_currency == "USD"`, `total_fob_egp == 505000.0`. PO without currency -> `total_fob_egp is None`.
- **Out of scope:** settlement FOB; customs math (route the diff through `customs-rules-reviewer`).

### BE810-T07: Dossier stops inventing values
- **Severity:** MAJOR (F22). **Depends on:** T06 (same file).
- **Schema/migration needed:** no.
- **API contract change:** yes (nullable): `actual_landed_cost_markup_factor`, PO `exchange_rate`, `net_weight_kg`,
  item `item_code` may be `null`; new `fob_source: "PO" | "ESTIMATE" | null`. Flutter: `comprehensive_dossier_model.dart`
  and the export dialog render "—".
- **Files to change:** `modules/file_closure/service.py`, `modules/file_closure/schemas.py`,
  `tests/unit/test_clo03_comprehensive_dossier_export.py`.
- **Steps:** replace `or 1.0` (lines 444, 533, 933 precheck `actual_markup_factor` too -> Optional), `ITM-%03d`
  fallback (458) with None, net weight fallback from gross (736) with None, estimated-cost fallback (470-473) keeps the
  number but sets `fob_source="ESTIMATE"` and never feeds `total_fob_egp` without that flag; `summary_notes` built from
  `closure_readiness` (e.g. only claims "ready" when the gate passes) or set to None.
- **Acceptance criteria / tests:** file without settlement and without markup -> `actual_landed_cost_markup_factor is None`;
  PO without exchange rate -> `exchange_rate is None`; no PO + estimated cost 20,000 USD -> `fob_source == "ESTIMATE"`.
- **Out of scope:** Arabic section names (FC-13 shared messages).

### BE810-T08: `closure_readiness` from the closure gate
- **Severity:** MAJOR (F23). **Depends on:** T03 (locked count), T06/T07 (same file).
- **Schema/migration needed:** no. **API contract change:** no (same keys; values now match the precheck).
- **Files to change:** `modules/file_closure/service.py`, `tests/unit/test_clo03_comprehensive_dossier_export.py`.
- **Steps:** in the dossier call `evaluate_file_closure_gate(db, imp)`; `closure_readiness = {**gate.checklist,
  "eir_returned": gate.checklist["empty_containers_returned"]}`. Delete the duplicated rules (lines 689-698).
- **Acceptance criteria / tests:** for a parametrized set of facts the dossier `closure_readiness` equals the precheck
  `checklist_status`; with one open operational task `tasks_closed` is False.
- **Out of scope:** gate rules themselves.

### BE810-T09: Preconditions for dossier export and draft closure
- **Severity:** MAJOR (F18, F19). **Depends on:** T08.
- **Schema/migration needed:** no.
- **API contract change:** yes: `POST /file-closure/confirm-dossier-export` -> 400 `FC_EXPORT_BLOCKED {blocking: [...]}`
  when customs / warehouse / landed cost are not met. Draft POST no longer moves the file stage. Flutter:
  `comprehensive_dossier_service.dart`, `comprehensive_dossier_export_dialog.dart`, `file_closure_provider.dart`.
- **Files to change:** `modules/file_closure/service.py`, `modules/file_closure/validators.py`,
  `tests/unit/test_clo03_comprehensive_dossier_export.py`, `tests/unit/test_file_closure.py`.
- **Steps:** validators `export_blocking_keys(gate)` = gate blocking keys minus `dossier_exported`; export raises when
  non-empty. Draft branch (service 212-214): change `current_module`/stage only when `imp.dossier_exported_at` is set;
  otherwise only save the record. Before setting `closed_at_phase` strip a trailing " (Draft)".
- **Acceptance criteria / tests:** export on a file without GRN -> 400 with `blocking == ["warehouse_received"]`; draft
  POST on a Phase 6 file leaves `current_module` and `current_stage` unchanged.
- **Out of scope:** resetting the export on reopen (Q6, import_files module).

### BE810-T10: Acting user from the token for auditor / exporter / inspector
- **Severity:** MAJOR (F20). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: `auditor_name`, `exported_by`, `inspector_name` in request bodies are ignored (stored
  value = signed-in username). Fields stay in the schemas (deprecated) so old clients do not get 422. Flutter: remove the
  inputs in `official_file_closure_dialog.dart`, `comprehensive_dossier_export_dialog.dart`,
  `warehouse_inspection_dialog.dart`, GRN form.
- **Files to change:** `modules/file_closure/service.py`, `modules/warehouse_receiving/service.py`,
  `modules/file_closure/schemas.py`, `modules/warehouse_receiving/schemas.py`, `tests/unit/test_clo04_official_file_closure.py`.
- **Steps:** replace `_resolve_user_name(...)` with `user`; WR `inspector = user` (create) and `record.inspector_name =
  user_name` (inspection); a non-empty client value different from the user is appended to `archival_notes` / `notes`
  as "Signed by: <text>" only if Q4 says so.
- **Acceptance criteria / tests:** close with body `auditor_name="Someone"` as user `u1` -> `record.auditor_name == "u1"`.
- **Out of scope:** a separate signer field (Q4).

### BE810-T11: GRN create preconditions (lines, warehouse, customs release)
- **Severity:** MAJOR (F08, F09 for WR, F10). **Depends on:** T02.
- **Schema/migration needed:** no.
- **API contract change:** yes: `grn_items` min 1 (422), `warehouse_name` required (422), 400 `WR_CUSTOMS_NOT_RELEASED`.
  Flutter: GRN form in `warehouse_receiving_screen.dart`.
- **Files to change:** `modules/warehouse_receiving/schemas.py`, `modules/warehouse_receiving/validators.py`,
  `modules/warehouse_receiving/service.py`, `tests/unit/test_tr03_warehouse_goods_receiving_note.py`.
- **Steps:** schema `warehouse_name: str = Field(..., min_length=2)`, `grn_items: List[GrnItemSchema] = Field(..., min_length=1)`,
  `item_code`/`item_name` `min_length=1`. Validator `validate_customs_release(imp, clearance)`: OK when
  `imp.is_customs_released` or `imp.customs_release_permit_no` or clearance status "Final Release Granted" or
  `clearance.is_under_bond_release`, or STEP_17 in `imp.skipped_stages`; else 400.
- **Acceptance criteria / tests:** empty lines -> 422; file without release and no under-bond -> 400; under-bond file -> 201 with lock.
- **Out of scope:** storage bin location (doc BP-034, needs columns: Q7).

### BE810-T12: Claim amount and currency validation
- **Severity:** MAJOR (F11). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: negative amount -> 422; `claim_currency` default null; unknown currency -> 400
  `WR_CLAIM_CURRENCY_INVALID`. Flutter: `warehouse_inspection_dialog.dart` (currency from the currencies provider).
- **Files to change:** `modules/warehouse_receiving/schemas.py`, `modules/warehouse_receiving/validators.py`,
  `modules/warehouse_receiving/service.py`, `tests/unit/test_tr04_warehouse_inspection_discrepancy.py`.
- **Steps:** `claim_amount_estimated: Optional[float] = Field(None, ge=0)` (Submit and Update); `claim_currency:
  Optional[str] = None`; validator: when amount > 0, currency required and must be an active `currencies.currency_code`
  (normalize with `enum_codes.normalize_currency`); service stores None instead of 0.0/"EGP" when absent.
- **Acceptance criteria / tests:** amount -5 -> 422; amount 1200 currency "XYZ" -> 400; amount 1200 "usd" -> stored "USD".
- **Out of scope:** FX conversion of claims.

### BE810-T13: Inland transport create validation (status, dates, carrier, truck type, defaults)
- **Severity:** MAJOR (F15, F16, F09 for IT). **Depends on:** T01.
- **Schema/migration needed:** no.
- **API contract change:** yes: `destination_warehouse`, `truck_type`, `transport_fare_egp` required (422); create
  `status` limited; `actual_arrival_at` on create -> 400; unknown `carrier_id` -> 400 `IT_CARRIER_INVALID`; unknown truck
  type -> 400 `IT_TRUCK_TYPE_INVALID`. Flutter: `inland_transport_dialog.dart`, `inland_transport_provider.dart`.
- **Files to change:** `modules/inland_transport/schemas.py`, `modules/inland_transport/validators.py`,
  `modules/inland_transport/service.py`, `tests/unit/test_tr01_inland_transport_coordination.py`.
- **Steps:** Create schema: separate `InlandTransportBookingCreate` fields without invented defaults; status allowed
  `{"Booking Confirmed","Dispatched"}` or "In Transit" only with `actual_departure_at`; reject `actual_arrival_at`;
  `validate_actual_times` too. Carrier: when `carrier_id` given, load `ExternalServiceProvider` (active) else 400 and set
  `carrier_name` from it. Truck type: after normalize, value must be in `enum_codes.LABELS_EN[enum_codes.TRUCK_TYPE]`
  (create and PUT).
- **Acceptance criteria / tests:** create with status "Delivered" -> 400; with `carrier_id=999999` -> 400; truck type
  "Spaceship" -> 400; missing fare -> 422.
- **Out of scope:** making `carrier_id` mandatory (Q8).

### BE810-T14: Keep gate-out / arrival evidence
- **Severity:** MAJOR (F17). **Depends on:** T13.
- **Schema/migration needed:** no (stored in `tracking_notes`; columns only if Q1 asks).
- **API contract change:** yes: arrival with `seal_intact=false` and no `seal_number` -> 400; future dates -> 400.
- **Files to change:** `modules/inland_transport/service.py`, `modules/inland_transport/validators.py`,
  `tests/unit/test_tr01_inland_transport_coordination.py`.
- **Steps:** append `"Gate pass: <no>"` and `"Seal: intact|BROKEN <no>"` to `tracking_notes`; `validate_not_future(dt)`
  (> now + 1 day -> 400); broken seal also creates a WARNING `SystemNotification` (same commit).
- **Acceptance criteria / tests:** gate-out with `gate_pass_no="GP-1"` -> notes contain "GP-1"; broken seal without number -> 400.
- **Out of scope:** GRN seal fields (already on the GRN).

### BE810-T15: Inland transport restore endpoint
- **Severity:** MAJOR (F13). **Depends on:** T01, T02.
- **Schema/migration needed:** no.
- **API contract change:** yes (new): `PATCH /api/v1/inland-transport/bookings/{id}/restore` -> booking; 409
  `IT_BOOKING_EXISTS` on an active duplicate waybill. Flutter: `inland_transport_provider.dart` (add restore).
- **Files to change:** `modules/inland_transport/router.py`, `modules/inland_transport/service.py`,
  `tests/unit/test_tr01_inland_transport_coordination.py`.
- **Steps:** route with `require_permission("warehouse_receiving.receive")`; service loads with `include_inactive=True`
  (404), duplicate waybill check, `is_active=True`, `_sync_file_inland_fields`, commit.
- **Acceptance criteria / tests:** delete then restore -> active, file cost back to the fare; restore with a new active
  booking on the same waybill -> 409.
- **Out of scope:** delete guards (Q5).

### BE810-T16: GRN delete guard
- **Severity:** MAJOR (F14). **Depends on:** T02.
- **Schema/migration needed:** no.
- **API contract change:** yes: DELETE -> 409 `WR_GRN_LOCKED` when a protocol or claim exists. Flutter: `warehouse_receiving_provider.dart`.
- **Files to change:** `modules/warehouse_receiving/service.py`, `modules/warehouse_receiving/validators.py`,
  `tests/unit/test_warehouse_receiving.py`.
- **Steps:** `validate_grn_deletable(record)`: 409 when `inspection_protocol_number` or `insurance_claim_filed` or
  `supplier_claim_filed` or `quarantine_lock_active`.
- **Acceptance criteria / tests:** GRN with protocol -> 409; plain GRN -> 204.
- **Out of scope:** reverting file progress on delete.

### BE810-T17: Audit trail for WR, IT and closure events
- **Severity:** MAJOR (F12). **Depends on:** T01, T05, T15, T16.
- **Schema/migration needed:** no.
- **API contract change:** no.
- **Files to change:** `modules/warehouse_receiving/service.py`, `modules/inland_transport/service.py`,
  `modules/file_closure/service.py`, `tests/unit/test_phase08_10_regressions.py`.
- **Steps:** after each core commit `best_effort(db, _audit, "<label>")` with
  `AuditLogService(db).log_activity(entity_type, entity_id, entity_code, action, old_data, new_data, performed_by=user)`:
  WR delete/restore/report-discrepancy/inspection (action `INSPECTION_PROTOCOL`); IT create/update/gate-out/arrival/
  delete/restore; FC final close (`CLOSE`), draft save, update, delete, restore, dossier export (`DOSSIER_EXPORT`).
- **Acceptance criteria / tests:** after an official close an audit row exists with action CLOSE, entity
  `ImportFileClosureRecord`, performed_by = user; after IT gate-out an audit row exists.
- **Out of scope:** reopen audit (import_files).

### BE810-T18: Pagination for GRN and inland transport lists
- **Severity:** MAJOR (F21). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** additive: query `skip` (default 0), `limit` (default 200, max 1000), response header
  `X-Total-Count`; body stays a list. Flutter: `warehouse_receiving_provider.dart`, `inland_transport_provider.dart`
  (optional paging).
- **Files to change:** `modules/warehouse_receiving/router.py`, `modules/warehouse_receiving/repository.py`,
  `modules/inland_transport/router.py`, `modules/inland_transport/repository.py`,
  `tests/unit/test_phase08_10_regressions.py`.
- **Steps:** repository returns `(items, total)` (`query.count()` before offset/limit); service passes through; router
  takes `response: Response` and sets the header (HTTP only). Expose the header in CORS if the app uses CORS.
- **Acceptance criteria / tests:** 3 GRNs, `limit=2` -> 2 items and `X-Total-Count: 3`.
- **Out of scope:** closure list (small table).

### BE810-T19: Warehouse receiving hygiene
- **Severity:** MINOR (F26, F29, F36). **Depends on:** T05.
- **Schema/migration needed:** no. **API contract change:** report-discrepancy type "None" -> 400; `quarantine_zone_assigned`
  default false. Flutter: report-discrepancy dialog.
- **Files to change:** `modules/warehouse_receiving/validators.py`, `modules/warehouse_receiving/schemas.py`,
  `modules/warehouse_receiving/service.py`, `tests/unit/test_tr04_warehouse_inspection_discrepancy.py`.
- **Steps:** `validate_verdict_matches` uses `WR_VERDICT_INCONSISTENT_EXPECTED`; report-discrepancy default false and
  type "None" rejected; inspection date not in the future.
- **Acceptance criteria / tests:** quantities clean + verdict DAMAGE_CLAIM_PENDING -> 400 with code
  `WR_VERDICT_INCONSISTENT_EXPECTED` and `expected_verdict == "ACCEPTED_FULL"`.
- **Out of scope:** none.

### BE810-T20: Inland transport and closure hygiene
- **Severity:** MINOR (F27, F28, F30, F31, F32, F33, F35). **Depends on:** T09, T13.
- **Schema/migration needed:** no. **API contract change:** precheck adds blocking key `already_closed` for a Closed file.
- **Files to change:** `modules/inland_transport/service.py`, `modules/file_closure/service.py`,
  `modules/file_closure/repository.py`, `tests/unit/test_clo04_official_file_closure.py`.
- **Steps:** tighten legacy title matches (exact `TR-01` / `CLO-04` only); TR-03 task `assigned_user=user`,
  `phase_name="Phase 8: Inland Transport & Warehouse Receiving"`; `add_closure` sets `closed_at` only when status is
  Closed; `_require_any_permission(actor=None)` raises unless called with `trusted=True` from `official_close`;
  precheck reason for a closed file; `selectinload(PurchaseOrder.line_items, PurchaseOrder.currency)`; export
  re-confirmation does not resend the notification.
- **Acceptance criteria / tests:** a task titled "إغلاق الاعتماد المستندي" stays open after a file close; draft record
  has `closed_at is None`.
- **Out of scope:** none.

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| All WR / IT writes | 409 `IMPORT_FILE_CLOSED` on a Closed file (T02) | `warehouse_receiving_provider.dart`, `inland_transport_provider.dart`, screens' SnackBars via `ApiErrorText.of` |
| `PUT /warehouse-receiving/{id}` | verdict not editable (400), status pairs only (409), nulls clear fields (T05) | `warehouse_receiving_screen.dart` edit save |
| `POST /warehouse-receiving` | lines ≥1, `warehouse_name` required, 400 `WR_CUSTOMS_NOT_RELEASED`; `inspector_name` ignored (T10, T11) | GRN form in `warehouse_receiving_screen.dart` |
| `POST /warehouse-receiving/{id}/inspection-protocol` | claim currency from master list, amount ≥0, `inspector_name` ignored (T10, T12) | `warehouse_inspection_dialog.dart` |
| `DELETE /warehouse-receiving/{id}` | 409 `WR_GRN_LOCKED` (T16) | `warehouse_receiving_provider.dart` |
| `POST /inland-transport/bookings` | required destination / truck type / fare; status limited; `IT_CARRIER_INVALID`, `IT_TRUCK_TYPE_INVALID` (T13) | `inland_transport_dialog.dart` |
| arrival / gate-out | broken seal needs number; no future dates (T14) | `inland_transport_dialog.dart` |
| `PATCH /inland-transport/bookings/{id}/restore` | new (T15) | `inland_transport_provider.dart` |
| list endpoints | `skip`/`limit`, `X-Total-Count` (T18) | WR / IT providers |
| `GET /file-closure` | `closed_at` nullable, checklist values nullable (T04) | `file_closure_model.dart` |
| `GET /file-closure/comprehensive-dossier/{id}` | `fob_by_currency`, `fob_source`; nullable `total_fob_fc`, `fob_currency`, markup, PO exchange rate, item code, net weight; `closure_readiness` = gate (T06-T08) | `comprehensive_dossier_model.dart`, `comprehensive_dossier_export_dialog.dart` |
| `POST /file-closure/confirm-dossier-export` | 400 `FC_EXPORT_BLOCKED`; `exported_by` ignored (T09, T10) | `comprehensive_dossier_service.dart`, export dialog |
| `POST /file-closure`, `/official-close` | `auditor_name` ignored; draft no longer moves the stage (T09, T10) | `official_file_closure_dialog.dart`, `file_closure_provider.dart` |
| `GET /file-closure/closure-precheck/{id}` | blocking key `already_closed`; `actual_markup_factor` nullable (T07, T20) | `official_file_closure_dialog.dart` |

New coded errors to register (system_messages + docs json + Flutter catalogs): `IMPORT_FILE_CLOSED`,
`WR_FIELD_NOT_EDITABLE`, `WR_STATUS_CHANGE_NOT_ALLOWED`, `WR_CUSTOMS_NOT_RELEASED`, `WR_CLAIM_CURRENCY_INVALID`,
`WR_GRN_LOCKED`, `IT_CARRIER_INVALID`, `IT_TRUCK_TYPE_INVALID`, `FC_EXPORT_BLOCKED`.

## 5. Open questions for the CTO

Shared need (outside these modules): `modules/import_files/service.py:reopen_shipment_service` should mark the active
closure record "Reopened" (or deactivate it), write an audit log with the reason, and decide on `dossier_exported_at`
(F25). Still open from the previous plan, section 5.

1. **Q1 Quarantine release evidence:** is it enough to mirror the customs lab lift onto the GRN (T03), or must the
   warehouse record its own lab certificate number / release date (needs nullable columns + migration)? [mirror only]
2. **Q2 GRN before customs release:** may a GRN be issued before final release except on the under-bond path? [no]
3. **Q3 GRN status changes by PUT:** which manual transitions are allowed (Draft -> Goods Received -> GRN Audited ->
   Closed)? [those three only]
4. **Q4 Signer vs acting user:** can the closure auditor / dossier exporter / inspector be a person other than the
   signed-in user? If yes, a separate `signed_by` text field is needed (migration). [no: always the signed-in user]
5. **Q5 Deleting a GRN / booking:** forbid deleting a GRN with an inspection protocol or claim, and a booking that has
   arrived? [GRN: forbid; booking: allow, with file resync]
6. **Q6 Dossier export validity:** reset `dossier_exported_at` on reopen and when the settlement changes after export?
   [reset on reopen]
7. **Q7 Storage zone / bin location (doc BP-034):** add to the GRN lines (JSON, no migration) or as columns? [JSON line field]
8. **Q8 Carrier master data:** make `carrier_id` mandatory for new bookings? [yes for new bookings, legacy rows keep the name]
9. **Q9 File transport cost:** confirm the file field is the sum of active fares (T01), not the last fare. [sum]
10. **Q10 Closure gate vs doc:** the doc's 6-point gate lists Form 4/SWIFT, container return with no pending detention,
    and "shortage settled"; today these are warnings or not checked. Promote any to blocking? [keep warnings; add
    "inspection protocol filed when the GRN has a discrepancy" as blocking]
