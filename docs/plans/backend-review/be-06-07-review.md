# Phases 06-07 (Customs preparation + clearance, customs tariff engine): backend review

Status: 2026-10-05, static review only (grep / read). No pytest, no `import main`, no DB access, no code edits.
Scope: `modules/customs_clearance/*`, `modules/customs_clearance_quotations/*`, `modules/customs_tariff/*`.
Baseline: `docs/plans/phase-06-07-quality-plan.md` (CL-01..CL-20, CCQ-01..CCQ-10). Items verified as fixed in the current code are
not re-reported (see "Verified fixed" below). `customs_tariff` was **not** covered by any previous wave (`docs/plans/review-coverage.md:28`),
so all its findings are new.

| File | Lines | Depth |
|---|---|---|
| `modules/customs_clearance/service.py` | 1560 | Full |
| `modules/customs_clearance/{router,validators,repository,model,schemas}.py` | 254 / 207 / 96 / 209 / 467 | Full |
| `modules/customs_clearance_quotations/{router,service,repository,validators,schemas,model}.py` | 188 / 303 / 220 / 155 / 185 / 175 | Full |
| `modules/customs_tariff/{router,service,repository,schemas,validators,model}.py` | 315 / 1564 / 350 / 533 / 46 / 220 | Full |
| `modules/customs_tariff/nafeza_text_parser.py` | 278 | Lines 80-278 (rate / agreement extraction); header mappings skimmed |
| Consumers read for hand-off | `modules/currencies/service.py:153-194`, `modules/financial_settlement/model.py:47`, `modules/auth/seed_rbac.py:58-95` | Targeted |
| Flutter | grep of endpoint / field consumers only (`frontend/lib/features/customs_*`) | Grep |

Verified fixed since the 06-07 wave (not re-reported): CL-01 permissions, CL-02 foreign `clearance_id`, CL-03 one duty formula,
CL-04 PUT workflow fields + null guard, CL-05 payment guard (assessed + no partial), CL-06 release guard, CL-07 adapters, CL-08
under-bond state + lab codes, CL-09 invoice FX rate, CL-10 category code sets, CL-11 task closing, CL-12/13 single commit +
`best_effort` after commit, CL-15 invoice code, CL-16 restore duplicate, CL-17 acting user, CCQ-01..CCQ-09.
Still open from the wave: CL-14 (partly, see BE67-F08), CL-18/19 (CTO questions, not re-reported), CL-20 (see BE67-F25), CCQ-10 (BE67-F32).

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 6 (F01, F02, F04, F05, F06, F07) |
| CRITICAL | 7 (F03, F08, F09, F10, F11, F12, F13) |
| MAJOR | 19 (F14-F31 except F32, plus F33) |
| MINOR | 9 (F32, F34-F41) |

Top points:
1. **`customs_tariff` has no permission checks at all** (`router.py:42`, only `get_current_user`): any logged-in user can change duty / VAT rates,
   bulk-upload a tariff file, add preferential agreements, create fee codes and write a consultation estimate. `customs_tariff.view` / `.edit` exist in `seed_rbac.py:63-64`.
2. **Wrong duty from the tariff engine**: `fixed_rate` agreements (e.g. Mercosur 3%) are applied with `reduction_percentage` (stored 1.00) instead of
   `preferential_duty_rate`, so the line gets 1% instead of 3%; the multi-item engine also applies expired / superseded agreements (no date filter).
   Nafeza "extra fees" subtract schedule tax that no fee code contains.
3. **Fabricated money inputs**: the customs engine silently uses a hard-coded USD 48.50 (or 1.0) when no customs rate exists; `simulate-file`
   invents HS `8479.89.90`, values 1,000 / 10,000 USD, currency USD and `broker_id=1`, then saves the estimate into the consultation.
4. **Payment-guard bypass in clearance**: a record becomes "assessed" (and payable / releasable) through `POST /customs-clearance` or a `PUT` with duty
   components, because `assessment_status` defaults to "Assessed"; CL-02 and the declaration-46 guard are skipped. After the final release, CS-03 / CL-01 /
   CL-02 / CL-03 still run and regress `status` away from "Final Release Granted" (which settlement filters on).
5. **Approved landed cost silently changes**: recording / deleting a clearance invoice rewrites `total_expenses_egp` of a settlement that is already Approved / Closed.

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE67-F01 | BLOCKER | `customs_tariff/router.py:42` (all 25 routes) | Only `get_current_user`; no `require_permission`. Rate edits (`PUT /{id}`, `POST /hs/{hs}/verify`), `POST /upload-excel`, `POST /with-agreements`, `POST /agreements`, `POST /fee-codes`, delete / restore and `POST /simulate-file/{id}` (writes a consultation) are open to every user. | Reads + pure calculations: `customs_tariff.view`. Every write: `customs_tariff.edit`. `simulate-file`: `customs_clearance.update` (it writes the consultation; alias of `customs_consultation.manage`, `seed_rbac.py:260`). |
| BE67-F02 | BLOCKER | `customs_tariff/service.py:223-224`, `685-686`; `nafeza_text_parser.py:229-237` | For `reduction_type == "fixed_rate"` both engines use `reduction_percentage` as the rate. The parser stores fixed agreements as `preferential_duty_rate=3.00`, `reduction_percentage=1.00`, so a 3% Mercosur line is charged 1%. `evaluate_duty_by_origin...` (`:1249-1255`) uses `preferential_duty_rate` correctly, so the two screens disagree. | One helper `_agreement_duty_rate(standard_rate, agreement)` used by single, multi and origin-check: fixed_rate -> `preferential_duty_rate` (422 if NULL), full exemption -> 0, percentage -> `standard * (1 - pct)` clamped at >= 0. |
| BE67-F03 | CRITICAL | `customs_tariff/schemas.py:193`; `service.py:222`, `683` | `reduction_percentage` is a fraction (1.00 = 100%, the FE sends `pct/100`, `add_agreement_dialog.dart:111`) but the schema allows `le=100`. A direct API value 50 gives rate `30 * (1-50) = -1470%` and a negative duty; no clamp in either engine. | `Field(ge=0, le=1)`; the helper from F02 clamps the rate at 0; a stored value > 1 makes the line 422 `CT_AGREEMENT_DATA_INVALID` (no guessing). |
| BE67-F04 | BLOCKER | `customs_tariff/service.py:596-601`, `1404-1407`; `currencies/service.py:170-189` | When no customs rate is registered, `_get_rate_to_egp` returns a hard-coded fallback (USD 48.50, EUR 52.80 ...) or 1.0 with `rate_id=None`; the engine and the simulation use it silently. | In `customs_tariff` only: if no explicit `exchange_rate` and `rate_id is None` and currency != EGP -> 422 `CT_CUSTOMS_RATE_MISSING` ("لا يوجد سعر صرف جمركي مسجل للعملة {currency} بتاريخ {date}."). The currency-service fallback itself is a shared need (out of scope). |
| BE67-F05 | BLOCKER | `customs_tariff/service.py:1327-1398`, `1465-1486` | `simulate-file` fabricates: HS `8479.89.90` when a line has none, value 1,000 USD for a zero line, 10,000 USD when the file has no lines, currency "USD", qty 1; a new consultation gets `broker_id = import_file.broker_id or 1` and "Approved Customs Broker". The fabricated estimate is saved to `estimated_duties_egp`. | No invented values: a line without HS / value is skipped and reported in a new `warnings[]`; no lines -> 422 `CT_SIMULATION_NO_LINES`; no consultation is created without a real broker (return `consultation_id=None` + warning). |
| BE67-F06 | BLOCKER | `customs_clearance/service.py:1379-1407`, `1503`, `1558`; `financial_settlement/model.py:47` | CL-05 invoice create / delete always rewrites the settlement snapshot (`expense_invoices`, `total_expenses_egp`), also when the settlement is `Approved` / `Closed`. An approved landed cost changes without trace. | Before the write: if the file's active settlement status is in (`Approved`, `Closed`) -> 409 `CC_SETTLEMENT_LOCKED` ("لا يمكن تعديل فواتير التخليص بعد اعتماد تسوية تكلفة الوصول."). |
| BE67-F07 | BLOCKER | `customs_clearance/validators.py:69-72`; `service.py:403-404`, `482-486`; `schemas.py:37-51`, `339-340` | `is_assessed` = `assessment_status == "Assessed"` (column default) AND total > 0. `POST /customs-clearance` with any duty component (or a PUT of components / `nafeza_claim_number` before CL-02) sets `actual_duty_total`, so the record counts as assessed: CL-03 payment and CL-04 release run without CL-02 and without declaration 46 (the CL-14 money guard). Create / Update money fields also accept negatives. | `is_assessed` also requires a non-empty `nafeza_claim_number` (only CL-02 writes it, `min_length=3`). Remove `nafeza_claim_number`, `nafeza_claim_date`, `assessment_status` from Create/Update (ignored). `ge=0` on every money field of Create/Update. No migration. |
| BE67-F08 | CRITICAL | `customs_clearance/service.py:765`, `856`, `958-959`, `1030-1031`, `1132-1160`; `validators.py:161-162` | No guard after the final release / payment (still open from CL-14 for these cases): CS-03 sets status "Under Customs Clearance", CL-01 "Inspection & Sampling Recorded", CL-02 re-assesses (changes `actual_duty_total`, read by landed cost) while `payment_status` stays paid, CL-03 can be paid twice (overwrites receipt), CL-04 can be re-issued (overwrites permit; the ACID check is skipped when already released). Settlement filters on "Final Release Granted". | 409 `CC_ALREADY_RELEASED` for CS-03, CL-01, CL-02, CL-03, CL-04 and under-bond when the record status is "Final Release Granted" or `is_customs_released`. 409 `CC_ALREADY_PAID` for CL-02 and CL-03 when `is_duty_fully_paid(record)`. |
| BE67-F09 | CRITICAL | `customs_tariff/service.py:673-675`; `repository.py:214-226` | Multi-item engine looks up agreements without `on_date`: expired agreements and, after a re-version (`repository.py:269-274` closes old rows, adds new ones), both old and new rows match; `[0]` is arbitrary. Lookup is exact `hs_code ==`, so `8536410000` misses an agreement stored as `8536.41.00` (tariff lookup normalizes dots, agreements do not). Origin match is `ILIKE %XX%` not an exact list member. | Pass `on_date`; match hs_code on the dot-free form (`func.replace(hs_code,'.','')`); split `origin_countries` and match exact codes; order by `effective_from desc` and take the newest. Same in single estimate (`:213`). |
| BE67-F10 | CRITICAL | `customs_tariff/service.py:797-808`, `523-534` | `extra_nafeza_fees = fee_codes_grand_total - (duty + vat + service fee + schedule tax)`. Reference fee codes only exist for duty / service / vat (`reference_map`), so schedule tax is subtracted from flat + derived fees and floored at 0. Example: flat 500 + derived 70, schedule tax 2,000 -> extras 0 instead of 570. With no reference codes seeded, all flat fees vanish. | `extra_nafeza_fees = sum(fee codes whose calculation_type in ("flat","derived"))`, i.e. never subtract taxes; keep `additional_fees_egp` override. |
| BE67-F11 | CRITICAL | `customs_tariff/repository.py:96-135`; `service.py:146-159` | `verify` with a rate change twice on the same day inserts a second row with the same `(hs_code, effective_from)` -> `uq_customs_tariff_hs_code_eff_from` IntegrityError -> 500. The new version does not copy `customs_service_fee_rate` (resets to the 1.00 default) and `customs_service_fee_rate` is not in `rate_fields`, so changing it alone never versions. | Same-day: update the current version in place. Copy `customs_service_fee_rate`, `requires_*`, `customs_category`; add `customs_service_fee_rate` to the rate fields. |
| BE67-F12 | CRITICAL | `customs_tariff/service.py:95-109`, `286-397`, `436-444` | `PUT /{id}` and `upload-excel` overwrite rates in place (no history), so estimates for past dates use the new rate. Upload: a missing / unparseable rate becomes 0 (`_parse_decimal` swallows errors), missing description -> "HS Code X", category -> GENERAL_GOODS, `requires_*` default true, the service-fee column is never mapped (always 1.00). | A rate change through PUT or upload goes through the versioning path (F11). Upload: duty and VAT columns required per row (row error otherwise), unparseable -> row error, description required, map `customs_service_fee_rate`. |
| BE67-F13 | CRITICAL | `customs_tariff/service.py:1330-1351`, `1426-1430` | Simulation: all lines are valued in the currency of the **last** PO (EUR PO lines converted at the USD rate); a freight quote in a third currency is converted with the invoice rate; origin is cut to 2 letters (`"China"` -> `"CH"` = Switzerland, so a wrong or missing agreement). | One rate per PO currency (per-line `value_fc` converted with its own customs rate, or 422 on mixed currencies, Q5); freight converted with the rate of `q_curr`; origin through the countries master (ISO-2) or None. |
| BE67-F14 | MAJOR | `customs_tariff/router.py:133`, `208`, `230` | `GET /fee-codes` and `GET /export-template` are declared after `GET /{tariff_id}` and are matched by it -> 422 (int parse). Unreachable. | Declare them before `/{tariff_id}` (or `/{tariff_id:int}`). |
| BE67-F15 | MAJOR | `customs_tariff/repository.py:80,91,133,145,209,307,345`; `service.py:389` | Every repository write commits. Bulk upload commits per row and catches `Exception` without rollback: after one DB error the session is in failed state and every later row also fails; the file is half imported. | Repository flushes only; the service commits once. Upload: `db.begin_nested()` per row, rollback the savepoint on error, one commit at the end. |
| BE67-F16 | MAJOR | `customs_tariff/router.py:197-205` | Upload has no size limit, no extension / content-type check, whole file read in memory; `.xlsx` bytes are decoded as latin-1. | Max 5 MB (413), accept `.csv` only (400 "صيغة الملف غير مدعومة، يرجى رفع ملف CSV."). |
| BE67-F17 | MAJOR | `customs_tariff/repository.py:154-196`, `104-105`, `138-147` | `DELETE /{id}` sets `is_active=False`, the same flag that marks an archived version, so `get_active_tariff_on_date` (which must ignore `is_active` for history) still prices goods with a deleted tariff. | Migration: `deleted_at`, `deleted_by` on `customs_tariffs`; delete/restore use them; date lookup filters `deleted_at IS NULL`. |
| BE67-F18 | MAJOR | `customs_tariff/model.py:9-219`; `service.py:1095`; `schemas.py:48,304`; `repository.py:125` | No `created_by` / `updated_by` on tariffs, agreements, fee codes; `verified_by` comes from the body (default "System Admin"); audit `performed_by="System Admin"`. Rate changes cannot be traced to a user. | Migration: `created_by`, `updated_by` (nullable, no backfill needed) on the 3 tables; router passes `current_user.username`; `verified_by` = token user (body value ignored). |
| BE67-F19 | MAJOR | `customs_tariff/service.py:649`, `205`, `653`; `schemas.py:419-423` | `vat_rate_override or tariff.vat_rate`: an override of 0 is ignored; no bounds. Deemed insurance / freight rates are hard-coded defaults (2.5% / 2%) and client-overridable without bounds. NULL service-fee rate falls back to a hard-coded 1.00. | `is not None`, `ge=0, le=100`; deemed rates `ge=0, le=0.1` (source Q3); NULL service-fee rate -> 422 `CT_TARIFF_RATE_MISSING`. |
| BE67-F20 | MAJOR | `customs_tariff/nafeza_text_parser.py:82-95`, `181`, `187`, `229-231` | Parser fabricates: VAT 14% when not found, duty 0 when not found, service fee 1.00, category guessed from Arabic words; an agreement line with no percentage and no "يعفى" becomes `percentage_of_duty` 1.00 (full exemption). Saved as-is by `/with-agreements`. | Missing rates are returned as None with `missing_fields[]` (the user must fill them before save); an unrecognized agreement line is returned in `unparsed_lines[]`, not as an agreement. |
| BE67-F21 | MAJOR | `customs_tariff/service.py:404-433`, `661-670` | `EXEMPTIONS_REGISTRY` is master data hard-coded in code (legal basis, 50%). `is_exemption_conditions_met=True` forces duty 0 even when the matched agreement is only a 10% reduction. | Q2. Default this wave: `is_exemption_conditions_met=True` applies the matched agreement's rate (F02 helper); 0 only when the agreement is a full exemption or no agreement exists and the user confirmed. Registry moves to a table next wave. |
| BE67-F22 | MAJOR | `customs_tariff/router.py:45-98`; `repository.py:69-74` | `limit` is optional: without it the full HS table (thousands of rows) is returned; no total; ORM objects cached in-process. | Default `limit=200` when absent, max 5000; add `X-Total-Count` header (additive). |
| BE67-F23 | MAJOR | `customs_tariff/service.py:862-865`; `schemas.py:151-163` | Duplicate fee `code` -> IntegrityError 500; `calculation_type`, `reference_source` free text (an unknown value yields 0 silently). | 409 `CT_FEE_CODE_DUPLICATE`; `Literal["flat","reference","derived"]`, `Literal["duty_amount","service_fee_amount","vat_amount"]`; derived requires base codes + rate. |
| BE67-F24 | MAJOR | `customs_clearance/service.py:1291-1307` | Lab CONFORMING + paid + can_release sets `is_customs_released=True` but no `customs_released_at`, no permit, no ACID check, no TR-01/TR-02 tasks, no lifecycle STEP_17 advance; `quarantine_lifted_by` is a hard-coded "Customs Laboratory Authority". | Release through the CL-04 write (`_issue_release`) with the lab certificate as permit reference, or only lift the lock and set next action "issue release" (Q4). `quarantine_lifted_by = user`. |
| BE67-F25 | MAJOR | `customs_clearance/service.py:820`, `827`, `746-747`, `825`, `837`, `546-548`, `585`; `model.py:36,48,53,65`; `schemas.py:14,22,27,36,102-103,116` | Invented values (still open from CL-20 / CL-14): random sampling record no `SMP-YYYY-NNNN-rnd`, inspection result defaults "Conforming", channel "Red Channel", office "Alexandria Port Customs", yard "Joint Inspection Yard", mandate letter broker license "رخصة معتمدة", `customs_exchange_rate` column default 1.0 on every new record. | Sampling record no required when `is_sample_drawn`; `inspection_result`, `channel_type`, `customs_office_name` required (no default); mandate letter skipped with a warning when the broker has no license; model `customs_exchange_rate` default None (column already nullable, no migration). |
| BE67-F26 | MAJOR | `customs_clearance/schemas.py:307-313`, `343-348`; `service.py:478-481` | PUT sets `broker_id` / `shipping_agent_id` without an active-FK check and lets `broker_name` / `shipping_agent_name` diverge from the provider master. | `require_active(ExternalServiceProvider)` and take the names from the provider; names are not accepted alone. |
| BE67-F27 | MAJOR | `customs_clearance/schemas.py:225-245`; `service.py:1435-1492` | CL-05 invoice: `provider_id` not checked, `provider_name` / `currency` / `payment_status` / `allocation_rule` free text; no duplicate check (same file + provider + invoice number is booked twice into landed cost); `wht_amount > amount + vat` gives a negative net. | Active-FK + master name when `provider_id` is sent; `enum_codes.normalize_currency`; Literal sets for status and rule; 409 `CC_INVOICE_DUPLICATE`; 400 when net < 0. |
| BE67-F28 | MAJOR | `customs_clearance/service.py:1374-1375` | Recording / deleting any CL-05 invoice raises progress to 96% and sets next action "book inland transport" even before the customs release. | Only when `imp_file.is_customs_released`. |
| BE67-F29 | MAJOR | `customs_clearance/schemas.py:270-282` | `ClearanceExpenseInvoiceResponse` is not a `LegacyRowTolerantModel`: a legacy NULL in `created_by`, `updated_by`, `payment_status`, `allocation_rule`, `is_verified` 500s the whole `/invoices/by-file` summary. | Base it on `LegacyRowTolerantModel` (keep `@read_model`); `exchange_rate`, `amount_fx` stay `Optional[float]`. |
| BE67-F30 | MAJOR | `customs_clearance/service.py:504-531`, `1239-1319` | Delete / restore / under-bond / lab result write no audit log; delete is allowed on a paid or released record and leaves the ImportFile `customs_duty_*` / `is_customs_released` flags. | Audit through `_follow_up(... _audit ...)`; 409 `CC_DELETE_NOT_ALLOWED` when paid or released. |
| BE67-F31 | MAJOR | `customs_clearance_quotations/service.py:160-237`; `validators.py:61-71` | After award: the awarded quote's prices can still be edited, quotes can be added, the RFQ PUT can move "Awarded" -> Draft / Cancelled while `awarded_*` stays set, and a second award silently switches the winner. | Awarded RFQ: 409 on quote add / edit / delete and on PUT status change; re-award only through an explicit `reaward=true` flag (Q6). Cancelled RFQ: 409 on quote add / edit. |
| BE67-F32 | MINOR | `customs_clearance_quotations/model.py:14-174` | Still open from CCQ-10: no `created_by` / `updated_by` on the 3 tables; services never receive the user. | Migration + router passes `current_user.username`. |
| BE67-F33 | MAJOR | `customs_clearance_quotations/service.py:98-104`, `269-276`; `schemas.py:16-18`, `144-147` | `provider_name` is client free text next to `provider_id` (award copies it to the RFQ); price-list `provider_id` is never checked active. | Name taken from `ExternalServiceProvider.partner_name`; `validate_quotation_provider` on price-list create / update. |
| BE67-F34 | MINOR | `customs_clearance/repository.py:51-74`; `router.py:59-68` | Clearance list is unbounded (no skip / limit / total). | Optional `skip` / `limit` (default unbounded to keep contract) + `X-Total-Count`. |
| BE67-F35 | MINOR | `customs_clearance_quotations/schemas.py:110-137`; `repository.py:170-187` | RFQ response includes soft-deleted quotes; price list unbounded; award `notes` is accepted and dropped; awarded RFQ can be deleted. | Filter `is_active` quotes in the response; 409 delete of an awarded RFQ; drop or store notes (Q6). |
| BE67-F36 | MINOR | `customs_tariff/service.py:84`, `91`, `100`; `validators.py:21-44`; `router.py:74,145` | User-facing errors in English ("Customs Tariff record not found", ValueError text). | Arabic `HTTPException` details. |
| BE67-F37 | MINOR | `customs_tariff/service.py:1139-1149` | History: agreements are fetched per version without a date filter (each version shows all agreements, N+1); NULL VAT shown as 14.0, NULL service fee as 1.0. | Filter agreements by the version's period; show None. |
| BE67-F38 | MINOR | `customs_clearance/service.py:1365-1367` | Record `total_clearance_expenses_egp` = all invoices, while `total_port_expenses_egp` / `total_handling_expenses_egp` are subsets: summing the three double counts. | Document in the response schema description (no value change; settlement reads the ImportFile total). |
| BE67-F39 | MINOR | `customs_clearance/service.py:1445-1446` | Currency EGP with an `exchange_rate` != 1 and `amount_egp=0` multiplies the amount. | Ignore the rate for EGP. |
| BE67-F40 | MINOR | `customs_clearance/schemas.py:250-268`; `validators.py:131-136`; `customs_tariff/validators.py:27` | Dead code: `ClearanceExpenseInvoiceUpdate`, `validate_release_permit`, `validate_tariff_exists`. | Remove. |
| BE67-F41 | MINOR | `customs_tariff/schemas.py:409`, `router.py:213-218` | Multi-item request defaults currency to "USD"; template CSV carries sample rates. | `currency` required; template keeps one clearly fake row with empty rates. |

## 3. Tasks

Each task is standalone. Shared rules for every task: read `.claude/rules/backend.md` and `.agents/rules/DOMAIN_RULES.md` §2 first;
every `pytest` / TestClient run uses a scratch `DATABASE_PATH`; coded errors (`detail={"code","message",...}`) must be registered in
`modules/common/system_messages.py` + `docs/system_message_codes.json` in the same change, or listed in `docs/plans/review-shared-needs.md`
if those files are not yours (`tests/unit/test_review_wave_codes.py` checks this). Read results from `--junitxml` and the exit code.

### BE67-T01: Permissions on customs_tariff + route order
- Severity: BLOCKER (F01) + MAJOR (F14)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. Every route returns 403 without the permission. `GET /fee-codes` and `GET /export-template` start working (were 422).
  Flutter: `frontend/lib/features/customs_tariff/providers/customs_tariff_provider.dart` (all calls), `customs_clearance` / consultation screens that call `simulate-file`.
- Files to change: `modules/customs_tariff/router.py`, new `tests/unit/test_customs_tariff_permissions.py`
- Steps:
  1. Import `require_permission` from `modules.auth.permissions`. Define `can_view = Depends(require_permission("customs_tariff.view"))`,
     `can_edit = Depends(require_permission("customs_tariff.edit"))`, `can_simulate = Depends(require_permission("customs_clearance.update"))`.
  2. Keep the router-level `get_current_user` dependency. Add `dependencies=[can_view]` to: `GET ""`, `GET "/"`, `GET /hs/{hs_code}`, `GET /{tariff_id}`,
     `GET /hs/{hs_code}/agreements`, `GET /fee-codes`, `GET /export-template`, `GET /history/{hs_code}`, `POST /estimate`, `POST /estimate-multi`,
     `POST /parse-text`, `POST /check-duty-for-origin`.
  3. `dependencies=[can_edit]` on: `POST ""`, `PUT /{tariff_id}`, `DELETE /{tariff_id}`, `PATCH /{tariff_id}/restore`, `POST /hs/{hs_code}/verify`,
     `POST /agreements`, `POST /upload-excel`, `POST /fee-codes`, `POST /with-agreements`.
  4. `dependencies=[can_simulate]` on `POST /simulate-file/{import_file_id}`.
  5. Move the `GET /export-template`, `GET /fee-codes`, `POST /fee-codes` routes (and their imports) above `@customs_tariff_router.get("/{tariff_id}")`.
- Acceptance criteria: a user without `customs_tariff.edit` gets 403 on every write; `GET /api/v1/customs-tariff/fee-codes` returns 200 with a list.
- Tests to add: `tests/unit/test_customs_tariff_permissions.py`: with `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)`
  and a viewer user (only `customs_tariff.view`): `PUT /api/v1/customs-tariff/1` -> 403, `POST /upload-excel` -> 403, `GET ""` -> 200;
  `GET /api/v1/customs-tariff/fee-codes` -> 200 (not 422); a user without `customs_clearance.update` -> 403 on `simulate-file`.
- Out of scope: role catalog changes in `seed_rbac.py`; caching.

### BE67-T02: One preferential-agreement rate helper (fixed rate, scale, date, hs format)
- Severity: BLOCKER (F02) + CRITICAL (F03, F09)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. `POST /agreements` and `POST /with-agreements`: `reduction_percentage` must be 0..1 (422 above 1). Estimate results change for
  fixed-rate agreements and for expired agreements (intended). Flutter: `customs_tariff/widgets/add_agreement_dialog.dart` already sends 0..1 (no change).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/repository.py`, `modules/customs_tariff/schemas.py`, new `tests/unit/test_customs_tariff_agreement_rate.py`
- Steps:
  1. `schemas.py:193`: `reduction_percentage: Decimal = Field(default=Decimal("1.00"), ge=0, le=1)`.
  2. `repository.get_agreements_by_hs_code(db, hs_code, origin_country=None, on_date=None)`: match `func.replace(PreferentialAgreement.hs_code, ".", "") == hs_code.strip().replace(".", "")`;
     drop the SQL `ILIKE` origin filter, filter in Python: `origin in [c.strip().upper() for c in ag.origin_countries.split(",")]`;
     order by `effective_from desc, agreement_id desc`.
  3. In `service.py` add `_agreement_duty_rate(standard_rate: Decimal, ag) -> Decimal`:
     `full_duty_exemption` -> 0; `fixed_rate` -> `Decimal(str(ag.preferential_duty_rate))`, raise 422 `CT_AGREEMENT_DATA_INVALID` if it is None;
     `percentage_of_duty` -> if `reduction_percentage > 1` raise 422 `CT_AGREEMENT_DATA_INVALID`, else `max(0, _round(standard * (1 - pct)))`; unknown type -> 422.
  4. Use the helper in `estimate_customs_duty_service` (`:211-224`), `estimate_multi_item_customs_duty_service` (`:671-687`, and pass `on_date=on_date`)
     and `evaluate_duty_by_origin_and_document_service` (`:1249-1255`). Take the first (newest) agreement.
- Acceptance criteria: a Mercosur fixed agreement 3% on a 30% HS code gives duty rate 3.00 in all three endpoints; an agreement with `effective_to` before the estimate date is ignored; `8536410000` finds an agreement stored as `8536.41.00`.
- Tests to add (`tests/unit/test_customs_tariff_agreement_rate.py`):
  - Tariff `8536.41.00` duty 30, VAT 14, other rates 0, service fee 1. Agreement fixed_rate, `preferential_duty_rate=3.00`, `reduction_percentage=1.00`, origin `BR`.
    `POST /estimate` CIF 100,000, origin BR -> `import_duty_amount == 3000.00`, `vat_amount == round((100000+3000)*0.14,2) == 14420.00`.
  - Same via `estimate-multi` (one line, `value_fc=100000`, `exchange_rate=1`, `has_*_document=True`, freight/insurance 0, `cif_declared_total_egp=100000`) -> `duty_egp == 3000.00`.
  - percentage agreement 0.10 on duty 40 -> rate 36.00; `reduction_percentage=50` on create -> 422.
  - Expired agreement (`effective_to = estimate_date - 1 day`) -> duty at the full rate.
  - hs `8536410000` in the request finds the dotted agreement.
- Out of scope: `is_exemption_conditions_met` semantics (T07), exemptions registry.

### BE67-T03: No fallback FX in the customs engine
- Severity: BLOCKER (F04)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. `POST /estimate-multi` and `POST /simulate-file/{id}` return 422 `CT_CUSTOMS_RATE_MISSING` when no customs rate is registered and no `exchange_rate` is sent.
  Flutter: `customs_tariff_provider.dart:181,198` must show the Arabic `detail.message` (ApiErrorText).
- Files to change: `modules/customs_tariff/service.py`, `tests/unit/test_customs_engine.py` (add cases)
- Steps:
  1. Add `_customs_rate(db, currency, on_date) -> (Decimal, date, int)`: EGP -> `(1, on_date, None)`; else call `CurrencyService(db)._get_rate_to_egp(currency, rate_type="customs", as_of_date=on_date)`;
     if the returned `rate_id is None` or the rate <= 0 -> `HTTPException(422, detail={"code":"CT_CUSTOMS_RATE_MISSING","message":"لا يوجد سعر صرف جمركي مسجل للعملة {currency} بتاريخ {on_date}.","currency":currency})`.
  2. Use it at `service.py:596-601` and `:1404-1407`.
- Acceptance criteria: with an empty currency-rates table, `estimate-multi` with `currency="USD"` and no `exchange_rate` returns 422 (today it silently uses 48.50).
- Tests to add: in `tests/unit/test_customs_engine.py`: no USD rate rows -> 422 code `CT_CUSTOMS_RATE_MISSING`; explicit `exchange_rate=50` -> 200 and `exchange_rate == 50`; a USD customs rate row 49.10 dated before the estimate date -> 200 and `exchange_rate_id` not None.
- Out of scope: removing `fallback_rates` in `modules/currencies/service.py` (add to `docs/plans/review-shared-needs.md` as a shared need).

### BE67-T04: simulate-file without invented data
- Severity: BLOCKER (F05) + CRITICAL (F13)
- Depends on: BE67-T03
- Schema/migration needed: no
- API contract change: yes. `ImportFileCustomsSimulationResponse` gains `warnings: List[str] = []` (message codes) and `skipped_lines: List[dict] = []` (additive).
  422 `CT_SIMULATION_NO_LINES` when no usable line exists. `consultation_id` is None when no consultation exists and no real broker is linked to the file.
  Flutter: `customs_tariff_provider.dart:198` and the caller screen of the simulation (grep `simulateFile` in `frontend/lib`).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_pl07_customs_duty_simulation.py`
- Steps:
  1. In `simulate_import_file_customs_duty_service` remove every literal default: `"8479.89.90"`, `Decimal("1000.00")`, `Decimal("10000.00")`/`10000.0`, `currency = "USD"`, `item.quantity or 1.0`.
  2. A PO line with no HS (line tariff, then `import_file.hs_code`) or value <= 0 is appended to `skipped_lines` (`{"po_number","item_code","reason":"NO_HS"|"NO_VALUE"}`), not estimated.
  3. Currency per PO: convert each line to EGP with that PO currency's customs rate (T03 helper) and pass the engine `currency="EGP"`, `exchange_rate=1`, `value_fc` = EGP value. Invoices fallback: same per invoice currency; skip invoices without currency.
  4. No lines left -> 422 `CT_SIMULATION_NO_LINES` ("لا توجد أصناف بها بند جمركي وقيمة لاحتساب الرسوم التقديرية.").
  5. Freight from the awarded quote: EGP as-is, otherwise convert with the customs rate of `q_curr` (not the invoice rate).
  6. Origin: resolve through the countries master (look up the PO / line `country_id` or ISO code); if it is not an ISO-2 code, pass None (never `origin[:2]`).
  7. Consultation: update an existing active one; create one only when `import_file.broker_id` is set (use that broker's id and `partner_name`); otherwise append warning `CT_SIMULATION_NO_BROKER` and leave `consultation_id=None`.
- Acceptance criteria: a file whose PO line has no HS code is not priced at `8479.89.90`; a file with a USD PO (100 x 10 USD) and an EUR PO (50 x 20 EUR), USD 50, EUR 55: CIF lines in EGP are 50,000 and 55,000.
- Tests to add (`tests/unit/test_pl07_customs_duty_simulation.py`):
  - Money: customs rates USD 50, EUR 55 on the estimate date; both HS codes duty 10%, VAT 14%, schedule / dev / import fee 0, service fee 1;
    request `freight_egp=0`, `insurance_egp=0` (deemed path: insurance 2.5%, freight 2% of FOB EGP 105,000 -> 2,625 + 2,100 = 4,725, allocated by value share).
    Expected line 1 (USD 1,000 -> 50,000 EGP, share 50,000/105,000): `cif_value_egp == round(50000 + 4725*50000/105000, 2) == 52250.00`, `duty_egp == 5225.00`;
    line 2 (EUR 1,000 -> 55,000 EGP): `cif_value_egp == 57475.00`, `duty_egp == 5747.50`. Today all lines are converted at one rate.
  - A line without HS -> listed in `skipped_lines`, not priced at `8479.89.90`; no usable lines -> 422 `CT_SIMULATION_NO_LINES`; no consultation and no `import_file.broker_id` -> `consultation_id is None` and warning `CT_SIMULATION_NO_BROKER`.
- Out of scope: the consultation module's own logic.

### BE67-T05: Lock clearance invoices once the landed-cost settlement is approved
- Severity: BLOCKER (F06)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. `POST /customs-clearance/invoices` and `DELETE /customs-clearance/invoices/{id}` return 409 `CC_SETTLEMENT_LOCKED` when the file's active settlement status is `Approved` or `Closed`.
  Flutter: `frontend/lib/features/customs_clearance/widgets/clearance_expenses_dialog.dart` (show `detail.message`).
- Files to change: `modules/customs_clearance/validators.py`, `modules/customs_clearance/service.py`, `tests/unit/test_cl05_clearance_fees_invoices.py`
- Steps:
  1. `validators.py`: `SETTLEMENT_LOCKED_STATUSES = ("Approved", "Closed")` and `validate_settlement_open(db, import_file_id)` that loads the active `LandedCostSettlementRecord` (lazy import from `modules.financial_settlement.model`) and raises 409 `CC_SETTLEMENT_LOCKED` ("لا يمكن تعديل فواتير التخليص بعد اعتماد تسوية تكلفة الوصول.") when its status is in the set.
  2. Call it at the start of `record_clearance_invoice_service` (after `_require_import_file`) and `delete_clearance_invoice_service` (after loading the invoice).
- Acceptance criteria: with an Approved settlement, create / delete invoice -> 409 and the settlement `total_expenses_egp` is unchanged.
- Tests to add: settlement `status="Approved"`, `total_expenses_egp=1000.0`; POST invoice 500 EGP -> 409, settlement still 1000.0; settlement `status="Calculated"` -> 201 and total becomes 1500.0 (when the existing rows sum to 1000 with no clearance rows).
- Out of scope: settlement module rules, re-opening an approved settlement.

### BE67-T06: "Assessed" means CL-02 really ran; no negative money on create / PUT
- Severity: BLOCKER (F07)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. `POST /customs-clearance` and `PUT /customs-clearance/{id}`: `nafeza_claim_number`, `nafeza_claim_date`, `assessment_status` are ignored; money fields reject negatives (422).
  Payment (`record-duty-payment`, `{id}/pay-duty`) returns 409 `CC_DUTY_NOT_ASSESSED` until CL-02 ran. Flutter: `customs_clearance_provider.dart` (create / update payloads), `customs_duty_payment_dialog.dart` (message).
- Files to change: `modules/customs_clearance/validators.py`, `modules/customs_clearance/schemas.py`, `tests/unit/test_cl03_customs_duty_payment.py`, `tests/unit/test_customs_clearance.py`
- Steps:
  1. `validators.is_assessed`: add `and bool((record.nafeza_claim_number or "").strip())`.
  2. `schemas.CustomsClearanceCreate`: delete `nafeza_claim_number`, `nafeza_claim_date`, `assessment_status` (Pydantic ignores extra keys). `CustomsClearanceUpdate`: delete `nafeza_claim_number`, `nafeza_claim_date`.
  3. Add `ge=0` (`Field(0.0, ge=0)` / `Field(None, ge=0)`) to every money field of Create and Update: `cif_base_amount`, the 7 duty components, `estimated_duty_total`, `actual_duty_total` (create), `delivery_order_fees`; `customs_exchange_rate` `gt=0`.
- Acceptance criteria: `POST /customs-clearance` with `import_duty_amount=1000`, then `POST /record-duty-payment` with 1000 -> 409 `CC_DUTY_NOT_ASSESSED`; after CL-02 the payment works.
- Tests to add: create with components 1000 + VAT 140 -> `total_duty_payable == 1140.0`, payment -> 409; CL-02 claim `NFZ-123`, components 1000/140 -> payment 1140 -> 200; `PUT` with `nafeza_claim_number` is ignored (record still unassessed); `PUT vat_amount=-5` -> 422.
- Out of scope: the status / stage order of CS-01..CL-01 (Q4 of the 06-07 plan).

### BE67-T07: Guards after payment and final release
- Severity: CRITICAL (F08)
- Depends on: BE67-T06
- Schema/migration needed: no
- API contract change: yes. 409 `CC_ALREADY_RELEASED` from `register-declaration-46`, `record-inspection-sampling`, `assess-final-duties`, `record-duty-payment`, `{id}/pay-duty`,
  `issue-final-release`, `{id}/complete-release`, `{id}/under-bond-release` once the record is finally released; 409 `CC_ALREADY_PAID` from `assess-final-duties`, `record-duty-payment`, `{id}/pay-duty` once fully paid.
  Flutter: the dialogs of these steps under `frontend/lib/features/customs_clearance/widgets/` show `detail.message`; buttons can be disabled from `status` / `payment_status`.
- Files to change: `modules/customs_clearance/validators.py`, `modules/customs_clearance/service.py`, `tests/unit/test_phase06_07_fixes.py`
- Steps:
  1. `validators.py`: `is_released(record, imp_file)` = `record.status == FINAL_RELEASE_STATUS or bool(imp_file and imp_file.is_customs_released)`;
     `validate_not_released(record, imp_file)` -> 409 `CC_ALREADY_RELEASED` ("تم الإفراج الجمركي النهائي عن هذه الشحنة ولا يمكن تعديل مراحل التخليص."); `validate_not_paid(record)` -> 409 `CC_ALREADY_PAID` ("تم سداد الرسوم الجمركية بالكامل لهذه الشحنة.") when `is_duty_fully_paid(record)`.
  2. In `register_customs_declaration_46_service`, `record_customs_inspection_sampling_service`: load the active record (`repo.get_active_clearance_for_file`) before `write()`; if one exists call `validate_not_released`.
  3. `assess_final_customs_duties_service`: `validate_not_released(existing, imp_file)` and `validate_not_paid(existing)` before computing.
  4. `record_customs_duty_payment_service`, `submit_duty_payment_service`: both guards before `validate_duty_payment_amount`.
  5. `_issue_release`: `validate_not_released(record, imp_file)` first (before the ACID check).
  6. `issue_under_bond_release_service` already refuses a released record (keep).
- Acceptance criteria: after a release, CL-02 returns 409 and `actual_duty_total` / `status` are unchanged.
- Tests to add: full happy path CS-03 -> CL-02 (1140) -> CL-03 (1140) -> CL-04; then CL-02 -> 409 `CC_ALREADY_RELEASED`, record `status == "Final Release Granted"`, `actual_duty_total == 1140.0`; before release a second payment -> 409 `CC_ALREADY_PAID`; re-issue release -> 409.
- Out of scope: enforcing CS-01 -> CL-01 order (Q4 of 06-07 plan).

### BE67-T08: Tariff versioning for PUT and verify (no in-place rate overwrite, no same-day 500)
- Severity: CRITICAL (F11, F12 part 1)
- Depends on: BE67-T01
- Schema/migration needed: no
- API contract change: yes. `PUT /api/v1/customs-tariff/{id}` with a changed rate returns the **new** version (new `tariff_id`, `effective_from = today`); the old row gets `effective_to = today`, `is_active=false`. Flutter: `customs_tariff_provider.dart:121` must refresh the list (already invalidates) and not assume the same id.
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/repository.py`, `tests/unit/test_customs_tariff.py`
- Steps:
  1. `RATE_FIELDS = ("customs_duty_rate","vat_rate","schedule_tax_rate","development_fee_rate","import_fee_rate","customs_service_fee_rate")` in `service.py`.
  2. `_has_rate_change(tariff, data)` compares `Decimal(str(...))` for the fields present.
  3. `repository.archive_and_create_new_tariff_version`: if `current_tariff.effective_from == effective_date` -> update the current row in place (no new row); else close + create, copying **all** columns of the current row (including `customs_service_fee_rate`, `customs_category`, `requires_*`, `notes`) and overriding with `new_data`. No `db.commit()` (T10 moves commits; until then keep one commit at the end of the function).
  4. `update_tariff_service`: if `_has_rate_change` -> `archive_and_create_new_tariff_version(db, tariff, update_dict, date.today())`; else in-place update.
  5. `verify_and_update_tariff_service`: use `RATE_FIELDS`.
- Acceptance criteria: two `verify` calls with different VAT on the same day -> both 200, one row for today; a PUT changing duty 10 -> 15 keeps the 10% row with `effective_to=today`.
- Tests to add: tariff duty 10 from 2026-01-01; PUT duty 15 -> 2 rows; `POST /estimate` with `estimate_date=2026-06-01`, CIF 1000 -> `import_duty_amount == 100.00`; with today -> 150.00. Same-day double verify (VAT 14 -> 10 -> 5) -> 200 both, final VAT 5, one row with today's `effective_from`. Verify changing only `customs_service_fee_rate` 1 -> 0 versions the row and the new row keeps 0.
- Out of scope: bulk upload (T09).

### BE67-T09: Tariff CSV upload: required rates, savepoints, size limit
- Severity: CRITICAL (F12 part 2) + MAJOR (F15 upload part, F16)
- Depends on: BE67-T08
- Schema/migration needed: no
- API contract change: yes. Rows with a missing or unparseable duty / VAT rate or description are reported in `errors` and not imported (before: imported as 0%). 413 above 5 MB, 400 for non-CSV.
  Flutter: `customs_tariff_provider.dart:215` (show `errors` list).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/router.py`, `tests/unit/test_customs_tariff.py`
- Steps:
  1. Router: reject `file.filename` not ending in `.csv` -> 400 "صيغة الملف غير مدعومة، يرجى رفع ملف CSV."; read with a cap: `contents = await file.read(5*1024*1024 + 1)`; if longer than 5 MB -> 413 "حجم الملف يتجاوز الحد المسموح (5 ميجابايت).".
  2. Service: map `customs_service_fee_rate` / `service_fee` headers. A rate column that is absent or empty or unparseable on a row -> row error "Row N: missing or invalid <field>" (duty and VAT required; schedule / dev / import fee may be empty = 0 only when the column exists and the cell is empty -> treat as 0 explicitly documented; service fee empty -> row error). Description empty -> row error.
  3. For each row: `with db.begin_nested():` create or (via T08 logic) version / update; on exception the savepoint rolls back and the error is recorded. One `db.commit()` after the loop.
- Acceptance criteria: a 3-row file with row 2 missing VAT imports rows 1 and 3, reports row 2, and stores no 0% VAT row.
- Tests to add: the 3-row example; an `.xlsx` filename -> 400; a 6 MB body -> 413; a row with duty "abc" -> error, not 0.
- Out of scope: real Excel parsing.

### BE67-T10: Correct the Nafeza extra-fees formula
- Severity: CRITICAL (F10)
- Depends on: none
- Schema/migration needed: no
- API contract change: no (values change: `additional_fees_egp`, `grand_total_payable_egp` of `estimate-multi`)
- Files to change: `modules/customs_tariff/service.py`, `tests/unit/test_customs_engine.py`
- Steps:
  1. In `calc_collection_fees` also return `non_tax_total` = sum of computed amounts for codes with `calculation_type in ("flat", "derived")`.
  2. `estimate_multi_item_customs_duty_service` (`:797-803`): `extra_nafeza_fees = _round(Decimal(str(fee_codes_result["non_tax_total"])))`; remove the subtraction of taxes.
- Acceptance criteria and test (`test_customs_engine.py`): fee codes: `77` flat 500, `390` reference duty_amount, `392` reference service_fee_amount, `798` derived 14% of `77` -> 70. One line duty 10%, VAT 14%, schedule 20%, CIF 10,000 EGP (exchange_rate 1, `cif_declared_total_egp=10000`): duty 1,000, schedule 2,000, service fee 100, VAT 1,540. Expected `additional_fees_egp == 570.00` (today 0.00), `grand_total_payable_egp == 1000+2000+100+1540+570 == 5210.00`.
- Out of scope: seeding fee codes.

### BE67-T11: customs_tariff repository without commits
- Severity: MAJOR (F15)
- Depends on: BE67-T08, BE67-T09 (same files; do after them)
- Schema/migration needed: no
- API contract change: no
- Files to change: `modules/customs_tariff/repository.py`, `modules/customs_tariff/service.py`, `tests/unit/test_customs_tariff.py`
- Steps: replace every `db.commit()` + `db.refresh()` in `repository.py` (`create_tariff`, `update_tariff`, `archive_and_create_new_tariff_version`, `toggle_tariff_active`, `create_preferential_agreement`, `bulk_create_or_update_tariff_with_agreements`, `create_fee_code`) with `db.flush()`; each service write function commits once and refreshes; `save_tariff_with_agreements_service` writes the audit log before the single commit.
- Acceptance criteria: `grep -n "commit" modules/customs_tariff/repository.py` returns nothing; all customs_tariff tests green.
- Tests to add: save-with-agreements where the audit log raises (monkeypatch `AuditLogService.log_activity`) -> nothing persisted (one transaction).
- Out of scope: behaviour changes.

### BE67-T12: Tariff soft delete separate from archive + audit columns
- Severity: MAJOR (F17, F18)
- Depends on: BE67-T11
- Schema/migration needed: yes. Alembic revision adding nullable `deleted_at DATETIME`, `deleted_by VARCHAR(100)` to `customs_tariffs`; nullable `created_by`, `updated_by VARCHAR(100)` to `customs_tariffs`, `preferential_agreements`, `fee_codes` (no backfill: NULL = unknown, response fields Optional).
- API contract change: yes (additive): `CustomsTariffResponse` gains `deleted_at`, `created_by`, `updated_by` (Optional). `verified_by` in the body of `verify` is ignored (token user). Flutter: `customs_tariff/models/*` tolerant parsing (additive, no break).
- Files to change: `modules/customs_tariff/model.py`, new `alembic/versions/<rev>_customs_tariff_soft_delete_audit.py`, `modules/customs_tariff/repository.py`, `modules/customs_tariff/service.py`, `modules/customs_tariff/router.py` (+ test `tests/unit/test_customs_tariff.py`)
- Steps: delete sets `deleted_at=now`, `deleted_by=user`, `is_active=False`; restore clears them; `get_active_tariff_on_date` and `get_tariff_by_hs_code` add `deleted_at IS NULL`; router passes `current_user.username` to every write service; service sets `created_by` / `updated_by` and `verified_by`; audit `performed_by=user`.
- Acceptance criteria: after `DELETE /{id}`, `POST /estimate` for that HS -> 422 (no tariff); archived versions still price past dates.
- Tests to add: delete then estimate -> 422; archived (T08) row still used for a past date; `verify` response `verified_by == acting username`.
- Out of scope: quotation audit columns (T18).

### BE67-T13: Engine inputs: VAT override, deemed rates, service fee, exemption flag
- Severity: MAJOR (F19, F21)
- Depends on: BE67-T02
- Schema/migration needed: no
- API contract change: yes. `vat_rate_override` 0..100 and 0 is honoured; `deemed_insurance_rate` / `deemed_freight_rate` 0..0.1; a tariff with NULL service fee -> 422 `CT_TARIFF_RATE_MISSING`; `is_exemption_conditions_met=true` applies the agreement rate. Flutter: `customs_tariff_provider.dart:181` callers (Form 46 / consultation estimate screens).
- Files to change: `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `tests/unit/test_po_country_of_origin_and_customs_exemption.py`
- Steps: `vat_rate = request.vat_rate_override if request.vat_rate_override is not None else tariff.vat_rate`; schema bounds; remove `"1.00"` fallbacks at `:205`, `:653` (422 instead); `is_exemption_conditions_met is True` -> if an agreement matches use `_agreement_duty_rate`, else 0 (explicit user confirmation, keep current label).
- Acceptance criteria / tests: override 0 on VAT 14 line CIF 10,000 duty 10% -> `vat_egp == 0.00`; `deemed_insurance_rate=0.5` -> 422; exemption flag with a 10% reduction agreement on duty 40 -> duty rate 36.00 (today 0).
- Out of scope: moving `EXEMPTIONS_REGISTRY` to a table (Q2).

### BE67-T14: Nafeza text parser stops fabricating rates
- Severity: MAJOR (F20)
- Depends on: BE67-T02
- Schema/migration needed: no
- API contract change: yes. `POST /parse-text` response: `tariff_data` rates may be null and a new `missing_fields: List[str]` and `unparsed_lines: List[str]` are returned; agreements with no detectable reduction are not in `agreements`. Flutter: `customs_tariff/widgets/nafeza_details_dialog.dart:279,303,356` must require the user to fill missing rates before `with-agreements`.
- Files to change: `modules/customs_tariff/nafeza_text_parser.py`, `modules/customs_tariff/schemas.py`, `modules/customs_tariff/service.py`, `tests/unit/test_customs_tariff_agreements.py`
- Steps: new `ParsedTariffData` schema (CustomsTariffCreate fields with `Optional[Decimal]` rates) used only in `SmartTariffParseResponse`; parser returns None for duty / VAT / service fee when not found and records the field name; `customs_category` None unless matched by `enum_codes`; agreement line without a percentage, a fixed rate or "يعفى" -> appended to `unparsed_lines`.
- Acceptance criteria / tests: text without a VAT line -> `tariff_data.vat_rate is None` and `"vat_rate" in missing_fields`; a "ر6722" line without a percentage -> not in `agreements`, present in `unparsed_lines`; existing Mercosur 3% sample still parsed as fixed 3.00.
- Out of scope: `with-agreements` validation (it already requires rates through `CustomsTariffCreate`).

### BE67-T15: Tariff list bound + fee code validation
- Severity: MAJOR (F22, F23)
- Depends on: BE67-T01
- Schema/migration needed: no
- API contract change: yes. `GET /customs-tariff` without `limit` returns at most 200 rows and sets `X-Total-Count`; `POST /fee-codes` 409 on duplicate, 422 on unknown type. Flutter: `customs_tariff_provider.dart:48` must page or pass `limit` (searchable dropdowns pass `search`).
- Files to change: `modules/customs_tariff/router.py`, `modules/customs_tariff/service.py`, `modules/customs_tariff/schemas.py`, `modules/customs_tariff/repository.py`, `tests/unit/test_customs_tariff.py`
- Steps: `limit: int = Query(200, ge=1, le=5000)`; repository returns `(rows, total)`; router sets the header through `Response`; `FeeCodeCreate.calculation_type: Literal["flat","reference","derived"]`, `reference_source: Optional[Literal[...]]`, model validator: reference needs source, derived needs base codes + rate; service checks duplicate code -> 409 `CT_FEE_CODE_DUPLICATE`.
- Acceptance criteria / tests: 250 tariffs -> list returns 200 and header 250; duplicate fee code -> 409; `calculation_type="percent"` -> 422.
- Out of scope: the in-process cache.

### BE67-T16: Lab-result release, audit, delete guard (clearance)
- Severity: MAJOR (F24, F30)
- Depends on: BE67-T07
- Schema/migration needed: no
- API contract change: yes. `DELETE /customs-clearance/{id}` -> 409 `CC_DELETE_NOT_ALLOWED` when paid or released. `lab-test-result` with CONFORMING no longer sets `is_customs_released` (Q4 default): it lifts the lock and sets next action "issue green release"; the release goes through `issue-final-release`. Flutter: `under_bond_release_dialog.dart`, `customs_clearance_screen.dart` (release button after lab).
- Files to change: `modules/customs_clearance/service.py`, `modules/customs_clearance/validators.py`, `modules/customs_clearance/router.py`, `tests/unit/test_phase06_07_fixes.py`
- Steps: lab CONFORMING: lift lock, `quarantine_lifted_by = user`, next action `NA_CL_ISSUE_GREEN_RELEASE` when paid else `NA_CL_RECORD_DUTY_PAYMENT`; drop the `can_release` branch (router stops computing it). Delete: guard via `is_duty_fully_paid` / released. Audit (`_follow_up(..., _audit, ...)`) for delete ("DELETE"), restore ("RESTORE"), under-bond ("UNDER_BOND_RELEASE"), lab ("LAB_RESULT"). Under-bond / lab use `_commit_write` + follow-ups.
- Acceptance criteria / tests: lab CONFORMING on a paid record -> `quarantine_lock False`, `is_customs_released False`, then `issue-final-release` -> 200; delete of a paid record -> 409; audit rows exist for delete / restore.
- Out of scope: lifecycle board changes.

### BE67-T17: No invented customs values in CS-03 / CL-01 / CS-01
- Severity: MAJOR (F25)
- Depends on: BE67-T07
- Schema/migration needed: no (model Python default change only; `customs_exchange_rate` is already nullable)
- API contract change: yes. CS-03: `channel_type` and `customs_office_name` required. CL-01: `inspection_result` required; `sampling_record_no` required when `is_sample_drawn=true`. Flutter: `customs_declaration_46` / inspection dialogs under `frontend/lib/features/customs_clearance/widgets/` must send them (they already have the fields; remove defaults).
- Files to change: `modules/customs_clearance/schemas.py`, `modules/customs_clearance/service.py`, `modules/customs_clearance/model.py`, `tests/unit/test_cl01_inspection_sampling.py`, `tests/unit/test_cs03_customs_declaration_46.py`
- Steps: remove defaults `"Red Channel"`, `"Alexandria Port Customs"`, `"Conforming"`, `"Physical & Sampling"` from the Submit schemas (keep them on Create for old clients? no: Create also loses them, Q7); delete the random `SMP-...` generator (`service.py:819-820`) -> 400 "رقم محضر سحب العينات مطلوب عند سحب عينات."; `_find_or_new_record` no longer passes `channel_type="Red Channel"` / office from yard; mandate letter: when `broker_license` is empty, skip the letter and log; `model.py:65` `customs_exchange_rate = Column(Float, nullable=True)` (no default).
- Acceptance criteria / tests: CL-01 with `is_sample_drawn=true` and no record no -> 400; CS-03 without channel -> 422; new record from CS-01 has `customs_exchange_rate is None`.
- Out of scope: T3 codes for channel / office (CL-20 / Q7 of 06-07 plan).

### BE67-T18: Clearance PUT and invoice master-data checks
- Severity: MAJOR (F26, F27, F28, F29) + MINOR (F39)
- Depends on: BE67-T05, BE67-T06
- Schema/migration needed: no
- API contract change: yes. PUT: `broker_id` / `shipping_agent_id` must be active (400), names taken from the provider. Invoice: provider must be active when given, 409 `CC_INVOICE_DUPLICATE` for the same file + provider + invoice number, 400 when net < 0, `payment_status` in (Unpaid, Partially Paid, Paid), `allocation_rule` in (Equal, Value-Based, Weight-Based, Volume-Based). Response tolerant of legacy NULLs. Flutter: `clearance_expenses_dialog.dart`.
- Files to change: `modules/customs_clearance/service.py`, `modules/customs_clearance/schemas.py`, `tests/unit/test_cl05_clearance_fees_invoices.py`, `tests/unit/test_customs_clearance.py`
- Steps: `require_active` (`modules/common/validators.py`) for provider ids; currency via `enum_codes.normalize_currency`; duplicate query on active invoices; `net_payable < 0` -> 400 "صافي الفاتورة لا يمكن أن يكون سالباً."; `_recalculate_clearance_expenses_aggregates` only raises progress / next action when `imp_file.is_customs_released`; `ClearanceExpenseInvoiceResponse(LegacyRowTolerantModel)` with Optional audit strings; EGP invoice ignores `exchange_rate`.
- Acceptance criteria / tests: duplicate invoice -> 409; WHT 200 on amount 100 -> 400; a legacy row with `created_by=NULL` -> summary 200; invoice before release leaves `progress_percent` unchanged; EGP with rate 50 and amount_fx 10, amount_egp 0 -> amount_egp 10.00.
- Out of scope: settlement module.

### BE67-T19: Quotation award workflow and master data
- Severity: MAJOR (F31, F33) + MINOR (F35)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. 409 `CCQ_RFQ_AWARDED` on quote add / update / delete and RFQ status change of an awarded RFQ, and on a second award; 409 on quote add / update of a Cancelled RFQ; `provider_name` is taken from the provider master (client value ignored); RFQ response lists active quotes only; delete of an awarded RFQ -> 409. Flutter: `customs_clearance_quotations_provider.dart:32-187`, `customs_clearance_quotations_screen.dart`.
- Files to change: `modules/customs_clearance_quotations/service.py`, `modules/customs_clearance_quotations/validators.py`, `modules/customs_clearance_quotations/schemas.py`, `tests/unit/test_customs_clearance_quotations.py`
- Steps: `validate_rfq_open(rfq)` (not Awarded / Cancelled) used by add / update / delete quote; `validate_rfq_status_change` refuses any change when current is Awarded; award refuses when `rfq.status == Awarded`; `_prepare_quote` sets `q_data["provider_name"]` from the provider row; price-list create / update call `validate_quotation_provider`; response: a `field_validator("quotations")` on the RFQ response filtering `is_active`.
- Acceptance criteria / tests: award then update the awarded quote -> 409; award twice -> 409; provider_name "X" with provider 5 named "Nile Broker" -> stored "Nile Broker"; price-list with inactive provider -> 400.
- Out of scope: audit columns (T20).

### BE67-T20: Quotation tables audit columns (still open from CCQ-10)
- Severity: MINOR (F32)
- Depends on: BE67-T19
- Schema/migration needed: yes: nullable `created_by`, `updated_by VARCHAR(100)` on `customs_clearance_rfqs`, `customs_clearance_quotations`, `clearance_price_list_items` (no backfill).
- API contract change: additive (`created_by`, `updated_by` Optional in the 3 responses).
- Files to change: `modules/customs_clearance_quotations/model.py`, new `alembic/versions/<rev>_ccq_audit_columns.py`, `modules/customs_clearance_quotations/router.py`, `modules/customs_clearance_quotations/service.py`, `tests/unit/test_customs_clearance_quotations.py`
- Steps: columns + migration; router routes take `current_user: User = Depends(require_permission(...))` and pass `current_user.username`; services set the columns.
- Acceptance criteria / tests: create RFQ -> `created_by == username`.
- Out of scope: other modules.

### BE67-T21: Minor hygiene (clearance list paging, tariff messages, history, dead code)
- Severity: MINOR (F34, F36, F37, F38, F40, F41)
- Depends on: BE67-T11, BE67-T18
- Schema/migration needed: no
- API contract change: additive only (`skip` / `limit` optional on `GET /customs-clearance`, `X-Total-Count`); multi-estimate `currency` required (Flutter `customs_tariff_provider.dart:181` already sends it: verify).
- Files to change: `modules/customs_clearance/repository.py`, `modules/customs_clearance/router.py`, `modules/customs_tariff/service.py`, `modules/customs_tariff/validators.py`, `modules/customs_clearance/schemas.py`
- Steps: optional paging; Arabic error texts in tariff service / validators; history filters agreements by version period and returns None for NULL rates; schema description note on `total_clearance_expenses_egp`; remove `ClearanceExpenseInvoiceUpdate`, `validate_release_permit`, `validate_tariff_exists` (grep first: no callers).
- Acceptance criteria / tests: existing tests green; `GET /customs-clearance?limit=1` returns 1 row with header.
- Out of scope: anything else.

## 4. Frontend impact

| Endpoint / field | Change | Flutter files |
|---|---|---|
| All `/api/v1/customs-tariff/*` | 403 without `customs_tariff.view` / `.edit`; `simulate-file` needs `customs_clearance.update` | `features/customs_tariff/providers/customs_tariff_provider.dart`, `features/customs_tariff/screens/customs_tariff_screen.dart` |
| `POST /customs-tariff/estimate-multi`, `simulate-file` | 422 `CT_CUSTOMS_RATE_MISSING`; simulate adds `warnings[]`, `skipped_lines[]`, 422 `CT_SIMULATION_NO_LINES`, `consultation_id` may be null | `customs_tariff_provider.dart:181,198` + simulation caller screens |
| `POST /customs-tariff/agreements`, `with-agreements` | `reduction_percentage` 0..1 | `customs_tariff/widgets/add_agreement_dialog.dart` (already 0..1) |
| `PUT /customs-tariff/{id}` | Rate change returns a new `tariff_id` | `customs_tariff/widgets/tariff_form_dialog.dart`, provider `:121` |
| `POST /customs-tariff/upload-excel` | CSV only, 5 MB, row errors for missing rates | provider `:215` |
| `POST /customs-tariff/parse-text` | nullable rates + `missing_fields[]`, `unparsed_lines[]` | `customs_tariff/widgets/nafeza_details_dialog.dart` |
| `GET /customs-tariff` | default 200 rows + `X-Total-Count` | provider `:48`, every HS-code `SearchableDropdownField` (pass `search`) |
| `POST /customs-clearance`, `PUT /{id}` | claim / assessment fields ignored; negatives 422; broker / agent active | `customs_clearance/providers/customs_clearance_provider.dart` |
| CS-03 / CL-01 / CL-02 / CL-03 / CL-04 | 409 `CC_ALREADY_RELEASED` / `CC_ALREADY_PAID`; CS-03 channel + office required; CL-01 result + record no required | `customs_clearance/widgets/*_dialog.dart` (show `ApiErrorText`) |
| `lab-test-result` | no longer releases; release via `issue-final-release` | `under_bond_release_dialog.dart`, `customs_clearance_screen.dart` |
| `/customs-clearance/invoices` | 409 `CC_SETTLEMENT_LOCKED`, `CC_INVOICE_DUPLICATE`; status / rule Literal sets | `customs_clearance/widgets/clearance_expenses_dialog.dart` |
| Quotations | 409 `CCQ_RFQ_AWARDED`; provider_name server-side; inactive quotes hidden | `customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart`, `.../screens/customs_clearance_quotations_screen.dart` |

## 5. Open questions for the CTO (safe default in brackets)

- Q1: May a clearance invoice be added after the landed-cost settlement is Approved (e.g. a late port invoice)? [No: 409; re-open the settlement first.]
- Q2: Exemptions (`EXEMPTIONS_REGISTRY`: investment law, free zone, diplomatic, 50%) are legal master data in code. Move to a DB table next wave? [Yes, next wave; keep code values now.]
- Q3: Deemed insurance 2.5% / freight 2% (no document): official values and where they live (settings table)? [Keep as request defaults, bounded 0..10%, until a settings source exists.]
- Q4: Lab CONFORMING on a paid record: release automatically, or always through the CL-04 release with a permit number? [Through CL-04.]
- Q5: Simulation with POs in several currencies: convert each PO with its own customs rate, or refuse? [Convert per PO.]
- Q6: May an awarded clearance RFQ be re-awarded to another broker? [No (409); cancel and create a new RFQ.]
- Q7: Old clients that rely on CS-03 / CL-01 defaults (channel "Red Channel", result "Conforming"): break them now? [Yes, the FE is updated in the same release.]
- Q8: Existing agreements with `reduction_percentage > 1` (if any): fix by data script, or refuse at calculation time? [Refuse at calculation (422) and run a read-only count before deploy.]
- Q9: Should `customs_tariff.edit` also be required for `parse-text` (no write)? [No: `view`.]
