# Backend + accounting review: task checklist

Single checklist for the 11 backend / accounting reports. Plan, merges, migrations, API changes and rules:
[`README.md`](README.md). Steps, acceptance criteria and tests of each task are in its report (link column); the six
`BEW0-*` tasks are described in README section 6.

Ordered by wave, then priority (money BLOCKERs first). "Safe for Antigravity": **review required** = migration, money
math or auth / approval gate (README section 12); **yes** = may be done by Antigravity. "Via BEW0-05" = the task's
migration was moved into the shared migration task. Status: `todo` / `in progress` / `done (PR #)`.

## Wave 0: shared foundations

| # | Task id | Scope | Sev | Title | Depends on | Migration | API change | Safe for Antigravity | Report link | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | BEW0-01 | currencies, customs_tariff | BLOCKER | Shared FX resolver, no fabricated rates (merges BEX-T07 + BE67-T03) | none | no | yes: 409 `CURRENCY_RATE_MISSING`, 404 `CURRENCY_NOT_FOUND`, 422 `CT_CUSTOMS_RATE_MISSING` | review required | [README §6](README.md), [be-cross](be-cross-review.md), [be-06-07](be-06-07-review.md) | todo |
| 2 | BEW0-06 | financial_settlement, customs_clearance | BLOCKER | Settlement external-write gate: lock + engine totals (merges BE67-T05 + BE09-T04) | none | no | yes: 409 `CC_SETTLEMENT_LOCKED` | review required | [README §6](README.md), [be-06-07](be-06-07-review.md), [be-09](be-09-review.md) | todo |
| 3 | BEW0-03 | common | BLOCKER | Closed-file guard `ensure_file_open` + code `IMPORT_FILE_CLOSED` | none | no | yes: new code | yes | [README §6](README.md), [be-08-10](be-08-10-review.md) | todo |
| 4 | BEW0-02 | common | MAJOR | Currency master validation helper `require_currency_code` | none | no | no (helper only) | yes | [README §6](README.md) | todo |
| 5 | BEW0-04 | common, import_files | MAJOR | List paging helper + `/paginated` contract, harden `/import-files/paginated` (was BEX-T13) | none | no | additive: `sort`, `q`, bounds, `X-Total-Count` | yes | [README §11](README.md), [be-cross](be-cross-review.md) | todo |
| 6 | BEW0-05 | ~25 tables (models) | MAJOR | One Alembic revision: audit + soft-delete columns for all modules | none | **yes** | additive (nullable fields) | review required | [README §6](README.md) | todo |

## Wave 1: BLOCKER + CRITICAL

| # | Task id | Scope | Sev | Title | Depends on | Migration | API change | Safe for Antigravity | Report link | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 7 | BE45-T01 | freight_booking | BLOCKER | Booking cost engine: charge currency to USD, per-container-type quantity, decimal qty (absorbs ACC3-T01) | BEW0-01, BEW0-02 | no | yes: `fx_rate_to_usd`, `amount_usd`, `container_type`, float `quantity`; 422 / 409 | review required | [be-04-05](be-04-05-review.md), [acc-logistics](acc-logistics-costs-review.md) | todo |
| 8 | ACC3-T02 | freight_booking (+FE form) | BLOCKER | Keep insurance (and storage) out of the booking freight total | BE45-T01; Q2 for storage | no | yes: `charge_category`; 422 on INSURANCE | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 9 | ACC2-T01 | financial_settlement, recalculation | BLOCKER | Landed cost uses the file's share of partially shipped POs | none | no | additive message `SETTLEMENT_PO_NOT_ALLOCATED` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 10 | BE67-T02 | customs_tariff | BLOCKER | One preferential-agreement rate helper (fixed rate, 0..1 scale, date, HS format) | none | no | yes: `reduction_percentage` 0..1 | review required | [be-06-07](be-06-07-review.md) | todo |
| 11 | ACC1-T01 | customs_tariff | BLOCKER | Foreign freight converted at its own customs rate, never the invoice rate | BEW0-01 | no | yes: `freight_rate_source`, 422 | review required | [acc-customs](acc-customs-review.md) | todo |
| 12 | BE67-T04 | customs_tariff | BLOCKER | `simulate-file` without invented HS / values / currency / broker; per-PO currency | BEW0-01 | no | yes: `warnings[]`, `skipped_lines[]`, 422 `CT_SIMULATION_NO_LINES` | review required | [be-06-07](be-06-07-review.md) | todo |
| 13 | ACC3-T03 | financial_settlement (PL-08) | BLOCKER | Estimate uses the ocean freight, not the quote total, in CIF | none | no | no (values) | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 14 | BE09-T02 | recalculation | BLOCKER | A justified recalculation keeps an Approved settlement Approved; file variance refreshed | none (Q1) | no | yes (status stays Approved) | review required | [be-09](be-09-review.md) | todo |
| 15 | BE09-T03 | recalculation | BLOCKER | Settlement recalculation no longer overwrites actual costs with estimates | Q1 | no | yes (FOB item only) | review required | [be-09](be-09-review.md) | todo |
| 16 | BE09-T01 | financial_settlement, recalculation | BLOCKER | Closed import file makes the settlement read-only | BEW0-03 | no | yes: 409 `IMPORT_FILE_CLOSED` | review required | [be-09](be-09-review.md) | todo |
| 17 | BE810-T01 | inland_transport | BLOCKER | Resync the file's inland transport fields from the active bookings | none | no | no | review required | [be-08-10](be-08-10-review.md) | todo |
| 18 | BE45-T03 | demurrage_detention | BLOCKER | Settlement permission on every re-push of a pushed tracking | none | no | yes: 403 | review required | [be-04-05](be-04-05-review.md) | todo |
| 19 | BE45-T02 | demurrage_detention | BLOCKER | Recalculate before pushing demurrage; live dual clock | BE45-T03, BEW0-06 | no | additive `is_provisional` | review required | [be-04-05](be-04-05-review.md) | todo |
| 20 | BE01-T01 | customs_consultation | BLOCKER | Broker fees converted to EGP per line | BEW0-01 | no | yes: request total ignored, 409 `SETTLEMENT_FX_RATE_MISSING` | review required | [be-01](be-01-review.md) | todo |
| 21 | BE02-T02 | financial_approval | BLOCKER | Budget clone converts freight with the freight currency's own rate | BEW0-01 | no | no (values) | review required | [be-02](be-02-review.md) | todo |
| 22 | BE02-T01 | financial_approval | BLOCKER | A new variance cancels an earlier override (hard-block bypass) | none | no | no | review required | [be-02](be-02-review.md) | done (`fix/be02-t01-variance-cancel-override`) |
| 23 | BE03-T02 | import_documentation | BLOCKER | Invoice/B-L sync never relabels the file's estimated-cost currency | none | no | additive `currency_mismatch` | review required | [be-03](be-03-review.md) | todo |
| 24 | BE03-T03 | smart_document_upload | BLOCKER | Smart-upload invoice apply is idempotent, does not overwrite the estimate | none | no | yes: `SDU_INVOICE_NUMBER_REQUIRED` | review required | [be-03](be-03-review.md) | todo |
| 25 | BE03-T01 | import_documentation (+FE tab) | BLOCKER | PO final adjustment applies each PO line once | none | no | yes: packing semantics, 400 duplicate line, `total_final_amount_by_currency` | review required | [be-03](be-03-review.md) | todo |
| 26 | BE67-T06 | customs_clearance | BLOCKER | "Assessed" means CL-02 really ran; no negative money on create / PUT | none | no | yes: claim fields ignored, 409 `CC_DUTY_NOT_ASSESSED` | review required | [be-06-07](be-06-07-review.md) | todo |
| 27 | BEX-T10 | projects, import_files | BLOCKER | Money aggregates in one currency (project commitments, master report) | BEW0-01 | no | yes: nullable USD totals, `missing_rate_currencies`, `estimated_cost_by_currency` | review required | [be-cross](be-cross-review.md) | todo |
| 28 | BE67-T01 | customs_tariff | BLOCKER | Permissions on all customs_tariff routes + route order | none | no | yes: 403; fee-codes / template reachable | review required | [be-06-07](be-06-07-review.md) | todo |
| 29 | BEX-T01 | lifecycle_board | BLOCKER | Board permissions, acting user, file and status guards | none | no | yes: 403, `LC_*` codes | review required | [be-cross](be-cross-review.md) | todo |
| 30 | BEX-T08 | auth, users | BLOCKER | Revocation loaded at startup, token version, login limiter, small auth fixes | none | **yes** (`users.token_version`) | yes: token `tv`, refresh revokes old token | review required | [be-cross](be-cross-review.md) | todo |
| 31 | BEX-T04 | auth seed, currencies, incoterms | BLOCKER | Master data permissions (A) + `master_data.edit` grant | Q1 | no | yes: 403; responsibility soft delete | review required | [be-cross](be-cross-review.md) | todo |
| 32 | BEX-T05 | projects, transport_locations, expense_catalog | BLOCKER | Master data permissions (B) | BEX-T04 | no | yes: 403 | review required | [be-cross](be-cross-review.md) | todo |
| 33 | BEX-T06 | suppliers, import_companies, external_service_providers | BLOCKER | Master data permissions (C) + actor on create / update | BEX-T04 | no | yes: 403 | review required | [be-cross](be-cross-review.md) | todo |
| 34 | BEX-T09 | 5 master-data Excel imports | BLOCKER | Excel imports: no invented values, one transaction, permission, limits | BEX-T05, BEX-T06 | no | yes: all-or-nothing, 413 / 415 | review required | [be-cross](be-cross-review.md) | todo |
| 35 | BE01-T02 | shipping_scenarios | BLOCKER | Scenario items upserted by id (bookings keep their quote) | none | no | yes: `item_id`, 409 `SCENARIO_ITEMS_BOOKED` | yes | [be-01](be-01-review.md) | todo |
| 36 | BE810-T02 | warehouse_receiving, inland_transport | BLOCKER | Closed file is read-only for WR and IT | BEW0-03 | no | yes: 409 `IMPORT_FILE_CLOSED` | yes | [be-08-10](be-08-10-review.md) | todo |
| 37 | ACC1-T05 | customs_consultation | CRITICAL | Consultation `estimated_duties_egp` from the engine only (new estimate-duties endpoint) | BE67-T04, BEW0-01; Q3 | no | yes: field ignored, new endpoint | review required | [acc-customs](acc-customs-review.md) | todo |
| 38 | ACC1-T02 | customs_tariff | CRITICAL | Line CIF allocation that reconciles (gross / dutiable, exact remainder) | Q1 (acc-customs) | no | yes: 422, `cif_total_egp`, `dutiable_cif_total_egp` | review required | [acc-customs](acc-customs-review.md) | todo |
| 39 | BE67-T08 | customs_tariff | CRITICAL | Tariff versioning for PUT and verify (no in-place rate overwrite, no same-day 500) | BE67-T01 | no | yes: new `tariff_id` on rate change | review required | [be-06-07](be-06-07-review.md) | todo |
| 40 | ACC1-T08 | customs_tariff | CRITICAL | Tariff save with agreements keeps a valid history | BE67-T08, BE67-T11 | no | yes: 422 back-dated | review required | [acc-customs](acc-customs-review.md) | todo |
| 41 | BE67-T09 | customs_tariff | CRITICAL | Tariff CSV upload: required rates, savepoints, size limit | BE67-T08 | no | yes: CSV only, 5 MB, row errors | review required | [be-06-07](be-06-07-review.md) | todo |
| 42 | BE67-T10 | customs_tariff | CRITICAL | Correct the Nafeza extra-fees formula | none | no | no (values) | review required | [be-06-07](be-06-07-review.md) | todo |
| 43 | BE67-T07 | customs_clearance | CRITICAL | Guards after payment and final release | BE67-T06 | no | yes: 409 `CC_ALREADY_RELEASED`, `CC_ALREADY_PAID` | review required | [be-06-07](be-06-07-review.md) | todo |
| 44 | ACC2-T02 | financial_settlement (+Odoo) | CRITICAL | Code-first expense classification (bucket and Odoo account) | none | no | no (values / accounts) | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 45 | BE09-T05 | financial_settlement | CRITICAL | Approve never drops manual settlement rows | Q3 | no | yes: 409 `SETTLEMENT_MANUAL_ROWS_NOT_AGGREGATED` | review required | [be-09](be-09-review.md) | todo |
| 46 | BE45-T04 | freight_booking, demurrage_detention | CRITICAL | No invented 14 free days on the booking | none | no | yes: nullable `free_demurrage_days`, `ge=0` | review required | [be-04-05](be-04-05-review.md) | todo |
| 47 | BE45-T05 | cargo_insurance | CRITICAL | One active insurance certificate per file | none | no | yes: 409 | review required | [be-04-05](be-04-05-review.md) | todo |
| 48 | BE45-T06 | demurrage_detention | CRITICAL | One active demurrage tracking per file | none | no | yes: 409 / 404; client code ignored | review required | [be-04-05](be-04-05-review.md) | todo |
| 49 | ACC3-T04 | demurrage_detention | CRITICAL | No demurrage / storage after empty return; gate-out required | none | no | yes: 422 | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 50 | ACC3-T05 | demurrage_detention (+FE dialog) | CRITICAL | Tracking currency = tariff currency | none | no | yes: `currency` optional, 422 mismatch | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 51 | BE01-T05 | freight_quotations | CRITICAL | Freight comparison in one currency (EGP) | BE01-T04, BEW0-01 | no | additive EGP fields; values change | review required | [be-01](be-01-review.md) | todo |
| 52 | BE01-T06 | import_requirements | CRITICAL | Prefill sums values per currency | BEW0-02 | no | yes: nullable value, `PREFILL_MIXED_CURRENCY` | review required | [be-01](be-01-review.md) | todo |
| 53 | BE810-T06 | file_closure | CRITICAL | Dossier FOB per currency | none | no | yes: `fob_by_currency`, nullable totals | review required | [be-08-10](be-08-10-review.md) | todo |
| 54 | BE02-T04 | financial_approval | CRITICAL | "Mark as Paid" requires a real SWIFT reference | none | no | yes: 400 `FA_SWIFT_REF_REQUIRED` | review required | [be-02](be-02-review.md) | todo |
| 55 | BE02-T05 | financial_approval | CRITICAL | Backfill legacy budget columns, NULL-safe sync | none | **yes** (backfill + server_default) | no | review required | [be-02](be-02-review.md) | todo |
| 56 | ACC2-T16 | Flutter financial_settlement / financial_approval | CRITICAL | Flutter shows backend money, no client variance / EGP formulas | ACC2-T12 | no | no (reads existing fields) | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 57 | BE03-T04 | import_documentation | CRITICAL | Gate or remove `/invoice-bl/certify-and-sync` | BE03-T02; Q4 | no | yes: 409 `DOC_INVOICE_BL_NOT_CERTIFIED` | review required | [be-03](be-03-review.md) | todo |
| 58 | BE03-T05 | import_documentation | CRITICAL | Server-owned gate fields for invoice/B-L and PO recon sessions | BEW0-02 | no | yes: gate fields ignored, `currency` required | review required | [be-03](be-03-review.md) | todo |
| 59 | BE03-T06 | import_documentation | CRITICAL | ACID verification status derived on the server | none | no | yes: status / flags ignored, 409 `DOC_ACID_CONFLICT` | review required | [be-03](be-03-review.md) | todo |
| 60 | BE03-T07 | import_documentation | CRITICAL | Draft B/L blocking flags and versions server-owned | none | no | yes: flags ignored | review required | [be-03](be-03-review.md) | todo |
| 61 | BE03-T08 | docs_customs_approval | CRITICAL | DCA final session requires real approvals | none | no | yes: `unapproved_documents`, status set | review required | [be-03](be-03-review.md) | todo |
| 62 | BEX-T11 | import_files | CRITICAL | Import files: tracking fields, exact lookup, status workflow, legacy response, reopen audit | none (Q4) | no | yes: `status` not in PUT, exact lookup, 409 `IF_STATUS_TRANSITION_INVALID` | yes | [be-cross](be-cross-review.md) | todo |
| 63 | BEX-T12 | import_files, suppliers, projects, smart_tasks | CRITICAL | Collision-safe business codes (IMP, SUP, PRJ, TSK) | none | conditional (Q8 unique indexes) | no | yes | [be-cross](be-cross-review.md) | todo |
| 64 | BE01-T03 | customs_consultation, freight_quotations | CRITICAL | Collision-safe codes for consultations, price lists, expense types, RFQs | none | no | no | yes | [be-01](be-01-review.md) | todo |
| 65 | BE01-T04 | freight_quotations | CRITICAL | RFQ integrity: quotation upsert, award only via `/award`, read without side effects | none | no | yes: `quotation_id`; status fields ignored | yes | [be-01](be-01-review.md) | todo |
| 66 | BE810-T03 | warehouse_receiving, customs_clearance, file_closure | CRITICAL | Release the GRN quarantine lock when customs lifts it | BE810-T02 | no | no (behaviour) | yes | [be-08-10](be-08-10-review.md) | todo |
| 67 | BE810-T04 | inland_transport, file_closure | CRITICAL | Legacy-tolerant response schemas (IT, FC) | none | no | yes: nullable `closed_at` | yes | [be-08-10](be-08-10-review.md) | todo |
| 68 | BE810-T05 | warehouse_receiving | CRITICAL | GRN PUT keeps rate, type and verdict consistent; no workflow bypass | BE810-T02 | no | yes: `WR_FIELD_NOT_EDITABLE`, `WR_STATUS_CHANGE_NOT_ALLOWED` | yes | [be-08-10](be-08-10-review.md) | todo |

## Wave 2: MAJOR

| # | Task id | Scope | Sev | Title | Depends on | Migration | API change | Safe for Antigravity | Report link | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 69 | ACC2-T04 | financial_settlement | MAJOR | CLO-01 readiness on the net-payable basis (land before BE09-T13) | none | no | yes: readiness semantics, `total_net_payable_egp` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 70 | ACC2-T05 | financial_settlement | MAJOR | Server-derived EGP amounts on settlement expense rows | BEW0-02 | no | yes: `currency` required | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 71 | ACC2-T06 | financial_settlement | MAJOR | One FOB basis for the actual landed cost; unrounded unit FOB | ACC2-T01; Q1 | no | yes: `fob_basis`, 409 `SETTLEMENT_ACTUAL_FOB_MISSING` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 72 | ACC2-T03 | financial_settlement | MAJOR | Customs components in CLO-01 / CLO-02 / approve | ACC2-T02 | no | additive `components` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 73 | ACC2-T07 | financial_approval, financial_settlement | MAJOR | Realised payment in EGP and payment coverage | BE02-T04; Q2 | **yes** (`paid_amount_egp`, `paid_exchange_rate`) | additive | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 74 | ACC2-T08 | financial_approval (+FE screen) | MAJOR | Payment request rate (EGP = 1) and PO ceiling | BE02-T11, BE02-T12 | no | yes: `FA_EGP_RATE_NOT_ONE`, `FA_PAYMENT_EXCEEDS_PO`, `FA_PAYMENT_CURRENCY_MISMATCH` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 75 | ACC2-T09 | financial_settlement | MAJOR | Allocation bases per BP-038 with a completeness rule | ACC2-T02; Q4 | no | additive `ALLOCATION_BASIS_INCOMPLETE` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 76 | ACC2-T10 | financial_settlement (PL-08) | MAJOR | PL-08 estimate reconciles with its lines | none | no | values only | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 77 | ACC2-T11 | financial_settlement | MAJOR | No invented currency in estimate / aggregation | BEW0-02 | no | yes: 409 `SETTLEMENT_CURRENCY_MISSING`, nullable currency | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 78 | ACC2-T12 | financial_settlement | MAJOR | No fabricated variance when the estimate is unavailable | ACC2-T06 | no | yes: nullable estimate / variance, `NO_ESTIMATE` | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 79 | ACC2-T13 | financial_settlement (Odoo) | MAJOR | Tax-aware Odoo journal behind a flag | ACC2-T02, ACC2-T03; Q6 | no | additive config + row keys | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 80 | ACC2-T14 | financial_settlement | MAJOR | Report missing actual sources (`ACTUAL_SOURCE_MISSING`) | Q5 | no | additive message | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 81 | ACC1-T03 | customs_tariff, customs_consultation | MAJOR | One insurance / freight rule for every server estimate | BE01-T17, BE67-T04; Q2 | no | yes: `insurance_source` / `freight_source` | review required | [acc-customs](acc-customs-review.md) | todo |
| 82 | ACC1-T04 | customs_tariff | MAJOR | Date-strict origin check; packaging inside CIF in `/estimate` | BE67-T02 | no | yes: 422, `cif_base_egp` | review required | [acc-customs](acc-customs-review.md) | todo |
| 83 | ACC1-T06 | customs_clearance | MAJOR | CL-02 override needs a reason; clearance estimate from phase 1 | BE67-T06; Q8 | no | yes: `duty_override_reason`, 409 | review required | [acc-customs](acc-customs-review.md) | todo |
| 84 | ACC1-T07 | import_requirements | MAJOR | `shipment_value_usd` converted on the server | BE01-T18, BEW0-01; Q7 | no | yes: client value ignored, 409 | review required | [acc-customs](acc-customs-review.md) | todo |
| 85 | ACC1-T09 | customs_tariff | MAJOR | Version comparison diffs every rate | BE67-T08 | no | no | review required | [acc-customs](acc-customs-review.md) | todo |
| 86 | ACC1-T10 | customs_tariff | MAJOR | Derived Nafeza fee codes in dependency order | BE67-T10 | no | yes: 422 `CT_FEE_CODE_FORMULA_INVALID` | review required | [acc-customs](acc-customs-review.md) | todo |
| 87 | ACC1-T11 | Flutter duty calculator, customs_tariff schema doc | MAJOR | Calculator sends "not decided" exemption flag as null | none | no | no | review required | [acc-customs](acc-customs-review.md) | todo |
| 88 | ACC3-T06 | shipping_scenarios, freight_booking, financial_approval | MAJOR | Scenario totals computed by the backend, freight separated | BE01-T02, BE01-T13, BEW0-01 | no | yes: server `total_quotation_amount`, `freight_total_amount`, 409 `SS_FX_RATE_MISSING` | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 89 | ACC3-T07 | cargo_insurance | MAJOR | Insurance fixed amounts in a defined currency; stable draft recalculation | BEW0-01; Q4 | no | no (values) | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 90 | ACC3-T08 | freight_quotations | MAJOR | Freight benchmark average on the included quotes | BE01-T05 | no | no (values) | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 91 | ACC3-T09 | Flutter cargo_insurance, demurrage, freight_booking | MAJOR | Flutter money display fixes (per-currency totals, tier currency, rate field) | none | no | no | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 92 | ACC3-T14 | financial_settlement aggregation | MAJOR | Seller-paid freight / insurance by Incoterm | Q1 (acc-logistics) | no | no | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 93 | BE02-T03 | financial_approval | MAJOR | Budget EGP amounts derived on the server (create and update) | BE02-T02 | no | yes: client EGP ignored when foreign > 0 | review required | [be-02](be-02-review.md) | todo |
| 94 | BE02-T06 | financial_approval | MAJOR | Override and approve: status guard + segregation of duties | BE02-T01 | no | yes: 403 / 409 / 400 codes | review required | [be-02](be-02-review.md) | todo |
| 95 | BE02-T09 | financial_approval | MAJOR | Budget prefill stops inventing values | none | no | yes: nullable prefill fields, `FA_CURRENCY_MISSING` | review required | [be-02](be-02-review.md) | todo |
| 96 | BE02-T12 | financial_approval | MAJOR | Changing a payment's currency requires a new rate | none | no | yes: `FA_PAYMENT_RATE_REQUIRED` | review required | [be-02](be-02-review.md) | todo |
| 97 | BE02-T14 | financial_approval | MAJOR | Remove the 50.0 rate defaults from the models | none | no (Python defaults) | no | review required | [be-02](be-02-review.md) | todo |
| 98 | BE09-T06 | financial_settlement | MAJOR | Approve preconditions (CLO-01 confirmed, items present) | none | no | yes: 409 `INVOICES_NOT_SETTLED`, `SETTLEMENT_NO_ITEMS` | review required | [be-09](be-09-review.md) | todo |
| 99 | BE09-T07 | financial_settlement | MAJOR | One active settlement per file at DB level | none | **yes** (partial unique index + dedupe) | no (409 on race) | review required | [be-09](be-09-review.md) | todo |
| 100 | BE09-T09 | financial_settlement | MAJOR | Reserved `RECALC-ADJ-*` invoice numbers are server-only | none | no | yes: 422 `SETTLEMENT_RESERVED_INVOICE_NO` | review required | [be-09](be-09-review.md) | todo |
| 101 | BE09-T10 | financial_settlement, demurrage_detention | MAJOR | Demurrage push and create share one initial-settlement builder | BE09-T07, BEW0-06 | no | no | review required | [be-09](be-09-review.md) | todo |
| 102 | BE09-T11 | financial_settlement (Odoo) | MAJOR | Odoo CSV / Excel export only for approved settlements | Q4 | no | yes: 409 `SETTLEMENT_NOT_APPROVED` | review required | [be-09](be-09-review.md) | todo |
| 103 | BE09-T13 | financial_settlement | MAJOR | CLO-01 confirm readiness gate and Cairo date | ACC2-T04; Q2 | no | yes: `acknowledge_unpaid`, 409 `INVOICES_NOT_READY` | review required | [be-09](be-09-review.md) | todo |
| 104 | BE45-T07 | demurrage_detention | MAJOR | Demurrage policy validation and uniqueness | none | no | yes: 422 / 409 | review required | [be-04-05](be-04-05-review.md) | todo |
| 105 | BE45-T08 | cargo_insurance | MAJOR | Insurance input bounds and issue guard | none | no | yes: 422 | review required | [be-04-05](be-04-05-review.md) | todo |
| 106 | BE45-T09 | demurrage_detention | MAJOR | EIR damage fee into the settlement | BE45-T02, BE45-T03, BEW0-06; Q4 | no | additive `damage_currency`, `INV-DMG-*` row | review required | [be-04-05](be-04-05-review.md) | todo |
| 107 | BE45-T14 | shipment_updates | MAJOR | Shipment update cost adjustment and transactions | Q6 | no | yes: `previous_cost` server-side, 409 | review required | [be-04-05](be-04-05-review.md) | todo |
| 108 | BE45-T20 | freight_booking | MAJOR | Savings engine charge matching (blocked) | BE45-T01; Q10 | no | no (values) | review required | [be-04-05](be-04-05-review.md) | todo |
| 109 | BE45-T22 | demurrage_detention | MAJOR | BK-02 response from the policy; last-free-day rule | Q7 (OVERDUE part) | no | no (values) | review required | [be-04-05](be-04-05-review.md) | todo |
| 110 | BE45-T11 | freight_booking | MAJOR | Departure data (`shipped_on_board_date`) and import-file sync | none | **yes** (`shipped_on_board_date`) | yes: new field, 422 future ATD | review required | [be-04-05](be-04-05-review.md) | todo |
| 111 | BE45-T13 | cargo_shipping | MAJOR | Approval lock, CargoX rule per shipment type, booking link check | Q5 | no | yes: 409 / 422; approvals reset | review required | [be-04-05](be-04-05-review.md) | todo |
| 112 | BE67-T12 | customs_tariff | MAJOR | Tariff soft delete separate from archive + audit wiring | BE67-T11, BEW0-05 | via BEW0-05 | additive; `verified_by` from token | review required | [be-06-07](be-06-07-review.md) | todo |
| 113 | BE67-T13 | customs_tariff | MAJOR | Engine inputs: VAT override, deemed rates, service fee, exemption flag | BE67-T02 | no | yes: bounds, `CT_TARIFF_RATE_MISSING` | review required | [be-06-07](be-06-07-review.md) | todo |
| 114 | BE67-T14 | customs_tariff | MAJOR | Nafeza text parser stops fabricating rates | BE67-T02 | no | yes: nullable rates, `missing_fields[]`, `unparsed_lines[]` | review required | [be-06-07](be-06-07-review.md) | todo |
| 115 | BE67-T16 | customs_clearance | MAJOR | Lab-result release, audit, delete guard | BE67-T07 | no | yes: 409 `CC_DELETE_NOT_ALLOWED`; lab no longer releases | review required | [be-06-07](be-06-07-review.md) | todo |
| 116 | BE67-T18 | customs_clearance | MAJOR | Clearance PUT and invoice master-data checks | BEW0-06, BE67-T06, BEW0-02 | no | yes: 409 `CC_INVOICE_DUPLICATE`, Literal sets | review required | [be-06-07](be-06-07-review.md) | todo |
| 117 | BE01-T07 | purchase_orders | MAJOR | PO exchange rate required, never 1.0 by default | none | no (Q2 optional) | yes: `exchange_rate` required | review required | [be-01](be-01-review.md) | todo |
| 118 | BE01-T17 | customs_consultation | MAJOR | Recalculation: no silent zero freight / insurance, no fabricated file code | BE01-T12 | no | additive flags + `RECALC_FREIGHT_MISSING` | review required | [be-01](be-01-review.md) | todo |
| 119 | BE810-T07 | file_closure | MAJOR | Dossier stops inventing values | BE810-T06 | no | yes: nullable fields, `fob_source` | review required | [be-08-10](be-08-10-review.md) | todo |
| 120 | BEX-T02 | lifecycle_board | MAJOR | One transaction per use case, skip policy, config authorisation | BEX-T01 | no | yes: `LC_SKIP_DUAL_APPROVAL_REQUIRED`, `LC_APPROVER_ROLE_UNKNOWN` | review required | [be-cross](be-cross-review.md) | todo |
| 121 | BEX-T14 | smart_tasks, audit_logs, notifications, transport_locations, suppliers, companies, partners, observability | MAJOR | Paginated endpoints for the largest tables + remaining route permissions | BEW0-04 | no | additive `/paginated`; 403 | review required | [be-cross](be-cross-review.md) | todo |
| 122 | BEX-T15 | audit_logs, auth, import_files | MAJOR | Audit trail actor, audit-log access, report exports | BEW0-04 | no | yes: `audit_logs.view`, `reports.export` | review required | [be-cross](be-cross-review.md) | todo |
| 123 | BEX-T17 | new system_parameters API, main.py | MAJOR | Settings API for system parameters + version-check hygiene | none | no | yes: new GET / PUT | review required | [be-cross](be-cross-review.md) | todo |
| 124 | BEX-T16 | database, lifecycle_board | MAJOR | DB integrity: FK pragma, stage uniqueness (audit columns moved to BEW0-05) | BEX-T02, BEW0-05; Q5 | **yes** (dedupe + unique index, pragma) | additive | review required | [be-cross](be-cross-review.md) | todo |
| 125 | BE03-T10 | docs_customs_approval | MAJOR | DCA ticket status workflow and session four-eyes | none | no | yes: 422 / 409 `DCA_TICKET_CLOSED`, `DCA_SAME_REVIEWER` | review required | [be-03](be-03-review.md) | todo |
| 126 | BE03-T20 | import_documentation | MAJOR | External LLM parsing behind an explicit setting | Q2 (be-03) | no | no | review required | [be-03](be-03-review.md) | todo |
| 127 | BE01-T08 | customs_consultation, import_requirements | MAJOR | One commit per use case | BE01-T01, BE01-T03, BE01-T06 | no | no | yes | [be-01](be-01-review.md) | todo |
| 128 | BE01-T09 | customs_consultation | MAJOR | Audit wiring for broker price lists and expense types | BE01-T08, BEW0-05 | via BEW0-05 | additive | yes | [be-01](be-01-review.md) | todo |
| 129 | BE01-T10 | freight_quotations | MAJOR | Audit wiring for freight RFQs | BE01-T04, BEW0-05 | via BEW0-05 | additive | yes | [be-01](be-01-review.md) | todo |
| 130 | BE01-T11 | purchase_orders | MAJOR | PO status workflow and lifecycle guards | BE01-T07 | no | yes: `PO_NOT_EDITABLE`, `PO_HAS_ALLOCATIONS` | yes | [be-01](be-01-review.md) | todo |
| 131 | BE01-T12 | customs_consultation | MAJOR | Consultation validation (FKs, clone guard, nulls, money inputs, dates) | BE01-T01, BE01-T03 | no | yes: stricter 400 / 409 / 422 | yes | [be-01](be-01-review.md) | todo |
| 132 | BE01-T13 | shipping_scenarios | MAJOR | Scenario clone guard and update re-validation | BE01-T02 | no | yes: 409 `SCENARIO_SESSION_EXISTS`, 422 | yes | [be-01](be-01-review.md) | todo |
| 133 | BE01-T14 | cbm_calculator | MAJOR | CBM totals pushed on update and link consistently | none | no | no (404 on inactive) | yes | [be-01](be-01-review.md) | todo |
| 134 | BE01-T15 | purchase_orders | MAJOR | Paginated PO list (`/purchase-orders/paginated`, summary rows) | BE01-T11, BEW0-04 | no | additive | yes | [be-01](be-01-review.md) | todo |
| 135 | BE01-T16 | purchase_orders, customs_consultation, freight_quotations | MAJOR | Legacy-tolerant response schemas | BE01-T07, BE01-T12, BE01-T04 | no | no | yes | [be-01](be-01-review.md) | todo |
| 136 | BE01-T18 | 4 phase-01 modules | MAJOR | Currency fields validated against the master, no invented defaults | BE01-T13, BE01-T12, BE01-T05, BE01-T06, BEW0-02 | no (option B: Q9) | yes: currency required with a price | yes | [be-01](be-01-review.md) | todo |
| 137 | BE02-T07 | financial_approval | MAJOR | SWIFT file extraction off the event loop + OCR page cap | none | no | no | yes | [be-02](be-02-review.md) | todo |
| 138 | BE02-T08 | financial_approval | MAJOR | `/paginated` for payment requests and budgets | BEW0-04 | no | additive | yes | [be-02](be-02-review.md) | todo |
| 139 | BE02-T10 | financial_approval | MAJOR | Money and currency input validation on request schemas | BEW0-02 | no | yes: currency required, `gt=0` | yes | [be-02](be-02-review.md) | todo |
| 140 | BE02-T11 | financial_approval | MAJOR | Validate master data on create and update | BE02-T10, BEW0-02 | no | yes: `FA_CURRENCY_UNKNOWN`, 404 | yes | [be-02](be-02-review.md) | todo |
| 141 | BE02-T13 | financial_approval | MAJOR | Batch reconcile without fabricated reference or date | none | no | yes: `FA_SWIFT_VALUE_DATE_INVALID` | yes | [be-02](be-02-review.md) | todo |
| 142 | BE02-T15 | financial_approval | MAJOR | Audit wiring `created_by` / `updated_by` | BEW0-05 | via BEW0-05 | additive | yes | [be-02](be-02-review.md) | todo |
| 143 | BE03-T09 | import_documentation | MAJOR | Document workflows fire once per transition | BE03-T06 | no | no | yes | [be-03](be-03-review.md) | todo |
| 144 | BE03-T11 | import_documentation, docs_customs_approval | MAJOR | Real PO sources in compare and DCA matrix | none | no | additive `system_items_missing` | yes | [be-03](be-03-review.md) | todo |
| 145 | BE03-T12 | import_documentation | MAJOR | Inspection draft template without invented standards | none | no | yes: empty `coc_number`, `missing_fields` | yes | [be-03](be-03-review.md) | todo |
| 146 | BE03-T13 | import_documentation | MAJOR | Declaration 46 and banking document validation | BEW0-02 | no | yes: currency required, 409 | yes | [be-03](be-03-review.md) | todo |
| 147 | BE03-T14 | import_documentation, docs_customs_approval | MAJOR | `/paginated` registries + raw text limits | BEW0-04 | no | additive; 422 > 200,000 chars | yes | [be-03](be-03-review.md) | todo |
| 148 | BE03-T15 | smart_document_upload | MAJOR | Smart-upload parsing off the event loop | none | no | no | yes | [be-03](be-03-review.md) | todo |
| 149 | BE03-T16 | import_documentation | MAJOR | Certified COO review is locked | none | no | yes: 409 | yes | [be-03](be-03-review.md) | todo |
| 150 | BE03-T17 | import_documentation, docs_customs_approval, original_documents_collection | MAJOR | Transaction hygiene (lifecycle call last, repo flush) | none | no | no | yes | [be-03](be-03-review.md) | todo |
| 151 | BE03-T18 | import_documentation | MAJOR | Audit wiring on the 9 documentation tables | BEW0-05 | via BEW0-05 | additive | yes | [be-03](be-03-review.md) | todo |
| 152 | BE45-T10 | demurrage_detention | MAJOR | Demurrage date sanity and the EIR step guard | none | no | yes: `empty_return_date` required, 422 future | yes | [be-04-05](be-04-05-review.md) | todo |
| 153 | BE45-T12 | freight_booking | MAJOR | Lock Sailed and Cancelled bookings | BE45-T04 | no | yes: 409 | yes | [be-04-05](be-04-05-review.md) | todo |
| 154 | BE45-T15 | freight_booking, cargo_shipping | MAJOR | `/paginated` for booking and cargo shipping lists | BEW0-04 | no | additive | yes | [be-04-05](be-04-05-review.md) | todo |
| 155 | BE45-T16 | shipment_updates, demurrage_detention | MAJOR | `/paginated` for shipment updates, trackings, policies; radar cost | BE45-T15 | no | additive; radar filter | yes | [be-04-05](be-04-05-review.md) | todo |
| 156 | BE45-T17 | cargo_shipping, cargo_insurance, shipment_updates, demurrage_detention | MAJOR | Legacy-tolerant response schemas | none | no | no | yes | [be-04-05](be-04-05-review.md) | todo |
| 157 | BE45-T18 | cargo_insurance, demurrage_detention | MAJOR | Remove invented defaults | BE45-T17 | no | yes: required port / container type, nullable fields | yes | [be-04-05](be-04-05-review.md) | todo |
| 158 | BE45-T19 | freight_booking | MAJOR | Booking FK master data on update | BE45-T12 | no | additive FK ids; Literal types | yes | [be-04-05](be-04-05-review.md) | todo |
| 159 | BE45-T21 | freight_booking | MAJOR | Audit wiring on `shipment_bookings` | BEW0-05 | via BEW0-05 (backfill from owner) | additive | yes | [be-04-05](be-04-05-review.md) | todo |
| 160 | BE67-T11 | customs_tariff | MAJOR | customs_tariff repository without commits | BE67-T08, BE67-T09 | no | no | yes | [be-06-07](be-06-07-review.md) | todo |
| 161 | BE67-T15 | customs_tariff | MAJOR | `/customs-tariff/paginated` + fee code validation | BE67-T01, BEW0-04 | no | yes: paging; 409 / 422 fee codes | yes | [be-06-07](be-06-07-review.md) | todo |
| 162 | BE67-T17 | customs_clearance | MAJOR | No invented customs values in CS-03 / CL-01 / CS-01 | BE67-T07 | no | yes: required channel / office / result | yes | [be-06-07](be-06-07-review.md) | todo |
| 163 | BE67-T19 | customs_clearance_quotations | MAJOR | Quotation award workflow and master data | none | no | yes: 409 `CCQ_RFQ_AWARDED` | yes | [be-06-07](be-06-07-review.md) | todo |
| 164 | BE810-T08 | file_closure | MAJOR | `closure_readiness` from the closure gate | BE810-T03, BE810-T06, BE810-T07 | no | no (values) | yes | [be-08-10](be-08-10-review.md) | todo |
| 165 | BE810-T09 | file_closure | MAJOR | Preconditions for dossier export and draft closure | BE810-T08 | no | yes: 400 `FC_EXPORT_BLOCKED` | yes | [be-08-10](be-08-10-review.md) | todo |
| 166 | BE810-T10 | file_closure, warehouse_receiving | MAJOR | Acting user from the token for auditor / exporter / inspector | none | no | yes: body names ignored | yes | [be-08-10](be-08-10-review.md) | todo |
| 167 | BE810-T11 | warehouse_receiving | MAJOR | GRN create preconditions (lines, warehouse, customs release) | BE810-T02 | no | yes: 422, `WR_CUSTOMS_NOT_RELEASED` | yes | [be-08-10](be-08-10-review.md) | todo |
| 168 | BE810-T12 | warehouse_receiving | MAJOR | Claim amount and currency validation | BEW0-02 | no | yes: `WR_CLAIM_CURRENCY_INVALID` | yes | [be-08-10](be-08-10-review.md) | todo |
| 169 | BE810-T13 | inland_transport | MAJOR | IT create validation (status, dates, carrier, truck type, defaults) | BE810-T01 | no | yes: required fields, `IT_CARRIER_INVALID`, `IT_TRUCK_TYPE_INVALID` | yes | [be-08-10](be-08-10-review.md) | todo |
| 170 | BE810-T14 | inland_transport | MAJOR | Keep gate-out / arrival evidence | BE810-T13 | no | yes: 400 broken seal without number | yes | [be-08-10](be-08-10-review.md) | todo |
| 171 | BE810-T15 | inland_transport | MAJOR | IT restore endpoint | BE810-T01, BE810-T02 | no | yes: new PATCH restore | yes | [be-08-10](be-08-10-review.md) | todo |
| 172 | BE810-T16 | warehouse_receiving | MAJOR | GRN delete guard | BE810-T02 | no | yes: 409 `WR_GRN_LOCKED` | yes | [be-08-10](be-08-10-review.md) | todo |
| 173 | BE810-T17 | warehouse_receiving, inland_transport, file_closure | MAJOR | Audit trail for WR, IT and closure events | BE810-T01, BE810-T05, BE810-T15, BE810-T16 | no | no | yes | [be-08-10](be-08-10-review.md) | todo |
| 174 | BE810-T18 | warehouse_receiving, inland_transport | MAJOR | `/paginated` for GRN and IT lists | BEW0-04 | no | additive | yes | [be-08-10](be-08-10-review.md) | todo |
| 175 | BE09-T08 | financial_settlement | MAJOR | Audit rows and task closure for every settlement transition | none | no | no | yes | [be-09](be-09-review.md) | todo |
| 176 | BE09-T12 | financial_settlement | MAJOR | Response tolerance, coded duplicate, `/paginated` | BEW0-04 | no | yes: 409 `SETTLEMENT_DUPLICATE_ACTIVE`, nullable fields | yes | [be-09](be-09-review.md) | todo |
| 177 | BEX-T03 | lifecycle_board | MAJOR | No invented data, bounded live tracking | none | no | yes: nullable card fields, risk "Unknown" | yes | [be-cross](be-cross-review.md) | todo |

## Wave 3: MINOR

| # | Task id | Scope | Sev | Title | Depends on | Migration | API change | Safe for Antigravity | Report link | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 178 | ACC1-T12 | customs_tariff | MINOR | Clear totals in engine and simulation responses | ACC1-T02, BE01-T03; Q6 | no | additive | review required | [acc-customs](acc-customs-review.md) | todo |
| 179 | ACC1-T13 | recalculation | MINOR | Recalculation FOB scaling and source currency | none | no | no | review required | [acc-customs](acc-customs-review.md) | todo |
| 180 | ACC1-T14 | customs_tariff, customs_consultation | MINOR | Decimal until the response + written rounding policy | Q5, Q9 (acc-customs) | no | no | review required | [acc-customs](acc-customs-review.md) | todo |
| 181 | ACC2-T15 | financial_settlement, recalculation | MINOR | Engine robustness and configurable thresholds | ACC2-T05 | no | no | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 182 | ACC2-T17 | currencies | MINOR | Currency master integrity (one base, one rate per date) | BEX-T04, BEW0-01 | no | yes: `replace` flag, 409 codes | review required | [acc-settlement](acc-settlement-review.md) | todo |
| 183 | ACC3-T10 | demurrage_detention | MINOR | Radar totals include returned, unsettled containers | ACC3-T04 | no | additive `is_final` | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 184 | ACC3-T11 | customs_clearance_quotations | MINOR | Clearance quotation totals on update and mixed currencies | none | no | additive `lowest_cost_currency` | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 185 | ACC3-T12 | cargo_insurance | MINOR | Insured value formula (after CTO answer) | Q5 (acc-logistics) | no | no (values) | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 186 | ACC3-T13 | cbm_calculator | MINOR | CBM weight units and required weight for air | none | no | additive `weight_unit` | review required | [acc-logistics](acc-logistics-costs-review.md) | todo |
| 187 | BE01-T19 | import_requirements | MINOR | Requirement task sync hygiene | BE01-T08 | no | no | yes | [be-01](be-01-review.md) | todo |
| 188 | BE01-T20 | 4 phase-01 validators | MINOR | Arabic user-facing messages in Phase 01 validators | BE01-T12, BE01-T13, BE01-T14, BE01-T04 | no | no | yes | [be-01](be-01-review.md) | todo |
| 189 | BE01-T21 | purchase_orders | MINOR | PO invented fallbacks (clone qty, balance currency) | BE01-T15 | no | yes: nullable `currency_code` | yes | [be-01](be-01-review.md) | todo |
| 190 | BE01-T22 | shipping_scenarios, freight_quotations | MINOR | One owner for `import_files.selected_scenario`, ports by id | BE01-T04, BE01-T13; Q10 | no | no | yes | [be-01](be-01-review.md) | todo |
| 191 | BE02-T16 | financial_approval | MINOR | Hygiene: status codes, Arabic details, layering, revision race | none | no | yes: small (409, 422, 404) | yes | [be-02](be-02-review.md) | todo |
| 192 | BE02-T17 | financial_approval | MINOR | Task auto-close and `import_files.swift_no` scope | BE02-T04 | no | no | yes | [be-02](be-02-review.md) | todo |
| 193 | BE02-T18 | financial_approval | MINOR | Legacy-tolerant budget money and base64 size limit | none | no | yes: nullable money | yes | [be-02](be-02-review.md) | todo |
| 194 | BE03-T19 | import_documentation, original_documents_collection | MINOR | Minor hygiene (no EUR fallback, no DHL default, validators in service) | none | no | yes: nullable currency / courier | yes | [be-03](be-03-review.md) | todo |
| 195 | BE45-T23 | cargo_insurance, shipment_updates, demurrage_detention | MINOR | Restore endpoints (+ tracking delete) | BE45-T05, BE45-T06 | no | yes: new endpoints | yes | [be-04-05](be-04-05-review.md) | todo |
| 196 | BE67-T20 | customs_clearance_quotations | MINOR | Audit wiring on the quotation tables | BE67-T19, BEW0-05 | via BEW0-05 | additive | yes | [be-06-07](be-06-07-review.md) | todo |
| 197 | BE67-T21 | customs_clearance, customs_tariff | MINOR | Minor hygiene (clearance `/paginated`, messages, history, dead code) | BE67-T11, BE67-T18, BEW0-04 | no | additive | yes | [be-06-07](be-06-07-review.md) | todo |
| 198 | BE810-T19 | warehouse_receiving | MINOR | Warehouse receiving hygiene | BE810-T05 | no | yes: small | yes | [be-08-10](be-08-10-review.md) | todo |
| 199 | BE810-T20 | inland_transport, file_closure | MINOR | IT and closure hygiene | BE810-T09, BE810-T13 | no | yes: `already_closed` key | yes | [be-08-10](be-08-10-review.md) | todo |
| 200 | BE09-T14 | financial_settlement, recalculation | MINOR | Hygiene: soft-delete fields wiring, incoterm, justification, dependency list | BEW0-05 | via BEW0-05 | yes: 422 incoterm | yes | [be-09](be-09-review.md) | todo |

Merged away (no own row): BE67-T03 and BEX-T07 -> BEW0-01; BE67-T05 and BE09-T04 -> BEW0-06; BEX-T13 -> BEW0-04;
ACC3-T01 -> BE45-T01. Their steps and tests stay in the source reports and are part of the owning task.

## How to execute a task

1. Pick the first `todo` row whose "Depends on" tasks are `done` and whose CTO question (Qn, numbered per report) is
   answered or has a safe default in the report. Antigravity takes only rows marked **yes**.
2. Read the task in its report (findings table + task section + "Frontend impact" + "Open questions"), and for a `BEW0-*`
   task the card in README section 6. Read `.claude/rules/backend.md` and, for money, `.agents/rules/DOMAIN_RULES.md` §2-3.
3. Check the branch (`git rev-parse --abbrev-ref HEAD`), branch from `main` as `fix/<task-id>-<slug>`. One task per branch
   and per PR. Track 1 only: no version bump, no `version.json`, no packaging.
4. Implement exactly the listed steps and files (Router -> Service -> Repository; no business logic in routers; Arabic
   `detail`; no invented values; register every new coded error in the same change).
5. Tests: write the tests listed in the task (numeric examples as assertions). Run with a scratch `DATABASE_PATH`, never
   against `sorour_logistics.db`; before testing a write path on a copy of real data run
   `python scripts/daily_backup.py --test`. Run pytest on the touched test files with `--junitxml=<scratch>/junit.xml` and
   read the XML and the exit code.
6. Migration tasks: only one open at a time; `down_revision` = the single current head; upgrade on a scratch DB.
7. Review before merge: `diff-reviewer` for all; `customs-rules-reviewer` for money tasks; `security-reviewer` for auth /
   permission tasks. Rows marked **review required** need a senior reviewer.
8. After merge: set Status to `done (PR #n)`, append one line to `history/YYYY-MM-DD.md`, and tell the frontend owner when
   the API change column is not "no".
