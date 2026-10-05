# Phases 8 "Warehouse Receiving" and 10 "File Closure": quality audit and fix plan

Status: proposed (2026-10-05). Nothing implemented. Based on static reading only: no pytest, no flutter test, no import of `main`.
Method and format follow `docs/plans/phase-01-quality-simplify-plan.md`. Reuse the A1 helpers listed in `docs/plans/phase-01-progress.md`.
Constraint for this wave: **no schema change and no Alembic migration.**

## Audit coverage

| Area | Depth |
|---|---|
| `modules/warehouse_receiving` (BP-033..035, TR-03/04, LOG-BOND-003), 989 lines | Full: all 6 files read line by line |
| `modules/inland_transport` (TR-01), 725 lines | Router, validators, service, repository, schemas read fully. Model columns read. `migration.py` only the head (raw sqlite script, never imported) |
| `modules/file_closure` (BP-040, CLO-03/04), 1585 lines | Router, validators, model, repository, service (1033 lines) read fully. `schemas.py` read l.1-80 plus a grep of the rest |
| Cross-module facts used | `notifications/model.py` (columns), `import_files` reopen service and model columns, `auth/permissions.require_permission`, `seed_rbac` catalog, `enum_codes.WAREHOUSE_INSPECTION_VERDICT` |
| Flutter, about 10k lines | Read fully: the 3 models, and the WR, IT, and goods-in-transit providers. Read in part: inland dialog l.120-325, official closure dialog l.90-270, WR screen l.395-437 and l.1060-1173, inspection dialog l.130-177 and l.488-503. Everything else was covered by grep sweeps only |
| Not audited | `goods_in_transit_model.dart`, both export services (only their save calls), `warehouse_received_report_screen.dart`, `inbound_warehouse_hub_screen.dart`, both clone dialogs, most of `file_closure_screen.dart`, the `frontend/test` coverage for these features |

Severity scale is the same as Phase 1: BLOCKER (breaks a non-negotiable rule, or corrupts money, quantities, or references) > CRITICAL (wrong result or a 500 on a normal path) > MAJOR > MINOR.

## 1. Findings

### Backend

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| WR-01 | BLOCKER | `warehouse_receiving/router.py:30-124` | No `require_permission` on any route. Any logged-in user, a viewer included, can issue or delete a GRN or approve an inspection protocol. | code | GET routes and `validate-dispatch` get `warehouse_receiving.view`. Every mutating route gets `warehouse_receiving.receive`. The router passes `current_user.username` to the service. |
| WR-02 | CRITICAL | `service.py:43,56,240` | The service reads `grn_number`, but the model only has `grn_code`. Creating a second GRN for the same file raises AttributeError, which returns 500 instead of the intended 400. The create and update audit logs always fail, and the error is swallowed, so no audit row has ever been written. | `model.py:169`; grep shows no `grn_number` anywhere | Use `grn_code`. Return the duplicate as `CodedHTTPException(409, "WR_GRN_EXISTS", ..., grn_code=...)`. |
| WR-03 | CRITICAL | `schemas.py:183`, `service.py:340-341` | `inspection_verdict` defaults to `"ACCEPTED_FULL"` and is never validated. When a line has a shortage or damage and the client omits the verdict (or sends ACCEPTED_FULL), the record stores ACCEPTED_FULL and the file goes to `QC_PASSED`, even though the quantities show a discrepancy. The Flutter dialog sends whatever verdict the user picks (`warehouse_inspection_dialog.dart:143`). | code | Default the verdict to `None` so the server derives it. Validate it against `WAREHOUSE_INSPECTION_VERDICT` (400 otherwise). Reject ACCEPTED_FULL when shortage + damaged > 0 (400). |
| WR-04 | CRITICAL | `schemas.py:150-157`, `repository.py:62-76,110-117`, `service.py:298-304` | No quantity check per GRN line. `accepted + shortage + damaged` can differ from `invoiced`, and the discrepancy rate and the claims are computed from inconsistent numbers. The Flutter prefill actually produces accepted = invoiced together with shortage 2 (see FE-01). | code | Shared validator `validate_grn_lines(items)` used by create, update, and inspection: per line, `accepted + shortage + damaged == invoiced`. The only exception is excess: `shortage == damaged == 0 and accepted > invoiced`, which keeps today's "Excess" type. Error is 400 with an Arabic detail naming the `item_code`. Confirm with Q4. |
| WR-05 | MAJOR | `service.py:30-192` | Create runs up to 4 commits: the repository (`repository.py:101`), l.123, the lifecycle service, and l.188. Four `except Exception: pass` blocks (l.97, 111, 165, 189) hide failures, and two of them guard core side effects: syncing the inland bookings and stopping the demurrage clock. | code | Repository uses `flush`. The core sync (bookings, demurrage, file tracking) commits once together with the GRN. Only the task, notification, and lifecycle steps go through `errors.best_effort`. |
| WR-06 | MAJOR | `service.py:59,244,281`, `model.py:217`, `schemas.py:170,182` | Hard-coded identities and texts: `performed_by="Warehouse Manager"`, `inspector_name="Kamal"` (model, schema, and Flutter model), `user_name="Warehouse QC Committee"`. The inspection committee default is an Arabic string stored in the DB, which breaks single-language storage. | code | Use `current_user.username` for the audit fields and as the inspector default. Committee default becomes `None`, which falls back to the English `DEFAULT_INSPECTION_COMMITTEE`. The `"Kamal"` column default stays (no migration) but is never relied on. |
| WR-07 | MAJOR | `schemas.py:204-215`, `repository.py:120-121` | PUT writes free-text `status`, `discrepancy_type`, and `inspection_verdict` straight to the record (`setattr`). Flutter writes `"Draft / Pending Warehouse Count"` this way. | `warehouse_receiving_screen.dart:1145` | Validate each field against a module-level frozenset of the current legacy labels (status, discrepancy) and against the verdict codes. Unknown values get 400. Conversion to T3 codes is in Shared needs. |
| WR-08 | MAJOR | `repository.py:9-30` | The GRN code takes the last row by id plus 1. A user-typed or out-of-order code collides, and the IntegrityError becomes a 500. | code | `next_yearly_code(db, WarehouseReceivingRecord.grn_code, "GRN", pad=4)` plus one retry on IntegrityError. |
| WR-09 | MAJOR | `service.py:256-260` | Restore does not check for an existing active GRN, so a file can end up with two active GRNs. Closure (`get_closure_by_import_file_id`) and by-file (`router.py:54`) then pick an arbitrary one. | code | Before restoring, check for another active GRN on the file and return 409 if there is one. |
| WR-10 | MINOR | `router.py:49-55,95-108` | Business logic in the router: the by-file lookup, and building the dispatch response with an Arabic message. | code | Move both to the service: `get_by_file_service` and `validate_dispatch_service` returns the response. |
| WR-11 | MINOR | `service.py:388,391` | The auto-resolve filter for TR-04 tasks has no `is_active`, matches on an Arabic title, and uses status "In Progress" (closure uses "In-Progress"). | code | Filter on `msg_code` or `task_type` first and add `is_active`. Keep the legacy title match as a fallback. |
| IT-01 | BLOCKER | `inland_transport/router.py:25-96` | No `require_permission` on any route. | code | Reuse `warehouse_receiving.view` and `warehouse_receiving.receive` (Q1 covers a dedicated code). |
| IT-02 | CRITICAL | `service.py:171-285` | No duplicate guard. A retry (double click, timeout, or FE-06) creates a second booking, a second TR code, and overwrites the file's inland fields. | code | 409 `IT_BOOKING_EXISTS` when an active booking already exists for the same `import_file_id` and the same waybill (trimmed, case-insensitive). Return the existing `transport_code`. Several trucks per file are still allowed when the waybills differ. |
| IT-03 | MAJOR | `repository.py:65-70` | `get_transport_booking_by_id` ignores `is_active`. Get, update, gate-out, arrival, and delete all work on soft-deleted bookings, and gate-out or arrival on a deleted booking still moves the file stage. | code | Filter `is_active` (404 otherwise). Add `include_inactive` only for an internal restore. |
| IT-04 | MAJOR | `service.py:267-281` | The notification passes `notification_code`, `import_file_id`, and `created_by`, which are not `SystemNotification` columns (`notifications/model.py:6-22`). The constructor raises TypeError, which is swallowed, so the TR-01 notification has never been created. | code | Use `entity_type="ImportFile", entity_id=...` like WR. Wrap in `best_effort`. |
| IT-05 | MAJOR | `service.py:287-345`, `repository.py:110-123` | No state machine: gate-out can be recorded after arrival (the file stage goes backward), arrival can be repeated, and PUT writes free-text `status` and unvalidated dates (arrival before departure). The `user="System"` default is never replaced by a real user. | code | `validators.validate_transition(current, target)`: gate-out only from Booking Confirmed or Dispatched; arrival from Booking Confirmed, Dispatched, or In Transit; a repeat gets 409. PUT re-runs the date and length checks on the merged values and validates `status` against the legacy label set. The router passes the username. |
| IT-06 | MINOR | `inland_transport/migration.py` | Raw sqlite DDL script with a hard-coded DB path. It is outside the 6-file layout and is never imported. | grep | Delete the file (it changes no schema). |
| IT-07 | MINOR | `schemas.py:186,191` | `datetime.utcnow` gives naive datetimes, while the rest of the code is timezone-aware. | code | `lambda: datetime.now(timezone.utc)`. |
| FC-01 | BLOCKER | `validators.py:14-30`, `schemas.py:5-12`, `service.py:39-94` | The final-close gate trusts the client. Every checklist flag defaults to `True`, so a POST with no checklist passes `validate_closure_checklist`. The 3 DB checks are each wrapped in `except Exception: pass`, so a failing query lets the close through (fail-open). Dossier export, the documents check, and the containers check are not verified on the server at all. | code | One server-side gate `_evaluate_closure_gate(db, imp) -> (checklist, blocking, warnings)` used by both precheck and close. Close (non-draft) raises 400 when `blocking` is not empty. Client flags are stored for the record only and never gate. No `except: pass`. |
| FC-02 | BLOCKER | `service.py:432` | `total_fob_egp = total_fob_fc * 48.5` is a hard-coded FX rate (DOMAIN_RULES: no hard-coded rates). | code | Use the settlement value. Otherwise use `CurrencyService` with the customs rate on the file date. Otherwise return `0.0`. Route through `customs-rules-reviewer`. |
| FC-03 | CRITICAL | `service.py:50-59` vs `828-848` | Precheck and close disagree. Precheck accepts a release permit or release date and skips STEP_13/14/17; close requires clearance status "Final Release Granted" and skips only STEP_17. The precheck can say `can_close` while the close returns 400, and the reverse. Precheck requires the dossier export; close does not. | code | Solved by the shared gate from FC-01. Customs is OK when (clearance status is Final Release Granted, or `is_customs_released`, or `customs_release_permit_no`), or STEP_13/14/17 is skipped (Q2). |
| FC-04 | CRITICAL | `service.py:96-118`, `repository.py:63-80` | No idempotency or state guard. Closing an already closed file runs everything again (duplicate notification, lifecycle, and learning trigger). A draft POST on a closed file moves the stage back to CLOSURE_IN_PROGRESS. `create_closure` commits the row as "Closed" with `closed_at` set before the draft status is applied (a second commit). | code | 409 `FC_ALREADY_CLOSED` when the file status is Closed (both draft and final). The repository uses `flush` and the status is set before the single commit. |
| FC-05 | MAJOR | `service.py:118`, `import_files/model.py:187` | `imp_file.closed_at` is not a column, so it is never persisted. `closed_at_phase` is never set, so `reopen_shipment_service` (`import_files/service.py:521`) always restores the file to "Phase 1". | code | Before overwriting `current_module`, set `imp.closed_at_phase = imp.current_module`. Drop `imp.closed_at` and use `record.closed_at` in the certificate. |
| FC-06 | MAJOR | `router.py:30-129` | No `require_permission`. Anyone can officially close a file. | code | GET routes get `import_files.view`. Official close, non-draft POST, delete, and restore get `import_files.close`. Draft POST, PUT, and confirm-dossier-export get `import_files.edit`. POST `""` takes `import_files.edit`, and the service calls `has_user_permission(db, user, "import_files.close")` when `is_draft` is false (403 otherwise). |
| FC-07 | MAJOR | `service.py:261-272,343-353,399,315-316,604-615` | The dossier invents data: company "شركة الاستيراد المصرية", broker "مكتب التخليص المعتمد", office "ميناء الدخيلة", warehouse "المستودع الرئيسي", mode "Sea FCL", incoterm "FOB", priority "High", free days 21, item text "بند استيرادي". | code | Return `""`, `None`, or `0` and let Flutter render "—". Field types stay the same (no contract change). |
| FC-08 | MAJOR | `service.py:392-397` | The dossier's GRN query has no `is_active` filter, so a deleted GRN shows as received (`closure_readiness.warehouse_received`). | code | Add `is_active == True`. |
| FC-09 | MAJOR | `service.py:220-235`, `repository.py:82-117` | PUT writes free-text `status` and can edit the checklist of a Closed record. Soft-deleting a Closed record leaves the file Closed with no closure. Restore does not check for another active closure. | code | PUT: `status` accepts only "Draft"; a Closed record allows only `archival_notes` and `archive_location`. Delete of a Closed record returns 409 ("reopen the file first"; Q5). Restore checks for duplicates (409). |
| FC-10 | MAJOR | `service.py:690,726`, `schemas.py:163` | `exported_by` and `auditor_name` are taken from the client, with fake defaults ("Finance & Logistics Controller"). | code | When absent or left at the default, use `current_user.username`. |
| FC-11 | MINOR | `service.py:957-958` | The warning says open tasks "will be closed automatically", but close only completes closure tasks. | code | Keep the behaviour, fix the text (Q6). |
| FC-12 | MINOR | `service.py:965` vs `repository.py:9-30` | The precheck preview code is `CLR-YYYY-<import_file_id>`, which is not the code that close issues. Both codes use the `count`/last-id pattern. | code | Preview uses `next_yearly_code(...)` (peek, no write). `generate_closure_code` becomes `next_yearly_code(..., "CLR", pad=4)`. |
| FC-13 | MINOR | `service.py:577-582,435-566`, `848-941` | `summary_notes`, `section_name_ar`, `status_ar`, and the blocking/warning texts are Arabic sentences built on the backend (single-language rule). `closure_readiness` uses the key `eir_returned` while precheck uses `empty_containers_returned`. | code | Additive `blocking_messages` and `warning_messages: List[SystemMessageItem]` (codes in Shared needs). Keep the Arabic fields for old clients and mark them deprecated. Add the key `empty_containers_returned` next to `eir_returned`. |

### Flutter

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FE-01 | BLOCKER | `warehouse_receiving_screen.dart:1076-1095` | The GRN form invents quantities. When customs has a discrepancy it pre-fills shortage 2 and damaged 1 while also setting accepted = invoiced. Without a PO it creates the item `ITM-GEN-01` with quantity 100, and the item code defaults to `ITM-PO`. These numbers end up in claims and landed cost. | Pre-fill invoiced = PO quantity, accepted = invoiced, shortage = damaged = 0. Without PO lines, start from an empty list that the user must fill (validator requires ≥1 line with an item code). Add a live per-line check that accepted + shortage + damaged equals invoiced, matching WR-04. |
| FE-02 | CRITICAL | `warehouse_receiving_screen.dart:1066` | POs are matched with `selectedFile.poNumber.contains(p.poNumber)`, so "PO-1" also matches "PO-10". | Filter by `po.importFileId == selectedFileId`. |
| FE-03 | CRITICAL | `warehouse_receiving_screen.dart:1145,1152` | "Save draft" on create sends `status`, which `WarehouseReceivingCreate` ignores. The result is a real GRN, and the lifecycle moves from STEP_19 to STEP_20. | Hide draft-save on create (Q3). On edit, send only the status values allowed by WR-07. |
| FE-04 | MAJOR | `inland_transport_dialog.dart:256,295` | Gate-out and arrival send `tracking_notes`, but the schema field is `notes`, so the notes are silently dropped. English default notes are also sent. | Send `notes`, and only when the user typed something. |
| FE-05 | MAJOR | `warehouse_inspection_dialog.dart:143-149` | The verdict and discrepancy type are derived on the client, and ACCEPTED_FULL can be sent with shortages (see WR-03). | Disable ACCEPTED_FULL when shortage + damaged > 0. Stop sending `discrepancy_type` (the server derives it). |
| FE-06 | CRITICAL | `inland_transport_provider.dart:44-54`, `inland_transport_dialog.dart:160` | `fetchBookingByFile` turns every error into `null`, so a network error shows the empty "create booking" form, which leads to duplicate bookings (IT-02). `catch (_)`. | Return null only on 200 with a null body. Rethrow other errors, show `ApiErrorText.of(...)`, and keep the form hidden. |
| FE-07 | MAJOR | `file_closure_model.dart:31-35` | `ClosureChecklistModel.fromJson` and the constructor default missing keys to `true`. The precheck dialog (`official_file_closure_dialog.dart:97-109`) does the same, so a missing key shows as passed. | Default to `false`. The dialog shows the server `checklist_status` read-only. |
| FE-08 | MAJOR | `official_file_closure_dialog.dart:122-165` | The "certificate" can be exported before closing, using the preview code. | Allow export only after a successful close, with `certificate.closureCode`. |
| FE-09 | MAJOR | `official_file_closure_dialog.dart:217-220` | `showDialog(context: context)` runs after `Navigator.pop`, on a deactivated context. | Capture the root navigator context before popping, or show the dialog from the caller once the pop result is true. |
| FE-10 | MAJOR | `goods_in_transit_export_service.dart:448`, `warehouse_received_report_export_service.dart:476` | PDF goes out through `Printing.layoutPdf`, bypassing `FileSaveHelper`. | `FileSaveHelper.exportAndSaveFile(bytes: await doc.save(), stageName: ..., extension: 'pdf')`. |
| FE-11 | MAJOR | dialogs and screens (all `catch (e)` SnackBars) | The raw exception `$e` is shown instead of the backend detail. | `ApiErrorText.of(l10n, e)` (`core/localization/api_error_text.dart:39`). |
| FE-12 | MAJOR | `inland_transport_dialog.dart:165-173` | "Auto-generate waybill" makes up a legal document number (a millisecond suffix, and the port guessed from the text "dekheila"). | Remove the button (Q7). |
| FE-13 | MAJOR | 9 files, about 261 Arabic string literals (inland dialog 77, closure dialog 56, inspection dialog 51, WR screen 41) | Hard-coded UI text. | Add l10n keys between the phase08_10 markers. |
| FE-14 | MINOR | about 30 `ElevatedButton`, 1 `DropdownButtonFormField` (claim currency, inspection dialog l.494), 1 `DropdownButton` (goods-in-transit file filter, l.294), about 150 `Colors.*` outside the PDF code | UI standards. | `AppButton`, `SearchableDropdownField` (currency from the currencies provider, file filter), and `AppTheme`. Do the mechanical sweeps in separate commits per file. |
| FE-15 | MINOR | `warehouse_receiving_provider.dart:135-151`, `inland_transport_provider.dart:104-114` | Delete and restore do not invalidate `importFilesProvider` or `smartTasksProvider`. `fetchRecords()` after a mutation drops the active filters. `catch (e) { rethrow; }` adds noise. | Invalidate the same set as create. Remember the last filters. Remove the no-op catch blocks. |
| FE-16 | MINOR | `goods_in_transit_provider.dart:12-45` | The goods-in-transit ledger exists only in client memory. It starts empty on every launch and is never loaded from the backend. | Out of scope for this wave (Q8). |
| FE-17 | MINOR | `warehouse_receiving_screen.dart:1081` | `samples_qty` is collected but never sent. | Remove the field (no backend column). |

## 2. Behaviour to keep identical

- WR totals are plain sums of the line ints. Discrepancy rate is `round((short+dmg)/invoiced*100, 2)` and 0 when invoiced is 0.
- WR create discrepancy type: Shortage > Damage > Excess > None (create gives "Shortage" even when there is damage too). Inspection gives "Shortage & Damaged".
- The inspection protocol number is `INSP-<year>-<receiving_id:04d>` and is never regenerated.
- The quarantine branch wins over the discrepancy branch. The `is_ready_for_landed_cost` rule stays.
- LOG-BOND-003: the under-bond lock from the clearance (`is_under_bond_release and quarantine_lock`) sets 3 flags and the status "Under Bond Quarantine". Dispatch is refused while the lock is set.
- GRN create: the file goes to `inland_transport_status=ARRIVED` with progress ≥98. Inspection sets progress ≥99. Dossier export sets ≥99.5. Final close sets status Closed and progress 100, with the stage codes unchanged.
- IT create maps the booking to the file fields (BOOKED or IN_TRANSIT) and creates the TR-03 task once per file. TRUCK_TYPE is normalized.
- Dossier section codes and statuses, `closure_readiness` (plus the new key), and the precheck checklist keys stay. Containers remain a warning only (Q2).

## 3. Characterization tests (backend, first, green on the current code)

New file `tests/unit/test_phase08_10_characterization.py`:

1. GRN create with mixed lines gives the totals, discrepancy type "Shortage" with damage present, file progress 98, booking status "Arrived at Warehouse", and the demurrage `gate_out_date` set.
2. Inspection with shortage 3 and damaged 2 out of 100 gives a rate of 5.0, verdict ACCEPTED_WITH_DISCREPANCY when the verdict is passed as `None`, and the stage DISCREPANCY_PROTOCOL_FILED.
3. Under-bond clearance gives the 3 lock flags, and `validate-dispatch` returns 400.
4. IT create gives BOOKED, the file fields, a single TR-03 task over 2 creates, and the TRUCK_TYPE label normalized.
5. Dossier with a settlement copies `total_fob_egp` from the settlement. Mark the case without a settlement `xfail(strict)` until FC-02 lands.
6. Final close with a valid file gives status Closed, progress 100, and stage ARCHIVED_CLOSED.

Regression tests, one per fix:

- WR-01, IT-01, FC-06: a viewer gets 403. Use the `ALLOW_DEV_AUTH_BYPASS=False` seam.
- WR-02: a second GRN gets 409.
- WR-03: ACCEPTED_FULL with a shortage gets 400.
- WR-04: a line that does not balance gets 400; excess is allowed.
- WR-09 and FC-09: restore with a duplicate gets 409.
- IT-02: a retried create gets 409.
- IT-03: gate-out on a deleted booking gets 404.
- IT-04: a notification row exists.
- IT-05: gate-out after arrival gets 409.
- FC-01: an empty checklist with no GRN or dossier gets 400, and a DB error makes the close fail (no silent pass).
- FC-03: precheck `can_close` and close agree, checked with a parametrized matrix.
- FC-04: a second close gets 409.
- FC-05: `closed_at_phase` is set.
- FC-02: no 48.5 factor.

Files: `tests/unit/test_warehouse_receiving.py`, `test_tr01_inland_transport_coordination.py`, `test_file_closure.py`, `test_clo04_official_file_closure.py`. Existing tests to re-check: `test_tr03*`, `test_tr04*` (verdict payload l.206), `test_under_bond_and_quarantine.py`, `test_inbound_and_closure_workflow.py`, `test_clo03*`, `test_file_closure.py` (checklist with `warehouse_received=False`, l.232).

Flutter: `frontend/test/features/file_closure/file_closure_model_test.dart` (missing key gives false), `.../warehouse_receiving/grn_line_balance_test.dart`, `.../inland_transport/inland_transport_provider_test.dart` (an error is rethrown, not null).

## 4. Work packages (disjoint files)

| Package | Owner | Files (exclusive) | Findings |
|---|---|---|---|
| **BE** | backend-developer | `modules/warehouse_receiving/*`, `modules/inland_transport/*` (deletes `migration.py`), `modules/file_closure/*`; new `tests/unit/test_phase08_10_characterization.py`; the 4 test files above | WR-01..11, IT-01..07, FC-01..13. Order: characterization tests, then permissions, then WR-02/03/04, IT-02/03, FC-01/03/04, then the rest |
| **FE** | flutter-developer | `frontend/lib/features/{warehouse_receiving,inland_transport,file_closure}/**`; l10n keys only between `// === review phase08_10 keys ...` and `// === end review phase08_10 keys ===` in `frontend/lib/core/localization/app_localizations{,_ar,_en}.dart`; `frontend/test/features/{warehouse_receiving,inland_transport,file_closure}/**` | FE-01..17. FE-01, 02, 04, 06, 07, 09..15, and 17 can start now. FE-03, 05, and 08 follow BE's contract |

**Contract changes, listed explicitly:**

1. Every route in the 3 modules can now return 403.
2. `WarehouseInspectionSubmit.inspection_verdict` defaults to `null`. Invalid or inconsistent verdicts get 400. Committee defaults to `null`.
3. GRN lines must balance (400). Duplicate GRN: 409 with `detail={code: WR_GRN_EXISTS, message, grn_code}`.
4. PUT `status` / `discrepancy_type` / `inspection_verdict` (WR), `status` (IT and FC) are restricted to the known values (400).
5. Duplicate IT booking: 409 `IT_BOOKING_EXISTS` with `transport_code`. Out-of-order gate-out or arrival: 409. A deleted booking now returns 404.
6. Closure: the client checklist no longer gates. Non-draft POST without the dossier export now gets 400 (it used to pass). A closed file gets 409 `FC_ALREADY_CLOSED`. Deleting a Closed record gets 409.
7. Additive: `blocking_messages` and `warning_messages` on precheck, `closure_readiness.empty_containers_returned`. Dossier string fields may be `""` instead of invented values.

## 5. Shared needs (devs do NOT edit these; the lead or package A does)

- `modules/common/system_messages.py` + `docs/system_message_codes.json`: codes `FC_BLOCK_CUSTOMS`, `FC_BLOCK_GRN`, `FC_BLOCK_LANDED_COST`, `FC_BLOCK_DOSSIER`, `FC_WARN_CONTAINERS`, `FC_WARN_DOCS`, `FC_WARN_OPEN_TASKS` (count). Until they exist, BE ships FC-13 without `*_messages` and keeps the Arabic lists.
- `modules/common/enum_codes.py` + `docs/enum_codes.json` (next wave): `WAREHOUSE_RECEIVING_STATUS`, `GRN_DISCREPANCY_TYPE`, `INLAND_TRANSPORT_STATUS`, `FILE_CLOSURE_STATUS`, with the legacy labels mapped. This wave validates against module-local legacy sets only.
- `modules/auth/seed_rbac.py`: only if Q1 picks a dedicated `inland_transport.manage`.
- `modules/import_files/service.py:reopen_shipment_service`: on reopen, mark the active closure record "Reopened" (or deactivate it) and write an audit log entry with the reason (BP-040 "Authorized Re-Open Protocol"). It should also require `import_files.close`. This is outside both packages.

## 6. Risks

- **FC-01/03 tighten the gate.** Files that closed before without the dossier export or the customs status will now be blocked. Before merging, run a read-only count of open files that pass the old gate and fail the new one.
- **WR-04** rejects unbalanced payloads. Old GRN rows are not touched, but editing an old unbalanced row will now require fixing its lines.
- **Permissions:** IT reuses `warehouse_receiving.*`. Roles without it (for example the customs broker role) lose booking rights. Check `seed_rbac.py:122-230` with the user.
- `advance_lifecycle_step_service` may commit internally, so a single commit is guaranteed only for the module's own rows.

## 7. Open questions for the CTO (safe default in brackets)

- **Q1**: Inland transport permission: a dedicated code, or reuse warehouse_receiving? [reuse]
- **Q2**: Closure gate. Customs: does a release permit or date count without the "Final Release Granted" status? [yes] Settlement: is "Calculated" enough, or must it be Approved (the doc says "معتمدة 100%")? [keep Calculated/Approved/Closed] Unreturned containers and Form 4/SWIFT: block or warn? [warn, as today] A GRN still under quarantine lock: block? [block]
- **Q3**: Is a real GRN draft wanted (a status that does not advance the lifecycle)? [no: hide it on create]
- **Q4**: GRN balance rule: accepted + shortage + damaged = invoiced, with excess allowed only when there is no shortage or damage? [yes]
- **Q5**: Deleting a Closed closure record: forbid and require reopen? [forbid, 409]
- **Q6**: Should final close auto-complete all open tasks of the file, or keep the warning? [keep the behaviour, fix the text]
- **Q7**: Remove the client-side waybill generator? [remove]
- **Q8**: Should goods-in-transit get a backend source? [backlog]
- **Q9**: With several trucks per file, `inland_transport_cost_egp` keeps only the last fare. Sum the fares instead? [keep the last; backlog]
