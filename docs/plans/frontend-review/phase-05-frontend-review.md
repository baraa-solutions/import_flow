# Phase 05 Cargo shipping: frontend review

Status: 2026-10-05, static review only (no flutter test, no pytest, no `import main`, no code edited). Scope: the Flutter features of Phase 05 (BP-020..025) plus the two Phase-05-owned operational screens wired in the sidebar: Cargo Shipping (nav 26 / 52), Shipment Update Engine (nav 42), Demurrage & Detention (nav 44). Backend contracts checked against `modules/{cargo_shipping,shipment_updates,demurrage_detention}/{router,schemas}.py` and the relevant service/repository lines. Previous plan: `docs/plans/phase-04-05-quality-plan.md` (FE-01..FE-12). Items verified fixed there are not repeated: FE-01 (typed `DualClockModel`), FE-02 (`buildCargoShippingPayload` drops `status`/`owner` on edit), FE-03 (no hard-coded FX 50), FE-05 (SU dropdowns are `SearchableDropdownField`), FE-08 for the SLA PDF (now `FileSaveHelper.exportAndSaveFile`), FE-12 (SU create and demurrage mutations invalidate file/lifecycle providers).

Note on BP-022/023/024 UI: the dual approval, original-docs courier and CargoX screens that users actually see are `features/import_documentation/screens/original_docs_and_cargox_screen.dart` (nav 54/57/58). They call the import-documentation backend, **not** `/cargo-shipping/{id}/approval/*` or `/cargo-shipping/{id}/cargox/*`. That screen belongs to the Phase 06 review; here it is only referenced (F05-14, Q1).

### Coverage depth

| file | lines | depth |
|---|---|---|
| `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart` | 3032 | read 1-1175, 1430-1660, 2253-2295, 2615-3032; Step-2 tracking cards (1660-2250) and LCL card (2293-2611) by grep only |
| `frontend/lib/features/cargo_shipping/models/cargo_shipping_model.dart` | 649 | full |
| `frontend/lib/features/cargo_shipping/models/cargo_container_defaults.dart` | 38 | full |
| `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart` | 197 | full |
| `frontend/lib/features/cargo_shipping/widgets/cargo_shipping_ui.dart` | 793 | 12-40, 339-495 full; rest grep |
| `frontend/lib/features/cargo_shipping/services/cargo_shipping_sla_export_service.dart` | 478 | 425-478 + grep |
| `frontend/lib/features/cargo_shipping/widgets/search_and_clone_cargo_shipping_dialog.dart` | 245 | not read (grep only) |
| `frontend/lib/features/shipment_updates/screens/shipment_update_engine_screen.dart` | 739 | full |
| `frontend/lib/features/shipment_updates/widgets/shipment_update_dialog.dart` | 359 | full |
| `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart` | 113 | full |
| `frontend/lib/features/shipment_updates/models/shipment_update_model.dart` | 115 | full |
| `frontend/lib/features/shipment_updates/widgets/su_consultation_dialog.dart`, `su_customs_section.dart`, `su_ui.dart` | 930 | grep only (customs consultation belongs to Phase 02/06) |
| `frontend/lib/features/demurrage_detention/screens/demurrage_detention_screen.dart` | 953 | 35-116, 325-552, 900-953 full; simulator tab grep |
| `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart` | 307 | full |
| `frontend/lib/features/demurrage_detention/models/demurrage_model.dart` | 698 | 100-175 + grep |
| `frontend/lib/features/demurrage_detention/widgets/demurrage_form_dialogs.dart` | 444 | 10-100, 320-375 + grep |
| `frontend/lib/features/demurrage_detention/widgets/demurrage_tracking_card.dart` | 400 | 160-201, 260-400 |
| `frontend/lib/features/demurrage_detention/widgets/demurrage_status.dart` | 59 | full |
| `frontend/lib/features/demurrage_detention/widgets/{dual_clock_radar_dialog,empty_container_return_dialog,free_days_agreement_dialog,freight_data_monitor_dialog,demurrage_simulation_panel}.dart` | 3219 | grep only |
| Backend `modules/cargo_shipping/{router,schemas}.py`, `service.py` 57-95,160-240,470-520, `repository.py` 30-50, `validators.py` 8-26 | — | contract read |
| Backend `modules/shipment_updates/{router,schemas}.py` | — | full |
| Backend `modules/demurrage_detention/router.py` 54-190, `schemas.py` 55-175, `service.py` greps, `repository.py` 86-101 | — | contract read |

---

## 1. Summary

| severity | count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 5 |
| MAJOR | 21 |
| MINOR | 8 |

Most important points:

1. **Demurrage money is pushed to the wrong import file.** `_handlePushToSettlement` sends `importFileId: item.importFileId ?? 1`. A tracking with no file (the create dialog cannot even link a file) gets its fines posted into file #1's financial settlement (F05-01, F05-21).
2. **Editing any container field in Cargo Shipping wipes the milestone audit trail.** Every `onChanged` in the container card rebuilds `ContainerLoadingModel(...)` by hand and drops `trackingHistory`, `milestoneNotes` and `slaDeadlineAt`. The next save PUTs the containers back and the backend stores them as sent (F05-02).
3. **Three normal-path actions always fail:** per-container milestone quick-save (PATCH body lacks the required `container_no` → 422, then a `TypeError` in the error handler) (F05-03); Shipment Update "Edit" (opens the create dialog without the file code → "select a shipment" or a duplicate log) (F05-04); "Comprehensive daily check-in" (sends `current_module` text such as `Phase 7 - Customs Clearance` as `target_phase` → 422) (F05-05).
4. **Large tables:** none of the 4 Phase-05 lists pages. Cargo registry and SU logs load every row and build them all (`ListView(shrinkWrap)` / `DataTable` inside `SingleChildScrollView`); demurrage trackings and policies are silently capped at 100 by the backend default `limit=100`, so the KPI "total demurrage EGP" is wrong once there are >100 sessions (F05-07, section 3). The repo already has the right pattern (`/import-files/paginated` + `CompactTablePaginationFooter`).
5. **Why there is no "Show / عرض":** Cargo Shipping has no read-only view at all: row tap and the pencil both call `_loadRecordForEditing`, which loads the record into the editable form tab (even soft-deleted records); the provider has no GET-by-id. Demurrage has no details view (the card shows only a container *count*). Shipment Updates does have a View, but it hides category, priority and cost (section 4).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F05-01 | BLOCKER | `features/demurrage_detention/screens/demurrage_detention_screen.dart:936` | `pushToSettlement(item.trackingId, importFileId: item.importFileId ?? 1)`. Backend `service.py:746-752` uses `tracking.import_file_id or req.import_file_id`, so an unlinked tracking posts its demurrage/detention/storage charges into import file #1's settlement | Never default the id. If `item.importFileId == null`, disable the push button with a tooltip ("link an import file first") and do not call the API; send `import_file_id` only when present |
| F05-02 | BLOCKER | `features/cargo_shipping/screens/cargo_shipping_screen.dart:1404-1425,1446-1464,1487-1505,1585-1601,1627-1643` | Container type / qty / VGM weight / container no / seal `onChanged` build a new `ContainerLoadingModel(...)` without `trackingHistory`, `milestoneNotes`, `slaDeadlineAt`. `buildCargoShippingPayload` then PUTs them and `service._process_container_items` (`service.py:57-73`) stores what it gets: the milestone history and notes of that container are erased | Replace every manual rebuild with `item.copyWith(...)` (already exists, `cargo_shipping_model.dart:118-160`). Add a unit test that edits a field and asserts history/notes survive in the payload |
| F05-03 | CRITICAL | `cargo_shipping_screen.dart:744-751,770-776` (same at 826-836 for LCL error path) | Quick milestone save PATCHes `/containers/{no}/loading-tracking` with a body that has no `container_no`, but `ContainerLoadingTrackingUpdate.container_no: str` is required (`schemas.py:49`) → 422 every time. The catch then passes `e.response.data['detail']` (a `List` for 422) into `cargoShippingQuickSaveError(String)` → `TypeError`, no SnackBar. A blank container no (new row) also builds `/containers//loading-tracking` | Add `'container_no': c.containerNo` and `'seal_no'` to the body; block the quick-save with a SnackBar when `containerNo` is empty; render errors with `ApiErrorText.of(l, e)` |
| F05-04 | CRITICAL | `features/shipment_updates/screens/shipment_update_engine_screen.dart:534-541`; `widgets/shipment_update_dialog.dart:15-46,135-140,158` | "Edit" opens `ShipmentUpdateDialog` in create mode without `initialFileCode` → submit is blocked by "shipment required" (`_selectedFileCode == null`); if the user re-picks the file a **new** log is created (duplicate). The provider has no update method although `PUT /shipment-updates/{id}` exists | Add `existing: ShipmentUpdateLogModel?` to the dialog (prefill note/date/cost/priority, lock file/category/phase as the PUT schema allows), add `updateLog(id, payload)` to the provider calling PUT with only `ShipmentUpdateLogUpdate` fields |
| F05-05 | CRITICAL | `shipment_update_engine_screen.dart:199-209`; dialog `:112` | Daily check-in passes `file.currentModule` (values like `Phase 7 - Customs Clearance` or `STEP_07 ...`, see `modules/customs_clearance/service.py:606`, `common/file_tracking.py:100`) as `target_phase`. Backend pattern is `^Phase (10|[1-9])$` → 422; the dropdown also shows no selection because the value is not in its items | Derive `Phase N` from the file (`currentPhaseId` / leading `Phase N` regex); when it cannot be derived, leave the phase empty and make it required |
| F05-06 | CRITICAL | `features/demurrage_detention/providers/demurrage_provider.dart:68-80,82-85,105-108`; screen `:62-70` | `fetchPolicies` and `fetchTrackings` share one `_cancelToken`. `loadInitialData` runs both in `Future.wait`, so `fetchTrackings` cancels the policies request and the cancel is swallowed → Policies tab empty on first load. When the screen opens with `initialImportFileId`, policies are never requested at all | One `CancelToken` per request type (`_policiesToken`, `_trackingsToken`); in `initState` always call `fetchPolicies()` too |
| F05-07 | CRITICAL | `demurrage_provider.dart:105-123`; screen `:333-335`; backend `repository.py:86-101` (`limit=100`) | Trackings (and policies) list is silently capped at the 100 newest rows; the FE cannot page. KPI "total calculated demurrage" (`screen:333`) and "incurred count" are computed on the partial list → wrong totals | Backend: paginated endpoint + server totals (section 6). FE: paged provider + footer + KPIs from the server summary |
| F05-08 | MAJOR | `cargo_shipping_screen.dart:2981-2988,3018-3026` | Restore and delete have no try/catch. Backend returns 409 for a non-deletable status (`validate_deletable`) or a restore conflict → unhandled async error, the user sees nothing. No `ref.invalidate(importFilesProvider / lifecycleBoardSummaryProvider)` after them. Delete success uses `AppSeverity.danger` | Wrap in try/catch + `ApiErrorText.of` SnackBar; invalidate file/lifecycle providers; success severity |
| F05-09 | MAJOR | `cargo_shipping_screen.dart:969-1000` | Every save error (403, 409, 422, network) shows `e.toString()` (raw `DioException ...` text) in a dialog titled "duplicate warning". Still open from FE-07 (cargo part) | Show `ApiErrorText.of(l, e)`; use the duplicate dialog only for 409 with the duplicate detail; others as SnackBar |
| F05-10 | MAJOR | `cargo_shipping_screen.dart:312-423` with `203-291` | Clone sets `_selectedImportFileId = null`; picking the target file runs `_onImportFileSelected`, which **always** replaces `_containers` (existing record, booking, or `_initDefaultContainer`). The cloned container lines are lost. Also invents `SHP-DRAFT-…` code (`:315`) and a `'CFS Warehouse'` name (`:391`) | Keep a `_pendingClone` flag; in `_onImportFileSelected` do not overwrite containers when a clone is pending (ask before replacing). Show "new record" instead of an invented code; leave CFS empty when the source had none |
| F05-11 | MAJOR | `cargo_shipping_screen.dart:2820-2828`; `widgets/cargo_shipping_ui.dart:28-38,367-369` | Registry status filter offers only `Cargo Ready`/`Completed`; backend ladder has 6 (`validators.py:8-14`: Loaded & Sealed, Dual Approved, Docs Dispatched, CargoX Transfer Completed). Other statuses render raw English text and all get `info` severity | Status list from one constant; l10n label + severity per status code |
| F05-12 | MAJOR | `cargo_shipping_screen.dart:2765,2773,2781` | TSV / Excel / PDF exports receive `allRecords`, ignoring search/status/SLA/active filters and including soft-deleted records; status column exported as raw English | Export the filtered list (or full server result set with the same filters once paginated); localized status |
| F05-13 | MAJOR | `cargo_shipping_ui.dart:375,473`; screen `:2977` | Row tap and Edit open soft-deleted records in the editable form; saving PUTs an inactive record → 404 | Soft-deleted rows: View only + Restore; no edit |
| F05-14 | MAJOR | `cargo_shipping_provider.dart:124-170`; `cargo_shipping_model.dart:625-649` | No UI anywhere for: CRD vs cut-off (BP-020: `crd_date`, `cargo_cutoff_date`, `is_crd_validated`), `/approval/level1|2` (BP-022), `courier_tracking_data` (BP-023), `/cargox/run-checklist|advance-stage` (BP-024), `live_tracking_url` (BP-025). Provider methods exist but are never called; the payload never sends these fields | Decide (Q1) which implementation is authoritative. Minimum here: show CRD / cut-off / `is_crd_validated` warning and `live_tracking_url` in the record view (FE05-T08) |
| F05-15 | MAJOR | `cargo_shipping_screen.dart:1434-1440,1472-1485,1567-1640` | Container no, seal no, qty, VGM weight have no validators: `int.tryParse ?? 1`, `double.tryParse ?? 0.0` silently; no ISO-6346 container format (`MSKU1234567`), no duplicate container/seal check in the form | `TextFormField.validator`s (required, `^[A-Z]{4}\d{7}$`, positive numbers), `FilteringTextInputFormatter`, duplicate check across units |
| F05-16 | MAJOR | `cargo_shipping_model.dart:37,68,561,598`; `shipment_update_model.dart:55`; `demurrage_model.dart:144`; `cargo_shipping_screen.dart:115-125` | Invented defaults: `vgmStatus = 'Submitted'` (backend default is `Pending`), `owner = 'Kamal'`, `assignedUser = 'Kamal'` (still open from FE-05), `portName = 'Alexandria Port'`, new container assignment date = now, LCL `consolidationScheduledDate = now` + `ASSIGNED` | Defaults `Pending` / `''` / null; leave dates null until the user sets them |
| F05-17 | MAJOR | `shipment_update_dialog.dart:310` | Priority option `Low` is not in backend `AlertPriority = Literal["Normal","High","Critical"]` → 422 | Remove `Low` (or add it in backend, Q4) |
| F05-18 | MAJOR | `shipment_update_dialog.dart:118-119,150-155,188-196,326-336,347` | Log date is free text with no picker/validator (backend requires `YYYY-MM-DD`); cost fields default `0.0` and parse failures become `0.0` silently (wrong money on a "Phase Cost Adjustment"); note validator allows 1 char (backend `min_length=2`) | Date picker (read-only field), numeric validators required when category = cost adjustment, note ≥ 2 |
| F05-19 | MAJOR | `shipment_update_engine_screen.dart:624-661` | View dialog shows only phase, date, user, note; hides category, priority, cost item/previous/new, created by/at | Full read-only details (FE05-T06) |
| F05-20 | MAJOR | `shipment_updates_provider.dart:89`; screen `:482` | Load error stored as `e.toString()` and displayed raw. Still open from FE-07 | Store the error object; render `ApiErrorText.of` |
| F05-21 | MAJOR | `demurrage_form_dialogs.dart:17-38,65-91,95-100` | Add-tracking dialog: no import-file selector (backend accepts `import_file_id`), no policy selector, a single container only, carriers/ports are hard-coded string lists (master data as free text, not `transport_locations` / partners FK), discharge date defaults to "now − 5 days", the dialog closes even on failure (input lost) | File selector (SearchableDropdown), policy selector filtered by carrier, repeatable container rows, ports from transport-locations provider, no default date, stay open on error |
| F05-22 | MAJOR | `demurrage_detention_screen.dart:448-458` | Status filter misses `Demurrage & Detention Incurred`, `Closed`, `All Containers Returned`, `All Containers Gated Out` (`service.py:367-372,716,976-978`); "Demurrage Incurred" does exact match and hides combined cases | Full status list + l10n via `localizedDemurrageStatus` |
| F05-23 | MAJOR | `demurrage_tracking_card.dart:311-317`; screen `:932-952`; `demurrage_model.dart:135-160` | "Push to financial settlement" posts money with one click, no confirm dialog showing totals. `settlement_warning_code` (`DD_SETTLEMENT_STALE`) is not parsed, so a stale pushed settlement is never flagged | Confirm dialog (file code, totals EGP, rate); map `settlementWarningCode` and show a warning chip using the system message catalog |
| F05-24 | MAJOR | `demurrage_detention_screen.dart:532-543` | Prefill reads `containers.first['container_number']`, the stored key is `container_no` (`service.py:648`) → always null | Read `container_no` |
| F05-25 | MAJOR | `demurrage_form_dialogs.dart:326-328,359-366`; `demurrage_tracking_card.dart:330-400` | Policies: no edit / delete / view though `PUT/DELETE/GET /policies/{id}` exist; free-day fields pre-filled 14/7/5 and unparseable input silently falls back to them | Edit + soft-delete actions; empty required fields with validators |
| F05-26 | MAJOR | `demurrage_detention_screen.dart:82-85` | Refresh (`_reload`) calls `loadInitialData()` without `initialImportFileId`, so a screen opened for one file switches to all files after refresh | Keep the file filter in state; reload with it |
| F05-27 | MAJOR | cargo registry `:2688-2960`; SU `:498-516`; demurrage `:395-401,914-922` | All lists build every row (`shrinkWrap` + `NeverScrollableScrollPhysics` inside `SingleChildScrollView`, or `DataTable`): no paging, no virtualization, no sticky header, client-side search/filter | Section 3 / FE05-T09..T11 |
| F05-28 | MAJOR | `demurrage_tracking_card.dart:169-173` | The card never shows the linked import file code (and shows only the container *count*), so the user cannot see which file the fines belong to | Show `importFileCode` chip (or "not linked" warning) |
| F05-29 | MINOR | `cargo_shipping_model.dart:197-212,345-361` | `arabicStatusLabel` getters with Arabic literals are dead code. Still open from FE-09 | Delete |
| F05-30 | MINOR | `cargo_shipping_screen.dart:1012-1022,1028-1030` | Tab and stage titles hard-coded (`titleEn`/`titleAr` literals) | l10n keys |
| F05-31 | MINOR | `features/shipment_updates/widgets/su_consultation_dialog.dart:89-90,325` | Status matched by Arabic substrings (`'معتمد'`, `'مرفوض'`) | Match on status codes |
| F05-32 | MINOR | `cargo_shipping_screen.dart:1580-1584,1622-1626` | `List.from(item.individualUnits)` is a shallow copy; the unit maps are mutated in place (shared with the provider's cached model) | Copy each map (`{...u}`) |
| F05-33 | MINOR | `shipment_update_engine_screen.dart:80-93`; dialog `:263-268` | Category `Milestone Phase Progression` (backend literal) has no label and shows raw English | Add l10n label (display only, not selectable) |
| F05-34 | MINOR | `shipment_update_engine_screen.dart:523-524` | Cost column always says USD; the log has no currency field | Drop the currency suffix or add a currency field (Q5) |
| F05-35 | MINOR | `cargo_shipping_screen.dart:138-151` | Screen mount fetches all freight bookings and all purchase orders just to prefill containers and compute CBM for one file | Fetch by `import_file_id` when a file is selected |
| F05-36 | MINOR | `demurrage_form_dialogs.dart:149-163` | Container/BL validators only check non-empty; backend needs container ≥ 4 chars, BL ≥ 3 → raw 422 | Mirror min lengths (and ISO-6346 for container) |

---

## 3. Large tables

Reference pattern already in the repo: `features/import_files/providers/import_files_provider.dart:60-110` calls `GET /import-files/paginated?page=&page_size=&search=&status=` and gets `{items,total,page,page_size,total_pages}`; `core/widgets/compact_table_pagination_footer.dart` renders the footer; `core/widgets/enterprise_data_table/` has a table with column picker, header toolbar, pagination bar and shimmer skeleton.

### 3.1 Cargo Shipping registry (`cargo_shipping_screen.dart:2680-2963`)

- Today: `GET /cargo-shipping?include_inactive=true` with no limit (`provider:41-49`); backend `repository.py:49` returns `.all()`. The tab is a `SingleChildScrollView` holding a `ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics)` (`:2947-2957`) → every row widget is built at once. Search, status, SLA and active filters run client-side (`:2898-2925`); backend `search` only covers code and owner (`repository.py:43-48`), not file code, company or container no. No sorting, no sticky header (rows are cards, not a table), no row count except the metric card, exports take `allRecords`. Metrics (FCL/LCL/breached) are computed from the loaded list. `_onImportFileSelected` (`:209-216`) and `_submitForm` (`:910-916`) look for an existing record of the file in the loaded list, so they depend on "everything is loaded".
- With thousands of rows: slow first paint, long jank on every keystroke (whole list filtered and rebuilt via `setState`), memory grows with container JSON per record.
- Recommended: backend `GET /cargo-shipping/paginated` (page, page_size, search over code/file code/company/container no/seal, status, sla=breached|ontime, active=active|deleted|all, sort) + `GET /cargo-shipping/summary` (counts per type/status/breach). FE: `PaginatedCargoShippingNotifier`, registry as `EnterpriseDataTable` (columns: code, file, company, type, containers, gated, SLA, status, actions) or a `ListView.builder` with the tab as its own scroll view; 300 ms debounced server search; footer with page size; exports call the same endpoint with `page_size=all` (or a dedicated export endpoint). The "existing record for this file" lookup becomes `GET /cargo-shipping?import_file_id=X`.

### 3.2 Shipment update logs (`shipment_update_engine_screen.dart:476-622`)

- Today: logs are fetched per selected file (`provider:70-79`), backend `.all()` (`shipment_updates/repository.py:82`). Rendered by a Material `DataTable` inside a horizontal `SingleChildScrollView` inside the page's vertical `SingleChildScrollView` (`:498-516`) → all rows built, header scrolls away, Actions column scrolls away horizontally (standard §10 wants sticky header + sticky actions). No sorting, no search box, no category/phase filter in the UI even though the provider and backend support `update_category`, `target_phase`, `search`. The file selector loads all import files (`importFilesProvider`).
- With thousands of logs on a long-running file the page becomes heavy; daily check-ins make this realistic.
- Recommended: `GET /shipment-updates/paginated` (import_file_id, category, phase, search, page). FE: `EnterpriseDataTable` with sticky header and pinned actions column, category/phase filters, footer. Metrics from a server summary (counts per category) instead of `logs.length`.

### 3.3 Demurrage trackings (`demurrage_detention_screen.dart:325-407`)

- Today: `GET /demurrage-detention/trackings` without skip/limit; backend silently returns the 100 newest (`repository.py:92,101`). Cards in `ListView.separated(shrinkWrap, NeverScrollable)` (`:395-401`). Search (code/BL/carrier) and status filter client-side (`:327-333`). KPIs (`:333-335`) sum only the loaded 100.
- Recommended: backend paginated endpoint returning `items,total` + a summary `{active, incurred, total_cost_egp}`; FE paged list (`ListView.builder` in its own scroll area or a compact table with expandable row), server search/status, footer; KPIs from summary.

### 3.4 Demurrage policies (`demurrage_detention_screen.dart:834-926`)

- Today: same 100 cap (`repository.py:31,38`), cards in `shrinkWrap` list, no search. Policy count is small in practice; recommended: a compact table with carrier/container-type filter and the same paging contract (low priority).

---

## 4. View/Show action

| entity | View exists? | why not (code reason) | what to add |
|---|---|---|---|
| Cargo shipping record | **No** | The screen is a "form tab + registry tab" stage. `ShippingRegistryRow` has copy / clone / edit / restore / delete only (`cargo_shipping_ui.dart:455-492`); `onTap` and `onOpen` both call `_loadRecordForEditing` (`cargo_shipping_screen.dart:2977`), which loads the record into the editable form. There is no details dialog and the provider has no `fetchRecordById` although `GET /cargo-shipping/{id}` exists (`router.py:61-67`). Soft-deleted rows also open in edit mode | `CargoShippingDetailsDialog` (read-only): header (code, file, company, type, status chip), containers table (no, seal, type, VGM, status, 5 milestones, SLA deadline, breach), LCL block, milestone history and notes, CRD / cut-off / `is_crd_validated`, approvals L1/L2 (read-only), CargoX envelope status, live tracking URL, audit (created/updated by/at). Row tap → View; Edit only for active records. Provider `fetchRecordById(id)` → `GET /cargo-shipping/{id}` so the dialog shows fresh data (FE05-T07) |
| Shipment update log | Yes, partial | `RowActionsPill(onView: _showLogViewDialog)` (`shipment_update_engine_screen.dart:532-548`), but the dialog shows only phase/date/user/note (`:624-661`) and there is no GET-by-id in the provider | Show category, phase status, priority, cost item + previous/new + delta, created by/at, updated by/at; load via `GET /shipment-updates/{id}` (FE05-T06) |
| Demurrage tracking | **No** | The card shows facts inline (`demurrage_tracking_card.dart:160-201`) but only the container *count*, not the containers (numbers, types, per-container gate-out / return / EIR). The Radar dialog shows clocks, not the record. No provider method for `GET /trackings/{id}` | "Details" button on the card → read-only dialog: file code, policy, carrier, BL, port, dates, FX rate, totals (FX + EGP), containers table with per-container dates and EIR, settlement link / stale warning, notes, audit (FE05-T12) |
| Demurrage policy | **No** (and no edit/delete) | `DemurragePolicyCard` only has copy (`demurrage_tracking_card.dart:330-400`); tiers are not displayed; provider has no update/delete/get-by-id | View dialog with tiers; Edit and soft-delete (FE05-T13) |

---

## 5. Tasks

### FE05-T01 — Never post demurrage to a default import file
- Severity: BLOCKER
- Type: bug
- Depends on: none
- Backend needed: no (optional hardening listed in §6)
- Files to change: `frontend/lib/features/demurrage_detention/screens/demurrage_detention_screen.dart`, `frontend/lib/features/demurrage_detention/widgets/demurrage_tracking_card.dart`, `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart`, l10n files (`frontend/lib/core/localization/app_localizations{,_ar,_en}.dart`)
- Steps:
  1. In `_handlePushToSettlement` (`demurrage_detention_screen.dart:932-952`) remove `?? 1`. If `item.importFileId == null`, show a warning SnackBar (new key `demPushNeedsLinkedFile`) and return without calling the API.
  2. In `DemurrageTrackingCard` (`:311-317`) set `onPressed: null` and a tooltip with the same text when `item.importFileId == null`.
  3. Add a confirm dialog before the push: file code, total demurrage FX, detention FX, storage EGP, total EGP, rate. Only on confirm call `pushToSettlement`.
  4. In `pushToSettlement` send `import_file_id` only when not null (`if (importFileId != null) 'import_file_id': importFileId`).
- Acceptance criteria:
  - [ ] A tracking without a linked file cannot be pushed; the button is disabled with an explanation.
  - [ ] Pushing a linked tracking asks for confirmation showing the totals.
  - [ ] No code path sends `import_file_id: 1` unless the tracking is really linked to file 1.
- Tests to add: `frontend/test/features/demurrage_detention/push_to_settlement_test.dart` — fake notifier records calls; tracking with `importFileId: null` → no call, button disabled; tracking with id 7 → confirm dialog shown, call has `importFileId == 7`.
- Out of scope: backend validation that a tracking must have a file (see §6).

### FE05-T02 — Keep container tracking history when editing a container field
- Severity: BLOCKER
- Type: bug
- Depends on: none
- Backend needed: no
- Files to change: `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/models/cargo_shipping_model.dart`
- Steps:
  1. In `_buildContainerEquipmentCard` replace each manual `ContainerLoadingModel(...)` rebuild (type `:1404-1425`, qty `:1446-1464`, weight `:1487-1505`, container no `:1585-1601`, seal `:1627-1643`) with `item.copyWith(...)` passing only the changed fields.
  2. In the unit handlers copy each unit map (`units.map((u) => {...u}).toList()`) before mutating (fixes F05-32).
  3. Make sure `copyWith` carries `slaDeadlineAt`, `trackingHistory`, `milestoneNotes` (it does; keep it as the single rebuild path).
- Acceptance criteria:
  - [ ] Open a saved record with milestones and notes, change a seal number, save: milestones, notes and history are still there after reload.
  - [ ] Changing qty keeps the existing unit numbers of the remaining units.
- Tests to add: `frontend/test/features/cargo_shipping/container_edit_preserves_history_test.dart` — build a `ContainerLoadingModel` with history/notes/sla, apply the same `copyWith` the handler uses, run `buildCargoShippingPayload`, assert `tracking_history`, `milestone_notes`, `sla_deadline_at` are present and unchanged.
- Out of scope: splitting the 3000-line screen.

### FE05-T03 — Fix per-container and LCL milestone quick-save
- Severity: CRITICAL
- Type: bug
- Depends on: none
- Backend needed: no
- Files to change: `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart`
- Steps:
  1. In `_quickSaveContainerMilestone` (`:720-786`) return early with a warning SnackBar when `c.containerNo.trim().isEmpty`.
  2. Add `'container_no': c.containerNo` and `'seal_no': c.sealNo` to the PATCH body (`:744-751`). Move body construction to a pure function `buildContainerMilestonePatch(ContainerLoadingModel c)` in `cargo_shipping_model.dart` so it can be unit-tested.
  3. URL-encode the container number in the provider path (`Uri.encodeComponent`).
  4. Replace the `e.toString().contains('404')` check with `e is DioException && e.response?.statusCode == 404`.
  5. Replace the `cleanMsg` extraction in both catch blocks (`:770-776`, `:826-836`) with `ApiErrorText.of(context.l10n, e)`.
- Acceptance criteria:
  - [ ] Saving a milestone for a container with a number returns success and the status chip updates.
  - [ ] A 422/409 shows the backend Arabic message in a red SnackBar; no red screen or silent failure.
  - [ ] A row without a container number shows "enter the container number first".
- Tests to add: `frontend/test/features/cargo_shipping/milestone_patch_payload_test.dart` — `buildContainerMilestonePatch` contains `container_no`, `seal_no`, the 5 dates and `milestone_notes`.
- Out of scope: per-unit milestones for qty > 1 rows (Q3).

### FE05-T04 — Shipment update: real Edit and correct Daily check-in phase
- Severity: CRITICAL
- Type: bug
- Depends on: none
- Backend needed: no (`PUT /shipment-updates/{id}` exists)
- Files to change: `frontend/lib/features/shipment_updates/widgets/shipment_update_dialog.dart`, `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart`, `frontend/lib/features/shipment_updates/screens/shipment_update_engine_screen.dart`, `frontend/lib/features/shipment_updates/models/shipment_update_model.dart`
- Steps:
  1. Provider: add `Future<ShipmentUpdateLogModel> updateLog(int id, Map<String, dynamic> payload)` → `PUT /shipment-updates/$id`, then `fetchLogs(importFileId: state.selectedFileId)`.
  2. Dialog: add `final ShipmentUpdateLogModel? existing`. When set: prefill note, date, cost item, previous/new cost, priority; disable file, category and phase (not in `ShipmentUpdateLogUpdate`); submit calls `updateLog` with only `note, log_date, adjusted_cost_item, previous_cost, new_cost, alert_priority`.
  3. Screen `:534-541`: pass `existing: log` (and `initialFileCode: log.importFileCode`).
  4. Add a pure helper `String? phaseCodeFromModule(String? currentModule, {int? phaseId})` returning `Phase N` (1..10) from `^Phase (10|[1-9])\b` or the phase id, else null. Use it in `_openDailyCheckin` (`:199-209`). When null, the dialog opens with no phase selected and the phase field is required.
  5. Dialog `_submit`: guard `_selectedFileCode` only on create (backend ignores `import_file_code` on create anyway: drop it from the payload).
- Acceptance criteria:
  - [ ] Edit on a log opens it prefilled; saving changes that log (same code), no new row appears.
  - [ ] "Comprehensive daily check-in" on a file in Phase 7 opens with "Phase 7" selected and saves successfully.
  - [ ] Invalidate `importFilesProvider` and `lifecycleBoardSummaryProvider` after edit too.
- Tests to add: `frontend/test/features/shipment_updates/phase_code_from_module_test.dart` (`'Phase 7 - Customs Clearance'` → `Phase 7`, `'Phase 10 - ...'` → `Phase 10`, `'STEP_07 ...'` → null); `frontend/test/features/shipment_updates/shipment_update_dialog_edit_test.dart` (fake notifier: edit calls `updateLog` with the id, not `createLog`).
- Out of scope: editing category/phase (backend does not allow it).

### FE05-T05 — Shipment update dialog validation and model defaults
- Severity: MAJOR
- Type: bug
- Depends on: FE05-T04
- Backend needed: no (unless Q4 keeps `Low`)
- Files to change: `frontend/lib/features/shipment_updates/widgets/shipment_update_dialog.dart`, `frontend/lib/features/shipment_updates/models/shipment_update_model.dart`, `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart`, `frontend/lib/features/shipment_updates/screens/shipment_update_engine_screen.dart`, l10n files
- Steps:
  1. Remove the `Low` priority item (`:310`).
  2. Date field: `readOnly: true` + `showDatePicker`, stores `yyyy-MM-dd`; validator required.
  3. Cost fields: empty by default (no `'0.0'`); when category = `Phase Cost Adjustment`, item and both amounts required, numeric `>= 0`, input formatter for decimals; payload uses parsed values only after validation.
  4. Note validator: trimmed length ≥ 2.
  5. Model: `assignedUser: json['assigned_user'] ?? ''`, `createdBy ?? ''`; label `Milestone Phase Progression` in `_getCategoryLabel`.
  6. Provider: keep the error object (`errorObject`) and render with `ApiErrorText.of` in `_buildLogsCard` (`:480-485`).
  7. Remove the hard-coded USD suffix in the cost column (`:523-524`) unless Q5 adds a currency.
- Acceptance criteria:
  - [ ] Cannot submit a cost adjustment with empty or non-numeric amounts; red error under the field.
  - [ ] No 422 from priority or date format on the normal path.
  - [ ] Load errors show the backend Arabic message.
- Tests to add: `frontend/test/features/shipment_updates/shipment_update_model_test.dart` (fromJson with missing `assigned_user` → `''`), widget test for the cost validators.
- Out of scope: customs consultation section (`su_*`).

### FE05-T06 — Shipment update: complete read-only View
- Severity: MAJOR
- Type: ux
- Depends on: FE05-T05
- Backend needed: no (`GET /shipment-updates/{id}` exists)
- Files to change: `frontend/lib/features/shipment_updates/screens/shipment_update_engine_screen.dart`, `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart`, `frontend/lib/features/shipment_updates/models/shipment_update_model.dart`, l10n files
- Steps:
  1. Model: parse `updated_at`, `updated_by`.
  2. Provider: `Future<ShipmentUpdateLogModel> fetchLogById(int id)`.
  3. `_showLogViewDialog`: load by id (spinner, error state), show code, file, category chip, phase + phase status, date, priority chip, cost item / previous / new / delta (only for cost adjustments), assigned user, note (selectable, multi-line), created by/at, updated by/at; footer actions Print slip and Close.
- Acceptance criteria:
  - [ ] View shows every field the log has, read-only, in AR and EN, RTL correct.
- Tests to add: `frontend/test/features/shipment_updates/log_view_dialog_test.dart` — pump with a cost-adjustment log, expect the three cost values and the category label.
- Out of scope: paging (FE05-T10).

### FE05-T07 — Cargo shipping: read-only details dialog + safe row actions
- Severity: MAJOR
- Type: feature
- Depends on: FE05-T02
- Backend needed: no (`GET /cargo-shipping/{id}` exists)
- Files to change: new `frontend/lib/features/cargo_shipping/widgets/cargo_shipping_details_dialog.dart`, `frontend/lib/features/cargo_shipping/widgets/cargo_shipping_ui.dart`, `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart`, l10n files
- Steps:
  1. Provider: `Future<CargoShippingModel> fetchRecordById(int id)` → `GET /cargo-shipping/$id`.
  2. New dialog (use `CcStageDialogShell` like the SU view): header chips (code, file, type, status, active/deleted); containers table (no, seal, type, VGM kg, VGM status, 5 milestones formatted with `ShippingFormat.dateTime`, SLA deadline, breach chip); LCL block when LCL; milestone notes and `tracking_history` list; CRD date, cut-off, `is_crd_validated` warning; level 1 / level 2 approval status + by/at (read-only); CargoX `envelope_status`; `live_tracking_url` as a copyable link; created/updated by/at. Actions: Print SLA PDF, Save PDF, Close.
  3. `ShippingRegistryRow`: add a visibility icon (`onView`) first; row `onTap` → View. Edit icon only when `rec.isActive`.
- Acceptance criteria:
  - [ ] Every registry row has "عرض / View" that opens a read-only dialog with fresh data from the server.
  - [ ] A soft-deleted record can be viewed and restored but not edited.
- Tests to add: `frontend/test/features/cargo_shipping/cargo_shipping_details_dialog_test.dart` — pump with a 2-container record (one breached); expect both container numbers, the breach chip, no editable `TextFormField`.
- Out of scope: approval/CargoX actions (Q1).

### FE05-T08 — Cargo shipping registry: statuses, error handling, filtered exports
- Severity: MAJOR
- Type: bug
- Depends on: none
- Backend needed: no
- Files to change: `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/widgets/cargo_shipping_ui.dart`, `frontend/lib/features/cargo_shipping/models/cargo_shipping_model.dart`, l10n files
- Steps:
  1. Add `const cargoShippingStatuses = ['Cargo Ready','Loaded & Sealed','Dual Approved','Docs Dispatched','CargoX Transfer Completed','Completed']` and `String localizedCargoShippingStatus(l, code)` + `ShippingFormat.statusSeverity` for all six. Use them in the filter (`:2820-2828`), the row chip (`cargo_shipping_ui.dart:367-369`) and the exports.
  2. Wrap restore (`:2981-2988`) and delete (`:3018-3026`) in try/catch; error → `ApiErrorText.of` red SnackBar; success delete → `AppSeverity.success`; after both `ref.invalidate(importFilesProvider)` and `ref.invalidate(lifecycleBoardSummaryProvider)`; if the deleted record is the one open in the form, `_resetForm()`.
  3. `_submitForm` catch (`:969-1000`): 409 → keep the existing dialog with `ApiErrorText.of`; other errors → red SnackBar with `ApiErrorText.of`.
  4. Exports (`:2765,2773,2781`) receive the filtered list (move the filter into `List<CargoShippingModel> _applyRegistryFilters(list)` used by both the table and the exports).
  5. Model defaults: `vgmStatus` default `'Pending'` (`:37,68`), `owner` default `''` (`:561,598`); delete the dead `arabicStatusLabel` getters.
  6. Tab titles (`:1012-1030`) from l10n.
- Acceptance criteria:
  - [ ] Filtering by "Dual Approved" works and the chip is translated.
  - [ ] Deleting a record in a protected status shows the backend reason; nothing fails silently.
  - [ ] Exported Excel/PDF/TSV contains exactly the rows on screen.
- Tests to add: `frontend/test/features/cargo_shipping/registry_filter_test.dart` (pure `_applyRegistryFilters` extracted to a top-level function), `cargo_shipping_status_label_test.dart` (six codes → non-raw labels, both locales).
- Out of scope: server paging (FE05-T09).

### FE05-T09 — Cargo shipping registry: server-side paging
- Severity: MAJOR
- Type: feature
- Depends on: FE05-T08, backend B1 (§6)
- Backend needed: yes — `GET /api/v1/cargo-shipping/paginated?page&page_size&search&status&sla&active&sort` returning `{items,total,page,page_size,total_pages}` and `GET /cargo-shipping/summary` (`{total,fcl,lcl,breached}`); search must cover code, import file code/custom number, company, container no, seal no
- Files to change: `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart` (new `PaginatedCargoShippingNotifier`), `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/widgets/cargo_shipping_ui.dart`
- Steps:
  1. New paginated provider modelled on `features/import_files/providers/import_files_provider.dart:60-130` (cancel token, `fetchPage`, `nextPage`, `prevPage`, `setPageSize`).
  2. Registry tab: the list gets its own scroll (`Expanded` + `ListView.builder`, or `EnterpriseDataTable` with sticky header), `CompactTablePaginationFooter` at the bottom, page sizes 25/50/100.
  3. Search: 300 ms debounce → `fetchPage(1, search: ...)`; status/SLA/active dropdowns → server params.
  4. Metrics from `/summary`.
  5. Keep the old `cargoShippingProvider` only for the form's "record of this file" lookup, changed to `fetchRecords(importFileId: id)`; `_onImportFileSelected`/`_submitForm` call the API for that file instead of scanning the whole list.
  6. Exports: fetch all pages for the current filters (loop with `page_size=500`), show a progress SnackBar.
- Acceptance criteria:
  - [ ] With 5,000 records the registry opens in < 1 s and shows 50 rows + "1-50 of 5,000".
  - [ ] Searching a container number finds the record on any page.
  - [ ] Excel export contains all filtered records, not only the current page.
- Tests to add: `frontend/test/features/cargo_shipping/paginated_cargo_shipping_provider_test.dart` (mock Dio adapter: page/page_size/search params sent; state total/totalPages parsed).
- Out of scope: the form tab layout.

### FE05-T10 — Shipment update logs: sticky table, filters, paging
- Severity: MAJOR
- Type: feature
- Depends on: FE05-T06, backend B2
- Backend needed: yes — `GET /api/v1/shipment-updates/paginated?import_file_id&update_category&target_phase&search&page&page_size` + per-category counts
- Files to change: `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart`, `frontend/lib/features/shipment_updates/screens/shipment_update_engine_screen.dart`, `frontend/lib/features/shipment_updates/widgets/su_ui.dart`
- Steps:
  1. Provider: page state (page, pageSize, total, totalPages) and filters.
  2. Replace `DataTable` (`:498-516`) with `EnterpriseDataTable` (sticky header, pinned actions column at the start edge, own vertical/horizontal scroll).
  3. Add search box + category + phase `SearchableDropdownField`s in the toolbar (backend already filters).
  4. Footer `CompactTablePaginationFooter`; metrics from the counts endpoint.
- Acceptance criteria:
  - [ ] Header and actions stay visible while scrolling 1,000 logs; paging works; filters are server-side.
- Tests to add: provider test for query params; widget test that the header stays (find header text after `drag`).
- Out of scope: customs consultation section.

### FE05-T11 — Demurrage: fix loading, file filter and paging
- Severity: CRITICAL
- Type: bug
- Depends on: backend B3 for paging (steps 1-3 can ship first)
- Backend needed: yes for step 4 — `GET /demurrage-detention/trackings/paginated` (`items,total`) + `GET /trackings/summary` (`active, incurred, total_cost_egp`), and policies with explicit paging
- Files to change: `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart`, `frontend/lib/features/demurrage_detention/screens/demurrage_detention_screen.dart`, l10n files
- Steps:
  1. Separate `CancelToken`s for policies and trackings (`:82-123`).
  2. `initState` (`:62-70`) always calls `fetchPolicies()`; store `initialImportFileId` in the notifier state so `_reload` (`:82-85`) and pull-to-refresh reuse it.
  3. Status filter (`:448-458`): add `Demurrage & Detention Incurred`, `Closed`, `All Containers Returned`, `All Containers Gated Out`; labels via `localizedDemurrageStatus`.
  4. Paging: paginated provider, `ListView.builder` in its own scroll view, footer, server search/status, KPIs from summary.
- Acceptance criteria:
  - [ ] Policies tab shows the policies on first open.
  - [ ] Opening the screen for one file and pressing refresh still shows that file only.
  - [ ] With 300 trackings the user can reach all 300; the total demurrage KPI equals the server total.
- Tests to add: `frontend/test/features/demurrage_detention/demurrage_provider_load_test.dart` (mock Dio: both GETs complete, `policies` and `trackings` non-empty after `loadInitialData`).
- Out of scope: simulator tab.

### FE05-T12 — Demurrage: tracking creation linked to a file + details view
- Severity: MAJOR
- Type: feature
- Depends on: FE05-T01
- Backend needed: no (`import_file_id`, `policy_id`, `containers[]` already accepted; `GET /trackings/{id}` exists)
- Files to change: `frontend/lib/features/demurrage_detention/widgets/demurrage_form_dialogs.dart`, `frontend/lib/features/demurrage_detention/widgets/demurrage_tracking_card.dart`, `frontend/lib/features/demurrage_detention/screens/demurrage_detention_screen.dart`, `frontend/lib/features/demurrage_detention/models/demurrage_model.dart`, new `frontend/lib/features/demurrage_detention/widgets/tracking_details_dialog.dart`
- Steps:
  1. `AddTrackingDialog`: required import-file `SearchableDropdownField<int>` (from `importFilesProvider`), optional policy dropdown filtered by carrier, repeatable container rows (no + type, add/remove), ports from the transport-locations provider (fallback: keep list but Q6), no default discharge date (required picker), validators: container `^[A-Z]{4}\d{7}$`, BL ≥ 3. Keep the dialog open on failure and show the SnackBar.
  2. Send `import_file_id`, `policy_id`, `containers: [...]`.
  3. Model: parse `settlement_warning_code`, `created_by/at`, `updated_by/at`; `portName` default `''`.
  4. Card: show the file code chip (or orange "not linked"); show a warning chip when `settlementWarningCode == 'DD_SETTLEMENT_STALE'` using the system message catalog; fix the prefill key `container_no` (`screen:536`).
  5. Details dialog (button "عرض / View" on the card): all fields + containers table with per-container gate-out/return/EIR + totals + settlement link + audit; loaded with `GET /trackings/{id}`.
- Acceptance criteria:
  - [ ] A new tracking is always linked to a file and can hold several containers.
  - [ ] The card shows the file; View shows every container.
  - [ ] "Return containers" opens with the first container prefilled.
- Tests to add: `frontend/test/features/demurrage_detention/tracking_model_test.dart` (fromJson with `settlement_warning_code`), widget test: submit without file → validator error, no API call.
- Out of scope: per-container PATCH editing.

### FE05-T13 — Demurrage policies: view, edit, delete, no invented defaults
- Severity: MAJOR
- Type: feature
- Depends on: FE05-T11
- Backend needed: no (`PUT/DELETE/GET /policies/{id}` exist)
- Files to change: `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart`, `frontend/lib/features/demurrage_detention/widgets/demurrage_form_dialogs.dart`, `frontend/lib/features/demurrage_detention/widgets/demurrage_tracking_card.dart`, `frontend/lib/features/demurrage_detention/screens/demurrage_detention_screen.dart`
- Steps:
  1. Provider: `updatePolicy(id, data)`, `deletePolicy(id)` (refresh list after each).
  2. `AddPolicyDialog` → `PolicyFormDialog({DemurragePolicyModel? existing})`; free-day fields empty and required (no 14/7/5, no silent fallback, `:326-328,359-366`).
  3. `DemurragePolicyCard`: actions View (tiers listed), Edit, Delete (confirm).
- Acceptance criteria:
  - [ ] A policy can be viewed with its tiers, edited and soft-deleted; errors show the backend message.
- Tests to add: widget test — empty free days → validator error; edit submits PUT with the policy id.
- Out of scope: tier editor UX redesign.

### FE05-T14 — Cargo shipping clone and container validation
- Severity: MAJOR
- Type: bug
- Depends on: FE05-T02
- Backend needed: no
- Files to change: `frontend/lib/features/cargo_shipping/screens/cargo_shipping_screen.dart`, `frontend/lib/features/cargo_shipping/models/cargo_container_defaults.dart`, l10n files
- Steps:
  1. Add `bool _pendingCloneContainers`. Set it in clone `onConfirm` (`:353-417`). In `_onImportFileSelected` (`:203-291`), when it is true and the file has no existing record, keep `_containers`; if the file has an existing record, ask "open existing record or keep cloned lines?". Reset the flag after save/reset.
  2. Remove the invented `SHP-DRAFT-…` code (show the l10n text "new record") and the `'CFS Warehouse'` fallback (`:315,391`).
  3. Validators: container no (required when a milestone beyond "assigned" is set; format `^[A-Z]{4}\d{7}$` when filled, uppercase formatter), seal no required when status ≥ LOADING_COMPLETED, qty integer ≥ 1, VGM weight number ≥ 0 (no silent `?? 0` / `?? 1`); duplicate container number across all units → error.
  4. `blankContainer`/`_initDefaultContainer`: `containerAssignmentDate: null`, `trackingStatus: 'PENDING_ASSIGNMENT'`; LCL default without date/ASSIGNED (`:115-125`).
- Acceptance criteria:
  - [ ] Clone → pick a new file → the cloned container types/qty/weights are still there.
  - [ ] Typing `abc` in VGM weight shows a red error, not 0.
- Tests to add: `frontend/test/features/cargo_shipping/container_validators_test.dart` (pure validator functions), `blank_container_test.dart` (no assignment date).
- Out of scope: dual approval / CargoX UI.

---

## 6. Backend dependencies

- **B1** `cargo_shipping`: paginated list + summary; `search` over file code / company / container no / seal (today code + owner only, `repository.py:43-48`). Needed by FE05-T09.
- **B2** `shipment_updates`: paginated list + category counts. Needed by FE05-T10.
- **B3** `demurrage_detention`: `GET /trackings` and `/policies` silently apply `limit=100` (`repository.py:31,92`) and the router exposes no paging params. Add a paginated endpoint with `total` and a summary (`total_cost_egp`, counts). Needed by FE05-T11.
- **B4** `demurrage_detention` push-to-settlement: reject (400 Arabic) when neither the tracking nor the request has a file; optionally ignore `req.import_file_id` when the tracking has none and require linking first (hardening for F05-01).
- **B5** `DemurrageSimulationRequest` still declares `port_storage_daily_rate_egp = 250.0` / `port_storage_free_days = 5` defaults (`schemas.py:132-133`); the FE simulator never sends storage inputs, so verify the service uses system parameters instead of these literals.

## 7. Open questions for the CTO

1. **Which BP-022/023/024 implementation is authoritative?** The visible screen is `import_documentation/original_docs_and_cargox_screen.dart` (import-documentation backend). The `/cargo-shipping/{id}/approval/*`, `/cargox/*`, `courier_tracking_data`, `crd_date`/`cargo_cutoff_date`, `live_tracking_url` endpoints and fields have no UI. Keep both (and add the cargo-shipping actions to the new View dialog), or retire the cargo-shipping copies?
2. Should a demurrage tracking be allowed without an import file at all (today the create dialog cannot link one)? Proposal: file required.
3. Multi-unit container rows (qty > 1): milestones are tracked only on the first unit's container number. Should each unit become its own container row (qty always 1)?
4. Shipment update priority `Low`: drop it from the UI (proposed) or add it to the backend literal?
5. Shipment cost adjustments: which currency? Add a `currency_id` field, or are they always EGP?
6. Demurrage carriers and ports: should they come from master data (Partners type = shipping line, Transport Locations type = port) instead of the hard-coded lists?
