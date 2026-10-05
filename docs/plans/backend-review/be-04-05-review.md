# Phases 04-05 (Freight booking + Cargo shipping): backend review

Status: 2026-10-05, static review only (grep/read). No pytest, no `import main`, no DB access, no code edits.
Baseline: `docs/plans/phase-04-05-quality-plan.md` (wave 1, marked "done" in `docs/plans/review-coverage.md`, commit `1f32ec2`).
Items of that plan that are verifiably fixed in the current code are not re-reported. Items still open are tagged "still open from <id>".

| File | Lines | Depth |
|---|---|---|
| `modules/freight_booking/{router,service,repository,validators,schemas,model}.py` | 1,263 | all read line by line |
| `modules/cargo_insurance/{router,service,repository,validators,schemas,model}.py` | 913 | all read line by line |
| `modules/cargo_shipping/{router,service,repository,validators,schemas,model}.py` | 1,409 | all read line by line |
| `modules/shipment_updates/{router,service,repository,validators,schemas,model}.py` | 587 | all read line by line |
| `modules/demurrage_detention/{router,service,repository,validators,schemas,model}.py` | 2,523 | all read line by line (service 1-1665) |
| Cross-checks | ~120 | `financial_settlement/service.py:1396-1465` (how bookings / insurance reach landed cost), `common/{legacy_rows,errors,sequence_generator,system_parameters}.py`, `auth/seed_rbac.py` permission codes, `customs_tariff/service.py:1385-1395`, Flutter `freight_booking_cost_row.dart`, `freight_booking_confirm_dialog.dart`, `freight_booking_model.dart` |

Verified fixed since wave 1 (not re-reported): FB-01/INS-01/CS-01/SU-01/DD-01 permissions (every route has `require_permission`, codes exist in `seed_rbac.py`), FB-02 status guards, FB-03 single core commit + `best_effort`, FB-04/INS-03/CS-09 code/DD-15 code generators (`next_yearly_code` + retry), FB-05, FB-07 owner from session, INS-02 rates from `system_parameters`, INS-04, INS-06, CS-02, CS-03, CS-04 (backend), CS-05, CS-06, CS-07, SU-02, SU-03, SU-04, SU-06, DD-02, DD-03, DD-04, DD-05, DD-06, DD-07, DD-09, DD-11.

---

## 1. Summary

| Severity | Count |
|---|---|
| BLOCKER | 3 |
| CRITICAL | 3 |
| MAJOR | 18 |
| MINOR | 7 |

Top points:
1. **Freight cost mixes currencies (BLOCKER).** `total_freight_cost_usd` adds every charge's `rate x qty` regardless of its `currency`. The Flutter cost row offers USD/EUR/EGP/GBP/CNY, and `financial_settlement` multiplies the total by the USD rate. A 4,000 EGP THC becomes 4,000 USD = 200,000 EGP in landed cost.
2. **Demurrage push writes stale totals (BLOCKER).** `push-to-settlement` copies the totals stored at the last save. It never recalculates to today, so a tracking created on discharge day and pushed 20 days later posts 0.
3. **Settlement rows rewritten without the settlement permission (BLOCKER).** Push requires `financial_settlement.calculate`, but PUT tracking, PATCH container, BK-02 and EIR re-push the rows of an already-pushed tracking with only `demurrage_detention.manage`. That includes a new user-typed `exchange_rate`.
4. **Invented 14 free days (CRITICAL).** The booking schema defaults `free_demurrage_days` to 14, `/confirm` overwrites the agreed days with 14 when the field is omitted, and the demurrage engine lets the booking value override the carrier policy.
5. **Double counting in landed cost (CRITICAL).** Nothing stops several active insurance certificates per file (drafts included, all summed by the settlement), or several active demurrage trackings per file (each pushed with its own invoice numbers).

---

## 2. Findings

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| BE45-F01 | BLOCKER | `modules/freight_booking/service.py:68-90`, `schemas.py:20`; consumer `modules/financial_settlement/service.py:1401-1405`; FE `frontend/lib/features/freight_booking/widgets/freight_booking_cost_row.dart:36-43` | Charges are summed into `total_freight_cost_usd` whatever their `currency` (free text). The settlement converts that total as USD at the confirmation-date rate. EUR/EGP/GBP/CNY charges are booked as USD | Convert each charge to USD with the commercial rate at the booking confirmation date (today when not confirmed). Store `fx_rate_to_usd` and `amount_usd` per charge. Validate the currency against the currencies master. 409 when a rate is missing (BE45-T01) |
| BE45-F02 | BLOCKER | `modules/demurrage_detention/service.py:729-787` (push), `:194-224` (`_settlement_rows`), `:855,886` (dual clock) | Push writes `tracking.total_*` from the last save without recalculating. Open containers keep accruing, so the settlement gets understated charges (0 when the tracking was never edited after creation on discharge day). The dual clock shows the same stale accrued amounts next to live day counts | Recalculate the tracking (today as calculation date) inside the push transaction before writing rows. The dual clock uses a live recalculation (BE45-T02) |
| BE45-F03 | BLOCKER | `modules/demurrage_detention/service.py:240-254` called from `:717`, `:983`, `:1086`, `:1525`; permission check only at `:738-744`; routers `router.py:118-120,137-149,156-158,183-194` | An already-pushed tracking is re-pushed into the settlement by PUT tracking (which also accepts a new `exchange_rate`), PATCH container, BK-02 and EIR. These routes need only `demurrage_detention.manage`, not `financial_settlement.calculate`, so the settlement permission can be bypassed | Before any recalculation of a pushed tracking, require `financial_settlement.calculate` from the logged-in user (403 Arabic). Routers pass `actor=current_user` (BE45-T03) |
| BE45-F04 | CRITICAL | `modules/freight_booking/schemas.py:48,116`, `model.py:50`, `service.py:232-233,475-476`; `modules/demurrage_detention/service.py:143-171` | `free_demurrage_days` defaults to 14 (invented) on create and on `/confirm`. A re-confirm without the field overwrites the BK-02 agreed days (for example 21) and `import_file.target_free_days` with 14. The demurrage engine uses the booking value over the carrier policy (`_agreed_tariff`), so a 21-day policy is priced with 14. There is no `ge=0`: -3 is accepted and truthy, which adds overdue days. 0 agreed days is ignored (`if booking_free_days:`) | `Optional[int] = Field(None, ge=0)` everywhere. `/confirm` overwrites only when the field is sent. The response field becomes `Optional[int]`. The engine uses `is not None` (BE45-T04) |
| BE45-F05 | CRITICAL | `modules/cargo_insurance/service.py:147-231`; consumer `modules/financial_settlement/service.py:1430-1445` | Any number of active certificates per import file is allowed. The settlement sums `total_payable_premium` of every active certificate, DRAFT included, as PAID. A draft plus its re-issued copy doubles the insurance in landed cost | 409 on create when the file already has an active certificate that is not CANCELLED. Settlement: count ISSUED only (shared need, Q2) (BE45-T05) |
| BE45-F06 | CRITICAL | `modules/demurrage_detention/service.py:617-672` (create), `:1452-1455` (EIR `.first()`), `schemas.py:63-64` | No guard against several active trackings for the same file or B/L. Each push writes rows `INV-DND-<own code>`, so the charges are doubled. EIR updates an arbitrary one. `import_file_id` is not checked (exists, active), and `import_file_code` is taken from the client | 409 when the file (or the B/L when there is no file) already has an active tracking. `require_active(ImportFile)`. The code is read from the DB. EIR returns 409 when more than one active tracking exists (BE45-T06) |
| BE45-F07 | MAJOR | `modules/demurrage_detention/schemas.py:31-42`, `service.py:590-602`, `repository.py:16-23,51-57` | Policy PUT has no constraints: negative free days and a negative `port_storage_daily_rate_egp` are stored, and a negative storage fee reduces landed cost. `demurrage_tiers: []` bypasses validation. Carrier + container type is not unique, and `get_policy_for_carrier_container().first()` picks an arbitrary duplicate | `ge=0` on the update fields. Validate tiers whenever the key is sent. 409 on a duplicate active carrier + type (create, update, reactivate) (BE45-T07) |
| BE45-F08 | MAJOR | `modules/cargo_insurance/schemas.py:62,101`, `validators.py:51-78`; consumer `financial_settlement/service.py:1441-1442` | `exchange_rate` has no `gt=0` on create or update. A 0, negative or wrong rate is used as-is by the settlement (any value != 1.0) and gives a negative or garbage EGP premium | `Field(None, gt=0)`. Do not store an invented 1.0 (Q3) (BE45-T08) |
| BE45-F09 | MAJOR | `modules/demurrage_detention/service.py:1502-1507`, `schemas.py:328-329`, `:194-224` | The EIR damage fee is written to the container JSON but never reaches the totals or the settlement. `damage_currency` is dropped. The repair cost is lost from landed cost | Store `damage_fee` + `damage_currency` per container. The settlement rows get a `INV-DMG-<code>` row when the sum > 0 (Q4) (BE45-T09) |
| BE45-F10 | MAJOR | `modules/demurrage_detention/service.py:1549-1560`; `modules/freight_booking/service.py:585` | Inside the core transaction, EIR forces the file to `STEP_20` and the departure forces `current_module = "STEP_08 In-Transit On Water"`, with no "already past this step" guard. A late EIR or B/L registration moves a file at STEP_21 or STEP_13 backwards | Apply only when the file is not past the target step (reuse `_file_past_step` from `freight_booking/service.py:213-222`) (BE45-T10, BE45-T11) |
| BE45-F11 | MAJOR | `modules/freight_booking/service.py:437-457`, `schemas.py:72-107`, `repository.py:104-116` | A Sailed or Cancelled booking stays fully editable: costs, dates and `import_file_id`. PUT `{"bill_of_lading_no": null}` clears the B/L of a Sailed booking (the column is nullable), and PUT can set `atd` without `/depart` | 409 for edits on Cancelled. On Sailed, only `notes`, `revised eta`, `vessel_name` and `voyage_number` may change. `bill_of_lading_no`, `atd` and `import_file_id` are locked once Confirmed/Sailed (BE45-T12) |
| BE45-F12 | MAJOR | `modules/cargo_shipping/service.py:216-301,472-500`, `repository.py:93-126` | After Dual Approved, CargoX Transfer Completed or Completed, PUT, the container loading PATCH and the LCL POST still rewrite containers, seals and weights. The approved and transferred documents change silently, without re-approval | 409 on container, seal or weight changes when status rank >= Dual Approved. Before that, a change after a level-1 approval resets the approvals to Pending (Q5) (BE45-T13) |
| BE45-F13 | MAJOR | `modules/cargo_shipping/service.py:408-412` | The CargoX rule "Bill of Lading & Container List Match" passes only when `containers_loading_data` is not empty. LCL and Air shipments can never pass the checklist, so they never reach Uploaded or Completed | The rule depends on `shipment_type`: FCL needs containers with seal numbers; LCL needs `lcl_tracking_data.port_gate_in_at`; Air passes with details `NOT_APPLICABLE` (BE45-T13) |
| BE45-F14 | MAJOR | `modules/shipment_updates/service.py:65-67`, `schemas.py:34-35,56`; consumer `modules/customs_tariff/service.py:1387-1388` | "Phase Cost Adjustment" overwrites `import_file.estimated_cost` (used as the customs estimate base) from a log entry. It has no currency (the file's `estimated_cost_currency` is assumed), `previous_cost` comes from the client, and PUT or DELETE of the log never re-syncs or reverts the file. `new_cost` has no `ge=0` | `previous_cost` is read from the file. Require `new_cost > 0`. PUT may not change `new_cost` on a cost-adjustment log (409). Soft delete of the latest cost-adjustment log restores `previous_cost` (Q6) (BE45-T14) |
| BE45-F15 | MAJOR | `freight_booking/repository.py:78-101` + `router.py:39-52`; `cargo_shipping/repository.py:29-49` + `router.py:51-60`; `shipment_updates/repository.py:53-82` + `router.py:38-57`; `demurrage_detention/repository.py:26-38,86-101` + `router.py:68-75,102-110`; radar `service.py:1244-1278` | The booking, cargo shipping and shipment update lists are unbounded. Trackings and policies are silently capped at 100 with no skip and no total. The radar loads every non-"Completed" tracking forever (no code sets "Completed") and calls `default_tariff()` (6 parameter queries) per tracking | `skip`/`limit` (default 200, max 500) and an `X-Total-Count` header on every list. Radar: exclude `All Containers Returned` / `Closed`, and resolve `default_tariff` once per request (BE45-T15, BE45-T16) |
| BE45-F16 | MAJOR | `cargo_shipping/schemas.py:136-170` vs `model.py:39,51,56,61,75,80-84`; `cargo_insurance/schemas.py:123-181`; `shipment_updates/schemas.py:63-72` vs `model.py:36-40`; `demurrage_detention/schemas.py:90-123` vs `model.py:96-106` | List responses are plain `BaseModel` with non-optional `str`/`bool`/`datetime`/`float` on columns that are nullable without `server_default` (`is_crd_validated`, `status`, `owner`, `created_by`, `is_active`, `is_pushed_to_settlement`, `exchange_rate`). `ShipmentUpdateLogResponse` re-applies `note` `min_length=2` on read. One legacy NULL gives a 500 on the whole list | `LegacyRowTolerantModel` + `@read_model`. Money/rate fields become `Optional[float]` (BE45-T17) |
| BE45-F17 | MAJOR | `modules/freight_booking/schemas.py:121-127`, `service.py:525-571` | `/depart` accepts `shipped_on_board_date` and discards it (no column). ATD is not checked against ETD, the booking request date or today (a 2027 typo is accepted and drives `departure_delay_days` and the warehouse ETA) | Add a nullable `shipped_on_board_date` column through a migration. 422 when ATD is in the future or before the booking request date (BE45-T11) |
| BE45-F18 | MAJOR | `cargo_insurance/schemas.py:80` + `model.py:67` (still open from INS-05: `claims_payable_at="Cairo, Egypt"`); `demurrage_detention/schemas.py:17-21` (policy 14/7/5/250 bypass `system_parameters`), `:59` (container type "40ft High Cube" drives policy match), `:68` + `model.py:79` ("Alexandria Port"), `service.py:1547` ("Carrier Depot"), `:1189,1217-1218` (still open from DD-13: "Carrier" + default detention/storage days); models `freight_booking/model.py:73`, `cargo_shipping/model.py:76`, `shipment_updates/model.py:34` ("Kamal") | Invented business data is stored or returned when the field is missing | Required or null as listed in BE45-T18. Policy create without a value takes the `system_parameters` default explicitly (not a schema literal) |
| BE45-F19 | MAJOR | `modules/freight_booking/schemas.py:72-107`, `repository.py:16-68`; `cargo_insurance/schemas.py:47-49`; `freight_booking/schemas.py:20,37,54` | `ShipmentBookingUpdate` cannot change `freight_forwarder_id`, `shipping_line_id`, `pol_location_id` or `pod_location_id`, only the free-text names, so name and FK drift apart. FK ids are never checked (SQLite `PRAGMA foreign_keys` is not enabled in `database/database.py:44-53`). `shipment_type`, `freight_terms` and the charge `currency` are free text | Accept the FK ids on update. Validate them (active provider / location) and derive the name from the master row when an id is sent. `Literal` whitelists for `shipment_type` and `freight_terms` (BE45-T19) |
| BE45-F20 | MAJOR | `modules/freight_booking/service.py:131-142` | Still open from FB-06: the savings engine matches charge types by substring (`"40" in c_type`), so "THC 40HC" is compared with the ocean-freight 40ft quote | Pending Q4 of wave 1; keep pinned (BE45-T20) |
| BE45-F21 | MAJOR | `modules/freight_booking/model.py:80-81` | Still open from FB-07/§6: `shipment_bookings` has no `created_by`/`updated_by` columns | Alembic migration with nullable columns + backfill from `owner`; the service writes them (BE45-T21) |
| BE45-F22 | MAJOR | `modules/cargo_insurance/service.py:309-332` | `/issue` issues a certificate with no insurer (`insurance_company_id` and name both null) and with `insured_value = 0` | 422 Arabic when the insurer is missing or `insured_value <= 0` (BE45-T08) |
| BE45-F23 | MAJOR | `modules/demurrage_detention/validators.py:34-56`, `schemas.py:323` | Gate-out and empty-return dates may be in the future. `empty_return_date` defaults to today (invented date). Detention is then computed up to a future date, or the clocks stop early | 422 when gate-out or return > today (Africa/Cairo). `empty_return_date` becomes required (BE45-T10) |
| BE45-F24 | MAJOR | `modules/demurrage_detention/service.py:839-843,1341` | Still open from DD-08 (Q11): the dual clock and the radar flag OVERDUE on the last free day, while the engine charges from day free + 1 | Wait for the CTO decision (Q7 below), then OVERDUE only when `consumed > free` (BE45-T22) |
| BE45-F25 | MINOR | `modules/shipment_updates/repository.py:96,109`, `router.py:83-89,116-121` | Commits inside the repository. 404 mapping in the router | Repository flushes. The service commits and raises `not_found` (BE45-T14) |
| BE45-F26 | MINOR | `modules/cargo_insurance/service.py:70-79`, `schemas.py:20,73,111` | Rates are loaded without bounds (a misconfigured `INSURANCE_TAX_RATE=5` reads as 500%). `tax_rate` input has no `le=1` | `min_value=0, max_value=1` for rates and `le=1.0` on inputs (BE45-T08) |
| BE45-F27 | MINOR | `cargo_insurance/router.py:121-132`; `shipment_updates/router.py:106-121`; `demurrage_detention/repository.py:120` (unused) | Soft delete without restore (insurance, shipment updates). Trackings have no delete or restore endpoint at all | Add `PATCH /{id}/restore`, plus `DELETE /trackings/{id}` with a guard for pushed trackings (BE45-T23) |
| BE45-F28 | MINOR | `modules/demurrage_detention/service.py:1039-1041,1153` | The BK-02 response and notification report the default-tariff detention and storage days, not the file's policy values | Use `_tracking_tariff` of the file's tracking when one exists (BE45-T22) |
| BE45-F29 | MINOR | `modules/cargo_shipping/service.py:130-186,472-500` | `booking_id` is not checked to be active and to belong to the same `import_file_id` | 422 Arabic when it does not match (BE45-T13) |
| BE45-F30 | MINOR | `modules/cargo_shipping/service.py:108-118` | Still open from CS-06/Q7: the allocation step is reported final on every save, even with 0 containers | Pending the CTO answer (Q8) |
| BE45-F31 | MINOR | `modules/freight_booking/service.py:238-242` | Every save, Draft included, overwrites `import_file.selected_scenario` with "Confirmed booking: ..." (English text, wrong for a draft) | Write it only from `/confirm` (BE45-T11) |

---

## 3. Tasks

Conventions for every task:
- Every probe or test uses a scratch `DATABASE_PATH`. Never touch `*.db` or `.env`.
- Read results from `--junitxml` and the exit code.
- Arabic `detail` for user-facing errors.
- A new coded error goes to `docs/plans/review-shared-needs.md` when the system-message files are not yours.

### BE45-T01: Currency-aware freight totals
- Severity: BLOCKER (F01)
- Depends on: none
- Schema/migration needed: no (charge items live in the JSON column `cost_charges_data`).
- API contract change: yes, additive. Each `cost_charges_data[]` item in the response gains `fx_rate_to_usd: float` and `amount_usd: float`. A currency that is unknown or has no rate returns 409. Flutter consumers: `frontend/lib/features/freight_booking/models/freight_booking_model.dart` (charge model, `toJson` must keep sending `currency`) and `widgets/freight_booking_cost_row.dart`.
- Files to change: `modules/freight_booking/service.py`, `modules/freight_booking/validators.py`, `modules/freight_booking/schemas.py`, `tests/unit/test_be45_freight_currency.py`
- Steps:
  1. In `validators.py`, add `validate_charge_currencies(db, charges)`. Each `currency` (upper-cased) must exist in the currencies master (`modules/currencies/repository.CurrencyRepository.get_currency_by_code`); otherwise 422 "عملة البند غير معروفة: <code>".
  2. In `service.calculate_transit_time_and_costs` (lines 67-90), compute per charge `item_total = rate * calc_qty` (as today). Then:
     - `fx_rate_to_usd = 1.0` for USD;
     - for any other currency, `rate_to_egp(ccy) / rate_to_egp(USD)`, using the commercial rate at `booking.booking_confirmation_date.date()`, or `date.today()` when the booking is not confirmed. Use the same lookup as `demurrage_detention/service.py:_resolve_exchange_rate`: EGP = 1.0, 409 when a rate is missing.
     - Store `c_dict["fx_rate_to_usd"]` and `c_dict["amount_usd"] = round(item_total * fx_rate_to_usd, 2)`.
     - `total_cost += amount_usd`.
  3. `calculate_transit_time_and_costs` needs `db`. All callers already pass `db=db` (`service.py:406,449,480,517,552`).
  4. In `schemas.BookingChargeItem`, add `fx_rate_to_usd: Optional[float] = None` and `amount_usd: Optional[float] = None` (server-computed; ignore client values: overwrite them in step 2).
  5. Run `validate_charge_currencies` in create and update (before computing).
- Acceptance criteria:
  - A booking with only USD charges keeps byte-identical totals (characterization test `test_phase04_05_characterization.py` stays green).
  - Mixed currencies give the USD total of the converted charges.
  - Unknown currency gives 422. A missing rate gives 409.
- Tests to add: `tests/unit/test_be45_freight_currency.py`
  - Seed USD commercial rate 50.0 and EGP. Two containers 40HC.
  - Charges: "Sea Freight" Per Container rate 1500 USD, and "THC" Per Shipment qty 1 rate 4000 EGP.
  - Expected: sea freight `amount_usd` 3000.00. THC `fx_rate_to_usd` = 1/50 = 0.02 and `amount_usd` 80.00. `total_freight_cost_usd` = 3080.00 (today's code gives 7000.00).
  - EUR at 55.0 EGP with USD at 50.0: a 1000 EUR charge gives `amount_usd` 1100.00.
  - Currency "XYZ" gives 422. EUR with no rate row gives 409.
- Out of scope: changing `financial_settlement` (it keeps reading `total_freight_cost_usd`), and the savings engine (T20).

### BE45-T02: Recalculate before pushing demurrage, live dual clock
- Severity: BLOCKER (F02)
- Depends on: BE45-T03 (same function, do T03 first or in the same PR)
- Schema/migration needed: no
- API contract change: yes, additive. The push response gains `is_provisional: bool` (true when at least one container has no empty-return date). Flutter consumer: `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart` (push call; it may ignore the field).
- Files to change: `modules/demurrage_detention/service.py`, `tests/unit/test_be45_demurrage_push.py`
- Steps:
  1. In `push_demurrage_to_financial_settlement_service` (`service.py:729-818`), after `_tracking_rate(tracking)`, recalculate:
     - `tariff = _tracking_tariff(db, tracking)`;
     - `containers, dem, det, stor = _recalculate_containers(tracking, tariff, rate, tracking.gate_out_date, tracking.empty_return_date)`;
     - `_apply_totals(...)`, and keep the computed status (do not set "Closed").
  2. Then write the rows (`_write_settlement_rows`) from the fresh totals. Still one commit.
  3. `is_provisional = not all(c.get("empty_return_date") for c in tracking.containers)`. Add it to the response.
  4. In `get_dual_clock_status_service` (`:826-911`), compute `accrued_demurrage_fx` and `accrued_storage_egp` from a live recalculation (no write, no commit) instead of `tracking.total_*`.
- Acceptance criteria:
  - The pushed carrier row equals the engine result at the push date.
  - The tracking totals in the DB equal the pushed rows.
  - The dual clock accrued values equal a fresh simulation.
- Tests to add: `tests/unit/test_be45_demurrage_push.py`. Freeze today with monkeypatch on `service.date`, or pass the calculation date through a seam.
  - Tracking: discharge 2026-09-01, 1 container 40HC, no policy (default tiers 40/70/120, 14 free days, storage 5 free days at 250 EGP), rate 50.0. It is created while today = 2026-09-01, so the stored totals are 0.
  - Push with today = 2026-09-21: consumed 20, overdue 6, demurrage 6 x 40 = 240.00 USD; storage (20-5) x 250 = 3750.00 EGP.
  - Carrier row `amount_fx` 240.00 and `amount_egp` 12000.00. Storage row 3750.00. `is_provisional` true. Today's code pushes 0.00.
- Out of scope: blocking provisional pushes (Q1).

### BE45-T03: Settlement permission on every re-push
- Severity: BLOCKER (F03)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. New 403 on PUT `/trackings/{id}`, PATCH `/trackings/{id}/containers/{no}`, POST `/free-days-agreement` and POST `/empty-container-return` when the user lacks `financial_settlement.calculate` **and** an affected tracking is already pushed. Flutter consumers show the 403 detail through `ApiErrorText`: `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart` and `frontend/lib/features/demurrage_detention/widgets/free_days_agreement_dialog.dart`.
- Files to change: `modules/demurrage_detention/router.py`, `modules/demurrage_detention/service.py`, `tests/unit/test_be45_demurrage_repush_permission.py`
- Steps:
  1. In `service.py`, extract the check at lines 738-744 into `_require_settlement_permission(db, actor)`.
  2. Add an `actor: Any = None` parameter to `recalculate_and_update_tracking_service`, `update_single_container_service`, `register_free_days_agreement_service` and `record_empty_container_return_service`.
  3. In each, before any change, when `actor is not None` and any target tracking has `is_pushed_to_settlement`, call `_require_settlement_permission`. For BK-02 that is all active trackings of the file; for EIR it is the file's tracking.
  4. The routers pass `actor=current_user`.
- Acceptance criteria:
  - A user with `demurrage_detention.manage` but without `financial_settlement.calculate` gets 403 on PUT of a pushed tracking, and nothing changes in the tracking or the settlement.
  - The same user can still edit a non-pushed tracking.
- Tests to add: `tests/unit/test_be45_demurrage_repush_permission.py`. Seam: `ALLOW_DEV_AUTH_BYPASS=False` and a role with only `demurrage_detention.*`. Cases: PUT pushed gives 403, PUT non-pushed gives 200, EIR on a pushed tracking gives 403.
- Out of scope: changing role grants in `seed_rbac.py`.

### BE45-T04: No invented free days on the booking
- Severity: CRITICAL (F04)
- Depends on: none
- Schema/migration needed: no. The column is already nullable. Remove the Python `default=14` from `model.py:50`; no DDL change.
- API contract change: yes.
  - Request: `free_demurrage_days` is optional (null = not agreed yet) and must be >= 0. `/confirm` changes it only when it is sent.
  - Response: `free_demurrage_days: int | null` (before: always int, 14 on legacy NULL).
  - Flutter: `frontend/lib/features/freight_booking/models/freight_booking_model.dart:278` (drop `?? 14`, keep null) and `widgets/freight_booking_confirm_dialog.dart:92` (send the key only when the field is filled; drop `?? 14`).
- Files to change: `modules/freight_booking/schemas.py`, `modules/freight_booking/model.py`, `modules/freight_booking/service.py`, `modules/demurrage_detention/service.py`, `tests/unit/test_be45_free_days.py`
- Steps:
  1. `schemas.py:48`: `free_demurrage_days: Optional[int] = Field(None, ge=0)`.
  2. `schemas.py:90`: add `ge=0` to the update field.
  3. `schemas.py:116`: `Optional[int] = Field(None, ge=0)`.
  4. `ShipmentBookingResponse`: declare `free_demurrage_days: Optional[int] = None`.
  5. `model.py:50`: remove `default=14`.
  6. `service.py:475`: `if "free_demurrage_days" in payload.model_fields_set and payload.free_demurrage_days is not None:`.
  7. `service.py:232`: `if booking.free_demurrage_days is not None:`.
  8. `service.py:315,347`: message params use `booking.free_demurrage_days` and "N/A" when it is null, never 14.
  9. `demurrage_detention/service.py:158,164`: replace `if booking_free_days:` with `if booking_free_days is not None:` and `not booking_free_days` with `booking_free_days is None`.
- Acceptance criteria:
  - A booking at 21 confirmed via `/confirm` without the field keeps 21, and `target_free_days` stays 21.
  - A new booking without the field stores NULL.
  - A tracking for a file whose booking has NULL uses the policy free days.
  - -1 gives 422.
- Tests to add: `tests/unit/test_be45_free_days.py`.
  - Policy MSC/40HC with 21 free days. Booking created without free days. Tracking discharge 2026-09-01 with gate-out 2026-09-23 (22 days consumed): overdue = 22 - 21 = 1, demurrage 40.00. Today's code: 22 - 14 = 8 overdue = 7x40 + 1x70 = 350.00.
  - A re-confirm without the field keeps 21.
  - Agreed 0 days applies 0 (not the policy).
- Out of scope: the BK-02 response (T22).

### BE45-T05: One active insurance certificate per file
- Severity: CRITICAL (F05)
- Depends on: none (the settlement-side filter is a shared need, Q2)
- Schema/migration needed: no
- API contract change: yes. New 409 on `POST /api/v1/cargo-insurance/certificates` with detail "يوجد بالفعل وثيقة تأمين نشطة لهذا الملف (<code>)". Flutter consumer: `frontend/lib/features/cargo_insurance/providers/cargo_insurance_provider.dart` (show the detail).
- Files to change: `modules/cargo_insurance/validators.py`, `modules/cargo_insurance/repository.py`, `modules/cargo_insurance/service.py`, `tests/unit/test_be45_insurance_unique.py`, `docs/plans/review-shared-needs.md` (append the settlement filter request)
- Steps:
  1. `repository.get_active_for_file(import_file_id)` returns the active certificate with `status != "CANCELLED"`.
  2. In the validator `validate_no_active_certificate_for_file(existing)`, return 409.
  3. Call it in `create_certificate` when `import_file_id` is set.
  4. Append to `review-shared-needs.md`: "financial_settlement/service.py:1431 must count `status == 'ISSUED'` certificates only".
- Acceptance criteria: a second create for the same file gives 409. Create is allowed after the first certificate is soft-deleted.
- Tests to add: `tests/unit/test_be45_insurance_unique.py` covers both cases. Money example for the shared need: two drafts at `total_payable_premium` 47.25 USD each, rate 50, give settlement insurance 4725.00 EGP today; the expected value is 2362.50.
- Out of scope: a cancel endpoint, and editing `financial_settlement`.

### BE45-T06: One active demurrage tracking per file
- Severity: CRITICAL (F06)
- Depends on: none
- Schema/migration needed: no (app-level guard; a DB partial unique index is deferred)
- API contract change: yes. New 409 on POST `/trackings`, and 404 when the file is missing or inactive. `import_file_code` in the request is ignored (deprecated). Flutter consumer: `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart`.
- Files to change: `modules/demurrage_detention/validators.py`, `modules/demurrage_detention/repository.py`, `modules/demurrage_detention/service.py`, `tests/unit/test_be45_tracking_unique.py`
- Steps:
  1. `repository.get_active_tracking_for_file(file_id)` and `get_active_tracking_for_bl(bl_no)`.
  2. In `create_demurrage_tracking_service`:
     - when `import_file_id` is set, call `require_active(db, ImportFile, id, "ملف الاستيراد", status_code=404)`, and set `import_file_code = file.custom_file_number or file.import_file_code`;
     - 409 when an active tracking exists for the file, or for the B/L when there is no file.
  3. In `record_empty_container_return_service`: query all active trackings of the file and return 409 when there is more than one.
- Acceptance criteria: a second tracking for the same file gives 409. A tracking for an inactive file gives 404. The stored code comes from the DB.
- Tests to add: `tests/unit/test_be45_tracking_unique.py` covers both cases plus the client-sent `import_file_code` "FAKE" being ignored.
- Out of scope: merging existing duplicate rows (report them with a one-off query in the PR description).

### BE45-T07: Demurrage policy validation and uniqueness
- Severity: MAJOR (F07)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. New 422s on PUT `/policies/{id}` for negative values or empty tiers, and 409 on a duplicate active carrier + container type (create, update and `is_active: true`). Flutter consumer: the demurrage policy dialog under `frontend/lib/features/demurrage_detention/`.
- Files to change: `modules/demurrage_detention/schemas.py`, `modules/demurrage_detention/service.py`, `modules/demurrage_detention/repository.py`, `modules/demurrage_detention/validators.py`, `tests/unit/test_be45_policy_validation.py`
- Steps:
  1. `DemurragePolicyUpdate`: add `Field(None, ge=0)` on the 3 free-day fields and on `port_storage_daily_rate_egp`. Add `min_length=2` on carrier and container.
  2. In the service, call `validate_tier_rates` whenever the key is in `model_fields_set`. An empty list gives 422 "يجب إدخال شريحة واحدة على الأقل".
  3. Add `repository.find_active_policy(carrier, type, exclude_id)` (case-insensitive) and a 409 in the validator, on create and update.
- Acceptance criteria: PUT `port_storage_daily_rate_egp=-100` gives 422 and leaves the stored value unchanged. A duplicate gives 409.
- Tests to add: `tests/unit/test_be45_policy_validation.py`. Before the fix, a negative storage rate -100 with 3 overdue days gave a storage fee of -300.00 EGP; that must now be impossible.
- Out of scope: recalculating existing trackings when a policy changes.

### BE45-T08: Insurance input bounds and issue guard
- Severity: MAJOR (F08, F22, F26)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes.
  - `exchange_rate` must be > 0 (422).
  - `tax_rate`, `markup_percentage` and the rate fields must be <= 1.
  - `/issue` returns 422 without an insurer or when `insured_value <= 0`.
  - Flutter: `frontend/lib/features/cargo_insurance/models/cargo_insurance_model.dart:131,186` (stop defaulting and sending 1.0 when the user gave no rate), the cargo_insurance screen.
- Files to change: `modules/cargo_insurance/schemas.py`, `modules/cargo_insurance/validators.py`, `modules/cargo_insurance/service.py`, `tests/unit/test_be45_insurance_bounds.py`
- Steps:
  1. Create: `exchange_rate: Optional[float] = Field(None, gt=0)`. When null, store `1.0` only for USD (Q3); for any other currency keep today's 1.0 sentinel until Q3 is answered.
  2. Update: same field with `gt=0`. Add `le=1.0` on `tax_rate` in the 3 schemas.
  3. In `load_insurance_rates`, pass `min_value=0, max_value=1` for the clause, war, tax and markup rates, and `min_value=0` for the fee and the minimum.
  4. `issue_certificate`: 422 "لا يمكن إصدار الوثيقة بدون شركة التأمين" when both `insurance_company_id` and `insurance_company_name` are empty, and 422 when `insured_value <= 0`.
- Acceptance criteria: as listed in the steps. Premium results are unchanged for valid input.
- Tests to add: `tests/unit/test_be45_insurance_bounds.py`.
  - The parameter `INSURANCE_TAX_RATE` set to "5" falls back to 0.05. Golden case: invoice 10000, freight 1000, ICC_A, war on → cif 11000.00, insured 12100.00, base 30.25, war 6.05, net 36.30, fee 15, tax round(51.30 x 0.05, 2) = 2.57 (2.565 rounds half-even on float, so assert the engine's current value and pin it), total 53.87.
  - `exchange_rate=-50` gives 422. Issue without an insurer gives 422.
- Out of scope: FK validation of `insurance_company_id` (T19 pattern).

### BE45-T09: EIR damage fee into the settlement
- Severity: MAJOR (F09)
- Depends on: BE45-T02, BE45-T03; Q4
- Schema/migration needed: no (container JSON)
- API contract change: yes, additive. `EmptyContainerReturnResponse` gains `damage_currency`. Settlement rows may include `INV-DMG-<tracking_code>`. Flutter: `frontend/lib/features/demurrage_detention/` EIR dialog (send `damage_currency` from a currency SearchableDropdown).
- Files to change: `modules/demurrage_detention/service.py`, `modules/demurrage_detention/schemas.py`, `tests/unit/test_be45_eir_damage.py`
- Steps:
  1. In the EIR, store `c["damage_currency"] = (payload.damage_currency or tracking.currency).upper()` next to `damage_fee`.
  2. In `_settlement_rows`, sum the container damage fees per currency. For each currency with sum > 0, add a row:
     - `invoice_no`: `INV-DMG-<code>` (suffix `-<CCY>` when there is more than one currency);
     - category "Container Damage";
     - rate: the tracking rate when the currency matches the tracking currency, 1.0 for EGP, otherwise `_resolve_exchange_rate(db, ccy, empty_return_date)`. This needs `db`: pass it through `_write_settlement_rows`.
  3. Add the new invoice numbers to `_settlement_invoice_nos` so a re-push replaces them.
- Acceptance criteria: a pushed tracking with a 300 USD damage at tracking rate 50 has a damage row with `amount_egp` 15000.00. A re-push does not duplicate it.
- Tests to add: `tests/unit/test_be45_eir_damage.py` with the example above, plus a re-push idempotency check (exactly 1 damage row).
- Out of scope: a damage-claim workflow with the carrier.

### BE45-T10: Demurrage date sanity and the EIR step guard
- Severity: MAJOR (F23, F10 EIR part)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes. `empty_return_date` becomes required on POST `/empty-container-return` (no default today). New 422 for future gate-out or return dates. Flutter: the EIR dialog and the tracking edit dialog under `frontend/lib/features/demurrage_detention/`.
- Files to change: `modules/demurrage_detention/validators.py`, `modules/demurrage_detention/schemas.py`, `modules/demurrage_detention/service.py`, `tests/unit/test_be45_dd_dates.py`
- Steps:
  1. In `validate_demurrage_dates`, add `today: date` (the Cairo date from the caller: use `modules.common` cairo date helper if one exists, otherwise `datetime.now(ZoneInfo("Africa/Cairo")).date()`). 422 when gate-out or return > today. The simulator (`simulate_demurrage_and_detention`) must NOT get this check: what-if dates are allowed there, so pass `today=None`.
  2. `EmptyContainerReturnSubmit.empty_return_date: date = Field(...)`.
  3. EIR (`service.py:1549-1560`): call `set_file_tracking(step_code="STEP_20")` and bump progress only when the file is not past STEP_20. Reuse a shared `_file_past_step` (copy the 10-line helper from `freight_booking/service.py:210-222` into the demurrage service or `modules/common/file_tracking.py` if you own it).
- Acceptance criteria: an EIR dated tomorrow gives 422. An EIR on a file at STEP_21 leaves `current_step_code` at STEP_21.
- Tests to add: `tests/unit/test_be45_dd_dates.py` covers both cases. The simulator with a future gate-out still returns 200.
- Out of scope: lifecycle_board internals.

### BE45-T11: Departure data and import-file sync
- Severity: MAJOR (F17, F10 departure part, F31)
- Depends on: none
- Schema/migration needed: yes. Alembic migration that adds `shipment_bookings.shipped_on_board_date DATE NULL` (nullable, no backfill: unknown for old rows). Add the column to `model.py`.
- API contract change: yes. The response gains `shipped_on_board_date: date | null`. `/depart` returns 422 when ATD is in the future or before `booking_request_date`. Flutter: `frontend/lib/features/freight_booking/models/freight_booking_model.dart` (read the new field) and the departure dialog.
- Files to change: `alembic/versions/<new>_booking_shipped_on_board_date.py`, `modules/freight_booking/model.py`, `modules/freight_booking/schemas.py`, `modules/freight_booking/service.py`, `tests/unit/test_be45_booking_departure.py`
- Steps:
  1. Migration (down_revision = current head; check `alembic heads`).
  2. Model column.
  3. Response field.
  4. In `confirm_departure_and_bol_service`, store `payload.shipped_on_board_date`. Validate `actual_departure_date.date() <= today` and `>= booking.booking_request_date.date()` when the latter is set.
  5. In `_sync_import_file_on_departure`, filter `ImportFile.is_active == True`. Write `current_module` and the next action only when `not _file_past_step(file_rec, "STEP_08_BL")`.
  6. In `_sync_import_file_with_booking`, write `selected_scenario` only when `tracking_step == "STEP_07"`.
- Acceptance criteria: the date is persisted and returned. A future ATD gives 422. A departure on a file at STEP_13 keeps `current_module`. A draft save does not touch `selected_scenario`.
- Tests to add: `tests/unit/test_be45_booking_departure.py` covers the four cases. Delay example: ETD 2026-09-10, ATD 2026-09-13 → `departure_delay_days` 3; ETA 2026-10-01 + 3 + 7 warehouse days → `expected_warehouse_arrival_date` 2026-10-11.
- Out of scope: lifecycle_board changes.

### BE45-T12: Lock Sailed and Cancelled bookings
- Severity: MAJOR (F11)
- Depends on: BE45-T04 (same files; sequential)
- Schema/migration needed: no
- API contract change: yes. PUT on a Cancelled booking gives 409. On Confirmed/Amended/Sailed, PUT of `bill_of_lading_no`, `atd` or `import_file_id` gives 409, and on Sailed the cost/container fields give 409 as well. The Flutter edit screen must hide or disable these fields: `frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart`.
- Files to change: `modules/freight_booking/validators.py`, `modules/freight_booking/service.py`, `tests/unit/test_be45_booking_lock.py`
- Steps:
  1. In `validators.py`, add `LOCKED_AFTER_CONFIRM = {"bill_of_lading_no", "atd", "import_file_id"}`, `SAILED_EDITABLE = {"notes", "eta", "vessel_name", "voyage_number", "status"}` and `validate_editable_fields(booking, sent_keys)`.
  2. In `update_booking_service`, call it with `payload.model_fields_set` before applying. Keys whose value equals the stored value pass (the screen re-sends everything).
  3. Run `validate_container_allocation` on update when `shipment_type` or `containers_data` is sent.
- Acceptance criteria: as listed. A PUT re-sending the unchanged values of a Sailed booking gives 200.
- Tests to add: `tests/unit/test_be45_booking_lock.py`: PUT `{"bill_of_lading_no": null}` on Sailed gives 409 and the B/L is kept; PUT with costs on Cancelled gives 409; unchanged re-send gives 200.
- Out of scope: an amendment workflow.

### BE45-T13: Cargo shipping approval lock, CargoX rule per shipment type, booking link check
- Severity: MAJOR (F12, F13, F29)
- Depends on: none; Q5
- Schema/migration needed: no
- API contract change: yes.
  - New 409 for container, seal or weight edits at or after Dual Approved.
  - Approvals reset to Pending on edits after level 1 (Q5 default).
  - The checklist BL rule `details` may be `NOT_APPLICABLE`.
  - 422 for a foreign `booking_id`.
  - Flutter: `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart` and `screens/cargo_shipping_screen.dart` (show the 409; refresh after a save).
- Files to change: `modules/cargo_shipping/validators.py`, `modules/cargo_shipping/service.py`, `tests/unit/test_be45_cargo_shipping_lock.py`
- Steps:
  1. In `validators.py`, add `validate_documents_editable(status, code)`: 409 when `_status_rank(status) >= _status_rank(STATUS_DUAL_APPROVED)`.
  2. Call it in `update_cargo_shipping_service` (when `containers_loading_data`, `lcl_tracking_data` or `shipment_type` is sent), `update_container_loading_tracking_service` and `update_lcl_loading_tracking_service`.
  3. Before Dual Approved, when level 1 is Approved and containers or seals change: set `level1_approval_status`, `level2_approval_status` and `dual_approval_status` to "Pending" and append a note to `level1_notes`.
  4. In the checklist (`service.py:408-412`), the rule depends on `record.shipment_type`:
     - FCL: containers present and every container has a `seal_no`;
     - LCL: `lcl_tracking_data.port_gate_in_at` is set;
     - Air: `passed=True` with details "NOT_APPLICABLE".
  5. On create and update, when `booking_id` is set: the booking must exist, be active, and have the same `import_file_id`. Otherwise 422 "الحجز لا يخص نفس ملف الاستيراد".
- Acceptance criteria: as listed.
- Tests to add: `tests/unit/test_be45_cargo_shipping_lock.py`: a PUT of containers on Dual Approved gives 409; an LCL with gate-in passes the BL rule; an FCL container without a seal fails; a booking from another file gives 422.
- Out of scope: a CargoX API integration.

### BE45-T14: Shipment update cost adjustment and transactions
- Severity: MAJOR (F14, F25)
- Depends on: Q6
- Schema/migration needed: no
- API contract change: yes.
  - `previous_cost` in the create request is ignored (the server reads it).
  - `new_cost` must be > 0 for "Phase Cost Adjustment".
  - PUT of `new_cost`/`previous_cost` gives 409.
  - DELETE of the latest cost-adjustment log restores the file cost.
  - Flutter: `frontend/lib/features/shipment_updates/widgets/shipment_update_dialog.dart` (no `previous_cost` input; show the file's current cost read-only).
- Files to change: `modules/shipment_updates/service.py`, `modules/shipment_updates/repository.py`, `modules/shipment_updates/schemas.py`, `modules/shipment_updates/router.py`, `tests/unit/test_be45_shipment_update_cost.py`
- Steps:
  1. Create: for the cost category, `new_cost` is required and > 0 (422). Set `previous_cost = import_file.estimated_cost` (server), then `import_file.estimated_cost = new_cost`.
  2. Repository `update_log_record` and `soft_delete_update_log` only set fields and flush. The service commits.
  3. Update: 409 when `new_cost` or `previous_cost` is in `model_fields_set`.
  4. Soft delete: when the log is a cost adjustment, is the latest active one for the file, and `import_file.estimated_cost == log.new_cost`, restore `previous_cost`. Same transaction.
  5. The router calls the service, which raises `not_found("تحديث الشحنة", id)`. Remove the router-level `HTTPException`.
- Acceptance criteria: a file at 24500.00 adjusted to 26000.00 stores `previous_cost` 24500.00 even when the client sends 1.00; deleting that log restores 24500.00.
- Tests to add: `tests/unit/test_be45_shipment_update_cost.py` with that example, plus PUT `new_cost` giving 409.
- Out of scope: currency conversion of the estimated cost.

### BE45-T15: Pagination for the booking and cargo shipping lists
- Severity: MAJOR (F15)
- Depends on: none
- Schema/migration needed: no
- API contract change: yes, backward compatible.
  - New query params `skip` (>= 0, default 0) and `limit` (1..500, default 200).
  - New response header `X-Total-Count`. The body stays a JSON list.
  - Flutter: `frontend/lib/features/freight_booking/providers/freight_booking_provider.dart` and `frontend/lib/features/cargo_shipping/providers/cargo_shipping_provider.dart` (read the header; add "load more" when total > loaded).
- Files to change: `modules/freight_booking/router.py`, `modules/freight_booking/repository.py`, `modules/cargo_shipping/router.py`, `modules/cargo_shipping/repository.py`, `tests/unit/test_be45_list_paging.py` (service signatures get `skip`/`limit` pass-through: a one-line change each in the two `service.py` files, allowed)
- Steps:
  1. The repository returns `(items, total)` with `count()` before `offset/limit`.
  2. The service passes it through.
  3. The router takes `response: Response`, sets `response.headers["X-Total-Count"] = str(total)` and returns the items.
- Acceptance criteria: with 250 rows, the default call returns 200 rows and the header says 250. `skip=200` returns 50.
- Tests to add: `tests/unit/test_be45_list_paging.py` covers exactly that for both endpoints.
- Out of scope: Flutter changes beyond the providers.

### BE45-T16: Pagination for shipment updates and trackings, radar cost
- Severity: MAJOR (F15)
- Depends on: BE45-T15 (same pattern)
- Schema/migration needed: no
- API contract change: yes, backward compatible.
  - Same `skip`/`limit`/`X-Total-Count` on GET `/shipment-updates`, `/demurrage-detention/trackings` and `/demurrage-detention/policies`. The silent 100 cap is replaced by default 200 / max 500.
  - The radar no longer lists trackings in `All Containers Returned` or `Closed`.
  - Flutter: `frontend/lib/features/shipment_updates/providers/shipment_updates_provider.dart`, `frontend/lib/features/demurrage_detention/providers/demurrage_provider.dart`.
- Files to change: `modules/shipment_updates/router.py`, `modules/shipment_updates/repository.py`, `modules/demurrage_detention/router.py`, `modules/demurrage_detention/repository.py`, `modules/demurrage_detention/service.py` (+ a pass-through line in `shipment_updates/service.py`)
- Steps:
  1. Same as T15.
  2. Radar (`service.py:1244-1249`): filter `DemurrageTracking.status.notin_(["All Containers Returned", "Closed"]) | DemurrageTracking.status.is_(None)`.
  3. Compute `fallback = default_tariff(db)` once. Give `_resolve_tariff` / `_tracking_tariff` an optional `fallback` parameter so the radar loop issues no parameter queries per tracking.
- Acceptance criteria: the paging test passes. The radar runs the system-parameter queries once per request (assert with a query counter or a monkeypatched `get_parameter` call count == 8).
- Tests to add: `tests/unit/test_be45_list_paging_2.py` covers paging plus a radar call count.
- Out of scope: radar UI.

### BE45-T17: Legacy-tolerant response schemas
- Severity: MAJOR (F16)
- Depends on: none
- Schema/migration needed: no
- API contract change: no (fields stay; legacy NULLs read as defaults; money/rate fields may be null).
- Files to change: `modules/cargo_shipping/schemas.py`, `modules/cargo_insurance/schemas.py`, `modules/shipment_updates/schemas.py`, `modules/demurrage_detention/schemas.py`, `tests/unit/test_be45_legacy_rows.py`
- Steps:
  1. Make `CargoShippingResponse`, `CargoInsuranceCertificateResponse`, `ShipmentUpdateLogResponse` and `DemurrageTrackingResponse` inherit `LegacyRowTolerantModel` and decorate them with `@read_model` (see `modules/common/legacy_rows.py`).
  2. Declare money and rate fields `Optional[float] = None`:
     - insurance: all premiums, `exchange_rate`;
     - tracking: `total_*`, `exchange_rate`, `total_cost_egp`;
     - shipment updates: `previous_cost`, `new_cost`.
  3. Give non-money fields declared defaults: `owner: str = ""`, `created_by: str = "System"`, `status: str = ...` as in the model.
- Acceptance criteria: a row inserted by raw SQL with NULL `status`, `created_by`, `is_crd_validated` and `exchange_rate`, and a 1-char note, does not 500 the list.
- Tests to add: `tests/unit/test_be45_legacy_rows.py`, one raw-SQL legacy row per table, list endpoint 200.
- Out of scope: data backfill.

### BE45-T18: Remove invented defaults
- Severity: MAJOR (F18)
- Depends on: BE45-T17
- Schema/migration needed: no (Python defaults only; `server_default` untouched)
- API contract change: yes.
  - Insurance `claims_payable_at` defaults to null.
  - Tracking `port_name` is required, and so is container `container_type`.
  - Policy create without free days or storage rate takes the configured `system_parameters` values (same numbers today).
  - The EIR depot stays null when not sent.
  - GET `/free-days-agreement/{id}` returns `carrier_name: null` when unknown.
  - Flutter: cargo_insurance form, demurrage tracking create dialog (`port_name` and `container_type` required, SearchableDropdown), `free_days_agreement_dialog.dart` (null carrier).
- Files to change: `modules/cargo_insurance/schemas.py`, `modules/cargo_insurance/model.py`, `modules/demurrage_detention/schemas.py`, `modules/demurrage_detention/service.py`, `tests/unit/test_be45_no_invented_defaults.py`
- Steps:
  1. `claims_payable_at: Optional[str] = None` (schema and model `default`).
  2. `port_name: str = Field(..., min_length=2)` and `container_type: str = Field(..., min_length=2)`.
  3. Policy base: `Optional[...] = None` for the 3 free-day fields and the storage rate. The service fills them from `default_tariff(db)` when None.
  4. `service.py:1547`: `imp_file.empty_containers_depot_name = payload.depot_name` (no literal).
  5. `service.py:1189`: `carrier = ... or None`. Make `FreeDaysAgreementResponse.carrier_name: Optional[str]`.
  6. Leave the "Kamal" model defaults to T21's migration PR, or change them to `"system"` here (Python default only).
- Acceptance criteria: no literal "Cairo, Egypt", "Alexandria Port", "Carrier Depot" or "Carrier" is written by these modules (grep).
- Tests to add: `tests/unit/test_be45_no_invented_defaults.py`: tracking create without `port_name` gives 422; a certificate created without `claims_payable_at` stores NULL.
- Out of scope: the master-data FK for ports.

### BE45-T19: Booking FK master data on update
- Severity: MAJOR (F19)
- Depends on: BE45-T12 (same files)
- Schema/migration needed: no
- API contract change: yes, additive.
  - `ShipmentBookingUpdate` accepts `freight_forwarder_id`, `shipping_line_id`, `pol_location_id`, `pod_location_id` and `rfq_request_id`.
  - Unknown or inactive ids give 422.
  - `shipment_type` must be one of `Ocean FCL`, `Ocean LCL` or `Air`; `freight_terms` one of `Prepaid` or `Collect`.
  - Flutter: `freight_booking_form_dialog.dart` (send ids from the SearchableDropdowns), `freight_booking_model.dart`.
- Files to change: `modules/freight_booking/schemas.py`, `modules/freight_booking/validators.py`, `modules/freight_booking/service.py`, `tests/unit/test_be45_booking_fk.py`
- Steps:
  1. Add the id fields to the update schema and `Literal` types (keep create tolerant of legacy values only on read).
  2. `validate_master_refs(db, data)` checks `external_service_providers` (active) and `transport_locations` (active).
  3. When an id is sent and the name is not, set the name from the master row.
- Acceptance criteria: as listed.
- Tests to add: `tests/unit/test_be45_booking_fk.py`: an unknown `shipping_line_id` gives 422; an id-only update fills `shipping_line_name`.
- Out of scope: enabling `PRAGMA foreign_keys` globally (Q9).

### BE45-T20: Savings engine charge matching (blocked)
- Severity: MAJOR (F20, still open from FB-06)
- Depends on: Q4 of wave 1 (still unanswered)
- Schema/migration needed: no
- API contract change: no (values of `cost_savings_usd`, `cost_variance_usd` and `savings_notes` change by design)
- Files to change: `modules/freight_booking/service.py`, `tests/unit/test_phase04_05_characterization.py` (update the pinned case)
- Steps: match only charges whose type is ocean freight (`charge_type` in a whitelist such as "Sea Freight", "Ocean Freight", "Air Freight"), with the container size parsed from the container line, not from a substring of the charge name.
- Acceptance criteria: "THC 40HC" at 300 no longer enters the breakdown. Sea Freight 40HC quoted 1600 and executed 1500 x 2 gives saving 200.00.
- Tests to add: update the pinned characterization case.
- Out of scope: everything else.

### BE45-T21: Audit columns on shipment_bookings
- Severity: MAJOR (F21, still open from FB-07)
- Depends on: none
- Schema/migration needed: yes. Alembic migration that adds `created_by VARCHAR(100) NULL` and `updated_by VARCHAR(100) NULL` to `shipment_bookings`, with a backfill `UPDATE shipment_bookings SET created_by = owner, updated_by = owner WHERE created_by IS NULL`. Change model `owner` `default="Kamal"` to `default="system"`.
- API contract change: yes, additive. The response gains `created_by` and `updated_by` (Optional[str]). Flutter: `freight_booking_model.dart` (optional read).
- Files to change: `alembic/versions/<new>_shipment_bookings_audit.py`, `modules/freight_booking/model.py`, `modules/freight_booking/repository.py`, `modules/freight_booking/schemas.py`, `modules/freight_booking/service.py`
- Steps:
  1. Migration.
  2. Model.
  3. `repo.create_booking(..., user)` sets both columns.
  4. `apply_booking_update` and `set_booking_active` take `user` and set `updated_by`.
  5. Response fields `Optional[str]`.
- Acceptance criteria: create, update, confirm, depart, delete and restore all set `updated_by` to the session user.
- Tests to add: `tests/unit/test_be45_booking_audit.py`, user "ops1" creates and "ops2" confirms → `created_by` "ops1", `updated_by` "ops2".
- Out of scope: other tables.

### BE45-T22: BK-02 response from the policy; last-free-day rule
- Severity: MAJOR (F24) / MINOR (F28)
- Depends on: Q7 for the OVERDUE part. The BK-02 part can be done now.
- Schema/migration needed: no
- API contract change: no (values change: correct detention and storage days; after Q7, status labels on the last free day).
- Files to change: `modules/demurrage_detention/service.py`, `tests/unit/test_be45_bk02_response.py`, `tests/unit/test_phase04_05_characterization.py` (Q7 pin update)
- Steps:
  1. In BK-02 register and GET, when the file has an active tracking, `effective_detention` and `effective_storage` come from `_tracking_tariff(db, tracking)`; otherwise from `default_tariff`.
  2. After Q7: in the dual clock (`:842`) and the radar (`:1341`), OVERDUE only when `consumed > free`.
- Acceptance criteria: a policy with 10 detention days gives `agreed_detention_free_days` 10 when not sent.
- Tests to add: `tests/unit/test_be45_bk02_response.py` covering that case.
- Out of scope: storing agreement detention and storage columns (deferred §6 of wave 1).

### BE45-T23: Restore endpoints
- Severity: MINOR (F27)
- Depends on: BE45-T05, BE45-T06 (uniqueness guards apply on restore)
- Schema/migration needed: no
- API contract change: yes, new endpoints:
  - `PATCH /api/v1/cargo-insurance/certificates/{id}/restore` (`cargo_insurance.manage`);
  - `PATCH /api/v1/shipment-updates/{id}/restore` (`import_files.edit`);
  - `DELETE /api/v1/demurrage-detention/trackings/{id}` and `PATCH .../trackings/{id}/restore` (`demurrage_detention.manage`; delete gives 409 when `is_pushed_to_settlement`).
  - Flutter: the "show deleted / restore" actions in the three features (optional).
- Files to change: `modules/cargo_insurance/{router,service}.py`, `modules/shipment_updates/{router,service}.py`, `modules/demurrage_detention/{router,service}.py` (split into 3 PRs of 2 files + test each)
- Steps: follow `freight_booking.restore_booking_service`. Load with `include_inactive`, run the uniqueness guard, set `is_active=True` and the audit user, then one commit.
- Acceptance criteria: delete → restore round-trip. Restoring when another active row exists gives 409.
- Tests to add: `tests/unit/test_be45_restore.py`.
- Out of scope: hard delete.

---

## 4. Frontend impact

| Backend change | Flutter files | What to follow |
|---|---|---|
| T01 charge `fx_rate_to_usd`, `amount_usd`; 409 missing rate | `features/freight_booking/models/freight_booking_model.dart`, `widgets/freight_booking_cost_row.dart` | Show the USD equivalent per non-USD charge. Show the 409 detail. Never compute totals client-side |
| T02 push `is_provisional` | `features/demurrage_detention/providers/demurrage_provider.dart` | Optional badge "provisional" |
| T03 403 on re-push routes | `demurrage_provider.dart`, `widgets/free_days_agreement_dialog.dart` | Show the backend Arabic detail via `ApiErrorText` |
| T04 `free_demurrage_days` nullable | `freight_booking_model.dart:278,330`, `widgets/freight_booking_confirm_dialog.dart:92` | No `?? 14`. Omit the key when empty |
| T05/T06 409 duplicates | `cargo_insurance_provider.dart`, `demurrage_provider.dart` | SnackBar with the detail |
| T08 `exchange_rate` > 0, issue guard | `features/cargo_insurance/models/cargo_insurance_model.dart:131,186` | Do not default and send 1.0. The rate field is empty and required for non-USD |
| T10 `empty_return_date` required, no future dates | demurrage EIR and tracking dialogs | Required date picker capped at today |
| T11 `shipped_on_board_date` | `freight_booking_model.dart`, departure dialog | New field read/write |
| T12 locked fields | `widgets/freight_booking_form_dialog.dart` | Disable B/L, ATD and file after confirmation. Disable everything except notes, ETA and vessel on Sailed |
| T13 409 after Dual Approved; approvals reset | `features/cargo_shipping/providers/cargo_shipping_provider.dart`, `screens/cargo_shipping_screen.dart` | Read-only containers after approval. Refresh after save |
| T14 `previous_cost` server-side | `features/shipment_updates/widgets/shipment_update_dialog.dart` | Remove the `previous_cost` input |
| T15/T16 `skip`/`limit` + `X-Total-Count` | the 5 feature providers | "Load more" when total > loaded |
| T18 required `port_name` / `container_type`, nullable `carrier_name` / `claims_payable_at` | demurrage create dialog, `free_days_agreement_dialog.dart`, cargo_insurance form | Required SearchableDropdowns. Null-safe display |
| T19 FK ids on update | `freight_booking_form_dialog.dart`, `freight_booking_model.dart` | Send ids from the SearchableDropdowns |
| T21 `created_by` / `updated_by` | `freight_booking_model.dart` | Optional display |
| T23 restore endpoints | insurance, shipment updates, demurrage screens | Optional restore action |

---

## 5. Open questions for the CTO

1. **Q1 (T02):** may demurrage be pushed while containers are still out, as a provisional amount re-pushed later? [Safe default: allow, recalculate at push, flag `is_provisional`]
2. **Q2 (T05):** should the landed-cost settlement count insurance certificates in DRAFT, or ISSUED only? [ISSUED only, change owned by financial_settlement]
3. **Q3 (T08):** which FX rate applies to a non-USD insurance premium: the rate typed on the certificate, or the bank rate at issue date? [Bank rate at issue date when the field is empty, no stored 1.0]
4. **Q4 (T09):** does the container damage fee from the EIR belong in landed cost (separate "Container Damage" row), or is it claimed back from the carrier or insurer? [Separate row in landed cost]
5. **Q5 (T13):** must a change of containers or seals after level-1 approval reset both approvals? [Yes, reset to Pending]
6. **Q6 (T14):** is "Phase Cost Adjustment" allowed to change the file's estimated cost at all, or should it only log? [Allowed, previous cost read server-side, revert on delete]
7. **Q7 (T22, still open from wave-1 Q11):** is the last free day WARNING or OVERDUE on the dual clock and the radar? [Keep OVERDUE until decided]
8. **Q8 (F30, still open from wave-1 Q7):** report the cargo-shipping allocation step final only when every container is gated in? [Keep `True`]
9. **Q9 (T19):** may we enable `PRAGMA foreign_keys=ON` in `database/database.py`? It would make every FK real but may break legacy rows. [Not now: app-level checks per module]
10. **Q10 (wave-1 Q4, T20):** savings engine compares ocean or air freight lines only? [Yes, once confirmed]
