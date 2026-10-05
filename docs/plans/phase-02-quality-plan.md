# Phase 2 "Financial Approval": quality audit and fix plan

Status: proposed (2026-10-05). Nothing has been implemented yet. The audit is a static reading only: no pytest run, no flutter test, no import of `main`.
Same method and severity scale as `docs/plans/phase-01-quality-simplify-plan.md`. It reuses the A1 helpers listed in `docs/plans/phase-01-progress.md`.
Constraint for this wave: **no DB schema changes and no Alembic migrations** (the items that need them are deferred in section 6).

## Audit coverage

| Area | Lines | Depth |
|---|---|---|
| `modules/financial_approval/service.py` | 2174 | Full, line by line |
| `router.py`, `validators.py` | 514 + 84 | Full |
| `repository.py` | 546 | l.1-340 read. Batch functions (l.360-546) read in part |
| `schemas.py`, `model.py` | 390 + 293 | Targeted: requests, responses, statuses, money columns, audit columns |
| `swift_mt103_parser.py`, `swift_file_extractor.py` | 741 + 220 | Grep only (`except`, scoring). **Parsing regexes not audited** |
| Flutter `providers/financial_approval_provider.dart` | 574 | Full |
| Flutter `models/financial_approval_model.dart` | 735 | Every `json[...]` key checked against the backend schemas |
| Flutter screens, widgets, export service (8 files) | 12,445 | Grep sweeps, plus reads of the save, approve, and pay flows. **Not read line by line** |
| Tests | n/a | Names counted: `test_financial_approval.py` (20), `test_fn01_*` (4), `test_fn02_*` (6), `test_swift_review_layer.py` (1), parser (5), extractor (6). Two tests read where they pin bugs |

Backend code covered: about 3,300 of 4,962 lines read. Flutter: 13,754 lines grep-swept, of which about 1,300 were read.

Severity: **BLOCKER** = breaks a non-negotiable rule, or can corrupt money or references. **CRITICAL** = a wrong result or a 500 on a normal path. **MAJOR** = a rule violation or real risk. **MINOR** = hygiene.

---

## 1. Findings

### 1a. Backend

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FA-01 | BLOCKER | `router.py:44-514` | Every route has only the router-level `get_current_user`. The only exception is `PUT /settings/variance-threshold` (`require_admin`). Any authenticated user can create, approve, pay, reconcile, delete, or restore payment requests and budgets, `AUDITOR_VIEWER` included. | Add a per-route `require_permission`. GET routes (lists, by id, prefill, variance logs, batch review, threshold GET) get `financial_approval.view`. Create, update, clone, delete, restore, SWIFT extract, field edit, and confirm get **new** `financial_approval.manage`. Approving a payment, `/pay`, `/reconcile-swift`, `/swift/smart-reconcile`, `/review-batch/{id}/reconcile`, and approving a budget get `financial_approval.approve`. Sync and override-variance get `budget.sync_variance`. Keep `require_admin` on the threshold PUT. |
| FA-02 | BLOCKER | `service.py:340`, `389`, `449`, `213`, `1907-1961`, `2126-2171`; `repository.py:71`; `schemas.py:28,59-70` | The payment approval workflow can be bypassed:<br>(a) `approve` sets Approved from any status (Paid, Rejected).<br>(b) `/pay` and all three reconcile paths set Paid from any status, including Draft and Rejected.<br>(c) Create stores the `status` from the payload, so a request can be created already Approved or Paid.<br>(d) PUT can move Approved to Paid and can write `swift_variance_*`, `swift_transferred_*`, and `swift_processing_days` directly.<br>(e) PUT can change the amount of a Paid request. | Use one guard, `validators.require_payment_status(item, allowed, action)`. Approve is allowed from Draft and Pending Approval. Pay and reconcile are allowed from Approved only. Create ignores `status` and always stores Draft. PUT may only make the transitions Draft↔Pending Approval, any status→Rejected, and Rejected→Draft. Approved and Paid are reached only through their endpoints. PUT ignores the `swift_*` fields. PUT on Approved or Paid is rejected with 409 and the Arabic detail "لا يمكن تعديل طلب صرف معتمد أو مدفوع.". Q2 confirms. |
| FA-03 | BLOCKER | `schemas.py:152-153`, `repository.py:313-326`, `router.py:363-370` | The budget approval workflow can be bypassed. PUT `budget_status="Budget Approved"` skips the hard-block check, the approve permission, and segregation of duties. PUT also edits the numbers of Approved and Superseded budgets, which breaks the immutability that `service.py:1108` documents. `approved_by` is a client query parameter (default "Finance Manager"), so the approver can be spoofed. | PUT ignores `budget_status` and `approved_by`, and rejects any edit of a Budget Approved or Superseded budget with 409. Approval goes through `/approve` only, with `approved_by = current_user.username`. The query parameter is accepted and ignored. |
| FA-04 | BLOCKER | `service.py:507,935,945`; `schemas.py:25,123,224`; `model.py:51,126` (default only) | The EGP exchange rate is hard-coded to 50.0. When a currency has no rate, the prefill, the variance engine, the sync, the clone, and the schema defaults all silently use 50, and the EGP budget and the hard block are computed on that fake rate. This is the same class as the settlement fix in commit 274f360. | Add one helper, `_commercial_rate_to_egp(db, code) -> Optional[float]`. When the rate is missing, raise `CodedHTTPException(400, "FA_FX_RATE_MISSING", "لا يوجد سعر صرف مسجل للعملة {currency_code}. يرجى إضافته من شاشة العملات.", currency_code=...)` from the prefill, the sync, and the clone. Remove `default=50.0` from the request schemas: `exchange_rate` becomes required, `gt=0` (contract change C1). The response default stays. In the variance evaluation the 400 is caught by the caller's `best_effort`, so the budget is left unchanged, which is safe. |
| FA-05 | CRITICAL | `service.py:432,1918,2140`; `swift_mt103_parser.py` (matching) | SWIFT variance is computed as `transferred - requested` even when `swift_transferred_currency != currency_code`. For example, EUR 10,000 against USD 10,000 shows as Matched. | When the currencies differ, reject with 400 code `FA_SWIFT_CURRENCY_MISMATCH` ("عملة السويفت {swift_currency} لا تطابق عملة طلب الصرف {currency_code}."). Q3. |
| FA-06 | CRITICAL | `service.py:1872`, `1750-1777`; `repository.py:448-503` | One SWIFT can be used twice:<br>(a) Reconcile accepts a RECONCILED batch, so the same MT103 settles a second payment.<br>(b) Confirm has no status guard (RECONCILED goes back to REVIEWED_CONFIRMED).<br>(c) Editing a field after confirm keeps the batch confirmed.<br>(d) The same `swift_reference_no` can be stored on several active requests. | Reconcile requires REVIEWED_CONFIRMED. RECONCILED is accepted only if `matched_payment_id` is the same payment (idempotent); otherwise return 409. Confirm requires EXTRACTED_PENDING_REVIEW. A field edit on a confirmed batch resets it to EXTRACTED_PENDING_REVIEW. Reject a `swift_reference_no` already used by another active request with 409 `FA_SWIFT_REF_ALREADY_USED`. |
| FA-07 | CRITICAL | `repository.py:81,161,172,186,246,330,341,355,434,500,521,543`; `service.py:1414+1428`, `650+656` | Writes are not atomic. The repository commits inside every write, then the service commits again. Create commits the payment request before its notification, task, and lifecycle side effects. Sync commits the revision before it resolves the logs. Reconcile-batch commits the batch status and the payment separately. | Repository methods `flush` only. Each service function commits once for the core state (row, status, logs, notification), then runs the follow-ups (lifecycle advance, smart tasks, `sync_budget_lifecycle_stage`) **after** the commit through `errors.best_effort`. This is the `customs_consultation._sync_file_side_effects` pattern. `best_effort` rolls back, so it must never run before the core commit. |
| FA-08 | MAJOR | `service.py:144,168,247,265,289,325,370,566,625,647,657,1027,1435,1489,1893,1898` | 16 `except Exception: pass` blocks. A failed lifecycle advance or task leaves the file stuck at STEP_04 with no log. | Use `best_effort` post-commit (FA-07). Date and amount parsing in `reconcile_reviewed_batch` use specific `ValueError`. |
| FA-09 | MAJOR | `service.py:236-246`, `630-646` | Smart-task auto-close is too broad. `t.reminder_type in ["Advance Payment","Payment Request"]` closes **every** pending payment task of the file when one request is paid. The Arabic title matches ("سداد الدفعة", "الميزانية") are dead, because titles are now English. | Match only `PayId: {id}` or `payment_code` in the notes, and `budget_code` / `BUDGET` for budgets. |
| FA-10 | MAJOR | `schemas.py:18-21`; `service.py:74,93,852`; Flutter screen `:328,2928-2932`, dialog `:297` | `payment_type` is free text. The screen sends "Advance Payment", or the prefill's `payment_terms_summary`, which can be the Arabic text `"متعدد (...)"` and then gets stored in the DB. The advance dialog sends `ADVANCE_PAYMENT`. As a result, `is_advance` and the duplicate guard compare raw strings and disagree. | Add a T3 code set `PAYMENT_TYPE`: ADVANCE_PAYMENT, AGAINST_BL, LETTER_OF_CREDIT, DOCUMENTARY_COLLECTION, FINAL_SETTLEMENT. Legacy English labels map to these codes. Call `normalize()` on write and on every comparison. An unknown value gets 422. The prefill returns `payment_terms_summary` in English ("Multiple (...)"). Contract C2. |
| FA-11 | MAJOR | `model.py:58,130,221`; `service.py` throughout | Payment status, budget status, `swift_variance_status`, and batch status are free strings with no closed set (the list filter accepts any value). They are English labels, not T3 codes. | This wave: `Literal` validation of the known English labels on every write and filter, plus one transitions table per entity in `validators.py`. Conversion to codes is deferred (D3, Q4). |
| FA-12 | MAJOR | `schemas.py:49-74`, `repository.py:151-157` | `PaymentRequestUpdate` has no `gt=0` on `requested_amount` or `exchange_rate`. An explicit `null` makes `None * rate` raise a TypeError, which returns a 500. `import_file_id` and `supplier` changes are not FK-validated. | Use `Field(None, gt=0)`. Drop `None` for NOT NULL fields before `setattr`, using `validators.not_null_columns`. Check active FKs with `require_active`. |
| FA-13 | MAJOR | `repository.py:25-47,191-213,360-383` | The PAY, BGT, and SWB code generators take the last row by id, so codes can collide, and an IntegrityError returns a 500. | Use `sequence_generator.next_yearly_code(db, col, "PAY"/"BGT"/...)` with a retry on IntegrityError. It already skips `-REV2` suffixes (digits-only GLOB). |
| FA-14 | MAJOR | `router.py:395-430`; `service.py:1313-1324`, `1527-1538` | Sync and override resolve the user from headers inside the router and check permissions in the service. `if current_user:` skips the check entirely. The role shortcut uses `"MANAGER"`, which is not a seeded role (the seeded role is GENERAL_MANAGER). | Use the router dependency `require_permission("budget.sync_variance")` and pass a non-optional `User`. Keep only the ADMIN segregation-of-duties exemption. |
| FA-15 | MAJOR | `schemas.py:271,275,301`; `repository.py:453,508`; Flutter provider `:275,307,485` | Audit identities come from the client: `user_name="admin"`, `approved_by="Finance Manager"`. The OCR correction log and `reviewed_by` can be spoofed. | Router passes `current_user.username`. The payload fields are kept for compatibility and ignored. |
| FA-16 | MAJOR | `router.py:59-91`, `444-457` | Upload has no size limit (`await file.read()`). An invalid base64 payload raises `binascii.Error`, which returns a 500. Base64 decoding and a DB query happen in the router (business logic in the router). | Move the decoding to the service. Invalid base64 gets 400. Add a size cap (Q6). The threshold GET calls one service function only. |
| FA-17 | MAJOR | `service.py:426-449`, `1918-1929`, `2140-2152`; `1826-1842`, `1996-2012`, `2078-2094`; `1133-1171` vs `1342-1357`; `1181-1197` vs `1451-1462` | Duplication:<br>- Variance and processing days are computed 3 times.<br>- The candidate-ranking loop appears 3 times.<br>- The cost diff appears twice, with different labels.<br>- "Apply prefill to budget" appears twice. | Use private helpers `_apply_swift_receipt`, `_rank_candidates`, `_cost_diffs`, and `_apply_prefill`. Same numbers, same order. |
| FA-18 | MAJOR | `service.py:1826,1996,2078` | Matching loads every active payment request, including Paid and Rejected ones, so it is slow on large lists and returns wrong candidates. | Filter in the repository on `status == "Approved"` and `swift_reference_no IS NULL`. Always include `target_payment_id` when it is given. |
| FA-19 | MAJOR | `service.py:571-595` | Budget approve has no status guard. A Superseded budget can be approved, and re-approving resets `approved_date`. | Approve is allowed from Draft, Pending Review, and Needs Revalidation, under the current hard-block rule. Budget Approved and Superseded get 409. |
| FA-20 | MAJOR | `repository.py:166-187,335-357` | Soft delete accepts Paid and Approved payment requests and Approved budgets, so the money trail disappears. Restore skips the duplicate-per-type and per-file guard. | Delete of a Paid or Approved request, or an Approved budget, gets 409. Restore re-runs the create duplicate guard. |
| FA-21 | MAJOR | `service.py:871-894`, `914-918` | The prefill picks the "highest freight" across mixed currencies without converting them (EUR 900 > USD 1000 by raw number). The supplier fallback matches `company_name` text. | Compare in EGP (rate from FA-04) and keep the original amount and currency of the winner. The supplier fallback is MINOR: keep it and add a comment. |
| FA-22 | MAJOR | `service.py:79`, `557`, `590`, `694`, `1323`, `1335`, `1363`, `1445`, `1499`, `1785` | Error `detail` texts and the success `message` texts are built as Arabic strings in the backend. The single-language rule wants codes and params. | Use `CodedHTTPException`, which keeps the Arabic message plus a code, for the duplicate, hard-block, segregation-of-duties, and permission errors. Add `message_code` and `message_params` next to `message` (additive, C3). |
| FA-23 | MINOR | `service.py:181,335,384,...`; `validators.py:25,37,48,73,80` | "not found" and validation details are in English. | Use `validators.not_found` / `get_or_404` with Arabic labels. |
| FA-24 | MINOR | `service.py:564`, `1122-1130` | `create_import_budget` checks `budget_status == "Budget Approved"`, which is always false (dead code). | Pass `is_approved=False`. |
| FA-25 | MAJOR | `schemas.py:89,163`; `matching` | `import_file_code` is declared in both responses but never filled (no column, no property). Flutter falls back to `IMP-{id}`, which shows a DB id, and searching by file code never matches. | Fill it in the list and get services through `import_files.repository.codes_by_ids` (one query). |

### 1b. Flutter (`frontend/lib/features/financial_approval/**`)

| id | sev | where | problem | fix |
|---|---|---|---|---|
| FE-01 | CRITICAL | `financial_approval_screen.dart:2059-2080`, `2400-2408` | The Approve payment, Mark Paid, and Approve budget buttons have no try/catch and no loading state. A 400 (hard block) or the new 403/409 errors are unhandled, so no SnackBar appears. | Wrap the calls in try/catch with a SnackBar showing `ApiError.message(e)`, and put a loading indicator inside the button. |
| FE-02 | BLOCKER | screen `:51,92,127,318,462,502,1796,4216`; export `:24,261,677,717`; model `:111,145,201,242` | 50.0 is hard-coded as the exchange rate in the UI. `_getExchangeRateForCurrency` returns 50 when no rate exists. | Return `null`, leave the rate field empty and required (validator), and show the l10n hint `fxRateMissing`. Model defaults become 0.0. Exports print "-" when the rate is 0. |
| FE-03 | MAJOR | 8 files | 642 `Colors.*` uses (248 of them white/black), 50 `Color(0x..)`, 168 Material buttons, 0 `AppButton`. | Mechanical sweep to AppTheme and AppButton, one commit per file. PDF `PdfColors` (39) stay. |
| FE-04 | MAJOR | `supplier_advance_payment_dialog.dart` (37 lines), `swift_extraction_review_widget.dart` (38), screens (39), `financial_export_service.dart` (188) | Inline `isAr ? '...' : '...'` text and Arabic literals bypass l10n. | Move the strings to the 3 localization files. Exports use l10n labels for the user's language. |
| FE-05 | MAJOR | provider `:526-528`, `:570-572`; screen `:666,1509`; dialog `:245`; 23 `e.toString()` SnackBars; 0 `ApiError.message` | Errors are swallowed (prefill returns null, variance logs return []). Coded `detail` maps reach the user as raw `{code: ...}` text. | Rethrow from the provider. Screens show `ApiError.message(e)`. Keep the date-parse `catch` only with a comment. |
| FE-06 | MAJOR | provider (all mutations) | Mutations re-fetch only their own list, and without the active filters. Payment create, budget create/update/sync/override, and clone do not invalidate `importFilesProvider`, although the backend advances the lifecycle. | Store the last filter arguments and re-fetch with them. Call `ref.invalidate(importFilesProvider)` after create, approve, pay, reconcile, sync, and override. |
| FE-07 | MAJOR | screen `:2928-2932`, `:328` | `payment_type` is a free `TextFormField`, prefilled from `paymentTermsSummary` (FA-10). | Use `SearchableDropdownField<String>` over the PAYMENT_TYPE codes with `domainEnumLabel` labels. Legacy values are mapped through `legacyToCode`. |
| FE-08 | MAJOR | provider `:275,307,485` | Sends `user_name: 'admin'` and `approved_by: 'Finance Manager'`. | Stop sending them (FA-15). |
| FE-09 | MINOR | export `:245,485,1059` | `Printing.layoutPdf` opens the print dialog. CSV goes through `FileSaveHelper.saveText`. | Verify that `saveText` routes to `exportAndSaveFile` and that the names follow `[Stage] - [File code].ext`. |
| FE-10 | MAJOR | screen 4,810 lines, SWIFT screen 2,533 lines | God files, against the Flutter rule. | Out of scope for this wave, except extracting the approve/pay dialog actions touched by FE-01. Backlog. |

Counts: BLOCKER 5 (FA-01..04, FE-02) · CRITICAL 4 (FA-05..07, FE-01) · MAJOR 23 (16 BE, 7 FE) · MINOR 3.

---

## 2. Behaviour that must stay identical

- `requested_amount_egp = requested_amount * exchange_rate`, unrounded (repo:53,157). `total_budget_egp` is the plain sum of the 4 EGP fields, in that order.
- SWIFT variance = `round(transferred - requested, 2)`. Matched when `abs < 0.01`, Deficit when < 0, Surplus when > 0. `processing_days = max(0, receipt - request_date)`.
- Variance engine:
  - A field counts only when `abs(diff) > 1.0` EGP.
  - `pct = 100` when the old value is 0, else `round(abs(diff)/old*100, 2)`.
  - Hard block when `pct > threshold`. The threshold defaults to 5.0 when it is missing or invalid.
- Status machine on upstream change:
  - Draft: auto-update.
  - Pending Review / Needs Revalidation: set Needs Revalidation and clear the approval.
  - Budget Approved: numbers stay untouched, the flag is set, and a CRITICAL notification is sent.
- Sync:
  - Approved: a new `{base}-REV{n+1}` revision in Pending Review, and the original becomes Superseded.
  - Other statuses are updated in place: Draft stays Draft, everything else goes to Pending Review.
  - A hard block without a justification gets 400, except in Draft. The segregation-of-duties 403 exempts ADMIN.
- Prefill precedence:
  1. PO FOB total, falling back to qty×price.
  2. `invoices_data`.
  3. `estimated_cost`.
  - The customs figure is the max over the sessions. The broker is taken from the max-fee session.
- Clone resets: the payment clone gets Draft, `due = today + 12`, and the title " (Copy)". The budget clone gets Pending Review and is unlinked when the target file equals the source file.
- Notification `msg_code`s and params (FA_*), and the lifecycle targets (STEP_03→04 on create, STEP_04→05 on paid). Matching scores (40/25/25/15/10/10) and the match-status brackets.

## 3. Characterization tests to add first (BE, before any fix)

New file `tests/unit/test_phase02_characterization.py`, green on the current code:
1. Payment EGP value, and EGP after a PUT that changes the rate.
2. SWIFT variance golden values: 0 / -50 / +0.004 (Matched) / +25.
3. Variance engine: diff 1.0 is ignored, diff 1.01 is logged; old value 0 gives 100%; pct 5.0 is not a hard block, 5.01 is.
4. The status machine for Draft, Pending Review, and Budget Approved on an upstream change.
5. Sync of an Approved budget creates `BGT-YYYY-NNN-REV2`, and the original becomes Superseded. Sync of a Pending Review budget updates in place.
6. Prefill fallback chain, and the broker chosen from the max-fee session.
7. Clone resets (both entities).
8. Segregation of duties: the upstream modifier gets 403, ADMIN passes.

Regression tests with each fix (`tests/unit/test_financial_approval.py` plus a new `tests/unit/test_financial_approval_guards.py`):
- FA-01: a viewer gets 403 on POST approve, pay, reconcile, and create. Use the seam `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)`.
- FA-02 and FA-19: pay or reconcile on a Draft gets 400. Create with `status=Paid` stores Draft. PUT on Paid gets 409.
- FA-03: PUT `budget_status=Budget Approved` is ignored.
- FA-04: a missing rate gives 400 `FA_FX_RATE_MISSING`.
- FA-05: currency mismatch gives 400.
- FA-06: a second reconcile of the batch on another payment gets 409. A duplicate SWIFT ref gets 409.
- FA-12: `requested_amount: null` gets 422 or 400, not 500.
- FA-13: a code collision is retried.
- FA-20: deleting a Paid request gets 409.
- FA-25: the list returns `import_file_code`.

**Tests that change by design:**
- `test_financial_approval.py:412-433` reconciles a Draft request; the test must approve it first.
- `test_fn02_*.py:~435` creates the request with `status="Approved"`; the test must call `/approve`.
- Tests that rely on `exchange_rate` defaulting to 50 must pass the rate explicitly.

Flutter tests: `frontend/test/features/financial_approval/financial_approval_model_test.dart` (round-trip, a null rate gives 0.0, `import_file_code`, payment-type code). `.../financial_approval_provider_test.dart`: a mutation invalidates `importFilesProvider` and keeps the filters, and the prefill error is rethrown.

## 4. Work split (two packages, disjoint files)

| Package | Owner | Files (exclusive) | Order |
|---|---|---|---|
| **BE** | backend-developer | `modules/financial_approval/*` (all 8 files); `tests/unit/test_phase02_characterization.py` (new), `test_financial_approval_guards.py` (new), and edits to `test_financial_approval.py` and `test_fn02_budget_approval_swift_mt103.py` | 1. characterization tests (green on the current code); 2. FA-01, 14, 15, 16 (router); 3. FA-07, 08 (transactions); 4. FA-02, 03, 19, 20, 12 (guards); 5. FA-04, 05, 06; 6. FA-10, 11, 13, 25, 17, 18, 21, 22, 9, 23, 24 |
| **FE** | flutter-developer | `frontend/lib/features/financial_approval/**`, `frontend/test/features/financial_approval/**` | Starts immediately with FE-01, 03, 04, 05, 06, 08 (no contract impact). FE-02 and FE-07 come after BE step 5/6 lands. |

Shared files that neither developer edits (the lead registers them centrally, see section 5): `modules/common/*`, `modules/auth/seed_rbac.py`, `docs/*.json`, and `frontend/lib/core/localization/*`.
FE gives the lead the new l10n keys as a list, unless the lead lets FE own the 3 localization files for this wave. **The lead decides; FE is the only candidate.**

### Contract changes (explicit)
- **C1**: `exchange_rate` becomes required (`gt=0`) on `PaymentRequestCreate` and `ImportBudgetCreate`. There is no 50.0 default. A missing rate now returns 400 `{code: FA_FX_RATE_MISSING, message, currency_code}` from the prefill, the sync, and the clone.
- **C2**: `payment_type` takes and returns PAYMENT_TYPE codes. Legacy labels are accepted on input and normalized. `payment_terms_summary` is English.
- **C3**: Additive fields:
  - `message_code` and `message_params` on `BudgetSyncResultResponse` and `SwiftBatchConfirmResponse`.
  - `import_file_code` is now filled.
  - Error `detail` becomes a coded dict for the duplicate, hard-block, segregation-of-duties, FX, SWIFT, and status errors. It keeps the Arabic `message`.
- **C4**: These fields are now ignored:
  - `status` on create.
  - `status` (outside the allowed transitions) and the `swift_*` fields on payment PUT.
  - `budget_status` and `approved_by` on budget PUT.
  - The `approved_by` query parameter.
  - `user_name` in the SWIFT payloads.
- **C5**: New 403 responses come from RBAC (FA-01). New 400/409 responses come from the guards (FA-02, 03, 05, 06, 19, 20).

## 5. Shared needs (the lead registers them; developers use plain `{code, params}`)

- Permission `financial_approval.manage` in `PERMISSIONS_CATALOG`, granted to ADMIN, GENERAL_MANAGER, FINANCE_OFFICER, and to every role or override that holds `financial_approval.view` except AUDITOR_VIEWER. Granted once on startup, like the Phase-1 grants.
- Enum type `PAYMENT_TYPE`: ADVANCE_PAYMENT ("Advance Payment"), AGAINST_BL ("Against B/L"), LETTER_OF_CREDIT ("Letter of Credit (L/C)"), DOCUMENTARY_COLLECTION ("Documentary Collection (CAD)"), FINAL_SETTLEMENT ("Final Settlement"), plus the legacy aliases. Also add it to `docs/enum_codes.json` and to the Flutter `domain_enum_labels.dart` (ar + en).
- Message codes (`system_messages.py`, `docs/system_message_codes.json`, and both Flutter catalogs):
  - FX and SWIFT: `FA_FX_RATE_MISSING{currency_code}`, `FA_SWIFT_CURRENCY_MISMATCH{swift_currency,currency_code}`, `FA_SWIFT_REF_ALREADY_USED{swift_ref,payment_code}`, `FA_SWIFT_BATCH_ALREADY_RECONCILED{batch_code,payment_code}`.
  - Status guards: `FA_PAYMENT_STATUS_INVALID{payment_code,status,action}`, `FA_PAYMENT_LOCKED{payment_code,status}`, `FA_BUDGET_LOCKED{budget_code,status}`, `FA_BUDGET_STATUS_INVALID{budget_code,status}`.
  - Duplicates and budget rules: `FA_PAYMENT_DUPLICATE_TYPE{payment_type,payment_code}`, `FA_BUDGET_DUPLICATE_FILE{import_file_code}`, `FA_BUDGET_HARD_BLOCK{variance_percentage,field_name}`, `FA_BUDGET_SOD_DENIED`.
  - Sync results: `FA_BUDGET_SYNC_REVISION_CREATED{budget_code}`, `FA_BUDGET_SYNC_DONE{budget_code,status}`, `FA_SWIFT_BATCH_CONFIRMED{batch_code}`.

## 6. Deferred (needs a schema change; not this wave)

- **D1**: Add `created_by` and `updated_by` on `payment_request_sessions` and `import_budget_approvals` (Audit Trail rule).
- **D2**: Currency columns (`currency_code`, `invoice_currency`, `freight_currency`, `swift_transferred_currency`) are free `String(10)`. They should become an FK to currencies.
- **D3**: Convert payment, budget, variance, and batch statuses to T3 codes, with a data backfill.
- **D4**: Add a unique index on the active `swift_reference_no`. FA-06 enforces it at app level until then.
- **D5**: Money columns are `Float`. Consider Numeric(18,2) with an EGP rounding policy.

## 7. Risks

- FA-01 and C5: LOGISTICS_OPERATOR and CUSTOMS_OFFICER have no `financial_approval.*` grant today. If they create advance requests from other screens (`supplier_advance_payment_dialog`), they will get 403. Check the role matrix (Q1).
- FA-02 changes the user flow: a Draft can no longer be marked Paid. Data already in the DB is untouched, but announce the change.
- FA-07: `evaluate_and_record_budget_variance_service` is called by `customs_consultation` through `best_effort`. Keep its own commit (the caller is not in scope) and its signature unchanged.
- `modules/recalculation/service.py:154,286,796` also writes budgets and settings. It is not audited here and is not changed.
- FA-04: files whose currency has no commercial rate will start returning 400 on the prefill. Before deploying, run a read-only count of currencies that have no latest rate.

## 8. Open questions for the CTO (with safe default)

- **Q1**: Who may create payment requests? *Default:* the new `financial_approval.manage` code, held by ADMIN, GENERAL_MANAGER, and FINANCE_OFFICER.
- **Q2**: Can a payment be reconciled from Pending Approval (bank paid before the approval was recorded)? *Default:* no, Approved only.
- **Q3**: A SWIFT in a different currency: block it, or accept it with a converted variance? *Default:* block with 400.
- **Q4**: Statuses as T3 codes: now, with a data backfill, or deferred? *Default:* deferred (D3). This wave validates the English labels.
- **Q5**: A missing FX rate: block, or warn and let the user type the rate? *Default:* block on the prefill, sync, and clone. The user can always type a rate on the form, since it is required.
- **Q6**: Upload size cap for SWIFT files. *Default:* 10 MB, 413 above it.
- **Q7**: Should deleting a Paid request be allowed for ADMIN? *Default:* no, 409 for everyone.

## Not audited

- The `swift_mt103_parser.py` regexes and `swift_file_extractor.py` OCR paths (grep only).
- `repository.py` l.340-546, read in part.
- Flutter screens, widgets, and the export service line by line: only grep sweeps plus the save, approve, and pay flows were read.
- `modules/recalculation` budget writes.
- `frontend/test` coverage for this feature.

## Accepted deviations (BE package, 2026-10-05)

- FA-02(c): create keeps a client `status` of "Pending Approval"; every other value (Approved, Paid, Rejected, unknown)
  is stored as Draft. Draft -> Pending Approval is an ordinary user transition, so nothing is bypassed (lead decision
  after diff review).
- FA-02(d) / C4: payment PUT ignores only the SWIFT reconciliation fields (`swift_reference_no`, `swift_receipt_date`,
  `swift_transferred_amount`, `swift_transferred_currency`, `swift_variance_amount`, `swift_variance_status`,
  `swift_processing_days`, `swift_reconciliation_notes`). `swift_code` (beneficiary BIC) stays editable.
- FA-04: the prefill requires a rate only when the invoice amount is > 0. An empty file returns the recorded rate, or
  `exchange_rate: null` when its currency has none (contract: `BudgetPrefillResponse.exchange_rate` is nullable).
- FA-03: syncing a Superseded budget returns 409 FA_BUDGET_LOCKED, and Superseded budgets cannot be deleted either.
- New finding FA-26 (fixed): the prefill fallback read `po.items` (the relationship is `line_items`), a 500 whenever a
  PO had a FOB total of 0.
- Prefill invoice (customs review #6 / #10): each PO / invoice amount is converted at its own currency's rate. One
  currency: amount, currency and rate as recorded. Mixed currencies: the invoice is reported in EGP (amount = EGP total,
  currency "EGP", rate 1.0). An amount without a currency gives 400 FA_CURRENCY_MISSING (no silent USD).
- Security review: a PUT that rejects a Pending Approval or Approved request also needs `financial_approval.approve`
  (403 otherwise); a manage-only user may still reject a Draft.
- The payment approver is NOT stored: `payment_request_sessions` has no approver column (no schema change this wave).
  Add `approved_by` / `approved_at` with D1.
