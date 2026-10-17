"""
Pydantic Schemas for Docs Customs Approval Hub (DCA-001)
"""

from typing import Optional, List, Any, Dict
from datetime import datetime, date
from pydantic import BaseModel, ConfigDict, Field, field_validator

from modules.docs_customs_approval.validators import SESSION_STATUS_VALUES


# --- Discrepancy Ticket Schemas ---

class DiscrepancyTicketBase(BaseModel):
    import_file_id: int
    approval_id: Optional[int] = None
    issue_category: str = Field(..., description="HS Code Mismatch, Weight Discrepancy, CBM Discrepancy, Value Mismatch, Missing ACID, Incoterm Conflict, Other")
    severity: str = Field("Major", description="Critical, Major, Minor")
    description: str
    expected_value: Optional[str] = None
    found_value: Optional[str] = None
    supplier_action_required: Optional[str] = None


class DiscrepancyTicketCreate(DiscrepancyTicketBase):
    pass


class DiscrepancyTicketUpdate(BaseModel):
    issue_category: Optional[str] = None
    severity: Optional[str] = None
    description: Optional[str] = None
    expected_value: Optional[str] = None
    found_value: Optional[str] = None
    supplier_action_required: Optional[str] = None
    supplier_response: Optional[str] = None
    status: Optional[str] = None


class DiscrepancyTicketResolve(BaseModel):
    supplier_response: str
    resolved_by: Optional[str] = Field(None, description="Ignored: the server records the logged-in user (DCA-03)")
    new_status: str = "Resolved"  # Resolved, Waived, Closed


class DiscrepancyTicketResponse(BaseModel):
    ticket_id: int
    ticket_code: str
    approval_id: Optional[int] = None
    import_file_id: int
    import_file_code: Optional[str] = None
    issue_category: str
    severity: str
    description: str
    expected_value: Optional[str] = None
    found_value: Optional[str] = None
    supplier_action_required: Optional[str] = None
    supplier_response: Optional[str] = None
    status: str
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- Customs Document Approval Schemas ---

class CustomsDocumentApprovalBase(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    document_type: str = Field(..., description="Commercial Invoice, Packing List, Bill of Lading, Certificate of Origin, EUR.1, Inspection Cert, Form 4")
    document_reference_no: Optional[str] = None
    document_date: Optional[date] = None


class CustomsDocumentApprovalCreate(CustomsDocumentApprovalBase):
    pass


class CustomsDocumentApprovalUpdate(BaseModel):
    document_reference_no: Optional[str] = None
    document_date: Optional[date] = None
    # Ignored (DCA-03): review statuses change only through the commercial-review / customs-review endpoints.
    commercial_status: Optional[str] = Field(None, description="Ignored: use POST /{id}/commercial-review")
    commercial_notes: Optional[str] = None
    customs_status: Optional[str] = Field(None, description="Ignored: use POST /{id}/customs-review")
    customs_broker_name: Optional[str] = None
    customs_notes: Optional[str] = None
    overall_status: Optional[str] = Field(None, description="Ignored: derived from the two review tiers")
    version: Optional[int] = Field(None, description="Current record version for optimistic concurrency control")


class CommercialReviewPayload(BaseModel):
    reviewer_name: Optional[str] = Field(None, description="Ignored: the server records the logged-in user (DCA-03)")
    status: str = Field(..., description="Approved, Rejected, Under Review")
    notes: Optional[str] = None
    version: Optional[int] = Field(None, description="Current record version for optimistic concurrency control")


class CustomsBrokerReviewPayload(BaseModel):
    broker_name: str
    reviewer_name: Optional[str] = Field(None, description="Ignored: the server records the logged-in user (DCA-03)")
    status: str = Field(..., description="Approved, Rejected, Conditionally Approved")
    notes: Optional[str] = None
    version: Optional[int] = Field(None, description="Current record version for optimistic concurrency control")


class CustomsDocumentApprovalResponse(BaseModel):
    approval_id: int
    approval_code: str
    version: int = 1
    import_file_id: int
    import_file_code: Optional[str] = None
    po_id: Optional[int] = None
    document_type: str
    document_reference_no: Optional[str] = None
    document_date: Optional[date] = None

    commercial_status: str
    commercial_reviewed_by: Optional[str] = None
    commercial_reviewed_at: Optional[datetime] = None
    commercial_notes: Optional[str] = None

    customs_status: str
    customs_reviewed_by: Optional[str] = None
    customs_reviewed_at: Optional[datetime] = None
    customs_broker_name: Optional[str] = None
    customs_notes: Optional[str] = None

    overall_status: str
    cross_check_summary: Optional[Dict[str, Any]] = None

    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- Cross-Document Matrix Audit Schemas ---

class MatrixCheckItem(BaseModel):
    parameter: str
    status: str  # Match, Mismatch, Warning, Missing, Not Checked (a source is missing: neither passed nor failed)
    invoice_val: Optional[str] = None
    bl_val: Optional[str] = None
    packing_val: Optional[str] = None
    coo_val: Optional[str] = None
    acid_val: Optional[str] = None
    notes: Optional[str] = None


class CrossDocumentMatrixCheckResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    overall_compliance: str  # Fully Compliant, Discrepancies Found, Critical Blocker
    total_checks: int
    passed_checks: int
    failed_checks: int
    not_checked_checks: int = 0
    checks: List[MatrixCheckItem]
    recommendations: List[str]
    open_tickets_count: int
    missing_documents: List[str] = Field(default_factory=list)
    completeness_percent: float = 0.0


# --- Docs Customs Approval Session Schemas (STEP-09) ---

class DocsCustomsApprovalSessionBase(BaseModel):
    import_file_id: int
    po_id: Optional[int] = None
    overall_status: str = "DRAFT"
    is_draft: bool = False

    final_invoice_ref: Optional[str] = None
    final_invoice_status: str = "Approved"

    final_pl_ref: Optional[str] = None
    final_pl_status: str = "Approved"

    draft_bl_ref: Optional[str] = None
    draft_bl_status: str = "Approved"

    coo_ref: Optional[str] = None
    coo_status: str = "Approved"

    coc_ref: Optional[str] = None
    coc_status: str = "Waived / Not Required"

    @field_validator(
        "final_invoice_status",
        "final_pl_status",
        "draft_bl_status",
        "coo_status",
        "coc_status",
        mode="before",
    )
    @classmethod
    def validate_session_status(cls, v: Any) -> Any:
        if v is not None and v not in SESSION_STATUS_VALUES:
            raise ValueError(
                f"Invalid session status: '{v}'. Allowed values: {', '.join(sorted(SESSION_STATUS_VALUES))}."
            )
        return v


    commercial_signoff_by: Optional[str] = None
    commercial_signoff_date: Optional[date] = None
    customs_signoff_by: Optional[str] = None
    customs_signoff_date: Optional[date] = None
    customs_broker_name: Optional[str] = None

    discrepancies_count: int = 0
    open_tickets_count: int = 0

    session_snapshot: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    # Ignored on requests (DCA-03): created_by / *_signoff_by come from the logged-in user.
    created_by: Optional[str] = "ADMIN"


class DocsCustomsApprovalSessionCreate(DocsCustomsApprovalSessionBase):
    pass


class DocsCustomsApprovalSessionUpdate(BaseModel):
    overall_status: Optional[str] = None
    is_draft: Optional[bool] = None
    final_invoice_ref: Optional[str] = None
    final_invoice_status: Optional[str] = None
    final_pl_ref: Optional[str] = None
    final_pl_status: Optional[str] = None
    draft_bl_ref: Optional[str] = None
    draft_bl_status: Optional[str] = None
    coo_ref: Optional[str] = None
    coo_status: Optional[str] = None
    coc_ref: Optional[str] = None
    coc_status: Optional[str] = None
    commercial_signoff_by: Optional[str] = None
    commercial_signoff_date: Optional[date] = None
    customs_signoff_by: Optional[str] = None
    customs_signoff_date: Optional[date] = None
    customs_broker_name: Optional[str] = None
    discrepancies_count: Optional[int] = None
    open_tickets_count: Optional[int] = None
    session_snapshot: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    version: Optional[int] = Field(None, description="Current record version for concurrency check")


class DocsCustomsApprovalSessionResponse(DocsCustomsApprovalSessionBase):
    session_id: int
    session_code: str
    version: int = 1
    import_file_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

