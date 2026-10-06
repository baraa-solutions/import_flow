# Phase 02 Financial approval: frontend review

Status: 2026-10-05 · static review only (no `flutter test`, no `pytest`, no `import main`, no code edits).
Previous wave: `docs/plans/phase-02-quality-plan.md` (FE-01..FE-10). Items verified fixed in the current code are not re-reported:
FE-01 (AsyncActionButton with spinner + SnackBar), FE-02 (no 50.0 rate; rate field empty + required), FE-03 (`Colors.*` gone from widgets; only `PdfColors` remain),
FE-05 (provider rethrows; `ApiError.message` used), FE-06 (filters kept in `_refresh`, `importFilesProvider` invalidated), FE-07 (payment type is a
`SearchableDropdownField` over codes), FE-08 (no `user_name` / `approved_by` sent). FE-04, FE-09, FE-10 are still open (see F02-22, F02-12).

Screens in scope (no go_router for this phase; index-based navigation in `frontend/lib/features/home/home_screen.dart:115-117,169`, indexes 8/9/10/46 in
`frontend/lib/core/providers/navigation_provider.dart:50-52,78`):
- `FinancialApprovalScreen` with 5 vertical tabs: 0 Payment request form (BP-012), 1 Import budget form (BP-013), 2 Saved budgets registry,
  3 Payment requests registry, 4 SWIFT MT103 reconciliation (embedded `SwiftReconciliationScreen`).
- `SwiftReconciliationScreen` (also standalone, index 46).
- `showSupplierAdvancePaymentDialog` (opened from `import_files/widgets/import_file_details_dialog.dart`).

Coverage depth:

| file | lines | depth |
|---|---|---|
| `frontend/lib/features/financial_approval/screens/financial_approval_screen.dart` | 6466 | Full read l.1-3125 and l.3126-6125; l.2937-3120 (share dialogs) and l.6126-6466 (SWIFT box) grep-swept |
| `frontend/lib/features/financial_approval/providers/financial_approval_provider.dart` | 650 | Full |
| `frontend/lib/features/financial_approval/models/financial_approval_model.dart` | 757 | Full, every `json[...]` key checked against `modules/financial_approval/schemas.py` |
| `frontend/lib/features/financial_approval/screens/swift_reconciliation_screen.dart` | 3149 | Read l.45-605, 1100-1210, 1380-1400, 1640-1680, 2380-2470, 2660-2790; rest grep-swept |
| `frontend/lib/features/financial_approval/widgets/saved_budgets_registry_tab.dart` | 1607 | Read l.1-460, 700-1020, 1460-1607; rest grep-swept |
| `frontend/lib/features/financial_approval/widgets/supplier_advance_payment_dialog.dart` | 1054 | Read l.100-410; rest grep-swept |
| `frontend/lib/features/financial_approval/widgets/financial_ui.dart` | 218 | Full |
| `frontend/lib/features/financial_approval/widgets/async_action_button.dart` | 58 | Full |
| `frontend/lib/features/financial_approval/services/financial_export_service.dart` | 1572 | Grep sweep (save path, names, Arabic literals, `paymentType`) |
| `widgets/search_and_clone_*_dialog.dart`, `widgets/swift_extraction_review_widget.dart` | 447+450+1016 | Grep sweep only |
| Backend contract: `modules/financial_approval/router.py`, `schemas.py`, `validators.py` (l.1-60), `repository.py` (list functions) | 439+429+236+481 | Targeted |
| Shared: `core/widgets/row_actions_pill.dart`, `compact_table_pagination_footer.dart`, `enterprise_data_table/`, `import_files_provider.dart` (paginated pattern), `.claude/skills/ui-screen-standards/SKILL.md` | - | Targeted |

---

## 1. Summary

| BLOCKER | CRITICAL | MAJOR | MINOR |
|---|---|---|---|
| 1 | 6 | 19 | 13 |

Most important points:
1. **SWIFT smart reconcile invents data (BLOCKER, F02-01).** When the extracted SWIFT lacks a reference / date / amount / currency, the screen sends
   `SWIFT-<timestamp>`, today's date, the *requested* amount (so the variance is always "Matched") and the payment currency. The payment is marked Paid on fabricated values.
2. **Budget form "Approve & Certify" does not approve (CRITICAL, F02-02)** – it calls the same `_saveImportBudget` as "Save Draft". Users believe the budget is approved; it stays Pending Review.
3. **Wrong money in the budget form and View dialog (CRITICAL, F02-03, F02-04, F02-07)** – freight EGP is computed with the *invoice* exchange rate; the budget View dialog silently shows
   the numbers typed in the form whenever a saved field is 0; the client prefill fallback adds PO amounts of different currencies together.
4. **Clone creates duplicates (CRITICAL, F02-05) and the payment duplicate guard blocks legitimate second payments (CRITICAL, F02-06).**
5. **CTO topics:** (A) all three lists load the full table in one request (backend has no paging for these endpoints) and two of them build every row eagerly inside nested
   `SingleChildScrollView` + `DataTable` with a header that scrolls away; (B) a View action **exists** on all three lists, but the budget View has two different
   implementations, neither is fetched by id, and the registry one has no Approve / variance actions. Details in sections 3 and 4.

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F02-01 | BLOCKER | `screens/swift_reconciliation_screen.dart:417-427`, `:441-454` | `_executeSmartReconciliation` fills missing values: ref `'SWIFT-${DateTime.now().millisecondsSinceEpoch}'`, date `DateTime.now()`, amount `?? pay.requestedAmount`, currency `?? pay.currencyCode`, then calls `smartReconcileSwift(autoExecute: true)` → payment becomes Paid with an invented SWIFT and a fake "Matched" variance. | Never default. If ref, value date, amount (>0) or currency is missing, block with a SnackBar listing the missing fields and send the user to the review widget / manual dialog. |
| F02-02 | CRITICAL | `screens/financial_approval_screen.dart:4864-4875` | Button labelled `approveAndCertifyBudget` calls `_saveImportBudget` (same as Save Draft at :4853-4862). No approve call. | Make it "Save & Approve": save, then `importBudgetsProvider.notifier.approveImportBudget(id)`; show backend error (hard block, 403). In edit mode on an approvable status keep the same behaviour. |
| F02-03 | CRITICAL | `financial_approval_screen.dart:609-618`, `:4555-4563`, `:4679-4689`, `:4711-4728` | Freight EGP = freight foreign × **invoice** rate (`_bgtExchangeRateController`) whenever the user types, and on prefill when the freight currency has no rate. Freight in EUR on a USD invoice is converted at the USD rate. Invoice and freight currency cannot be changed (no picker; values only come from prefill or `'USD'` default :113-114). | Add `SearchableDropdownField` for invoice currency and freight currency and a separate freight rate field (prefilled from `_getExchangeRateForCurrency(freightCurrency)`, empty + required when unknown). Freight EGP = freight × freight rate. Never fall back to the invoice rate. |
| F02-04 | CRITICAL | `financial_approval_screen.dart:5637-5665` (used by View dialog :2786-2787) | `_buildConsolidatedBudgetSummary(bgt: …)` uses `bgt.x > 0 ? bgt.x : double.tryParse(<form controller>)`. A saved budget with freight/customs/clearance = 0 shows the values currently typed in the Budget form (another budget) and a wrong grand total. | When `bgt != null`, read only `bgt` fields (0 stays 0; grand total = `bgt.totalBudgetEgp`). Form controllers only when `bgt == null`. |
| F02-05 | CRITICAL | `financial_approval_screen.dart:1252-1293`, `:1455-1494` | Clone: backend `/clone` creates a new Draft, then the *source* values are loaded into the form in create mode (`_editingPaymentId = null`). Pressing Save creates a second record (or hits backend 409 duplicate). If `/clone` fails, the error is swallowed (`catch (_) {}`) and a success SnackBar shows the source code. | On success: `_loadPaymentRequestForEdit(cloned)` / `_loadBudgetForEdit(cloned)` (edit the clone). On failure: rethrow → error SnackBar, form untouched. Remove the "client-side fallback". |
| F02-06 | CRITICAL | `financial_approval_screen.dart:293-343` | Selecting an import file that already has **any** active payment request (even Paid/Rejected, any type) opens a blocking "duplicate" dialog and clears the file. Backend only blocks one *open* (Draft/Pending/Approved) request **of the same payment_type** (`validators.py:31`, `service.py:299`). Balance / final payments cannot be issued from this form. The check also uses the client list, which may be filtered. | Remove the file-select guard. Warn (non-blocking banner) when an open request of the *same selected type* exists; rely on backend 409 `FA_PAYMENT_DUPLICATE_TYPE` at save (already shown by `_showApiError`). |
| F02-07 | CRITICAL | `financial_approval_screen.dart:363-395`, `:567-598`; `widgets/supplier_advance_payment_dialog.dart:192-205`, `:237-239` | When the backend prefill fails (e.g. 400 `FA_FX_RATE_MISSING` / `FA_CURRENCY_MISSING`) or returns 0, the client re-computes the invoice total by summing linked PO amounts **across currencies** (last PO currency wins, default `'USD'`), duplicating backend prefill logic and bypassing its currency checks. | Use the backend prefill only. On error/0: leave amount and currency empty (required) and show the backend message. Delete the client fallback chain. |
| F02-08 | MAJOR | `financial_approval_screen.dart:1333-1396`, `:4166-4181`, `:1602-1609` | "Clone PO allocation" inserts a fake PO row (`poId: 0`) into the prefill and adds its amount to `totalInvoiceAmount`, converted at the invoice rate whatever the PO currency. That inflated total drives the 10-100 % advance chips (:83-92). Not persisted anywhere. | Remove the clone-PO-allocation action (rows are read-only reference data). |
| F02-09 | MAJOR | `financial_approval_screen.dart:2502-2547`; registry row `:5293-5310` | Payment workflow actions missing: no "Submit for approval" (Draft→Pending Approval), no "Reject" (with reason), no "Return to Draft" (Rejected→Draft). Backend supports them via PUT `status` (`validators.py` `PAYMENT_USER_TRANSITIONS`). | Add status-aware actions in the payment View dialog using `updatePaymentRequest(id, {'status': ..., 'notes'?, 'version'})`. |
| F02-10 | MAJOR | `financial_approval_screen.dart:5297-5309`; `widgets/saved_budgets_registry_tab.dart:443-449`, `:757-763` | Edit and Delete are always enabled. Approved/Paid payments and Budget Approved/Superseded budgets are locked by the backend (409 `FA_PAYMENT_LOCKED` / `FA_BUDGET_LOCKED`) – user edits the whole form then fails. | Pass `onEdit`/`onDelete: null` (disabled) for locked statuses; tooltip with the reason. |
| F02-11 | MAJOR | `financial_approval_screen.dart:2915-2916`; `saved_budgets_registry_tab.dart:897-1287` | Approve budget shown only for `Pending Review`/`Draft`; backend also allows `Needs Revalidation` (`validators.py` `BUDGET_APPROVABLE`). The registry View dialog has no Approve, no Recalculate, no variance info – approval is only reachable from the form tab's dialog. | One shared budget details dialog (see F02-12) with Approve for Draft / Pending Review / Needs Revalidation. |
| F02-12 | MAJOR | `financial_approval_screen.dart:2739-2935` vs `saved_budgets_registry_tab.dart:897-1287` (+ two WhatsApp/email share copies each) | Two different budget-details dialogs and duplicated share dialogs (business-logic duplication; FE-10 god files still open: 6466 + 3149 lines). | Extract `widgets/budget_details_dialog.dart` used by both places. |
| F02-13 | MAJOR | `financial_approval_screen.dart:5084-5096` | Payment registry status filter: options All/Draft/Approved/Paid/**Reconciled**. "Reconciled" is not a payment status (always empty); "Pending Approval" and "Rejected" missing; "Approved" uses label `approvedBudgetsMetric`. | Options = backend `PaymentStatusFilter` (All, Draft, Pending Approval, Approved, Paid, Rejected) with proper labels. |
| F02-14 | MAJOR | `widgets/financial_ui.dart:93-113` | `statusStyle` maps only paid/reconciled/approved/pending/draft. `Rejected`, `Needs Revalidation`, `Superseded`, `Budget Exceeded` render raw English; "Pending Approval" renders as "Pending Review". | Explicit map for every backend status (payments + budgets) with l10n labels and severities. |
| F02-15 | MAJOR | `financial_approval_screen.dart:1234`, `:2348`, `:5280`, `:5457-5472`; `services/financial_export_service.dart:655,829,911,982`; `swift_reconciliation_screen.dart:1666` | Payment type shown as the raw code (`ADVANCE_PAYMENT`) in the registry, View dialog, clone summary, exports and SWIFT target list. `FinancialUi.paymentTypeLabel` exists but is unused there. | Use `FinancialUi.paymentTypeLabel(l, code)` everywhere a payment type is displayed. |
| F02-16 | MAJOR | `financial_approval_screen.dart:5149-5160`, `:5288-5290`, `:5352-5359`, `:6132-6134` | Registry table container and rows use `AppTheme.white` / `AppTheme.charcoal` text; SWIFT extractor box background `AppTheme.white` – unreadable in dark mode. | Use `isDark ? AppTheme.darkCardBackground : AppTheme.white` etc., like the budget tab. |
| F02-17 | MAJOR | `financial_approval_screen.dart:2486-2494` | "Extract & match SWIFT" in the payment View dialog sets `_tabController.index = 3` (Payment Requests Registry). SWIFT tab is index 4. | Use 4 (and `_visitedTabs.add(4)`). Better: open the SWIFT screen pre-targeted to this payment. |
| F02-18 | MAJOR | `widgets/saved_budgets_registry_tab.dart:52-53`, `:337-338` | `budgetsState.valueOrNull ?? []`: while loading and on API error the tab shows "No budgets" + "Approve new budget" (error hidden, no retry). | `budgetsState.when(loading: FinancialStateView.loading, error: FinancialStateView.error(retry), data: …)`. |
| F02-19 | MAJOR | `swift_reconciliation_screen.dart:2749-2761`, `:1650-1666` | "Register/Edit SWIFT" is offered for every payment (Draft, Pending, Rejected, Paid) though the backend only reconciles Approved (400/409). Target-payment dropdown lists every active payment with raw `[status]`. | Enable register only for `Approved` without `swiftReferenceNo`; target list = Approved & unreconciled; localized status. |
| F02-20 | MAJOR | `swift_reconciliation_screen.dart:494-496`, `:1139-1142` | Manual reconcile dialog: transferred currency is a free `TextFormField` with `'USD'` fallback (master data as free text). | `SearchableDropdownField<String>` over `currenciesProvider`, required, default = payment currency. |
| F02-21 | MAJOR | `financial_approval_screen.dart:1889-2092`, `:2098-2116` | 200-line client-side MT103 regex parser duplicates the backend parser; backend errors (403/422/500) are swallowed (`catch (_)`) and the client parser runs instead, defaulting currency to `'USD'` and amount to 0. | Remove `_parseSwiftClientFallback`; show `ApiError.message(e)` on backend failure. |
| F02-22 | MAJOR | `services/financial_export_service.dart` (122 Arabic-literal lines; names at :546, :842, :886, :935, :1177; `Printing.layoutPdf` at :462, :802, :1545) | Still open FE-04 / FE-09: hard-coded Arabic labels in exports, file names `Phase2_..._<millis>.csv` instead of `[Stage Name] - [Import File Code].ext`, "Excel" buttons produce CSV, PDFs go to the print dialog instead of `FileSaveHelper.exportAndSaveFile`. | l10n labels; names via one helper `"<stage> - <importFileCode>.<ext>"`; PDF bytes → `FileSaveHelper.exportAndSaveFile`. |
| F02-23 | MAJOR | `financial_approval_screen.dart:5108-5585`; provider `:59-98` | Payment registry: full list in one call, client filter computed twice (:5028, :5123), `DataTable` with all rows inside horizontal + vertical `SingleChildScrollView` (no virtualization, header not sticky, no sort, no paging). See section 3. | Phase A paging client-side; Phase B server pagination (T11/T12). |
| F02-24 | MAJOR | `swift_reconciliation_screen.dart:2449`, `:2674-2790` | SWIFT table: all rows eager inside the page `SingleChildScrollView`; header scrolls away; KPIs and filters client-side over the full list. | See T14. |
| F02-25 | MAJOR | `saved_budgets_registry_tab.dart:89-108`, `:339-346`, `:352-828` | Budgets registry: `ListView.builder` (lazy – good) but each card is ~470 lines with 13 buttons; full list; client filter only All/Approved/Pending; `Superseded` and `Needs Revalidation` budgets mixed in "All" and coloured like pending; no sort/paging. | See T13. |
| F02-26 | MAJOR | `financial_approval_screen.dart:2516-2547`, `:2502-2511` | Approve and Mark-as-Paid are irreversible money actions with no confirmation step; Mark-as-Paid accepts an empty SWIFT reference. | Confirmation dialog (amount, currency, beneficiary); SWIFT ref required for Mark-as-Paid (or explicit "without SWIFT" choice). |
| F02-27 | MINOR | `financial_approval_screen.dart:1656-1678` | When currencies fail to load, a hard-coded list (USD, EUR, EGP, GBP, CNY, SAR, AED) is offered – master data invented on the client. | Show the load error + retry; no hard-coded list. |
| F02-28 | MINOR | `financial_approval_screen.dart:3212`, `:3233`, `:4817-4829`, `:5054-5056`, `:5113-5115`; `swift_reconciliation_screen.dart:80`, `:3104` | Refresh buttons call `fetchPaymentRequests()` / `fetchImportBudgets()` without args, resetting the filters the provider remembers. | Add public `refresh()` (calls `_refresh`) in both notifiers and use it. |
| F02-29 | MINOR | `financial_approval_screen.dart:5258-5261`; `saved_budgets_registry_tab.dart:431`, `:948` | Fallback `'IMP-${importFileId}'` shows a DB id (FA-25 remnant; backend now fills `import_file_code`). | Show `-` when the code is null. |
| F02-30 | MINOR | `financial_approval_screen.dart:1709-1747`, `:1724`, `:1744`, `:5553-5557` | Date pickers `lastDate: DateTime(2030)`; dates displayed as raw ISO substrings, not localized. | `lastDate: DateTime.now().add(Duration(days: 3650))`; format with the app date formatter. |
| F02-31 | MINOR | `financial_approval_screen.dart:4834-4850`, `:3317-3330`, `:4209-4223` | Budget "Reset" keeps title, amounts, currencies, rate; payment "Cancel edit" (header) keeps rate/bank/SWIFT/IBAN while the footer one clears them. | One `_resetPaymentForm()` / `_resetBudgetForm()` used everywhere. |
| F02-32 | MINOR | `financial_approval_screen.dart:4519-4626`, `:4631-4779`; `:3409`, `:4410` | Budget numeric fields have no validators (negative → backend 422); "Import File *" marked required but "Not linked" accepted. | Validators `>= 0`; decide required vs optional (Q5) and align the label. |
| F02-33 | MINOR | `swift_reconciliation_screen.dart:438`, `:452`; `financial_approval_screen.dart:1256-1257`, `:1459` | Stored notes are UI strings (`swiftScreenSubtitle` in the user's language) or English literals ("Cloned via Smart Financial Review Dialog"). | Send `null` / a fixed English code-like note; never l10n text to the DB. |
| F02-34 | MINOR | `financial_approval_screen.dart:1229`, `:1428` | Clone review shows `suggestedNewCode: '<code>-CLONE'`, but the backend generates a new PAY/BGT code. | Show "auto-generated" text instead of a fake code. |
| F02-35 | MINOR | `financial_approval_screen.dart:3695-3700` | Advance % chip label shows the base amount with `_currencyCode` (form currency) while the base is in `prefill.invoiceCurrency`. | Use `_payPrefillData!.invoiceCurrency`; hide chips if currencies differ. |
| F02-36 | MINOR | `widgets/financial_ui.dart:58-62` | `normalizePaymentType` maps any unknown value to `ADVANCE_PAYMENT`; editing a legacy record silently changes its type; prefill `payment_terms_summary` ("Multiple (...)") also becomes Advance. | Unknown → keep empty and require a choice. |
| F02-37 | MINOR | `providers/financial_approval_provider.dart:391-411`, `:543-552`, `:602-649`; `models/financial_approval_model.dart:590-620` | `restorePaymentRequest`, `restoreImportBudget`, `syncBudgetWithUpstream`, `overrideBudgetVariance`, `fetchBudgetVarianceLogs` have no UI caller; `BudgetSyncResultModel` ignores `message_code` / `message_params`. | Use `fetchBudgetVarianceLogs` in the budget dialog (T09); delete or wire the rest. |
| F02-38 | MINOR | `financial_approval_screen.dart:3136-3199`, `:3216-3241` | Tab titles are inline `titleEn`/`titleAr` literals; `stageCode: 'PHASE-1: STEP_04'`; no `BackToDashboardButton` in `headerActions` (ui-screen-standards checklist #3). | l10n keys; add `const BackToDashboardButton()` last. |
| F02-39 | MINOR | `financial_approval_screen.dart:242-245` | `initialImportFileId` triggers both pay and budget selection; both duplicate dialogs can pop at once. | Run only the selection for `initialIndex`. |

(Severity count: BLOCKER 1 · CRITICAL 6 · MAJOR 19 · MINOR 13.)

---

## 3. Large tables

Backend fact for all lists: `GET /financial-approval/payment-requests` and `GET /financial-approval/import-budgets` return `List[...]` with no `page`/`page_size`/`sort`
(`modules/financial_approval/router.py:217-229`, `:312-325`; `repository.py:159`, `:305` `.all()`). Search exists server-side (`search`, `status`, `budget_status`) but the
Flutter screens filter client-side on the full list. A working pattern already exists in the project: `GET /import-files/paginated` (`modules/import_files/router.py:91-135`,
`PaginatedImportFilesResponse{items,total,page,page_size,total_pages}`) and `paginatedImportFilesProvider` (`frontend/lib/features/import_files/providers/import_files_provider.dart:52-129`),
plus the footer widget `frontend/lib/core/widgets/compact_table_pagination_footer.dart`.

| list | current behaviour (evidence) | with 5,000+ rows | recommended |
|---|---|---|---|
| Payment requests registry (tab 3) | Provider fetches all (`financial_approval_provider.dart:59-98`). Filter list computed twice per build (`financial_approval_screen.dart:5028-5045`, `:5123-5140`). `SingleChildScrollView(horizontal)` → `SingleChildScrollView(vertical)` → `DataTable` with every row (`:5165-5172`). Header is inside the vertical scroll (not sticky); actions column not sticky; no sort; count only in the title (`:5050`). Each row resolves shipment names over the full import-files list (`:5262-5273`, O(rows × files)). Export = the loaded filtered list (`:5051-5053`). | Slow first load (one big JSON), every keystroke rebuilds all rows, header lost when scrolling, jank. | **Phase A (FE only, T11):** page the filtered list client-side (50 rows) with `CompactTablePaginationFooter`, header row outside the vertical scroll (sticky), `Scrollbar`s, compute filtered list once, build a `Map<String, ImportFile>` once per build. **Phase B (T12, backend):** `GET /payment-requests/paginated` (page, page_size, sort_by, sort_dir, search, status, swift_status, import_file_id, date range; response with `total` and KPI totals); 300 ms debounced search; KPIs from the response; "Export all" fetches all pages (or a server CSV endpoint). |
| Saved budgets registry (tab 2) | Full list (`provider:459-498`); client filter (`saved_budgets_registry_tab.dart:89-108`); `ListView.builder` (`:339-346`, lazy, good); each card is a large widget with 13 buttons (`:352-828`). No sort, no paging, status chips All/Approved/Pending only. | Lazy list survives, but full download + KPI fold over everything; superseded revisions accumulate. | T13: hide Superseded by default (toggle), add Needs Revalidation chip, compact the card (actions in `RowActionsPill` + overflow menu), then server paging like Phase B (`/import-budgets/paginated`). |
| SWIFT reconciliation table (tab 4 / screen 46) | Full payment list (`swift_reconciliation_screen.dart:2388-2389`), client filter (`:2392-2416`), metrics over full list (`:2419-2446`). `DataTable` in a horizontal scroll inside the page `SingleChildScrollView` (`:2449`, `:2674-2676`) → all rows eager, header scrolls away. | Same as payments registry; also the SWIFT box above pushes the table down. | T14: same Phase A paging + sticky header; Phase B reuse the paginated endpoint with `swift_status` filter (PENDING = no SWIFT ref, MATCHED, DEFICIT, SURPLUS). |
| Import-file pickers (forms tab 0/1) | Items = whole `importFilesProvider` list (`financial_approval_screen.dart:3416-3428`, `:3462-3476`, `:4417-4428`, `:4463-4476`). | Dropdown with thousands of items, full list loaded at mount (`:226-228`). | Use a server search picker on `/import-files/paginated?search=` (top 20). Keep current list until then. |
| SWIFT target payment picker | All active payments (`swift_reconciliation_screen.dart:1650-1670`). | Thousands of items, including Paid/Draft. | Only Approved & unreconciled (T14); server filter once Phase B exists. |
| Search & clone dialogs | Receive the loaded list (`financial_approval_screen.dart:1200`, `:1399`), `ListView.separated` (lazy). | OK for now; only sees the filtered/loaded rows. | After Phase B: query the paginated endpoint with `search`. |

---

## 4. View/Show action

| entity / list | View exists? | evidence | gap / why | what to add |
|---|---|---|---|---|
| Payment request (registry tab 3) | Yes | `RowActionsPill(onView: _showPaymentDetailsDialog(p))` `financial_approval_screen.dart:5293-5296`; dialog `:2315-2552` | Shows the list snapshot (no GET by id although `GET /payment-requests/{id}` exists, `router.py:232`). Missing fields: import file code/name, PO/PI, advance %, notes, SWIFT reconciliation block (ref, receipt date, transferred amount, variance, processing days), created/updated. Payment type raw code; no Reject / Submit; "Extract & match SWIFT" goes to the wrong tab (F02-17). | Fetch by id on open (`getPaymentRequest(id)` in provider), add the missing sections, status-aware actions (T08). |
| Import budget (registry tab 2) | Yes, two versions | Registry: `saved_budgets_registry_tab.dart:442`, `:740-746` → `_showBudgetDetailsDialog` `:897`. Screen: `_showBudgetDetailsDialog` `financial_approval_screen.dart:2739` (opened after save and from the duplicate dialog) | Two implementations with different content. Registry one: no Approve, no Recalculate, no variance logs, no revision chain (parent/revision number), no override reason. Screen one: shows form values for 0 fields (F02-04), hides Approve for Needs Revalidation. Neither fetches by id (`GET /import-budgets/{id}` exists, `router.py:416`). | One `widgets/budget_details_dialog.dart` (T09): fetch by id, cost table, approval info (`approved_by`, `approved_date`), revision info, variance log list (`fetchBudgetVarianceLogs`), Approve / Recalculate / Edit (status-aware). |
| SWIFT reconciliation row | Yes | `IconButton(Icons.visibility) → _showSwiftDetailsDialog(pay)` `swift_reconciliation_screen.dart:2764-2771`; dialog `:1193` | Works; "Edit" offered for reconciled Paid rows that the backend rejects (F02-19). | Status-aware Edit (T14). |
| SWIFT review batches | No | Only the current extraction is kept in state (`_currentBatch`, `swift_reconciliation_screen.dart:72`) | No list endpoint: backend has only `GET /swift/review-batch/{id}` (`router.py:122-127`). Past batches (who confirmed which MT103, which payment it settled) cannot be viewed. | Backend `GET /swift/review-batches` (paged) + a read-only batch history list (backlog, Q6). |
| Budget variance logs | No | Provider `fetchBudgetVarianceLogs` (`financial_approval_provider.dart:638`) has no caller | No screen/section uses it. | Section inside the shared budget dialog (T09). |
| Linked PO rows (payment form) | No (not needed) | `financial_approval_screen.dart:3938-4188` | Reference rows; clone action should be removed (F02-08). | Optional: open the PO View from the PO number. |

Why it felt like "no Show": on the payment registry the View icon is the first icon of the pill but opens a short summary; on the budget registry the View exists but
lacks the decisive actions (Approve), so users go through Edit, which loads the record into the form tab (`_loadBudgetForEdit`) – and editing an approved budget then fails with 409.

---

## 5. Tasks

> For the executor (Antigravity, no context): read `AGENTS.md`, `.agents/rules/CORE_RULES.md`, `.claude/rules/flutter.md` first. Every new user-facing string goes into
> `frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`. Colours only from `AppTheme`. Use
> `EdgeInsetsDirectional`/`AlignmentDirectional`. After each task run `cd frontend && flutter test test/features/financial_approval` and `flutter analyze lib/features/financial_approval`.
> No version bump, no packaging. Append a line to `history/2026-10-05.md` (append-only).

### FE02-T01 SWIFT smart reconcile: stop inventing reference, date, amount, currency
- **Severity:** BLOCKER · **Type:** bug · **Depends on:** none · **Backend needed:** no
- **Files to change:** `frontend/lib/features/financial_approval/screens/swift_reconciliation_screen.dart`; the 3 l10n files.
- **Steps:**
  1. In `_executeSmartReconciliation` (l.413-482) read `transaction_reference`, `value_date`, `amount`, `currency` from `_extractedSwift` with **no** `??` defaults.
  2. Build a list of missing fields (ref empty, date not parseable, amount null or <= 0, currency empty). If not empty: show a SnackBar (`AppTheme.orange`) `l10n.swiftReconcileMissingFields(fields)` and return without calling the provider.
  3. When `_currentBatch != null` and `_currentBatch!.status != 'REVIEWED_CONFIRMED'` (and not RECONCILED for the same payment), block with `l10n.swiftBatchNotConfirmed` instead of calling `reconcileReviewedSwiftBatch`.
  4. Replace `notes: storedText.swiftScreenSubtitle` / `swiftReconciliationNotes: l10n.swiftScreenSubtitle` (l.438, l.452) with `null`.
  5. Manual dialog (l.484-1191): replace the currency `TextFormField` (`currencyController`) with `SearchableDropdownField<String>` over `ref.watch(currenciesProvider)`, default = `pay.currencyCode`, validator required; remove the `'USD'` fallback at l.1139-1142.
- **Acceptance criteria:**
  - [ ] Extracted text without `:20:` reference → no API call, orange SnackBar naming "SWIFT reference".
  - [ ] Extracted amount missing → no "Matched" result; user must enter it in the manual dialog.
  - [ ] Manual dialog currency is a searchable list of currencies; empty → red validator text.
- **Tests to add:** `frontend/test/features/financial_approval/swift_smart_reconcile_guard_test.dart` – pump the screen with a fake `PaymentRequestsNotifier` (override `paymentRequestsProvider`), set extracted data without reference, tap reconcile, assert `smartReconcileSwift` / `reconcileReviewedSwiftBatch` were **not** called and the SnackBar text is shown.
- **Out of scope:** backend parser changes; moving the screen to smaller files.

### FE02-T02 Budget form: "Approve & Certify" must approve
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** no (`POST /import-budgets/{id}/approve` exists)
- **Files to change:** `frontend/lib/features/financial_approval/screens/financial_approval_screen.dart`; l10n files.
- **Steps:**
  1. Split `_saveImportBudget()` (l.2196-2313) into `Future<ImportBudgetModel?> _persistBudget()` (returns the saved model, no dialog) and the existing UI wrapper.
  2. New `_saveAndApproveBudget()`: `final saved = await _persistBudget(); if (saved == null) return;` then `await ref.read(importBudgetsProvider.notifier).approveImportBudget(saved.budgetId)`; on success SnackBar `l10n.budgetApprovedSuccess(code)` and `_showBudgetDetailsDialog(approved)`; on error `_showApiError(e)` (hard block / 403 / 409 are coded errors).
  3. Bind the "4. Final Approval" button (l.4864-4875) to `_saveAndApproveBudget`, label `l.saveAndApproveBudget`; keep "Save Draft" on `_saveImportBudget`. Show `isLoading` on both buttons while saving.
  4. In `_showBudgetDetailsDialog` (l.2915-2916) show Approve for `Draft`, `Pending Review`, **`Needs Revalidation`**.
- **Acceptance criteria:**
  - [ ] Clicking "Save & Approve" on a valid new budget ends with status "Budget Approved" in the registry.
  - [ ] Hard-block error from the backend appears as a red SnackBar; the budget stays saved (Pending Review).
  - [ ] A Needs Revalidation budget shows the Approve button in its dialog.
- **Tests to add:** `frontend/test/features/financial_approval/budget_save_and_approve_test.dart` – fake `ImportBudgetsNotifier` records calls; tap the approve button; assert `createImportBudget` then `approveImportBudget(id)` called in order.
- **Out of scope:** permission-based hiding of the button (Q3).

### FE02-T03 Budget form: per-currency freight rate and currency pickers
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** no (`freight_currency`, `freight_cost_egp` already in `ImportBudgetCreate`)
- **Files to change:** `financial_approval_screen.dart`; l10n files.
- **Steps:**
  1. Add state `TextEditingController _bgtFreightRateController` (dispose it).
  2. Add two `SearchableDropdownField<String>` (invoice currency, freight currency) fed by `currenciesProvider` next to the foreign amount fields (both layouts, l.4519-4626 and l.4631-4779). On change: set the currency, set the matching rate controller from `_getExchangeRateForCurrency`, call `_warnFxMissing` when null.
  3. Add a "Freight exchange rate (EGP)" field with `_validateExchangeRate` (only when freight foreign > 0).
  4. Freight EGP = freight foreign × freight rate everywhere (`onChanged` handlers l.4555-4563, l.4679-4689; rate `onChanged` l.4711-4728 must update only the invoice EGP; prefill l.609-618 must not fall back to `effRate`).
  5. When freight currency == invoice currency, prefill the freight rate with the invoice rate (still editable).
- **Acceptance criteria:**
  - [ ] Invoice USD 10,000 @ 50 and freight EUR 1,000 @ 55 → invoice EGP 500,000, freight EGP 55,000.
  - [ ] Freight currency without a registered rate → freight rate empty, red validator, save blocked.
  - [ ] Both currencies can be changed by the user.
- **Tests to add:** `frontend/test/features/financial_approval/budget_form_currency_test.dart` – enter values, assert the two EGP controllers' text.
- **Out of scope:** backend recomputation of EGP values.

### FE02-T04 Budget summary in View must show saved values only
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`.
- **Steps:**
  1. In `_buildConsolidatedBudgetSummary` (l.5635-5667): `if (bgt != null)` use `bgt.invoiceAmountForeign`, `bgt.invoiceAmountEgp`, `bgt.freightCostForeign`, `bgt.freightCostEgp`, `bgt.customsDutiesEgp`, `bgt.clearanceInlandEgp` as-is and `grandTotalEgp = bgt.totalBudgetEgp`; the controller/prefill fallback only when `bgt == null`.
  2. Rename the header of column 2 from `requestedAmountLabel` to an amount label (`l.amountInCurrencyCol`).
- **Acceptance criteria:**
  - [ ] A saved budget with freight 0 shows 0 in its View dialog even while another budget's freight is typed in the form.
  - [ ] Total in the dialog equals the registry card total.
- **Tests to add:** `frontend/test/features/financial_approval/budget_summary_values_test.dart` – type 999 in the freight form field, open the dialog for a model with freight 0, expect "0.00 EGP" for freight.
- **Out of scope:** dialog unification (T09).

### FE02-T05 Clone: edit the server clone, never create a second record
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`.
- **Steps:**
  1. In `_openClonePaymentReviewDialog.onConfirm` (l.1245-1326): remove the inner `try { … } catch (_) {}`; `final cloned = await …clonePaymentRequest(…)`; if non-null call `_loadPaymentRequestForEdit(cloned)` and show `clonePaymentRequestSuccess(cloned.paymentCode)`. Delete the block that copies the source fields into the form (l.1268-1293).
  2. Same for budgets (l.1448-1527): `_loadBudgetForEdit(cloned)`.
  3. Errors go to the existing outer `catch (e)` SnackBar.
  4. Replace `suggestedNewCode: '<code>-CLONE'` (l.1229, l.1428) with `l.autoGeneratedCode`; stop sending English `remarks` literals (send `notes` or omit).
- **Acceptance criteria:**
  - [ ] After clone the form is in edit mode on the new PAY/BGT code; Save updates that record (registry count +1, not +2).
  - [ ] When `/clone` fails, a red SnackBar shows the backend message and the form is unchanged.
- **Tests to add:** `frontend/test/features/financial_approval/clone_flow_test.dart` – fake notifier returns a clone; after confirm assert the edit banner shows the clone code and `createPaymentRequest` is never called on Save.
- **Out of scope:** clone dialog redesign.

### FE02-T06 Payment duplicate guard aligned with backend rule
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** optional (`import_file_id` filter on `GET /payment-requests`, see section 6)
- **Files to change:** `financial_approval_screen.dart`; l10n files.
- **Steps:**
  1. In `_onPayImportFileSelected` (l.284-343) delete the blocking dialog.
  2. Add a getter `_openSameTypeRequest` = first payment with same `importFileId`, `FinancialUi.normalizePaymentType(p.paymentType) == _paymentType`, `isActive`, status in {Draft, Pending Approval, Approved}, id != `_editingPaymentId`.
  3. When not null, render a non-blocking orange banner above the amount row: `l.faOpenPaymentSameType(code)` + a "View" link that opens `_showPaymentDetailsDialog`.
  4. Keep save enabled; backend 409 `FA_PAYMENT_DUPLICATE_TYPE` is displayed by `_showApiError`.
- **Acceptance criteria:**
  - [ ] File with a Paid advance: selecting it and choosing "Against B/L" lets the user save a new request.
  - [ ] File with an open advance and type Advance: banner shown; save → red SnackBar with the backend message.
- **Tests to add:** `frontend/test/features/financial_approval/payment_duplicate_guard_test.dart` – list with a Paid ADVANCE for file 1; select file 1; assert no AlertDialog and the file stays selected.
- **Out of scope:** backend rule changes.

### FE02-T07 Remove client-side prefill fallbacks and PO-allocation clone
- **Severity:** CRITICAL · **Type:** bug · **Depends on:** none · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`; `frontend/lib/features/financial_approval/widgets/supplier_advance_payment_dialog.dart`.
- **Steps:**
  1. `_onPayImportFileSelected` (l.363-395) and `_onBgtImportFileSelected` (l.567-598): use only `prefill.totalInvoiceAmount` / `prefill.invoiceCurrency`. If prefill is null or amount 0: amount empty, currency unchanged-but-empty-rate, no PO/invoice/estimated-cost summation, no `'USD'` default.
  2. Same in `supplier_advance_payment_dialog.dart` l.192-205, l.237-239 (keep `widget.totalAmountForeign` only if its currency is known; otherwise 0).
  3. Delete `_cloneLinkedPoItem` (l.1333-1396) and its two buttons (l.1602-1609, l.4166-4181) and the "Actions" column of the linked PO table.
- **Acceptance criteria:**
  - [ ] Prefill returns 400 `FA_FX_RATE_MISSING`: red SnackBar with backend text, amount and rate empty, save blocked by validators.
  - [ ] No "clone PO allocation" icon remains; advance % chips use the backend total only.
- **Tests to add:** extend `frontend/test/features/financial_approval/financial_approval_provider_test.dart` or new `prefill_no_fallback_test.dart` – prefill throws; linked POs in USD+EUR present; assert amount field is empty.
- **Out of scope:** backend prefill.

### FE02-T08 Payment workflow actions and status-aware row actions
- **Severity:** MAJOR · **Type:** feature · **Depends on:** T10 (labels) recommended · **Backend needed:** no (PUT `status` transitions exist; `approve`, `pay` exist)
- **Files to change:** `financial_approval_screen.dart`; `widgets/financial_ui.dart`; l10n files.
- **Steps:**
  1. Add to `FinancialUi`: `isPaymentLocked(status)` (Approved, Paid) and `paymentNextActions(status)` per `PAYMENT_USER_TRANSITIONS` (Draft→Pending/Rejected, Pending→Draft/Rejected, Approved→Rejected, Rejected→Draft).
  2. In `_showPaymentDetailsDialog` actions (l.2516-2548): add AsyncActionButtons "Submit for approval", "Reject" (asks for a reason in a small dialog, sent as `notes`), "Return to draft" calling `updatePaymentRequest(id, {'status': X, 'version': pay.version, if reason 'notes': …})`.
  3. Approve and Mark-as-Paid: confirmation dialog (code, amount, currency, beneficiary) before the call; Mark-as-Paid requires a non-empty SWIFT ref (validator on the TextField l.2504-2510).
  4. Registry row (l.5293-5310): `onEdit`/`onDelete` = `null` when `isPaymentLocked(p.status)`.
  5. After every action close the dialog and show a green SnackBar.
- **Acceptance criteria:**
  - [ ] Draft request: dialog shows Approve, Submit, Reject; Paid request: no Edit/Delete, no workflow buttons.
  - [ ] Reject asks for a reason; registry shows "Rejected" after refresh.
  - [ ] Approve asks for confirmation first.
- **Tests to add:** `frontend/test/features/financial_approval/payment_status_actions_test.dart` – unit tests for `paymentNextActions`; widget test that a Paid row's edit button is disabled.
- **Out of scope:** permission-based hiding (Q3).

### FE02-T09 One shared budget details dialog (approve, variance log, revisions)
- **Severity:** MAJOR · **Type:** refactor + feature · **Depends on:** T04 · **Backend needed:** no (`GET /import-budgets/{id}`, `/variance-logs`, `/approve` exist)
- **Files to change:** new `frontend/lib/features/financial_approval/widgets/budget_details_dialog.dart`; `financial_approval_screen.dart`; `widgets/saved_budgets_registry_tab.dart`; `providers/financial_approval_provider.dart` (add `getImportBudget(id)`); l10n files.
- **Steps:**
  1. Add `Future<ImportBudgetModel> getImportBudget(int id)` to `ImportBudgetsNotifier` (`GET /financial-approval/import-budgets/{id}`).
  2. Create `showBudgetDetailsDialog(BuildContext, WidgetRef, int budgetId, {VoidCallback? onEdit})`: FutureBuilder on `getImportBudget` + prefill; content = cost table (saved values, T04 rule), approval info (`approvedBy`, `approvedDate`), revision (`revisionNumber`, parent code), variance override reason, variance-log table from `fetchBudgetVarianceLogs` (field, old, new, %, hard block, resolution), share/export buttons.
  3. Actions: Approve (Draft / Pending Review / Needs Revalidation), `RecalculateButton` (when `importFileId != null`), Edit (disabled for Budget Approved / Superseded).
  4. Replace `_showBudgetDetailsDialog` in both files (screen l.2739-2935, registry l.897-1287) and the duplicated WhatsApp/e-mail dialogs with calls to the new widget.
  5. Registry: Edit/Delete disabled for Budget Approved / Superseded.
- **Acceptance criteria:**
  - [ ] View from the registry and from the form show the same dialog with Approve when allowed.
  - [ ] Variance history list visible for budgets that have logs; "No variance" otherwise.
  - [ ] Editing an approved budget is not offered.
- **Tests to add:** `frontend/test/features/financial_approval/budget_details_dialog_test.dart` – fake notifier; status Needs Revalidation → Approve visible; Budget Approved → Edit disabled; logs rendered.
- **Out of scope:** variance threshold settings UI.

### FE02-T10 Status and payment-type labels; payment status filter
- **Severity:** MAJOR · **Type:** ux · **Depends on:** none · **Backend needed:** no
- **Files to change:** `widgets/financial_ui.dart`; `financial_approval_screen.dart`; `screens/swift_reconciliation_screen.dart`; l10n files.
- **Steps:**
  1. `FinancialUi.statusStyle`: explicit cases for Draft, Pending Approval, Approved, Paid, Rejected, Pending Review, Needs Revalidation, Budget Approved, Superseded, Budget Exceeded (new l10n keys where missing); unknown → l10n "Unknown status".
  2. Replace every raw `paymentType` display with `FinancialUi.paymentTypeLabel(l, FinancialUi.normalizePaymentType(x))` (screen l.1234, l.2348, l.5280, l.5457-5472; swift l.1666).
  3. `normalizePaymentType`: return `''` for unknown values; the form validator requires a selection.
  4. Payment registry filter (l.5084-5096): All, Draft, Pending Approval, Approved, Paid, Rejected with status labels; remove "Reconciled".
  5. SWIFT target list: show the localized status chip text instead of `[${p.status}]`.
- **Acceptance criteria:**
  - [ ] In Arabic UI no English status or `ADVANCE_PAYMENT` code is visible in lists or dialogs.
  - [ ] Filter "Rejected" returns rejected requests; "Pending Approval" is available.
- **Tests to add:** `frontend/test/features/financial_approval/financial_ui_labels_test.dart` – every backend status returns a non-raw label in ar and en.
- **Out of scope:** exports (T16).

### FE02-T11 Payments registry: paging, sticky header, dark mode (frontend only)
- **Severity:** MAJOR · **Type:** ux · **Depends on:** none · **Backend needed:** no (Phase A)
- **Files to change:** new `frontend/lib/features/financial_approval/widgets/payment_requests_registry_tab.dart`; `financial_approval_screen.dart`; `providers/financial_approval_provider.dart` (public `refresh()`); l10n files.
- **Steps:**
  1. Move tab 3 (screen l.4972-5591) into `PaymentRequestsRegistryTab` (ConsumerStatefulWidget) with callbacks `onView`, `onEdit`, `onClone`, `onDelete`.
  2. Compute `filtered` once per build; build `Map<String, ImportFileModel> filesByCode` once for name resolution.
  3. Table: header row as a separate widget above an inner vertical `Scrollbar` + `ListView.builder` of rows (fixed column widths shared by header and rows) inside one horizontal `Scrollbar`/`SingleChildScrollView` → header stays visible; rows built lazily.
  4. Client paging: page size 50 (options 25/50/100), `CompactTablePaginationFooter` (`frontend/lib/core/widgets/compact_table_pagination_footer.dart`); reset to page 1 on search/filter change; sort by code / request date / amount EGP / status (tap header).
  5. Dark mode: replace `AppTheme.white`/`AppTheme.charcoal` backgrounds/text (l.5151, 5289, 5358) with `isDark` variants.
  6. Add `Future<void> refresh() => _refresh();` to both notifiers and use it in every refresh button (screen l.3212, 3233, 4817-4829, 5054-5056, 5113-5115).
  7. Fix F02-17: the "Extract & match SWIFT" button goes to index 4.
- **Acceptance criteria:**
  - [ ] With 2,000 fake rows the tab opens smoothly, shows 50 rows, footer "1-50 of 2000", header visible while scrolling.
  - [ ] Search keeps the status filter after Refresh.
  - [ ] Dark mode: rows readable.
- **Tests to add:** `frontend/test/features/financial_approval/payment_registry_paging_test.dart` – provider override with 120 items; expect 50 `DataRow`/row widgets and footer text; go to page 3 → 20 rows.
- **Out of scope:** server paging (T12).

### FE02-T12 Server-side pagination for payment requests and budgets
- **Severity:** MAJOR · **Type:** feature · **Depends on:** T11, T13, backend endpoints (section 6) · **Backend needed:** yes – `GET /financial-approval/payment-requests/paginated` and `GET /financial-approval/import-budgets/paginated`
- **Files to change:** `providers/financial_approval_provider.dart` (new `paginatedPaymentRequestsProvider`, `paginatedImportBudgetsProvider`); `models/financial_approval_model.dart` (`PaginatedResult<T>`); `widgets/payment_requests_registry_tab.dart`; `widgets/saved_budgets_registry_tab.dart`.
- **Steps:**
  1. Copy the pattern of `paginatedImportFilesProvider` (`frontend/lib/features/import_files/providers/import_files_provider.dart:52-129`): state {items,total,page,pageSize,totalPages,isLoading,error}, `fetchPage(page, {search, status, swiftStatus, sortBy, sortDir})`, CancelToken.
  2. Registry tabs read the paginated provider; search debounced 300 ms; filters/sort sent to the server; KPI cards from response `totals`.
  3. "Export Excel" exports **all** rows matching the filter: loop pages with page_size 500 (show progress) then call the existing export.
  4. After mutations, the old list notifiers still invalidate; also call `ref.invalidate(paginated…Provider)`.
- **Acceptance criteria:**
  - [ ] Network shows `page=2&page_size=50` when moving to page 2; search sends `search=`.
  - [ ] Export with 3 pages produces one file with all rows.
- **Tests to add:** `frontend/test/features/financial_approval/paginated_payment_provider_test.dart` – fake Dio adapter returns page payloads; assert query params and state.
- **Out of scope:** SWIFT tab (T14 phase B).

### FE02-T13 Budgets registry: states, filters, compact card
- **Severity:** MAJOR · **Type:** ux · **Depends on:** T10 · **Backend needed:** no
- **Files to change:** `widgets/saved_budgets_registry_tab.dart`; l10n files.
- **Steps:**
  1. Wrap the body in `budgetsState.when(loading: FinancialStateView.loading(), error: FinancialStateView.error(message: l.faLoadFailed(ApiError.message(e)), onAction: refresh), data: …)`.
  2. Filter chips: All, Draft/Pending Review, Needs Revalidation, Budget Approved, and a "Show superseded" toggle (default off). Use exact status equality, not `contains`.
  3. Card footer (l.718-824): keep View, Edit, Print; move WhatsApp, Email, Copy, Excel into an overflow `PopupMenuButton`.
  4. Client paging 20 cards per page with `CompactTablePaginationFooter`; sort by created date desc.
  5. Replace `'IMP-${budget.importFileId}'` (l.431, l.948) with `-`.
- **Acceptance criteria:**
  - [ ] Loading shows a spinner, API error shows message + Retry.
  - [ ] Superseded revisions hidden unless the toggle is on.
- **Tests to add:** `frontend/test/features/financial_approval/budget_registry_states_test.dart` – provider in error → error view visible; loading → spinner.
- **Out of scope:** server paging (T12).

### FE02-T14 SWIFT table: paging, sticky header, status-aware actions
- **Severity:** MAJOR · **Type:** ux/bug · **Depends on:** T10 · **Backend needed:** no (phase A)
- **Files to change:** `screens/swift_reconciliation_screen.dart`; l10n files.
- **Steps:**
  1. Extract the table (l.2660-2800) into a widget with a header outside the vertical scroll, lazy rows, page size 50 + `CompactTablePaginationFooter`.
  2. Row action "Register SWIFT" enabled only for `status == 'Approved'` and empty `swiftReferenceNo`; "Edit" for reconciled rows disabled with tooltip (backend rejects re-reconcile of Paid).
  3. Target-payment dropdown (l.1650-1670): only Approved without SWIFT ref; label uses localized status.
  4. Changing the target (l.1671-1676) must not re-run extraction when a batch exists; call `matchReviewedSwiftBatch(batchId, targetPaymentId)` instead.
- **Acceptance criteria:**
  - [ ] Draft/Paid rows cannot open the register dialog.
  - [ ] Header visible while scrolling 500 rows.
- **Tests to add:** `frontend/test/features/financial_approval/swift_table_actions_test.dart` – Draft row button disabled; Approved row enabled.
- **Out of scope:** batch history list (backend needed, Q6).

### FE02-T15 Remove the client-side SWIFT parser
- **Severity:** MAJOR · **Type:** refactor · **Depends on:** none · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`.
- **Steps:**
  1. Delete `_parseSwiftClientFallback` (l.1889-2092).
  2. `_autoFillFromSwiftText` (l.2094-2132): call `smartExtractSwift`; on exception show `ApiError.message(e)` (red); on `success != true` show `res['error']`; no fallback.
  3. In `_applySwiftParsedData` (l.1749-1887) do not overwrite the currency when the parsed currency is empty; never default to USD.
- **Acceptance criteria:**
  - [ ] Backend 403/500 during "extract" shows the backend message; fields stay as they were.
- **Tests to add:** `frontend/test/features/financial_approval/swift_autofill_error_test.dart` – notifier throws; assert SnackBar text and unchanged amount field.
- **Out of scope:** backend parser accuracy.

### FE02-T16 Exports: names, l10n, Save-As for PDF (still open FE-04 / FE-09)
- **Severity:** MAJOR · **Type:** refactor · **Depends on:** T10 · **Backend needed:** no
- **Files to change:** `services/financial_export_service.dart`; l10n files; (call sites only pass `context`).
- **Steps:**
  1. Add `static String _fileName(String stage, String? importFileCode, String ext)` → `'$stage - ${importFileCode ?? 'All'}.$ext'` (sanitize `/\:*?"<>|`).
  2. Use it for every CSV (l.546, 842, 886, 935, 1177) – stage names from l10n (e.g. "Import Budget Approval", "Payment Request").
  3. PDFs (l.462, 802, 1545): build bytes with `pdf.save()` and call `FileSaveHelper.exportAndSaveFile(...)`; keep a separate "Print" button using `Printing.layoutPdf`.
  4. Replace the 122 Arabic-literal lines with `AppLocalizations` lookups (pass `AppLocalizations l` into each builder); payment type via `FinancialUi.paymentTypeLabel`.
  5. Rename buttons "Download Excel" → "Export CSV" in l10n (or generate real xlsx – Q7).
- **Acceptance criteria:**
  - [ ] Exporting budget BGT-2026-001 for file IMP-2026-010 proposes "Import Budget Approval - IMP-2026-010.csv" in a Save-As dialog.
  - [ ] English UI exports contain no Arabic labels.
- **Tests to add:** extend `frontend/test/features/financial_approval/financial_export_rate_test.dart` with `_fileName` cases and an English-locale label test.
- **Out of scope:** SWIFT slip layout.

### FE02-T17 Form hygiene (dates, resets, validators, currency fallback)
- **Severity:** MINOR · **Type:** ux · **Depends on:** none · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`; l10n files.
- **Steps:**
  1. Currency dropdown (l.1656-1678): no hard-coded list; when the provider has an error show an error item + retry.
  2. Date pickers (l.1709-1747): `lastDate: DateTime.now().add(const Duration(days: 3650))`; display with the app date formatter.
  3. `_resetPaymentForm()` / `_resetBudgetForm()` clearing every controller and state; use in both Cancel-edit buttons and Reset (l.3317-3330, 4209-4223, 4834-4850).
  4. Budget numeric validators `>= 0` (parseable); decide "Import File *" per Q5.
  5. Advance % label currency = `_payPrefillData!.invoiceCurrency` (l.3695-3700).
  6. `initialImportFileId` (l.242-245): only run the selection for the tab in `initialIndex`.
- **Acceptance criteria:**
  - [ ] Reset leaves an empty budget form.
  - [ ] Negative customs value shows a red validator message.
- **Tests to add:** `frontend/test/features/financial_approval/budget_form_reset_test.dart`.
- **Out of scope:** layout changes.

### FE02-T18 Small cleanups (DB ids, stored UI text, dead code, header)
- **Severity:** MINOR · **Type:** refactor · **Depends on:** T09 (uses variance logs) · **Backend needed:** no
- **Files to change:** `financial_approval_screen.dart`; `providers/financial_approval_provider.dart`; `models/financial_approval_model.dart`; l10n files.
- **Steps:**
  1. Replace `'IMP-${p.importFileId}'` (l.5258-5261) with `-` when `importFileCode` is null.
  2. Remove unused `restorePaymentRequest`, `restoreImportBudget`, `syncBudgetWithUpstream`, `overrideBudgetVariance` from the provider **or** wire restore into a "Show deleted" toggle (Q8); keep `fetchBudgetVarianceLogs` (used by T09).
  3. `BudgetSyncResultModel`: parse `message_code` and `message_params`.
  4. Tab titles via l10n; `stageCode` → `'PHASE-2: STEP_04'` (confirm label) ; add `const BackToDashboardButton()` as last header action.
  5. Remove the unused `isAr` locals (l.496, l.5120 if unused).
- **Acceptance criteria:**
  - [ ] `flutter analyze lib/features/financial_approval` has no new warnings; no DB id visible in any list.
- **Tests to add:** extend `frontend/test/features/financial_approval/financial_approval_model_test.dart` for `message_code` parsing.
- **Out of scope:** splitting the 6,466-line screen beyond T09/T11 extractions.

---

## 6. Backend dependencies (short)

1. **Paginated lists** (T12): `GET /financial-approval/payment-requests/paginated` and `GET /financial-approval/import-budgets/paginated` with `page`, `page_size`,
   `sort_by`, `sort_dir`, `search` (code, title, supplier, import_file_code, swift_reference_no), `status` / `budget_status`, `swift_status` (PENDING/MATCHED/DEFICIT/SURPLUS),
   `import_file_id`, `date_from`/`date_to`; response `{items, total, page, page_size, total_pages, totals: {count_by_status, sum_requested_egp}}` (mirror `PaginatedImportFilesResponse`).
2. `import_file_id` query param on `GET /financial-approval/payment-requests` (repository already supports it, `repository.py:142`; router `:217-229` does not expose it) – used by T06 banner.
3. SWIFT batch history: `GET /financial-approval/swift/review-batches` (paged) – for a read-only batch list (backlog).
4. Payment approver audit (`approved_by`, `approved_at` on `payment_request_sessions`) – deferred D1 in the previous plan; the payment View cannot show who approved until then.

## 7. Open questions for the CTO

- **Q1:** One file can have several payment requests (advance + against B/L + final)? *Default:* yes, one **open** request per payment type (backend rule); T06 follows it.
- **Q2:** SWIFT reconcile with missing reference/amount in the extracted text: block and require manual entry? *Default:* block (T01).
- **Q3:** Hide Approve / Pay / Reject buttons for users without `financial_approval.approve`? The app has no current-user permission helper in Flutter today. *Default:* show and let backend 403 explain; add hiding later.
- **Q4:** Default page size for financial registries: 50? *Default:* 50 (options 25/50/100).
- **Q5:** Is the import file mandatory for payment requests and budgets? Labels say `*` but "Not linked" is accepted. *Default:* mandatory for budgets, optional for payments.
- **Q6:** Do you want a SWIFT batch history screen (needs backend list endpoint)? *Default:* backlog.
- **Q7:** "Excel" exports are CSV today. Real `.xlsx` or rename to CSV? *Default:* rename to CSV (T16).
- **Q8:** Restore of soft-deleted payment requests / budgets from the UI ("Show deleted" toggle)? *Default:* not now; remove the dead provider methods.
