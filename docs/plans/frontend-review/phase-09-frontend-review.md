# Phase 09 Financial settlement: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited).
Scope: BP-036/037 (CLO-01 invoices aggregation and confirm), BP-038 (allocation), BP-039 (CLO-02 actual landed cost,
approve, comparison), PL-08 estimated simulation dialog, Odoo journal export, settlement registry, shared recalculate button.

Where the screens live (`frontend/lib/features/home/home_screen.dart:146,179`, `core/providers/navigation_provider.dart:61,82`):

| Screen | Entry | File |
|---|---|---|
| Landed-cost settlement hub (registry + header CLO-01 / CLO-02 buttons) | sidebar index 29 | `features/financial_settlement/screens/financial_settlement_screen.dart` |
| Landed cost comparison (estimated vs actual) | sidebar index 50 = hub tab 1 (embedded) | `features/financial_settlement/screens/landed_cost_comparison_screen.dart` |
| CLO-01 final invoices dialog | hub header button + card button | `features/financial_settlement/widgets/final_settlement_invoices_dialog.dart` |
| CLO-02 actual landed cost dialog | hub header button + card button | `features/financial_settlement/widgets/actual_landed_cost_dialog.dart` |
| PL-08 estimated simulation dialog | only from Import File details (`import_files/widgets/import_file_details_dialog.dart:599`) | `features/financial_settlement/widgets/estimated_landed_cost_dialog.dart` |
| Odoo journal dialog | card "View" (eye) + "Odoo" button | `features/financial_settlement/screens/odoo_journal_entry_dialog.dart` |
| Recalculate (shared) | card | `core/widgets/recalculate_button.dart` + `features/recalculation/**` |

Coverage depth:

| file | lines | depth |
|---|---|---|
| `financial_settlement/screens/financial_settlement_screen.dart` | 679 | Full |
| `financial_settlement/widgets/settlement_registry_card.dart` | 429 | Full |
| `financial_settlement/widgets/settlement_form_dialog.dart` | 424 | Full |
| `financial_settlement/providers/financial_settlement_provider.dart` | 250 | Full |
| `financial_settlement/widgets/final_settlement_invoices_dialog.dart` | 596 | Full |
| `financial_settlement/widgets/actual_landed_cost_dialog.dart` | 675 | Full |
| `financial_settlement/screens/landed_cost_comparison_screen.dart` | 847 | 1-330 full, 330-847 grep (keys, variance, export, tables) |
| `financial_settlement/widgets/estimated_landed_cost_dialog.dart` | 725 | 1-262 full, 360-400 full, rest grep |
| `financial_settlement/screens/odoo_journal_entry_dialog.dart` | 534 | 1-200 full, rest grep |
| `financial_settlement/models/actual_landed_cost_model.dart` | 437 | 1-80, 180-345, 380-437 |
| `financial_settlement/models/invoices_aggregation_model.dart` | 309 | JSON keys (grep) |
| `financial_settlement/models/financial_settlement_model.dart` | 333 | JSON keys (grep) |
| `financial_settlement/services/landed_cost_comparison_export_service.dart` | 557 | grep (keys, save calls) |
| `financial_settlement/widgets/search_and_clone_financial_settlement_dialog.dart` | 274 | grep |
| `financial_settlement/widgets/settlement_ui.dart` | 522 | grep (`settlementWarningLines`) |
| `core/widgets/recalculate_button.dart` | 607 | 180-240 + grep |
| `recalculation/models/recalculation_model.dart` | 212 | grep |
| Backend contract | - | `modules/financial_settlement/{router.py full, schemas.py full, repository.py:48-78, validators.py:43-122, service.py:701-726, 1886-1960, 2464-2515}` |
| Docs | - | `docs/phase_09_financial_settlement.md`, `docs/phase_09/README.md`, `docs/phase_09/tasks/BP-038, BP-039` (generic templates), `docs/plans/phase-09-quality-plan.md`, `docs/plans/review-coverage.md` |

Previous wave check (`phase-09-quality-plan.md` §1c): FE-01 (client money math, fabricated weight/CBM/rate), FE-02 (clone to
same file, client code), FE-03 (Odoo + comparison saves now use `FileSaveHelper.exportAndSaveFile`), FE-04 (searchable rule
dropdown), FE-06 (colors/buttons, one `Colors.transparent` left), FE-08 (`ApiErrorText`), FE-09 (no 48.5 / 50.0 defaults),
FE-10 (lifecycle + smart tasks invalidated), FE-11 (form extracted) are **verified fixed**. **FE-07 is still open** (see F09-12).
FE-05 is mostly fixed (a few English literals remain, F09-21).

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 1 |
| CRITICAL | 3 |
| MAJOR | 15 |
| MINOR | 6 |

Most important points:

1. **The header CLO-01 / CLO-02 buttons open the first file in the list, not a file the user picks** (F09-01). A user can
   confirm invoices or approve the actual landed cost of the wrong shipment. Both actions cannot be undone (409 on repeat).
2. **"Edit" on a settlement card runs a recalculate, does not await it, and always shows "recalculated successfully"**, even
   when the backend refuses it with 409 for an Approved settlement (F09-02). Delete has the same no-await / no-error pattern (F09-05).
3. **Wrong money on screen**: the comparison tab treats `import_files.estimated_cost` (stored in `estimated_cost_currency`,
   default USD) as EGP and computes the variance in the client (F09-03). The CLO-02 items tab prints the EGP FOB unit price with a
   "USD" suffix (F09-04).
4. **Large tables**: the registry loads every settlement with all its invoice and item JSON (no pagination on the API), then
   draws one tall card per settlement with two full `DataTable`s inside. Search hits only `settlement_code` / `accountant_name`
   server-side, with no debounce and no status filter (F09-09, F09-10). Recommendation in §3.
5. **No real "View"**: the eye icon opens the Odoo journal dialog, not the settlement. There is no details dialog, no
   `GET /financial-settlement/{id}` call in the provider, and no restore or show-inactive option (F09-07, F09-08). Section §4.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F09-01 | BLOCKER | `screens/financial_settlement_screen.dart:376-401`, `:449-465` | `_openGlobalDialog` opens CLO-01 / CLO-02 for `files.first` (the first loaded import file), not one the user picked. Confirm (CLO-01) and approve (CLO-02) are irreversible: the second call returns 409. | Header buttons open a small picker dialog (`SearchableDropdownField<int>` of import files) and then open the dialog for the chosen file. If nothing is chosen, do nothing. |
| F09-02 | CRITICAL | `widgets/settlement_registry_card.dart:331-339` | `onEdit` calls `notifier.recalculateSettlement(...)` without `await` or `try/catch`, and immediately shows a cobalt "recalculated" SnackBar. On an Approved settlement the backend returns 409 `SETTLEMENT_NOT_EDITABLE` (`validators.py:43-54`). The user sees success and an unhandled exception is thrown. The "Edit" pencil icon does not edit anything. | Remove `onEdit` from the pill (there is no edit form). Add a "Recalculate" action that awaits, shows a crimson `ApiErrorText` SnackBar on failure and a success SnackBar only after the response. Hide it when `status == 'Approved'`. |
| F09-03 | CRITICAL | `screens/landed_cost_comparison_screen.dart:86-89`, `:324-325`, `:371`, `:580` | The "estimated" value is `import_files.estimated_cost`, whose currency is `estimated_cost_currency` (default USD, `modules/import_files/model.py:156-157`), but it is shown as EGP and compared with EGP actuals. The FOB variance compares actual **FOB** with the estimated **total** cost. Variance math runs in the client. | Take the estimate from the backend: `POST /financial-settlement/calculate-actual-landed-cost/{id}` already returns `estimated_total_fob_egp`, `estimated_total_landed_cost_egp`, `landed_variance_pct`, `variance_status`. Show those values and remove the client formulas. |
| F09-04 | CRITICAL | `widgets/actual_landed_cost_dialog.dart:564-565`; `models/actual_landed_cost_model.dart:192-197` | The CLO-02 item line has no `currency`, `fob_unit_price_fc` or `unit_of_measure` (`schemas.py` `ActualLandedCostItemLine`). The model falls back to `fob_unit_egp` and `currency ?? 'USD'`, so the "FOB price" column shows an EGP amount labelled USD. Qty uses `toStringAsFixed(0)` (2.5 shows as "3") and the unit is always "PCS". | Read `fob_unit_egp` into a field named `fobUnitEgp` and label it EGP. Drop the `currency` / `unitOfMeasure` fallbacks (show the unit only when the backend sends it). Show qty with `formatSettlementMoney` or the `qtyLabel` rule. |
| F09-05 | MAJOR | `widgets/settlement_registry_card.dart:341-365` | Delete: `notifier.softDeleteSettlement` is not awaited, there is no `try/catch`, and there is no success or error SnackBar. The backend refuses deletes on Approved settlements (`service.py:710-715`) and the user gets no message. | Await the call. Show a success SnackBar, or a crimson `ApiErrorText` SnackBar on error. Hide delete for Approved. |
| F09-06 | MAJOR | `widgets/settlement_registry_card.dart:320-427` | The card actions do not depend on status. An Approved settlement still shows edit/recalculate, delete, CLO-01 confirm and CLO-02 approve, and each one ends in 409. There are 9 buttons in the row, and three of them do the same thing (copy row, copy breakdown, print = copy breakdown). | Status-aware action set: Draft/Calculated show View, Recalculate, CLO-01, CLO-02, Clone, Delete. Approved shows View, Odoo journal, Clone, Copy. Put the copy actions in an overflow menu. |
| F09-07 | MAJOR | `widgets/settlement_registry_card.dart:330`; `providers/financial_settlement_provider.dart` (no get-by-id) | "View" (eye, tooltip `financialSettlementViewTooltip`) opens the Odoo journal dialog. There is no read-only settlement details view. The backend has `GET /financial-settlement/{id}` (`router.py:73-79`), but the provider never calls it. | Add `fetchSettlement(id)` to the provider and a `SettlementDetailsDialog` (header, status, audit, expenses table, items table, notes). Point `onView` to it and keep the Odoo journal as its own button. See §4. |
| F09-08 | MAJOR | `providers/financial_settlement_provider.dart:107-114`; `screens/financial_settlement_screen.dart:493-584` | `restoreSettlement` and `includeInactive` exist but no UI uses them. A soft-deleted settlement cannot be seen or restored. | Add a "Show deleted" toggle to the toolbar (passes `includeInactive`). Deleted rows are greyed and show only a "Restore" action (await + SnackBar; a 409 `SETTLEMENT_DUPLICATE_ACTIVE` goes through `ApiErrorText`). |
| F09-09 | MAJOR | `providers/financial_settlement_provider.dart:54-61`; `screens/financial_settlement_screen.dart:644-670`; `widgets/settlement_registry_card.dart:182-302`; backend `repository.py:68` | The registry loads every settlement with full `expense_invoices` and `item_landed_costs` JSON (`.all()`, no limit). Each row is a ~600-px card with 4 KPI tiles and two non-virtualised `DataTable`s. With 1,000+ files the screen is slow, cannot be scanned, and has no sort, row count or column control. | Replace the cards with a summary table (`EnterpriseDataTable`, `core/widgets/enterprise_data_table/`): code, file code, company, status, FOB, expenses, landed, markup, updated_at, actions. Details move to F09-07. Later, add server pagination (§6). |
| F09-10 | MAJOR | `screens/financial_settlement_screen.dart:539-541`; backend `repository.py:62-67` | Search calls the API on every keystroke (no debounce; the cancel token only hides the race). Server search only matches `settlement_code` / `accountant_name`, so typing a file code or company name finds nothing. The search-and-clone dialog, by contrast, searches file code and company on the client. There is no status filter, although the provider supports `status`. | 350 ms debounce. Status filter chips (All / Draft / Calculated / Approved) wired to `fetchSettlements(status:)`. Keep filters on refresh. Backend: extend search to the import file code (§6). |
| F09-11 | MAJOR | `screens/financial_settlement_screen.dart:140`, `:649`; `screens/landed_cost_comparison_screen.dart:165`, `:401` | When the file is not in `importFilesProvider`, the UI shows `IMP-<db id>` / `IMP-#<id>`, which is a database ID shown to the user (CORE_RULES §6). The response has no `import_file_code`, so the screen depends on loading **all** import files to label rows. | Backend adds `import_file_code` + `company_name` to `FinancialSettlementResponse` (§6). FE reads them and shows "-" when they are missing. Never build `IMP-<id>`. |
| F09-12 | MAJOR | `widgets/final_settlement_invoices_dialog.dart:119`, `:457`, `:463`; `widgets/actual_landed_cost_dialog.dart:137`, `:287`, `:478`; `widgets/estimated_landed_cost_dialog.dart:383`; `core/widgets/recalculate_button.dart:191`, `:236`, `:327`; `models/invoices_aggregation_model.dart:56-59` | **Still open from FE-07.** The UI renders backend Arabic text (`party_type_ar`, `category_ar`, `variance_status_ar`, `executive_summary_ar`, the response `message`, `message_ar`), so the English UI shows Arabic. The model does not parse `category_code` (it exists in `AggregatedInvoiceItemSchema`). | Party label comes from `party_type` via the existing `settlementClo01Party*` keys. Category comes from `category_code` via `DomainEnums.labelIfKnown(..., clearanceExpenseCategory, ...)`, falling back to `category`. Variance comes from `variance_status` via l10n. Success SnackBars use l10n text plus `import_file_code`. Recalc uses `messageCode` when present. |
| F09-13 | MAJOR | `widgets/final_settlement_invoices_dialog.dart:97-140`, `:53`, `:60`, `:537-548`, `:583-592` | CLO-01 confirm has no confirmation step, even when `total_remaining_egp > 0` (unpaid invoices). The button stays enabled after `financial_settlement_status == 'INVOICES_SETTLED'` (the backend returns 409). The "Settled by" field is editable but never sent (the server records the user), so it is a dead input. | A confirm dialog shows the count, total and remaining, plus an extra warning when remaining > 0. Disable the button and show the status chip when the invoices are already settled. Show "Settled by" as read-only text (the current user). |
| F09-14 | MAJOR | `widgets/actual_landed_cost_dialog.dart:107-116`, `:579-593` | Approve requires a non-empty "Approved by" that is never sent (`provider.dart:224-238`), so a user without `fullName` cannot approve. There is no confirmation before a freezing approval, and approve stays enabled when `itemsBreakdown` is empty or when `messages` contains an error severity (for example a missing FX rate). | "Approved by" becomes read-only. Add a confirm dialog with the landed total, variance and allocation rule. Disable approve when there are no items or a message has `severity == 'error'`. |
| F09-15 | MAJOR | `screens/landed_cost_comparison_screen.dart:67-136` | The screen calls `dio` directly (no provider), contrary to CORE_RULES §3. All errors are swallowed: `_error` is never set, so a 403 or a network error shows "no landed cost data registered". | Move the fetches into a `FutureProvider.family<…, int>` in `financial_settlement_provider.dart`. Use `.when(error:)` with `ApiErrorText` and a retry. |
| F09-16 | MAJOR | `widgets/settlement_registry_card.dart:253-264`; `screens/financial_settlement_screen.dart:341-366` | The items table and the breakdown TSV skip `allocated_other_egp` (insurance, bank, VAT go there), so freight + customs + clearance + transport ≠ unit landed cost. | Add an "Other allocated" column (key already parsed: `allocatedOtherEgp`). |
| F09-17 | MAJOR | `widgets/settlement_form_dialog.dart:85`, `:94`, `:203-222`; `screens/financial_settlement_screen.dart:100-134` | The form edits **one** invoice and **one** item. A clone builds every line (`screen:103-123`), but the form keeps only `.first`, so cloning a 20-line settlement silently saves 1 line. There is no edit (PUT) UI for Draft/Calculated. | Short term: when the source has more than one line, the clone dialog lists every line read-only and sends them all. Medium term: Q1 (keep the manual form at all?). |
| F09-18 | MAJOR | `widgets/estimated_landed_cost_dialog.dart:165-178`, `:553` | Override inputs are plain `TextField`s parsed with `double.tryParse`. Invalid text (e.g. "1,500") is dropped without a message and the simulation runs on defaults, so the user thinks the override applied. Negative values are accepted. | Wrap the inputs in a `Form` with `parseSettlementNumber` plus a ">= 0" validator. Block "Recalculate" while the form is invalid. |
| F09-19 | MAJOR | `widgets/actual_landed_cost_dialog.dart:415-432`, `:522-610`; `widgets/estimated_landed_cost_dialog.dart:597`, `:668` | Item tables are `DataTable`s inside nested `SingleChildScrollView`s: every row is built, there is no sticky header and no row count. CLO-02 has **no export** of the itemized landed-cost sheet that BP-039 asks for (only the estimated dialog has CSV/TSV). | Item tables use a lazy, sticky-header table (`EnterpriseDataTable` or `TableView`-style `ListView.builder` + pinned header). Add Excel + PDF export of the CLO-02 items through `FileSaveHelper.exportAndSaveFile` (stage "Actual Landed Cost - <file code>"). |
| F09-20 | MINOR | `screens/odoo_journal_entry_dialog.dart:269-276`, `:336` | The CSV/Excel buttons stay enabled when `isBalanced == false` (the backend answers 409 `JOURNAL_UNBALANCED`). `Colors.transparent` is used. | Disable the buttons when the journal is unbalanced and show the difference. Use `AppTheme`/`null` instead. |
| F09-21 | MINOR | `widgets/estimated_landed_cost_dialog.dart:179-180`, `:207`, `:214`; `screens/financial_settlement_screen.dart:216`, `:245` | Hard-coded English TSV header and `stageName` literals ('Landed Cost Simulation', 'Financial Settlement'). CSV fields are not escaped (a `"` or a newline in an item name breaks the file). | Use l10n stage names and headers. Escape CSV fields (double the quotes, quote every text field). |
| F09-22 | MINOR | `screens/financial_settlement_screen.dart:431` | `stageCode: 'PHASE-6: STEP_20'` on a Phase 9 screen. | `'PHASE-9: STEP_20'` (or the value the stage map uses). |
| F09-23 | MINOR | `widgets/settlement_form_dialog.dart:238-240`, `:392-406` | The import-file dropdown lists files that already have an active settlement, so save returns 409. "Reset" clears only the invoice fields. | Exclude the file ids that appear in `financialSettlementProvider`. Reset clears every field. |
| F09-24 | MINOR | `models/invoices_aggregation_model.dart:56`, `:66`; `widgets/actual_landed_cost_dialog.dart:503` | Defaults invent data: `payment_status ?? 'PAID'`, `party_type_ar ?? 'أخرى'`. The CLO-02 "Source" column reads `source_note`, which the backend schema does not have, so it is always empty. The invoice date, per-row WHT and net payable are parsed but not shown. | Default to `'UNKNOWN'` / ''. Remove the Source column (or have the backend add it). Add Date and WHT columns. |
| F09-25 | MINOR | `screens/financial_settlement_screen.dart:50-52`; `widgets/settlement_form_dialog.dart:106`; `screens/landed_cost_comparison_screen.dart:51-53` | They call `importFilesProvider.notifier.fetchImportFiles()` with no filters on the **shared** provider. This resets the list (and filters) the Import Files screen uses, and loads every file only to resolve labels. | After F09-11, drop the label dependency. Pickers use a dedicated lookup provider (`importFileLookupProvider`, active only) instead of the shared list provider. |

## 3. Large tables

| List / table | Current behaviour (evidence) | Recommended solution |
|---|---|---|
| Settlement registry (hub tab 0) | `GET /financial-settlement` returns **all** rows with full invoice and item JSON (`repository.py:68` `.all()`; `provider.dart:54-61`). `SliverList` builds cards lazily (`screen:644-670`), but each card is ~600 px with 2 eager `DataTable`s (`card:182-302`). No sort, no row count, no column picker, no sticky header. Search is server-side on code/accountant only, with no debounce (`screen:539`). Excel/PDF/TSV export only the loaded list (`screen:196-260`), which today is everything. | Phase A (FE only, FE09-T06): `EnterpriseDataTable<LandedCostSettlementModel>` with summary columns, sort, client paging (25/50/100), sticky header, row count, column picker, status chips, show-deleted toggle, 350 ms debounce. Row tap or View opens `SettlementDetailsDialog` (FE09-T05). Phase B (backend dep): `GET /financial-settlement?page=&page_size=&sort=&search=` returning `{items, total}` with summary fields only (no JSON blobs), search on file code + company, and a server export endpoint for "export all". |
| CLO-01 invoices (per file) | `DataTable` in a horizontal `SingleChildScrollView` inside a vertical one (`invoices_dialog:386-519`). All rows built. Party filter is client-side. Volume is one file (normally < 100 rows), so this is acceptable. No export. | Keep `DataTable`, add a sticky header and a row count. Add an Excel export of the filtered rows (FE09-T14, optional). |
| CLO-02 categories (per file) | Few rows (8 buckets), `DataTable` (`actual:440-517`). | No change. |
| CLO-02 items (per file) | Eager `DataTable`, nested scroll, 12 columns, no sticky header (`actual:522-610`). A PO with 500-2,000 lines builds every row at once and freezes the dialog. | Lazy table with a pinned header (FE09-T14). Show "N items" (already in the tab label). Add an Excel/PDF export of the full sheet. |
| PL-08 estimated items / expenses | Eager `DataTable`s (`estimated:597`, `:668`). CSV/TSV export exists. | Same lazy table as CLO-02 (shared widget). |
| Odoo journal lines | Eager `DataTable` (`odoo:311`). Lines = categories plus suppliers (tens). | No change. |
| Comparison expenses / items | Eager `DataTable`s over the raw map (`comparison:676`, `:744`). Same item-count risk as CLO-02. | Reuse the item table from FE09-T14 after FE09-T04. |
| Search-and-clone list | Client-side filter over the loaded registry, `ListView.separated` (`search_and_clone…:50-63`, `:133`). Lazy, fine. | Once Phase B pagination lands, call the server search instead. |
| Import-file pickers (form, comparison, header picker) | `SearchableDropdownField` over the full `importFilesProvider` list. | Lookup provider with server search (FE09-T15). |

## 4. View/Show action

| Entity | View exists? | Why not (code reason) | What to add |
|---|---|---|---|
| Landed-cost settlement (registry) | **No real one.** The eye icon (`card:330`, `onView: onOpenJournal`) opens the Odoo journal. The card shows the data inline because there is no detail screen. | No `SettlementDetailsDialog`, no `fetchSettlement(id)` in the provider (`GET /financial-settlement/{id}` exists at `router.py:73`, unused). The "list" is the detail view, which is why it cannot scale (F09-09). | `SettlementDetailsDialog` (read-only): header (code, file code, company, status chip, incoterm, accountant, created/updated by/at), 4 KPIs, expenses table, items table (with "other"), notes, plus footer actions Odoo journal / Copy / Export. It loads via `fetchSettlement(id)` on open (live load). FE09-T05. |
| CLO-01 aggregated invoice row | No | Rows come from several modules (`source_module`), and there is no per-row action or route to the source record. | Out of scope this wave. Show `invoice_date`, WHT and net in the row (F09-24). Q4: should a row deep-link to its source screen? |
| CLO-02 item line | No (the table is the view) | Read-only calculation result, so a separate view is not needed. | Optional row tap that opens a breakdown popover (every allocated bucket for that line). Not planned. |
| Odoo journal | Yes (it is a view dialog) | - | Keep it, behind its own button, not the eye icon. |
| Recalculation logs | No UI | `recalculation/router.py` `/logs` has no frontend consumer. | Q5 (backlog). |

## 5. Tasks

### FE09-T01 - Header CLO-01 / CLO-02 must ask which file
- **Severity:** BLOCKER. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, `frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`.
- **Steps:**
  1. In `_openGlobalDialog` (`financial_settlement_screen.dart:376-401`) remove every use of `files.first`.
  2. Show an `AlertDialog` titled `settlementPickFileTitle` that contains one `SearchableDropdownField<int>` (key `settlementPickFileField`) over `importFilesProvider` items (`primaryNameWithCode - companyName`), a validator `financialSettlementImportFileValidator`, and buttons Cancel / Continue (`AppButton`).
  3. On Continue, close the picker and open `FinalSettlementInvoicesDialog.show` or `ActualLandedCostDialog.show` with the chosen `importFileId` and its `importFileCode`.
  4. Add the l10n keys `settlementPickFileTitle`, `settlementPickFileContinue` (ar + en).
- **Acceptance criteria:**
  - [ ] Clicking the header "CLO-01" opens a file picker. No invoices dialog opens until a file is chosen.
  - [ ] The CLO-01 / CLO-02 dialog subtitle shows the chosen file code.
  - [ ] Cancel closes the picker with no other dialog.
- **Tests to add:** `frontend/test/features/financial_settlement/global_clo_buttons_test.dart`: pump the screen with 2 stubbed import files, tap `globalFinalSettlementInvoicesBtn`, and assert that `settlementPickFileField` is shown and `FinalSettlementInvoicesDialog` is not. Select the second file, tap Continue, and assert the dialog subtitle contains the second file code.
- **Out of scope:** card-level CLO buttons (already pass the row file).

### FE09-T02 - Card actions: real recalculate, safe delete, status-aware buttons
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/settlement_registry_card.dart`, the 3 `app_localizations*.dart` files.
- **Steps:**
  1. In `_buildActions` (`settlement_registry_card.dart:320-427`) remove `onEdit` from `RowActionsPill`.
  2. Add an async `_recalculate(context, ref)`: `try { await notifier.recalculateSettlement(id); success SnackBar (AppTheme.emerald) } catch (e) { SnackBar(ApiErrorText.of(l10n, e), AppTheme.crimson) }`, guard with `context.mounted`. Wire it to a "Recalculate" `IconActionButton` (icon `Icons.calculate`).
  3. In `onDelete`, after confirm: `try { await notifier.softDeleteSettlement(id); success SnackBar } catch (e) { crimson ApiErrorText SnackBar }`.
  4. `final locked = record.status == 'Approved';`. When locked, hide Recalculate, Delete, `RecalculateButton`, CLO-01 and CLO-02, and keep Odoo journal, Clone and Copy.
  5. Move "Copy row", "Copy breakdown TSV" and "print" (all copy actions) into one `PopupMenuButton` (`Icons.more_vert`) with l10n labels.
- **Acceptance criteria:**
  - [ ] An Approved settlement card shows no recalculate / delete / CLO-01 / CLO-02 actions.
  - [ ] When the backend rejects a recalculation, the user sees a red SnackBar with the reason and no success message.
  - [ ] A delete failure shows a red SnackBar, and a delete success shows a confirmation and the row disappears.
- **Tests to add:** `frontend/test/features/financial_settlement/settlement_registry_card_test.dart`: (a) an Approved record pumps with no `Icons.delete_outline` / recalc key; (b) a Calculated record with a stub adapter returning 409 on `/recalculate` shows the `ApiErrorText` text and not `financialSettlementRecalculateSuccessSnack`.
- **Out of scope:** an edit form (FE09-T12 / Q1).

### FE09-T03 - CLO-02 items: correct FOB currency and quantity
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/models/actual_landed_cost_model.dart`, `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `frontend/test/features/financial_settlement/actual_cost_contract_test.dart`.
- **Steps:**
  1. In `ActualLandedCostItemLineModel.fromJson` (`actual_landed_cost_model.dart:192-197`), add `fobUnitEgp: _numOf(json, ['fob_unit_egp'], 0.0)`. Change `currency` to `json['currency']?.toString() ?? ''` and `unitOfMeasure` to `json['unit_of_measure']?.toString() ?? ''`.
  2. In `actual_landed_cost_dialog.dart:564-565`, render the FOB column as `'${formatSettlementMoney(item.fobUnitEgp)} $egp'`, and quantity as the `qtyLabel` rule (no `toStringAsFixed(0)`). Append the unit only when it is not empty.
  3. Rename the column header key if it says "FC" (`settlementClo02ColFobPrice` text becomes "FOB unit (EGP)").
- **Acceptance criteria:**
  - [ ] The CLO-02 items tab shows the FOB unit price with "EGP", not "USD".
  - [ ] A quantity of 2.5 shows as 2.5.
- **Tests to add:** in `actual_cost_contract_test.dart`, parse a line `{fob_unit_egp: 485.0, qty: 2.5}` and assert `fobUnitEgp == 485.0`, `currency == ''`, `unitOfMeasure == ''`.
- **Out of scope:** the backend adding an FC price per line.

### FE09-T04 - Comparison tab: provider, backend estimate, error state
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no (uses the existing `POST /financial-settlement/calculate-actual-landed-cost/{id}` and `GET /financial-settlement?import_file_id=`).
- **Files to change:** `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`, `frontend/lib/features/financial_settlement/screens/landed_cost_comparison_screen.dart`, `frontend/lib/features/financial_settlement/services/landed_cost_comparison_export_service.dart`, l10n files.
- **Steps:**
  1. Add `landedCostComparisonProvider = FutureProvider.autoDispose.family<LandedCostComparisonData, int>` that calls `calculateActualLandedCost(fileId)` and `GET /financial-settlement?import_file_id=fileId`, and returns `{calc, settlement?}`.
  2. In the screen, delete `_fetchData`, `_estimatedCost`, `CancelToken` and the direct `dio` use (`:67-136`). Use `ref.watch(landedCostComparisonProvider(fileId)).when(...)`, with `error:` showing `SettlementStateView.error(ApiErrorText.of(...), retry: ref.invalidate(...))`.
  3. Estimated values come from `calc.estimatedTotalLandedCostEgp` (add the parse of `estimated_total_fob_egp`, `estimated_total_expenses_egp` to the model if missing). Variance comes from `calc.landedVariancePct` and status from `calc.varianceStatus`. Remove the client formulas at `:324-325`.
  4. Incoterm comes from `calc.incoterm`. Do not call `/import-files/{id}` any more.
  5. Pass the same values to `LandedCostComparisonExportService` (replace `estimatedCost`).
- **Acceptance criteria:**
  - [ ] For a file whose `estimated_cost` is 24,500 USD, the "estimated" card shows the backend EGP estimate, not 24,500 EGP.
  - [ ] When the API returns 403 or 500, the tab shows an error with Retry, not "no data registered".
  - [ ] The FOB card compares estimated FOB with actual FOB.
- **Tests to add:** `frontend/test/features/financial_settlement/landed_cost_comparison_test.dart`: with a stub adapter, (a) a 500 on calculate shows the error state; (b) a calc payload with `estimated_total_landed_cost_egp: 1000000, landed_variance_pct: 5.0` shows "5.00%".
- **Out of scope:** the Incoterm rule card text.

### FE09-T05 - Settlement details (View) dialog
- **Severity:** MAJOR. **Type:** feature. **Depends on:** none. **Backend needed:** no (`GET /financial-settlement/{id}` exists). FE09-T07 enriches the header later.
- **Files to change:** `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`, new `frontend/lib/features/financial_settlement/widgets/settlement_details_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/settlement_registry_card.dart`, `frontend/lib/features/financial_settlement/models/financial_settlement_model.dart`, l10n files.
- **Steps:**
  1. Provider: `Future<LandedCostSettlementModel> fetchSettlement(int id)` that does a GET on `/financial-settlement/$id`.
  2. Model: parse `incoterm_code`, `created_by`, `updated_by` (present in `FinancialSettlementResponse`).
  3. The new dialog loads on open (spinner, error + retry). It shows a header (code, file title, status chip, incoterm, accountant), audit (created/updated by/at), the 4 KPIs, the expenses table and the items table (including the "Other" column from FE09-T09), and notes. Footer: Odoo journal, Copy breakdown, Close. Read-only, so it has no inputs.
  4. Card: `onView` opens `SettlementDetailsDialog`. The "Odoo journal" button keeps `onOpenJournal`. Set `viewTooltip` to a new key `settlementViewDetailsTooltip`.
- **Acceptance criteria:**
  - [ ] The eye icon on a row opens the settlement details, not the journal.
  - [ ] The details dialog shows who created and last updated the settlement, and when.
  - [ ] The details are fetched fresh from the server every time the dialog opens.
- **Tests to add:** `frontend/test/features/financial_settlement/settlement_details_dialog_test.dart`: the stub GET `/financial-settlement/7` returns a record with `created_by: 'acc1'`, and the test asserts the code, 'acc1' and an item row are rendered.
- **Out of scope:** editing from the dialog.

### FE09-T06 - Registry as a scalable table (filters, show-deleted, restore, debounce)
- **Severity:** MAJOR. **Type:** ux. **Depends on:** FE09-T05, FE09-T02. **Backend needed:** no for this task (Phase B pagination is in §6).
- **Files to change:** `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`, `frontend/lib/features/financial_settlement/widgets/settlement_registry_card.dart` (keep only the reusable expense/item table builders, or move them into the details dialog), l10n files.
- **Steps:**
  1. Provider: keep the last `includeInactive`, `status` and `search` in fields, so `fetchSettlements()` with no args re-applies them (filters survive refresh and invalidation).
  2. Replace the `SliverList` of cards (`screen:644-670`) with `EnterpriseDataTable<LandedCostSettlementModel>` (`core/widgets/enterprise_data_table/enterprise_data_table.dart`). Columns: code, file title, status (chip), FOB EGP, expenses EGP, landed EGP, markup, updated_at, actions (View, Odoo, Recalculate, Clone, Delete/Restore by status). `storageKey: 'financial_settlement_registry'`, `initialPageSize: 50`, `initialSortColumnId: 'updated_at'` desc, sticky header. Row tap opens View.
  3. Toolbar: status `ChoiceChip`s (All/Draft/Calculated/Approved), passed to `fetchSettlements(status:)`. A "Show deleted" `Switch` passes `includeInactive`. Debounce search with a 350 ms `Timer`, cancelled in `dispose`.
  4. Inactive rows: muted text, and their only action is Restore (`await notifier.restoreSettlement`, SnackBar success / `ApiErrorText`).
  5. The header shows "N settlements" (filtered count).
- **Acceptance criteria:**
  - [ ] The registry shows one compact row per settlement, sortable by every money column, with 25/50/100 page sizes.
  - [ ] Typing in search sends one request after the user stops typing.
  - [ ] The user can show deleted settlements and restore one. A duplicate active settlement shows a clear red message.
  - [ ] The status filter persists after the refresh button.
- **Tests to add:** `frontend/test/features/financial_settlement/settlement_registry_table_test.dart`: (a) 120 stub records render with a "120" count and only the page-size number of rows; (b) toggling "Show deleted" sends `include_inactive=true` (check the stub request); (c) typing 5 chars quickly produces 1 request.
- **Out of scope:** server pagination (needs the backend), and export of all pages.

### FE09-T07 - Show the import file code, never the DB id
- **Severity:** MAJOR. **Type:** bug. **Depends on:** backend B1 (§6). **Backend needed:** yes, `import_file_code` and `company_name` on `FinancialSettlementResponse` (list and get).
- **Files to change:** `frontend/lib/features/financial_settlement/models/financial_settlement_model.dart`, `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, `frontend/lib/features/financial_settlement/screens/landed_cost_comparison_screen.dart`, `frontend/lib/features/financial_settlement/widgets/search_and_clone_financial_settlement_dialog.dart`.
- **Steps:**
  1. The model parses `import_file_code` and `company_name` (default '').
  2. `_fileTitle` (`screen:138-143`) uses the record fields first, then `importFilesMap`, then `'-'`. Delete `'IMP-${r.importFileId}'` (`:140`, `:649`).
  3. Comparison `:165`, `:401`: use `'-'` / `''` instead of `IMP-#id`.
  4. The clone dialog search also matches `importFileCode`.
- **Acceptance criteria:**
  - [ ] No screen in this feature shows "IMP-<number>" built from a database id.
  - [ ] The registry shows the file code even when the Import Files list was filtered elsewhere.
- **Tests to add:** in `settlement_models_test.dart`, parse a record with `import_file_code: 'IF-2026-0012'`. A widget test asserts the absence of the text `IMP-7` when the file is not in `importFilesProvider`.
- **Out of scope:** the backend change itself.

### FE09-T08 - Render codes, not backend Arabic text (CLO-01, CLO-02, PL-08)
- **Severity:** MAJOR. **Type:** bug (still open from FE-07). **Depends on:** none. **Backend needed:** no (`party_type`, `category_code`, `variance_status`, `import_file_code` already sent). Optional: `message_code` on confirm and approve responses (§6 B4).
- **Files to change:** `frontend/lib/features/financial_settlement/models/invoices_aggregation_model.dart`, `frontend/lib/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/estimated_landed_cost_dialog.dart`, l10n files.
- **Steps:**
  1. The model parses `category_code` (nullable).
  2. Add `String settlementPartyLabel(AppLocalizations, String partyType)` (in `settlement_ui.dart` or the dialog) that maps SUPPLIER/CARRIER/INSURANCE/CUSTOMS/BROKER/TRANSPORT/DEMURRAGE/WAREHOUSE/OTHER to the `settlementClo01Party*` keys (add Warehouse/Other keys).
  3. Invoices dialog `:457`, `:463`: party uses `settlementPartyLabel(inv.partyType)`. Category uses `DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, inv.categoryCode ?? inv.category) ?? inv.category`.
  4. `:119`: the SnackBar text becomes `l10n.settlementClo01ConfirmedSnack(res.importFileCode, res.invoicesCount)`.
  5. Actual dialog `:478`: show `settlementCategoryLabel(context, cat.category)` (a single line). `:287`: variance text comes from `varianceStatus` via the keys `settlementClo02StatusSaving/Over/Matched`. `:137`: `l10n.settlementClo02ApprovedSnack(res.settlementCode ?? '', res.importFileCode)`.
  6. Estimated dialog `:383`: hide `executiveSummaryAr` when `Localizations.localeOf(context).languageCode != 'ar'`, or build the summary from the KPIs with an l10n template `settlementEstSummary(...)` (preferred).
- **Acceptance criteria:**
  - [ ] With the English locale, the CLO-01, CLO-02 and PL-08 dialogs show no Arabic text coming from the server.
  - [ ] With the Arabic locale, the labels are the same meaning as before.
- **Tests to add:** `frontend/test/features/financial_settlement/settlement_labels_test.dart`: pump the invoices dialog in `en` with a stub aggregation (`party_type: 'CARRIER', party_type_ar: 'ناقل'`) and assert that 'ناقل' is not found and the English carrier label is found.
- **Out of scope:** `recalculate_button.dart` (FE09-T10).

### FE09-T09 - Items table: add "Other allocated"
- **Severity:** MAJOR. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/settlement_registry_card.dart` (or the details dialog after T05), `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, l10n files.
- **Steps:**
  1. Add `DataColumn(financialSettlementColAllocatedOther, numeric)` after transport, with a cell `money(itm.allocatedOtherEgp)`, in `_buildItemsTable` (`card:253-299`) and its `rowSummary`.
  2. Add the same column to `_copySettlementBreakdownTsv` (`screen:341-366`).
  3. Add the l10n key `financialSettlementColAllocatedOther`.
- **Acceptance criteria:**
  - [ ] For each item, freight + customs + clearance + transport + other = unit landed cost − FOB unit (within rounding), visible on screen.
- **Tests to add:** in `settlement_models_test.dart` or a widget test, a record with `allocated_other_egp: 12.5` shows "12.50".
- **Out of scope:** backend bucket mapping.

### FE09-T10 - Recalculate button renders message codes
- **Severity:** MAJOR. **Type:** bug (still open from FE-07 / shared need). **Depends on:** none. **Backend needed:** no (`message_code` + `params` are parsed already: `recalculation_model.dart:74`, `:107`).
- **Files to change:** `frontend/lib/core/widgets/recalculate_button.dart`, `frontend/lib/core/localization/system_messages/system_message_renderer.dart` (only if the codes are not registered), l10n files.
- **Steps:**
  1. Add a helper `String _msg(l10n, code, params, fallback)` that uses the system message renderer when `code != null` and `messageAr` otherwise.
  2. Replace `Text(preview.messageAr)` (`:191`, `:327`) and `Text(result.messageAr)` (`:236`).
- **Acceptance criteria:**
  - [ ] With the English UI, the recalculate preview and success messages are English when the server sends `message_code`.
- **Tests to add:** `frontend/test/core/widgets/recalculate_button_message_test.dart`: a preview with `message_code` + `message_ar` renders the coded text, and without a code it renders `message_ar`.
- **Out of scope:** other `RecalculateButton` callers' behaviour.

### FE09-T11 - CLO-01 confirm and CLO-02 approve: confirmations and dead fields
- **Severity:** MAJOR. **Type:** ux. **Depends on:** FE09-T08 (same files, do it after). **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `frontend/lib/features/financial_settlement/providers/financial_settlement_provider.dart`, l10n files.
- **Steps:**
  1. CLO-01: before `_handleConfirmSettlement`, show an `AlertDialog` with the count, total and remaining. When `totalRemainingEgp > 0`, add an orange warning line `settlementClo01ConfirmUnpaidWarning(amount)`. Continue only on Yes.
  2. CLO-01: disable the confirm button when `financialSettlementStatus` is `INVOICES_SETTLED` or later. Replace the "Settled by" `TextFormField` (`:537-548`) with read-only text showing the signed-in user.
  3. CLO-02: replace the "Approved by" `TextField` (`:579-591`) with read-only text, and remove the empty check (`:108-116`). Remove the `approvedBy` parameter from `approveActualLandedCost` (`provider.dart:226`) and update its callers and tests.
  4. CLO-02: show a confirm dialog with the landed total, variance % and allocation rule before approving. Disable approve when `itemsBreakdown.isEmpty` or any `messages` has `severity == 'error'`, with a tooltip that gives the reason.
- **Acceptance criteria:**
  - [ ] Confirming invoices with unpaid amounts asks for explicit confirmation and shows the unpaid total.
  - [ ] An already settled file shows the CLO-01 button disabled.
  - [ ] A user without a full name can still approve. Approval always asks "are you sure" first.
- **Tests to add:** extend `financial_settlement_provider_test.dart` (approve has no `approvedBy`). Add `clo_dialogs_confirm_test.dart`: with remaining > 0, tapping confirm shows the warning dialog, and with no items the approve button is disabled.
- **Out of scope:** backend ordering CLO-01 before CLO-02 (Q2).

### FE09-T12 - Clone and create keep every line
- **Severity:** MAJOR. **Type:** bug. **Depends on:** Q1 (if the CTO drops the manual form, do only step 1). **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/settlement_form_dialog.dart`, `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, l10n files.
- **Steps:**
  1. In `buildSettlementCreatePayload`, accept `List<ExpenseInvoiceModel>` / `List<ItemLandedCostModel>`.
  2. Form state holds lists. The current single-line inputs become the editor for the "new line", with an "Add line" `AppButton`. Lines added so far show in a compact read-only list with remove buttons. A clone prefills the lists with all source lines.
  3. Validation: at least 1 invoice and 1 item.
  4. Exclude files that already have an active settlement from the import-file dropdown (F09-23). "Reset" clears all fields and lists.
- **Acceptance criteria:**
  - [ ] Cloning a settlement with 3 invoices and 5 items to another file creates a settlement with 3 invoices and 5 items.
  - [ ] The file dropdown does not list files that already have an active settlement.
- **Tests to add:** in `settlement_form_dialog_test.dart`, a clone of a 3/5-line record posts a payload with 3 `expense_invoices` and 5 `item_landed_costs`.
- **Out of scope:** a PUT edit UI (Q1).

### FE09-T13 - PL-08 override validation and export hygiene
- **Severity:** MAJOR. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/estimated_landed_cost_dialog.dart`, l10n files.
- **Steps:**
  1. Wrap the override inputs in `Form(key: _overridesKey)`. Each input becomes a `TextFormField` with the validator "empty OK, else `parseSettlementNumber` != null and >= 0" (`settlementNonNegativeNumberRequired`), using `AutovalidateMode.onUserInteraction`.
  2. `_buildRequestFromControllers` uses `parseSettlementNumber` (accepts a comma). `_loadSimulation` returns early when the form is invalid.
  3. TSV header (`:179-180`): build it from l10n keys (reuse `settlementEstCsvHeader` split by `,` or add per-column keys).
  4. CSV (`:207`): escape every text field (`"${v.replaceAll('"', '""')}"`). `stageName` uses `l10n.settlementStageSimulation`.
- **Acceptance criteria:**
  - [ ] Typing "abc" or "-5" in an override shows a red error and does not run the simulation.
  - [ ] "1,500" is accepted as 1500.
  - [ ] An item named `Valve "A", 2"` exports to a CSV that opens with the correct columns.
- **Tests to add:** `frontend/test/features/financial_settlement/estimated_dialog_validation_test.dart`: an invalid override shows the error and the stub adapter receives no second POST.
- **Out of scope:** simulation math.

### FE09-T14 - Large item tables and CLO-02 export
- **Severity:** MAJOR. **Type:** feature. **Depends on:** FE09-T03. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/widgets/settlement_ui.dart` (add `SettlementLazyTable`), `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/estimated_landed_cost_dialog.dart`, new `frontend/lib/features/financial_settlement/services/actual_landed_cost_export_service.dart`, l10n files.
- **Steps:**
  1. `SettlementLazyTable`: given column specs (label, width, numeric) and `rowCount` + `cellBuilder(row, col)`, it renders a pinned header row and a `ListView.builder` body inside one horizontal `Scrollbar` + `SingleChildScrollView`, with fixed column widths. Numeric cells align to the end and use `SettlementMoneyText`.
  2. Use it for the CLO-02 items tab (`actual:522-610`) and the PL-08 items table (`estimated:597`).
  3. The export service builds rows from `calc.itemsBreakdown` and calls `TableExportService.exportTableToExcel` / `exportTableToPdf` (these go through `FileSaveHelper`) with `stageName: l10n.settlementStageActualLandedCost` and `importFileNameOrCode: calc.importFileCode`.
  4. Add Excel and PDF `IconActionButton`s to the CLO-02 allocation control bar.
- **Acceptance criteria:**
  - [ ] A CLO-02 calculation with 2,000 items opens without freezing, and the header stays visible while scrolling.
  - [ ] The user can export the itemized landed cost sheet to Excel and PDF, with a Save As dialog and the name "Actual Landed Cost - <file code>".
- **Tests to add:** `frontend/test/features/financial_settlement/settlement_lazy_table_test.dart`: 2,000 rows build fewer than 100 row widgets (`find.byType(...)` count) and the header text is found after scrolling.
- **Out of scope:** CLO-01 invoice export.

### FE09-T15 - Hygiene: Odoo, stage code, defaults, shared provider
- **Severity:** MINOR. **Type:** refactor. **Depends on:** FE09-T07. **Backend needed:** no.
- **Files to change:** `frontend/lib/features/financial_settlement/screens/odoo_journal_entry_dialog.dart`, `frontend/lib/features/financial_settlement/screens/financial_settlement_screen.dart`, `frontend/lib/features/financial_settlement/models/invoices_aggregation_model.dart`, `frontend/lib/features/financial_settlement/widgets/actual_landed_cost_dialog.dart`, `frontend/lib/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart`.
- **Steps:**
  1. Odoo `:269-276`: `onPressed: (!entry.isBalanced || _isExporting) ? null : ...` plus a tooltip showing the difference. `:336`: replace `Colors.transparent` with `null`.
  2. Screen `:431`: `stageCode: 'PHASE-9: STEP_20'`. `:216`, `:245`: `stageName: l10n.settlementStageRegistry`.
  3. Model `:56`, `:66`: defaults become `''` and `'UNKNOWN'`. The invoices dialog renders `UNKNOWN` as a grey "Unknown" chip.
  4. Remove the CLO-02 "Source" column (`actual:503` and its header) because the backend never sends `source_note`.
  5. Invoices table: add `invoice_date` and WHT columns.
  6. Screen `initState` (`:50-52`): stop calling `fetchImportFiles()` once FE09-T07 has landed.
- **Acceptance criteria:**
  - [ ] Odoo export buttons are disabled when the journal is unbalanced, and a tooltip explains why.
  - [ ] An invoice with no payment status is not shown as "Paid".
- **Tests to add:** in `settlement_models_test.dart`, an aggregation row without `payment_status` parses as `'UNKNOWN'`.
- **Out of scope:** the lookup provider for import-file pickers (backlog after backend B2 search).

## 6. Backend dependencies

- **B1:** add `import_file_code` and `company_name` to `FinancialSettlementResponse` (list + get + create + restore). Needed by FE09-T07.
- **B2:** paginated summary list: `GET /financial-settlement?page=&page_size=&sort=&order=` returning `{items, total}` with summary fields only (no `expense_invoices` / `item_landed_costs` blobs). Extend `search` to the import file code and company name (`repository.py:62-67`). Add an "export all" endpoint (xlsx) for the registry. Needed for phase B of §3.
- **B3:** the CLO-02 item line could carry `currency`, `fob_unit_fc` and `unit_of_measure` so the dialog can show both FC and EGP (FE09-T03 works without them).
- **B4:** confirm and approve responses add `message_code` + `params` (the `message` is Arabic). FE09-T08 has a client-side fallback.
- **B5:** `source_note` on `ActualLandedCostCategoryBreakdown`, or confirm the column is dropped (FE09-T15).
- **B6:** approve does not check that CLO-01 was confirmed (`service.py:2473-2474`). Decide per Q2.

## 7. Open questions for the CTO

- **Q1:** Should the manual "New settlement" form (one invoice + one item typed by hand) stay? The business doc (BP-036/037) says costs are aggregated automatically "with no duplicate manual entry", and CLO-02 approve already creates the settlement. [Safe default: keep it for corrections, but make clone carry every line (FE09-T12); no PUT edit UI.]
- **Q2:** Must CLO-01 (invoices confirmed) be done before CLO-02 approve? Today the backend allows approve first. [Safe default: the frontend warns when the status is not `INVOICES_SETTLED`; the backend enforcement is B6.]
- **Q3:** Registry page size and the default sort. [50 rows, newest updated first.]
- **Q4:** Should a CLO-01 invoice row link to its source record (supplier invoice, freight, clearance…)? [Backlog.]
- **Q5:** Do you want a screen for the recalculation logs (`/recalculation/logs`)? [Backlog.]
- **Q6:** On the comparison tab, "estimated" = the PL-08 / CLO-02 backend estimate (EGP), not `import_files.estimated_cost`. OK? [Yes, FE09-T04.]
