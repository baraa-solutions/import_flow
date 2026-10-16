from datetime import datetime, date
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field


class CourierEntry(BaseModel):
    courier_no: str = Field(..., description="Courier Air Waybill / Tracking Number (e.g. DHL-981245)")
    courier_company: Optional[str] = Field(None, description="Courier Service Provider (DHL, FedEx, Aramex, UPS, Naqel, etc.)")
    dispatch_date: Optional[str] = Field(None, description="Courier dispatch date (YYYY-MM-DD)")
    is_received: bool = Field(False, description="Whether courier envelope package is physically delivered")
    received_date: Optional[str] = Field(None, description="Physical delivery / reception date (YYYY-MM-DD)")
    received_time: Optional[str] = Field(None, description="Physical delivery time (HH:MM)")
    received_by: Optional[str] = Field(None, description="Staff member who received the courier envelope")
    tracking_url: Optional[str] = Field(None, description="Direct web link to carrier live tracking")
    pod_reference: Optional[str] = Field(None, description="Proof of delivery reference / receipt waybill number")
    status: Optional[str] = Field("DISPATCHED", description="Courier status: DISPATCHED, IN_TRANSIT, DELIVERED, DELAYED")
    notes: Optional[str] = Field(None, description="Courier specific notes")


class CourierReceiptProofRequest(BaseModel):
    import_file_id: int = Field(..., description="Target Import File ID")
    courier_no: str = Field(..., description="Courier Tracking / AWB Number to confirm")
    received_date: str = Field(..., description="Actual receipt date (YYYY-MM-DD)")
    received_time: Optional[str] = Field(None, description="Actual receipt time (HH:MM)")
    received_by: str = Field(..., description="Staff member / archive specialist confirming delivery receipt")
    pod_reference: Optional[str] = Field(None, description="Proof of delivery code / waybill acknowledgment")
    notes: Optional[str] = Field(None, description="Delivery or package condition notes")
    mark_documents_received: bool = Field(True, description="Whether to auto-mark all documents associated with this courier as physically received")


class CourierAlertItem(BaseModel):
    courier_no: str
    courier_company: Optional[str] = None
    import_file_id: int
    import_file_code: str
    acid_number: Optional[str] = None
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    dispatch_date: Optional[str] = None
    days_in_transit: int = 0
    alert_level: str = "INFO"  # 'INFO', 'WARNING', 'CRITICAL'
    alert_message_ar: str
    alert_message_en: str


class CourierAlertsResponse(BaseModel):
    total_active_couriers: int = 0
    pending_receipt_count: int = 0
    delayed_count: int = 0
    delivered_count: int = 0
    alerts: List[CourierAlertItem] = Field(default_factory=list)


class CourierFlatItemResponse(BaseModel):
    courier_no: str
    courier_company: Optional[str] = None
    import_file_id: int
    import_file_code: str
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    dispatch_date: Optional[str] = None
    is_received: bool = False
    received_date: Optional[str] = None
    received_time: Optional[str] = None
    received_by: Optional[str] = None
    tracking_url: Optional[str] = None
    pod_reference: Optional[str] = None
    status: str = "IN_TRANSIT"
    days_in_transit: int = 0
    associated_docs_count: int = 0
    notes: Optional[str] = None


class OriginalDocumentItem(BaseModel):
    category: str = Field("Commercial", description="Document category: Commercial, Certificate, Shipping, Egypt Import, Banking, Regulatory, Other")
    document_name: str = Field(..., description="Document Name (e.g. Commercial Invoice, Packing List, Certificate of Origin, etc.)")
    is_required: str = Field("Yes", description="'Yes', 'No', 'Conditional'")
    responsible_party: str = Field("Supplier", description="Responsible party: 'Supplier', 'Freight Forwarder', 'Inspection Agency', 'Bank', 'Importer'")
    courier_no: Optional[str] = Field(None, description="Assigned Courier Tracking / AWB Number")
    is_received: bool = Field(False, description="Physical hard-copy document received")
    received_date: Optional[str] = Field(None, description="Document receipt date (YYYY-MM-DD)")
    is_verified: bool = Field(False, description="Physical hard-copy verified & matched against electronic archive")
    verified_by: Optional[str] = Field(None, description="Auditor / customs specialist who verified the original document")
    verification_date: Optional[str] = Field(None, description="Document verification date (YYYY-MM-DD)")
    status: str = Field("Pending", description="'Pending', 'In Transit', 'Received', 'Verified', 'Discrepant', 'Not Required'")
    remarks: Optional[str] = Field(None, description="Specific notes or discrepancy remarks")


class OriginalDocumentsCollectionBase(BaseModel):
    import_file_id: int
    import_file_code: str
    acid_number: Optional[str] = None
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    status: str = "DRAFT"
    couriers_list: List[CourierEntry] = Field(default_factory=list)
    documents_list: List[OriginalDocumentItem] = Field(default_factory=list)
    discrepancy_override_reason: Optional[str] = None
    notes: Optional[str] = None


class OriginalDocumentsCollectionCreate(OriginalDocumentsCollectionBase):
    pass


class OriginalDocumentsCollectionUpdate(BaseModel):
    status: Optional[str] = None
    couriers_list: Optional[List[CourierEntry]] = None
    documents_list: Optional[List[OriginalDocumentItem]] = None
    discrepancy_override_reason: Optional[str] = None
    notes: Optional[str] = None


class OriginalDocumentsCollectionResponse(OriginalDocumentsCollectionBase):
    collection_id: int
    collection_code: str
    total_documents_count: int = 0
    received_documents_count: int = 0
    verified_documents_count: int = 0
    pending_documents_count: int = 0
    completion_percentage: float = 0.0
    is_active: bool = True
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


class OriginalDocumentsAutoPopulateResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    acid_number: Optional[str] = None
    importer_name: Optional[str] = None
    supplier_name: Optional[str] = None
    default_couriers: List[CourierEntry] = Field(default_factory=list)
    required_documents: List[OriginalDocumentItem] = Field(default_factory=list)
    existing_session: Optional[OriginalDocumentsCollectionResponse] = None
