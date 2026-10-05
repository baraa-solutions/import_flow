# Phases 6 "Customs Preparation" and 7 "Customs Clearance": quality audit and fix plan

Status: proposed (2026-10-05). Nothing implemented. Static reading only: no pytest, no flutter test, no `import main`.
Method and severity scale are the same as `docs/plans/phase-01-quality-simplify-plan.md`. Shared helpers come from the
Phase-1 A1 wave (`docs/plans/phase-01-progress.md`). **No schema changes or migrations in this wave.**

## Audit coverage

| Area | Depth |
|---|---|
| `modules/customs_clearance/service.py` (2,366) | Full: all 14 services, CL-05 invoices and aggregates |
| `modules/customs_clearance/{router,validators,repository,model,schemas}.py` | Full |
| `modules/customs_clearance_quotations/{router,validators,service,model}.py` | Full |
| `modules/customs_clearance_quotations/{schemas,repository}.py` | Grep plus the key functions (create/update/delete quote, get_rfq_by_id). Price-list repo **not audited** |
| Downstream consumers | `financial_settlement/service.py:208-224, 1090-1140` and `lifecycle_board/service.py:277-484` (commit points) read to check the hand-off |
| Flutter (18k lines) | Rule grep sweeps of all 23 files. Read fully: `customs_clearance_provider.dart`, the `customs_clearance_model.dart` JSON keys, the payload keys of the 8 dialogs, `under_bond_release_dialog.dart:84-165`, `clearance_expenses_dialog.dart:100-175`. Screens and export services **not read line by line** |
| Docs | `docs/phase_07_customs_clearance.md`, `DOMAIN_RULES.md` §1-2. `docs/phase_06/tasks/*` and `docs/phase_07/tasks/*` **not audited** |

Severity: **BLOCKER** = breaks a non-negotiable rule, or can corrupt money, customs data or references. **CRITICAL** = a wrong result or a 500 on a normal path. **MAJOR** = a rule violation or real risk. **MINOR** = hygiene.

---

## 1. Findings

### 1a. Backend `customs_clearance` (CL)

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| CL-01 | BLOCKER | `customs_clearance/router.py:51-207` | None of the 21 routes has `require_permission`, only `get_current_user`. Any viewer can assess duties, record payments, issue a release or delete invoices. | GET routes: `customs_clearance.view`. Release routes (`issue-final-release`, `{id}/complete-release`): `customs_clearance.release`. Every other mutating route, invoices included: `customs_clearance.update`. These are existing codes, so no catalog change (Q9). |
| CL-02 | BLOCKER | `service.py:1656-1666` | `issue_final_customs_release_service` loads the record by `payload.clearance_id` and never checks that it belongs to `payload.import_file_id`. File B's record gets the release permit while file A is marked `is_customs_released`. | If `record.import_file_id != payload.import_file_id`, return 400 "سجل التخليص المحدد لا يخص ملف الشحنة.". |
| CL-03 | BLOCKER | `repository.py:64,119` vs `service.py:1144` | There are two formulas for `total_duty_payable`. Create and update (repository) sum duty+VAT+schedule+WHT+lab and leave out `development_fee_amount` and `customs_service_fees`. CL-02 includes them. Any `PUT /{id}` after CL-02 silently drops the two components. `financial_settlement/service.py:1096-1099` uses `total_duty_payable` for the remaining balance. | One pure function `_duty_components_total(rec)` in `service.py` that sums the 7 components, used by create, update and assess. The repository stops computing anything. Characterize first (T-3). |
| CL-04 | BLOCKER | `schemas.py:286-361`, `repository.py:109-131` | Through `CustomsClearanceUpdate`, a generic PUT can set `status`, `payment_status`, `duty_paid_amount`, `actual_duty_total`, `assessment_status`, `delivery_order_status`, the `total_*_expenses_egp` aggregates and `clearance_invoices_count`. That bypasses every workflow guard: mark it paid, then release. The repository uses `exclude_unset` only, so an explicit `null` on a NOT NULL column (`customs_office_name`, `inspection_result`) or on a money field (`None + float` at l.119) causes a 500. | Remove the workflow and derived fields from the update schema. Pydantic then ignores them, so old clients do not break. Drop `None` values in the service before `setattr`. Business logic moves from the repository to the service. |
| CL-05 | CRITICAL | `service.py:1384-1425` | CL-03 duty payment has three problems. (a) `actual_duty_total = duty_paid_amount` (l.1413) overwrites the assessed Nafeza total, and landed cost reads `actual_duty_total` (`financial_settlement/service.py:218-219`). (b) Any amount, partial included, becomes "Paid & Verified". (c) With no record, it creates one with the fake declaration `"DEC-AUTO-46"` (l.1398) through `repository.create_customs_clearance`, which commits mid-request. | Require an assessed record (`total_duty_payable > 0`), else 409 "لا يمكن تسجيل السداد قبل احتساب الرسوم الجمركية النهائية (CL-02).". Keep `actual_duty_total` as assessed. Return 400 when `duty_paid_amount < actual_duty_total - 0.01` (Q1). Remove the auto-create. |
| CL-06 | CRITICAL | `service.py:1668-1692` | The release payment check passes when any `duty_paid_amount > 0` or when `imp_file.customs_duty_payment_status == "PAID"`, so a partial payment releases the goods. With no record, it also creates one on the spot. | Require an existing active record with paid status and `duty_paid_amount >= actual_duty_total - 0.01`. Otherwise return 400 with the existing Arabic detail. Do not auto-create a record in release. |
| CL-07 | CRITICAL | `service.py:1553-1607`, `1874-1959`, `validators.py:7-18` | There is a second payment and release path: `/{id}/pay-duty` and `/{id}/complete-release`, which the FE calls at `customs_clearance_screen.dart:1858,1957`. It sets a different status ("Duty Paid"), does not sync the ImportFile `customs_duty_*` fields, needs no amount, lets the client set `estimated_duty_total`, and commits before the lifecycle step. | Keep both paths (contract), but turn them into thin adapters that build the CL-03/CL-04 payload and call the same service. Then the guards from CL-05/06 apply once. |
| CL-08 | CRITICAL | `service.py:2022-2097`, `schemas.py:197-210` | Under-bond and lab results. (a) Under-bond has no state guard: it can run after a final release, and `release_date` gets overwritten. (b) `lab_test_result` is free text, and Arabic `"مطابق"` / `"مقبول"` is accepted and stored (l.2071), against single-language storage. (c) A conforming result sets `status="Final Release Granted"` and `is_customs_released=True` without any duty-payment check, and settlement then books the duty. (d) The Arabic default `customs_warehouse_location` is appended to `notes`. (e) The FE payload never matches (FE-01), so the flow is broken end to end. | Under-bond: 409 if already under bond or finally released. Lab result: accept the codes `CONFORMING` / `NON_CONFORMING`, map legacy values (conforming, approved, مطابق, مقبول) on input, and store the code. Lift the lock as today, but set `is_customs_released` and the release status only when the duty is paid (Q3). Make the English default location `"Factory bonded warehouse"`. |
| CL-09 | CRITICAL | `service.py:2211-2216`, `schemas.py:224` | Clearance invoice FX: `exchange_rate` defaults to 1.0, so a USD invoice with `amount_egp=0` is booked 1:1 as EGP. `vat_included` is stored but ignored: net = amount + VAT always, which double-counts VAT on an inclusive invoice (Q2). | Make `exchange_rate: Optional[float] = None`. When `currency != "EGP"` and `amount_egp <= 0`, a rate is required, else 400 "سعر الصرف مطلوب لفاتورة بعملة أجنبية.". Keep the net formula until Q2 is answered. |
| CL-10 | MAJOR | `service.py:2125-2127`, `2319-2322` | Aggregates match category substrings. The Arabic keywords are dead because categories are now codes. The record total (`total_net`, all invoices) differs from the summary split. `OTHER_CLEARANCE` counts as a clearance fee because it contains "clearance". | Use explicit code sets, normalizing legacy rows with `enum_codes.normalize` on read: clearance = {BROKER_FEES, OTHER_CLEARANCE}, port = {PORT_DUES_WHARFAGE, STORAGE_DEMURRAGE}, handling = {STEVEDORING_HANDLING}. These sets give the same numbers as today for code rows (pin with T-6). |
| CL-11 | MAJOR | `service.py:2272`, `306,558,771,1005,1243,1470,1770` | CL-05 task closing reads `t.task_name`, which does not exist. The AttributeError is swallowed by `print`, so CL-05 tasks never close. Every other step writes `t.completion_notes`, which is not a column (`smart_tasks/model.py:10-38`), so the note is silently lost. Matching on Arabic titles is dead because titles are English now. | Match on `task_type` (+ legacy `task_code`) only. Write the note to `t.notes`. |
| CL-12 | MAJOR | `service.py` (~35 blocks), `94`, `2183`, `2279` | Side effects are wrapped in `try/except Exception: log` (or `print`, or `pass` for the ACID date parse) with no rollback. A failed flush inside one leaves the session broken, and the final commit then fails with a 500. | Order: (1) validate, (2) write the business rows, (3) **one `db.commit()`**, (4) then run each side effect (tasks, notification, lifecycle, audit, settlement sync) through `errors.best_effort(db, fn, label)`. Do **not** call `best_effort` before the main commit: its rollback would discard the business write. ACID parse: a 400 on a bad date, not `pass`. |
| CL-13 | MAJOR | `lifecycle_board/service.py:375,480`; `service.py:127,1403,1992`; `repository.py:105,129,139,148` | `advance_lifecycle_step_service` commits internally, in the middle of every CS/CL service, before the main commit. The create/update/delete repository functions commit too, so one request makes several transactions. | Repository functions `flush` only. Services commit once (CL-12 order), with the lifecycle advance after the commit. |
| CL-14 | MAJOR | each CS-01..CL-04 service, "find or create" blocks | No stage guard (DOMAIN_RULES §1). Any step creates the record and runs out of order: assessment before the 46, inspection creating a record with a hard-coded "Red Channel". | This wave adds only the money guards: assess requires `declaration_46_no` (409), plus CL-05 and CL-06. The other steps stay permissive (Q4). |
| CL-15 | MAJOR | `service.py:2111-2115` | `generate_clearance_invoice_code` uses `count()+1` across all years. It collides with the unique `invoice_code`, which gives a 500, and it is unsafe under concurrency. | `next_yearly_code(db, ClearanceExpenseInvoice.invoice_code, "CLI", pad=4)` plus a retry on IntegrityError. Clearance codes: use `next_yearly_code(..., "CLR", pad=4)` too (same output). |
| CL-16 | MAJOR | `repository.py:142-150`, `service.py:2100` | Restore has no duplicate check, so a file can end up with two active records. Every "find or create" uses `.first()`. | 409 "يوجد بيان تخليص نشط آخر لنفس الملف." if another active record exists for the file. |
| CL-17 | MAJOR | router → service (`user="Kamal"/"System"/"Customs Broker"`), `118`, `2003` | Audit trail: services never get the real user. `created_by` / `updated_by` / `performed_by` are hard-coded, and `owner` defaults to "Kamal". | Router passes `current_user.username` to every mutating service. Default to the user, never a name. |
| CL-18 | MAJOR | `service.py:1174-1179` | No flow ever populates `estimated_duty_total` (only PUT and legacy pay-duty), so the BP-031 variance engine is always 0. | Not fixed this wave (needs a consultation link). Q5. |
| CL-19 | MAJOR | `service.py:1144-1148` | A CL-02 `actual_duty_total` override can differ from the itemised components without any trace. | Keep accepting it this wave. Pin the behaviour with a test (T-2). Q6 decides the tolerance rule. |
| CL-20 | MINOR | `model.py:36,48,142`, `service.py:241,685,1166` | Free-text English status/channel values and default customs office names (master data as text). `channel_type` is stored raw, although `CUSTOMS_CHANNEL` codes exist. | Backlog Q7 (needs a data migration). Keep `record.status` labels byte-identical: settlement filters on "Final Release Granted". |

### 1b. Backend `customs_clearance_quotations` (CCQ)

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| CCQ-01 | BLOCKER | `customs_clearance_quotations/router.py:36-184` | No `require_permission` on any route, the award route included. | GET: `quotations.view`. Mutating routes, price list included: `quotations.manage`. |
| CCQ-02 | BLOCKER | `repository.py:129-135` | `delete_quotation` hard-deletes, the awarded quote included. `rfq.awarded_quotation_id` and the awarded provider are left dangling. | Soft delete (`is_active=False`). Return 409 "لا يمكن حذف العرض المُرسى عليه." when `is_awarded`. |
| CCQ-03 | CRITICAL | `repository.py:44-50`, `service.py:118-223` | Soft-delete leak: `get_rfq_by_id` does not filter `is_active`, so a deleted RFQ can be updated, quoted or awarded. Award accepts an inactive quote. | Services load through `validators.get_or_404(..., active_only=True)`. Award requires `target_quote.is_active`. |
| CCQ-04 | CRITICAL | `schemas.py:102`, `service.py:118-125,197-223` | RFQ `status` is free text writable by PUT, so a client can set "Awarded" without awarding. Award has no state check and ignores `validity_date`. | Validate status against {Draft, Quotations Received, Awarded, Cancelled}. PUT cannot set Awarded. Award on a Cancelled RFQ returns 409. An expired quote returns 400 "عرض السعر منتهي الصلاحية.". |
| CCQ-05 | MAJOR | `service.py:52-58`, `73-82`, `147-154`, `172-179` | `lowest_clearance_cost = min(total_cost)` across quotes in different currencies. A client-sent `total_cost` is kept on create but recomputed on update. | Total is always the sum of the 5 components (the client value is ignored). Lowest cost: as today when all quotes share one currency, otherwise the minimum over EGP quotes (Q8). |
| CCQ-06 | MAJOR | `service.py:67-85`, `repository.py:62-75`, `validators.py:35-49` | Quotes nested in an RFQ create skip `validate_quotation_create` and `_normalize_quote_fields`. `provider_id`, `import_file_id`, `project_id` and `port_id` are never checked for an active FK. | Run the same validation and normalization for nested quotes. Use `require_active` for the FKs. |
| CCQ-07 | MAJOR | `repository.py:73,85,100,112,124,134,170,182,192`; `service.py:62,180` | Each repository write commits, then `recalculate_rfq_metrics` commits again. Update-quote makes up to 3 commits. | Repository functions flush. The service commits once. |
| CCQ-08 | MAJOR | `service.py:42-44` | `CRFQ-` code uses `count()+1`, which collides under concurrency. | A max-suffix lookup that keeps the `CRFQ-000001` format, plus a retry on IntegrityError. |
| CCQ-09 | MAJOR | `service.py:262-268`, `schemas.py:152-164` | Price-list update skips all validation. `effective_from > effective_to` is accepted. | Validate on create and update: 400 "تاريخ بداية السريان بعد تاريخ نهايته.". |
| CCQ-10 | MINOR | `model.py` (3 tables) | No `created_by` / `updated_by` (Audit Trail rule). | Next wave, with a migration (Q10). |

### 1c. Flutter (FE)

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FE-01 | CRITICAL | `customs_clearance/widgets/under_bond_release_dialog.dart:97-102,137-143` | Contract mismatch. Under-bond sends `quarantine_location` and omits the required `temporary_release_date`, so it always gets a 422. Lab posts to `/lab-inspection-result`, but the route is `/lab-test-result`, so it always gets a 404. It sends `is_lab_passed` instead of `lab_test_result` + `test_completion_date`. It also calls raw `dio` instead of the provider. | Send `{bond_guarantee_ref, temporary_release_date, customs_warehouse_location}` and `{lab_test_result: CONFORMING/NON_CONFORMING, lab_certificate_number, test_completion_date, lift_quarantine_lock, remarks}` through two new provider methods that refresh the list. |
| FE-02 | CRITICAL | `clearance_expenses_dialog.dart:144,154`; `final_duty_assessment_dialog.dart:114,444` | Hard-coded VAT 14%, WHT 3% and customs FX `48.50`, against DOMAIN_RULES §2. | Remove the auto-calculation: VAT and WHT become manual fields (Q2). The FX field starts empty, with a neutral hint. |
| FE-03 | MAJOR | `customs_clearance/models/customs_clearance_model.dart` | The model lacks `is_under_bond_release`, `bond_guarantee_ref`, `quarantine_lock`, `lab_test_result`, `lab_certificate_number`, `quarantine_lifted_date/by`. The screen guesses under-bond state with `status.contains('Bond')` (`customs_clearance_screen.dart:1136`). | Add the fields (tolerant parsing). Use `isUnderBondRelease`. |
| FE-04 | MAJOR | 13 hits in 10 files (`customs_broker_authorization_dialog.dart:425`, `clearance_expenses_dialog.dart:690,719`, `customs_duty_payment_dialog.dart:665,701`, `delivery_order_payment_dialog.dart:469`, `customs_clearance_quotations_screen.dart:271`, …) | `DropdownButtonFormField` / `DropdownButton` for customs office, expense category, currency, bank, payment method and status filter. | Replace with `SearchableDropdownField<T>`. |
| FE-05 | MAJOR | `customs_clearance_quotations_screen.dart:1039` | `selectedProviderId` falls back to `1`, so a quote can be attached to provider 1 silently. | No default: require a picked partner (form validator). |
| FE-06 | MAJOR | e.g. `final_duty_assessment_dialog.dart:240`, `under_bond_release_dialog.dart:115,160` | Errors show the raw `$e` (DioException) instead of the backend Arabic `detail`. | `ApiErrorText.of(context.l10n, e)` (`core/localization/api_error_text.dart:39`) in every SnackBar. |
| FE-07 | MAJOR | `customs_clearance_screen.dart:123`; `clearance_expenses_dialog.dart:116` | `catch (_) {}`, and invoice loading swallows the error. | Show a SnackBar through FE-06. |
| FE-08 | MAJOR | 19 files: ~545 `Colors.`, ~94 `Color(0x`, ~140 `ElevatedButton/TextButton/OutlinedButton` | Theme and button rule violations. | Map to `AppTheme.*` / `AppButton`, one commit per file. |
| FE-09 | MAJOR | ~690 Arabic literal lines in 19 files (screen 67, quotations screen 74, dialogs 32-64 each, export services 6-18) | Hard-coded UI text, not l10n. | Move to l10n keys (prefix `cc` / `ccq`) inside the phase06_07 marker block. Priority: SnackBars, validators, dialog titles. Export header text is a document: keep it, but read it from l10n when cheap. |
| FE-10 | MINOR | `customs_clearance_provider.dart:77-276` | After a mutation, `fetchRecords()` drops the screen filters. `createRecord`, `submitDutyPayment`, `completeRelease`, `softDeleteRecord` and `restoreRecord` do not invalidate `importFilesProvider` / `smartTasksProvider`. | Keep the last filter args in the notifier. Invalidate both providers after every mutation. |
| FE-11 | MINOR | `customs_clearance_quotations_screen.dart:1486-1550,1901-1910` | Demo quote texts with prices sit in production code (sample-fill buttons). | Keep (feature), but move them to a `sample_quotes.dart` constant inside the feature. |
| FE-12 | verify | 4 export services | Exports go through `FileSaveHelper.saveText`, not `exportAndSaveFile`. | Check that `saveText` (`core/services/file_save_helper.dart:435`) opens the Save-As dialog. If it does not, switch to `exportAndSaveFile`. |

---

## 2. Behaviour to keep identical (money outputs)

- CL-02: `computed_total = round(duty+vat+schedule+dev+services+wht+lab, 2)`. A `actual_duty_total > 0` override wins, rounded to 2. Variance: `round(actual-est, 2)`, `round(var/est*100, 2)`, only when `est > 0`.
- CL-03 variance: amount **unrounded** (l.1422), pct rounded to 2. Keep the asymmetry.
- Invoice: `amount_egp = round(fx*rate, 2)` only when `amount_egp <= 0` and `fx > 0`. `net = round(amount_egp + vat - wht, 2)`. Aggregates rounded to 2. `total_other` is floored at 0.
- Settlement snapshot: rows `"Clearance / <label_en>"` replace earlier clearance rows. `total_expenses_egp = round(sum(net), 2)`.
- Quotes: total = sum of 5 components. Lowest = min, fastest = min days. Draft → "Quotations Received" on the first quote.
- `record.status` labels, `imp_file` stage codes, progress floors 80/83/86/88/90/92/95/96, message codes (`CC_*`, `NA_*`).

## 3. Characterization tests (BE, first, green on current code)

New `tests/unit/test_phase06_07_characterization.py`:
1. T-1: CL-02 golden total with all 7 components, and with an override.
2. T-2: override ≠ components: both values stored as today (CL-19).
3. T-3: `PUT /{id}` after CL-02 drops dev fee + service fees. Mark xfail-on-fix: CL-03 flips it.
4. T-4: CL-03 variance on unrounded amount, pct to 2.
5. T-5: invoice FX path `round(fx*rate, 2)`, net formula, `vat_included=True` still adds VAT.
6. T-6: category split for each `CLEARANCE_EXPENSE_CATEGORY` code, legacy bilingual labels included. OTHER_CLEARANCE counts as clearance.
7. T-7: settlement snapshot rows after create and after delete invoice.
8. T-8: quote total/lowest/fastest, and the status flip.

Regression tests with the fixes: 403 for a viewer on each module's POST (seam `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)`). Release with a foreign `clearance_id` returns 400. Payment without assessment returns 409, partial payment 400, partial-paid release 400. PUT ignores `payment_status`, and a null money field gives no 500. Restore duplicate returns 409. CL-05 task closes. Lab "مطابق" is stored as `CONFORMING`. Quote delete is soft, and deleting the awarded quote returns 409. Award on a deleted RFQ returns 404. Invoice code has no collision across years. Update existing tests that pin old behaviour: `test_cl03_customs_duty_payment.py`, `test_cl04_customs_final_release.py`, `test_customs_clearance.py`, `test_customs_clearance_variance_and_extraction.py`, `test_customs_clearance_quotations.py`, `test_cl05_clearance_fees_invoices.py`.

FE tests: `frontend/test/features/customs_clearance/customs_clearance_model_test.dart` (new under-bond fields, numeric parsing), an under-bond/lab payload test on the provider, and `customs_clearance_quotation_model_test.dart` (toJson without a provider fallback).

## 4. Work split (disjoint files)

| Package | Owner | Files (exclusive) | Order |
|---|---|---|---|
| **BE** | backend-developer | `modules/customs_clearance/*`, `modules/customs_clearance_quotations/*`, new `tests/unit/test_phase06_07_characterization.py`, the 6 test files above | T-1..8 green, then CL-01/CCQ-01 (permissions), then CL-02..09 and CCQ-02..04, then the MAJORs |
| **FE** | flutter-developer | `frontend/lib/features/{customs_clearance,customs_clearance_quotations}/**`, `frontend/test/features/customs_clearance*/**`; l10n **only** between `// === review phase06_07 keys ...` and `// === end review phase06_07 keys ===` in `frontend/lib/core/localization/app_localizations{,_ar,_en}.dart` | Start now on FE-02..12. FE-01 lab payload uses the codes from contract change 5 |

Reviews: `customs-rules-reviewer` (CL-03/05/06/09, FE-02), `security-reviewer` (CL-01, CCQ-01, CL-02), `diff-reviewer` (all).

### Contract changes (explicit)
1. Every route of both modules returns 403 without the permission listed in CL-01 / CCQ-01.
2. `PUT /customs-clearance/{id}`: workflow and derived fields are no longer applied (ignored, not rejected).
3. `POST record-duty-payment` and `{id}/pay-duty`: 409 with no assessment, 400 when underpaid. `actual_duty_total` is no longer overwritten by the paid amount.
4. `POST issue-final-release` and `{id}/complete-release`: 400 on a foreign `clearance_id`, 400 when underpaid. A record is no longer auto-created.
5. `{id}/lab-test-result`: `lab_test_result` takes `CONFORMING` / `NON_CONFORMING` (legacy accepted) and the response returns the code. `{id}/under-bond-release` returns 409 if already under bond or released.
6. `POST /customs-clearance/invoices`: `exchange_rate` is optional. Non-EGP with no `amount_egp` and no rate returns 400.
7. Quotations: `DELETE /quotations/{id}` is soft, with 409 when awarded. RFQ PUT `status` is validated and cannot be "Awarded". Award returns 404/409/400 on a deleted RFQ, a cancelled RFQ or an expired quote. `total_cost` is always server-computed.

### Shared needs (devs do NOT edit `modules/common/*`, `modules/auth/seed_rbac.py`, `docs/*.json`)
- Register enum type `LAB_TEST_RESULT` = CONFORMING ("Conforming"), NON_CONFORMING ("Non-Conforming"), PENDING, NONE, with legacy map (conforming, approved, مطابق, مقبول → CONFORMING) in `enum_codes.py` + `docs/enum_codes.json`. Until then, BE validates with a schema `Literal` plus a local legacy map in `validators.py`.
- No new permission codes and no message codes needed (plain Arabic `HTTPException` details).
- Out-of-scope consumers, for the Phase 8-10 owners: `financial_settlement/service.py:1091` reads clearances without `is_active`. D/O fees are summed as EGP whatever `delivery_order_currency` is (`:1126`).

## 5. Risks
- **Live data**: existing records whose `actual_duty_total` was overwritten by a payment (CL-05) stay as they are. Before deploying, run a read-only count of records where `duty_paid_amount != total_duty_payable`, and report it. No auto-repair.
- Stricter payment and release guards will block users who today release after a partial payment. Announce this as a behaviour change.
- CL-03 changes `total_duty_payable` on the next PUT for records that have dev/service fees: the corrected value is higher. Settlement balances move.
- Removing the lifecycle advance from inside the main transaction changes the commit order. A failure is now logged and no longer blocks the business write. That is intended.

## 6. Open questions for the CTO (safe default in brackets)
- Q1: Allow partial duty payments? [No: 400 until paid ≥ assessed.]
- Q2: Does `vat_included=True` mean "VAT inside the amount" (extract it, do not add it)? [Keep the current add-on math. The FE stops the 14% auto-fill.]
- Q3: May a conforming lab result release the goods when the duty is unpaid? [No: lift the quarantine lock only.]
- Q4: Enforce stage order for CS-01..CL-01? [No: only the money guards this wave.]
- Q5: Source `estimated_duty_total` from the latest customs consultation at CL-02? [Not this wave.]
- Q6: Tolerance between an override total and the itemised sum? [Accept, pinned by a test. Decide the rule later.]
- Q7: T3 codes for clearance status, channel and inspection fields (needs a data migration)? [Next wave.]
- Q8: Mixed-currency quotes: lowest cost over EGP quotes only? [Yes.]
- Q9: Should duty payment need `financial_approval.approve` instead of `customs_clearance.update`? [`customs_clearance.update`.]
- Q10: Audit columns on the 3 quotation tables (migration)? [Next wave.]

## Not audited
Price-list repository; `docs/phase_06/tasks/*`, `docs/phase_07/tasks/*`; Flutter screens, tabs and export services beyond grep; existing test bodies (names only).
