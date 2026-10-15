# Review shared needs (append-only)

## 03a-D2 shared needs

New system message codes emitted by `modules/import_documentation/service.py` as plain `{code, params}`
(not yet in `system_messages.CATALOG`, so `to_item` is not used). Register in `system_messages.py` +
`docs/system_message_codes.json`:

| code | params | English template |
|---|---|---|
| `DOC_ACID_TRACKER_STATUS` | `status` (tracker status value: Valid / Expiring Soon / Expired / Customs Released / Pending Issue), `days` (days remaining, negative when expired) | `ACID status: {status} ({days} days remaining).` |
| `DOC_LEGAL_DOC_EXPIRED` | `doc_kind`, `doc_number`, `expiry_date`, `eta_date`, `days` | `{doc_kind} {doc_number} expired on {expiry_date}: shipping and customs release are blocked.` |
| `DOC_LEGAL_DOC_CRITICAL_BREACH` | same | `{doc_kind} {doc_number} expires on {expiry_date}, less than 30 days after the expected arrival {eta_date}.` |
| `DOC_LEGAL_DOC_EXPIRING_SOON` | same | `{doc_kind} {doc_number} expires on {expiry_date} ({days} days left).` |
| `DOC_LEGAL_DOC_VALID` | same | `{doc_kind} {doc_number} is valid until {expiry_date}.` |
| `DOC_LEGAL_ACID_MISSING` | same (`expiry_date`, `days` are null) | `The ACID validity date of this shipment is not recorded yet.` |
| `DOC_LEGAL_BANNER` | `critical_count` | `Critical shipment safety warning (ETA + 30 days margin): {critical_count} document(s) need action.` |
| `DOC_INVOICE_BL_SYNCED` | `invoice_number`, `draft_bl_number` | `Invoice {invoice_number} and B/L {draft_bl_number} matched, approved and synced to the import file and customs approvals.` |

Enum code set `LEGAL_DOC_KIND`: `ACID`, `IMPORT_CARD`, `COMMERCIAL_REGISTRY`, `TAX_CARD` (used in `doc_kind`).

Schema fields D2 passes that D1 must declare (until then Pydantic drops them silently):
- `AcidTrackerItem.message_code: Optional[str]`, `message_params: Optional[Dict[str, Any]]`; `importer_name` /
  `supplier_name` should become `Optional[str]` (D2 sends `None` once the field accepts it, `""` before).
- `LegalDocAlertItem.message_code`, `message_params`; `LegalDocsExpiryComplianceResponse.banner_message_code`,
  `banner_message_params`.
- `COODraftTemplateResponse.missing_fields: List[str] = []`, `InspectionDraftTemplateResponse.missing_fields`
  (already also inside `template_data["missing_fields"]`).
- `POReconciliationItem.packing_item_id: Optional[int] = None` (+ `ge=0` on quantities / weights).


## 03b shared needs

Owner of `modules/common`, `docs/*.json`, `financial_settlement`. Phase 3b (ODC / DCA / SDU) uses these as plain
`detail={"code", "message", ...params}` dicts or response fields today, so nothing fails while unregistered.

### Message codes (`modules/common/system_messages.py` + `docs/system_message_codes.json`)

| Code | HTTP / where | Params | English template |
|---|---|---|---|
| `ODC_COURIER_NOT_FOUND` | 404 confirm-receipt | `courier_no`, `import_file_id` | Courier {courier_no} is not registered on this file's original documents session. Add it to the session first. |
| `ODC_SESSION_NOT_FOUND` | 404 GET /original-documents-collection/sessions/by-file/{id} | `import_file_id` | No original documents collection session exists for import file {import_file_id}. |
| `DCA_SESSION_FINAL_LOCKED` | 409 POST /docs-customs-approval/sessions | `session_code` | Customs approval session {session_code} is certified and can no longer be changed. |
| `DCA_SESSION_NOT_READY` | 400 same | `missing_statuses` (list), `open_tickets_count` | The session cannot be certified: document statuses not set ({missing_statuses}); open rectification tickets: {open_tickets_count}. |
| `DCA_TICKET_CLOSED` | 409 resolve ticket | `ticket_code`, `status` | Rectification ticket {ticket_code} is already closed ({status}). |
| `SDU_ACID_INVALID` | 400 apply invoice | `acid_number` | The extracted ACID number {acid_number} is invalid: it must be 19 digits. |
| `SDU_ACID_CONFLICT` | 409 apply invoice | `acid_number`, `current_acid_number`, `import_file_code` | The extracted ACID {acid_number} differs from the ACID on file {import_file_code} ({current_acid_number}). |
| `DCA_SAME_REVIEWER` | 409 POST /docs-customs-approval/{id}/commercial-review and /customs-review | `approval_code`, `reviewer` | {reviewer} already signed the other review tier of {approval_code}: the commercial and customs reviews need two different users. |
| `SDU_FILE_CLOSED` | 409 POST /smart-upload/apply/commercial-invoice and /apply/bill-of-lading | `import_file_code`, `status` | Import file {import_file_code} is {status}: extracted data cannot be applied to it. |
| `SDU_INVOICE_APPLIED` | apply invoice `msg_code` | `import_file_code`, `invoice_no` | Invoice {invoice_no} data applied to file {import_file_code}. |
| `SDU_BL_APPLIED` | apply B/L `msg_code` | `cargo_shipping_code`, `containers_applied` | B/L data applied to shipment {cargo_shipping_code} ({containers_applied} containers). |
| `SDU_EXTRACTED_ONLY` | apply `msg_code` (no target) | - | Data extracted and ready to use for a new file. |
| `XCHK_ACID_MISMATCH` | cross-check `issues[]` | - | ACID number mismatch between the commercial invoice and the bill of lading |
| `XCHK_TAX_ID_MISMATCH` | same | - | Egyptian importer tax ID mismatch between the invoice and the bill of lading |
| `XCHK_SHIPPER_MISMATCH` | same | `similarity_pct` | Shipper / exporter name differs (similarity {similarity_pct}%) |
| `XCHK_CONSIGNEE_MISMATCH` | same | `similarity_pct` | Consignee / importer name differs (similarity {similarity_pct}%) |
| `XCHK_WEIGHT_OVER` | same | `diff_kg`, `variance_pct`, `tolerance_pct` | Gross weight variance of {diff_kg} kg ({variance_pct}%) exceeds the allowed tolerance ({tolerance_pct}%) |
| `XCHK_WEIGHT_MINOR` | same | `diff_kg`, `variance_pct` | Minor gross weight difference of {diff_kg} kg ({variance_pct}%) within the accepted tolerance |
| `XCHK_PORTS_MISMATCH` | same | - | Port of loading or port of discharge does not fully match |
| `XCHK_INCOTERM_PREPAID_CONFLICT` | same | `incoterm` | Shipping terms conflict: invoice term {incoterm} but the bill of lading is Freight Prepaid |
| `XCHK_INCOTERM_COLLECT_CONFLICT` | same | `incoterm` | Shipping terms conflict: invoice term {incoterm} includes freight but the bill of lading is Freight Collect |
| `XCHK_PACKAGES_MISMATCH` | same | `invoice_packages`, `bl_packages` | Package count differs between the invoice ({invoice_packages}) and the bill of lading ({bl_packages}) |

The English XCHK templates live in `modules/smart_document_upload/cross_checker.py` (`XCHK_TEMPLATES_EN`) until registered.

### Enum codes (`modules/common/enum_codes.py`), local sets today

- `ODC_STATUS`: DRAFT, IN_TRANSIT, PARTIALLY_RECEIVED, FULLY_RECEIVED, FULLY_VERIFIED, DISCREPANCY_NOTED (stored as codes already).
- `ORIGINAL_DOC_STATUS`: PENDING, IN_TRANSIT, RECEIVED, VERIFIED, DISCREPANT, NOT_REQUIRED (stored as the labels "Pending" ... "Not Required" this wave). `ORIGINAL_DOC_REQUIRED`: YES, NO, CONDITIONAL.
- `COURIER_STATUS`: DISPATCHED, IN_TRANSIT, DELIVERED, DELAYED.
- `DOC_REVIEW_STATUS`, `DOC_APPROVAL_STATUS`, `TICKET_STATUS`, `TICKET_SEVERITY`: as in the plan section 6 (labels stored this wave, Q6). Local sets: `modules/original_documents_collection/validators.py`, `modules/docs_customs_approval/validators.py`.

### Other

- `modules/common/clock.py` (`cairo_today`, `cairo_date`) was created as a copy; `financial_settlement/service.py` can re-import it (owner's call).
- Schema (deferred): `created_by/updated_by` on `customs_document_approvals` + `discrepancy_rectification_tickets`; ODC dates as `Date`; `upload_sessions.created_by` type.


## 02 shared needs

Phase 2 (financial approval, `modules/financial_approval`). All codes are raised today as plain
`HTTPException(detail={"code", "message" (Arabic), **params})` dicts (`validators.fa_error`) or returned as
`message_code` / `message_params` response fields, so nothing fails while unregistered.

### Message codes (`modules/common/system_messages.py` + `docs/system_message_codes.json` + both Flutter catalogs)

| Code | HTTP / where | Params | English template |
|---|---|---|---|
| `FA_FX_RATE_MISSING` | 400 GET /prefill/{id}, POST /import-budgets/{id}/sync, POST .../clone (payment + budget) | `currency_code` | No exchange rate is recorded for {currency_code}. Add it on the Currencies screen. |
| `FA_SWIFT_CURRENCY_MISMATCH` | 400 reconcile-swift, swift/smart-reconcile, review-batch/{id}/reconcile | `swift_currency`, `currency_code` | The SWIFT currency {swift_currency} does not match the payment request currency {currency_code}. |
| `FA_SWIFT_REF_ALREADY_USED` | 409 pay, reconcile-swift, smart-reconcile, batch reconcile | `swift_ref`, `payment_code` | SWIFT reference {swift_ref} is already used by payment request {payment_code}. |
| `FA_SWIFT_BATCH_ALREADY_RECONCILED` | 409 review-batch/{id}/reconcile | `batch_code`, `payment_code` | SWIFT batch {batch_code} is already reconciled with payment request {payment_code}. |
| `FA_SWIFT_BATCH_STATUS_INVALID` | 409 confirm (batch not pending review), 400 field edit / re-extract (RECONCILED / REJECTED), 403 batch reconcile before confirmation | `batch_code`, `status` | This action is not allowed on SWIFT batch {batch_code} in status {status}. |
| `FA_PAYMENT_STATUS_INVALID` | 400 approve / pay / reconcile / PUT status | `payment_code`, `status`, `action` (approve, pay, reconcile, status:<target>) | Payment request {payment_code} is {status}: the action {action} is not allowed. |
| `FA_PAYMENT_LOCKED` | 409 PUT and DELETE of an Approved / Paid request | `payment_code`, `status` | An approved or paid payment request ({payment_code}, {status}) cannot be changed or deleted. |
| `FA_BUDGET_LOCKED` | 409 PUT / DELETE of a Budget Approved / Superseded budget, sync of a Superseded budget | `budget_code`, `status` | An approved or superseded budget ({budget_code}, {status}) cannot be changed: sync it to create a new revision. |
| `FA_BUDGET_STATUS_INVALID` | 409 POST /import-budgets/{id}/approve | `budget_code`, `status` | Budget {budget_code} cannot be approved in status {status}. |
| `FA_PAYMENT_DUPLICATE_TYPE` | 400 create / PUT / clone / restore payment request | `payment_type` (PAYMENT_TYPE code), `payment_code` | An open payment request of type {payment_type} already exists for this file ({payment_code}). |
| `FA_BUDGET_DUPLICATE_FILE` | 400 create / PUT / clone / restore budget | `import_file_code` | A budget already exists for import file {import_file_code}. Edit it instead of creating a new one. |
| `FA_BUDGET_HARD_BLOCK` | 400 budget approve, budget sync without justification | `variance_percentage`, `field_name` (budget column) | The cost variance of {variance_percentage}% on {field_name} exceeds the threshold (hard block): sync the costs or give a written justification. |
| `FA_BUDGET_SOD_DENIED` | 403 budget sync | - | Segregation of duties: the user who changed the upstream costs cannot sync the approved budget. |
| `FA_BUDGET_SYNC_REVISION_CREATED` | sync response `message_code` | `budget_code` | Budget revision {budget_code} created; the approved version was archived as superseded. |
| `FA_BUDGET_SYNC_DONE` | sync response `message_code` | `budget_code`, `status` | Budget {budget_code} synced with live costs; status {status}. |
| `FA_SWIFT_BATCH_CONFIRMED` | confirm response `message_code` | `batch_code` | SWIFT data of batch {batch_code} confirmed; matching is unlocked. |
| `FA_SWIFT_FILE_TOO_LARGE` | 413 swift/smart-extract-file, swift/smart-extract-base64 | `max_mb` | The SWIFT file exceeds the {max_mb} MB limit. |
| `FA_SWIFT_FILE_INVALID_BASE64` | 400 swift/smart-extract-base64 | - | The uploaded file content is not valid Base64. |
| `FA_CODE_GENERATION_CONFLICT` | 409 create / clone (code taken 3 times in a row), sync revision code already taken | `reference_code` | Reference {reference_code} is already in use. Please try again. |

### Enum code set `PAYMENT_TYPE` (`modules/common/enum_codes.py`, `docs/enum_codes.json`, Flutter `domain_enum_labels.dart`)

| Code | English label | Legacy aliases accepted on input |
|---|---|---|
| `ADVANCE_PAYMENT` | Advance Payment | "Advance Payment", "Advance" |
| `AGAINST_BL` | Against B/L | "Against B/L", "Against BL" |
| `LETTER_OF_CREDIT` | Letter of Credit (L/C) | "Letter of Credit (L/C)", "Letter of Credit", "L/C", "LC" |
| `DOCUMENTARY_COLLECTION` | Documentary Collection (CAD) | "Documentary Collection (CAD)", "Documentary Collection", "CAD" |
| `FINAL_SETTLEMENT` | Final Settlement | "Final Settlement" |

Local copy today: `modules/financial_approval/validators.py` (`PAYMENT_TYPE_LABELS_EN`, `_PAYMENT_TYPE_ALIASES`).
`normalize_payment_type` switches to `enum_codes.normalize("PAYMENT_TYPE", ...)` automatically once the type is
registered, so keep the same codes and aliases there. Rows keep their legacy labels in the DB (no backfill this wave);
responses show the code.

### RBAC note (lead decision)

LOGISTICS_OPERATOR and CUSTOMS_OFFICER hold `financial_approval.manage` but not `financial_approval.view`. Reads
(list, get, prefill, batch review, match, variance logs, threshold GET) require `.view`, so the advance / duty payment
dialogs that call GET /prefill/{id} or the lists return 403 for them. Either grant them `financial_approval.view`
(one-time grant) or confirm the dialogs only POST.

## 09 shared needs

Source: phase-09 BE (financial_settlement, recalculation). BE emits plain `{code, params}` dicts / `HTTPException(detail={"code", "message", **params})` until these are registered.

System message codes (`modules/common/system_messages.py` + `docs/system_message_codes.json`), params and English template:
- `SETTLEMENT_FX_RATE_MISSING` (currency, on_date): "No exchange rate for {currency} on {on_date}. Register the rate before calculating the settlement." (409)
- `SETTLEMENT_NOT_EDITABLE` (status, settlement_code): "Settlement {settlement_code} is {status} and cannot be edited or recalculated." (409)
- `SETTLEMENT_DUPLICATE_ACTIVE` (settlement_code): "Cannot restore: another active settlement ({settlement_code}) exists for this import file." (409)
- `INVOICES_ALREADY_SETTLED` (import_file_code, status): "Invoices of {import_file_code} are already settled ({status})." (409)
- `JOURNAL_UNBALANCED` (difference, settlement_code): "The journal entry is unbalanced by {difference} EGP and cannot be exported." (409)
- `SETTLEMENT_LINE_NO_HS` (item_code, line_no): "Line {item_code} has no HS code: it is left out of the customs estimate." (messages[])
- `PAYMENT_STATUS_UNKNOWN` (invoice_no, party_name): "Invoice {invoice_no} is partially paid but the paid amount is unknown: counted as unpaid." (messages[])
- `ESTIMATE_UNAVAILABLE` (reason): "The estimated landed cost is unavailable ({reason}); variances are against zero." (messages[])
- `SETTLEMENT_UNPAID_INVOICE` (party_name, amount, invoice_no): "Unpaid balance for {party_name}: {amount} EGP (invoice {invoice_no})." (messages[])
- `WHT_RATE_MISSING_WARNING` (tax_code, on_date, invoice_no): "No withholding tax rate ({tax_code}) valid on {on_date}: no deduction on invoice {invoice_no}." (messages[])
- `RECALC_NO_VARIANCE` (): "No variance: all costs match the live sources."
- `RECALC_SOFT_VARIANCE` (threshold): "Cost variances below {threshold}% found. You can sync with a warning."
- `RECALC_HARD_BLOCK` (threshold): "A variance above {threshold}% was found. A written justification is required."
- `RECALC_APPLIED` (action_taken, new_entity_code): "Recalculation applied ({action_taken})."
- Frontend `api_error_text.dart`: the 409 codes above plus `WHT_RATE_NOT_CONFIGURED`. Recalc preview items may carry `status="RATE_MISSING"` with `message_code="SETTLEMENT_FX_RATE_MISSING"`.

System parameters (`modules/common/system_parameters.py` DEFAULT_PARAMETERS seed; read with these defaults when missing):
- `settlement.deemed_freight_pct` = 2 (deemed freight, % of FOB, PL-08)
- `settlement.deemed_insurance_pct` = 2.5 (deemed insurance, % of FOB)
- `settlement.default_clearance_egp` = 4500
- `settlement.default_port_handling_egp` = 5000
- `settlement.default_inland_transport_egp` = 7500
- `settlement.default_bank_fees_egp` = 2500
- `settlement.default_other_expenses_egp` = 2000

Enums (`modules/common/enum_codes.py` + `docs/enum_codes.json`):
- `ALLOCATION_RULE`: VALUE / WEIGHT / VOLUME / EQUAL mapped from "Value-Based" / "Weight-Based" / "Volume-Based" / "Equal" (API values unchanged).
- `SETTLEMENT_STATUS` (read-only legacy set): Draft, Calculated, Approved, Closed. PUT accepts Draft / Calculated only.
- `ACTUAL_COST_BUCKET` (stored as `bucket` on approved settlement rows): Freight, Insurance, Customs Duty, VAT & Taxes, Clearance & Port, Inland Transport, Demurrage & Storage, Other & Admin.

## 08-10 shared needs

Source: phase-08/10 BE (warehouse_receiving, inland_transport, file_closure). BE raises `HTTPException(detail={"code", "message", **params})` (Arabic `message`) until these are registered.

System message codes (`modules/common/system_messages.py` + `docs/system_message_codes.json`), params and English template:
- `WR_GRN_EXISTS` (grn_code): "An active goods receipt note ({grn_code}) already exists for this import file." (409, create and restore)
- `WR_GRN_LINE_UNBALANCED` (item_code, invoiced_qty, accepted_qty, shortage_qty, damaged_qty): "Line {item_code}: accepted {accepted_qty} + shortage {shortage_qty} + damaged {damaged_qty} must equal invoiced {invoiced_qty}." (400)
- `WR_VERDICT_INVALID` (verdict): "Unknown inspection verdict '{verdict}'." (400)
- `WR_VERDICT_INCONSISTENT` (verdict_enum_warehouse_inspection_verdict, shortage_qty, damaged_qty): "The verdict cannot be accepted in full with {shortage_qty} short and {damaged_qty} damaged." (400; BE param name today: `verdict`)
- `WR_STATUS_INVALID` (status): "Unknown goods receipt status '{status}'." (400)
- `WR_DISCREPANCY_TYPE_INVALID` (discrepancy_type): "Unknown discrepancy type '{discrepancy_type}'." (400)
- `IT_BOOKING_EXISTS` (transport_code, waybill_number): "An active inland booking ({transport_code}) already exists for waybill {waybill_number} on this file." (409)
- `IT_STATUS_INVALID` (status): "Unknown inland transport status '{status}'." (400)
- `IT_TRANSITION_NOT_ALLOWED` (current_status, action): "Cannot record {action} while the booking is '{current_status}'." (409; action = gate_out / warehouse_arrival)
- `FC_ALREADY_CLOSED` (import_file_code): "Import file {import_file_code} is already closed. Reopen it first." (409)
- `FC_CLOSURE_BLOCKED` (blocking): "The file cannot be closed: {blocking} not met." (400; blocking = comma list of customs_cleared, warehouse_received, warehouse_quarantine, landed_cost_settled, dossier_exported)
- `FC_CLOSED_RECORD_LOCKED` (closure_code): "Closure record {closure_code} belongs to a closed file: reopen the file first." (409, delete / PUT of locked fields)
- `FC_CLOSURE_EXISTS` (closure_code): "Cannot restore: another active closure record ({closure_code}) exists for this file." (409)
- `FC_STATUS_INVALID` (status): "A closure record can only be set back to Draft." (400)
- Plan FC-13 codes still open (precheck `blocking_messages` / `warning_messages` not shipped): `FC_BLOCK_CUSTOMS`, `FC_BLOCK_GRN`, `FC_BLOCK_GRN_QUARANTINE`, `FC_BLOCK_LANDED_COST`, `FC_BLOCK_DOSSIER`, `FC_WARN_CONTAINERS`, `FC_WARN_DOCS`, `FC_WARN_OPEN_TASKS` (count).

Other modules:
- `modules/import_files/service.py:reopen_shipment_service`: mark the active closure record "Reopened" (or deactivate it) with an audit entry and require `import_files.close`. BE now writes `closed_at_phase` on final close, so reopen restores the right phase.
- `modules/common/enum_codes.py`: WAREHOUSE_RECEIVING_STATUS, GRN_DISCREPANCY_TYPE (legacy labels incl. "Shortage and Damage", "Shortage Only", "Damage Only", "Broken Seal Discrepancy", "Damage & Shortage"), INLAND_TRANSPORT_STATUS, FILE_CLOSURE_STATUS. Module-local frozensets in the three validators.py are the source lists.

## 06-07 shared needs

Source: phase-06/07 BE (customs_clearance, customs_clearance_quotations). BE raises `HTTPException(detail={"code", "message", **params})` (Arabic `message`) until these are registered. Existing plain-string details are unchanged.

System message codes (`modules/common/system_messages.py` + `docs/system_message_codes.json`), params and English template:
- `CC_RELEASE_RECORD_FILE_MISMATCH` (clearance_id, import_file_id): "Clearance record {clearance_id} does not belong to import file {import_file_id}." (400, issue-final-release)
- `CC_DUTY_NOT_ASSESSED` (no params): "The duty payment cannot be recorded before the final duty assessment (CL-02)." (409, record-duty-payment and {id}/pay-duty)
- `CC_DUTY_UNDERPAID` (paid_amount, assessed_amount): "The paid amount {paid_amount} EGP is below the assessed duty of {assessed_amount} EGP." (400, payment routes and both release routes)
- `CC_DUTY_NOT_PAID` (no params): "The final release cannot be issued before the customs duty is paid (CL-03)." (400, both release routes, incl. no clearance record)
- `CC_DUTY_PAID_AMOUNT_REQUIRED` (no params): "The paid duty amount is required and must be above zero." (400, {id}/pay-duty)
- `CC_ASSESS_REQUIRES_DECLARATION_46` (import_file_id): "Final duties cannot be assessed before customs declaration 46 is registered (CS-03)." (409, assess-final-duties)
- `CC_UPDATE_NULL_NOT_ALLOWED` (fields): "These fields cannot be cleared: {fields}." (400, PUT /{id}; fields = comma list)
- `CC_RESTORE_DUPLICATE_ACTIVE` (clearance_code): "Cannot restore: another active clearance record ({clearance_code}) exists for this file." (409)
- `CC_UNDER_BOND_NOT_ALLOWED` (clearance_status): "Under-bond release refused: the shipment is already under bond or finally released ({clearance_status})." (409)
- `CC_INVOICE_FX_RATE_REQUIRED` (currency): "An exchange rate is required for an invoice in {currency}." (400, POST /invoices)
- `CC_INVOICE_RECORD_FILE_MISMATCH` (customs_clearance_id, import_file_id): "Clearance record {customs_clearance_id} does not belong to import file {import_file_id}." (400, POST /invoices)
- `CC_ACID_EXPIRY_INVALID` (import_file_id): "The ACID expiry date stored on import file {import_file_id} is invalid." (400, create / release)
- `CC_REFERENCE_CODE_CONFLICT` (no params): "A unique reference code could not be generated because of concurrent saves; please retry." (409)
- `CCQ_RFQ_STATUS_INVALID` (status): "RFQ status '{status}' is not allowed; awarding is done through the award action only." (400, PUT /rfqs/{id})
- `CCQ_RFQ_CANCELLED` (rfq_code): "RFQ {rfq_code} is cancelled and cannot be awarded." (409)
- `CCQ_QUOTE_EXPIRED` (validity_date): "The quotation expired on {validity_date}." (400, award)
- `CCQ_AWARDED_QUOTE_DELETE` (quotation_id): "The awarded quotation cannot be deleted." (409, DELETE /quotations/{id})
- `CCQ_PRICE_LIST_DATE_RANGE` (effective_from, effective_to): "The validity start {effective_from} is after its end {effective_to}." (400, price-list create / update)

- `CC_RELEASE_QUARANTINE_LOCKED` (clearance_code): "The final release cannot be issued while {clearance_code} is under the laboratory quarantine lock." (409, both release routes)
- `CC_LAB_RESULT_ALREADY_FINAL` (clearance_status): "The lab result was already recorded and the quarantine lifted, or the shipment is finally released ({clearance_status})." (409, lab-test-result)

- `CC_ASSESSED_COMPONENTS_LOCKED` (fields): "Duty components cannot be edited after the assessment ({fields}); re-assess the final duties (CL-02)." (409, PUT /{id})

Enum (`modules/common/enum_codes.py` + `docs/enum_codes.json`):
- `LAB_TEST_RESULT`: CONFORMING "Conforming", NON_CONFORMING "Non-Conforming", PENDING "Pending", NONE "None"; legacy: conforming, approved, مطابق, مقبول -> CONFORMING; non-conforming, non conforming, rejected, غير مطابق, مرفوض -> NON_CONFORMING. Local map today: `modules/customs_clearance/validators.py` (`normalize_lab_test_result`). Under-bond still writes the legacy "Pending" value until the enum lands.

Other modules (not changed here):
- `financial_settlement/service.py:1091` reads clearances without `is_active`; D/O fees summed as EGP whatever `delivery_order_currency` is (`:1126`). Landed cost reads `actual_duty_total`, which is now always the assessed total (CL-05).
- Read-only data check before deploy: count records where `duty_paid_amount != total_duty_payable` (old CL-03 overwrote `actual_duty_total` with the paid amount); no auto-repair.

## 04-05 shared needs

system_parameters to seed (insert-only). Readers: `modules/cargo_insurance/service.py` (`load_insurance_rates`) and
`modules/demurrage_detention/service.py` (`default_tariff`, `_standard_free_days`, `_cost_avoidance`). Each falls back
to the module constant (= the value below) when the key is missing or invalid, so seeding does not change any number.

| key | default | description |
|---|---|---|
| INSURANCE_RATE_ICC_A | 0.0025 | Cargo insurance base rate, Institute Cargo Clauses A (all risks) |
| INSURANCE_RATE_AIR_ALL_RISKS | 0.0020 | Cargo insurance base rate, air cargo all risks |
| INSURANCE_RATE_ICC_B | 0.0015 | Cargo insurance base rate, Institute Cargo Clauses B |
| INSURANCE_RATE_ICC_C | 0.0010 | Cargo insurance base rate, Institute Cargo Clauses C |
| INSURANCE_WAR_STRIKES_RATE | 0.0005 | War & strikes add-on rate on the insured value |
| INSURANCE_TAX_RATE | 0.05 | Tax / stamp duty rate on (net premium + issuance fee) (Q3) |
| INSURANCE_ISSUANCE_FEE | 15 | Fixed certificate issuance fee (certificate currency) |
| INSURANCE_MIN_PREMIUM | 30 | Minimum net premium (certificate currency) |
| INSURANCE_MARKUP | 0.10 | Insured value markup on CIF (0.10 = 110% CIF) |
| DD_DEFAULT_DEMURRAGE_TIERS | `[{"from_day":1,"to_day":7,"rate_per_day":40.0},{"from_day":8,"to_day":14,"rate_per_day":70.0},{"from_day":15,"to_day":null,"rate_per_day":120.0}]` | Default demurrage tiers (USD/day) when no carrier policy matches (JSON, read with get_parameter + json.loads; fits the 255-char column) |
| DD_DEFAULT_DETENTION_TIERS | `[{"from_day":1,"to_day":7,"rate_per_day":35.0},{"from_day":8,"to_day":14,"rate_per_day":65.0},{"from_day":15,"to_day":null,"rate_per_day":110.0}]` | Default detention tiers (USD/day) when no carrier policy matches (JSON) |
| DD_DEFAULT_FREE_DAYS_DEMURRAGE | 14 | Default demurrage free days without a policy |
| DD_DEFAULT_FREE_DAYS_DETENTION | 7 | Default detention free days without a policy |
| DD_DEFAULT_STORAGE_FREE_DAYS | 5 | Default port storage free days without a policy |
| DD_DEFAULT_STORAGE_RATE_EGP | 250 | Default port storage rate (EGP per container per day) without a policy |
| DD_STANDARD_FREE_DAYS | 14 | Standard free days used for the BK-02 cost-avoidance comparison |
| DD_AVOIDANCE_RATE_USD | 70 | USD/day per container used for the BK-02 estimated cost avoidance |

No new permission or message codes needed beyond the ones already registered (cargo_insurance.view/manage,
cargo_shipping.approve). `MANUAL_CHECK_REQUIRED` / `MANUALLY_CONFIRMED` are CargoX checklist `details` values, not catalog codes.

04-05 review addendum: candidate message code `DD_SETTLEMENT_STALE` (warning, no params beyond the tracking code): "The
demurrage charges of {tracking_code} were recalculated but its landed-cost settlement is locked; they were not re-pushed."
Returned today as a plain `settlement_warning_code` value (tracking PUT / single container / EIR responses) and as
`stale_settlement_tracking_codes` (BK-02 response); Flutter maps it until the catalog entry exists.

02 addendum (review fixes):

| Code | HTTP / where | Params | English template |
|---|---|---|---|
| `FA_CURRENCY_MISSING` | 400 GET /prefill/{id} (and sync / variance evaluation that use it) | `source` (PO number, invoice number or file code) | No currency is recorded for the amount of {source}. Set the currency first. |

Contract note: `BudgetPrefillResponse.exchange_rate` is nullable (null for an empty file whose currency has no rate).
- (09 addendum) `RECALC_RATE_MISSING` (fields): "Some items could not be compared: no exchange rate for their currency ({fields})." (recalc preview / no-op apply)
- (09 addendum) Settlement rows auto-fetched from customs carry `duty_component` (import_duty_amount, vat_amount, schedule_tax_amount, development_fee_amount, customs_service_fees, wht_amount, lab_service_fees, or actual_duty_total for an overridden total): candidate enum `DUTY_COMPONENT`.
- Update (08-10 diff review): `FC_CLOSURE_BLOCKED.blocking` is a JSON list of keys (not a comma string). `WR_VERDICT_INCONSISTENT` also fires when a sent verdict contradicts the derived outcome; params verdict, expected_verdict (or shortage_qty, damaged_qty for ACCEPTED_FULL with discrepancy). `IT_TRANSITION_NOT_ALLOWED` also covers PUT status changes: action=status_change, extra param target_status (allowed via PUT: Booking Confirmed -> Dispatched, Arrived at Warehouse -> Delivered).
- (09 addendum) `SETTLEMENT_LINE_ZERO_VALUE` (item_code, line_no): "Line {item_code} has no value: it is left out of the customs estimate." (simulate messages[])


### 03b follow-up codes (diff review)

| Code | HTTP / where | Params | English template |
|---|---|---|---|
| `SDU_NO_SHIPPING_RECORD` | 409 POST /smart-upload/apply/bill-of-lading | `import_file_id`, `import_file_code` | File {import_file_code} has no active shipping record; create it before applying B/L data. |

### Dev backend port (PORT env var, 2026-10-06)

Backend dev launchers now honour `PORT` (default 28080, `utils/runtime_port.resolve_port`) and never kill the
process on the port. Needs outside backend-developer ownership:
- Flutter: `frontend/lib/core/constants/api_constants.dart` `defaultServerPort = 28080` - a dev frontend must be
  able to target the dev port (e.g. `--dart-define`), otherwise it talks to the production backend.
- `build_backend_exe.py` (optional): add `utils.runtime_port` to `hidden_imports` next to `utils.db_safety`
  (PyInstaller already finds it through the static `backend_runner` import).
- Legacy scripts still bound to 28080: `scripts/service_manager.py` (`PORT = 28080`, `stop_service` taskkills the
  PID found by `findstr ":28080"`, which also matches :280800 and non-LISTENING rows), `scripts/start_backend_service.vbs`
  (hard-coded `--port 28080`, unanchored findstr), `scripts/validate_clean_machine.py` (`DEFAULT_PORT = 28080`,
  read-only check), `package_production.py` (generated launchers taskkill `:28080`; Track 2 only).

### 04-05 shared needs (diff review)

- `financial_settlement/service.py:1431`: must count `status == 'ISSUED'` certificates only (currently aggregates all active certificates regardless of status, including drafts, double-counting landed cost if a draft was re-created before BE45-T05).
