# Phase 9 "Financial Settlement / Landed Cost": quality audit and fix plan

Status: proposed (2026-10-05). Static reading only: no pytest, flutter test, or `import main` was run. Same method and severity scale as `docs/plans/phase-01-quality-simplify-plan.md`. Constraint for this wave: **no schema change, no Alembic migration**.

## Audit coverage

| Area | Depth |
|---|---|
| `modules/financial_settlement/service.py` (2108) | Full, line by line (engine, create/update/recalc, PL-08 simulation, CLO-01 aggregation + confirm, CLO-02 actual + approve) |
| `financial_settlement/router.py`, `validators.py`, `model.py`, `repository.py` | Full |
| `financial_settlement/schemas.py` (375) | l.1-120 full, the rest by grep (status / `_ar` / preference / actor fields) |
| `financial_settlement/odoo_export_service.py` (463) | l.1-300 (journal build, CSV, Excel sheet 1). Excel sheets 2-3 (l.300-463) not audited |
| `modules/recalculation/service.py` (806), `router.py` | Full |
| `recalculation/repository.py`, `schemas.py`, `seed_dependencies.py`, `model.py` | Grep (commits, settlement seeds, contract fields). `model.py` not audited |
| Flutter `financial_settlement` + `recalculation` (8517) | Grep sweeps on all files. Read fully: both providers. Read at the flagged spots: add/clone dialog in `financial_settlement_screen.dart`, the export code in `odoo_journal_entry_dialog.dart`, and `financial_settlement_model.dart` l.1-110 |
| Known 1% WHT item (`service.py:1168`) | **Already resolved** by commits c40574a/274f360: rates come from `tax_rates`. `wht_amount_for` (l.915-918) keeps the old rounding. Invoices marked `wht_deducted` with no rate configured get 409 `WHT_RATE_NOT_CONFIGURED`. Nothing left to do except FS-16 (message codes) |

Severity: **BLOCKER** = breaks a non-negotiable rule, or corrupts money or references. **CRITICAL** = a wrong number or a 500 on a normal path. **MAJOR** = a rule violation or real risk. **MINOR** = hygiene.

## 1. Findings

### 1a. Backend: financial_settlement (FS)

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| FS-01 | BLOCKER | `service.py:1955-1991` | Approve overwrites `expense_invoices` with the **category breakdown** (`category, estimated_egp, actual_egp…`) and `item_landed_costs` with `ActualLandedCostItemLine` keys (`actual_total_landed_cost_egp`, `allocated_customs_duty_egp`…). The manually entered invoices are lost. After that, `/recalculate`, PUT, and `recalculation.apply` run the engine on rows that have no `amount_egp` / `fob_unit_egp`, so the totals drop to FOB-only. The Odoo journal credits 0 for expenses (`odoo_export_service.py:131-136`), and Flutter shows 0 for the unit/total landed cost (`financial_settlement_model.dart:43-44`). | code | Approve stores the aggregated invoices in the `ExpenseInvoiceSchema` shape (invoice_no, category, provider_name, currency, amount_fx, exchange_rate, amount_egp, allocation_rule) plus an additive `bucket` key. Items get the canonical `ItemLandedCostSchema` keys, mapped from the actual line: customs = duty+vat, other = insurance+demurrage+other. The `actual_*` keys are kept additively. The approve response does not change. |
| FS-02 | BLOCKER | `service.py:950,1032,1381,550,1611` | Hard-coded FX: `base_exchange_rate = 48.5` converts commercial invoices, freight (USD), and the estimated-cost fallback. The demurrage fallback is `50.0`. The simulation falls back to `48.5` on **any** exception. The aggregation response reports 48.5 as "the" rate. | code | Use `CurrencyService._get_rate_to_egp(currency, rate_type, on_date)` once per (currency, date). The date is the invoice date, else the booking confirmation date, else Cairo today. When no rate exists, return 409 `CodedHTTPException("SETTLEMENT_FX_RATE_MISSING", currency, on_date)`. Never use a literal. Q2 decides the rate type. |
| FS-03 | BLOCKER | `service.py:340-384`, `schemas.py:44` | Approved settlements are mutable. PUT and `/recalculate` reset `status` to "Calculated" with no check, and PUT accepts any free-text `status` (so "Approved" can be set without approval). | code | `validators.ensure_settlement_editable(record)`: Approved/Closed returns 409 with an Arabic detail. `status` in Update is limited to `Draft`/`Calculated` (otherwise 422). Approval goes only through approve-actual-landed-cost. |
| FS-04 | BLOCKER | `router.py:43-196` | There is no `require_permission` on any route: approve, confirm, delete, and restore are open to any logged-in user. `approved_by`, `settled_by`, and `accountant_name` come from the request body, so the audit trail can be spoofed. `created_by`/`updated_by` are never set ("System"). | code | GET routes, simulate, and both exports use `financial_settlement.view`. Create, PUT, recalculate, delete, restore, confirm, and approve use `financial_settlement.calculate` (both codes already exist in `seed_rbac.py:77-78`). The router passes `current_user.username`. The service uses it for actor fields and audit, and ignores the body values (kept in the schema for compatibility). |
| FS-05 | CRITICAL | `service.py:255-278`, `482-493` | Create reads `POLineItem` attributes that do not exist (`is_active`, `line_item_id`, `item_description`, `unit_price_egp`, `hs_code`). The AttributeError is swallowed, so items are **always empty** and `total_fob_egp = 0`. The simulation reads `itm.cbm` (the column is `total_cbm`), so CBM is always 0 and volume allocation never applies. | `modules/purchase_orders/model.py` POLineItem columns | Map `description_ar/en`, `total_cbm`, `gross_weight_kg`, `tariff.hs_code`, and `unit_price × po.exchange_rate`. Remove the try/except. Behaviour change (intended), listed in §2. |
| FS-06 | BLOCKER | `service.py:474,515,532,1728,1756`, `478-480`, `526`, `1732-1733,1746-1747,1760-1761` | Fabricated data drives money: HS `"8479.89.90"` is invented when a line has no tariff (customs duty estimated on a wrong HS); line value `1000.0` when the total is ≤ 0; `estimated_cost or 10000.0`; 100 kg / 0.5 CBM per line in the actual calculation (this skews weight/volume allocation). | code | No fabrication. A missing HS skips the customs line and adds `messages[] {code: SETTLEMENT_LINE_NO_HS}`. A missing weight or CBM stays 0 (the existing ratio fallback to value applies). A zero value stays 0. |
| FS-07 | MAJOR | `service.py:581,584,605,675-679,1651-1652` | Hard-coded estimate constants: deemed freight 2%, insurance 2.5%, clearance 4500, port 5000, inland 7500, bank 2500, other 2000, and a fixed 40/60 duty/VAT split of the estimate. | code | `system_parameters.get_float_parameter(db, key, <current default>)` with the keys `settlement.deemed_freight_pct`, `…insurance_pct`, `…default_clearance_egp`, and so on. Outputs stay byte-identical while the rows are missing. Replace the 40/60 split with the simulation's own duty and VAT totals (add additive response fields `total_customs_duty_egp` and `total_vat_and_fees_egp`). Q5. |
| FS-08 | CRITICAL | `service.py:1618-1623`, `1716-1719`, `1833-1846` | Header and items do not reconcile. Header FOB = Σ goods invoices at their own rate. Item FOB = PO `total_price × 48.5`, even for EGP POs. Lines are rounded to 2 decimals with no remainder handling, so Σ item landed ≠ header landed. | code | Item FOB = PO total × the PO's rate (EGP = 1). Add an additive `reconciliation_difference_egp` field (header minus Σ items). Line values are not changed (Q6). |
| FS-09 | MAJOR | `service.py:1681-1699` vs `1800-1808` | `custom_category_allocation` and `categories_breakdown[].allocation_rule` only affect the display: allocation uses a fixed mapping (freight by CBM even when the preference is Value, Equal ignored for freight). | code | Safe default: report the rule that is actually used. Q7 decides whether the requested rules should drive allocation. |
| FS-10 | CRITICAL | `service.py:1045-1048,1079-1081,1196,1142-1145,964` | Payment status is fabricated: freight and insurance are always PAID; a "partial" clearance invoice is counted as 50% paid; a delivery order in USD uses rate 1.0 (the FX amount is treated as EGP); commercial invoices count as PAID when the file has a `swift_no`. | code | Delivery order: convert with the FS-02 FX lookup. Partial: use the stored paid amount if the source has one, otherwise add `messages[] PAYMENT_STATUS_UNKNOWN` and count 0 as paid. Freight/insurance/swift: keep as is and ask Q8. |
| FS-11 | MAJOR | `service.py:188,451,945,1474,1594,1935`, `1091-1093`, `1058-1060`; `repository.py:140-148` | Soft-delete leaks: five of the six `ImportFile` lookups skip `is_active` (only create filters). Clearance records and insurance certificates are aggregated without `is_active`. Restore does not check for an existing active settlement on the same file, which allows two active settlements. | code | `validators.require_active(db, ImportFile, id, "ملف الشحنة", status_code=404)`. Filter `is_active` on the two sources. Restore returns 409 if another active settlement exists for the file. |
| FS-12 | MAJOR | `service.py:1478-1484`, `1500-1507` | Confirm trusts client `invoices_overrides` amounts for `financial_settlement_total_egp`. It is not idempotent: every call adds another notification. It closes **every** task whose title contains "فواتير" (titles are English since single-language storage, so this also misses). | code | Close tasks by `task_code` / `step_code="STEP_19"` only. If the file is already INVOICES_SETTLED or later, return 409. `invoices_overrides` is ignored and the server re-aggregates (Q9). |
| FS-13 | MAJOR | `repository.py:85,112,122,146`; `service.py:303,355,366-367`, `1602-1605`, `2069-2082` | Several commits per request: create commits in the repo, then again in the service. Update = repo commit + recalc commit. Lifecycle advance is swallowed **inside** the approve transaction (a failed flush poisons the session, then commit returns 500). `except Exception: sim = None` silently turns the estimate into "estimate = actual". `validators.py` is imported but never called. | code | Repository uses `flush` only and the service commits once. Lifecycle, audit, and notification run after the commit through `errors.best_effort`. The simulation error propagates (or adds `messages[] ESTIMATE_UNAVAILABLE`). Wire `validate_expense_invoice` into create/update. |
| FS-14 | MAJOR | `odoo_export_service.py:92-187,207-250` | The journal can be unbalanced and is still exported. Debit = header landed cost (excludes seller-paid rows) while the credits include **every** invoice, seller-paid included. Tolerance is 0.05. `amount_currency` is an FX amount but the currency column is "EGP". `exp.get(...).strip()` on `None` raises a 500. | code | Credits come from the same filtered list as the engine. CSV/Excel export returns 409 `JOURNAL_UNBALANCED` when diff > 0.01 (Q10). Currency column = the invoice currency when `amount_currency` is set. Use `(x or "").strip()`. |
| FS-15 | MINOR | `router.py:118,134` | Export filenames use the DB id (`…_{settlement_id}`). | code | `Content-Disposition` uses `import_file_code` (FE builds the final name, see FE-03). |
| FS-16 | MINOR | `service.py:921-925,1434-1439,1575,2106`; schemas `*_ar`, `executive_summary_ar` | The response carries Arabic sentences (warnings, `message`, `variance_status_ar`, `party_type_ar`, `category_ar`), which breaks single-language T1. | code | Additive `messages: [{code, params}]` next to `unsettled_warnings`, built with `system_messages.to_item`. Keep the old fields (deprecated). Codes are listed in Shared needs. |
| FS-17 | MINOR | `model.py:262-263`, `schemas.py:18,37`; `repository.py:9-30` | Free-text `status` (Draft/Calculated/Approved), `accountant_name` default "Kamal", `qty: int` (rejects 2.5, while the engine uses `max(qty,1)` so qty < 1 gives a wrong unit cost), and the code generator does not retry on collision. | code | Validate status against the legacy set (no migration). Default `accountant_name` = current user. `qty: float > 0`. `next_yearly_code(db, col, "LCS", pad=4)` with a retry on IntegrityError. The engine's `max(qty,1)` stays (pinned). |
| FS-18 | MINOR | `service.py:87,144-153` | `incoterm` is only echoed back: there is no Incoterm logic beyond the `is_seller_paid` flag. "Insurance" and "VAT & Taxes" categories fall into `allocated_other`. | code | Document it in the docstring. Q11. |

### 1b. Backend: recalculation (RC)

| id | sev | file:line | problem | evidence | fix |
|---|---|---|---|---|---|
| RC-01 | BLOCKER | `service.py:195-265` | Settlement read and write are asymmetric and double count. The read **sums** every invoice that matches a substring. The write sets the **first** match to the total and leaves the other matches in place, so freight becomes new + others. `"customs"` also matches "Customs Clearance", so clearance is counted as duties. The clearance read includes transport keywords but the write does not, so preview still shows a variance after apply. | code | One classifier, `financial_settlement.service.actual_expense_bucket`, used for both read and write. The write appends or updates a single adjustment row `RECALC-ADJ-<field>` worth `new - Σ others`. Repeated applies are idempotent and user invoices are never changed. |
| RC-02 | CRITICAL | `service.py:450-453,383-399` | `apply` on an **Approved** settlement recalculates in place and resets it to "Calculated" (pinned by `test_recalculation_engine.py:606-660`). Budgets get a revision instead. | test 12 | Q1. Safe default: keep it (pinned) and record `action_taken="recalculated_approved"` in the log. |
| RC-03 | CRITICAL | `service.py:116-120`, `59-96` | Source FX: a PO without `exchange_rate` uses 1.0 (the FX amount becomes EGP). Scenario `total_quotation_amount` is in `quotation_currency` (default USD, `shipping_scenarios/model.py:102`) but is written as EGP freight. | code | Convert with `CurrencyService` (rate type per Q2). A missing rate skips that item and sets `status=RATE_MISSING`. |
| RC-04 | MAJOR | `repository.py:103,139`; `service.py:516,705,717,728` | `create_log` commits, so preview (documented as "no data change") commits on every open. Apply commits the entity, then the log: if the log fails, the change has no audit row. | code | `create_log` flushes. The service commits once. |
| RC-05 | MAJOR | `router.py:73-119` | `/logs` and `/dependencies` call the repository from the router, and the filtering/mapping happens in the router. Preview, logs, and dependencies check authentication only. | code | Add `service.list_logs` / `service.list_dependencies`. View permission per target, resolved in the service: `import_budget` uses `financial_approval.view`, `financial_settlement` uses `financial_settlement.view`. |
| RC-06 | MINOR | `service.py:160,169,172,190,498-502,691,711-724,750` | English `detail` strings, `message_ar` with emoji and Arabic only, and `applied_changes=[]` always in the apply result. | code | Arabic details. Additive `message_code` + `params`. Return the real `applied_changes`. |
| RC-07 | MINOR | `service.py:76-79,141` | N+1 query per scenario session. `latest` depends on row order without an `order_by`. | code | One `IN` query. `order_by(id)`. |

### 1c. Flutter (FE)

| id | sev | file:line | problem | fix |
|---|---|---|---|---|
| FE-01 | BLOCKER | `screens/financial_settlement_screen.dart:1585-1604,1565` | Money math and fabricated data in the client: `amount_egp = fx*rate`, `gross_weight_kg: 1000.0`, `cbm: 10.0`, currency fixed to 'USD', default rate '50.0', and `qty` parsed as int. | Do not send `amount_egp` (the backend computes it). Add weight/CBM inputs (empty = 0) and a currency `SearchableDropdownField`. No default rate. `qty` as decimal. |
| FE-02 | MAJOR | `screens/financial_settlement_screen.dart:95-200` | Clone sends a create for the **same** `importFileId`, which the backend always rejects (one active settlement per file). The code `SETTLE-DRAFT-…` is generated in the client. The texts use `isAr ? '…' : '…'` instead of l10n. | Clone requires choosing a different import file (`SearchableDropdownField`). Remove the client-side code. Move the texts to l10n. |
| FE-03 | MAJOR | `screens/odoo_journal_entry_dialog.dart:69-104`; `services/landed_cost_comparison_export_service.dart:215-220,333-338` | Saves go through the legacy `saveText`/`saveBytes` with names like `Phase6_…_<id>` and `landed_cost_comparison_…`. | `FileSaveHelper.exportAndSaveFile` with `"<Stage name> - <import_file_code>.<ext>"`. |
| FE-04 | MAJOR | `widgets/estimated_landed_cost_dialog.dart:692`, `widgets/actual_landed_cost_dialog.dart:495` | `DropdownButtonFormField` / `DropdownButton` used for the allocation rule. | `SearchableDropdownField<String>` over the 4 rule codes, with l10n labels. |
| FE-05 | MAJOR | 9 files | About 259 lines with Arabic string literals (screen 53, actual dialog 67, estimated dialog 70, invoices dialog 54, odoo 8, comparison 4, others 3). | Move them to l10n (§4). |
| FE-06 | MAJOR | 8 files | 181 `Colors.*`, 44 `Color(0x…)`, and 38 Material buttons. | Use `AppTheme.*` and `AppButton`. One mechanical commit per file. |
| FE-07 | MAJOR | 12 sites | The UI renders backend `*_ar` / `executive_summary_ar` / `message` / `unsettled_warnings` text, so it shows Arabic in the English UI. | Render from codes: `party_type`, `category_code`, and `variance_status` via `domain_enum_labels`, and the new `messages[]` (FS-16). |
| FE-08 | MINOR | 25 `catch (e)` sites | SnackBars show the raw `$e` (DioException dump). | `ApiErrorText.of(context.l10n, e)`. |
| FE-09 | MINOR | `models/invoices_aggregation_model.dart:167,186,238`; `financial_settlement_model.dart:16,24` | Model defaults copy the backend's hard-coded values (48.5, 50.0, 'Cost Accounting Specialist'). `qty` uses `toInt()`, which truncates 2.5 to 2. | Neutral defaults (0 / ''). `qty` as double. Stop sending `settled_by`/`approved_by` (server uses the current user). |
| FE-10 | MINOR | `providers/financial_settlement_provider.dart:183-186,229-232` | After confirm or approve, only `importFilesProvider` is invalidated. The lifecycle board and smart-task lists stay stale. | Also invalidate the lifecycle and tasks providers that the screen watches. |
| FE-11 | MINOR | `screens/financial_settlement_screen.dart` (1627 lines) | The add/clone dialog is embedded in the screen file. | Extract it to `widgets/settlement_form_dialog.dart` (mechanical). |

## 2. Behaviour preservation

**Must stay byte-identical** (same floats, same rounding order):
- `calculate_landed_cost_engine`: unrounded per-item buckets, totals rounded to 2 decimals, markup rounded to 4, `max(qty,1)`, the 1/n fallback ratio, seller-paid skip, and the `amount_fx*rate` fill when `amount_egp == 0`.
- The simulation (PL-08) with the parameter rows missing: 2% / 2.5% and 4500/5000/7500/2500/2000, the rule-selection chains (l.595, 689, 700, 711), customs via `estimate_multi_item_customs_duty_service`, and every `round(...,2)`.
- WHT: `round(amt * (rate/100.0), 2)`, the Cairo-date lookup, 409 on `wht_deducted` without a rate, and warnings for synthetic rows.
- Actual (CLO-02) bucket mapping (`actual_expense_bucket`), variance thresholds (±0.05 per unit, ±100 EGP overall), and the default allocation chains.
- The Odoo journal for a settlement with no seller-paid rows: line order, labels, `round(...,2)`, and the CSV header.
- Recalculation for budgets: the revision path, SoD, the hard-block threshold, and the 100% variance when old = 0.

**Intended money changes** (must be announced): FS-02 (real FX), FS-05 (create/simulate items, CBM), FS-06 (no fake HS/weight/value), FS-08 (item FOB rate), FS-10 (delivery order FX, partial), FS-14 (seller-paid credits), RC-01 (no double count), and RC-03 (scenario FX).

**Characterization tests first** (green on the current code): new file `tests/unit/test_phase09_characterization.py`:
1. Engine golden values: 3 items × Value/Weight/Volume/Equal plus a seller-paid row, an `amount_egp=0` fill, and qty 0.5.
2. Simulation golden values with all overrides set (no DB constants involved), and once with defaults (2% / 2.5% / 4500…).
3. WHT 17.50 at 1% gives 0.18 (already in `test_withholding_tax_rates.py`, keep it).
4. Actual: Value preference with 2 PO lines, an EGP freight invoice, and a broker invoice, giving the bucket totals and variance status.
5. Odoo: a balanced journal for a settlement without seller-paid rows, and the exact CSV text.
6. Recalc: a budget revision (existing tests), and the Approved-settlement justification path (existing test 12).

Regression tests with each fix: FS-01 (approve then GET keeps invoices, recalculate gives 409), FS-03/04 (viewer gets 403 on approve, using the `monkeypatch ALLOW_DEV_AUTH_BYPASS=False` seam; PUT `status:"Approved"` gives 422), FS-02 (missing rate gives 409 `SETTLEMENT_FX_RATE_MISSING`), FS-05 (create from a PO gives non-empty items), FS-11 (restore duplicate gives 409), FS-12 (second confirm gives 409, unrelated task untouched), FS-14 (seller-paid row stays balanced, unbalanced export gives 409), RC-01 (apply twice gives the same totals, then preview shows no variance), RC-03 (USD quotation converted). Flutter: `frontend/test/features/financial_settlement/settlement_models_test.dart` (decimal qty, actual-shape fallback, no 48.5 default) and `…/financial_settlement_provider_test.dart` (create payload has no `amount_egp`, invalidation after approve).

## 3. Work split (disjoint files)

| Package | Owner | Files (exclusive) |
|---|---|---|
| **BE** | backend-developer | `modules/financial_settlement/*` (7 files), `modules/recalculation/*` (except `model.py`, untouched), new `tests/unit/test_phase09_characterization.py`, and edits to `test_financial_settlement.py`, `test_odoo_gl_export.py`, `test_recalculation_engine.py`, `test_clo01_*`, `test_clo02_*`, `test_pl08_*` |
| **FE** | flutter-developer | `frontend/lib/features/financial_settlement/**`, `frontend/lib/features/recalculation/**`, `frontend/test/features/financial_settlement/**`, and the l10n keys **only** between `// === review phase08_10 keys ...` and `// === end review phase08_10 keys ===` in `app_localizations{,_ar,_en}.dart`, every key prefixed `settlement` (e.g. `settlementCloneTargetFileLabel`, `settlementExportFailed`, `settlementMsgLineNoHs`) |

Order: BE-T (characterization) → BE-1 (FS-04, FS-03, FS-11, FS-13, RC-04/05: no money change) → BE-2 (FS-01, FS-02, FS-05..10, FS-14, RC-01, RC-03: money) → reviews (`customs-rules-reviewer` on BE-2, `security-reviewer` on FS-04/RC-05). FE starts immediately on FE-04..06, FE-08, and FE-11 (no contract impact). FE-01/02/07/09 follow once BE-2 has landed.

**Contract changes** (all additive unless marked):
1. Response `messages: [{code, params}]` on aggregation, simulate, and actual. New fields: `reconciliation_difference_egp` (actual), `total_customs_duty_egp` + `total_vat_and_fees_egp` (simulate), `message_code`/`params` (recalc preview and apply), and a real `applied_changes` list.
2. **Breaking:** PUT `status` only accepts `Draft`/`Calculated` (422 otherwise). PUT and `/recalculate` on Approved/Closed return 409. A second confirm returns 409. Restore when another active settlement exists returns 409. An unbalanced Odoo export returns 409. A missing FX rate returns 409 `SETTLEMENT_FX_RATE_MISSING`.
3. Ignored, kept for compatibility: `approved_by`, `settled_by`, `accountant_name`, `invoices_overrides` (per Q9).
4. Stored JSON after approve uses the canonical keys (FS-01). The `actual_*` keys are kept.
5. Permissions: 403 for users without `financial_settlement.view` or `.calculate`.

## 4. Shared needs (devs do NOT edit these; the lead routes them)

- `modules/common/system_messages.py` + `docs/system_message_codes.json`: register `SETTLEMENT_FX_RATE_MISSING` (currency, on_date), `SETTLEMENT_LINE_NO_HS` (item_code), `PAYMENT_STATUS_UNKNOWN` (invoice_no), `ESTIMATE_UNAVAILABLE`, `JOURNAL_UNBALANCED` (difference), `INVOICES_ALREADY_SETTLED` (import_file_code), `SETTLEMENT_NOT_EDITABLE` (status), `SETTLEMENT_UNPAID_INVOICE` (party_name, amount, invoice_no), `WHT_RATE_MISSING_WARNING` (tax_code, on_date, invoice_no), and recalc `RECALC_NO_VARIANCE` / `RECALC_SOFT_VARIANCE` / `RECALC_HARD_BLOCK` (threshold) / `RECALC_APPLIED`. BE emits plain `{code, params}` dicts until they are registered.
- `modules/common/system_parameters.py` seed: the FS-07 keys with their current defaults.
- `modules/common/enum_codes.py` + `docs/enum_codes.json`: `ALLOCATION_RULE` (VALUE/WEIGHT/VOLUME/EQUAL mapped from the legacy labels; API values unchanged this wave) and `SETTLEMENT_STATUS` (legacy set, read-only).
- `frontend/lib/core/localization/api_error_text.dart`: add the 409 codes above plus `WHT_RATE_NOT_CONFIGURED`. `frontend/lib/core/widgets/recalculate_button.dart`: render `message_code` instead of `message_ar` (FE edits it only if the lead assigns it).
- `modules/auth/seed_rbac.py`: no change needed unless Q3 adds `financial_settlement.approve`.

## 5. Risks

- **FS-01 live data:** settlements approved before the fix already hold category rows in `expense_invoices`. Run a read-only count before deploying (`status='Approved'` and the first row has an `actual_egp` key). Do not auto-repair; the CTO decides on re-approve (Q12).
- **FS-02/RC-03 change historical numbers** when a file is recalculated. Approved records are frozen by FS-03, so only drafts move.
- **Permissions:** accountants without `financial_settlement.*` will get 403. Check the role matrix before merging.
- **FE-07 depends on FS-16 codes.** Until they are registered, render the existing fields as a fallback.

## 6. Open questions for the CTO (safe default in brackets)

- Q1: May recalculation apply to an Approved settlement? [keep the current justified path; pinned by a test]
- Q2: FX rate type for actual landed cost: commercial/bank or customs? [commercial at the invoice date; customs rows are already EGP]
- Q3: Approve under `financial_settlement.calculate`, or a new `.approve` code (segregation of duties)? [`.calculate`]
- Q4: When the file has no PO lines, may the simulation still run on `invoices_data` / `estimated_cost`? [yes, but without inventing the 10000 / HS defaults]
- Q5: Deemed freight 2% and insurance 2.5%: configurable per company, or global parameters? [global parameters]
- Q6: Allocate the rounding remainder to the largest line so Σ lines = header? [no, report the difference only]
- Q7: Should `custom_category_allocation` drive the allocation? [no, report the rule actually used]
- Q8: Freight/insurance always PAID, and swift = goods paid: keep? [keep and flag]
- Q9: Drop `invoices_overrides` from confirm? [ignore it, re-aggregate on the server]
- Q10: Odoo balance tolerance: 0.01 or 0.05? [0.01, and block export above it]
- Q11: Implement Incoterm-aware exclusion (CIF ignores freight and insurance)? [backlog]
- Q12: Repair settlements already corrupted by FS-01: re-approve, or leave them? [report the count only]
