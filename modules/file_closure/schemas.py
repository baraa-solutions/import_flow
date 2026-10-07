from typing import Optional, Dict, Any, List
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model

class ClosureChecklistSchema(BaseModel):
    """Client checklist: stored on drafts for the record only. It never gates the final close (the server
    evaluates the gate itself) and a missing key is unknown, never "done"."""
    docs_verified: Optional[bool] = None
    customs_cleared: Optional[bool] = None
    warehouse_received: Optional[bool] = None
    landed_cost_settled: Optional[bool] = None
    tasks_closed: Optional[bool] = None
    dossier_exported: Optional[bool] = None
    empty_containers_returned: Optional[bool] = None

class FileClosureCreate(BaseModel):
    import_file_id: int
    closure_checklist: ClosureChecklistSchema = Field(default_factory=ClosureChecklistSchema)
    auditor_name: Optional[str] = Field(None, description="Defaults to the signed-in user")
    archive_location: str = "Digital Archive Vault - 2026"
    archival_notes: Optional[str] = None
    is_draft: bool = False

class FileClosureUpdate(BaseModel):
    closure_checklist: Optional[ClosureChecklistSchema] = None
    auditor_name: Optional[str] = None
    archive_location: Optional[str] = None
    archival_notes: Optional[str] = None
    status: Optional[str] = None

@read_model
class FileClosureResponse(LegacyRowTolerantModel):
    closure_id: int
    closure_code: str
    import_file_id: int
    closure_checklist: Optional[Dict[str, Optional[bool]]] = Field(default_factory=dict)
    auditor_name: Optional[str] = "Internal Auditor"
    archive_location: Optional[str] = "Digital Archive Vault - 2026"
    archival_notes: Optional[str] = None
    status: Optional[str] = "Closed"
    is_active: bool = True
    closed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    created_by: Optional[str] = "System"
    updated_at: Optional[datetime] = None
    updated_by: Optional[str] = "System"

    model_config = ConfigDict(from_attributes=True)


# ============================================================
# CLO-03: Comprehensive Shipment Dossier Export Schemas
# ============================================================

class DossierSectionSummary(BaseModel):
    section_code: str
    section_name_en: str
    section_name_ar: str
    status: str  # COMPLETED, IN_PROGRESS, PENDING, NOT_APPLICABLE
    status_ar: str
    details: Dict[str, Any] = Field(default_factory=dict)


class ComprehensiveShipmentDossierResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    custom_file_number: Optional[str] = None
    status: str
    current_stage: str
    current_module: str
    progress_percent: float
    next_action: str
    owner: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    dossier_exported_at: Optional[datetime] = None
    dossier_exported_by: Optional[str] = None

    # Party information
    company_id: Optional[int] = None
    company_name: str
    supplier_id: Optional[int] = None
    supplier_name: str
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None

    # Cargo & Shipping Specifications
    shipment_mode: str
    incoterm_code: str
    shipment_category: str
    priority: str
    commodity: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    total_packages: int = 0
    gross_weight_kg: float = 0.0
    net_weight_kg: float = 0.0
    total_cbm: float = 0.0
    target_free_days: int = 0

    # Purchase Orders & FOB values
    purchase_orders: List[Dict[str, Any]] = Field(default_factory=list)
    total_fob_fc: float = 0.0
    total_fob_egp: Optional[float] = Field(None, description="null when no customs exchange rate is configured")
    fob_currency: str = "USD"
    items_count: int = 0
    items_detail: List[Dict[str, Any]] = Field(default_factory=list)

    # Official Documentation & Clearances
    acid_number: Optional[str] = None
    acid_issue_date: Optional[str] = None
    acid_expiry_date: Optional[str] = None
    form4_no: Optional[str] = None
    form4_date: Optional[str] = None
    swift_no: Optional[str] = None
    form46_no: Optional[str] = None
    form46_date: Optional[str] = None
    form46_status: Optional[str] = None
    cargox_envelope_id: Optional[str] = None
    cargox_transferred_at: Optional[str] = None

    # Customs Clearance
    customs_declaration_no: Optional[str] = None
    customs_channel: Optional[str] = None
    customs_office: Optional[str] = None
    customs_duty_amount: float = 0.0
    vat_amount: float = 0.0
    schedule_tax_amount: float = 0.0
    total_customs_paid: float = 0.0
    customs_release_permit_no: Optional[str] = None
    customs_released_at: Optional[str] = None

    # Transportation & Inbound
    inland_carrier_name: Optional[str] = None
    inland_truck_plate_no: Optional[str] = None
    inland_driver_name: Optional[str] = None
    inland_actual_arrival_date: Optional[str] = None
    warehouse_grn_code: Optional[str] = None
    warehouse_name: Optional[str] = None
    warehouse_accepted_qty: int = 0
    warehouse_shortage_qty: int = 0
    warehouse_damaged_qty: int = 0
    empty_containers_returned_at: Optional[str] = None
    empty_containers_eir_numbers: Optional[str] = None

    # Financial Settlement & Actual Landed Cost Breakdown
    financial_settlement_status: Optional[str] = None
    financial_settlement_invoices_count: int = 0
    financial_settlement_total_egp: float = 0.0
    actual_landed_cost_total_egp: float = 0.0
    actual_landed_cost_markup_factor: float = 1.0
    actual_landed_cost_variance_egp: float = 0.0
    actual_landed_cost_variance_pct: float = 0.0
    actual_landed_cost_calculated_at: Optional[datetime] = None

    # Structured 10-Phase Sections Dossier
    sections: List[DossierSectionSummary] = Field(default_factory=list)
    closure_readiness: Dict[str, bool] = Field(default_factory=dict)
    summary_notes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class DossierExportConfirmRequest(BaseModel):
    import_file_id: int
    exported_by: Optional[str] = Field(None, description="Defaults to the signed-in user")
    export_format: str = Field("PDF & Excel Full Bundle", description="Exported format e.g. PDF, Excel, Full Bundle")
    notes: Optional[str] = None


class DossierExportConfirmResponse(BaseModel):
    success: bool
    import_file_id: int
    import_file_code: str
    dossier_exported_at: datetime
    dossier_exported_by: str
    progress_percent: float
    current_stage: str
    current_module: str
    next_task_code: str
    next_task_title: str
    message: str


# ============================================================
# CLO-04: Official File Closure & Digital Archive Schemas
# ============================================================

class ClosurePrecheckResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    company_name: str
    supplier_name: str
    can_close: bool
    blocking_reasons: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    checklist_status: Dict[str, bool] = Field(default_factory=dict)
    actual_landed_cost_egp: float = 0.0
    actual_markup_factor: float = 1.0
    dossier_exported_at: Optional[datetime] = None
    dossier_exported_by: Optional[str] = None
    empty_containers_returned_at: Optional[datetime] = None
    certificate_code_preview: str


class OfficialClosureCertificateResponse(BaseModel):
    success: bool
    closure_id: int
    closure_code: str
    import_file_id: int
    import_file_code: str
    company_name: str
    supplier_name: str
    auditor_name: str
    archive_location: str
    archival_notes: Optional[str] = None
    closed_at: datetime
    status: str
    progress_percent: float
    current_stage: str
    current_module: str
    next_action: str
    message: str

    model_config = ConfigDict(from_attributes=True)

