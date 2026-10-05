# Cross-cutting (all phases + shared widgets): frontend review: large tables and the View action

Status: 2026-10-05, static review only (no code run, no tests run, nothing edited). Reviewer scope: shared table / row-action
widgets, list providers of every feature, backend list endpoints (`modules/*/router.py`) for paging support, UI permission and
error infrastructure. Per-screen bugs inside a phase are owned by the phase reports (`phase-0N-frontend-review.md`); this report
owns the **standard** for large tables (topic A) and the View action (topic B) and the migration plan.

Relation to earlier plans: `phase-01-frontend-review.md` proposed `FE01-T22 PagedDataTable` and `FE01-T26 View loads by id`.
This report **replaces both with one shared design** (FEX-T01..T03 and FEX-T09). Phase tasks that say "use FE01-T22" should use
FEX-T02 instead. Nothing here re-reports items that the previous quality wave fixed.

| File | Lines | Depth |
|---|---|---|
| `frontend/lib/core/widgets/enterprise_data_table/enterprise_data_table.dart` | 792 | full |
| `frontend/lib/core/widgets/enterprise_data_table/widgets/*.dart` (pagination bar, header toolbar, column picker, shimmer) | 969 | API + strings |
| `frontend/lib/core/widgets/row_actions_pill.dart`, `buttons/icon_action_button.dart`, `row_context_menu.dart` | 471 | full |
| `frontend/lib/core/widgets/compact_table_pagination_footer.dart` | 215 | API |
| `frontend/lib/core/network/api_error.dart`, `features/auth/models/user_model.dart`, `auth_route_guard.dart` | 160 | full |
| `frontend/lib/core/providers/navigation_provider.dart`, `workspace_tabs_provider.dart` | 615 | structure |
| `frontend/lib/features/import_files/providers/import_files_provider.dart` (paged notifier) + `import_files_screen.dart` (list part 1090-1880) | ~900 | targeted |
| `frontend/lib/features/cargo_insurance/providers/cargo_insurance_provider.dart` (paged notifier) | 120 | targeted |
| `frontend/lib/features/customs_tariff/screens/customs_tariff_screen.dart` + provider | 1000 | targeted |
| All 89 `features/*/screens/*.dart` and registry/table/tab widgets | ~150k | scripted inventory (grep: DataTable / Table / ListView.builder / RowActionsPill / onView / shrinkWrap) + spot reads |
| All `features/*/providers/*.dart` list fetches | - | grep of GET calls + query params |
| `modules/*/router.py` list and GET-by-id routes; `modules/import_files/schemas.py:374`; `modules/cargo_insurance/router.py:55-80` | - | grep + targeted |
| `.claude/skills/ui-screen-standards/SKILL.md` §Type B, §10, §14 | - | targeted |

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 0 |
| CRITICAL | 2 |
| MAJOR | 11 |
| MINOR | 6 |

Most important points:

1. **Lists cut off without warning (FX-01, CRITICAL).** Several screens call list endpoints that have a default `limit` (100 or
   200) and never send `limit`/`offset`. Rows past that limit never appear, the client-side search does not find them, and exports
   are short. No "showing 100 of N" text is shown. Affected: Customs clearance RFQs, CargoX envelopes, CargoX standard-invoice
   sessions, Experience guide, Original documents sessions, Audit logs.
2. **Customs tariff renders the whole tariff at once (FX-02, CRITICAL).** `GET /customs-tariff` with no limit returns every HS
   line. The screen builds every row eagerly in a `Table` inside two `SingleChildScrollView`s, so the header scrolls away.
   Thousands of tariff lines make the screen freeze. The backend already supports `skip/limit/search`.
3. **There is no shared server-paged table.** The only shared table, `EnterpriseDataTable`, pages on the client. It needs the
   full list in memory, it offers a "All" page size, and it re-filters and re-sorts the list 2-3 times per build. Only Import files
   (`/import-files/paginated`) and Cargo insurance (`skip/limit` + `total`) page on the server, and they use two different
   contracts. A third contract (`limit/offset`) is used by CargoX and Original documents. **Design: sections 3.3-3.6.**
4. **Why there is no "Show" (topic B).** `RowActionsPill` always draws a View icon. When a screen passes no `onView`, the icon
   shows greyed out with no reason. No screen loads a record by id: the backend has `GET /<entity>/{id}` for almost every entity,
   but the frontend has **zero** GET-by-id calls for main entities. So "View" is either a dialog over the stale list row, the edit
   form (Incoterms, Cost items, Transport locations), or something else: audit history (Projects), rate history (Currencies),
   Odoo journal (Settlements). Smart tasks, clearance price items, step configs, users and freight RFQs have no View at all. There
   are no go_router routes (navigation is an `IndexedStack` index), so no per-record route exists either. **Design: section 4.**
5. **No UI permission gating (FX-11).** The client only knows `role`. `GET /auth/me/permissions` exists but nothing calls it for
   the signed-in user, so Edit and Delete show for everyone and fail with 403 after the click. A standard View action needs a
   `can('x.view')` check, so this must land first.

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FX-01 | CRITICAL | `customs_clearance_quotations_provider.dart:26-33` vs `modules/customs_clearance_quotations/router.py:41-42` (limit 100); `cargox_provider.dart:40-50` vs `cargox/router.py:31` (100); `cargox_provider.dart:190-193` vs `cargox/router.py:227` (100); `experience_guide_provider.dart:87-90` vs `experience_guide/router.py:37-38` (100); `original_documents_collection_provider.dart:46-53` vs `original_documents_collection/router.py:109` (100); `audit_logs_provider.dart:26` (`?limit=200`) + client search `audit_logs_screen.dart:61-67`, export `:177` | The list is silently cut to the first 100 or 200 rows. Search and export work only on those rows. Searching for an older audit entry or RFQ shows "no results". | Short term (FEX-T04): send an explicit `limit=500`. When the result length equals the limit, show an orange banner: "Showing the first N records. Narrow the filter." Move search to the server. Long term: these lists move to the paged contract (FEX-T05/T06). |
| FX-02 | CRITICAL | `customs_tariff_provider.dart:44-60` (no `limit`); `customs_tariff_screen.dart:346-415` (`Table` with `...tariffs.map` inside vertical + horizontal `SingleChildScrollView`) | The whole tariff is fetched and every row is built eagerly. The header is not sticky (skill §10-a), and `Colors.white` / `Colors.grey.shade200` (l.355-357) break dark mode. With the real tariff (thousands of lines) the screen freezes on open and on every search keystroke. | Move to `PagedDataTable` (FEX-T02) with server `search` + page. The backend already has `skip/limit/search` (`router.py:45-51`); only `total` is missing (backend dependency B1). Task FEX-T05. |
| FX-03 | MAJOR | `import_files_screen.dart:1098-1101` (initial `fetchPage(1)` without the deep-link `initialSearchQuery` that was just put into `_searchController` at l.1091), `:1205` (after clone), `:1312` (header refresh), `:1561,1573,1599,1644,2099,2111` (action `onSuccess`); `import_files_provider.dart:116-127` (`nextPage/prevPage` drop filters) | The filters live in the screen, not in the provider, so each refresh loads the **unfiltered** page while the search box and status chip still show the filter. A deep link "open import files filtered by X" shows all files. | Keep the `ListQuery` (search, status, company, page, pageSize) inside the notifier; `refresh()` reuses it. Task FEX-T06. |
| FX-04 | MAJOR | `enterprise_data_table.dart:203-260, 426-431, 486-494`; `enterprise_table_pagination_bar.dart:87-90` | `EnterpriseDataTable` pages on the client only, although its doc comment (l.28) says "client and server pagination". `_filteredAndSortedData` runs at l.428, again inside `_pagedData` (l.247) and again for select-all, so one keystroke filters and sorts the full list 2-3 times. The "All" page size (`-1`) builds every row in a `DataTable`. Without a `sortComparator`, columns sort as strings ("100" < "9", dates in display format). | Cache the filtered/sorted list in state and recompute only when the data, query or sort changes. Hide "All" when there are more than 500 rows. Require `sortComparator` for numeric and date columns (assert). The widget stays the client-side option for small lists (under about 500 rows). Task FEX-T07. |
| FX-05 | MAJOR | `enterprise_data_table.dart:320-329, 377-379` | CSV export: the save dialog offers `['csv','xlsx']`, but the content is always CSV text. Saving as `.xlsx` writes a broken file that Excel will not open. The default name `Export_<title>_<millis>.csv` breaks the naming rule (`[Stage Name] - [Import File Code].ext`). The PDF stage name is the internal `storageKey` (for example `smart_tasks_master_table`). | Offer `csv` only. The name comes from a required `exportStageName` plus an optional code. Task FEX-T07. |
| FX-06 | MAJOR | `enterprise_data_table.dart:67, 305, 327, 355, 377, 389, 543, 556`; `enterprise_table_pagination_bar.dart:64, 89, 98`; `enterprise_table_header_toolbar.dart` (12 literals); `enterprise_table_column_picker_dialog.dart` (11); colors `enterprise_data_table.dart:589, 594, 685` (`Color(0xFFEEF2F6)`, `Color(0xFFF1F5F9)`, `Colors.grey.shade*`) | The shared table has hard-coded Arabic text, so the English UI shows Arabic. It also has hard-coded colors instead of `AppTheme`. | Move the strings to `app_localizations*.dart` and the colors to `AppTheme` tokens. Task FEX-T07. |
| FX-07 | MAJOR | `row_actions_pill.dart:57-105`; `icon_action_button.dart:178,184` | View, Edit and Delete are always drawn. A null callback draws a grey disabled icon with the normal tooltip, so users see an eye icon that does nothing and no reason why. Print without `onPrint` shows a fake "preparing export" SnackBar and does nothing (l.86-95). | Replace with `RowActions<T>`: actions are a list; a null action is **hidden**, or disabled with a `disabledReason` tooltip; no default Print. Task FEX-T08. |
| FX-08 | MAJOR | `incoterms_screen.dart:478-479, 1029-1030`; `transport_locations_screen.dart:407-408` (View = same editable dialog as Edit); `projects_screen.dart:560-569` (View = `RowHistoryDialog`); `currencies_screen.dart:445` (View = rate history); `settlement_registry_card.dart:330-340` (View = Odoo journal; **Edit = `recalculateSettlement`** with no confirm and a success SnackBar shown before the call finishes; Print = copy breakdown) | The same icon means different things on different screens. In Settlements, the pencil silently recalculates money. | One meaning per icon: View = read-only details; History = a separate action; Recalculate = its own labelled action with a confirm. Tasks FEX-T10, FEX-T12. |
| FX-09 | MAJOR | All View dialogs, e.g. `import_files_screen.dart:1618`, `purchase_orders_screen.dart:772`, `suppliers_screen.dart:441`, `partners_screen.dart:704`, `saved_cbm_registry_tab.dart:366`; repo-wide grep: no `GET /<entity>/{id}` call for main entities (only `landed_cost_comparison_screen.dart:85`) while backend routes exist (`purchase_orders/router.py` `/{po_id}`, `suppliers/router.py:223`, `import_companies/router.py:203`, `projects`, `currencies`, `incoterms`, `transport_locations`, `smart_tasks/router.py:86`, `freight_booking:56`, `freight_quotations:71`, `cargo_shipping`, `warehouse_receiving`, `financial_settlement`, `file_closure`, `customs_tariff`, `external_service_providers`, `cargox/envelopes/{id}`, `experience_guide/{id}`) | Details render the list row object, which can be stale. Once lists move to light "summary" rows (needed for paging), these dialogs would lose data. Notifications, audit logs and the AI assistant cannot open a record they only know by id. | Shared `entityDetailsProvider.family` + `EntityDetailsDialog` that loads by id (FEX-T09). |
| FX-10 | MAJOR | `smart_tasks_screen.dart:486-490`; `customs_clearance_quotations_screen.dart:565-569` | Delete runs on a single tap with no confirm dialog and no result SnackBar. | Route every delete through a shared `confirmAndRun` (FEX-T08) and show the API error with `ApiError.message`. Task FEX-T11. |
| FX-11 | MAJOR | `user_model.dart:1-40` (only `role`); `rbac_models.dart:111` (`effectivePermissions` parsed, used only in the users admin screen); backend `modules/auth/router.py:186` `GET /auth/me/permissions` | The UI cannot hide or disable actions by permission. Users without `*.manage` see Edit, Delete and Clone, click them, and get 403. A View-only role cannot be supported in the UI. | `currentPermissionsProvider` (loaded after login) + `can(String code)` + `PermissionGate`; `RowAction.permission`. Task FEX-T13. |
| FX-12 | MAJOR | `searchable_dropdown_field.dart:22,109` (static `items` only); 91 files read `importFilesProvider` (full `GET /import-files`, full payload); 25 files read `purchaseOrdersProvider` (all POs with items) | Every picker downloads the entire table to fill a dropdown. This grows with the business and duplicates memory per screen. | `SearchableDropdownField.remote(search: (q) => ...)` with a 300 ms debounce + backend `/lookup?q=&limit=20` (B3). Migrate the import-file and PO pickers first. Task FEX-T14. |
| FX-13 | MAJOR | List screens with header that scrolls away and all rows built eagerly: `partners_screen.dart:545-588`, `projects_screen.dart:485-535`, `incoterms_screen.dart:399-438, 950-989, 1507-1550`, `customs_tariff_screen.dart:369-415`, `currencies_screen.dart:372-420`, `transport_locations_screen.dart:337-382`, `saved_cbm_registry_tab.dart`, `saved_scenarios_registry_tab.dart`, `saved_consultations_tab.dart`, `financial_approval_screen.dart:5108+`, `lifecycle_board_screen.dart`, `shipment_update_engine_screen.dart` | These break skill §10 (sticky header, sticky actions column, independent scroll container). Only Import files and Purchase orders build a sticky header, each with its own hand-made two-`DataTable` trick (`import_files_screen.dart:1440-1510`, `purchase_orders_screen.dart:653-715`). | Migrate to `PagedDataTable` in the order of section 3.7. |
| FX-14 | MINOR | `row_context_menu.dart:294-330, 354` | Right-click menu has hard-coded English labels (`'Edit Record'`, `'View Activity Log'`, `'Copy Code'`, `'Deactivate Record'`) and no View item. It is used only by Suppliers and Import companies. | l10n + add View as the first item; build it from the same `RowAction` list as the row buttons. Task FEX-T08. |
| FX-15 | MINOR | 40 sites in 20 files show raw `$e` in SnackBars/Text, e.g. `standard_invoice_hub_tab.dart:693,715,804,950,1468,1487`, `system_observability_screen.dart` (4), `import_files_screen.dart` (4), `visual_container_load_planner_dialog.dart` (3) | Users see `DioException [bad response]: ...` instead of the backend `detail` (CORE_RULES: backend errors as SnackBar text). | Use `ApiError.message(e)` / `ApiErrorText`. Task FEX-T16. |
| FX-16 | MINOR | `icon_action_button.dart:155-160, 173-184`; `PrintActionButton` l.232 | Disabled colors are hard-coded light (`0xFFF5F5F5`, `0xFFBDBDBD`), so they are invisible in dark mode. The file also uses deprecated `color.red` / `withOpacity`. | Use `AppTheme` disabled tokens (`*Of(context)`) and `withValues`. Task FEX-T08. |
| FX-17 | MINOR | 21 `shrinkWrap: true` lists in 16 feature files (e.g. `cargo_shipping_screen.dart:1331`, PO mobile list) | `shrinkWrap` + `NeverScrollableScrollPhysics` builds every child, so there is no virtualization. This is fine for small form sections, but not for registries. | Covered by migration; list registries must not use `shrinkWrap`. |
| FX-18 | MINOR | `pubspec.yaml` (`go_router: ^15.1.2`); no `GoRouter`/`GoRoute` in `lib/`; `navigation_provider.dart:37-60` (int indices); `workspace_tabs_provider.dart:6-12` (tab = `routeIndex`) | go_router is a dependency but unused. Screens are opened by integer index, so there is no way to address one record (no `/purchase-orders/:id`). | The View design (section 4) uses an `EntityRef` registry instead of routes. Adding go_router is out of scope (open question Q4). |
| FX-19 | MINOR | `modules/import_files/router.py:97-98` | `page`/`page_size` have no bounds (`page_size=1000000` or `page=0` are accepted). This is the only paged contract the frontend uses today. | Backend dependency B1 (`ge=1`, `le=200`). |

---

## 3. Large tables (topic A)

### 3.1 What exists today

Shared building blocks:

| Block | File | What it does | Gap |
|---|---|---|---|
| `EnterpriseDataTable<T>` | `core/widgets/enterprise_data_table/enterprise_data_table.dart` | Client-side search/sort/page, column picker + reorder + resize persisted in SharedPreferences, CSV/PDF/TSV export, selection + bulk bar, shimmer, empty state | Needs the full list in memory. Only `smart_tasks_screen.dart:801` uses it. Header not sticky (it sits in a `Column(mainAxisSize: min)`, so the page scrolls). Rows not virtualized (`DataTable`). FX-04/05/06. |
| `CompactTablePaginationFooter` | `core/widgets/compact_table_pagination_footer.dart` | Pager UI (l10n OK) | Used by Import files (server), Currencies and Transport locations (client slices). |
| `RowActionsPill` | `core/widgets/row_actions_pill.dart` | View/Edit/Clone/Print/Delete icons | FX-07, no permission, no confirm. |
| `MasterDataToolbarWidget` | `core/widgets/master_data_toolbar.dart` | Toolbar for master data | Search is client-side in callers. |
| Paged notifiers | `import_files_provider.dart:60-127` (page/page_size, filters not kept); `cargo_insurance_provider.dart:30-75` (skip/limit, filters kept, "load more") | Two separate implementations | No shared base, different contracts. |

Dependencies: no data-grid package in `frontend/pubspec.yaml` (no pluto_grid, data_table_2, syncfusion, two_dimensional_scrollables).

Backend list endpoints and paging support:

| Contract | Endpoints | Returns total? |
|---|---|---|
| `page` / `page_size` → `{items,total,page,page_size,total_pages}` | `GET /import-files/paginated` (`import_files/router.py:91-135`, schema `import_files/schemas.py:374-379`) | yes |
| `skip` / `limit` → `{total, items}` | `GET /cargo-insurance/certificates` (`cargo_insurance/router.py:55-79`) | yes |
| `skip` / `limit` → plain list | `customs-tariff` (limit default None = all), `transport-locations` (None = all), `customs-clearance-quotations/rfqs` (default 100), `experience-guide` (100), `smart-document-upload` | no |
| `limit` / `offset` → plain list | `cargox/envelopes` (100), `cargox/standard-invoice/sessions` (100), `original-documents-collection/sessions` (100) | no |
| `limit` only | `audit-logs` (100, max 500), `notifications` (100), `app-update/history`, `recalculation`, `simulation`, `smart-email` logs | no |
| No paging at all (whole table) | `purchase-orders` (with items + packing rows), `suppliers`, `import-companies`, `external-service-providers`, `projects`, `currencies`, `incoterms`, `cost-items`, `smart-tasks`, `freight-quotations`, `freight-booking`, `shipment-updates`, `warehouse-receiving`, `financial-approval` payment requests + budgets, `financial-settlement`, `file-closure`, `customs-consultations` (+ price lists, expense types), `cbm-calculator`, `shipping-scenarios`, `import-requirements`, `lifecycle-board/step-configs`, `GET /import-files` (full list used by 91 pickers) | no |

### 3.2 Per list screen (current behaviour, evidence, recommendation)

Expected size is a rough guess for a busy importer after 3 years. "Size" decides the migration order in 3.7.

| Screen / list | Rows loaded | Widget | Sticky header / h-scroll | Search / filter / sort | Evidence | Expected size | Recommendation |
|---|---|---|---|---|---|---|---|
| Customs tariff (HS) | **all** (no limit) | `Table`, eager | no / yes | server search, no sort, no paging | `customs_tariff_provider.dart:44-60`, `customs_tariff_screen.dart:346-415` | thousands | PagedDataTable + server page (FEX-T05) |
| Audit logs | first 200 only | `ListView.builder` cards | n/a | client search over 200 | `audit_logs_provider.dart:26`, `audit_logs_screen.dart:61-67` | 100k+ | Paged server list + filters entity/user/date (FEX-T04 → T15) |
| Import files | server page 50 | header `DataTable` + body `DataTable` (eager per page) | yes (hand-made) / yes | server search/status; filters lost on refresh (FX-03) | `import_files_provider.dart:60-127`, `import_files_screen.dart:1440-1880` | 5k-20k | Keep server paging; fix query state (FEX-T06); later swap body to PagedDataTable (FEX-T17) |
| Purchase orders | all, with items | header + body `DataTable` | yes / yes | server search/filters, no sort | phase-01 §3; `purchase_orders_screen.dart:653-715` | 5k-20k | Phase task FE01-T23 rebuilt on FEX-T02 |
| Payment requests / budgets (financial approval) | all | `DataTable` eager | no / yes | client filter computed twice | phase-02 F02-23; `financial_approval_screen.dart:5108+` | 5k+ | Phase-02 T11/T12 on FEX-T02 |
| Smart tasks | all | `EnterpriseDataTable` (client page 25) | no / yes | client search/sort | `smart_tasks_screen.dart:801-820` | 10k+ (auto tasks) | Paged contract (FEX-T18); keep columns |
| CargoX envelopes / standard-invoice sessions | first 100 | cards / `DataTable` | no | server search | `cargox_provider.dart:40-50, 190-193` | 5k | FEX-T04 now, paged later |
| Customs clearance RFQs | first 100 | `ListView.builder` cards | n/a | server status/port | `customs_clearance_quotations_provider.dart:26-33` | 2k+ | FEX-T04 now, paged later |
| Clearance price items | all | `DataTable` eager | no | none | `customs_clearance_quotations_screen.dart:535-575` | hundreds | FEX-T02 client mode |
| Experience guide | first 100 | list | n/a | server | `experience_guide_provider.dart:80-90` | 1k | FEX-T04 |
| Original docs sessions | first 100 | `DataTable` | no | server | `original_documents_collection_provider.dart:46-53` | 5k | FEX-T04 |
| Transport locations | all (`limit` None) | `Table`, client page 50 | no / yes | server search/type, client page | `transport_locations_screen.dart:300-382, 562` | 1k-10k (world ports) | Server page via existing `skip/limit` + total (B1) |
| Partners | all | `Table` eager | no / yes | client | `partners_screen.dart:545-588` | hundreds-1k | FEX-T15 |
| Suppliers / Import companies | all | `ListView.separated` (virtualized) | no column header | client | `suppliers_screen.dart:387`, `import_companies_screen.dart:350` | hundreds-1k | OK for now; move to PagedDataTable with Partners pattern later |
| Projects | all | `Table` eager | no / yes | server status, client search | `projects_screen.dart:485-535` | hundreds | FEX-T15 |
| Currencies | all, client page 25 | `Table` | no / yes | client | `currencies_screen.dart:344-420, 651` | < 50 | Keep client; replace with FEX-T02 client mode when touched |
| Incoterms / cost items / matrix | all | `Table` eager | no / yes | none | `incoterms_screen.dart:399-438, 950-989, 1507-1550` | < 200 | Keep (small); sticky header via FEX-T02 client mode when touched |
| CBM / Shipping scenarios / Consultations registries | all | `DataTable` eager in nested scroll | no / no scrollbar | mixed | phase-01 §3 | 1k-5k each | Phase-01 FE01-T24/T25 rebuilt on FEX-T02 |
| Lifecycle board, Shipment inquiry, Shipment updates, Step configs, Warehouse GRN / GIT ledger / received report, Cargo insurance (load-more), Swift reconciliation, CargoX invoice hub | all (insurance: 50 + load more) | `DataTable` eager | no | client/mixed | inventory grep | varies | Phase owners, on FEX-T02 |

### 3.3 Standard solution: one table, one query object, one backend contract

The goal is one widget and one notifier base that every list uses. A screen gives the columns and the row actions. The notifier
holds the query (page, size, sort, search, filters). The backend does the paging.

```
Screen ──columns + actions──▶ PagedDataTable<T> ──onQueryChanged──▶ PagedListNotifier<T>
                                   ▲                                      │ GET /<entity>/paginated?page&page_size&sort&q&filters
                                   └──────────── PagedListState<T> ◀──────┘ {items,total,page,page_size,total_pages}
```

Two data sources share the same widget:
- `ServerPagedSource` calls the paged endpoint (target).
- `ClientPagedSource` slices an already-loaded list (small lists and the transition period). The screen code stays the same when
  the backend endpoint lands.

### 3.4 Widget API sketch (Dart)

Files: `frontend/lib/core/widgets/paged_data_table/` (`list_query.dart`, `page_result.dart`, `paged_list_notifier.dart`,
`paged_table_column.dart`, `row_action.dart`, `paged_data_table.dart`).

```dart
// list_query.dart
@immutable
class ListQuery {
  final int page;            // 1-based
  final int pageSize;        // 25 | 50 | 100 (max 200, never "all")
  final String? sort;        // "-created_at" or "supplier_name,-eta"
  final String search;       // sent as q=
  final Map<String, Object?> filters; // status, company_id, date_from, ...
  final bool includeInactive;

  const ListQuery({this.page = 1, this.pageSize = 50, this.sort, this.search = '',
      this.filters = const {}, this.includeInactive = false});

  Map<String, dynamic> toQueryParameters() => {
        'page': page, 'page_size': pageSize,
        if (sort != null) 'sort': sort,
        if (search.trim().isNotEmpty) 'q': search.trim(),
        if (includeInactive) 'include_inactive': true,
        for (final e in filters.entries) if (e.value != null && e.value != '') e.key: e.value,
      };

  ListQuery copyWith({int? page, int? pageSize, String? sort, String? search,
      Map<String, Object?>? filters, bool? includeInactive});
  // Any change other than `page` resets page to 1 (done in the notifier).
}

// page_result.dart
class PageResult<T> {
  final List<T> items; final int total; final int page; final int pageSize; final int totalPages;
  factory PageResult.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => PageResult(
      items: (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
      total: (j['total'] as num).toInt(), page: (j['page'] as num).toInt(),
      pageSize: (j['page_size'] as num).toInt(),
      totalPages: (j['total_pages'] as num?)?.toInt() ?? 0);
}

// paged_list_notifier.dart
@immutable
class PagedListState<T> {
  final ListQuery query;
  final PageResult<T>? data;   // last good page (kept while the next page loads: no flashing)
  final bool isLoading;
  final Object? error;         // shown with ApiError.message + Retry
}

abstract class PagedListNotifier<T> extends StateNotifier<PagedListState<T>> {
  PagedListNotifier(this._dio, {required this.path, required this.fromJson, ListQuery initial = const ListQuery()})
      : super(PagedListState(query: initial)) { load(); }

  final Dio _dio; final String path; final T Function(Map<String, dynamic>) fromJson;
  CancelToken? _cancel; Timer? _debounce;

  Future<void> load();                       // cancels the previous request, keeps `data` while loading
  Future<void> refresh() => load();          // SAME query: used after add/edit/delete (CORE_RULES auto-refresh)
  void setSearch(String q);                  // 350 ms debounce, page -> 1
  void setFilter(String key, Object? value); // page -> 1
  void setSort(String? sort);                // page -> 1
  void setPage(int page);
  void setPageSize(int size);                // page -> 1, persisted per storageKey
  @override void dispose() { _cancel?.cancel(); _debounce?.cancel(); super.dispose(); }
}

// paged_table_column.dart
class PagedTableColumn<T> {
  final String id;                                  // stable id for prefs
  final String Function(AppLocalizations l) label;  // l10n only
  final double width;                               // fixed width: header and rows line up without measuring
  final String? sortKey;                            // server sort field; null = not sortable
  final bool numeric;                               // end-aligned + LTR island (amounts, codes, dates)
  final bool pinned;                                // pinned at the start edge (actions, code)
  final bool hideable;                              // column picker
  final Widget Function(BuildContext context, T row) cell;
  final String Function(T row)? exportValue;        // CSV / TSV / PDF
}

// row_action.dart  (also replaces RowActionsPill: see section 4)
enum RowActionKind { view, edit, clone, print, history, delete, custom }
class RowAction<T> {
  final RowActionKind kind;
  final String? permission;             // e.g. 'purchase_orders.manage'; hidden when the user lacks it
  final String? disabledReason;         // non-null = shown disabled with this tooltip
  final bool confirm;                   // delete: true by default (shared confirm dialog)
  final Future<void> Function(T row) run;
  final IconData? icon; final String Function(AppLocalizations l)? label; // custom actions only
}

// paged_data_table.dart
class PagedDataTable<T> extends ConsumerStatefulWidget {
  const PagedDataTable({
    super.key,
    required this.storageKey,                 // column widths / visibility / page size prefs
    required this.columns,
    required this.state,                      // PagedListState<T>
    required this.onQueryChanged,             // (ListQuery) -> notifier
    this.rowActions,                          // List<RowAction<T>> Function(T row)
    this.onOpen,                              // double-click / Enter: defaults to the view action
    this.rowKey,                              // Object Function(T) for selection and focus (business id)
    this.selectable = false, this.onSelectionChanged, this.bulkActions,
    this.toolbarLeading, this.toolbarFilters, // search box is built in; filters are SearchableDropdownField
    this.exportStageName,                     // "[Stage Name] - [code].ext" naming
    this.emptyMessage, this.pageSizes = const [25, 50, 100],
  });
}
```

Layout and behaviour rules:

| Need | How |
|---|---|
| Virtualized rows | Body = `ListView.builder(itemExtent: density.rowHeight)` (`core/theme/density_provider.dart:11,49,87`). Only visible rows are built. No `DataTable`, no `shrinkWrap`. |
| Sticky header | The header row is outside the vertical scroll: `Column(header, Expanded(body), footer)`. Solid background `AppTheme.charcoal` at 6% opacity (skill §10-a). |
| Horizontal scroll | One horizontal `Scrollbar` + `SingleChildScrollView` holds a `SizedBox(width: sum(column widths))` with the header and the body inside, so they always line up. |
| Pinned start columns (actions + code) | Two panes: a pinned pane (pinned columns) and the scrolling pane (the rest). Each pane has its own `ListView.builder`. Their vertical `ScrollController`s are synced by a listener with a re-entrancy guard. The pinned pane is at the **start** edge, so it is on the right in Arabic. Alternative: the first-party `two_dimensional_scrollables` package (`TableView` with `pinnedRowCount`/`pinnedColumnCount`, lazy in both axes). It needs approval for a new dependency (Q1). |
| Column resize / visibility / order | Reuse the column picker and the width persistence from `enterprise_data_table.dart:128-184, 394-422, 659-691`. Store under `paged_table_<storageKey>_*`. SharedPreferences is fine here: these are UI preferences, not secrets. |
| Server sort | A header tap cycles asc → desc → none on `sortKey`. The arrow icon is shown. Multi-sort with Shift+click is optional. |
| Search / filter | The toolbar search box calls `setSearch` (debounced). Filters use `SearchableDropdownField` (CORE_RULES). Filter chips show the active filters with a clear-all button. |
| Row count | The footer (`CompactTablePaginationFooter`) shows "1-50 of 12,345". The toolbar shows the total. |
| States | First load: shimmer (`EnterpriseTableShimmerSkeleton`). Next page: keep the old rows and show a 2 px `LinearProgressIndicator`. Error: `ApiError.message` + Retry button. Empty vs no-results: two different messages, and "clear filters" for no-results. |
| Export of the full set | The CSV/Excel/PDF buttons export **all rows of the current query**, not just the page. They call the backend export when it exists (`/<entity>/export-excel?same filters`), otherwise loop through `page_size=200` pages with a progress dialog and a cancel button (limit: 10,000 rows, then ask the user to filter). Save goes through `FileSaveHelper.exportAndSaveFile` with name `[exportStageName] - [code].ext`. |
| Keyboard | Up/Down move the focused row; Enter / double-click = View; `Ctrl+F` focuses search; PageUp/PageDown = previous/next page; `Delete` = delete action (with confirm), only when permitted; `Ctrl+C` copies the focused row as TSV (reuse `CopyableTableCell` summary). |
| RTL | Only `EdgeInsetsDirectional` / `AlignmentDirectional`. Numeric and code cells are wrapped in an LTR island (as `enterprise_data_table.dart:762-767`). The resize drag delta is mirrored in RTL (as l.664-665). |
| Narrow (< 768 px) | The same notifier feeds a card list (`ListView.builder`) with the same `RowAction`s (skill §11). |
| Auto refresh | After add/edit/delete, call `notifier.refresh()`, which keeps the query. Never call `fetchPage(1)` with lost filters (FX-03). |

### 3.5 Backend list contract (needed by the widget)

Keep the old endpoints unchanged (many callers and pickers use the plain lists). Add one new route per entity, following the
precedent `GET /import-files/paginated`:

```
GET /api/v1/<entity>/paginated
    ?page=1                 int, ge=1
    &page_size=50           int, ge=1, le=200
    &sort=-created_at,code  comma list; "-" = desc; whitelist per entity; unknown field -> 400 {code: LIST_SORT_FIELD_INVALID}
    &q=text                 server search over the entity's searchable columns (code, name, refs)
    &include_inactive=false
    &<entity filters>       status, company_id, supplier_id, import_file_id, date_from, date_to ...
-> 200 {
     "items": [ <EntitySummary> ... ],   // light row schema: no nested line items
     "total": 12345,                      // count of the filtered query
     "page": 1, "page_size": 50, "total_pages": 247
   }
```

- Stable order: always add the primary key as the last sort key, so page boundaries never repeat or skip rows.
- Shared helper in `modules/common/pagination.py`: `Page[T]` (generic Pydantic model) + `paginate(query, page, page_size,
  sort, allowed_sorts)`. It runs `count()` on the filtered query and `offset/limit` on the sorted query.
- Auth: the same `require_permission("<module>.view")` as the plain list route.
- Summary schemas: lists return `<Entity>ListItem` (codes, names, status, key amounts with currency). Full details come from
  `GET /<entity>/{id}` (topic B). This is what makes paging cheap for POs (no `items`/`packing_list_items`).
- Pickers: `GET /api/v1/<entity>/lookup?q=&limit=20&ids=1,2,3` → `[{id, code, label, is_active}]`. `ids` resolves the labels of
  values that are already selected.
- Server export: `GET /<entity>/export-excel?<same filters and sort>` streams the whole filtered set (the existing
  `suppliers/router.py:149` and `import_companies/router.py:145` routes show the pattern).
- Endpoints that already take `skip/limit` (tariff, locations, RFQs, guide, CargoX, original docs) also get the `/paginated`
  route. The current `skip/limit/offset` parameters stay for backward compatibility.

### 3.6 Lookups (pickers) are part of the large-data problem

`SearchableDropdownField` takes a static `items` list. So every screen that picks an import file reads `importFilesProvider`,
which is the whole `GET /import-files` with the full payload (91 files), and every PO picker reads all POs with their items
(25 files). Standard: `SearchableDropdownField<T>.remote({required Future<List<SearchableDropdownItem<T>>> Function(String q) search,
required Future<SearchableDropdownItem<T>?> Function(T value) resolve})`. It debounces by 300 ms, shows the first 20 matches, and
says "type to search more". It is backed by `/lookup` (B3). Migrate the import-file and PO pickers first (FEX-T14).

### 3.7 Migration order (largest data and highest risk first)

| # | List | Why first | Task |
|---|---|---|---|
| 0 | Shared base: query/page/notifier + widget + row actions + permissions | everything depends on it | FEX-T01, T02, T08, T13 |
| 1 | Silent truncation banner (RFQs, CargoX ×2, guide, original docs, audit logs) | wrong results today; small change | FEX-T04 |
| 2 | Customs tariff | thousands of rows, freezes | FEX-T05 |
| 3 | Import files query state | core screen, filters lost | FEX-T06 |
| 4 | Audit logs (server filters + paging) | grows fastest | FEX-T15 (needs B1/B4) |
| 5 | Purchase orders | heavy payload (items) | FE01-T23 on FEX-T02 |
| 6 | Payment requests / budgets | money lists | phase-02 T11/T12 on FEX-T02 |
| 7 | Smart tasks | auto-generated, grows fast | FEX-T18 |
| 8 | CargoX envelopes, Clearance RFQs, Original docs sessions, Experience guide | after banner, real paging | phase owners on FEX-T02 |
| 9 | Transport locations, Partners, Projects | master data, medium | FEX-T19 (+ suppliers/companies later) |
| 10 | CBM / Scenarios / Consultations / Requirements registries | medium | FE01-T24/T25 on FEX-T02 |
| 11 | Import files body swap to PagedDataTable | already paged; removes the hand-made sticky header | FEX-T17 |
| 12 | Small lists (currencies, incoterms, cost items, price items) | small; client mode | when touched |
| 13 | Pickers to remote lookup | memory and startup | FEX-T14, then per feature |

---

## 4. View / Show action (topic B)

### 4.1 Why there is no real "Show"

Root causes, with code evidence:

1. **The shared row widget hides the problem.** `RowActionsPill` (`row_actions_pill.dart:57-62`) always draws View. When the screen
   gives no `onView`, the icon is drawn disabled (`icon_action_button.dart:178,184`) with the normal "View details" tooltip, so it
   looks broken. Screens that do not use the pill (Smart tasks `smart_tasks_screen.dart:447-490`, Clearance price items
   `customs_clearance_quotations_screen.dart:556-571`, Step configs `step_config_management_screen.dart:246-261`, Users
   `users_management_screen.dart:1252`) build their own icon rows with only Edit/Delete.
2. **No GET-by-id on the frontend.** The backend has `GET /<entity>/{id}` for almost every entity (finding FX-09 lists them). No
   provider calls them, so a View can only show the list row object. Building a real details view was never cheaper than reusing
   the edit dialog. That is why Incoterms, Cost items and Transport locations wire View to the **edit** dialog
   (`incoterms_screen.dart:478,1029`; `transport_locations_screen.dart:407`).
3. **No detail route convention.** go_router is unused. Screens are `IndexedStack` indices (`navigation_provider.dart:37-60`) and a
   workspace tab is keyed by `routeIndex` (`workspace_tabs_provider.dart:6-12`), so a record cannot have its own page or tab.
   Other places that know a record by id (notifications, audit logs, AI assistant, command palette) cannot open it.
4. **Forms only have create/edit modes.** No dialog has a `readOnly` mode.
5. **No permission in the UI** (FX-11), so a View-only role cannot be served. Every user sees Edit anyway.
6. **Meanings drifted.** Without a standard, "View" became history (Projects), rate history (Currencies) or the Odoo journal
   (Settlements). The Settlements Edit button recalculates money (`settlement_registry_card.dart:331-339`).

### 4.2 The standard

1. **Row actions come from one list:** `List<RowAction<T>>` (section 3.4). Fixed order: View, Edit, Clone, Print, History, Delete,
   then custom actions in a `⋮` menu. View is always first and always present for any entity that has a list. An action without
   permission is hidden. An action that is not allowed in this state (for example Edit on a closed file) is shown disabled with a
   `disabledReason` tooltip. Delete always goes through the shared confirm dialog and shows the API result as a SnackBar. The same
   list drives the row buttons, the right-click menu (`row_context_menu.dart`), the mobile card menu and the keyboard
   (Enter = View).
2. **View = read-only details loaded by id.**
   - `final entityDetailsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, EntityRef>(...)` calls
     `GET /<entity>/{id}`. Typed wrappers exist per feature, e.g. `purchaseOrderByIdProvider = FutureProvider.autoDispose.family<PurchaseOrderModel, int>`.
   - `EntityDetailsDialog` (`core/widgets/entity_details/entity_details_dialog.dart`): a side sheet on desktop (540-600 px, start
     edge) or a full-screen dialog when narrow. It has a header with the business code and status chip, then read-only
     `DetailsSection`s with `DetailsField(label, value, copyable: true)` (reuse `CopyableTableCell`), and loading / error (Retry) /
     not-found states. The footer has Edit (if permitted, closes the sheet and opens the existing edit dialog), Print/PDF (existing
     export service), History (`RowHistoryDialog`, `features/audit_logs/widgets/row_history_dialog.dart`) and Close.
   - It shows business codes, never DB ids (CORE_RULES §8). Money is always shown with its currency. Missing values show `—`, never
     invented defaults.
   - The existing details dialogs (`SupplierDetailsDialog`, `PartnerDetailsDialog`, `ImportCompanyDetailsDialog`,
     `showNafezaDetailsDialog`, PO / CBM / scenario / consultation details) become the **body** of `EntityDetailsDialog`. They
     receive the record loaded by id instead of the list row.
3. **Addressing a record without routes:** `EntityRef(type: EntityType.purchaseOrder, id: 42)` +
   `EntityDetailsRegistry.open(context, ref, entityRef)`. Each feature registers its builder once
   (`registerEntityDetails(EntityType.x, (ctx, id) => XDetailsBody(id: id))`). Notifications, audit logs, the AI assistant and the
   command palette can then open any record's View. A later step can open a record as a workspace tab (open question Q4).
4. **Permission:** View needs `<module>.view` (the same permission the list route needs). Edit, Clone and Delete need
   `<module>.manage`, or the module's specific codes from `modules/auth/seed_rbac.py`. Codes are read once after login from
   `GET /auth/me/permissions` into `currentPermissionsProvider`. ADMIN = `*`.
5. **Read-only form mode is not the standard.** Forms carry validators, dirty-state guards and draft saving, so making them
   read-only is fragile. Use it only for very small master data (fewer than 6 fields) through a `readOnly: true` flag that
   disables every field and hides Save. The incoterm, cost item and location dialogs may use this as a quick fix
   (FEX-T10 lets the developer choose either).

### 4.3 Entity list

| Entity (screen) | View today | Evidence | Gap / why | What to add |
|---|---|---|---|---|
| Import file | Yes, list row dialog | `import_files_screen.dart:1618` | stale row; no by-id | Load `/import-files/{id}` (FEX-T09 pattern; phase owner) |
| Purchase order | Yes, list row | `purchase_orders_screen.dart:772, 4283` | stale; summary paging would break it | FE01-T26 on FEX-T09 |
| Supplier | Yes, `SupplierDetailsDialog` from row | `suppliers_screen.dart:441` | stale | load `/suppliers/{id}` |
| Import company | Yes, `ImportCompanyDetailsDialog` | `import_companies_screen.dart:416` | stale | load `/import-companies/{id}` |
| Partner (service provider) | Yes, `PartnerDetailsDialog` | `partners_screen.dart:704` | stale | load `/external-service-providers/{id}` |
| Customs tariff line | Yes, `showNafezaDetailsDialog` | `customs_tariff_screen.dart:453` | OK (row has all fields); by-id when list becomes summary | load `/customs-tariff/{id}` with FEX-T05 |
| Incoterm | **View = edit dialog** | `incoterms_screen.dart:478-479` | no details view built | read-only details (FEX-T10) |
| Incoterm cost item | **View = edit dialog** | `incoterms_screen.dart:1029-1030` | same | FEX-T10 |
| Transport location | **View = edit dialog** | `transport_locations_screen.dart:407-408, 442` | same; row tap also opens edit | FEX-T10 |
| Project | **View = audit history** | `projects_screen.dart:560-569` | history used as a stand-in | details + separate History action (FEX-T12) |
| Currency | **View = rate history** | `currencies_screen.dart:445` | acceptable content but wrong label | rename to "Rate history" action; View = currency details + latest rates (FEX-T12) |
| Financial settlement | **View = Odoo journal; Edit = recalculate** | `settlement_registry_card.dart:330-340` | wrong semantics; money recalculated without confirm | View = settlement details by id; "Recalculate" own action with confirm; "Odoo journal" own action (FEX-T12) |
| Smart task | **No** | `smart_tasks_screen.dart:447-490` | own icon row (complete/copy/print/edit/delete); delete without confirm | View + RowAction list (FEX-T11); `/smart-tasks/{id}` exists |
| Clearance price item | **No** | `customs_clearance_quotations_screen.dart:556-571` | copy + one-tap delete only | View + confirm delete (FEX-T11) |
| Clearance RFQ | card tap opens RFQ | `rfq_card.dart` | no explicit View | phase owner; use RowAction list |
| Broker price list | **No** (edit form as viewer) | phase-01 F01-30 | | phase-01 FE01-T27 on FEX-T09 |
| Freight RFQ | **No registry** | phase-01 F01-12 | nowhere to put actions | phase-01 FE01-T11 |
| Step config (lifecycle) | **No** | `step_config_management_screen.dart:246-261` | edit icons only | View with audit logs (`/step-configs/{code}/audit-logs` exists) (FEX-T20) |
| User | **No** | `users_management_screen.dart:1213-1260` | edit only | View: profile + effective permissions (FEX-T20) |
| Audit log entry | **No** (summary inline) | `audit_logs_screen.dart` | change diff not openable | View = `change_diff_dialog.dart` (exists in core) (FEX-T15) |
| CBM calc, Shipping scenario, Consultation, Budget, Payment request, Insurance certificate, Freight booking, File closure, GRN, Shipment update | Yes, list row dialogs | `saved_cbm_registry_tab.dart:366`, `saved_scenarios_registry_tab.dart:356`, `saved_consultations_tab.dart:680`, `saved_budgets_registry_tab.dart:442`, `financial_approval_screen.dart:5293`, `insurance_certificates_table.dart:125` (Print = View), `freight_booking_registry_row.dart:290`, `closure_record_card.dart:222`, `grn_record_card.dart:148`, `shipment_update_engine_screen.dart:533` | stale rows; some Print = View | by-id load per phase owner on FEX-T09 |

---

## 5. Tasks

Rules for every task (the executor has no other context):
- Flutter 3.x Windows desktop, Riverpod (`StateNotifier`), dio via `dioProvider`. Shared code lives in `frontend/lib/core/`.
- New user text goes into all three files: `frontend/lib/core/localization/app_localizations.dart` (abstract getter),
  `app_localizations_ar.dart`, `app_localizations_en.dart`. Read it with `context.l10n.x`. No hard-coded UI strings.
- Colors only from `AppTheme` (`frontend/lib/core/theme/app_theme.dart`), using the `*Of(context)` variants for dark mode.
- Only `EdgeInsetsDirectional` / `AlignmentDirectional`. Numbers and codes go in an LTR island.
- Show backend errors with `ApiError.message(e)` (`frontend/lib/core/network/api_error.dart`) in a SnackBar.
- Tests are flat files in `frontend/test/`. Run `flutter test <file>` from `frontend/`. Do not bump versions.
- Do not edit `.env`, `*.db`, or `version.json`.

### FEX-T01: Shared list query, page result and paged notifier base
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: none
- **Backend needed**: no (the client source works without it; the server source targets `/paginated` from §3.5)
- **Files to change**: new `frontend/lib/core/widgets/paged_data_table/list_query.dart`, new `.../page_result.dart`, new `.../paged_list_notifier.dart`, new `frontend/test/paged_list_notifier_test.dart`
- **Steps**:
  1. Write `ListQuery`, `PageResult<T>` and `PagedListState<T>` exactly as in section 3.4. `ListQuery.toQueryParameters()` drops null and empty filters and trims `q`.
  2. Write `abstract class PagedListNotifier<T> extends StateNotifier<PagedListState<T>>` with `load`, `refresh`, `setSearch` (350 ms `Timer` debounce), `setFilter`, `setSort`, `setPage`, `setPageSize`, `dispose`. Each setter except `setPage` sets `page` to 1. `load` cancels the previous `CancelToken`, sets `isLoading: true` and **keeps** `data`. On success it stores `data`; on error it stores `error` (ignore cancel errors).
  3. Add `ServerPagedSource` (GET `path` with `query.toQueryParameters()`, parse with `PageResult.fromJson`) and `ClientPagedSource<T>` (takes `Future<List<T>> Function()` + `bool Function(T, String q)` matcher + `Comparator<T> Function(String sortKey)`; it filters, sorts and slices locally and fills `total`/`totalPages`). The notifier takes a source in its constructor.
- **Acceptance criteria**:
  - [ ] A notifier with the client source over 1,234 items returns page 1 with 50 items, `total` 1234, `totalPages` 25.
  - [ ] Typing 5 characters quickly sends one request.
  - [ ] `refresh()` after `setFilter('status','Open')` requests with `status=Open` and the same page.
- **Tests to add**: `frontend/test/paged_list_notifier_test.dart`: client source paging/sort/search; server source with a fake dio `HttpClientAdapter` checks the query string (`page=2&page_size=50&sort=-created_at&q=abc&status=Open`); debounce with `fakeAsync`; error keeps old `data`.
- **Out of scope**: the widget (T02); any screen migration.

### FEX-T02: `PagedDataTable<T>` widget (virtualized, sticky header, pinned start columns)
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FEX-T01, FEX-T08 (`RowAction`)
- **Backend needed**: no
- **Files to change**: new `frontend/lib/core/widgets/paged_data_table/paged_table_column.dart`, new `.../paged_data_table.dart`, `frontend/lib/core/localization/app_localizations*.dart` (3 files: strings), new `frontend/test/paged_data_table_test.dart`
- **Steps**:
  1. `PagedTableColumn<T>` as in §3.4.
  2. Layout: `Column(toolbar, header, Expanded(body), CompactTablePaginationFooter)`. The body has a pinned pane (columns with `pinned: true`, start edge) and a scrolling pane inside a horizontal `Scrollbar` + `SingleChildScrollView` + `SizedBox(width: sum(widths))`. Both panes use `ListView.builder(itemExtent: ref.watch(densityProvider).rowHeight)`. Sync their vertical `ScrollController`s with listeners and a `_syncing` bool guard.
  3. The header row repeats the same widths, is outside the vertical scroll, has a solid background (`AppTheme.charcoal` at 6% opacity in light mode, `AppTheme.darkSurface` in dark mode), and a sort arrow on columns with `sortKey`. A tap cycles asc / desc / none and calls `onQueryChanged(query.copyWith(sort: ...))`.
  4. Toolbar: search `TextField` (calls the notifier `setSearch` via `onQueryChanged`), the `toolbarFilters` slot, total count, refresh, column picker (reuse `EnterpriseTableColumnPickerDialog`), and export buttons (export all pages through the given exporter callback: see §3.4).
  5. States: shimmer on first load (`EnterpriseTableShimmerSkeleton`); a thin progress bar on later loads; error with `ApiError.message` + Retry; empty vs no-results messages.
  6. Keyboard: `Focus` + `Shortcuts`/`Actions` for Up/Down/Enter/PageUp/PageDown/Ctrl+F/Delete as in §3.4. Enter and double-click call `onOpen` or the view `RowAction`.
  7. Persist widths, visibility and page size under `paged_table_<storageKey>_*` (copy the logic from `enterprise_data_table.dart:128-184`).
  8. When `MediaQuery` width is under 768, render a card `ListView.builder` with the same actions.
- **Acceptance criteria**:
  - [ ] With 5,000 rows in a client source and page size 100, scrolling is smooth and fewer than 40 row widgets exist.
  - [ ] The header stays visible on vertical scroll. The actions and code columns stay at the start edge on horizontal scroll, in both Arabic and English.
  - [ ] A sort tap changes `query.sort`. A footer page change calls `setPage`.
  - [ ] Error shows the backend `detail` and Retry reloads.
- **Tests to add**: `frontend/test/paged_data_table_test.dart`: pump with 1,000 items in the state and assert `find.byType(<RowWidget>)` count < 60; tap the sortable header → callback receives `sort: 'code'`, then `'-code'`; RTL pump: the pinned pane is at the right (`tester.getTopLeft` x greater than the scroll pane x); Enter on the focused row calls `onOpen`.
- **Out of scope**: migrating screens (T05+); multi-sort.

### FEX-T03: Backend contract doc for list paging and lookups
- **Severity**: MINOR
- **Type**: refactor (documentation)
- **Depends on**: none
- **Backend needed**: no (document only; backend tasks implement it)
- **Files to change**: new `docs/standards/list-paging-contract.md`
- **Steps**:
  1. Copy §3.5 and §3.6 of this report into the doc: query parameters, response envelope, sort whitelist, error code `LIST_SORT_FIELD_INVALID`, stable PK tiebreak, `/lookup` shape, export route, auth rule, summary schemas.
  2. Add a "per entity" table with the sort keys and filters for: customs tariff, audit logs, purchase orders, payment requests, smart tasks, transport locations, partners, projects.
- **Acceptance criteria**:
  - [ ] Backend and frontend developers can implement `/paginated` for a new entity from the doc alone.
- **Tests to add**: none (doc).
- **Out of scope**: implementing endpoints.

### FEX-T04: Stop silent truncation of capped lists
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart`, `frontend/lib/features/cargox/providers/cargox_provider.dart`, `frontend/lib/features/experience_guide/providers/experience_guide_provider.dart`, `frontend/lib/features/import_documentation/providers/original_documents_collection_provider.dart`, `frontend/lib/features/audit_logs/providers/audit_logs_provider.dart` (+ l10n files for one string, + one shared banner widget `frontend/lib/core/widgets/list_truncated_banner.dart`)
- **Steps**:
  1. Send `limit: 500` explicitly in: RFQs (`customs_clearance_quotations_provider.dart:26`), CargoX envelopes (`cargox_provider.dart:40`) and standard-invoice sessions (`:190`), Experience guide (`experience_guide_provider.dart:80`), Original docs sessions (`original_documents_collection_provider.dart:46`), Audit logs (`audit_logs_provider.dart:26`: `limit=500`).
  2. Each notifier exposes `bool isTruncated` = `items.length >= 500`.
  3. New `ListTruncatedBanner(count: 500)`: orange (`AppTheme.orange`) strip with text l10n `listTruncatedBanner(count)` = "Showing the first {count} records. Use search or filters to find older records." / Arabic. Place it above each list (the screens that read these providers: `customs_clearance_quotations_screen.dart`, `cargox_hub_screen.dart`, `standard_invoice_hub_tab.dart`, `experience_guide_management_dialog.dart`, `original_documents_collection_tab.dart`, `audit_logs_screen.dart`). If more than 5 files are needed, split the screen edits into a follow-up.
  4. Audit logs: send the search text to the backend if it supports it. It does not today (B4), so keep the client search but show the banner.
- **Acceptance criteria**:
  - [ ] With 600 RFQs in the DB, the RFQ list shows 500 rows and the orange banner.
  - [ ] With 50 rows, no banner.
- **Tests to add**: `frontend/test/list_truncation_test.dart`: fake adapter returns 500 items → notifier `isTruncated` true; banner widget renders the l10n text in `ar` and `en`.
- **Out of scope**: real paging for these lists (phase owners after FEX-T02).

### FEX-T05: Customs tariff on server paging
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: FEX-T01, FEX-T02
- **Backend needed**: yes: `GET /api/v1/customs-tariff/paginated?page&page_size&sort&q&include_inactive&customs_category` returning `{items,total,page,page_size,total_pages}` (B1). Until then, use `skip/limit` on the existing route and compute `hasNext` by asking `limit = pageSize + 1` (show "page N" without the total).
- **Files to change**: `frontend/lib/features/customs_tariff/providers/customs_tariff_provider.dart`, `frontend/lib/features/customs_tariff/screens/customs_tariff_screen.dart`, new `frontend/lib/features/customs_tariff/widgets/customs_tariff_columns.dart`, `frontend/test/customs_tariff_paging_test.dart`
- **Steps**:
  1. Add `customsTariffPagedProvider = StateNotifierProvider.autoDispose<CustomsTariffPagedNotifier, PagedListState<CustomsTariffModel>>` extending `PagedListNotifier` (server source, path `/customs-tariff/paginated`, default sort `hs_code`, page size 50).
  2. Move the 7 cell builders from `_buildTariffTable` (`customs_tariff_screen.dart:346-500`) into `customs_tariff_columns.dart` as `List<PagedTableColumn<CustomsTariffModel>>`. Pin the actions and HS code columns. The HS code column is `numeric` (LTR).
  3. Replace `_buildTariffTable` with `PagedDataTable`. The row actions are View (`showNafezaDetailsDialog`), Edit, Print and Delete as `RowAction`s, keeping the existing callbacks (`:453-470`).
  4. After create/edit/delete, call `ref.read(customsTariffPagedProvider.notifier).refresh()`. Keep the old `customsTariffProvider` for other callers (HS search screen, pickers).
  5. Replace `Colors.white` / `Colors.grey.shade200` (`:355-357`) with `AppTheme.surfaceOf(context)` / `AppTheme.borderOf(context)`.
- **Acceptance criteria**:
  - [ ] Opening the tariff screen requests one page of 50 and renders quickly with a sticky header.
  - [ ] Searching "8471" requests `q=8471` once (debounced) and shows the server total.
  - [ ] Edit then save keeps the current search and page.
- **Tests to add**: `frontend/test/customs_tariff_paging_test.dart`: fake adapter asserts `page=1&page_size=50&sort=hs_code`; second page request `page=2`; refresh after edit keeps `q`.
- **Out of scope**: HS code search screen (`hs_code_search_screen.dart`); tariff pickers.

### FEX-T06: Import files list keeps its filters on every refresh
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none (FEX-T01 optional: if it exists, extend it; otherwise add the query to the existing state)
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/import_files/providers/import_files_provider.dart`, `frontend/lib/features/import_files/screens/import_files_screen.dart`, `frontend/test/import_files_query_state_test.dart`
- **Steps**:
  1. In `PaginatedImportFilesState` add `search`, `status`, `owner`, `companyId`, `supplierId`. `fetchPage(page, {...})` stores the given filters in state. Add `refresh()` = `fetchPage(state.page)` with the **stored** filters, and `setFilters({...})` = store the filters, then `fetchPage(1)`. Fix `nextPage`/`prevPage` (`:116-127`) to use the stored filters.
  2. In `import_files_screen.dart` replace every `fetchPage(paginatedState.page)` / `fetchPage(1)` refresh call (`:1205, 1312, 1561, 1573, 1599, 1644, 2099, 2111`) with `refresh()`. Replace the search/status handlers (`:2372-2375, 2433-2460`) with `setFilters(...)`.
  3. In the mount code (`:1098-1101`), if `widget.initialSearchQuery` is set, call `setFilters(search: widget.initialSearchQuery)` instead of `fetchPage(1)`.
- **Acceptance criteria**:
  - [ ] Search "IMP-2026", status "Open", then clone a file: the list still shows only the matching open files.
  - [ ] Opening Import files from a deep link with a search query shows the filtered list on first paint.
  - [ ] The header Refresh keeps the current filters and page.
- **Tests to add**: `frontend/test/import_files_query_state_test.dart`: fake adapter records requests; `setFilters(search:'X')` then `refresh()` → both requests contain `search=X`; `nextPage()` keeps `status`.
- **Out of scope**: replacing the table body (FEX-T17).

### FEX-T07: EnterpriseDataTable correctness, export and l10n
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/core/widgets/enterprise_data_table/enterprise_data_table.dart`, `.../widgets/enterprise_table_pagination_bar.dart`, `.../widgets/enterprise_table_header_toolbar.dart`, `.../widgets/enterprise_table_column_picker_dialog.dart`, `frontend/lib/core/localization/app_localizations*.dart`
- **Steps**:
  1. Cache: add `List<T>? _cache` with a key (`identityHashCode(widget.data)`, `_searchQuery`, `_sortColumnId`, `_isAscending`). Recompute only when the key changes. `build`, `_pagedData` and select-all read the cache.
  2. Remove the "All" (`-1`) page size item (`enterprise_table_pagination_bar.dart:87-90`). If a saved page size is not in `availablePageSizes`, fall back to `initialPageSize`.
  3. Sorting: when there is no `sortComparator` and the column `isNumeric`, compare `num.tryParse` of the export value; add an `assert` in `EnterpriseColumn` that date columns pass a comparator (or document it).
  4. Export: `allowedExtensions: ['csv']` only (`:328`). Add a required-when-export `exportStageName` parameter. File name = `'$exportStageName - ${exportCode ?? title}.csv'`. PDF uses the same `stageName` (`:378`).
  5. Move every Arabic literal (l.67, 305, 327, 355, 377, 389, 543, 556; pagination bar 64, 89, 98; toolbar; picker) to l10n getters (`tableNoData`, `tableNoDataToExport`, `tableCopiedRows(count)`, `tableRowsPerPage`, `tableShowingRange(start,end,total)`, `tableNoResultsFor(query)`, `tableClearSearch`, ...). Replace `Color(0xFFEEF2F6)`, `Color(0xFFF1F5F9)` and `Colors.grey.shade*` with `AppTheme` tokens.
  6. Update the only caller `smart_tasks_screen.dart:801` to pass `exportStageName: context.l10n.smartTasksTableTitle` (6th file, one line).
- **Acceptance criteria**:
  - [ ] In English, every table text is English. In Arabic, every table text is Arabic.
  - [ ] Export offers only CSV and the default name is "Smart Tasks - Smart Tasks.csv" (or the stage name given).
  - [ ] Typing in the search box filters a 2,000-row list without visible lag.
- **Tests to add**: `frontend/test/enterprise_data_table_test.dart`: page-size menu has no "All"; numeric sort orders 9 < 100; en locale shows no Arabic characters (regex `[؀-ۿ]` not found in the rendered texts).
- **Out of scope**: server paging (that is `PagedDataTable`).

### FEX-T08: RowAction model, RowActionsBar and shared confirm (replaces RowActionsPill internals)
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FEX-T13 for permission hiding (without it, the `permission` field is ignored)
- **Backend needed**: no
- **Files to change**: new `frontend/lib/core/widgets/paged_data_table/row_action.dart`, `frontend/lib/core/widgets/row_actions_pill.dart`, `frontend/lib/core/widgets/buttons/icon_action_button.dart`, `frontend/lib/core/widgets/row_context_menu.dart`, l10n files
- **Steps**:
  1. Write `RowActionKind` and `RowAction<T>` (§3.4). Add `RowActionsBar<T>(row, actions)`, which renders the actions in fixed order (view, edit, clone, print, history, delete), then custom actions in a `⋮` `PopupMenuButton`.
  2. Hide an action whose `permission` the user lacks (`ref.watch(currentPermissionsProvider).can(code)` when T13 exists). Show `disabledReason` as the tooltip of a disabled button.
  3. `confirm: true` (default for delete) shows a shared `showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage(code))` (crimson confirm button). After `run` returns, show a green SnackBar; on error, a red SnackBar with `ApiError.message(e)`.
  4. Keep `RowActionsPill` as a thin adapter: it builds `RowAction`s from its callbacks and **hides** null ones (no more grey eye); remove the fake Print SnackBar (`row_actions_pill.dart:86-95`). Existing callers keep compiling.
  5. `IconActionButton`: disabled colors from `AppTheme.surfaceAltOf(context)` / `AppTheme.textMutedOf(context)`; `withValues` instead of `withOpacity`; drop the `color.red` math.
  6. `RowContextMenuHelper`: build the menu from the same `List<RowAction<T>>` (View first) + "Copy code"; all labels from l10n.
- **Acceptance criteria**:
  - [ ] A row without a view callback shows no eye icon.
  - [ ] Delete from any `RowActionsPill` asks for confirmation once (screens that already confirm must pass `confirm: false` or their own confirm is removed: check each pill caller's `onDelete` for an existing `showDialog` and set the flag accordingly).
  - [ ] The right-click menu shows View, Edit, Copy code, Deactivate in the UI language.
- **Tests to add**: `frontend/test/row_actions_bar_test.dart`: null actions hidden; disabled reason tooltip; delete shows the confirm dialog and runs only on confirm; error SnackBar text = backend `detail`.
- **Out of scope**: wiring View into each screen (T10-T12, phase owners).

### FEX-T09: EntityDetailsDialog + by-id providers + EntityRef registry
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FEX-T08
- **Backend needed**: no (GET by id routes exist)
- **Files to change**: new `frontend/lib/core/widgets/entity_details/entity_ref.dart`, new `.../entity_details_dialog.dart`, new `.../details_section.dart`, l10n files, new `frontend/test/entity_details_dialog_test.dart`
- **Steps**:
  1. `enum EntityType { importFile, purchaseOrder, supplier, importCompany, partner, project, currency, incoterm, costItem, transportLocation, customsTariff, smartTask, clearancePriceItem, settlement, ... }` and `class EntityRef { final EntityType type; final int id; }`.
  2. `EntityDetailsRegistry` (static map `EntityType → Widget Function(BuildContext, int id)`) with `register` and `open(BuildContext, EntityRef)`. Each feature registers its body in its own file (follow-up tasks).
  3. `EntityDetailsDialog.show(context, {required String title, required AsyncValue<T> value, required Widget Function(T) body, List<RowAction<T>> footerActions, VoidCallback onRetry})`: a side sheet at the start edge on width ≥ 1200 (560 px), otherwise a centered dialog (max 720 px). It shows loading (shimmer), error (`ApiError.message` + Retry), 404 (l10n "record not found or deleted") and data.
  4. `DetailsSection(title, children)` and `DetailsField(label, value, {bool copyable = true, bool ltr = false})`: two-column grid on wide screens; `—` for null; copy button via `CopyHelper.copy`.
  5. Footer: Edit / Print / History / Close from the given `RowAction`s (permission rules apply).
  6. Document the pattern in the dialog's doc comment: "Each feature adds `final xByIdProvider = FutureProvider.autoDispose.family<XModel, int>((ref, id) async => XModel.fromJson((await ref.watch(dioProvider).get('${ApiConstants.x}/$id')).data));`".
- **Acceptance criteria**:
  - [ ] A test body registered for `EntityType.supplier` opens from `EntityDetailsRegistry.open` with a loading state, then data.
  - [ ] 404 shows the l10n "not found" text, not an exception.
  - [ ] RTL: the sheet opens from the right.
- **Tests to add**: `frontend/test/entity_details_dialog_test.dart`: loading → data; error → Retry calls `onRetry`; 404 text; Edit hidden without permission.
- **Out of scope**: per-entity bodies (T10-T12 and phase owners).

### FEX-T10: Real View for Incoterms, Cost items and Transport locations
- **Severity**: MAJOR
- **Type**: ux
- **Depends on**: FEX-T09
- **Backend needed**: no (`GET /incoterms/{id}`, `/cost-items/{id}`, `/transport-locations/{id}` exist)
- **Files to change**: `frontend/lib/features/incoterms/providers/incoterms_provider.dart`, `frontend/lib/features/incoterms/screens/incoterms_screen.dart`, `frontend/lib/features/transport_locations/providers/transport_locations_provider.dart`, `frontend/lib/features/transport_locations/screens/transport_locations_screen.dart`, l10n files
- **Steps**:
  1. Add `incotermByIdProvider`, `costItemByIdProvider` and `transportLocationByIdProvider` (FutureProvider.autoDispose.family, by id).
  2. Add `_showIncotermDetails`, `_showCostItemDetails` and `_showLocationDetails` that open `EntityDetailsDialog` with read-only `DetailsField`s (all model fields; codes not ids; booleans as Yes/No l10n). The footer Edit opens the existing edit dialog.
  3. Wire `onView` to the details (`incoterms_screen.dart:478, 1029`; `transport_locations_screen.dart:407`). Row tap on locations (`:442`) opens View, not Edit.
- **Acceptance criteria**:
  - [ ] Clicking the eye on an incoterm opens a read-only sheet with no Save button.
  - [ ] Editing from the sheet's Edit button saves and refreshes the list.
- **Tests to add**: `frontend/test/master_data_view_test.dart`: tap View on a location row → no `TextFormField` in the sheet; Edit button opens the form.
- **Out of scope**: list paging for these screens.

### FEX-T11: View and safe delete for Smart tasks and Clearance price items
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: FEX-T08, FEX-T09
- **Backend needed**: no (`GET /smart-tasks/{task_id}` exists; for price items, a View from the row data is fine: the row has every field)
- **Files to change**: `frontend/lib/features/smart_tasks/screens/smart_tasks_screen.dart`, `frontend/lib/features/smart_tasks/providers/smart_tasks_provider.dart`, `frontend/lib/features/customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart`, l10n files
- **Steps**:
  1. Smart tasks (`smart_tasks_screen.dart:447-490`): replace the icon row with `RowActionsBar<SmartTaskModel>`: View (new `smartTaskByIdProvider` + `EntityDetailsDialog` showing code, type, title, linked shipment code, priority, reminder, due date, status, description), Edit, Print, Delete (`confirm: true`), and Complete + Copy as custom actions.
  2. Make `deleteTask` return or throw the error so the bar can show it.
  3. Clearance price items (`customs_clearance_quotations_screen.dart:556-571`): `RowActionsBar` with View (details from the row), Copy (custom), Delete (`confirm: true`).
- **Acceptance criteria**:
  - [ ] Delete on a smart task or price item asks for confirmation; Cancel keeps the row.
  - [ ] A failed delete shows the backend message.
  - [ ] View shows the task in read-only form.
- **Tests to add**: `frontend/test/smart_tasks_row_actions_test.dart`: tap delete → confirm dialog; cancel → no DELETE request (fake adapter).
- **Out of scope**: smart tasks server paging (FEX-T18).

### FEX-T12: One meaning per icon in Projects, Currencies and Settlements
- **Severity**: MAJOR
- **Type**: ux
- **Depends on**: FEX-T08, FEX-T09
- **Backend needed**: no (`/projects/{id}`, `/currencies/{id}`, `/financial-settlement/{id}` exist)
- **Files to change**: `frontend/lib/features/projects/screens/projects_screen.dart`, `frontend/lib/features/currencies/screens/currencies_screen.dart`, `frontend/lib/features/financial_settlement/widgets/settlement_registry_card.dart`, `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`, l10n files
- **Steps**:
  1. Projects (`projects_screen.dart:560-569`): View = project details by id (code, name, company code+name, supplier, incoterm, categories, status, dates); History = separate `RowActionKind.history` running `RowHistoryDialog.show`.
  2. Currencies (`currencies_screen.dart:445`): View = currency details (code, name, symbol, base flag, latest rate with date); "Rate history" = custom action with the existing `_showCurrencyRateHistoryDialog`.
  3. Settlements (`settlement_registry_card.dart:329-345`): View = settlement details by id; "Odoo journal" = custom action (`onOpenJournal`); "Recalculate" = custom action with confirm text "Recalculate landed cost for {code}? Amounts will change." It awaits `recalculateSettlement`, then shows success or error (remove the SnackBar that is shown before the call); "Copy breakdown" = custom action (not Print). Remove the Edit pencil if settlements have no edit form.
- **Acceptance criteria**:
  - [ ] The pencil never triggers a recalculation.
  - [ ] Recalculate asks first and reports the real result.
  - [ ] The eye always opens read-only details.
- **Tests to add**: `frontend/test/settlement_row_actions_test.dart`: recalculate requires confirm; success SnackBar only after the fake POST completes.
- **Out of scope**: settlement math.

### FEX-T13: Current-user permissions in the UI
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: none
- **Backend needed**: no (`GET /api/v1/auth/me/permissions` exists, `modules/auth/router.py:186`, returns `effective_permissions`)
- **Files to change**: new `frontend/lib/features/auth/providers/current_permissions_provider.dart`, `frontend/lib/features/auth/providers/auth_provider.dart` (invalidate on login/logout), new `frontend/lib/core/widgets/permission_gate.dart`, new `frontend/test/current_permissions_test.dart`
- **Steps**:
  1. `class PermissionSet { final Set<String> codes; bool can(String code) => codes.contains('*') || codes.contains(code); }`.
  2. `currentPermissionsProvider = FutureProvider<PermissionSet>` that GETs `/auth/me/permissions` and reads `effective_permissions`. While loading or on error, return an empty set (deny by default) for edit actions only; view actions stay visible (the backend still enforces).
  3. Invalidate it on login, logout and token user change in `auth_provider.dart`.
  4. `PermissionGate(code, child, {fallback})` widget.
  5. `RowActionsBar` (T08) reads it to hide actions.
- **Acceptance criteria**:
  - [ ] An OPERATOR without `purchase_orders.manage` sees no Edit/Delete on PO rows (once the screen passes permissions).
  - [ ] ADMIN (`*`) sees everything.
- **Tests to add**: `frontend/test/current_permissions_test.dart`: `*` grants any code; parse of the backend JSON; error → empty set.
- **Out of scope**: adding `permission:` to every screen (each migration task does it).

### FEX-T14: Remote search for SearchableDropdownField + import-file lookup
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: none
- **Backend needed**: yes: `GET /api/v1/import-files/lookup?q=&limit=20&ids=` → `[{id, code, label, is_active}]` (B3). Interim: `GET /import-files/paginated?search=q&page_size=20` and map items.
- **Files to change**: `frontend/lib/core/widgets/searchable_dropdown_field.dart`, new `frontend/lib/features/import_files/providers/import_file_lookup_provider.dart`, `frontend/test/searchable_dropdown_remote_test.dart`
- **Steps**:
  1. Add a named constructor `SearchableDropdownField.remote({required Future<List<SearchableDropdownItem<T>>> Function(String q) search, required Future<SearchableDropdownItem<T>?> Function(T value) resolve, ...same decoration/validator params})`. Debounce 300 ms; show a spinner while searching; show "type to search" hint and at most 20 results; resolve the label of the initial value.
  2. `importFileLookupProvider` with `search(q)` and `resolve(id)` using the interim endpoint.
  3. Do not migrate callers in this task; list the 3 highest-traffic import-file pickers in the PR description for follow-ups.
- **Acceptance criteria**:
  - [ ] Typing "IMP-26" sends one request after 300 ms and lists matches.
  - [ ] A form opened with an existing file id shows its code without loading all files.
- **Tests to add**: `frontend/test/searchable_dropdown_remote_test.dart`: debounce, result list, resolve of the initial value.
- **Out of scope**: migrating the 91 callers.

### FEX-T15: Audit logs on server paging with filters and change View
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FEX-T01, FEX-T02, FEX-T09
- **Backend needed**: yes: `GET /api/v1/audit-logs/paginated?page&page_size&sort=-performed_at&q&entity_type&performed_by&date_from&date_to` (B1, B4), protected by `audit_logs.view`
- **Files to change**: `frontend/lib/features/audit_logs/providers/audit_logs_provider.dart`, `frontend/lib/features/audit_logs/screens/audit_logs_screen.dart`, new `frontend/lib/features/audit_logs/widgets/audit_log_columns.dart`, `frontend/test/audit_logs_paging_test.dart`
- **Steps**:
  1. `auditLogsPagedProvider` on `PagedListNotifier` (server source).
  2. Replace the card list with `PagedDataTable`: columns time, user, entity type, entity code, action, summary. Filters: entity type and user (`SearchableDropdownField`), date range.
  3. View = existing `core/widgets/change_diff_dialog.dart` for the row. An "Open record" custom action uses `EntityDetailsRegistry.open` when the entity type is registered.
  4. Export uses the backend export or the page loop (§3.4).
- **Acceptance criteria**:
  - [ ] Searching an entity code from last year finds it.
  - [ ] The footer shows the real total.
- **Tests to add**: `frontend/test/audit_logs_paging_test.dart`: query string with filters; View opens the diff dialog.
- **Out of scope**: backend.

### FEX-T16: Backend error text instead of raw exceptions
- **Severity**: MINOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change** (batch 1, ≤5 files): `frontend/lib/features/cargox/widgets/standard_invoice_hub_tab.dart`, `frontend/lib/features/system_observability/screens/system_observability_screen.dart`, `frontend/lib/features/import_files/screens/import_files_screen.dart`, `frontend/lib/features/import_files/widgets/visual_container_load_planner_dialog.dart`, `frontend/lib/features/comprehensive_report/screens/import_file_comprehensive_report_screen.dart`
- **Steps**:
  1. Find `$e` / `${e}` / `$err` inside `Text(` or `SnackBar(` (`grep -nE '\$(e|err|error)(\b|\})'`).
  2. Replace with `ApiError.message(e, fallback: context.l10n.genericErrorMessage)`. Keep the l10n prefix. Use `AppTheme.crimson` instead of `Colors.red`.
  3. Batch 2 (separate session): the remaining 15 files from the same grep.
- **Acceptance criteria**:
  - [ ] A 400 from the backend shows its `detail` text, not `DioException [bad response]`.
- **Tests to add**: extend `frontend/test/api_error_test.dart` only if a new helper is added; otherwise none.
- **Out of scope**: provider-level error state redesign.

### FEX-T17: Import files table body on PagedDataTable
- **Severity**: MINOR
- **Type**: refactor
- **Depends on**: FEX-T02, FEX-T06
- **Backend needed**: no (`/import-files/paginated` exists; add `sort` later)
- **Files to change**: `frontend/lib/features/import_files/screens/import_files_screen.dart`, new `frontend/lib/features/import_files/widgets/import_file_columns.dart`, `frontend/lib/features/import_files/providers/import_files_provider.dart`, `frontend/test/import_files_table_test.dart`
- **Steps**:
  1. Move the 13 column cell builders (`import_files_screen.dart:1420-1840`) to `import_file_columns.dart`. Keep the widths (`colActionsWidth` etc.). Pin the actions and file code columns.
  2. Replace the two-`DataTable` sticky trick (`:1440-1510`) and the footer (`:1860`) with `PagedDataTable`. Row actions via `RowActionsBar` with the existing callbacks.
  3. Delete the dummy body columns and the `Directionality` scrollbar trick.
- **Acceptance criteria**:
  - [ ] The same columns, actions, highlight of `highlightedFileId` and density sizes as before.
  - [ ] Header sticky; actions column pinned at the start edge.
- **Tests to add**: `frontend/test/import_files_table_test.dart`: renders a page of 50 from a fake state; tapping View opens the details dialog.
- **Out of scope**: master report dialog.

### FEX-T18: Smart tasks on server paging
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FEX-T01, FEX-T02, FEX-T11
- **Backend needed**: yes: `GET /api/v1/smart-tasks/paginated` with filters `task_type,status,priority,import_file_id,q` and sorts `due_date,priority,created_at` (B1)
- **Files to change**: `frontend/lib/features/smart_tasks/providers/smart_tasks_provider.dart`, `frontend/lib/features/smart_tasks/screens/smart_tasks_screen.dart`, `frontend/test/smart_tasks_paging_test.dart`
- **Steps**:
  1. `smartTasksPagedProvider` (server source, default sort `due_date`).
  2. Convert `_buildColumns` (`smart_tasks_screen.dart:170-495`) from `EnterpriseColumn` to `PagedTableColumn`; keep selection + bulk complete (selection keyed by `taskId`).
  3. Metrics at the top come from `/smart-tasks/metrics/summary` (exists), not from the loaded list.
- **Acceptance criteria**:
  - [ ] 10,000 tasks: the screen loads one page; bulk complete works on the selected rows of the page.
- **Tests to add**: `frontend/test/smart_tasks_paging_test.dart`: query string; bulk complete sends only the selected ids.
- **Out of scope**: reminders.

### FEX-T19: Transport locations, Partners and Projects on PagedDataTable
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FEX-T02, FEX-T10, FEX-T12
- **Backend needed**: yes for server mode (`/paginated` per entity, B1); works in client mode first
- **Files to change**: `frontend/lib/features/transport_locations/screens/transport_locations_screen.dart`, `frontend/lib/features/external_service_providers/screens/partners_screen.dart`, `frontend/lib/features/projects/screens/projects_screen.dart` (+ their providers if the server source is used: split into one session per screen if over 5 files)
- **Steps**:
  1. Replace the `Table` blocks (`transport_locations_screen.dart:337-382`, `partners_screen.dart:545-588`, `projects_screen.dart:485-535`) with `PagedDataTable` in client mode (`ClientPagedSource` over the existing provider list).
  2. Remove the screen-local `_currentPage/_pageSize` slicing (`transport_locations_screen.dart:30-31, 305-310`).
  3. When B1 lands for an entity, switch its source to server mode (one line).
- **Acceptance criteria**:
  - [ ] Sticky header + pinned actions on all three screens; search and sort work; counts correct.
- **Tests to add**: `frontend/test/master_data_tables_test.dart`: each screen renders with 300 fake rows and builds fewer than 60 rows.
- **Out of scope**: suppliers and import companies (card lists, already virtualized).

### FEX-T20: View for Step configs and Users
- **Severity**: MINOR
- **Type**: ux
- **Depends on**: FEX-T09
- **Backend needed**: no (`/lifecycle-board/step-configs/{step_code}` and `/{step_code}/audit-logs` exist; the users list row carries the profile; effective permissions come from the users admin API already used by `rbac_provider.dart`)
- **Files to change**: `frontend/lib/features/lifecycle_board/screens/step_config_management_screen.dart`, `frontend/lib/features/lifecycle_board/providers/step_config_provider.dart`, `frontend/lib/features/auth/screens/users_management_screen.dart`, l10n files
- **Steps**:
  1. Step configs (`:246-261`): add View (details + audit log list) before Edit.
  2. Users (`:1213-1260`): add View (profile, role, active, effective permissions grouped by module) before Edit.
- **Acceptance criteria**:
  - [ ] Both lists have an eye action that opens a read-only sheet.
- **Tests to add**: `frontend/test/step_config_view_test.dart`: View opens with the audit list.
- **Out of scope**: editing permissions.

---

## 6. Backend dependencies (short)

| id | Need | For |
|---|---|---|
| B1 | `modules/common/pagination.py` (`Page[T]`, `paginate()`), then `/paginated` routes per entity with `page ge=1`, `page_size 1..200`, sort whitelist, `q`, `total`. Priority: customs tariff, audit logs, purchase orders (summary rows), payment requests, smart tasks, transport locations, CargoX envelopes, clearance RFQs, original docs sessions. Also bound the existing `import_files/router.py:97-98`. | FEX-T05, T15, T18, T19, FE01-T23 |
| B2 | `<Entity>ListItem` summary schemas (no nested line items) for paged lists | PO and budget lists |
| B3 | `/lookup?q&limit&ids` for import files, POs, suppliers, companies, partners, HS codes | FEX-T14 |
| B4 | Audit logs: search + filters (entity type, user, date) + `require_permission("audit_logs.view")` (today only `get_current_user`, `modules/audit_logs/router.py:9-13`) | FEX-T15 |
| B5 | Server export routes that accept the same filters as `/paginated` (`/<entity>/export-excel?...`) | full-set export |

## 7. Open questions for the CTO

1. **Grid engine.** May we add the first-party Flutter package `two_dimensional_scrollables` (publisher flutter.dev) for `TableView`?
   It gives lazy rows and columns with pinned header and pinned columns out of the box. Without it, FEX-T02 builds pinned columns
   with two synced `ListView`s (works, but more code).
2. **Contract choice.** Phase-01 proposed `limit/offset` + `X-Total-Count` header. This report proposes the `/paginated`
   envelope `{items,total,page,page_size,total_pages}` because `/import-files/paginated` already uses it. Please confirm one,
   so all backend tasks follow it.
3. **Defaults.** Page size 50 (25/50/100 options, no "All") and newest first on every list? Should metric cards above a list show
   totals for the full filtered set (needs a backend summary per list) or say "this page"?
4. **Records as tabs.** Should View be a side sheet only (proposal), or should a record be able to open as its own workspace tab
   (needs per-record tabs in `workspace_tabs_provider.dart` or adopting go_router routes like `/purchase-orders/:id`)?
5. **Export limit.** Is 10,000 rows the right cap for a client-side full export before we require a backend export route?
