from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, text
from sqlalchemy.orm import relationship

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.import_files.model import ImportFile
from modules.master_items.model import MasterItem  # noqa: F401
from modules.common.system_parameters import SystemParameter  # noqa: F401  (registers system_parameters on Base.metadata)


# ==================================================
# Purchase Orders & Proforma Invoices Module (BP-001 / BP-002)
# ==================================================

class PurchaseOrder(Base):
    __tablename__ = "purchase_orders"

    # Primary Key
    po_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Reference Code
    po_number = Column(String(50), nullable=False, unique=True, index=True) # e.g. PO-2026-001
    po_reference = Column(String(200), nullable=True)                      # اسم أو مرجع أمر الشراء e.g. "Chiller Units - Delta Factory"
    proforma_invoice_number = Column(String(100), nullable=True)           # Supplier PI Number

    # Foreign Keys
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.project_id"), nullable=False, index=True)
    company_id = Column(Integer, ForeignKey("import_companies.company_id"), nullable=False, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False, index=True)
    incoterm_id = Column(Integer, ForeignKey("incoterms.incoterm_id"), nullable=False, index=True)
    currency_id = Column(Integer, ForeignKey("currencies.currency_id"), nullable=False, index=True)

    # Dates & Financials
    order_date = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    expected_delivery_date = Column(DateTime, nullable=True)
    exchange_rate = Column(Numeric(10, 4), default=1.0, nullable=False)
    total_amount_fob = Column(Numeric(14, 2), default=0.0, nullable=False)

    # Shipping Measurements Aggregates
    total_cbm = Column(Numeric(10, 4), default=0.0, nullable=False)
    total_gross_weight_kg = Column(Numeric(26, 16), default=0.0, nullable=False)
    total_net_weight_kg = Column(Numeric(26, 16), default=0.0, nullable=False)
    total_packages_count = Column(Integer, default=0, nullable=False)

    # Palletization & Master Handling Plan (مخطط البالتات)
    pallet_count = Column(Integer, default=0, nullable=True)
    pallet_type = Column(String(100), default="Euro Pallet (120x80)", nullable=True)
    is_pallet_stackable = Column(Boolean, default=False, nullable=True)
    pallet_length_cm = Column(Numeric(10, 2), default=120.0, nullable=True)
    pallet_width_cm = Column(Numeric(10, 2), default=80.0, nullable=True)
    pallet_height_cm = Column(Numeric(10, 2), default=150.0, nullable=True)
    pallet_plan = Column(Text, nullable=True) # JSON list of multi-row pallet items

    # Workflow Status & Information
    country_of_origin = Column(String(100), nullable=True) # بلد المنشأ لأمر التوريد e.g. "CN", "DE - Germany"
    payment_terms = Column(String(100), nullable=True, default="LC at Sight")
    status = Column(String(50), nullable=False, default="DRAFT", index=True)  # enum_codes.PO_STATUS code (legacy rows: English label)
    notes = Column(Text, nullable=True)

    # PO Fulfillment & Balance Tracking (EPIC-PO-PART)
    total_shipped_quantity = Column(Numeric(14, 2), default=0.0, nullable=False, server_default=text("0.0"))
    total_received_quantity = Column(Numeric(14, 2), default=0.0, nullable=False, server_default=text("0.0"))
    remaining_balance_quantity = Column(Numeric(14, 2), default=0.0, nullable=False, server_default=text("0.0"))
    fulfillment_status = Column(String(50), default="OPEN", nullable=False, server_default=text("'OPEN'"), index=True) # OPEN, PARTIALLY_SHIPPED, FULLY_SHIPPED

    # Concurrency Control & Audit Trail
    version = Column(Integer, default=1, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_by = Column(String(100), nullable=True)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
    project = relationship("Project", foreign_keys=[project_id])
    company = relationship("ImportCompany", foreign_keys=[company_id])
    supplier = relationship("Supplier", foreign_keys=[supplier_id])
    incoterm = relationship("Incoterm", foreign_keys=[incoterm_id])
    currency = relationship("Currency", foreign_keys=[currency_id])
    line_items = relationship("POLineItem", back_populates="purchase_order", cascade="all, delete-orphan")
    packing_list_items = relationship("PackingListItem", back_populates="purchase_order", cascade="all, delete-orphan")


class POLineItem(Base):
    __tablename__ = "po_line_items"

    item_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    po_id = Column(Integer, ForeignKey("purchase_orders.po_id"), nullable=False, index=True)

    item_code = Column(String(50), nullable=True)
    main_description = Column(String(250), nullable=True) # الوصف الرئيسي للصنف / Main Description
    description_ar = Column(String(250), nullable=False)
    description_en = Column(String(250), nullable=True)
    country_of_origin = Column(String(100), nullable=True) # بلد المنشأ للصنف

    # Customs Tariff Link
    tariff_id = Column(Integer, ForeignKey("customs_tariffs.tariff_id"), nullable=True, index=True)

    # Quantities & Pricing
    quantity = Column(Numeric(12, 2), nullable=False, default=1.0)
    unit_of_measure = Column(String(30), nullable=False, default="PCS") # PCS, CTN, KG, SET
    unit_price = Column(Numeric(14, 4), nullable=False, default=0.0)
    total_price = Column(Numeric(14, 2), nullable=False, default=0.0)

    # Package & Volume Specs
    cbm_per_unit = Column(Numeric(10, 4), default=0.0, nullable=False)
    total_cbm = Column(Numeric(10, 4), default=0.0, nullable=False)
    gross_weight_kg = Column(Numeric(26, 16), default=0.0, nullable=False)
    net_weight_kg = Column(Numeric(26, 16), default=0.0, nullable=False)

    # CGX-003: Multi-Invoice Extraction Fields
    invoice_number = Column(String(100), nullable=True, index=True)     # رقم الفاتورة التي ينتمي إليها هذا البند
    invoice_line_number = Column(Integer, nullable=True)                 # ترتيب البند داخل الفاتورة
    customs_unit_price = Column(Numeric(14, 4), nullable=True)          # سعر الجمرك لو مختلف عن سعر المورد

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    purchase_order = relationship("PurchaseOrder", back_populates="line_items")
    tariff = relationship("CustomsTariff", foreign_keys=[tariff_id])
    master_item_id = Column(Integer, ForeignKey("master_items.item_id"), nullable=True)
    master_item = relationship("MasterItem", foreign_keys=[master_item_id])


class PackingListItem(Base):
    """
    BP-003 Review Packing List Model
    Stores detailed packing list items with weights, dimensions, and package counts.
    """
    __tablename__ = "packing_list_items"

    packing_item_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    po_id = Column(Integer, ForeignKey("purchase_orders.po_id"), nullable=False, index=True)

    hs_code = Column(String(50), nullable=False)
    item_code = Column(String(50), nullable=False)
    main_description = Column(String(250), nullable=True)
    description = Column(String(250), nullable=True)
    qty_pcs = Column(Numeric(12, 2), nullable=False, default=1.0)
    qty_pkg = Column(Numeric(12, 2), nullable=False, default=1.0)
    package_type = Column(String(50), nullable=True, default="Carton")
    length_cm = Column(Numeric(10, 2), nullable=True, default=0.0)
    width_cm = Column(Numeric(10, 2), nullable=True, default=0.0)
    height_cm = Column(Numeric(10, 2), nullable=True, default=0.0)
    net_weight_unit_kg = Column(Numeric(26, 16), nullable=False, default=0.0)
    gross_weight_unit_kg = Column(Numeric(26, 16), nullable=False, default=0.0)
    # Declared weight UOM label (MEASURE_UNIT code KGM / GRM / STN / SET) exported to CargoX. The weights in
    # this row are ALWAYS kilograms: the label is never used to convert them.
    weight_unit = Column(String(30), nullable=True, default="KGM")

    # Computed fields stored for reports and fast retrieval
    total_net_weight_kg = Column(Numeric(26, 16), nullable=False, default=0.0)
    total_gross_weight_kg = Column(Numeric(26, 16), nullable=False, default=0.0)
    total_cbm = Column(Numeric(10, 4), nullable=False, default=0.0)
    chargeable_weight_kg = Column(Numeric(26, 16), nullable=False, default=0.0)
    is_stackable = Column(Boolean, nullable=False, default=True)

    # CGX-003: Multi-Invoice & Pallet Grouping Fields
    invoice_number = Column(String(100), nullable=True, index=True)     # رقم الفاتورة المرتبطة بهذا البند
    pallet_number = Column(Integer, nullable=True)                       # رقم البالت (للتجميع الجمركي على بالتات)
    carton_numbers = Column(JSON, nullable=True)                         # قائمة أرقام الكراتين: [1, 2, ..., 20]

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    purchase_order = relationship("PurchaseOrder", back_populates="packing_list_items")
    master_item_id = Column(Integer, ForeignKey("master_items.item_id"), nullable=True)
    master_item = relationship("MasterItem", foreign_keys=[master_item_id])


# ==================================================
# Package Types Master (أنواع التعبئة والتغليف والطرود)
# ==================================================

class PackageType(Base):
    __tablename__ = "package_types"

    package_type_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    code = Column(String(10), nullable=False, unique=True, index=True)   # e.g. B4, CT, BX, PK
    name = Column(String(150), nullable=False, index=True)              # e.g. Belt, Carton, Box, Package
    name_ar = Column(String(150), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


# ==================================================
# Units of Measure Master (وحدات القياس)
# ==================================================

class UnitOfMeasure(Base):
    __tablename__ = "units_of_measure"

    unit_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    code = Column(String(10), nullable=False, unique=True, index=True)   # e.g. GRM, KGM, SET, STN, PCS
    name = Column(String(150), nullable=False, index=True)              # e.g. gram, kilogram, set, ton
    name_ar = Column(String(150), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


# ==================================================
# LOG-PART-004: Partial Shipments & PO Allocations
# ==================================================

class POShipmentAllocation(Base):
    __tablename__ = "po_shipment_allocations"

    allocation_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    po_id = Column(Integer, ForeignKey("purchase_orders.po_id"), nullable=False, index=True)
    po_line_item_id = Column(Integer, ForeignKey("po_line_items.item_id"), nullable=True, index=True)
    po_item_id = Column(Integer, ForeignKey("po_line_items.item_id"), nullable=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)

    shipment_batch_no = Column(String(100), nullable=True)  # رقم دفعة الشحن
    shipment_ref = Column(String(100), nullable=True)  # رقم البوليصة أو كود الشحنة (e.g. B/L # MEDU123456)
    allocated_quantity = Column(Numeric(12, 2), nullable=False, default=0.0, server_default=text("0.0"))
    shipped_quantity = Column(Numeric(12, 2), nullable=False, default=0.0, server_default=text("0.0"))
    allocated_fob_amount = Column(Numeric(14, 2), nullable=False, default=0.0, server_default=text("0.0"))
    shipped_amount_fob = Column(Numeric(14, 2), nullable=False, default=0.0, server_default=text("0.0"))
    shipping_date = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    status = Column(String(50), default="In Transit", nullable=False)  # In Transit, Arrived, Customs Cleared, Received at Warehouse
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_by = Column(String(100), nullable=True)

    def __init__(self, **kwargs):
        if "po_line_item_id" in kwargs and "po_item_id" not in kwargs:
            kwargs["po_item_id"] = kwargs["po_line_item_id"]
        elif "po_item_id" in kwargs and "po_line_item_id" not in kwargs:
            kwargs["po_line_item_id"] = kwargs["po_item_id"]
        if "allocated_quantity" in kwargs and "shipped_quantity" not in kwargs:
            kwargs["shipped_quantity"] = kwargs["allocated_quantity"]
        elif "shipped_quantity" in kwargs and "allocated_quantity" not in kwargs:
            kwargs["allocated_quantity"] = kwargs["shipped_quantity"]
        if "allocated_fob_amount" in kwargs and "shipped_amount_fob" not in kwargs:
            kwargs["shipped_amount_fob"] = kwargs["allocated_fob_amount"]
        elif "shipped_amount_fob" in kwargs and "allocated_fob_amount" not in kwargs:
            kwargs["allocated_fob_amount"] = kwargs["shipped_amount_fob"]
        if "shipment_batch_no" in kwargs and "shipment_ref" not in kwargs:
            kwargs["shipment_ref"] = kwargs["shipment_batch_no"]
        elif "shipment_ref" in kwargs and "shipment_batch_no" not in kwargs:
            kwargs["shipment_batch_no"] = kwargs["shipment_ref"]
        super().__init__(**kwargs)

    purchase_order = relationship("PurchaseOrder", backref="shipment_allocations")
    po_item = relationship("POLineItem", foreign_keys=[po_item_id], backref="shipment_allocations")
    po_line_item = relationship("POLineItem", foreign_keys=[po_line_item_id])
    import_file = relationship("ImportFile", backref="po_allocations")
