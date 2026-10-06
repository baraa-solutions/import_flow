# Phase 10 File closure: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited).
Scope: BP-040 (closure gate, closure record, certificate, reopen), CLO-03 (comprehensive dossier export, which is a
blocking pillar of the gate) and CLO-04 (official close). The Odoo journal export described in `docs/phase_10_file_closure.md`
lives in `features/financial_settlement/screens/odoo_journal_entry_dialog.dart` and is **out of scope** here (Phase 09 review).

Where the screens live:

| Screen / dialog | Entry | File |
|---|---|---|
| File Closure & Archival registry (Type A stage screen, "PHASE-6: STEP_21") | `home_screen.dart:147` (sidebar index of `FileClosureScreen`) | `frontend/lib/features/file_closure/screens/file_closure_screen.dart` |
| Closure form (draft / certify) | toolbar "New certificate", vertical tab 2, empty state, clone | `frontend/lib/features/file_closure/widgets/file_closure_form_dialog.dart` |
| Official close CLO-04 (6 pillars, certificate export, lesson) | **only** from the import file details dialog (`import_files/widgets/import_file_details_dialog.dart:1087`) | `frontend/lib/features/file_closure/widgets/official_file_closure_dialog.dart` |
| Comprehensive dossier export CLO-03 | import file details dialog `:1069`, comprehensive report screen `:333` (`home_screen.dart:170`) | `frontend/lib/features/comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart` |

Coverage depth:

| file | lines | depth |
|---|---|---|
| `file_closure/models/file_closure_model.dart` | 307 | Full |
| `file_closure/providers/file_closure_provider.dart` | 113 | Full |
| `file_closure/screens/file_closure_screen.dart` | 744 | Full |
| `file_closure/widgets/closure_record_card.dart` | 268 | Full |
| `file_closure/widgets/closed_files_banner.dart` | 107 | Full |
| `file_closure/widgets/file_closure_form_dialog.dart` | 440 | Full |
| `file_closure/widgets/official_file_closure_dialog.dart` | 651 | Full |
| `file_closure/widgets/search_and_clone_file_closure_dialog.dart` | 283 | Full |
| `comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart` | 647 | 60-160 full, rest grep |
| `comprehensive_report/services/comprehensive_dossier_service.dart` | 36 | Full |
| `comprehensive_report/services/comprehensive_report_export_service.dart` | 838 | grep + 244-250, 425-450 |
| `comprehensive_report/screens/import_file_comprehensive_report_screen.dart` | 1,562 | grep only (not audited in depth) |
| `core/widgets/master_data_toolbar.dart` | ~300 | 180-300 full |
| `core/widgets/reopen_shipment_dialog.dart` | ~100 | grep |
| `import_files/providers/import_files_provider.dart` | ~300 | 1-20, 130-215 |
| Backend contract: `modules/file_closure/{router,schemas,model,validators}.py` | 150/225/48/228 | Full |
| Backend contract: `modules/file_closure/service.py` | 991 | 160-375, 915-991 |
| Backend contract: `modules/file_closure/repository.py` | 162 | 37-60 |
| Tests present | `frontend/test/features/file_closure/file_closure_model_test.dart`, `test/clo04_official_file_closure_test.dart`, `test/file_closure_*`, `test/perf/screen_30_file_closure_perf_test.dart`, `test/responsive_and_clone_screen30_test.dart` | names only |

Previous wave (`docs/plans/phase-08-10-quality-plan.md`): verified fixed in current code and **not** re-reported:
FE-07 (missing checklist key = false, `file_closure_model.dart:32-58`), FE-08 (certificate export only after close,
`official_file_closure_dialog.dart:128-130`), FE-09 (lesson dialog opened from the still-mounted dialog, `:229-242`),
FE-11 for the closure dialogs and the delete flow (they use `ApiErrorText.of`), FE-13/FE-14 inside `features/file_closure`
(no Arabic literals, no `Colors.*`, `AppButton` used). FE-11 is **still open** on the screen error state and the reopen
dialog (F10-09). FE-10 is **still open** for the dossier PDF (F10-21). FC-13 (coded precheck messages) is **still open on
the backend** (F10-13).

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 0 |
| CRITICAL | 2 |
| MAJOR | 13 |
| MINOR | 10 |

Most important points:

1. **Closed records show as "Draft".** The screen decides "archived" from the checklist (`isFullyVerified`), not
   from `status`. The server closes a file even when `docs_verified`, `tasks_closed` or `empty_containers_returned` are
   false, because these are warnings only (`validators.py:152-175`). So a real closed file shows a "Draft" badge, is
   counted as a draft in the metrics, and is hidden by the "Closed" filter of the clone dialog (F10-01).
2. **3 of the toolbar buttons fail on every click.** `MasterDataToolbarWidget(moduleEndpoint: 'file-closure')` calls
   `GET /file-closure/export-excel`, `GET /file-closure/export-pdf` and `POST /file-closure/import-excel`. None of these
   routes exist. The two GETs hit `/{closure_id}` and return 422 (F10-02).
3. **No real Edit, no trash/restore, and "Print" only copies to the clipboard.** Edit shows a SnackBar
   (`file_closure_screen.dart:722-726`). The PUT endpoint and `restoreClosure` are never used. A closed record has no
   certificate re-export (F10-03, F10-08, F10-12).
4. **The registry screen and the official-close dialog follow 2 different closure paths.** "Certify" in the form uses
   `POST /file-closure` and gives no certificate. The 6-pillar official dialog (`/official-close`) can only be opened from
   the import file details dialog. Also, the form's checklist leaves out the blocking "dossier exported" pillar, so it
   can show 5/5 green while closing is blocked (F10-06, F10-07).
5. **Large data.** `GET /file-closure` returns all records with no pagination. The screen loads **all** import files
   only to resolve names. The "closed files" banner draws one card per closed file ever, in a non-lazy `Wrap` above the
   list. The cards show the DB id as a fake code `IMP-<id>` (F10-04, F10-05, §3).

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F10-01 | CRITICAL | `file_closure_model.dart:107`, `:23-30`; `closure_record_card.dart:44,128-130`; `file_closure_screen.dart:95,465`; `search_and_clone_file_closure_dialog.dart:53-56,180` | `isFullyVerified = checklist.isAllCompleted && status == 'Closed'`. The server's stored checklist on close is the gate checklist (`service.py:191-193`), and docs/tasks/containers are warnings only (`validators.py:152-175`). So closed files with open operational tasks (common: close completes only closure tasks, `service.py:225-229`) show as **Draft** in the badge, the metrics, the clone filter and the clone summary. | Add `bool get isClosed => status == 'Closed'` and use it for every status display, metric and filter. Keep the checklist only for the condition chips. |
| F10-02 | CRITICAL | `file_closure_screen.dart:641-645`; `core/widgets/master_data_toolbar.dart:253-277`; `modules/file_closure/router.py:58` | The generic master-data toolbar is mounted with `moduleEndpoint: 'file-closure'` and no overrides. Export Excel calls `GET /file-closure/export-excel`, which matches `GET /{closure_id}` and returns 422. Export PDF does the same. Import Excel calls `POST /file-closure/import-excel`, which returns 405. Importing closures from Excel would also bypass the server gate. The screen already has its own Excel/PDF/TSV exports (`:530-549`). | Remove `MasterDataToolbarWidget` from this screen. Keep the screen's own exports and refresh. |
| F10-03 | MAJOR | `file_closure_screen.dart:722-726` | Edit is a stub: it only shows `fileClosureEditSnack`. `PUT /file-closure/{id}` (`router.py:66-73`, Draft: all fields; Closed: only `archival_notes`, `archive_location`, `service.py:314-332`) is never called. A draft cannot be continued from its card. | Draft: open `FileClosureFormDialog(initialRecord: r)`. Closed: open a small dialog with the vault + notes fields that sends `PUT`. Add `updateClosure` to the provider. |
| F10-04 | MAJOR | `file_closure_screen.dart:712` (`'IMP-${r.importFileId}'`), `:97,167,229,282,335,362,404`; `search_and_clone_file_closure_dialog.dart:66,144`; l10n `fileClosureCertFileNo(int id)` (`app_localizations.dart:3562`) | The DB id is shown to the user as a file code (`IMP-17`, `#17`) on the card tag, in the View dialog, in the TSV/Excel/PDF exports and in the clone summary (CORE_RULES §6: never show the DB id). `FileClosureResponse` has no `import_file_code` (`schemas.py:181-197`). | Use `importFilesMap[r.importFileId]?.importFileCode`, else `—`. Change the l10n signature to `fileClosureCertFileNo(String code)`. Backend later: add `import_file_code`, `company_name` and `supplier_name` to the response (§6). |
| F10-05 | MAJOR | `file_closure_screen.dart:595,648,653-668`; `closed_files_banner.dart:48-101`; l10n `closureMetricStoppedFiles` | `closedFiles = importFiles.where(status == 'Closed')` includes **every** closed file: normal closures and early stops (`stop_shipment` also sets `Closed`, `import_files/service.py:484-492`). The banner draws one 220-360 px card per file in a non-lazy `Wrap` above the registry. The metric is labelled "Stopped files" but counts all closed files. With a few years of data the list is pushed off-screen and `build` creates thousands of widgets. | Split into "stopped early" (`closureReason != null`) vs closed normally. Show the banner collapsed, with a count and max 5 items plus "show all", which opens a lazy `ListView.builder` dialog. Fix the metric label/count. |
| F10-06 | MAJOR | `file_closure_form_dialog.dart:228-234,358-362`; `file_closure_screen.dart:100` | The form shows 5 checks (docs, customs, warehouse, landed cost, tasks) and computes progress `x/5`. It leaves out `dossier_exported`, which **blocks** close (`validators.py:146-150`), and `empty_containers_returned`. Docs and tasks are shown as red failures but they are warnings only. Result: the user can see 5/5 green with Certify blocked, or 3/5 red with closing allowed. | Show the 6 server pillars (reuse `ClosurePillars.fromStatus`) with 3 states: passed (green), blocking (red, key in `blocking`), warning (orange). Progress = passed / 6. Clone summary uses the same count. |
| F10-07 | MAJOR | `file_closure_form_dialog.dart:123-184` (POST `/file-closure`, `is_draft:false`); `official_file_closure_dialog.dart:181-227` (`/official-close`) | There are 2 final-close paths. From the registry screen, Certify closes the file but gives no certificate, no export and no lesson prompt. The official dialog that does all of this cannot be opened from Phase 10's own screen. | Certify in the form calls `officialCloseImportFile` and then shows the same closed view (certificate export + lesson). Or simpler: Certify closes the form and opens `OfficialFileClosureDialog.show(file)`, prefilled with auditor/vault/notes. |
| F10-08 | MAJOR | `file_closure_screen.dart:727` (`onPrint: _copySingleCertificateSummary`), `:360-387`; `official_file_closure_dialog.dart:128-179` | The "Print" action of every card only copies text to the clipboard. The certificate file (`FileSaveHelper`, txt) can only be exported in the few seconds after the close, inside the official dialog. A closed file has no way to re-issue its certificate later (doc: "شهادة إغلاق رسمية برقم مرجعي فريد"). | Move the certificate text builder into `file_closure/services/closure_certificate_builder.dart` (input: closure record + import file + optional precheck). Print/Export on a **Closed** card saves it through `FileSaveHelper.exportAndSaveFile` (`stageName: 'Closure Certificate'`, code = import file code). Disable it for drafts. |
| F10-09 | MAJOR | `file_closure_screen.dart:688`; `core/widgets/reopen_shipment_dialog.dart:76` | The load error shows the raw exception (`'${l.fileClosureFetchError} $err'`), and the reopen error SnackBar shows `'$e'`. **Still open from FE-11.** | `ApiErrorText.of(l10n, err)` in both places. |
| F10-10 | MAJOR | `file_closure_screen.dart:80-160` | Clone makes up a code `CLOSURE-DRAFT-<ms>` (`:83`). It is shown in the review dialog but never sent (the server issues `CLR-YYYY-NNNN`). The clone targets the **same** import file (`:138`), so "clone" only re-opens the upsert of that file's own record. On a closed file it gets 409 `FC_ALREADY_CLOSED`. The copied checklist is overwritten by the precheck as soon as the form opens (`file_closure_form_dialog.dart:56-58,73`). | Clone = template: copy only auditor, vault and notes. The form opens with **no file selected**, and the user must pick a different file that is not closed. The suggested code shows "assigned on save" (l10n). Do not copy checklist flags. |
| F10-11 | MAJOR | `file_closure/providers/file_closure_provider.dart:86-90` (unused), `:30` (`include_inactive` always false) | A soft-deleted closure record disappears for good from the UI. `restoreClosure` exists but no screen calls it, and there is no "show deleted" toggle. | Add a "Show deleted" chip that refetches with `includeInactive: true`. Deleted cards show a "Deleted" chip and a Restore action (409 `FC_CLOSURE_EXISTS` shown through `ApiErrorText`). |
| F10-12 | MAJOR | `file_closure_screen.dart:578-580,629,644,690`; `file_closure_provider.dart:68,74,80,92` | Filters are lost. Refresh, delete, restore and close call `fetchClosures()` with no args, so the typed search stays in the box but the list shows everything (**still open from FE-15**). Search sends a request on every keystroke with no debounce. Server search covers only `closure_code` and `auditor_name` (`repository.py:48-53`), not the file code or the company. | The notifier keeps the last `{search, includeInactive, status}` and reuses it on every refetch. Debounce 350 ms. Server search on file code/company comes with the backend item in §6. |
| F10-13 | MAJOR | `file_closure_model.dart:206-211,228-229`; `modules/file_closure/schemas.py:338-352` | The FE renders coded `blocking_messages` / `warning_messages`, but `ClosurePrecheckResponse` does not declare them, so they never arrive. The UI always falls back to the Arabic backend sentences (`validators.py:32-59`), also in English locale. **Backend FC-13 still open.** | Backend dependency only (§6). The FE is ready. Add a widget test once the backend sends them. |
| F10-20 | MAJOR | `comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart:88-92,133-150,160-260,520-647`; `services/comprehensive_dossier_service.dart:21,34` | The CLO-03 dialog has 26 lines with hard-coded Arabic. It uses `Colors.white` for the dialog background and header text (broken in dark mode), shows raw `$e` / `e.toString()` errors, throws Arabic `Exception` texts and uses `DropdownButtonFormField` for the format. "Approve export" can be clicked without exporting any file, so the blocking pillar `dossier_exported` is satisfied by one click. | l10n + `AppTheme.surfaceOf(context)` + `ApiErrorText.of`. Approve stays disabled until one of PDF / Excel / TSV succeeded in this dialog session (set `_exportedFormat` from the saver's non-null path) and sends that format. |
| F10-21 | MAJOR | `comprehensive_report/services/comprehensive_report_export_service.dart:244-445` (`Printing.layoutPdf` at `:441`), called from `import_file_comprehensive_report_screen.dart:176,316` | The dossier PDF goes to `Printing.layoutPdf`, which bypasses `FileSaveHelper` and the naming rule (**still open, same pattern as FE-10**). | Save `await pdf.save()` with `FileSaveHelper.exportAndSaveFile(stageName: 'Comprehensive Dossier', importFileNameOrCode: file.importFileCode, extension: 'pdf')`. Keep print as a second, explicit action if wanted. |
| F10-14 | MINOR | `file_closure_form_dialog.dart:263-269` | The file dropdown lists every import file, closed ones included. Picking a closed file always ends in 409 on save. | Filter `f.status != 'Closed'`. For an already selected `initialRecord` file, keep it in the list. |
| F10-15 | MINOR | `file_closure_screen.dart:187,236,289,342,371,410`; `official_file_closure_dialog.dart:144` | `closed_at` is shown and exported as a raw ISO string. The certificate falls back to `DateTime.now()` when `closedAt` is empty (an invented value). | Format with the app date formatter (`yyyy-MM-dd HH:mm`, local). Show `—` when empty, never "now". |
| F10-16 | MINOR | `file_closure_form_dialog.dart:379` vs `official_file_closure_dialog.dart:589` | The vault/archive location is optional in the form but required in the official dialog. The form sends `''`, which is stored as `''` (the backend default applies only when the key is missing, `schemas.py:170`). | Required validator in both (confirm with Q3). |
| F10-17 | MINOR | `closure_record_card.dart:221-230`; `file_closure_screen.dart:432-462` | Delete is offered on a Closed record of a closed file, and it always gets 409 `FC_CLOSED_RECORD_LOCKED` (`service.py:347-354`). | Hide (or disable with the tooltip "reopen the file first") when `r.isClosed && file?.status == 'Closed'`. |
| F10-18 | MINOR | `file_closure_screen.dart:599-624` | Vertical tab 2 ("Close file") is a button in disguise: `selectedIndex` is fixed at 0 and the tab never shows as selected. | Remove the tab. The primary action is already in the toolbar and the empty state. |
| F10-19 | MINOR | `closure_record_card.dart:127-131`; `modules/import_files/service.py:497-531` | After a reopen, the closure record keeps `status = Closed` (the backend does not update it), so the card still says Closed for an active file. | FE: when `r.isClosed && file != null && file.status != 'Closed'`, show a "Reopened" warning chip. Backend: §6. |
| F10-22 | MINOR | `official_file_closure_dialog.dart:305,168` | The raw English file status (`widget.file.status`) is shown in the header and in the certificate status line. | `DomainEnumLabels.label(l10n, 'file_closure_status' / import file status type, value)`. |
| F10-23 | MINOR | `import_files/providers/import_files_provider.dart:146-160`; `file_closure_screen.dart:46-49`; `file_closure_form_dialog.dart:72` | The screen and the form each call `fetchImportFiles()`, which sets the **shared** provider to `loading` and downloads all files (unpaginated `GET /import-files`). Each open of the closure form makes other screens flicker and resets the dropdown items. | Do not refetch in the form if the provider already has data. Long term, use the backend response fields (F10-04) and a paginated file picker. |
| F10-24 | MINOR | `file_closure_screen.dart:505-586` | The toolbar has 3 buttons, 2 icon buttons and a search, on top of the MasterData toolbar: duplicated exports and more than the "max 3 visible + More ⋮" rule (ui-screen-standards, Type B toolbar). | After F10-02: New certificate, Search & clone, then a More menu (TSV copy). Keep Excel/PDF icons and search. |
| F10-25 | MINOR | `file_closure_screen.dart:301-302,353-354` | Registry exports are named `File Closure & Archival - Registry.xlsx`, with an English hard-coded stage name. | Acceptable for a cross-file registry. Add the date: `importFileNameOrCode: 'Registry ${yyyy-MM-dd}'`. |

## 3. Large tables

| List | Current behaviour | Evidence | Recommended solution |
|---|---|---|---|
| Closure registry (`FileClosureScreen`) | The client loads **all** active closure records in one call. It renders tall cards (about 230-280 px each) in a `SliverList` with a builder (lazy: OK). There is no table, no column view, no sort, no status/date filter and no row count other than the metric. Metrics are computed on the client from the full list. Search is server-side but limited to code + auditor, with no debounce. Exports cover the loaded (searched) set. | `file_closure_provider.dart:30-50` (no page params); `repository.py:37-54` (`.all()`); `file_closure_screen.dart:707-735` (`SliverList` + `SliverChildBuilderDelegate`); `:464-498` (client metrics) | **Phase 1 (FE only, FE10-T12):** keep the cards for <768 px. At ≥1024 px show a compact `DataTable` inside its own vertical + horizontal scroll with a sticky header. Columns: Closure code, Import file code, Company, Status, Conditions x/6, Vault, Auditor, Closed date, Actions (sticky end). Add client paging of 50 rows with `CompactTablePaginationFooter`, a status filter chip (All/Closed/Draft/Deleted) and sorting on code/date. **Phase 2 (needs backend §6 #1):** switch the provider to `GET /file-closure/paginated` (server page, search, status, date range, sort, counts for the metrics). Excel/PDF export of the full filtered set comes from a backend export endpoint or by looping over pages. |
| Closed / stopped files banner | A non-lazy `Wrap` with one card per closed file ever, above the registry | `closed_files_banner.dart:48-101`; `file_closure_screen.dart:595,653` | FE10-T08: split stopped vs closed, collapse, show max 5, "show all" dialog with `ListView.builder` + search. |
| Import files lookup (name/code resolution, form dropdown) | Downloads **all** import files (`GET /import-files`, no paging) on every screen mount and every form open | `import_files_provider.dart:146-180`; `file_closure_screen.dart:46-49,593-594`; `file_closure_form_dialog.dart:72,225` | Backend §6 #2 adds `import_file_code`/company/supplier to the closure response, so the screen no longer needs all files. The form dropdown uses a server-searched picker (`/import-files/paginated?search=&status=`) of non-closed files. |
| Search & clone dialog | Client-side filter over the already loaded records. `ListView.separated` (lazy: OK). | `search_and_clone_file_closure_dialog.dart:52-72,138-141` | Fine at today's size. With Phase 2, query the paginated endpoint with the dialog search (debounced). |

## 4. View/Show action

| Entity | Exists? | Why / what is missing | What to add |
|---|---|---|---|
| Closure record (registry card) | **Partly.** The eye icon in `RowActionsPill` opens `_showCertificate` (`file_closure_screen.dart:389-430`, wired at `:721`). | It is a thin `AlertDialog` built from the list row (no GET-by-id, though `GET /file-closure/{id}` exists, `router.py:58-64`). It shows the **DB id** as the file number (`:404`) and a raw ISO date. It shows no status, no checklist/pillars, no company/supplier, and no `created_by` / `updated_by` audit fields (the schema has them, `schemas.py:192-195`, but the model does not read them, `file_closure_model.dart:109-124`). It has no certificate export. | FE10-T06: `ClosureDetailsDialog` (read-only) that fetches `GET /file-closure/{id}` on open (live load). Sections: header (closure code, status chip, import file **code**, company, supplier), 6 pillar chips, archival (vault, auditor, notes), audit (closed at, created by/at, updated by/at). Actions: Export certificate (Closed only, via `FileSaveHelper`), Copy, Close. Add `createdBy` / `updatedBy` to the model. |
| Closed / stopped import file (banner) | **No.** Only "Reopen". | The banner has no handler for the file itself. | A "View file" action that opens `ImportFileDetailsDialog` for that file (it already exists in `features/import_files/widgets/import_file_details_dialog.dart`). |
| Search & clone list item | **No** (only "Clone to draft"). | The dialog has only `onSelectRecord`. | Optional: an eye icon that opens the same `ClosureDetailsDialog`. Low priority. |
| Comprehensive dossier | **Yes.** The dossier dialog/report screen is itself the read-only view. | Not applicable | None. |

## 5. Tasks

### FE10-T01: A closed record is shown as Closed

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/file_closure/models/file_closure_model.dart`, `frontend/lib/features/file_closure/widgets/closure_record_card.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/search_and_clone_file_closure_dialog.dart`, `frontend/test/features/file_closure/file_closure_model_test.dart`
- **Steps:**
  1. In `ImportFileClosureModel` (model l.107) add `bool get isClosed => status == 'Closed';` and `bool get isDraft => status == 'Draft';`. Mark `isFullyVerified` `@Deprecated('use isClosed for status')`, or remove it after replacing every use.
  2. `closure_record_card.dart:44`: `final archived = r.isClosed;` (the badge at l.127-131 and the accent bar follow).
  3. `file_closure_screen.dart:465`: `archived = records.where((r) => r.isClosed).length`. Draft metric = `records.where((r) => r.isDraft).length` (not `length - archived`). In `:95`, use `isClosed` for the source label.
  4. `search_and_clone_file_closure_dialog.dart:53-56,180-182`: filter on `isClosed` / `isDraft`.
  5. `grep -rn isFullyVerified frontend/lib frontend/test` and replace the rest.
- **Acceptance criteria:**
  - [ ] A record with `status: "Closed"` and `closure_checklist: {"tasks_closed": false, ...}` shows the green Closed badge and counts in "Archived".
  - [ ] A `Draft` record with all checks true still shows "Draft".
  - [ ] The "Closed" filter in Search & clone lists that record.
- **Tests to add:** `frontend/test/features/file_closure/file_closure_model_test.dart`: `isClosed` is true for `status Closed` + `tasks_closed:false`, and false for `Draft` + all true. A widget test pumps `ClosureRecordCard` with that record and finds the Closed label (`AppLocalizationsEn().fileClosureStatusBadgeClosed`).
- **Out of scope:** the checklist chips themselves (T04).

### FE10-T02: Remove the broken master-data toolbar and compact the toolbar

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/test/responsive_and_clone_screen30_test.dart` (update finders if any)
- **Steps:**
  1. Delete the `MasterDataToolbarWidget(...)` block and the `SizedBox` after it (l.641-646). Remove the import (l.13).
  2. In `_buildToolbar` (l.500-586): keep `createClosureBtn`, `searchAndCloneClosureBtn`, Excel and PDF icon buttons and the search. Move `copyClosureTableTsvBtn` into a `PopupMenuButton` ("More", `Icons.more_vert`) whose item calls `_copyArchivedFilesTsv`. Keep the existing keys on the menu item.
  3. Remove the second vertical tab (l.605-609) and the `onTabSelected` handler (l.620-624). Keep a single tab.
  4. Keep the header refresh button (l.626-630).
- **Acceptance criteria:**
  - [ ] The screen has no "Import Excel" button. There is one Excel and one PDF export, and both produce a file through the Save As dialog.
  - [ ] No request to `/file-closure/export-excel`, `/export-pdf` or `/import-excel` is ever sent.
  - [ ] The TSV copy is reachable from the More menu.
- **Tests to add:** `frontend/test/features/file_closure/file_closure_screen_test.dart` (new): pump `FileClosureScreen` with `fileClosureProvider` and `importFilesProvider` overridden by fake notifiers returning 1 record. Assert `find.byType(MasterDataToolbarWidget)` finds nothing, and `find.byKey(Key('exportClosureExcelBtn'))` finds one widget.
- **Out of scope:** table layout (T12).

### FE10-T03: Error texts and status labels

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/core/widgets/reopen_shipment_dialog.dart`, `frontend/lib/features/file_closure/widgets/official_file_closure_dialog.dart`, `frontend/test/features/file_closure/file_closure_screen_test.dart`
- **Steps:**
  1. `file_closure_screen.dart:688`: `message: '${l.fileClosureFetchError} ${ApiErrorText.of(l, err)}'`.
  2. `reopen_shipment_dialog.dart:76`: `l10n.reopenShipmentErrorSnack(ApiErrorText.of(l10n, e))` (import `core/localization/api_error_text.dart`).
  3. `official_file_closure_dialog.dart:305` and `:168`: show the status through `DomainEnumLabels.labelIfKnown(l10n, '<import file status type>', value) ?? value`. Check `core/localization/domain_enum_labels.dart` for the type key used by the import file status. Use `file_closure_status` for `cert.status`.
- **Acceptance criteria:**
  - [ ] When `GET /file-closure` returns 500 with `{"detail":"..."}`, the error view shows the server detail, not `DioException [bad response]...`.
  - [ ] Reopen with an empty reason on the server side shows the backend Arabic detail.
  - [ ] In Arabic locale, the official dialog header shows `مغلق` / the Arabic status, not `Closed`.
- **Tests to add:** in `file_closure_screen_test.dart`, a fake notifier in the error state with a `DioException` whose response data is `{"detail":"boom"}`. Expect `find.textContaining('boom')` and no `DioException` text.
- **Out of scope:** dossier dialog errors (T13).

### FE10-T04: The closure form shows the 6 server pillars with blocking vs warning

- **Severity:** MAJOR | **Type:** bug | **Depends on:** FE10-T01 | **Backend needed:** no (uses `checklist_status`, `blocking_reasons`, `warnings` from `GET /file-closure/closure-precheck/{id}`)
- **Files to change:** `frontend/lib/features/file_closure/widgets/file_closure_form_dialog.dart`, `frontend/lib/features/file_closure/widgets/closure_record_card.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart` (clone summary l.100), l10n files (`frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`), `frontend/test/features/file_closure/file_closure_form_dialog_test.dart` (new)
- **Steps:**
  1. In `file_closure_form_dialog.dart` replace `closureCompletedCount` (l.17-22) with `closurePassedCount(ClosureChecklistModel c)` that counts 6 items: customs, warehouse, landed cost, dossier (`dossierExported == true`), containers (`emptyContainersReturned == true`), docs, tasks. Name the constant `kClosurePillarCount = 7` if docs are kept separate, or follow the official dialog's 6 pillars (customs, warehouse, landed cost, dossier, containers, tasks) plus docs as a seventh row. Pick one and use it everywhere (card l.176-186, clone summary l.100, clone dialog l.146,242).
  2. Each row has 3 states. **Passed** = green check. **Blocking** = red: the item is false and is one of `customs_cleared`, `warehouse_received`, `landed_cost_settled`, `dossier_exported`. **Warning** = orange `Icons.warning_amber`: the item is false and is one of `docs_verified`, `empty_containers_returned`, `tasks_closed`. Put this key set in one const in the model file (`kClosureBlockingKeys`) with a comment pointing to `modules/file_closure/validators.py:106-175`.
  3. Show `_precheck.warningTexts(l10n)` under the blocking texts (orange), the same way as `blockingTexts` (l.363-370).
  4. Progress colour: green when `canClose`, else orange. Do not use "5/5".
  5. Add l10n keys `fileClosureCheck6Dossier`, `fileClosureCheck7Containers` (ar/en).
  6. Filter the file dropdown (l.263): `importFiles.where((f) => f.status != 'Closed' || f.importFileId == widget.initialRecord?.importFileId)` (F10-14).
  7. Vault field (l.379): add the validator `l10n.closureArchiveLocationRequired` (F10-16).
- **Acceptance criteria:**
  - [ ] With a precheck where everything is true except `dossier_exported`, the form shows the dossier row red, the Certify button shows the "cannot close" SnackBar, and progress is not green.
  - [ ] With only `tasks_closed:false`, the tasks row is orange and Certify is allowed.
  - [ ] Closed files are not in the file dropdown.
  - [ ] Saving with an empty vault shows the red required message.
- **Tests to add:** `frontend/test/features/file_closure/file_closure_form_dialog_test.dart`: override `fileClosureProvider` with a fake whose `fetchClosurePrecheck` returns a fixed model. Assert the dossier row has `Icons.cancel` and the tasks row has `Icons.warning_amber`. Assert the dropdown items exclude a `status:'Closed'` file.
- **Out of scope:** the Certify endpoint (T05).

### FE10-T05: One final-close path (Certify gives a certificate)

- **Severity:** MAJOR | **Type:** refactor | **Depends on:** FE10-T04 | **Backend needed:** no (`POST /file-closure/official-close`, schema `FileClosureCreate`, response `OfficialClosureCertificateResponse`, `modules/file_closure/schemas.py:166-172,355-374`)
- **Files to change:** `frontend/lib/features/file_closure/widgets/file_closure_form_dialog.dart`, `frontend/lib/features/file_closure/widgets/official_file_closure_dialog.dart`, `frontend/test/features/file_closure/file_closure_form_dialog_test.dart`
- **Steps:**
  1. Give `OfficialFileClosureDialog` optional constructor params `initialAuditor`, `initialArchiveLocation`, `initialNotes`, used in `initState` (l.89-96) when not null. Add the same params to `show()`.
  2. In `FileClosureFormDialog._submitClosure`, when `isDraft == false`: validate, find `ImportFileModel file` from `importFilesProvider` by `_selectedImportFileId`, `Navigator.pop(context)` the form, then call `OfficialFileClosureDialog.show(rootContext, file: file, initialAuditor: ..., ...)`. Capture `final rootContext = Navigator.of(context, rootNavigator: true).context;` **before** popping. Drafts keep using `closeImportFile` (POST `/file-closure`, `is_draft:true`).
  3. Remove the now-unused final-close branch and its success SnackBar text in the form.
- **Acceptance criteria:**
  - [ ] "Certify & archive" in the registry form opens the official dialog with the same file, auditor, vault and notes. After closing, the certificate export and lesson buttons appear.
  - [ ] Only `POST /file-closure/official-close` is sent for a final close. `POST /file-closure` with `is_draft:false` is never sent from the UI.
  - [ ] The registry list and the import files list refresh after the close (already done by `officialCloseImportFile`, `file_closure_provider.dart:99-112`).
- **Tests to add:** in `file_closure_form_dialog_test.dart`, a fake notifier records calls. Tap `closureFormCertifyBtn` with `canClose:true` and assert `closeImportFile` was **not** called and `find.byType(OfficialFileClosureDialog)` finds one widget.
- **Out of scope:** changing the official dialog layout.

### FE10-T06: Read-only closure details (View) and certificate re-export

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE10-T01 | **Backend needed:** no (`GET /file-closure/{closure_id}`, `router.py:58-64`). Optional later: `import_file_code` in the response (§6 #2)
- **Files to change:** `frontend/lib/features/file_closure/services/closure_certificate_builder.dart` (new), `frontend/lib/features/file_closure/widgets/closure_details_dialog.dart` (new), `frontend/lib/features/file_closure/widgets/official_file_closure_dialog.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/models/file_closure_model.dart`
- **Steps:**
  1. Model: read `created_by` and `updated_by` (`json['created_by'] ?? ''`) into new fields `createdBy`, `updatedBy`.
  2. Provider: add `Future<ImportFileClosureModel> fetchClosure(int id)` → `GET /file-closure/$id`.
  3. Move the text body of `_handleExportCertificate` (official dialog l.128-169) into `ClosureCertificateBuilder.build({required AppLocalizations l10n, required String closureCode, required String closedAt, required String fileCode, required String company, required String supplier, required String auditor, required String location, String? notes, required Map<String,bool> checklist, double? landedCostEgp, double? markup, required String statusLabel})`. The official dialog calls it (same output as today).
  4. `ClosureDetailsDialog(closureId, file)`: on open, call `fetchClosure` (spinner, error with retry via `ApiErrorText`). Show the closure code, a status chip (`isClosed`), the import file **code** (`file?.importFileCode ?? '—'`), company and supplier from `file`, 6 pillar chips (reuse the T04 states), vault, auditor, notes, and the formatted closed/created/updated dates with users. Actions: "Export certificate" (only `isClosed`) → `FileSaveHelper.exportAndSaveFile(context:, bytes: utf8.encode(text), stageName: 'Closure Certificate', importFileNameOrCode: file.importFileCode, extension: 'txt', customDialogTitle: l10n.closureCertSaveTitle)`. Also "Copy" (existing `_copySingleCertificateSummary`) and Close.
  5. Screen: `onView` (l.721) opens `ClosureDetailsDialog`. `onPrint` (l.727) exports the certificate directly for Closed records. For drafts, it shows an orange SnackBar `closureCertDraftNotAvailable` (new l10n key). Delete `_showCertificate`.
  6. Add the formatted date helper used here and in exports (F10-15): `_fmt(String iso)` → `yyyy-MM-dd HH:mm` local, `—` when empty. Remove the `DateTime.now()` fallback in the official dialog (l.144).
- **Acceptance criteria:**
  - [ ] The eye icon opens a read-only dialog with live data from the server, showing the import file code (never `#<id>`) and who created/updated the record.
  - [ ] On a Closed record, "Export certificate" opens Save As with the name `Closure Certificate - <IMPORT FILE CODE>.txt`.
  - [ ] On a Draft record, export is disabled or explains why.
- **Tests to add:** `frontend/test/features/file_closure/closure_details_dialog_test.dart`: a fake Dio adapter (same pattern as `file_closure_model_test.dart:13-45`) answers `GET /file-closure/7`. Assert the code, the "Closed" chip and the file code text are shown, and no text contains `#7`. Unit test `ClosureCertificateBuilder.build` contains the closure code and 6 pillar lines.
- **Out of scope:** PDF certificate with QR (Q1).

### FE10-T07: Business file code everywhere instead of the DB id

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no for the FE part (backend §6 #2 makes it independent of the import files list)
- **Files to change:** `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/search_and_clone_file_closure_dialog.dart`, l10n files (`fileClosureCertFileNo` signature), `frontend/test/file_closure_localization_test.dart`
- **Steps:**
  1. Add a helper in the screen: `String _fileCode(ImportFileClosureModel r, Map<int, ImportFileModel> m) => m[r.importFileId]?.importFileCode ?? '—';`.
  2. Replace `rawCode = 'IMP-${r.importFileId}'` (l.712) with the helper. For the name, when `matchingFile == null`, show `l10n.fileClosureUnknownFile` (new key) instead of resolving `'IMP-<id>'`.
  3. Replace `'#${r.importFileId}'` in l.97, 167, 229, 282, 335, 362 and `fileClosureCertFileNo(r.importFileId)` l.404 (if not already removed by T06). Change the l10n method to `String fileClosureCertFileNo(String code)` in all 3 l10n files.
  4. Clone dialog l.66 and l.144: same helper (search on the real code).
- **Acceptance criteria:**
  - [ ] No screen text, export cell or clipboard text of this feature contains `IMP-<db id>` or `#<db id>`.
  - [ ] When the file is not in the loaded list, `—` is shown.
- **Tests to add:** in `file_closure_screen_test.dart`, a record with `import_file_id: 42` and an import file with code `IMP-2026-0099`. Expect `IMP-2026-0099` and no `IMP-42`.
- **Out of scope:** backend field.

### FE10-T08: Closed-files banner that scales, and a "Reopened" chip

- **Severity:** MAJOR | **Type:** ux | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/file_closure/widgets/closed_files_banner.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/closure_record_card.dart`, l10n files, `frontend/test/features/file_closure/closed_files_banner_test.dart` (new)
- **Steps:**
  1. Screen l.595: `stoppedFiles = importFiles.where((f) => f.status == 'Closed' && (f.closureReason?.isNotEmpty ?? false))`. The banner gets only `stoppedFiles`, and the "Stopped files" metric (l.489-495) counts only them.
  2. Banner: collapsed by default (`ExpansionTile`-like header with count). When expanded, show at most 5 cards. If there are more, show a "Show all (N)" button that opens a dialog with a search field + `ListView.builder` of the same card.
  3. Each banner card gets a second action, "View file", that opens `ImportFileDetailsDialog` for that file (find the existing show method in `features/import_files/widgets/import_file_details_dialog.dart`).
  4. Card: pass `bool fileReopened` (screen: `r.isClosed && matchingFile != null && matchingFile.status != 'Closed'`). When true, show an extra warning `OpsStatusChip(label: l.closureReopenedChip)` (new key).
- **Acceptance criteria:**
  - [ ] With 300 closed files of which 3 were stopped early, the banner says 3 and shows 3 cards. Normally closed files are not offered for "reopen" here.
  - [ ] With 40 stopped files, at most 5 cards render until "Show all" is pressed.
  - [ ] A closure record whose file was reopened shows "Reopened".
- **Tests to add:** `closed_files_banner_test.dart`: pump the banner with 12 files, expand it, and assert 5 reopen buttons, then after tapping "Show all" a `ListView` in a dialog.
- **Out of scope:** backend reopen marking the record (§6 #4).

### FE10-T09: Real Edit for drafts and archival fields

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE10-T01 | **Backend needed:** no (`PUT /file-closure/{id}`, `FileClosureUpdate` `schemas.py:174-179`. Closed record: only `archival_notes`, `archive_location`, else 409 `FC_CLOSED_RECORD_LOCKED`)
- **Files to change:** `frontend/lib/features/file_closure/providers/file_closure_provider.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/closure_archival_edit_dialog.dart` (new), l10n files, `frontend/test/features/file_closure/file_closure_provider_test.dart` (new)
- **Steps:**
  1. Provider: `Future<ImportFileClosureModel> updateClosure(int id, Map<String, dynamic> payload)` → `PUT`, then `_invalidateRelated()` + refetch with the remembered filters (T10).
  2. Screen `onEdit` (l.722-726): if `r.isDraft`, `_showCloseFileDialog(initialRecord: r)` (the form upserts by file). If `r.isClosed`, open `ClosureArchivalEditDialog(record: r)`: a `Form` with Vault (required) and Notes. Save calls `updateClosure(r.closureId, {'archive_location': ..., 'archival_notes': ...})`. Error → `ApiErrorText` SnackBar (crimson). Success → emerald SnackBar and pop.
  3. Delete the `fileClosureEditSnack` usage (keep the key until a cleanup pass).
- **Acceptance criteria:**
  - [ ] Edit on a draft opens the form with its file, auditor, vault and notes, and saving updates the same record (no new code).
  - [ ] Edit on a closed record changes only vault/notes, and the card shows the new values right away.
- **Tests to add:** `file_closure_provider_test.dart` with a fake adapter: `updateClosure` sends `PUT /file-closure/5` with only the 2 keys, and a 409 is rethrown.
- **Out of scope:** changing the checklist of a closed record (forbidden by the server).

### FE10-T10: Keep filters, debounce search, show deleted and restore

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no (`include_inactive=true` on `GET /file-closure`, `PATCH /{id}/restore`)
- **Files to change:** `frontend/lib/features/file_closure/providers/file_closure_provider.dart`, `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/closure_record_card.dart`, l10n files, `frontend/test/features/file_closure/file_closure_provider_test.dart`
- **Steps:**
  1. Notifier: private fields `_search`, `_includeInactive`. `fetchClosures({bool? includeInactive, String? search})` updates the fields only when the arg is not null, then always queries with the stored values. Mutations call `fetchClosures()` and keep the filters.
  2. Screen search: a `Timer? _debounce` of 350 ms in `onChanged` (l.578). Cancel it in `dispose`.
  3. Toolbar: a `FilterChip` "Show deleted" (new key `closureShowDeletedChip`) toggles `includeInactive`.
  4. Card: if `!record.isActive`, show a "Deleted" chip and replace Edit/Delete with a Restore `AppButton` (calls `restoreClosure`, errors through `ApiErrorText`).
  5. Card: hide Delete when `record.isClosed && fileClosed` (new bool param from the screen, F10-17).
- **Acceptance criteria:**
  - [ ] Type a search, then delete a record: the list still shows only matching records.
  - [ ] Typing "CLR-2026" sends 1 request after a pause, not 8.
  - [ ] A deleted draft can be found with "Show deleted" and restored. A conflicting restore shows the server message.
- **Tests to add:** provider test: after `fetchClosures(search: 'X')` then `softDeleteClosure(1)`, the last GET has `search=X`. Widget test: a typing burst triggers one fetch (`tester.pump(Duration(milliseconds: 400))`).
- **Out of scope:** server pagination (T12).

### FE10-T11: Clone as a template for another file

- **Severity:** MAJOR | **Type:** bug | **Depends on:** FE10-T04 | **Backend needed:** no
- **Files to change:** `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/file_closure_form_dialog.dart`, l10n files, `frontend/test/responsive_and_clone_screen30_test.dart`
- **Steps:**
  1. `_onCloneClosure` (l.80-160): `suggestedNewCode: l.closureCodeAssignedOnSave` (new key). Remove `newDraftCode`.
  2. `mandatorilyResetFields` must include "Import file" and "Checklist" (new keys). Set `allowCopyLineItems: false`.
  3. The cloned `ImportFileClosureModel` is replaced by a new form param: `FileClosureFormDialog(templateRecord: source)` which pre-fills only auditor, vault and notes, and leaves `_selectedImportFileId = null`. Add a validator that rejects `source.importFileId` (new key `closureCloneSameFileError`).
- **Acceptance criteria:**
  - [ ] Cloning opens the form with no file selected and with auditor/vault/notes copied.
  - [ ] Choosing the source file shows the red validator message.
  - [ ] No made-up `CLOSURE-DRAFT-…` code appears anywhere.
- **Tests to add:** update `test/responsive_and_clone_screen30_test.dart`: after the clone confirm, the form's file dropdown value is null and `find.textContaining('CLOSURE-DRAFT')` finds nothing.
- **Out of scope:** server-side clone endpoint (none needed).

### FE10-T12: Registry as a compact table with paging (large data)

- **Severity:** MAJOR | **Type:** ux | **Depends on:** FE10-T01, FE10-T07, FE10-T10 | **Backend needed:** phase 1 no. Phase 2 yes: `GET /file-closure/paginated` (§6 #1)
- **Files to change:** `frontend/lib/features/file_closure/screens/file_closure_screen.dart`, `frontend/lib/features/file_closure/widgets/closure_registry_table.dart` (new), `frontend/lib/features/file_closure/providers/file_closure_provider.dart` (phase 2), l10n files, `frontend/test/perf/screen_30_file_closure_perf_test.dart`
- **Steps:**
  1. `ClosureRegistryTable(records, filesMap, callbacks)`: `LayoutBuilder`. Below 1024 px wide, keep the `ClosureRecordCard` list. At ≥1024 px use a `DataTable` (dense, `headingRowColor` = `AppTheme.charcoal.withOpacity(0.06)`) inside a vertical `Scrollbar` + `SingleChildScrollView` and a horizontal one, with a sticky header: header row in a separate non-scrolling `Row` synced by a shared horizontal `ScrollController`, the same pattern as `features/import_files/screens/import_files_screen.dart` (copy the pattern, do not invent a new widget).
  2. Columns and widths: Actions 150 (pinned at the end: `RowActionsPill` view/edit/print/delete), Closure code 140, File code 140, Company 180, Status 100 (chip), Conditions 90 (`x/6`), Vault 160, Auditor 140, Closed at 130.
  3. Client paging: 50 rows per page with `CompactTablePaginationFooter(currentPage, totalPages, totalCount, pageSize, onPageChanged, onPageSizeChanged)`. Sort by tapping Code / Closed at (`sortColumnIndex`, `sortAscending`).
  4. Status filter chips All / Closed / Draft next to the search (client filter in phase 1).
  5. Phase 2 (after backend §6 #1): the provider holds `{items, total, page, pageSize, totalPages, counts}` and calls `/file-closure/paginated` with `page, page_size, search, status, include_inactive, sort`. The footer drives `page`. Metrics use `counts`. Excel/PDF export calls the backend export or loops over pages.
- **Acceptance criteria:**
  - [ ] With 5,000 fake records the screen opens and scrolls without jank (perf test frame budget), and at most 50 rows are built.
  - [ ] The header stays visible while scrolling. The actions column stays visible while scrolling horizontally.
  - [ ] Sorting by Closed at works both ways. The footer shows the total.
- **Tests to add:** extend `frontend/test/perf/screen_30_file_closure_perf_test.dart` with 5,000 records at 1366x768: expect `find.byType(DataRow)`-equivalent count ≤ 50 and no exceptions. Widget test for the status chips.
- **Out of scope:** the backend endpoint itself.

### FE10-T13: Dossier export dialog (CLO-03) cleanup and honest approval

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart`, `frontend/lib/features/comprehensive_report/services/comprehensive_dossier_service.dart`, l10n files, `frontend/test/features/comprehensive_report/dossier_export_dialog_test.dart` (new)
- **Steps:**
  1. Replace the 26 Arabic literals (grep `[ء-ي]` in the file) with l10n keys (`dossierDialog*`). Replace `Colors.white` / `Colors.white70` with `AppTheme.surfaceOf(context)` for the dialog background and `AppTheme.white` on the coloured header.
  2. Errors: `_errorMessage = ApiErrorText.of(context.l10n, e)` (l.88-92). SnackBar l.144: `ApiErrorText.of(l10n, e)`. The service (l.21, 34) throws `StateError('dossier_fetch_failed')` instead of Arabic text, or simply lets Dio throw.
  3. Keep `String? _exportedFormat`. Each export button (l.389-430) awaits the saver and sets `_exportedFormat` when the returned path is not null. The approve button (l.~625) is disabled while `_exportedFormat == null`, with the helper text `dossierExportFirstHint`. The request sends `exportFormat: _exportedFormat`.
  4. The format `DropdownButtonFormField` (l.~589) becomes read-only text showing `_exportedFormat` (it is no longer chosen by hand).
- **Acceptance criteria:**
  - [ ] In English locale no Arabic text is shown by the dialog (except data). In dark mode the dialog is dark.
  - [ ] The approve button is disabled until a PDF, Excel or TSV file was actually saved.
  - [ ] A backend 403 shows the server detail.
- **Tests to add:** `dossier_export_dialog_test.dart`: override `comprehensiveDossierServiceProvider` with a fake. Assert the approve button `onPressed == null` at start. Assert no call to `confirmDossierExport` before an export.
- **Out of scope:** the comprehensive report screen layout (not audited in depth).

### FE10-T14: Dossier PDF through FileSaveHelper

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/comprehensive_report/services/comprehensive_report_export_service.dart`, `frontend/lib/features/comprehensive_report/screens/import_file_comprehensive_report_screen.dart`
- **Steps:**
  1. In `printOrSavePdf` (l.244-445) replace `Printing.layoutPdf(...)` (l.441-444) with `await FileSaveHelper.exportAndSaveFile(context: context, bytes: await pdf.save(), stageName: 'Comprehensive Dossier', importFileNameOrCode: file.importFileCode, extension: 'pdf')`.
  2. If a print preview is still wanted, add a separate "Print" action in the screen (l.176 / l.316) that calls `Printing.layoutPdf` explicitly, labelled as print, not save.
- **Acceptance criteria:**
  - [ ] "Save PDF" on the comprehensive report opens Save As with `Comprehensive Dossier - <IMPORT FILE CODE>.pdf`.
- **Tests to add:** none practical (platform plugin). Add a grep-style unit test in `frontend/test/architecture/no_silent_pdf_save_test.dart` that reads the service source and asserts `Printing.layoutPdf` is not used in `printOrSavePdf`, if the repo already has a similar source-scan test. Otherwise skip.
- **Out of scope:** PDF content.

## 6. Backend dependencies (short)

1. `GET /api/v1/file-closure/paginated` → `{items, total, page, page_size, total_pages, counts: {closed, draft, deleted}}` with `page, page_size, search (closure_code, auditor, import_file_code, company name), status, include_inactive, date_from, date_to, sort` (for FE10-T12 phase 2).
2. `FileClosureResponse`: add `import_file_code`, `company_name` and `supplier_name` (join `ImportFile`; additive). Removes the need to load all import files (F10-04, F10-23).
3. `ClosurePrecheckResponse`: declare `blocking_messages` / `warning_messages: List[SystemMessageItem]` and fill them from the gate (FC-13 still open, `schemas.py:338-352`, `validators.py:32-59`). The FE already renders them.
4. `reopen_shipment_service` (`modules/import_files/service.py:497-531`): mark the active closure record `Reopened` (or keep `Closed` plus `reopened_at` / `reopened_by` / `reason`) and write an audit entry. Also require `import_files.close` (already listed in the previous plan, "Shared needs").
5. Optional: `GET /file-closure/{id}/certificate` (PDF with QR) if Q1 is yes.

## 7. Open questions for the CTO

- **Q1.** The certificate today is a `.txt` file. The doc asks for a reference number, a QR code and the signatures of the auditor and the import manager. Should it be a PDF (FE with `pdf` + `FileSaveHelper`, or a backend endpoint)? Is a QR code with the closure code enough?
- **Q2.** Which screen owns the final close: the Phase 10 registry (after FE10-T05 it opens the official dialog) or only the import file details dialog? Should the registry also start the CLO-03 dossier export when the dossier pillar is red?
- **Q3.** Is the archive location (vault) mandatory for every closure (official dialog: yes, form: no)?
- **Q4.** Should the "closed files" banner list only early-stopped files (FE10-T08 proposal), or be removed in favour of a "Closed / Stopped" status filter in the table?
- **Q5.** Reopen protocol: the doc requires "موافقة إدارية". Today any user with the import file permission can reopen from the banner. Should reopen be limited to `import_files.close` and need a second approval?
- **Q6.** Clone of a closure record: keep it (as a template for auditor/vault/notes, FE10-T11) or remove it? It adds little value for a one-per-file record.
