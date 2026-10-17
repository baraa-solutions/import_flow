from typing import Optional, List, Dict, Any, Literal, Union
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator

from modules.common.legacy_rows import read_model

_ACID_STATUS_WORDS = ("PENDING", "REQUESTED", "DRAFT", "")


def normalize_acid_number(value: Optional[str], strict: bool) -> Optional[str]:
    """Empty -> PENDING, status words upper-cased. ``strict`` (input) also requires exactly 19 digits; on read a
    stored legacy number is returned as stored so an old row can never fail a list."""
    if not value:
        return "PENDING"
    cleaned = value.strip()
    if cleaned.upper() in _ACID_STATUS_WORDS:
        return cleaned.upper()
    if strict and (len(cleaned) != 19 or not cleaned.isdigit()):
        raise ValueError(f"ACID Number must be exactly 19 numeric digits, got '{cleaned}' ({len(cleaned)} digits).")
    return cleaned


# --- ACID REGISTRATION SCHEMAS (BP-014) ---
class AcidRegistrationBase(BaseModel):
    acid_number: Optional[str] = Field(default="PENDING", description="19-digit Nafeza ACID Number or PENDING during request")
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    po_number: Optional[str] = None
    po_date: Optional[date] = None

    importer_id: Optional[int] = None
    importer_name: str = Field(..., min_length=2, max_length=200)
    importer_tax_id: str = Field(..., min_length=5, max_length=50)
    importer_address: Optional[str] = None

    supplier_id: Optional[int] = None
    exporter_name: str = Field(..., min_length=2, max_length=200)
    exporter_reg_type: Optional[str] = Field(default="VAT Number", max_length=100)
    exporter_reg_id: str = Field(..., min_length=1, max_length=100)
    exporter_country: str = Field(..., min_length=1, max_length=100)
    exporter_country_code: Optional[str] = Field(default=None, max_length=10)
    exporter_address: Optional[str] = None
    exporter_phone: Optional[str] = None
    cargox_id: Optional[str] = None

    proforma_invoice_no: str = Field(..., min_length=1, max_length=100)
    proforma_invoice_date: Optional[date] = None
    invoice_date: Optional[date] = None
    invoice_type: Optional[str] = Field(default="Proforma Invoice", max_length=50)
    invoice_attachment_name: Optional[str] = None

    pol_name: str = Field(..., min_length=1, max_length=150)
    pod_name: str = Field(..., min_length=1, max_length=150)

    customs_broker_id: Optional[int] = None
    customs_broker_name: Optional[str] = None
    customs_broker_phone: Optional[str] = None

    requested_date: Optional[date] = None
    generated_date: Optional[date] = None
    expiry_date: Optional[date] = None
    execution_days: Optional[int] = None

    raw_nafeza_text: Optional[str] = None
    requested_data: Optional[Dict[str, Any]] = None
    generated_data: Optional[Dict[str, Any]] = None
    discrepancies_data: Optional[Dict[str, Any]] = None
    discrepancy_override_reason: Optional[str] = None
    verification_notes: Optional[str] = None

    @field_validator("acid_number")
    @classmethod
    def validate_acid_number_field(cls, v: Optional[str]) -> Optional[str]:
        return normalize_acid_number(v, strict=True)


class AcidRegistrationCreate(AcidRegistrationBase):
    pass


class AcidRegistrationUpdate(BaseModel):
    acid_number: Optional[str] = None
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    importer_name: Optional[str] = None
    importer_tax_id: Optional[str] = None
    importer_address: Optional[str] = None
    exporter_name: Optional[str] = None
    exporter_reg_type: Optional[str] = None
    exporter_reg_id: Optional[str] = None
    exporter_country: Optional[str] = None
    exporter_country_code: Optional[str] = None
    exporter_address: Optional[str] = None
    exporter_phone: Optional[str] = None
    cargox_id: Optional[str] = None
    proforma_invoice_no: Optional[str] = None
    proforma_invoice_date: Optional[date] = None
    invoice_date: Optional[date] = None
    invoice_type: Optional[str] = None
    invoice_attachment_name: Optional[str] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None
    customs_broker_name: Optional[str] = None
    customs_broker_phone: Optional[str] = None
    requested_date: Optional[date] = None
    generated_date: Optional[date] = None
    expiry_date: Optional[date] = None
    execution_days: Optional[int] = None
    raw_nafeza_text: Optional[str] = None
    requested_data: Optional[Dict[str, Any]] = None
    generated_data: Optional[Dict[str, Any]] = None
    discrepancies_data: Optional[Dict[str, Any]] = None
    discrepancy_override_reason: Optional[str] = None
    status: Optional[str] = None
    is_importer_matched: Optional[bool] = None
    is_exporter_matched: Optional[bool] = None
    is_invoice_matched: Optional[bool] = None
    is_ports_matched: Optional[bool] = None
    has_discrepancies: Optional[bool] = None
    verification_notes: Optional[str] = None


@read_model
class AcidRegistrationResponse(AcidRegistrationBase):
    @field_validator("acid_number")
    @classmethod
    def _acid_number_read(cls, v: Optional[str]) -> Optional[str]:
        # Read side: same normalisation, but a legacy (non 19-digit) number is listed as stored.
        return normalize_acid_number(v, strict=False)

    acid_id: int
    acid_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    is_importer_matched: bool = True
    is_exporter_matched: bool = True
    is_invoice_matched: bool = True
    is_ports_matched: bool = True
    has_discrepancies: bool = False
    status: str
    days_to_expiry: int
    execution_days: Optional[int] = None
    is_verified: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AcidTextParseRequest(BaseModel):
    raw_text: str = Field(..., min_length=10, description="Raw MTS / Nafeza approval notification text")
    import_file_id: Optional[int] = None


class AcidTextParseResponse(BaseModel):
    parsed_data: Dict[str, Any]
    comparison: Optional[Dict[str, Any]] = None


class AcidComparisonRequest(BaseModel):
    requested: Dict[str, Any]
    generated: Dict[str, Any]


class AcidRequestTemplateResponse(BaseModel):
    whatsapp_text: str
    email_subject: str
    email_body: str


# --- BANKING DOCUMENT SCHEMAS (BP-015) ---
class BankingDocumentBase(BaseModel):
    doc_type: Literal["Form 4", "Form 9", "Letter of Credit (L/C)"] = Field(
        default="Form 4", description="Form 4, Form 9, Letter of Credit (L/C)"
    )
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    bank_id: Optional[int] = None
    bank_name: str = Field(..., min_length=2, max_length=200)
    doc_reference_number: Optional[str] = Field(default="PENDING", max_length=100)
    amount: float = Field(..., gt=0.0)
    currency_code: str = Field(..., min_length=3, max_length=10, description="Active ISO 4217 currency code")
    request_date: Optional[date] = None
    received_date: Optional[date] = None
    execution_days: Optional[int] = 0
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    notes: Optional[str] = None

    # Pre-Form 4 Readiness Pipeline Fields (Tax Coding Sheet & SWIFT Bank Linkage)
    tax_coding_sheet_status: Optional[str] = Field("NOT_STARTED", description="NOT_STARTED, PULLED_BY_BROKER, UPLOADED_BY_ACCOUNTANT")
    tax_coding_sheet_file_url: Optional[str] = None
    tax_coding_pulled_date: Optional[date] = None
    tax_coding_broker_id: Optional[int] = None
    tax_coding_broker_name: Optional[str] = None
    tax_coding_uploaded_date: Optional[date] = None
    tax_coding_accountant_name: Optional[str] = None

    items_pulled_verified: Optional[bool] = False
    items_pulled_date: Optional[date] = None
    items_count_total: Optional[int] = 0
    items_count_coded: Optional[int] = 0
    regulatory_bodies_detected: Optional[List[str]] = None

    nafeza_bank_link_status: Optional[str] = Field("PENDING", description="PENDING, LINKED_TO_BANK")
    nafeza_bank_link_date: Optional[date] = None
    nafeza_linked_bank_id: Optional[int] = None
    nafeza_linked_bank_name: Optional[str] = None
    swift_executing_bank_id: Optional[int] = None
    swift_executing_bank_name: Optional[str] = None
    swift_reference_no: Optional[str] = None
    is_bank_matching_swift: Optional[bool] = True


class BankingDocumentCreate(BankingDocumentBase):
    pass


class BankingDocumentUpdate(BaseModel):
    doc_type: Optional[Literal["Form 4", "Form 9", "Letter of Credit (L/C)"]] = None
    doc_reference_number: Optional[str] = None
    import_file_id: Optional[int] = None
    bank_id: Optional[int] = None
    bank_name: Optional[str] = None
    amount: Optional[float] = Field(None, gt=0.0)
    currency_code: Optional[str] = None
    request_date: Optional[date] = None
    received_date: Optional[date] = None
    execution_days: Optional[int] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    status: Optional[str] = None
    notes: Optional[str] = None

    tax_coding_sheet_status: Optional[str] = None
    tax_coding_sheet_file_url: Optional[str] = None
    tax_coding_pulled_date: Optional[date] = None
    tax_coding_broker_id: Optional[int] = None
    tax_coding_broker_name: Optional[str] = None
    tax_coding_uploaded_date: Optional[date] = None
    tax_coding_accountant_name: Optional[str] = None
    items_pulled_verified: Optional[bool] = None
    items_pulled_date: Optional[date] = None
    items_count_total: Optional[int] = None
    items_count_coded: Optional[int] = None
    regulatory_bodies_detected: Optional[List[str]] = None
    nafeza_bank_link_status: Optional[str] = None
    nafeza_bank_link_date: Optional[date] = None
    nafeza_linked_bank_id: Optional[int] = None
    nafeza_linked_bank_name: Optional[str] = None
    swift_executing_bank_id: Optional[int] = None
    swift_executing_bank_name: Optional[str] = None
    swift_reference_no: Optional[str] = None
    is_bank_matching_swift: Optional[bool] = None


class TaxCodingSheetPullRequest(BaseModel):
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    pulled_date: date = Field(default_factory=date.today)
    file_url: Optional[str] = None
    notes: Optional[str] = None


class TaxCodingSheetUploadRequest(BaseModel):
    accountant_name: str = Field(..., min_length=2, max_length=200)
    uploaded_date: date = Field(default_factory=date.today)
    items_count_coded: Optional[int] = None
    items_count_total: Optional[int] = None
    file_url: Optional[str] = None
    notes: Optional[str] = None


class ItemsVerificationConfirmRequest(BaseModel):
    verified: bool = True
    verified_date: date = Field(default_factory=date.today)
    items_count_total: Optional[int] = None
    items_count_coded: Optional[int] = None
    regulatory_bodies_detected: Optional[List[str]] = None
    notes: Optional[str] = None


class NafezaBankLinkConfirmRequest(BaseModel):
    bank_id: int = Field(..., description="External service provider ID of the bank linked on Nafeza")
    bank_name: Optional[str] = None
    link_date: date = Field(default_factory=date.today)
    notes: Optional[str] = None
    override_swift_mismatch: bool = False
    override_reason: Optional[str] = None


class SwiftCoverageSummary(BaseModel):
    invoice_amount: float = 0.0
    invoice_currency: str = "USD"
    total_swift_transferred_amount: float = 0.0
    coverage_percent: float = 0.0
    is_fully_covered: bool = False
    executing_bank_id: Optional[int] = None
    executing_bank_name: Optional[str] = None
    swift_references: List[str] = []


class BankingDocumentReceive(BaseModel):
    form4_number: str = Field(..., min_length=1, max_length=100, description="Approved Form 4 official number")
    received_date: date = Field(default_factory=date.today, description="Receipt / endorsement date from bank")
    notes: Optional[str] = None


@read_model
class BankingDocumentResponse(BankingDocumentBase):
    bank_doc_id: int
    bank_doc_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    po_number: Optional[str] = None
    status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    swift_coverage: Optional[SwiftCoverageSummary] = None
    can_submit_form4: bool = False
    blockers: List[str] = []

    model_config = ConfigDict(from_attributes=True)


# --- SHIPMENT DOCUMENT ITEM SCHEMAS (BP-016, BP-017, BP-018) ---
class ShipmentDocumentBase(BaseModel):
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    doc_name: str = Field(..., min_length=2, max_length=100)
    doc_number: str = Field(..., min_length=1, max_length=100)
    issue_date: Optional[date] = None
    received_date: Optional[date] = None
    notes: Optional[str] = None


class ShipmentDocumentCreate(ShipmentDocumentBase):
    pass


class ShipmentDocumentUpdate(BaseModel):
    doc_number: Optional[str] = None
    import_file_id: Optional[int] = None
    status: Optional[str] = None
    is_cargox_uploaded: Optional[bool] = None
    cargox_envelope_id: Optional[str] = None
    is_bl_endorsed: Optional[bool] = None
    endorsement_number: Optional[str] = None
    notes: Optional[str] = None


@read_model
class ShipmentDocumentResponse(ShipmentDocumentBase):
    document_id: int
    document_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    status: str
    is_cargox_uploaded: bool
    cargox_envelope_id: Optional[str] = None
    is_bl_endorsed: bool
    endorsement_number: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- CUSTOMS DECLARATION 46 DRAFT SCHEMAS (BP-019) ---
class CustomsDeclarationBase(BaseModel):
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    acid_number: str = Field(..., min_length=19, max_length=19)
    form4_number: Optional[str] = None
    bl_number: Optional[str] = None
    total_cif_val_egp: Optional[float] = Field(None, ge=0.0)
    total_customs_duties_egp: Optional[float] = Field(None, ge=0.0)
    total_vat_egp: Optional[float] = Field(None, ge=0.0)


class CustomsDeclarationCreate(CustomsDeclarationBase):
    pass


@read_model
class CustomsDeclarationResponse(CustomsDeclarationBase):
    declaration_id: int
    declaration_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    amounts_entered: bool = False
    declaration_status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- ACID EXPIRY TRACKER SCHEMAS ---
class AcidTrackerItem(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    custom_file_number: Optional[str] = None
    acid_session_id: Optional[int] = None
    acid_code: Optional[str] = None
    acid_number: str
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    po_number: Optional[str] = None
    pi_number: Optional[str] = None
    shipment_mode: Optional[str] = None
    current_stage: Optional[str] = None
    customs_broker_name: Optional[str] = None

    # Dates & Validity
    acid_issue_date: Optional[date] = None
    acid_expiry_date: Optional[date] = None
    execution_days: Optional[int] = None
    days_remaining: int
    total_validity_days: int = 90
    validity_percentage: float  # 0 to 100%

    # Customs Release Status (Key Rule: alert removed once customs released)
    is_customs_released: bool = False
    customs_released_at: Optional[datetime] = None
    release_permit_no: Optional[str] = None

    # Tracker Status: 'Valid', 'Expiring Soon', 'Expired', 'Customs Released', 'Pending Issue'
    status: str
    status_label_ar: str  # deprecated (single-language rule): render message_code + message_params instead
    alert_required: bool  # True only if NOT customs released AND (days_remaining <= 14 or expired)
    # C6 (additive): language-neutral status text, e.g. DOC_ACID_TRACKER_STATUS {status, days}
    message_code: Optional[str] = None
    message_params: Optional[Dict[str, Any]] = None


class AcidTrackerSummary(BaseModel):
    total_acids_count: int
    valid_count: int
    expiring_soon_count: int
    expired_count: int
    customs_released_count: int
    pending_issue_count: int
    items: List[AcidTrackerItem]


# --- PHASE 6: FINAL INVOICE & PACKING LIST PO RECONCILIATION SCHEMAS ---
class POReconciliationItem(BaseModel):
    po_item_id: Optional[int] = None
    # C4 (additive): the packing_list_items row to adjust. Packing rows are touched only when this is sent.
    packing_item_id: Optional[int] = None
    item_code: str
    description: str
    hs_code: Optional[str] = None
    # None = no package type recorded (PO line with no packing-list row); never substituted with an invented type.
    package_type: Optional[str] = "Carton"
    initial_quantity: float
    final_quantity: float
    initial_unit_price: float = 0.0
    unit_price: float = 0.0
    final_unit_price: float = 0.0
    currency: str = "USD"
    initial_packages_count: float = 0.0
    final_packages_count: float = 0.0
    initial_net_weight_kg: float = 0.0
    final_net_weight_kg: float = 0.0
    initial_gross_weight_kg: float = 0.0
    final_gross_weight_kg: float = 0.0
    initial_cbm: float = 0.0
    final_cbm: float = 0.0
    is_confirmed: bool = True
    variance_percentage: float = 0.0
    price_variance_percentage: float = 0.0
    weight_variance_percentage: float = 0.0
    notes: Optional[str] = None


class POFinalAdjustmentItem(POReconciliationItem):
    """Request line of the final PO adjustments: quantities, prices, packages, weights and CBM are never negative
    (C4: 422). Responses keep using ``POReconciliationItem`` (OCR-extracted values are not constrained)."""
    initial_quantity: float = Field(..., ge=0)
    final_quantity: float = Field(..., ge=0)
    initial_unit_price: float = Field(default=0.0, ge=0)
    unit_price: float = Field(default=0.0, ge=0)
    final_unit_price: float = Field(default=0.0, ge=0)
    initial_packages_count: float = Field(default=0.0, ge=0)
    final_packages_count: float = Field(default=0.0, ge=0)
    initial_net_weight_kg: float = Field(default=0.0, ge=0)
    final_net_weight_kg: float = Field(default=0.0, ge=0)
    initial_gross_weight_kg: float = Field(default=0.0, ge=0)
    final_gross_weight_kg: float = Field(default=0.0, ge=0)
    initial_cbm: float = Field(default=0.0, ge=0)
    final_cbm: float = Field(default=0.0, ge=0)


class POFinalAdjustmentRequest(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    final_invoice_number: str
    final_invoice_date: Optional[date] = None
    final_packing_list_number: Optional[str] = None
    items: List[POFinalAdjustmentItem]
    is_approved_for_downstream: bool = True
    # C3: accepted for old clients but ignored; the server records the logged-in user.
    approved_by: Optional[str] = None


# --- PHASE 6: DRAFT BILL OF LADING (DRAFT B/L) 5-STAGE SCHEMAS ---
class AutoGeneratedShipmentSummary(BaseModel):
    shipper_name: str
    shipper_address: Optional[str] = None
    shipper_phone: Optional[str] = None
    shipper_reg_id: Optional[str] = None
    consignee_name: str
    consignee_address: Optional[str] = None
    consignee_phone: Optional[str] = None
    importer_tax_id: Optional[str] = None
    notify_party: str
    vessel: Optional[str] = None
    voyage: Optional[str] = None
    pol: Optional[str] = None
    pod: Optional[str] = None
    freight_terms: str = "Prepaid"
    place_of_delivery: Optional[str] = None
    booking_number: Optional[str] = None
    acid_number: Optional[str] = None
    shipping_mode: str = "FCL"
    container_summary: Optional[str] = None
    gross_weight_kg: float = 0.0
    net_weight_kg: float = 0.0
    measurement_cbm: float = 0.0
    number_of_packages: int = 0
    package_type: str = "Packages"


class DraftBLChecklistItem(BaseModel):
    field_key: str
    field_label_ar: str
    field_label_en: str
    source_entity: str
    system_value: Any
    draft_value: Any
    status: str = "Correct"  # 'Correct', 'Incorrect', 'N/A'
    required_correction: Optional[str] = None
    reason: Optional[str] = None
    # System message code of a system-generated reason (single-language storage); cleared when the text is edited.
    reason_code: Optional[str] = None
    reason_params: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    responsible_party: Optional[str] = None  # 'Shipping Provider', 'Carrier', 'Supplier', 'Importer', 'Customs Broker'
    is_locked: bool = False
    previous_status: Optional[str] = None


class RevisionReportItem(BaseModel):
    item: str
    required_action: str
    responsible: str
    reason: Optional[str] = None
    notes: Optional[str] = None


class DraftBLDiscrepancyItem(BaseModel):
    field_key: str
    field_label_ar: str
    field_label_en: str
    source_entity: str
    system_value: Any
    draft_value: Any
    match_status: str  # 'MATCH', 'MISMATCH_MINOR', 'MISMATCH_CRITICAL', 'MISSING_IN_DRAFT'
    severity: str      # 'NONE', 'WARNING', 'BLOCKING'
    tolerance_pct: float = 0.0
    details: Optional[str] = None  # English render of details_code (legacy rows: Arabic text, no code)
    details_code: Optional[str] = None
    details_params: Optional[Dict[str, Any]] = None
    structured_values: Optional[Dict[str, Dict[str, Any]]] = None


ComparisonMatrixFieldItem = DraftBLDiscrepancyItem


class DualApprovalRequest(BaseModel):
    bl_review_id: int
    role: Literal["importer", "customs_broker"]  # C2: anything else is 422
    action: Literal["Approved", "Rejected"]
    # C3: accepted for old clients but ignored; the approver is the logged-in user.
    approved_by: Optional[str] = None
    notes: Optional[str] = None


class NewDraftVersionRequest(BaseModel):
    parent_session_id: int
    draft_source: str = "SMART_TEXT"
    raw_draft_text: Optional[str] = None
    draft_fields: Optional[Dict[str, Any]] = None


class DraftBLReviewBase(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    booking_id: Optional[int] = None
    draft_bl_number: str = Field(default="DRAFT-BL", max_length=100)
    shipping_line: Optional[str] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    booking_no: Optional[str] = None
    hbl_no: Optional[str] = None
    mbl_no: Optional[str] = None
    freight_terms: Optional[str] = "Prepaid"
    place_of_delivery: Optional[str] = None
    importer_tax_id: Optional[str] = None
    shipper_reg_id: Optional[str] = None
    measurement_cbm: Optional[float] = 0.0
    net_weight_kg: Optional[float] = 0.0
    packages_count: Optional[int] = 0
    container_summary: Optional[str] = None
    draft_source: str = "SMART_TEXT"
    version_number: int = 1
    parent_session_id: Optional[int] = None
    stage: str = "Stage 1: Draft Review"
    system_snapshot_data: Optional[Dict[str, Any]] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Union[Dict[str, Any], DraftBLDiscrepancyItem]]] = None
    checklist_data: Optional[List[Union[Dict[str, Any], DraftBLChecklistItem]]] = None
    revision_report_data: Optional[List[Union[Dict[str, Any], RevisionReportItem]]] = None
    has_blocking_mismatch: bool = False
    open_discrepancies_count: int = 0
    blocking_reasons: Optional[List[str]] = None
    # [{"code": DOC_DRAFT_BLOCKING_*, "params": {"field_enum_draft_bl_field": <DRAFT_BL_FIELD code>}}]
    blocking_reasons_coded: Optional[List[Dict[str, Any]]] = None
    correction_request_letter: Optional[str] = None
    importer_approval_status: str = "Pending"
    importer_approved_by: Optional[str] = None
    importer_approval_date: Optional[datetime] = None
    importer_approval_notes: Optional[str] = None
    broker_approval_status: str = "Pending"
    broker_approved_by: Optional[str] = None
    broker_approval_date: Optional[datetime] = None
    broker_approval_notes: Optional[str] = None
    status: str = "AUTO_COMPARISON_RUN"
    is_draft: Optional[bool] = False
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None


class DraftBLReviewCreate(DraftBLReviewBase):
    pass


class DraftBLReviewUpdate(BaseModel):
    draft_bl_number: Optional[str] = None
    shipping_line: Optional[str] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    booking_no: Optional[str] = None
    hbl_no: Optional[str] = None
    mbl_no: Optional[str] = None
    freight_terms: Optional[str] = None
    place_of_delivery: Optional[str] = None
    draft_source: Optional[str] = None
    stage: Optional[str] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    checklist_data: Optional[List[Dict[str, Any]]] = None
    revision_report_data: Optional[List[Dict[str, Any]]] = None
    has_blocking_mismatch: Optional[bool] = None
    open_discrepancies_count: Optional[int] = None
    blocking_reasons: Optional[List[str]] = None
    blocking_reasons_coded: Optional[List[Dict[str, Any]]] = None
    correction_request_letter: Optional[str] = None
    importer_approval_status: Optional[str] = None
    importer_approved_by: Optional[str] = None
    importer_approval_date: Optional[datetime] = None
    importer_approval_notes: Optional[str] = None
    broker_approval_status: Optional[str] = None
    broker_approved_by: Optional[str] = None
    broker_approval_date: Optional[datetime] = None
    broker_approval_notes: Optional[str] = None
    status: Optional[str] = None
    is_draft: Optional[bool] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None


@read_model
class DraftBLReviewResponse(DraftBLReviewBase):
    bl_review_id: int
    bl_review_code: str
    import_file_code: Optional[str] = None
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DraftBLComparisonRequest(BaseModel):
    import_file_id: int
    draft_source: str = "SMART_TEXT"
    raw_draft_text: Optional[str] = None
    raw_text: Optional[str] = None
    draft_fields: Optional[Dict[str, Any]] = None


# --- PHASE 6: CERTIFICATE OF ORIGIN (COO / EUR.1) SCHEMAS ---
class CertificateOfOriginReviewBase(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    certificate_type: str = "EUR.1"
    certificate_number: str = "DRAFT-COO"
    exporter_name: Optional[str] = "N/A"
    importer_name: Optional[str] = "N/A"
    country_of_origin: Optional[str] = "N/A"
    destination_country: Optional[str] = "Egypt"
    transport_details: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    raw_input_text: Optional[str] = None
    system_snapshot_data: Optional[Dict[str, Any]] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    has_discrepancies: bool = False
    has_critical_mismatch: bool = False
    override_reason: Optional[str] = None
    notes: Optional[str] = None
    status: str = "Draft Generated"
    is_draft: Optional[bool] = False
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None


class CertificateOfOriginReviewCreate(CertificateOfOriginReviewBase):
    pass


class CertificateOfOriginReviewUpdate(BaseModel):
    certificate_type: Optional[str] = None
    certificate_number: Optional[str] = None
    exporter_name: Optional[str] = None
    importer_name: Optional[str] = None
    country_of_origin: Optional[str] = None
    destination_country: Optional[str] = None
    transport_details: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    raw_input_text: Optional[str] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    has_discrepancies: Optional[bool] = None
    has_critical_mismatch: Optional[bool] = None
    override_reason: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None
    is_draft: Optional[bool] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None


class CertificateOfOriginReviewResponse(CertificateOfOriginReviewBase):
    coo_review_id: int
    coo_review_code: str
    import_file_code: Optional[str] = None
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class COOComparisonRequest(BaseModel):
    import_file_id: int
    certificate_type: str = "EUR.1"
    raw_text: Optional[str] = None
    draft_fields: Optional[Dict[str, Any]] = None


class COODraftTemplateResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    certificate_type: str
    template_data: Dict[str, Any]
    preview_markdown: str
    exemption_notes: Optional[str] = None
    recommended_certificate_type: Optional[str] = None
    allowed_certificate_types: Optional[List[str]] = None
    recommendation_alert: Optional[str] = None
    is_manual_choice_required: Optional[bool] = False
    # C5 (additive): template keys left empty because the system has no value for them (e.g. acid_number, hs_code)
    missing_fields: List[str] = Field(default_factory=list)


# --- PHASE 6: INSPECTION CERTIFICATE SCHEMAS ---
class InspectionCertificateReviewBase(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    inspection_type: str = "COC (Certificate of Conformity)"
    inspection_agency: str = "SGS"
    certificate_number: str = "DRAFT-INSP"
    issue_date: date = Field(default_factory=date.today)
    expiry_date: Optional[date] = None
    regulatory_authority: str = "GOEIC (الرقابة على الصادرات والواردات)"
    standard_specification: Optional[str] = "Egyptian Standard ES Egyptian Conformity"
    raw_input_text: Optional[str] = None
    system_snapshot_data: Optional[Dict[str, Any]] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    has_discrepancies: bool = False
    has_critical_mismatch: bool = False
    override_reason: Optional[str] = None
    status: str = "Required_Draft_Generated"
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None


class InspectionCertificateReviewCreate(InspectionCertificateReviewBase):
    pass


class InspectionCertificateReviewUpdate(BaseModel):
    inspection_type: Optional[str] = None
    inspection_agency: Optional[str] = None
    certificate_number: Optional[str] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    regulatory_authority: Optional[str] = None
    standard_specification: Optional[str] = None
    raw_input_text: Optional[str] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    has_discrepancies: Optional[bool] = None
    has_critical_mismatch: Optional[bool] = None
    override_reason: Optional[str] = None
    status: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None


class InspectionCertificateReviewResponse(InspectionCertificateReviewBase):
    inspection_review_id: int
    inspection_review_code: str
    import_file_code: Optional[str] = None
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class InspectionComparisonRequest(BaseModel):
    import_file_id: int
    inspection_type: str = "COC (Certificate of Conformity)"
    inspection_agency: str = "SGS"
    raw_text: Optional[str] = None
    draft_fields: Optional[Dict[str, Any]] = None


class InspectionDraftTemplateResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    inspection_agency: str
    inspection_type: str
    template_data: Dict[str, Any]
    preview_markdown: str
    applicable_standards: List[str] = []
    # C5 (additive): template keys left empty because the system has no value for them
    missing_fields: List[str] = Field(default_factory=list)


class DocumentExtractRequest(BaseModel):
    document_type: str  # 'CHINA_COO', 'EUR1', 'INSPECTION_VOC', 'DRAFT_BL', 'COMMERCIAL_INVOICE'
    raw_text: Optional[str] = None
    import_file_id: Optional[int] = None


class DocumentExtractResponse(BaseModel):
    document_type: str
    extracted_data: Dict[str, Any]
    warnings: List[str] = []
    is_draft_detected: bool = False


class ThreeWayCrossMatchRequest(BaseModel):
    import_file_id: int
    coo_data: Optional[Dict[str, Any]] = None
    inspection_data: Optional[Dict[str, Any]] = None
    bl_data: Optional[Dict[str, Any]] = None
    invoice_data: Optional[Dict[str, Any]] = None
    packing_list_data: Optional[Dict[str, Any]] = None


class ThreeWayCrossMatchResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    overall_status: str  # 'FULLY_MATCHED', 'ACCEPTED_WITH_WARNINGS', 'DISCREPANCY_DETECTED'
    match_score: float
    is_safe_for_customs: bool
    matrix: List[Dict[str, Any]]
    critical_discrepancies: List[str]
    warning_discrepancies: List[str]
    compliance_summary_ar: str


# --- PHASE 6: ACID & IMPORTER LEGAL DOCS EXPIRY & ETA + 30 DAYS SAFETY MARGIN SCHEMAS ---
class LegalDocAlertItem(BaseModel):
    doc_type: str            # 'ACID Number', 'Import Card (بطاقة استيرادية)', 'Commercial Register (سجل تجاري)', 'Tax Card (بطاقة ضريبية)'
    doc_number: str
    expiry_date: Optional[date] = None
    days_until_expiry: int
    days_after_eta: Optional[int] = None
    is_expired: bool
    is_critical_breach: bool  # True if expires before ETA + 30 Days
    alert_message: str        # deprecated (Arabic only): render message_code + message_params instead
    status: str               # 'EXPIRED', 'CRITICAL_BREACH', 'EXPIRING_SOON', 'VALID'
    # C6 (additive): DOC_LEGAL_* code + {doc_kind, doc_number, expiry_date, eta_date, days}
    message_code: Optional[str] = None
    message_params: Optional[Dict[str, Any]] = None


class LegalDocsExpiryComplianceResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    company_name: str
    eta_date: Optional[date] = None
    eta_source: str           # 'Freight Booking', 'Cargo Shipping', 'Estimated'
    safety_window_date: Optional[date] = None # ETA + 30 Days
    has_critical_alerts: bool
    total_alerts_count: int
    alerts: List[LegalDocAlertItem]
    overall_compliance_status: str # 'COMPLIANT', 'CRITICAL_ACTION_REQUIRED', 'WARNING'
    persistent_banner_text: Optional[str] = None  # deprecated (Arabic only)
    # C6 (additive): DOC_LEGAL_BANNER + params for persistent_banner_text
    banner_message_code: Optional[str] = None
    banner_message_params: Optional[Dict[str, Any]] = None


# --- PHASE 6: COMMERCIAL INVOICE VS. BILL OF LADING SMART RECONCILIATION SCHEMAS ---
class InvoiceBLDiscrepancyMatrixItem(BaseModel):
    item_code: str
    field_name_ar: str
    field_name_en: str
    system_value: Optional[Any] = None
    invoice_value: Any
    packing_list_value: Optional[Any] = None
    bl_value: Any
    match_status: str  # 'MATCH', 'MISMATCH_MINOR', 'MISMATCH_CRITICAL', 'EXTRACTION_FAILED'
    severity: str      # 'NONE', 'WARNING', 'BLOCKING'
    tolerance: Optional[str] = None
    tolerance_code: Optional[str] = None
    tolerance_params: Optional[Dict[str, Any]] = None
    details: str  # English render of details_code (legacy rows: Arabic text, no code)
    details_code: Optional[str] = None
    details_params: Optional[Dict[str, Any]] = None
    # value key -> {"placeholder": VALUE_PLACEHOLDER code} | {"number": n, "unit": MEASURE_UNIT code}
    structured_values: Optional[Dict[str, Dict[str, Any]]] = None
    disagreeing_sources: Optional[List[str]] = None


class InvoiceBLExtractAndMatchRequest(BaseModel):
    import_file_id: Optional[int] = None
    invoice_raw_text: Optional[str] = None
    bl_raw_text: Optional[str] = None
    packing_list_raw_text: Optional[str] = None
    invoice_fields: Optional[Dict[str, Any]] = None
    bl_fields: Optional[Dict[str, Any]] = None
    packing_list_fields: Optional[Dict[str, Any]] = None


class InvoiceBLExtractAndMatchResponse(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    overall_status: str  # 'FULLY_MATCHED', 'ACCEPTED_WITH_WARNINGS', 'DISCREPANCY_DETECTED'
    is_safe_for_certification: bool
    match_score_percentage: float
    critical_discrepancies_count: int
    warning_discrepancies_count: int
    comparison_matrix: List[InvoiceBLDiscrepancyMatrixItem]
    correction_letter: Optional[str] = None
    invoice_data: Dict[str, Any]
    bl_data: Dict[str, Any]
    packing_list_data: Optional[Dict[str, Any]] = None



class POHeaderDiscrepancyItem(BaseModel):
    category: str
    check_code: str
    field_name_ar: str
    system_value: Any
    extracted_value: Any
    system_invoice_value: Optional[Any] = None
    system_packing_value: Optional[Any] = None
    uploaded_invoice_value: Optional[Any] = None
    uploaded_packing_value: Optional[Any] = None
    status: str  # 'MATCH', 'MINOR_VARIANCE', 'CRITICAL_VARIANCE'
    details: str  # English render of details_code (legacy rows: Arabic text, no code)
    details_code: Optional[str] = None
    details_params: Optional[Dict[str, Any]] = None
    # value key -> {"placeholder": VALUE_PLACEHOLDER code} | {"number": n, "unit": MEASURE_UNIT code}
    structured_values: Optional[Dict[str, Dict[str, Any]]] = None


class POExtractAndCompareRequest(BaseModel):
    import_file_id: Optional[int] = None
    invoice_raw_text: Optional[str] = None
    packing_list_raw_text: Optional[str] = None
    invoice_data: Optional[Dict[str, Any]] = None
    packing_data: Optional[Dict[str, Any]] = None
    system_items: Optional[List[Dict[str, Any]]] = None
    system_packing_items: Optional[List[Dict[str, Any]]] = None


class POExtractAndCompareResponse(BaseModel):
    import_file_id: Optional[int] = None
    overall_status: str  # 'FULLY_MATCHED', 'ACCEPTED_WITH_WARNINGS', 'CRITICAL_VARIANCE'
    is_safe_for_certification: bool
    critical_discrepancies_count: int
    warning_discrepancies_count: int
    header_discrepancies: List[POHeaderDiscrepancyItem]
    reconciled_invoice_items: List[POReconciliationItem]
    reconciled_packing_items: List[POReconciliationItem]
    extracted_invoice_data: Dict[str, Any]
    extracted_packing_data: Dict[str, Any]
    system_items_missing: bool = False


class InvoiceBLSyncRequest(BaseModel):
    import_file_id: int
    invoice_data: Optional[Dict[str, Any]] = None
    bl_data: Optional[Dict[str, Any]] = None
    sync_to_po: bool = True
    sync_to_shipping: bool = True
    notes: Optional[str] = None


class InvoiceBLMatchSessionBase(BaseModel):
    import_file_id: int
    import_file_code: Optional[str] = None
    invoice_number: Optional[str] = None
    bl_number: Optional[str] = None
    packing_list_number: Optional[str] = None
    acid_number: Optional[str] = None
    match_score_percentage: float = 0.0
    overall_status: str = "DRAFT_SAVED"
    is_safe_for_certification: bool = False
    is_draft: bool = False
    critical_discrepancies_count: int = 0
    warning_discrepancies_count: int = 0
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    invoice_data: Optional[Dict[str, Any]] = None
    bl_data: Optional[Dict[str, Any]] = None
    packing_list_data: Optional[Dict[str, Any]] = None
    correction_letter: Optional[str] = None
    notes: Optional[str] = None
    certified_by: Optional[str] = None


class InvoiceBLMatchSessionCreate(InvoiceBLMatchSessionBase):
    pass


class InvoiceBLMatchSessionUpdate(BaseModel):
    invoice_number: Optional[str] = None
    bl_number: Optional[str] = None
    packing_list_number: Optional[str] = None
    acid_number: Optional[str] = None
    match_score_percentage: Optional[float] = None
    overall_status: Optional[str] = None
    is_safe_for_certification: Optional[bool] = None
    is_draft: Optional[bool] = None
    critical_discrepancies_count: Optional[int] = None
    warning_discrepancies_count: Optional[int] = None
    comparison_matrix: Optional[List[Dict[str, Any]]] = None
    invoice_data: Optional[Dict[str, Any]] = None
    bl_data: Optional[Dict[str, Any]] = None
    packing_list_data: Optional[Dict[str, Any]] = None
    correction_letter: Optional[str] = None
    notes: Optional[str] = None
    certified_by: Optional[str] = None


class InvoiceBLMatchSessionResponse(InvoiceBLMatchSessionBase):
    session_id: int
    session_code: str
    import_file_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    currency_mismatch: Optional[bool] = None

    model_config = ConfigDict(from_attributes=True)


class POReconciliationSessionBase(BaseModel):
    import_file_id: int
    final_invoice_number: Optional[str] = None
    final_packing_list_number: Optional[str] = None
    acid_number: Optional[str] = None
    shipper_name: Optional[str] = None
    total_invoice_amount: float = 0.0
    currency: Optional[str] = None
    total_packages: float = 0.0
    total_net_weight_kg: float = 0.0
    total_gross_weight_kg: float = 0.0
    total_cbm: float = 0.0
    overall_status: str = "DRAFT"
    is_safe_for_certification: bool = False
    critical_discrepancies_count: int = 0
    warning_discrepancies_count: int = 0
    header_discrepancies: Optional[List[Dict[str, Any]]] = None
    reconciled_invoice_items: Optional[List[Dict[str, Any]]] = None
    reconciled_packing_items: Optional[List[Dict[str, Any]]] = None
    extracted_invoice_data: Optional[Dict[str, Any]] = None
    extracted_packing_data: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    certified_by: Optional[str] = None


class POReconciliationSessionCreate(POReconciliationSessionBase):
    currency: str = Field(..., min_length=3, max_length=3, description="3-letter active ISO currency code")


class POReconciliationSessionUpdate(BaseModel):
    final_invoice_number: Optional[str] = None
    final_packing_list_number: Optional[str] = None
    acid_number: Optional[str] = None
    shipper_name: Optional[str] = None
    total_invoice_amount: Optional[float] = None
    currency: Optional[str] = None
    total_packages: Optional[float] = None
    total_net_weight_kg: Optional[float] = None
    total_gross_weight_kg: Optional[float] = None
    total_cbm: Optional[float] = None
    overall_status: Optional[str] = None
    is_safe_for_certification: Optional[bool] = None
    critical_discrepancies_count: Optional[int] = None
    warning_discrepancies_count: Optional[int] = None
    header_discrepancies: Optional[List[Dict[str, Any]]] = None
    reconciled_invoice_items: Optional[List[Dict[str, Any]]] = None
    reconciled_packing_items: Optional[List[Dict[str, Any]]] = None
    extracted_invoice_data: Optional[Dict[str, Any]] = None
    extracted_packing_data: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    certified_by: Optional[str] = None


class POReconciliationSessionResponse(POReconciliationSessionBase):
    session_id: int
    session_code: str
    import_file_code: Optional[str] = None
    importer_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# CENTRAL SHIPMENT DOCUMENTS ARCHIVE & DISCREPANCIES SUMMARY SCHEMAS
# ==============================================================================

class CentralArchiveDocumentSummary(BaseModel):
    document_type: str
    title_ar: str
    is_available: bool = False
    is_mandatory: bool = True
    is_waived: bool = False
    waive_reason: Optional[str] = None
    legal_requirement_note: Optional[str] = None
    status: str = "NOT_STARTED"  # 'APPROVED', 'REVIEW_PENDING', 'MODIFICATIONS_REQUESTED', 'WAIVED', 'NOT_STARTED'
    document_reference: Optional[str] = None
    details: Dict[str, Any] = {}
    discrepancies: List[Dict[str, Any]] = []
    raw_content: Optional[str] = None
    last_updated: Optional[datetime] = None


class CentralArchiveResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    custom_file_number: Optional[str] = None
    importer_name: str
    supplier_name: str
    acid_number: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    total_packages: Optional[int] = None
    total_gross_weight_kg: Optional[float] = None
    currency: Optional[str] = None
    fob_or_cif_amount: Optional[float] = None
    readiness_status: str  # 'READY_FOR_RELEASE', 'ACTION_REQUIRED', 'IN_REVIEW'
    readiness_score: float  # 0.0 to 100.0

    final_invoice: CentralArchiveDocumentSummary
    final_packing_list: CentralArchiveDocumentSummary
    draft_bl: CentralArchiveDocumentSummary
    certificate_of_origin: CentralArchiveDocumentSummary
    inspection_certificate: CentralArchiveDocumentSummary

    # Import Requirements (BP-011) Integration
    import_requirements_summary: Optional[Dict[str, Any]] = None
    tariff_exemption_alert: Optional[str] = None
    goeic_inspection_alert: Optional[str] = None
    decree_43_alert: Optional[str] = None

    total_critical_discrepancies: int = 0
    total_warning_discrepancies: int = 0
    all_rectifications_checklist: List[Dict[str, Any]] = []
    supplier_email_rectification_text: str = ""
    supplier_whatsapp_rectification_text: str = ""


