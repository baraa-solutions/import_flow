# Phase 03 (Import documentation): backend review

Status: 2026-10-05, static review only (no pytest, no `import main`, no DB access). Baseline: the fixes from
`docs/plans/phase-03a-quality-plan.md` (DOC-01..26) and `docs/plans/phase-03b-quality-plan.md` (DCA-01..08,
ODC-01..13, SDU-01..08) are in the code; items verified fixed are not re-reported. "Still open from <id>" marks a plan
item that is only partly fixed or was deferred.

| File | Lines | Depth |
|---|---|---|
| `modules/import_documentation/router.py` | 899 | full |
| `modules/import_documentation/service.py` | 6026 | targeted, about 2,600 lines read: 95-565 (ACID), 780-1350 (banking, shipment docs, declaration, PO final adjustment), 1997-2625 (draft B/L), 2777-3240 (COO, inspection), 4199-4365 (inspection template), 4761-5060 (invoice/B-L), 5057-5490 (PO extract, recon sessions, deletes), 5630-5660 and 5910-5930 (central archive). The rest grep-scanned (commit, except, literals, currency defaults) |
| `modules/import_documentation/repository.py`, `validators.py`, `schemas.py`, `model.py` | 871 / 204 / 1125 / 598 | repository 1-200 + targeted; validators full; schemas: ACID, banking, declaration, PO adjustment, draft B/L update, session schemas; model: column scan |
| `modules/import_documentation/ai_document_parser.py`, `nafeza_acid_parser.py`, `arabic_ocr_engine.py` | 3427 / 454 / 232 | grep only (env keys, external calls) |
| `modules/docs_customs_approval/service.py` | 1008 | full |
| `modules/docs_customs_approval/router.py`, `validators.py`, `schemas.py`, `repository.py` | 271 / 188 / 246 / 238 | router scan, validators full, schemas status fields, repository commits / limits |
| `modules/original_documents_collection/service.py` | 916 | 150-500, 700-800 full; rest grep |
| `modules/original_documents_collection/router.py`, `repository.py` | 190 / 118 | scan |
| `modules/smart_document_upload/service.py`, `router.py`, `validators.py` | 799 / 421 / 257 | service 600-799 full, router full scan, validators upload chain |
| Cross-module facts | - | `purchase_orders/model.py:30-130`, `financial_approval/service.py:1150-1162`, `file_closure/service.py:465-473`, `lifecycle_board/service.py:249-480` (commits at 375 and 480), `common/legacy_rows.py`, Flutter `po_reconciliation_tab.dart:955-1006, 1260-1270`, providers' endpoint list |
| Business docs | - | `docs/phase_03_import_documentation.md` (BP-014..016), `.agents/rules/DOMAIN_RULES.md`, `.claude/rules/backend.md` |

Verified fixed (not re-reported): per-route `require_permission` on all four routers (DOC-01, DCA-02, ODC-01, SDU-01);
acting user from the token in every write route (DOC-12, DCA-03, ODC-09); draft B/L server-owned status/stage/approval
fields and four-eyes on dual approval (DOC-04, partly, see F07); version code chain (DOC-05); COO/inspection
justification and server compare (DOC-06); repository not-found -> 404 and no silent restore (DOC-07/08);
`next_yearly_code` generators (DOC-10/22, DCA-05, ODC-12, SDU-05); PO final adjustment ownership, rounding, version bump
(DOC-02 a-g, see F01 for the remaining defect); upload size/extension and threadpool in import_documentation (DOC-16);
fabricated ACID / B/L / COO placeholders removed (DOC-03, see F13 for inspection template leftovers); DCA fake matrix rows
(DCA-01), DCA session lock and `customs_clearance.update` (DCA-04, see F08); ODC exact AWB match, single transaction,
receipt date once (ODC-02..12); SDU apply schemas, ACID conflict 409, container merge (SDU-01), bounded reads (SDU-03).

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 3 |
| CRITICAL | 5 |
| MAJOR | 15 |
| MINOR | 6 |

Top points:
1. **PO final adjustment writes each PO line twice** (F01): the Flutter screen sends invoice rows and packing rows, both
   carrying the same `po_item_id`. The packing row overwrites the line quantity with `qty_pcs` and the response
   `total_final_amount` is the sum of both rows.
2. **Invoice/B-L certification relabels money** (F02): `ImportFile.estimated_cost_currency` is overwritten by the
   invoice currency while `estimated_cost` keeps its old amount. Financial approval and file closure then read the old
   amount in the new currency.
3. **Workflow gates still trust client flags with optimistic defaults** (F05, F06, F07, F08): `is_safe_for_certification`
   defaults to True, `overall_status` to FULLY_MATCHED / "APPROVED", ACID match flags to True, and draft B/L
   `has_blocking_mismatch` / DCA session document statuses come from the client. Each drives a lifecycle advance.
4. **`/invoice-bl/certify-and-sync` bypasses certification** (F04): no session, no discrepancy check, yet it approves
   three DCA commercial tiers and advances STEP_08_MATCH.
5. **Workflows re-fire on every save** (F09): ACID and banking updates create a new SmartTask and notification on each
   save.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE03-F01 | BLOCKER | `modules/import_documentation/service.py:1248-1295`; Flutter `frontend/lib/features/import_documentation/widgets/po_reconciliation_tab.dart:977-1006, 1006 (plList.addAll(invList)), 1263` | `/po-reconciliation` applies every request item to its `po_item_id`. The screen sends `[..._invoiceItems, ..._packingItems]`, and each packing item carries `poItemId` of the matching PO line plus `finalQuantity = plItm.qtyPcs`. The second write wins: `POLineItem.quantity` becomes the packing pieces count and `total_price` is recomputed from it. `total_final_amount`, `total_net_weight_kg`, `total_gross_weight_kg` and `total_cbm` in the response add both rows (2x when there is no packing list, because `plList.addAll(invList)`). Duplicate `po_item_id` in the request is not rejected. | Apply PO line changes only from items with `packing_item_id is None`; items with `packing_item_id` update the packing row only. Reject a `po_item_id` that appears in two line items (400). Totals count each PO line once (T01). |
| BE03-F02 | BLOCKER | `service.py:4876, 4885-4886` (via `create_invoice_bl_match_session_service` 5025 and `sync_certified_invoice_bl_to_file_service` 4974); consumers `financial_approval/service.py:1160-1162`, `file_closure/service.py:470-473` | Certifying an invoice/B-L match writes `imp_file.estimated_cost_currency = <invoice currency>` without touching `estimated_cost`. A file estimated at 24,500 EUR becomes 24,500 USD after a USD invoice is certified. Financial approval (fallback part) and file closure FOB fallback read the relabelled value. | Never write `estimated_cost_currency` from the invoice sync. Keep the invoice currency in the session `invoice_data`; return `currency_mismatch: true` when it differs from the file's currency (T02). |
| BE03-F03 | BLOCKER | `modules/smart_document_upload/service.py:692-706`; consumer `financial_approval/service.py:1152-1158` | `apply_extracted_invoice_service` appends to `invoices_data` without a duplicate check. Applying the same invoice twice stores two rows, and financial approval sums `invoices_data` amounts when it has no PO parts (double value). It also overwrites `estimated_cost` with a single invoice value (the last one applied, not the file total) and invents `INV-<n>` when the invoice number is missing. No Flutter caller today (API only). | Upsert by normalized `invoice_no` (replace the row), require `invoice_number` (400), do not overwrite `estimated_cost` (T03). |
| BE03-F04 | CRITICAL | `modules/import_documentation/router.py:830-840`, `service.py:4966-4995` | `POST /invoice-bl/certify-and-sync` (permission `import_documentation.upload`) writes `pi_number`, `bl_number`, `booking_no`, `vessel_name`, `incoterm_code`, cargo `containers_loading_data`, approves the commercial tier of the CI / B/L / PL `CustomsDocumentApproval` rows and advances STEP_08_MATCH -> STEP_08_COO. No certified session, no discrepancy or justification check, no lock. The session path (5014-5025) has those checks; this route skips them. Also replaces the whole container list with raw extracted dicts (4905-4906). No Flutter caller. | Require an active certified `InvoiceBLMatchSession` for the file and take `invoice_data` / `bl_data` from it (ignore the body), else 409; or remove the route (Q4). Container sync merges by `container_no` like `smart_document_upload/service.py:758-780` (T04). |
| BE03-F05 | CRITICAL | `schemas.py:956-960` (InvoiceBLMatchSessionBase), `schemas.py:1013-1020` (POReconciliationSessionBase), `service.py:5020, 5319-5330, 5355-5357`, `model.py:514, 521-524, 570-573` | Session gate fields are client-owned with optimistic defaults: `is_safe_for_certification=True`, `critical_discrepancies_count=0`, `overall_status="FULLY_MATCHED"`, `currency="EUR"`, amounts 0.0. An empty PO recon session POST advances STEP_08_PO -> STEP_08_BL (`_po_recon_lifecycle` triggers on `is_safe_for_certification`). An invoice/B-L session certifies without a justification when the client omits the counts. PO recon stores an invented EUR currency. | Server recomputes the gate: invoice/B-L via `match_invoice_with_bl(invoice_data, bl_data, snapshot)`; PO recon via `reconcile_po_documents_with_system` when extracted data is present, else `is_safe=False`. Schema defaults become pessimistic (`is_safe_for_certification=False`, `overall_status="DRAFT"`), `currency` required on create and validated against `currencies` (T05). |
| BE03-F06 | CRITICAL | `repository.py:131-136`, `schemas.py:112-117` (AcidRegistrationUpdate.status / is_*_matched / has_discrepancies), `service.py:321-339, 473-487` | ACID: create stores `is_*_matched=True`, `has_discrepancies=False` and `status="Verified"` whenever a 19-digit number and `generated_date` exist, whatever `discrepancies_data` says and without `discrepancy_override_reason`. PUT lets the client set `status="Verified"` and the match flags. Either path runs `_handle_acid_verification_workflow`: overwrites `ImportFile.acid_number` (no conflict check, unlike `SDU_ACID_CONFLICT`), advances STEP_05 -> STEP_06 and creates the freight booking task. | Server derives `has_discrepancies` / flags from `discrepancies_data`; "Verified" only with no discrepancy, "Discrepancy_Accepted" only with an override reason (400 otherwise). Ignore client `status` / flags on PUT. 409 `DOC_ACID_CONFLICT` when the file has a different ACID (T06). |
| BE03-F07 | CRITICAL | `service.py:2239-2258, 2333-2342`, `schemas.py:572-576` | Draft B/L: `has_blocking_mismatch` and `open_discrepancies_count` are not server-owned. PUT `{has_blocking_mismatch:false, open_discrepancies_count:0}` without `checklist_data` turns REVISION_REQUIRED into REVIEWED_PENDING_APPROVAL and `_require_pending_approval` (2182) then allows approval despite a critical mismatch. Create with a non-empty `comparison_matrix` and no checklist skips the server compare and keeps the client flags. | Always derive both values from the stored/merged checklist (`_checklist_has_blocking`, count of "Incorrect"); drop them from the PUT payload; on create without checklist always run `compare_draft_bl_service` for a certified save (T07). |
| BE03-F08 | CRITICAL | `modules/docs_customs_approval/service.py:931-935, 937-949`, `schemas.py:174-190` | DCA final session: the readiness check only tests that the five `*_status` fields were sent. Values are free text, so `final_invoice_status="Rejected"` still certifies, sets STEP_09 -> STEP_10 and progress 60. `overall_status` defaults to "APPROVED" and is stored as sent. The statuses are not compared with the file's `CustomsDocumentApproval` rows. | Final save requires each of the five statuses in an allowed set (`Approved`, `Waived / Not Required` for COC) and the matching approval row (`Commercial Invoice`, `Packing List`, `Bill of Lading`, `Certificate of Origin`, `Inspection Certificate`) to be `Approved for Clearance` (or waived for COC). `overall_status` is server-set (T08). |
| BE03-F09 | MAJOR | `service.py:381-405, 408-428` (ACID), `893-926, 929-950` (banking), callers `486, 539, 965, 991, 1017` | Every ACID upsert/update and every banking update/receive with an issued number re-runs the workflow: a new `SmartTask` (freight booking / Declaration 46) and a new `SystemNotification` each time, plus a lifecycle call. No dedupe, unlike `_dispatch_sh03` (2091-2097). | Run follow-ups only on the transition into the issued state (compare the previous status / number), and dedupe tasks by `import_file_id` + `msg_code` (T09). |
| BE03-F10 | MAJOR | `modules/docs_customs_approval/service.py:814-841`, `router.py:121-131` | `PUT /tickets/{id}` sets any ticket status, including Resolved / Waived / Closed, bypassing `/resolve` (no `resolved_by`, `resolved_at`, open check) and can reopen a closed ticket, which then blocks the DCA session. The route passes no user. | PUT accepts only `Open` / `Sent to Supplier`; closing goes through `/resolve`; editing a closed ticket gives 409 `DCA_TICKET_CLOSED`; router passes the user (T10). |
| BE03-F11 | MAJOR | `service.py:5087-5197` | PO extract-and-compare: `ImportFile` and `PurchaseOrder` loads ignore `is_active` and take `.first()` (still open from DOC-18); `po_curr = "USD"` invented default; when no PO lines exist the "system" items are built from the invoice itself (compare invoice vs invoice, always matches) with `po_item_id = idx`; packing system rows put `packing_item_id` into `po_item_id`; package count defaults to 1 and type to "Carton". | Active filters; no default currency (None + missing flag); no system items from the invoice (return `system_items_missing=true`, status DRAFT); packing rows expose `packing_item_id` (T11). |
| BE03-F12 | MAJOR | `modules/docs_customs_approval/service.py:113-116` | `_po_for_file` looks up the PO by `po_number` only: no `import_file_id`, no `is_active`, `.first()`. The matrix check (HS, value, weight, CBM, incoterm) and approval `po_id` may use a deleted PO or another file's PO with the same number. | Query by `import_file_id` + `is_active`; with several POs aggregate or return Not Checked (T11). |
| BE03-F13 | MAJOR | `service.py:4239-4290` | Inspection draft template invents regulatory data: any product not matched by keyword is "Commercial Goods" with standard `ES 7321 / 2011` (a furniture standard); with no items the template lists two furniture/acoustic standards; `coc_number` is fabricated (`DEG-000123`, `DRAFT-COT-0123`); "brand: Standard"; quantity default 1. Still open from DOC-03. | Unknown product -> standard `""` and add `adopted_standard` to `missing_fields`; empty `applicable_standards` when none; `coc_number` empty; no brand text when unknown (T12). |
| BE03-F14 | MAJOR | `schemas.py:278-286`, `repository.py:361-378`, `service.py:1085-1091` | Customs Declaration 46 draft stores client CIF, duties and VAT (EGP) with default 0.0 (a fabricated zero); `acid_number` is 19 chars but not checked as digits nor against the file's ACID; several drafts per file allowed. Read by `formal_letters/service.py:82`. | Money fields `Optional[float] = Field(None, ge=0)`, ACID via `validate_acid_number(..., allow_pending=False)` and equal to the file ACID when the file has one (409), one active draft per file (409) (T13). |
| BE03-F15 | MAJOR | `schemas.py:172-201`, `model.py:144-145`, `service.py:1002-1003` | Banking document: `currency_code` defaults to "USD" and is free text (not checked against `currencies`); `doc_type` free text; `BankingDocumentUpdate.amount` has no `gt=0`; `received_date` before `request_date` silently gives 0 execution days. | `currency_code` required, validated with `_validate_currency_code`; `doc_type` in {"Form 4","Form 9","Letter of Credit (L/C)"}; `amount: Optional[float] = Field(None, gt=0)`; 400 when received < requested (T13). |
| BE03-F16 | MAJOR | `modules/import_documentation/model.py` (9 tables), `service.py:454-541, 953-1091` | No `created_by` / `updated_by` columns on any of the 9 tables; the `user` argument of ACID, banking, shipment-doc and declaration services is unused. Still open from DOC-26 (deferred, needs a migration). | Alembic migration adding nullable `created_by`, `updated_by` (String(100)) to the 9 tables, no backfill (legacy NULL is honest); services set them from `user` (T18). |
| BE03-F17 | MAJOR | `repository.py:211, 303, 342, 418, 538, 624, 703, 841`; `docs_customs_approval/repository.py:82, 165, 224` | 11 list endpoints return every row with heavy JSON columns (`raw_nafeza_text`, comparison matrices, checklists, extracted data). No `skip`/`limit`, no total. | Add `skip: int = Query(0, ge=0)`, `limit: int = Query(100, ge=1, le=500)` and apply `.offset().limit()`; response shape unchanged (T14). |
| BE03-F18 | MAJOR | `modules/smart_document_upload/router.py:79, 106, 133, 185, 224, 325, 353` | SDU routes are `async def` and call the synchronous OCR / PDF / Excel parsers directly, so one OCR blocks every other request of the single-process server. import_documentation fixed this (plain `def`, DOC-16). | Make the parse routes plain `def` and read with a sync bounded reader, or wrap the service call in `run_in_threadpool` (T15). |
| BE03-F19 | MAJOR | `modules/import_documentation/ai_document_parser.py:388-390` | Document text (ACID, tax IDs, prices) goes to Gemini / Anthropic / OpenAI whenever a key is in the environment; no opt-in setting, no audit. Still open from DOC-20 (Q8 not decided). | Decision first (Q2). Then an explicit `system_parameters` flag `EXTERNAL_LLM_PARSING_ENABLED` default False (T20). |
| BE03-F20 | MAJOR | `service.py:2909-2925, 2930-2984, 5462-5469` | A certified COO review is not locked: a second certified POST overwrites it in place and re-runs the follow-ups (DCA sync, lifecycle); PUT edits a certified review; DELETE removes it. Draft B/L has the lock (`_reject_terminal_draft_bl`), COO does not. | Certified COO: POST certified again -> 409, PUT -> 409 unless only `notes`, DELETE -> 409 (T16). |
| BE03-F21 | MAJOR | `service.py:2491-2577` | New draft B/L version leaves the parent active (a FINAL parent stays active and FINAL), so two active reviews exist for the file and `get_draft_bl_review_by_file_id` order decides which one screens see. `has_blocking_mismatch` comes from the raw compare while locked items were reset to Correct, so the two can disagree. Not `is_draft` aware. | Deactivate a non-FINAL parent on new version (FINAL parent stays as history but the new version needs re-approval); recompute `has_blocking_mismatch` from the new checklist (T07). |
| BE03-F22 | MAJOR | `docs_customs_approval/service.py:976-991`, `original_documents_collection/service.py:368-381`, `lifecycle_board/service.py:375, 480` | `advance_lifecycle_step_service` commits internally, in the middle of use cases documented as one transaction (DCA final session, ODC FULLY_* orchestration). A failure after the lifecycle step leaves the session saved and the lifecycle advanced while the rest rolls back. | Call the lifecycle step last, just before the use-case commit, or pass a `commit=False` flag if the lifecycle service supports it (shared need otherwise) (T17). |
| BE03-F23 | MAJOR | `schemas.py:64, 501, 613-614, 631, 658, 686, 716, 740, 768, 786, 875-877, 919-920`; `router.py:352-356` (Form texts) | Raw text inputs have no `max_length`: unbounded strings reach the regex parsers and (with keys) external LLMs. SDU caps at `MAX_RAW_TEXT_CHARS`. | `Field(None, max_length=200_000)` on every raw text field; Form texts checked with the same constant (T14). |
| BE03-F24 | MINOR | `repository.py:78-87, 171-180` | `_soft_delete` and `restore_acid_session` commit inside the repository (rule: commit in the service). | Flush in the repository; services commit (T17). |
| BE03-F25 | MINOR | `service.py:5645, 5923`, `model.py:514` | Central archive falls back to "EUR" when the file has no currency; PO recon column default "EUR". | Return None (T19). |
| BE03-F26 | MINOR | `router.py:199, 390, 444` and others | `validators.validate_status` is called in the router (business validation in the HTTP layer). | Move into the service functions (T19). |
| BE03-F27 | MINOR | `original_documents_collection/service.py:189-208, 601, 606, 761, 807, 872` | Auto-populate proposes couriers "DHL" / "FedEx" and display paths fall back to "DHL" when the company is empty: an invented carrier is saved if the user keeps the default rows, and the tracking URL points to DHL. | Default couriers with `courier_company=None`; fallback label "" and no tracking URL (T19). |
| BE03-F28 | MINOR | `docs_customs_approval/service.py:942-949` | Session certification stamps both `commercial_signoff_by` and `customs_signoff_by` with the same user; the four-eyes rule exists for approval rows (`validate_distinct_reviewers`) but not for the session. | Keep `commercial_signoff_by` from the earlier draft save; 409 `DCA_SAME_REVIEWER` when equal to the certifying user (T10). |
| BE03-F29 | MINOR | `service.py:1295, 1317-1327` | `total_final_amount` adds line totals across POs of different currencies; packing-only changes do not recompute `PurchaseOrder.total_packages_count`. | Return totals per currency (additive field) and recompute `total_packages_count` from packing rows of touched POs (T01). |

## 3. Tasks

### BE03-T01: PO final adjustment applies each PO line once
- **Severity:** BLOCKER (F01, F29). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes, request semantics: an item with `packing_item_id` set updates only that packing row;
  its `po_item_id` is ignored for line updates. A `po_item_id` present in two items without `packing_item_id` -> 400.
  Response: additive `total_final_amount_by_currency: {"USD": 245.0}`; `total_final_amount` stays (sum of distinct lines).
  Flutter consumer: `frontend/lib/features/import_documentation/widgets/po_reconciliation_tab.dart` (builds the payload,
  lines 966-1006 and 1263) and `providers/import_documentation_provider.dart:854`; no change needed if it keeps sending
  `packing_item_id` on packing rows, but it should stop `plList.addAll(invList)` duplicates (see section 4).
- **Files to change:** `modules/import_documentation/service.py` (1225-1346), `modules/import_documentation/validators.py`,
  `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. Split `request.items` into `line_items = [i for i in items if not i.packing_item_id]` and
     `packing_items = [i for i in items if i.packing_item_id]`.
  2. `validators.validate_unique_po_lines(line_items)`: duplicate `po_item_id` -> 400
     `"بند أمر الشراء رقم {id} مكرر في طلب المطابقة."`.
  3. PO line writes (quantity, unit price, total, line weights/CBM) only from `line_items`. Packing writes only from
     `packing_items` (by `packing_item_id`, after the existing ownership check).
  4. Response totals: amount from `line_items` only; weights/CBM from `packing_items` when any, else from `line_items`.
     Add `total_final_amount_by_currency` using the PO currency (`open_pos[po_id].currency.currency_code`).
  5. For each touched PO with packing changes: `po.total_packages_count = int(sum(qty_pkg of its packing rows))`.
  6. Keep one commit.
- **Acceptance criteria:** a PO line is written by exactly one request item; the response amount equals the sum of the
  stored line totals of the touched lines.
- **Tests to add** (`tests/unit/test_phase03a_service.py`):
  - PO line `item_id=11`, qty 100, unit_price 2.5, total 250.00; packing row 21 (same PO), qty_pcs 1000.
    Request: `{po_item_id:11, final_quantity:98, final_unit_price:2.5}` and
    `{po_item_id:11, packing_item_id:21, final_quantity:1000, final_unit_price:2.5, final_gross_weight_kg:500}`.
    Expect `line.quantity == 98`, `line.total_price == 245.00`, `po.total_amount_fob == 245.00` (single line PO),
    packing row 21 `total_gross_weight_kg == 500`, response `total_final_amount == 245.0`
    (today: quantity 1000, total 2500.00, response 2745.0).
  - Two items with `po_item_id=11` and no `packing_item_id` -> 400.
- **Out of scope:** zero `final_quantity` meaning (Q3), PO status lock after financial approval (Q5).

### BE03-T02: Invoice/B-L sync never relabels the file's estimated-cost currency
- **Severity:** BLOCKER (F02). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes, additive: `/invoice-bl/sessions` (certified) and `/invoice-bl/certify-and-sync` responses
  gain `currency_mismatch: bool`; `currency` in the sync response becomes the invoice currency as sent (was the file
  currency). Flutter consumer: `providers/import_documentation_provider.dart:1041-1067` (reads the session only).
- **Files to change:** `modules/import_documentation/service.py` (4868-4907, 4966-4995, 4998-5036),
  `modules/import_documentation/schemas.py` (InvoiceBLMatchSessionResponse: `currency_mismatch: Optional[bool] = None`),
  `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. In `_apply_invoice_bl_sync` keep `_validate_currency_code` (400 on unknown) but delete the write
     `imp_file.estimated_cost_currency = currency`.
  2. Return `currency_mismatch = currency is not None and currency != imp_file.estimated_cost_currency` from the helper
     and expose it in both responses.
- **Acceptance criteria:** after any invoice/B-L certification, `estimated_cost` and `estimated_cost_currency` are unchanged.
- **Tests to add:** file `estimated_cost=24500.0`, `estimated_cost_currency="EUR"`; certify a session with
  `invoice_data={"invoice_number":"INV-9","currency":"USD","incoterm":"FOB"}` and `bl_data={"draft_bl_number":"MEDU1"}`
  -> file still `24500.0 EUR`, `pi_number=="INV-9"`, `currency_mismatch is True`. Financial approval invoice part
  fallback for that file (no PO parts, empty `invoices_data`) returns `(24500.0, "EUR")`.
- **Out of scope:** a real invoice amount column on ImportFile (deferred, see DOC-13).

### BE03-T03: Smart-upload invoice apply is idempotent and does not overwrite the estimate
- **Severity:** BLOCKER (F03). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: `ApplyInvoiceRequest.invoice_data.invoice_number` required when `import_file_id` is set
  (400 `SDU_INVOICE_NUMBER_REQUIRED`, register the code in `modules/common/system_messages.py` +
  `docs/system_message_codes.json` or list it in `docs/plans/review-shared-needs.md`); response `params.replaced: bool`.
  No Flutter caller (`/smart-upload/apply/*` unused).
- **Files to change:** `modules/smart_document_upload/service.py` (647-718), `modules/smart_document_upload/validators.py`,
  `tests/unit/test_smart_document_upload.py`.
- **Steps:**
  1. Normalize key `strip().upper()` of `invoice_number`; find an existing `invoices_data` row with the same key; replace
     it in place, else append.
  2. Remove `file_record.estimated_cost = data.invoice_value` and the currency overwrite (same reason as T02).
  3. No `INV-<n>` fallback.
- **Acceptance criteria:** applying the same invoice N times leaves one row.
- **Tests to add:** empty `invoices_data`; apply `{invoice_number:"inv-77", invoice_value:10000, currency:"USD"}` twice
  -> `len(invoices_data)==1`, `invoices_count==1`, `sum(amount)==10000.0` (today 20000.0), `estimated_cost` unchanged.
- **Out of scope:** `/apply/bill-of-lading`.

### BE03-T04: Gate or remove `/invoice-bl/certify-and-sync`
- **Severity:** CRITICAL (F04). **Depends on:** T02 (same helper).
- **Schema/migration needed:** no.
- **API contract change:** yes: the route now syncs from the file's active certified `InvoiceBLMatchSession`; the body's
  `invoice_data` / `bl_data` are ignored; no certified session -> 409 `DOC_INVOICE_BL_NOT_CERTIFIED` (register code).
  If Q4 says remove: route returns 410 for one release. No Flutter caller.
- **Files to change:** `modules/import_documentation/router.py` (830-840), `modules/import_documentation/service.py`
  (4897-4907, 4966-4995), `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. Load `repo.get_invoice_bl_match_session_by_file_id(db, file_id, include_drafts=False)`; 409 if none.
  2. Use `session.invoice_data` / `session.bl_data`.
  3. Container sync: merge by `container_no` (keep existing `vgm_status`, `tracking_status`), same algorithm as
     `smart_document_upload/service.py:758-780`.
- **Acceptance criteria:** the route cannot approve any `CustomsDocumentApproval` row or advance the lifecycle without a
  certified session.
- **Tests to add:** no session -> 409 and `CustomsDocumentApproval.commercial_status` unchanged; with a certified session
  -> file `bl_number` equals the session's `bl_data.draft_bl_number`; existing container `{container_no:"MSCU1",
  vgm_status:"Verified"}` keeps `vgm_status` after a sync that sends `{container_no:"MSCU1", seal_no:"S1"}`.
- **Out of scope:** session certification rules (T05).

### BE03-T05: Server-owned gate fields for invoice/B-L and PO reconciliation sessions
- **Severity:** CRITICAL (F05). **Depends on:** none.
- **Schema/migration needed:** no (columns keep their DB defaults; the API stops relying on them).
- **API contract change:** yes: create schemas `InvoiceBLMatchSessionCreate`, `POReconciliationSessionCreate`:
  `is_safe_for_certification`, `critical_discrepancies_count`, `warning_discrepancies_count`, `overall_status`,
  `match_score_percentage` are ignored (server computed). `POReconciliationSessionCreate.currency` required (3-letter,
  active in `currencies`), no default. Flutter consumers: `providers/import_documentation_provider.dart:909-968,
  1041-1067`, `models/po_reconciliation_session_model.dart`, `widgets/po_reconciliation_tab.dart` (must send currency).
- **Files to change:** `modules/import_documentation/schemas.py` (949-1030), `modules/import_documentation/service.py`
  (4998-5036, 5319-5410), `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. Invoice/B-L create: when `invoice_data` and `bl_data` are present, run `match_invoice_with_bl(invoice_data, bl_data,
     _build_system_bl_snapshot(db, file_id), packing_list_data)` and copy its `overall_status`,
     `is_safe_for_certification`, `match_score_percentage`, counts and `comparison_matrix` onto the payload. Without
     both: `is_safe_for_certification=False`, `overall_status="DISCREPANCY_DETECTED"`. Keep the justification rule at 5020.
  2. PO recon create/update: when `extracted_invoice_data` present, recompute with
     `reconcile_po_documents_with_system` (same inputs as `extract_and_compare_po_documents_service`); otherwise
     `is_safe_for_certification=False`, `overall_status="DRAFT"`. `_po_recon_lifecycle` then fires only on server values.
  3. Schema defaults: `is_safe_for_certification: bool = False`, `overall_status: str = "DRAFT"` (invoice/B-L:
     `"DRAFT_SAVED"`), `currency: str = Field(..., min_length=3, max_length=3)` on PO recon create.
- **Acceptance criteria:** an empty POST never advances STEP_08_PO; a certified invoice/B-L session with a server-found
  critical mismatch requires notes.
- **Tests to add:** POST `/po-reconciliation/sessions` `{import_file_id, currency:"USD"}` -> `is_safe_for_certification
  False`, lifecycle STEP_08_PO not completed; POST without currency -> 422. Invoice/B-L certify with
  `invoice_data.total_gross_weight_kg=1000`, `bl_data.total_gross_weight_kg=1500` and client
  `is_safe_for_certification=true`, no notes -> 400.
- **Out of scope:** recoding status labels.

### BE03-T06: ACID verification status is derived on the server
- **Severity:** CRITICAL (F06). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: `AcidRegistrationUpdate.status`, `is_*_matched`, `has_discrepancies` are ignored
  (accepted for old clients). New error 409 `DOC_ACID_CONFLICT` (register code). Flutter consumer:
  `providers/import_documentation_provider.dart:73-182` and the ACID screen that sends `status` (it must stop relying on
  sending "Verified"; it sends `discrepancy_override_reason` instead).
- **Files to change:** `modules/import_documentation/service.py` (321-541), `modules/import_documentation/repository.py`
  (131-136), `modules/import_documentation/validators.py`, `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. `validators.acid_flags(discrepancies_data) -> (importer, exporter, invoice, ports, has_disc)`: a key counts as a
     mismatch when its entry has `match` False / `status` not "MATCH" (follow the shape produced by
     `compare_acid_datasets_service`, service.py:775).
  2. `_apply_acid_derived_fields`: set the flags; status = "Requested" when number pending or no `generated_date`;
     "Verified" when no discrepancy; "Discrepancy_Accepted" when discrepancies and `discrepancy_override_reason`
     non-empty; otherwise 400 `"يوجد اختلافات في بيانات الـ ACID: يجب كتابة مبرر قبول الاختلافات."`.
  3. Update: drop `status` and the flags from the payload before `repo.update_acid_session`.
  4. File sync (321-335): if `imp.acid_number` is a different 19-digit number -> 409 before the session commit.
- **Acceptance criteria:** STEP_05 -> STEP_06 fires only for a server-derived Verified / Discrepancy_Accepted session.
- **Tests to add:** create with 19-digit number, `generated_date`, `discrepancies_data` showing an exporter mismatch and
  no override -> 400; with override -> status "Discrepancy_Accepted", `has_discrepancies True`. PUT `{status:"Verified"}`
  on a Requested session -> status stays Requested. File ACID `1111111111111111111`, session `2222222222222222222` -> 409.
- **Out of scope:** expiry rules (DOC-15 done).

### BE03-T07: Draft B/L blocking flags and versions are server-owned
- **Severity:** CRITICAL (F07, F21). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: PUT `/draft-bl/{id}` ignores `has_blocking_mismatch`, `open_discrepancies_count`,
  `revision_report_data`. Flutter consumer: `providers/import_documentation_provider.dart:442-496` and the draft B/L
  review widget (no change if it sends `checklist_data`).
- **Files to change:** `modules/import_documentation/service.py` (2199-2352, 2491-2577), `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. Add the three fields to `_DRAFT_BL_SERVER_OWNED`.
  2. Update: merged checklist = `clean.checklist_data` if sent else `review.checklist_data`; `open_count` and
     `has_blocking` always from it (`_checklist_has_blocking`).
  3. Create, certified save (`is_draft False`) without `checklist_data`: always run `compare_draft_bl_service`, ignore a
     client `comparison_matrix`.
  4. New version: after creating it, set `parent.is_active=False` unless `parent.status in DRAFT_BL_TERMINAL_STATUSES`;
     `has_blocking_mismatch = _checklist_has_blocking(new_checklist)`; one commit.
- **Acceptance criteria:** approval is impossible while the stored checklist has an Incorrect/Missing critical field.
- **Tests to add:** review REVISION_REQUIRED with checklist `consignee` Incorrect; PUT
  `{has_blocking_mismatch:false, open_discrepancies_count:0}` -> status stays REVISION_REQUIRED; `/dual-approval` -> 400.
  New version from a REVISION_REQUIRED parent -> parent `is_active False`, one active review for the file.
- **Out of scope:** role-to-user mapping for importer/broker approval (Q6).

### BE03-T08: DCA final session requires real approvals
- **Severity:** CRITICAL (F08). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: final save validates the five statuses (`Approved`; `coc_status` also
  `Waived / Not Required`) and the matching approval rows; `overall_status` in the body ignored (server sets
  "APPROVED" on final, "DRAFT" on draft). 400 `DCA_SESSION_NOT_READY` gets a new list `unapproved_documents`. Flutter
  consumer: `providers/docs_customs_approval_provider.dart:306-330` and the session screen (show the new list).
- **Files to change:** `modules/docs_customs_approval/service.py` (877-993), `modules/docs_customs_approval/validators.py`,
  `modules/docs_customs_approval/schemas.py` (171-235), `tests/unit/test_docs_customs_approval.py`.
- **Steps:**
  1. `validators.SESSION_STATUS_VALUES = {"Approved","Rejected","Pending","Waived / Not Required"}`; validate every sent
     status (422 otherwise), draft or final.
  2. Final: each of `final_invoice_status`, `final_pl_status`, `draft_bl_status`, `coo_status` must be "Approved",
     `coc_status` "Approved" or "Waived / Not Required".
  3. Final: for document types Commercial Invoice, Packing List, Bill of Lading, Certificate of Origin (and Inspection
     Certificate unless COC waived) the active approval row must have `overall_status == "Approved for Clearance"`;
     missing or not approved -> listed in `unapproved_documents`.
  4. `overall_status` set by the service.
- **Acceptance criteria:** STEP_09 -> STEP_10 fires only when the five documents are approved in the DCA hub.
- **Tests to add:** final save with `final_invoice_status="Rejected"` -> 400, lifecycle not advanced; all "Approved" but
  the B/L approval row "Under Review" -> 400 with `unapproved_documents == ["Bill of Lading"]`; all approved -> 201,
  `overall_status == "APPROVED"`.
- **Out of scope:** four-eyes on the session (T10).

### BE03-T09: Document workflows fire once per transition
- **Severity:** MAJOR (F09). **Depends on:** T06.
- **Schema/migration needed:** no.
- **API contract change:** no.
- **Files to change:** `modules/import_documentation/service.py` (294-428, 803-1019), `tests/unit/test_phase03a_service.py`.
- **Steps:**
  1. Capture `(previous_status, previous_ref)` before the save in ACID create-upsert/update and banking update/receive;
     pass to the workflow.
  2. Lifecycle / task / notification only when the entity moves into the issued state (was not issued before, or the
     reference number changed).
  3. Task creation: skip when an active non-completed `SmartTask` exists with the same `import_file_id` and `msg_code`.
- **Acceptance criteria:** saving a verified ACID twice creates one freight-booking task and one notification.
- **Tests to add:** ACID verified create, then PUT `notes="x"` -> `SmartTask` count with `msg_code
  "DOC_TASK_FREIGHT_BOOKING"` == 1, notifications `DOC_ACID_REGISTERED` == 1. Banking receive twice -> one
  `DOC_TASK_DECLARATION_46` task.
- **Out of scope:** file sync on every save (keep).

### BE03-T10: DCA ticket status workflow and session four-eyes
- **Severity:** MAJOR (F10, F28). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: PUT `/tickets/{id}` `status` limited to `Open` / `Sent to Supplier` (422 otherwise);
  PUT on a closed ticket -> 409 `DCA_TICKET_CLOSED`. Final session by the same user who did the commercial sign-off ->
  409 `DCA_SAME_REVIEWER`. Flutter: `providers/docs_customs_approval_provider.dart` (ticket edit dialog must use resolve
  for closing).
- **Files to change:** `modules/docs_customs_approval/service.py` (814-841, 937-949), `modules/docs_customs_approval/router.py`
  (121-131), `modules/docs_customs_approval/validators.py`, `tests/unit/test_docs_customs_approval.py`.
- **Steps:** router passes `current_user.username`; service: `validate_ticket_open(ticket)` first; status via
  `normalize_label(..., OPEN_TICKET_STATUSES, ...)`; session: keep the existing `commercial_signoff_by` on final and
  call `validate_distinct_reviewers`.
- **Tests to add:** PUT `{status:"Closed"}` -> 422 and ticket still Open; resolve then PUT -> 409; draft session by
  user A, final by A -> 409, by B -> 201.
- **Out of scope:** ticket audit columns.

### BE03-T11: Real PO sources in compare and DCA matrix
- **Severity:** MAJOR (F11, F12). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes, additive: `POExtractAndCompareResponse.system_items_missing: bool = False`;
  `file_metadata.currency` may be null. System packing rows expose `packing_item_id` (and `po_item_id` = matching line
  id or null). Flutter consumer: `widgets/po_reconciliation_tab.dart` (show "no PO lines" state).
- **Files to change:** `modules/import_documentation/service.py` (5057-5245), `modules/import_documentation/schemas.py`
  (POExtractAndCompareResponse), `modules/docs_customs_approval/service.py` (113-116), `tests/unit/test_phase03a_service.py`,
  `tests/unit/test_docs_customs_approval.py`.
- **Steps:** active filters on ImportFile and PurchaseOrder; all active POs of the file (not `.first()`); no "USD"
  default; no system items built from the invoice; packing defaults `qty_pkg` None / `package_type` None; DCA
  `_po_for_file` filters `import_file_id` + `is_active` and returns the single PO or None when several (matrix shows Not
  Checked, Q7 of 03a).
- **Tests to add:** soft-deleted PO on the file -> not used; file with no PO lines and an invoice -> 
  `system_items_missing True`, `is_safe_for_certification False`; DCA with PO of another file sharing `po_number` -> HS
  check Not Checked.
- **Out of scope:** multi-PO aggregation.

### BE03-T12: Inspection draft template without invented standards
- **Severity:** MAJOR (F13). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: `template_data.coc_number` "" ; `applicable_standards` may be empty; new entries in
  `missing_fields` (`adopted_standard`, `coc_number`). Flutter consumer: inspection review widget (shows missing fields).
- **Files to change:** `modules/import_documentation/service.py` (4239-4295), `tests/unit/test_phase03a_service.py`.
- **Steps:** keep keyword mapping only for matched categories; else `product_type=""`, `adopted_standard=""`; remove the
  default standards list; `coc_number=""`; description without "brand: Standard"; quantity text empty when unknown.
- **Tests to add:** PO line "Steel bolts" -> item `adopted_standard == ""` and `"adopted_standard" in missing_fields`;
  no lines -> `applicable_standards == []`.
- **Out of scope:** a real product-to-standard master table (Q8).

### BE03-T13: Declaration 46 and banking document validation
- **Severity:** MAJOR (F14, F15). **Depends on:** none.
- **Schema/migration needed:** no (columns stay NOT NULL with DB defaults; create sends explicit values or the service
  writes 0.0 only where the column needs it, flagged; see step 1).
- **API contract change:** yes: Declaration create: `total_*_egp` `Optional[float] = Field(None, ge=0)` (stored 0.0 only
  because the column is NOT NULL; response returns them as sent: add `amounts_entered: bool`), ACID digits-only and equal
  to file ACID (409), one active draft per file (409). Banking: `currency_code` required and active, `doc_type` enum,
  update `amount gt=0`. Flutter: banking form (`providers/import_documentation_provider.dart:216-277`) must send currency.
- **Files to change:** `modules/import_documentation/schemas.py` (171-201, 278-290), `modules/import_documentation/service.py`
  (953-1091), `modules/import_documentation/validators.py`, `tests/unit/test_phase03a_service.py`.
- **Steps:** as in the fix column of F14/F15; banking receive: 400 when `received_date < request_date`.
- **Tests to add:** banking create without currency -> 422; `currency_code="XYZ"` -> 400; receive with received
  2026-01-01 and request 2026-02-01 -> 400; declaration ACID `"12345678901234567AB"` -> 400; second declaration for the
  file -> 409.
- **Out of scope:** computing duties (customs engine, phase 06).

### BE03-T14: Pagination and raw text limits
- **Severity:** MAJOR (F17, F23). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes, additive query params `skip` (default 0) / `limit` (default 100, max 500) on the 11 list
  routes; response stays a list (total via `X-Total-Count` header). Raw text > 200,000 chars -> 422. Flutter: list
  providers keep working with the default 100 (lists today are per file in practice).
- **Files to change:** `modules/import_documentation/router.py`, `modules/import_documentation/repository.py`,
  `modules/import_documentation/schemas.py`, `modules/docs_customs_approval/router.py`, `modules/docs_customs_approval/repository.py`.
- **Steps:** add params, `.offset(skip).limit(limit)`, header via `Response`; `MAX_RAW_TEXT_CHARS = 200_000` in
  `import_documentation/validators.py` and `Field(max_length=...)` on every raw text field listed in F23.
- **Tests to add (in `tests/unit/test_phase03a_import_documentation.py`):** 3 ACID sessions, `limit=2` -> 2 rows and
  header `X-Total-Count: 3`; `raw_text` of 200,001 chars -> 422.
- **Out of scope:** ODC and SDU (already limited).

### BE03-T15: Smart-upload parsing off the event loop
- **Severity:** MAJOR (F18). **Depends on:** none.
- **Schema/migration needed:** no. **API contract change:** no.
- **Files to change:** `modules/smart_document_upload/router.py`, `modules/smart_document_upload/validators.py`,
  `tests/unit/test_smart_document_upload_api.py`.
- **Steps:** add sync `read_validated_upload_sync(file)` (reads `file.file.read(MAX+1)`), convert the 7 routes to `def`.
- **Tests to add:** the existing API tests stay green; assert the routes are not coroutine functions
  (`inspect.iscoroutinefunction(router.parse_document_for_module) is False`).
- **Out of scope:** OCR performance.

### BE03-T16: Certified COO review is locked
- **Severity:** MAJOR (F20). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** yes: POST certified when one exists -> 409; PUT on certified -> 409 except `notes`; DELETE on
  certified -> 409. Flutter: COO review widget (offer "new review" only via draft).
- **Files to change:** `modules/import_documentation/service.py` (2864-2984, 5462-5469), `tests/unit/test_phase03a_service.py`.
- **Tests to add:** certified COO exists; second certified POST -> 409 and lifecycle call count unchanged; DELETE -> 409.
- **Out of scope:** COO versioning (Q9).

### BE03-T17: Transaction hygiene
- **Severity:** MAJOR (F22, F24). **Depends on:** none.
- **Schema/migration needed:** no. **API contract change:** no.
- **Files to change:** `modules/import_documentation/repository.py` (78-87, 171-180), `modules/import_documentation/service.py`
  (789-799, delete services 1022-1025, 5413-5481), `modules/docs_customs_approval/service.py` (976-991),
  `modules/original_documents_collection/service.py` (338-381), `tests/unit/test_phase03b_regressions.py`.
- **Steps:** repository flush only, service commits; in DCA and ODC move the lifecycle call to be the last step before
  `db.commit()` (it commits by itself, so nothing that can fail runs after it).
- **Tests to add:** monkeypatch `set_file_tracking` to raise in DCA final -> session not certified and lifecycle not
  advanced (step order proves it).
- **Out of scope:** changing the lifecycle service signature (shared need if a `commit=False` flag is wanted).

### BE03-T18: Audit columns on import documentation tables
- **Severity:** MAJOR (F16). **Depends on:** none.
- **Schema/migration needed:** yes: new Alembic revision adding `created_by VARCHAR(100) NULL`, `updated_by VARCHAR(100) NULL`
  to `acid_registration_sessions`, `banking_document_sessions`, `shipment_document_items`, `customs_declaration_drafts`,
  `draft_bl_review_sessions`, `certificate_of_origin_review_sessions`, `inspection_certificate_review_sessions`,
  `po_packing_reconciliation_sessions`, `invoice_bl_match_sessions` (nullable, no backfill: unknown author stays NULL).
  Skip a table that already has the column (check with `sa.inspect`).
- **API contract change:** yes, additive `created_by` / `updated_by: Optional[str]` on the response schemas. Flutter: none.
- **Files to change:** `alembic/versions/<new>_import_documentation_audit_by.py`, `modules/import_documentation/model.py`,
  `modules/import_documentation/schemas.py`, `modules/import_documentation/service.py`, `tests/unit/test_phase03a_service.py`.
- **Tests to add:** create ACID as user "u1" -> `created_by == "u1"`; legacy row with NULL lists fine.
- **Out of scope:** `deleted_by`.

### BE03-T19: Minor hygiene
- **Severity:** MINOR (F25, F26, F27). **Depends on:** none.
- **Schema/migration needed:** no.
- **API contract change:** central archive `currency` may be null; ODC auto-populate default couriers have
  `courier_company: null`. Flutter: ODC screen must allow choosing the company.
- **Files to change:** `modules/import_documentation/service.py` (5645, 5923), `modules/import_documentation/router.py`
  (validate_status calls -> service), `modules/original_documents_collection/service.py` (189-208, 601, 606, 761, 807, 872),
  `tests/unit/test_original_documents_collection.py`.
- **Tests to add:** auto-populate default couriers have `courier_company is None`; central archive of a file with no
  recon session and empty currency -> `currency is None`.

### BE03-T20: External LLM parsing behind an explicit setting (after Q2)
- **Severity:** MAJOR (F19). **Depends on:** CTO decision Q2.
- **Schema/migration needed:** no (a `system_parameters` row seeded by the existing seed path).
- **API contract change:** no.
- **Files to change:** `modules/import_documentation/ai_document_parser.py` (388-397), seed of system parameters (shared
  need), `tests/unit/test_pl04_smart_doc_extraction.py`.
- **Steps:** read `EXTERNAL_LLM_PARSING_ENABLED` (default False); without it never call external providers even with keys;
  log one audit line (provider, document kind, chars sent, no content) per call.
- **Tests to add:** keys set, flag False -> no HTTP call (monkeypatch the client to raise).

## 4. Frontend impact

- `/po-reconciliation` (T01): packing rows must send `packing_item_id`; the matching `po_item_id` on a packing row no
  longer changes the PO line. Remove `plList.addAll(invList)` in `po_reconciliation_tab.dart` (sends every line twice).
  Show `total_final_amount_by_currency` when present.
- `/po-reconciliation/sessions` (T05): send `currency` (required); stop sending `is_safe_for_certification` /
  `overall_status` / counts as decisions (ignored).
- `/invoice-bl/sessions` (T02, T05): read `currency_mismatch`; certification may now return 400 asking for notes when
  the server finds a critical mismatch.
- `/acid-sessions` (T06): `status` and match flags are server-derived; send `discrepancy_override_reason` to accept
  discrepancies; handle 409 `DOC_ACID_CONFLICT`.
- `/draft-bl/{id}` PUT (T07): `has_blocking_mismatch` / `open_discrepancies_count` ignored; send `checklist_data`.
- `/docs-customs-approval/sessions` (T08, T10): handle `unapproved_documents` in 400 `DCA_SESSION_NOT_READY` and 409
  `DCA_SAME_REVIEWER`; tickets are closed only via `/resolve`.
- Banking form (T13): `currency_code` required, chosen from the currencies master (SearchableDropdownField).
- Lists (T14): default page of 100; no change needed for per-file screens.
- COO (T16): certified review read-only; 409 on edit/delete.
- New coded errors to add to Flutter catalogs: `DOC_ACID_CONFLICT`, `DOC_INVOICE_BL_NOT_CERTIFIED`,
  `SDU_INVOICE_NUMBER_REQUIRED`.

## 5. Open questions for the CTO

1. **Q1 (F01):** in the final adjustment, is the invoice row the only source of the PO line quantity and price, with the
   packing row only for packages / weights / CBM? (Safe default: yes.)
2. **Q2 (F19):** may document text be sent to external LLMs at all? If yes, opt-in per installation and which providers?
   (Safe default: disabled.)
3. **Q3 (F01):** `final_quantity = 0` today zeroes the PO line (a short shipment), while 0 means "unchanged" for price,
   weight and CBM. Keep 0 = not shipped? (Safe default: keep, but require `notes` on a zeroed line.)
4. **Q4 (F04):** remove `/invoice-bl/certify-and-sync` (no Flutter caller) or keep it gated by a certified session?
   (Safe default: gate.)
5. **Q5:** the final adjustment changes `total_amount_fob` of a PO already approved in Phase 2 (only CLOSED / CANCELLED are
   blocked). Should a post-approval change need financial re-approval or a variance threshold?
6. **Q6 (F07):** any `import_documentation.approve` holder can approve as "importer" or "customs_broker". Should the broker
   role require `customs_clearance.update`? (Safe default: yes for `customs_broker`.)
7. **Q7 (F08):** for the DCA final session, is "Approved for Clearance" on each approval row the right gate, or is the
   commercial tier enough for Inspection / Fumigation?
8. **Q8 (F13):** is there an authoritative product-category -> Egyptian standard (ES) list to seed as master data?
9. **Q9 (F20):** should a certified COO be corrected through a new version (like draft B/L) or via an unlock by an approver?
