# Phase 02 Financial approval (`modules/financial_approval`): backend review

Status: 2026-10-05, static review only (no pytest, no `import main`, no DB access). Baseline: the fixes of
`docs/plans/phase-02-quality-plan.md` (FA-01..FA-25) are in the code. They are not re-reported unless still broken.
Severity: **BLOCKER** = wrong money / data corruption / security / auth bypass. **CRITICAL** = wrong result or 500 on a
normal path. **MAJOR** = rule violation, real risk. **MINOR** = hygiene.

| File | Lines | Depth |
|---|---|---|
| `modules/financial_approval/service.py` | 2072 | Full, line by line |
| `modules/financial_approval/router.py` | 439 | Full (every route checked for its `require_permission`) |
| `modules/financial_approval/repository.py` | 481 | Full |
| `modules/financial_approval/validators.py` | 236 | Full |
| `modules/financial_approval/schemas.py` | 429 | Full |
| `modules/financial_approval/model.py` | 293 | Full (nullability, defaults, audit columns) |
| `modules/financial_approval/swift_file_extractor.py` | 220 | Targeted: entry point, PDF OCR loop, exception handling |
| `modules/financial_approval/swift_mt103_parser.py` | 741 | Not audited (regexes and scoring out of scope) |
| Context read | n/a | `customs_consultation/service.py:343-354` (variance caller), `auth/seed_rbac.py` grants, `alembic/versions/627c866a1010_*.py:192-224`, `common/legacy_rows.py`, Flutter `financial_approval_provider.dart` (list / pay / reconcile calls), screen `:2500-2545` (Mark Paid dialog), model `:120-160` |

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 2 |
| CRITICAL | 2 |
| MAJOR | 12 |
| MINOR | 10 |

Top points:
1. **Hard-block bypass (BE02-F01)**: a variance override, once given, is never cleared. A later upstream cost change with a new
   hard block (for example +20% customs) does not stop `/approve`, because approval only checks `variance_override_reason`.
2. **Wrong EGP freight on budget clone (BE02-F02)**: the clone multiplies the freight foreign amount by the *invoice* rate.
   A mixed-currency budget (rate 1.0) clones with freight USD 3,000 stored as EGP 3,000.
3. **Fabricated SWIFT reference (BE02-F04)**: "Mark as Paid" with an empty reference stores `SWF-<id>` on the payment request and
   on `import_files.swift_no`. The Flutter dialog sends an empty string when the field is left blank.
4. **Legacy budgets crash sync (BE02-F05)**: `revision_number` was added without `server_default` or backfill. Syncing a
   pre-upgrade Approved budget does `None + 1` and returns 500.
5. **Override and approve have no SoD and no status guard (BE02-F06/F07)**: the user who changed the customs costs can override
   the hard block and approve the budget. An Approved budget can be overridden, which silences its CRITICAL variance flag.

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE02-F01 | BLOCKER | `service.py:909`, `1486-1500`, `1680-1681` | `approve_import_budget_service` blocks only when `has_unresolved_variance and not variance_override_reason`. `variance_override_reason` is set by override (`:1681`) and is never cleared when `evaluate_and_record_budget_variance_service` records a **new** variance (`:1486-1500`). Result: once overridden, every later hard block on that budget is approvable without justification. | On a new variance in Pending Review / Needs Revalidation, clear `variance_override_reason` and `variance_overridden_by`. In approve, decide only on `repo.first_pending_hard_block(...)` (an override resolves the logs, so it still passes). Task BE02-T01. |
| BE02-F02 | BLOCKER | `service.py:965-972` | Budget clone: `frt_egp = frt_foreign * rate`, where `rate` is the invoice rate (`orig.exchange_rate` or `new_exchange_rate`). `freight_currency` can differ from `invoice_currency` (the prefill picks the freight currency on its own, `:1204-1207`). After a mixed-currency prefill the rate is 1.0 (`:1256`), so the freight foreign amount is stored as EGP unchanged. | Convert freight with its own currency's rate: the invoice rate if it is the same currency, 1.0 for EGP, else the latest commercial rate (`_require_rate`). Task BE02-T02. |
| BE02-F03 | MAJOR | `repository.py:234-256`, `320-332`; `schemas.py:145-153`, `175-183` | Budget EGP amounts (`invoice_amount_egp`, `freight_cost_egp`) come from the client and are never checked against `foreign × rate`. PUT `exchange_rate` alone leaves both EGP amounts and `total_budget_egp` on the old rate. The money calculation lives in Flutter. | Derive the EGP amounts on the server when the foreign amount is > 0, using the same helper as BE02-T02. Task BE02-T03. |
| BE02-F04 | CRITICAL | `service.py:550-552`, `565`, `662-675`; `router.py:254-261`; Flutter `financial_approval_screen.dart:2504-2545` | `/pay` with no or empty `swift_reference_no` stores the invented reference `SWF-{payment_id}` on the request and on `import_files.swift_no`. `_ensure_swift_ref_unused` is skipped for an empty value. The currency falls back to `"USD"` (`:552`). | Require a non-blank SWIFT reference (the request's or the parameter), with 400 `FA_SWIFT_REF_REQUIRED`. Drop the `"USD"` fallback (`currency_code` is NOT NULL). Task BE02-T04. |
| BE02-F05 | CRITICAL | `service.py:1585`; `model.py:141`; no Alembic migration for `revision_number` | `revision_number` (and `has_unresolved_variance`) were added after the table existed, with a Python `default=` only. `schema_upgrade_service` step 4b adds them as plain nullable columns, so pre-upgrade rows read NULL. Syncing such an Approved budget runs `None + 1`, a TypeError and a 500. | Alembic migration: backfill `revision_number=1`, `has_unresolved_variance=0` where NULL. Add `server_default` in the model. Defensive `(budget.revision_number or 1) + 1`. Task BE02-T05. |
| BE02-F06 | MAJOR | `service.py:1663-1691` | Override has no status guard. Overriding an **Approved** budget clears `has_unresolved_variance`, which silences the CRITICAL "approved budget variance" flag without a revision. A Superseded or Draft budget can also be overridden. | Allow it only from Pending Review / Needs Revalidation. Approved / Superseded get 409 `FA_BUDGET_LOCKED`. Draft gets 400 `FA_BUDGET_STATUS_INVALID`. Task BE02-T06. |
| BE02-F07 | MAJOR | `service.py:903-943`, `1525-1536`; `router.py:328-335`, `369-382` | Segregation of duties applies only to sync of Approved / Superseded budgets (`_require_sod`, `:1527`). The user recorded in `upstream_modified_by` can override their own hard block and approve the budget (approve and override never call `_require_sod`). The SoD message itself says the modifier may not "sync or approve". | Apply `_require_sod` to override and approve for every status (ADMIN exempt). Pass `current_user` to the approve service. Q1. Task BE02-T06. |
| BE02-F08 | MAJOR | `router.py:73-85`; `swift_file_extractor.py:104-122` | `smart_extract_swift_from_file` is `async def` and calls the synchronous service. pdfplumber, OCR and openpyxl then run on the event loop and freeze every other request for the duration. The scanned-PDF OCR loop renders **every** page at scale 2 with no page cap. | Run the service through `run_in_threadpool`. Cap the OCR fallback at `MAX_SWIFT_OCR_PAGES = 5`. Task BE02-T07. |
| BE02-F09 | MAJOR | `repository.py:159`, `305`; `router.py:217-229`, `312-325` | `GET /payment-requests` and `GET /import-budgets` return every row (no skip/limit, no total). | Add optional `skip`/`limit` and an `X-Total-Count` header. Additive: without `limit`, the current behaviour is kept for Flutter. Task BE02-T08. |
| BE02-F10 | MAJOR | `service.py:1129`, `1169`, `1180`, `1193`, `1204`, `1264`; `schemas.py:232-234`, `240` | The prefill invents data: payment terms `"Standard Payment"`, summary `"Advance Payment"` when there is no PO, supplier `"Foreign Exporter"`, incoterm `"FOB"`, freight quotation currency `"USD"` when the quotation has none (that amount is then converted at the USD rate). | Return `None` for the missing text fields (schema becomes `Optional`). A freight quotation with amount > 0 and no currency gets 400 `FA_CURRENCY_MISSING` (the existing `_require_currency`). Task BE02-T09. |
| BE02-F11 | MAJOR | `schemas.py:34`, `103`, `147`, `150`, `365-376` | Request schemas default the currency to `"USD"`: `PaymentRequestBase.currency_code`, `SwiftReconciliationRequest.swift_transferred_currency`, `ImportBudgetBase.invoice_currency` / `freight_currency`, `SmartSwiftReconcileRequest.swift_transferred_currency`. `SmartSwiftReconcileRequest.swift_transferred_amount` has no `gt=0`, and `swift_reference_no` has no length limit. A zero or negative SWIFT amount produces a fake Deficit and can mark the request Paid. | Make the currencies required on the create and reconcile requests. Budget currencies are required when their foreign amount is > 0. Add `gt=0` and `min_length=2, max_length=100`. Task BE02-T10. |
| BE02-F12 | MAJOR | `validators.py:218-236`; `repository.py:75-100`; `service.py:866-883` | Master data on create is not validated: `currency_code` can be any text (no check against `currencies`), `supplier_name` is taken from the client even when `supplier_id` is set (the beneficiary name can disagree with the FK), `project_id` is never validated (payment or budget), and the budget's `po_id` is never validated. | `require_known_currency` (active row in `currencies`), `supplier_name` taken from the Supplier row when `supplier_id` is given, `require_active` for Project and PurchaseOrder. Task BE02-T11. |
| BE02-F13 | MAJOR | `service.py:440-474`; `repository.py:208-215` | A payment PUT that changes `currency_code` without `exchange_rate` keeps the old currency's rate. `requested_amount_egp` becomes wrong (USD rate applied to EUR). | Changing the currency requires an explicit `exchange_rate` in the same PUT: 400 `FA_PAYMENT_RATE_REQUIRED`. Task BE02-T12. |
| BE02-F14 | MAJOR | `service.py:1930-1937` | Batch reconcile invents data: SWIFT reference `SWF-REF-{batch_id}` when the field is empty, and receipt date = today when `value_date` is missing or not `YYYY-MM-DD`. The second makes `swift_processing_days` wrong. | Missing reference → 400 (defence; confirm already requires it). A missing or unparseable `value_date` → 400 `FA_SWIFT_VALUE_DATE_INVALID`. Task BE02-T13. |
| BE02-F15 | MINOR | `service.py:1880-1884`, `1855-1858`, `486-489`; `router.py:301`, `439` | Wrong status code and language: match before confirm returns **403** (a state error, not a permission error). The confirm 400 detail and the reject 403 detail are in English. The restore responses use an English `message`. | 409 `FA_SWIFT_BATCH_STATUS_INVALID` (existing `batch_status_error`). Arabic details. Task BE02-T16. |
| BE02-F16 | MINOR | `service.py:897` | `_close_budget_tasks` closes every open task of the file whose notes contain `"BUDGET"`, not only this budget's tasks (same class as FA-09). | Match only `_ref_pattern(budget_code)`. Task BE02-T17. |
| BE02-F17 | MINOR | `service.py:1345-1351`, `1293-1294`, `1428-1436` | Variance logs of a missing budget return `[]` instead of 404. Queries run in the service instead of the repository. | `_get_budget` first, then move the 3 queries to `repository.py`. Task BE02-T16. |
| BE02-F18 | MINOR | `schemas.py:57-62`, `161-166` | `new_requested_amount` has no `gt=0` (the service returns a 400 instead of a 422). A `new_exchange_rate <= 0` is silently ignored and the old rate is used. | `Field(None, gt=0)` on both. Task BE02-T16. |
| BE02-F19 | MINOR | `service.py:1584-1621` | Revision code: a check-then-insert outside `_insert_with_unique_code`. Two concurrent syncs give an IntegrityError and a 500. | Catch `IntegrityError` around the commit, roll back, and return 409 `FA_CODE_GENERATION_CONFLICT`. Task BE02-T16. |
| BE02-F20 | MINOR | `validators.py:1-8`, `120-122` | The docstring says the FA codes are "not registered yet". They are now registered (`system_messages.py:1113-1151`). | Fix the docstring. Optional: switch `fa_error` to `CodedHTTPException`. Task BE02-T16. |
| BE02-F21 | MINOR | `schemas.py:346-349` | `file_base64` has no `max_length`, so the whole JSON body is parsed before the 413 check (`service.py:2063`). | `Field(..., max_length=ceil(10 MB × 4/3) + 4)`. Task BE02-T18. |
| BE02-F22 | MINOR | `service.py:1099` | The prefill (and therefore the variance engine) reads a soft-deleted import file. | Filter `ImportFile.is_active == True` and return 404. Task BE02-T16. |
| BE02-F23 | MINOR | `service.py:565`, `720`, `737`, `1967` | `import_files.swift_no` is overwritten by whichever request of the file was paid or reconciled last. With `auto_execute=False` it is written before the request is Paid, and it is never cleared when that Approved request is later rejected. | Write `swift_no` only in `_mark_paid`, and only when it is empty or equals this request's old reference. Q5. Task BE02-T17. |
| BE02-F24 | MAJOR | `alembic/versions/627c866a1010_*.py:203`; `model.py:51`, `126` | The legacy migration added `import_budget_approvals.exchange_rate` with `server_default='50.0'`, so pre-migration budgets carry an invented rate of 50. Clone (`service.py:965`) reuses it. The ORM Python defaults are still `50.0`. | Remove the Python `default=50.0` from both models. Clone of a budget requires `new_exchange_rate` when the source rate is the legacy 50.0 and the budget predates the migration (Q4). Task BE02-T14. |
| BE02-F25 | MINOR | `schemas.py:145-153`, `191-197`; `model.py:118-127`; `service.py:1374-1376` | Budget money columns are nullable, but `ImportBudgetResponse` declares them `float`. A legacy NULL becomes a validation error, so the whole list returns 500. `_cost_diffs` runs `new - None`, which raises a TypeError. | Response money fields become `Optional[float]` (legacy rule). `_cost_diffs` treats None as "no budget value" (old = 0.0 → pct 100). Task BE02-T18. |
| BE02-F26 | MAJOR | `model.py:80-88`, `150-158` (still open from plan D1) | `payment_request_sessions` and `import_budget_approvals` have no `created_by` / `updated_by`. Nobody can tell who created or edited a payment request, and maker-checker cannot be enforced (Q2). | Migration with nullable columns. The service sets them from the token user. Task BE02-T15. |

Routes / auth: all 31 routes have the router-level `get_current_user` plus a per-route `require_permission` (`can_view` / `can_manage` /
`can_approve` / `can_sync`) or `require_admin`. No gap found. No `except Exception: pass` left in the module (the extractor logs and falls back).

---

## 3. Tasks

Common rules for every task:
- Do not run `import main` against the real DB. Run tests with a scratch `DATABASE_PATH` (pytest fixtures already do this).
  Read the results from `--junitxml` and the exit code.
- A new coded error is registered in the same change in `modules/common/system_messages.py` (`"<CODE>": {"note": "..."}` next to
  the other `FA_*` entries around line 1113), in `docs/system_message_codes.json`, and in
  `frontend/lib/core/localization/system_messages/system_message_catalog_{ar,en}.dart`. Otherwise
  `tests/unit/test_review_wave_codes.py` fails. Raise coded errors with `validators.fa_error(status, CODE, arabic_message, **params)`.
- Statuses are English labels (constants in `modules/financial_approval/validators.py`).
- Append one line per task to `history/YYYY-MM-DD.md` (append-only).

### BE02-T01: A new variance cancels an earlier override (hard-block bypass)
- **Severity**: BLOCKER (BE02-F01)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: no. `/approve` returns the existing 400 `FA_BUDGET_HARD_BLOCK` in a case that was wrongly accepted.
- **Files to change**: `modules/financial_approval/service.py`, `tests/unit/test_be02_variance_override.py` (new)
- **Steps**:
  1. In `evaluate_and_record_budget_variance_service`, in the `elif current_status in (BUDGET_PENDING, BUDGET_REVALIDATION):`
     branch (`service.py:1486`), add `budget.variance_override_reason = None` and `budget.variance_overridden_by = None`.
     Do not change the Draft or Budget Approved branches.
  2. In `approve_import_budget_service` (`service.py:909-920`), replace
     `if db_item.has_unresolved_variance and not db_item.variance_override_reason:` with an unconditional
     `hard = repo.first_pending_hard_block(db, budget_id)`, and keep the same `fa_error` when `hard is not None`. An override sets
     its logs to `resolution_type="overridden"`, so an overridden block still passes. A new block (a new `pending` log) does not.
- **Acceptance criteria**: after override → new upstream hard variance, approve returns 400 `FA_BUDGET_HARD_BLOCK`, and
  `variance_override_reason` is NULL. Override → approve with no new variance still works. Characterization tests stay green.
- **Tests to add** (`tests/unit/test_be02_variance_override.py`, with the db fixture pattern of `tests/unit/test_financial_approval_guards.py`):
  - Budget in Pending Review with `customs_duties_egp=100000`, threshold 5.0. Make the prefill return customs 110000 (10% > 5).
    Call `evaluate_and_record_budget_variance_service`, expect status Needs Revalidation and 1 pending hard log.
  - Override with `"approved by GM"`, expect the log to be `overridden`.
  - Make the prefill return customs 132000 (the budget value is still 100000, so the variance is 32%). Evaluate
    again. Assert `variance_override_reason is None` and that `approve_import_budget_service` raises 400 with
    `detail["code"] == "FA_BUDGET_HARD_BLOCK"`.
  - Control: override, then approve with no second evaluation, expect Budget Approved.
- **Out of scope**: SoD on approve (T06). The recalculation module (`modules/recalculation/service.py:388,442`).

### BE02-T02: Budget clone converts freight with the freight currency's own rate
- **Severity**: BLOCKER (BE02-F02)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: no (same fields; the values are now correct)
- **Files to change**: `modules/financial_approval/service.py`, `tests/unit/test_be02_budget_money.py` (new)
- **Steps**:
  1. Add the helper `_budget_egp_amounts(db, invoice_foreign, invoice_currency, freight_foreign, freight_currency, invoice_rate) -> Tuple[float, float]`
     near `_require_rate` (`service.py:282`):
     - `inv_egp = invoice_foreign * invoice_rate`.
     - Freight rate:
       - `invoice_rate` when `normalize_currency(freight_currency) == normalize_currency(invoice_currency)`.
       - `1.0` when the freight currency is EGP.
       - Else `_require_rate(db, freight_currency)`, which raises 400 `FA_FX_RATE_MISSING` when no rate exists.
     - `frt_egp = freight_foreign * freight_rate`.
     - Return `(inv_egp, frt_egp)`.
  2. In `clone_import_budget_service` (`service.py:969-972`), keep `inv_egp = orig.invoice_amount_egp` when
     `inv_foreign <= 0`, and the same for freight. Otherwise use the helper.
- **Acceptance criteria**: the freight EGP of a clone never uses the invoice rate for another currency.
- **Tests to add** (`tests/unit/test_be02_budget_money.py`):
  - **Different currencies.** Source budget: invoice USD 10,000 at rate 50 (invoice EGP 500,000), freight EUR 2,000 (freight EGP 110,000),
    customs 80,000, clearance 20,000. Seeded latest commercial EUR rate = 55. Clone with `new_exchange_rate=52`. Expect:
    - `invoice_amount_egp = 520000.0`
    - `freight_cost_egp = 110000.0`
    - `total_budget_egp = 730000.0`
    - Today's code gives freight 104,000 and total 724,000.
  - **Mixed-currency source.** `invoice_currency="EGP"`, rate 1.0, `invoice_amount_foreign=1500000`, freight USD 3,000, seeded USD rate 50.
    Clone with no new rate. Expect `freight_cost_egp = 150000.0` (today: 3,000).
  - **Missing rate.** Freight GBP with no GBP rate gives 400 `FA_FX_RATE_MISSING`, and no row is created.
- **Out of scope**: create / update (T03).

### BE02-T03: Budget EGP amounts are derived on the server (create and update)
- **Severity**: MAJOR (BE02-F03)
- **Depends on**: BE02-T02 (helper)
- **Schema/migration needed**: no
- **API contract change**: yes.
  - Before: `invoice_amount_egp` and `freight_cost_egp` were stored as sent.
  - After: when the matching `*_foreign` amount is > 0, the server computes the EGP value with `_budget_egp_amounts` and ignores
    the client value. When the foreign amount is 0, the client EGP value is kept (EGP-only entries).
  - The response shape is unchanged.
  - Flutter: `frontend/lib/features/financial_approval/screens/financial_approval_screen.dart` (budget form). It should show the
    returned EGP values after saving.
- **Files to change**: `modules/financial_approval/service.py`, `modules/financial_approval/repository.py`, `tests/unit/test_be02_budget_money.py`
- **Steps**:
  1. `create_import_budget_service`: before the insert, compute `(inv_egp, frt_egp)` from the schema values and pass them to
     `repo.add_import_budget` as explicit arguments. Change its signature to
     `add_import_budget(db, schema, code, invoice_amount_egp, freight_cost_egp)`. The total is the sum of those plus customs and clearance.
  2. `update_import_budget_service`: merge `changes` over the current row values (foreign amounts, currencies, rate), recompute
     with the helper, and put `invoice_amount_egp` / `freight_cost_egp` into `changes` before `repo.apply_budget_changes`.
- **Acceptance criteria**: PUT `{"exchange_rate": 55}` on a budget with invoice USD 10,000 (EGP 500,000) stores invoice EGP 550,000 and recomputes the total.
- **Tests to add**:
  - Create with invoice USD 10,000, rate 50, and a client `invoice_amount_egp=1` → stored 500000.0.
  - The PUT case above, with freight EUR 2,000 and EUR rate 55 → `freight_cost_egp=110000.0`, total = 550000 + 110000 + customs + clearance.
  - Foreign amount 0 and `invoice_amount_egp=75000` → kept as 75000.0.
- **Out of scope**: sync / prefill (already computed server-side).

### BE02-T04: "Mark as Paid" requires a real SWIFT reference
- **Severity**: CRITICAL (BE02-F04)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes.
  - Before: `POST /payment-requests/{id}/pay` worked with no `swift_reference_no` or with an empty one, and stored `SWF-{id}`.
  - After: 400 `{code: "FA_SWIFT_REF_REQUIRED", message, payment_code}` when both the parameter and the stored
    `swift_reference_no` are blank.
  - Flutter: `financial_approval_screen.dart:2504-2545`. The SWIFT field becomes required (validator, disable the button when
    empty). `providers/financial_approval_provider.dart:172-186` must not send an empty string.
- **Files to change**: `modules/financial_approval/service.py`, `modules/common/system_messages.py`, `docs/system_message_codes.json`,
  the two Flutter catalogs (registration only), `tests/unit/test_financial_approval_guards.py`
- **Steps**:
  1. In `execute_payment_service` (`service.py:662`), set
     `ref = (swift_reference_no or "").strip() or (db_item.swift_reference_no or "").strip()`. When it is empty, raise
     `fa_error(400, "FA_SWIFT_REF_REQUIRED", "يجب إدخال الرقم المرجعي للسويفت قبل تسجيل السداد.", payment_code=...)`.
     Run `_ensure_swift_ref_unused(db, ref, db_item)` on `ref`.
  2. In `_mark_paid` (`service.py:550-552`), remove the `f"SWF-{item.payment_id}"` fallback (the callers always pass a
     reference now: assert non-empty) and the `"USD"` fallback (`item.currency_code` is NOT NULL).
  3. Register `FA_SWIFT_REF_REQUIRED` with params `payment_code`.
- **Acceptance criteria**:
  - `/pay` with `swift_reference_no=""` on an Approved request without a stored reference returns 400, and the status stays Approved.
  - `/pay` with `"FT2610050001"` returns Paid, and `import_files.swift_no == "FT2610050001"`.
  - `/pay` with no parameter on a request that already has a reference from smart-reconcile (`auto_execute=False`) succeeds.
- **Tests to add**: the 3 cases above in `test_financial_approval_guards.py`. Grep for an `SWF-` code path: none must be left in `service.py`.
- **Out of scope**: the batch reconcile fallback (T13).

### BE02-T05: Backfill legacy budget columns and make sync NULL-safe
- **Severity**: CRITICAL (BE02-F05)
- **Depends on**: none
- **Schema/migration needed**: yes.
  - New Alembic revision (`down_revision` = the current head, from `alembic heads`).
  - `UPDATE import_budget_approvals SET revision_number = 1 WHERE revision_number IS NULL`.
  - `UPDATE import_budget_approvals SET has_unresolved_variance = 0 WHERE has_unresolved_variance IS NULL`.
  - `UPDATE import_budget_approvals SET version = 1 WHERE version IS NULL`.
  - `UPDATE payment_request_sessions SET version = 1 WHERE version IS NULL`.
  - Guard each column with `inspector.get_columns` so it is a no-op when a column is absent.
  - Downgrade: no-op.
- **API contract change**: no
- **Files to change**: `alembic/versions/<new>_fa_legacy_budget_backfill.py` (new), `modules/financial_approval/model.py`,
  `modules/financial_approval/service.py`, `tests/unit/test_be02_legacy_rows.py` (new)
- **Steps**:
  1. Write the migration above.
  2. Model: add `server_default="1"` to `revision_number` and both `version` columns, and `server_default=sa.false()`
     (`"0"`) to `has_unresolved_variance`.
  3. Service `:1585`: `next_rev = (budget.revision_number or 1) + 1`.
- **Acceptance criteria**: syncing an Approved budget whose `revision_number` is NULL creates `BGT-YYYY-NNN-REV2` instead of returning 500.
- **Tests to add**: insert a budget, set `revision_number=None` with a raw `UPDATE`, set status Budget Approved, call
  `sync_budget_with_upstream_service` (a user other than `upstream_modified_by`). Expect `revision_created == True` and code `...-REV2`.
- **Out of scope**: money columns (T18).

### BE02-T06: Override and approve: status guard plus segregation of duties
- **Severity**: MAJOR (BE02-F06, BE02-F07)
- **Depends on**: BE02-T01 (same functions)
- **Schema/migration needed**: no
- **API contract change**: yes. These new error responses can now occur:
  - `POST /import-budgets/{id}/override-variance`: 409 `FA_BUDGET_LOCKED` (Approved / Superseded), 400
    `FA_BUDGET_STATUS_INVALID` (Draft), and 403 `FA_BUDGET_SOD_DENIED`.
  - `POST /import-budgets/{id}/approve`: 403 `FA_BUDGET_SOD_DENIED`.
  - Flutter: `financial_approval_screen.dart` (the approve-budget and override dialogs) shows `ApiError.message(e)`.
- **Files to change**: `modules/financial_approval/service.py`, `modules/financial_approval/router.py`,
  `modules/common/system_messages.py` (update the `FA_BUDGET_SOD_DENIED` note text only), `tests/unit/test_financial_approval_guards.py`
- **Steps**:
  1. `_require_sod(budget, current_user)` (`service.py:1525`): remove the `budget.budget_status not in BUDGET_LOCKED` condition
     (SoD applies in every status). The ADMIN exemption stays. Make the Arabic message generic ("...لا يجوز لك مزامنة أو تجاوز أو اعتماد هذه الميزانية...").
  2. `override_budget_variance_service`:
     - Call `_require_sod` first.
     - Approved / Superseded: `raise budget_locked_error(budget)`.
     - Any status other than Pending Review / Needs Revalidation: `fa_error(400, "FA_BUDGET_STATUS_INVALID", ..., budget_code, status)`.
  3. `approve_import_budget_service(db, budget_id, current_user: User)`: call `_require_sod(db_item, current_user)` after
     `require_budget_approvable`, and set `approved_by = current_user.username`. In the router (`router.py:335`), pass `current_user=current_user`.
- **Acceptance criteria**:
  - A user equal to `upstream_modified_by` (not ADMIN) gets 403 on both override and approve. ADMIN passes.
  - An override on an Approved budget gets 409, and `has_unresolved_variance` stays True.
- **Tests to add**: the 4 cases above. Update the existing callers of `approve_import_budget_service(..., approved_by=...)` in the
  tests to pass a `User` (grep `approve_import_budget_service(` in `tests/unit`).
- **Out of scope**: maker-checker on payment requests (needs T15 and Q2).

### BE02-T07: SWIFT file extraction off the event loop, plus an OCR page cap
- **Severity**: MAJOR (BE02-F08)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: no
- **Files to change**: `modules/financial_approval/router.py`, `modules/financial_approval/swift_file_extractor.py`, `tests/unit/test_swift_multi_format_extractor.py`
- **Steps**:
  1. Router `:73-85`: keep `async def` and `await file.read(...)`, then
     `return await run_in_threadpool(service.smart_extract_swift_from_file_service, db=db, filename=..., content_bytes=..., target_payment_id=...)`
     (`from starlette.concurrency import run_in_threadpool`).
  2. Extractor `:104-122`: `MAX_SWIFT_OCR_PAGES = 5` and `for i in range(min(len(pdf), MAX_SWIFT_OCR_PAGES)):`. When pages are
     skipped, log `logger.info(...)` with the count.
- **Acceptance criteria**: a 20-page image-only PDF runs OCR on 5 pages only. The endpoint returns the same response shape.
- **Tests to add**: monkeypatch `get_ocr_engine` with a counter stub and `pdfium.PdfDocument` with a 20-page fake. Assert 5 calls.
- **Out of scope**: the parser regexes.

### BE02-T08: Optional pagination on the two list endpoints
- **Severity**: MAJOR (BE02-F09)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes, additive.
  - New query parameters `skip: int = Query(0, ge=0)` and `limit: Optional[int] = Query(None, ge=1, le=500)` on
    `GET /payment-requests` and `GET /import-budgets`, plus the response header `X-Total-Count`.
  - Without `limit`, the full list is returned (current Flutter keeps working).
  - Flutter (later): `providers/financial_approval_provider.dart:75-97`, `:470-497`.
- **Files to change**: `router.py`, `service.py`, `repository.py`, `tests/unit/test_financial_approval.py`
- **Steps**:
  1. Repository: split the query building into a helper, `count = query.order_by(None).count()`, then
     `.offset(skip).limit(limit)` when `limit` is set. Return `(items, total)`.
  2. Service: return both values. Router: `response: Response` parameter, `response.headers["X-Total-Count"] = str(total)`.
- **Acceptance criteria**: 30 rows with `skip=10&limit=5` returns 5 items (ids 20..16 in desc order) and the header `X-Total-Count: 30`. No params returns 30 items.
- **Tests to add**: the case above for both endpoints.
- **Out of scope**: the Flutter paging UI.

### BE02-T09: The prefill stops inventing values
- **Severity**: MAJOR (BE02-F10)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. `BudgetPrefillResponse` fields become nullable:
  - `supplier_name: Optional[str]` (was `"Foreign Exporter"` when unknown)
  - `incoterm: Optional[str]` (was `"FOB"`)
  - `payment_terms_summary: Optional[str]` (was `"Advance Payment"` when there is no PO)
  - `LinkedPOItemSchema.payment_terms: Optional[str]` (was `"Standard Payment"`)
  - `freight_currency: Optional[str]` (None when there is no freight)
  - A freight quotation with amount > 0 and no currency → 400 `FA_CURRENCY_MISSING` (already registered).
  - Flutter: `models/financial_approval_model.dart:120-160` must drop its own `?? 'FOB'` default and keep the empty string or
    null. The payment form must not fill `payment_type` from a null summary.
- **Files to change**: `service.py`, `schemas.py`, `tests/unit/test_financial_approval_guards.py`
- **Steps**:
  1. `service.py:1129`: `p_term = po.payment_terms` (may be None). Add to `payment_terms_set` / `terms_list_str` only when set.
  2. `:1169`: `payment_terms_summary = None` when there are no terms.
  3. `:1180`: `supplier_name = sup.company_name if sup else imp.supplier_name` (may be None). `beneficiary_name` the same.
  4. `:1193`: `freight_currency: Optional[str] = None`.
  5. `:1204`: `curr = _require_currency(getattr(itm, "quotation_currency", None), "freight quotation")` (the `source` param is shown in the message; add the shipping session's business code if the model has one).
  6. `:1264`: `incoterm=imp.incoterm_code` (may be None).
  7. In `_apply_prefill` (`:1388`), keep the budget's existing `freight_currency` when the prefill value is None (the column has a default).
- **Acceptance criteria**: a file with no supplier, no incoterm and no PO returns those fields as null. A freight item with amount 1,200 and no currency returns 400 `FA_CURRENCY_MISSING`.
- **Tests to add**: the 2 cases above. Update existing tests that assert `"FOB"` / `"Advance Payment"`, if any (grep `tests/unit`).
- **Out of scope**: the `import_file_title` label (`"Shipment {code}"`, a derived display label).

### BE02-T10: Money and currency input validation on request schemas
- **Severity**: MAJOR (BE02-F11)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. A missing currency is now 422:
  - `PaymentRequestCreate.currency_code` becomes required (`min_length=3, max_length=10`).
  - `SwiftReconciliationRequest.swift_transferred_currency` and `SmartSwiftReconcileRequest.swift_transferred_currency` become required.
  - `SmartSwiftReconcileRequest.swift_transferred_amount` gets `gt=0`, and `swift_reference_no` gets `min_length=2, max_length=100`.
  - `ImportBudgetCreate`: a `model_validator` requires `invoice_currency` when `invoice_amount_foreign > 0` and `freight_currency`
    when `freight_cost_foreign > 0`. Remove the `"USD"` defaults on the Create schema only; the response keeps them.
  - Flutter: `providers/financial_approval_provider.dart:191-210` (`swiftTransferredCurrency = 'USD'` default) and `:265-290`
    (smart reconcile) must pass the request's currency. The payment form must always send `currency_code`.
- **Files to change**: `schemas.py`, `tests/unit/test_financial_approval_guards.py`, `tests/unit/test_financial_approval.py` (fix payloads that relied on the defaults)
- **Steps**:
  1. Override the fields in the Create / request classes (not in `PaymentRequestBase`, which `PaymentRequestResponse` inherits).
     `@read_model` already strips input rules from responses.
  2. Add the budget `model_validator(mode="after")`.
- **Acceptance criteria**:
  - Create without `currency_code` → 422.
  - Smart reconcile with `swift_transferred_amount=0` → 422.
  - Budget create with `invoice_amount_foreign=1000` and no `invoice_currency` → 422.
- **Tests to add**: the 3 cases above.
- **Out of scope**: master-data existence (T11).

### BE02-T11: Validate master data on create and update
- **Severity**: MAJOR (BE02-F12)
- **Depends on**: BE02-T10
- **Schema/migration needed**: no (the currency FK column is deferred, Q3)
- **API contract change**: yes.
  - An unknown currency → 400 `FA_CURRENCY_UNKNOWN{currency_code}` (new code).
  - An inactive or missing project / PO → 404 (existing `require_active` detail).
  - `supplier_name` is overwritten with the supplier's `company_name` when `supplier_id` is set (the response shows the master name).
  - Flutter: none required (the payment form already sends `supplier_id`).
- **Files to change**: `validators.py`, `service.py`, `modules/common/system_messages.py` (+ `docs/system_message_codes.json`, Flutter catalogs: registration only), `tests/unit/test_financial_approval_guards.py`
- **Steps**:
  1. `validators.require_known_currency(db, code) -> str`:
     - `normalize_currency(code)`.
     - `CurrencyRepository(db).get_currency_by_code(norm)`; when it is missing or inactive, raise `fa_error(400, "FA_CURRENCY_UNKNOWN", "العملة {code} غير معرفة في شاشة العملات.", currency_code=code)`.
     - Return `norm`.
  2. `validate_payment_request_inputs`: add `currency_code` and `project_id` parameters. Run `require_active(db, Project, project_id, "المشروع", status_code=404)` and `require_known_currency`.
  3. `create_payment_request_service`:
     - Store the normalized currency.
     - When `supplier_id` is set, set `supplier_name` (and `beneficiary_name` when empty) from the Supplier row, before `repo.add_payment_request`. Pass the values explicitly, or use `schema.model_copy(update=...)`.
  4. `update_payment_request_service`: when `currency_code` is in `changes`, run `require_known_currency`.
  5. `create_import_budget_service` and `update_import_budget_service`:
     - `require_active` for `po_id` and `project_id` when they are given.
     - `require_known_currency` for `invoice_currency` / `freight_currency` when their foreign amount is > 0.
- **Acceptance criteria**:
  - Currency `"XYZ"` → 400 `FA_CURRENCY_UNKNOWN`.
  - `supplier_id=5`, `supplier_name="Wrong"` → stored as the supplier's company name.
  - `project_id=999` → 404.
- **Tests to add**: the 3 cases above.
- **Out of scope**: an FK column for currency (Q3).

### BE02-T12: Changing a payment's currency requires a new rate
- **Severity**: MAJOR (BE02-F13)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. PUT with a different `currency_code` and no `exchange_rate` → 400
  `FA_PAYMENT_RATE_REQUIRED{payment_code, currency_code}` (new code). Flutter: the payment edit form in
  `financial_approval_screen.dart` must send the rate whenever the currency changes (it already sends the full form; verify).
- **Files to change**: `validators.py`, `modules/common/system_messages.py` (+ json, Flutter catalogs: registration), `tests/unit/test_financial_approval_guards.py`
- **Steps**: in `validate_payment_update`, when `"currency_code" in changes` and
  `normalize_currency(changes["currency_code"]) != normalize_currency(item.currency_code)` and `"exchange_rate" not in changes`,
  raise `fa_error(400, "FA_PAYMENT_RATE_REQUIRED", "عند تغيير عملة طلب الصرف يجب إدخال سعر الصرف الجديد.", payment_code=..., currency_code=...)`.
- **Acceptance criteria**:
  - Draft USD 10,000 at rate 50 (EGP 500,000). PUT `{"currency_code": "EUR"}` → 400.
  - PUT `{"currency_code": "EUR", "exchange_rate": 55}` → `requested_amount_egp == 550000.0`.
- **Tests to add**: the 2 cases above.
- **Out of scope**: none.

### BE02-T13: Batch reconcile without fabricated reference or date
- **Severity**: MAJOR (BE02-F14)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes. `POST /swift/review-batch/{id}/reconcile` returns 400 `FA_SWIFT_VALUE_DATE_INVALID{batch_code, value}`
  (new code) when `value_date` is missing or not `YYYY-MM-DD`. Flutter: `widgets/swift_extraction_review_widget.dart` must let the
  user edit `value_date` (an existing field edit endpoint) and show the error.
- **Files to change**: `service.py`, `modules/common/system_messages.py` (+ json, Flutter catalogs: registration), `tests/unit/test_swift_review_layer.py`
- **Steps**:
  1. `service.py:1930`: `swift_ref = (field_map.get("transaction_reference") or "").strip()`. When it is empty, raise
     `batch_status_error(batch, 400)` (defence; confirm already requires it).
  2. `:1931-1937`: a missing or unparseable `value_date` raises the new 400 instead of using `date.today()`.
     Accept `%Y-%m-%d` only; the parser output format is ISO, so verify that in `swift_mt103_parser.py` before tightening.
- **Acceptance criteria**: a confirmed batch with `value_date=""` → 400, and the payment stays Approved. `value_date="2026-10-01"` with request date 2026-09-20 → `swift_processing_days == 11`.
- **Tests to add**: the 2 cases above.
- **Out of scope**: making `value_date` a mandatory confirm field (Q6).

### BE02-T14: Remove the 50.0 rate defaults from the models
- **Severity**: MAJOR (BE02-F24)
- **Depends on**: none
- **Schema/migration needed**: no DDL. Python defaults only. The legacy `server_default='50.0'` in the DB stays until Q4 is answered.
- **API contract change**: no
- **Files to change**: `model.py`, `tests/unit/test_be02_budget_money.py`
- **Steps**: in `model.py:51` and `:126`, remove `default=50.0` (keep `nullable=False` on payments: every create path passes a rate).
  Run `grep -rn "50\.0" modules/financial_approval`: expect no money default left (the `schemas.py:35,153` Base defaults stay
  overridden by the Create classes. Change them to `Optional[float] = None` on the Base classes so that the response shows None
  for a missing rate instead of 50).
- **Acceptance criteria**: constructing `PaymentRequestSession(...)` without `exchange_rate` and flushing raises an IntegrityError (no silent 50).
- **Tests to add**: the case above.
- **Out of scope**: rewriting legacy rows (Q4).

### BE02-T15: Audit columns `created_by` / `updated_by` (still open from plan D1)
- **Severity**: MAJOR (BE02-F26)
- **Depends on**: none
- **Schema/migration needed**: yes.
  - New Alembic revision adding `created_by VARCHAR(100) NULL` and `updated_by VARCHAR(100) NULL` to `payment_request_sessions`
    and `import_budget_approvals`.
  - No backfill value exists (the author of legacy rows is unknown). Keep them NULL and declare the response fields `Optional[str]`.
  - Guard with `inspector.get_columns`. Downgrade drops the columns with `batch_alter_table`.
- **API contract change**: yes, additive. `created_by` and `updated_by` appear in `PaymentRequestResponse` and
  `ImportBudgetResponse`. Flutter: `models/financial_approval_model.dart` can read them (optional).
- **Files to change**: `alembic/versions/<new>_fa_audit_by.py`, `model.py`, `schemas.py`, `service.py`, `tests/unit/test_financial_approval.py`
- **Steps**:
  1. Model columns `Mapped[Optional[str]] = mapped_column(String(100), nullable=True)`.
  2. Service sets `created_by=current_user_name` on create and clone (add a `current_user_name` parameter to both clone services,
     passed from the router `current_user.username`), and `updated_by` on update, approve, pay, reconcile, override and sync.
     Use the existing `set_created_info` / `set_updated_info` helpers if they exist in `modules/common`; grep first.
- **Acceptance criteria**: a payment created through the API by user `fin1` has `created_by == "fin1"`, and approved by `gm1` has `updated_by == "gm1"`.
- **Tests to add**: the case above through the TestClient fixture of `test_financial_approval_guards.py` (`api`).
- **Out of scope**: maker-checker enforcement (Q2).

### BE02-T16: Hygiene: status codes, Arabic details, layering, clone schemas, revision race, soft-deleted file
- **Severity**: MINOR (BE02-F15, F17, F18, F19, F20, F22)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes, small.
  - Match before confirm returns 409 instead of 403.
  - Clone with an amount or rate <= 0 → 422.
  - Variance logs of a missing budget → 404.
  - The restore responses carry Arabic text.
  - Flutter: `screens/swift_reconciliation_screen.dart` checks the status code of the match error (grep `403`).
- **Files to change**: `service.py`, `schemas.py`, `repository.py`, `validators.py`, `router.py` (≤5)
- **Steps**:
  1. `service.py:1880-1884` → `raise batch_status_error(batch)` (409).
  2. `:1855-1858`, `:486-489` → Arabic details.
  3. `router.py:301,439` → Arabic messages.
  4. `schemas.py:60`, `:165` → `Field(None, gt=0)`.
  5. `service.py:1345` → call `_get_budget(db, budget_id)` first. Move the variance-log, threshold-setting and active-budgets
     queries into the repository functions `variance_logs_for_budget`, `get_setting`, `active_budgets_for_file`.
  6. `:1619-1621` → wrap the commit in `try/except IntegrityError: db.rollback(); raise fa_error(409, "FA_CODE_GENERATION_CONFLICT", ...)`.
  7. `:1099` → add `ImportFile.is_active == True`.
  8. `validators.py:1-8` → fix the docstring.
- **Acceptance criteria**: the existing tests pass after updating the asserted status code of match-before-confirm.
- **Tests to add**: one test per behaviour change (match 409, clone 422, logs 404, prefill of a soft-deleted file 404).
- **Out of scope**: none.

### BE02-T17: Task auto-close and `import_files.swift_no` scope
- **Severity**: MINOR (BE02-F16, BE02-F23)
- **Depends on**: BE02-T04
- **Schema/migration needed**: no
- **API contract change**: no
- **Files to change**: `service.py`, `tests/unit/test_financial_approval_guards.py`
- **Steps**:
  1. `service.py:897`: remove `"BUDGET" in notes or`. Match only `by_code`.
  2. Remove the `_set_file_swift_no` calls at `:720` and `:1967`, so `swift_no` is written only when the request becomes Paid.
  3. In `_mark_paid` (`:565`), write `imp.swift_no` only when it is empty or equals the old `item.swift_reference_no` (Q5 may change this).
- **Acceptance criteria**: approving budget A closes only the tasks whose notes or title contain A's code. Smart-reconcile with `auto_execute=False` leaves `import_files.swift_no` unchanged.
- **Tests to add**: the 2 cases above.
- **Out of scope**: none.

### BE02-T18: Legacy-tolerant budget money and base64 size limit
- **Severity**: MINOR (BE02-F21, BE02-F25)
- **Depends on**: none
- **Schema/migration needed**: no
- **API contract change**: yes, small. Budget response money fields can be `null` for legacy rows. Flutter `models/financial_approval_model.dart` already uses `?? 0.0`; verify for `ImportBudgetModel`.
- **Files to change**: `schemas.py`, `service.py`, `tests/unit/test_be02_legacy_rows.py`
- **Steps**:
  1. In `ImportBudgetResponse`, redeclare `invoice_amount_egp`, `invoice_amount_foreign`, `freight_cost_egp`, `freight_cost_foreign`,
     `customs_duties_egp`, `clearance_inland_egp`, `exchange_rate` and `total_budget_egp` as `Optional[float] = None`.
  2. In `_cost_diffs` (`service.py:1374`), `old = getattr(budget, column)`, then `old_val = float(old) if old is not None else 0.0`.
  3. `SmartSwiftFileExtractRequest.file_base64: str = Field(..., max_length=13_981_020)` (10 MB × 4/3 + padding).
- **Acceptance criteria**: a list that contains a budget with `invoice_amount_egp = NULL` (raw UPDATE) returns 200.
- **Tests to add**: the case above, plus a 422 for an oversize base64 string (build the string with `"A" * 14_000_000`).
- **Out of scope**: none.

---

## 4. Frontend impact

| Backend task | Endpoint / field | What Flutter must do | Files |
|---|---|---|---|
| T04 | `POST /payment-requests/{id}/pay` | The SWIFT reference is required (disable the button when it is empty, never send `""`). Show `FA_SWIFT_REF_REQUIRED`. | `screens/financial_approval_screen.dart:2504-2545`, `providers/financial_approval_provider.dart:172-186` |
| T06 | `/import-budgets/{id}/approve`, `/override-variance` | Handle 403 `FA_BUDGET_SOD_DENIED`, 409 `FA_BUDGET_LOCKED` and 400 `FA_BUDGET_STATUS_INVALID`. Hide the override button for Approved / Superseded / Draft. | `screens/financial_approval_screen.dart` (budget dialogs) |
| T03 | Budget create / PUT | The server computes the EGP amounts when a foreign amount > 0. Show the returned values, and do not treat the client-side EGP as authoritative. | budget form in `financial_approval_screen.dart` |
| T08 | `GET /payment-requests`, `GET /import-budgets` | Optional `skip` / `limit` and the `X-Total-Count` header (adopt later). | `providers/financial_approval_provider.dart:75-97`, `:470-497` |
| T09 | `GET /prefill/{id}` | `supplier_name`, `incoterm`, `payment_terms_summary`, `linked_pos[].payment_terms` and `freight_currency` can be null. Remove the local `?? 'FOB'`. 400 `FA_CURRENCY_MISSING` is possible. | `models/financial_approval_model.dart:120-160`, the payment form prefill |
| T10 | Create / reconcile payloads | Always send `currency_code`, `swift_transferred_currency` (the request's currency, never a `'USD'` default), and the budget currencies when there are foreign amounts. | `providers/financial_approval_provider.dart:191-210`, `:265-290`, forms |
| T11 / T12 | Payment create / PUT | New 400 codes `FA_CURRENCY_UNKNOWN` and `FA_PAYMENT_RATE_REQUIRED`. `supplier_name` comes back as the master name. | payment form |
| T13 | `POST /swift/review-batch/{id}/reconcile` | New 400 `FA_SWIFT_VALUE_DATE_INVALID`. Let the user fix `value_date` in the review widget. | `widgets/swift_extraction_review_widget.dart` |
| T15 | Responses | New optional `created_by` / `updated_by`. | `models/financial_approval_model.dart` |
| T16 | `POST /swift/review-batch/{id}/match` | 409 instead of 403 before confirmation. | `screens/swift_reconciliation_screen.dart` |
| T18 | Budget response | Money fields can be null for legacy rows. | `models/financial_approval_model.dart` (`ImportBudgetModel.fromJson`) |

New message codes to add to both Flutter catalogs: `FA_SWIFT_REF_REQUIRED`, `FA_CURRENCY_UNKNOWN`, `FA_PAYMENT_RATE_REQUIRED`, `FA_SWIFT_VALUE_DATE_INVALID`.

---

## 5. Open questions for the CTO

- **Q1**: Should SoD (the person who changed upstream costs cannot approve or override) apply to budgets in every status, or only to Approved ones?
  *Safe default:* every status, ADMIN exempt (T06).
- **Q2**: Maker-checker for payment requests: may the creator approve and pay their own request? Today a FINANCE_OFFICER with
  `manage` and `approve` can do the whole cycle alone. *Safe default:* after T15, block approval when `created_by == current_user` (except ADMIN).
- **Q3**: The currency columns (`currency_code`, `invoice_currency`, `freight_currency`, `swift_transferred_currency`) are still free
  `String(10)` (plan D2). Is a migration to `currency_id` FK now in scope? *Default:* app-level validation only (T11). The FK stays deferred.
- **Q4**: Legacy budgets created before migration `627c866a1010` got `exchange_rate = 50.0` from `server_default`. Should they be
  listed for manual correction? *Default:* a read-only count first (`SELECT COUNT(*) FROM import_budget_approvals WHERE exchange_rate = 50.0`),
  then the CTO decides. No automatic rewrite.
- **Q5**: An import file can have several payment requests (advance and final). Which SWIFT should `import_files.swift_no` hold?
  *Default:* the first Paid one, never overwritten (T17).
- **Q6**: Should `value_date` become a mandatory confirm field of the SWIFT review layer? *Default:* no. The reconcile step requires it (T13).
- **Q7**: Should a payment request check its cumulative amount against the PO or invoice total (no over-payment)? There is no
  such guard today. *Default:* no change until the rule is written in `docs/phase_02_financial_approval.md`.
- **Q8**: Plan items D4 (a unique index on the active `swift_reference_no`) and D5 (`Float` money columns) are still open.
  *Default:* stay deferred. The app-level guard `_ensure_swift_ref_unused` covers D4.
- **Q9**: `modules/recalculation/service.py:388,442` also writes budget overrides and statuses, outside this module's guards.
  It is not reviewed here: is it in scope for another review?
