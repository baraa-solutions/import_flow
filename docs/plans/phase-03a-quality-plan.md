# Phase 3a "Import Documentation" (backend `modules/import_documentation/`): quality audit and fix plan

Status: proposed (2026-10-05). Static reading only: no pytest, no `import main`. Same method and severity scale as
`docs/plans/phase-01-quality-simplify-plan.md` (BLOCKER / CRITICAL / MAJOR / MINOR). Phase 3b/3c (other Phase 3
modules) and the Flutter side are out of scope. Shared helpers from Phase 1 A1 (`docs/plans/phase-01-progress.md`) are reused.

## Audit coverage (about 5,400 of 13,072 lines read line by line; the rest grep-scanned)

| File (lines) | Depth |
|---|---|
| `router.py` (897) | Full |
| `validators.py` (112) | Full |
| `repository.py` (949) | Read l.1-620 and 760-949. l.620-760 (inspection/REC code gen) checked with grep |
| `service.py` (5332) | Read: 1-1255 (ACID, banking, shipment docs, Dec 46, PO final adjustments, B/L snapshot), 1290-2210 (upload/OCR, draft B/L compare + full review workflow), 2221-2240, 2340-2490, 2600-2735 (COO/inspection create/update), 4013-4882 (legal compliance, invoice-B/L, PO reconciliation, thin CRUD wrappers). Grep only: COO/inspection compare bodies, template generators 2863-3783, `extract_document_service`, `cross_match_certificates_service`, `get_central_archive_service` (4875-5332) |
| `schemas.py` (1071) | Status fields, update schemas, `POReconciliationItem`, `POFinalAdjustmentRequest`, draft-B/L and approval schemas |
| `model.py` (598) | Grep: tables, uniques, FKs, audit columns |
| `ai_document_parser.py` (3427) | LLM dispatch only (l.375-420, 2495-2600). Not audited: heuristics |
| `nafeza_acid_parser.py`, `arabic_ocr_engine.py` | Not audited (pure parsers, also used by `modules/smart_document_upload`) |

---

## 1. Findings

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| DOC-01 | BLOCKER | `router.py:14-895` | None of the 55 routes declares `require_permission`, only router-level `get_current_user`. A viewer can create or edit ACID sessions, Form 4, PO quantities (`/po-reconciliation`), approve a B/L, and overwrite import-file data. | code | Per-route `Depends(require_permission(...))` using existing codes: GET and pure compare/parse/template routes (`/acid/parse-text`, `/acid/compare`, `/acid/templates`, `*/compare`, `*/draft-template/*`, `/legal-compliance`, `/central-archive`) get `import_documentation.view`. Every mutating route and every upload/extract route (these call OCR and optional external LLMs) gets `import_documentation.upload`. Approval routes (`/draft-bl/{id}/approve`, `/draft-bl/dual-approval`) get the new `import_documentation.approve` (Shared needs). Until it is registered, use `import_documentation.upload`. See Q1. |
| DOC-02 | BLOCKER | `service.py:996-1065` | `reconcile_po_final_adjustments_service` corrupts PO data:<br>(a) l.1026 loads `PackingListItem` with `packing_item_id == itm.po_item_id`. That is a PO line id, from a different id space, so it overwrites an unrelated packing row, possibly on another PO.<br>(b) l.1013 updates any `POLineItem` by id. It does not check that the line belongs to an active PO of `request.import_file_id`, or that the PO is not CANCELLED or CLOSED.<br>(c) It does not bump the PO `version` and does not set `updated_by`, so Phase 1 optimistic locking misses the change. PO header totals stay stale.<br>(d) l.1018 `total_price` is not rounded (PO rule: `round(q*p, 2)`).<br>(e) `final_quantity` and the weights have no `ge=0`.<br>(f) The import file is not checked for `is_active`.<br>(g) `approved_by` comes from the client, default "Kamal". | code | Validate ownership in `validators.validate_po_lines_belong(db, import_file_id, ids)` and return 400 with an Arabic detail. Remove the lookup by `po_item_id` at l.1026. Add an optional `packing_item_id` to `POReconciliationItem` (additive) and update a packing row only by that id, after the same ownership check. Round `total_price`. Bump `PurchaseOrder.version` and set `updated_at`/`updated_by` once per touched PO. Use one commit. Q2 covers header recompute. Route to `customs-rules-reviewer`. |
| DOC-03 | BLOCKER | `service.py:1197-1218, 2227, 2243, 2375-2379, 2468-2469, 2481, 2901-2905, 3191-3192, 3216, 3437-3459, 3644-3654, 3747` | Fabricated customs data stands in for missing system values:<br>- ACID numbers `"7595528271015010011"` and `"7595528271020210010"`<br>- origin "Lithuania", "Italy", or "China"<br>- HS code `"560229"`<br>- invoice numbers "INV-FINAL" and "INV-2026-FINAL"<br>- B/L placeholders "OCEAN VESSEL", "VOY-01", "BKG-REF", and a fake consignee address and phone<br>- a real third-party importer and exporter name and address (l.3650-3654)<br>Where these values go:<br>- They feed the comparison engines. A critical field like `booking_no` or `acid_number` gets a false BLOCKING mismatch, and the correction letter asks the carrier to print "BKG-REF".<br>- They are persisted in `system_snapshot_data` and in `country_of_origin` (COO create l.2379).<br>- They prefill official COO and VoC draft templates. | code | Missing system value: return `None` (snapshot) or `""` (template). Add `missing_fields: List[str]` to the template responses (additive). COO certified save without a known origin returns 400 with an Arabic detail; the service no longer stores a default origin, "Exporter", or "Importer". Keep descriptive defaults such as "Carton" and "Freight Prepaid" (Q3). Route to `customs-rules-reviewer`. |
| DOC-04 | CRITICAL | `service.py:1912-1923, 1962-1963`, `schemas.py:504`, `service.py:1975-1989, 2053-2103, 2181-2203`, `router.py:502-532` | Draft B/L approval can be bypassed:<br>(a) Create with the default `status="AUTO_COMPARISON_RUN"` and no discrepancies becomes APPROVED and runs `_complete_draft_bl_review_workflow`, which writes `ImportFile.bl_number`, approves the customs B/L document, and advances the lifecycle, without any approval. A client can also send `status="APPROVED"`, or send its own `checklist_data`/`has_blocking_mismatch`.<br>(b) PUT `/draft-bl/{id}` sets any `status`, `stage`, or `*_approval_status`, even on a FINAL review.<br>(c) `/approve` sets both the importer and broker approvals for one caller, named by a query param that defaults to "Kamal".<br>(d) Dual approval: one user can approve both roles. A FINAL review can be approved again, which re-runs the side effects. `action` is free text: anything other than "Approved" counts as a rejection.<br>(e) Two terminal codes exist: APPROVED (create) and FINAL (approval). | code | The server owns `status`, `stage`, and the approval fields:<br>- Create and PUT ignore them from the client. Create ends at REVIEWED_PENDING_APPROVAL at most. PUT on FINAL or APPROVED returns 409.<br>- `/dual-approval`: `role` and `action` become `Literal`. The approver is `current_user.username`. The same user cannot hold both roles (409). FINAL returns 409.<br>- `/approve` stays as a single-step override for `import_documentation.approve` holders and records `current_user`.<br>- Q4 covers whether a certified save should still mean approval. |
| DOC-05 | CRITICAL | `service.py:2106-2178`, `repository.py:407-422` | New draft version:<br>(a) `draft_bl_number=f"{parent}-v{n}"`. On approval, `MEDU123-v2` is written to `ImportFile.bl_number`, `CargoShippingRecord.bl_number`, and the customs approval ref (l.1711, 1731, 1747).<br>(b) The code is `f"{parent_code}-v{n}"`. Two versions from the same parent collide (IntegrityError, 500).<br>(c) `generate_bl_review_code` takes the last row by id. When that row is a `-vN` code, `int()` fails and it returns `...-0001`, which already exists (500 on the next create).<br>(d) The parent stays active and may be FINAL. | code | Keep `draft_bl_number = parent.draft_bl_number`; `version_number` carries the version. Allow a new version only from the latest active version of the chain (409 otherwise). Code: `f"{root_code}-v{n}"` with n = max+1. Use `next_yearly_code(db, DraftBLReviewSession.bl_review_code, "BL-REV", pad=4)`, which ignores non-digit suffixes. |
| DOC-06 | CRITICAL | `service.py:2381-2399, 2621-2652, 2655-2674` | COO certified save:<br>- The `override_reason` check runs only when status is Verified, Approved, or Discrepancy_Accepted. Compare returns "Correction Requested" on a critical mismatch, so the check is skipped and l.2392 forces "Approved", then advances the lifecycle to STEP_09.<br>- The upsert picks drafts and certified rows alike, so a later draft save overwrites a certified review back to "Draft Generated".<br>Inspection: the client-sent status decides the outcome and drives the lifecycle advance on create and update. | code | Certified save with `has_discrepancies` or `has_critical_mismatch` requires `override_reason` (400, Arabic), whatever the status. A draft save never overwrites a certified review (409). Inspection uses the same rule. The status is computed server-side from compare results plus `override_reason`. |
| DOC-07 | CRITICAL | `repository.py:368, 494, 602, ~699, 810, 927`, `service.py:4287` | Not-found raises `ValueError`, which the global handler turns into a 500, on cargox-bl, draft-bl PUT, COO PUT, inspection PUT, PO-recon and invoice-B/L update. Also an unguarded `float(bl["total_gross_weight_kg"])`. | code | Services load with active filter and raise `validators.not_found("<label>", id)`. Bad numbers give 400 with an Arabic detail. |
| DOC-08 | CRITICAL | `repository.py:491-502, 599-610, 696-708, 803-818, 920-935` | `update_*` queries ignore `is_active` and set `is_active = True`, so a PUT on a soft-deleted row silently restores it. COO and inspection PUT call the repository directly. | code | Updates load active rows only (404 otherwise) and never touch `is_active`. ACID keeps its `/restore` endpoint. |
| DOC-09 | CRITICAL | `model.py:505` vs `service.py:4673` | `po_packing_reconciliation_sessions.import_file_id` is `unique=True`, but the duplicate check sees only active rows. After a delete, creating a new session gives an IntegrityError (500), and the file can never get a session again. | code | No schema change. On create, if an inactive row exists for the file, update it in place, reactivate it, and audit it as CREATE (Q5). |
| DOC-10 | CRITICAL | `repository.py:381-403` | The declaration code is the constant `DEC46-{year}-001`. The second declaration of a year fails with IntegrityError (500). | code | `next_yearly_code(db, CustomsDeclarationDraft.declaration_code, "DEC46")`, plus `require_active` on `import_file_id`. |
| DOC-11 | MAJOR | `service.py:240-333, 692-801, 1703-1853, 2402-2447, 2638-2650, 4290-4361, 4685-4713, 4809` | Multi-commit workflows: each side step commits, and `except Exception` logs without rolling back. One failed flush leaves the session in PendingRollback, so the next steps fail, and the caller's final commit (`process_dual_approval` l.2101) raises a 500 after the main entity was already saved. The outer `except` at l.1852 hides everything. l.4809 is `except: pass`. | code | Commit the main entity first. Run each follow-up (file sync, lifecycle, task close, task create, notification, audit) through `errors.best_effort(db, fn, label)`, with each fn committing its own work. Keep the step order. |
| DOC-12 | MAJOR | `router.py:506, 530`, `schemas.py:370, 451`, `service.py:1956, 1985, 2022, 2415, 4693` | The acting user comes from the client or is hard-coded: `reviewer_name`/`approved_by="Kamal"`, a "Kamal" audit fallback, `certified_by` from the payload, "Smart Match Engine". | code | The router passes `current_user.username` as `user`. Services use it for `reviewed_by`, `approved_by`, `*_approved_by`, `commercial_reviewed_by`, and audit `performed_by`. Client identity fields are still accepted but ignored (contract C3). |
| DOC-13 | MAJOR | `service.py:4242-4404` | Certify-and-sync:<br>- It writes unvalidated OCR or client values into `ImportFile.total_amount`, `currency`, `incoterm`, and `bl_number`.<br>- It approves the customs commercial documents without a user.<br>- It ignores `is_safe_for_certification`.<br>- `create_invoice_bl_match_session_service` allows several certified sessions per file, and commits the session before the sync (two transactions). | code | Validate `currency` against `Currency.currency_code` and `incoterm` against the Incoterm codes (400, Arabic). Guard numbers. Record `user`. Use a single commit for session plus sync. Reject a second certified session for a file (409). Gating on discrepancies: Q6. |
| DOC-14 | MAJOR | `schemas.py:106, 191, 235, 504/545, 594/620, 677/700, 903/927` | Every `status`/`overall_status` is free text. The workflows trigger on literal label lists (`service.py:243, 695, 2637, 4700`), so a typo silently skips or fires a stage advance. | code | `validators.validate_status(kind, value)` with frozensets of today's exact values (ACID, banking, shipment doc, draft B/L, COO, inspection, reconciliation). Return 400 with an Arabic detail. No recoding in this wave: the stored values stay identical. T3 recoding is deferred. |
| DOC-15 | MAJOR | `repository.py:66-68, 114`, `service.py:387-413` | ACID create:<br>- With no `expiry_date`, it stores `expiry = today` or `generated_date`, so the tracker and legal compliance show it EXPIRED right away.<br>- `status="Verified"` when `acid_number` is None (stored as "PENDING") but `generated_date` is set.<br>- Update skips `validate_acid_expiry`. | code | Leave the expiry null when not given. The tracker already defaults it to issue + 90. Status is "Requested" whenever the number is PENDING or empty. Apply `validate_acid_expiry` on update when the dates change. |
| DOC-16 | MAJOR | `router.py:294-322, 409-442, 686-701, 751-818`, `service.py:1354-1460` | Upload safety:<br>- Unbounded `await file.read()`.<br>- No extension whitelist.<br>- A `None` filename crashes `.lower()` (500).<br>- CPU-heavy PDF/OCR runs inside `async def`, which blocks the event loop.<br>- Exception text is returned inside `raw_text`.<br>Nothing is written to disk, so there is no path-traversal risk. | code | `validators.validate_upload(filename, content)`: allowed extensions are pdf, docx, doc, xlsx, xls, txt, png, jpg, jpeg, tiff, bmp, webp. Max 20 MB, the same as `smart_document_upload/validators.py:9`. Return 413/400 with an Arabic detail. Routes become plain `def` (threadpool) and read `file.file.read()`. Return a fixed English note instead of the exception text. |
| DOC-17 | MAJOR | `router.py:87-93, 100-106, 122-127, 149-151, 156-162, 207-209, 306-322, 419-442, 484-487, 768-818, 869-875` | Business logic in the router: response enrichment, None→404 mapping, the extract→parse→compare orchestration, and multi-file merging. | code | Move each block into a service function (names in §4). Each route becomes one service call. |
| DOC-18 | MAJOR | `service.py:4454-4459, 997, 1084, 2222, 2458, 4014, 4245, 4380, 4665` | Soft-delete leaks and missing FK checks:<br>- The PO lookup has no `is_active` filter and takes `.first()`, so a multi-PO file compares one PO only.<br>- `ImportFile` loads ignore `is_active`.<br>- No create validates `import_file_id`/`po_id` (ACID, banking, shipment doc, Dec 46, draft B/L, COO, inspection, invoice-B/L). | code | Add an `is_active` filter to the PO and import-file reads. Writes call `require_active(db, ImportFile, id, "ملف الاستيراد")` and `require_active(db, PurchaseOrder, id, "أمر الشراء")`. Multi-PO comparison stays as is (Q7). |
| DOC-19 | MAJOR | `service.py:471-489, 500-501, 4054-4138, 4366`, `1870`, `1136, 4545` | Single-language rule:<br>- The tracker sends `status_label_ar` plus Arabic fallback names.<br>- Legal compliance sends `doc_type`, `alert_message`, and the banner in Arabic only.<br>- The sync `message` is Arabic.<br>- The revision report stores `field_label_ar` in the DB (`revision_report_data`).<br>- The B/L goods description prefers `description_ar` in an English document comparison. | code | Additive `message_code` + `message_params` on tracker items, legal alerts, and the banner (`system_messages.to_item`). Keep the Arabic fields for old clients and deprecate them. The revision report uses `field_label_en`. Use `description_en` first. Fallback names become `None`. |
| DOC-20 | MAJOR | `ai_document_parser.py:388-397, 2495-2600` | When `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` is set, up to 8,000 characters of each document (ACID, tax IDs, prices) go to an external LLM. There is no opt-in setting and no audit. | code | No change in this wave (the parser is shared with `smart_document_upload`). The decision is Q8. |
| DOC-21 | MINOR | `service.py:454, 465-489, 4037, 4041, 4114` | Hard-coded day thresholds: ACID default validity 90, expiring at ≤14, ETA default +21, ETA safety margin 30, company docs at 60. | code | Move them to module constants now; `system_parameters` later (Q9). |
| DOC-22 | MINOR | `repository.py:41, 201, 304, 407, 516, 624, 721, 834` | 8 yearly code generators that take the last row by id. They collide with any non-digit suffix. | code | `next_yearly_code` with the same prefix and pad: ACID/FORM4/DOC pad 3; BL-REV/COO/INSP/REC/MATCH pad 4. |
| DOC-23 | MINOR | `service.py:1653-1668` ≡ `2026-2040`; `203-333` ≈ `659-801`; `159-200` | The correction letter is built twice. The ACID and banking workflow skeletons are near copies. Three enrich helpers repeat the import-file lookup. | code | One `_build_bl_correction_letter(sys_data, report, intro)`. Enrich uses `import_files.repository.codes_by_ids` / `get_import_files_map`. Leave the workflow skeletons alone (behaviour risk). |
| DOC-24 | MINOR | `service.py:4621`, `99`, `416-593` | N+1 queries: the import file is loaded per session in lists, and the tracker loads every active file. | code | Use the bulk map in list enrich. The tracker stays as is (single-laptop scale). |
| DOC-25 | MINOR | `service.py:1572`, `repository.py:273` | A numeric compare with system value 0 always MATCHes. Banking update drops explicit nulls. | code | Pin the first in a test and leave it (Q10). Banking: `exclude_unset` only, for nullable fields. |
| DOC-26 | MINOR | `model.py` (all 9 tables) | No `created_by`/`updated_by` columns. | grep | Deferred (needs a migration, see §6). |

---

## 2. Behaviour that must stay identical

- Code formats: `ACID-YYYY-NNN`, `FORM4-YYYY-NNN`, `DOC-YYYY-NNN`, `BL-REV-YYYY-NNNN`, `COO-YYYY-NNNN`, `INSP-YYYY-NNNN`, `REC-YYYY-NNNN`, `MATCH-YYYY-NNNN`, `DEC46-YYYY-NNN`.
- ACID: 19-digit rule, PENDING/REQUESTED/DRAFT accepted, Arabic duplicate messages (validators l.69-111), `execution_days = max(0, generated-requested)`.
- Tracker:
  - release detection
  - 90-day defaults
  - status buckets (≤0 Expired, ≤14 Expiring Soon)
  - `validity_percentage` rounding to 1 decimal
  - counts
- Banking: `execution_days`, "Received" when the reference is not PENDING, the STEP_12→STEP_13 trigger list.
- Draft B/L compare:
  - the field list and its order (l.1501-1522)
  - fuzzy threshold 0.85
  - numeric tolerance 0.5 %
  - strict text compare
  - MISSING_IN_DRAFT is BLOCKING only when the field is critical and explicitly `""`
  - `blocking_reasons` and `blocking_reasons_coded` stay in step
  - the checklist and revision-report shape
- PO final adjustments: variance % rounded to 2 decimals. Response totals rounded to 2 decimals (weights, amount) and 3 decimals (CBM).
- All lifecycle step codes and the order of the side effects in every workflow. msg codes are unchanged.
- The parser modules (`ai_document_parser.py`, `nafeza_acid_parser.py`, `arabic_ocr_engine.py`) are untouched.

## 3. Characterization tests (package T, green on current code first)

New `tests/unit/test_phase03a_characterization.py`:
1. ACID create with a 19-digit number plus `generated_date`: status Verified, the import file gets the ACID and dates, and STEP_05→STEP_06 runs.
2. ACID duplicate per file on update: 400 with the Arabic text.
3. Tracker buckets at days remaining = 15, 14, 0, and released.
4. Banking create with a reference: status Received, `execution_days`, and the import file `form4_*` sync.
5. Draft B/L compare golden matrix: an empty critical field is BLOCKING, a missing non-critical field is WARNING, 0.5 % vs 0.6 % weight, fuzzy 0.85.
6. Checklist update: an Incorrect item without a reason gives 400; otherwise the status and correction letter are set.
7. Dual approval: importer then broker gives FINAL and the workflow ran.
8. COO certified save with discrepancies, Verified status, and no override: 400.
9. PO reconciliation session duplicate (active): 400.
10. `reconcile_po_final_adjustments` variance rounding and response totals (no packing rows in the fixture).
11. Code generation for each prefix (golden next code).

Mark these as `xfail(strict=True)` now and flip them with each fix: DOC-04a (create auto-APPROVED), DOC-06 (critical COO approved), DOC-09 (create after delete gives 500), DOC-10 (second DEC46 gives 500), DOC-05c (code after a `-v2` gives 500).

Regression tests written with each fix:
- 403 for a viewer on POST/PUT/DELETE (`ALLOW_DEV_AUTH_BYPASS=False` seam). Approve permission is required.
- DOC-02: a foreign `po_item_id` gives 400. A packing row is untouched unless `packing_item_id` is sent. The PO version is bumped.
- DOC-03: no import-file data gives a snapshot with `None`, and the template's `missing_fields` lists `acid_number` and `hs_code`.
- DOC-07/08: PUT on a missing or deleted id gives 404, and the row stays inactive.
- DOC-15: no expiry stays null, and the tracker shows Valid (90-day default).
- DOC-16: a 21 MB file gives 413, `.exe` gives 400, a `None` filename gives 400.

## 4. Work split (disjoint files, each file has one owner)

| Package | Owner | Files (exclusive) | Content |
|---|---|---|---|
| **T** | backend-developer #1 | new `tests/unit/test_phase03a_characterization.py` | §3. Runs first and must be green or xfail on the current code. |
| **D1: edge** | backend-developer #1 (after T) | `router.py`, `validators.py`, `repository.py`, `schemas.py`, new `tests/unit/test_import_documentation_permissions.py` | DOC-01, 07 (repository side), 08, 10, 12 (router side), 14, 16, 17 (router side), 22, the schema parts of 02/04/13. |
| **D2: engine** | backend-developer #2 (after T) | `service.py`, `tests/unit/test_import_documentation.py`, `tests/unit/test_draft_reviews_and_compliance.py`, `tests/unit/test_invoice_bl_match_session.py` | DOC-02, 03, 04, 05, 06, 09, 11, 13, 15, 17 (new service functions), 18, 19, 21, 23, 24, 25. |

### D1 ↔ D2 interface (agreed signatures, so both can run in parallel)

- Every mutating service function gets a trailing keyword `user: Optional[str] = None`. D1 passes `current_user.username`.
- These names move out of the router into D2:
  - `list_acid_sessions_service(db, **filters) -> List[AcidRegistrationResponse]`
  - `get_acid_session_service(db, acid_id)`, which raises 404
  - `soft_delete_acid_session_service(db, acid_id, user=None)`, which raises 404
  - `list_banking_documents_service`, `get_banking_document_service`, `list_shipment_documents_service`
  - `get_draft_bl_review_service(db, id)`, which raises 404
  - `get_invoice_bl_match_session_service`, which raises 404
  - `extract_po_files_and_compare_service(db, invoice: Optional[tuple[str, bytes]], packing: Optional[tuple[str, bytes]], import_file_id, invoice_text, packing_text)`
  - `extract_draft_bl_file_service(db, filename, content, import_file_id) -> dict`
  - `extract_certificate_file_service(document_type, filename, content, import_file_id)`
  - `extract_invoice_bl_files_and_match_service(db, invoices: list[tuple[str, bytes]], bls: list[...], packings: list[...], import_file_id, invoice_text, bl_text, packing_list_text)`
- The router calls `validators.validate_upload(filename, content)` before calling the service.
- D1 owns the repository. D2 needs new repository functions: `get_*_active(db, id)`, `get_inactive_po_reconciliation_by_file`, and `next code` wrappers. D1 adds them first, in its first commit.
- Repository functions stop raising `ValueError` and return `None`. D2 raises `not_found`.
- Both fill the DOC-07 gap: D1 makes the repository return `None`, D2 raises.
- `validators.py` functions that D2 calls are written by D1 in its first commit: `validate_status(kind, value)`, `validate_po_lines_belong(db, import_file_id, po_item_ids, packing_item_ids)`, `validate_currency_code(db, code)`, `validate_incoterm_code(db, code)`, `validate_upload`.

Order: T → D1 commit 1 (validators + repository helpers + schemas) → D2 and the rest of D1 in parallel → reviews:
- `diff-reviewer` (all)
- `customs-rules-reviewer` (DOC-02, 03, 06, 13)
- `security-reviewer` (DOC-01, 12, 16, 20)

## 5. Contract changes for the Flutter agent (explicit)

- **C1**: 403 on every endpoint for roles without `import_documentation.view` / `.upload` / `.approve`.
- **C2**: Draft B/L `status`, `stage`, `importer_*`/`broker_*` approval fields, and `approved_by` sent on POST/PUT are ignored. Create returns at most REVIEWED_PENDING_APPROVAL (no auto APPROVED, Q4). PUT on FINAL/APPROVED returns 409. Dual approval: `role` must be `importer|customs_broker` and `action` must be `Approved|Rejected` (422 otherwise). The same user approving both roles gets 409.
- **C3**: `approved_by`, `reviewer_name`, `reviewed_by`, `certified_by` in requests and query params are ignored; the server uses the logged-in user.
- **C4**: `POReconciliationItem.packing_item_id: Optional[int]` (additive). Packing rows are updated only when it is sent. Negative quantities and weights give 422.
- **C5**: Template responses get `missing_fields: List[str]` (additive). Snapshot fields can be `null` instead of placeholders.
- **C6**: Tracker items, legal alerts, and the banner get `message_code` + `message_params` (additive). `status_label_ar` and the Arabic `alert_message` are deprecated.
- **C7**: Uploads larger than 20 MB give 413. An unsupported extension or a missing filename gives 400.
- **C8**: Free-text `status` values outside today's set give 400.
- **C9**: Second certified invoice-B/L session for a file gives 409. A bad currency or incoterm code gives 400.
- **C10**: ACID created without an expiry returns `expiry_date: null`, where today it returns today's date.

## 6. Shared needs (registered centrally by the lead; developers do not edit common files, `seed_rbac.py`, or `docs/*.json`)

- Permission `import_documentation.approve` ("Approve Shipping Documents"). Grant it to ADMIN, GENERAL_MANAGER, and every role holding `import_documentation.upload`. Apply the same one-time grant to existing DBs, as in Phase 1.
- Message codes (`system_messages.py` + `docs/system_message_codes.json`):
  - `DOC_ACID_TRACKER_STATUS` (params status, days)
  - `DOC_LEGAL_DOC_EXPIRED`, `DOC_LEGAL_DOC_CRITICAL_BREACH`, `DOC_LEGAL_DOC_EXPIRING_SOON`, `DOC_LEGAL_DOC_VALID`, `DOC_LEGAL_ACID_MISSING` (params doc_kind, doc_number, expiry_date, eta_date, days)
  - `DOC_LEGAL_BANNER`
  - `DOC_INVOICE_BL_SYNCED`
- Enum code set `LEGAL_DOC_KIND`: ACID, IMPORT_CARD, COMMERCIAL_REGISTRY, TAX_CARD.
- No new enum types for statuses in this wave (DOC-14 whitelists stay local in `validators.py`).
- Deferred to a schema wave:
  - `created_by`/`updated_by` on the 9 tables (DOC-26)
  - dropping `unique` on `po_packing_reconciliation_sessions.import_file_id` in favour of a partial unique index on active rows (DOC-09)
  - T3 recoding of the ACID, banking, COO, and inspection status labels
  - stripping `field_label_ar` from the stored `comparison_matrix`/`checklist_data` JSON

## 7. Open questions for the CTO (safe default in brackets)

- **Q1**: Should ACID routes use `cargox_nafeza.view/manage` instead of `import_documentation.*`? [No. Keep `import_documentation.*` so the logistics role is not locked out.]
- **Q2**: After final PO adjustments, should PO header totals (FOB, CBM, weights) be recomputed through `cargo_math.compute_po_totals`? [No recompute this wave. Bump the version only, so the PO screen shows the edit and can save again.]
- **Q3**: Should non-data defaults such as "Carton" and "Freight Prepaid" stay? [Yes, keep them. Only identity, customs, and number placeholders are removed.]
- **Q4**: Should a certified (non-draft) draft-B/L save still count as approval? [No. Approval only through dual approval or `/approve`.]
- **Q5**: Recreating a PO-reconciliation session after delete: reactivate the old row with the new data, or return 409 and point to a restore? [Reactivate and overwrite, audited.]
- **Q6**: Should invoice-B/L certify be blocked when critical discrepancies exist? [Allow it, but require `notes` as the justification (400 if empty) when the client flags critical > 0.]
- **Q7**: Multi-PO files in PO reconciliation: compare all active POs? [Keep the first active PO this wave and log a warning.]
- **Q8**: External LLM extraction: allowed? [Off unless `DOC_AI_EXTRACTION_ENABLED=true` in `.env`. This is a parser change for a later wave; until then document that setting a key enables egress.]
- **Q9**: Move the tracker and compliance day thresholds to `system_parameters`? [Constants now, parameters later.]
- **Q10**: Numeric compare when the system value is 0: MATCH (today) or WARNING "unverifiable"? [Keep MATCH.]

## 8. Risks

- **DOC-04 / C2** changes the user flow (no auto-approval on save). The Flutter agent must ship the matching UI in the same release.
- **DOC-02 on the live DB**: past calls may already have overwritten wrong packing rows. Before deploying, run a read-only check: list `packing_list_items` whose `packing_item_id` equals any `po_line_items.item_id` of a different PO, and whose `updated_at` matches PO-reconciliation dates. Report the list; do not repair.
- **DOC-03** turns silent false matches into "missing" warnings, so users will see more warnings on files with incomplete master data. This is intended.
- **DOC-15** changes stored expiry for new rows only. Existing rows with `expiry = request date` stay EXPIRED. Report the count (read-only) and do not backfill.
- `get_central_archive_service` is imported by `modules/original_documents_collection/service.py`, and `extract_text_and_boxes_from_uploaded_file` by `modules/smart_document_upload/service.py`. Their signatures must not change.
- `service.py` (5.3k lines) has one owner (D2). D1 must not touch it, even for imports.
