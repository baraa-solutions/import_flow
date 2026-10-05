# Phase 01 Import planning: frontend review

Status: 2026-10-05, static review only (no flutter test, no pytest, no `import main`, no code edited).
Scope: BP-001..BP-011 screens. Navigation is an `IndexedStack` of const screens in `frontend/lib/features/home/home_screen.dart:98-190`
(not go_router): `2 = PurchaseOrdersScreen`, `3 = CBMCalculatorScreen`, `4/5 = ShippingScenariosScreen (tab 0 study / tab 1 saved)`,
`6/7/55/56 = CustomsConsultationScreen`, `43 = ImportRequirementsScreen`, `49 = FreightQuotationsScreen`. Sidebar entries:
`home_screen.dart:885, 899-901, 1001-1002`.
Previous plan: `docs/plans/phase-01-quality-simplify-plan.md` (backend items mostly done per `docs/plans/phase-01-progress.md`;
FE-01 `ref.invalidate` is now covered by `PurchaseOrdersNotifier.refreshAfterMutation` and `test/features/purchase_orders_mutation_refresh_test.dart`;
FE-03 raw buttons are fixed in PO/CBM/SS/CC/IR; PO-01 `item_id` / `packing_item_id` are now sent by `purchase_order_model.dart:195,376`).

Coverage depth:

| file | lines | depth |
|---|---|---|
| `frontend/lib/features/purchase_orders/providers/purchase_orders_provider.dart` | 268 | full |
| `frontend/lib/features/purchase_orders/screens/purchase_orders_screen.dart` | 4564 | partial: l.1-1070 full (list, toolbar, table, row actions), rest grep |
| `frontend/lib/features/purchase_orders/widgets/po_form_dialog.dart` | 4475 | partial: FX rate, validators, save payload, Arabic literals (grep + l.300-340, 2008-2024, 3380-3400) |
| `frontend/lib/features/purchase_orders/models/purchase_order_model.dart` | 664 | json keys vs `modules/purchase_orders/schemas.py` (scripted diff) |
| `frontend/lib/features/cbm_calculator/providers/cbm_calculator_provider.dart` | 228 | full |
| `frontend/lib/features/cbm_calculator/widgets/saved_cbm_registry_tab.dart` | 2703 | partial: l.40-370, 640-750, 1655-1680, exports grep |
| `frontend/lib/features/cbm_calculator/screens/cbm_calculator_screen.dart` | 2247 | grep (initState, error, mutations) |
| `frontend/lib/features/shipping_scenarios/providers/shipping_scenarios_provider.dart` | 198 | grep (copyWith, mutations) |
| `frontend/lib/features/shipping_scenarios/widgets/saved_scenarios_registry_tab.dart` | 1711 | partial: l.59-300, 1320-1356, mutations |
| `frontend/lib/features/shipping_scenarios/screens/shipping_scenarios_screen.dart` | 4416 | partial: l.269-400 (init, FX conversion), grep |
| `frontend/lib/features/customs_consultation/providers/customs_consultation_provider.dart` | 514 | partial: l.240-370 full, rest grep |
| `frontend/lib/features/customs_consultation/screens/customs_consultation_screen.dart` | 3797 | partial: l.450-470, 732-1000 (client tax engine), 1490-1560 (save payload) |
| `frontend/lib/features/customs_consultation/widgets/saved_consultations_tab.dart` | 1126 | partial: l.40-610 grep + reads |
| `frontend/lib/features/customs_consultation/widgets/broker_price_lists_tab.dart` | 1156 | partial: l.186-300, 575-680 |
| `frontend/lib/features/import_requirements/providers/import_requirements_provider.dart` | 120 | full |
| `frontend/lib/features/import_requirements/screens/import_requirements_screen.dart` | 3132 | partial: l.2008-2400 (registry) full, rest grep |
| `frontend/lib/features/freight_quotations/providers/freight_quotations_provider.dart` | 112 | full |
| `frontend/lib/features/freight_quotations/screens/freight_quotations_screen.dart` | 2560 | partial: l.60-440, 1580-1640 |
| `frontend/lib/features/freight_quotations/widgets/*`, `services/*`, `freight_quotations_comparison_screen.dart` | 2734 | grep only |
| `frontend/lib/core/widgets/master_data_toolbar.dart`, `row_actions_pill.dart`, `compact_table_pagination_footer.dart`, `enterprise_data_table/enterprise_data_table.dart` | 1300 | read API parts |
| Backend contract: `modules/{purchase_orders,cbm_calculator,shipping_scenarios,customs_consultation,import_requirements,freight_quotations}/router.py` list routes, `schemas.py` keys (scripted), `modules/customs_tariff/router.py:101-118` | - | targeted |
| Not read: `po_report_preview_dialog.dart`, `po_balance_ledger_dialog.dart`, `price_list_form_dialog.dart` (grep only), `freight_quotations_extractor_dialog.dart` (grep only), `rfq_benchmark_dialog.dart`, `import_requirements_screen.dart` form tabs (l.824-2007) | - | - |

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 3 |
| CRITICAL | 6 |
| MAJOR | 21 |
| MINOR | 6 |
| **Total** | **36** |

Most important points:

1. **Customs money is still computed in Flutter with invented rates** (F01-01, F01-02). `customs_consultation_screen.dart` falls back to duty 5 %,
   VAT 14 %, service fee 1 %, FX 50.0, a fake HS `8479.89.90`, hard-coded agreement exemptions by origin, and sends the result as
   `estimated_duties_egp` (l.1522) plus `broker_id ?? 1` (l.1515). The backend engine `/customs-tariff/estimate-multi` exists and is unused here.
   The previous wave fixed the backend copy (CC-01) but not this one.
2. **Invented exchange rates in PO and shipping scenarios** (F01-03, F01-04): PO rate defaults to `1.0` with no validator and can pick a
   future-dated rate; scenario totals convert currencies at `1.0` when a rate is missing.
3. **Broken toolbar actions** (F01-05, F01-06): PO "Export Excel / Export PDF / Template / Import Excel" and the Import Requirements
   `MasterDataToolbarWidget` call endpoints that do not exist in the backend (requests hit `GET /{id}` and fail).
4. **Large tables (CTO topic A)**: none of the 6 Phase-1 list endpoints paginate; PO list returns every PO with all line items and
   packing rows; 4 of 6 tables build every row eagerly (`DataTable` inside `SingleChildScrollView`), 3 have no sticky header, none sort.
   Filters/search also cannot be reset to "All" (F01-08) and PO filters leak to 26 other screens through the shared provider (F01-09).
5. **View action (CTO topic B)**: View exists for PO, CBM, scenarios, consultations and requirements, but it renders the list row (no GET-by-id),
   so it shows stale data and blocks pagination. Missing entirely for Freight RFQs (no registry at all, F01-12) and broker price lists (F01-30).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F01-01 | BLOCKER | `frontend/lib/features/customs_consultation/screens/customs_consultation_screen.dart:72,462,752,812-835,917,925-955,958-961,1663` | Client-side customs engine with invented values: FX controller starts at `'50.0'` and every parse falls back to `?? 50.0`; Case A (invoices but no PO lines) hard-codes duty `5.0`, VAT `14.0`, service fee `1.0`, HS `'8479.89.90'`, unit `'SET'`; per-line path uses `customsDutyRate ?? 5.0`, `vatRate ?? 14.0`, `customsServiceFeeRate ?? 1.0`; origin codes (EU, Mercosur, GAFTA, TR, GB) zero the duty in the UI. The total is saved as `estimated_duties_egp` (l.1522). Breaks DOMAIN_RULES §2 / BP-010 ("no fixed rate, VAT is not always 14 %"). | Call `POST /api/v1/customs-tariff/estimate-multi` (`customs_tariff_provider.dart:178 estimateMultiItemDuty`) and render its breakdown. A line without tariff shows "TARIFF_MISSING / —" and is excluded from totals. No FX default: empty field = validation error. Task FE01-T01. |
| F01-02 | BLOCKER | `customs_consultation_screen.dart:1515-1516` | `'broker_id': _selectedBrokerId ?? 1` and `'broker_name': ... : 'Customs Review'` invent a master-data FK and an English free-text value. | Broker is required for a non-tax-review save (validator + SnackBar); in tax-review mode send `broker_id` only if selected (backend dependency if it is NOT NULL). Task FE01-T02. |
| F01-03 | BLOCKER | `frontend/lib/features/purchase_orders/widgets/po_form_dialog.dart:968,315,324-327,2012-2019,3386,3798` | Exchange rate: controller starts `1.0` (l.968); `double.tryParse(...) ?? 1.0` on save (l.3386, 3798); field has no validator (l.2012); rate lookup `orElse: () => sortedRates.first` takes the newest rate even when it is after the order date (l.324-327); when no rate exists the `1.0` stays silently. Wrong FOB→EGP for every non-EGP PO. | Empty controller for non-base currency; validator "> 0 required"; no `orElse` fallback (leave empty + hint); keep `1.0` only for base currency. Task FE01-T03. |
| F01-04 | CRITICAL | `frontend/lib/features/shipping_scenarios/screens/shipping_scenarios_screen.dart:377-390` | `_calculateTotalQuoteValue` converts mixed-currency charges with `latestCommercialRate ?? 1.0` (target and source). A missing EUR or CNY rate sums them 1:1 into the scenario total that drives the recommendation. | Return `null` total when any needed rate is missing; render "—" + warning chip "rate missing for X"; exclude from cheapest/recommended. Task FE01-T04. |
| F01-05 | CRITICAL | `frontend/lib/features/purchase_orders/screens/purchase_orders_screen.dart:432-445,256-320` | More-actions "Export Excel", "Export PDF", "Download template", "Import Excel" call `/purchase-orders/export-excel`, `/export-pdf`, `/template`, `/import-excel`. `modules/purchase_orders/router.py` has none of them (routes l.29-133), so GET hits `/{po_id}` (422) and POST gets 405. | Export via `TableExportService.exportTableToExcel/exportTableToPdf` (client, current filtered set) until backend export exists; hide Template / Import Excel. Task FE01-T05. |
| F01-06 | CRITICAL | `frontend/lib/features/import_requirements/screens/import_requirements_screen.dart:2016-2020` + `frontend/lib/core/widgets/master_data_toolbar.dart:253-278` | `MasterDataToolbarWidget(moduleEndpoint: 'import-requirements')` shows Export Excel / Export PDF / Import Excel that call non-existent `/import-requirements/export-excel|export-pdf|import-excel`. The working exports are a second button row below (l.2024-2059), so the user sees two Export Excel buttons, one broken. Title `'Import_Requirements_Registry'` is a hard-coded English string. | Pass `onExportExcel` / `onExportPdf` to the local `MasterDataExportService` calls; add `showImportExcel` (default true) to the toolbar and pass false; delete the duplicate row; title from l10n. Task FE01-T06. |
| F01-07 | CRITICAL | `purchase_orders_screen.dart:102,231-235` | Metric "Total FOB" sums `totalAmountFob` of all loaded POs regardless of currency and prints it with `$`. EUR + CNY + USD POs produce a meaningless dollar figure. | Group by `currencyCode`: show one value per currency (or "multi-currency" + tooltip). Task FE01-T07. |
| F01-08 | CRITICAL | `frontend/lib/features/purchase_orders/providers/purchase_orders_provider.dart:74-75`; `frontend/lib/features/cbm_calculator/providers/cbm_calculator_provider.dart:48-49,51`; `frontend/lib/features/shipping_scenarios/providers/shipping_scenarios_provider.dart:41-42` | `copyWith` uses `x ?? this.x`, so `setStatusFilter(null)` / `setProjectFilter(null)` / `setPoFilter(null)` (the "All" item, `purchase_orders_screen.dart:476,508`) keep the old filter. Once a status or project is picked, the user cannot get back to the full list without restarting. Same for `quickCalcResult`. | Sentinel-based copyWith (`Object? statusFilter = _unset`) or explicit `clearX` flags. Task FE01-T08. |
| F01-09 | MAJOR | `purchase_orders_provider.dart:40-137` + 26 consumer files (e.g. `cbm_calculator/widgets/saved_cbm_registry_tab.dart:55,1624`, `freight_quotations/screens/freight_quotations_screen.dart:161`, `customs_consultation_screen.dart:745`) | Search, status and project filter live in the shared `purchaseOrdersProvider`. Filtering the PO screen silently filters the PO pickers and calculations in CBM, scenarios, consultation, freight, booking, etc. | Move list filters to a screen-scoped provider (`purchaseOrdersListQueryProvider`) and keep `purchaseOrdersProvider` unfiltered for lookups (later replaced by a lookup endpoint, see §3). Task FE01-T09. |
| F01-10 | CRITICAL | `freight_quotations_screen.dart:1581-1608`; `freight_quotations_provider.dart:67-110` | Save always calls `createRFQ`, even after "Load to Compare" (`_matchedExistingRFQ`, l.354-372). Editing an existing RFQ creates a duplicate with a new code. Provider has no `updateRFQ`; backend `PUT /api/v1/freight-quotations/{rfq_id}` exists (`router.py:83`). | Add `updateRFQ`; save uses PUT when `_matchedExistingRFQ != null`; show the RFQ code being edited. Task FE01-T10. |
| F01-11 | MAJOR | `freight_quotations_screen.dart:1601-1603,395-398` | `chargeable_weight_kg` is sent equal to gross weight (should be max(gross, CBM × air factor) for air); CBM/weight `?? 0.0` and reset to `'0.0'` (invented zeros); default title `'New Freight RFQ Request'` stored as data. | Send `chargeable_weight_kg` only if computed from `cargo_math` result returned by backend (or omit and let backend compute); empty = validation error; title empty + validator. Task FE01-T10. |
| F01-12 | MAJOR | `freight_quotations_provider.dart:95-110` (unused), `freight_quotations_screen.dart:242-390` | No RFQ registry: saved RFQs are only reachable in a "Load saved" dialog; `softDeleteRFQ` / `restoreRFQ` are never called, so an RFQ cannot be deleted, restored, filtered by status or exported. BP-008 requires managing RFQs. | Add a "Saved RFQs" tab (registry table with View / Edit / Award / Delete-Restore). Task FE01-T11. |
| F01-13 | MAJOR | `purchase_orders_screen.dart:809-815`; `purchase_orders_provider.dart:221-241` | Delete/restore result is ignored (no success or failure SnackBar). On failure the provider sets `state.error`, which replaces the whole PO table with the error page (`purchase_orders_screen.dart:199-200`), e.g. on a 403 or a 409 "PO has allocations". | Return the error (like `createPurchaseOrder`), keep `state.error` for list load only, show SnackBar with `ApiErrorText.of`. Task FE01-T12. |
| F01-14 | MAJOR | `frontend/lib/features/cbm_calculator/widgets/saved_cbm_registry_tab.dart:268-293,666-671,705-719,1660-1668` | Registry never renders `state.error`: a failed load / 403 shows "No data found". Delete, restore, clone and link failures are silent (bool/null result ignored, link dialog just stays open). | Error view with Retry; SnackBar on every failed mutation using `state.errorText(l)`. Task FE01-T12. |
| F01-15 | MAJOR | `frontend/lib/features/shipping_scenarios/widgets/saved_scenarios_registry_tab.dart:268-300,1408-1411` | Same as F01-14 for scenarios: no error view, delete/restore result ignored. | Same pattern. Task FE01-T12. |
| F01-16 | MAJOR | `frontend/lib/features/customs_consultation/providers/customs_consultation_provider.dart:291,305,315,324`; `widgets/saved_consultations_tab.dart:44,411-419` | After create/update/delete/restore the provider calls `fetchConsultations()` with default `includeInactive: false` while the "show archived" chip stays selected. Restoring an archived consultation (only possible with the chip on) makes all archived rows disappear and the chip lies. | Keep the last query (includeInactive, search, filters) in the notifier and reuse it on refetch. Task FE01-T13. |
| F01-17 | MAJOR | `saved_consultations_tab.dart:289` | Load error rendered as raw `'${l.error}: $err'` (DioException dump, a 403 is not "no permission"). | `ApiErrorText.of(l, err)` + Retry. Task FE01-T13. |
| F01-18 | MAJOR | `frontend/lib/features/import_requirements/providers/import_requirements_provider.dart:32,49,53-61`; `import_requirements_screen.dart:2153-2155` | `_fetchRequirements` wraps every error into `Exception('Failed to fetch import requirements: $e')`, so the screen cannot localize it (raw text shown). `refreshData()` after add/update/delete drops the `importFileId` filter set by `fetchByFileId`. List always loads deleted rows (`include_inactive: true`) and filters client-side. | Rethrow the DioException; keep `_lastFileId`; server-side `include_inactive` from the Active/Deleted filter. Task FE01-T14. |
| F01-19 | MAJOR | `purchase_orders_screen.dart:776-784` | Row action "Print" only shows a SnackBar with the PO name; nothing is printed. | Open `po_report_preview_dialog.dart` (existing) for the row, or remove `onPrint`. Task FE01-T15. |
| F01-20 | MAJOR | `cbm_calculator_provider.dart:136-170` | Create and link push CBM/weight/packages into the PO on the backend (`PurchaseOrderService.apply_measurements`) but only `fetchCalculations()` is refreshed; PO list, import files and scenario PO data stay stale. | After create/update/link success call `ref.read(purchaseOrdersProvider.notifier).refreshAfterMutation()` (notifier needs `Ref`). Task FE01-T12. |
| F01-21 | MAJOR | `saved_scenarios_registry_tab.dart:1320-1353` | Study export: CSV with hard-coded Arabic headers, file name `Phase1_Shipping_Evaluation_<code>_<epoch>.csv` (rule: `[Stage Name] - [Import File Code].ext`), offers `xlsx` extension for CSV text (Excel shows garbage if saved as .xlsx), dialog title hard-coded Arabic. | Use `TableExportService.exportTableToExcel` with l10n headers, `stageName` = l10n stage, `importFileNameOrCode` = file code. Task FE01-T16. |
| F01-22 | MAJOR | `purchase_orders_screen.dart:730-745,931-957,734,1232,1246,1402,1406,1526,2133-2216` | Table shows DB ids as references: `'PRJ-#${po.projectId}'`, `'COMP-#${po.companyId}'`, `'SUP-#${po.supplierId}'`, `'IMP-${po.importFileId}'`; currency invented `po.currencyCode ?? "USD"` in 9 places. CORE_RULES: never show DB id; unknown stays unknown. | Show `—` when name/code missing; currency `—`. Task FE01-T07. |
| F01-23 | MAJOR | `po_form_dialog.dart:3389-3393,95-130` | Discrepancy justification is stored inside `notes` with an Arabic prefix `'[مبررات اختلاف الفاتورة والباكينج]: '` (UI language persisted in data). Country of origin is a hard-coded bilingual list (`countryOptions`), free text instead of FK (backend PO-17 backlog). | Prefix from a fixed English token (e.g. `[PL_DISCREPANCY_JUSTIFICATION]`) rendered via l10n, or separate field (backend). Country list: keep until Q7 decided, but labels from l10n. Task FE01-T17. |
| F01-24 | MAJOR | `frontend/lib/features/freight_quotations/**` | 217 `isArabic ?` ternaries, 214 `Colors.*`, 12 `Color(0x...)`, 72 raw `ElevatedButton/OutlinedButton/TextButton`, `DropdownButtonFormField` (`widgets/freight_quotations_extractor_dialog.dart:494`), Arabic-only SnackBars (`freight_quotations_screen.dart:225,1585,1627`), hard-coded `$` on `lowestFreightCost` (l.326). | Sweep: l10n keys, `AppTheme`, `AppButton`, `SearchableDropdownField`, currency from RFQ. Tasks FE01-T18, FE01-T19. |
| F01-25 | MAJOR | `customs_consultation/widgets/price_list_form_dialog.dart` (118 Arabic literal lines), `services/customs_consultation_pdf_service.dart:425,461,663`, `widgets/nafeza_fee_breakdown_card.dart:190`, `services/clearance_expense_types_export_service.dart:369` | Hard-coded Arabic UI text; PDFs printed through `Printing.layoutPdf` with names `..._${millisecondsSinceEpoch}` (generic, no import-file code). | l10n sweep; PDF names `[Stage] - [File code]`; "Save" goes through `FileSaveHelper`. Task FE01-T20. |
| F01-26 | MAJOR | `saved_cbm_registry_tab.dart:196-219` | Button labels built from `Directionality ... ? 'تصدير إكسيل' : 'Export Excel'` etc. instead of `l.exportExcel`/`l.exportPdf`. | Use existing l10n keys. Task FE01-T16. |
| F01-27 | MAJOR | `purchase_orders_screen.dart:451`; `saved_cbm_registry_tab.dart:161-163`; `saved_scenarios_registry_tab.dart:178` | Server search fires one GET per keystroke (no debounce). With the full PO graph in each response this is the main load on large data. | 350 ms debounce in the notifier (`Timer`). Task FE01-T21. |
| F01-28 | MAJOR | see §3 | No pagination anywhere; eager `DataTable` bodies; no sticky header in CBM / scenarios / consultations; no sort; PO list payload carries all items. | Shared paged/virtualized table + backend `limit/offset`. Tasks FE01-T22..T25. |
| F01-29 | MAJOR | `purchase_orders_screen.dart:752,772,1042`; `saved_cbm_registry_tab.dart:366`; `saved_scenarios_registry_tab.dart:356`; `saved_consultations_tab.dart:680` | View dialogs render the list row object; `GET /purchase-orders/{id}`, `/cbm-calculator/{id}`, `/shipping-scenarios/{id}`, `/customs-consultations/{id}` are never called. Data can be stale and pagination/summary lists would break the dialogs. | View loads by id (FutureProvider.family) with loading/error states. Task FE01-T26. |
| F01-30 | MAJOR | `customs_consultation/widgets/broker_price_lists_tab.dart:237-243,283` | Price lists have only Edit (form dialog) and Clone; no read-only View. Clone sends `copy_items` which `CloneBrokerPriceListRequest` (`modules/customs_consultation/schemas.py:134-139`) ignores, and the service always copies items: the "copy line items" toggle does nothing. | Add View (read-only dialog); hide the copy-items toggle (`allowCopyLineItems: false`) until backend supports it. Task FE01-T27. |
| F01-31 | MINOR | `import_requirements_screen.dart:2106-2126,2321-2323` | Status/risk filters and badges use raw English values (`Draft`, `In Progress`, `Low`) from the backend; Arabic UI shows English. | Map to l10n labels (backend codes later). Task FE01-T14. |
| F01-32 | MINOR | `frontend/lib/features/freight_quotations/screens/freight_quotations_comparison_screen.dart` (536 lines); `saved_cbm_registry_tab.dart:1676` | Dead code: comparison screen is not mounted (index 49 is `FreightQuotationsScreen`, `home_screen.dart:186`; stale comment `core/providers/navigation_provider.dart:81`); `_showContainerComparisonDialog` marked `unused_element`. | Delete (keep its l10n keys only if used elsewhere). Task FE01-T28. |
| F01-33 | MINOR | `purchase_orders_screen.dart:120-153,517-525` | Type B header has 3 actions + an extra refresh (max 2: primary + Back); refresh duplicated in toolbar. | Move Smart Upload into toolbar, drop header refresh. Task FE01-T28. |
| F01-34 | MINOR | `po_form_dialog.dart:2139,2015-2016` | `'Required'` literal validator text; bilingual hard-coded label `'Exchange Rate (سعر الصرف)'`. | l10n. Task FE01-T03. |
| F01-35 | MINOR | `frontend/lib/features/shipping_scenarios/models/shipping_scenario_model.dart:150,281`; `freight_quotations/models/freight_quotation_model.dart:50` | Missing currency becomes `'USD'`. | Nullable currency, render `—`. Task FE01-T04. |
| F01-36 | MINOR | `cbm_calculator_provider.dart:81,105,138,...`; `shipping_scenarios_provider.dart:70,114,...` | Relative paths `'/cbm-calculator'`, `'/shipping-scenarios'` instead of `ApiConstants` (flutter rule). | Add constants, use them. Task FE01-T21. |

Verified fixed from the previous plan (not re-reported): FE-01 (PO refresh after mutation, `purchase_orders_provider.dart:142-147`), FE-03 in PO/CBM/SS/CC/IR (0 raw Material buttons), PO-01 item ids sent on edit, PO-03 status filter now sends `PO_STATUS` codes (`purchase_orders_screen.dart:509-511`). Still open from FE-02 / FE-04 only in `freight_quotations` and `customs_consultation` (F01-24, F01-25); FE-05 god files unchanged (4.4-4.6k lines); FE-06 export naming still open (F01-21, F01-25).

---

## 3. Large tables (CTO topic A)

Backend fact for all six lists: no `limit`/`offset`/`page`/`sort` parameter and no total count
(`modules/purchase_orders/router.py:29-48`, `cbm_calculator/router.py:49-69`, `shipping_scenarios/router.py:38-58`,
`customs_consultation/router.py` list at ~l.275, `import_requirements/router.py:48-62`, `freight_quotations/router.py:42-67`).
Shared building blocks already in the codebase: `core/widgets/compact_table_pagination_footer.dart` (pager UI, used by
`import_files_screen.dart:1860`), `core/widgets/enterprise_data_table/enterprise_data_table.dart` (client-side paging/sort/search only,
persists column prefs in SharedPreferences), `core/services/table_export_service.dart`.

| Screen / list | Current behaviour | Evidence | Recommended solution |
|---|---|---|---|
| Purchase orders (index 2) | Server filter + search (no debounce), loads ALL POs with ALL line items and packing rows (`PurchaseOrderResponse.items/packing_list_items`, `schemas.py:255-256`, `repository.py:61-67` selectinload). Body = `DataTable` in a vertical `SingleChildScrollView`: every row and ~11 cells with `CopyableTableCell` built eagerly. Sticky header done right (separate header `DataTable` + fixed widths), horizontal scrollbar OK. No sort, row count only in metric strip, TSV copy = loaded rows, Excel/PDF export broken (F01-05). Mobile: `ListView.separated` with `shrinkWrap + NeverScrollableScrollPhysics` (all cards built). | `purchase_orders_provider.dart:96-108`; `purchase_orders_screen.dart:571-1040` (body l.701-1026), mobile l.176-181 | Backend: `limit/offset/sort` + `X-Total-Count` header (additive, old callers unaffected) and `view=summary` (no items). Frontend: screen-scoped paged query provider, virtualized body (`ListView.builder` rows with the same fixed column widths, `itemExtent` = density row height), `CompactTablePaginationFooter` (25/50/100), clickable sortable headers mapped to `sort=`, 350 ms debounce, export full set through backend export or page loop. PO pickers in other screens move to a lookup endpoint (`/purchase-orders/lookup?search=&limit=20`). Tasks T21, T22, T23. |
| CBM saved registry (index 3, tab) | Server search (no debounce), all rows. `DataTable` inside horizontal `SingleChildScrollView` inside vertical `SingleChildScrollView` + `Card`: header scrolls away (not sticky), no scrollbar, all rows built. Count chip OK. Client exports of loaded rows via `TableExportService` (OK). | `saved_cbm_registry_tab.dart:299-349`, `cbm_calculator_provider.dart:80-93` | Same shared virtualized table (T22) + backend paging (T24). |
| Shipping scenarios saved registry (index 5) | Same structure as CBM; no list export at all; avg-transit metric over loaded rows incl. inactive. | `saved_scenarios_registry_tab.dart:66-72,282-300` | T22 + T24; add list export via `TableExportService`. |
| Customs consultations saved (index 7) | Loads all, search is client-side only (`_searchQuery` filter, l.300-305), `DataTable` in nested `SingleChildScrollView` (not sticky, all rows built). Archived toggle refetch bug (F01-16). | `saved_consultations_tab.dart:278-310,594-606` | T22 + T25 (server `search` param already exists in backend). |
| Import requirements registry (index 43, tab) | Loads all incl. deleted (`include_inactive: true`), client-side search/status/risk/active filters, rows in `ListView.separated` (virtualized, OK) as `ListTile`s, no columns, no sort, no count. Two export rows, one broken (F01-06). | `import_requirements_provider.dart:31-42`; `import_requirements_screen.dart:2151-2219` | Keep `ListView`; send `search`, `overall_status`, `risk_level`, `include_inactive` to backend (already supported, `router.py:48-62`); add count + footer when backend paging lands (T25). |
| Freight RFQs (index 49) | No registry; "Load saved RFQ" dialog loads all RFQs and filters client-side in a `ListView.separated` (virtualized). | `freight_quotations_screen.dart:242-390` | New registry tab built directly on the shared paged table (T11). |
| Broker price lists / expense types (index 55 tab) | Price lists: `ListView.builder` cards (virtualized). Expense types catalog: `DataTable` in nested `SingleChildScrollView` (all rows; catalog is small, acceptable). | `broker_price_lists_tab.dart:194,591-604` | No change needed beyond View (T27). |

Why not just reuse `EnterpriseDataTable`: it is client-side only (it still needs the full list in memory) and stores prefs in
SharedPreferences; it fixes rendering but not the payload. The plan is a thin server-paged wrapper (T22) that can reuse its column
model later.

---

## 4. View/Show action (CTO topic B)

| Entity | View exists? | How it works today | Why it looks "missing" / gap | What to add |
|---|---|---|---|---|
| Purchase order | Yes: eye icon in `RowActionsPill` + row tap + PO number link (`purchase_orders_screen.dart:752,772,830`) | `_showPODetailsDialog(context, po)` (l.1042) renders the list object, no GET by id | Hidden among 5 icons, opened also by row tap (accidental). Data is the list payload (stale; breaks with summary paging). Print next to it is fake (F01-19). | Load `GET /purchase-orders/{id}` in the dialog (T26); real Print (T15). |
| CBM calculation | Yes: `RowActionsPill.onView` (`saved_cbm_registry_tab.dart:366`, mobile l.865) | `_showDetailDialog(context, calc)` from list row | Edit (`onLoadSession`) leaves the registry and loads the calculator tab; View is fine but stale. | Fetch by id (T26). |
| Shipping scenario study | Yes: `onView` (`saved_scenarios_registry_tab.dart:356`) | `_showSessionDetailsDialog` from list row | Same as CBM. | Fetch by id (T26). |
| Customs consultation | Yes: `onView` + row tap (`saved_consultations_tab.dart:672,680`) → `consultation_details_dialog.dart` | from list row | Same. | Fetch by id (T26). |
| Import requirement | Yes: `Icons.visibility_outlined` (`import_requirements_screen.dart:2350-2354`) | `_showRequirementDetailsDialog(req)` from list row | Not the standard `RowActionsPill` (6 loose icons), so it does not look like other screens. | Use `RowActionsPill` (View/Edit/Print/Delete) (T14). |
| Freight RFQ | Only inside the "Load saved RFQ" dialog (`freight_quotations_screen.dart:343-347`) | `_showRFQDetailsDialog(rfq)` | **No registry screen exists**, so there is nowhere to put View/Edit/Delete; provider delete/restore methods are unused. This is the real "no Show". | Saved RFQs registry tab with View (T11). |
| Broker price list | No (`broker_price_lists_tab.dart:237-243`: Edit button + clone + delete only) | Only `showPriceListFormDialog(existingPriceList: pl)` (edit form reused as viewer) | No read-only dialog was built; edit form doubles as view, so a viewer role (no `customs_consultation.manage`) cannot inspect safely. | Read-only View dialog (T27). |
| Clearance expense type | No (edit/delete/clone/copy) | Row shows all catalog fields | Catalog row is self-describing; View not needed. | None. |

Root reason across the phase: no detail route (IndexedStack navigation, no go_router path like `/purchase-orders/:id`) and no
GET-by-id provider in any Phase-1 feature, so every "View" is a dialog over the list row, and entities without a list (RFQ) have none.

---

## 5. Tasks

Order = priority. Every task: keep edits inside the listed files; follow `.claude/rules/flutter.md`; any new user text goes into
`frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`.
Run `flutter test` for the touched area and `flutter analyze` on touched files before finishing.

### FE01-T01: Customs consultation uses the backend duty engine (no client-side rates)
- **Severity**: BLOCKER
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no (uses existing `POST /api/v1/customs-tariff/estimate-multi`, request schema `MultiItemCustomsEstimateRequest` in `modules/customs_tariff/schemas.py:408`; read the item schema just below it before building the payload)
- **Files to change**: `frontend/lib/features/customs_consultation/screens/customs_consultation_screen.dart`, `frontend/lib/features/customs_tariff/providers/customs_tariff_provider.dart` (reuse `estimateMultiItemDuty`, l.178), `frontend/lib/features/customs_consultation/models/customs_consultation_model.dart` (l.704 `?? 50.0`), l10n files
- **Steps**:
  1. In `_calculateCustomsLines()` (l.732) stop computing duty/VAT/fees. Build the `estimate-multi` request from the PO lines (HS / tariff id, qty, unit price, currency), freight and insurance controllers.
  2. Delete Case A fabricated row (l.810-850: HS `8479.89.90`, duty 5, VAT 14, svc 1). When there are invoices but no PO lines, show an info banner "add PO lines with HS codes to estimate duties" and no numbers.
  3. Remove every `?? 50.0` (l.462, 752, 1663) and the controller default `'50.0'` (l.72): empty controller; if no customs rate is found, leave empty and show the field error.
  4. Remove `?? 5.0`, `?? 14.0`, `?? 1.0` (l.917, 958, 961) and the origin-code agreement block (l.925-955): agreements/exemptions come from the engine response or are not shown.
  5. Lines without a tariff render status "TARIFF_MISSING" and "—" and are excluded from totals; `estimated_duties_egp` (l.1522) = engine grand total, or the save is blocked with a SnackBar when any line is missing.
  6. Model l.704: `exchangeRate` nullable (no `?? 50.0`).
  7. Debounce engine calls (400 ms) when inputs change; show a loader in the totals card.
- **Acceptance criteria**:
  - [ ] An item whose HS has VAT 0 % shows VAT 0, not 14 %.
  - [ ] With no customs rate for the currency the FX field is empty and red, and Save shows an error SnackBar.
  - [ ] A file with invoices and no PO lines shows no duty numbers.
  - [ ] Saved `estimated_duties_egp` equals the engine total shown.
- **Tests to add**: `frontend/test/features/customs_consultation/customs_estimate_payload_test.dart`: build payload from 2 lines (one without tariff) → request contains only the tariffed line; response with VAT 0 rendered as 0; parse model json without `exchange_rate` → null. Grep-guard test: the screen source contains no `?? 50.0`, `14.0`, `'8479.89.90'`.
- **Out of scope**: broker fee logic, PDF layout.

### FE01-T02: Consultation save never invents broker
- **Severity**: BLOCKER
- **Type**: bug
- **Depends on**: none
- **Backend needed**: check `broker_id` nullability in `modules/customs_consultation/schemas.py` create schema; if required in tax-review mode, list it in §6 (do not change backend here)
- **Files to change**: `customs_consultation_screen.dart`, l10n files
- **Steps**:
  1. At l.1515-1516 remove `?? 1` and the `'Customs Review'` fallback.
  2. In normal mode, validate that a broker is selected before saving (red text under the broker field + SnackBar).
  3. In tax-review mode (`widget.isTaxReviewMode`), send `broker_id` / `broker_name` only when selected.
- **Acceptance criteria**:
  - [ ] Saving without a broker in normal mode is blocked with a clear message.
  - [ ] No consultation is ever saved with broker id 1 unless the user picked broker 1.
- **Tests to add**: `frontend/test/features/customs_consultation/consultation_payload_test.dart`: payload builder with null broker in tax-review mode has no `broker_id` key.
- **Out of scope**: broker master data.

### FE01-T03: PO exchange rate is required and never defaulted
- **Severity**: BLOCKER
- **Type**: bug
- **Depends on**: none
- **Backend needed**: yes, small: `PurchaseOrderCreate.exchange_rate` defaults to `1.0` (`modules/purchase_orders/schemas.py:181`); the UI fix works without it, see §6
- **Files to change**: `frontend/lib/features/purchase_orders/widgets/po_form_dialog.dart`, `frontend/lib/features/purchase_orders/models/purchase_order_model.dart` (l.586), l10n files
- **Steps**:
  1. l.968: controller text = `po?.exchangeRate?.toString() ?? ''` for new POs (not `1.0`).
  2. `_updateExchangeRateFromCurrency` (l.310-335): base currency → `1.0`; otherwise pick the latest rate with `effectiveDate <= orderDate`; if none, clear the field and show helper text "no rate for <code> on <date>" (remove `orElse: () => sortedRates.first`).
  3. l.2012: add `validator`: required and `> 0`; label/helper from l10n (replace `'Exchange Rate (سعر الصرف)'`, l.2015-2016, and `'Required'` at l.2139).
  4. l.3386 and l.3798: parse without `?? 1.0`; the form validator guarantees a value.
- **Acceptance criteria**:
  - [ ] New EUR PO with no EUR rate on/before the order date: rate field empty and red, Save blocked.
  - [ ] Order date before the first rate: no future rate is filled.
  - [ ] EGP PO: rate 1.0 filled automatically.
- **Tests to add**: `frontend/test/features/po_exchange_rate_test.dart`: extract the rate-picking logic into a pure function `pickCommercialRate(rates, orderDate)` in `frontend/lib/features/purchase_orders/utils/po_payment_terms.dart` or a new `utils/po_fx_rate.dart`; assert: date before all rates → null, exact date → that rate, between → previous.
- **Out of scope**: currency master screens.

### FE01-T04: Shipping scenario totals never convert at 1.0
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/shipping_scenarios/screens/shipping_scenarios_screen.dart`, `frontend/lib/features/shipping_scenarios/models/shipping_scenario_model.dart`, `frontend/lib/features/freight_quotations/models/freight_quotation_model.dart` (l.50), l10n files
- **Steps**:
  1. `_calculateTotalQuoteValue` (l.373-400): return `double?`; if a source or target currency rate is missing (`latestCommercialRate == null`), return null.
  2. Where the total is assigned (l.473) and displayed (l.2379, 2729, 2790, 3570), show "—" and a small orange chip "rate missing: <codes>" when null.
  3. Exclude null-total scenarios from cheapest/recommended computations and from the saved `total_quotation_amount` (send null or block save with SnackBar; check backend schema allows null, else block).
  4. Models: `quotation_currency` / `currency_code` without `?? 'USD'` (nullable; render "—").
- **Acceptance criteria**:
  - [ ] A scenario with a CNY charge and no CNY rate shows "—" with a warning, not a number.
  - [ ] It is never marked recommended because of a wrong total.
- **Tests to add**: `frontend/test/features/shipping_scenarios/scenario_total_test.dart`: make the conversion a pure static function; assert null on missing rate, correct value with both rates.
- **Out of scope**: transit-day logic.

### FE01-T05: PO toolbar exports that work
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no for the fix; backend export/template/import endpoints are optional (see §6)
- **Files to change**: `frontend/lib/features/purchase_orders/screens/purchase_orders_screen.dart`
- **Steps**:
  1. Replace `case 'export_excel'` / `'export_pdf'` (l.432-437) with `TableExportService.exportTableToExcel` / `exportTableToPdf` (`frontend/lib/core/services/table_export_service.dart:109,138`) using the same headers/rows as `_copyPOTableTsv` (l.322-349), `stageName: l.purchaseOrdersTitle`, `importFileNameOrCode`: the selected project code or `l.allProjects`.
  2. Remove the `download_template` and `import_excel` menu items (l.409-428, 441-446) and `_downloadPOFile` / `_handleImportExcel` if unused.
- **Acceptance criteria**:
  - [ ] Export Excel and PDF open a Save-As dialog and produce a file with the visible rows.
  - [ ] No menu item produces a 4xx error.
- **Tests to add**: `frontend/test/features/purchase_orders/po_export_rows_test.dart`: extract `buildPoExportRows(orders, l)` and assert columns/ordering and that missing names render "—".
- **Out of scope**: server-side Excel import.

### FE01-T06: Import requirements registry toolbar without broken buttons
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/core/widgets/master_data_toolbar.dart`, `frontend/lib/features/import_requirements/screens/import_requirements_screen.dart`, l10n files
- **Steps**:
  1. Add `final bool showImportExcel;` (default `true`) to `MasterDataToolbarWidget`; wrap the Import Excel button (l.270-279) in `if (widget.showImportExcel)`.
  2. In the IR screen (l.2016-2020) pass `onExportExcel: () => MasterDataExportService.exportImportRequirementsToExcel(context, list)`, `onExportPdf: () => MasterDataExportService.printOrSaveImportRequirementsListPdf(context, list)`, `showImportExcel: false`, `title: l10n.<new key importRequirementsRegistryTitle>`.
  3. Delete the duplicate export `Row` (l.2024-2059) but keep the TSV copy as `extraTrailing`.
- **Acceptance criteria**:
  - [ ] Registry shows one Export Excel and one Export PDF, both work.
  - [ ] No Import Excel button on this screen; other master-data screens unchanged.
- **Tests to add**: `frontend/test/core/master_data_toolbar_test.dart`: widget test that `showImportExcel: false` hides the button and default shows it.
- **Out of scope**: other screens using the toolbar.

### FE01-T07: PO list shows honest money and references
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `purchase_orders_screen.dart`, l10n files
- **Steps**:
  1. Metric "Total FOB" (l.102, 231-235): group sums by `currencyCode`; one currency → `"<code> <sum>"`; several → first two + "+N" with a tooltip listing all; null currency counted under "—".
  2. Replace `'PRJ-#${po.projectId}'`, `'COMP-#…'`, `'SUP-#…'`, `'IMP-${po.importFileId}'` (l.730-745, 931-957) with `'—'`.
  3. Replace every `po.currencyCode ?? "USD"` (l.734, 1232, 1246, 1402, 1406, 1526, 2133, 2137, 2151, 2216) with `po.currencyCode ?? '—'`.
- **Acceptance criteria**:
  - [ ] Loading one USD and one EUR PO shows both totals separately, no `$` sum.
  - [ ] No DB id appears in the table.
- **Tests to add**: `frontend/test/features/purchase_orders/po_fob_totals_test.dart`: pure `fobTotalsByCurrency(orders)` returns `{USD: x, EUR: y}`.
- **Out of scope**: currency conversion.

### FE01-T08: Filters can be reset to "All"
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/purchase_orders/providers/purchase_orders_provider.dart`, `frontend/lib/features/cbm_calculator/providers/cbm_calculator_provider.dart`, `frontend/lib/features/shipping_scenarios/providers/shipping_scenarios_provider.dart`
- **Steps**:
  1. In each `copyWith`, use a private sentinel: `static const _unset = Object();` and params `Object? statusFilter = _unset` → `statusFilter: identical(statusFilter, _unset) ? this.statusFilter : statusFilter as String?`. Apply to `statusFilter`, `projectFilter`, `poFilter`, `quickCalcResult`.
  2. Keep `error` semantics unchanged (already resets).
- **Acceptance criteria**:
  - [ ] Choose status "Approved" then "All statuses": list shows all POs again.
  - [ ] Same for project filter (PO) and project/PO filters (CBM, scenarios).
- **Tests to add**: `frontend/test/features/filters_reset_test.dart`: with the `_RecordingAdapter` pattern from `frontend/test/features/purchase_orders_mutation_refresh_test.dart`, call `setStatusFilter('APPROVED')` then `setStatusFilter(null)` and assert the last GET has no `status` query param; same for CBM `setProjectFilter`.
- **Out of scope**: moving filters out of the provider (T09).

### FE01-T09: PO screen filters do not leak to other screens
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FE01-T08
- **Backend needed**: no
- **Files to change**: `purchase_orders_provider.dart`, `purchase_orders_screen.dart`, new `frontend/lib/features/purchase_orders/providers/po_list_query_provider.dart`
- **Steps**:
  1. Create `poListQueryProvider` (StateNotifier holding search/status/project/showInactive) and `poListProvider` (FutureProvider/AsyncNotifier that GETs with those params).
  2. PO screen table, metrics, toolbar use the new providers.
  3. `purchaseOrdersProvider` keeps fetching the unfiltered active list (lookup for other screens); remove its filter setters only after grepping that no other file calls them (`grep -rn "setSearchQuery\|setStatusFilter\|setProjectFilter" frontend/lib` within purchase_orders usage).
  4. `refreshAfterMutation` also invalidates `poListProvider`.
- **Acceptance criteria**:
  - [ ] Filter PO screen by a project, open CBM "link to PO": all POs are listed.
  - [ ] PO screen filtering still works.
- **Tests to add**: `frontend/test/features/purchase_orders/po_list_query_test.dart`: setting a filter on `poListQueryProvider` does not change requests made by `purchaseOrdersProvider`.
- **Out of scope**: pagination (T23).

### FE01-T10: Freight RFQ edit updates instead of duplicating
- **Severity**: CRITICAL
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no (`PUT /api/v1/freight-quotations/{rfq_id}`, `modules/freight_quotations/router.py:83`; check the update schema in `schemas.py` for accepted fields incl. `quotations`)
- **Files to change**: `frontend/lib/features/freight_quotations/providers/freight_quotations_provider.dart`, `frontend/lib/features/freight_quotations/screens/freight_quotations_screen.dart`, l10n files
- **Steps**:
  1. Add `updateRFQ(int rfqId, Map payload)` (PUT, then `fetchRFQs()`, rethrow on error).
  2. `_saveRFQ` (l.1581): if `_matchedExistingRFQ != null` call `updateRFQ(_matchedExistingRFQ!.rfqId, payload)`, else create. Show "Editing RFQ <code>" chip in the form header with a "New RFQ" action (existing `_resetRFQForm`).
  3. Payload (l.1592-1606): CBM and weight parsed without `?? 0.0` (validators already required → add them on the controllers if missing); remove `chargeable_weight_kg` (let backend compute) unless the update schema requires it; if required, compute `max(gross, cbm * factor)` using the factor returned by the backend (ask in §7, do not hard-code).
  4. `_resetRFQForm` (l.395-398): title empty (validator), CBM/weight empty, not `'0.0'`.
- **Acceptance criteria**:
  - [ ] Load an RFQ, change a quote, save: same RFQ code, no new row.
  - [ ] Empty CBM/weight blocks save with field errors.
- **Tests to add**: `frontend/test/features/freight_quotations/rfq_save_mode_test.dart`: recording adapter; with a matched RFQ the request is `PUT .../freight-quotations/<id>`, without it `POST`.
- **Out of scope**: registry (T11), l10n sweep (T18).

### FE01-T11: Saved RFQs registry tab with View / Edit / Award / Delete-Restore
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FE01-T10 (and FE01-T22 if available; otherwise use the same pattern as `saved_cbm_registry_tab.dart` but with `ListView.builder`)
- **Backend needed**: no (list filters `search`, `status`, `shipping_method`, `include_inactive` exist, `router.py:42-67`; delete/restore exist)
- **Files to change**: new `frontend/lib/features/freight_quotations/widgets/saved_rfqs_registry_tab.dart`, `freight_quotations_screen.dart` (add a TabBar: "Comparison workspace" / "Saved RFQs"), `freight_quotations_provider.dart` (keep last query), l10n files
- **Steps**:
  1. Registry columns: RFQ code, title, import file code, method, POL → POD, quotes count, lowest cost with its currency, status, awarded provider.
  2. Toolbar: search (debounced, server), status filter (`SearchableDropdownField`), show-deleted chip, refresh, Excel/PDF via `TableExportService`.
  3. Row actions via `RowActionsPill`: View (`_showRFQDetailsDialog` moved into the widget or a new `rfq_details_dialog.dart`), Edit (switch to tab 0 and load, same as "Load to Compare"), Benchmark/Award (existing `showRFQBenchmarkDialog`), Delete/Restore (confirm dialog, SnackBar on success/failure, refetch keeping filters).
- **Acceptance criteria**:
  - [ ] User can find an RFQ, view it read-only, edit it, delete and restore it.
  - [ ] Errors show as SnackBar via `ApiErrorText.of`.
- **Tests to add**: `frontend/test/features/freight_quotations/saved_rfqs_registry_test.dart`: widget test with a fake provider: 2 RFQs render, View opens a dialog, delete calls `softDeleteRFQ`.
- **Out of scope**: awarding rules.

### FE01-T12: Mutation results visible in PO, CBM and scenario lists
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `purchase_orders_provider.dart`, `purchase_orders_screen.dart`, `cbm_calculator_provider.dart`, `saved_cbm_registry_tab.dart`, `saved_scenarios_registry_tab.dart`
- **Steps**:
  1. PO provider `deletePurchaseOrder` / `restorePurchaseOrder` (l.221-241): return `Object?` error (null = success) and do not set `state.error`. Same for `allocateShipment` / `clonePurchaseOrder` (`state = state.copyWith(error: e)` removed; they already rethrow).
  2. PO screen l.809-815: SnackBar success (emerald) or failure (crimson, `ApiErrorText.of`).
  3. CBM provider: mutations keep returning bool but store the failure in a separate `lastMutationError` field (not `error`), and `CBMCalculatorNotifier` receives `Ref` so create/update/link call `ref.read(purchaseOrdersProvider.notifier).refreshAfterMutation()` on success (F01-20).
  4. CBM registry: render `state.error` in the list area (error icon, message via `state.errorText(l)`, Retry); SnackBars for failed delete/restore/clone/link (l.666-671, 705-719, 1660-1668).
  5. Scenarios registry: same error view (l.268-300) and SnackBars for delete/restore (l.1408-1411).
- **Acceptance criteria**:
  - [ ] A 403 on PO delete shows a red SnackBar and the table stays visible.
  - [ ] CBM list load failure shows an error with Retry, not "No data".
  - [ ] After linking a CBM to a PO, the PO list shows the new CBM without manual refresh.
- **Tests to add**: extend `frontend/test/features/purchase_orders_mutation_refresh_test.dart`: an adapter returning 403 for DELETE → `deletePurchaseOrder` returns non-null and `state.error` stays null. New `frontend/test/features/cbm_calculator/cbm_link_refresh_test.dart`: link success triggers a GET on `/purchase-orders`.
- **Out of scope**: redesign of the registry tables (T22).

### FE01-T13: Consultations list keeps its query and shows real errors
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `customs_consultation_provider.dart`, `saved_consultations_tab.dart`
- **Steps**:
  1. Store the last `fetchConsultations` arguments in the notifier (`_lastQuery`); add `refetch()` that reuses them; create/update/delete/restore/clone call `refetch()` (l.291, 305, 315, 324, ~364).
  2. Send the search text to the backend (`search`) with a 350 ms debounce instead of client filtering (l.300-305).
  3. Error branch (l.289): `ApiErrorText.of(l, err)` + Retry button.
- **Acceptance criteria**:
  - [ ] With "show archived" on, restoring a row keeps archived rows visible.
  - [ ] A 403 reads "no permission" in the user's language.
- **Tests to add**: `frontend/test/features/customs_consultation/consultations_refetch_test.dart`: recording adapter; `fetchConsultations(includeInactive: true)` then `restoreConsultation(1)` → last GET has `include_inactive=true`.
- **Out of scope**: table virtualization (T25).

### FE01-T14: Import requirements registry: errors, filters, standard row actions
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: FE01-T06
- **Backend needed**: no (list params `search`, `overall_status`, `risk_level`, `include_inactive`, `import_file_id` exist)
- **Files to change**: `import_requirements_provider.dart`, `import_requirements_screen.dart`, l10n files
- **Steps**:
  1. Provider l.45-50: rethrow the original error (keep the cancel case). Keep `_lastFileId`; `refreshData()` reuses it.
  2. Move status/risk/active/search filtering to query params (debounced search); default `include_inactive=false` unless the Active filter is "All" or "Deleted".
  3. Error view (l.2153): `ApiErrorText.of(l10n, err)` + Retry.
  4. Replace the loose `IconButton`s (l.2337-2395) with `RowActionsPill(onView, onEdit, onPrint, onDelete)`; keep Restore for inactive rows as `onDelete` with restore tooltip (same as other registries). Keep copy-summary as a separate small icon.
  5. Badges/filters: map `Draft/In Progress/Complete/Confirmed` and `Low/Medium/High` to l10n labels (F01-31) via a small map; unknown values show raw.
- **Acceptance criteria**:
  - [ ] After saving while filtered by a file, the list stays filtered.
  - [ ] A 403 shows a localized message.
  - [ ] Row actions look like the PO/CBM registries.
- **Tests to add**: `frontend/test/features/import_requirements/ir_provider_test.dart`: 403 from GET → `AsyncError` whose error is a `DioException`; after `fetchByFileId(5)` and `addRequirement`, last GET has `import_file_id=5`.
- **Out of scope**: assessment form tabs.

### FE01-T15: Real Print for a PO row
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `purchase_orders_screen.dart` (l.776-784), maybe `frontend/lib/features/purchase_orders/widgets/po_report_preview_dialog.dart` (read its public entry point first)
- **Steps**:
  1. Read `po_report_preview_dialog.dart` and find the function that opens the report for a PO.
  2. `onPrint` opens it for the row (desktop table and mobile card, l.4282 area). If no suitable entry exists, remove `onPrint` from both pills.
- **Acceptance criteria**:
  - [ ] Clicking Print opens the PO report preview with Save/Print via `FileSaveHelper` naming `[Stage] - [PO/File code].pdf`.
- **Tests to add**: widget test in `frontend/test/features/purchase_orders/po_row_print_test.dart` that tapping print shows the preview dialog (pump with one PO).
- **Out of scope**: report content.

### FE01-T16: Registry exports follow naming and l10n (CBM, scenarios)
- **Severity**: MAJOR
- **Type**: ux
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `saved_cbm_registry_tab.dart`, `saved_scenarios_registry_tab.dart`, l10n files
- **Steps**:
  1. CBM l.196-219: labels `l.exportExcel`, `l.exportPdf`, `l.copyTable` (add key if missing).
  2. Scenarios per-study export (l.1320-1353): rebuild with `TableExportService.exportTableToExcel` (headers from l10n, rows from `sess.items`), `stageName` = l10n "Shipping scenarios", `importFileNameOrCode` = file code; remove `xlsx` for CSV text.
  3. Add list-level Excel/PDF export buttons to the scenarios registry toolbar (same as CBM).
- **Acceptance criteria**:
  - [ ] Files are named `<Stage> - <File code>.<ext>` and open correctly in Excel.
  - [ ] English UI shows English headers.
- **Tests to add**: `frontend/test/features/shipping_scenarios/scenario_export_rows_test.dart`: pure row builder returns localized headers for `en`.
- **Out of scope**: PDF styling.

### FE01-T17: PO notes and origin list without stored UI text
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: none
- **Backend needed**: optional: a dedicated `discrepancy_justification` field (§6)
- **Files to change**: `po_form_dialog.dart`, `purchase_orders_screen.dart` (where notes are displayed), l10n files
- **Steps**:
  1. l.3391: write `'[PL_DISCREPANCY_JUSTIFICATION] $text'` (fixed token, English, code-like).
  2. Where notes are rendered, replace the token with `l.poDiscrepancyJustificationLabel` (and keep old Arabic-prefixed notes as is).
  3. `countryOptions` (l.95-130): keep codes, take display names from l10n or the countries master provider if one exists (`grep -rn "countriesProvider" frontend/lib`).
- **Acceptance criteria**:
  - [ ] New notes contain no Arabic text added by the app; English UI shows an English label.
- **Tests to add**: `frontend/test/features/purchase_orders/po_notes_token_test.dart`: render helper replaces the token per locale.
- **Out of scope**: origin as FK (backend Q7).

### FE01-T18: Freight quotations screen sweep (l10n, AppTheme, AppButton)
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FE01-T10, FE01-T11 (avoid conflicts)
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/freight_quotations/screens/freight_quotations_screen.dart`, l10n files
- **Steps**:
  1. Replace every `isArabic ? 'x' : 'y'` with an l10n key (prefix `fq`).
  2. `Colors.*` / `Color(0x..)` → `AppTheme.*`; `ElevatedButton/OutlinedButton/TextButton` → `AppButton` variants per the button matrix in the `ui-screen-standards` skill.
  3. l.326: show `rfq.lowestFreightCost` with the RFQ quote currency, not `$`.
  4. Do it in separate commits by section to keep diffs reviewable.
- **Acceptance criteria**:
  - [ ] `grep -cE "isArabic \?|Colors\.|ElevatedButton" freight_quotations_screen.dart` returns 0 (except `Colors.transparent`).
  - [ ] Screen looks the same in Arabic; English UI fully English.
- **Tests to add**: extend `frontend/test/freight_quotations_localization_test.dart` with the new keys (ar/en parity).
- **Out of scope**: extractor dialog (T19).

### FE01-T19: Freight extractor and benchmark dialogs sweep
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: none
- **Backend needed**: no
- **Files to change**: `frontend/lib/features/freight_quotations/widgets/freight_quotations_extractor_dialog.dart`, `widgets/rfq_benchmark_dialog.dart`, `services/freight_quotations_export_service.dart`, l10n files
- **Steps**:
  1. `DropdownButtonFormField` (extractor l.494) → `SearchableDropdownField`.
  2. Arabic literals (117 + 30 lines) → l10n; colours → `AppTheme`; raw buttons → `AppButton`.
  3. Export names (`freight_quotations_export_service.dart:213,274,425`) → `[Stage] - [File code].ext`.
- **Acceptance criteria**:
  - [ ] No `DropdownButtonFormField` in the feature; English UI fully English.
- **Tests to add**: extend `frontend/test/freight_quotations_extractor_test.dart` for the dropdown widget type.
- **Out of scope**: extraction logic.

### FE01-T20: Customs consultation l10n and PDF naming sweep
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FE01-T01 (same screen file)
- **Backend needed**: no
- **Files to change**: `customs_consultation/widgets/price_list_form_dialog.dart`, `services/customs_consultation_pdf_service.dart`, `services/customs_export_service.dart`, `widgets/nafeza_fee_breakdown_card.dart`, l10n files
- **Steps**:
  1. Arabic literals → l10n (PDF services may receive `AppLocalizations` as a parameter).
  2. `Printing.layoutPdf(name: ...epoch...)` → `name: '<stage l10n> - <import file code>'`; any "save" path uses `FileSaveHelper`.
  3. `customs_export_service.dart:94`: the Nafeza 14 % VAT constant must come from data (ask CTO §7 if it is statutory); leave a TODO only if the CTO confirms.
- **Acceptance criteria**:
  - [ ] English UI fully English in price list dialog and PDFs.
- **Tests to add**: extend `frontend/test/customs_consultation_localization_test.dart`.
- **Out of scope**: engine changes (T01).

### FE01-T21: Debounced server search and ApiConstants paths
- **Severity**: MAJOR
- **Type**: bug
- **Depends on**: FE01-T08
- **Backend needed**: no
- **Files to change**: `purchase_orders_provider.dart`, `cbm_calculator_provider.dart`, `shipping_scenarios_provider.dart`, `frontend/lib/core/constants/api_constants.dart`
- **Steps**:
  1. In each `setSearchQuery`, cancel a `Timer? _debounce` and start a 350 ms timer that calls fetch; cancel it in `dispose`.
  2. Add `cbmCalculator` and `shippingScenarios` getters to `ApiConstants` and use them instead of `'/cbm-calculator'`, `'/shipping-scenarios'`.
- **Acceptance criteria**:
  - [ ] Typing "PO-2026" sends one request, not seven.
- **Tests to add**: `frontend/test/features/search_debounce_test.dart` with `fakeAsync`: 5 quick `setSearchQuery` calls → 1 GET.
- **Out of scope**: pagination.

### FE01-T22: Shared server-paged, virtualized table widget
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: none (can be built and tested with client data first)
- **Backend needed**: no for the widget
- **Files to change**: new `frontend/lib/core/widgets/paged_data_table/paged_data_table.dart`, new `frontend/lib/core/widgets/paged_data_table/paged_table_column.dart`, reuse `frontend/lib/core/widgets/compact_table_pagination_footer.dart`
- **Steps**:
  1. API: `PagedDataTable<T>({columns, rows, totalCount, page, pageSize, onPageChanged, onPageSizeChanged, sortColumnId, sortAscending, onSort, isLoading, error, onRetry, emptyMessage, rowActionsBuilder})`. Columns have fixed `width`, `id`, `label`, `sortable`, `cellBuilder`.
  2. Layout: horizontal `Scrollbar` + `SingleChildScrollView` holding a `SizedBox(width: sum(widths))` → `Column(header row (sticky, `AppTheme.charcoal` background), Expanded(ListView.builder(itemExtent: density.rowHeight)))`; actions column first (RTL-aware via `Directionality`).
  3. Footer = `CompactTablePaginationFooter`; header taps call `onSort`.
  4. Loading = shimmer (`enterprise_table_shimmer_skeleton.dart`), error = message + Retry, empty = icon + text.
  5. Only `EdgeInsetsDirectional` / `AlignmentDirectional` (rtl guard test).
- **Acceptance criteria**:
  - [ ] 5,000 fake rows scroll smoothly; only visible rows are built.
  - [ ] Header stays visible on vertical scroll; actions column stays at the start edge.
- **Tests to add**: `frontend/test/core/paged_data_table_test.dart`: pump with 1,000 rows and assert fewer than 60 row widgets built; tapping a sortable header calls `onSort`; footer next page calls `onPageChanged(2)`.
- **Out of scope**: column reordering/persistence.

### FE01-T23: Purchase orders list on server paging
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: FE01-T09, FE01-T22, backend paging (§6 item 1)
- **Backend needed**: yes: `GET /purchase-orders?limit&offset&sort&view=summary` with `X-Total-Count`; `GET /purchase-orders/lookup?search&limit`
- **Files to change**: `po_list_query_provider.dart` (from T09), `purchase_orders_screen.dart`, `purchase_orders_provider.dart`
- **Steps**:
  1. Query provider adds `page`, `pageSize` (default 50), `sort`; reading `X-Total-Count`.
  2. Replace `_buildPOTable` body (l.571-1040) with `PagedDataTable<PurchaseOrderModel>` keeping the same columns/cells (move cell builders to `frontend/lib/features/purchase_orders/widgets/po_table_cells.dart`).
  3. Metrics (count/FOB/CBM/weight) come from the paged response total count; FOB/CBM totals need a backend summary or are labelled "this page".
  4. Exports: request all pages (loop with `limit=500`) or the backend export when available.
- **Acceptance criteria**:
  - [ ] With 10,000 POs the screen opens in under 2 s and pages by 50.
  - [ ] Sorting by PO number / date / FOB works server-side.
- **Tests to add**: `frontend/test/features/purchase_orders/po_paging_test.dart`: adapter returns `X-Total-Count: 120` → footer shows 3 pages at 50; page 2 sends `offset=50`.
- **Out of scope**: lookup migration in other features (separate tasks per feature later).

### FE01-T24: CBM and scenario registries on the shared table
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FE01-T22, FE01-T12; backend paging optional (works client-paged first)
- **Backend needed**: yes for server paging (§6 item 1); no for virtualization
- **Files to change**: `saved_cbm_registry_tab.dart`, `saved_scenarios_registry_tab.dart`, `cbm_calculator_provider.dart`, `shipping_scenarios_provider.dart`
- **Steps**:
  1. Replace the `SingleChildScrollView > DataTable` blocks (CBM l.299-349+, scenarios l.282-294+) with `PagedDataTable`, same columns and `RowActionsPill`.
  2. Until the backend pages, page client-side inside the provider (slice of the loaded list) so the UI contract does not change later.
- **Acceptance criteria**:
  - [ ] Header sticky, rows virtualized, pager visible, count correct.
- **Tests to add**: widget tests per tab in `frontend/test/features/cbm_calculator/cbm_registry_table_test.dart` and `frontend/test/features/shipping_scenarios/scenario_registry_table_test.dart` (rows render, View action opens dialog).
- **Out of scope**: mobile card lists.

### FE01-T25: Consultations and requirements registries server-filtered and paged
- **Severity**: MAJOR
- **Type**: refactor
- **Depends on**: FE01-T13, FE01-T14, FE01-T22
- **Backend needed**: yes for paging (§6 item 1); filters already exist
- **Files to change**: `saved_consultations_tab.dart`, `customs_consultation_provider.dart`, `import_requirements_screen.dart` (registry part only), `import_requirements_provider.dart`
- **Steps**:
  1. Consultations: `PagedDataTable` instead of l.594-606 `DataTable`.
  2. Requirements: keep the `ListView` rows but add count + `CompactTablePaginationFooter` driven by `limit/offset`.
- **Acceptance criteria**:
  - [ ] Both registries show total count and page; search is server-side.
- **Tests to add**: `frontend/test/features/customs_consultation/consultations_paging_test.dart` (offset on page 2).
- **Out of scope**: form tabs.

### FE01-T26: View dialogs load the record by id
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: none (needed before T23/T24 switch to summary payloads)
- **Backend needed**: no (GET by id exists for PO, CBM, scenario, consultation, requirement)
- **Files to change**: new `frontend/lib/features/purchase_orders/providers/po_detail_provider.dart` (`FutureProvider.autoDispose.family<PurchaseOrderModel, int>`), `purchase_orders_screen.dart` (`_showPODetailsDialog` l.1042), and the same small provider + dialog change in `saved_cbm_registry_tab.dart`, `saved_scenarios_registry_tab.dart`, `customs_consultation/widgets/consultation_details_dialog.dart`
- **Steps**:
  1. Dialog opens immediately with the list row as placeholder, watches the detail provider, shows a thin progress bar while loading, replaces content when loaded, shows error + Retry on failure.
  2. After any mutation of that record, `ref.invalidate(poDetailProvider(id))` (and equivalents).
- **Acceptance criteria**:
  - [ ] Edit a PO in another tab, open View here: fresh values.
  - [ ] A deleted record shows a localized 404 message.
- **Tests to add**: `frontend/test/features/purchase_orders/po_detail_provider_test.dart`: GET `/purchase-orders/7` is called once per open; error state on 404.
- **Out of scope**: dialog redesign. If more than 5 files are needed, split per feature (T26a PO, T26b CBM+scenarios, T26c consultation).

### FE01-T27: Broker price list read-only View and honest clone dialog
- **Severity**: MAJOR
- **Type**: feature
- **Depends on**: none
- **Backend needed**: optional `copy_items` support in `CloneBrokerPriceListRequest` (§6)
- **Files to change**: `frontend/lib/features/customs_consultation/widgets/broker_price_lists_tab.dart`, new `frontend/lib/features/customs_consultation/widgets/price_list_view_dialog.dart`, l10n files
- **Steps**:
  1. Add a View icon (eye) before Edit (l.237) opening a read-only dialog: header (code, title, broker, port, validity, version, status) + items table (expense type, unit, price, currency).
  2. Clone (l.250-283): `allowCopyLineItems: false` and stop sending `copy_items` until backend supports it.
- **Acceptance criteria**:
  - [ ] A user can inspect a price list without opening the edit form.
  - [ ] Clone dialog does not offer an option that is ignored.
- **Tests to add**: `frontend/test/features/customs_consultation/price_list_view_dialog_test.dart`: renders items count and broker name.
- **Out of scope**: price list edit form.

### FE01-T28: Phase-1 dead code and header hygiene
- **Severity**: MINOR
- **Type**: refactor
- **Depends on**: FE01-T05
- **Backend needed**: no
- **Files to change**: delete `frontend/lib/features/freight_quotations/screens/freight_quotations_comparison_screen.dart` (after `grep -rn FreightQuotationsComparisonScreen frontend/lib frontend/test` shows no runtime use), `frontend/lib/core/providers/navigation_provider.dart` (comment l.81), `saved_cbm_registry_tab.dart` (`_showContainerComparisonDialog`, l.1676), `purchase_orders_screen.dart` (header l.120-153)
- **Steps**:
  1. Remove the dead screen and method; fix the index comment to `49 = FreightQuotationsScreen`.
  2. PO header: keep only `BackToDashboardButton` (+ primary if moved); move Smart Upload into the toolbar primary actions; drop the header refresh (toolbar already has one).
  3. If `frontend/test/freight_quotations_comparison_localization_test.dart` only covers the deleted screen, keep its l10n keys test but drop widget references.
- **Acceptance criteria**:
  - [ ] `flutter analyze` clean on touched files; PO header has at most 2 actions.
- **Tests to add**: none new; existing tests stay green.
- **Out of scope**: other god-file splits (FE-05).

---

## 6. Backend dependencies (short)

1. **List paging** for `purchase_orders`, `cbm_calculator`, `shipping_scenarios`, `customs_consultation`, `import_requirements`, `freight_quotations`:
   additive `limit` / `offset` / `sort` query params and an `X-Total-Count` response header (no envelope, so existing callers keep working).
   PO list also `view=summary` (no `items` / `packing_list_items`) and a light `GET /purchase-orders/lookup?search&limit` for pickers.
2. **PO exports**: optional `GET /purchase-orders/export-excel|export-pdf` and `/template` + `POST /import-excel` if the CTO wants server-side
   exports; until then T05 exports client-side.
3. `PurchaseOrderCreate.exchange_rate` defaults to `1.0` (`modules/purchase_orders/schemas.py:181`): should be required (or default only for base currency).
4. `CloneBrokerPriceListRequest` has no `copy_items` (`modules/customs_consultation/schemas.py:134-139`); service always copies items.
5. Customs consultation create: confirm whether `broker_id` may be null in tax-review mode (T02).
6. Import requirements `overall_status` / `risk_level` are free English text (`modules/import_requirements/schemas.py:124-125`); enum codes would let Flutter label them properly.
7. Freight RFQ: confirm what `chargeable_weight_kg` the update/create schema expects and whether the backend computes it (T10).

## 7. Open questions for the CTO

1. Pagination size and default sort per list (proposal: 50 rows, newest first). Should the metric cards show totals for the full filtered set
   (needs a backend summary endpoint) or only for the current page?
2. Do you want server-side Excel/PDF exports of the full PO list (backend work) or is client export of the current filter enough?
3. Customs consultation "Case A" (file has invoices but no PO lines): hide estimates completely, or estimate per invoice using the file's
   main HS codes through the engine?
4. Nafeza services VAT 14 % in `customs_export_service.dart:94`: statutory constant or should it come from settings?
5. Freight RFQ: is one RFQ per import file the rule (then "save" should always update the file's RFQ), or can a file have several RFQs?
6. Should viewers (read-only roles) see Edit buttons disabled or hidden on Phase-1 registries?
