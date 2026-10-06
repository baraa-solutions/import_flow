# Phase 04 Freight booking: frontend review

Status: 2026-10-05, static review only (no flutter test, no pytest, no `import main`, no code edited).
Scope: BP-017 (select provider), BP-018 (booking draft), BP-019 (confirmation, vessel, ETD/ETA, departure / B/L) and the cargo
insurance certificates screen that lives next to the booking. Screens are reached by index in `core/providers/navigation_provider.dart`
(`25 = FreightBookingScreen`, `65 = CargoInsuranceScreen`), from `home_screen.dart:142,224`, from
`import_files/widgets/import_file_details_dialog.dart:686` (booking filtered by file) and embedded in
`import_documentation/screens/shipment_draft_docs_screen.dart:332` (insurance filtered by file).
Previous plan: `docs/plans/phase-04-05-quality-plan.md` (FE-04, FE-07, FE-08, FE-10, FE-11 relevant here).

Coverage depth:

| file | lines | depth |
|---|---|---|
| `frontend/lib/features/freight_booking/screens/freight_booking_screen.dart` | 615 | full |
| `frontend/lib/features/freight_booking/providers/freight_booking_provider.dart` | 146 | full |
| `frontend/lib/features/freight_booking/models/freight_booking_model.dart` | 351 | full |
| `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart` | 1428 | full |
| `.../widgets/freight_booking_confirm_dialog.dart` | 237 | full |
| `.../widgets/departure_confirmation_dialog.dart` | 351 | full |
| `.../widgets/freight_booking_registry_row.dart` | 323 | full |
| `.../widgets/freight_booking_toolbar.dart` | 166 | full |
| `.../widgets/freight_booking_view_dialog.dart` | 227 | full |
| `.../widgets/freight_booking_print_dialog.dart` | 163 | full |
| `.../widgets/search_and_clone_freight_booking_dialog.dart` | 258 | full |
| `.../widgets/freight_booking_ui.dart` | 453 | partial (status / snack / format helpers) |
| `.../widgets/freight_booking_cost_row.dart` | 150 | grep (currency list, rate field) |
| `.../widgets/freight_booking_prompts.dart`, `freight_booking_quote_card.dart` | 317 | not read (called only) |
| `frontend/lib/features/cargo_insurance/screens/cargo_insurance_screen.dart` | 641 | full |
| `frontend/lib/features/cargo_insurance/providers/cargo_insurance_provider.dart` | 176 | full |
| `frontend/lib/features/cargo_insurance/models/cargo_insurance_model.dart` | 269 | full |
| `.../widgets/insurance_certificates_table.dart` | 343 | full |
| `.../widgets/insurance_details_dialog.dart` | 238 | full |
| `.../widgets/insurance_form_dialog.dart` | 984 | ~70% (state, init, auto-fill, payload, field list; layout grepped) |
| `.../services/cargo_insurance_export_service.dart` | 532 | grep + save paths read |
| `modules/freight_booking/{router,schemas,repository,validators}.py` | 488 | full |
| `modules/freight_booking/service.py` | 671 | cost engine + create/update/confirm/depart/delete/restore read |
| `modules/cargo_insurance/{router,schemas}.py`, `repository.py` list, `validators.py` | ~500 | full / grep |
| `.claude/skills/ui-screen-standards/SKILL.md` | - | grep (sticky header, exports, actions) |

---

## 1. Summary

| severity | count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 7 |
| MAJOR | 23 |
| MINOR | 6 |

Most important points:
1. **Wrong freight money (BLOCKER).** The booking form sends `Sea Freight 40ft` and `Sea Freight 20ft` with `unit: 'Per Container'`; the backend
   multiplies every "Per Container" charge by the TOTAL container count, so a 2x40 + 1x20 booking is saved at 3x each rate. The 17 cost items
   each carry their own currency (USD/EUR) and both the screen banner and the backend add them into one `total_freight_cost_usd`.
2. **Departure / status flow is broken on normal paths (CRITICAL).** "Update B/L" on a Sailed booking always gets 409 (backend only departs
   Confirmed/Amended), Amended bookings have no departure button, Cancelled/Amended have no label, a Draft cannot be saved without the carrier
   confirmation number, and "Print now" only shows a success SnackBar without printing anything.
3. **Filters silently dropped (CRITICAL).** The freight booking screen opened for one import file shows ALL bookings (first fetch skipped while
   the provider is still loading; search/status/refresh drop `import_file_id`). The insurance screen embedded per file in the draft-docs tab never
   sends `import_file_id` at all, so every file shows every certificate.
4. **Large tables.** Freight booking: backend returns every row (`.all()`), the screen builds every card eagerly
   (`ListView.separated(shrinkWrap: true, NeverScrollableScrollPhysics)` inside a `SingleChildScrollView`), KPIs are computed from the loaded
   list. Insurance: server paging exists (50 + "load more"), but search/status/KPIs/exports run client-side on the loaded page only, and the
   `DataTable` has no sticky header / sticky actions column.
5. **"Show" (عرض) exists in both lists** (eye icon in `RowActionsPill` + tap on the row / code). It is a read-only dialog built from the list
   row (no GET-by-id), misses BP-018/019 fields, and the "Print" icon beside it is fake (booking) or a duplicate of View (insurance).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F04-01 | BLOCKER | `freight_booking/widgets/freight_booking_form_dialog.dart:493-514` + `modules/freight_booking/service.py:73-79` | Sea freight lines are sent as `unit: 'Per Container'` with their own quantity; the backend replaces the quantity of every "Per Container" charge with the total container count. 2x40ft @2000 + 1x20ft @1000 is saved as 3x2000 + 3x1000 = 9000 instead of 5000. The form banner (`:700-720`) shows 5000, the saved record 9000 | Send per-type units the backend does not multiply (`'Per 40ft Container'`, `'Per 20ft Container'`) with the per-type quantity; keep `'Per Container'` only for items that really apply to every container. Backend fix listed in section 6 |
| F04-02 | BLOCKER | `freight_booking_form_dialog.dart:700-720`, `freight_booking_cost_row.dart:39-40`, `service.py:66-90` | Each of the 17 cost items has its own currency (USD/EUR), but the live banner and the backend both add raw amounts into one USD total (`total_freight_cost_usd`). The wrong total feeds the savings figures and the insurance auto-fill (`insurance_form_dialog.dart:291-295`) | Until the backend converts: block save when applicable items use more than one currency (SnackBar + red text under the currency field), label the total with the single currency used. Backend FX conversion in section 6 |
| F04-03 | CRITICAL | `freight_booking_form_dialog.dart:711` vs `:493-566` | The cancellation fee is added to the live "executed" total but `_rebuildChargesFromQuoteBreakdown` never creates a charge for it, so it is shown in the banner and lost on save | Add the `Booking Cancellation` charge in `_rebuildChargesFromQuoteBreakdown` (unit `Per Shipment`), and compute the banner from `_charges` instead of a second hand-written sum |
| F04-04 | CRITICAL | `freight_booking_registry_row.dart:133,304-319`, `departure_confirmation_dialog.dart:118-160`, `modules/freight_booking/validators.py:19,81-86` | Sailed rows show "Update B/L" (and the status chip opens departure) but `/depart` only accepts Confirmed/Amended: always 409. Amended rows show no departure button although the backend allows it | Departure button for `Confirmed` and `Amended`. For `Sailed`, replace it with an "Edit B/L / ETA" dialog that PUTs `bill_of_lading_no` and `eta` (both exist in `ShipmentBookingUpdate`) |
| F04-05 | CRITICAL | `freight_booking_form_dialog.dart:960-967` | The create/edit form makes `booking_confirmation_no` mandatory. A Draft / Booking Requested booking (BP-018) cannot be saved before the carrier confirms (BP-019); users are pushed to type invented numbers. The clone flow clears the number and then blocks on it | Remove the validator from the form (keep it optional); the confirm dialog (`freight_booking_confirm_dialog.dart:149`) stays the place where it is required |
| F04-06 | CRITICAL | `freight_booking_screen.dart:59-65,534,557-570`, `freight_booking_provider.dart:22-24`, `freight_booking_form_dialog.dart:1364` | (a) Opened from an import file, the first filtered fetch is skipped because the provider constructor's unfiltered fetch is still loading (`if (!isLoading)`), so the list shows all files while the chip says "filtered". (b) Search and status handlers call `fetchBookings` without `importFileId`; the toolbar refresh and the form "live reload" drop every filter | Keep the active filters inside `FreightBookingNotifier` (like `CargoInsuranceNotifier._filter*`), add `refresh()` that reuses them, and always run the screen's filtered fetch on mount (cancel token already handles the race) |
| F04-07 | CRITICAL | `freight_booking_print_dialog.dart:58-61` | "Print now" shows `freightBookingPrintSuccess` and closes: nothing is printed or saved | Build a PDF of the sheet and offer Print (`Printing.layoutPdf`) and Save (`FileSaveHelper.exportAndSaveFile`, name `Freight Booking - <import file code>.pdf`) |
| F04-08 | CRITICAL | `cargo_insurance/screens/cargo_insurance_screen.dart:69-72`, `import_documentation/screens/shipment_draft_docs_screen.dart:332-336` | `initialImportFileId` is never passed to `fetchCertificates`; the per-file embedded tab and the screen opened for a file list the certificates of every file | `fetchCertificates(importFileId: widget.initialImportFileId)` on mount and on refresh; show a file chip like the booking screen |
| F04-09 | CRITICAL | `cargo_insurance/widgets/insurance_form_dialog.dart:279-295,320-327` | Auto-fill builds the insured value from (a) the sum of all invoices whatever their currency, (b) a fallback to `file.estimatedCost` (an estimate, not an invoice), (c) the booking freight in USD while the certificate currency is taken from the first invoice (e.g. EUR). CIF and premium are wrong | Sum only invoices in one currency (if mixed, leave empty + warning); never use `estimatedCost`; copy the booking freight only when the booking currency equals the certificate currency, otherwise leave freight empty with a warning |
| F04-10 | MAJOR | `freight_booking_ui.dart:34-63`, `freight_booking_toolbar.dart:130-136`, `search_and_clone_freight_booking_dialog.dart:121-125`, `freight_booking_registry_row.dart:289-319`, `freight_booking_screen.dart:386-396` | Backend statuses are Draft, Booking Requested, Confirmed, Amended, Cancelled, Sailed. `FbkUi.status` has no Amended/Cancelled (raw English label), filters omit them, a Cancelled row shows "Confirm" (409), Delete is shown for Confirmed/Amended/Sailed (backend `validate_deletable` returns 409) | Add both statuses to the label switch, filters and metrics; hide Confirm for Cancelled/Sailed; hide Delete for committed statuses and offer "Cancel booking" (PUT `status: Cancelled`) instead |
| F04-11 | MAJOR | `departure_confirmation_dialog.dart:71-75,127`, `freight_booking_form_dialog.dart:624,1133-1140` | Invented values: when the booking has no ETA the dialog fabricates `revised_eta = ATD + transit or 15 days` and sends it; expected warehouse days has no validator and silently becomes 7 | Leave revised ETA empty unless the user picks it; add a validator (integer >= 0, required) to warehouse days and drop the `?? 7` |
| F04-12 | MAJOR | `freight_booking_provider.dart:26-29`, `freight_booking_confirm_dialog.dart:96`, `departure_confirmation_dialog.dart:135-141` | Confirm and depart move the lifecycle (STEP_07 / STEP_08) but only `importFilesProvider` and `smartTasksProvider` are invalidated; the lifecycle board and live tracking stay stale (the form does invalidate them, `form:645-648`) | Invalidate `lifecycleBoardSummaryProvider` and `liveLogisticsTrackingProvider` in `_invalidateRelatedProviders` |
| F04-13 | MAJOR | `freight_booking_form_dialog.dart:609-619,986-1053,1289-1290` | Shipping line, forwarder, POL and POD are sent as names only (`shipping_line_id`, `freight_forwarder_id`, `pol_location_id`, `pod_location_id` never sent); the shipping-line list also includes partners whose type contains "Bank" | Use `SearchableDropdownField<int>` keyed by partner / location id and send id + name; drop the `Bank` filter. Backend must accept the ids on PUT (section 6) |
| F04-14 | MAJOR | `freight_booking_form_dialog.dart:63,183,628,1205-1265`, `freight_booking_confirm_dialog.dart:86-94` | BP-018/019 fields missing: cargo cut-off, SI cut-off, freight terms (always the default `Collect`, no input), container release order on confirm; the equipment section edits only the first container line although a quote may create 40ft + 20ft lines | Add the fields (date tiles + Prepaid/Collect dropdown), a release-order field on confirm, and a container-lines editor (type + qty per line) |
| F04-15 | MAJOR | `freight_booking_model.dart:300`, `freight_booking_screen.dart:294,420`, `departure_confirmation_dialog.dart:168`, `freight_booking_form_dialog.dart:679` | Still open from FE-11: `import_file_code` is never returned by the backend; the UI shows `IMP-<database id>` and the TSV/Excel "import file" column is empty | Resolve the code from `importFilesProvider` by `importFileId` through one helper; show "—" when not found; never build `IMP-<id>` |
| F04-16 | MAJOR | `freight_booking_screen.dart:163-179` | Draft B/L review with no loaded file fabricates an `ImportFileModel(importFileId: 0, importFileCode: 'IMP-<booking code>')` and opens the dialog on it | If the file is not found: SnackBar "file not loaded" + refresh files; never pass id 0 |
| F04-17 | MAJOR | `freight_booking_screen.dart:376-447,553-559`, `freight_booking_toolbar.dart:119`, `modules/freight_booking/repository.py:101` | Large table: no paging on the API, every card built eagerly, server search on every keystroke without debounce, KPIs from the loaded list (see section 3) | FE04-T09 / FE04-T10 |
| F04-18 | MAJOR | `freight_booking_screen.dart:204-273` | Clone keeps `importFileId` (save then hits the "one booking per file" 400), shows a fake code `BK-DRAFT-…` that is never saved (backend generates `BKG-YYYY-NNNN`), and copies the old ETD/ETA | Clear the import file, ETD/ETA and charges' actuals; show "code assigned on save" instead of a fake code |
| F04-19 | MAJOR | `freight_booking_screen.dart:586-593,110` | Load error shows the raw exception (`'${l.error}: $err'`); the experience-guide load swallows errors (`catch (_) {}`) | `ApiErrorText.of(l, err)`; log or show a soft warning for the guide |
| F04-20 | MAJOR | `freight_booking_screen.dart:331-332,360-370,455-466,475`, `freight_booking_form_dialog.dart:1213-1222`, `freight_booking_view_dialog.dart:80`, `freight_booking_registry_row.dart:143` | Hard-coded text: PDF title/subtitle/metadata (`'Freight Bookings Registry'`, `'Total Bookings'`, `'Total USD'`, mixed Arabic subtitle), tab titles, `'B/L'`, container type labels (`'40HC High Cube'`), stage code `'PHASE-3: STEP_07'` (phase 4 screen) | Move to l10n keys; stage code to the real step label |
| F04-21 | MAJOR | `freight_booking_cost_row.dart:39-40,52` | Rate field displays `price.toStringAsFixed(0)` (99.50 shows "100"; editing from it loses cents); currencies limited to USD/EUR instead of `currenciesProvider` | Show 2 decimals; currency items from `currenciesProvider` |
| F04-22 | MAJOR | `freight_booking_provider.dart:137-145`, `freight_booking_screen.dart:406-447` | Soft-deleted bookings are unreachable: no "show deleted" toggle, `restoreBooking` is never called; no "Cancel booking" action | Add a "show deleted" filter (`include_inactive=true`) and a Restore action on inactive rows |
| F04-23 | MAJOR | `cargo_insurance_screen.dart:206-237,247-270` | Insurance search and status filter run client-side on the loaded page (50) although the API supports `search`/`status`; KPIs count only the loaded page and add insured values/premiums of all currencies under a `$` prefix | Send search (debounced) and status to the provider; KPIs grouped per currency and labelled "loaded N of total" until a summary endpoint exists |
| F04-24 | MAJOR | `cargo_insurance_screen.dart:213-214,394-412`, `modules/cargo_insurance/repository.py:50` | "Show deleted" toggle can never show anything: the API always filters `is_active == True` | Remove the toggle (or wire it after the backend adds `include_inactive`) |
| F04-25 | MAJOR | `cargo_insurance_provider.dart:132,146,159,171` | After create/update/issue/delete the provider calls `fetchCertificates()` with no args, which resets the stored filters while the screen still shows them; create/update/delete do not invalidate `importFilesProvider` | Add `refresh()` that reuses `_filter*`; invalidate import files after every mutation |
| F04-26 | MAJOR | `insurance_certificates_table.dart:105-108`, `insurance_details_dialog.dart:67-70`, `cargo_insurance_export_service.dart:39,92,157,277,465`, `cargo_insurance_screen.dart:221` | File reference built as `IMP-<database id>`; the title lookup by code never matches the real code, so the DB id is displayed, exported and searched | Look the file up by `importFileId` in `importFilesProvider` and use its `importFileCode` / display title |
| F04-27 | MAJOR | `insurance_form_dialog.dart:438-870` (controllers vs widgets), `:612-621` | Controllers exist but no input is rendered for other costs, exchange rate, final destination, voyage number, markup / minimum premium / fee / tax overrides, package type, survey agent, claims payable at and remarks; invoice value has no validator (0 accepted) | Add the inputs (rates in a collapsed "advanced" section, empty = system parameter); invoice value required and > 0 |
| F04-28 | MAJOR | `insurance_form_dialog.dart:475,571,582,638-648` | Insurance company, POL, POD are free text and the currency list is hard-coded (5 codes) although partners, transport locations and currencies are loaded by the screen | `SearchableDropdownField` on partners (insurance type) sending `insurance_company_id` + name, on transport locations, and on `currenciesProvider` |
| F04-29 | MAJOR | `insurance_certificates_table.dart:28-36,124-141`, `insurance_details_dialog.dart:82-85` | Edit is enabled on CANCELLED (409), Delete shown on ISSUED (409), "Print" opens View, CLAIMED is labelled Draft, the details header shows "Draft" for CANCELLED | Status-aware actions and labels; Print = PDF of the single certificate |
| F04-30 | MAJOR | `cargo_insurance_export_service.dart:197-229,505-517`, `insurance_details_dialog.dart:91` | Still open from FE-08 (partly): TSV/"Excel" use `saveText` with generic names `cargo_insurance_registry_<timestamp>`; the "Excel" button writes CSV but offers `.xlsx`, without UTF-8 BOM (Arabic breaks in Excel); single-certificate print goes to `Printing.layoutPdf` named `cargo_insurance_registry.pdf`; exports cover only the loaded page | Excel through `TableExportService.exportTableToExcel` / `FileSaveHelper.exportAndSaveFile` with `[Stage] - [file code]`; CSV with BOM; single-certificate PDF save named `Cargo Insurance - <file code>.pdf` |
| F04-31 | MAJOR | `cargo_insurance_screen.dart:169-181` | Smart upload extracts fields, shows a SnackBar, then opens an EMPTY form: the extraction is thrown away | Pass `result.extractedFields` to `CargoInsuranceFormDialog` (new optional `prefill` map) and fill only empty fields |
| F04-32 | MAJOR | `insurance_certificates_table.dart:66-97`, `cargo_insurance_screen.dart:430-441` | `DataTable` inside two scroll views: every loaded row built, header scrolls away, actions column scrolls horizontally (ui-screen-standards #11, #12) | See section 3 / FE04-T19 |
| F04-33 | MINOR | `freight_booking_form_dialog.dart:739-751` | Date picker range 2020-2030 (confirm/departure use 2035); a stored date outside the range asserts on open | Range from `DateTime(now.year - 5)` to `DateTime(now.year + 10)` and clamp `initialDate` |
| F04-34 | MINOR | `freight_booking_form_dialog.dart:1337,1368-1393` | "Save draft" and "Save" run the same code (no forced Draft status); "Clear / New" clears 7 fields and keeps dates, containers, charges and edit mode | "Save draft" sets status Draft when the booking is new; "Clear" resets all state or is removed in edit mode |
| F04-35 | MINOR | `freight_booking_form_dialog.dart:655-664` | Duplicate-booking handling matches Arabic substrings of the error text | Match on a structured `detail.code` once the backend sends one (section 6); keep the text match as fallback |
| F04-36 | MINOR | `cargo_insurance_screen.dart:143,620-625`, `insurance_certificates_table.dart:281,310` | `ElevatedButton`/`TextButton` in the delete dialog, raw `OCEAN`/`ICC_A` codes in the table, stage code `PHASE-3-INS` | `AppButton`; reuse the details-dialog label switches |
| F04-37 | MINOR | `insurance_details_dialog.dart:115-176` | View misses other costs, markup %, exchange rate, final destination, remarks, issued at / by; prints invented defaults (`insGeneralCargo`, `insPackagesDefault`, `insClaimsDefault`) when the field is empty | Add the fields; show "—" for empty values |
| F04-38 | MINOR | `cargo_insurance/models/cargo_insurance_model.dart:218-268` | `InsuranceCalculationResultModel` ignores `minimum_premium` returned by `/calculate`, so the preview cannot say that the minimum premium was applied | Add the field and a "minimum applied" chip when `net_premium == minimum_premium` |

---

## 3. Large tables

### 3.1 Freight bookings registry (`freight_booking_screen.dart`)

| aspect | today | evidence |
|---|---|---|
| API paging | none: `GET /freight-booking` returns every row | `modules/freight_booking/repository.py:101` `.all()`, `router.py:44-52` (no skip/limit) |
| rendering | `ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside `SingleChildScrollView` = every card built and laid out at once; each card has ~8 facts + chips + 9 icons | `freight_booking_screen.dart:409-446,524-527` |
| search | server-side `search` (code, confirmation no, B/L, vessel, forwarder) on every keystroke, no debounce; drops the file filter | `screen:557-559`, `toolbar.dart:119` |
| status filter | server-side, but Amended / Cancelled missing | `toolbar.dart:130-136` |
| sorting | fixed `created_at desc`, no user sort | `repository.py:101` |
| row count / KPIs | computed from the loaded list | `screen:376-403` |
| layout | card list (no columns, no sticky header) | `freight_booking_registry_row.dart` |
| export | Excel/PDF/TSV of the loaded list = full set today (no paging), would become one page after paging | `screen:319-374` |

Recommended solution (two steps, no shared-widget dependency):
1. **FE only, now (FE04-T09):** move the registry into an `Expanded` + `ListView.separated` (lazy, own scroll) instead of shrink-wrapped
   inside the page scroll; keep header blocks in a `CustomScrollView` with `SliverList` so only visible cards are built; debounce search 350 ms;
   show "N bookings" from the response length.
2. **With backend (FE04-T10):** `GET /freight-booking` gets `skip`, `limit` (default 50, max 200), `sort`, and returns `{total, items}` under a
   new opt-in flag (`?paged=true`) so other callers (`navigation_provider.dart:271`, insurance auto-fill, demurrage) keep the plain list; a
   `GET /freight-booking/summary` returns the KPI counts (by status, delayed) for the active filters. FE: "load more" footer like insurance,
   KPIs from summary, exports call the API with `limit=total` (or a dedicated export endpoint) so "export" means the full filtered set.

### 3.2 Insurance certificates (`cargo_insurance_screen.dart` + `insurance_certificates_table.dart`)

| aspect | today | evidence |
|---|---|---|
| API paging | yes: `skip`/`limit` (50, max 100) + `total` | `modules/cargo_insurance/router.py:59-78` |
| FE paging | "load more" footer (FE-10 fixed) | `cargo_insurance_provider.dart:86-111`, `screen:497-533` |
| rendering | Material `DataTable` (non-lazy) in a horizontal `SingleChildScrollView` inside a vertical one: every loaded row built; grows with each "load more" | `insurance_certificates_table.dart:69-97`, `screen:430-441` |
| sticky header / actions | no: header scrolls away vertically, actions column scrolls away horizontally | same lines; ui-screen-standards #11/#12 |
| column widths | fixed `SizedBox(width: 130/140)` on 2 columns, others intrinsic | `table.dart:244-263` |
| search / status | client-side on the loaded page only (server supports both) | `screen:211-237` |
| file filter | never sent | `screen:69-72` |
| sorting | none | - |
| KPIs | loaded page only, currencies mixed under `$` | `screen:206-270` |
| export | loaded + client-filtered page only | `screen:303-352` |

Recommended solution (FE04-T14 + FE04-T19): server-side search (debounced) / status / file filter through the provider; keep the
"load more" footer; replace the `DataTable` with a header `Row` pinned above a `ListView.builder` of fixed-height rows (same column widths
list for header and rows, horizontal scroll wrapping both, actions column first and outside the horizontal scroll so it stays visible);
KPIs per currency with "loaded N of total" until a backend summary endpoint exists (section 6); exports fetch all pages (loop `skip` until
`total`) before writing the file.

---

## 4. View/Show action (عرض)

| entity | View exists? | how | gaps / why it looks missing | what to add |
|---|---|---|---|---|
| Freight booking | **Yes** | `FreightBookingViewDialog` (`freight_booking_view_dialog.dart`), opened by the eye icon in `RowActionsPill` (`freight_booking_registry_row.dart:289-298`) and by tapping the card (`:67-68`) | Built from the list row (no `GET /freight-booking/{id}`), so it can be stale; missing file code/name, forwarder, cut-off dates, freight terms, release order, free demurrage days, request/confirmation dates, notes, owner; no next-step action buttons; the eye icon sits at the end of the card footer among 7-9 icons, easy to miss | FE04-T11: load by id on open, add the missing fields, add footer actions by status (Edit, Confirm, Departure, Print) |
| Freight booking print | Fake | `freight_booking_print_dialog.dart:58-61` | "Print now" does nothing | FE04-T06 |
| Insurance certificate | **Yes** | `CargoInsuranceDetailsDialog` via eye icon (`insurance_certificates_table.dart:124-133`) and tap on the code (`:153-154`) | Built from the list row; missing fields (F04-37); "Print" icon is a second View; header badge wrong for CANCELLED | FE04-T17 / FE04-T20 |
| Search & clone list | n/a | selection dialog only | - | none |

Answer to "why no show": in Phase 04 both lists DO have a read-only view; there is no separate details route (no go_router route, the app
navigates by index and dialogs), which is fine for this phase. The perceived gap comes from (1) the view being a dialog on stale list
data with missing fields, (2) the eye icon being one of many small icons, and (3) Print looking like a view.

---

## 5. Tasks

Conventions for every task: Flutter Windows desktop, Riverpod `StateNotifier`, colours only from `AppTheme`, text only from `context.l10n`
(add keys to `frontend/lib/core/localization/app_localizations.dart`, `app_localizations_ar.dart`, `app_localizations_en.dart`, between
`// === review phase04 keys ===` and `// === end review phase04 keys ===`), API errors as SnackBar via `ApiErrorText.of(l, e)`,
`SearchableDropdownField` for reference data, `ref.invalidate(...)` after mutations, exports only through `FileSaveHelper.exportAndSaveFile`.
Run `flutter test test/<the files you touched>` from `frontend/`. Do not edit `modules/**` unless the task says "Backend needed: yes".

### FE04-T01: Correct freight charge units, cancellation fee and currency guard
- **Severity:** BLOCKER. **Type:** bug. **Depends on:** none. **Backend needed:** no (backend fixes in section 6 are complementary).
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`, the 3 l10n files, `frontend/test/features/freight_booking/freight_booking_charges_test.dart` (new).
- **Steps:**
  1. Extract `_rebuildChargesFromQuoteBreakdown` (lines ~493-566) into a pure static function `List<BookingChargeModel> buildChargesFromQuote(FbkQuoteState s)` (record or small class in the same file) so it can be unit-tested.
  2. Sea freight 40ft: `unit: 'Per 40ft Container'`, `quantity: container40ftQty`; 20ft: `unit: 'Per 20ft Container'`, `quantity: container20ftQty`. Keep `'Per Container'` only for SOLAS/VGM and VGM notification (they apply to every container).
  3. Add the missing cancellation charge: `BookingChargeModel(chargeType: 'Booking Cancellation', unit: 'Per Shipment', quantity: 1, currency: _cancellationCur, rate: _cancellationPrice, total: _cancellationPrice)` when `_cancellationApp && _cancellationPrice > 0`.
  4. Replace `_computedCurrentExecutedFreight` with the sum of `buildChargesFromQuote(...)` totals (one source of truth).
  5. Before save (`_submitWithContainerValidation`), collect the currencies of applicable items; if more than one, stop, switch to the cost tab and show SnackBar `l.fbkMixedCurrencyError` ("All charges must use one currency until currency conversion is available").
- **Acceptance criteria:**
  - [ ] 2x40ft @2000 + 1x20ft @1000 saves a total of 5000 (check the registry row after save).
  - [ ] Enabling the cancellation fee changes both the banner and the saved total by the same amount.
  - [ ] Choosing EUR on one item and USD on another blocks save with a red SnackBar.
- **Tests:** `freight_booking_charges_test.dart`: units and quantities per type; cancellation charge present; mixed-currency detector returns true for USD+EUR.
- **Out of scope:** FX conversion, backend cost engine.

### FE04-T02: Status-aware labels, filters and row actions for bookings
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_ui.dart`, `.../widgets/freight_booking_registry_row.dart`, `.../widgets/freight_booking_toolbar.dart`, `.../widgets/search_and_clone_freight_booking_dialog.dart`, `.../screens/freight_booking_screen.dart`.
- **Steps:**
  1. In `FbkUi.status` add `Amended` (warning, `l.fbkStatusAmended`, `Icons.edit_calendar`) and `Cancelled` (danger, `l.fbkStatusCancelled`, `Icons.cancel_outlined`). Add `FbkUi.canConfirm(status)` = Draft, Booking Requested, Amended (the backend also re-confirms Confirmed, but no button is shown for it); `canDepart` = Confirmed, Amended; `canDelete` = Draft, Booking Requested, Cancelled; `canCancel` = any except Cancelled and Sailed.
  2. Registry row: use those helpers for the Confirm / Departure / Delete icons and for the status-chip tap (no tap action for Cancelled; Sailed opens the T03 dialog).
  3. Add a "Cancel booking" icon (`Icons.cancel_outlined`, crimson) calling a new screen method that asks confirmation (`FbkPrompts`) then `updateBooking(id, {'status': 'Cancelled'})`.
  4. Toolbar status filter and clone dialog chips: add Amended and Cancelled.
  5. Screen metrics: count Amended with Confirmed in the "confirmed" card or add a card; no other change.
- **Acceptance criteria:**
  - [ ] Cancelled and Amended rows show translated labels in AR and EN.
  - [ ] No Confirm icon on Cancelled/Sailed rows; Departure icon on Confirmed and Amended rows.
  - [ ] No Delete icon on Confirmed/Amended/Sailed rows; Cancel works and the row turns Cancelled after refresh.
- **Tests:** `frontend/test/features/freight_booking/fbk_status_actions_test.dart`: helpers per status; widget test that a Cancelled row has no `confirmBookingRowBtn_*` key.
- **Out of scope:** backend status rules.

### FE04-T03: Edit B/L and ETA of a sailed booking (no 409)
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** FE04-T02. **Backend needed:** no (`ShipmentBookingUpdate` already has `bill_of_lading_no`, `eta`, `vessel_name`, `voyage_number`).
- **Files:** `frontend/lib/features/freight_booking/widgets/departure_confirmation_dialog.dart`, `.../widgets/freight_booking_registry_row.dart`, `.../screens/freight_booking_screen.dart`, l10n files.
- **Steps:**
  1. Add a `mode` to `DepartureConfirmationDialog`: `depart` (current) and `editSailed`. In `editSailed` the title is `l.fbkEditBlTitle`, ATD and shipped-on-board are read-only, and submit calls `updateBooking(id, {'bill_of_lading_no', 'eta', 'vessel_name', 'voyage_number'})` (only sent keys).
  2. Registry row: Sailed rows open `editSailed`; Confirmed/Amended open `depart`.
  3. Remove the invented revised ETA (lines 71-75): initialise `_revisedEta` only from `b.eta`, otherwise null; send `revised_eta` only when the user picked one.
- **Acceptance criteria:**
  - [ ] On a Sailed booking, changing the B/L number saves without error and the new number shows in the row chip.
  - [ ] Departure of a booking without ETA does not send `revised_eta` unless picked.
- **Tests:** `frontend/test/features/freight_booking/departure_dialog_payload_test.dart`: payload has no `revised_eta` when ETA is null and none picked; editSailed builds a PUT payload without `actual_departure_date`.
- **Out of scope:** backend `/depart` rules.

### FE04-T04: Booking form: optional confirmation number, clone fixes, honest draft buttons
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`, `.../screens/freight_booking_screen.dart`, l10n files.
- **Steps:**
  1. Remove the validator of the confirmation number field (form ~line 966); send `booking_confirmation_no` only when not empty.
  2. Clone (`screen._onCloneBooking`): set `importFileId: null`, `etd: null`, `eta: null`; drop the fake `newDraftCode` and pass `l.fbkCodeAssignedOnSave` as `suggestedNewCode`; add `l.fbkCloneResetFile` and `l.fbkCloneResetDates` to `mandatorilyResetFields`.
  3. "Save draft" button: for a new booking force `_status = 'Draft'` before `_submitWithContainerValidation`.
  4. "Clear / New": hide it in edit mode; in create mode reset every field (dates, containers, charges, quote state, status) via one `_resetForm()`.
  5. Expected warehouse days: add validator (required, integer >= 0) and send the parsed value without `?? 7`.
- **Acceptance criteria:**
  - [ ] A new booking saves as Draft with an empty confirmation number.
  - [ ] Cloning a booking opens a form with no import file and no dates; saving it on another file succeeds.
  - [ ] Empty warehouse days shows a red error under the field.
- **Tests:** `frontend/test/features/freight_booking/booking_form_validation_test.dart` (widget): save with empty confirmation no is not blocked; empty warehouse days is blocked.
- **Out of scope:** new fields (FE04-T12).

### FE04-T05: Keep booking filters (file, status, search) across every fetch
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/providers/freight_booking_provider.dart`, `.../screens/freight_booking_screen.dart`, `.../widgets/freight_booking_form_dialog.dart`, `.../widgets/freight_booking_toolbar.dart`.
- **Steps:**
  1. In `FreightBookingNotifier` store `_filterImportFileId`, `_filterStatus`, `_filterSearch`, `_includeInactive`; `fetchBookings(...)` updates them; add `Future<void> refresh()` that refetches with the stored values; create/update/confirm/depart/delete/restore call `refresh()`.
  2. Screen `initState`: always call `fetchBookings(importFileId: _selectedImportFileId, status: ...)` (remove the `isLoading` guard for this provider only).
  3. Search: debounce 350 ms in the screen (`Timer`), and pass `importFileId: _selectedImportFileId` in search and status handlers.
  4. `MasterDataToolbarWidget.onRefreshNeeded`, header refresh and the form "live reload" button call `refresh()`.
- **Acceptance criteria:**
  - [ ] Opening "Freight Booking" from an import file shows only that file's bookings on first open.
  - [ ] Typing in search or changing status keeps the file chip filter applied.
  - [ ] After saving a booking the list keeps the current filters.
- **Tests:** `frontend/test/features/freight_booking/freight_booking_provider_filters_test.dart`: with a fake Dio adapter assert the query params of `refresh()` after `fetchBookings(importFileId: 7, status: 'Draft')` and after `createBooking`.
- **Out of scope:** server paging (FE04-T10).

### FE04-T06: Real print / save PDF for one booking
- **Severity:** CRITICAL. **Type:** feature. **Depends on:** FE04-T08 (file code helper) recommended. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_print_dialog.dart`, new `frontend/lib/features/freight_booking/services/freight_booking_pdf_service.dart` (reason: PDF building does not belong in a widget; mirrors `cargo_insurance/services`), l10n files.
- **Steps:**
  1. `FreightBookingPdfService.build(booking, l, fileCode)` returns `Uint8List` with the same sections as the sheet (header, carrier, route, schedule, containers, charges, total, savings) using the Cairo fonts like `TableExportService.exportTableToPdf`.
  2. Dialog footer: "Print" -> `Printing.layoutPdf(onLayout: (_) => bytes)`; "Save PDF" -> `FileSaveHelper.exportAndSaveFile(bytes, stageName: l.fbkStageName, importFileNameOrCode: fileCode ?? booking.bookingCode, extension: 'pdf')`.
  3. Remove the fake success SnackBar; show success only after the save/print future completes.
- **Acceptance criteria:**
  - [ ] "Print" opens the system print dialog with the booking content.
  - [ ] "Save PDF" opens Save As with the name `<Stage> - <file code>.pdf`.
- **Tests:** `frontend/test/features/freight_booking/freight_booking_pdf_service_test.dart`: bytes non-empty and start with `%PDF`.
- **Out of scope:** registry PDF (already through `TableExportService`).

### FE04-T07: Refresh lifecycle after confirm / depart; release order on confirm
- **Severity:** MAJOR. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/providers/freight_booking_provider.dart`, `.../widgets/freight_booking_confirm_dialog.dart`, l10n files.
- **Steps:**
  1. `_invalidateRelatedProviders`: also `lifecycleBoardSummaryProvider` and `liveLogisticsTrackingProvider` (imports from `lifecycle_board/providers/lifecycle_board_provider.dart`).
  2. Confirm dialog: add "Container release order no" field; since `/confirm` does not accept it, after a successful confirm call `updateBooking(id, {'container_release_order_no': value})` only when not empty.
  3. Confirm dialog: validate ETA >= ETD before submit (red text under ETA).
- **Acceptance criteria:**
  - [ ] After confirming, the lifecycle board shows STEP_07 without manual refresh.
  - [ ] Release order typed in the confirm dialog appears in the booking view.
- **Tests:** `frontend/test/features/freight_booking/confirm_dialog_test.dart`: ETA before ETD shows an error and no request is sent.
- **Out of scope:** backend `/confirm` schema.

### FE04-T08: Show real import file codes in bookings (no `IMP-<id>`)
- **Severity:** MAJOR. **Type:** bug (still open from FE-11). **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/screens/freight_booking_screen.dart`, `.../widgets/departure_confirmation_dialog.dart`, `.../widgets/freight_booking_form_dialog.dart`, `.../models/freight_booking_model.dart`.
- **Steps:**
  1. Add `static String? fileCodeFor(int? id, List<ImportFileModel> files)` in `FbkFormat` (`freight_booking_ui.dart`) returning `importFileCode` or null.
  2. Replace every `'IMP-${...}'` and `booking.importFileCode ?? ...` (screen 169, 294, 420; departure 168; form 679) with the helper; show `—` when null.
  3. `_showDraftBlReviewDialog`: if the file is not in the provider, SnackBar `l.fbkFileNotLoaded` and refresh import files; do not construct `ImportFileModel(importFileId: 0)`.
  4. Model: stop reading `import_file_code`; remove `individual_containers`, `cost_savings_usd`, `cost_variance_usd`, `savings_notes`, `booking_id`, `booking_code` from `toJson` (still open FE-11).
- **Acceptance criteria:**
  - [ ] Registry, departure dialog and exports show `IMP-2026-xxxx` style codes, never a DB id.
  - [ ] Draft B/L review on an unknown file shows a message instead of opening.
- **Tests:** extend `frontend/test/freight_booking_model_test.dart`: `toJson` has no computed keys; helper returns null for an unknown id.
- **Out of scope:** backend adding `import_file_code` to the response.

### FE04-T09: Lazy rendering and debounced search for the booking registry
- **Severity:** MAJOR. **Type:** refactor. **Depends on:** FE04-T05. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/screens/freight_booking_screen.dart`, `frontend/test/perf/screen_25_freight_booking_perf_test.dart`.
- **Steps:**
  1. Replace `SingleChildScrollView > Column > ListView.separated(shrinkWrap)` with a `CustomScrollView`: toolbar/metrics/filter/banner as `SliverToBoxAdapter`, bookings as `SliverList.separated` (lazy).
  2. Loading / error / empty states as `SliverFillRemaining` or `SliverToBoxAdapter`.
  3. Keep `SelectionArea` around the scroll view.
- **Acceptance criteria:**
  - [ ] With 2,000 bookings the screen opens and scrolls without jank (only visible cards built).
  - [ ] No layout change for small lists.
- **Tests:** update the perf test: pump 2,000 fake bookings and assert fewer than 50 `FbkRegistryRow` widgets are built.
- **Out of scope:** server paging.

### FE04-T10: Server paging + summary for bookings
- **Severity:** MAJOR. **Type:** feature. **Depends on:** FE04-T05, FE04-T09, backend B04-1. **Backend needed:** yes: `GET /api/v1/freight-booking?paged=true&skip&limit&sort` returning `{total, items}` and `GET /api/v1/freight-booking/summary` (counts by status, delayed) with the same filters.
- **Files:** `frontend/lib/features/freight_booking/providers/freight_booking_provider.dart`, `.../screens/freight_booking_screen.dart`, new test.
- **Steps:**
  1. Provider: `pageSize = 50`, `_total`, `hasMore`, `loadMore()` (copy the pattern of `CargoInsuranceNotifier`), request with `paged=true`.
  2. Add `freightBookingSummaryProvider` (FutureProvider.family on the filter tuple) for the metric cards.
  3. Screen: "Loaded N of T" + "Load more" footer; metrics from the summary; Excel/PDF export fetch all pages first (loop until `total`).
- **Acceptance criteria:**
  - [ ] First open loads 50 rows; "Load more" appends 50.
  - [ ] Metric cards show totals for all matching bookings, not only the loaded ones.
  - [ ] Export contains every matching booking.
- **Tests:** `frontend/test/features/freight_booking/freight_booking_paging_test.dart`: `loadMore` sends `skip=50`; `hasMore` false when loaded == total.
- **Out of scope:** other callers of the plain list.

### FE04-T11: Complete the booking View dialog
- **Severity:** MAJOR. **Type:** ux. **Depends on:** FE04-T08. **Backend needed:** no (`GET /freight-booking/{id}` exists).
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_view_dialog.dart`, `.../providers/freight_booking_provider.dart`, `.../screens/freight_booking_screen.dart`, l10n files.
- **Steps:**
  1. Provider: `Future<ShipmentBookingModel> getBooking(int id)`.
  2. Dialog: show the list row immediately, then replace with the fetched record (small spinner chip while loading; error as SnackBar).
  3. Add facts: import file (code + name), forwarder, cargo / SI cut-off, freight terms, release order, free demurrage days, request and confirmation dates, notes, owner.
  4. Footer actions by status using the FE04-T02 helpers: Edit, Confirm, Departure / Edit B/L, Print (callbacks passed from the screen).
- **Acceptance criteria:**
  - [ ] View shows every BP-018/019 field; empty values show `—`.
  - [ ] Confirm / Departure can be started from the View dialog.
- **Tests:** widget test `freight_booking_view_dialog_test.dart`: Cancelled booking shows no Confirm button; fields render.
- **Out of scope:** new backend fields.

### FE04-T12: BP-018/019 fields and multi-line containers in the booking form
- **Severity:** MAJOR. **Type:** feature. **Depends on:** FE04-T04. **Backend needed:** no (`cargo_cutoff_date`, `si_cutoff_date`, `freight_terms`, `containers_data[]` already accepted).
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`, l10n files, test.
- **Steps:**
  1. Terms section: `SearchableDropdownField<String>` Prepaid / Collect bound to `_freightTerms`.
  2. Schedule section: `FbkDateField` for cargo cut-off and SI cut-off (validator: before ETD when both set).
  3. Equipment: replace the single type/qty pair with a list of lines (type dropdown + qty field + remove icon + "add line"), editing `_containers` entirely.
  4. Payload: `cargo_cutoff_date`, `si_cutoff_date`, `freight_terms`.
- **Acceptance criteria:**
  - [ ] User can choose Prepaid, save, reopen and see Prepaid.
  - [ ] A quote with 40ft + 20ft shows two editable lines.
  - [ ] Cut-off after ETD shows a red error.
- **Tests:** `booking_form_fields_test.dart`: payload contains the new keys; two container lines serialised.
- **Out of scope:** container numbers / seals (loading stage).

### FE04-T13: Carrier, forwarder and port ids instead of free names
- **Severity:** MAJOR. **Type:** bug. **Depends on:** backend B04-3. **Backend needed:** yes: `ShipmentBookingUpdate` must accept `shipping_line_id`, `freight_forwarder_id`, `pol_location_id`, `pod_location_id`.
- **Files:** `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`, test.
- **Steps:**
  1. Change the four dropdowns to `SearchableDropdownField<int>` keyed by `partnerId` / `locationId`; keep the name for display and send both id and name.
  2. Shipping-line list: partner types containing `Shipping Line` or `Carrier` only (remove `Bank` and `Freight`); forwarders: `Forwarder` / `Freight`.
  3. Editing a legacy booking with name only: preselect by name match, otherwise show the stored name as a disabled hint and require a choice.
- **Acceptance criteria:**
  - [ ] Saved bookings carry the 4 ids (check the API response).
  - [ ] Banks no longer appear in the shipping-line list.
- **Tests:** payload test: ids present.
- **Out of scope:** backend migration of legacy rows.

### FE04-T14: Insurance: file scope, server search/status, filter-safe refresh
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/providers/cargo_insurance_provider.dart`, `.../screens/cargo_insurance_screen.dart`, `frontend/test/features/cargo_insurance/cargo_insurance_provider_test.dart`.
- **Steps:**
  1. Provider: add `refresh()` that reuses `_filter*`; create/update/issue/delete call `refresh()` instead of `fetchCertificates()`.
  2. Screen: `_refreshData` calls `fetchCertificates(importFileId: widget.initialImportFileId, status: _selectedStatusFilter, search: _searchController.text)`; status chips and the debounced (350 ms) search call it too; remove the client-side status/search filtering (keep nothing on the client).
  3. Remove the "show deleted" toggle (API never returns inactive rows).
  4. After create/update/delete: `ref.invalidate(importFilesProvider)`.
  5. KPIs: compute per currency (`Map<String, double>`) and render `"<amount> <code>"` lines; title shows `l.insuranceLoadedOfTotal(loaded, total)`.
- **Acceptance criteria:**
  - [ ] The insurance tab of a file in Draft Docs lists only that file's certificates.
  - [ ] Searching finds a certificate that is not in the first 50.
  - [ ] Saving a certificate keeps the status filter.
- **Tests:** provider test: query params of `refresh()` after a filtered fetch and after `createCertificate`.
- **Out of scope:** summary endpoint.

### FE04-T15: Insurance auto-fill without mixed currencies or estimates
- **Severity:** CRITICAL. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/widgets/insurance_form_dialog.dart`, l10n files, test.
- **Steps:**
  1. Extract the value part of `_onImportFileSelected` into a pure function `InsuranceAutoFill compute(file, booking, pos)`.
  2. Invoice value: group `file.invoicesData` by currency; if exactly one currency use its sum and set `_currency`; if several, leave empty and set a warning `l.insAutoFillMixedCurrency`. If no invoices, use PO FOB only when all POs share one currency. Never use `file.estimatedCost`.
  3. Freight: copy the booking total only when the booking charges use the certificate currency (all charges' `currency == _currency`); otherwise leave empty and warn.
  4. Show warnings in an `FbkNotice`-like banner above the valuation inputs.
- **Acceptance criteria:**
  - [ ] File with EUR + USD invoices leaves invoice value empty and shows the warning.
  - [ ] File with only an estimated cost leaves invoice value empty.
- **Tests:** `frontend/test/features/cargo_insurance/insurance_autofill_test.dart` for the 3 rules.
- **Out of scope:** FX conversion.

### FE04-T16: Insurance form: missing inputs, validators, master-data dropdowns
- **Severity:** MAJOR. **Type:** feature. **Depends on:** FE04-T15. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/widgets/insurance_form_dialog.dart`, l10n files, test.
- **Steps:**
  1. Render inputs for: other costs, exchange rate (required when currency != EGP, > 0), final destination, voyage number, package type, survey agent, claims payable at, remarks; collapsed "advanced rates" section for markup / minimum premium / issuance fee / tax rate (empty = system parameter; hint says so). All numeric inputs trigger `_runLiveCalculation`.
  2. Invoice value: required, > 0.
  3. Insurance company: `SearchableDropdownField<int>` over `partnersProvider` filtered to insurance partners; send `insurance_company_id` + `insurance_company_name`.
  4. POL / POD: `SearchableDropdownField<String>` over `transportLocationsProvider` (value = location name, as the backend stores names).
  5. Currency: items from `currenciesProvider`.
- **Acceptance criteria:**
  - [ ] Every field of `CargoInsuranceCertificateCreate` can be entered.
  - [ ] Invoice value 0 is rejected with red text.
  - [ ] Choosing an insurance company stores its id.
- **Tests:** widget/payload test: payload keys and validator behaviour.
- **Out of scope:** backend FK for ports.

### FE04-T17: Insurance: status-aware actions and real file codes
- **Severity:** MAJOR. **Type:** bug. **Depends on:** none. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/widgets/insurance_certificates_table.dart`, `.../widgets/insurance_details_dialog.dart`, `.../services/cargo_insurance_export_service.dart`, `.../screens/cargo_insurance_screen.dart`.
- **Steps:**
  1. Add `static ImportFileModel? fileFor(int? id, List<ImportFileModel>)` in the export service; replace every `'IMP-${...importFileId}'` with the real `importFileCode` / `DisplayNameResolver.resolveShipmentTitle(file)`.
  2. Table: Edit only for DRAFT; Delete only for DRAFT/CANCELLED; Print calls `printOrSaveCertificatesPdf(context, [cert])`; label CLAIMED (`l.insuranceStatusClaimedBadge`).
  3. Details header chip: real label/icon for each status (reuse `insuranceStatusLabel` / severity).
  4. Delete dialog buttons -> `AppButton`; transport mode / clause labels in the table via the details-dialog switches (move them to a shared function in the table file).
- **Acceptance criteria:**
  - [ ] No row shows `IMP-<number>` that is not a real file code.
  - [ ] Issued certificate: no Edit, no Delete; Cancelled: no Edit.
- **Tests:** widget test on the table with ISSUED / CANCELLED rows; unit test for `fileFor`.
- **Out of scope:** cancel endpoint (backend B04-6).

### FE04-T18: Insurance exports through FileSaveHelper with standard names
- **Severity:** MAJOR. **Type:** bug (still open from FE-08). **Depends on:** FE04-T14, FE04-T17. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/services/cargo_insurance_export_service.dart`, `.../screens/cargo_insurance_screen.dart`, `frontend/test/cargo_insurance_export_service_test.dart`.
- **Steps:**
  1. "Excel": build rows and call `TableExportService.exportTableToExcel(context, stageName: l.insuranceExportStageName, importFileNameOrCode: <file code or l.insuranceExportRegistryTag>, headers, rows)`.
  2. TSV/CSV: `FileSaveHelper.exportAndSaveFile` with UTF-8 BOM bytes and the `[Stage] - [file code].csv` name.
  3. Single-certificate print from the details dialog: name `Cargo Insurance - <file code>.pdf`; add a "Save PDF" button next to Print.
  4. Before exporting, if `notifier.hasMore`, fetch all remaining pages (loop `loadMore` with a progress SnackBar) so the export is the full filtered set.
- **Acceptance criteria:**
  - [ ] Excel opens in Excel with Arabic text readable.
  - [ ] Save As shows `Cargo Insurance - IMP-....xlsx/.pdf`.
  - [ ] Export with 120 matching certificates contains 120 rows.
- **Tests:** export service test: generated file name format; CSV starts with BOM.
- **Out of scope:** PDF layout redesign.

### FE04-T19: Insurance table for large data (lazy rows, sticky header and actions)
- **Severity:** MAJOR. **Type:** refactor. **Depends on:** FE04-T14. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/widgets/insurance_certificates_table.dart`, `.../screens/cargo_insurance_screen.dart`, test.
- **Steps:**
  1. Replace `DataTable` with: a fixed actions column (left in LTR / right in RTL, `EdgeInsetsDirectional`) + a horizontally scrollable area containing a header `Row` and a `ListView.builder` of fixed-height (56 px) rows; one `List<double>` of column widths shared by header and rows; header background solid (`AppTheme.surfaceAltOf`).
  2. Synchronise vertical scroll between the actions column and the data area with two `ScrollController`s linked by a listener (or one `ListView` whose rows contain both parts, with the horizontal scroll inside each row driven by one shared horizontal controller).
  3. Screen: remove the outer vertical `SingleChildScrollView` around the table (the table owns its scroll inside `Expanded`).
- **Acceptance criteria:**
  - [ ] Header stays visible while scrolling 500 loaded rows; actions stay visible while scrolling horizontally.
  - [ ] RTL layout mirrors correctly.
- **Tests:** widget test with 500 rows: fewer than 60 row widgets built; header finder still visible after `drag`.
- **Out of scope:** shared `EnterpriseDataTable` server mode (open question).

### FE04-T20: Insurance smart-upload prefill and complete details view
- **Severity:** MINOR. **Type:** ux. **Depends on:** FE04-T16. **Backend needed:** no.
- **Files:** `frontend/lib/features/cargo_insurance/screens/cargo_insurance_screen.dart`, `.../widgets/insurance_form_dialog.dart`, `.../widgets/insurance_details_dialog.dart`, `.../models/cargo_insurance_model.dart`.
- **Steps:**
  1. Form: optional `Map<String, dynamic>? prefill`; fill only empty controllers from keys `policy_number`, `bl_number` (-> tracking reference), `vessel_name`, `port_of_loading`, `port_of_discharge`, `invoice_value`, `currency`.
  2. Screen smart upload: pass `result.extractedFields` as `prefill`.
  3. Details: add other costs, markup %, exchange rate, final destination, remarks, issued at, created/updated by; replace `insGeneralCargo` / `insPackagesDefault` / `insClaimsDefault` defaults with `—`.
  4. Model: add `minimumPremium` to `InsuranceCalculationResultModel`; preview shows a "minimum premium applied" chip when `netPremium == minimumPremium`.
- **Acceptance criteria:**
  - [ ] Uploading a policy PDF opens the form with the extracted values.
  - [ ] Details never show invented cargo text.
- **Tests:** model test for `minimum_premium`; widget test for prefill.
- **Out of scope:** extractor quality.

### FE04-T21: Booking screen hygiene: l10n, error text, rate decimals, deleted/restore
- **Severity:** MAJOR. **Type:** refactor. **Depends on:** FE04-T05. **Backend needed:** no.
- **Files:** `frontend/lib/features/freight_booking/screens/freight_booking_screen.dart`, `.../widgets/freight_booking_cost_row.dart`, `.../widgets/freight_booking_form_dialog.dart`, `.../widgets/freight_booking_registry_row.dart`, l10n files.
- **Steps:**
  1. Replace hard-coded strings listed in F04-20 with l10n keys (PDF title/subtitle/metadata, tab titles, `'B/L'`, container type labels); stage name/code from l10n.
  2. Error state: `ApiErrorText.of(l, err)`.
  3. Cost row: show the rate with 2 decimals; currency items from `currenciesProvider`.
  4. Add a "show deleted" `FilterChip` (sets `includeInactive` in the provider, FE04-T05) and a Restore icon on inactive rows calling `restoreBooking` with SnackBar on error.
  5. Date pickers: range `now.year-5 .. now.year+10` and clamp `initialDate`.
- **Acceptance criteria:**
  - [ ] No English literal visible in AR mode on the booking screen and exports.
  - [ ] A deleted booking can be shown and restored.
  - [ ] Rate 99.50 is displayed as 99.50.
- **Tests:** `freight_booking_design_test.dart` extended: deleted toggle + restore button present for inactive rows.
- **Out of scope:** Arabic PDF layout.

---

## 6. Backend dependencies

- **B04-1** `freight_booking`: list paging opt-in (`paged=true`, `skip`, `limit`, `sort`, `{total, items}`) + `/summary` counts for the active filters (FE04-T10).
- **B04-2** `freight_booking/service.py:73-79`: "Per Container" must not overwrite a per-type quantity; better, compute container-type charges from the matching container lines. `service.py:66-90`: convert each charge to USD (CurrencyService) or store the total per currency instead of `total_freight_cost_usd` of mixed amounts (F04-01/02).
- **B04-3** `ShipmentBookingUpdate` (`schemas.py:206-241`): accept `shipping_line_id`, `freight_forwarder_id`, `pol_location_id`, `pod_location_id` (FE04-T13).
- **B04-4** Booking response: add `import_file_code` (removes the FE lookup in FE04-T08); duplicate-booking 400 with a structured `detail.code` (`FB_DUPLICATE_BOOKING_FOR_FILE`) (F04-35).
- **B04-5** `/confirm`: accept `container_release_order_no` (FE04-T07 uses a follow-up PUT meanwhile).
- **B04-6** `cargo_insurance`: a `/certificates/{id}/cancel` endpoint (status CANCELLED from DRAFT/ISSUED with reason) and `include_inactive` + restore if deleted certificates must stay reachable; a `/certificates/summary` (count and sums per currency) for KPIs.

## 7. Open questions for the CTO

1. Freight total currency: should a booking support charges in several currencies (converted to USD at which rate/date), or must all charges be in one currency? [Safe default: one currency per booking, FE blocks mixed (FE04-T01)]
2. Is "Cancel booking" allowed after Sailed? [Default: no; backend currently allows Cancelled from any committed status]
3. Editing the B/L after sailing: plain PUT (FE04-T03) or a dedicated audited endpoint? [Default: PUT, audit log already records UPDATE]
4. Large tables across the app: extend the shared `EnterpriseDataTable` (`core/widgets/enterprise_data_table`) with a server-side mode (page/sort/search callbacks), or keep per-screen "load more" like insurance? [Default: per-screen now (FE04-T10/T19), shared server mode as a cross-phase task]
5. Insurance auto-fill: may the insured value come from PO FOB when there is no commercial invoice yet? [Default: yes when single currency, never from `estimatedCost`]
6. Should insurance certificates be listed inside the booking View (same import file) to make BP-018 and insurance one flow? [Default: link only]
