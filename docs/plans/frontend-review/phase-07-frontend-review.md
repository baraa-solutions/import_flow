# Phase 07 Customs clearance: frontend review

Status: 2026-10-05, static review only (no `flutter test`, no `pytest`, no `import main`, no code edited).
Scope: BP-029 (follow-up, inspection, sampling, free time), BP-030 (Nafeza duty claim / CL-02 assessment),
BP-031 (CL-03 duty payment and ledger), BP-032 (CL-04 final release, gate pass), plus CL-05 clearance invoices and the
under-bond / lab-result flow. Phase 06 items in the same files (CS-01 broker, CS-02 D/O, CS-03 declaration 46, the hub
record list, the edit form, the clearance quotations) are owned by `docs/plans/frontend-review/phase-06-frontend-review.md`
and are referenced here, not re-planned.

Where the screens live (`frontend/lib/features/home/home_screen.dart:144, 209-215`, `core/providers/navigation_provider.dart:59, 92-94`):

| Screen | Entry | File |
|---|---|---|
| Clearance hub, tab 0 follow-up (record cards) + header stage buttons CL-01..CL-05 | nav 27 | `features/customs_clearance/screens/customs_clearance_screen.dart` |
| Tab 1 drawing samples & shortage | nav 60 (and tab 1 of nav 27) | `features/customs_clearance/widgets/drawing_samples_and_shortage_tab.dart` |
| Tab 2 discrepancy & damage | nav 61 | `features/customs_clearance/widgets/discrepancy_and_damage_tab.dart` |
| Tab 3 final duty payment & release ledger | nav 62 | `features/customs_clearance/widgets/final_duty_payment_tab.dart` |
| CL-01..CL-05 + under-bond dialogs | header buttons and card actions | `features/customs_clearance/widgets/*_dialog.dart` |

Coverage depth:

| file | lines | depth |
|---|---|---|
| `customs_clearance/screens/customs_clearance_screen.dart` | 867 | Full |
| `customs_clearance/providers/customs_clearance_provider.dart` | 323 | Full |
| `customs_clearance/models/customs_clearance_model.dart` | 418 | Full |
| `customs_clearance/widgets/clearance_card.dart` | 249 | Full |
| `customs_clearance/widgets/final_duty_payment_tab.dart` | 462 | Full |
| `customs_clearance/widgets/drawing_samples_and_shortage_tab.dart` | 492 | Full |
| `customs_clearance/widgets/drawing_samples_dialogs.dart` | 290 | Full |
| `customs_clearance/widgets/discrepancy_and_damage_tab.dart` | 430 | 1-130 full, rest grep |
| `customs_clearance/widgets/discrepancy_protocol_dialog.dart` | 239 | Save path 200-239 + grep |
| `customs_clearance/widgets/customs_inspection_sampling_dialog.dart` | 677 | 1-275 full, rest grep |
| `customs_clearance/widgets/final_duty_assessment_dialog.dart` | 630 | 1-260 full, rest grep |
| `customs_clearance/widgets/customs_duty_payment_dialog.dart` | 491 | 1-215 full, rest grep |
| `customs_clearance/widgets/customs_final_release_dialog.dart` | 537 | 1-300 full, rest grep |
| `customs_clearance/widgets/under_bond_release_dialog.dart` | 411 | 60-200 full |
| `customs_clearance/widgets/clearance_expenses_dialog.dart` | 874 | 60-260 full, 724-760 + grep |
| `customs_clearance/widgets/clearance_screen_dialogs.dart` | 738 | Fallback payment/release dialogs 369-672 full |
| `customs_clearance/widgets/customs_ui.dart` | 452 | `CcFormat`, `statusStyle`, `channelStyle` |
| `customs_clearance/services/*_export_service.dart` (3) | 1,647 | grep (file names, save path) |
| Backend contract | — | `modules/customs_clearance/router.py` full; `schemas.py:110-160`; `service.py:430-470, 975-1200` + status strings; `validators.py:11-206`; `repository.py:50-95` |
| Docs | — | `docs/phase_07_customs_clearance.md`, `docs/phase_07/README.md`, `docs/phase_07/tasks/*` (generic templates, no extra rules) |

Rule sweep (grep) result: `Colors.` / `Color(0x` / `DropdownButtonFormField` / raw `$e` in SnackBars are gone from the
Phase-07 files (previous wave FE-02/04/06/07/08 verified fixed). Arabic literals: only 5 left in the screen (scaffold
`titleAr` props) and 5 in the discrepancy export service. Provider mutations now call `_invalidateRelated()` + `refresh()`
(FE-10 fixed). FE-01 (under-bond payload) and FE-03 (model fields) are fixed.

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 5 |
| CRITICAL | 5 |
| MAJOR | 14 |
| MINOR | 7 |

Most important points:

1. **Tabs 1 and 2 lose every record.** Drawn samples, shortage protocols and damage/discrepancy protocols live in
   `List<Map>` fields of the screen state (`customs_clearance_screen.dart:62-65`). Nothing is sent to the backend; closing
   the tab or restarting the app deletes them, and the KPIs/exports are built from that session list. There is no backend
   table for them.
2. **Official numbers are invented and saved.** CL-04 pre-fills the release permit `REL-<year>-<DB id>` and gate pass
   `GP-...`; CL-03 pre-fills SADAD `SADAD-<year>-<DB id>` and bank `NBE`; CL-01 pre-fills the sampling record
   `SMP-<year>-ALX-<random>`, a yard, an inspector name and the verdict "Conforming"; the fallback release uses
   `REL-<clearance code>`; under-bond pre-fills `BOND-EG-2026-` / `LAB-GOEIC-2026-` and the lab verdict CONFORMING.
   All pass the backend min-length checks, so one click stores fake government references.
3. **A paid or released record can be paid again, and that rolls the status back.** The ledger "Payment details" button
   opens the editable CL-03 dialog; the backend `_record_duty_payment` has no state guard and sets
   `status = "Duty Paid - Ready for Final Release"` even on a "Final Release Granted" record. Release, pay and under-bond
   buttons are never disabled by state.
4. **Large tables:** nothing is server-paged. The follow-up list is a lazy `ListView.builder` (fine), but the duty
   ledger, samples, shortage and discrepancy tables are `DataTable`s inside a page `SingleChildScrollView`: every row is
   built, the header scrolls away, no sort, no paging. Fix = `EnterpriseDataTable` now, server paging later (shared need).
5. **No View (عرض) action anywhere in Phase 07.** No detail widget exists and the provider has no `getRecord(id)`
   although `GET /customs-clearance/{id}` exists (`router.py:175`). The only way to "see" a payment or release is to open
   the editable dialog, which is exactly what causes point 3. Phase-06 task FE06-T09 creates `ClearanceDetailsDialog`;
   FE07-T09 adds the Phase-07 sections and makes paid/released rows open it read-only.

---

## 2. Findings

Paths are relative to `frontend/lib/features/customs_clearance/` unless they start with `modules/` or `frontend/`.

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| F07-01 | BLOCKER | `screens/customs_clearance_screen.dart:62-65, 827-854`; `widgets/drawing_samples_dialogs.dart:111-119, 267-277`; `widgets/drawing_samples_and_shortage_tab.dart:64-90` | Drawn samples and shortage protocols are session-only `List<Map>` in the screen state. "Save" shows a success SnackBar but nothing is persisted or linked to a clearance record / import file. Data lost on tab close or restart. Each of nav 27/60 has its own copy. | Interim (FE only): build the samples table from real records (`isSampleDrawn`, `samplingRecordNo`, `samplingDate`, `sampledRegulatoryBodies`, `goeicCertificateNo`, `sampleTestStatus`, `labTestResult`); "Add sample" opens the CL-01 dialog for a picked file. Shortage: remove the fake save, show an info state until the backend exists (FE07-T03 / T13). |
| F07-02 | BLOCKER | `widgets/discrepancy_and_damage_tab.dart:66-74`; `widgets/discrepancy_protocol_dialog.dart:208-222` | Same for damage/discrepancy protocols, including `estimated_loss_egp` money and insurance-claim status. ID `DMG-ALX-<ms>` is invented. | Interim: no fake save; read-only info state. Target: backend table + endpoints (Backend deps B3), then FE07-T13. |
| F07-03 | BLOCKER | `widgets/customs_final_release_dialog.dart:74-79, 87-92, 134-150, 333, 402`; `:62-64` | Release permit pre-filled `REL-<year>-<importFileId 4 digits>` (DB id exposed and stored as an official number), gate pass `GP-...`; "auto-generate" buttons regenerate them. Gate-out date defaults to today and `dispatch_authorized` defaults to true. | Fields start from the stored record/file value or empty; remove both generators and buttons. Gate-out date null by default (optional picker). Dispatch switch default false. |
| F07-04 | BLOCKER | `widgets/customs_duty_payment_dialog.dart:58-59, 81-85, 350` | SADAD number pre-filled `SADAD-<year>-<DB id>` (passes the backend `min_length=3`), bank defaults to `NBE`, "auto-generate" button. A fake payment reference is stored on the record and on the import file (`service.py:1036-1038`). | SADAD and bank start empty (`String? _bankName`), required validators; remove the generator. |
| F07-05 | BLOCKER | `widgets/customs_inspection_sampling_dialog.dart:53-58, 79-85, 102-106, 387, 411` | CL-01 defaults: yard `ALEXANDRIA_BERTH_42`, verdict `Conforming`, `GOEIC` pre-checked, inspector `'Joint Customs Inspection Committee'` (hard-coded English), sampling record `SMP-<year>-ALX-<rand>` with regenerate buttons. A user who only changes the date stores a conforming inspection with a fake official record. | Yard, verdict and sampled bodies start unselected with required validators (verdict + yard required; bodies required when `is_sample_drawn`). Inspector and sampling record start empty; remove the generator. |
| F07-06 | CRITICAL | `widgets/final_duty_payment_tab.dart:384-398`; `widgets/clearance_card.dart:179-188`; backend `modules/customs_clearance/service.py:1010-1031` | Pay / Release / Under-bond actions are always enabled. On a paid row the button says "Payment details" but opens the **editable** CL-03 dialog; re-submitting re-runs CL-03, which sets `status = "Duty Paid - Ready for Final Release"` even after "Final Release Granted" (no backend guard). Release can also be submitted twice. | FE: derive a `CcStage` from the record (helper in `customs_ui.dart`): Pay enabled only when assessed and not paid; Release only when fully paid, `!quarantineLock`, not released; Under-bond only when not released and not under bond. Paid/released rows open the read-only details (FE07-T09). Backend: 409 on pay after release and on a second release (B1). |
| F07-07 | CRITICAL | `widgets/under_bond_release_dialog.dart:82, 87-88, 127-133, 156-160` | Bond ref pre-filled `BOND-EG-2026-`, lab certificate `LAB-GOEIC-2026-` (year hard-coded), verdict defaults to `kLabConforming`. The only check is "not empty", so the placeholder passes. With `customs_clearance.release`, a conforming lab result can set the final release (`router.py:224-234`). | Empty controllers, verdict `null` with a required choice, `Form` + validators (min 3 chars, not equal to a prefix). Confirmation dialog before a CONFORMING submit that says it lifts the quarantine. |
| F07-08 | CRITICAL | `widgets/clearance_screen_dialogs.dart:647` | Fallback release dialog pre-fills `REL-${clearanceCode}` and has no `Form`/validator. | Empty field, `Form` + required validator (min 3). |
| F07-09 | CRITICAL | `widgets/final_duty_payment_tab.dart:109-112` | KPI "Total paid" sums `effectiveDutyTotal` (assessed) of paid rows, not `dutyPaidAmount`. "Total payable" (l.105-108) includes already paid rows. Wrong money totals on the ledger header. | Total paid = sum of `dutyPaidAmount` where paid; Outstanding = sum of `effectiveDutyTotal` where assessed and not paid; null-safe (`CcFormat.money(null)` shows "—"). |
| F07-10 | CRITICAL | `widgets/customs_inspection_sampling_dialog.dart:255-266` | The "channel" badge always shows `l.ccInsBadgeChannelValue` = "Red channel" whatever the record's channel; the declaration date falls back to **today** when `file.form46Date` is null. | Pass `clearanceRecord` to the dialog; badge = `CcUi.channelStyle(l, rec.channelType)`; date "—" when unknown. |
| F07-11 | MAJOR | `widgets/final_duty_assessment_dialog.dart:164-166`, `customs_duty_payment_dialog.dart:122-124`, `customs_final_release_dialog.dart:115-117`; backend `service.py:956-957, 1022-1024, 1161-1162` | The notes field is pre-filled with the whole `record.notes`, and the backend **appends** it again (`notes + " | Nafeza assessment: <notes>"`). Each stage roughly doubles the notes text. | Notes fields start empty (they are "notes for this step"). Show the existing record notes read-only above the field. |
| F07-12 | MAJOR | `widgets/customs_ui.dart:90-116`; `screens/customs_clearance_screen.dart:693-700`; backend `service.py:856, 958, 1093, 1121, 1259, 1311, 1373` | The Phase-07 statuses the backend writes ("Inspection & Sampling Recorded", "Customs Duties Assessed - Ready for Payment", "Duty Paid - Ready for Final Release", "Under Bond Released", "Lab Non-Conforming - Rejected", "Invoices Logged & Verified") are not in `statusStyle` or the filter: shown raw English in Arabic UI and not filterable. Filter value "Duty Requested" is never written. (Phase-06 statuses: F06-21.) | Add each status with an l10n label + severity, and to the filter. Keep "Duty Requested"/"Inspection In Progress" for legacy rows. |
| F07-13 | MAJOR | `widgets/clearance_card.dart:54`, `final_duty_payment_tab.dart:46-49, 79, 109, 358`, `screens/customs_clearance_screen.dart:369, 612-613`; backend `validators.py:11` | "Paid" is tested as `paymentStatus == 'Paid & Verified'` in 8 places; the backend also treats `"Paid"` and `"Duties Paid"` as paid. Legacy rows show as pending. | One helper `CcStatus.isPaid(record)` (set of the 3 values) in `customs_ui.dart`, used everywhere. |
| F07-14 | MAJOR | `screens/customs_clearance_screen.dart:611`; `models/customs_clearance_model.dart:255-256` | Metric "Assessed" counts `actualDutyTotal > 0`, but the model falls back to `total_duty_payable`, which is also filled before CL-02. Unassessed records are counted as assessed. | `isAssessed = nafezaClaimNumber not empty && effectiveDutyTotal > 0` (mirror `validators.is_assessed`), helper in `customs_ui.dart`. |
| F07-15 | MAJOR | `models/customs_clearance_model.dart:118, 126, 131, 163, 205, 222, 230, 235, 268, 285, 291, 310` | `fromJson` invents values for missing keys: office "Alexandria Port Customs", channel "Red Channel", inspection result "Conforming", free days 14, owner "Kamal", payment method `'Sadad / E-Finance'` (constructor says `SADAD_EFINANCE`), release type Arabic legacy label. | Missing → empty / null; free days nullable (`int?`); owner `''`; payment method `SADAD_EFINANCE`, release type `FINAL_GREEN` only if the backend default is that, else null. Update `customs_clearance_model_test.dart`. |
| F07-16 | MAJOR | `services/final_duty_payment_export_service.dart:128-147, 476-478`; `services/drawing_samples_export_service.dart:190-227, 601-603`; `services/discrepancy_and_damage_export_service.dart:120-139, 463-465` | **Still open from FE-12.** File names `<Name>_<ms>.tsv/.csv`, PDF through `Printing.layoutPdf` (print dialog, no Save-As), "Excel" button writes CSV. Violates Task I. | Route through `FileSaveHelper.exportAndSaveFile` with `stageName` "Customs Duty Ledger" / "Customs Samples" / "Customs Discrepancies" and `importFileNameOrCode` "Registry" (or file code when filtered to one file). Excel via `TableExportService.exportTableToExcel` (as the hub does at `customs_clearance_screen.dart:327-336`). |
| F07-17 | MAJOR | `widgets/clearance_card.dart:87-128` | Card shows nothing about under-bond / quarantine lock / lab result (`isUnderBondRelease`, `quarantineLock`, `labTestResult` are parsed but used nowhere in the UI). | Add chips: "Under bond" (warning), "Quarantine lock" (danger), lab result (success/danger). |
| F07-18 | MAJOR | (missing feature) `docs/phase_07_customs_clearance.md` BP-029 | No free-time counter / demurrage early warning. `deliveryOrderExpiry`, `portArrivalDate`, `freeDaysAllowed` are never used in the UI (grep: only the clone draft). | Card + ledger chip "Free time: N days left" from `deliveryOrderExpiry` (else `portArrivalDate + freeDaysAllowed`); warning ≤ 3 days, danger when expired; hidden after release. Pure function + test. |
| F07-19 | MAJOR | `widgets/final_duty_assessment_dialog.dart` (no `SmartUploadButton`) vs `widgets/clearance_screen_dialogs.dart:209-214` | BP-030 smart Nafeza extraction exists only in the generic edit form, not in the CL-02 assessment dialog where the claim is entered. | Add `SmartUploadButton(module: SmartUploadModule.customsClearance)` to the CL-02 dialog header; map extracted fields into the CL-02 controllers (move `_applyExtractedNafezaData` mapping to a shared function). |
| F07-20 | MAJOR | `screens/customs_clearance_screen.dart:500-523` | Header CL-02/CL-03/CL-04/CL-05 buttons open the dialog without `clearanceRecord`, so no prefill (estimate, assessed total, stored SADAD) and no variance. File choice is `files.first` (covered by FE06-T04). | After FE06-T04 picks the file, look up the active record of that file in `customsClearanceProvider` and pass it as `clearanceRecord`. |
| F07-21 | MAJOR | `widgets/clearance_expenses_dialog.dart:72, 159-176` | CL-05 invoices are EGP only (`final String _currency = 'EGP'`, `exchange_rate: 1.0` hard-coded). Shipping-line / port invoices in USD cannot be entered correctly. Provider is free text (`_providerNameController`) instead of a partner FK. | Currency from master data (`SearchableDropdownField`), exchange rate required (no default) when currency ≠ EGP, `amount_fx` and `amount_egp` separate; provider via partners `SearchableDropdownField<int>` (keep the name text for legacy). VAT-included semantics: open Q2 of the previous plan. |
| F07-22 | MAJOR | `widgets/final_duty_payment_tab.dart:405`; `screens/customs_clearance_screen.dart:295` | Ledger and exports show `channelType` raw ("Red Channel") in Arabic UI. | `CcUi.channelStyle(l, r.channelType).label`. |
| F07-23 | MAJOR | `widgets/drawing_samples_dialogs.dart:51, 53` | Sample dialog pre-fills authority and test type from l10n defaults (`ccSampleDefaultAuthority`, `ccSampleDefaultTestType`): invented data. | Fixed by FE07-T03 (dialog replaced by CL-01). |
| F07-24 | MAJOR | `widgets/final_duty_payment_tab.dart:307-326`, `drawing_samples_and_shortage_tab.dart:335-391, 424-487`, `discrepancy_and_damage_tab.dart:305-307` | Large tables: `DataTable` in a vertical `SingleChildScrollView`; all rows built, header not sticky, no sort, no paging, no column widths. | `EnterpriseDataTable` (see §3). |
| F07-25 | MINOR | `widgets/clearance_screen_dialogs.dart:393-394, 431` | Fallback payment pre-fills the paid amount with the assessed total and sends it as `actual_duty_total` (legacy key) instead of `duty_paid_amount`. | Field empty with hint "assessed: X"; send `duty_paid_amount`. |
| F07-26 | MINOR | `widgets/under_bond_release_dialog.dart:121-126` | Raw `SnackBar(backgroundColor: color)` instead of `AppTheme.snackBar(..., severity:)`. | Use `AppTheme.snackBar`. |
| F07-27 | MINOR | `widgets/drawing_samples_dialogs.dart:271-273` | Quantities rounded with `toStringAsFixed(0)` (2.5 tons → 3). | Moot after FE07-T03; keep decimals in T13. |
| F07-28 | MINOR | `screens/customs_clearance_screen.dart:539` | `stageCode: 'PHASE-5'` on the Phase-7 hub. | Use the lifecycle stage code that `VerticalStageScaffold` expects for Phase 7 (check `stage_lifecycle_controls`); if the hub intentionally spans 5-7, add a comment. |
| F07-29 | MINOR | `widgets/final_duty_payment_tab.dart:142, 422`; `clearance_card.dart:57` | Variance warning threshold `500` EGP hard-coded in 3 places (F06-30 for the card). | One named constant in `customs_ui.dart` (or percentage, Q4 of Phase 06). |
| F07-30 | MINOR | `widgets/final_duty_payment_tab.dart:224` | Row count `filtered / total` exists only in the ledger; the follow-up list shows no count (F06 §3). | Covered by FE06-T18. |
| F07-31 | MINOR | `widgets/clearance_expenses_dialog.dart:755` | Invoice list is a `Column` of cards (all built). Per-file count is small, so OK; there is no edit (no backend PUT) and no export of the invoices. | Leave; add export with the CL-05 summary later (Q). |

Re-checked items from `docs/plans/phase-06-07-quality-plan.md`: FE-01 fixed (`provider:299-322`), FE-02 fixed
(`final_duty_assessment_dialog.dart:115-125` no FX default; expenses VAT/WHT manual), FE-03 fixed (model l.96-102),
FE-04 fixed for Phase-07 files (`SearchableDropdownField` in expenses, payment), FE-06/07 fixed (ApiErrorText everywhere),
FE-10 fixed. **FE-12 still open** (F07-16).

---

## 3. Large tables

Context: no endpoint of `modules/customs_clearance` pages (`repository.py:50-73` returns `.all()`). The only server-paged
pattern in the backend is `GET /import-files/paginated` (`modules/import_files/schemas.py:374`). `EnterpriseDataTable`
(`frontend/lib/core/widgets/enterprise_data_table/enterprise_data_table.dart`) pages/sorts/resizes client-side.

| List | Today | Evidence | Recommended |
|---|---|---|---|
| Follow-up records (tab 0) | Lazy `ListView.builder` of cards; full list from `GET /customs-clearance`; client search/filter. | `customs_clearance_screen.dart:783-809`; provider `:69-81` | Owned by Phase 06: FE06-T10 (server search) + FE06-T18 (count, sort, paging). |
| Final duty ledger (tab 3) | `DataTable` inside `SingleChildScrollView(horizontal)` inside the page `SingleChildScrollView`: all rows built, header scrolls away, no sort, no paging, fixed font widths; filter chips + client search; KPIs over the loaded list; exports the filtered list. | `final_duty_payment_tab.dart:146-151, 301-327` | `EnterpriseDataTable<CustomsClearanceModel>` with columns code / file code / decl 46 / office / channel / assessed / paid / variance / payment status / receipt / permit / free time / actions; sticky header, sort, page size 25/50/100, column widths. Actions column: View, Pay (gated), Release (gated). Phase B: server paging when B2 exists; exports call the API without paging. |
| Drawn samples (tab 1) | `DataTable`, all rows, session data only. | `drawing_samples_and_shortage_tab.dart:335-391` | After FE07-T03 rows come from records with `isSampleDrawn` (one row per record) → `EnterpriseDataTable`, client paging is enough (one row per shipment). |
| Shortage protocols (tab 1) | `DataTable`, all rows, session data only. | same file `:424-487` | After backend B3: `EnterpriseDataTable` with server filter by file. |
| Discrepancy protocols (tab 2) | `DataTable`, all rows, session data only. | `discrepancy_and_damage_tab.dart:305-307` | Same as shortage. |
| CL-05 invoices per file | `Column` of cards inside the dialog. | `clearance_expenses_dialog.dart:724-756` | OK (tens per file). |
| Import-file pickers | `SearchableDropdownField` over the full `importFilesProvider`. | `clearance_screen_dialogs.dart:229-243` | OK for now; server-search picker is a cross-phase shared need. |

Shared need (same as Phase 06): `ServerPagedNotifier<T>` + server mode in `EnterpriseDataTable`.

---

## 4. View / Show action

| Entity | View exists? | Why not (code reason) | What to add |
|---|---|---|---|
| Clearance record (hub card) | No. Card actions: edit, copy, clone, under-bond, pay, release, expenses (`clearance_card.dart:169-190`). | No detail widget; provider has no `getRecord(id)` though `GET /customs-clearance/{id}` exists (`router.py:175-181`). Edit dialog shows ~12 fields and never PUTs (F06-08). | FE06-T09 creates `ClearanceDetailsDialog` (Phase-06 sections). FE07-T09 adds the Phase-07 sections: inspection & sampling, lab / under-bond, assessment components + variance, payment (SADAD, receipt, bank, amount, date), release (permit, gate pass, officer, gate-out, dispatch, demurrage), invoices summary. |
| Duty ledger row (tab 3) | No. "Payment details" opens the editable CL-03 dialog (`final_duty_payment_tab.dart:384-390`). | Same; the editable dialog is reused as a viewer. This is the root of F07-06. | View icon first in the actions cell → `ClearanceDetailsDialog` (payment section). Paid rows: the pay button becomes View. |
| Payment (CL-03) / release (CL-04) | No. | Data only on the record; no read-only rendering. | Sections in the details dialog; the CL-04 dialog opens read-only when released. |
| Drawn sample | No (row only). | Session map, no entity. | After FE07-T03 the sample row = record → View opens the details dialog on the inspection section. |
| Shortage / discrepancy protocol | No. | Session map, no backend entity. | After B3: View dialog per protocol (FE07-T13). |
| Clearance invoice (CL-05) | Partial: card shows the main fields; no notes/allocation detail popover. | Fields fit on the card. | Not needed now. |

---

## 5. Tasks

Order = priority. Phase-06 tasks referenced: FE06-T04 (file picker), FE06-T05 (edit PUT), FE06-T09 (details dialog),
FE06-T10 (status/shipment code/server search), FE06-T18 (large tables on the hub). Files in the same feature: run
FE06 tasks that touch the same file first, or rebase.

Common test setup: widget tests pump the dialog inside `ProviderScope` + `MaterialApp(localizationsDelegates: ...)`
as the existing `frontend/test/cl0*_test.dart` do; read those files first and copy their harness.

### FE07-T01: CL-03 / CL-04 dialogs stop inventing payment and release references

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_duty_payment_dialog.dart`,
  `frontend/lib/features/customs_clearance/widgets/customs_final_release_dialog.dart`,
  `frontend/lib/features/customs_clearance/widgets/clearance_screen_dialogs.dart` (fallback release only),
  `frontend/test/cl03_customs_duty_payment_test.dart`, `frontend/test/cl04_customs_final_release_test.dart`
- **Steps:**
  1. Payment dialog `initState` (l.80-85): SADAD = `rec?.sadadNumber ?? file.customsDutySadadNo ?? ''`; delete the
     `SADAD-...` fallback. Remove the auto-generate icon button (tooltip `ccDutyAutoGenerate`, ~l.345-355).
  2. `String _bankName = 'NBE'` → `String? _bankName`; the bank `SearchableDropdownField` gets `isRequired: true` and a
     validator; payload sends `_bankName!` only after validation.
  3. SADAD field validator: required, trimmed length ≥ 3.
  4. Release dialog `initState` (l.74-92): permit = stored value or `''`; gate pass = stored value or `''`. Delete
     `_generatePermitNumber` and `_generateGatePassNumber` (l.134-150) and their buttons (l.333, l.402).
  5. `DateTime? _portGateOutDate = DateTime.now()` → `null` unless the record/file has one; payload sends null when
     unset. `_dispatchAuthorized = true` → `false` unless `rec?.dispatchAuthorized == true`.
  6. Demurrage field: empty when the record has no value (not `'0.00'`); parse empty as `0.0` only at submit
     (backend accepts 0); add hint text.
  7. Fallback release dialog (`clearance_screen_dialogs.dart:647`): `_releaseNoCtrl.text = record.releasePermitNo ?? ''`;
     wrap the field in a `Form` with required validator (min 3); `_submit` returns early when invalid.
- **Acceptance criteria:**
  - [ ] Opening CL-03 for a file with no stored SADAD shows an empty SADAD field and no bank selected.
  - [ ] Submitting without SADAD or bank shows red validator text, no API call.
  - [ ] Opening CL-04 for a file with no permit shows empty permit and gate-pass fields; no generate buttons exist.
  - [ ] Gate-out date is empty and dispatch is off by default.
  - [ ] No text containing the import file DB id appears in any field.
- **Tests to add:** in `frontend/test/cl03_customs_duty_payment_test.dart`: pump `CustomsDutyPaymentDialog` with an
  `ImportFileModel` without SADAD → `expect(find.textContaining('SADAD-'), findsNothing)`; tap submit → validator text
  visible. In `cl04_customs_final_release_test.dart`: `find.textContaining('REL-')` and `'GP-'` findsNothing; no widget with
  tooltip `ccRelGenerate*`. Fallback: `customs_clearance_fallback_dialogs_test.dart` empty permit → submit shows validator.
- **Out of scope:** state gating of the buttons (FE07-T04), notes (FE07-T06).

### FE07-T02: CL-01 inspection dialog without invented verdict, yard and record number

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** none | **Backend needed:** no (payload `CustomsInspectionSamplingSubmit`, `modules/customs_clearance/schemas.py:110-124`)
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_inspection_sampling_dialog.dart`,
  `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart` (pass the record),
  l10n (`frontend/lib/core/localization/app_localizations.dart`, `_ar.dart`, `_en.dart`),
  `frontend/test/cl01_inspection_sampling_test.dart`
- **Steps:**
  1. Add optional `CustomsClearanceModel? clearanceRecord` to `CustomsInspectionSamplingDialog` and its `show(...)`.
  2. Defaults (l.53-58): `_selectedYard`, `_selectedResult` → `String?` null; `_selectedSampledBodies` → `{}`; prefill
     from `clearanceRecord` when present (`inspectionYard`, `inspectionResult`, `sampledRegulatoryBodies`,
     `samplingRecordNo`, `inspectorName`, `goeicCertificateNo`, dates).
  3. Inspector controller (l.79-81): empty (or record value). Sampling record (l.84-86): empty (or record value). Delete
     `_generateSamplingRecordNo` (l.102-106) and the buttons at ~l.387 and ~l.411.
  4. Validators: yard required, verdict required, at least one sampled body when `_isSampleDrawn`, sampling record
     required (min 3) when `_isSampleDrawn`. New l10n keys `ccInsYardRequired`, `ccInsResultRequired`,
     `ccInsBodiesRequired`, `ccInsSamplingNoRequired` (AR + EN).
  5. Channel badge (l.255-260): `CcUi.channelStyle(l, clearanceRecord?.channelType ?? '')` label; show "—" when no
     record. Date badge (l.261-266): `file.form46Date` else "—" (never today).
  6. In the screen, card/ledger paths that know the record pass it (header path handled in FE07-T08).
- **Acceptance criteria:**
  - [ ] New inspection: yard, verdict and bodies unselected; record no. and inspector empty; no regenerate buttons.
  - [ ] Submit with nothing chosen → red validator messages, no API call.
  - [ ] Opening for a record with a Green channel shows the Green chip; with no record shows "—".
  - [ ] Re-opening for an inspected record shows the stored values.
- **Tests to add:** `frontend/test/cl01_inspection_sampling_test.dart`: pump the dialog with a file and no record →
  `find.textContaining('SMP-')` findsNothing, `find.text('Joint Customs Inspection Committee')` findsNothing; tap submit →
  `find.text(l.ccInsResultRequired)` findsOneWidget. Pump with a record `channel_type: 'Green Channel'` → finds
  `l.customsClearanceChannelGreen`.
- **Out of scope:** BP-029 free-time counter (FE07-T10).

### FE07-T03: Samples tab shows real data; no session-only saves

- **Severity:** BLOCKER | **Type:** bug | **Depends on:** FE07-T02 (dialog accepts a record), FE06-T04 (file picker helper) | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/drawing_samples_and_shortage_tab.dart`,
  `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart`,
  `frontend/lib/features/customs_clearance/services/drawing_samples_export_service.dart`,
  l10n files, new `frontend/test/features/customs_clearance/drawing_samples_tab_test.dart`
- **Steps:**
  1. Screen: delete `_drawnSamples`, `_shortageProtocols` (l.62-64) and the `onAddSample/onAddShortage` callbacks
     (l.833-838). Pass only `records` to the tab.
  2. Tab: samples = `records.where((r) => r.isSampleDrawn)`. Columns: sampling record no., file code (resolve by
     `importFileId` via `importFilesProvider`, never `IMP-<id>`), sampled bodies (localized with `DomainEnums` if a type
     exists, else raw code), sampling date, GOEIC cert, test status (`sampleTestStatus`), lab result (`labTestResult`).
     Status filter: ALL / PENDING (`sampleTestStatus == 'Samples Under Testing'` or `labTestResult == 'PENDING'`) /
     PASSED (`labTestResult == 'CONFORMING'` or `sampleTestStatus == 'Approved'`) / REJECTED.
  3. "Add sample" button → pick a file (FE06-T04 picker) → `CustomsInspectionSamplingDialog.show(context, file,
     clearanceRecord: activeRecordOf(file))`. Stop calling `showAddSampleDialog`; delete it from
     `drawing_samples_dialogs.dart` (keep the file only if the shortage dialog stays).
  4. Shortage section: remove "Add shortage" button and the session table; show `CcStateView.empty` with new l10n text
     `ccShortageNotAvailable` ("Shortage protocols will be saved after the backend registry is added") until FE07-T13.
  5. Export service: build rows from `CustomsClearanceModel` instead of maps (and fix naming in FE07-T11 if not done).
  6. KPIs: total / passed / pending computed from the same list; shortage KPI removed until T13.
- **Acceptance criteria:**
  - [ ] After recording CL-01 with "sample drawn", the row appears in tab 1 after refresh and survives app restart.
  - [ ] No "Saved" SnackBar appears for data that is not stored.
  - [ ] File column shows the real import-file code.
- **Tests to add:** `frontend/test/features/customs_clearance/drawing_samples_tab_test.dart`: pump the tab with 2
  records (one `is_sample_drawn: true, sampling_record_no: 'R-1'`, one false) → `find.text('R-1')` findsOneWidget, total KPI
  `'1'`; no widget with label `customsClearanceAddSampleButton` calls a local insert (assert the dialog type opened is
  `CustomsInspectionSamplingDialog` using a fake file list).
- **Out of scope:** persisted shortage protocols (FE07-T13).

### FE07-T04: Gate Pay / Release / Under-bond by state; paid and released rows are read-only

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** FE06-T09 (details dialog exists) | **Backend needed:** yes, B1 (409 on pay after release and on a second release) — FE gating works without it
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_ui.dart`,
  `frontend/lib/features/customs_clearance/widgets/clearance_card.dart`,
  `frontend/lib/features/customs_clearance/widgets/final_duty_payment_tab.dart`,
  `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart`,
  new `frontend/test/features/customs_clearance/cc_stage_test.dart`
- **Steps:**
  1. In `customs_ui.dart` add `class CcStatus` with pure static functions:
     `isPaid(r)` (paymentStatus in {'Paid & Verified','Paid','Duties Paid'} — mirrors `modules/customs_clearance/validators.py:11`),
     `isAssessed(r)` (`(r.nafezaClaimNumber ?? '').isNotEmpty && (r.effectiveDutyTotal ?? 0) > 0`),
     `isReleased(r)` (`r.status == 'Final Release Granted' || (r.releasePermitNo ?? '').isNotEmpty`),
     `canPay(r) = isAssessed && !isPaid && !isReleased`, `canRelease(r) = isPaid && !r.quarantineLock && !isReleased`,
     `canUnderBond(r) = !isReleased && !r.isUnderBondRelease`, `canRecordLab(r) = r.isUnderBondRelease && r.quarantineLock`.
  2. Replace every `== 'Paid & Verified'` in the feature (card l.54, ledger l.46-49, 79, 109, 113, 358; screen l.369,
     612-613) with `CcStatus.isPaid`. Metric "Assessed" (screen l.611) uses `CcStatus.isAssessed`.
  3. Card: pass `null` (disabled `IconButton`) for pay/release/under-bond when not allowed; tooltip explains why
     (new l10n keys `ccActionNeedsAssessment`, `ccActionNeedsPayment`, `ccActionQuarantineLocked`, `ccActionAlreadyReleased`).
     Under-bond icon opens lab mode when `canRecordLab`.
  4. Ledger actions cell (l.384-398): when paid or released, the first button is "View" → `ClearanceDetailsDialog`
     (FE06-T09); Pay button only when `canPay`; Release only when `canRelease`.
  5. `ClearanceCardActions` gets `onView` (first icon, `Icons.visibility_outlined`), wired to the details dialog.
- **Acceptance criteria:**
  - [ ] On a released record, Pay, Release and Under-bond are disabled with a tooltip; View opens a read-only dialog.
  - [ ] On an unassessed record, Pay is disabled ("assess first").
  - [ ] On a quarantine-locked record, Release is disabled.
  - [ ] A legacy record with payment status "Paid" shows as paid.
- **Tests to add:** `frontend/test/features/customs_clearance/cc_stage_test.dart`: table-driven unit tests for each
  `CcStatus` function (unassessed / assessed-unpaid / paid / paid+quarantine / released / legacy "Duties Paid").
  Widget test in `frontend/test/customs_clearance_test.dart`: card for a released record → the pay `IconButton`
  (`Key('payDutyBtn_<code>')`) has `onPressed == null`.
- **Out of scope:** backend guards (B1).

### FE07-T05: Under-bond / lab dialog without placeholders or a default verdict

- **Severity:** CRITICAL | **Type:** bug | **Depends on:** none | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/under_bond_release_dialog.dart`, l10n files,
  `frontend/test/features/customs_clearance_under_bond_test.dart`
- **Steps:**
  1. `_bondRefController` and `_labCertController` (l.82, 87) start empty.
  2. `String _labVerdict = kLabConforming` → `String? _labVerdict`; radio group without selection; required.
  3. Wrap both modes in `Form` with `GlobalKey<FormState>`; validators: bond ref required min 3, warehouse location
     required, lab certificate required min 3, verdict required. Remove the manual empty checks (l.127-131, 156-159).
  4. Before submitting a CONFORMING verdict show a confirm dialog (new l10n `underBondConfirmLiftTitle/Body`: "This lifts
     the quarantine lock and may finalize the release").
  5. `_snack` (l.121-126) → `AppTheme.snackBar(context, text, severity: ...)`.
- **Acceptance criteria:**
  - [ ] Dialog opens with empty references and no verdict selected.
  - [ ] Submit with empty fields shows red validator texts.
  - [ ] CONFORMING asks for confirmation; cancelling sends nothing.
- **Tests to add:** in `frontend/test/features/customs_clearance_under_bond_test.dart`: pump in lab mode →
  `find.textContaining('LAB-GOEIC-')` findsNothing; tap submit → validator text; select CONFORMING + fill → confirm dialog
  visible (`find.text(l.underBondConfirmLiftTitle)`). Keep the existing payload-builder tests.
- **Out of scope:** backend lab rules.

### FE07-T06: Stage notes do not duplicate the record notes

- **Severity:** MAJOR | **Type:** bug | **Depends on:** FE07-T01 (same files) | **Backend needed:** no (backend append behaviour stays; see Q3)
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/final_duty_assessment_dialog.dart`,
  `frontend/lib/features/customs_clearance/widgets/customs_duty_payment_dialog.dart`,
  `frontend/lib/features/customs_clearance/widgets/customs_final_release_dialog.dart`, l10n files,
  `frontend/test/cl02_final_duty_assessment_test.dart`
- **Steps:**
  1. Notes controllers (assessment l.164-166, payment l.122-124, release l.115-117) start empty.
  2. Above each notes field, when `rec?.notes` is not empty, show a read-only, collapsible box "Previous notes"
     (new l10n `ccPreviousNotesLabel`) with `SelectableText(rec.notes)`.
  3. Label the field "Notes for this step" (new l10n `ccStepNotesLabel`).
- **Acceptance criteria:**
  - [ ] Opening any of the three dialogs on a record with notes shows them read-only and an empty notes field.
  - [ ] Saving without typing notes sends `assessment_notes` / `payment_notes` / `notes` = null.
- **Tests to add:** `frontend/test/cl02_final_duty_assessment_test.dart`: pump with a record `notes: 'N1'` → the notes
  `TextFormField` controller text is `''` and `find.text('N1')` finds the read-only box.
- **Out of scope:** cleaning already-duplicated notes in the DB.

### FE07-T07: Phase-07 statuses, channel labels and paid/assessed helpers in all views

- **Severity:** MAJOR | **Type:** bug | **Depends on:** FE06-T10 (adds Phase-06 statuses in the same switch), FE07-T04 (helpers) | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_ui.dart`,
  `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart`,
  `frontend/lib/features/customs_clearance/widgets/final_duty_payment_tab.dart`, l10n files,
  `frontend/test/customs_clearance_localization_test.dart`
- **Steps:**
  1. `CcUi.statusStyle` (l.90-116): add cases with new l10n labels and severities:
     "Inspection & Sampling Recorded" (info), "Customs Duties Assessed - Ready for Payment" (warning),
     "Duty Paid - Ready for Final Release" (info), "Duty Paid" (info, exists), "Under Bond Released" (warning),
     "Lab Non-Conforming - Rejected" (danger), "Invoices Logged & Verified" (info). Strings come from
     `modules/customs_clearance/service.py:856, 958, 1093, 1121, 1259, 1311, 1373`.
  2. Status filter (screen l.693-700): add the same values; keep legacy "Duty Requested".
  3. Ledger channel cell (l.405) and the hub export row (screen l.295): `CcUi.channelStyle(l, r.channelType).label`.
  4. Ledger KPIs (l.105-117): Total paid = sum `dutyPaidAmount` of `CcStatus.isPaid`; Outstanding = sum
     `effectiveDutyTotal` of `isAssessed && !isPaid`; Net variance only over rows with `estimatedDutyTotal > 0`; rename
     the first KPI label to "Outstanding" (new key `finalDutyKpiOutstanding`).
  5. Variance threshold 500 → `CcUi.varianceWarnThresholdEgp` constant (l.142, 422; card l.57).
- **Acceptance criteria:**
  - [ ] In Arabic UI no English status or channel text appears in cards, ledger or exports.
  - [ ] Filtering by "Assessed - Ready for Payment" shows only those records.
  - [ ] KPI "Total paid" equals the sum of paid amounts, not of assessed totals.
- **Tests to add:** `frontend/test/customs_clearance_localization_test.dart`: for each of the 7 status strings,
  `CcUi.statusStyle(arL10n, s).label != s`. New unit test in `frontend/test/features/customs_clearance/final_duty_kpis_test.dart`
  if the KPI math is extracted to a pure function `FinalDutyKpis.from(records)` (recommended): paid 1000 vs assessed 1200 →
  totalPaid 1000.
- **Out of scope:** T3 enum codes for statuses (backend Q7 of the previous plan).

### FE07-T08: Header stage buttons and CL-02 pass the clearance record; smart Nafeza extraction in CL-02

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T04 (file picker in `_openStage`) | **Backend needed:** no (`SmartUploadModule.customsClearance` exists)
- **Files to change:** `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart`,
  `frontend/lib/features/customs_clearance/widgets/final_duty_assessment_dialog.dart`,
  `frontend/lib/features/customs_clearance/widgets/clearance_screen_dialogs.dart` (extract the mapping),
  new `frontend/lib/features/customs_clearance/widgets/nafeza_extraction_mapper.dart`,
  `frontend/test/cl02_final_duty_assessment_test.dart`
- **Steps:**
  1. In the screen add `CustomsClearanceModel? _activeRecordFor(int importFileId)` = first record in
     `customsClearanceProvider` with that `importFileId` and `isActive`.
  2. Header buttons CL-01 (l.494-499), CL-02 (l.500-505), CL-03 (l.506-511), CL-04 (l.512-517), CL-05 (l.518-523):
     call `.show(context, f, clearanceRecord: _activeRecordFor(f.importFileId))` (CL-01 after FE07-T02).
  3. Move the field mapping of `_applyExtractedNafezaData` (clearance_screen_dialogs.dart) to a pure function
     `NafezaExtractionMapper.toAssessmentFields(Map<String, dynamic>)` returning a typed record (claim no., CIF, rate,
     duty, VAT, schedule, dev fee, service fees, WHT, lab fees). The edit form keeps using it.
  4. CL-02 dialog header: `SmartUploadButton(module: SmartUploadModule.customsClearance, compact: true, onDataExtracted:
     ...)` filling the controllers; numbers never overwrite a field with null; exchange rate stays empty if not extracted.
- **Acceptance criteria:**
  - [ ] Opening CL-03 from the header for a file with an assessed record pre-fills the amount and shows the summary.
  - [ ] In CL-02 the user can upload a Nafeza claim and the fields are filled; the user still confirms with Save.
- **Tests to add:** `frontend/test/features/customs_clearance/nafeza_extraction_mapper_test.dart`: map a sample
  extracted JSON → expected doubles; missing keys → null (not 0). CL-02 widget test: dialog contains a `SmartUploadButton`.
- **Out of scope:** backend extraction quality.

### FE07-T09: Phase-07 sections in the read-only details dialog

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE06-T09 (`ClearanceDetailsDialog` + `getRecord(id)`) | **Backend needed:** no (`GET /customs-clearance/{id}`)
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/clearance_details_dialog.dart` (created by FE06-T09),
  `frontend/lib/features/customs_clearance/providers/customs_clearance_provider.dart` (only if `fetchClearanceInvoices`
  needs a summary call from the dialog), l10n files,
  `frontend/test/features/customs_clearance/clearance_details_dialog_test.dart`
- **Steps:**
  1. Add sections (read-only `CcFact` rows, "—" for null): **Inspection & sampling** (date, type, yard label, inspector,
     result, sample drawn, sampling record, sampled bodies, GOEIC cert, test status, lab fees);
     **Under bond / lab** (under bond, bond ref, quarantine lock, lab result, certificate, lifted date/by);
     **Assessment** (Nafeza claim no./date, CIF, customs rate, 7 components, total, estimated, variance amount/%/reason);
     **Payment** (status, SADAD, receipt, bank label via `DomainEnums`, method label, paid amount, date, receipt URL);
     **Release** (permit, date, type label, officer, gate pass, gate-out, demurrage, dispatch, instructions);
     **Clearance invoices** (count + the 3 totals `totalClearanceExpensesEgp` / `totalPortExpensesEgp` /
     `totalHandlingExpensesEgp`).
  2. Each section header has a copy icon (`CopyHelper`), the dialog has Print/PDF via `FileSaveHelper.exportAndSaveFile`
     (`stageName: 'Customs Clearance'`, file code).
  3. Add an `initialSection` parameter so the ledger "View" opens scrolled to Payment.
- **Acceptance criteria:**
  - [ ] From a paid ledger row, View shows the SADAD, receipt, bank and amount, with no editable field.
  - [ ] Unknown money values show "—", not 0.00.
- **Tests to add:** `clearance_details_dialog_test.dart`: fake notifier returns a record with `sadad_number: 'S-1'`,
  `release_permit_no: 'P-1'`, `lab_test_result: 'CONFORMING'` → texts found; `find.byType(TextFormField)` findsNothing.
- **Out of scope:** editing from the dialog.

### FE07-T10: Free-time counter and quarantine chips on cards and ledger (BP-029)

- **Severity:** MAJOR | **Type:** feature | **Depends on:** FE07-T04 | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/customs_ui.dart`,
  `frontend/lib/features/customs_clearance/widgets/clearance_card.dart`,
  `frontend/lib/features/customs_clearance/widgets/final_duty_payment_tab.dart`, l10n files,
  new `frontend/test/features/customs_clearance/free_time_test.dart`
- **Steps:**
  1. Pure function `CcFreeTime.daysLeft(CustomsClearanceModel r, DateTime today)`: if released → null; if
     `deliveryOrderExpiry` parses → days until it; else if `portArrivalDate` parses and `freeDaysAllowed > 0` → arrival +
     free days − today; else null.
  2. Chip: null → hidden; > 3 → info "N days free time left"; 0..3 → warning; < 0 → danger "Free time expired N days ago"
     (l10n with plural-safe placeholders).
  3. Card: add the free-time chip plus "Under bond" (warning) when `isUnderBondRelease`, "Quarantine lock" (danger) when
     `quarantineLock`, lab result chip when `labTestResult` is CONFORMING/NON_CONFORMING.
  4. Ledger: add a "Free time" column using the same chip.
- **Acceptance criteria:**
  - [ ] A record whose D/O expires in 2 days shows an orange chip on the card and in the ledger.
  - [ ] Released records show no free-time chip.
  - [ ] A record under bond shows the quarantine chip.
- **Tests to add:** `free_time_test.dart`: expiry today+5 → 5; expiry today−2 → −2; no dates → null; released → null;
  arrival + 14 free days.
- **Out of scope:** notifications / smart tasks for demurrage (backend).

### FE07-T11: Phase-07 exports through FileSaveHelper with the naming rule (still open from FE-12)

- **Severity:** MAJOR | **Type:** refactor | **Depends on:** FE07-T03 (samples rows from records) | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/services/final_duty_payment_export_service.dart`,
  `frontend/lib/features/customs_clearance/services/drawing_samples_export_service.dart`,
  `frontend/lib/features/customs_clearance/services/discrepancy_and_damage_export_service.dart`,
  `frontend/test/customs_export_service_test.dart`
- **Steps:**
  1. Replace `FileSaveHelper.saveText(defaultFileName: '<Name>_<ms>.tsv')` with
     `FileSaveHelper.exportAndSaveFile(context:, bytes: utf8.encode('﻿' + tsv), stageName:, importFileNameOrCode:, extension: 'tsv')`.
     Stage names: "Customs Duty Ledger", "Customs Samples", "Customs Discrepancies"; file part "Registry" (or the single
     file code when all rows share one `importFileId`).
  2. Replace `Printing.layoutPdf(...)` (final l.476, samples l.601, discrepancy l.463) with
     `final bytes = await doc.save(); FileSaveHelper.exportAndSaveFile(..., extension: 'pdf')`.
  3. The "Excel" buttons: either produce xlsx via `TableExportService.exportTableToExcel` (preferred, already used at
     `customs_clearance_screen.dart:327-336`) or relabel to "CSV".
  4. Move the 5 Arabic literals in `discrepancy_and_damage_export_service.dart` to l10n.
- **Acceptance criteria:**
  - [ ] Every export opens a Save-As dialog; suggested name is `Customs Duty Ledger - Registry.pdf` style; no millisecond names.
  - [ ] The "Excel" button produces an `.xlsx` (or is labelled CSV).
- **Tests to add:** `frontend/test/customs_export_service_test.dart`: `FileSaveHelper.buildExportFileName(stageName:
  'Customs Duty Ledger', importFileNameOrCode: 'Registry', extension: 'pdf')` equals the expected string; grep-style test
  that the three services contain no `millisecondsSinceEpoch` (read the source file as text).
- **Out of scope:** export content redesign.

### FE07-T12: CL-05 invoices in foreign currency and with a partner picker

- **Severity:** MAJOR | **Type:** feature | **Depends on:** none (Q2 for VAT semantics) | **Backend needed:** no (`exchange_rate` optional and required for non-EGP already, previous plan contract change 6)
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/clearance_expenses_dialog.dart`, l10n files,
  `frontend/test/cl05_clearance_invoices_test.dart`
- **Steps:**
  1. `final String _currency = 'EGP'` → `String _currency` chosen from the currencies master provider (the same one
     used in Phase 06 FE06-T14) with `SearchableDropdownField<String>`.
  2. When currency ≠ EGP: show `amount_fx` and `exchange_rate` fields (rate empty, required, > 0) and compute
     `amount_egp = round(fx * rate, 2)` for display; payload sends `amount_fx`, `exchange_rate`, and `amount_egp: 0` to let
     the backend compute (backend formula `service.py` CL-05) — or the computed value, consistent with backend rule.
     When EGP: `exchange_rate` omitted (not 1.0).
  3. Provider: `SearchableDropdownField<int>` over partners (all active partners; name stored in `provider_name`),
     with "other (free text)" fallback for legacy.
- **Acceptance criteria:**
  - [ ] A USD port invoice can be entered with an explicit rate; saving without a rate shows a validator.
  - [ ] An EGP invoice payload has no `exchange_rate: 1.0`.
- **Tests to add:** `frontend/test/cl05_clearance_invoices_test.dart`: build the payload through an extracted pure
  `buildInvoicePayload(...)` → USD case contains rate; EGP case has no `exchange_rate` key.
- **Out of scope:** invoice edit (no backend PUT), VAT-inclusive math (Q2).

### FE07-T13: Persisted shortage and damage/discrepancy protocols

- **Severity:** MAJOR | **Type:** feature | **Depends on:** backend B3, FE07-T03 | **Backend needed:** yes: B3 (`/customs-clearance/{id}/cargo-discrepancies` CRUD with soft delete)
- **Files to change:** new `frontend/lib/features/customs_clearance/models/cargo_discrepancy_model.dart`,
  `frontend/lib/features/customs_clearance/providers/customs_clearance_provider.dart` (or a new
  `cargo_discrepancies_provider.dart`), `frontend/lib/features/customs_clearance/widgets/discrepancy_and_damage_tab.dart`,
  `frontend/lib/features/customs_clearance/widgets/discrepancy_protocol_dialog.dart`, new test
- **Steps:**
  1. Model mirrors the backend response (type SHORTAGE/DAMAGE/SURPLUS, clearance id, container no., item, manifest qty,
     landed qty, damaged qty, estimated loss EGP (nullable), responsible party, committee, claim status code, protocol
     date, notes, protocol code).
  2. Dialog: pick the clearance record (`SearchableDropdownField<int>` of records, label = clearance code + file code +
     decl 46), no invented defaults (`damagedQtyCtrl` l.17 empty, `claimStatus` l.22 null required), decimals kept.
  3. Tab: `EnterpriseDataTable` with View / Edit / Delete (confirm) actions; `ref.invalidate` after each write.
  4. Restore the shortage section of tab 1 using the same model filtered by type SHORTAGE.
- **Acceptance criteria:**
  - [ ] A saved protocol is still there after app restart and shows the linked clearance code.
  - [ ] Delete is soft and asks for confirmation.
- **Tests to add:** `frontend/test/features/customs_clearance/cargo_discrepancy_model_test.dart` (fromJson with null
  loss → null); widget test of the dialog validators.
- **Out of scope:** insurance-claim integration (Q4).

### FE07-T14: Duty ledger as an EnterpriseDataTable

- **Severity:** MAJOR | **Type:** ux | **Depends on:** FE07-T04, FE07-T07, FE07-T10 | **Backend needed:** no now; B2 for server paging later
- **Files to change:** `frontend/lib/features/customs_clearance/widgets/final_duty_payment_tab.dart`,
  `frontend/test/features/customs_clearance/final_duty_payment_tab_test.dart` (new)
- **Steps:**
  1. Replace the `DataTable` (l.301-327) with `EnterpriseDataTable<CustomsClearanceModel>`; columns as in §3;
     sticky header, sortable on code/assessed/paid/variance/free time, page size 25/50/100, persisted column widths if
     the widget supports a storage key.
  2. Keep search + filter chips above it; pass the filtered list.
  3. The page body becomes a `Column` with the table in `Expanded` (no outer `SingleChildScrollView` around the table).
- **Acceptance criteria:**
  - [ ] With 2,000 records the tab opens without jank and shows page 1 of N; header stays visible while scrolling.
  - [ ] Sorting by "Paid" works.
- **Tests to add:** widget test with 120 fake records → only page-size rows built (`find.byType(...)` count ≤ 50).
- **Out of scope:** server paging (after B2 + shared `ServerPagedNotifier`).

### FE07-T15: Model and hygiene

- **Severity:** MINOR | **Type:** refactor | **Depends on:** FE07-T04 | **Backend needed:** no
- **Files to change:** `frontend/lib/features/customs_clearance/models/customs_clearance_model.dart`,
  `frontend/lib/features/customs_clearance/widgets/clearance_screen_dialogs.dart`,
  `frontend/lib/features/customs_clearance/screens/customs_clearance_screen.dart`,
  `frontend/test/customs_clearance_model_test.dart`
- **Steps:**
  1. `fromJson` (F07-15): no invented defaults for office, channel, inspection result, owner, free days
     (`int? freeDaysAllowed`), payment method (`SADAD_EFINANCE` constant matching the constructor), release type
     (`FINAL_GREEN` constant, not the Arabic label). Fix compile errors in users of `freeDaysAllowed` (card l.120,
     clone l.190, 235) with `?? 0` only for display.
  2. Fallback payment dialog (F07-25): amount field empty with hint "assessed: X"; send `duty_paid_amount`.
  3. `stageCode: 'PHASE-5'` (F07-28): confirm the expected value in `core/widgets/vertical_stage_scaffold.dart` and fix
     or comment.
- **Acceptance criteria:**
  - [ ] A record JSON without `customs_office_name` shows "—" as office, not "Alexandria Port Customs".
- **Tests to add:** `customs_clearance_model_test.dart`: `fromJson({customs_clearance_id:1, clearance_code:'C', import_file_id:2, created_at:'', updated_at:''})`
  → `customsOfficeName == ''`, `owner == ''`, `freeDaysAllowed == null`.
- **Out of scope:** backend response defaults.

---

## 6. Backend dependencies (short)

- **B1** `modules/customs_clearance/service.py:1010-1031` (`_record_duty_payment`) and `:1128-1170` (`_issue_release`):
  no state guard. Return 409 when the record is already "Final Release Granted" (pay and release), and when already
  fully paid (pay; or allow an explicit correction flow, Q2). Today a re-payment rolls the status back.
- **B2** `GET /customs-clearance/paginated` (items, total, page, page_size, total_pages) with `status`, `search`,
  `payment_status`, `import_file_id`, `sort` — same envelope as `/import-files/paginated`. Needed for FE07-T14 phase B
  and FE06-T18.
- **B3** New entity for cargo shortage / damage / discrepancy protocols (per clearance record, soft delete, audit fields,
  claim status code, Alembic migration) + CRUD routes with `customs_clearance.view/update`. Needed for FE07-T13.
- **B4** (optional) expose `is_assessed`, `is_duty_fully_paid` booleans on `CustomsClearanceResponse` so the FE does not
  mirror `validators.is_assessed` (FE07-T04 mirrors it meanwhile).
- **B5** Stage notes are appended to `record.notes` (`service.py:956-957, 1022-1024, 1161-1162`); consider per-step note
  columns or a notes log (Q3).
- Still open from the previous plan: CL-18 (`estimated_duty_total` never populated → variance always 0 in the ledger).

---

## 7. Open questions for the CTO

1. Tabs 1-2 interim: hide the shortage/discrepancy registries until B3 exists, or keep them visible with an
   "not saved yet" notice? [Default: visible, read-only, with a notice; no fake save.]
2. After a payment is recorded, may a user correct it (wrong receipt no.) and with which permission? [Default: no
   re-payment from the UI; correction through an admin-only flow later.]
3. Stage notes: keep appending to one `notes` text, or store notes per step? [Default: keep appending; FE stops
   duplicating.]
4. Should a damage/discrepancy protocol create or link a cargo-insurance claim (`features/cargo_insurance`)? [Default:
   link by optional `insurance_claim_id` later.]
5. Free-time warning threshold: 3 days fixed, or per company/port setting? [Default: 3 days constant.]
6. Q2 of the previous plan (VAT-included meaning on clearance invoices) is still open and blocks the VAT part of FE07-T12.
