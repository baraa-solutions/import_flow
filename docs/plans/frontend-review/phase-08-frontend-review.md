# Phase 08 Warehouse receiving: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited).
Scope: BP-033 (inland transport + truck arrival + seal check), BP-034 (GRN and line audit), BP-035 (quarantine,
discrepancy and claims). Frontend features `warehouse_receiving` and `inland_transport`.

Where the screens live (`frontend/lib/features/home/home_screen.dart:145,218,221`, `core/providers/navigation_provider.dart:60,95,96,280-284`):

| Screen | Entry | File |
|---|---|---|
| Inbound Warehouse Hub (3 sub-tabs) | sidebar index 28 (GRN tab), 63 (GIT tab), 64 (report tab) | `frontend/lib/features/warehouse_receiving/screens/inbound_warehouse_hub_screen.dart` |
| Tab 0: Goods in transit ledger | hub tab 0 | `.../screens/goods_in_transit_screen.dart` + `widgets/git_ledger_table.dart` |
| Tab 1: GRN registry (cards) + GRN form, discrepancy, inspection, clone dialogs | hub tab 1; also pushed full-screen from `import_files/widgets/import_file_details_dialog.dart:959` | `.../screens/warehouse_receiving_screen.dart` + `widgets/*` |
| Tab 2: Received shipments report | hub tab 2 | `.../screens/warehouse_received_report_screen.dart` + `widgets/received_report_table.dart` |
| Inland transport booking (TR-01) | only a dialog: `import_file_details_dialog.dart:923` and the GIT tab "Book inland" button | `frontend/lib/features/inland_transport/widgets/inland_transport_dialog.dart` |

Coverage depth:

| file | lines | depth |
|---|---|---|
| `warehouse_receiving/screens/warehouse_receiving_screen.dart` | 746 | Full |
| `warehouse_receiving/widgets/warehouse_receiving_form_dialog.dart` | 580 | Full |
| `warehouse_receiving/widgets/grn_record_card.dart` | 334 | Full |
| `warehouse_receiving/widgets/grn_discrepancy_dialog.dart` | 237 | Full |
| `warehouse_receiving/widgets/warehouse_inspection_dialog.dart` | 634 | Full |
| `warehouse_receiving/providers/warehouse_receiving_provider.dart` | 145 | Full |
| `warehouse_receiving/models/warehouse_receiving_model.dart` | 201 | Full (JSON keys vs `WarehouseReceivingResponse`) |
| `warehouse_receiving/models/grn_line_balance.dart` | 39 | Full |
| `warehouse_receiving/screens/inbound_warehouse_hub_screen.dart` | 145 | Full |
| `warehouse_receiving/screens/goods_in_transit_screen.dart` | 306 | Full |
| `warehouse_receiving/screens/warehouse_received_report_screen.dart` | 268 | Full |
| `warehouse_receiving/widgets/received_report_table.dart` | 220 | Full |
| `warehouse_receiving/widgets/git_ledger_table.dart` | 197 | 1-80 full, rest skimmed |
| `warehouse_receiving/providers/goods_in_transit_provider.dart`, `models/goods_in_transit_model.dart` | 45 + 99 | Full |
| `warehouse_receiving/services/warehouse_received_report_export_service.dart` | 497 | 40-110 (row derivation), 195-235, 470-497 (save calls) |
| `warehouse_receiving/services/goods_in_transit_export_service.dart` | 519 | save calls only (grep) |
| `warehouse_receiving/widgets/search_and_clone_warehouse_receiving_dialog.dart` | 299 | 49-80, 160-200 |
| `warehouse_receiving/widgets/ops_ui_kit.dart` | 503 | not read (shared presentational kit) |
| `inland_transport/widgets/inland_transport_dialog.dart` | 981 | 1-420 full, 600-720 full, 720-981 grep + 905-930 |
| `inland_transport/providers/inland_transport_provider.dart` | 99 | Full |
| `inland_transport/models/inland_transport_model.dart` | 173 | 1-80 |
| Cross-feature | — | `core/localization/domain_enum_labels.dart:73-75,470-480,800-830,900-925,956-1000`, `core/widgets/row_actions_pill.dart`, `import_files/widgets/import_file_details_dialog.dart:945-965`, `comprehensive_report/screens/import_file_comprehensive_report_screen.dart:70-80,115` |
| Backend contract | — | `modules/warehouse_receiving/{router.py, schemas.py, repository.py, validators.py}` full; `service.py` 96-160, 312-345, 408-520. `modules/inland_transport/{router.py, schemas.py}` full; `validators.py` statuses; `service.py` 70-110, 185-240 |
| Docs | — | `docs/phase_08_warehouse_receiving.md`, `docs/phase_08/README.md`, `docs/phase_08/tasks/BP-033..035` (generic templates), `docs/plans/phase-08-10-quality-plan.md`, `docs/plans/review-coverage.md`, skill `ui-screen-standards` (Type B, section 10 tables) |

Previous wave check (`phase-08-10-quality-plan.md` FE items), verified fixed in the current code: FE-01 (no invented
quantities, live line balance: `warehouse_receiving_form_dialog.dart:46-55,469-579`), FE-02 (PO match by file id: `:183`),
FE-03 (no draft on create: `:221`), FE-04 (gate-out/arrival send `notes`: `inland_transport_dialog.dart:30-40`),
FE-05 (ACCEPTED_FULL hidden when shortage/damage: `warehouse_inspection_dialog.dart:416`), FE-06 (by-file errors rethrown,
error view: `inland_transport_provider.dart:44-53`, dialog `:173-180,367-404`), FE-10 (PDF via `FileSaveHelper.exportAndSaveFile`),
FE-12 (waybill generator removed), FE-13 (0 Arabic literals left in both features), FE-14 (no `Colors.*`, no
`DropdownButton`, no `ElevatedButton` in both features), FE-15 (filters remembered, related providers invalidated:
`warehouse_receiving_provider.dart:30-47`), FE-17 (`samples_qty` no longer sent).
Still open: FE-11 partly (report and GIT error views print the raw error), FE-16 (GIT ledger is memory only).

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 1 |
| CRITICAL | 3 |
| MAJOR | 23 |
| MINOR | 8 |

The most important points:

1. **The "Received shipments report" makes up data (BLOCKER).** Every row gets a fake file code `IMP-<database id>`,
   a fake PO `PO-MAIN-<id>`, a fake container `1 × 40ft HQ`, samples `0`, and the status column always says
   "Approved & Received", even for quarantined or discrepancy GRNs. This goes into the PDF/CSV the user hands over
   (`warehouse_received_report_export_service.dart:56-69`, `received_report_table.dart:197-205`).
2. **The inland transport flow breaks after gate-out (CRITICAL).** The dialog compares the booking status to
   `'In Transit (Gate-Out)'` and `'Arrived Warehouse'`. The backend writes `'In Transit'` and `'Arrived at Warehouse'`.
   After gate-out the "warehouse arrival" button never appears, and the status reads "Not booked"
   (`inland_transport_dialog.dart:16-21,657-688` vs `modules/inland_transport/validators.py:10-14`).
   Related: "Edit / Rebook" does not edit. It POSTs a new booking (`:628-632` → `_submitBooking` `:231`), and the
   GIT tab's "Book inland" opens the dialog for an arbitrary file (`goods_in_transit_screen.dart:41-45`).
3. **Large tables:** nothing pages on the server (`repository.py:58` returns `.all()`). The GRN registry is a lazy
   `SliverList` of ~260 px cards (about 2 visible at 1366×768). The report and GIT tabs build one `DataTable` row per GRN line, all at once,
   inside a vertical `SingleChildScrollView`. With thousands of lines that freezes the UI. There is no sticky header, no sort and no row count.
   The report tab and the comprehensive report also reuse the **same filtered provider** as the GRN tab, so their totals
   change with the GRN tab's search box.
4. **"Show" (عرض):** the GRN card has a View icon, but it opens the **editable** form (`warehouse_receiving_screen.dart:697-698`,
   `onView` = `onEdit`). There is no read-only GRN details widget, and nothing calls `GET /warehouse-receiving/{id}` or
   `GET /{id}/inspection-protocol`. Inland bookings have no list and no View at all. Report and GIT rows only have "copy".
5. **The GRN card and dialogs show internal data.** The card never shows the import file. The inspection dialog shows
   `IMP-FILE-<database id>` (`warehouse_inspection_dialog.dart:230`). Status and discrepancy type appear as raw English DB labels,
   although `DomainEnums` already maps them (`domain_enum_labels.dart:806-815,901-915`).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F08-01 | BLOCKER | `warehouse_receiving/services/warehouse_received_report_export_service.dart:56-69` | The report invents `importFileCode: 'IMP-${r.importFileId}'` (a DB id shown as a business code), `poNumber: 'PO-MAIN-${id}'`, `containerInfo: '1 × 40ft HQ (...)'`, and `samplesQty: 0`. These values go into the table, the KPIs and the PDF/CSV exports. | Resolve the file code from `importFilesProvider` (`importFileCode`/`primaryNameWithCode`), take the PO from the line (`po_number`, see backend dep B1) or show `—`, show the truck plate only, and drop the samples column and KPI (no backend field). |
| F08-02 | CRITICAL | `inland_transport/widgets/inland_transport_dialog.dart:16-21,285-322,657-688` | Status constants do not match the backend (`'In Transit (Gate-Out)'`/`'Arrived Warehouse'` vs `'In Transit'`/`'Arrived at Warehouse'`, `validators.py:10-14`). After gate-out no arrival button is shown, so the truck can never be marked arrived from the UI. `Dispatched` (allowed for gate-out) shows no action. The header falls back to file codes `BOOKED`/`IN_TRANSIT`/`ARRIVED` (`service.py:81,203,238`), which are not mapped either. | Map with `DomainEnums.legacyToCode(DomainEnumType.inlandTransportStatus, status)` and switch on codes (BOOKING_CONFIRMED/DISPATCHED → gate-out; IN_TRANSIT → arrival; ARRIVED_AT_WAREHOUSE/DELIVERED → done). Add the legacy keys `BOOKED`→BOOKING_CONFIRMED and `ARRIVED`→ARRIVED_AT_WAREHOUSE to `domain_enum_labels.dart:816`. Use `DomainEnums.label` for the text. |
| F08-03 | CRITICAL | `inland_transport/widgets/inland_transport_dialog.dart:626-632,188-240`; `inland_transport_provider.dart` (no update method) | "Edit / Rebook" only shows the create form, and the submit POSTs a **new** booking. With the same waybill the user gets a 409. With a changed waybill a second booking is created and the file's inland fields are overwritten. There is no way to correct a typo in a booking. | Add `updateBooking(id, payload)` (PUT `/inland-transport/bookings/{id}`). In edit mode prefill and PUT only the changed fields. Keep a separate "Add another truck" action for a real second booking. |
| F08-04 | CRITICAL | `warehouse_receiving/screens/goods_in_transit_screen.dart:37-51` | "Book inland transport" picks `files.firstWhere(f.inlandTransportStatus != 'Arrived Warehouse' && f.isActive, orElse: files.first)`. The file status is stored as `ARRIVED`, so the test is always true, and the dialog opens for whichever file is first in the list. A booking can be made on the wrong shipment. | Open a small picker first (`SearchableDropdownField<int>` of active files that are not ARRIVED, labelled `primaryNameWithCode`), then call `InlandTransportDialog.show` with the picked file. |
| F08-05 | MAJOR | `warehouse_receiving/screens/warehouse_receiving_screen.dart:697-698`; `grn_record_card.dart:147-156` | The View action calls `_showAddEditDialog(r)`, the same editable form as Edit. There is no read-only GRN details view. | New `GrnDetailsDialog` (read-only), see section 4 and FE08-T05. |
| F08-06 | MAJOR | `grn_record_card.dart:109-145,172-203` | The card never shows which import file the GRN belongs to. The response has only `import_file_id`. | Resolve `importFileCode`/`primaryNameWithCode` from `importFilesProvider` (already loaded on mount, `warehouse_receiving_screen.dart:49-51`) and show it as a copyable chip. Backend dep B2 adds `import_file_code` to the response. |
| F08-07 | MAJOR | `grn_record_card.dart:18-31,196-201`; `warehouse_receiving_screen.dart:176-358,415-434` | Status and discrepancy type appear as raw English DB labels (`Inspection Passed / Clean Receipt`, `Shortage & Damaged`, `Under Bond Quarantine`) in the card, copy, Excel, PDF and print. `GrnStatusView` knows only 4 of 8 statuses. | Use `DomainEnums.label(l10n, DomainEnumType.warehouseReceivingStatus, r.status)` and `...grnDiscrepancyType...`. Map severity by code. |
| F08-08 | MAJOR | `warehouse_receiving_screen.dart:479-482,577-582` | The status filter offers only All/Draft/Goods Received/Discrepancy. Quarantine, Inspection Passed, Under Bond and GRN Audited cannot be filtered. The "Received" KPI counts only `Goods Received`/`Closed`, so clean inspected GRNs are missed. | Build the filter items from `DomainEnums.codesOf(warehouseReceivingStatus)` and send the English legacy label (`DomainEnums.englishLabel`) as `status`. KPIs compare codes. |
| F08-09 | MAJOR | `warehouse_receiving/widgets/warehouse_receiving_form_dialog.dart:222-234`; `modules/warehouse_receiving/schemas.py:189-206` | Edit sends `import_file_id` and `seal_number`, which `WarehouseReceivingUpdate` does not have, so they are silently dropped. The file picker stays enabled in edit mode (`:331-343`), so the user "changes" the file and nothing happens. | In edit mode: file picker read-only, and send only the Update fields. Backend dep B3 adds `seal_number`, `driver_phone`, `arrival_datetime` to the Update schema. |
| F08-10 | MAJOR | `warehouse_receiving_form_dialog.dart:222-230` | The arrival date/time (BP-033) and driver phone are never captured. The server stamps `now`, so a GRN typed the next day records the wrong arrival time, which also drives the demurrage gate-out. | Add a date-time picker (default now, user can change) and a driver phone field. Send `arrival_datetime` (ISO with offset) and `driver_phone`. |
| F08-11 | MAJOR | `warehouse_receiving_form_dialog.dart:400-419` | The "Send dispatch alert to warehouse" button only flips local state and shows a green success SnackBar. Nothing is sent. | Remove the button and the banner action (or wire it to a real notification endpoint later, Q2). |
| F08-12 | MAJOR | `warehouse_receiving_form_dialog.dart:357,362-372` | A broken seal needs a seal number on the server (`validators.py:44-50`), but the form has no validator, so the user gets a 400 after submit. | Seal number validator: required when `_sealIntact == false`. |
| F08-13 | MAJOR | `warehouse_receiving/models/warehouse_receiving_model.dart:267-307` | The model ignores `is_under_bond_quarantine`, `quarantine_lock_active`, `dispatch_blocked`, `created_by` and `updated_by` (`schemas.py:230-232,248-250`). The LOG-BOND-003 customs lock is invisible on the card, and the audit trail cannot be shown. | Parse the 5 fields. The card shows a "Customs bond lock / dispatch blocked" chip. Details view shows created/updated by and at. |
| F08-14 | MAJOR | `warehouse_inspection_dialog.dart:422-431,530-536`; backend `service.py:473-476` | The quarantine switch can be turned on while the verdict is ACCEPTED_WITH_DISCREPANCY (or the record has `quarantine_lock_active`). The server then returns 400 `WR_VERDICT_INCONSISTENT`. | When quarantine is on (switch or lock) force the verdict to REJECTED_QUARANTINED and disable the other items. Turning the verdict away from REJECTED turns the switch off. |
| F08-15 | MAJOR | `warehouse_inspection_dialog.dart:42-63,163,230`; `warehouse_receiving_screen.dart:703` | The screen opens the dialog without `importFileCode`, so the subtitle shows `IMP-FILE-<database id>` and the Excel export is named with the GRN code instead of the file code (Task I naming rule). | Pass the resolved file code from the screen. Fallback is `—`, never the DB id. |
| F08-16 | MAJOR | `warehouse_inspection_dialog.dart:182,541-572` | `inspection_date` is always "now", and the claim refs are optional even when a claim is filed (the discrepancy dialog requires its ref). | Date picker (default now). Validators: insurance ref required when the insurance claim is checked, supplier ref required when the supplier claim is checked. |
| F08-17 | MAJOR | `warehouse_receiving_screen.dart:415-434`; `grn_record_card.dart:147-156` | "Print GRN" copies plain text to the clipboard. There is no GRN document (BP-034) and no discrepancy & insurance claim report (BP-035, `docs/phase_08_warehouse_receiving.md` "Receiving Discrepancy & Insurance Claim Report"). | A `GrnPdfService` with 2 documents (GRN, discrepancy/claim report) saved through `FileSaveHelper.exportAndSaveFile(stageName: 'Goods Receipt Note' / 'Receiving Discrepancy Report', importFileNameOrCode: <file code>)`. |
| F08-18 | MAJOR | `warehouse_received_report_screen.dart:51,62-70`; `comprehensive_report/screens/import_file_comprehensive_report_screen.dart:77,115`; `warehouse_receiving_provider.dart:49-58` | The report tab, the GRN tab and the comprehensive report share one `warehouseReceivingProvider`, which remembers the last filters. Typing a search or picking a status in the GRN tab changes the report's rows and KPIs. Opening the comprehensive report for one file narrows the GRN registry in the hub to that file. | Give the report its own unfiltered read (`warehouseReceivingReportProvider`, `FutureProvider.autoDispose`), and use a `FutureProvider.family<int>` (by file) for the comprehensive report. The registry provider stays filter-aware. |
| F08-19 | MAJOR | `received_report_table.dart:197-205` | The receipt status column is hard-coded "Approved & Received" for every row. | Show `DomainEnums.label(...warehouseReceivingStatus, item.status)` with the severity mapping from F08-07. |
| F08-20 | MAJOR | `received_report_table.dart:38-60`; `git_ledger_table.dart:27-47`; `warehouse_received_report_screen.dart:123-237` | Large-table problem: a `DataTable` with every GRN line, inside a horizontal scroll inside a vertical `SingleChildScrollView`. Every row is built at once, there is no sticky header, no sort, no page, no row count, and the client search rebuilds the whole table on each keystroke. | See section 3 (FE08-T11, FE08-T12). |
| F08-21 | MAJOR | `warehouse_receiving_screen.dart:691-711`; `modules/warehouse_receiving/repository.py:58` | The GRN registry loads every record (no paging on the server), shows ~2 cards per screen, has no sort and no visible record count. | See section 3. |
| F08-22 | MAJOR | `warehouse_received_report_export_service.dart:203-232` | The TSV/CSV files are named `Warehouse_Received_Detailed_Report_<millis>` (Task I wants `[Stage Name] - [Import File Code].[ext]`). The CSV dialog also offers the `xlsx` extension, which saves CSV text under an `.xlsx` name that Excel refuses to open. The same pattern is in `goods_in_transit_export_service.dart:120,138`. | Names `Warehouse Received Report - <file code or "All Files">.csv`. Allowed extensions `['csv']`. For a real Excel file use `TableExportService.exportTableToExcel` (as the GRN registry does at `warehouse_receiving_screen.dart:308`). |
| F08-23 | MAJOR | `goods_in_transit_provider.dart:12-45`; `goods_in_transit_screen.dart` | Still open from FE-16: the GIT ledger is in memory only, starts empty, and `addReconciledShipment` has no caller in the app. The tab always shows "no data" plus 5 export buttons and 5 zero KPIs. `_invalidateRelated` (`warehouse_receiving_provider.dart:39`) also resets it. | CTO decision Q1: hide the tab until there is a backend source, or build `GET /warehouse-receiving/goods-in-transit` (lines of POs on files that are released but have no active GRN). |
| F08-24 | MAJOR | `inland_transport_dialog.dart:88-92,894-896` | Planned departure and expected arrival times are `final` 10:00 and 16:00. Only the date can be picked, so the stored times are made up. | Add time pickers (`showTimePicker`) and keep the fields non-final. |
| F08-25 | MAJOR | `inland_transport_dialog.dart:110,116,788-863`; `schemas.py:9,17-18` | Carrier, pickup location and destination warehouse are free text. `carrier_id` exists on the API but is never sent (CORE_RULES: master data as FK, `SearchableDropdownField` for Partner/Port). | Carrier: `SearchableDropdownField<int>` over `partnersProvider` (transport partners), sending `carrier_id` + `carrier_name`. Pickup: dropdown over `transport_locations_provider`. Destination: free text until a warehouse master exists (Q3). |
| F08-26 | MAJOR | `inland_transport_dialog.dart:242-283`; `schemas.py:50-59` | The arrival step does not capture the seal check (`seal_intact`, `seal_number`), which is the BP-033 "Seal Intact vs Broken" step, and gate-out does not capture `gate_pass_no`. | Arrival panel: seal-intact switch + seal number (required when broken). Gate-out panel: gate pass no. |
| F08-27 | MAJOR | `inland_transport_provider.dart:44-53`; `inland_transport_dialog.dart:150` | One file can have several trucks (backend allows different waybills), but the dialog shows only the one booking from `by-file`. The other trucks cannot be seen, gated out or marked arrived. | List all bookings of the file (`fetchBookings(importFileId:)`) as rows, each with its own gate-out/arrival actions. |
| F08-28 | MINOR | `warehouse_received_report_screen.dart:64-65`; `goods_in_transit_screen.dart:70-71` | Still open from FE-11: the error views print the raw exception (`whReportErrorFetchingData(err)`, `gitErrorFetchingData(err)`). | `ApiErrorText.of(l, err)`. |
| F08-29 | MINOR | `warehouse_receiving_screen.dart:568-570` | Server search fires on every keystroke (no debounce). | 350 ms debounce `Timer`. |
| F08-30 | MINOR | `warehouse_receiving_screen.dart:648,740` | Refresh calls `fetchRecords()` with no args, which drops the active search/status while the toolbar still shows them. | Pass `search: _searchController.text, status: _selectedStatusFilter`. |
| F08-31 | MINOR | `warehouse_receiving_provider.dart:140-144` | `restoreRecord` exists, but there is no "show deleted" toggle and no restore action, so a soft-deleted GRN cannot be brought back from the UI. | "Show deleted" switch (`includeInactive: true`) + Restore action on inactive cards. |
| F08-32 | MINOR | `warehouse_receiving_screen.dart:390-393` | "Confirm final receipt" (legacy Draft rows only) overwrites `discrepancy_notes` with the text "Goods Received", which loses the stored notes. | Send only `status`. |
| F08-33 | MINOR | `search_and_clone_warehouse_receiving_dialog.dart:70,167` | Search matches `imp-<database id>`, and the fallback label is `IMP-<id>`. | Match and show the resolved `importFileCode`. |
| F08-34 | MINOR | `warehouse_receiving_model.dart:232,260,273,301`; `inland_transport_model.dart` (`destinationWarehouse` default) | Model fallbacks invent `'Main Warehouse - Cairo'` and `'Kamal'` when the JSON value is null. | Fall back to `''` and render `—`. |
| F08-35 | MINOR | `import_files/widgets/import_file_details_dialog.dart:946-962` (outside this feature) | The "Warehouse Receiving (TR-03)" button pushes the unfiltered registry, and uses `ElevatedButton` + `Color(0xFF27AE60)` + an `isAr ? ... : ...` literal. | Push `InboundWarehouseHubScreen(initialSubTab: 1, initialImportFileId: file.importFileId)` and filter the registry by that file. `AppButton` (success) + l10n key. |

---

## 3. Large tables

Common fact: no list endpoint in this phase pages on the server. `GET /warehouse-receiving` returns `.all()`
(`modules/warehouse_receiving/repository.py:36-58`), and `GET /inland-transport/bookings` does the same. The only paged
endpoint in the codebase is `GET /import-files/paginated` (`modules/import_files/router.py:92-133`, envelope with
`page`, `page_size`, `total`). Shared widgets already exist: `core/widgets/compact_table_pagination_footer.dart`
and `core/widgets/enterprise_data_table/` (used by `smart_tasks_screen.dart`).

| List screen | Today (evidence) | Recommended |
|---|---|---|
| GRN registry (hub tab 1) | `SliverList` + `SliverChildBuilderDelegate` (lazy build, OK) of `GrnRecordCard`s about 260 px high (`warehouse_receiving_screen.dart:691-711`, `grn_record_card.dart:74-106`), so about 2 cards are visible at 1366×768. Server search and status (`:568-588`), no debounce, no sort, record count only as the "Total" KPI, which is computed on the loaded list (`:479-515`). Excel/PDF export the loaded list, which is the full filtered set only because there is no paging (`:271-358`). | **Phase A (FE only, FE08-T11):** debounce, a "N records" chip, a sort selector (arrival date / GRN code / status), and a "compact table" toggle that renders the same records as rows (`EnterpriseDataTable` with GRN code, file code, warehouse, status, arrival, invoiced/accepted/shortage/damaged, actions column with View/Edit/Inspection/Delete). Cards stay as the default "detail" mode. **Phase B (backend B4, FE08-T12):** `GET /warehouse-receiving/paginated?page&page_size&status&search&import_file_id&sort` with the import-files envelope, a paged notifier (`page`, `pageSize=50`, `total`), and `CompactTablePaginationFooter` under the list. KPIs come from a `summary` block in the response (counts per status for the whole filter, not the page). Exports call the unpaged endpoint with the same filters to get the **full** filtered set. |
| Received shipments report (hub tab 2) | Flattens every line of every GRN on the client (`warehouse_received_report_export_service.dart:47-75`). `DataTable` with 12 columns inside `SingleChildScrollView(horizontal)` inside `SingleChildScrollView(vertical)` (`received_report_table.dart:38-60`, `warehouse_received_report_screen.dart:123`), so all rows are built at once. No sticky header (skill section 10.a), no sticky actions column (10.b), no sort, no paging, no count. Client search on every keystroke. KPIs over the filtered set. 1,000 GRNs × 20 lines = 20,000 `DataRow`s, which freezes the UI. | **Phase A (FE08-T11):** replace with `EnterpriseDataTable` (paged on the client, 50 rows a page, sticky header, column resize, sort) or a `ListView.builder` table with a pinned header row; debounce the search; show "N lines / M GRNs". **Phase B (backend B5):** `GET /warehouse-receiving/lines?page&page_size&search&status&date_from&date_to` returns flattened lines with `import_file_code`, `po_number`, `grn_code`, `status`. KPIs come from the response `totals`. Export fetches all pages (or `?export=true`). Add a date-range filter, because a receiving report without a period is not usable at scale. |
| Goods-in-transit ledger (hub tab 0) | Same `DataTable` pattern (`git_ledger_table.dart:27-47`), client filters (`goods_in_transit_screen.dart:76-89`). In practice always empty (F08-23). | Decide Q1 first. If kept: the same component and paging as the report. |
| Inland bookings | No list screen at all. The provider loads **all** bookings at creation (`inland_transport_provider.dart:20-42`) and nothing renders them. | FE08-T14: an "Inland bookings" tab in the hub with server filters (status, file, search), the same table component, View/Edit/Gate-out/Arrival actions. Stop the eager `fetchBookings()` in the constructor. |
| Inspection dialog line table | `DataTable` in a 140 px box (`warehouse_inspection_dialog.dart:337-383`). Fine for normal GRNs (< 50 lines). | Leave as is. In the details view (FE08-T05) use a lazy list when lines > 50. |
| Search & clone dialog | `ListView.separated` (lazy) over the loaded records, client filter (`search_and_clone_warehouse_receiving_dialog.dart:52-79,162`). | OK for now. After Phase B it must query the server (`search=`) instead of the loaded page. |

---

## 4. View/Show action

| Entity | View exists? | Why not (code reason) | What to add |
|---|---|---|---|
| GRN (Goods Receipt Note) | **Icon only.** `RowActionsPill.onView` is wired to `_showAddEditDialog(r)` (`warehouse_receiving_screen.dart:697`), the same as Edit (`:698`). | There is no read-only widget for a GRN, and the provider has no `fetchById` (`warehouse_receiving_provider.dart` has list/create/update/report/inspection/delete/restore only), although `GET /warehouse-receiving/{id}` (`router.py:64-70`) and `GET /{id}/inspection-protocol` (`router.py:99-105`, returns `is_ready_for_landed_cost`, rate, claims) exist. The edit form was reused as the view. | `GrnDetailsDialog` (read-only, FE08-T05): header (GRN code, file code, warehouse, status chip, seal chip, bond lock chip), truck/driver/arrival, a line table, totals and discrepancy rate, an inspection block (protocol no., date, committee, verdict, root cause) from `GET /{id}/inspection-protocol`, claims, audit (created/updated by and at), and footer actions: Print GRN PDF, Edit (when permitted), Close. A new provider method `fetchInspectionSummary(id)`. |
| Inspection protocol | No. The only entry is the certify dialog, which always submits. | A read mode was never built. A certified protocol is reopened in the edit form and can be re-submitted. | Show the protocol inside `GrnDetailsDialog`. In the card, change the button label to "View protocol" when `inspectionProtocolNumber != null`, opening the details dialog scrolled to the inspection section. "Re-inspect" stays a separate action. |
| Inland transport booking | Partly. The per-file dialog shows a read-only card of **one** booking (`inland_transport_dialog.dart:600-660`). There is no list, so a booking cannot be found or viewed except by opening the right import file first. | There is no list screen or registry tab, `fetchBookings()` results are never rendered, and `by-file` returns one booking. | FE08-T14: a registry tab + a row View that opens the same dialog in read-only mode for that booking (all fields, status timeline: booked → gate-out → arrived, tracking notes). |
| Received report row | No. The only row action is "copy row summary" (`received_report_table.dart:208-214`). | The report is built from flattened lines with no link back to the GRN id. | Add `receivingId` to `WarehouseReceivedReportItem` and an "Open GRN" icon that opens `GrnDetailsDialog`. |
| GIT ledger row | No (copy only, `git_ledger_table.dart:60-66`). | No data source (F08-23). | After Q1: "Open file" (import file details) and "Book inland" for that row's file. |

---

## 5. Tasks

Order = priority. Every task is standalone. Paths are relative to the repo root. Run `flutter test` for the touched folder,
`flutter analyze` on the touched files, and do a manual check in Arabic (RTL) and English.

### FE08-T01: Received report must not invent file code, PO, container, samples or status
- **Severity:** BLOCKER
- **Type:** bug
- **Depends on:** none (better with backend B1/B2, but works without them)
- **Backend needed:** no (optional B1: `po_number` per GRN line; B2: `import_file_code` on the GRN response)
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/services/warehouse_received_report_export_service.dart`
  - `frontend/lib/features/warehouse_receiving/widgets/received_report_table.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_received_report_screen.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart` (only if a key is missing)
- **Steps:**
  1. Change `WarehouseReceivedReportItem.fromReceivingRecords(records)` to `fromReceivingRecords(records, {required Map<int, String> fileCodeById})`. Set `importFileCode = fileCodeById[r.importFileId] ?? ''` (never `IMP-<id>`).
  2. Set `poNumber` from the GRN line JSON key `po_number` when present (add `poNumber` to `GrnItemModel.fromJson` as optional `String?` in `frontend/lib/features/warehouse_receiving/models/warehouse_receiving_model.dart`, default `''`); otherwise `''`, rendered as `—`.
  3. Replace `containerInfo` with the truck plate only (`r.truckPlateNumber ?? ''`); rename the column label to the existing truck label (`warehouseReceivingTruckPlateLabel`).
  4. Remove `samplesQty` from the item, the table column, the KPI strip (`warehouse_received_report_screen.dart:86,165-171`), the TSV/CSV/PDF columns and `toRowSummary`.
  5. Add `receivingId` and keep `status` (raw). In `received_report_table.dart:197-205` show `DomainEnums.label(l, DomainEnumType.warehouseReceivingStatus, item.status)` with severity: INSPECTION_PASSED/GOODS_RECEIVED/CLOSED/GRN_AUDITED = success, DISCREPANCY_REPORTED = warning, UNDER_QUARANTINE_INSPECTION/UNDER_BOND_QUARANTINE = danger, PENDING_COUNT = info. Use the same label in exports.
  6. In the screen build `fileCodeById` from `ref.watch(importFilesProvider).valueOrNull` (`importFileId → importFileCode`).
- **Acceptance criteria:**
  - [ ] No row, KPI or exported file shows `IMP-<number>`, `PO-MAIN-`, `40ft HQ` or a samples column.
  - [ ] A GRN under quarantine shows a red "Under Quarantine Inspection" chip (Arabic label in Arabic UI), not "Approved & Received".
  - [ ] Unknown PO shows `—`.
- **Tests to add:** `frontend/test/features/warehouse_receiving/received_report_item_test.dart`: build 2 records (one with `po_number` on a line, one without) and assert `importFileCode` comes from the map, `poNumber` is `'PO-77'` / `''`, no field contains `IMP-` or `PO-MAIN`, and `status` is passed through.
- **Out of scope:** paging (FE08-T11/T12), GIT tab.

### FE08-T02: Fix inland transport status mapping (arrival button never shows)
- **Severity:** CRITICAL
- **Type:** bug
- **Depends on:** none
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/inland_transport/widgets/inland_transport_dialog.dart`
  - `frontend/lib/core/localization/domain_enum_labels.dart`
  - `frontend/test/tr01_inland_transport_coordination_test.dart`
  - new `frontend/test/features/inland_transport/inland_status_test.dart`
- **Steps:**
  1. In `domain_enum_labels.dart` (legacy map, line ~816) set `DomainEnumType.inlandTransportStatus: {'BOOKED': 'BOOKING_CONFIRMED', 'ARRIVED': 'ARRIVED_AT_WAREHOUSE', 'In Transit (Gate-Out)': 'IN_TRANSIT', 'Arrived Warehouse': 'ARRIVED_AT_WAREHOUSE', 'Not Booked': null}`. Skip the null entry if the map type does not allow it.
  2. Replace the `InlandStatus` string constants with a helper `static String? codeOf(String? raw) => DomainEnums.legacyToCode(DomainEnumType.inlandTransportStatus, raw);`.
  3. `_statusSeverity`, `_getStatusColor` and `_statusLabel` switch on the code: BOOKING_CONFIRMED/DISPATCHED = warning/orange, IN_TRANSIT = info/cobalt, ARRIVED_AT_WAREHOUSE/DELIVERED = success/emerald, null = "Not booked". The label text comes from `DomainEnums.label(l10n, DomainEnumType.inlandTransportStatus, raw, fallback: l10n.inlandStatusNotBooked)`.
  4. In `_buildExistingBookingCard` show gate-out when code is BOOKING_CONFIRMED or DISPATCHED, arrival when IN_TRANSIT, the done banner when ARRIVED_AT_WAREHOUSE or DELIVERED.
  5. Update the fixture in `tr01_inland_transport_coordination_test.dart:58,83` to the real backend label `'Arrived at Warehouse'`.
- **Acceptance criteria:**
  - [ ] Book → Gate-out → the "Confirm warehouse arrival" panel appears → Arrival → the green "arrived" banner shows.
  - [ ] A booking in `Dispatched` shows the gate-out button.
  - [ ] Header and KPI show the localized status (Arabic in Arabic UI) for booking statuses and for the file codes BOOKED/IN_TRANSIT/ARRIVED.
- **Tests to add:** `inland_status_test.dart`: `codeOf('In Transit') == 'IN_TRANSIT'`, `codeOf('Arrived at Warehouse') == 'ARRIVED_AT_WAREHOUSE'`, `codeOf('BOOKED') == 'BOOKING_CONFIRMED'`, `codeOf('ARRIVED') == 'ARRIVED_AT_WAREHOUSE'`, `codeOf('Not Booked') == null`. A widget test that pumps the dialog with a fake provider returning status `'In Transit'` and finds `Key('inlandWarehouseArrivalBtn')`.
- **Out of scope:** edit booking (T03), multi-truck (T14).

### FE08-T03: "Edit booking" must update, not create a new booking
- **Severity:** CRITICAL
- **Type:** bug
- **Depends on:** FE08-T02
- **Backend needed:** no (PUT `/api/v1/inland-transport/bookings/{id}` exists, `router.py:72-80`)
- **Files to change:**
  - `frontend/lib/features/inland_transport/providers/inland_transport_provider.dart`
  - `frontend/lib/features/inland_transport/widgets/inland_transport_dialog.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart` (keys `inlandEditBookingBtn`, `inlandSaveChangesBtn`, `inlandUpdatedSnack`)
  - `frontend/test/features/inland_transport/inland_transport_provider_test.dart`
- **Steps:**
  1. Add `Future<InlandTransportModel> updateBooking(int transportId, Map<String, dynamic> payload)` that PUTs, invalidates `importFilesProvider` and `smartTasksProvider`, and returns the parsed model.
  2. In the dialog add `_isEditing` (true when the user taps "Edit booking" on an existing booking). Rename the toggle button label to `inlandEditBookingBtn`.
  3. When editing, prefill all controllers from `_existingBooking` (already done in `_loadBookingData`), plus the planned and expected dates from `plannedDepartureAt` / `expectedArrivalAt`.
  4. `_submitBooking`: if `_isEditing`, build a payload with only the fields that differ from `_existingBooking`, call `updateBooking`, show `inlandUpdatedSnack`, reload. Otherwise keep the create path.
  5. Hide the edit button when the booking code is ARRIVED_AT_WAREHOUSE or DELIVERED.
- **Acceptance criteria:**
  - [ ] Correcting the driver phone on a booking keeps the same transport code, and no second booking appears.
  - [ ] Network trace shows `PUT /inland-transport/bookings/{id}`, not `POST`.
  - [ ] An arrived booking cannot be edited.
- **Tests to add:** provider test: `updateBooking` sends PUT to the right path with only the given keys (mock Dio adapter), and rethrows on 400.
- **Out of scope:** adding a second truck (T14).

### FE08-T04: "Book inland transport" in the GIT tab must ask which file
- **Severity:** CRITICAL
- **Type:** bug
- **Depends on:** none
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/screens/goods_in_transit_screen.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart` (key `wrPickFileForBookingTitle`)
  - new `frontend/test/features/warehouse_receiving/goods_in_transit_book_inland_test.dart`
- **Steps:**
  1. Replace `_bookInland` with: candidates = active files whose `inlandTransportStatus` is not `ARRIVED` (compare case-insensitively against `ARRIVED` and `Arrived at Warehouse`).
  2. Show an `AlertDialog` with a `SearchableDropdownField<int>` (label `primaryNameWithCode`) and OK/Cancel `AppButton`s. OK stays disabled until a file is picked.
  3. Call `InlandTransportDialog.show(context, pickedFile)`. If there are no candidates, show the existing `wrNoFilesForBooking` SnackBar.
- **Acceptance criteria:**
  - [ ] Clicking "Book inland" never opens a booking dialog without the user choosing the file.
  - [ ] Files already arrived are not in the list.
- **Tests to add:** widget test with 3 files (one ARRIVED): tap `Key('inlandTransportScreenBtn')`, expect a picker with 2 items, and expect no `InlandTransportDialog` before a pick.
- **Out of scope:** GIT data source (T15).

### FE08-T05: Read-only GRN details view ("Show")
- **Severity:** MAJOR
- **Type:** feature
- **Depends on:** FE08-T06 (file code + status labels), FE08-T07 (model fields)
- **Backend needed:** no (`GET /api/v1/warehouse-receiving/{id}` and `GET /{id}/inspection-protocol` exist)
- **Files to change:**
  - new `frontend/lib/features/warehouse_receiving/widgets/grn_details_dialog.dart`
  - `frontend/lib/features/warehouse_receiving/providers/warehouse_receiving_provider.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
  - new `frontend/test/features/warehouse_receiving/grn_details_dialog_test.dart`
- **Steps:**
  1. Provider: add `Future<WarehouseReceivingModel> fetchById(int id)` (GET `/warehouse-receiving/{id}`) and `Future<Map<String, dynamic>> fetchInspectionSummary(int id)` (GET `/{id}/inspection-protocol`). Neither changes the list state.
  2. `GrnDetailsDialog(receivingId, fileCode)`: on open, load both (live load, `OpsLoadingView` while loading, `ApiErrorText` + retry on error). No `TextFormField`s; use `OpsLabeledValue` / `CopyableText`.
  3. Sections: header chips (GRN code, file code, warehouse, status, seal, bond lock); truck/driver/arrival; line table (code, name, invoiced, accepted, shortage, damaged, using a lazy `ListView.builder` when > 50 lines); totals + `discrepancy_rate_percent`; inspection (protocol no., date, committee, verdict label via `DomainEnums`, root cause, `is_ready_for_landed_cost`); claims; audit (created_by, created_at, updated_by, updated_at).
  4. Footer: Close (secondary), Edit (opens the form and closes this dialog), Print GRN (wired in FE08-T09; hidden until then).
  5. Screen: `onView: () => GrnDetailsDialog.show(context, r.receivingId, fileCode)`. Edit stays on `onEdit`.
- **Acceptance criteria:**
  - [ ] The eye icon opens a dialog with no editable field and the same data as the card + lines + inspection.
  - [ ] A GRN with no inspection shows "Not inspected yet" instead of an empty block.
  - [ ] Works in RTL (numbers and codes stay LTR).
- **Tests to add:** widget test with a mocked Dio: the dialog shows the GRN code, the file code, 2 line rows and the verdict label, and `find.byType(TextFormField)` finds nothing.
- **Out of scope:** PDF (T09), inline editing.

### FE08-T06: GRN card and registry: file code, localized status/discrepancy, full status filter, correct KPIs
- **Severity:** MAJOR
- **Type:** ux
- **Depends on:** none
- **Backend needed:** no (optional B2 `import_file_code`)
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/widgets/grn_record_card.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - `frontend/lib/features/warehouse_receiving/widgets/warehouse_inspection_dialog.dart` (only the `importFileCode` fallback, line 230)
  - `frontend/lib/features/warehouse_receiving/widgets/search_and_clone_warehouse_receiving_dialog.dart` (lines 70, 167)
  - new `frontend/test/features/warehouse_receiving/grn_status_view_test.dart`
- **Steps:**
  1. `GrnStatusView.of`: compute `code = DomainEnums.legacyToCode(DomainEnumType.warehouseReceivingStatus, status)`, label = `DomainEnums.label(...)`, severity by code (same mapping as FE08-T01 step 5). `isDraftStatus` → `code == 'PENDING_COUNT'`.
  2. Card: add a `fileCode` parameter and show it as a copyable chip after the GRN code. Discrepancy value = `DomainEnums.label(l, DomainEnumType.grnDiscrepancyType, r.discrepancyType)`; "no discrepancy" check by code `NONE`.
  3. Screen: build `fileCodeById` from `importFilesProvider` and pass it to the card, the inspection dialog (`importFileCode:`) and the copy/Excel/PDF rows (add a "File" column). Use localized status/discrepancy in all exports.
  4. Status filter items: `'All'` + one item per code in `DomainEnums.codesOf(DomainEnumType.warehouseReceivingStatus)`, value = `DomainEnums.englishLabel(type, code)` (the stored legacy label), label = localized. Note: PENDING_COUNT's stored label is `Draft / Pending Warehouse Count` and INSPECTION_PASSED's is `Inspection Passed / Clean Receipt`; use the legacy map for these two.
  5. KPIs: received = codes GOODS_RECEIVED, INSPECTION_PASSED, GRN_AUDITED, CLOSED; discrepancy = DISCREPANCY_REPORTED or discrepancy code != NONE; add a "Quarantine" KPI = UNDER_QUARANTINE_INSPECTION + UNDER_BOND_QUARANTINE.
  6. Inspection dialog and clone dialog: never build `IMP-FILE-<id>` / `IMP-<id>`; fall back to `—` and search on the resolved code.
- **Acceptance criteria:**
  - [ ] Every card shows its import file code.
  - [ ] In Arabic UI no status or discrepancy value is shown in English.
  - [ ] Filtering by "Under Quarantine Inspection" returns those GRNs.
  - [ ] No screen in this feature shows a database id.
- **Tests to add:** `grn_status_view_test.dart`: each of the 8 legacy labels maps to a non-raw localized label and the expected severity; an unknown label returns itself with info severity.
- **Out of scope:** paging, new table mode (T11).

### FE08-T07: GRN form contract fixes (edit fields, arrival time, seal validator, fake alert, bond-lock fields)
- **Severity:** MAJOR
- **Type:** bug
- **Depends on:** backend B3 for editing seal number / arrival (the create part works today)
- **Backend needed:** yes for edit: add `seal_number`, `driver_phone`, `arrival_datetime` to `WarehouseReceivingUpdate` (`modules/warehouse_receiving/schemas.py:189`)
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/widgets/warehouse_receiving_form_dialog.dart`
  - `frontend/lib/features/warehouse_receiving/models/warehouse_receiving_model.dart`
  - `frontend/lib/features/warehouse_receiving/widgets/grn_record_card.dart` (bond-lock chip only)
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
  - `frontend/test/features/warehouse_receiving/warehouse_receiving_form_test.dart`
- **Steps:**
  1. Model: parse `is_under_bond_quarantine`, `quarantine_lock_active`, `dispatch_blocked` (bool, default false), `created_by`, `updated_by` (String, default ''). Change the null fallbacks `'Main Warehouse - Cairo'` and `'Kamal'` to `''`.
  2. Card: when `quarantineLockActive || dispatchBlocked`, show a danger chip "Customs bond lock: dispatch blocked" (new l10n key).
  3. Form, edit mode: render the file as a read-only field (no dropdown), and do not send `import_file_id`. Send only Update-schema keys: `warehouse_name`, `truck_plate_number`, `driver_name`, `seal_intact`, `grn_items`, plus `seal_number`, `driver_phone`, `arrival_datetime` once B3 is merged.
  4. Form, create mode: add a driver phone field and an arrival date + time picker (default `DateTime.now()`), and send `arrival_datetime: dt.toUtc().toIso8601String()`.
  5. Seal number validator: required when the seal-intact switch is off (new key `wrSealNumberRequiredWhenBroken`).
  6. Remove the "send dispatch alert" button from `_buildDispatchBanner` (keep the info banner text, or remove the banner if it only explains the button), and remove `_alertSentToWarehouse`.
- **Acceptance criteria:**
  - [ ] In edit mode the file cannot be changed.
  - [ ] Creating with seal "broken" and no seal number shows a red field error, and no request is sent.
  - [ ] The saved GRN shows the arrival time the user picked.
  - [ ] No button shows a success message without a server call.
  - [ ] A GRN created on an under-bond file shows the lock chip.
- **Tests to add:** in `warehouse_receiving_form_test.dart`: (a) broken seal without number blocks submit; (b) the edit payload has no `import_file_id`; (c) the create payload has `arrival_datetime` and `driver_phone`. Model test: the 3 lock flags parse from JSON.
- **Out of scope:** inspection dialog changes (T08).

### FE08-T08: Inspection dialog: quarantine/verdict consistency, date, required claim refs, file code
- **Severity:** MAJOR
- **Type:** bug
- **Depends on:** FE08-T07 (model field `quarantineLockActive`)
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/widgets/warehouse_inspection_dialog.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
  - new `frontend/test/features/warehouse_receiving/inspection_verdict_test.dart`
- **Steps:**
  1. Add `bool get _quarantineForced => _quarantineAssigned || widget.record.quarantineLockActive;`. When true, set `_selectedVerdict = REJECTED_QUARANTINED` and offer only that item. Show a helper text (new key) explaining why.
  2. Picking a verdict other than REJECTED sets `_quarantineAssigned = false`; picking REJECTED sets it to true (already done). Disable the quarantine switch when `quarantineLockActive`.
  3. Extend `InspectionVerdict.initial` with `required bool quarantine` so it returns REJECTED_QUARANTINED when quarantine is true.
  4. Add an inspection date picker (default now) and send `inspection_date` as UTC ISO.
  5. Validators: insurance ref required when `_insuranceClaimFiled`; supplier ref required when `_supplierClaimFiled`.
  6. Excel export: `importFileNameOrCode: widget.importFileCode ?? ''`. Subtitle fallback `—`.
- **Acceptance criteria:**
  - [ ] Turning quarantine on can never lead to a 400 `WR_VERDICT_INCONSISTENT`.
  - [ ] Filing an insurance claim without a reference shows a field error.
  - [ ] The exported file is named `Warehouse Inspection Protocol - <file code>.xlsx`.
- **Tests to add:** `inspection_verdict_test.dart`: `initial(saved: 'ACCEPTED_WITH_DISCREPANCY', shortage: 2, damaged: 0, quarantine: true) == 'REJECTED_QUARANTINED'`; `isFullAcceptanceAllowed` unchanged. A widget test: toggle the quarantine switch and expect the verdict field to show the "Rejected / quarantined" label.
- **Out of scope:** editing line quantities inside the inspection dialog (Q4).

### FE08-T09: GRN and discrepancy/claim PDF documents (replace "print = copy text")
- **Severity:** MAJOR
- **Type:** feature
- **Depends on:** FE08-T06
- **Backend needed:** no
- **Files to change:**
  - new `frontend/lib/features/warehouse_receiving/services/grn_pdf_service.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - `frontend/lib/features/warehouse_receiving/widgets/grn_record_card.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
  - new `frontend/test/features/warehouse_receiving/grn_pdf_service_test.dart`
- **Steps:**
  1. `GrnPdfService.buildGrnPdf(record, fileCode, l10n) -> Future<Uint8List>`: header (GRN code, file code, warehouse, arrival, truck/driver, seal), line table, totals, signature boxes (storekeeper, inspector). Use the same font loading and RTL handling as `warehouse_received_report_export_service.dart` (PDF part).
  2. `buildDiscrepancyReportPdf(record, inspectionSummary, fileCode, l10n)`: lines with shortage/damage only, rate, root cause, quarantine, insurance/supplier claim refs and amount, committee.
  3. Save both with `FileSaveHelper.exportAndSaveFile(context:, bytes:, stageName: 'Goods Receipt Note' | 'Receiving Discrepancy Report', importFileNameOrCode: fileCode, extension: 'pdf')`.
  4. `_printGrn` calls the GRN PDF. The card gets a "Discrepancy report (PDF)" button, visible when shortage + damaged > 0 or the discrepancy code is not NONE.
- **Acceptance criteria:**
  - [ ] "Print" opens a Save As dialog with the name `Goods Receipt Note - <file code>.pdf`.
  - [ ] The PDF shows Arabic text correctly (RTL) and codes LTR.
  - [ ] The discrepancy report is offered only for GRNs with a discrepancy.
- **Tests to add:** `grn_pdf_service_test.dart`: `buildGrnPdf` returns non-empty bytes starting with `%PDF` for a record with 2 lines (no file save in the test).
- **Out of scope:** e-signature, email.

### FE08-T10: Stop the report and comprehensive report from sharing the GRN tab's filtered state
- **Severity:** MAJOR
- **Type:** bug
- **Depends on:** none
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/providers/warehouse_receiving_provider.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_received_report_screen.dart`
  - `frontend/lib/features/comprehensive_report/screens/import_file_comprehensive_report_screen.dart`
  - new `frontend/test/features/warehouse_receiving/warehouse_receiving_providers_test.dart`
- **Steps:**
  1. Add `final warehouseReceivingAllProvider = FutureProvider.autoDispose<List<WarehouseReceivingModel>>(...)` (GET with `include_inactive=false`, no filters) and `final warehouseReceivingByFileProvider = FutureProvider.autoDispose.family<List<WarehouseReceivingModel>, int>(...)` (GET with `import_file_id`).
  2. In `WarehouseReceivingNotifier._invalidateRelated` also invalidate these two.
  3. The report screen watches `warehouseReceivingAllProvider` and refreshes it with `ref.invalidate` (initState and refresh button). Error view uses `ApiErrorText.of(l, err)` (closes F08-28 for this screen).
  4. The comprehensive report watches `warehouseReceivingByFileProvider(fileId)` and no longer calls `warehouseReceivingProvider.notifier.fetchRecords(importFileId:)` (lines 77 and 115).
- **Acceptance criteria:**
  - [ ] Typing a search in the GRN tab does not change the report tab totals.
  - [ ] Opening the comprehensive report for a file does not narrow the GRN registry.
  - [ ] After creating a GRN, the report shows it on the next view (invalidated).
- **Tests to add:** provider test with a `ProviderContainer` and a mocked Dio: calling `fetchRecords(search: 'x')` on the registry does not change what `warehouseReceivingAllProvider` returns; the family provider sends `import_file_id`.
- **Out of scope:** server paging (T12).

### FE08-T11: Large tables, phase A (frontend only)
- **Severity:** MAJOR
- **Type:** ux
- **Depends on:** FE08-T01, FE08-T06, FE08-T10
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/widgets/received_report_table.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_received_report_screen.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - new `frontend/lib/features/warehouse_receiving/widgets/grn_registry_table.dart`
  - new `frontend/test/features/warehouse_receiving/received_report_table_test.dart`
- **Steps:**
  1. Report: replace the `DataTable` with `EnterpriseDataTable<WarehouseReceivedReportItem>` (`frontend/lib/core/widgets/enterprise_data_table/enterprise_data_table.dart`), `initialPageSize: 50`, `storageKey: 'wh_received_report'`, columns as today (after FE08-T01), a pinned actions column with "Open GRN" (opens `GrnDetailsDialog` from FE08-T05 when merged; until then copy row). Remove the outer vertical `SingleChildScrollView` so the table owns its scroll (skill section 10.c). Header must stay visible while scrolling.
  2. Report: 300 ms debounce on the search; show "N lines · M GRNs" above the table.
  3. GRN registry: 350 ms debounce on the server search (closes F08-29); refresh keeps filters (closes F08-30); a sort selector (arrival date desc default, GRN code, status) applied client-side; a "N records" chip.
  4. GRN registry: a toggle "Cards / Table". Table mode = `GrnRegistryTable` (an `EnterpriseDataTable` with GRN code, file code, warehouse, status chip, arrival, invoiced/accepted/shortage/damaged, actions View/Edit/Inspection/Delete). Remember the choice with the table's own preference (not tokens; UI preference only).
- **Acceptance criteria:**
  - [ ] With 5,000 report lines (test data) the tab opens without a visible freeze, shows 50 rows and a page bar, and the header stays fixed while scrolling.
  - [ ] Sorting by arrival date works in both modes.
  - [ ] The record count is visible without scrolling.
- **Tests to add:** `received_report_table_test.dart`: pump with 120 items; expect 50 data rows on page 1 and a pagination bar; after a search that matches 3 items, expect 3 rows.
- **Out of scope:** server paging (T12).

### FE08-T12: Large tables, phase B (server paging for GRN registry and report lines)
- **Severity:** MAJOR
- **Type:** feature
- **Depends on:** FE08-T11, backend B4 + B5
- **Backend needed:** yes. B4: `GET /api/v1/warehouse-receiving/paginated?page&page_size&status&search&import_file_id&sort` returning `{items, total, page, page_size, summary:{by_status:{...}}}` (same envelope as `GET /import-files/paginated`). B5: `GET /api/v1/warehouse-receiving/lines?page&page_size&search&status&date_from&date_to` returning flattened lines with `receiving_id, grn_code, import_file_code, po_number, item_code, item_name, invoiced_qty, accepted_qty, shortage_qty, damaged_qty, status, warehouse_name, arrival_datetime` and `totals`.
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/providers/warehouse_receiving_provider.dart`
  - new `frontend/lib/features/warehouse_receiving/providers/warehouse_received_lines_provider.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_received_report_screen.dart`
  - `frontend/test/features/warehouse_receiving/warehouse_receiving_providers_test.dart`
- **Steps:**
  1. Registry notifier: keep `page`, `pageSize` (50), `total`, `summary`; `fetchRecords` calls `/paginated`. Put `CompactTablePaginationFooter` (`frontend/lib/core/widgets/compact_table_pagination_footer.dart`) under the list. Any filter change resets to page 1.
  2. KPIs read `summary.by_status` (whole filter, not the page).
  3. Excel/PDF/TSV exports call the unpaged list endpoint (`GET /warehouse-receiving` with the same filters) so they export the **full filtered set**, and show a progress SnackBar.
  4. Report: a lines provider with server paging, search, status and a date range picker (default: current month). KPIs from `totals`. Exports fetch all pages.
  5. Search & clone dialog: query `/paginated?search=` instead of filtering the loaded page.
- **Acceptance criteria:**
  - [ ] Only 50 GRNs travel per request; the footer shows the total.
  - [ ] Export of a filtered registry contains all matching rows, not only the visible page.
  - [ ] The report KPIs match the date range, not the visible page.
- **Tests to add:** provider test: page 2 request sends `page=2&page_size=50` and keeps the filters; export path calls the unpaged endpoint.
- **Out of scope:** backend implementation itself (backend-developer).

### FE08-T13: Inland booking form: real master data, editable times, seal check at arrival, gate pass
- **Severity:** MAJOR
- **Type:** feature
- **Depends on:** FE08-T02, FE08-T03
- **Backend needed:** no (`carrier_id`, `seal_intact`, `seal_number`, `gate_pass_no` already exist in `modules/inland_transport/schemas.py`)
- **Files to change:**
  - `frontend/lib/features/inland_transport/widgets/inland_transport_dialog.dart`
  - `frontend/lib/features/inland_transport/models/inland_transport_model.dart` (default `destinationWarehouse` → `''`)
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
  - new `frontend/test/features/inland_transport/inland_booking_form_test.dart`
- **Steps:**
  1. Carrier: `SearchableDropdownField<int>` over `partnersProvider` (filter to transport/trucking partners if the model has a type; otherwise all active partners). Send `carrier_id` and `carrier_name`. Keep a legacy booking's free-text name displayed when `carrierId == null`.
  2. Pickup location: `SearchableDropdownField<String>` over `transport_locations_provider` items, with the file's port of discharge preselected when it matches.
  3. Make `_plannedDepartureTime` / `_expectedArrivalTime` non-final and add a time picker next to each date picker.
  4. Gate-out panel: optional `gate_pass_no` field, sent when not empty.
  5. Arrival panel: seal-intact switch (default on) + seal number field (required when off). Send `seal_intact` and `seal_number`.
- **Acceptance criteria:**
  - [ ] The carrier can only be picked from master data; the saved booking has `carrier_id`.
  - [ ] The planned departure time saved is the time the user chose, not 10:00.
  - [ ] Marking arrival with a broken seal requires the seal number.
- **Tests to add:** `inland_booking_form_test.dart`: `inlandEventPayload`-style helper for arrival includes `seal_intact:false` and `seal_number`; the create payload contains `carrier_id` and the chosen hour.
- **Out of scope:** a warehouse master table (Q3).

### FE08-T14: Inland bookings registry + several trucks per file + View
- **Severity:** MAJOR
- **Type:** feature
- **Depends on:** FE08-T02, FE08-T03, FE08-T11 (table component)
- **Backend needed:** no for the first version (`GET /inland-transport/bookings` with `status`, `import_file_id`, `search`); paging later (backend B6)
- **Files to change:**
  - new `frontend/lib/features/inland_transport/screens/inland_bookings_tab.dart`
  - `frontend/lib/features/warehouse_receiving/screens/inbound_warehouse_hub_screen.dart`
  - `frontend/lib/features/inland_transport/providers/inland_transport_provider.dart`
  - `frontend/lib/features/inland_transport/widgets/inland_transport_dialog.dart`
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
- **Steps:**
  1. Provider: remove the eager `fetchBookings()` from the constructor; add `fetchBookings({importFileId, status, search})` with filter memory (same pattern as `warehouse_receiving_provider.dart:30-58`).
  2. New hub tab (index 3) "Inland transport": toolbar (search, status filter from `DomainEnums.codesOf(inlandTransportStatus)`, refresh, Excel export via `TableExportService`), `EnterpriseDataTable` with transport code, file code, waybill, carrier, plate, driver, status chip, planned/actual dates, fare; actions View / Edit / Delete (soft, with confirm).
  3. View opens `InlandTransportDialog` in a read-only mode for that booking id (new optional `bookingId` + `readOnly` params). Edit opens it in edit mode (FE08-T03).
  4. In the per-file dialog, list every active booking of the file (`fetchBookings(importFileId:)`) as compact rows, each with its own gate-out/arrival actions; add an "Add another truck" button that opens the create form with an empty waybill.
- **Acceptance criteria:**
  - [ ] A user can find a booking by waybill or plate without knowing the file.
  - [ ] A file with 2 trucks shows both, and each can be gated out and marked arrived.
  - [ ] Delete asks for confirmation and the row disappears (soft delete).
- **Tests to add:** widget test for the tab with 3 bookings (mocked provider): 3 rows, the status filter narrows to 1, the View action opens a dialog without input fields.
- **Out of scope:** server paging for bookings (B6).

### FE08-T15: Goods-in-transit tab: hide until it has a data source (or wire the backend)
- **Severity:** MAJOR
- **Type:** ux
- **Depends on:** CTO answer Q1
- **Backend needed:** only for option B: `GET /api/v1/warehouse-receiving/goods-in-transit` (PO lines of files released from customs that have no active GRN)
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/screens/inbound_warehouse_hub_screen.dart`
  - `frontend/lib/features/warehouse_receiving/providers/goods_in_transit_provider.dart`
  - `frontend/lib/features/warehouse_receiving/screens/goods_in_transit_screen.dart`
  - `frontend/lib/core/providers/navigation_provider.dart` (index 63 routing)
- **Steps (option A, default):**
  1. Remove tab 0 from the hub (`tabs` and `IndexedStack`), shift the indexes, and route sidebar index 63 to the GRN tab with a SnackBar-free fallback.
  2. Delete the `confirmWarehouseReceipt` calls (`warehouse_receiving_screen.dart:395`, `warehouse_receiving_form_dialog.dart:237-239`) and the `goodsInTransitProvider` invalidation in `warehouse_receiving_provider.dart:39`.
  3. Keep the files on disk only if T04's "Book inland" button moves to the GRN tab toolbar; otherwise delete the GIT screen, provider, model, table and export service in one commit.
- **Steps (option B):** a `FutureProvider` over the new endpoint, error view via `ApiErrorText`, file names per Task I.
- **Acceptance criteria:**
  - [ ] No visible tab shows an always-empty ledger with export buttons.
- **Tests to add:** hub widget test: the tab count matches the chosen option.
- **Out of scope:** the backend endpoint itself.

### FE08-T16: Export hygiene (file names, CSV extension, raw errors)
- **Severity:** MAJOR
- **Type:** refactor
- **Depends on:** none
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/services/warehouse_received_report_export_service.dart`
  - `frontend/lib/features/warehouse_receiving/services/goods_in_transit_export_service.dart` (skip if T15 option A deletes it)
  - `frontend/lib/features/warehouse_receiving/screens/goods_in_transit_screen.dart` (error view only)
- **Steps:**
  1. TSV/CSV default names: `'Warehouse Received Report - All Files.csv'` / `.tsv` (or the single file code when the list has one file). Same for GIT: `'Goods In Transit Ledger - All Files.csv'`.
  2. `allowedExtensions: ['csv']` for CSV (remove `'xlsx'`), `['tsv']` for TSV.
  3. Rename the "Excel" button to "CSV" (l10n) or switch it to `TableExportService.exportTableToExcel` for a real .xlsx.
  4. Error view: `ApiErrorText.of(l, err)` instead of `gitErrorFetchingData(err)`.
- **Acceptance criteria:**
  - [ ] No export file name contains a timestamp or underscores-only generic name.
  - [ ] A file saved from the "Excel" button opens in Excel without a format warning.
- **Tests to add:** unit test on a pure helper `reportFileName(List<item>)` returning the expected names for 0, 1 and 2 files.
- **Out of scope:** PDF layout.

### FE08-T17: Small fixes (restore deleted GRN, confirm-receipt notes, import file entry point)
- **Severity:** MINOR
- **Type:** bug
- **Depends on:** FE08-T06
- **Backend needed:** no
- **Files to change:**
  - `frontend/lib/features/warehouse_receiving/screens/warehouse_receiving_screen.dart`
  - `frontend/lib/features/warehouse_receiving/widgets/grn_record_card.dart`
  - `frontend/lib/features/import_files/widgets/import_file_details_dialog.dart` (lines 946-962 only)
  - `frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`
- **Steps:**
  1. Toolbar switch "Show deleted" → `fetchRecords(includeInactive: true, ...)`. Inactive cards are greyed and show only View + Restore (`restoreRecord`, confirm dialog, `ApiErrorText` on 409).
  2. `_confirmFinalReceipt`: send only `{'status': 'Goods Received'}` (do not overwrite `discrepancy_notes`).
  3. Import file details: replace the `ElevatedButton` + `Color(0xFF27AE60)` + `isAr` literal with `AppButton(variant: success, label: l10n.<new key>)` that pushes `InboundWarehouseHubScreen(initialSubTab: 1, initialImportFileId: file.importFileId)`, and make the GRN tab apply `importFileId` as a filter when given (add an optional `initialImportFileId` to `WarehouseReceivingScreen`).
- **Acceptance criteria:**
  - [ ] A deleted GRN can be restored from the UI.
  - [ ] Confirming a legacy draft keeps its discrepancy notes.
  - [ ] Opening receiving from an import file shows only that file's GRN.
- **Tests to add:** widget test: with `initialImportFileId: 5` the provider is called with `importFileId: 5`.
- **Out of scope:** permission-based hiding of actions.

---

## 6. Backend dependencies (short)

- **B1** `GrnItemSchema` (`modules/warehouse_receiving/schemas.py:138`): add optional `po_number: Optional[str] = None` (stored in the JSON column, no migration). The form already knows the PO per line (`warehouse_receiving_form_dialog.dart:23,188`) but cannot send it.
- **B2** `WarehouseReceivingResponse`: add `import_file_code: Optional[str]` (join or property) so the frontend does not depend on the import-files list being loaded.
- **B3** `WarehouseReceivingUpdate`: add `seal_number`, `driver_phone`, `arrival_datetime` (with the seal validator applied on the merged values).
- **B4** `GET /warehouse-receiving/paginated` with the import-files envelope + `summary.by_status`; search also on warehouse name and file code.
- **B5** `GET /warehouse-receiving/lines` (flattened, paged, date range, totals).
- **B6** `GET /inland-transport/bookings/paginated` (later).
- Note: `PUT /warehouse-receiving/{id}` with new `grn_items` recomputes totals but not `discrepancy_type`/`status` (`service.py:326-331`). Editing lines after an inspection can leave a "clean" status with shortages. Backend should recompute or block line edits after inspection.
- Note: `WarehouseReceivingCreate.warehouse_name` and `InlandTransportBookingBase.destination_warehouse` still default to `"Main Warehouse - Cairo"` (invented value).

## 7. Open questions for the CTO

- **Q1** Goods-in-transit tab: hide it now (option A) or build a backend source (option B)? [A]
- **Q2** The "dispatch alert to warehouse" in the GRN form: drop it, or should it create a real notification/task for the warehouse team? [drop]
- **Q3** Warehouses are free text everywhere (GRN `warehouse_name`, booking `destination_warehouse`). Do we add a warehouse master (MD) with a dropdown? [yes, next wave]
- **Q4** Should the inspection dialog allow entering the counted quantities per line (BP-034 physical count), or stay "verdict only" with counts entered in the GRN form? [stay; counts in the GRN form]
- **Q5** Large tables: what volume should we design for (GRNs per year, lines per GRN)? Default assumption: up to 5,000 GRNs/year, up to 200 lines each, so server paging (T12) is required, not optional.
- **Q6** Should the received report default to the current month (date range) once it is server-paged? [yes]
