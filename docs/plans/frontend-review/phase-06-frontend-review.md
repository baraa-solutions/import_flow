# Phase 06 Customs preparation: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited).
Scope: BP-026 (final document review), BP-027 (broker assignment: CS-01 broker authorization, CS-02 delivery order,
broker quotations/RFQs), BP-028 (CS-03 customs declaration 46). Phase 07 dialogs (inspection, assessment, duty payment,
release, invoices, under-bond) are **out of scope** here except where they share a file with Phase 06.

Where the screens live (from `frontend/lib/features/home/home_screen.dart` and `core/providers/navigation_provider.dart`):

| Screen | Entry | File |
|---|---|---|
| Customs Declaration 46 (form + registry) | sidebar "5. Port & Clearance" → index 23/24 | `frontend/lib/features/import_documentation/screens/customs_declaration46_screen.dart` |
| Customs Clearance Hub (CS-01/CS-02/CS-03 header buttons + record list) | sidebar index 27 | `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart` |
| Broker clearance quotations (RFQs + price list) | only embedded: Customs Consultation tab 4 (`customs_consultation_screen.dart:3669`) and `broker_price_lists_tab.dart:112` | `frontend/lib/features/customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart` |

Coverage depth:

| file | lines | depth |
|---|---|---|
| `import_documentation/screens/customs_declaration46_screen.dart` | 2,102 | Full read of 1-1110 and 1110-1600, save + exports 2040-2102 |
| `customs_clearance/screens/customs_clearance_screen.dart` | 867 | Full |
| `customs_clearance/providers/customs_clearance_provider.dart` | 323 | Full |
| `customs_clearance/widgets/customs_broker_authorization_dialog.dart` | 404 | Full |
| `customs_clearance/widgets/customs_declaration_46_dialog.dart` | 616 | 1-260 full, 260-616 grep |
| `customs_clearance/widgets/delivery_order_payment_dialog.dart` | 530 | 1-200 full, rest grep |
| `customs_clearance/widgets/clearance_card.dart` | 249 | Full |
| `customs_clearance/widgets/clearance_screen_dialogs.dart` | 738 | `ClearanceFormDialog` 60-200 full, fallback dialogs grep (Phase 07) |
| `customs_clearance/widgets/customs_ui.dart` | 452 | `statusStyle` only |
| `customs_clearance/models/customs_clearance_model.dart` | 418 | JSON keys vs `CustomsClearanceResponse` |
| `customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart` | 614 | Full |
| `customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart` | 193 | Full |
| `customs_clearance_quotations/widgets/quotation_dialogs.dart` | 738 | 90-130, 300-470, 600-640 full, rest grep |
| `customs_clearance_quotations/widgets/rfq_card.dart` | 337 | grep + 210-236 |
| `customs_clearance_quotations/services/customs_clearance_quotations_export_service.dart` | 666 | save calls only |
| `customs_clearance_quotations/widgets/smart_clearance_extractor_dialog.dart` | 722 | grep |
| Backend contract | — | `modules/customs_clearance/{router.py, schemas.py:72-110, 359-460, service.py:348-366 + status strings}`, `modules/customs_clearance_quotations/{router.py, repository.py:15-45}` |
| Docs | — | `docs/phase_06_customs_preparation.md`, `docs/phase_06/README.md`, `docs/phase_06/tasks/*` (generic templates), `docs/plans/phase-06-07-quality-plan.md`, `docs/plans/review-coverage.md` |

Previous wave check (phase-06-07-quality-plan FE items): FE-04 (dropdowns), FE-05 (provider fallback 1), FE-06 (raw `$e`),
FE-08/FE-09 (colors, Arabic literals), FE-10 (filters kept, related providers invalidated) are **verified fixed** in the
files above. FE-12 is **still open** for the quotations export service (see F06-19).

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 6 |
| CRITICAL | 5 |
| MAJOR | 18 |
| MINOR | 7 |

Most important points:

1. **The Declaration 46 screen in the sidebar never saves.** `_saveDeclaration46` waits 600 ms and shows "saved"
   (`customs_declaration46_screen.dart:2083-2101`). Its "registry" invents a declaration for every import file:
   number `46-ALX-<file code>`, today's date and the status "Registered on Nafeza" (`:1128, 1243-1244`). Users believe
   declarations are registered when nothing reaches the backend.
2. **Official references and money are invented by the CS dialogs.** On open, the CS-01 dialog generates a random
   delegation number, the CS-03 dialog a random 46 number + MTS number, and the CS-02 dialog a random D/O number with a
   default fee of **12,500 EGP**. One click on "confirm" stores them as real customs data and the D/O fee flows into landed cost.
3. **The hub stage buttons act on the wrong shipment.** Opened from the sidebar, the CS-01/02/03 buttons use
   `files.first` (`customs_clearance_screen.dart:426-441`), with no file picker.
4. **Edit is broken.** The edit dialog POSTs a new record (`clearance_screen_dialogs.dart:165`), so the backend always
   answers 400 "already exists" (`service.py:361-366`).
5. **Large tables and "Show".** No list in this phase pages on the server. The RFQ list is silently cut at 100 rows by
   the backend default `limit=100`. No entity has a read-only View: clearance records only have Edit (which is broken),
   and the Declaration 46 registry "view" shows a computed estimate, not a stored declaration.

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F06-01 | BLOCKER | `import_documentation/screens/customs_declaration46_screen.dart:2083-2101` | `_saveDeclaration46` is a stub: `Future.delayed(600ms)`, then the success SnackBar, then a jump to the registry tab. No API call. Data typed by the user is lost. | Call `customsClearanceProvider.notifier.registerDeclaration46(payload)` (existing, `customs_clearance_provider.dart:121`). Show `ApiErrorText` on failure. Stay on the form on error. |
| F06-02 | BLOCKER | same file `:1116-1245`, `:1262-1291` | The registry is built from `importFilesProvider`: one fake "declaration" per import file. Number `'46-ALX-${file.importFileCode}'` (l.1128), `registrationDate: DateTime.now()` (l.1243), status `l.customsDeclStatusRegisteredNafeza` for every file (l.1244). The KPIs (total CIF, total duties) sum client estimates as if declared. | The registry must list real `customs_clearance` records with `declaration46No != null` (from `customsClearanceProvider`). Show `declaration_46_no`, `declaration_46_date`, office, channel, MTS, status from the record. The computed tariff estimate stays as a separate "estimate" column. |
| F06-03 | BLOCKER | same file `:134`, `:281` | The declaration-number field is prefilled with `'46-EG-2026-'`, then `'46-ALX-${file.importFileCode}'` on file select. The required validator always passes on the invented value. | Start empty. Prefill only from the stored record (`file.form46No` or the clearance record). |
| F06-04 | BLOCKER | `customs_clearance/widgets/customs_declaration_46_dialog.dart:114-116`, `:144-166` | When `file.form46No` is empty, `initState` calls `_generateDeclaration46Number()`: `46-<year>-<port>-<random>` plus `MTS-<year>-<port>-<random+100>`. Submit sends them to `POST /customs-clearance/register-declaration-46`. A fake official number gets stored. | Remove the generator and its button (`generateDeclaration46Btn`, l.325-330). Fields start empty. 46 no. is required (min 3), MTS is optional. |
| F06-05 | BLOCKER | `customs_clearance/widgets/customs_broker_authorization_dialog.dart:73-75`, `:99-115`, `:305-309` | The same pattern for the CS-01 delegation number: `DEL-<year>-<port>-<random>` is generated on open and stored as the Nafeza delegation. | Remove `_generateDelegationNumber` and the auto-fix button. Start empty, and keep the required validator. |
| F06-06 | BLOCKER | `customs_clearance/widgets/delivery_order_payment_dialog.dart:69`, `:74-76`, `:98-111` | D/O fee defaults to `'12500'`, and the D/O number is random `DO-<line>-<year>-<rand>`. The fee is money. `financial_settlement` sums D/O fees into landed cost (see the previous plan §4, "D/O fees are summed"). | Fee starts empty with a required validator (>= 0). D/O number starts from `file.deliveryOrderNo` or empty. Remove `_generateDONumber`. |
| F06-07 | CRITICAL | `customs_clearance/screens/customs_clearance_screen.dart:426-441`, `:476-523`; also `:101-108` | `_openStage` targets `widget.initialImportFileId`, else `files.first`. From the sidebar (index 27, no file id), CS-01/CS-02/CS-03 open for whatever file is first in the list, with no picker, so they record a broker, D/O or 46 on the wrong shipment. The experience-guide banner also uses `files.first`. | Before opening a stage dialog with no `initialImportFileId`, show an import-file picker (`SearchableDropdownField<int>` in a small dialog). Also add the per-record actions CS-01/CS-02/CS-03 on each `ClearanceCard` (file = `record.importFileId`). Skip the guide banner when no file is selected. |
| F06-08 | CRITICAL | `customs_clearance/widgets/clearance_screen_dialogs.dart:134-167`; backend `modules/customs_clearance/service.py:361-366` | `ClearanceFormDialog._save` always calls `createRecord` (POST), also in edit mode. The backend rejects a second active record for the file with 400, so **edit never works**. Clone (same file) also always gets 400. The payload total (l.143) leaves out `development_fee_amount` and `customs_service_fees`, and the form has no fields for them. | Edit: a new provider method `updateRecord(id, payload)` → `PUT /customs-clearance/{id}`, sending only editable fields (no `total_duty_payable`: the server computes it after CL-03 of the previous plan). Clone: allow only to a **different** import file (file picker required, the source file excluded). |
| F06-09 | CRITICAL | `customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart:19-34`; backend `customs_clearance_quotations/router.py:39-58` | `fetchRFQs` never sends `skip`/`limit`. The backend default is `limit=100`, so from RFQ 101 the oldest RFQs silently disappear and the metrics count only 100. | Short term: page through the RFQs (`skip += 500` until fewer than 500 come back), or show "showing first N". Target: server-side paging (see §3 and §6). |
| F06-10 | CRITICAL | `customs_clearance_quotations/widgets/quotation_dialogs.dart:105-109`, `:305-310`, `:486` | Invented defaults: RFQ gross weight 10000, CBM 30, port "Alexandria Port", shipment "Ocean FCL (40HQ)". Quote fees 3000 / 6000 / 1500 / 2000 / 500 EGP and 3 days. Price item 3500 EGP. They are saved unless the user edits them, and the award compares these totals. | All numeric fields start empty with validators (required, >= 0). The port comes from `transportLocationsProvider` or the linked file's port of discharge, never a constant. |
| F06-11 | CRITICAL | `customs_clearance_quotations_screen.dart:598-612` (+ `smart_clearance_extractor_dialog.dart`) | The smart extractor opened from the toolbar (`targetRfqId == null`) attaches the extracted quote to `rfqs.first` (the newest RFQ), whatever RFQ the offer is for. | When no target RFQ: show an RFQ picker (`SearchableDropdownField<int>` of RFQs, label = code + title + port), or "create new RFQ". Never default. |
| F06-12 | MAJOR | `customs_clearance_quotations_screen.dart:565-570` | Price-list delete: no confirmation, and the future is not awaited or caught. A 4xx becomes an unhandled exception with no SnackBar. | Confirm dialog, then `try/await` with `ApiErrorText` SnackBar (same as `confirmDeleteQuotation`). |
| F06-13 | MAJOR | `customs_clearance_quotations_provider.dart:58-79`, `:173-183`; `rfq_card.dart` | `updateRFQ`, `deleteRFQ` and `updatePriceItem` exist but no UI calls them. RFQs cannot be edited, cancelled or deleted, and price items cannot be edited. | Add Edit / Cancel / Delete on `RfqCard` and Edit on price rows (see FE06-T12). |
| F06-14 | MAJOR | `customs_clearance_provider.dart:279-297`; `clearance_card.dart:169-190` | `softDeleteRecord` / `restoreRecord` are never used, and there is no "show inactive" toggle. A wrong clearance record cannot be removed from the UI. | Delete (confirm) on the card, a "show deleted" switch → `fetchRecords(includeInactive: true)`, and Restore on inactive cards. |
| F06-15 | MAJOR | `clearance_card.dart:45-50`, `:99`; `customs_clearance_screen.dart:284-286` | The shipment is resolved with the fake code `'IMP-${record.importFileId}'`. Real codes are `IMP-<year>-<seq>` (`modules/import_files/repository.py:18`), so the lookup never matches and the card shows `IMP-12`, a DB id (CORE_RULES §6). Exports carry the same value. | Resolve by id: `files.firstWhereOrNull((f) => f.importFileId == record.importFileId)`, then `DisplayNameResolver.resolveShipmentTitle(file)` and `file.importFileCode`. Show "-" when it is not found. |
| F06-16 | MAJOR | `customs_broker_authorization_dialog.dart:54-62, 77-85`; `customs_declaration_46_dialog.dart:59-69, 118-132`; `clearance_screen_dialogs.dart:64` | Customs offices are hard-coded in two **different** lists ("Port Said Port Customs" vs "Port Said Customs", "Ain Sokhna Customs" vs "Sokhna Port Customs"), and the edit form takes free text. The port is matched by Arabic substrings. The same office is stored under several spellings. | One shared constant list of office **codes** in `customs_ui.dart` (labels via l10n `ccDecOffice0..8`, which already exist), used by both dialogs and the edit form. A legacy free-text value is shown as is. A master table is an open question (Q1). |
| F06-17 | MAJOR | `customs_broker_authorization_dialog.dart:227-233`; `delivery_order_payment_dialog.dart:303-312`; `customs_clearance_quotations_screen.dart:498-503`; `smart_clearance_extractor_dialog.dart:250` | Brokers and shipping agents are filtered with free-text `partnerType.contains('broker'/'تخليص'/'مخلص'/'ملاح')`. When nothing matches, the D/O dialog falls back to **all** partners. | One helper `PartnerRoles.isCustomsBroker(p)` / `isShippingAgent(p)` in `features/external_service_providers/` using `p.categoriesList` with exact English codes plus a legacy map. No fallback to all partners: show an empty state "no shipping agents defined". |
| F06-18 | MAJOR | `delivery_order_payment_dialog.dart:57,60`; `quotation_dialogs.dart:615`; quote dialog `:300-470` | The D/O currency is a hard-coded `['EGP','USD','EUR']`, and the price-item currency is fixed to `'EGP'`. The quote dialog has no currency and no validity date, although the model and API support `currency` and `validity_date` (model l.13-15). | Currency from `currenciesProvider` (`SearchableDropdownField<String>`). Add Currency and Validity date to the quote dialog. |
| F06-19 | MAJOR | `customs_clearance_quotations_export_service.dart:91-97, 182, 405-408, 522, 565, 661` | TSV saved as `clearance_rfqs_<ms>.tsv` and PDF printed through `Printing.layoutPdf`. This breaks the Task-I rule (`FileSaveHelper.exportAndSaveFile` with `[Stage Name] - [Import File Code].ext`). Still open from FE-12. | Route all exports through `FileSaveHelper.exportAndSaveFile` (as `core/services/table_export_service.dart:125` does). Name: `Customs Clearance RFQs - <file code or "Registry">.<ext>`. |
| F06-20 | MAJOR | `customs_clearance_screen.dart:758-767`; `customs_clearance_provider.dart:52-89` | Search and status filtering are client-side only, although `GET /customs-clearance` accepts `status` and `search`. They only filter what was loaded. | Debounce (400 ms), then `fetchRecords(search:, status:)`. Keep the client filter only as instant feedback. |
| F06-21 | MAJOR | `customs_clearance_screen.dart:693-700`; `customs_ui.dart:90-116`; backend `service.py:586, 672, 754` | The status filter offers `Inspection In Progress / Duty Requested / Duty Paid / Final Release Granted`. The Phase-06 statuses the backend writes ("Broker Authorized - Ready for 46", "D/O Received - Ready for 46", "Under Customs Clearance") cannot be filtered and are shown as **raw English** in the Arabic UI. "Duty Requested" is never written by the backend. | Add the 3 Phase-06 statuses to the filter and to `statusStyle` with l10n labels. Drop "Duty Requested" or keep it for legacy rows only. |
| F06-22 | MAJOR | `delivery_order_payment_dialog.dart:148` | `delivery_order_paid_at` is sent as the D/O **receipt date**, and there is no payment-date field. | Add a separate "Paid at" date picker (default empty, required when a payment ref is entered). |
| F06-23 | MAJOR | `customs_declaration46_screen.dart:143`, `:838-844` | The submission date is a free-text field with no date picker and no validator. | Date picker (`showDatePicker`), stored as `DateTime`, sent as `declaration_46_date`. |
| F06-24 | MAJOR | `home_screen.dart:969` vs `customs_clearance_screen.dart:488-493` | There are two Declaration 46 entry points that behave differently: the sidebar screen (stub save, fake registry) and the hub header dialog (real POST). | After FE06-T01/T02, both use the same provider call, and the screen form reuses the dialog's field rules. |
| F06-25 | MAJOR | `customs_declaration46_screen.dart:1272-1288`, `:1385-1578` | Large table: the registry `DataTable` builds every row eagerly and recomputes `_calculateAssessment` (PO items × tariffs) for **every import file on every keystroke** of the search box. | See §3: `EnterpriseDataTable` with paging, computed once per data change (memoised), debounced search. |
| F06-26 | MAJOR | `customs_clearance_quotations_screen.dart:523-595` | Large table: the price list is a `DataTable` in a vertical `SingleChildScrollView` with `width: double.infinity`. There is no horizontal scroll (columns get clipped on narrow windows), no search, no sort and no paging, and all rows are built. | `EnterpriseDataTable<ClearancePriceListItemModel>` (search, sort, paging, column widths, horizontal scroll). |
| F06-27 | MAJOR | `customs_broker_authorization_dialog.dart:67`; quotations award `quotation_dialogs.dart:643` | The award result is not used: CS-01 preselects only `file.brokerId` and ignores the broker awarded in the clearance RFQ of the same file. The quotations screen is not in the Phase 5/6 sidebar group (only inside Customs Consultation tab 4), so BP-027 users cannot find it. | CS-01: if an RFQ with `importFileId == file.importFileId && status == 'Awarded'` exists, preselect `awardedProviderId` and show an info chip. Add a sidebar item "Broker clearance quotations" under the Port & Clearance group (new nav index). |
| F06-28 | MAJOR | (missing feature) docs `phase_06_customs_preparation.md` BP-026 | No final pre-clearance check before CS-01: B/L ↔ invoice ↔ packing match, insurance present for FOB/CFR, ACID valid, importer IDs. | Read-only "Readiness" panel at the top of the CS-01 dialog, built from existing providers (ACID expiry, `cargoInsuranceProvider`, invoice-vs-B/L match sessions). Warn only, never block (Q3). |
| F06-29 | MAJOR | `clearance_card.dart:87-128` | The card hides all Phase-06 data: broker name, delegation no./date, mandate letter code, D/O date/expiry/fees/status, declaration date, MTS, regulatory bodies. The only way to see them is Edit (broken, and the form lacks these fields). | Read-only details dialog (FE06-T09). |
| F06-30 | MINOR | `clearance_card.dart:57` | Hard-coded variance warning threshold `> 500` (EGP). | Use a named constant in `customs_ui.dart`, or the percentage from the record (`dutyVariancePercentage`). Q4. |
| F06-31 | MINOR | `rfq_card.dart:285-289` | The delete icon is shown on the awarded quote, and the backend answers 409. | Hide or disable it when `q.isAwarded`. |
| F06-32 | MINOR | `rfq_card.dart` (~l.56-58) | "Lowest cost" is always labelled EGP, even for quotes in another currency. | Show the currency of the cheapest quote. |
| F06-33 | MINOR | `customs_clearance_quotations_provider.dart:24`, `:139` | Every refetch sets `AsyncValue.loading()`, so the list flashes and scroll resets after each add, award or delete. | Keep the previous data while reloading (`state = const AsyncLoading<...>().copyWithPrevious(state)`, or only set loading when `state.valueOrNull == null`, as the clearance notifier does at l.62). |
| F06-34 | MINOR | `customs_declaration46_screen.dart:603`, `:2041-2077` | Export header text is hard-coded English: `'Declaration 46: … — Import File:'`, `'Total Declarations'`, `'Generated At'`, `'Sorour Logistics ERP — Customs Clearance Follow-up'`. | l10n keys. |
| F06-35 | MINOR | `customs_declaration46_screen.dart:1462`, `customs_clearance_screen.dart:731` | Success-message keys are used as tooltips (`copyRegistryRowSuccess`, `copyCustomsClearanceTableSuccess`). | Use tooltip keys (`copyRowTooltip`, ...). |
| F06-36 | MINOR | `customs_declaration_46_dialog.dart:240-246` | `_isDirty` is always true when the number was auto-generated, so a close prompt appears with no user edit. | Fixed by FE06-T03 (no generator). |

---

## 3. Large tables

Common situation: every list in this phase loads **the whole set** in one GET (no paging params, except RFQs, which are cut
at 100). Search, status filter, KPIs and exports work on the loaded list only. There is no shared server-side paging widget.
`EnterpriseDataTable` (`core/widgets/enterprise_data_table/enterprise_data_table.dart`) pages, sorts and resizes columns,
but only client-side (`widget.data.length`, l.427). The only server-paged backend pattern is
`GET /import-files/paginated` → `PaginatedImportFilesResponse{items,total,page,page_size,total_pages}`
(`modules/import_files/schemas.py:374`).

| Screen / list | Today | Evidence | Recommendation |
|---|---|---|---|
| Clearance hub, follow-up tab (records) | `ListView.builder` of cards (lazy build: OK). Full list from `GET /customs-clearance` (no paging). Client search and status filter. Metrics and exports on the loaded list. No sort. No row count shown. | `customs_clearance_screen.dart:758-821`; `customs_clearance_provider.dart:69-81`; router `customs_clearance/router.py:59-68` | Phase A (FE only): debounced server search + status (F06-20), a "N records" chip, a sort selector (date / code / status). Phase B (backend): `GET /customs-clearance/paginated` with the import-files envelope, plus `CompactTablePaginationFooter` under the list. Exports call the API without paging to get the **full filtered set**. Cards stay (they suit the stage actions), but switch to a compact table at > 50 rows (`EnterpriseDataTable` with an actions column). |
| Declaration 46 registry | `DataTable` in `SingleChildScrollView(horizontal)` inside the page `SingleChildScrollView`: **all rows built**. The header scrolls away (no sticky header). Rows are fabricated from import files (F06-02). Assessment recomputed per file per keystroke. | `customs_declaration46_screen.dart:1272-1291, 1385-1578` | After FE06-T02, source = clearance records with a 46 number. Use `EnterpriseDataTable` (sticky header, paging 25/50/100, sort, column widths saved). Compute the estimate once per data change (memoise by `importFileId`). Debounce search 300 ms. Excel/PDF export of the full filtered set. |
| RFQ list (quotations) | `ListView.builder` of `RfqCard` (lazy). Each card has a nested horizontal `DataTable` of quotes (small). **Backend default limit 100 is silently applied.** Client search and status filter. | `customs_clearance_quotations_screen.dart:230-276`; provider `:19-34`; router `:39-58` | Immediate: FE06-T08 (fetch every page, or warn). Target: backend `/rfqs/paginated` + footer. Server-side `status`, `port_name`, `import_file_id`, and a new `search` param. |
| Clearance price list | `DataTable` in a vertical scroll, `width: infinity`, no horizontal scroll, all rows, no search, sort or paging. | `customs_clearance_quotations_screen.dart:523-595` | `EnterpriseDataTable` (client paging is fine, since price lists stay in the hundreds). Search by broker, port and category. Edit and delete actions (F06-12/13). |
| Regulatory approvals (per file) | `DataTable`, a few rows per file. | `customs_declaration46_screen.dart:982` | OK as is. |
| Import-file pickers (all CS dialogs, Decl 46) | `SearchableDropdownField` over the full `importFilesProvider` list. | `customs_declaration46_screen.dart:803-813` | OK up to a few thousand. Later, a server-search picker on `/import-files/paginated?search=` (shared need, all phases). |

Shared need (cross-phase, list it once in `review-shared-needs.md`): a `ServerPagedNotifier<T>` (page, pageSize, total,
search, filters) plus a server mode in `EnterpriseDataTable` (`totalCount`, `onPageChanged`, `onSortChanged`,
`onSearchChanged` callbacks). Without it every phase will hand-roll paging.

---

## 4. View / Show action

| Entity | View exists? | Why not (code reason) | What to add |
|---|---|---|---|
| Customs clearance record (hub card) | **No.** Card actions: edit, copy, clone, under-bond, pay, release, expenses (`clearance_card.dart:169-190`). | No details widget exists. The provider has no `getRecord(id)`, although the backend has `GET /customs-clearance/{id}` (`router.py:175-181`). The only "open" path is the edit dialog, which shows ~12 fields and is broken (F06-08). | `ClearanceDetailsDialog` (read-only, sections CS-01 broker / CS-02 D/O / CS-03 declaration / duties / payment / release), opened by a View icon (first action) and by tapping the card. It fetches `GET /customs-clearance/{id}` on open (live load) and has Copy + Print/PDF via `FileSaveHelper`. |
| Declaration 46 (registry row) | Partial: "view assessment" (`customsDeclViewAssessmentTooltip`, l.1453-1458) shows the **computed tariff estimate**, not a stored declaration. | No declaration is ever stored from this screen (F06-01), so there is nothing to view. | After FE06-T01/T02, the View action opens `ClearanceDetailsDialog` on the declaration section. Keep "assessment" as a second action named "Tariff estimate". |
| Broker RFQ | Inline only: the card shows the port, shipment, HS, weight, CBM and a quotes table. | No details screen. The linked import file, commodity and notes are not shown, and the provider has no GET-by-id (backend `GET /rfqs/{id}` exists, `router.py:70`). | A View icon on `RfqCard` → read-only dialog with the full RFQ (linked file code and title, commodity, notes, award notes, created at/by) and each quote's remarks, validity and currency. |
| Clearance quote (line) | No. Remarks, validity and currency are never shown. | Not in the quotes `DataTable` columns (`rfq_card.dart:221-231`). | A row tap or info icon → quote details popover. Add a "Validity" column. |
| Price-list item | No (notes column only). There is no edit either. | `updatePriceItem` is unused. | An Edit dialog (reuse the add dialog with initial values). View is not needed (all fields fit in the row). |
| D/O and broker authorization | No: stored only inside the clearance record. | Same as the clearance record. | Covered by `ClearanceDetailsDialog` sections. |

---

## 5. Tasks

Order = priority. Every task: Arabic UI text through l10n keys added **only** inside the
`// === review phase06_07 keys ... ===` block in `frontend/lib/core/localization/app_localizations.dart`,
`app_localizations_ar.dart` and `app_localizations_en.dart` (prefix `cc` / `ccq` / `customsDecl`). Colors only from `AppTheme`.
Errors through `ApiErrorText.of(l, e)` in an `AppTheme.snackBar(..., severity: AppSeverity.danger)`. Run
`flutter test` for the touched test files plus `flutter analyze` on the touched files before you finish.

### FE06-T01: Declaration 46 screen saves for real

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** none | **Backend needed:** no (uses `POST /customs-clearance/register-declaration-46`, schema `CustomsDeclaration46Submit` in `modules/customs_clearance/schemas.py:98-108`)
- **Files to change:** `frontend/lib/features/import_documentation/screens/customs_declaration46_screen.dart`, l10n files (block above), `frontend/test/customs_declaration46_test.dart`
- **Steps:**
  1. In `_saveDeclaration46` (l.2083) delete `Future.delayed`. Build the payload `{import_file_id, declaration_46_no, declaration_46_date (ISO from the picked date), customs_office_name, channel_type, regulatory_bodies: [], mts_certificate_number: null, customs_tariff_items_count: max(1, _matchedTariffs.length), inspection_notes: _notesCtrl.text or null}`. Use the office code from FE06-T13 if it is merged, else `'Alexandria Port Customs'` **only as the backend default is today**. Add an Office field (SearchableDropdownField) and a Channel field like the CS-03 dialog.
  2. `await ref.read(customsClearanceProvider.notifier).registerDeclaration46(payload)` inside try/catch. On success: success SnackBar, `ref.invalidate(importFilesProvider)`, switch to tab 1. On error: danger SnackBar, stay on the form, `_isSavingDeclaration=false` in `finally`.
  3. `_declaration46NoCtrl` starts empty (l.134). On file select (l.281) set it to `file.form46No ?? ''`, never `'46-ALX-…'`.
  4. Replace the free-text submission date (l.143, 838-844) with a read-only field + `showDatePicker` (first: today-365, last: today+30). Required validator.
- **Acceptance criteria:**
  - [ ] Saving with a file and a number creates or updates the clearance record. It appears in the hub (index 27) with that 46 number.
  - [ ] A backend error (e.g. expired ACID) shows the Arabic backend message, and the form keeps the values.
  - [ ] Selecting a file with no stored 46 number leaves the field empty, and saving with it empty shows the red required message.
  - [ ] The date can only be picked, not typed.
- **Tests to add:** `frontend/test/customs_declaration46_test.dart`: override `customsClearanceProvider` with a fake notifier recording `registerDeclaration46` calls. Assert one call with the typed number and `import_file_id`. Assert no call when the number is empty. Assert the error SnackBar text on a thrown `DioException`. Update the existing expectation at l.308 (`'46-ALX-FILE-2026-007'`).
- **Out of scope:** registry rework (T02), figures panel math.

### FE06-T02: Declaration 46 registry shows real declarations

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** FE06-T01 | **Backend needed:** no (optional later: `has_declaration` filter, §6)
- **Files to change:** `customs_declaration46_screen.dart`, l10n files, `frontend/test/customs_declaration46_test.dart`
- **Steps:**
  1. In `_buildDeclarationRegistryView` (l.1262), the source becomes `ref.watch(customsClearanceProvider)` records where `declaration46No` is not empty. Join the import file by `importFileId` from `importFilesProvider` for the code, title and supplier.
  2. Columns: Actions, Declaration no. (`declaration46No`), Import file code, Supplier, Declaration date (`declaration46Date`, `—` if null), Office, Channel (via `CcUi.channelStyle`), Status (via `CcUi.statusStyle`), Tariff estimate (from `_calculateAssessment`, labelled "estimate").
  3. Remove `declNo = '46-ALX-…'`, `registrationDate: DateTime.now()` and the fixed status from `_calculateAssessment` (l.1128, 1243-1244). Keep the method only for the estimate figures and for clone.
  4. KPIs: count = number of real declarations. Total duties = sum of `record.effectiveDutyTotal` (stored), not estimates. The estimate total is a separate KPI labelled as estimate.
  5. Memoise the estimates: compute a `Map<int importFileId, CustomsDeclarationAssessment>` only when the input lists change (store it in state with a hash of list lengths and identities), not in `build` per keystroke. Debounce search 300 ms.
  6. Empty state: "No registered declarations yet" + a button to the form tab.
  7. Make Excel/PDF/TSV exports (l.1979-2081) use the new rows. l10n the hard-coded metadata strings (F06-34).
- **Acceptance criteria:**
  - [ ] With 0 clearance records, the registry is empty (not one row per import file).
  - [ ] After saving a declaration in T01, it appears with the typed number, the picked date and the backend status.
  - [ ] Typing in search does not freeze with 1,000 import files (no per-keystroke recompute).
- **Tests to add:** `frontend/test/customs_declaration46_test.dart`: given 3 import files and 1 clearance record with `declaration_46_no='46-X-1'`, the registry shows exactly 1 row with `46-X-1`. No text matches `46-ALX-`.
- **Out of scope:** server paging (T18), view dialog (T09 provides it; wire it here only if T09 is merged).

### FE06-T03: Stop inventing references and money in CS-01 / CS-02 / CS-03 dialogs

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_broker_authorization_dialog.dart`, `delivery_order_payment_dialog.dart`, `customs_declaration_46_dialog.dart`, `frontend/test/cs01_customs_broker_authorization_test.dart`, `frontend/test/cs03_customs_declaration_46_test.dart`
- **Steps:**
  1. Broker dialog: delete `_generateDelegationNumber` (l.99-115), its call in `initState` (l.73-75), the auto-fix `IconButton` (l.305-309) and `import 'dart:math'`. The field starts from `file.customsBrokerDelegationNo ?? ''`.
  2. Declaration dialog: delete `_generateDeclaration46Number` (l.144-166), the call (l.114-116), the `generateDeclaration46Btn` button (l.325-330) and `dart:math`. `_tariffCountController` stays `'1'` (the backend minimum). Fix `_isDirty` (l.240-246) to compare against the initial values.
  3. D/O dialog: delete `_generateDONumber` (l.98-111) and its call. `_feesController` starts **empty** (l.69). Add a validator: required, a number, >= 0. Keep `_freeDaysAllowed` from `file.targetFreeDays`, else **empty and required** (no 14 default): change the field to a required int.
  4. Remove unused l10n keys only if nothing else references them (grep `ccDecGenerate`, `ccBrkGenerateTooltip`).
- **Acceptance criteria:**
  - [ ] Opening each dialog for a file without stored numbers shows empty number fields. Confirm shows the red required errors and sends nothing.
  - [ ] The D/O fee field is empty, and confirm without a fee is blocked.
  - [ ] Stored numbers (`form46No`, `deliveryOrderNo`, `customsBrokerDelegationNo`) still prefill.
- **Tests to add:** widget tests in `frontend/test/cs01_customs_broker_authorization_test.dart` and `frontend/test/cs03_customs_declaration_46_test.dart`: pump the dialog with an `ImportFileModel` having null numbers, `expect(find.textContaining('DEL-'), findsNothing)`, `find.textContaining('46-20')` and `MTS-` findsNothing. New `frontend/test/features/customs_clearance/delivery_order_dialog_test.dart`: the fee field text is `''`, and tapping confirm shows the validator error.
- **Out of scope:** office list (T13), currency list (T14).

### FE06-T04: Pick the shipment before a stage dialog opens, and add per-record stage actions

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `customs_clearance/screens/customs_clearance_screen.dart`, `customs_clearance/widgets/clearance_card.dart`, new `customs_clearance/widgets/import_file_picker_dialog.dart`, l10n files, new test `frontend/test/features/customs_clearance/stage_file_picker_test.dart`
- **Steps:**
  1. New `Future<ImportFileModel?> showImportFilePickerDialog(BuildContext, WidgetRef, {required String title})`: an `AlertDialog` with a `SearchableDropdownField<int>` over `importFilesProvider` (label `primaryNameWithCode — supplierName`, required) and Cancel / Continue.
  2. `_openStage` (l.426-441): if `widget.initialImportFileId != null` and found → use it. Else `await showImportFilePickerDialog(...)` and return on null. Remove the `files.first` fallbacks (l.435-439).
  3. `_loadClearanceGuide` (l.101-108): when `fileId == null`, set the result to null (no `files.first`).
  4. `ClearanceCardActions`: add `onBrokerAuth`, `onDeliveryOrder`, `onDeclaration46` (icons as in the header: `assignment_ind_rounded`, `directions_boat_filled_rounded`, `description_rounded`). The screen resolves the file by `record.importFileId` and opens the matching dialog. If the file is not found, show a warning SnackBar.
- **Acceptance criteria:**
  - [ ] From the sidebar, clicking "Broker authorization" first asks which shipment. Cancel opens nothing.
  - [ ] From a card, CS-01/02/03 open directly for that card's shipment (the file chip in the dialog header matches the card).
  - [ ] With `initialImportFileId` set (opened from the lifecycle), no picker appears.
- **Tests to add:** `stage_file_picker_test.dart`: pump `CustomsClearanceScreen` with 2 fake files and no `initialImportFileId`, tap `authorizeCustomsBrokerHeaderBtn`, expect the picker dialog and no `CustomsBrokerAuthorizationDialog` yet. Pick file 2 and expect the dialog chip with file 2's name.
- **Out of scope:** the Phase-07 stage buttons' internal logic (they get the same picker for free).

### FE06-T05: Edit a clearance record with PUT, clone only to another shipment

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no (`PUT /customs-clearance/{record_id}`, `CustomsClearanceUpdate`; after the previous wave CL-04, workflow and derived fields are ignored)
- **Files to change:** `customs_clearance/providers/customs_clearance_provider.dart`, `customs_clearance/widgets/clearance_screen_dialogs.dart`, l10n files, `frontend/test/customs_clearance_test.dart`
- **Steps:**
  1. Provider: `Future<CustomsClearanceModel> updateRecord(int id, Map<String, dynamic> payload)` → `_dio.put('/customs-clearance/$id')`, then `_invalidateRelated(); await refresh();`.
  2. `ClearanceFormDialog._save` (l.134-180): when `recordToEdit != null && !isCloneDraft`, call `updateRecord(recordToEdit.customsClearanceId, payload)`. Do **not** send `import_file_id` or `total_duty_payable`. Add fields `development_fee_amount` and `customs_service_fees` (number, >= 0) and send them.
  3. Create and clone: keep `createRecord` and drop `total_duty_payable` from the payload (the server computes it). Clone: the import-file field is required and must differ from the source (`validator: v == source.importFileId ? l.ccCloneSameFileError : null`). Exclude files that already have an active record (from the loaded records) from the dropdown.
  4. Number fields: validators (a number, >= 0). Empty becomes an error, not a silent 0.
- **Acceptance criteria:**
  - [ ] Editing the customs office of an existing record saves, and the card shows the new office (no "already exists" error).
  - [ ] Cloning to the same shipment is blocked in the form. Cloning to another shipment creates a new record.
  - [ ] Dev fee and service fee are editable and kept after save.
- **Tests to add:** `frontend/test/customs_clearance_test.dart`: with a fake Dio adapter (or a fake notifier), edit mode calls `updateRecord` (PUT) with no `import_file_id` key, and create mode calls `createRecord`.
- **Out of scope:** changing which fields the backend accepts.

### FE06-T06: No invented values in RFQ, quote and price-item dialogs; add currency and validity

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no (`currency`, `validity_date` already in the quote API; check `CustomsClearanceQuotationCreate` in `modules/customs_clearance_quotations/schemas.py` before sending)
- **Files to change:** `customs_clearance_quotations/widgets/quotation_dialogs.dart`, `customs_clearance_quotations/models/customs_clearance_quotation_model.dart` (only if `toJson` needs `currency`), l10n files, `frontend/test/features/customs_clearance_quotations/customs_clearance_quotation_model_test.dart`
- **Steps:**
  1. `showCreateRfqDialog` (l.90-130): `grossWeightCtrl` and `cbmCtrl` start empty, with validators (a number, > 0). `portName` = `initialPortName`, else the selected file's `portOfDischarge`, else **null** with a required validator. Remove the `'Alexandria Port'` literal (l.109). `shipmentType`: required, no default.
  2. `showAddQuotationDialog` (l.300-311): fee controllers start from `prefill` or `''`. Validators: a number, >= 0. `daysCtrl`: required int >= 0. Add a Currency `SearchableDropdownField<String>` from `currenciesProvider` (required) and a Validity date picker (optional). Pass `currency` and `validityDate` to the model.
  3. `showAddPriceItemDialog` (l.475-636): `priceCtrl` starts empty (l.486), a Currency dropdown replaces `currency: 'EGP'` (l.615), and the port has no `'Alexandria Port'` fallback (l.483).
  4. Do not send `totalCost` as a business value (the server recomputes it, CCQ-05). Keep it only for the live preview.
- **Acceptance criteria:**
  - [ ] All three dialogs open with empty money and quantity fields. Saving empty shows red validator messages.
  - [ ] A quote saved in USD shows "USD" in the quotes table and the export.
- **Tests to add:** `customs_clearance_quotation_model_test.dart`: `toJson` contains `currency` and `validity_date` when set. New widget test `frontend/test/features/customs_clearance_quotations/quotation_dialogs_test.dart`: open the add-quote dialog with no prefill and expect no `'3000'`/`'6000'` text.
- **Out of scope:** the sample texts in `quotation_sample_texts.dart` (a demo feature, kept).

### FE06-T07: Smart extractor must not attach a quote to a random RFQ

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart`, l10n files, `frontend/test/customs_clearance_quotations_screen_test.dart`
- **Steps:**
  1. In `_showSmartExtractorDialog` `onExtracted` (l.603-611): if `targetRfqId == null`, open a small dialog "Attach to which RFQ?" with a `SearchableDropdownField<int>` of non-cancelled RFQs (label `rfqCode — title — portName`) plus a "Create new RFQ" button. Remove `rfqs.first`.
  2. Then call `showAddQuotationDialog(context, ref, pickedId, prefill: extracted)`.
- **Acceptance criteria:**
  - [ ] Extracting from the toolbar always asks for the RFQ. Cancelling saves nothing.
  - [ ] Extracting from a card's "smart extract" still goes straight to that RFQ.
- **Tests to add:** `customs_clearance_quotations_screen_test.dart`: simulate `onExtracted` with `targetRfqId=null` and 2 RFQs, and expect the picker dialog, not the add-quote dialog.
- **Out of scope:** extractor parsing.

### FE06-T08: RFQ list is not silently cut at 100

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no for the interim fix. Yes for the target: `GET /customs-clearance-quotations/rfqs/paginated` (§6)
- **Files to change:** `customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart`, `frontend/test/customs_clearance_quotations_test.dart`
- **Steps:**
  1. `fetchRFQs`: loop `skip = 0; limit = 500;` request with `skip` and `limit`, append the results, stop when a page has fewer than `limit` rows (hard cap 20 pages, then stop and set a flag `isTruncated`).
  2. Keep the previous data while loading (F06-33): set `AsyncValue.loading()` only when there is no data yet.
  3. Pass the status, port and file filters from the screen to the provider (server-side) when they change.
- **Acceptance criteria:**
  - [ ] With 150 RFQs in the DB, the metric "RFQs" shows 150.
  - [ ] After adding a quote, the list does not flash to a spinner.
- **Tests to add:** `customs_clearance_quotations_test.dart`: a fake Dio returning 500 then 10 items, and expect 510 RFQs and 2 requests with `skip` 0 and 500.
- **Out of scope:** UI pager (T18).

### FE06-T09: Read-only clearance details (View / عرض)

- **Severity:** MAJOR | **Type:** feature | **Depends on:** none | **Backend needed:** no (`GET /customs-clearance/{id}`)
- **Files to change:** `customs_clearance/providers/customs_clearance_provider.dart`, new `customs_clearance/widgets/clearance_details_dialog.dart`, `customs_clearance/widgets/clearance_card.dart`, `customs_clearance/screens/customs_clearance_screen.dart`, l10n files
- **Steps:**
  1. Provider: `Future<CustomsClearanceModel> getRecord(int id)` → GET `/customs-clearance/$id` (no state change).
  2. `ClearanceDetailsDialog(recordId)`: `FutureBuilder` on `getRecord` (fresh data on open). Read-only sections with `CcFact` rows. **CS-01** broker name, delegation no., delegation date, mandate letter code, delegation status, notes. **CS-02** D/O no., date, expiry, free days, shipping agent, fees + currency, payment ref, paid at, status. **CS-03** 46 no., date, office, channel chip, MTS no., tariff item count, regulatory bodies, notes. Then duties (components + total), payment, release. Shipment shown as `importFileCode` + title (resolved by id). Dates via `CcFormat.date`, money via `CcMoneyText` (LTR digits, RTL layout). Footer: Copy all (TSV), Close.
  3. `ClearanceCardActions.onView`, shown as the **first** icon (`Icons.visibility_outlined`, tooltip l10n "View"). Tapping the card body also opens View.
- **Acceptance criteria:**
  - [ ] Every card has a View icon left of Edit (RTL: right of Edit). It opens a read-only dialog with the Phase-06 data the user entered.
  - [ ] Empty values show "—". No DB id is shown.
  - [ ] A load error shows the Arabic backend message inside the dialog with Retry.
- **Tests to add:** new `frontend/test/features/customs_clearance/clearance_details_dialog_test.dart`: a fake notifier returns a record with `delegation_number='D-1'`, `delivery_order_number='DO-1'`, `declaration_46_no='46-1'`, and expect all three texts and no `TextFormField`.
- **Out of scope:** printing a PDF of the details (later).

### FE06-T10: Correct shipment code, Phase-06 statuses and server-side search on the hub

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `customs_clearance/widgets/clearance_card.dart`, `customs_clearance/screens/customs_clearance_screen.dart`, `customs_clearance/widgets/customs_ui.dart`, l10n files, `frontend/test/customs_clearance_test.dart`
- **Steps:**
  1. Card (l.45-50, 99) and `_tableRow` (l.284-286): find the file by `importFileId` and show `file.importFileCode` and `DisplayNameResolver.resolveShipmentTitle(file, isArabic:)`. Show "—" when it is not found. Never `'IMP-$id'`.
  2. `CcUi.statusStyle`: add `'Broker Authorized - Ready for 46'`, `'D/O Received - Ready for 46'`, `'Under Customs Clearance'`, `'Inspection & Sampling Recorded'`, `'Customs Duties Assessed - Ready for Payment'`, `'Duty Paid - Ready for Final Release'`, `'Under Bond Released'`, `'Lab Non-Conforming - Rejected'` with l10n labels and severities.
  3. Status filter (l.693-700): build the items from that same map (+ All).
  4. Search: a `Timer` debounce 400 ms → `ref.read(customsClearanceProvider.notifier).fetchRecords(search: q, status: s == 'All' ? null : s)`. Keep the local filter for instant feedback.
  5. Add a chip "N records" in the toolbar.
- **Acceptance criteria:**
  - [ ] The card shows `IMP-2026-0007` (the real code), not `IMP-7`.
  - [ ] A record after CS-01 shows an Arabic status chip, and filtering by "Broker authorized" lists it.
- **Tests to add:** `customs_clearance_test.dart`: a record with `importFileId: 7` and a file with code `IMP-2026-0007`; expect the `IMP-2026-0007` text and not `IMP-7`. Expect the Arabic label for `'Broker Authorized - Ready for 46'` under the `ar` locale.
- **Out of scope:** server paging (T18).

### FE06-T11: Delete, restore and show deleted clearance records

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T09 (card action list) | **Backend needed:** no (`DELETE /customs-clearance/{id}` is soft, `PATCH /{id}/restore`)
- **Files to change:** `clearance_card.dart`, `customs_clearance_screen.dart`, l10n files, `frontend/test/customs_clearance_test.dart`
- **Steps:**
  1. Card: a Delete icon (`AppTheme.crimson`) → confirm dialog naming the clearance code → `softDeleteRecord` → SnackBar. When `!record.isActive`: show a "Deleted" chip, hide the stage actions, show Restore.
  2. Toolbar: a switch "Show deleted" → `fetchRecords(includeInactive: value)`.
  3. Errors (409 duplicate on restore, from the previous wave CL-16) → `ApiErrorText` SnackBar.
- **Acceptance criteria:**
  - [ ] Delete asks for confirmation. The record leaves the list and comes back with "Show deleted" + Restore.
- **Tests to add:** widget test: tap delete → confirm → the fake notifier's `softDeleteRecord` is called once with the record id.
- **Out of scope:** hard delete (forbidden).

### FE06-T12: RFQ edit/cancel/delete, price-item edit, safe deletes

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T06 (dialog fields) | **Backend needed:** no (`PUT/DELETE /rfqs/{id}`, `PUT /price-list/{id}`. RFQ status values `Draft / Quotations Received / Awarded / Cancelled`)
- **Files to change:** `customs_clearance_quotations/widgets/rfq_card.dart`, `customs_clearance_quotations/widgets/quotation_dialogs.dart`, `customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart`, l10n files
- **Steps:**
  1. `RfqCard`: add a header menu with View (T09-like read-only dialog for RFQ + quotes, incl. remarks, validity and currency), Edit (reuse `showCreateRfqDialog` with initial values → `updateRFQ`), Cancel (confirm → `updateRFQ(id, {'status': 'Cancelled'})`) and Delete (confirm → `deleteRFQ`). Hide Edit/Cancel when the status is Awarded.
  2. Hide the quote delete icon when `q.isAwarded` (l.285-289).
  3. Price list (l.565-570): Delete → confirm + try/catch SnackBar. Add an Edit icon → the add dialog prefilled → `updatePriceItem`.
  4. Status filter: add `Cancelled`.
- **Acceptance criteria:**
  - [ ] An RFQ can be edited, cancelled and deleted from its card with confirmation. Errors show the Arabic message.
  - [ ] Deleting a price item asks first. A failure shows a red SnackBar, not a crash.
- **Tests to add:** extend `frontend/test/customs_clearance_quotations_screen_test.dart`: the card menu has 4 entries for a Draft RFQ and no Edit/Cancel for Awarded. The price-row delete opens a confirm dialog.
- **Out of scope:** quote edit (backend `PUT /quotations/{id}` exists. A later task).

### FE06-T13: One customs-office list, and partner-role helper

- **Severity:** MAJOR | **Type:** refactor | **Depends on:** FE06-T03 | **Backend needed:** no (a master table is Q1)
- **Files to change:** `customs_clearance/widgets/customs_ui.dart`, `customs_broker_authorization_dialog.dart`, `customs_declaration_46_dialog.dart`, `delivery_order_payment_dialog.dart`, new `frontend/lib/features/external_service_providers/utils/partner_roles.dart`
- **Steps:**
  1. In `customs_ui.dart`: `const kCustomsOffices = <String>[…]`, the 9 English values of the CS-03 list (stored values), with `CcUi.officeLabel(l, code)` mapping to `ccDecOffice0..8`. Add `CcUi.officeForPort(String? pod)`, which matches on English tokens of the port **code/name** only (no Arabic substrings).
  2. Both dialogs use `kCustomsOffices`. A stored value not in the list is added as an extra item (legacy).
  3. `PartnerRoles.isCustomsBroker(p)` / `isShippingAgent(p)` over `p.categoriesList`, compared case-insensitively against `{'Customs Broker','Customs Clearance'}` / `{'Shipping Line','Shipping Agent'}` plus the legacy Arabic values in one map. Replace the 4 inline filters (F06-17). No fallback to all partners.
- **Acceptance criteria:**
  - [ ] The broker and declaration dialogs show the same office list in Arabic labels and store the same English values.
  - [ ] The D/O agent dropdown shows only shipping lines/agents, with an empty-state hint if none exist.
- **Tests to add:** `frontend/test/features/external_service_providers/partner_roles_test.dart`: the type `'مستخلص جمركي'` → broker true, `'Bank'` → false.
- **Out of scope:** the clearance edit form office field (switch it in T05 if T13 is merged first).

### FE06-T14: D/O currency from master data and a real payment date

- **Severity:** MAJOR | **Type:** bug | **Depends on:** FE06-T03 | **Backend needed:** no
- **Files to change:** `delivery_order_payment_dialog.dart`, l10n files, `frontend/test/features/customs_clearance/delivery_order_dialog_test.dart`
- **Steps:**
  1. Replace `_currencies` (l.60) with `ref.watch(currenciesProvider)` codes (load on open if empty). Default = the stored `delivery_order_currency` or none (required).
  2. Add a "Paid at" date picker. Send `delivery_order_paid_at` from it (l.148). Required when a payment ref is filled.
- **Acceptance criteria:**
  - [ ] The currency list equals the Currencies master. The paid date can differ from the D/O date.
- **Tests to add:** the payload captured by a fake notifier has `delivery_order_paid_at` equal to the picked paid date, not the D/O date.
- **Out of scope:** FX conversion of D/O fees (backend, previous plan §4).

### FE06-T15: Quotations exports through FileSaveHelper with the naming rule

- **Severity:** MAJOR | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `customs_clearance_quotations/services/customs_clearance_quotations_export_service.dart`, `frontend/test/customs_export_service_test.dart` (or a new test)
- **Steps:**
  1. Replace `FileSaveHelper.saveText(... defaultFileName: 'clearance_rfqs_<ms>.tsv')` (l.91, 182, 522, 565) and `Printing.layoutPdf` (l.405, 661) with `FileSaveHelper.exportAndSaveFile` (see its use in `core/services/table_export_service.dart:125, 407`).
  2. File name: `Customs Clearance RFQs - <importFileCode or 'Registry'>.<ext>` and `Customs Clearance Price List - Registry.<ext>`.
- **Acceptance criteria:**
  - [ ] Every export opens Save-As with the rule's file name. Nothing is printed or saved silently.
- **Tests to add:** a unit test on the file-name builder function (extract it as `static String fileName(...)`).
- **Out of scope:** PDF layout.

### FE06-T16: Use the awarded broker in CS-01, and make quotations reachable

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T04 | **Backend needed:** no
- **Files to change:** `customs_broker_authorization_dialog.dart`, `frontend/lib/features/home/home_screen.dart`, `frontend/lib/core/providers/navigation_provider.dart`, l10n files
- **Steps:**
  1. In the CS-01 `initState`: if `file.brokerId == null`, call `customsClearanceQuotationsProvider.notifier.fetchRFQs(importFileId: file.importFileId)`. Then, if an RFQ has `status == 'Awarded'`, preselect `awardedProviderId` and show an info chip "Awarded in RFQ <code>".
  2. Sidebar group "5. Port & Clearance" (`home_screen.dart:958-962`): add the item "Broker clearance quotations" → a new index (append at the end of `_screens`, update `_totalScreens` and the index comment in `navigation_provider.dart`, and add a live-load case calling `fetchRFQs()` and `fetchPriceList()`). The screen = `CustomsClearanceQuotationsScreen()` (not embedded).
- **Acceptance criteria:**
  - [ ] For a file whose clearance RFQ is awarded, CS-01 opens with that broker selected.
  - [ ] The quotations screen opens from the Port & Clearance sidebar group.
- **Tests to add:** widget test with a fake quotations notifier returning an awarded RFQ for file 1: the broker dropdown value equals the awarded provider id.
- **Out of scope:** writing the award to the import file on the backend (§6).

### FE06-T17: BP-026 readiness panel before broker authorization

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T04 | **Backend needed:** no (optional later: one `GET /import-files/{id}/clearance-readiness`)
- **Files to change:** new `customs_clearance/widgets/clearance_readiness_panel.dart`, `customs_broker_authorization_dialog.dart`, l10n files, new test
- **Steps:**
  1. A panel with 4 rows (OK / warning / missing): (a) ACID number present and `acidExpiryDate` >= today. (b) Insurance certificate exists in `cargoInsuranceProvider` for the file **when** `file.incotermCode` is FOB/CFR/CPT/FCA/EXW. (c) The invoice ↔ B/L match session exists and is matched (`invoiceBLMatchSessionsProvider`). (d) The D/O number is recorded. Each row shows a short Arabic reason.
  2. Show it at the top of the CS-01 dialog. **It warns only** and does not block confirm (Q3).
- **Acceptance criteria:**
  - [ ] For a FOB file without insurance, the panel shows a red "insurance missing" row. For a CIF file the row is "not required".
- **Tests to add:** `frontend/test/features/customs_clearance/clearance_readiness_panel_test.dart`: pure function `computeReadiness(file, insurances, matches)` cases for FOB/CIF and expired ACID.
- **Out of scope:** blocking rules.

### FE06-T18: Large tables on Phase-06 lists

- **Severity:** MAJOR | **Type:** ux | **Depends on:** FE06-T02, FE06-T12. Backend paging for steps 3-4 | **Backend needed:** yes for steps 3-4: `/customs-clearance/paginated` and `/customs-clearance-quotations/rfqs/paginated` (§6)
- **Files to change:** `customs_clearance_quotations_screen.dart` (price list), `customs_declaration46_screen.dart` (registry), `customs_clearance_screen.dart`, `customs_clearance_provider.dart`
- **Steps:**
  1. Price list: replace the `DataTable` (l.523-595) with `EnterpriseDataTable<ClearancePriceListItemModel>` (`storageKey: 'ccq_price_list'`, columns broker, port, category, container, rate (numeric, LTR), notes, an actions column; search over broker, port and category; page size 50).
  2. Declaration 46 registry: the same, `storageKey: 'decl46_registry'`.
  3. (backend ready) Hub: a paged notifier (`page`, `pageSize=50`, `total`) + `CompactTablePaginationFooter` under the `ListView.builder`. Search and status go to the server. Exports fetch all filtered rows (no paging) before writing.
  4. (backend ready) RFQs: the same with `/rfqs/paginated`.
- **Acceptance criteria:**
  - [ ] The price list scrolls horizontally on a 1024 px window, with a sticky header and sortable columns.
  - [ ] With 5,000 clearance records, the hub opens in < 1 s and shows "1-50 of 5,000".
- **Tests to add:** widget test: the price list with 120 items shows a pagination footer and 50 rows on page 1.
- **Out of scope:** the shared server-mode `EnterpriseDataTable` (cross-phase shared need, own task).

### FE06-T19: Hygiene

- **Severity:** MINOR | **Type:** refactor | **Depends on:** none | **Backend needed:** no
- **Files to change:** `clearance_card.dart`, `rfq_card.dart`, `customs_clearance_quotations_provider.dart`, `customs_declaration46_screen.dart`, `customs_clearance_screen.dart`
- **Steps:** (1) Replace the variance threshold `500` (`clearance_card.dart:57`) with a named constant `kDutyVarianceWarnEgp` in `customs_ui.dart` (Q4). (2) Show the currency of the cheapest quote in "lowest cost" (`rfq_card.dart`). (3) Keep the previous data while refetching in both quotation notifiers (l.24, 139). (4) l10n for the hard-coded export strings (`customs_declaration46_screen.dart:603, 2041-2077`). (5) Use tooltip keys instead of success-message keys (`customs_declaration46_screen.dart:1462`, `customs_clearance_screen.dart:731`).
- **Acceptance criteria:** [ ] No English literals in the Arabic PDF header. [ ] Tooltips read as actions, not "copied successfully".
- **Tests to add:** extend `frontend/test/customs_declaration46_localization_test.dart` for the new keys (ar/en non-empty).
- **Out of scope:** anything else.

---

## 6. Backend dependencies (short)

1. **Paging:** `GET /customs-clearance/paginated` and `GET /customs-clearance-quotations/rfqs/paginated` returning
   `{items,total,page,page_size,total_pages}` (same as `PaginatedImportFilesResponse`), with `search` + `status` server-side.
   Today the RFQ list silently caps at `limit=100` (`customs_clearance_quotations/router.py:42`).
2. `CustomsClearanceResponse` has no `import_file_code`. The FE can resolve it by id (T10), but adding the code to the
   response avoids loading every import file just to label the cards.
3. Optional `has_declaration=true` filter on `GET /customs-clearance` for the Declaration 46 registry (T02).
4. Awarding a clearance RFQ does not write the broker to the import file (`service.py` award path). The FE preselects it
   (T16), but a backend link (`import_file.broker_id` on award, if empty) would keep it consistent.
5. Defaults that invent data on the backend side too: `customs_office_name="Alexandria Port Customs"` and
   `channel_type="Red Channel"` (`schemas.py:77, 102-103`), `free_days_allowed=14` (`:87`). After T03/T13 the FE always
   sends explicit values, so these defaults should become required fields.
6. Customs offices master data (Q1) if the CTO wants a table instead of a constant list.

## 7. Open questions for the CTO

- **Q1:** Customs offices: a constant code list in the app (T13), or a master table (`customs_offices`, linked to ports)? [Constant list now.]
- **Q2:** Must the channel (red/yellow/green) be chosen at declaration registration, or is it set later when customs
  assigns it? Today it defaults to Red. [Keep it selectable, no default, required.]
- **Q3:** Should the BP-026 readiness panel **block** broker authorization when insurance or ACID is missing, or only warn? [Warn only.]
- **Q4:** What duty variance should flag a record (fixed EGP amount or %)? [Keep 500 EGP as a named constant until decided.]
- **Q5:** Phase naming: the sidebar shows "5. Port & Clearance" and the screens use `stageCode: 'PHASE-5'`, while the
  business docs call this Phase 6. Should the UI follow the docs numbering? [Not in this wave.]
- **Q6:** Is the stand-alone Declaration 46 screen (sidebar index 23) still wanted, or should the sidebar point to the hub's CS-03 dialog only? [Keep it, fixed by T01/T02.]
