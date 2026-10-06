# Phase 03 Import Documentation: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited). Scope:
`frontend/lib/features/import_documentation/**` (56 files, ~47,000 lines), the shared table widgets it should use
(`frontend/lib/core/widgets/{enterprise_data_table,compact_table_pagination_footer,row_actions_pill}.dart`), and the
backend contracts in `modules/{import_documentation,original_documents_collection,docs_customs_approval,smart_document_upload}/router.py`
+ `schemas.py`. Baseline: the 03c plan (`docs/plans/phase-03c-flutter-quality-plan.md`, FED-01..26) was implemented in
commit `601f16e`. FED items verified fixed are not repeated. Items still open are marked "still open from FED-xx".

Previous plan check (verified in current code): FED-01, 02, 03, 05, 06, 09, 11, 13, 16, 17 are fixed (grep shows no
`Kamal`, no fixed ACID/company literals in widgets, no `Printing.sharePdf`, no `DropdownButtonFormField`, provider
`_afterMutation` keeps the last query). FED-15 is only partly fixed (see F03-18). The `ElevatedButton`/`OutlinedButton`
sweep is done (0 hits). `Colors.` hits left (209) are almost all `PdfColors.` in `services/*_export_service.dart` (valid).

### Coverage depth

| File | Lines | Depth |
|---|---|---|
| `providers/import_documentation_provider.dart` | 1,089 | Every list fetch + mutation path read (l.36-110, 195-345, 403-460, 979-1089) |
| `providers/original_documents_collection_provider.dart` | 179 | Full |
| `providers/docs_customs_approval_provider.dart` | 340 | Fetch paths read; mutations grep |
| `screens/nafeza_acid_screen.dart` | 3,683 | initState/refresh (115-160), registry tab (1856-2160), expiry tab header (2158-2310), save payloads (2595-2605, 2865-2890, 3015-3045), edit/delete (2912-2990), exports (3487-3680) grep |
| `screens/bank_form4_screen.dart` | 1,387 | initState, request tab header (436-445), registry tab (899-1110), exports grep |
| `screens/customs_declaration46_screen.dart` | 2,102 | initState (150-190), assessment (1116-1260), registry (1262-1500), save (2083-2101) |
| `screens/original_docs_and_cargox_screen.dart` | 156 | Full |
| `screens/shipment_draft_docs_screen.dart` | 345 | Tab routing + refresh (60-130, 300-345) |
| `screens/central_docs_archive_screen.dart` | 1,248 | Structure + provider usage (grep), l.30-60, 126-230 |
| `screens/import_documentation_screen.dart` + 6 thin wrapper screens | ~760 | Full / grep |
| `widgets/original_documents_collection_tab.dart` | 2,495 | Registry (1689-1960), courier registry (2149-2310), init (60-75) |
| `widgets/customs_document_approval_tab.dart` | 1,938 | Refresh (40-85), list (870-1040), approval row (1062-1140) |
| `widgets/draft_bl_review_tab.dart` | 3,307 | Registry stage (2385-2850) |
| `widgets/coo_review_tab.dart` | 2,351 | Registry (1610-1940), duplicate check (690-700) |
| `widgets/inspection_review_tab.dart` | 1,595 | Registry actions (1280-1390), duplicate check (540-550) |
| `widgets/invoice_bl_matcher_tab.dart` | 3,049 | Registry (1995-2430), demo data (75-260, 985-995) |
| `widgets/po_reconciliation_tab.dart` | 4,639 | Registry (2995-3400), duplicate checks (205-225, 1350-1360), demo gate (4170-4185) |
| `widgets/search_and_clone_*_dialog.dart` (8) | ~2,700 | Grep (list widgets) |
| Other widgets/services/models | ~17,000 | Grep sweeps only (colours, literals, `catch (_)`, FileSaveHelper, `isAr ?`) |
| Backend routers (4) + `import_documentation/schemas.py` | ~2,000 | All list/GET routes and their params; ACID/bank/declaration schemas |

Lines read line by line: about 4,800. Grep-swept: 100% of the feature.

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 2 |
| MAJOR | 13 |
| MINOR | 7 |

Most important points:

1. **Form 46 (Customs Declaration) is not saved at all.** The Save button waits 600 ms and shows "saved" (`customs_declaration46_screen.dart:2093`). The backend `POST /import-documentation/customs-declarations` exists and is never called.
2. **The Form 46 "registry" is invented.** It lists *every import file* as a declaration with a made-up number `46-ALX-<file code>`, today's date and the fixed status "Registered on Nafeza" (`:1128`, `:1243-1244`). Nothing in it comes from a stored declaration. The backend has no list endpoint yet.
3. **Large tables: none of the 11 list screens in this phase pages its data.** Every registry downloads the whole global table (with heavy JSON columns), filters in Dart, and builds every row eagerly in a `DataTable` inside `SingleChildScrollView`. There is no sticky header, no sort, and no "x of y" count. The Original Docs registry is also **cut silently at 100 rows**: the backend default `limit=100` applies, the client sends no `limit`/`offset`, and no total comes back. The app already has the right parts: `GET /import-files/paginated` + `PaginatedImportFilesNotifier` + `CompactTablePaginationFooter` + the sticky header in `ImportFilesScreen` (l.1440-1503), and `EnterpriseDataTable` (client paging, sorting, sticky header). This phase uses none of them.
4. **View (عرض) action: 5 of 11 lists have one** (Draft B/L, COO, Inspection, Invoice-B/L, PO-Reconciliation). **ACID, Bank Form 4, Form 46, Original Docs sessions and Couriers have none.** The reason is the same in each: the only row action reuses the *editor* (`_loadSessionForEdit`, `_loadForm4ForEdit`, `_loadInitialFile`), and no read-only details dialog was ever written. The backend already has GET-by-id for ACID and bank docs, so these can be added without backend work.
5. **ACID status is shown wrong.** Only `Issued`/`ISSUED` counts as issued. The backend issued states `Verified`, `Discrepancy_Accepted`, `Generated`, `ACID Issued` show as "Under review" on screen and in the Excel/PDF exports (`nafeza_acid_screen.dart:1988`, `3492`, `3531`, `3570`).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F03-01 | BLOCKER | `screens/customs_declaration46_screen.dart:2083-2101` | `_saveDeclaration46` validates, then `await Future.delayed(600ms)` and shows `customsDeclSaveSuccess`. No API call. The user believes Form 46 was registered. The backend `POST /import-documentation/customs-declarations` (`modules/import_documentation/router.py:309-317`, schema `CustomsDeclarationCreate` = `import_file_id, po_id, acid_number(19 digits), form4_number, bl_number, total_cif_val_egp, total_customs_duties_egp, total_vat_egp`) is never called. | Add `createCustomsDeclaration` to a provider, send the real figures from `_calculateAssessment`, show success only from the response, and show `ApiErrorText` on error. Block the save when ACID is not 19 digits or a figure is missing. |
| F03-02 | BLOCKER | `screens/customs_declaration46_screen.dart:281`, `:1128`, `:1243-1244`, `:1262-1290` | The registry is `importFiles.map(_calculateAssessment)`: every import file in the system appears as a declaration. The number is made up (`'46-ALX-${file.importFileCode}'`, a port hard-coded as ALX), `registrationDate = DateTime.now()`, and `status = customsDeclStatusRegisteredNafeza` is fixed. Invented customs data (CORE_RULES §6). | Registry lists stored declarations only (`declaration_code`, `declaration_status`, `created_at` from `CustomsDeclarationResponse`). The declaration-number field starts empty (user input / backend code). Needs backend `GET /customs-declarations` (see §6). |
| F03-03 | CRITICAL | `screens/nafeza_acid_screen.dart:1988-1992`, `:3492`, `:3531`, `:3570` | `isIssued = status == 'Issued' \|\| 'ISSUED'`. The backend issued set is `{Verified, Discrepancy_Accepted, Generated, Issued, ACID Issued}` (`modules/import_documentation/service.py:432`). A verified ACID shows "Under review" in the table and in the TSV/Excel/PDF exports. | One helper `AcidStatusView.of(status)` → `issued / draft / requested / review` with the backend set. Use it in the 4 places. |
| F03-04 | CRITICAL | `providers/original_documents_collection_provider.dart:36-67`; backend `modules/original_documents_collection/router.py:99-123` | `GET /original-documents-collection/sessions` has `limit=100` by default. The client sends no `limit`/`offset`, so after 100 sessions the older ones disappear from the registry. There is no hint and no paging. | Send `limit`/`offset`. Request `pageSize+1` rows to detect a next page. Add a pagination footer (`CompactTablePaginationFooter`). Optional backend total (§6). |
| F03-05 | MAJOR | `screens/nafeza_acid_screen.dart:1856-1866`, `providers/import_documentation_provider.dart:54-85` | The ACID registry loads all sessions and searches in Dart. The backend already supports `search`, `status`, `import_file_id`. There is no status filter in the UI and no "show deleted" toggle. | Debounced (400 ms) server search + status filter through `fetchAcidSessions(search:, status:)` (the notifier already remembers them). |
| F03-06 | MAJOR | `providers/import_documentation_provider.dart:180` (`restoreAcidSession`), `screens/nafeza_acid_screen.dart:2950-2990` | ACID delete is a soft delete. `restoreAcidSession` has **no caller** and `include_inactive` is never `true`, so a deleted ACID cannot be found or restored from the UI. | "Show deleted" toggle → `fetchAcidSessions(includeInactive: true)`. Inactive rows are greyed and get a Restore action. |
| F03-07 | MAJOR | `screens/bank_form4_screen.dart:1060`, `:1204-1219`, `:1299`, `:1335`, `:1371` | Bank status is binary: `'Received'` → endorsed, everything else → "processing". The backend accepts `Approved by Bank`, `Form Issued`, `Verified`, `Endorsed` (`service.py:846`), and these show as "processing" on screen and in exports. | Status helper with the backend set (as F03-03). |
| F03-08 | MAJOR | `screens/bank_form4_screen.dart:1066-1090`; `providers/import_documentation_provider.dart:275` | The Bank Form 4 registry has Endorse / Edit / Clone only. `deleteBankingDocument` exists in the provider (backend `DELETE /banking-documents/{id}`, router l.268) but has **no caller**. There is no View. | Add View (read-only dialog, `GET /banking-documents/{id}`) and Delete with confirm (only while not endorsed). |
| F03-09 | MAJOR | `screens/nafeza_acid_screen.dart:2011-2025`, `screens/bank_form4_screen.dart:1077-1081`, `widgets/original_documents_collection_tab.dart:1949-1952`, `:2299-2303`, `screens/customs_declaration46_screen.dart:1453-1458` | No read-only View on ACID, Bank Form 4, Original Docs sessions and Couriers. The row's only "open" action loads the record into the **editable** form (a risk of editing by accident, and it loses the user's current draft). On Form 46 the "view assessment" recalculates live, so it is not the stored record. | Use `RowActionsPill(onView:, onEdit:, onClone:, onDelete:)` (`core/widgets/row_actions_pill.dart`). View = read-only details dialog (tasks T05, T06, T12). |
| F03-10 | MAJOR | All registries: `nafeza_acid_screen.dart:1962-1980`, `:2337-2354`; `bank_form4_screen.dart:1039-1056`; `customs_declaration46_screen.dart:1388-1390`; `draft_bl_review_tab.dart:2685-2689`; `coo_review_tab.dart:1863-1866`; `inspection_review_tab.dart:1290`; `invoice_bl_matcher_tab.dart:2260`; `po_reconciliation_tab.dart:3280`; `original_documents_collection_tab.dart:1898-1900`, `:2231-2233` | Large tables: `DataTable` + `rows: list.map(...)` inside horizontal `SingleChildScrollView`, inside the page's vertical scroll. Every row (and every `CopyableTableCell`, `IconButton`, `DisplayNameResolver` lookup) is built on each `setState` (each search keystroke). There is no sticky header, no sort, no paging, no "filtered / total" count. The UI standard (skill §10, checklist #11-12) is not met. | Phase 1 (frontend only): render registries with `EnterpriseDataTable<T>` (client paging 25/50/100, sort, sticky header) or the `ImportFilesScreen` pattern. Phase 2: server pagination (F03-11). |
| F03-11 | MAJOR | `providers/import_documentation_provider.dart:210-228` (bank, no params), `:300-310` (shipment docs, no params), `:428-455` (draft B/L), `:614-640` (COO), `:741-765` (inspection), `:889-925` (PO rec), `:1023-1057` (invoice-B/L) | Every list fetch is global and unbounded. The response models carry big JSON columns (`draft_extracted_data`, `system_snapshot_data`, `comparison_*`, `invoice_data`, `bl_data`) that the list never shows. With thousands of files this means MBs per screen open, on every mutation (`_afterMutation` re-fetches all). | Backend paginated summary endpoints (`/…/paginated` → `{items,total,page,page_size,total_pages}`, items without JSON blobs) + GET-by-id for details. Frontend `Paginated…Notifier` like `PaginatedImportFilesNotifier` (`features/import_files/providers/import_files_provider.dart:52-130`). |
| F03-12 | MAJOR | `widgets/coo_review_tab.dart:696`, `widgets/inspection_review_tab.dart:548`, `widgets/po_reconciliation_tab.dart:220`, `:1356`, `screens/nafeza_acid_screen.dart:2600`, `:2885`, `:3040` | "Already exists for this file" (create vs update) is decided by searching the **client list**. This works only because the list is complete. Once paging or a search filter is active, the lookup misses and a duplicate record is created. | Before any paging: look up by `import_file_id` on the server (`fetch…(importFileId:)` returns the active row) and rely on a backend uniqueness check (409). |
| F03-13 | MAJOR | `screens/customs_declaration46_screen.dart:1262-1290`, `:1116-1205`, `:165-190` | Form 46 registry and assessment: for each import file `_calculateAssessment` scans acids, bank docs, reviews, bookings, POs and the **whole tariff table** (`customsTariffProvider.fetchTariffs()`, unpaged). This runs on every build/keystroke: O(files × all lists). The screen also loads all POs and all freight bookings on mount. | After F03-02 the registry lists stored declarations (no per-row calculation). The assessment runs only for the selected file, memoized by file id. Tariffs are looked up by HS code (`/customs-tariff?search=<hs>` or a family provider), not by loading the table. |
| F03-14 | MAJOR | `frontend/lib/features/customs_tariff/providers/customs_tariff_provider.dart:42-52` used by `customs_declaration46_screen.dart:180`, `:352`, `:1272` | Form 46 reads the shared `customsTariffProvider`, whose `search`/`showInactive` belong to the Customs Tariff screen. If the user searched there, Form 46 gets a filtered list and reports "tariff missing" for valid HS codes (plausible, not reproduced). | A dedicated `tariffByHsCodeProvider.family` (server lookup) for Form 46. |
| F03-15 | MAJOR | `widgets/original_documents_collection_tab.dart:1803-1807`, `:1812-1830`, `:2182` | Registry search calls the server on **every keystroke** with no debounce (the CancelToken cancels, but requests still flood). The status filter is a raw `DropdownButton` with a hard-coded status list. | 400 ms debounce. `SearchableDropdownField<String>` (or the standard toolbar status filter) with the status list from one constant shared with `_getRegistryStatusFilterLabel`. |
| F03-16 | MAJOR | `screens/original_docs_and_cargox_screen.dart:61-62`, `:73-99`; `screens/shipment_draft_docs_screen.dart:90-91`; `providers/import_documentation_provider.dart:292-345` | BP-016 (shipment document lifecycle Draft → Received → Under Review → Approved/Rejected, `docs/phase_03_import_documentation.md`) has **no screen**. `shipmentDocumentsProvider` downloads the whole `shipment-documents` table only to show a count badge on the CargoX tab. The count is global (all files), not for the selected file. | Short term: badge = count for the selected file (`?import_file_id=`), or remove it. Long term: a per-file shipment-documents list (Q2). |
| F03-17 | MAJOR | `screens/nafeza_acid_screen.dart:1898-1900`, `:1925-1929`, `:2274-2276`, `:2301-2305` | 12 hard-coded bilingual labels: `languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table'`, `'تصدير Excel'`, `'تصدير PDF'`. The keys already exist (`idocBCopyTable`, `idocBExportExcel`, `idocBExportPdf`, used by `bank_form4_screen.dart:952-954`). | Replace with `context.l10n.idocB…`. |
| F03-18 | MINOR | `widgets/invoice_bl_matcher_tab.dart:79-130`, `:252-262` | Still open from FED-15 (partial): the button is behind `kDebugMode` (l.989), but the Shaw Europe invoice / MSC B/L constants, including an ACID literal `7595528271019210013` (l.115), still ship in the release binary. | Move the samples to `frontend/test/fixtures/` or delete them. Extend `import_documentation_no_fabricated_defaults_test.dart` with `Shaw` and `7595528271019210013`. |
| F03-19 | MINOR | `screens/bank_form4_screen.dart:441` | Banks are found with `partnerType.contains('Bank') \|\| contains('بنك')`: matching on stored text in Arabic (single-language storage rule). | Filter on the partner type code (the enum/code the partners module stores). |
| F03-20 | MINOR | `screens/bank_form4_screen.dart:1056`, `widgets/po_reconciliation_tab.dart:3006` | Fallback file code `'IMP-${importFileId}'` shows a DB id dressed up as a business code (CORE_RULES §6 "never show DB id"). | Show `'—'` when `import_file_code` is null. |
| F03-21 | MINOR | `widgets/original_documents_collection_tab.dart:1901`, `:2234`, `:1775` | `headingRowColor: AppTheme.surfaceAlt` and the title colour `AppTheme.charcoal` are not dark-aware (other registries use `isDark ? AppTheme.darkSurface : …`). | `AppTheme.surfaceAltOf(context)` / `AppTheme.textPrimaryOf(context)`. |
| F03-22 | MINOR | `widgets/legal_compliance_banner.dart:34`, `:70`, `:99` | Dates are passed as raw `DateTime.toString()` (`2026-10-05 00:00:00.000`). | `IdocBFormat.date(...)` / `DateFormat.yMd(locale)`. |
| F03-23 | MINOR | `widgets/customs_document_approval_tab.dart:63-71` | With no file chosen, `_refresh` picks `files.first`, so approvals and tickets of an arbitrary file show with no hint. | Start empty with an empty-state "select a file", or pick the file passed by the stage navigator only. |
| F03-24 | MINOR | `providers/import_documentation_provider.dart:979-995` | `centralArchiveProvider` returns `{}` on cancel and is an untyped `Map`, so a cancelled load can render an "empty archive". | Rethrow the cancel (FutureProvider is disposed anyway). Optional typed model later. |

---

## 3. Large tables (one row per list screen)

Reference for the fix (already in the codebase):
- Server pagination: `GET /api/v1/import-files/paginated?page&page_size&…` → `PaginatedImportFilesResponse {items,total,page,page_size,total_pages}` (`modules/import_files/schemas.py:374`, router l.92-116), `PaginatedImportFilesNotifier.fetchPage` (`frontend/lib/features/import_files/providers/import_files_provider.dart:52-130`), `CompactTablePaginationFooter` (`frontend/lib/core/widgets/compact_table_pagination_footer.dart`), sticky header + separate scroll body in `ImportFilesScreen` (`frontend/lib/features/import_files/screens/import_files_screen.dart:1440-1503`).
- Client-side paging/sort/sticky header for small or medium lists: `EnterpriseDataTable<T>` (`frontend/lib/core/widgets/enterprise_data_table/enterprise_data_table.dart`), today used only by `smart_tasks_screen.dart`.

| List screen | Today (evidence) | Size risk | Recommended |
|---|---|---|---|
| ACID registry (Nafeza screen, sub-tab 3) | Loads all sessions (`provider:54-80`, only `include_inactive`). Dart search (`nafeza_acid_screen.dart:1860-1865`). `DataTable` in horizontal scroll, all rows built (`:1962-1980`). Per row `importFiles.where(...)` lookup (`:1983`). No sort, no sticky header, no count. Export = filtered client list. | 1 row per import file → grows with files (thousands/year). | Phase 1: `EnterpriseDataTable` + debounced server search/status (T07, T06). Phase 2: `/acid-sessions/paginated` + "export all" from the server (T10). |
| ACID expiry tracker (sub-tab 4) | `acidTrackerProvider` one call, client filter, `DataTable` all rows (`:2337-2354`). | Only active, not-released ACIDs → medium. | `EnterpriseDataTable` (client paging) is enough. |
| Bank Form 4 registry | `fetchBankingDocuments()` with **no params** (`provider:210-228`). Dart search (`bank_form4_screen.dart:904-910`). `DataTable` all rows (`:1039-1056`). `DisplayNameResolver` twice per row (`:1057-1058`). | 1-3 per file. | Same as ACID (T07, T10). Backend already accepts `import_file_id`. |
| Form 46 registry | Not a list of records: one computed row per import file (`customs_declaration46_screen.dart:1272-1290`), heavy per-row calculation (F03-13). `DataTable` all rows (`:1388`). | Equal to all import files, the worst case. | Replace with a stored-declarations list (T02), paginated from day one. |
| Draft B/L registry (stage 5) | Global fetch (`DraftBLNotifier` constructor `fetchReviews()` with no file), JSON blobs per row. Dart filter (`draft_bl_review_tab.dart:2397-2408`). `DataTable` minWidth 950, all rows (`:2685-2689`). | Several versions per file. | T08 (client) then T10 pattern (server summary list). |
| COO registry | `fetchCOOReviews()` global (`coo_review_tab.dart:77`). Dart filter reads `draftInputData` maps (`:1621-1640`). `DataTable` all rows (`:1863-1866`). | 1-3 per file. | T08 / T10. |
| Inspection registry | `fetchInspectionReviews()` global (`inspection_review_tab.dart:68`). `DataTable` all rows (`:1290`). | 1-2 per file. | T08 / T10. |
| Invoice vs B/L sessions | Fetch by `_activeFileId` (`invoice_bl_matcher_tab.dart:141`), null = global. Dart filter (`:2012-2027`). `DataTable` (`:2260`). | Drafts + certified per file. | T09 / T10. |
| PO reconciliation sessions | `fetchSessions()` global (`po_reconciliation_tab.dart:208`). Dart filter with `DisplayNameResolver` per row **inside the filter** (`:2999-3016`). `DataTable` (`:3280`). | Drafts + certified per file. | T09 / T10. |
| Original docs sessions | Server search/status (good) but **cut at 100** (F03-04), no debounce (F03-15), `DataTable` all rows (`original_documents_collection_tab.dart:1898-1900`). | 1 per file. | T04 (limit/offset + footer), then server total. |
| Couriers registry | `GET /couriers/all` (all couriers of all files, no params, backend `router.py:178-190`). Dart filter (`:2207-2215`). `DataTable` (`:2233`). | Several per file. | Client paging now (T12). Backend `limit/offset/search` later (§6). |
| Customs approvals + tickets | Per file (`fetchApprovals(importFileId:)`), `ListView.separated` (lazy) (`customs_document_approval_tab.dart:919`, `:1017`). | Small per file. | OK. No change, except F03-23. |
| Search & Clone dialogs (8) | Receive the full provider list, `ListView.separated` (lazy). | Inherits the size of the list. | OK once T10 lands: dialogs call the server search instead of the cached list. |
| Master-data dropdowns on every screen | `importFilesProvider`, `purchaseOrdersProvider`, `suppliersProvider`, `partnersProvider` fully loaded on mount (`nafeza_acid_screen.dart:139-160`, `customs_declaration46_screen.dart:165-190`). | All import files / POs in memory per screen. | Out of scope here (shared). Listed as Q3 for a cross-phase "remote searchable dropdown". |

Why the current approach breaks at scale: `DataTable` has no lazy rows, so 5,000 rows means 5,000 × (8-11 cells + 3 icon buttons) widgets built at once. With the page-level `SingleChildScrollView` around it there is no viewport culling. Any `setState` (one search keystroke) rebuilds everything. The fix order: (1) bound the rendered rows (client paging) now, (2) bound the downloaded rows (server paging + summary DTO) next, (3) move "does a record exist for this file" checks to the server before (2) (F03-12).

---

## 4. View/Show action

| Entity (list) | View exists? | Evidence | Why not (code reason) | What to add |
|---|---|---|---|---|
| ACID session | No | Row actions: Edit (`_loadSessionForEdit`), Clone, Delete (`nafeza_acid_screen.dart:2011-2025`) | No details dialog was written. "Edit" was used as "open". The provider never calls `GET /acid-sessions/{id}` (it exists, router l.187). | Read-only `AcidSessionDetailsDialog`: requested vs generated data, discrepancies, override reason, dates, audit. Data from the row model or GET-by-id (T06). |
| Bank Form 4 doc | No | Endorse, Edit, Clone (`bank_form4_screen.dart:1066-1090`) | Same: no dialog. GET-by-id exists (router l.232) but no provider method. | `BankDocDetailsDialog` + Delete (T05). |
| Form 46 declaration | No (only "view assessment", recalculated live) | `customs_declaration46_screen.dart:1453-1458` | There is no stored declaration to view (F03-01/02) and no backend list/GET-by-id. | After T01/T02: a View of the stored declaration (totals as saved, not recalculated). |
| Draft B/L review | Yes | `draft_bl_review_tab.dart:2754-2756` `_showDraftBLSessionDetailsDialog` | | |
| COO review | Yes | `coo_review_tab.dart:1903-1906` | | |
| Inspection review | Yes | `inspection_review_tab.dart:1349-1352` | | |
| Invoice vs B/L session | Yes | `invoice_bl_matcher_tab.dart:2406-2409` | | |
| PO reconciliation session | Yes | `po_reconciliation_tab.dart:3337-3340` | | |
| Original docs session | No | Copy row + "load session" (`original_documents_collection_tab.dart:1940-1952`) | The only action opens the editable collection grid for the file. No session details dialog. | Read-only dialog: documents checklist with received/verified flags, couriers, completion % (T12). |
| Courier | No | Track, Confirm delivery, Copy, Load session (`:2267-2303`) | Same as above. | Read-only courier dialog: company, AWB, dates, POD, receiver (T12). |
| Customs approval / ticket | Inline (the row shows both tiers) | `customs_document_approval_tab.dart:1062-1140`, `:1229-1290` | The card is already the detail view. | None. |
| Shipment documents (BP-016) | No list at all | F03-16 | Screen never built. | Q2. |

The 5 registries that do have View each use a different icon and order (`Icons.visibility`, `visibility_outlined`, `visibility_rounded`, `analytics_outlined`). Standardise on `RowActionsPill` order View → Edit → Clone → Print → Delete when touching each registry (part of T07-T09).

---

## 5. Tasks

General rules for every task (Antigravity has no context):
- Flutter app root `frontend/`. Feature folder `frontend/lib/features/import_documentation/`. State = Riverpod `StateNotifier`, HTTP = `dio` via `ref.read(dioProvider)`, base URL `ApiConstants.baseUrl` (`/api/v1`).
- Colours only from `AppTheme`. Buttons `AppButton`. Dropdowns `SearchableDropdownField`. Text only via `context.l10n.<key>`. New keys go in all three files `frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`, between the markers `// === review phase03_ui_b keys (append below this line) ===` and `// === end review phase03_ui_b keys ===`. Use the prefix `fe03`.
- Show API errors with `ApiErrorText.of(context.l10n, e)` (`frontend/lib/core/localization/api_error_text.dart`) in a red `SnackBar`. After every mutation the notifier re-fetches (existing `_afterMutation`).
- Do not touch backend files. Do not bump versions. Run `flutter test <the new/changed test files>` and `flutter analyze` on changed files before finishing.

### FE03-T01: Form 46 save calls the backend

- **Severity**: BLOCKER. **Type**: bug. **Depends on**: none.
- **Backend needed**: no (`POST /api/v1/import-documentation/customs-declarations` exists; body `CustomsDeclarationCreate`: `import_file_id:int?`, `po_id:int?`, `acid_number:str` exactly 19 digits, `form4_number:str?`, `bl_number:str?`, `total_cif_val_egp:float>=0`, `total_customs_duties_egp:float>=0`, `total_vat_egp:float>=0`; response `CustomsDeclarationResponse` adds `declaration_id`, `declaration_code`, `import_file_code`, `declaration_status`, `is_active`, `created_at`, `updated_at`).
- **Files to change**: `frontend/lib/features/import_documentation/models/import_documentation_model.dart` (add `CustomsDeclarationModel`), `frontend/lib/features/import_documentation/providers/import_documentation_provider.dart` (add `CustomsDeclarationService` or a method), `frontend/lib/features/import_documentation/screens/customs_declaration46_screen.dart` (`_saveDeclaration46`, l.2083-2101), l10n files (2 keys), test file.
- **Steps**:
  1. Add `CustomsDeclarationModel.fromJson` with exactly the response fields above (`total_*` as `double`, dates as `DateTime`).
  2. Add `Future<CustomsDeclarationModel> createCustomsDeclaration(Map<String,dynamic> body)` that POSTs to `'${ApiConstants.baseUrl}/import-documentation/customs-declarations'` and rethrows errors.
  3. In `_saveDeclaration46`: remove `Future.delayed`. Build the body from the current file's assessment (`_calculateAssessment(file, l)`): `import_file_id`, `acid_number` (the ACID shown on screen), `form4_number`, `bl_number`, `total_cif_val_egp = cifEgp`, `total_customs_duties_egp = totalDutiesEgp`, `total_vat_egp = vatEgp`.
  4. Refuse to save (red SnackBar, new key `fe03Form46MissingFigures`) when ACID is not 19 digits or `cifEgp`/`totalDutiesEgp`/`vatEgp` is null (the assessment's `missing` list is non-empty). Never send 0 for a missing figure.
  5. Show `customsDeclSaveSuccess` with the returned `declaration_code` (new key `fe03Form46Saved(code)`) only after a 2xx. On `DioException` show `ApiErrorText.of`. Keep `isLoading` on the button.
  6. After success: `ref.invalidate(importFilesProvider)` and switch to the registry sub-tab as today.
- **Acceptance criteria**:
  - [ ] Pressing Save with complete data creates a row in `customs_declarations` (visible through the API) and shows its code.
  - [ ] A missing ACID / tariff / FX rate blocks the save with a clear red message. No request is sent.
  - [ ] A backend 422 shows the backend message, not "saved".
- **Tests to add**: `frontend/test/customs_declaration46_save_test.dart`. Use a fake Dio adapter (pattern in `frontend/test/import_documentation_provider_refresh_test.dart`): (a) the POST body has exactly the 8 schema keys with the computed numbers; (b) a 422 response makes the screen show the error and not the success text; (c) a missing figure sends no request.
- **Out of scope**: the registry (T02), PUT/edit of a declaration.

### FE03-T02: Form 46 registry shows stored declarations only

- **Severity**: BLOCKER. **Type**: bug. **Depends on**: FE03-T01 + backend `GET /customs-declarations` (list, filters `import_file_id`, `search`, `status`, `page`, `page_size`; envelope `{items,total,page,page_size,total_pages}`) and `GET /customs-declarations/{id}`.
- **Backend needed**: yes (above; see §6 B1).
- **Files to change**: `screens/customs_declaration46_screen.dart` (`_buildDeclarationRegistryView` l.1262-1500, l.281, l.1128, l.1243-1244), `providers/import_documentation_provider.dart` (new `PaginatedCustomsDeclarationsNotifier`, modelled on `frontend/lib/features/import_files/providers/import_files_provider.dart:52-130`), `models/import_documentation_model.dart`, l10n, test.
- **Steps**:
  1. Remove the made-up number: `_declaration46NoCtrl` starts empty (l.281, l.429). Remove `declNo = '46-ALX-…'` (l.1128), `registrationDate: DateTime.now()` and the fixed `status` (l.1243-1244) from the assessment object (they belong to the stored record, not the calculation).
  2. Registry rows = `items` of the paginated endpoint. Columns: `declaration_code`, file (`import_file_code` + shipment name), ACID, CIF EGP, duties EGP, VAT EGP, `declaration_status` (localized via a status map), `created_at`.
  3. Server search (400 ms debounce) + status filter + `CompactTablePaginationFooter`.
  4. Row actions via `RowActionsPill`: View (read-only dialog from the row / GET-by-id: stored totals, not recalculated), Clone (existing `_onCloneDeclarationSelected`).
  5. KPI strip totals come from the loaded page and are labelled "this page" (new key), or from a backend summary if one is added.
- **Acceptance criteria**:
  - [ ] An import file with no saved declaration does **not** appear in the registry.
  - [ ] No `46-ALX-` text anywhere (grep), no `DateTime.now()` used as a registration date.
  - [ ] 2,000 declarations: the screen opens in < 1 s and shows 50 rows + pagination.
- **Tests to add**: `frontend/test/customs_declaration46_registry_test.dart`: with a fake API returning 2 items and `total: 120`, the table shows 2 rows and the footer shows 120. Extend `frontend/test/import_documentation_no_fabricated_defaults_test.dart` to forbid `46-ALX-`.
- **Out of scope**: editing a stored declaration.

### FE03-T03: Correct ACID status everywhere

- **Severity**: CRITICAL. **Type**: bug. **Depends on**: none. **Backend needed**: no.
- **Files to change**: new `frontend/lib/features/import_documentation/models/acid_status_view.dart`, `screens/nafeza_acid_screen.dart` (l.1988-1992, 2113-2132, 3492-3494, 3531-3533, 3570-3572), test.
- **Steps**:
  1. Create `enum AcidStatusKind { issued, draft, requested, underReview }` and `AcidStatusKind acidStatusKindOf(String status)`: issued when the status (case-insensitive) is in `{verified, discrepancy_accepted, generated, issued, acid issued}`; draft for `draft`; requested for `requested`, `pending`, `pending issue`; otherwise underReview. Comment: mirrors `_ACID_ISSUED_STATUSES` in `modules/import_documentation/service.py:432`.
  2. Add `String acidStatusLabel(AppLocalizations l, AcidStatusKind k)` using the existing keys `issuedAndValidStatus`, `tempDraftStatus`, `underReviewStatus` + one new key `fe03AcidRequestedStatus`.
  3. Replace the 4 `isIssued` blocks and the badge colours with the helper.
- **Acceptance criteria**:
  - [ ] An ACID with status `Verified` shows "Issued & valid" (green) in the table, TSV, Excel and PDF.
  - [ ] `Requested` shows its own label, not "Under review".
- **Tests to add**: `frontend/test/acid_status_view_test.dart`: table-driven test for every status listed above, including mixed case.
- **Out of scope**: expiry tracker statuses (backend sends `status` + message code there).

### FE03-T04: Original docs registry: paging, debounce, no silent cut at 100

- **Severity**: CRITICAL. **Type**: bug. **Depends on**: none. **Backend needed**: no for paging (`limit`, `offset` exist). Optional total count (§6 B3).
- **Files to change**: `providers/original_documents_collection_provider.dart` (l.36-67), `widgets/original_documents_collection_tab.dart` (l.1755-1960), l10n, test.
- **Steps**:
  1. Add `int pageSize = 50`, `int page = 1`, `bool hasNext` to the notifier (keep the `AsyncValue<List<…>>` state; store paging fields as public getters). `fetchSessions({status, search, page = 1})` sends `limit: pageSize + 1`, `offset: (page-1)*pageSize`; `hasNext = response.length > pageSize`; keep only `pageSize` items.
  2. `_afterMutation` re-fetches the same page, status and search.
  3. In the tab: debounce the search `onChanged` by 400 ms (a `Timer` field, cancelled in `dispose`).
  4. Under the table add Prev / Next buttons (`AppButton` small) + "Page N" text (new keys `fe03PrevPage`, `fe03NextPage`, `fe03PageN(n)`). Disable Prev on page 1, Next when `!hasNext`.
  5. Replace the status `DropdownButton<String>` (l.1812) with `SearchableDropdownField<String>` using the same values and `_getRegistryStatusFilterLabel`.
  6. Heading colours: `AppTheme.surfaceAltOf(context)` (l.1901, 2234) and `AppTheme.textPrimaryOf(context)` (l.1775) (F03-21).
- **Acceptance criteria**:
  - [ ] With 130 sessions the user can reach session #130 (page 3).
  - [ ] Typing "ABC" sends one request, not three.
  - [ ] Dark mode heading is readable.
- **Tests to add**: `frontend/test/original_documents_registry_paging_test.dart`: fake Dio returns 51 rows for `limit=51` → notifier keeps 50, `hasNext == true`; page 2 sends `offset=50`.
- **Out of scope**: couriers registry (T12), total count.

### FE03-T05: Bank Form 4: correct status, View, Delete

- **Severity**: MAJOR. **Type**: feature + bug. **Depends on**: none. **Backend needed**: no (`GET /banking-documents/{id}`, `DELETE /banking-documents/{id}` exist).
- **Files to change**: `screens/bank_form4_screen.dart` (l.1060-1090, 1204-1219, 1299, 1335, 1371, 1056), new `widgets/bank_doc_details_dialog.dart`, `providers/import_documentation_provider.dart` (add `getBankingDocument(id)`), l10n, test.
- **Steps**:
  1. Status helper `bankDocIsEndorsed(String s)` true for `Received`, `Approved by Bank`, `Form Issued`, `Verified`, `Endorsed` (mirrors `service.py:846`). Use it in the table, badge and the 3 exports.
  2. `BankDocDetailsDialog` (read-only): code, type, reference, Form 4 number, bank, amount + currency, request/received/issue/expiry dates, execution days, status, notes, file code + shipment name. `SelectionArea`, Close button, RTL-safe (`AlignmentDirectional`).
  3. Replace the row action `Row` with `RowActionsPill(onView:, onEdit:, onClone:, onDelete:)`, plus the existing Endorse icon. Delete only when not endorsed. Confirm dialog, then `deleteBankingDocument(id)`. SnackBar result. Error → `ApiErrorText`.
  4. File code fallback `'IMP-${id}'` (l.1056) → `'—'` (F03-20).
- **Acceptance criteria**:
  - [ ] Each row has View; View never opens the edit form.
  - [ ] A pending Form 4 can be deleted and disappears after refresh; an endorsed one has no Delete.
  - [ ] A doc with status `Form Issued` shows as endorsed.
- **Tests to add**: `frontend/test/bank_form4_registry_actions_test.dart`: pump the registry with 2 docs (one `Received`, one `Pending`), assert the View icon on both, Delete only on `Pending`, and the dialog shows the reference number.
- **Out of scope**: paging (T07/T10).

### FE03-T06: ACID registry: server search/status filter, show deleted + restore, View

- **Severity**: MAJOR. **Type**: feature. **Depends on**: FE03-T03. **Backend needed**: no (`GET /acid-sessions?search&status&include_inactive`, `PATCH /acid-sessions/{id}/restore` exist).
- **Files to change**: `screens/nafeza_acid_screen.dart` (registry tab l.1856-2160, delete l.2950-2990), new `widgets/acid_session_details_dialog.dart`, l10n, test.
- **Steps**:
  1. Search field: 400 ms debounce → `fetchAcidSessions(search:, status:, includeInactive:)`. Remove the Dart `where` filter (l.1860-1865).
  2. Add a status filter (`SearchableDropdownField<String>`, values: All / Draft / Requested / Issued; send the backend words `DRAFT`, `Requested`, `Verified` etc. as agreed in Q4; default All).
  3. Add a "Show deleted" `Switch` → `includeInactive`. Inactive rows: greyed text, actions = View + Restore (`restoreAcidSession`, SnackBar, re-fetch).
  4. `AcidSessionDetailsDialog` (read-only): ACID number, file, PO, importer (name, tax id), exporter (name, reg id, country), ports, broker, requested/generated/expiry dates, days to expiry, discrepancies list, override reason, notes.
  5. Row actions → `RowActionsPill(onView, onEdit, onClone, onDelete)`.
  6. Replace the 12 literal labels (`'نسخ الجدول'`, `'تصدير Excel'`, `'تصدير PDF'`, l.1898-1929 and 2274-2305) with `context.l10n.idocBCopyTable / idocBExportExcel / idocBExportPdf` (F03-17).
- **Acceptance criteria**:
  - [ ] Search runs on the server (one request per pause).
  - [ ] A deleted ACID can be found with "Show deleted" and restored.
  - [ ] View shows all fields read-only. No `languageCode == 'ar' ?` left in the file (grep).
- **Tests to add**: `frontend/test/acid_registry_actions_test.dart`: the View dialog opens with the ACID number; with "Show deleted" on, the provider receives `include_inactive: true`; Restore calls `PATCH …/restore`.
- **Out of scope**: paging (T07/T10).

### FE03-T07: Bounded rendering for ACID + Bank Form 4 registries (client paging, sticky header, sort)

- **Severity**: MAJOR. **Type**: refactor/ux. **Depends on**: FE03-T05, FE03-T06 (same files; do after). **Backend needed**: no.
- **Files to change**: `screens/nafeza_acid_screen.dart` (registry + expiry tables), `screens/bank_form4_screen.dart` (registry table), test. Do not change `core/widgets/enterprise_data_table/*` in this task (if a bug is found, write it in the PR notes).
- **Steps**:
  1. Replace each `SingleChildScrollView(horizontal) + DataTable(rows: list.map…)` with `EnterpriseDataTable<T>(data:, columns: [EnterpriseColumn…], storageKey: 'idoc_acid_registry' / 'idoc_acid_expiry' / 'idoc_bank_registry', initialPageSize: 50, availablePageSizes: [25,50,100], enableExport: false, emptyMessage: context.l10n.<existing empty key>)`. Keep the existing export buttons (they export the full filtered list).
  2. Columns `isSortable: true` for code, file, dates, status, amount.
  3. Keep the action column first, and keep `CopyableTableCell` in cells.
  4. Pre-compute per-row lookups (`importFiles` by id → `Map<int, ImportFileModel>`) once per build, not inside the row builder.
- **Acceptance criteria**:
  - [ ] With 3,000 ACID rows in a fake provider the tab scrolls smoothly and builds at most 100 rows.
  - [ ] Header stays visible while scrolling. Clicking a header sorts.
  - [ ] The page size choice survives a restart.
- **Tests to add**: `frontend/test/import_doc_registries_bounded_render_test.dart`: pump the ACID registry with 500 fake rows; assert `find.byType(DataRow)`/row widgets ≤ 100 and that a pagination control is present.
- **Out of scope**: server paging (T10).

### FE03-T08: Bounded rendering for Draft B/L, COO, Inspection registries + unified row actions

- **Severity**: MAJOR. **Type**: refactor/ux. **Depends on**: none. **Backend needed**: no.
- **Files to change**: `widgets/draft_bl_review_tab.dart` (l.2385-2850), `widgets/coo_review_tab.dart` (l.1610-1940), `widgets/inspection_review_tab.dart` (l.1280-1390), test.
- **Steps**: same as FE03-T07 steps 1-4 for the three registries (`storageKey`: `idoc_draft_bl_registry`, `idoc_coo_registry`, `idoc_inspection_registry`). Move the per-row actions into `RowActionsPill` in the order View → Edit/Load → Clone → Print/PDF → Delete (Delete only for drafts, as today). Keep the status/file filters and the KPI counts as they are.
- **Acceptance criteria**:
  - [ ] Each of the 3 registries shows ≤ 100 rows per page, has a sticky header and sortable columns.
  - [ ] View is the first action on each row, with the same icon in all three.
- **Tests to add**: extend `frontend/test/import_doc_registries_bounded_render_test.dart` with one case per registry (500 fake rows → ≤ 100 rendered).
- **Out of scope**: changing what the details dialogs show.

### FE03-T09: Bounded rendering for Invoice-B/L and PO-reconciliation registries

- **Severity**: MAJOR. **Type**: refactor/ux. **Depends on**: none. **Backend needed**: no.
- **Files to change**: `widgets/invoice_bl_matcher_tab.dart` (l.1995-2430), `widgets/po_reconciliation_tab.dart` (l.2995-3400, l.3006), test.
- **Steps**: same as FE03-T07 (`storageKey`: `idoc_invoice_bl_registry`, `idoc_po_rec_registry`). In the PO-rec filter (l.2999-3016) build the shipment-title map once before filtering instead of calling `DisplayNameResolver` per row per keystroke. Replace the `'IMP-${s.importFileId}'` fallback (l.3006) with an empty string (F03-20). Row actions → `RowActionsPill`.
- **Acceptance criteria**: as FE03-T08 for the two registries.
- **Tests to add**: extend `frontend/test/import_doc_registries_bounded_render_test.dart` (2 cases).
- **Out of scope**: the matcher/editor parts of these tabs.

### FE03-T10: Server-side paging for phase-03 registries (frontend part)

- **Severity**: MAJOR. **Type**: feature. **Depends on**: FE03-T07..T09, FE03-T11, and backend B2 (§6).
- **Backend needed**: yes: `GET /import-documentation/{acid-sessions|banking-documents|draft-bl|coo|inspection|invoice-bl/sessions|po-reconciliation/sessions}/paginated?page&page_size&search&status&import_file_id&sort&order` → `{items,total,page,page_size,total_pages}`, items = summary fields only (no JSON blobs); GET-by-id for the details dialog (missing today for COO and inspection).
- **Files to change** (one registry per session; first ACID + Bank): `providers/import_documentation_provider.dart` (new `Paginated…Notifier`s, pattern `frontend/lib/features/import_files/providers/import_files_provider.dart:52-130`), `models/import_documentation_model.dart` (summary models), the registry widget of that entity, test.
- **Steps**:
  1. Add `PaginatedAcidSessionsNotifier` with `fetchPage(page, {search, status, includeInactive, sort})` and state `{items,total,page,pageSize,totalPages,isLoading,error}`.
  2. Registry: server mode, with `CompactTablePaginationFooter(currentPage, totalPages, totalCount, pageSize, onPageChanged, onPageSizeChanged)` under the table (stop using `EnterpriseDataTable`'s client paging for this registry; keep its sticky header/sort by passing the server sort).
  3. View/Edit: load the full record with GET-by-id before opening the dialog/editor.
  4. Export buttons: "Export all" calls the paginated endpoint page by page (page_size 200) until done, with a progress SnackBar; never only the visible page.
  5. Repeat for Bank Form 4, then Draft B/L, COO, Inspection, Invoice-B/L, PO rec (one task session each).
- **Acceptance criteria**:
  - [ ] Opening the ACID registry downloads ≤ 1 page (check the network log), and the total count is correct.
  - [ ] Excel export of 1,200 rows contains 1,200 rows.
- **Tests to add**: `frontend/test/paginated_acid_sessions_notifier_test.dart`: fake Dio, page 2 sends `page=2&page_size=50`, state total/pages parsed; export collects all pages.
- **Out of scope**: backend implementation.

### FE03-T11: "Record exists for this file" checks via the server, not the cached list

- **Severity**: MAJOR. **Type**: bug (latent). **Depends on**: none. Must land before FE03-T10. **Backend needed**: no (list endpoints accept `import_file_id`). Backend 409 uniqueness is recommended (§6 B4).
- **Files to change**: `screens/nafeza_acid_screen.dart` (l.2600, 2885, 3040), `widgets/coo_review_tab.dart` (l.696), `widgets/inspection_review_tab.dart` (l.548), `widgets/po_reconciliation_tab.dart` (l.220, 1356), `providers/import_documentation_provider.dart` (helper methods), test.
- **Steps**:
  1. Add to each notifier `Future<T?> findActiveForFile(int importFileId)` that GETs the list with `import_file_id` (and `include_inactive=false`) **without changing the notifier state**, and returns the first active item or null.
  2. Replace each `sessions.where((s) => s.importFileId == … && s.isActive).firstOrNull` with `await notifier.findActiveForFile(id)`.
  3. On a 409 from create, show `ApiErrorText` and offer "Open existing" (load into editor).
- **Acceptance criteria**:
  - [ ] With the registry filtered by a search that hides file X's record, saving file X again updates the record instead of creating a duplicate.
- **Tests to add**: `frontend/test/import_doc_find_active_for_file_test.dart`: fake Dio, `findActiveForFile(7)` sends `import_file_id=7` and leaves the notifier state unchanged.
- **Out of scope**: backend unique constraints.

### FE03-T12: Original docs + couriers: read-only View and client paging for couriers

- **Severity**: MAJOR. **Type**: feature. **Depends on**: FE03-T04 (same file). **Backend needed**: no (GET session by id exists: `original_documents_collection/router.py` ~l.83-95).
- **Files to change**: `widgets/original_documents_collection_tab.dart` (l.1940-1952, 2149-2310), new `widgets/original_docs_session_details_dialog.dart`, l10n, test.
- **Steps**:
  1. `OriginalDocsSessionDetailsDialog` (read-only): collection code, file, ACID, supplier, each document (name, required, received, verified, verified by/at), couriers, completion %, notes.
  2. `CourierDetailsDialog` (same file is fine): company, number, sent/expected/received dates, receiver, POD reference, tracking link (reuse the existing safe link opener).
  3. Registry row actions → `RowActionsPill(onView:, onEdit: _loadInitialFile)`. Courier row: View + existing Track/Confirm/Copy.
  4. Courier table → `EnterpriseDataTable` (client paging 50, sticky header), keeping the current Dart search.
- **Acceptance criteria**:
  - [ ] Both lists have a View that never opens the editor.
  - [ ] 2,000 couriers render ≤ 100 rows per page.
- **Tests to add**: `frontend/test/original_docs_view_dialogs_test.dart`: the View icon opens a dialog with the collection code and no editable `TextField`.
- **Out of scope**: backend courier paging (§6 B5).

### FE03-T13: Form 46 performance and tariff source

- **Severity**: MAJOR. **Type**: refactor. **Depends on**: FE03-T02. **Backend needed**: no (`GET /customs-tariff?search=<hs>` exists).
- **Files to change**: `screens/customs_declaration46_screen.dart` (l.150-190, 340-365, 1116-1205), new `frontend/lib/features/import_documentation/providers/form46_tariff_provider.dart`, test.
- **Steps**:
  1. Create `tariffByHsCodeProvider = FutureProvider.family<CustomsTariffModel?, String>` that GETs `/customs-tariff?search=<hs>` and returns the exact `hs_code` match (or null). It must not read or change `customsTariffProvider`.
  2. `_calculateAssessment` runs only for the selected file. Cache the result in a field keyed by `importFileId` and invalidate it when the file or its data changes.
  3. Remove `customsTariffProvider.fetchTariffs()`, the global `freightBookingProvider.fetchBookings()` and `purchaseOrdersProvider.fetchPurchaseOrders()` from `initState` if T02 removed their last list use. Fetch per file instead (`?import_file_id=`).
- **Acceptance criteria**:
  - [ ] Searching in the Customs Tariff screen no longer changes Form 46 results.
  - [ ] Opening Form 46 does not download the tariff table (network log).
- **Tests to add**: `frontend/test/form46_tariff_provider_test.dart`: fake Dio; provider returns the exact match and null when none; `customsTariffProvider` state untouched.
- **Out of scope**: the duty formula (`services/customs_declaration46_calculator.dart`).

### FE03-T14: Shipment documents badge (BP-016) per file

- **Severity**: MAJOR. **Type**: bug. **Depends on**: none. **Backend needed**: no (`GET /shipment-documents?import_file_id=` exists).
- **Files to change**: `providers/import_documentation_provider.dart` (l.292-310), `screens/original_docs_and_cargox_screen.dart` (l.55-100, 118-121), `screens/shipment_draft_docs_screen.dart` (l.90-91), test.
- **Steps**:
  1. `fetchShipmentDocuments({int? importFileId})`. Store and reuse the last value in `_afterMutation`. Add a `CancelToken` like the other notifiers.
  2. Both screens fetch with the selected file id. With no file selected, do not fetch and hide the badge.
  3. Remove the fetch from `shipment_draft_docs_screen.dart` if nothing on that screen reads the provider (grep before deleting).
- **Acceptance criteria**:
  - [ ] The CargoX badge shows the number of documents of the selected file only.
  - [ ] Opening the screens without a file does not download the shipment-documents table.
- **Tests to add**: `frontend/test/shipment_documents_badge_test.dart`: fake Dio receives `import_file_id`; no request when the id is null.
- **Out of scope**: a full BP-016 lifecycle screen (Q2).

### FE03-T15: Hygiene bundle (MINOR)

- **Severity**: MINOR. **Type**: refactor. **Depends on**: none. **Backend needed**: no.
- **Files to change**: `widgets/invoice_bl_matcher_tab.dart` (l.75-130, 252-262, 985-995), `screens/bank_form4_screen.dart` (l.441), `widgets/legal_compliance_banner.dart` (l.34, 70, 99), `widgets/customs_document_approval_tab.dart` (l.63-71), `frontend/test/import_documentation_no_fabricated_defaults_test.dart`.
- **Steps**:
  1. Delete `sampleShawInvoice`, `sampleMscBL`, `_loadSampleData` and the `kDebugMode` button (F03-18). Add `Shaw Europe`, `MEDURE910647`, `7595528271019210013` to the forbidden list of the guard test.
  2. Bank picker: filter partners by type code (read `PartnerModel` to find the code field; e.g. `partnerTypeCode == 'BANK'`). No Arabic text matching (F03-19). If no code field exists, leave it and note it in the PR.
  3. Legal banner: format the dates with the app date formatter (`IdocBFormat.date` or `DateFormat.yMMMd(locale)`) (F03-22).
  4. Customs approval tab: do not auto-pick `files.first`. Show the existing "select a file" empty state until the user or the stage navigator picks a file (F03-23).
- **Acceptance criteria**:
  - [ ] Guard test passes and fails if the Shaw literal comes back.
  - [ ] The legal banner shows `05/10/2026`-style dates in both languages.
- **Tests to add**: guard test update (above). `frontend/test/legal_compliance_banner_format_test.dart`: no `00:00:00.000` in the rendered text.
- **Out of scope**: F03-24 (optional).

---

## 6. Backend dependencies (short)

- **B1** (for FE03-T02): `GET /api/v1/import-documentation/customs-declarations` (paginated envelope, filters `import_file_id`, `search`, `status`) and `GET /customs-declarations/{id}`. Only `POST` exists today (`router.py:309-317`).
- **B2** (for FE03-T10): `/paginated` summary endpoints for ACID, banking documents, draft B/L, COO, inspection, invoice-B/L sessions, PO-rec sessions (same envelope as `PaginatedImportFilesResponse`), plus `sort`/`order`. Add `GET /coo/{id}` and `GET /inspection/{id}` (missing).
- **B3** (nice to have for FE03-T04): a total count for `/original-documents-collection/sessions` (envelope or `X-Total-Count` header).
- **B4** (for FE03-T11): unique active record per `import_file_id` (409 on duplicate) for ACID, COO, inspection, PO-rec sessions. The frontend check is not a guarantee.
- **B5**: `/original-documents-collection/couriers/all` needs `limit/offset/search/import_file_id` (returns all couriers of all files today).

## 7. Open questions for the CTO

- **Q1**: Form 46 declaration number. Who issues it: the user types the Nafeza number after registering, or the backend generates `declaration_code` and the Nafeza number is a separate field? The schema today has only `declaration_code` (backend-generated). Is a `nafeza_declaration_number` column needed?
- **Q2**: BP-016 shipment document lifecycle (Draft → Received → Under Review → Approved/Rejected) has backend endpoints but no screen. Build a per-file "Shipment documents" tab (in Shipment Draft Docs or Original Docs), or are the review tabs (Draft B/L / COO / Inspection) considered enough?
- **Q3**: Master-data dropdowns load all import files / POs / suppliers on every screen. Do we want a cross-phase "remote search" `SearchableDropdownField` (server search, 20 results) now, or only when the data grows?
- **Q4**: ACID status vocabulary. The backend uses `DRAFT`, `Requested`, `Pending Issue`, `Verified`, `Discrepancy_Accepted`, `Generated`, `Issued`, `ACID Issued`. Can the backend normalise it to a small code set (e.g. `DRAFT/REQUESTED/ISSUED/CORRECTION_REQUESTED`) so the filter in FE03-T06 is simple?
- **Q5**: Phase-1 client paging (FE03-T07..T09) is cheap and safe. Should we stop there for registries that are 1-3 rows per file, and use server paging (FE03-T10) only for ACID + Bank + Original Docs?
