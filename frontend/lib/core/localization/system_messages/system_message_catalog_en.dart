// Templates of the backend system messages (docs/system_message_codes.json) in English (source: modules/common/system_messages.py CATALOG).
// Keep in sync with the contract: test/system_message_catalog_parity_test.dart checks every
// code, part and param. Placeholders are `{param}`; formatting is done by SystemMessageRenderer.

// ignore_for_file: lines_longer_than_80_chars

const Map<String, Map<String, String>> systemMessageCatalogEn = {
  'ALERT_ACID_EXPIRY_RADAR': {
    'title': 'ACID numbers close to expiry',
    'body': '{count} ACID numbers expire within 7 days ({acid_numbers}). Complete the customs procedures quickly.',
  },
  'ALERT_BACKUP_OVERDUE': {
    'title': 'Backup overdue or missing',
    'body': 'The last valid backup is {hours} h old (>26h). Check the backup path and run the backup script now.',
  },
  'ALERT_DB_HEALTH_DEGRADED': {
    'title': 'Database health degraded',
    'body': 'The deep health check reported {verdict_enum_db_health_verdict}. Issues: {issues}.',
  },
  'ALERT_DEMURRAGE_RISK': {
    'title': 'Demurrage and detention risk',
    'body': '{count} containers are close to the end of their free time (<48h) or already accruing charges ({container_numbers}).',
  },
  'ALERT_DISK_CRITICAL': {
    'title': 'Critical low disk space',
    'body': 'Free disk space is below 2 GB ({free_gb} GB). Risk of database failure.',
  },
  'ALERT_DISK_LOW': {
    'title': 'Low disk space warning',
    'body': 'Free disk space is below 5 GB ({free_gb} GB). Clean temporary files and logs.',
  },
  'ALERT_DISPATCHED': {
    'title': '[{severity_enum_alert_severity}] {alert_title}',
    'body': '{alert_message} (Action: check the {target_tab} tab)',
  },
  'ALERT_OFFSITE_BACKUP_OVERDUE': {
    'title': 'Offsite backup overdue',
    'body': 'No new backup synced to the Google Drive folder for {hours} h (>26h). Check the sync client.',
  },
  'ALERT_SLOW_QUERY_SPIKE': {
    'title': 'Slow query spike',
    'body': '{count} slow queries (>150ms) recorded. Check the monitoring screen.',
  },
  'ALERT_STUCK_SHIPMENTS': {
    'title': 'Stuck shipments',
    'body': '{count} import files have stayed in the same stage for more than 10 days ({import_file_codes}).',
  },

  'CC_BROKER_AUTHORIZED': {
    'title': 'Customs broker authorized electronically - {broker_name}',
    'body': 'Customs broker {broker_name} authorized for {import_file_code} (delegation no. {delegation_no}). The file is ready for the delivery order payment and declaration 46.',
    'note': 'Customs broker {broker_name} assigned and authorized (delegation no. {delegation_no}); file moved to declaration 46.',
  },
  'CC_CLEARANCE_INVOICE_RECORDED': {
    'title': 'Clearance and port expenses invoice recorded (CL-05)',
    'body': 'Invoice {invoice_number} ({expense_category_enum_clearance_expense_category}) of {net_amount} EGP from {provider_name} recorded for {import_file_code}.',
  },
  'CC_DECLARATION_46_REGISTERED': {
    'title': 'Customs declaration 46 registered - {import_file_code}',
    'body': 'Customs declaration 46 no. {declaration_no} registered on the {channel_enum_customs_channel} for {import_file_code} at {customs_office}. The file is under inspection & sampling (CL-01).',
    'note': 'Customs declaration 46 no. {declaration_no} registered on the {channel_enum_customs_channel}; shipment moved to inspection & sampling.',
  },
  'CC_DELIVERY_ORDER_PAID': {
    'title': 'Delivery order paid and D/O received - {import_file_code}',
    'body': 'Shipping agency charges paid ({shipping_agent_name}) and delivery order {do_number} received for {import_file_code}. Valid until {expiry_date}. Ready for declaration 46.',
    'note': 'Shipping agency charges paid and delivery order {do_number} received. Ready for declaration 46.',
  },
  'CC_DUTIES_ASSESSED': {
    'title': 'Customs duties and taxes assessed - {import_file_code}',
    'body': 'Customs claim {claim_no} for {import_file_code} assessed with a total due of {total_amount} EGP. Ready for payment via Sadad (CL-03).',
    'note': 'Customs duties assessed on Nafeza claim {claim_no}, total {total_amount} EGP. Ready for Sadad payment.',
  },
  'CC_DUTIES_PAID': {
    'title': 'Customs duties paid - {import_file_code}',
    'body': 'Customs duty payment of {paid_amount} EGP confirmed for {import_file_code} via Sadad {sadad_no}, receipt {receipt_no}. Ready for the green release order (CL-04).',
    'note': 'Customs duties paid via Sadad {sadad_no}, receipt {receipt_no}. Awaiting the final release permit.',
  },
  'CC_DUTIES_PAID_BANK': {
    'note': 'Customs duties paid with receipt {receipt_no} at {bank_enum_duty_bank}. Awaiting the final release permit.',
  },
  'CC_INSPECTION_RECORDED': {
    'title': 'Inspection & sampling recorded - {import_file_code}',
    'body': 'Inspection report for {import_file_code} recorded with result {inspection_result_enum_inspection_result} at {inspection_yard_enum_inspection_yard}. Sampling record: {sampling_record_no}. Ready for final duty assessment (CL-02).',
    'note': 'Inspection completed with result {inspection_result_enum_inspection_result}. Sampling record: {sampling_record_no}. Shipment moved to duty assessment.',
  },
  'CC_RECORD_OPENED': {
    'note': 'Customs clearance record {clearance_code} opened; file moved to declaration 46 registration.',
  },
  'CC_RELEASE_ISSUED': {
    'title': 'Green customs release issued - {import_file_code}',
    'body': 'Final green customs release permit {permit_no} issued for {import_file_code}. Dispatch and loading onto inland transport trucks authorized (TR-01).',
    'note': 'Final green release order {permit_no} issued. Dispatch authorized; file moved to transport & warehousing.',
  },
  'CC_RELEASE_ISSUED_TO_DEMURRAGE': {
    'note': 'Final release order {permit_no} issued. File moved to demurrage & free-time management.',
  },
  'CC_TASK_DECLARATION_46': {
    'title': 'Register customs declaration Form 46 (CS-03) - {import_file_code}',
    'body': 'Delivery order {do_number} received, valid until {expiry_date}. Register customs declaration Form 46 on Nafeza MTS to start inspection and valuation.',
  },
  'CC_TASK_DELIVERY_ORDER_PAYMENT': {
    'title': 'Pay the shipping-line delivery order and collect the D/O (CS-02) - {import_file_code}',
    'body': 'Customs broker {broker_name} authorized (delegation no. {delegation_no}). Pay the shipping agency charges and collect the delivery order to start inspection and declaration 46.',
  },
  'CC_TASK_DUTY_ASSESSMENT': {
    'title': 'Assess the final customs duties and taxes (CL-02) - {import_file_code}',
    'body': 'Inspection & sampling recorded for {import_file_code} with result {inspection_result_enum_inspection_result}. Review the customs claim and assess the final duties and taxes (import duty, VAT, development fee, service fees).',
  },
  'CC_TASK_DUTY_PAYMENT': {
    'title': 'Record the customs duty payment via Sadad / E-Finance (CL-03) - {import_file_code}',
    'body': 'Customs claim {claim_no} issued with total duties of {total_amount} EGP for {import_file_code}. Issue the transfer order via Sadad and record the bank payment receipt.',
  },
  'CC_TASK_FREE_TIME_MONITOR': {
    'title': 'Monitor free time and avoid demurrage & detention (TR-02) - {import_file_code}',
    'body': "Follow up the containers' gate-out and unloading at the warehouse before the free time ({free_days} days) ends to avoid shipping-line penalties.",
  },
  'CC_TASK_INLAND_TRANSPORT': {
    'title': 'Book inland transport trucks to the warehouse (TR-01) - {import_file_code}',
    'body': 'Final green release permit {permit_no} issued. Confirm and book the transport trucks and record truck and driver details to move the shipment from the port to the warehouse.',
  },
  'CC_TASK_INSPECTION': {
    'title': 'Record inspection & sampling (CL-01) - {import_file_code}',
    'body': 'Customs declaration 46 no. {declaration_no} registered on the {channel_enum_customs_channel} at {customs_office}. Start the physical inspection and draw samples for the listed authorities.',
  },
  'CC_TASK_RELEASE': {
    'title': 'Issue the green customs release and start transport (CL-04) - {import_file_code}',
    'body': "Customs duties of {paid_amount} EGP paid via Sadad {sadad_no} for {import_file_code}. Obtain the final green release permit and coordinate the containers' gate-out.",
  },

  'CGX_ENVELOPE_SEALED': {
    'title': 'CargoX envelope approved, sealed and transferred to customs - {envelope_code}',
    'body': 'CargoX envelope {envelope_code} (ACID {acid_number}) sealed and signed electronically and transferred to Egyptian Customs (receipt: {receipt_no}).',
    'note': 'CargoX envelope {envelope_code} sealed and officially transferred to Egyptian Customs. Moving to original documents collection.',
  },
  'CGX_TASK_COLLECT_ORIGINALS': {
    'title': 'Collect and verify the original bank documents (SH-04) - {import_file_code}',
    'body': 'CargoX envelope {envelope_code} sealed and sent to customs (receipt: {receipt_no}). Collect and verify the original bank documents to prepare declaration 46.',
  },

  'CLO_DOSSIER_EXPORTED': {
    'title': 'Full dossier exported for {import_file_code}',
    'body': '{exported_by} exported and approved the full dossier of {import_file_code} as {export_format}. The shipment is ready for official closure and digital archiving (CLO-04).',
    'note': 'Full dossier exported ({export_format}) by {exported_by}.',
  },
  'CLO_FILE_CLOSED': {
    'title': 'Officially closed and archived: {import_file_code}',
    'body': 'Import file {import_file_code} officially closed at 100% completion; closure certificate {closure_code} issued and filed at {archive_location}.',
    'note': 'Import file finally closed and archived (code: {closure_code}) by {auditor_name}.',
  },
  'CLO_FILE_REOPENED': {
    'title': 'Shipment reopened: {import_file_code}',
    'body': 'Import file {import_file_code} has been officially reopened by supervisor {reopened_by}. Reason: {justification}',
  },
  'CLO_TASK_OFFICIAL_CLOSURE': {
    'title': 'Official closure and digital archiving of the file (CLO-04)',
    'body': 'Full dossier of {import_file_code} exported and approved as {export_format}. Complete the final checklist and issue the closure and archiving certificate.',
  },

  'DAILY_REPORT_FAILED': {
    'title': 'Daily monitoring report failed',
    'body': 'The automated daily observability report failed to generate: {error}',
  },
  'DAILY_REPORT_READY': {
    'title': 'Daily monitoring report - {report_date}',
  },

  'DD_CHARGES_POSTED': {
    'note': 'Container demurrage and free-time charges ({tracking_code}) posted to the financial settlement. Moving to warehouse receiving.',
  },
  'DD_EMPTY_CONTAINERS_RETURNED': {
    'title': 'Empty containers returned - {import_file_code}',
    'body': 'Return of {container_count} containers confirmed with EIR #{eir_number} to {depot_enum_empty_container_depot}; penalty counters stopped. The shipment is ready for the final settlement.',
    'note': 'Empty containers returned with EIR #{eir_number}; penalty counters fully stopped.',
  },
  'DD_FREE_DAYS_RECORDED': {
    'title': 'Free days recorded ({demurrage_free_days} days) (BK-02)',
    'body': 'Free days recorded for {import_file_code}. Demurrage free days: {demurrage_free_days}, detention free days: {detention_free_days}. Reference: {agreement_reference}. Demurrage radar updated; expected saving: {estimated_saving_amount} USD.',
  },
  'DD_TASK_SETTLE_FINAL_INVOICES': {
    'title': 'Collect and settle the final invoices and landed cost (CLO-01)',
    'body': 'EIR #{eir_number} received and the shipping-line file closed. Collect the supplier, freight, broker and transport invoices and calculate the final landed cost.',
  },

  'DOC_ACID_CONFLICT': {
    'note': 'ACID number {acid_number} differs from the ACID on file {import_file_code} ({current_acid_number}).',
  },

  'DOC_ACID_REGISTERED': {
    'title': 'ACID registered and verified: {acid_number}',
    'body': 'ACID {acid_number} registered and verified for {import_file_code}. Valid until {expiry_date}. The shipment moved to freight booking (STEP_06).',
    'note': 'ACID {acid_number} registered and verified for {import_file_code}.',
  },
  'DOC_BANK_DOCUMENT_RECORDED': {
    'title': '{doc_type} approved and recorded: {reference_no}',
    'body': '{doc_type} no. {reference_no} recorded via {bank_name} for {import_file_code}. The shipment moved to customs procedures and declaration 46 (STEP_13).',
    'note': 'Bank document {doc_type} no. {reference_no} received and recorded for {import_file_code}.',
  },
  'DOC_COO_APPROVED': {
    'note': 'Certificate of origin {certificate_type} - {certificate_number} approved and customs approval updated.',
  },
  'DOC_CUSTOMS_APPROVAL_GRANTED': {
    'note': 'Customs approval of the documents granted in session {session_code}; shipment moved to phase 4 (CargoX and originals collection).',
  },
  'DOC_DRAFT_BLOCKING_FIELD_EMPTY': {
    'reason': 'Critical field is empty: {field_enum_draft_bl_field}',
  },
  'DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH': {
    'reason': 'Critical mismatch in {field_enum_draft_bl_field}',
  },
  'DOC_DRAFT_BL_REVIEWED': {
    'title': 'Dual review of the draft B/L completed: {import_file_code} (SH-02)',
    'body': 'Draft B/L {draft_bl_number} for {import_file_code} matched and approved against the purchase order and commercial invoice. The file is ready for CargoX (SH-03).',
    'note': 'Draft B/L {draft_bl_number} review completed and customs approval updated (SH-02).',
  },
  'DOC_INSPECTION_REVIEW_APPROVED': {
    'note': 'Draft inspection certificate review {review_code} approved. Moving to final customs approval of documents.',
  },
  'DOC_INSPECTION_REVIEW_UPDATED': {
    'note': 'Inspection certificate review {review_code} updated and approved. Moving to customs approval of documents.',
  },
  'DOC_INVOICE_BL_MATCH_DONE': {
    'note': 'Smart match between invoice {invoice_number} and B/L {draft_bl_number} completed; customs document approval matrix updated.',
  },
  'DOC_PO_RECONCILIATION_DONE': {
    'note': 'Invoice and packing list reconciled with the purchase order ({session_code}). Moving to draft B/L review.',
  },
  'DOC_PO_RECONCILIATION_UPDATED': {
    'note': 'Invoice and packing list reconciliation updated and approved ({session_code}). Moving to draft B/L.',
  },
  'DOC_TASK_CARGOX_TRANSFER': {
    'title': 'CargoX digital transfer and document approval: {import_file_code} (SH-03)',
    'body': 'Dual review of draft B/L {draft_bl_number} completed and approved against the purchase order and invoice to avoid customs amendment penalties. The exporter must now upload the document package and approve the digital envelope (Envelope ID) on CargoX to link it with Nafeza.',
  },
  'DOC_TASK_DECLARATION_46': {
    'title': 'Register customs declaration Form 46: {import_file_code} (CS-03)',
    'body': 'Bank document {doc_type} (reference {reference_no}) from {bank_name} approved and recorded. Submit declaration Form 46 and start the customs inspection and matching procedures via Nafeza.',
  },
  'DOC_TASK_FREIGHT_BOOKING': {
    'title': 'Confirm the freight booking and the shipping line: {import_file_code} (BK-01)',
    'body': 'ACID {acid_number} issued and verified. Confirm the booking (Booking No) with the shipping line or forwarder, set the expected sailing (ETD) and arrival (ETA) dates and fix the free days.',
  },

  'EMAIL_PARSE_MATCHED': {
    'note': 'E-mail matched shipment [{import_file_code}] by reference [{reference}]; follow-up/payment task #{task_code} created.',
  },
  'EMAIL_PARSE_NO_REFERENCE': {
    'note': 'E-mail received; no B/L, ACID, purchase order or project of a registered shipment was found.',
  },
  'EMAIL_PARSE_UNMATCHED_ACID': {
    'note': 'ACID number [{acid_number}] was extracted but no active shipment is registered with it.',
  },
  'EMAIL_PARSE_UNMATCHED_BL': {
    'note': 'B/L [{bl_number}] was extracted but no active shipment is registered with this number.',
  },
  'EMAIL_PARSE_UNMATCHED_PO': {
    'note': 'Purchase order [{po_number}] was extracted but no active shipment is linked to it.',
  },
  'EMAIL_SYNC_EMPTY': {
    'body': 'Mailbox checked; no new messages.',
  },
  'EMAIL_SYNC_ERROR': {
    'body': 'Error while fetching e-mails from the server: {error}',
  },
  'EMAIL_SYNC_ERROR_OUTLOOK': {
    'body': 'Error while fetching messages from Microsoft Outlook: {error}',
  },
  'EMAIL_SYNC_SUMMARY': {
    'body': 'Scanned {count} e-mails, matched {matched_count} shipments and created {tasks_count} payment tasks.',
  },
  'EMAIL_SYNC_SUMMARY_OUTLOOK': {
    'body': 'Scanned {count} e-mails from Microsoft Outlook, matched {matched_count} shipments and created {tasks_count} payment tasks.',
  },
  'EMAIL_TASK_APPROVED': {
    'title': 'Pay the delivery order charges ({import_file_code})',
    'body': 'Approved and routed via the smart email review.',
    'note': 'Approved and routed by user: {user_name}',
  },
  'EMAIL_TASK_AUTO_GENERATED': {
    'note': 'Auto-generated by the smart email listener based on: {reference}',
  },
  'EMAIL_TASK_DELIVERY_ORDER_PAYMENT': {
    'title': 'Pay the delivery order charges ({import_file_code})',
    'body': 'An arrival notice / official e-mail follow-up linked to [{reference}] was detected. Follow up with the shipping agent immediately to pay the delivery order and port charges before the expected vessel arrival on {eta_date} to avoid demurrage or storage charges.',
    'note': 'Auto-generated by the smart email listener based on: {reference}',
  },

  'FA_ADVANCE_PAYMENT_REQUESTED': {
    'note': 'Supplier advance payment request {payment_code} issued for {requested_amount} {currency_code}',
  },
  'FA_APPROVED_BUDGET_VARIANCE': {
    'title': 'Financial variance on an approved budget: {import_file_code}',
    'body': 'Source costs of approved budget {budget_code} for {import_file_code} were changed by {modified_by}. The variance requires review and approval of a new budget revision.',
  },
  'FA_BUDGET_APPROVED': {
    'title': 'Estimated budget approved: {budget_code}',
    'body': 'Estimated budget {budget_code} of {total_amount} EGP approved by {approved_by}.',
  },
  'FA_BUDGET_APPROVED_FILE': {
    'title': 'Estimated budget approved: {budget_code}',
    'body': 'Estimated budget {budget_code} for shipment {import_file_code} of {total_amount} EGP approved by {approved_by}.',
  },
  'FA_BUDGET_NEEDS_REVALIDATION': {
    'title': 'Budget needs revalidation: {import_file_code}',
    'body': "Costs of an earlier stage were changed by {modified_by} for {import_file_code}. The approval cycle was stopped and budget {budget_code} moved to 'Needs Revalidation'.",
  },
  'FA_PAYMENT_REQUEST_APPROVED': {
    'title': 'Payment request approved: {payment_code}',
    'body': 'Payment request {payment_code} of {requested_amount} {currency_code} to supplier {supplier_name} approved. Ready for execution and bank transfer.',
  },
  'FA_PAYMENT_REQUEST_APPROVED_FILE': {
    'title': 'Payment request approved: {payment_code}',
    'body': 'Payment request {payment_code} for shipment {import_file_code} of {requested_amount} {currency_code} to supplier {supplier_name} approved. Ready for execution and bank transfer.',
  },
  'FA_PAYMENT_REQUEST_CREATED': {
    'title': 'Supplier advance payment request: {payment_code}',
    'body': 'Advance payment request issued to supplier {supplier_name} for {requested_amount} {currency_code} ({requested_egp_amount} EGP) for shipment {import_file_code}. Due on {due_date}. Requires review, approval and the bank SWIFT payment.',
  },
  'FA_PAYMENT_REQUEST_CREATED_GENERIC': {
    'title': 'New payment request: {payment_code}',
    'body': 'Payment request issued to supplier {supplier_name} for {requested_amount} {currency_code} ({requested_egp_amount} EGP). Due on {due_date}.',
  },
  'FA_SWIFT_PAID': {
    'title': 'Payment and SWIFT transfer done - ready for ACID ({import_file_code})',
    'body': 'Bank transfer and SWIFT {swift_ref} of {paid_amount} {currency_code} confirmed for {import_file_code}. The ACID stage via Nafeza is now open.',
    'note': 'Bank transfer and SWIFT MT103 {swift_ref} of {paid_amount} {currency_code} paid',
  },
  'FA_TASK_ISSUE_ACID': {
    'title': '[{import_file_code}] - Obtain the shipment ACID number via Nafeza',
    'body': 'Bank SWIFT {swift_ref} transferred. Obtain the ACID number for {import_file_code} on Nafeza and upload the initial documents.',
  },
  'FA_TASK_SUPPLIER_PAYMENT': {
    'title': 'Pay the supplier advance payment and SWIFT: {supplier_name} ({payment_code})',
    'body': 'Pay the supplier {requested_amount} {currency_code} ({requested_egp_amount} EGP) due on {due_date} for shipment {import_file_code} and match the MT103/SWIFT transfer advice.',
  },
  'FA_TASK_SUPPLIER_PAYMENT_GENERIC': {
    'title': 'Pay the supplier dues: {supplier_name} ({payment_code})',
    'body': 'Pay the supplier {requested_amount} {currency_code} ({requested_egp_amount} EGP) due on {due_date} for shipment {import_file_code} and match the MT103/SWIFT transfer advice.',
  },

  'FB_BOOKING_CONFIRMED': {
    'title': 'Booking confirmed (booking: {booking_no})',
    'body': 'Booking {booking_no} for {import_file_code} confirmed. Shipping line: {shipping_line_name}, vessel: {vessel_name}, ETD: {etd_date}, ETA: {eta_date}. Free days: {demurrage_free_days}.',
  },
  'FB_SAILING_CONFIRMED': {
    'title': 'Sailing and B/L confirmed (B/L: {bl_number})',
    'body': 'Shipment {import_file_code} sailed on {atd_date}. Vessel: {vessel_name}, voyage: {voyage_number}. B/L no.: {bl_number}. Updated ETA: {eta_date}.',
    'note': 'Actual sailing confirmed on {atd_date} and B/L {bl_number} issued',
  },
  'FB_TASK_DRAFT_BL_REVIEW': {
    'title': 'Dual review of the draft B/L against the purchase order: {import_file_code} (SH-02)',
    'body': 'Actual sailing confirmed and B/L no. {bl_number} recorded on vessel {vessel_name}, voyage {voyage_number}. Match the B/L data (Shipper, Consignee, Notify, Goods, Net/Gross Wt) with the purchase order and commercial invoice to avoid customs amendment penalties.',
  },
  'FB_TASK_FREE_DAYS': {
    'title': 'Record and confirm the container free days: {import_file_code} (BK-02)',
    'body': 'Booking {booking_no} confirmed with shipping line {shipping_line_name} on vessel {vessel_name}. Record and confirm the agreed free demurrage days ({demurrage_free_days} days) to feed the demurrage radar.',
  },

  'FS_INVOICES_SETTLED': {
    'title': 'Shipment invoices settlement approved: {import_file_code}',
    'body': '{settled_by} approved and reconciled all {invoice_count} invoices and expenses of {import_file_code} with a total of {total_amount} EGP, ahead of the landed cost calculation (CLO-02).',
  },
  'FS_LANDED_COST_APPROVED': {
    'title': 'Actual landed cost approved: {import_file_code}',
    'body': '{approved_by} approved the actual landed cost of {import_file_code}: total {total_amount} EGP (markup factor {markup_factor}x, variance {variance_pct}% - {variance_status_enum_landed_cost_variance_status}).',
    'note': 'Actual landed cost and variance approved ({settlement_code}).',
  },
  'FS_SETTLEMENT_CREATED': {
    'note': 'Financial settlement record {settlement_code} created and landed cost calculated.',
  },
  'FS_TASK_CALCULATE_LANDED_COST': {
    'title': 'Calculate actual landed cost and allocate it to items (CLO-02)',
    'body': 'Invoices and expenses of {import_file_code} collected and reconciled: {invoice_count} invoices, total {total_amount} EGP. Run the landed cost engine and allocate the costs to the items.',
  },
  'FS_TASK_EXPORT_DOSSIER': {
    'title': 'Generate and export the full dossier PDF/Excel (CLO-03)',
    'body': 'Actual landed cost of {import_file_code} approved: total {total_amount} EGP, variance {variance_pct}%. Export the full dossier and the document package.',
  },

  'GUIDE_HS_LAB_INSPECTION': {
    'title': 'Mandatory lab test and regulatory inspection for HS {hs_code}',
    'body': 'HS {hs_code} ({product_category}) typically goes through the red inspection channel with sampling for ({regulatory_bodies_enum_regulatory_body}) in 100% of {shipment_count} past shipments. Prepare the approved original invoices and analysis/conformity certificates in advance to avoid container charges.',
    'evidence': 'All {shipment_count} past shipments of HS {hs_code} went through lab testing and the red channel.',
    'reason': 'HS {hs_code} was repeatedly routed to the red channel with sampling in past shipments.',
  },
  'GUIDE_PORT_COST_VARIANCE': {
    'title': 'Actual clearance cost above estimates at {port_name} (+{avg_variance_pct}%)',
    'body': 'Final accounts of shipments discharged at {port_name} show landed cost above the estimated budget by +{avg_variance_pct}% on average across {shipment_count} shipments. Review demurrage and port admin items early.',
    'evidence': '{shipment_count} past shipments at {port_name} exceeded the estimated cost by +{avg_variance_pct}% on average.',
    'reason': 'Actual total costs at {port_name} repeatedly exceeded the estimates.',
  },
  'GUIDE_SEASONAL_CONGESTION': {
    'title': 'Seasonal shipment congestion in {month}',
    'body': 'Shipments opened in {month} see a general supply-chain slowdown due to public holidays or the global peak season. Start the ACID and book space at least 3 weeks before shipping.',
    'evidence': 'Heavy import activity and seasonal delays recorded in {shipment_count} shipments in this month.',
    'reason': 'Supply and transit repeatedly slow down in the annual {month} cycle.',
  },
  'GUIDE_SUPPLIER_DELAY': {
    'title': 'Repeated delivery delays by supplier {supplier_name} (+{avg_delay_days} days)',
    'body': 'Past shipments show supplier {supplier_name} is late with cargo readiness by +{avg_delay_days} days on average ({frequency_pct}% across {delayed_count} of {total_shipment_count} shipments). Add a time buffer to the schedule and consider it when issuing the ACID.',
    'evidence': 'Delay found in {delayed_count} of {total_shipment_count} shipments with an average delay of {avg_delay_days} days.',
    'reason': 'Supplier {supplier_name} repeatedly missed contractual delivery dates in more than one shipment.',
  },
  'GUIDE_SUPPLIER_DOC_ERRORS': {
    'title': 'Repeated document errors from supplier {supplier_name} ({category})',
    'body': '{mismatch_count} document mismatch cards were recorded for supplier {supplier_name}, mostly ({category}). The supplier must check drafts, weights and descriptions before the final B/L is issued.',
    'evidence': "{mismatch_count} past document mismatches in the supplier's shipments, mostly in {category}.",
    'reason': 'Supplier {supplier_name} repeatedly issued documents with discrepancies.',
  },
  'GUIDE_TRANSIT_DEVIATION': {
    'title': 'Transit time deviation for {carrier_name} to {port_name} (+{avg_extra_days} days)',
    'body': 'Voyages of {carrier_name} to {port_name} exceed the scheduled transit time by +{avg_extra_days} days on average across {delayed_count} shipments. Negotiate enough free time (>= 21 days) to avoid demurrage.',
    'evidence': '{delayed_count} of {total_shipment_count} shipments were late by an extra {avg_extra_days} days on average versus the contractual transit time.',
    'reason': '{carrier_name} repeatedly exceeded the scheduled transit times to {port_name}.',
  },

  'LC_APPROVER_ROLE_UNKNOWN': {
    'note': 'Approver role {role_code} does not match any known system role.',
  },
  'LC_CLOSURE_STEP_RESERVED': {
    'note': 'Step STEP_21 is reserved for the file closure module and cannot be completed directly from HTTP.',
  },
  'LC_FILE_NOT_ACTIVE': {
    'note': 'Import file {import_file_code} is {status} and cannot be transitioned on the lifecycle board.',
  },
  'LC_FILE_NOT_FOUND': {
    'note': 'Import file {import_file_code} was not found or is inactive.',
  },
  'LC_FILE_REF_REQUIRED': {
    'note': 'Import file id or code is required.',
  },

  'LC_FILE_ON_HOLD': {
    'note': 'Shipment put on hold at [{phase_id}]: {reason}',
  },
  'LC_FILE_ON_HOLD_CODED': {
    'note': 'Shipment put on hold at [{phase_id}]: {reason_enum_hold_reason}',
  },
  'LC_FILE_ON_HOLD_CODED_WITH_NOTES': {
    'note': 'Shipment put on hold at [{phase_id}]: {reason_enum_hold_reason} | {notes}',
  },
  'LC_FILE_ON_HOLD_WITH_NOTES': {
    'note': 'Shipment put on hold at [{phase_id}]: {reason} | {notes}',
  },
  'LC_FILE_RESUMED': {
    'note': 'Operations resumed: {notes}',
  },
  'LC_FILE_RESUMED_DEFAULT': {
    'note': 'Operations resumed: shipment operations restarted',
  },
  'LC_INITIAL_ACTIVITY': {
    'note': 'Initial shipment activity setup',
  },
  'LC_MULTI_STAGE_ACTIVATED': {
    'note': 'Activated as a parallel stage',
  },
  'LC_PENDING_REFERENCE': {
    'note': 'Pending reference: {reference_number} - {reason}',
  },
  'LC_SKIP_DUAL_APPROVAL_REQUIRED': {
    'note': 'Step {step_code} requires dual approval and cannot be skipped by non-admin users.',
  },
  'LC_SKIP_HAS_OPEN_TASKS': {
    'title': 'Skip blocked: {step_code} has open tasks',
    'body': 'Step {step_code} has {open_tasks_count} open task(s). Confirm skip with force_skip to proceed.',
    'note': 'Cannot skip {step_code}: {open_tasks_count} open tasks remain',
  },
  'LC_STARTING_POINT_SET': {
    'note': 'Shipment starting point set to {step_code}',
  },
  'LC_STEP_ACTIVATED': {
    'note': 'Activated after {completed_step_code} completed',
  },
  'LC_STEP_ACTIVATED_AFTER_SKIP': {
    'note': 'Activated after {skipped_step_code} was skipped',
  },
  'LC_STEP_AUTO_CLOSED_PRIOR': {
    'note': 'Auto-completed when {completed_step_code} was done',
  },
  'LC_STEP_AUTO_COMPLETED': {
    'note': 'Auto-completed on transition to {target_step_code}',
  },
  'LC_STEP_BYPASSED_FOR_LATER_START': {
    'note': 'Bypassed and completed to start the shipment directly from a later step',
  },
  'LC_STEP_COMPLETED': {
    'note': '{step_code} completed',
  },
  'LC_STEP_NOT_ACTIVE': {
    'note': 'Step {step_code} is not currently active on import file {import_file_code}.',
  },
  'LC_STEP_ALREADY_COMPLETED': {
    'note': 'Step {step_code} is already completed or skipped on import file {import_file_code}.',
  },
  'LC_STEP_SEQUENCE_INVALID': {
    'note': 'Step {step_code} cannot be activated ahead of sequence for non-admin users.',
  },
  'LC_TARGET_STEP_INVALID': {
    'note': 'Cannot directly advance to {step_code} without administrator privileges.',
  },
  'LC_STEP_ON_HOLD': {
    'note': 'On hold: {reason}',
  },
  'LC_STEP_ON_HOLD_CODED': {
    'note': 'On hold: {reason_enum_hold_reason}',
  },
  'LC_STEP_RESUMED': {
    'note': 'Resumed: {notes}',
  },
  'LC_STEP_RESUMED_DEFAULT': {
    'note': 'Resumed: shipment operations restarted',
  },
  'LC_STEP_SKIPPED': {
    'note': 'Step skipped: {reason}',
  },
  'LC_SYNC_BOOKING_CONFIRMED': {
    'note': 'Booking {booking_code} confirmed',
  },
  'LC_SYNC_BOOKING_CONFIRMED_DETAILS': {
    'note': 'Booking {booking_code} confirmed - confirmation no.: {confirmation_no}, vessel: {vessel_name}',
  },
  'LC_SYNC_BOOKING_PENDING': {
    'note': 'Booking request {booking_code} is being followed up with the shipping line',
  },
  'LC_SYNC_BUDGET_APPROVED': {
    'note': 'Estimated shipment budget approved',
  },
  'LC_SYNC_BUDGET_UNDER_REVIEW': {
    'note': 'Estimated budget prepared and under financial review',
  },
  'LC_SYNC_CARGO_ALLOCATION_DONE': {
    'note': 'Container allocation and VGM weights completed for shipping record {cargo_shipping_code} ({container_count} containers/packages)',
  },
  'LC_SYNC_CARGO_ALLOCATION_DRAFT': {
    'note': 'Container allocation record {cargo_shipping_code} is being prepared (draft)',
  },
  'LC_SYNC_CUSTOMS_STUDY_DONE': {
    'note': 'Customs consultation and tariff study completed',
  },
  'LC_SYNC_FREIGHT_STUDIES_DONE': {
    'note': 'Freight studies completed; moved to customs studies',
  },
  'LC_TASK_NEXT_STEP': {
    'title': '[{import_file_code}] - {step_code}',
    'body': '{completed_step_code} completed for {import_file_code}; moved to {step_code} in {phase_id}. Action: follow up and complete the stage requirements.',
    'note': 'Auto-generated after {completed_step_code} was completed',
  },
  'LC_TASK_NEXT_STEP_SKIPPED': {
    'title': '[{import_file_code}] - {step_code}',
    'body': '{completed_step_code} skipped for {import_file_code}; moved to {step_code} in {phase_id}. Action: follow up and complete the stage requirements.',
    'note': 'Auto-generated after {completed_step_code} was skipped',
  },

  'NA_ARCHIVE_IMPORT_FILE': {
    'action': 'Archive import file',
  },
  'NA_AUDIT_COO_PREFERENTIAL': {
    'action': 'Audit certificate of origin & preferential trade rules',
  },
  'NA_AUDIT_DRAFT_BL_INVOICES': {
    'action': 'Audit draft B/L & commercial invoices',
  },
  'NA_AUDIT_INSPECTION_CERTIFICATES': {
    'action': 'Audit pre-shipment inspection & conformity certificates',
  },
  'NA_AUDIT_INVOICE_PACKING_VS_PO': {
    'action': 'Audit commercial invoice & packing list vs PO',
  },
  'NA_AUDIT_LANDED_COST_CLOSURE': {
    'action': 'Audit landed cost breakdown & issue closure certificate',
  },
  'NA_AWAIT_LAB_APPROVAL_BEFORE_PRODUCTION': {
    'action': 'Awaiting laboratory test approval before production',
  },
  'NA_CLO_CALCULATE_LANDED_COST': {
    'action': 'Calculate actual landed cost and allocate it to items (CLO-02)',
  },
  'NA_CLO_CALCULATE_LANDED_COST_AND_SETTLE': {
    'action': 'Calculate actual landed cost and variance (CLO-02) and the final settlement (CLO-01)',
  },
  'NA_CLO_COMPLETE_CHECKLIST': {
    'action': 'Complete remaining closure checklist tasks',
  },
  'NA_CLO_EXPORT_DOSSIER': {
    'action': 'Generate and export the full dossier PDF/Excel (CLO-03)',
  },
  'NA_CLO_OFFICIAL_CLOSURE': {
    'action': 'Official closure and digital archiving of the file (CLO-04)',
  },
  'NA_CLO_SETTLE_FINAL_INVOICES': {
    'action': "Collect and settle the file's final invoices (CLO-01)",
  },
  'NA_CL_ASSESS_FINAL_DUTIES': {
    'action': 'Assess the final customs duties and taxes (CL-02)',
  },
  'NA_CL_AWAIT_LAB_RESULTS': {
    'action': 'Awaiting laboratory test results',
  },
  'NA_CL_ISSUE_GREEN_RELEASE': {
    'action': 'Issue the green customs release order (CL-04)',
  },
  'NA_CL_RECORD_DUTY_PAYMENT': {
    'action': 'Record the customs duty payment via Sadad (CL-03)',
  },
  'NA_CL_RECORD_INSPECTION': {
    'action': 'Record inspection & sampling (CL-01)',
  },
  'NA_CL_RE_EXPORT_OR_DISPOSAL': {
    'action': 'Re-export or disposal',
  },
  'NA_COLLECT_ORIGINALS_FORM4': {
    'action': 'Collect original documents & process Form 4',
  },
  'NA_COMPLETE_CLONED_FILE': {
    'action': 'Complete the cloned shipment data and open ACID procedures',
  },
  'NA_CONFIRM_ACID_PROCEED_BOOKING': {
    'action': 'Confirm ACID & proceed to freight booking',
  },
  'NA_CONFIRM_BOOKING_REVIEW_DRAFT_BL': {
    'action': 'Confirm shipping line booking & review draft B/L',
  },
  'NA_CREATE_PAYMENT_REQUEST_FORM4': {
    'action': 'Create payment request (BP-012) & issue Form 4',
  },
  'NA_CS01_ASSIGN_BROKER': {
    'action': 'Assign the customs broker and issue the electronic authorization (CS-01)',
  },
  'NA_CS_PAY_DELIVERY_ORDER': {
    'action': 'Pay the shipping-line delivery order and collect the D/O (CS-02)',
  },
  'NA_CS_REGISTER_DECLARATION_46': {
    'action': 'Register customs declaration Form 46 (CS-03)',
  },
  'NA_CUSTOMS_INSPECTION_DUTY_SETTLEMENT': {
    'action': 'Customs inspection & duty settlement',
  },
  'NA_EVALUATE_SCENARIOS_REQUEST_QUOTES': {
    'action': 'Evaluate shipping scenarios (BP-007) & request freight quotations (BP-008)',
  },
  'NA_FILE_ARCHIVED_READ_ONLY': {
    'action': 'File archived - read-only historical state',
  },
  'NA_FILE_CLOSED': {
    'action': 'Import file closed',
  },
  'NA_FILE_CLOSED_EARLY': {
    'action': 'File closed early at {phase_id}',
  },
  'NA_FILE_CLOSED_EARLY_GENERIC': {
    'action': 'File closed early',
  },
  'NA_FILE_FULLY_CLOSED_ARCHIVED': {
    'action': 'File fully closed & archived',
  },
  'NA_FOLLOW_COMPENSATION_LANDED_COST': {
    'action': 'Follow up the insurance/supplier compensation (CLO-01) and calculate landed cost (CLO-02)',
  },
  'NA_FOLLOW_LAB_RESULTS_WARRANTY_CLAIMS': {
    'action': 'Follow up lab results and warranty claims with the supplier',
  },
  'NA_FOLLOW_UP_STEP': {
    'action': 'Follow up {step_code}',
  },
  'NA_INSPECT_CARGO_SETTLE_TAXES': {
    'action': 'Inspect cargo & settle customs taxes',
  },
  'NA_INSPECT_GOODS_SETTLE_LANDED_COST': {
    'action': 'Inspect received goods & settle landed cost',
  },
  'NA_ISSUE_ADVANCE_PAYMENT_REQUEST_ACID': {
    'action': 'Issue advance payment & request ACID',
  },
  'NA_OBTAIN_CUSTOMS_APPROVAL_DRAFTS': {
    'action': 'Obtain customs approval on draft documents',
  },
  'NA_PAY_DUTIES_RELEASE_CARGO': {
    'action': 'Pay customs duties & release cargo from port',
  },
  'NA_PENDING_REGULATORY_REQUIREMENTS': {
    'action': 'Fulfil {count} pending regulatory requirements ({requirements})',
  },
  'NA_PREPARE_FINANCIAL_APPROVAL': {
    'action': 'Prepare financial approval request',
  },
  'NA_REGISTER_DECLARATION_46': {
    'action': 'Register customs declaration 46',
  },
  'NA_RESUME_OPERATIONS': {
    'action': 'Resume operations at {phase_id}',
  },
  'NA_RESUME_OPERATIONS_GENERIC': {
    'action': 'Resume operations',
  },
  'NA_REVIEW_DRAFT_BL_WITH_CARRIER': {
    'action': 'Review draft B/L with carrier & issue revisions',
  },
  'NA_REVIEW_REGULATORY_REQUIREMENTS': {
    'action': 'Review import regulatory requirements',
  },
  'NA_REVIEW_SETTLEMENT_AND_CLOSE': {
    'action': 'Review final settlement & perform file closure',
  },
  'NA_SH04_COLLECT_ORIGINALS': {
    'action': 'Collect and verify the original bank documents (SH-04)',
  },
  'NA_STEP03_REVIEW_REGULATORY_APPROVALS': {
    'action': "Review the shipment's import requirements and regulatory approvals",
  },
  'NA_STEP04_APPROVE_ADVANCE_PAYMENT': {
    'action': 'Review and approve the supplier advance payment and prepare the bank SWIFT',
  },
  'NA_STEP04_APPROVE_BUDGET_SUPPLIER_PAYMENT': {
    'action': 'Review and approve the estimated budget and the supplier payment',
  },
  'NA_STEP04_COMPLETE_PAYMENT_REQUEST_ACID': {
    'action': 'Complete the supplier payment and request the ACID number (STEP_05)',
  },
  'NA_STEP04_REVIEW_BUDGET_SUPPLIER_TRANSFER': {
    'action': 'Review budget approvals and the supplier bank transfer',
  },
  'NA_STEP05_REQUEST_ACID': {
    'action': 'Request and obtain the ACID number via Nafeza',
  },
  'NA_STEP06_CONFIRM_BOOKING': {
    'action': 'Confirm the booking with the awarded shipping line or forwarder',
  },
  'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION': {
    'action': 'Follow up the booking confirmation',
  },
  'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF': {
    'action': 'Follow up the booking confirmation (booking {booking_no})',
  },
  'NA_STEP07_AUDIT_ALLOCATION_VGM': {
    'action': 'Audit container allocation, VGM weights and draft shipping documents',
  },
  'NA_STEP07_COMPLETE_CONTAINERS_VGM': {
    'action': 'Complete container numbers, seals and VGM weights',
  },
  'NA_STEP07_FOLLOW_LOADING_PLAN': {
    'action': 'Follow up the loading plan, container allocation and VGM certificates (booking {booking_no})',
  },
  'NA_STEP08BL_MATCH_BL_PO_INVOICE': {
    'action': 'Review B/L data and match it with the purchase order and invoice',
  },
  'NA_STEP08BL_REVIEW_DRAFT_BL': {
    'action': 'Review the draft B/L and match it with the invoice (SH-02)',
  },
  'NA_STEP08COO_REVIEW_COO': {
    'action': 'Review the draft certificate of origin and preferential agreements',
  },
  'NA_STEP08PO_RECONCILE_INVOICE_PACKING_PO': {
    'action': 'Reconcile invoice and packing list lines with the purchase order',
  },
  'NA_STEP09_CARGOX_ENVELOPE': {
    'action': 'Upload and approve the digital envelope via CargoX (SH-03)',
  },
  'NA_STEP09_FINAL_DOCS_APPROVAL': {
    'action': 'Audit the final customs approval of the documents',
  },
  'NA_STEP10_UPLOAD_APPROVED_TO_CARGOX': {
    'action': 'Upload the approved drafts and certificates to the CargoX platform',
  },
  'NA_SUBMIT_DOCS_BANK_FORM4': {
    'action': 'Submit documents to bank for Form 4',
  },
  'NA_TRACK_DEMURRAGE_FREE_TIME': {
    'action': 'Track container demurrage & free time expiry',
  },
  'NA_TRACK_LAB_RESULTS': {
    'action': 'Track regulatory & lab sample test results',
  },
  'NA_TR_BOOK_INLAND_TRANSPORT': {
    'action': 'Book inland transport trucks to the warehouse (TR-01)',
  },
  'NA_TR_BOOK_INLAND_TRANSPORT_MONITOR_FREE_TIME': {
    'action': 'Book inland transport trucks to the warehouse (TR-01) and monitor free time (TR-02)',
  },
  'NA_TR_CHECK_SEALS_ISSUE_GRN': {
    'action': 'Check seal integrity and issue the receiving GRN (TR-03)',
  },
  'NA_TR_FOLLOW_DISPATCH_FREE_TIME_RECEIVING': {
    'action': 'Follow up dispatch (TR-01), the free-time radar (TR-02) and warehouse receiving (TR-03)',
  },
  'NA_TR_INSPECTION_DISCREPANCY_LANDED_COST': {
    'action': 'Technical inspection, shortage & damage protocol (TR-04) and landed cost (CLO-02)',
  },
  'NA_TR_RECEIVE_TRUCK_ISSUE_GRN': {
    'action': 'Receive the truck, unload the containers and issue the GRN (TR-03)',
  },
  'NA_UPLOAD_CARGOX_PREPARE_DECLARATION_46': {
    'action': 'Upload digital documents to CargoX & prepare declaration 46',
  },
  'NA_UPLOAD_DOCS_TO_CARGOX': {
    'action': 'Upload digital documents to CargoX',
  },
  'NA_VALUATION_INSPECTION_SAMPLING': {
    'action': 'Customs valuation, inspection & sampling',
  },
  'NA_VERIFY_INVOICE_BL_MATCH': {
    'action': 'Verify field matching between invoice & B/L',
  },
  'NA_VERIFY_QUANTITIES_DISCREPANCIES': {
    'action': 'Verify cargo quantities & reconcile discrepancies',
  },
  'NA_WAREHOUSE_READY_FOR_DISPATCH': {
    'action': 'Warehouse inventory ready for dispatch',
  },

  'NOTIF_ACID_REQUEST_EXPIRY': {
    'title': 'ACID number expiring soon: {acid_number}',
    'body': 'ACID {acid_number} has only {days_left} days left before shipping and expires on {expiry_date}.',
  },
  'NOTIF_BUDGET_OVERRUN': {
    'title': 'Shipment budget exceeded: {import_file_code}',
    'body': 'Actual expenses of {import_file_code} exceeded the estimated budget by {overrun_pct}% (actual: {actual_amount} EGP vs estimated: {estimated_amount} EGP). Review the variances.',
  },
  'NOTIF_CARGOX_UPLOAD_DELAY': {
    'title': 'CargoX documents upload delayed: {import_file_code}',
    'body': '{import_file_code} is expected to arrive in {days_left} days (ETA: {eta_date}) and supplier {supplier_name} has not uploaded or approved the CargoX document envelope. Follow up urgently.',
  },
  'NOTIF_CHECKLIST_ETA_APPROACHING': {
    'title': 'Checklist readiness alert before arrival: {import_file_code}',
    'body': '{import_file_code} vessel arrival expected in {days_left} days (ETA: {eta_date}) with {blocking_count} mandatory checklist item(s) still unverified. Settle requirements to avoid port bottlenecks.',
  },
  'NOTIF_CHECKLIST_GATE_BLOCKED': {
    'title': 'Checklist gate blocked: {import_file_code}',
    'body': '{import_file_code} has {blocking_count} mandatory checklist item(s) pending for phase {target_phase}. Automatic or manual progression is blocked until verified or waived.',
  },
  'NOTIF_COMPANY_IMPORTER_ID_EXPIRY': {
    'title': 'Importer card expiring: {company_name}',
    'body': 'Importer card {importer_id} has {days_left} days left and expires on {expiry_date}. Renew now.',
  },
  'NOTIF_COMPANY_REGISTRATION_EXPIRY': {
    'title': 'Commercial registration expiring: {company_name}',
    'body': 'Commercial registration {registration_number} has {days_left} days left and expires on {expiry_date}.',
  },
  'NOTIF_CUSTOMS_FX_DROP': {
    'title': 'Customs USD exchange rate fell',
    'body': 'The customs USD exchange rate fell by {change_pct}% (current: {current_rate} EGP vs {previous_rate} EGP). Update the customs duty studies of running shipments.',
  },
  'NOTIF_CUSTOMS_FX_RISE': {
    'title': 'Customs USD exchange rate rose',
    'body': 'The customs USD exchange rate rose by {change_pct}% (current: {current_rate} EGP vs {previous_rate} EGP). Update the customs duty studies of running shipments.',
  },
  'NOTIF_CUSTOMS_FX_VOLATILITY': {
    'title': 'Customs USD exchange rate change',
    'body': 'The customs USD exchange rate changed by {change_pct}% (current: {current_rate} EGP vs {previous_rate} EGP). Update the customs duty studies of running shipments.',
  },
  'NOTIF_DEMURRAGE_ACTIVE': {
    'title': 'Active demurrage charges: {import_file_code}',
    'body': '{import_file_code} is accruing demurrage of USD {fx_amount} ({egp_amount} EGP). Clear and collect the cargo immediately.',
  },
  'NOTIF_DEMURRAGE_WARNING': {
    'title': 'Demurrage warning: {import_file_code}',
    'body': '{import_file_code} has {days_left} days left before the free time ends and demurrage starts. Speed up the clearance.',
  },
  'NOTIF_DETENTION_RETURN_DEADLINE': {
    'title': 'Empty container return deadline (detention): {tracking_code}',
    'body': '{days_left} days left in the empty container free time of {carrier_name} (B/L {bl_number}). Return the containers to avoid USD detention charges.',
  },
  'NOTIF_DOCUMENT_SHORTAGE': {
    'title': 'Missing documents: {import_file_code}',
    'body': '{import_file_code} has arrived or is about to arrive but its documents are only {readiness_pct}% complete ({verified_count}/7 documents). Complete the document file now.',
  },
  'NOTIF_ETA_WITHOUT_CLEARANCE': {
    'title': 'ETA imminent without clearance: {import_file_code}',
    'body': '{import_file_code} arrives within {hours} hours and no customs clearance file has been opened. Start the declaration 46 procedures now.',
  },
  'NOTIF_FORM4_DELAY': {
    'title': 'Bank Form 4 delayed: {bank_name}',
    'body': 'Form 4 request with {bank_name} pending for {pending_days} days (reference: {bank_doc_code}). Follow up with the bank before the goods arrive.',
  },
  'NOTIF_IMPORT_FILE_ACID_EXPIRY': {
    'title': 'Shipment ACID expiring soon: {import_file_code}',
    'body': 'ACID {acid_number} of {import_file_code} has {days_left} days left and expires on {expiry_date}. Extend it via Nafeza to avoid a release block.',
  },
  'NOTIF_ORIGINALS_COLLECTION_DELAY': {
    'title': 'Original documents collection delayed: {import_file_code}',
    'body': 'The B/L and original documents of {import_file_code} are not fully received while the vessel ETA is {days_left} days away (ETA: {eta_date}). Check the courier tracking.',
  },
  'NOTIF_REGULATORY_PENDING': {
    'title': 'Regulatory and pre-inspection requirement pending: {import_file_code}',
    'body': '{import_file_code} contains items (HS {hs_code}) requiring a pre-inspection certificate or a regulatory approval ({authority_enum_regulatory_body}) that is still pending.',
  },

  'ODC_ORIGINALS_RECEIVED': {
    'title': 'Original bank documents received and verified - {collection_code}',
    'body': 'All original bank documents for {import_file_code} received and verified at {completion_pct}% (code: {collection_code}). The file is ready for customs clearance.',
    'note': 'Original bank documents fully received and verified (code: {collection_code}). Moving to bank Form 4 and customs preparation.',
  },
  'ODC_TASK_ASSIGN_BROKER': {
    'title': 'Assign the customs broker and issue the electronic authorization (CS-01) - {import_file_code}',
    'body': 'Original bank documents for {import_file_code} received and verified (session {collection_code}). Assign the customs broker and issue the electronic authorization to start declaration 46.',
  },

  'REQ_TASK_COA': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Provide the laboratory analysis and conformity certificate (COA)',
    'body': 'Receive the chemical/mechanical test report from the manufacturer',
  },
  'REQ_TASK_COO': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Obtain and verify the original certificate of origin',
    'body': 'The original certificate of origin must be received and verified to apply preferential treatment and customs release - current status: {status_enum_requirement_status}',
  },
  'REQ_TASK_COO_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] Obtain and verify the certificate of origin ({certificate_type})',
    'body': 'The certificate of origin for item {hs_code} must be received and verified to apply the duty exemption/reduction - status: {status_enum_requirement_status}',
  },
  'REQ_TASK_DECREE43': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Verify the foreign factory/supplier registration with GOEIC (Decree 43)',
    'body': 'The goods are subject to Ministerial Decree 43/2016; verify the factory is on the GOEIC white list before shipping',
  },
  'REQ_TASK_DECREE43_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] Supplier factory registration required on the white list (Decree 43/2016)',
    'body': 'Tariff item {hs_code} is subject to Ministerial Decree 43/2016 and the supplier is not on the GOEIC white list; register the factory or obtain an approved exemption before shipping.',
  },
  'REQ_TASK_HALAL': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Provide the official Halal certificate',
    'body': 'Provide the Halal certificate issued by a centre approved by IS EG Halal',
  },
  'REQ_TASK_INSPECTION': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Issue the pre-shipment inspection certificate ({authority_enum_regulatory_body})',
    'body': 'The item is subject to mandatory pre-shipment technical inspection in the country of origin by {authority_enum_regulatory_body}',
  },
  'REQ_TASK_INSPECTION_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] Issue the pre-shipment inspection certificate ({authority_enum_regulatory_body})',
    'body': 'Item {hs_code} is subject to mandatory pre-shipment technical inspection by {authority_enum_regulatory_body}',
  },
  'REQ_TASK_MSDS': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Provide an approved, up-to-date material safety data sheet (MSDS)',
    'body': "Provide the item's MSDS to define safety, port handling and storage requirements",
  },
  'REQ_TASK_PERMIT': {
    'title': '[{import_file_code}] [ACID: {acid_number}] Obtain the prior import approval ({authority_enum_regulatory_body})',
    'body': 'An official import permit/approval must be obtained from {authority_enum_regulatory_body} before shipping',
  },
  'REQ_TASK_PERMIT_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] Obtain the prior import approval ({authority_enum_regulatory_body})',
    'body': 'An import permit for item {hs_code} must be obtained from {authority_enum_regulatory_body} before shipping',
  },

  'TASK_AUTO_PHASE_FOLLOW_UP': {
    'title': '{import_file_code} - {task_enum_phase_follow_up_task}',
    'body': 'System-generated follow-up task: {task_enum_phase_follow_up_task}',
    'note': 'Auto-generated for shipment {import_file_code}',
  },

  'TR_BOOKING_CONFIRMED': {
    'title': 'Inland transport trucks booked (TR-01)',
    'body': 'Truck {truck_plate_number} booked to move {import_file_code} from {pickup_location} to {destination_warehouse}. Driver: {driver_name} ({driver_phone}).',
  },
  'DOC_TASK_TAX_CODING_PULL': {
    'title': 'Pull the tax coding sheet from Nafeza: {import_file_code}',
    'body': 'The customs broker must pull the tax coding sheet from the Nafeza platform so it can be passed to the accountant for shipment {import_file_code}.',
  },
  'DOC_TASK_TAX_CODING_UPLOAD': {
    'title': 'Code and upload the items tax sheet on Nafeza: {import_file_code}',
    'body': 'The customs broker pulled the tax coding sheet. The accountant must complete the coding and upload it on the company\'s Nafeza account for file {import_file_code}.',
  },
  'DOC_TASK_ITEMS_VERIFY_BANK_LINK': {
    'title': 'Pull the items to verify the coding and link to bank: {bank_name} - {import_file_code}',
    'body': 'The items tax sheet was coded and uploaded. The customs broker must pull the items to confirm the coding is complete, then link the shipment on Nafeza to {bank_name} for shipment {import_file_code}.',
  },
  'DOC_TASK_ITEMS_VERIFY_SWIFT_BANK_LINK': {
    'title': 'Pull the items to verify the coding and link to the SWIFT executing bank: {import_file_code}',
    'body': 'The items tax sheet was coded and uploaded. The customs broker must pull the items to confirm the coding is complete, then link the shipment on Nafeza to the SWIFT executing bank for shipment {import_file_code}.',
  },
  'DOC_TASK_FORM4_SUBMIT': {
    'title': 'Submit the Form 4 file to the bank branch: {bank_name} - {import_file_code}',
    'body': 'Tax coding and the Nafeza link to {bank_name} are complete. Ready to submit the Form 4 application to the bank and follow up its approval for shipment {import_file_code}.',
  },
  'DOC_REGULATORY_BODIES_DETECTED': {
    'title': 'Regulatory inspections detected for shipment {import_file_code}',
    'body': 'The Nafeza items pull shows regulatory inspection bodies: {regulatory_bodies}. Prepare the inspection file and draw samples early.',
  },
  'TR_TASK_TRACK_ARRIVAL_GRN': {
    'title': 'Follow up the truck arrival at the warehouse and issue the GRN (TR-03)',
  },
  'TR_SEAL_BROKEN': {
    'title': 'Broken customs seal reported for truck {truck_plate_number}',
    'body': 'Truck {truck_plate_number} arrived with a broken customs seal ({seal_number}).',
    'note': 'Broken customs seal {seal_number} reported upon arrival.',
  },

  'WH_GRN_ISSUED': {
    'title': 'Goods receiving note issued ({grn_code})',
    'body': 'Goods of {import_file_code} arrived at {warehouse_name}; GRN {grn_code} issued.',
    'note': 'Goods received at {warehouse_name}; GRN {grn_code} issued.',
  },
  'WH_INSPECTION_PROTOCOL_APPROVED': {
    'title': 'Warehouse inspection protocol ({protocol_no})',
    'body': '{committee} approved the inspection protocol for {import_file_code}. Verdict: {verdict_enum_warehouse_inspection_verdict} (accepted: {accepted_qty}, shortage: {shortage_qty}, damaged: {damaged_qty}).',
  },
  'WH_INSPECTION_PROTOCOL_APPROVED_CLAIMS': {
    'title': 'Warehouse inspection protocol ({protocol_no})',
    'body': '{committee} approved the inspection protocol for {import_file_code}. Verdict: {verdict_enum_warehouse_inspection_verdict} (accepted: {accepted_qty}, shortage: {shortage_qty}, damaged: {damaged_qty}). Insurance claim: {insurance_claim_ref}. Supplier debit note: {supplier_claim_ref}.',
  },
  'WH_TASK_INSPECTION_DISCREPANCY': {
    'title': 'Technical inspection and shortage & damage reconciliation (TR-04) - {grn_code}',
    'body': 'Reconcile the quantities of GRN {grn_code} with the invoice and record any shortage or damage for {import_file_code}.',
  },
  'DOC_CHK_ACID_MATCH': {
    'note': 'ACID number matches exactly',
  },
  'DOC_CHK_ACID_MISMATCH': {
    'note': 'The ACID number in the invoice differs from the ACID number recorded in the system!',
  },
  'DOC_CHK_AMOUNT_MATCH': {
    'note': 'Total amount and currency match exactly',
  },
  'DOC_CHK_AMOUNT_VARIANCE': {
    'note': 'Amount difference: {variance_amount} {currency} ({variance_pct}%)',
  },
  'DOC_CHK_CBM_MATCH': {
    'note': 'Total volume matches',
  },
  'DOC_CHK_CBM_VARIANCE': {
    'note': 'Volume difference: {difference_qty} CBM ({difference_pct}%)',
  },
  'DOC_CHK_CURRENCY_MISMATCH': {
    'note': 'Currency mismatch: system ({system_currency}) vs document ({document_currency})',
  },
  'DOC_CHK_GROSS_WEIGHT_MATCH': {
    'note': 'Gross weight matches',
  },
  'DOC_CHK_GROSS_WEIGHT_VARIANCE': {
    'note': 'Weight difference: {difference_qty} kg ({difference_pct}%)',
  },
  'DOC_CHK_HS_CODE_MATCH': {
    'note': 'HS code matches',
  },
  'DOC_CHK_HS_CODE_MISMATCH': {
    'note': 'Extracted HS code ({document_value}) differs from the record ({system_value})',
  },
  'DOC_CHK_IMPORTER_MATCH': {
    'note': 'Importer name matches',
  },
  'DOC_CHK_IMPORTER_MISMATCH': {
    'note': 'Extracted importer name ({document_value}) differs from the record ({system_value})',
  },
  'DOC_CHK_INVOICE_NO_MATCH': {
    'note': 'Invoice number matches the purchase order and the system',
  },
  'DOC_CHK_INVOICE_NO_MISMATCH': {
    'note': 'Invoice number in the document ({document_value}) differs from the system invoice number ({system_value})!',
  },
  'DOC_CHK_NET_WEIGHT_MATCH': {
    'note': 'Net weight matches',
  },
  'DOC_CHK_NET_WEIGHT_VARIANCE': {
    'note': 'Net weight difference: {difference_qty} kg ({difference_pct}%)',
  },
  'DOC_CHK_PACKAGES_MATCH': {
    'note': 'Number of packages matches',
  },
  'DOC_CHK_PACKAGES_VARIANCE': {
    'note': 'Packages difference: {difference_count} packages',
  },
  'DOC_CHK_SUPPLIER_MATCH': {
    'note': 'Supplier name matches',
  },
  'DOC_CHK_SUPPLIER_MISMATCH': {
    'note': 'Extracted supplier name ({document_value}) differs from the system record ({system_value})',
  },
  'DOC_CHK_TAX_ID_MATCH': {
    'note': 'Tax ID matches',
  },
  'DOC_CHK_TAX_ID_MISMATCH': {
    'note': 'Importer tax ID mismatch.',
  },
  'DOC_COO_SIMILARITY': {
    'note': 'Similarity: {match_pct}%',
  },
  'DOC_COO_VALUE_NOT_FOUND': {
    'note': 'Value not found in the certificate of origin draft',
  },
  'DOC_DRAFT_APPROVED_VALUE_MISMATCH': {
    'note': 'Mismatch! Approved value: \'{system_value}\' | Draft value: \'{draft_value}\'.',
  },
  'DOC_DRAFT_FIELD_MISSING': {
    'note': 'Required field was not extracted or entered in the draft B/L data.',
  },
  'DOC_DRAFT_FUZZY_MATCH': {
    'note': 'Smart match at {match_pct}%.',
  },
  'DOC_DRAFT_NUMERIC_MATCH': {
    'note': 'Numeric match (difference {diff_pct}% within the {tolerance_pct}% tolerance).',
  },
  'DOC_DRAFT_NUMERIC_UNVERIFIABLE': {
    'note': 'Could not verify the value numerically: {draft_value}',
  },
  'DOC_DRAFT_NUMERIC_VARIANCE': {
    'note': 'Difference exceeds the tolerance ({diff_pct}%). System: {system_qty} | Draft: {draft_qty}.',
  },
  'DOC_DRAFT_TEXT_MATCH': {
    'note': 'Exact text match (100%).',
  },
  'DOC_DRAFT_VALUE_FROM_DRAFT': {
    'note': 'Value taken from the draft ({draft_value}).',
  },
  'DOC_DRAFT_VALUE_MISMATCH': {
    'note': 'Mismatch! System value: \'{system_value}\' | Draft value: \'{draft_value}\'.',
  },
  'DOC_IBL_ACID_MATCH': {
    'note': 'Customs ACID number matches 100%',
  },
  'DOC_IBL_ACID_MISMATCH': {
    'note': 'ACID number mismatch blocks customs release and stops the shipment immediately.',
  },
  'DOC_IBL_ACID_NOT_EXTRACTED': {
    'note': 'ACID number was not extracted from the invoice or the B/L.',
  },
  'DOC_IBL_ARITHMETIC_MATCH': {
    'note': 'Line items arithmetic recalculation matches total invoice amount ({total_amount} {currency})',
  },
  'DOC_IBL_ARITHMETIC_MISMATCH': {
    'note': 'Arithmetic discrepancy: calculated line items sum ({calculated_amount}) differs from total ({total_amount})',
  },
  'DOC_IBL_CONSIGNEE_MATCH': {
    'note': 'Importer name matches',
  },
  'DOC_IBL_CONSIGNEE_MISMATCH': {
    'note': 'Importer name differs between the invoice and the B/L.',
  },
  'DOC_IBL_CONSIGNEE_NOT_EXTRACTED': {
    'note': 'Could not extract the importer / consignee name.',
  },
  'DOC_IBL_CURRENCY_MATCH': {
    'note': 'Currency matches across documents and system ({currency})',
  },
  'DOC_IBL_CURRENCY_MISMATCH': {
    'note': 'Currency mismatch: invoice ({invoice_currency}) vs system ({system_currency})',
  },
  'DOC_IBL_CONTAINERS_MATCH': {
    'note': 'Container numbers match exactly',
  },
  'DOC_IBL_CONTAINERS_MISMATCH': {
    'note': 'Container numbers in the invoice do not match the B/L.',
  },
  'DOC_IBL_CONTAINERS_DUMMY': {
    'note': 'Provisional or dummy container number ({container_no}) detected: final confirmation required',
  },
  'DOC_IBL_CONTAINERS_ISO_INVALID': {
    'note': 'Container number ({container_no}) fails ISO 6346 check digit validation',
  },
  'DOC_IBL_GROSS_WEIGHT_EXCEEDS': {
    'note': 'Gross weight difference exceeds the customs tolerance.',
  },
  'DOC_IBL_GROSS_WEIGHT_MATCH': {
    'note': 'Gross weight matches within the allowed range (<= {tolerance_pct}%)',
  },
  'DOC_IBL_HS_MATCH': {
    'note': 'Harmonized System (HS) code matches across invoice, B/L and system',
  },
  'DOC_IBL_HS_MISMATCH': {
    'note': 'HS code mismatch: invoice ({invoice_hs}) vs B/L ({bl_hs})',
  },
  'DOC_IBL_HS_NOT_EXTRACTED': {
    'note': 'HS classification code not found in one or more documents',
  },
  'DOC_IBL_INCOTERMS_COHERENT': {
    'note': 'Incoterm {incoterm} is consistent with the freight payment ({freight_terms})',
  },
  'DOC_IBL_NET_WEIGHT_MATCH': {
    'note': 'Net weight matches',
  },
  'DOC_IBL_NET_WEIGHT_VARIANCE': {
    'note': 'Net weight differs between the invoice and the draft B/L.',
  },
  'DOC_IBL_NOTIFY_MATCH': {
    'note': 'Notify party details match the consignee and shipment document',
  },
  'DOC_IBL_NOTIFY_MISMATCH': {
    'note': 'Notify party differs between the invoice and the B/L',
  },
  'DOC_IBL_NOTIFY_NOT_EXTRACTED': {
    'note': 'Notify party details were not extracted from the B/L',
  },
  'DOC_IBL_NOTIFY_PENDING_WARNING': {
    'note': 'Notify party contains pending annotation (Please Advise / TBA) requiring confirmation',
  },
  'DOC_IBL_PACKAGES_MATCH': {
    'note': 'Package and pallet counts match exactly',
  },
  'DOC_IBL_PACKAGES_MISMATCH': {
    'note': 'Package count or packing unit differs (carton vs pallet).',
  },
  'DOC_IBL_SEALS_CHECK': {
    'note': 'Please verify the seal number fixed on the container.',
  },
  'DOC_IBL_SEALS_MATCH': {
    'note': 'Seal numbers match',
  },
  'DOC_IBL_SHIPPER_MATCH': {
    'note': 'Exporter name matches in the invoice and the B/L',
  },
  'DOC_IBL_SHIPPER_MISMATCH': {
    'note': 'Exporter / shipper name differs between the invoice and the B/L.',
  },
  'DOC_IBL_SHIPPER_NOT_EXTRACTED': {
    'note': 'Could not extract the shipper / exporter name.',
  },
  'DOC_IBL_TAX_ID_MATCH': {
    'note': 'Importer tax registration number matches',
  },
  'DOC_IBL_TAX_ID_MISMATCH': {
    'note': 'Tax ID mismatch blocks the Nafeza and Form 4 matching.',
  },
  'DOC_IBL_TAX_ID_NOT_EXTRACTED': {
    'note': 'Importer tax ID was not extracted from the documents.',
  },
  'DOC_INSPECTION_MATCH_RATE': {
    'note': 'Match rate: {match_pct}%',
  },
  'DOC_INSPECTION_OPTIONAL_NOT_INCLUDED': {
    'note': 'Optional field not included in the inspection certificate draft',
  },
  'DOC_INSPECTION_VALUE_NOT_FOUND': {
    'note': 'Value not found in the uploaded inspection certificate draft',
  },
  'DOC_TOL_ARITHMETIC': {
    'note': 'Line-by-line arithmetic precision',
  },
  'DOC_TOL_CONTAINERS_EXACT': {
    'note': '0% (exact container number match)',
  },
  'DOC_TOL_CURRENCY': {
    'note': '0% (exact currency match)',
  },
  'DOC_TOL_EXACT': {
    'note': '0% (exact match required)',
  },
  'DOC_TOL_HS_CODE': {
    'note': 'HS code classification match',
  },
  'DOC_TOL_ISO_CONTAINER': {
    'note': 'ISO 6346 & provisional check',
  },
  'DOC_TOL_PACKAGES_EXACT': {
    'note': '0% (package count match)',
  },
  'DOC_TOL_SEAL_MATCH': {
    'note': 'Seal number match',
  },
  'DOC_TOL_SIMILARITY': {
    'note': 'Similarity: {match_pct}%',
  },
  'DOC_TOL_TERMS_COHERENCE': {
    'note': 'Commercial terms coherence',
  },
  'DOC_TOL_WEIGHT_DIFFERENCE': {
    'note': 'Difference: {difference_qty} kg ({difference_pct}%)',
  },
  'CUSTOMS_FX_RATE_MISSING': {
    'note': 'No customs exchange rate for {currency} on {on_date}.',
  },
  'IR_ASSESSMENT_EXISTS': {
    'note': 'An active import-requirements assessment ({assessment_code}) already exists for this import file.',
  },
  'OVER_SHIPPED': {
    'note': 'Over-shipment: {shipped_qty} shipped against {ordered_qty} ordered on purchase order {po_number} {item_code}',
  },
  'PO_PL_DIMENSIONS_MISSING': {
    'note': 'Item #{line_num} ({item_code}): Package dimensions missing or zero; CBM cannot be computed accurately.',
  },
  'PO_PL_GROSS_BELOW_NET': {
    'note': 'Item #{line_num} ({item_code}): Gross weight per unit ({gross_qty} kg) cannot be less than Net weight ({net_qty} kg).',
  },
  'PO_PL_HS_MISSING_IN_INVOICE': {
    'note': 'HS Code \'{hs_code}\' exists in Packing List but is missing from Commercial Invoice.',
  },
  'PO_PL_HS_MISSING_IN_PACKING': {
    'note': 'HS Code \'{hs_code}\' exists in Commercial Invoice but is missing from Packing List.',
  },
  'PO_PL_HS_QTY_MISMATCH': {
    'note': 'HS Code \'{hs_code}\': Packing List Qty ({packing_qty}) differs from Invoice Qty ({invoice_qty}) [Diff: {signed_difference}].',
  },
  'PO_PL_NEGATIVE_WEIGHT': {
    'note': 'Item #{line_num} ({item_code}): Unit weights cannot be negative.',
  },
  'PO_PL_NO_ITEMS': {
    'note': 'No packing list items recorded for this purchase order.',
  },
  'PO_PL_TOTAL_QTY_MISMATCH': {
    'note': 'Total Quantity Mismatch: Packing List total PCS ({packing_qty}) differs from Invoice total PCS ({invoice_qty}) [Diff: {signed_difference}].',
  },
  'PREFILL_LINE_NO_HS': {
    'note': 'PO {po_number} line {item_code} has no tariff (HS code) and was skipped.',
  },
  'PREFILL_NO_HS': {
    'note': 'No HS code found for import file {import_file_code}: add the tariff on the PO lines or the consultation.',
  },
  'PREFILL_MIXED_CURRENCY': {
    'note': 'The purchase orders of this import file use different currencies ({currencies}): enter the shipment value and currency manually.',
  },
  'PO_ITEMS_ALLOCATED': {
    'note': 'Purchase order lines {item_ids} have recorded shipments and cannot be removed; send their item_id to edit them.',
  },
  'PO_NUMBER_TAKEN': {
    'note': 'Purchase order number {po_number} is already in use; please retry.',
  },
  'SCENARIO_SESSION_EXISTS': {
    'note': 'An active shipping-scenario study ({session_code}) already exists for this import file.',
  },
  'SCENARIO_ITEMS_BOOKED': {
    'note': 'Cannot delete shipping options ({item_ids}) referenced by a freight booking.',
  },
  'CONSULTATION_EXISTS': {
    'note': 'An active customs consultation ({consultation_code}) already exists for this import file.',
  },
  'CUSTOMS_MIXED_CURRENCY': {
    'note': 'The purchase orders of this import file use different currencies ({currencies}): recalculation needs one currency per side.',
  },
  'FA_FX_RATE_MISSING': {
    'note': 'No exchange rate is recorded for {currency_code}. Add it on the Currencies screen.',
  },
  'FA_CURRENCY_MISSING': {
    'note': 'No currency is recorded for the amount of {source}. Set the currency first.',
  },
  'FA_CURRENCY_UNKNOWN': {
    'note': 'Currency {currency_code} is not defined on the Currencies screen.',
  },
  'FA_SWIFT_CURRENCY_MISMATCH': {
    'note': 'The SWIFT currency {swift_currency} does not match the payment request currency {currency_code}.',
  },
  'FA_SWIFT_REF_ALREADY_USED': {
    'note': 'SWIFT reference {swift_ref} is already used by payment request {payment_code}.',
  },
  'FA_SWIFT_REF_REQUIRED': {
    'note': 'A SWIFT reference is required before recording payment for request {payment_code}.',
  },
  'FA_SWIFT_BATCH_ALREADY_RECONCILED': {
    'note': 'SWIFT batch {batch_code} is already reconciled with payment request {payment_code}.',
  },
  'FA_SWIFT_BATCH_STATUS_INVALID': {
    'note': 'This action is not allowed on SWIFT batch {batch_code} in status {status}.',
  },
  'FA_SWIFT_VALUE_DATE_INVALID': {
    'note': "Value date '{value}' in SWIFT batch {batch_code} is missing or not in YYYY-MM-DD format.",
  },
  'FA_PAYMENT_STATUS_INVALID': {
    'note': 'Payment request {payment_code} is {status}: the action {action} is not allowed.',
  },
  'FA_PAYMENT_LOCKED': {
    'note': 'An approved or paid payment request ({payment_code}, {status}) cannot be changed or deleted.',
  },
  'FA_PAYMENT_RATE_REQUIRED': {
    'note': 'When changing the currency of payment request {payment_code}, the new exchange rate for {currency_code} must be provided.',
  },
  'FA_BUDGET_LOCKED': {
    'note': 'An approved or superseded budget ({budget_code}, {status}) cannot be changed: sync it to create a new revision.',
  },
  'FA_BUDGET_STATUS_INVALID': {
    'note': 'Budget {budget_code} cannot be approved in status {status}.',
  },
  'FA_PAYMENT_DUPLICATE_TYPE': {
    'note': 'An open payment request of type {payment_type} already exists for this file ({payment_code}).',
  },
  'FA_BUDGET_DUPLICATE_FILE': {
    'note': 'A budget already exists for import file {import_file_code}. Edit it instead of creating a new one.',
  },
  'FA_BUDGET_HARD_BLOCK': {
    'note': 'The cost variance of {variance_percentage}% on {field_name} exceeds the threshold (hard block): sync the costs or give a written justification.',
  },
  'FA_BUDGET_SOD_DENIED': {
    'note': 'Segregation of duties: the user who changed the upstream costs cannot sync the approved budget.',
  },
  'FA_BUDGET_SYNC_REVISION_CREATED': {
    'note': 'Budget revision {budget_code} created; the approved version was archived as superseded.',
  },
  'FA_BUDGET_SYNC_DONE': {
    'note': 'Budget {budget_code} synced with live costs; status {status}.',
  },
  'FA_SWIFT_BATCH_CONFIRMED': {
    'note': 'SWIFT data of batch {batch_code} confirmed; matching is unlocked.',
  },
  'FA_SWIFT_FILE_TOO_LARGE': {
    'note': 'The SWIFT file exceeds the {max_mb} MB limit.',
  },
  'FA_SWIFT_FILE_INVALID_BASE64': {
    'note': 'The uploaded file content is not valid Base64.',
  },
  'FA_CODE_GENERATION_CONFLICT': {
    'note': 'Reference {reference_code} is already in use. Please try again.',
  },
  'DOC_ACID_TRACKER_STATUS': {
    'note': 'ACID status: {status} ({days} days remaining).',
  },
  'DOC_LEGAL_DOC_EXPIRED': {
    'note': '{doc_kind} {doc_number} expired on {expiry_date}: shipping and customs release are blocked.',
  },
  'DOC_LEGAL_DOC_CRITICAL_BREACH': {
    'note': '{doc_kind} {doc_number} expires on {expiry_date}, less than 30 days after the expected arrival {eta_date}.',
  },
  'DOC_LEGAL_DOC_EXPIRING_SOON': {
    'note': '{doc_kind} {doc_number} expires on {expiry_date} ({days} days left).',
  },
  'DOC_LEGAL_DOC_VALID': {
    'note': '{doc_kind} {doc_number} is valid until {expiry_date}.',
  },
  'DOC_LEGAL_ACID_MISSING': {
    'note': 'The ACID validity date of this shipment is not recorded yet.',
  },
  'DOC_LEGAL_BANNER': {
    'note': 'Critical shipment safety warning (ETA + 30 days margin): {critical_count} document(s) need action.',
  },
  'DOC_INVOICE_BL_SYNCED': {
    'note': 'Invoice {invoice_number} and B/L {draft_bl_number} matched, approved and synced to the import file and customs approvals.',
  },
  'DOC_INVOICE_BL_NOT_CERTIFIED': {
    'note': 'No active certified invoice vs B/L match session exists for import file {import_file_id}. Certify the session first.',
  },
  'ODC_COURIER_NOT_FOUND': {
    'note': 'Courier {courier_no} is not registered on this file\'s original documents session. Add it to the session first.',
  },
  'ODC_SESSION_NOT_FOUND': {
    'note': 'No original documents collection session exists for import file {import_file_id}.',
  },
  'DCA_SESSION_FINAL_LOCKED': {
    'note': 'Customs approval session {session_code} is certified and can no longer be changed.',
  },
  'DCA_SESSION_NOT_READY': {
    'note': 'The session cannot be certified: document statuses not set ({missing_statuses}); open rectification tickets: {open_tickets_count}.',
  },
  'DCA_TICKET_CLOSED': {
    'note': 'Rectification ticket {ticket_code} is already closed ({status}).',
  },
  'DCA_SAME_REVIEWER': {
    'note': '{reviewer} already signed the other review tier of {approval_code}: the commercial and customs reviews need two different users.',
  },
  'SDU_ACID_INVALID': {
    'note': 'The extracted ACID number {acid_number} is invalid: it must be 19 digits.',
  },
  'SDU_ACID_CONFLICT': {
    'note': 'The extracted ACID {acid_number} differs from the ACID on file {import_file_code} ({current_acid_number}).',
  },
  'SDU_INVOICE_NUMBER_REQUIRED': {
    'note': 'Invoice number is required to link invoice data to the import file.',
  },
  'SDU_FILE_CLOSED': {
    'note': 'Import file {import_file_code} is {status}: extracted data cannot be applied to it.',
  },
  'SDU_INVOICE_APPLIED': {
    'note': 'Invoice {invoice_no} data applied to file {import_file_code}.',
  },
  'SDU_BL_APPLIED': {
    'note': 'B/L data applied to shipment {cargo_shipping_code} ({containers_applied} containers).',
  },
  'SDU_EXTRACTED_ONLY': {
    'note': 'Data extracted and ready to use for a new file.',
  },
  'SDU_NO_SHIPPING_RECORD': {
    'note': 'Import file {import_file_code} has no active shipping record: create it before applying the B/L data.',
  },
  'XCHK_ACID_MISMATCH': {
    'note': 'ACID number mismatch between the commercial invoice and the bill of lading',
  },
  'XCHK_TAX_ID_MISMATCH': {
    'note': 'Egyptian importer tax ID mismatch between the invoice and the bill of lading',
  },
  'XCHK_SHIPPER_MISMATCH': {
    'note': 'Shipper / exporter name differs (similarity {similarity_pct}%)',
  },
  'XCHK_CONSIGNEE_MISMATCH': {
    'note': 'Consignee / importer name differs (similarity {similarity_pct}%)',
  },
  'XCHK_WEIGHT_OVER': {
    'note': 'Gross weight variance of {diff_kg} kg ({variance_pct}%) exceeds the allowed tolerance ({tolerance_pct}%)',
  },
  'XCHK_WEIGHT_MINOR': {
    'note': 'Minor gross weight difference of {diff_kg} kg ({variance_pct}%) within the accepted tolerance',
  },
  'XCHK_PORTS_MISMATCH': {
    'note': 'Port of loading or port of discharge does not fully match',
  },
  'XCHK_INCOTERM_PREPAID_CONFLICT': {
    'note': 'Shipping terms conflict: invoice term {incoterm} but the bill of lading is Freight Prepaid',
  },
  'XCHK_INCOTERM_COLLECT_CONFLICT': {
    'note': 'Shipping terms conflict: invoice term {incoterm} includes freight but the bill of lading is Freight Collect',
  },
  'XCHK_PACKAGES_MISMATCH': {
    'note': 'Package count differs between the invoice ({invoice_packages}) and the bill of lading ({bl_packages})',
  },
  'DD_SETTLEMENT_STALE': {
    'note': 'The demurrage charges of {tracking_code} were recalculated but its landed-cost settlement is locked; they were not re-pushed.',
  },
  'CC_RELEASE_RECORD_FILE_MISMATCH': {
    'note': 'Clearance record {clearance_id} does not belong to import file {import_file_id}.',
  },
  'CC_DUTY_NOT_ASSESSED': {
    'note': 'The duty payment cannot be recorded before the final duty assessment (CL-02).',
  },
  'CC_DUTY_UNDERPAID': {
    'note': 'The paid amount {paid_amount} EGP is below the assessed duty of {assessed_amount} EGP.',
  },
  'CC_DUTY_NOT_PAID': {
    'note': 'The final release cannot be issued before the customs duty is paid (CL-03).',
  },
  'CC_DUTY_PAID_AMOUNT_REQUIRED': {
    'note': 'The paid duty amount is required and must be above zero.',
  },
  'CC_ASSESS_REQUIRES_DECLARATION_46': {
    'note': 'Final duties cannot be assessed before customs declaration 46 is registered (CS-03).',
  },
  'CC_UPDATE_NULL_NOT_ALLOWED': {
    'note': 'These fields cannot be cleared: {fields}.',
  },
  'CC_RESTORE_DUPLICATE_ACTIVE': {
    'note': 'Cannot restore: another active clearance record ({clearance_code}) exists for this file.',
  },
  'CC_UNDER_BOND_NOT_ALLOWED': {
    'note': 'Under-bond release refused: the shipment is already under bond or finally released ({clearance_status}).',
  },
  'CC_INVOICE_FX_RATE_REQUIRED': {
    'note': 'An exchange rate is required for an invoice in {currency}.',
  },
  'CC_INVOICE_RECORD_FILE_MISMATCH': {
    'note': 'Clearance record {customs_clearance_id} does not belong to import file {import_file_id}.',
  },
  'CC_ACID_EXPIRY_INVALID': {
    'note': 'The ACID expiry date stored on import file {import_file_id} is invalid.',
  },
  'CC_REFERENCE_CODE_CONFLICT': {
    'note': 'A unique reference code could not be generated because of concurrent saves; please retry.',
  },
  'CC_RELEASE_QUARANTINE_LOCKED': {
    'note': 'The final release cannot be issued while {clearance_code} is under the laboratory quarantine lock.',
  },
  'CC_REGULATORY_REQUIREMENTS_NOT_MET': {
    'note': 'Customs release cannot be issued: the regulatory approvals or the goods inspection are not complete (GOEIC / food safety / technical inspection).',
  },
  'IF_FILE_ON_HOLD': {
    'note': 'Import file {import_file_code} is on hold ({hold_reason}); resume it before continuing.',
  },
  'IF_FILE_ALREADY_CLOSED': {
    'note': 'Import file {import_file_code} is already closed.',
  },
  'ITEM_CODE_ALREADY_EXISTS': {
    'note': 'This item code is already registered in the item catalog.',
  },
  'ITEM_NOT_FOUND': {
    'note': 'The item does not exist or has been deleted.',
  },
  'ITEM_SUPPLIER_LINK_EXISTS': {
    'note': 'This item is already linked to this supplier in the price catalog.',
  },
  'SUPPLIER_NOT_FOUND': {
    'note': 'The foreign supplier does not exist in the directory.',
  },
  'TARIFF_NOT_FOUND': {
    'note': 'The customs tariff item does not exist or is inactive.',
  },
  'CC_LAB_RESULT_ALREADY_FINAL': {
    'note': 'The lab result was already recorded and the quarantine lifted, or the shipment is finally released ({clearance_status}).',
  },
  'CC_ASSESSED_COMPONENTS_LOCKED': {
    'note': 'Duty components cannot be edited after the assessment ({fields}); re-assess the final duties (CL-02).',
  },
  'CC_SETTLEMENT_LOCKED': {
    'note': 'Clearance invoices cannot be modified after the landed-cost settlement is approved ({settlement_code}).',
  },
  'CCQ_RFQ_STATUS_INVALID': {
    'note': 'RFQ status \'{status}\' is not allowed; awarding is done through the award action only.',
  },
  'CCQ_RFQ_AWARDED': {
    'note': 'The RFQ is already awarded and cannot be modified, deleted, or awarded again.',
  },
  'CCQ_RFQ_CANCELLED': {
    'note': 'RFQ {rfq_code} is cancelled and cannot be awarded.',
  },
  'CCQ_QUOTE_EXPIRED': {
    'note': 'The quotation expired on {validity_date}.',
  },
  'CCQ_AWARDED_QUOTE_DELETE': {
    'note': 'The awarded quotation cannot be deleted.',
  },
  'CCQ_PRICE_LIST_DATE_RANGE': {
    'note': 'The validity start {effective_from} is after its end {effective_to}.',
  },
  'SS_FX_RATE_MISSING': {
    'note': 'No commercial exchange rate found for currency {currency} on date {on_date}.',
  },
  'WR_GRN_EXISTS': {
    'note': 'An active goods receipt note ({grn_code}) already exists for this import file.',
  },
  'WR_GRN_LINE_UNBALANCED': {
    'note': 'Line {item_code}: accepted {accepted_qty} + shortage {shortage_qty} + damaged {damaged_qty} must equal invoiced {invoiced_qty}.',
  },
  'WR_VERDICT_INVALID': {
    'note': 'Unknown inspection verdict \'{verdict}\'.',
  },
  'WR_VERDICT_INCONSISTENT': {
    'note': 'The verdict cannot be accepted in full with {shortage_qty} short and {damaged_qty} damaged.',
  },
  'WR_VERDICT_INCONSISTENT_EXPECTED': {
    'note': 'The inspection verdict {verdict} does not match the inspection outcome (expected {expected_verdict}).',
  },
  'WR_STATUS_INVALID': {
    'note': 'Unknown goods receipt status \'{status}\'.',
  },
  'WR_DISCREPANCY_TYPE_INVALID': {
    'note': 'Unknown discrepancy type \'{discrepancy_type}\'.',
  },
  'WR_CLAIM_CURRENCY_INVALID': {
    'note': 'Claim currency code \'{currency_code}\' is invalid or inactive.',
  },
  'WR_FIELD_NOT_EDITABLE': {
    'note': 'Field \'{field_name}\' cannot be edited directly.',
  },
  'WR_STATUS_CHANGE_NOT_ALLOWED': {
    'note': 'Cannot change goods receipt status from \'{current_status}\' to \'{target_status}\'.',
  },
  'WR_CUSTOMS_NOT_RELEASED': {
    'note': 'Cannot create warehouse receipt for file {import_file_code}: customs release or under-bond authorization required.',
  },
  'WR_GRN_LOCKED': {
    'note': 'Goods receipt {grn_code} is locked (filed protocol, active claims, or quarantine): deletion is blocked.',
  },
  'WR_DATE_IN_FUTURE': {
    'note': 'The inspection date cannot be more than 24 hours in the future.',
  },
  'IT_BOOKING_EXISTS': {
    'note': 'An active inland booking ({transport_code}) already exists for waybill {waybill_number} on this file.',
  },
  'IT_CARRIER_INVALID': {
    'note': 'Carrier with ID {carrier_id} is unknown or inactive.',
  },
  'IT_TRUCK_TYPE_INVALID': {
    'note': 'Truck type \'{truck_type}\' is invalid.',
  },
  'IT_SEAL_REQUIRED': {
    'note': 'Seal number is required when seal is broken.',
  },
  'IT_DATE_IN_FUTURE': {
    'note': '{field_name} cannot be more than 24 hours in the future.',
  },
  'IT_STATUS_INVALID': {
    'note': 'Unknown inland transport status \'{status}\'.',
  },
  'IT_TRANSITION_NOT_ALLOWED': {
    'note': 'Cannot record {action} while the booking is \'{current_status}\'.',
  },
  'FC_ALREADY_CLOSED': {
    'note': 'Import file {import_file_code} is already closed. Reopen it first.',
  },
  'LIST_SORT_FIELD_INVALID': {
    'note': 'Unknown sort field \'{field}\'. Allowed fields: {allowed}.',
  },
  'CURRENCY_NOT_FOUND': {
    'note': 'Currency code \'{currency}\' is not registered in the system.',
  },
  'CURRENCY_RATE_MISSING': {
    'note': 'No exchange rate registered for currency \'{currency}\' (rate type \'{rate_type}\') as of {as_of_date}.',
  },
  'CURRENCY_RATE_EXISTS': {
    'note': 'An active exchange rate already exists for {currency} on {effective_date}. Pass replace=true to overwrite.',
  },
  'CURRENCY_BASE_EXISTS': {
    'note': 'A base currency ({base_currency}) already exists; cannot set a second base currency.',
  },
  'PORT_TERMINAL_RATE_EXISTS': {
    'note': 'A port storage rate already exists for terminal {terminal_code}, {container_size} container, effective {effective_date}. Edit the existing rate or choose another effective date.',
  },
  'CT_CUSTOMS_RATE_MISSING': {
    'note': 'No customs exchange rate registered for currency \'{currency}\' on date {on_date}.',
  },
  'TRM_INVALID_HS': {
    'note': 'Tariff item \'{hs_code}\' is not valid: it needs at least 4 digits.',
  },
  'TRM_INVALID_ORIGIN': {
    'note': 'Origin country \'{origin_country}\' must be a two-letter ISO code.',
  },
  'TRM_BASIS_FIELDS_MISSING': {
    'note': 'Measure basis {duty_basis} needs its rate (percent) or its fixed amount and currency.',
  },
  'TRM_INVALID_DATES': {
    'note': 'The end date ({effective_to}) is before the start date ({effective_from}).',
  },
  'TRM_OVERLAP': {
    'note': 'Measure {measure_code} already covers the same tariff item, origin and exporter in this period.',
  },
  'TRM_NOT_FOUND': {
    'note': 'Trade remedy measure {measure_id} was not found.',
  },
  'CT_TRADE_REMEDY_ORIGIN_MISSING': {
    'note': 'Tariff item {hs_code} has a {measure_type} measure by origin: enter the origin country to compute it.',
  },
  'CT_TRADE_REMEDY_EXPORTER_MISSING': {
    'note': 'The {measure_type} measure on {hs_code} is set per exporter: enter the exporter name to compute it.',
  },
  'CT_TRADE_REMEDY_QTY_MISSING': {
    'note': 'The trade remedy duty on {hs_code} is charged per {duty_basis}: enter the item\'s actual weight or quantity.',
  },
  'CT_TRADE_REMEDY_DEPOSIT': {
    'note': 'Trade remedy duties under {decree_refs} are paid to the Ministry of Investment and Foreign Trade special account.',
  },
  'CT_TRADE_REMEDY_RATE_MISSING': {
    'note': 'Tariff item {hs_codes} is flagged for anti-dumping or safeguard measures but no effective measure is registered, so no duty is included. Register the decree under Trade Remedies.',
  },
  'CT_AGREEMENT_DATA_INVALID': {
    'note': 'Invalid preferential trade agreement data ({reason}).',
  },
  'IMPORT_FILE_CLOSED': {
    'note': 'Import file {import_file_code} is permanently closed and cannot be modified. Reopening is required first.',
  },
  'IF_STATUS_TRANSITION_INVALID': {
    'note': 'Cannot transition import file status from {from} to {to}.',
  },
  'FC_CLOSURE_BLOCKED': {
    'note': 'The file cannot be closed: {blocking} not met.',
  },
  'FC_EXPORT_BLOCKED': {
    'note': 'The comprehensive dossier export cannot proceed: {blocking} not met.',
  },
  'FC_CLOSED_RECORD_LOCKED': {
    'note': 'Closure record {closure_code} belongs to a closed file: reopen the file first.',
  },
  'FC_CLOSURE_EXISTS': {
    'note': 'Cannot restore: another active closure record ({closure_code}) exists for this file.',
  },
  'FC_STATUS_INVALID': {
    'note': 'A closure record can only be set back to Draft.',
  },
  'CURRENCY_CODE_UNKNOWN': {
    'note': 'Unknown or inactive currency code \'{currency_code}\'.',
  },
  'SETTLEMENT_FX_RATE_MISSING': {
    'note': 'No exchange rate for {currency} on {on_date}. Register the rate before calculating the settlement.',
  },
  'SETTLEMENT_NOT_EDITABLE': {
    'note': 'Settlement {settlement_code} is {status} and cannot be edited or recalculated.',
  },
  'SETTLEMENT_COST_ALREADY_APPROVED': {
    'note': 'The actual landed cost of import file {import_file_code} is already approved ({status}).',
  },
  'SETTLEMENT_DUPLICATE_ACTIVE': {
    'note': 'Cannot restore: another active settlement ({settlement_code}) exists for this import file.',
  },
  'INVOICES_ALREADY_SETTLED': {
    'note': 'Invoices of {import_file_code} are already settled ({status}).',
  },
  'JOURNAL_UNBALANCED': {
    'note': 'The journal entry is unbalanced by {difference} EGP and cannot be exported.',
  },
  'SETTLEMENT_LINE_NO_HS': {
    'note': 'Line {item_code} has no HS code: it is left out of the customs estimate.',
  },
  'SETTLEMENT_LINE_ZERO_VALUE': {
    'note': 'Line {item_code} has no value: it is left out of the customs estimate.',
  },
  'SETTLEMENT_PO_NOT_ALLOCATED': {
    'note': 'Purchase order {po_number} is allocated to other shipments and has no share for this file.',
  },
  'PAYMENT_STATUS_UNKNOWN': {
    'note': 'Invoice {invoice_no} is partially paid but the paid amount is unknown: counted as unpaid.',
  },
  'ESTIMATE_UNAVAILABLE': {
    'note': 'The estimated landed cost is unavailable ({reason}); variances are against zero.',
  },
  'SETTLEMENT_UNPAID_INVOICE': {
    'note': 'Unpaid balance for {party_name}: {amount} EGP (invoice {invoice_no}).',
  },
  'WHT_RATE_MISSING_WARNING': {
    'note': 'No withholding tax rate ({tax_code}) valid on {on_date}: no deduction on invoice {invoice_no}.',
  },
  'WHT_RATE_NOT_CONFIGURED': {
    'note': 'No withholding tax rate ({tax_code}) is valid on {on_date} for clearance invoice {invoice_code}: configure the rate or enter the deducted amount on the invoice.',
  },
  'RECALC_NO_VARIANCE': {
    'note': 'No variance: all costs match the live sources.',
  },
  'RECALC_SOFT_VARIANCE': {
    'note': 'Cost variances below {threshold}% found. You can sync with a warning.',
  },
  'RECALC_HARD_BLOCK': {
    'note': 'A variance above {threshold}% was found. A written justification is required.',
  },
  'RECALC_APPLIED': {
    'note': 'Recalculation applied ({action_taken}).',
  },
  'RECALC_RATE_MISSING': {
    'note': 'Some items could not be compared: no exchange rate for their currency ({fields}).',
  },
  'CT_SIMULATION_NO_LINES': {
    'note': 'No items with HS code and value available to calculate estimated customs duties.',
  },
  'CT_SIMULATION_NO_BROKER': {
    'note': 'No customs broker assigned to the import file; customs consultation session was not created.',
  },
  'SYSPARAM_UNKNOWN': {
    'note': 'System parameter \'{param_key}\' is unknown or does not exist.',
  },
  'SYSPARAM_INVALID_VALUE': {
    'note': 'Invalid value for system parameter \'{param_key}\': {reason}',
  },
  'ACTUAL_SOURCE_MISSING': {
    'note': 'Expense bucket \'{bucket}\' has an estimated amount of {estimated_egp} EGP but no actual source invoices.',
  },
  'ACTUAL_WH_ARRIVAL': {
    'note': 'Actual warehouse arrival date.',
  },
  'ALLOCATION_BASIS_INCOMPLETE': {
    'note': 'Allocation basis \'{rule}\' for {bucket} is incomplete (missing values on {item_codes}); fell back to Value-Based.',
  },
  'CC_BANK_LINK_REQUIRES_TARIFF_CODING': {
    'note': 'Nafeza bank linkage cannot be accepted before completing item tariff coding (tariff_coding_date).',
  },
  'CHECKLIST_GATE_BLOCKED': {
    'note': 'Gatekeeper blocked: {blocking_count} mandatory checklist item(s) pending for phase {target_phase}.',
  },
  'DYNAMIC_WH_ESTIMATE': {
    'note': 'Expected warehouse arrival date (computed).',
  },
  'EMPTY_CONTAINER_RETURN': {
    'note': 'Empty container return date.',
  },
  'FA_EGP_RATE_NOT_ONE': {
    'note': 'When the payment currency is EGP, the exchange rate must be 1.0 (received {exchange_rate}).',
  },
  'FA_PAYMENT_CURRENCY_MISMATCH': {
    'note': 'The payment request currency {request_currency} does not match the purchase order currency {po_currency}.',
  },
  'FA_PAYMENT_EXCEEDS_PO': {
    'note': 'Payment amount {requested} exceeds the purchase order {po_number} ceiling (total {po_total}, already committed {committed}).',
  },
  'INVOICES_NOT_READY': {
    'note': 'Invoices settlement readiness ({readiness}%) is less than 100% due to unpaid invoices ({unpaid_count}). Please confirm payment or acknowledge unpaid amounts.',
  },
  'INVOICES_NOT_SETTLED': {
    'note': 'Actual landed cost cannot be approved before shipment invoices are settled (status: {status}).',
  },
  'LOG_TASK_DELIVERY_ORDER': {
    'title': 'Pay shipping agency charges and collect delivery order (D/O) - {import_file_code}',
    'body': 'Vessel {vessel_name} arrived at {port_name}. Settle container and agency charges to obtain Delivery Order before demurrage incurs.',
  },
  'LOG_VESSEL_ARRIVED_PORT': {
    'title': 'Vessel berthed at {port_name} - {import_file_code}',
    'body': 'Vessel {vessel_name} has berthed at {port_name}. Free days demurrage countdown is active. Settle shipping agency charges and collect Delivery Order.',
    'note': 'Vessel {vessel_name} berthed at {port_name} on {arrival_date}.',
  },
  'OPEN_TASKS_BYPASSED': {
    'note': '{count} open task(s) were bypassed by the forced skip.',
  },
  'PO_HAS_ALLOCATIONS': {
    'note': 'Purchase order cannot be deleted because it has recorded shipment allocations.',
  },
  'PO_NOT_EDITABLE': {
    'note': 'Purchase order cannot be edited or allocated in status \'{status}\'.',
  },
  'SETTLEMENT_ACTUAL_FOB_MISSING': {
    'note': 'The actual landed cost cannot be approved without an actual goods invoice or purchase order FOB value.',
  },
  'SETTLEMENT_CURRENCY_MISSING': {
    'note': 'Currency is missing for {source} invoice {invoice_no}; please provide a valid currency.',
  },
  'SETTLEMENT_MANUAL_ROWS_NOT_AGGREGATED': {
    'note': 'Settlement contains manual expense rows that are not in the aggregated invoice sources: {invoice_nos}.',
  },
  'SETTLEMENT_NOT_APPROVED': {
    'note': 'Cannot export settlement {settlement_code} because its status is \'{status}\': approval is required first.',
  },
  'SETTLEMENT_NO_ITEMS': {
    'note': 'Cannot approve actual landed cost: shipment file has no item lines for cost allocation.',
  },
  'SETTLEMENT_RESERVED_INVOICE_NO': {
    'note': 'Invoice number \'{invoice_no}\' uses the reserved recalculation adjustment prefix and can only be generated by the recalculation engine.',
  },
};
