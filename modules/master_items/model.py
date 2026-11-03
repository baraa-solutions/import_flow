"""
Master Items Models (MD-ITEM-001)
Central catalog for standardized import items, supplier linkages, and historical landed cost tracking.
"""

from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from database.database import Base


class MasterItem(Base):
    """
    Master Item Definition (Single Source of Truth for Products/SKUs)
    Standardizes internal item codes, descriptions, default tariffs, and physical specs.
    """

    __tablename__ = "master_items"

    item_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    item_code = Column(String(100), nullable=False, unique=True, index=True)

    description_ar = Column(String(500), nullable=False, index=True)
    description_en = Column(String(500), nullable=True)

    tariff_id = Column(
        Integer,
        ForeignKey("customs_tariffs.tariff_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    default_uom = Column(String(30), nullable=True, default="PCS")
    default_pkg_type = Column(String(50), nullable=True, default="Carton")

    # Default Unit Dimensions & Weights
    cbm_per_unit = Column(Float, nullable=True, default=0.0)
    gross_weight_kg = Column(Float, nullable=True, default=0.0)
    net_weight_kg = Column(Float, nullable=True, default=0.0)

    # Cached duty and tax rates from tariff for fast display
    last_customs_duty_pct = Column(Float, nullable=True)
    last_vat_pct = Column(Float, nullable=True)
    last_schedule_tax_pct = Column(Float, nullable=True)

    # Categories
    product_category = Column(String(100), nullable=True, index=True)
    product_subcategory = Column(String(100), nullable=True)

    notes = Column(Text, nullable=True)

    # Soft Delete & Audit Trail
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    created_by = Column(String(100), nullable=True)
    updated_at = Column(DateTime, nullable=True)
    updated_by = Column(String(100), nullable=True)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)

    # Relationships
    tariff = relationship("CustomsTariff", foreign_keys=[tariff_id])
    supplier_catalogs = relationship(
        "ItemSupplierCatalog",
        back_populates="item",
        cascade="all, delete-orphan",
    )
    price_history = relationship(
        "ItemPriceHistory",
        back_populates="item",
        cascade="all, delete-orphan",
    )


class ItemSupplierCatalog(Base):
    """
    Many-to-Many mapping between Master Items and Overseas Suppliers.
    Resolves supplier-specific part numbers and maintains the last confirmed quotation prices.
    """

    __tablename__ = "item_supplier_catalog"

    catalog_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    item_id = Column(
        Integer,
        ForeignKey("master_items.item_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    supplier_id = Column(
        Integer,
        ForeignKey("suppliers.supplier_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    supplier_item_code = Column(String(100), nullable=True, index=True)
    supplier_description = Column(String(500), nullable=True)

    last_confirmed_price = Column(Float, nullable=True)
    last_confirmed_currency = Column(String(10), nullable=True, default="USD")
    last_confirmed_date = Column(String(30), nullable=True)
    last_po_id = Column(
        Integer,
        ForeignKey("purchase_orders.po_id", ondelete="SET NULL"),
        nullable=True,
    )

    min_order_qty = Column(Float, nullable=True)
    lead_time_days = Column(Integer, nullable=True)
    preferred_incoterm = Column(String(10), nullable=True)
    is_preferred_supplier = Column(Boolean, default=False, nullable=False)

    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(DateTime, nullable=True)

    # Relationships
    item = relationship("MasterItem", back_populates="supplier_catalogs")
    supplier = relationship("Supplier", foreign_keys=[supplier_id])
    purchase_order = relationship("PurchaseOrder", foreign_keys=[last_po_id])


class ItemPriceHistory(Base):
    """
    Historical Ledger of Item Prices across Purchase Orders and Actual Landed Costs.
    Enables procurement price trend analysis and supplier cost comparisons.
    """

    __tablename__ = "item_price_history"

    history_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    item_id = Column(
        Integer,
        ForeignKey("master_items.item_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    supplier_id = Column(
        Integer,
        ForeignKey("suppliers.supplier_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    po_id = Column(
        Integer,
        ForeignKey("purchase_orders.po_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    import_file_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    unit_price_fx = Column(Float, nullable=False)
    currency = Column(String(10), nullable=False, default="USD")
    exchange_rate = Column(Float, nullable=True, default=1.0)
    unit_price_egp = Column(Float, nullable=True)

    # Landed Cost post-clearance settlement
    landed_cost_egp = Column(Float, nullable=True)
    landed_cost_markup = Column(Float, nullable=True)

    quantity = Column(Float, nullable=True)
    po_date = Column(String(30), nullable=True)
    recorded_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    item = relationship("MasterItem", back_populates="price_history")
    supplier = relationship("Supplier", foreign_keys=[supplier_id])
    purchase_order = relationship("PurchaseOrder", foreign_keys=[po_id])
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
