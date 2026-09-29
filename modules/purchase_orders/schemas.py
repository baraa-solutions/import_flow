from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict


class POLineItemBase(BaseModel):
    item_code: Optional[str] = Field(None, max_length=50)
    main_description: Optional[str] = Field(None, max_length=250, description="الوصف الرئيسي للصنف / Main Description")
    description_ar: str = Field(..., min_length=2, max_length=250)
    description_en: Optional[str] = Field(None, max_length=250)
    country_of_origin: Optional[str] = Field(None, max_length=100, description="بلد المنشأ للصنف")
    tariff_id: Optional[int] = None
    quantity: float = Field(1.0, gt=0)
    unit_of_measure: str = Field("PCS", max_length=30)
    unit_price: float = Field(0.0, ge=0)
    cbm_per_unit: float = Field(0.0, ge=0)
    gross_weight_kg: float = Field(0.0, ge=0)
    net_weight_kg: float = Field(0.0, ge=0)


class POLineItemCreate(POLineItemBase):
    pass


class POLineItemResponse(POLineItemBase):
    item_id: int
    po_id: int
    total_price: float
    total_cbm: float
    created_at: datetime
    hs_code: Optional[str] = None
    duty_rate: Optional[float] = None
    vat_rate: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# BP-003 Packing List Schemas
# ==================================================

class PackingListItemBase(BaseModel):
    hs_code: str = Field(..., min_length=2, max_length=50)
    item_code: str = Field(..., min_length=1, max_length=50)
    main_description: Optional[str] = Field(None, max_length=250, description="Main description of product / الوصف الرئيسي")
    description: Optional[str] = Field(None, max_length=250, description="Product description in packing list")
    qty_pcs: float = Field(1.0, gt=0)
    qty_pkg: float = Field(1.0, gt=0)
    package_type: Optional[str] = Field("Carton", max_length=50)
    unit: Optional[str] = Field("cm", max_length=10)
    length_cm: Optional[float] = Field(0.0, ge=0)
    width_cm: Optional[float] = Field(0.0, ge=0)
    height_cm: Optional[float] = Field(0.0, ge=0)
    net_weight_unit_kg: float = Field(0.0, ge=0)
    gross_weight_unit_kg: float = Field(0.0, ge=0)
    weight_unit: Optional[str] = Field("KGM", max_length=30, description="Weight Unit of Measure e.g. KGM, GRM, TON, STN")
    is_stackable: bool = Field(True, description="Stackable vs Non-stackable cargo instruction")
    total_cbm: Optional[float] = Field(0.0, ge=0, description="CBM volume either calculated or directly entered")
    total_net_weight_kg: Optional[float] = Field(0.0, ge=0)
    total_gross_weight_kg: Optional[float] = Field(0.0, ge=0)


class PackingListItemCreate(PackingListItemBase):
    pass


class PackingListItemResponse(PackingListItemBase):
    packing_item_id: int
    po_id: int
    total_net_weight_kg: float
    total_gross_weight_kg: float
    total_cbm: float
    chargeable_weight_kg: float
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PackingListSummaryByHSCode(BaseModel):
    hs_code: str
    qty_pcs: float
    qty_pkg: float
    total_net_weight_kg: float
    total_gross_weight_kg: float
    total_cbm: float
    invoice_pcs: float = 0.0
    discrepancy_pcs: float = 0.0
    is_matched: bool = True


class PackingListValidationReport(BaseModel):
    is_valid: bool
    has_discrepancy: bool = False
    errors: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    total_items: int = 0
    total_pcs: float = 0.0
    total_pkg: float = 0.0
    total_net_weight_kg: float = 0.0
    total_gross_weight_kg: float = 0.0
    total_cbm: float = 0.0
    chargeable_weight_kg: float = 0.0
    total_invoice_pcs: float = 0.0
    total_packing_pcs: float = 0.0
    missing_hs_in_packing: List[str] = Field(default_factory=list)
    missing_hs_in_invoice: List[str] = Field(default_factory=list)
    hs_code_summary: List[PackingListSummaryByHSCode] = Field(default_factory=list)


class PalletPlanItem(BaseModel):
    pallet_type: str = Field("Euro Pallet (120x80)", max_length=100)
    pallet_count: int = Field(1, ge=1)
    length_cm: float = Field(120.0, ge=0)
    width_cm: float = Field(80.0, ge=0)
    height_cm: float = Field(150.0, ge=0)
    gross_weight_per_pallet_kg: float = Field(0.0, ge=0)
    is_stackable: bool = Field(False)
    notes: Optional[str] = None


# ==================================================
# Purchase Order Schemas
# ==================================================

class PurchaseOrderBase(BaseModel):
    import_file_id: Optional[int] = None
    po_reference: Optional[str] = Field(None, max_length=200, description="اسم أو مرجع أمر الشراء")
    proforma_invoice_number: Optional[str] = Field(None, max_length=100)
    country_of_origin: Optional[str] = Field(None, max_length=100, description="بلد المنشأ لأمر التوريد")
    project_id: int
    company_id: int
    supplier_id: int
    incoterm_id: int
    currency_id: int
    order_date: Optional[datetime] = Field(None, description="Invoice Date / تاريخ الفاتورة")
    expected_delivery_date: Optional[datetime] = None
    exchange_rate: float = Field(1.0, gt=0)
    payment_terms: Optional[str] = Field("LC at Sight", max_length=100)
    notes: Optional[str] = None
    pallet_count: Optional[int] = Field(0, ge=0, description="عدد البالتات الكلي")
    pallet_type: Optional[str] = Field("Euro Pallet (120x80)", max_length=100)
    is_pallet_stackable: Optional[bool] = Field(False, description="تعليمات رص البالتات")
    pallet_length_cm: Optional[float] = Field(120.0, ge=0)
    pallet_width_cm: Optional[float] = Field(80.0, ge=0)
    pallet_height_cm: Optional[float] = Field(150.0, ge=0)
    pallet_plan: Optional[List[PalletPlanItem]] = Field(default_factory=list)


class PurchaseOrderCreate(PurchaseOrderBase):
    po_number: Optional[str] = Field(None, max_length=50, description="Auto-generated if empty (PO-YYYY-XXX)")
    items: List[POLineItemCreate] = Field(default_factory=list)
    packing_list_items: List[PackingListItemCreate] = Field(default_factory=list)


class PurchaseOrderUpdate(BaseModel):
    import_file_id: Optional[int] = None
    po_reference: Optional[str] = Field(None, max_length=200, description="اسم أو مرجع أمر الشراء")
    proforma_invoice_number: Optional[str] = Field(None, max_length=100)
    country_of_origin: Optional[str] = Field(None, max_length=100)
    project_id: Optional[int] = None
    company_id: Optional[int] = None
    supplier_id: Optional[int] = None
    incoterm_id: Optional[int] = None
    currency_id: Optional[int] = None
    order_date: Optional[datetime] = None
    expected_delivery_date: Optional[datetime] = None
    exchange_rate: Optional[float] = Field(None, gt=0)
    payment_terms: Optional[str] = Field(None, max_length=100)
    status: Optional[str] = Field(None, max_length=50) # Draft, Approved, In Transit, Closed, Cancelled
    notes: Optional[str] = None
    pallet_count: Optional[int] = Field(None, ge=0)
    pallet_type: Optional[str] = Field(None, max_length=100)
    is_pallet_stackable: Optional[bool] = None
    pallet_length_cm: Optional[float] = Field(None, ge=0)
    pallet_width_cm: Optional[float] = Field(None, ge=0)
    pallet_height_cm: Optional[float] = Field(None, ge=0)
    pallet_plan: Optional[List[PalletPlanItem]] = None
    is_active: Optional[bool] = None
    version: Optional[int] = Field(None, description="Current version of the record for optimistic concurrency control")
    items: Optional[List[POLineItemCreate]] = None
    packing_list_items: Optional[List[PackingListItemCreate]] = None


class PurchaseOrderResponse(PurchaseOrderBase):
    po_id: int
    po_number: str
    version: int = 1
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    order_date: Optional[datetime] = None
    total_amount_fob: float
    total_cbm: float
    total_gross_weight_kg: float
    total_net_weight_kg: float
    total_packages_count: int
    status: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    project_name: Optional[str] = None
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    incoterm_code: Optional[str] = None
    currency_code: Optional[str] = None
    items: List[POLineItemResponse] = Field(default_factory=list)
    packing_list_items: List[PackingListItemResponse] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


# =========================================================================
# LOG-PART-004: PO Balance & Partial Shipment Schemas
# =========================================================================

class POShipmentAllocationCreate(BaseModel):
    po_item_id: Optional[int] = None
    import_file_id: Optional[int] = None
    shipment_ref: str = Field(..., min_length=2, description="رقم البوليصة أو كود الشحنة")
    shipped_quantity: float = Field(..., gt=0)
    shipped_amount_fob: float = Field(..., ge=0)
    shipping_date: Optional[datetime] = None
    status: str = "In Transit"
    notes: Optional[str] = None


class POShipmentAllocationResponse(BaseModel):
    allocation_id: int
    po_id: int
    po_item_id: Optional[int] = None
    import_file_id: Optional[int] = None
    shipment_ref: str
    shipped_quantity: float
    shipped_amount_fob: float
    shipping_date: datetime
    status: str
    notes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class POLineItemBalanceItem(BaseModel):
    item_id: int
    item_code: Optional[str] = None
    description_ar: str
    ordered_qty: float
    shipped_qty: float
    remaining_qty: float
    unit_price: float
    ordered_amount_fob: float
    shipped_amount_fob: float
    remaining_amount_fob: float
    fulfillment_percent: float


class POBalanceSummaryResponse(BaseModel):
    po_id: int
    po_number: str
    total_ordered_qty: float
    total_shipped_qty: float
    total_remaining_qty: float
    total_ordered_amount_fob: float
    total_shipped_amount_fob: float
    total_remaining_amount_fob: float
    currency_code: str
    overall_fulfillment_percent: float
    fulfillment_status: str  # Pending, Partially Shipped, Fully Shipped, Over-Shipped
    line_items_balance: List[POLineItemBalanceItem]
    allocations: List[POShipmentAllocationResponse]
    executive_summary_ar: str

    model_config = ConfigDict(from_attributes=True)


# =========================================================================
# UX-CLONE-011: Universal Entity-Level Clone Schemas
# =========================================================================

class ClonePurchaseOrderRequest(BaseModel):
    new_po_number: str = Field(..., min_length=2, max_length=50, description="Unique new PO number for the cloned purchase order")
    new_po_reference: Optional[str] = Field(None, max_length=200, description="Optional new display reference or title")
    copy_items: bool = Field(True, description="Copy commercial PO line items (default True per UX-CLONE-011)")
    copy_packing_list: bool = Field(True, description="Copy packing list items (default True)")
    copy_pallet_plan: bool = Field(True, description="Copy pallet plan items (default True)")
    notes: Optional[str] = Field(None, description="Optional notes on the cloned purchase order")
