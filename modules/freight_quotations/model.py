"""
Freight Quotations Engine Models (BP-008)
"""

from datetime import datetime, date, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from database.database import Base


class FreightRFQRequest(Base):
    """
    Master Request for Quotation (RFQ) for Freight Shipping (BP-008).
    Tracks shipment requirements, POL, POD, CBM, weight, competing carrier quotes, and awarded quote.
    """

    __tablename__ = "freight_rfq_requests"

    rfq_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    rfq_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    
    # Shipping Method: 'Ocean FCL', 'Ocean LCL', 'Air Freight', 'Inland Trucking'
    shipping_method: Mapped[str] = mapped_column(String(50), default="Ocean FCL", nullable=False)

    crd_date: Mapped[date] = mapped_column(Date, nullable=False)

    # Ports & Locations
    pol_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("transport_locations.location_id"), nullable=True
    )
    pol_name: Mapped[str] = mapped_column(String(200), nullable=False)

    pod_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("transport_locations.location_id"), nullable=True
    )
    pod_name: Mapped[str] = mapped_column(String(200), nullable=False)

    # Optional Link to Import File, Purchase Order or Project
    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    project_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("projects.project_id"), nullable=True, index=True
    )

    # Cargo Volume & Weights
    total_cbm: Mapped[float] = mapped_column(Float, default=0.0)
    total_gross_weight_kg: Mapped[float] = mapped_column(Float, default=0.0)
    chargeable_weight_kg: Mapped[float] = mapped_column(Float, default=0.0)

    # Status: 'Draft', 'RFQ Issued', 'Quotations Received', 'Awarded', 'Cancelled'
    status: Mapped[str] = mapped_column(
        String(50), default="Draft", nullable=False, index=True
    )
    selected_quotation_id: Mapped[int] = mapped_column(Integer, nullable=True)

    notes: Mapped[str] = mapped_column(Text, nullable=True)

    # Audit & Soft Delete
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )
    created_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    updated_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Relationship to Quotation Items
    quotations: Mapped[list["FreightQuotationItem"]] = relationship(
        "FreightQuotationItem",
        back_populates="rfq_request",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class FreightQuotationItem(Base):
    """
    Individual Carrier / Shipping Line Quotation in RFQ (BP-008).
    """

    __tablename__ = "freight_quotation_items"

    quotation_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    rfq_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("freight_rfq_requests.rfq_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Carrier / Forwarder (MD-003)
    provider_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True
    )
    provider_name: Mapped[str] = mapped_column(String(200), nullable=False)
    vessel_name: Mapped[str] = mapped_column(String(100), nullable=True)
    voyage_number: Mapped[str] = mapped_column(String(50), nullable=True)

    # Financial Breakdown
    currency_code: Mapped[str] = mapped_column(String(10), default="USD", nullable=False)
    ocean_freight_cost: Mapped[float] = mapped_column(Float, default=0.0)
    local_charges_cost: Mapped[float] = mapped_column(Float, default=0.0)
    inland_cost: Mapped[float] = mapped_column(Float, default=0.0)
    total_cost: Mapped[float] = mapped_column(Float, default=0.0)

    # Schedule & Delays
    sailing_date: Mapped[date] = mapped_column(Date, nullable=False)
    estimated_arrival_date: Mapped[date] = mapped_column(Date, nullable=False)
    transit_days: Mapped[int] = mapped_column(Integer, default=0)
    free_days_at_pod: Mapped[int] = mapped_column(Integer, default=14)

    # Award & Exception Flags
    is_awarded: Mapped[bool] = mapped_column(Boolean, default=False)
    is_excluded_from_avg: Mapped[bool] = mapped_column(Boolean, default=False)
    remarks: Mapped[str] = mapped_column(Text, nullable=True)

    # Parent Relationship
    rfq_request: Mapped["FreightRFQRequest"] = relationship(
        "FreightRFQRequest", back_populates="quotations"
    )
