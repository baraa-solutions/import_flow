from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from modules.common import enum_codes
from modules.common.cargo_math import LengthUnit
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model
from modules.common.system_messages import SystemMessageItem  # noqa: F401  (re-exported for the PO API)

# Declared packing-list weight UOM (enum_codes.MEASURE_UNIT; KG is exported to CargoX as KGM).
# A label only: every *_kg value is kilograms whatever this says (no conversion, CTO decision Q6).
PACKING_WEIGHT_UNITS = ("KG", "GRM", "STN", "SET")
DEFAULT_WEIGHT_UNIT = "KG"


def normalize_weight_unit(value: Any) -> str:
    """Blank -> KG; aliases / legacy spellings (KGM, kg, TON ...) -> their code; anything else raises ValueError."""
    if value is None or (isinstance(value, str) and not value.strip()):
        return DEFAULT_WEIGHT_UNIT
    code = enum_codes.normalize(enum_codes.MEASURE_UNIT, value)
    if code not in PACKING_WEIGHT_UNITS:
        raise ValueError(f"weight_unit must be one of {', '.join(PACKING_WEIGHT_UNITS)}")
    return code


def stored_weight_unit(value: Any) -> str:
    """A stored / legacy weight_unit as an allowed code: the mapped code when it is one, else KG (old clients
    stored package words such as CT / CTN there). Used when reading rows, never to validate requests."""
    try:
        return normalize_weight_unit(value)
    except ValueError:
        return DEFAULT_WEIGHT_UNIT


def _upper_code(value: Optional[str]) -> Optional[str]:
    """Business reference typed by the user: trimmed, upper-cased; blank -> None (auto-generated)."""
    if value is None:
        return None
    text = value.strip().upper()
    return text or None


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
    item_id: Optional[int] = Field(None, description="Existing line id on update: the row is updated in place. Omit for a new line.")


@read_model
class POLineItemResponse(POLineItemBase, LegacyRowTolerantModel):
    item_id: int
    po_id: int
    quantity: Optional[float] = None
    unit_price: Optional[float] = None
    total_price: Optional[float] = None
    cbm_per_unit: Optional[float] = None
    total_cbm: Optional[float] = None
    gross_weight_kg: Optional[float] = None
    net_weight_kg: Optional[float] = None
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
    unit: LengthUnit = Field("cm", description="Unit of length / width / height in the request (mm, cm or m); stored as cm")
    length_cm: Optional[float] = Field(0.0, ge=0)
    width_cm: Optional[float] = Field(0.0, ge=0)
    height_cm: Optional[float] = Field(0.0, ge=0)
    net_weight_unit_kg: float = Field(0.0, ge=0)
    gross_weight_unit_kg: float = Field(0.0, ge=0)
    weight_unit: Optional[str] = Field("KG", max_length=30, description="Declared weight UOM code: KG, GRM, STN or SET (KGM accepted)")
    is_stackable: bool = Field(True, description="Stackable vs Non-stackable cargo instruction")
    total_cbm: Optional[float] = Field(0.0, ge=0, description="CBM volume either calculated or directly entered")
    total_net_weight_kg: Optional[float] = Field(0.0, ge=0)
    total_gross_weight_kg: Optional[float] = Field(0.0, ge=0)


class PackingListItemCreate(PackingListItemBase):
    packing_item_id: Optional[int] = Field(None, description="Existing packing row id on update: the row is updated in place. Omit for a new row.")

    @field_validator("weight_unit", mode="before")
    @classmethod
    def _weight_unit(cls, value: Any) -> str:
        return normalize_weight_unit(value)


@read_model
class PackingListItemResponse(PackingListItemBase, LegacyRowTolerantModel):
    packing_item_id: int
    po_id: int
    qty_pcs: Optional[float] = None
    qty_pkg: Optional[float] = None
    length_cm: Optional[float] = None
    width_cm: Optional[float] = None
    height_cm: Optional[float] = None
    net_weight_unit_kg: Optional[float] = None
    gross_weight_unit_kg: Optional[float] = None
    total_net_weight_kg: Optional[float] = None
    total_gross_weight_kg: Optional[float] = None
    total_cbm: Optional[float] = None
    chargeable_weight_kg: Optional[float] = None
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
    # Coded twin of errors + warnings (same order); errors / warnings keep their English text for old clients.
    messages: List[SystemMessageItem] = Field(default_factory=list)


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

    _po_number = field_validator("po_number")(lambda cls, v: _upper_code(v))
    items: List[POLineItemCreate] = Field(default_factory=list)
    packing_list_items: List[PackingListItemCreate] = Field(default_factory=list)
    # Supplier credit limit governance (Trello GzFff0Pc): reason of an ADMIN override when the supplier's BLOCK
    # credit limit would be exceeded. Ignored when the PO stays within the limit.
    credit_limit_override_reason: Optional[str] = Field(None, max_length=500)


class PurchaseOrderUpdate(BaseModel):
    # Unknown keys (e.g. the removed ``is_active``: use DELETE / restore) are ignored.
    model_config = ConfigDict(extra="ignore")

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
    status: Optional[str] = Field(None, max_length=50, description="PO_STATUS code (legacy labels accepted)")
    notes: Optional[str] = None
    pallet_count: Optional[int] = Field(None, ge=0)
    pallet_type: Optional[str] = Field(None, max_length=100)
    is_pallet_stackable: Optional[bool] = None
    pallet_length_cm: Optional[float] = Field(None, ge=0)
    pallet_width_cm: Optional[float] = Field(None, ge=0)
    pallet_height_cm: Optional[float] = Field(None, ge=0)
    pallet_plan: Optional[List[PalletPlanItem]] = None
    version: Optional[int] = Field(None, description="Current version of the record for optimistic concurrency control")
    items: Optional[List[POLineItemCreate]] = None
    packing_list_items: Optional[List[PackingListItemCreate]] = None


@read_model
class PurchaseOrderResponse(PurchaseOrderBase, LegacyRowTolerantModel):
    po_id: int
    po_number: str
    version: int = 1
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    order_date: Optional[datetime] = None
    exchange_rate: Optional[float] = None
    total_amount_fob: Optional[float] = None
    total_cbm: Optional[float] = None
    total_gross_weight_kg: Optional[float] = None
    total_net_weight_kg: Optional[float] = None
    total_packages_count: Optional[int] = 0
    pallet_count: Optional[int] = 0
    pallet_length_cm: Optional[float] = None
    pallet_width_cm: Optional[float] = None
    pallet_height_cm: Optional[float] = None
    status: str  # PO_STATUS code
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    project_name: Optional[str] = None
    company_name: Optional[str] = None
    supplier_name: Optional[str] = None
    incoterm_code: Optional[str] = None
    currency_code: Optional[str] = None
    items: List[POLineItemResponse] = Field(default_factory=list)
    packing_list_items: List[PackingListItemResponse] = Field(default_factory=list)
    total_shipped_quantity: Optional[float] = 0.0
    total_received_quantity: Optional[float] = 0.0
    remaining_balance_quantity: Optional[float] = 0.0
    fulfillment_status: Optional[str] = "OPEN"

    model_config = ConfigDict(from_attributes=True)


class PurchaseOrderListItem(BaseModel):
    id: Optional[int] = None
    po_id: int
    code: Optional[str] = None
    po_number: str
    po_reference: Optional[str] = None
    proforma_invoice_number: Optional[str] = None
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    company_id: Optional[int] = None
    company_name: Optional[str] = None
    project_id: Optional[int] = None
    project_name: Optional[str] = None
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    total_amount_fob: float = 0.0
    total_amount: Optional[float] = None
    currency_id: Optional[int] = None
    currency_code: Optional[str] = None
    currency: Optional[str] = None
    status: str
    order_date: Optional[datetime] = None
    expected_delivery_date: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    is_active: bool = True
    total_shipped_quantity: Optional[float] = 0.0
    total_received_quantity: Optional[float] = 0.0
    remaining_balance_quantity: Optional[float] = 0.0
    fulfillment_status: Optional[str] = "OPEN"

    model_config = ConfigDict(from_attributes=True)


class PaginatedPurchaseOrdersResponse(BaseModel):
    items: List[PurchaseOrderListItem]
    total: int
    page: int
    page_size: int
    total_pages: int

    model_config = ConfigDict(from_attributes=True)


# =========================================================================
# LOG-PART-004 & EPIC-PO-PART: PO Balance & Partial Shipment Schemas
# =========================================================================

class POAllocationCreate(BaseModel):
    po_id: Optional[int] = None
    po_line_item_id: Optional[int] = None
    po_item_id: Optional[int] = None
    import_file_id: Optional[int] = None
    shipment_batch_no: Optional[str] = None
    shipment_ref: Optional[str] = None
    allocated_quantity: Optional[float] = None
    shipped_quantity: Optional[float] = None
    allocated_fob_amount: Optional[float] = 0.0
    shipped_amount_fob: Optional[float] = 0.0
    shipping_date: Optional[datetime] = None
    status: str = "IN_TRANSIT"
    notes: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def _sync_aliases(cls, values: Any) -> Any:
        if not isinstance(values, dict):
            return values
        # Item ID alias
        item_id = values.get("po_line_item_id") or values.get("po_item_id")
        values["po_line_item_id"] = item_id
        values["po_item_id"] = item_id

        # Batch / Ref alias
        ref = values.get("shipment_batch_no") or values.get("shipment_ref") or "BATCH-01"
        values["shipment_batch_no"] = ref
        values["shipment_ref"] = ref

        # Quantity alias
        qty = values.get("allocated_quantity")
        if qty is None:
            qty = values.get("shipped_quantity")
        if qty is None:
            qty = 0.0
        values["allocated_quantity"] = float(qty)
        values["shipped_quantity"] = float(qty)

        # FOB amount alias
        fob = values.get("allocated_fob_amount")
        if fob is None:
            fob = values.get("shipped_amount_fob")
        if fob is None:
            fob = 0.0
        values["allocated_fob_amount"] = float(fob)
        values["shipped_amount_fob"] = float(fob)

        return values

    @field_validator("status", mode="before")
    @classmethod
    def _normalize_create_status(cls, v: Any) -> str:
        if v is None:
            return "IN_TRANSIT"
        norm = enum_codes.normalize(enum_codes.PO_ALLOCATION_STATUS, v)
        return norm or str(v)


POShipmentAllocationCreate = POAllocationCreate


@read_model
class POShipmentAllocationResponse(LegacyRowTolerantModel):
    allocation_id: int
    po_id: int
    po_line_item_id: Optional[int] = None
    po_item_id: Optional[int] = None
    import_file_id: Optional[int] = None
    shipment_batch_no: Optional[str] = None
    shipment_ref: Optional[str] = None
    allocated_quantity: Optional[float] = None
    shipped_quantity: Optional[float] = None
    allocated_fob_amount: Optional[float] = None
    shipped_amount_fob: Optional[float] = None
    shipping_date: Optional[datetime] = None
    status: str = "IN_TRANSIT"
    notes: Optional[str] = None
    created_by: Optional[str] = None
    # Warnings about this allocation, e.g. OVER_SHIPPED (over-allocation is allowed, CTO decision Q4).
    messages: List[SystemMessageItem] = Field(default_factory=list)

    @model_validator(mode="before")
    @classmethod
    def _sync_resp_aliases(cls, values: Any) -> Any:
        if hasattr(values, "__dict__"):
            d = values.__dict__
            line_id = getattr(values, "po_line_item_id", None) or getattr(values, "po_item_id", None)
            ref = getattr(values, "shipment_batch_no", None) or getattr(values, "shipment_ref", None)
            qty = getattr(values, "allocated_quantity", None) or getattr(values, "shipped_quantity", None)
            fob = getattr(values, "allocated_fob_amount", None) or getattr(values, "shipped_amount_fob", None)
            setattr(values, "po_line_item_id", line_id)
            setattr(values, "po_item_id", line_id)
            setattr(values, "shipment_batch_no", ref)
            setattr(values, "shipment_ref", ref)
            setattr(values, "allocated_quantity", qty)
            setattr(values, "shipped_quantity", qty)
            setattr(values, "allocated_fob_amount", fob)
            setattr(values, "shipped_amount_fob", fob)
        elif isinstance(values, dict):
            line_id = values.get("po_line_item_id") or values.get("po_item_id")
            ref = values.get("shipment_batch_no") or values.get("shipment_ref")
            qty = values.get("allocated_quantity") if values.get("allocated_quantity") is not None else values.get("shipped_quantity")
            fob = values.get("allocated_fob_amount") if values.get("allocated_fob_amount") is not None else values.get("shipped_amount_fob")
            values["po_line_item_id"] = line_id
            values["po_item_id"] = line_id
            values["shipment_batch_no"] = ref
            values["shipment_ref"] = ref
            values["allocated_quantity"] = qty
            values["shipped_quantity"] = qty
            values["allocated_fob_amount"] = fob
            values["shipped_amount_fob"] = fob
        return values

    @field_validator("status", mode="before")
    @classmethod
    def _normalize_response_status(cls, v: Any) -> str:
        if v is None:
            return "IN_TRANSIT"
        norm = enum_codes.normalize(enum_codes.PO_ALLOCATION_STATUS, v)
        return norm or str(v)

    model_config = ConfigDict(from_attributes=True)


POAllocationResponse = POShipmentAllocationResponse


@read_model
class POLineItemBalanceItem(LegacyRowTolerantModel):
    item_id: int
    item_code: Optional[str] = None
    description_ar: str
    ordered_qty: Optional[float] = None
    contracted_qty: Optional[float] = None
    shipped_qty: Optional[float] = None
    received_qty: Optional[float] = 0.0
    remaining_qty: Optional[float] = None
    unit_price: Optional[float] = None
    ordered_amount_fob: Optional[float] = None
    shipped_amount_fob: Optional[float] = None
    remaining_amount_fob: Optional[float] = None
    fulfillment_percent: Optional[float] = None

    @model_validator(mode="before")
    @classmethod
    def _sync_item_contracted(cls, values: Any) -> Any:
        if isinstance(values, dict):
            if "contracted_qty" not in values or values["contracted_qty"] is None:
                values["contracted_qty"] = values.get("ordered_qty")
        elif hasattr(values, "__dict__"):
            if not getattr(values, "contracted_qty", None):
                setattr(values, "contracted_qty", getattr(values, "ordered_qty", None))
        return values


@read_model
class POBalanceSummaryResponse(LegacyRowTolerantModel):
    po_id: int
    po_number: str
    total_ordered_qty: Optional[float] = None
    total_contracted_qty: Optional[float] = None
    total_shipped_qty: Optional[float] = None
    total_received_qty: Optional[float] = 0.0
    total_remaining_qty: Optional[float] = None
    total_ordered_amount_fob: Optional[float] = None
    total_shipped_amount_fob: Optional[float] = None
    total_remaining_amount_fob: Optional[float] = None
    currency_code: Optional[str] = None
    overall_fulfillment_percent: Optional[float] = None
    fulfillment_status: str = "OPEN"  # OPEN, PARTIALLY_SHIPPED, FULLY_SHIPPED, etc.
    line_items_balance: List[POLineItemBalanceItem] = Field(default_factory=list)
    allocations: List[POShipmentAllocationResponse] = Field(default_factory=list)
    executive_summary_ar: str = ""

    @model_validator(mode="before")
    @classmethod
    def _sync_summary_contracted(cls, values: Any) -> Any:
        if isinstance(values, dict):
            if "total_contracted_qty" not in values or values["total_contracted_qty"] is None:
                values["total_contracted_qty"] = values.get("total_ordered_qty")
        elif hasattr(values, "__dict__"):
            if not getattr(values, "total_contracted_qty", None):
                setattr(values, "total_contracted_qty", getattr(values, "total_ordered_qty", None))
        return values

    model_config = ConfigDict(from_attributes=True)


# =========================================================================
# UX-CLONE-011: Universal Entity-Level Clone Schemas
# =========================================================================

class ClonePurchaseOrderRequest(BaseModel):
    new_po_number: str = Field(..., min_length=2, max_length=50, description="Unique new PO number for the cloned purchase order")

    _new_po_number = field_validator("new_po_number")(lambda cls, v: _upper_code(v))
    new_po_reference: Optional[str] = Field(None, max_length=200, description="Optional new display reference or title")
    copy_items: bool = Field(True, description="Copy commercial PO line items (default True per UX-CLONE-011)")
    copy_packing_list: bool = Field(True, description="Copy packing list items (default True)")
    copy_pallet_plan: bool = Field(True, description="Copy pallet plan items (default True)")
    notes: Optional[str] = Field(None, description="Optional notes on the cloned purchase order")
