# Phases 4 "Freight Booking" and 5 "Cargo Shipping": quality audit and fix plan

Status: proposed (2026-10-05). Nothing has been implemented. The audit is static reading only: no pytest run, no flutter test run, no `import main`. It follows the method of `docs/plans/phase-01-quality-simplify-plan.md` and reuses the A1 helpers listed in `docs/plans/phase-01-progress.md`.
Business stages: BP-017..019 (Phase 4, GP-002 STEP_06/07) and BP-020..025 (Phase 5, STEP_07/08). Demurrage (TR-02/TR-05, BK-02) feeds Phase 9 landed cost.

## Audit coverage

| Area | Depth |
|---|---|
| `modules/freight_booking` | Router, service, validators, repository, model and schemas read fully |
| `modules/cargo_insurance` | Router, service, validators, repository and schemas read fully. Model columns grepped |
| `modules/cargo_shipping` | Router, service, validators and repository read fully. Schemas and model grepped |
| `modules/shipment_updates` | Router, service, validators and schemas read fully. Repository and model grepped |
| `modules/demurrage_detention` | Router, service (all 1473 lines) and validators read fully. Repository, schemas and model grepped |
| Backend total | About 4.9k of the 5.9k lines read line by line. The rest was grepped |
| Flutter (22.3k lines) | Grep sweeps over all 5 features. Read line by line: the `freight_booking` and `cargo_insurance` providers, the `demurrage_provider` method list, and about 150 targeted lines of the screens and dialogs. JSON keys of all 5 models were diffed by script against the backend schemas. The god screens were **not audited** line by line |
| Tests | Test files inventoried. The tests that pin behaviour this plan changes are listed in §3 |

Severity: **BLOCKER** breaks a non-negotiable rule, or can corrupt money, customs data or references. **CRITICAL** gives a wrong result, data loss, or a 500 on a normal path. **MAJOR** is a rule violation or a real risk without immediate loss. **MINOR** is hygiene.

---

## 1. Findings

### 1a. Backend

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| FB-01 | BLOCKER | `freight_booking/router.py:20-121` | No `require_permission` on any route. Only authentication is checked | code | Add permissions. GET: `freight_booking.view`. POST create, PUT, DELETE, restore: `freight_booking.create`. `/confirm` and `/depart`: `freight_booking.confirm` |
| FB-02 | CRITICAL | `service.py:387-450,466-499`, `schemas.py:61,103` | (a) `status` is free text. PUT can set `Sailed` without a B/L, or `Confirmed` without a confirmation number, and the screen sends `status` on every save (`freight_booking_screen.dart:1860`).<br>(b) `/confirm` has no state guard: confirming a Sailed or Cancelled booking resets it to Confirmed and re-runs the STEP_07 workflow.<br>(c) `/depart` works on a booking that was never confirmed | code | In `validators.py`, keep an allowed set of the current labels (Draft, Booking Requested, Confirmed, Amended, Cancelled, Sailed). PUT may only set Draft, Booking Requested, Amended or Cancelled. Any other value returns 409 "لا يمكن تغيير حالة الحجز يدويًا إلى <s>". Confirm is allowed from Draft, Booking Requested, Amended or Confirmed. Depart is allowed from Confirmed or Amended. Anything else returns 409 with an Arabic detail |
| FB-03 | MAJOR | `service.py:241,274,341,351,401,446,494,522,536,572,638`, `repository.py:68,121` | One request runs 4-7 commits: booking, file sync, tasks, notification, audit. A failure part-way leaves the import file updated without the lifecycle step | code | The repository flushes and the service commits once. Side effects go through `errors.best_effort`. Log text stays the same |
| FB-04 | MAJOR | `repository.py:10-15` | `BKG-YYYY-NNNN` is `count()+1` filtered on `created_at`. A gap or a concurrent create gives a duplicate code: IntegrityError, then 500 | code | `next_yearly_code(db, ShipmentBooking.booking_code, "BKG", pad=4)` plus one retry |
| FB-05 | MAJOR | `service.py:457-463` | Restore skips `validate_no_duplicate_booking_for_file`, so a file can end up with two active bookings | code | Run the guard on restore (400, existing Arabic detail) |
| FB-06 | MAJOR | `service.py:119-131` | The savings engine matches on substrings: `"40" in charge_type` or `"20"`. "THC 40HC" or "VGM Fee 20GP" gets compared with the ocean-freight rate, which produces wrong `cost_variance_usd` and `savings_notes` | code | Pin it now (§3). The fix waits for Q4 |
| FB-07 | MAJOR | `service.py:364,415`, `schemas.py:62`, `model.py:73` | The audit log uses `performed_by = booking.owner or "Kamal"`, and `owner` defaults to "Kamal". The real user is never recorded | code | The router passes `current_user.username`. The audit log uses it, and `owner` defaults to the username when it is not sent. `created_by`/`updated_by` columns are deferred (§6) |
| FB-08 | MINOR | `router.py:54-121`, `validators.py:15,23` | The router maps None to 404, which is logic in the router. The details are English | code | The service uses `validators.not_found("حجز الشحن", id)`. Validators get Arabic details |
| FB-09 | MINOR | `service.py:269-273,567-571` | Smart tasks are auto-closed by matching Arabic or English substrings in the title | code | Match on `msg_code` first and keep the title match as a fallback |
| INS-01 | BLOCKER | `cargo_insurance/router.py:20-128` | No permissions. The catalog has no insurance code at all | code | `cargo_insurance.view` and `cargo_insurance.manage` (Shared needs). Safe default: `freight_booking.view` and `freight_booking.create` |
| INS-02 | BLOCKER | `service.py:20-33`, `schemas.py:13-20,65-71`, `model.py:48-57` | Premium rates are hard-coded: ICC_A 0.25%, AIR 0.20%, ICC_B 0.15%, ICC_C 0.10%, war 0.05%, **tax 5%**, issuance fee 15, minimum premium 30, markup 10%. An unknown clause is priced silently as ICC_A (`RATE_TABLE.get(..., 0.0025)`), including on `/calculate` | code | Read every rate from `system_parameters` through `get_float_parameter`. New keys (Shared needs) are seeded with today's values, so the numbers stay identical. Validate the clause and the mode in the engine: 400 "بند التغطية غير معروف" |
| INS-03 | CRITICAL | `repository.py:12-19` | The code is literally `INS-2026-{count+1}`. The year is frozen, and the count covers all rows | code | `next_yearly_code(db, CargoInsuranceCertificate.certificate_code, "INS", pad=5)` |
| INS-04 | CRITICAL | `service.py:184-227`, `schemas.py:117` | An ISSUED certificate can still be edited and its premium recomputed. `status` can be set by PUT (ISSUED without `issued_at`, or a step back to DRAFT). On update, the clause, mode and policy type are not validated. An explicit null is ignored silently | code | Return 409 when the status is ISSUED or CANCELLED. `status` in the update payload is ignored (the field stays, deprecated). Run the create enum checks on update |
| INS-05 | MAJOR | `service.py:111-150` | The service invents legal data on the certificate: insurer "Misr Insurance / Suez Canal Insurance", destination "Cairo / Alexandria, Egypt", survey agent "Lloyd's Agency…", and a generated `policy_number` | code | Store null when the field is not sent. Q5 decides whether `policy_number` is still generated |
| INS-06 | MAJOR | `router.py:46,100,113` | `created_by` and `updated_by` are always "system": the router never passes the user | code | Pass `current_user.username` |
| CS-01 | BLOCKER | `cargo_shipping/router.py:31-106` | No permissions. Level-2 approval has no dedicated code | code | GET: `cargo_shipping.view`. Mutations and level 1: `cargo_shipping.update`. Level 2 and CargoX advance: `cargo_shipping.approve` (Shared needs). Safe default: `cargo_shipping.update` |
| CS-02 | BLOCKER | `service.py:292-303,343-344,346-348`, `repository.py:122-125` | The CargoX checklist hard-codes "ACID verified on Nafeza" and "Invoice consignee match" as `passed=True`. "Uploaded" invents `blockchain_tx_hash` and `envelope_id` ("ENV-CGX-2026-…"). A client can PUT a `cargox_exchange_data.verification_checklist` with every rule passed. `target_stage` is free text, so unknown values commit nothing silently, and "Completed" skips the checklist | code + `test_cargo_shipping.py:366` | The ACID rule becomes `ImportFile.acid_number` present. The invoice rule becomes `passed=False` with details "MANUAL_CHECK_REQUIRED" until a real check exists. Never invent the hash or the envelope id: accept them as optional query params, otherwise leave them null. `target_stage` is a `Literal`, and the order Checklist Passed → Ready for Upload → Uploaded → Completed is enforced (409 Arabic). PUT ignores `verification_checklist`, `envelope_status`, `blockchain_tx_hash` and `envelope_id` |
| CS-03 | CRITICAL | `repository.py:93-98`, `service.py:88-92,163,220,232,237`, `router.py:54` | Soft-delete leak: PUT, both loading-tracking endpoints, and POST auto-upsert all set `is_active=True` again. A deleted record is revived by any edit | code | Mutations load active records only, otherwise 404. Restore is possible only through `/restore`. Auto-upsert onto an inactive record returns 409 "السجل محذوف، استخدم الاستعادة" |
| CS-04 | CRITICAL | `repository.py:127-128` + `cargo_shipping_screen.dart:1005-1006` | The screen sends `status: 'Cargo Ready'` and `owner: 'Kamal'` on **every** save, edits included. That resets Dual Approved, CargoX Transfer Completed and Completed records back to Cargo Ready | code | BE: PUT accepts only `Cargo Ready`, `Loaded & Sealed` or `Docs Dispatched`, and never downgrades a workflow status: silently ignored, as today's field is optional. FE: stop sending `status` and `owner` on edit |
| CS-05 | MAJOR | `service.py:243-285`, `schemas.py:111-118` | `approved_by` comes from the request body, so it can be spoofed. The same person can approve level 1 and level 2. Level 1 can be resubmitted after Dual Approved, which leaves `status` at Dual Approved while `dual_approval_status` becomes Rejected | code | `approved_by = current_user.username` (the body field becomes optional and ignored). 409 when the record is already Dual Approved or later. The L2 ≠ L1 approver check depends on Q6 |
| CS-06 | MAJOR | `service.py:116-128,383-394` | Lifecycle sync runs under `except Exception: pass`, always with `is_final_completed=True`, even with 0 containers | code | `best_effort` with logging now. The completion flag waits for Q7 |
| CS-07 | MAJOR | `validators.py:6-25` | `parse_iso_datetime` swallows bad strings and returns None. The sequence check and the 15-day reuse check are then skipped, and the garbage text is stored | code | A non-empty value that cannot be parsed returns 422 "صيغة التاريخ غير صحيحة: <field>" |
| CS-08 | MAJOR | `repository.py:88`, `service.py:113,223,239,260,283,327,353` | Multiple commits per request | code | One commit in the service |
| CS-09 | MINOR | `validators.py:201-204`, `repository.py:10-31`, `validators.py:129` | The reuse check loads every active record on each save (O(N·C)). The code generator reads the last id. The 48 h SLA and the 15-day window are hard-coded | code | `next_yearly_code("SHP", pad=4)`. Perf and parameters go to the backlog |
| SU-01 | BLOCKER | `shipment_updates/router.py:19-97` | No permissions | code | GET: `import_files.view`. POST, PUT, DELETE: `import_files.edit` |
| SU-02 | CRITICAL | `service.py:95-98,115` | `"Phase 1" in current_module` also matches "Phase 10". A file in Phase 10 is reported as Phase 1, with every later phase as Future, and Phase 10 logs are counted under Phase 1 | code | Parse the number with `re.search(r"\bPhase (\d+)\b")` and compare integers |
| SU-03 | CRITICAL | `service.py:42-56` | Create has these problems:<br>(a) It writes `import_file.current_module` from free text, which bypasses the GP-002 board.<br>(b) It **overwrites** `import_file.notes`, so user notes are lost.<br>(c) It does not check that the file exists or is active.<br>(d) It commits the file before the log row: two transactions.<br>(e) `import_file_code` is taken from the client | code | `require_active(db, ImportFile, id, "ملف الاستيراد", status_code=404)`. `target_phase` must match `Phase 1..10`. Append to the notes instead of overwriting (Q8). Use one commit. Take the code from the DB |
| SU-04 | MAJOR | `schemas.py:173-182` | `update_category`, `phase_status` and `alert_priority` are free text. `log_date` is a string that is never validated | code | `Literal` sets of the current values. `log_date` is validated as `YYYY-MM-DD` and still stored as a string |
| SU-05 | MAJOR | `service.py:24-35` | The API returns Arabic `phase_name` labels, against the single-language rule | code | Keep the field (deprecated). Flutter renders the label from `phase_number` (FE-09) |
| SU-06 | MAJOR | `service.py:38,72`, `router.py:28,83` | `created_by` is always "System" and `assigned_user` defaults to "Kamal" | code | Pass `current_user.username` |
| DD-01 | BLOCKER | `demurrage_detention/router.py:45-190` | No permissions. Tariff policies, push-to-settlement and EIR are open to any user who is logged in | code | GET and `/simulate`: `demurrage_detention.view`. Everything else: `demurrage_detention.manage` |
| DD-02 | BLOCKER | `service.py:41-51,282-295,402-407,582,611,678-684,1245-1251` | Carrier tariffs are hard-coded: demurrage 40/70/120 and detention 35/65/110 USD/day, storage 250 EGP/day, free days 14/7/5, FX fallback 50. They apply silently when no policy matches and are then pushed into landed cost | code | Use one `_resolve_tariff(policy) -> Tariff` in the service. The defaults come from `system_parameters` (new keys seeded with today's values, so the numbers stay identical). Remove the FX fallback of 50: `exchange_rate` is required to be > 0 |
| DD-03 | BLOCKER | `service.py:1045-1186` | The radar exposure uses hard-coded **70 USD/day, 250 EGP/day and FX 50**. It ignores the tracking policy tiers and the stored totals, so the dashboard does not match the tracking or the settlement. N+1 lazy loads of `t.policy` and `t.import_file` | code + `test_tr02` | Compute each container through `simulate_demurrage_and_detention` with `_resolve_tariff`. `joinedload(policy, import_file)`. This is an intended change of values |
| DD-04 | CRITICAL | `service.py:856-901` | Free-days registration (BK-02) recalculates every tracking without passing its tiers or storage rate, so the schema defaults replace the policy. It rebuilds each container and drops `gate_out_date`, `empty_return_date`, `eir_number`, `seal_no`, `condition` and `damage_*`. It also recalculates trackings that were already pushed to settlement, which leaves the settlement stale. One commit per tracking | code | Add `_recalculate_containers(tracking, tariff, overrides)`. It updates only the computed keys and keeps every other key. Skip trackings with `is_pushed_to_settlement` and log them (Q9). Use one commit |
| DD-05 | CRITICAL | `service.py:391-473` | PUT trackings drops the same per-container keys (EIR, per-container dates). `req.x or tracking.x` makes clearing a date impossible. `req.status or computed` lets free text hide the incurred fines. `exchange_rate` is not validated | code | Use `_recalculate_containers`. Status: computed, or `Closed` only. `validate_positive_amount` on the rate |
| DD-06 | CRITICAL | `service.py:1193-1445` | Empty return (TR-05) has these problems:<br>(a) `task_code=f"TSK-0901-{file_id}"` is unique, so a second (partial) return fails at the final commit: 500, and the EIR is lost.<br>(b) The board moves to STEP_20 even on a partial return.<br>(c) Every inland booking is set to Completed on a partial return.<br>(d) The return date is not checked against the discharge and gate-out dates. Unknown container numbers are ignored silently.<br>(e) With no tracking, it invents "CONTAINER-01".<br>(f) `empty_containers_eir_numbers` is overwritten, so earlier EIRs are lost.<br>(g) The task auto-close has no `is_active` filter and matches any title containing "حاويات" | code + `test_tr05` | (a) Create the task once: skip it if one with that code exists. (b, c) Only when `all_returned`. (d) `validate_demurrage_dates` per container. Unknown numbers return 400 with the list. (e) 404 "لا توجد جلسة تتبع حاويات لهذا الملف" when no tracking exists and no containers are given (Q10). (f) Append with ", ". (g) Add the `is_active` filter and match on `msg_code` |
| DD-07 | CRITICAL | `service.py:491-546` | Push-to-settlement creates `LandedCostSettlementRecord` itself:<br>(a) The code `LCS-2026-{count+1}` collides with `financial_settlement/repository.py:9`: 500.<br>(b) It invents the accountant "Sorour Logistics Accountant".<br>(c) It sets only `total_expenses_egp`, so the landed-cost totals go stale.<br>(d) Two commits | code | Import, without editing, `financial_settlement.repository.generate_settlement_code` and, after updating the invoices, call `financial_settlement.service.recalculate_settlement_service`. Accountant: `req.accountant_name or current user`. Use one commit before the recalculation |
| DD-08 | MAJOR | `service.py:588-597,620-627,1111,1124` | Date boundaries disagree. The simulator counts fines from day free+1, but the dual clock and the radar flag OVERDUE/CRITICAL when `remaining == 0`, i.e. on the last free day | code | Pin the current behaviour. Q11 decides the rule. Fix: OVERDUE only when `consumed > free` |
| DD-09 | MAJOR | `schemas.py:71,134`, `model.py:93` + `demurrage_detention_screen.dart:1602` | The FX rate is client data with a default of 50, and the create dialog hard-codes `50.0`. EGP totals reach landed cost at a fake rate | code | BE: when the request has no rate, resolve it through `CurrencyService._get_rate_to_egp` at the discharge date (Q12 decides the rate type). FE stops sending 50.0 |
| DD-10 | MAJOR | `service.py:278-291` | The policy is matched on the first container type only, so a mix of 20' and 40' is priced with one policy. The booking override changes the demurrage free days only | code | Backlog (Q13). Pin it now |
| DD-11 | MAJOR | `validators.py:7-29` | Tiers are not checked for gaps or overlaps. Gap days are priced at 0, and on an overlap the breakdown double counts | code | Require contiguous tiers (`from = prev.to + 1`) with only the last one open. Otherwise 422 with an Arabic detail. Translate the existing English details |
| DD-12 | MAJOR | `service.py:147-161,565,644-650,1105-1141,1469` | Arabic presentation text with emojis is built on the backend (`countdown_summary_ar`, `summary_ar`, `status_label_ar`, `alert_message_ar`, `message_ar`, tier names), plus hex `color_code` | code | Keep the fields (deprecated). Flutter renders from the codes and numbers (FE-09) |
| DD-13 | MAJOR | `service.py:904-909,1000-1005,1029-1030` | Cost avoidance uses a hard-coded 70 USD/day and 14 standard days. GET free-days answers with invented 7/5 days and the name "Carrier" | code | The rate and the standard days come from `system_parameters` (today's values). The stored detention and storage days are deferred (§6) |
| DD-14 | MAJOR | `service.py:842,852,901,923,949,510,544` and all `user="System"` defaults | Multiple commits. The audit user is never passed | code | One commit, plus `current_user.username` from the router |
| DD-15 | MINOR | `repository.py:69-72`, `service.py:243,387` | `DND-YYYY-NNNN` is `count()+1` over all years. The 404 details are English | code | `next_yearly_code("DND", pad=4)`, Arabic details |

### 1b. Flutter

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FE-01 | CRITICAL | `demurrage_detention/widgets/dual_clock_radar_dialog.dart:178-340` | The dialog reads 15 keys that `DualClockResponse` does not have (`daily_rate_usd`, `free_days_remaining`, `demurrage_overdue_days`, `total_accrued_demurrage_usd`, `current_tier_name`, `urgent_advice_ar`, `is_storage_overdue`, …). It always shows zeros or defaults | Add a typed `DualClockModel` in `demurrage_model.dart` mapped to the real schema (`carrier_clock.free_days_allowed/days_consumed/days_remaining/accrued_demurrage_fx/status`, `port_storage_clock.storage_free_days/days_remaining/hours_until_penalties/daily_rate_egp/accrued_storage_egp/is_critical_72h_warning/status`) |
| FE-02 | CRITICAL | `cargo_shipping/screens/cargo_shipping_screen.dart:999-1006` | `status: 'Cargo Ready'` and `owner: 'Kamal'` are sent on edit (CS-04) | Send `status` on create only. Never send `owner` |
| FE-03 | MAJOR | `demurrage_detention_screen.dart:42,117,920,1602,1745,1816` | Hard-coded FX 50.0 and storage rate 250.0 | Drop `exchange_rate` from the create payload (DD-09). The simulator rate is an empty required field |
| FE-04 | MAJOR | `cargo_insurance/screens/cargo_insurance_screen.dart:1187-1215` | A copy of the premium engine with hard-coded rates and no rounding | A debounced `POST /cargo-insurance/calculate` through `calculateInsurance` |
| FE-05 | MAJOR | `shipment_updates/widgets/shipment_update_dialog.dart:246,261,330`, `screens/shipment_update_engine_screen.dart:1051,1200` | 3 `DropdownButtonFormField` and 2 `DropdownButton`. Hard-coded phase list. `_assignedUser = 'Kamal'` (`:61`) | `SearchableDropdownField<String>`. Drop the `assigned_user` literal (the BE uses the session user) |
| FE-06 | MAJOR | counts FB / INS / CS / SU / DD | `Colors.` 135/88/155/64/116. `Color(0x` 46/0/46/0/12. Elevated/Outlined/TextButton 54/28/54/28/55. `isAr ?` 25/4/19/0/44. Arabic literals in 282 lines across 12 files. `Text('…')` 26/5/9/7/11 | Mechanical sweep: `AppTheme.*`, `AppButton`, `context.l10n`. One commit per file |
| FE-07 | MAJOR | `demurrage_provider.dart:143-233` (`error: e.toString()`), `:205` `catch (_)`, `freight_booking_screen.dart:107`, `free_days_agreement_dialog.dart:128` | The backend Arabic detail and 403s are lost: screens show generic SnackBars or nothing | Use `ApiErrorText` (`core/localization/api_error_text.dart`) and show it as a SnackBar. `fetchFreeDaysAgreement` swallows only 404 |
| FE-08 | MAJOR | `cargo_insurance_export_service.dart:501`, `cargo_shipping_sla_export_service.dart:437`, `shipment_update_engine_screen.dart:903,1010,1249` | PDFs go through `Printing.layoutPdf` and bypass `FileSaveHelper.exportAndSaveFile` and the `[Stage] - [File code].pdf` naming. The CSVs use `saveText` (dialog OK) | Add a "Save PDF" path through `exportAndSaveFile`. Printing stays as a separate action |
| FE-09 | MAJOR | `demurrage_model.dart:224,351,361,536`, `shipment_update_model.dart:107`, `cargo_shipping_model.dart:200-206` | The screens render backend Arabic fields, and the model has Arabic status labels | Render from the codes (`status_badge`, `radar_status`, `overall_alert_level`, `phase_number`, `tracking_status`) through l10n keys |
| FE-10 | MAJOR | `cargo_insurance_provider.dart:26-55` | No paging: the backend default `limit=50` hides older certificates | Add `skip`/`limit` and "load more" using `total` |
| FE-11 | MINOR | `freight_booking_model.dart:61,91,300` | The model reads `import_file_code`, which the backend never returns, and sends `individual_containers`, which Pydantic drops. It sends computed fields (`cost_savings_usd`, `savings_notes`) | Drop them from `toJson`. Resolve the file code from `importFilesProvider` |
| FE-12 | MINOR | shipment_updates and demurrage mutations | The import-file and lifecycle providers are not invalidated after SU create, EIR, free days or push, though those calls change the file | `ref.invalidate(importFilesProvider)` and `ref.invalidate(lifecycleBoardSummaryProvider)` |

No physical `EdgeInsets.only(left/right)`. The two `Alignment.centerLeft` hits are inside PDF tables (fine).

---

## 2. Behaviour to keep identical

- **Freight booking**: `transit_time_days = max(0, (eta-etd).days)` on naive datetimes. Delay is computed from dates. Warehouse ETA = eta + delay + `expected_warehouse_days` (default 7). "Per Container" charges multiply by the total container count. Rounding at 2 places. The savings breakdown and the `savings_notes` English text (T2) stay unchanged until Q4.
- **Insurance**: `cif = round(inv+frt+oth,2)`, `insured = round(cif*(1+markup),2)`, base and war premiums rounded separately, `net = max(calc, min)`, `tax = round((net+fee)*rate,2)`. Seeded parameter values equal today's constants.
- **Cargo shipping**: `calculate_container_sla_and_status` (48 h, status ladder), the 15-day/same-seal reuse rule, `validate_crd_against_cutoff`, and the dual-approval order.
- **Demurrage**: `calculate_tiered_fee` totals. `consumed = (end - discharge).days`, `overdue = consumed - free`. Storage uses the same window as demurrage. EGP = `(dem+det)*fx + storage`. Per-container sums rounded at the end. Simulator responses stay byte-identical when the request carries its tiers.
- Lifecycle step codes and `msg(...)` codes sent today (FB_*, DD_*, NA_*) do not change.

## 3. Characterization tests (first, green on the current code)

New `tests/unit/test_phase04_05_characterization.py`:
1. Booking cost engine golden values: 2×40HC with "Per Container" sea freight and a "Per Shipment" BL fee give the totals, variance and the exact `savings_notes`. "THC 40HC" against a 40ft quote gives the current (wrong) saving, pinned and marked for Q4.
2. Booking dates: transit and delay days, warehouse ETA with and without ATD.
3. Insurance engine: ICC_A with war at the 30 minimum, ICC_C without war above the minimum, the tax at the cent.
4. `calculate_tiered_fee`: 0, 7, 8, 15 and 30 overdue days, with the default tiers and with custom tiers.
5. Simulator: gate-out on the expiry day gives 0 overdue, and expiry + 1 gives 1 day. Storage with 5 free days.
6. Dual clock and radar on the last free day: the current OVERDUE/CRITICAL value, pinned for Q11.
7. Container SLA ladder and the 15-day reuse conflict (same seal fails, other seal passes).
8. Shipment-update inspection for a file in "Phase 3", which works today.

Existing tests that change by design: `test_cargo_shipping.py:366` (hash is now null, CS-02), `test_cargo_insurance.py:144` (current year, INS-03), `test_tr02_demurrage_detention_radar.py` (exposure now uses the policy, DD-03), `test_bk02_free_days_agreement.py:164,253` (980.0 stays as long as the seeded parameters stay at 70/14), `test_tr05_empty_container_return.py:178-184` (task stays, created once).

Regression tests written with each fix: 403 for a viewer on POST in each of the 5 routers (seam: `ALLOW_DEV_AUTH_BYPASS=False`). FB-02 (confirm on Sailed gives 409), FB-05, INS-03, INS-04 (edit after issue gives 409), CS-02 (checklist with no ACID fails, PUT cannot inject the checklist), CS-03 (edit of a deleted record gives 404), CS-04 (PUT status on a Dual Approved record is kept), SU-02 (Phase 10), SU-03 (notes appended, inactive file gives 404), DD-04/05 (EIR survives a recalculation, policy tiers kept), DD-06 (second partial return gives 201, the board stays at STEP_19), DD-07 (code from the settlement generator, totals recalculated), DD-11 (gap gives 422).

Flutter tests: `frontend/test/features/demurrage_detention/dual_clock_model_test.dart` (fromJson of a real backend payload), `cargo_shipping_payload_test.dart` (no `status`/`owner` on edit), `cargo_insurance_provider_test.dart` (paging), and `shipment_update_model_test.dart`.

## 4. Work split (two packages, disjoint files)

| Package | Owner | Files (exclusive) |
|---|---|---|
| **BE** | backend-developer | `modules/{freight_booking,cargo_insurance,cargo_shipping,shipment_updates,demurrage_detention}/*`; new `tests/unit/test_phase04_05_characterization.py`; the existing test files listed in §3 |
| **FE** | flutter-developer | `frontend/lib/features/{freight_booking,cargo_insurance,cargo_shipping,shipment_updates,demurrage_detention}/**`; l10n keys **only** between `// === review phase04_05 keys ...` and `// === end review phase04_05 keys ===` in `frontend/lib/core/localization/app_localizations{,_ar,_en}.dart`; `frontend/test/features/<those 5>/` |

Order:
1. BE: characterization tests.
2. BE: routers and permissions, using the existing codes or the safe defaults.
3. BE: CS-02/03/04, DD-04..07, SU-02/03.
4. BE: hard-coded rates through parameters, after the Shared needs are merged.
5. FE: starts at once with FE-01, FE-02, FE-05..08 and FE-10..12, which do not depend on BE. FE-03 waits for DD-09 and FE-04 waits for INS-02.
6. Reviews: `customs-rules-reviewer` (INS-02, DD-02/03/07/09), `security-reviewer` (permissions, CS-02, CS-05), and diff-reviewer.

**Contract changes** (all backward compatible for the current FE except where marked):
1. Fields accepted but ignored: PUT `status` (insurance always; cargo-shipping workflow values; booking Confirmed/Sailed now gets 409), `approved_by`, the CargoX checklist fields in PUT.
2. `/cargo-shipping/{id}/cargox/advance-stage`: `target_stage` gets 422 when unknown. Optional `tx_hash` and `envelope_id` query params.
3. `exchange_rate` on tracking create becomes optional. The server resolves it.
4. New 409s and 404s, all with Arabic details: FB-02, FB-05, INS-04, CS-03, CS-05, DD-06e.
5. The deprecated Arabic display fields stay in the responses for one release.

## 5. Shared needs (lead / common owner; devs do NOT edit `modules/common/*`, `modules/auth/seed_rbac.py`, `docs/*.json`)

- **Permissions**: `cargo_insurance.view` and `cargo_insurance.manage`, granted to the roles holding `freight_booking.view` / `freight_booking.create`. `cargo_shipping.approve`, granted to ADMIN, GENERAL_MANAGER and the roles holding `cargo_shipping.update`. Same one-time grant pattern as A1.
- **`system_parameters` defaults**, seeded with current values:
  - Insurance: `INSURANCE_RATE_ICC_A` 0.0025, `INSURANCE_RATE_AIR_ALL_RISKS` 0.0020, `INSURANCE_RATE_ICC_B` 0.0015, `INSURANCE_RATE_ICC_C` 0.0010, `INSURANCE_WAR_STRIKES_RATE` 0.0005, `INSURANCE_TAX_RATE` 0.05, `INSURANCE_ISSUANCE_FEE` 15, `INSURANCE_MIN_PREMIUM` 30, `INSURANCE_MARKUP` 0.10.
  - Demurrage: `DD_DEFAULT_DEMURRAGE_TIERS` and `DD_DEFAULT_DETENTION_TIERS` as JSON (a JSON getter is needed), `DD_DEFAULT_FREE_DAYS_DEMURRAGE` 14, `DD_DEFAULT_FREE_DAYS_DETENTION` 7, `DD_DEFAULT_STORAGE_FREE_DAYS` 5, `DD_DEFAULT_STORAGE_RATE_EGP` 250, `DD_STANDARD_FREE_DAYS` 14, `DD_AVOIDANCE_RATE_USD` 70.
- **Enum codes**: none this wave. Statuses stay legacy labels, validated as whitelists. T3 codes are deferred.
- **Message codes**: none required. `MANUAL_CHECK_REQUIRED` is a checklist `details` value, not a catalog code.

## 6. Deferred (needs schema change or migration, not in this wave)

- `created_by` and `updated_by` on `shipment_bookings`.
- Stored detention and storage free days plus the agreement date (BK-02), instead of the invented 7/5.
- T3 status codes for booking, cargo shipping, insurance and demurrage.
- FKs instead of free text for carrier, port and insurer names.
- An indexed container table for the CS reuse check.

## 7. Open CTO questions (safe default in brackets)

- Q1: Insurance permission codes. [New codes, granted like freight booking]
- Q2: A dedicated `cargo_shipping.approve` for level 2. [Yes]
- Q3: Is insurance tax 5% a real configured rate? [Parameter seeded at 0.05]
- Q4: Savings engine: compare freight charges only? [Keep and pin]
- Q5: Keep generating `policy_number` when it is empty? [Keep]
- Q6: Must the L2 approver differ from L1? [No block, log only]
- Q7: Lifecycle STEP_08 only when every container is gated in? [Keep `True`]
- Q8: Shipment update notes: append or overwrite? [Append]
- Q9: Recalculate trackings already pushed to settlement? [Skip and report]
- Q10: EIR without a tracking session: block? [404]
- Q11: The last free day: WARNING or OVERDUE? [Keep current until decided]
- Q12: FX rate type for demurrage (customs or bank)? [Bank/commercial rate at discharge date]
- Q13: Per-container policy resolution? [Backlog]

## 8. Not audited

- Flutter screens and dialogs line by line (the 4.1k, 3.9k, 2.3k, 1.9k and 1.4k-line files): grep sweeps only.
- The cargo_shipping and shipment_updates providers.
- The repositories, schemas and models of cargo_shipping, shipment_updates and demurrage_detention beyond the greps.
- Frontend test coverage.
- The lifecycle_board functions called from these modules.
