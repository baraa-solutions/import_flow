"""
SQLAlchemy Model for Split Shipments & Multi-PO Allocations
"""

from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    func,
    text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class SplitShipmentAllocation(Base):
    """
    Split B/L and Multi-PO Line Item Allocation Entity.
    Enables splitting a master bill of lading into multiple partial consignments
    and allocates line items from various purchase orders with prorated landed cost metrics.
    """

    __tablename__ = "split_shipment_allocations"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    shipment_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    parent_bl_number = Column(String(100), nullable=False, index=True)
    split_bl_number = Column(String(100), nullable=False, index=True)

    po_id = Column(
        Integer,
        ForeignKey("purchase_orders.po_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    po_item_id = Column(
        Integer,
        ForeignKey("po_line_items.item_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    item_sku = Column(String(100), nullable=False)

    allocated_quantity = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    total_item_quantity = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    allocation_ratio = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))

    prorated_customs_cost = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    prorated_freight_cost = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    currency = Column(String(10), nullable=False, default="EGP", server_default=text("'EGP'"))
    notes = Column(Text, nullable=True)

    is_deleted = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    created_by_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True
    )
    updated_by_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True
    )
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    __table_args__ = (
        Index("ix_split_alloc_shipment_bl", "shipment_id", "split_bl_number"),
        Index("ix_split_alloc_po_item", "po_id", "po_item_id"),
    )
