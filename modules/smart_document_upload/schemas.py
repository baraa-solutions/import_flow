"""
Smart Document Upload — Pydantic Schemas
Request & Response schemas for every supported module.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ─────────────────────────────────────────────────────────────────────────────
# Supported module names (used as URL path segment)
# ─────────────────────────────────────────────────────────────────────────────

SUPPORTED_MODULES = {
    "purchase-order",
    "import-file",
    "cargo-shipping",
    "customs-clearance",
    "freight-quotation",
    "freight-booking",
    "clearance-quotation",
    "customs-broker-quotation",
    "customs-consultation",
    "warehouse-receiving",
    "demurrage",
    "financial-document",
    "commercial-invoice",
    "commercial_invoice",
    "packing-list",
    "packing_list",
    "coo-certificate",
    "inspection-certificate",
}


# ─────────────────────────────────────────────────────────────────────────────
# Generic extraction response
# ─────────────────────────────────────────────────────────────────────────────

class SmartUploadResponse(BaseModel):
    """Universal response returned by every smart-upload parse endpoint."""
    session_id: Optional[int] = None
    session_ref: Optional[str] = None
    module_name: str
    filename: str
    file_type: str
    file_size_bytes: Optional[int] = None
    extraction_status: str               # SUCCESS | PARTIAL | FAILED
    confidence_score: float = 0.0        # 0.0 – 1.0
    extracted_fields: Dict[str, Any] = Field(default_factory=dict)
    missing_fields: List[str] = Field(default_factory=list)
    extraction_notes: Optional[str] = None
    raw_text_preview: Optional[str] = None  # First 500 chars of extracted text (debug)

    # ── Entity Verification Results ─────────────────────────────────────────
    # Indicates whether supplier_name / importer_name extracted from the document
    # were matched against existing records in the database.
    supplier_verified: Optional[bool] = None   # True=found, False=not found, None=not applicable
    supplier_id: Optional[int] = None          # DB supplier_id if matched
    supplier_code: Optional[str] = None        # Business code if matched (e.g. SUP-000001)
    importer_verified: Optional[bool] = None   # True=found, False=not found, None=not applicable
    importer_id: Optional[int] = None          # DB company_id if matched
    importer_code: Optional[str] = None        # Business importer_id code if matched

    # ── AI Quotation & Completeness Validation Layer (AI-EXTRACT-VALIDATE-001)
    validation_report: Optional[Dict[str, Any]] = None


# ─────────────────────────────────────────────────────────────────────────────
# Upload Session list/detail
# ─────────────────────────────────────────────────────────────────────────────

class UploadSessionResponse(BaseModel):
    id: int
    session_ref: str
    module_name: str
    filename: str
    file_type: Optional[str]
    file_size_bytes: Optional[int]
    extraction_status: str
    confidence_score: float
    extracted_fields: Dict[str, Any] = Field(default_factory=dict)
    missing_fields: List[str] = Field(default_factory=list)
    extraction_notes: Optional[str]
    linked_record_id: Optional[int]
    linked_module: Optional[str]
    created_at: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)

    @classmethod
    def from_model(cls, s: Any) -> "UploadSessionResponse":
        return cls(
            id=s.id,
            session_ref=s.session_ref,
            module_name=s.module_name,
            filename=s.filename,
            file_type=s.file_type,
            file_size_bytes=s.file_size_bytes,
            extraction_status=s.extraction_status,
            confidence_score=s.confidence_score or 0.0,
            extracted_fields=s.get_extracted_fields(),
            missing_fields=s.get_missing_fields(),
            extraction_notes=s.extraction_notes,
            linked_record_id=s.linked_record_id,
            linked_module=s.linked_module,
            created_at=s.created_at,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Per-module extracted field schemas (for type safety in Flutter)
# ─────────────────────────────────────────────────────────────────────────────

class POLineItemExtracted(BaseModel):
    description: Optional[str] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None
    unit_price: Optional[float] = None
    total_price: Optional[float] = None
    hs_code: Optional[str] = None


class PurchaseOrderExtracted(BaseModel):
    po_number: Optional[str] = None
    supplier_name: Optional[str] = None
    order_date: Optional[str] = None
    currency: Optional[str] = None
    incoterms: Optional[str] = None
    delivery_port: Optional[str] = None
    payment_terms: Optional[str] = None
    total_amount: Optional[float] = None
    items: List[POLineItemExtracted] = Field(default_factory=list)


class ContainerExtracted(BaseModel):
    container_no: Optional[str] = None
    seal_no: Optional[str] = None
    container_type: Optional[str] = None
    gross_weight_kg: Optional[float] = None
    cbm: Optional[float] = None


class CargoShippingExtracted(BaseModel):
    bl_number: Optional[str] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    carrier_name: Optional[str] = None
    loading_port: Optional[str] = None
    discharge_port: Optional[str] = None
    etd: Optional[str] = None
    eta: Optional[str] = None
    total_gross_weight_kg: Optional[float] = None
    total_cbm: Optional[float] = None
    containers: List[ContainerExtracted] = Field(default_factory=list)
    shipper: Optional[str] = None
    consignee: Optional[str] = None


class CustomsClearanceExtracted(BaseModel):
    declaration_no: Optional[str] = None
    declaration_date: Optional[str] = None
    hs_code: Optional[str] = None
    commodity_description: Optional[str] = None
    origin_country: Optional[str] = None
    customs_value_egp: Optional[float] = None
    exchange_rate: Optional[float] = None
    import_duty: Optional[float] = None
    vat_amount: Optional[float] = None
    schedule_tax: Optional[float] = None
    other_fees: Optional[float] = None
    total_taxes: Optional[float] = None


class ImportFileExtracted(BaseModel):
    commodity_description: Optional[str] = None
    hs_code: Optional[str] = None
    origin_country: Optional[str] = None
    loading_port: Optional[str] = None
    discharge_port: Optional[str] = None
    incoterms: Optional[str] = None
    currency: Optional[str] = None
    invoice_value: Optional[float] = None
    supplier_name: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_date: Optional[str] = None


class FreightQuotationExtracted(BaseModel):
    carrier_name: Optional[str] = None
    origin_port: Optional[str] = None
    destination_port: Optional[str] = None
    freight_rate: Optional[float] = None
    currency: Optional[str] = None
    transit_days: Optional[int] = None
    validity_date: Optional[str] = None
    container_type: Optional[str] = None
    free_days_demurrage: Optional[int] = None
    free_days_detention: Optional[int] = None


class FreightBookingExtracted(BaseModel):
    booking_number: Optional[str] = None
    carrier_name: Optional[str] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    loading_port: Optional[str] = None
    discharge_port: Optional[str] = None
    etd: Optional[str] = None
    eta: Optional[str] = None
    si_cutoff: Optional[str] = None
    vgm_cutoff: Optional[str] = None
    container_type: Optional[str] = None
    containers_count: Optional[int] = None


class COOCertificateExtracted(BaseModel):
    certificate_number: Optional[str] = None
    issue_date: Optional[str] = None
    origin_country: Optional[str] = None
    exporter_name: Optional[str] = None
    consignee_name: Optional[str] = None
    product_description: Optional[str] = None
    hs_code: Optional[str] = None
    gross_weight: Optional[str] = None
    invoice_number: Optional[str] = None


class InspectionCertificateExtracted(BaseModel):
    certificate_number: Optional[str] = None
    inspection_date: Optional[str] = None
    inspector_name: Optional[str] = None
    inspection_company: Optional[str] = None
    product_description: Optional[str] = None
    quantity_inspected: Optional[str] = None
    result: Optional[str] = None          # PASS | FAIL | CONDITIONAL
    defects_found: Optional[str] = None
    remarks: Optional[str] = None


class FinancialDocumentExtracted(BaseModel):
    invoice_number: Optional[str] = None
    invoice_date: Optional[str] = None
    supplier_name: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None
    payment_terms: Optional[str] = None
    bank_name: Optional[str] = None
    swift_code: Optional[str] = None
    iban: Optional[str] = None
    due_date: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# Typed request bodies: cross-check and apply (SDU-01 / SDU-04). Same keys as the former raw dicts; extra keys
# coming from the extraction output are ignored.
# ─────────────────────────────────────────────────────────────────────────────

class CrossCheckRequest(BaseModel):
    invoice_data: Optional[Dict[str, Any]] = None
    bl_data: Optional[Dict[str, Any]] = None
    system_data: Optional[Dict[str, Any]] = None
    packing_list_data: Optional[Dict[str, Any]] = None
    weight_tolerance_pct: float = Field(3.0, ge=0, le=20)


class InvoiceApplyData(BaseModel):
    model_config = ConfigDict(extra="ignore")

    invoice_number: Optional[str] = Field(None, max_length=100)
    invoice_date: Optional[str] = Field(None, max_length=30)
    acid_number: Optional[str] = None
    importer_tax_id: Optional[str] = None
    supplier_name: Optional[str] = None
    importer_name: Optional[str] = None
    origin_country: Optional[str] = None
    hs_code: Optional[str] = None
    is_preferential_origin: Optional[bool] = False
    preferential_origin_agreement: Optional[str] = None
    is_free_of_charge: Optional[bool] = False
    incoterms: Optional[str] = None
    loading_port: Optional[str] = Field(None, max_length=100)
    discharge_port: Optional[str] = Field(None, max_length=100)
    invoice_value: Optional[float] = Field(None, gt=0)
    freight_amount: Optional[float] = None
    currency: Optional[str] = None
    total_gross_weight_kg: Optional[float] = None
    total_net_weight_kg: Optional[float] = None
    pallets_count: Optional[int] = None
    packages_count: Optional[int] = None
    container_number: Optional[str] = None
    seal_number: Optional[str] = None
    purchase_order: Optional[str] = None
    items: List[Dict[str, Any]] = Field(default_factory=list)

    @field_validator("invoice_value", mode="before")
    @classmethod
    def _no_total_is_none(cls, value: Any) -> Any:
        """The invoice extractor returns 0.0 when it finds no total: 0 / "" / None mean "not extracted"
        (the file keeps its value), only a real amount must be > 0."""
        if value is None:
            return None
        if isinstance(value, str):
            text = value.strip().replace(",", "")
            if not text:
                return None
            try:
                return None if float(text) == 0 else value
            except ValueError:
                return value  # non-numeric -> 422 from the float field
        if isinstance(value, (int, float)) and not isinstance(value, bool) and value == 0:
            return None
        return value


class ApplyInvoiceRequest(BaseModel):
    import_file_id: Optional[int] = None
    invoice_data: InvoiceApplyData = Field(default_factory=InvoiceApplyData)


class ContainerApplyItem(BaseModel):
    model_config = ConfigDict(extra="ignore")

    container_no: Optional[str] = Field(None, max_length=30)
    seal_no: Optional[str] = Field(None, max_length=50)
    container_type: Optional[str] = Field(None, max_length=20)
    gross_weight_kg: Optional[float] = Field(None, ge=0)
    cbm: Optional[float] = Field(None, ge=0)


class BLApplyData(BaseModel):
    model_config = ConfigDict(extra="ignore")

    containers: List[ContainerApplyItem] = Field(default_factory=list)


class ApplyBLRequest(BaseModel):
    import_file_id: Optional[int] = None
    bl_data: BLApplyData = Field(default_factory=BLApplyData)
