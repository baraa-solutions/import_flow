# Phase 3 "Import Documentation": Flutter quality audit and fix plan (03c)

Status: proposed (2026-10-05). Nothing implemented. Based on static reading and grep only: no `flutter test` was run.
Scope: `frontend/lib/features/import_documentation/**` (49 files, 47,203 lines) and its tests under `frontend/test/`.
Backend findings for the same phase are in the sibling plans (03a/03b). Severity scale is the same as `phase-01-quality-simplify-plan.md`
(BLOCKER: breaks a non-negotiable rule or corrupts money, customs data, or references; CRITICAL: a wrong result on a normal path;
MAJOR: a rule violation or real risk; MINOR: hygiene).

## Audit coverage

| Area | Depth |
|---|---|
| `providers/` (3 files, 1,487 lines) | Read fully |
| `models/docs_customs_approval_model.dart` | Read fully, compared field by field with `modules/docs_customs_approval/schemas.py` |
| `models/{invoice_bl_match_session,po_reconciliation_session,docs_customs_approval_session,original_documents_collection}_model.dart` | JSON keys diffed against the backend `*Response`/`*Create` schemas (scripted diff) |
| `models/import_documentation_model.dart` (1,710) | Keys diffed against `modules/import_documentation/schemas.py` + `smart_document_upload/schemas.py`. Unmatched keys traced; all are fallbacks or service-built dict keys except those listed below |
| Screens, widgets, services (44 files, ~44k lines) | 100% grep sweeps (table below) plus targeted reads around every hit that matters (~700 lines). **Not audited line by line**: the bodies of `po_reconciliation_tab`, `draft_bl_review_tab`, `invoice_bl_matcher_tab` (outside save/upload), `original_documents_collection_tab`, `coo_review_tab`, `customs_document_approval_tab`, `bank_form4_screen`, `central_docs_archive_screen`, the visual sheets, and the PDF layout code in `services/` |
| Tests | Names inventoried (33 related files). `invoice_bl_match_sessions_test.dart` pins the wrong contract (FED-01, FED-10) |

Lines read line by line: about 2,300 of 47,203 (about 5%). Lines grep-swept: 47,203 (100%).

## Rule sweeps (counts)

| Rule | Hits | Top files |
|---|---|---|
| `Colors.` | 1,798 | draft_bl_review_tab 208, nafeza_acid_screen 174, po_reconciliation_tab 129, coo_review_tab 112, visual_draft_coo_sheet 109, invoice_bl_matcher_tab 109 |
| `Color(0x` | 269 | customs_declaration46_screen 112, original_documents_collection_tab 45, nafeza_acid_screen 21 |
| `ElevatedButton` / `OutlinedButton` / `TextButton(` | 266 / 228 / 31 | draft_bl_review_tab 48+16, nafeza_acid_screen 36+45, po_reconciliation_tab 27+22 |
| `DropdownButtonFormField` | 5 | draft_bl_review_tab:1713, formal_letter_generator_dialog:290, original_documents_collection_tab:675,884,909 |
| `Text('` / `Text("` literals | 327 / 5 | po_reconciliation_tab 45, invoice_bl_matcher_tab 44, coo_export_service 36, draft_bl_export_service 29, visual_draft_coo_sheet 29 |
| `isAr ?` inline ternaries | 323 | inspection_export_service 129, po_reconciliation_tab 57, customs_document_approval_tab 54 |
| `catch (_)` | 11 | 6 are harmless utf8-decode fallbacks; 5 swallow real failures (FED-05, FED-13, FED-22) |
| Raw `e.toString()` / `$e` in user messages | ~52 in 13 files | `ApiErrorText`/`ApiError` used 0 times in the feature |
| `ref.invalidate` | 37 | 0 in nafeza_acid_screen, bank_form4_screen, customs_declaration46_screen (they rely on notifier self-refresh) |
| `FileSaveHelper` | 13 (`saveText`/`saveBytes`) | 1 export path bypasses it: `Printing.sharePdf` (FED-09) |
| `print(` / `debugPrint(` / `SharedPreferences` / `http://` | 0 / 3 / 0 / 0 | |
| `Alignment.centerLeft/Right` | 3 | RTL hygiene |
| Hard-coded customs references (10+ digit literals, sample companies) | 40+ | inspection_review_tab, coo_review_tab, nafeza_acid_screen, coo_export_service, visual_draft_coo_sheet (FED-02/03) |

## 1. Findings

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| FED-01 | BLOCKER | `widgets/invoice_bl_matcher_tab.dart:468-490`, `models/invoice_bl_match_session_model.dart` | The save payload uses keys that `InvoiceBLMatchSessionCreate` does not have: `match_score`, `discrepancy_count`, `has_critical_discrepancies`, `invoice_extracted_data`, `bl_extracted_data`, `packing_extracted_data`, `session_notes`, `session_title`, `*_raw_text`, `*_file_name`, `created_by`. Pydantic drops them, so every session is stored with `match_score_percentage=0`, `overall_status="FULLY_MATCHED"`, both discrepancy counts 0 and `invoice_data`/`bl_data` null. Because the data is null, `create_invoice_bl_match_session_service` (`modules/import_documentation/service.py`, "If certified" branch) **never runs the sync to the import file, shipping, and customs approvals**, while the SnackBar says it did. The model reads the same wrong keys back. | code + schema diff | Send the backend names: `match_score_percentage`, `overall_status` (from `_matchResult`), `critical_discrepancies_count`, `warning_discrepancies_count`, `invoice_data`, `bl_data`, `packing_list_data`, `invoice_number`, `bl_number`, `packing_list_number`, `acid_number`, `notes`, `certified_by` (signed-in user). Drop the keys the schema lacks (Q1 asks whether backend should add raw text/file names). Rewrite `InvoiceBLMatchSessionModel.fromJson/toJson` to the `InvoiceBLMatchSessionResponse` fields. Show the success SnackBar only from the response. |
| FED-02 | BLOCKER | `widgets/inspection_review_tab.dart:36,138,298,667,1044,1074,1104,1134`; `widgets/coo_review_tab.dart:305,343,1109,1531,1555,2104`; `services/coo_export_service.dart:182,289`; `screens/nafeza_acid_screen.dart:438`; `widgets/visual_draft_coo_sheet.dart` (2) | When the file has no ACID, a fixed ACID number (`7595528271015010011`, `7595528271020210010`, `5281534391023010013`) is put into the form, the saved review payload, and the exported certificate. A wrong ACID on a customs document. | grep | Remove every fallback. ACID field starts empty with a required validator. Exports and saves are blocked with a localized SnackBar when ACID is missing. |
| FED-03 | BLOCKER | `screens/nafeza_acid_screen.dart:3080-3086`, `:3884-3892` | Real third-party data is injected as defaults into the ACID form and the generated request text: importer "SCAS For Construction And Finishing", tax ID `528153439`, Maadi address, exporter "Suzhou Yuheng Textile", reg ID `913205813141920259`, phone, CargoX UUID `5b1b827d-…`. Also `528153439` in coo_export_service (3), coo_review_tab (1), visual_draft_coo_sheet (2). | grep | Delete the defaults. Prefill only from the import file / supplier / company master data already loaded on screen; empty otherwise, with required validators. |
| FED-04 | BLOCKER | `screens/customs_declaration46_screen.dart:286-311`, `:1736-1762` | Form 46 assessment computes duties on the client with hard-coded values: FX `const exchangeRate = 50.7917`, freight `fob*0.02`, insurance `fob*0.025`, FOB fallback `12500.0`, and when no tariff: duty 5%, VAT 14%, service fee 1%. The numbers are displayed and exported (`_exportRegistryExcel/Pdf`, l.2807+). Breaks DOMAIN_RULES §2 and duplicates the backend customs engine. Exemption is guessed from `portOfLoading.contains('IT'/'FR'/'DE'/'ES')` (l.320, 1766). | code | Replace the local math with the backend estimate (`customs_tariff` multi-item estimate endpoint; Q2 confirms which endpoint/contract the 03a/03b architects expose). Until it exists: no fallback rate; a missing tariff or customs FX rate shows a "rate missing" state and excludes the line from totals; FX from the existing currency provider (customs rate). Remove the port-name exemption guess. **Route through `customs-rules-reviewer`.** |
| FED-05 | CRITICAL | `widgets/draft_bl_review_tab.dart:575-584`; `providers/import_documentation_provider.dart:479` | Checklist edits are PUT with `catch (_) {}`: on failure the UI shows the edit but the server never stored it. The provider sends `reviewer_name='Kamal'` by default (the caller never passes it), so the audit trail names the wrong person. | code | Pass `ref.read(authProvider).user?.fullName` (as l.84 already does for the broker). Make `reviewerName` required. On error: revert `_comparisonResult` and show `ApiErrorText.of`. |
| FED-06 | CRITICAL | `providers/import_documentation_provider.dart:533`; `widgets/original_documents_collection_tab.dart:1023` | `approveDraftBL(approvedBy='Kamal')` default and `doc.verifiedBy = 'Kamal'` when ticking "verified": falsified audit identity on customs documents. | code | Required parameter / signed-in user's full name from `authProvider`. |
| FED-07 | CRITICAL | `services/coo_export_service.dart:63`; `widgets/visual_draft_coo_sheet.dart` | `formatCooHsCode('')` returns `56.02` / `5602290000`: a COO with no HS code is exported with an invented tariff line. `'CN - China'` is also a fallback origin (coo_export_service 4, visual sheet 3). | grep | Return empty; the export validates HS code and origin are present and refuses otherwise. |
| FED-08 | CRITICAL | `screens/customs_declaration46_screen.dart:569`, `:603` | The regulatory-approvals export writes "Fulfilled" in the status column for every row, regardless of data. | code | Map the real status from `appr` (field name to confirm in the Form 46 data; show "-" when absent). |
| FED-09 | CRITICAL | `providers/original_documents_collection_provider.dart:78-88` | `fetchSessionByFile` returns `null` on **any** error (network, 401/403, 500). The tab then treats the file as having no session and the next save upserts an empty/auto-populated session over the existing one. | code | Return `null` only for 404 (or `response.data == null`); rethrow everything else and show the error. |
| FED-10 | MAJOR | `models/docs_customs_approval_session_model.dart`, `providers/docs_customs_approval_provider.dart:225-301` | Model fields (`session_title`, `overall_compliance`, `total_checks`, `checks_matrix`, `recommendations`, `session_notes`) do not exist in `DocsCustomsApprovalSessionResponse` (which has `overall_status`, `final_*_ref/_status`, `commercial_/customs_signoff_*`, `notes`, `session_snapshot`). The provider has no caller in `lib/` (only `frontend/test/invoice_bl_match_sessions_test.dart:139`). | grep + diff | Q3: delete provider + model + test case (simplest), or rewrite the model to the response schema. Default plan: rewrite to the schema (keeps the STEP-09 session endpoint usable) and fix the test. |
| FED-11 | MAJOR | `services/draft_bl_export_service.dart:392-411` (callers `draft_bl_review_tab.dart:774,1417,2801`, `visual_draft_bl_sheet.dart:162`) | `exportDraftBLToPdf` uses `Printing.sharePdf` and bypasses `FileSaveHelper`; `saveDraftBLPdfToFile` (l.501) already does it right. | grep | Make `exportDraftBLToPdf` delegate to `saveDraftBLPdfToFile` (signature unchanged, so callers stay untouched). |
| FED-12 | MAJOR | ~52 sites, e.g. `draft_bl_review_tab.dart:632`, `smart_invoice_bl_extractor_dialog.dart:243,280,312` | Backend errors shown as the raw `DioException` string; the Arabic `detail` from FastAPI is never shown. | grep | Use `ApiErrorText.of(context.l10n, e)` in every SnackBar/dialog that prints `e`. |
| FED-13 | MAJOR | `providers/import_documentation_provider.dart:472,487,507,526,541,551,658,669,776,787,881,897,909,997,1009`; `docs_customs_approval_provider.dart:283,295`; `original_documents_collection_provider.dart:101,121` | After a mutation, notifiers re-fetch with **no arguments**, so a list filtered by import file (all tabs filter by `_activeFileId`) is replaced by the global list. Draft B/L, COO, inspection, PO-reconciliation, shipment-doc, and DCA review mutations do not invalidate `centralArchiveProvider`, `legalComplianceFamilyProvider`, `importFilesProvider`, or `smartTasksProvider` (only some call sites do). | code | Each notifier keeps its last query (`_lastImportFileId`, etc.) and re-fetches with it. Notifiers take `Ref` (as `AcidSessionsNotifier` does) and after every mutation invalidate `importFilesProvider`, `smartTasksProvider`, and `centralArchiveProvider`/`legalComplianceFamilyProvider` for the affected file. Keep the existing call-site invalidations. |
| FED-14 | MAJOR | `widgets/smart_invoice_bl_extractor_dialog.dart:232,265-310` | Cross-check sends a hard-coded `weight_tolerance_pct: 3.0`. Apply-invoice / apply-B/L only invalidate `importFilesProvider`, not the PO / cargo shipping providers they change. | code | Omit the field (backend default) unless a configured value exists (Q4). Also invalidate `purchaseOrdersProvider` and the cargo shipping provider. |
| FED-15 | MAJOR | `widgets/invoice_bl_matcher_tab.dart:73+` (Shaw Europe invoice preset with VAT no.), `widgets/po_reconciliation_tab.dart:4288` (`poRecLoadSampleDemoButton`) | Sample/demo data and a "load demo" button ship in the production UI and can be saved as real sessions. | grep | Remove, or gate behind `kDebugMode`. Default: remove. |
| FED-16 | MAJOR | `services/original_docs_export_service.dart:926` | Courier `tracking_url` (user-entered) is passed to `cmd /c start` with only `&` escaped: command injection on Windows. | code | Parse with `Uri.tryParse`, allow only `http`/`https`, open with `launchUrl` (if `url_launcher` is in pubspec) or `Process.run('explorer.exe', [uri.toString()])` without a shell. **security-reviewer.** |
| FED-17 | MAJOR | 5 `DropdownButtonFormField` (sweep table) | Forbidden widget. | grep | `SearchableDropdownField<String>`. |
| FED-18 | MAJOR | 332 `Text('…')` literals, 323 `isAr ?` ternaries, Arabic literals in `invoice_bl_matcher_tab.dart:442-521` | Hard-coded UI strings. | grep | Move UI strings to l10n keys. PDF layouts of official English forms in `services/` (COO, B/L, inspection) stay English literals if Q5 confirms. |
| FED-19 | MAJOR | 1,798 `Colors.` + 269 `Color(0x` | Colours outside `AppTheme`. | grep | Mechanical sweep, one commit per file, after the fixes above. |
| FED-20 | MAJOR | 266 `ElevatedButton`, 228 `OutlinedButton`, 31 `TextButton(` | `AppButton` is mandatory. | grep | Same mechanical sweep. |
| FED-21 | MINOR | `inspection_review_tab.dart:149`, `formal_letter_generator_dialog.dart:144`, `nafeza_acid_screen.dart:309`, `shipment_draft_docs_screen.dart:122`; `debugPrint` in coo_review_tab:315, po_reconciliation_tab:511 | Template / history / experience-guide load failures are silent. | grep | Template and history: show an inline error. Guide match is optional: keep silent but log via the app logger. |
| FED-22 | MINOR | 13 `FileSaveHelper` calls in `services/` | Default file names use `Phase3_…_<epoch>` / `Original_Docs_Registry_<epoch>` instead of `[Stage Name] - [File code].ext`. | grep | Build names as `'<Stage> - <importFileCode>.<ext>'`. |
| FED-23 | MINOR | `models/original_documents_collection_model.dart:259-261` | `created_by`/`updated_by` fall back to `'ADMIN'` and `created_at` to `DateTime.now()`: masks contract errors. | code | Nullable / empty fallback. |
| FED-24 | MINOR | `providers/import_documentation_provider.dart:724` | Defaults `agency='COTECNA'`, `certType='COC (…)'` sent as query when the caller omits them. | code | Make both required at the call sites that already know them. |
| FED-25 | MINOR | `formal_letter_generator_dialog.dart:97,137`, `invoice_bl_matcher_tab.dart:365-371`, `po_reconciliation_tab.dart:490`, `smart_invoice_bl_extractor_dialog.dart` (7) | Direct `dio` calls from widgets; endpoints built inline instead of `ApiConstants`. Every provider method wraps `try { } catch (e) { rethrow; }`. | grep | Not in this wave (no behaviour change); backlog. |
| FED-26 | MINOR | 3 `Alignment.centerLeft/Right` | RTL. | grep | `AlignmentDirectional.centerStart/End`. |

Counts: **BLOCKER 4, CRITICAL 5, MAJOR 11, MINOR 6** (26 findings).

## 2. Contract changes (Flutter side)

1. `InvoiceBLMatchSessionModel` and the save payload switch to the `InvoiceBLMatchSession*` schema names (FED-01). No backend change needed. Old rows in the DB already have the defaults; they cannot be repaired from the client (risk R1).
2. `DocsCustomsApprovalSessionModel` follows `DocsCustomsApprovalSessionResponse` (FED-10).
3. `updateDraftBLChecklist(reviewerName:)` and `approveDraftBL(approvedBy:)` become required named parameters (FED-05/06). Only caller in `lib/`: `draft_bl_review_tab.dart:577`.
4. Form 46 consumes a backend estimate instead of computing duties (FED-04). Depends on Q2.

## 3. Work split (2 flutter-developer packages, disjoint files)

| Package | Files (exclusive) | Findings |
|---|---|---|
| **A: sessions, providers, approvals** | `providers/*` (3), `models/*` (6), `widgets/{invoice_bl_matcher_tab, smart_invoice_bl_extractor_dialog, draft_bl_review_tab, draft_bl_review_dialog, customs_document_approval_tab, original_documents_collection_tab, original_documents_collection_dialog, po_reconciliation_tab, formal_letter_generator_dialog, search_and_clone_*}.dart`, `screens/{import_documentation, smart_invoice_bl_match, draft_bl_review, docs_customs_approval, po_packing_reconciliation, original_docs_and_cargox, central_docs_archive}_screen.dart`; tests listed under A | FED-01, 05, 06, 09, 10, 12-15, 17, 23-25, and the FED-18..20/26 sweeps in its files |
| **B: customs references, Form 46, exports** | `screens/{nafeza_acid, customs_declaration46, bank_form4, shipment_draft_docs, draft_coo_review, draft_inspection_review}_screen.dart`, `widgets/{coo_review_tab, inspection_review_tab, visual_draft_coo_sheet, visual_draft_bl_sheet, visual_draft_inspection_sheet, legal_compliance_banner}.dart`, `services/*` (5); tests listed under B | FED-02, 03, 04, 07, 08, 11, 16, 21, 22, and the FED-18..20/26 sweeps in its files |

Shared files and order:
- **Localization** (`frontend/lib/core/localization/app_localizations{,_ar,_en}.dart`): keys only between `// === review phase03 keys (append below this line) ===` and `// === end review phase03 keys ===`. Package A edits first: it adds its keys (prefix `idocA…`) and a sub-comment `// -- phase03c package B --` just above the end marker in all three files. Package B develops against agreed key names (prefix `idocB…`) and appends under that sub-comment only after A's l10n commit lands. Neither touches lines outside the markers.
- B never edits `providers/`; A never edits `services/`. FED-11 keeps the `exportDraftBLToPdf` signature, so A's call sites in `draft_bl_review_tab` stay unchanged.
- Order inside each package: correctness findings first (one commit each), then the mechanical sweeps one file per commit. Do not split god files in this wave.

## 4. Tests to add or change

Package A:
- `frontend/test/invoice_bl_match_sessions_test.dart`: rewrite to backend JSON (`match_score_percentage`, `overall_status`, counts, `invoice_data`, `bl_data`, `notes`); DCA session case per FED-10.
- New `frontend/test/import_documentation_contract_test.dart`: `fromJson` of a JSON sample copied from each backend `*Response` (invoice-BL session, DCA session, PO-recon session, original-docs session, approval, ticket); the save payload builder for FED-01 contains exactly schema keys (extract the payload builder to a pure function inside the tab file or the model as a `toCreateJson` static).
- New `frontend/test/import_documentation_provider_refresh_test.dart`: with a fake Dio adapter, a mutation re-fetches with the last `import_file_id`; `fetchSessionByFile` returns null on 404 and throws on 500; `updateDraftBLChecklist` sends the given reviewer name.

Package B:
- New `frontend/test/import_documentation_no_fabricated_defaults_test.dart`: source-scan guard (pattern of the RTL ratchet guard) over `lib/features/import_documentation/`: no 10+ digit string literals, no `'Kamal'`, no `SCAS`/`Suzhou`/`Shaw`/`528153439`/`5b1b827d`, no `Printing.sharePdf`, no `const exchangeRate =`.
- `frontend/test/customs_declaration46_test.dart` / `cs03_customs_declaration_46_test.dart`: a missing tariff yields "rate missing" and no 14%/5%/1% fallback; export status column reflects data.
- `frontend/test/visual_draft_coo_and_inspection_test.dart`: `formatCooHsCode('')` returns `''`; export refuses an empty ACID/HS code.

## 5. Risks

- **R1**: Existing `invoice_bl_match_sessions` rows were saved as `FULLY_MATCHED`, score 0, without invoice/B/L data, and their "final approval" never synced. Ask the backend architect for a read-only count of non-draft sessions with `invoice_data IS NULL`; users may need to re-run final approval for affected files. No auto-repair.
- **R2**: Rows already saved with a fabricated ACID / importer data (FED-02/03) or reviewer "Kamal" (FED-05/06) stay in the DB. Read-only query recommended (ACID values equal to the literals above).
- **R3**: FED-04 changes displayed Form 46 numbers; communicate as a behaviour change.
- **R4**: The sweep commits touch ~25k lines in god files; keep them separate from fix commits so reviews stay readable.

## 6. Open questions

- **Q1**: Should `InvoiceBLMatchSession` store raw texts and file names (backend additive columns), or are they dropped?
- **Q2**: Which backend endpoint returns the Form 46 duty estimate (customs_tariff multi-item estimate)? Decided with the 03a/03b architects.
- **Q3**: DCA sessions (FED-10): keep and fix, or delete the unused provider/model?
- **Q4**: Is the 3% invoice-vs-B/L weight tolerance a business setting (system parameter) or the backend default?
- **Q5**: Official PDF forms (COO, B/L, inspection) stay English-only, or get localized labels?
- **Q6**: Demo presets (FED-15): delete, or keep behind `kDebugMode`?
