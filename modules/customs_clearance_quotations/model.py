"""
Customs Clearance Quotations & Price Lists Models
"""

from __future__ import annotations

from datetime import datetime, date, timezone
from typing import List, Optional
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from database.database import Base


class CustomsClearanceRFQ(Base):
    """
    Master Request for Quotation (RFQ) for Customs Clearance & Local Logistics.
    Compares competing customs broker quotations and manages awarded clearance agency rates.
    """

    __tablename__ = "customs_clearance_rfqs"

    rfq_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    rfq_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)

    # Clearance Port / Location
    port_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("transport_locations.location_id"), nullable=True
    )
    port_name: Mapped[str] = mapped_column(String(200), nullable=False)

    # Optional Link to Import File or Project
    import_file_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    project_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("projects.project_id"), nullable=True, index=True
    )

    # Cargo Details
    commodity_description: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    hs_code: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    shipment_type: Mapped[str] = mapped_column(String(50), default="Ocean FCL (40HQ)")

    containers_count: Mapped[int] = mapped_column(Integer, default=1)
    packages_count: Mapped[int] = mapped_column(Integer, default=0)
    gross_weight_kg: Mapped[float] = mapped_column(Float, default=0.0)
    cbm: Mapped[float] = mapped_column(Float, default=0.0)

    # Status: 'Draft', 'RFQ Issued', 'Quotations Received', 'Awarded', 'Cancelled'
    status: Mapped[str] = mapped_column(
        String(50), default="Draft", index=True, nullable=False
    )

    # Evaluated Summary Metrics
    lowest_clearance_cost: Mapped[float] = mapped_column(Float, default=0.0)
    fastest_turnaround_days: Mapped[int] = mapped_column(Integer, default=0)

    # Awarded Broker Information
    awarded_provider_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=True
    )
    awarded_provider_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    awarded_quotation_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    awarded_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Audit & Soft-Delete
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    quotations: Mapped[List[CustomsClearanceQuotationItem]] = relationship(
        "CustomsClearanceQuotationItem",
        back_populates="rfq",
        cascade="all, delete-orphan",
        order_by="CustomsClearanceQuotationItem.total_cost.asc()",
    )


class CustomsClearanceQuotationItem(Base):
    """
    Individual clearance quotation received from a Customs Broker / Clearance Office.
    """

    __tablename__ = "customs_clearance_quotations"

    quotation_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    rfq_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("customs_clearance_rfqs.rfq_id"), nullable=False, index=True
    )

    provider_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=False
    )
    provider_name: Mapped[str] = mapped_column(String(200), nullable=False)
    license_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Cost Breakdown (EGP or USD)
    clearance_fee: Mapped[float] = mapped_column(Float, default=0.0)
    inland_transport_fee: Mapped[float] = mapped_column(Float, default=0.0)
    inspection_fee: Mapped[float] = mapped_column(Float, default=0.0)
    port_expenses: Mapped[float] = mapped_column(Float, default=0.0)
    miscellaneous_fee: Mapped[float] = mapped_column(Float, default=0.0)
    total_cost: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="EGP", nullable=False)

    # Turnaround & Validity
    estimated_turnaround_days: Mapped[int] = mapped_column(Integer, default=3)
    validity_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    # Award & Notes
    is_awarded: Mapped[bool] = mapped_column(Boolean, default=False)
    remarks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    rfq: Mapped[CustomsClearanceRFQ] = relationship("CustomsClearanceRFQ", back_populates="quotations")


class ClearanceServicePriceListItem(Base):
    """
    Standard Clearance & Inland Logistics Master Price List per Broker and Port.
    """

    __tablename__ = "clearance_price_list_items"

    price_item_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    provider_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True
    )
    provider_name: Mapped[str] = mapped_column(String(200), nullable=False)
    port_name: Mapped[str] = mapped_column(String(200), nullable=False)

    service_category: Mapped[str] = mapped_column(String(100), default="CLEARANCE_FEE")  # CLEARANCE_QUOTE_SERVICE_CATEGORY code
    container_type: Mapped[str] = mapped_column(String(50), default="40HQ")
    unit_price: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="EGP", nullable=False)

    effective_from: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    effective_to: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
