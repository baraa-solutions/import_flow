"""
Customs Consultation Engine & Broker Price Lists Models (BP-009)
"""

from datetime import datetime, date, timezone
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from database.database import Base


class ClearanceExpenseType(Base):
    """
    Master Catalog for Clearance & Logistics Expense Types (تكويد أنواع المصروفات والخدمات).
    Categorized into Clearance Fees, Procedures/Approvals, Inland Transport, Port/Handling, Other.
    """

    __tablename__ = "clearance_expense_types"

    expense_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    expense_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    name_ar: Mapped[str] = mapped_column(String(200), nullable=False)
    name_en: Mapped[str] = mapped_column(String(200), nullable=True)
    category: Mapped[str] = mapped_column(
        String(100), nullable=False, default="CLEARANCE_FEES"
    )  # Clearance Fees, Procedures & Approvals, Inland Transport, Port & Handling, Other Fees
    default_unit: Mapped[str] = mapped_column(
        String(100), nullable=False, default="PER_INVOICE"
    )  # Per Invoice, Per Ton, Per Container 20ft, Per Container 40ft, Per Vehicle, Per Inspection, Per Trip, Fixed
    default_currency: Mapped[str] = mapped_column(String(10), default="EGP", nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class BrokerPriceList(Base):
    """
    Broker Price List / Tariff header (قائمة أسعار مخلص جمركي / مورد خدمة).
    Supports historical versions and effective dates so past studies remain unaffected.
    """

    __tablename__ = "broker_price_lists"

    price_list_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    price_list_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    broker_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True
    )
    broker_name: Mapped[str] = mapped_column(String(200), nullable=False)
    port_name: Mapped[str] = mapped_column(String(150), nullable=True)  # e.g. ميناء الإسكندرية والدخيلة
    effective_from: Mapped[date] = mapped_column(Date, nullable=False, default=date.today)
    effective_to: Mapped[date] = mapped_column(Date, nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    cloned_from_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("broker_price_lists.price_list_id"), nullable=True
    )
    cloned_from_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    items: Mapped[list["BrokerPriceListItem"]] = relationship(
        "BrokerPriceListItem",
        back_populates="price_list",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class BrokerPriceListItem(Base):
    """
    Line item inside a Broker Price List.
    """

    __tablename__ = "broker_price_list_items"

    item_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    price_list_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("broker_price_lists.price_list_id", ondelete="CASCADE"), nullable=False, index=True
    )
    expense_type_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("clearance_expense_types.expense_id"), nullable=True, index=True
    )
    expense_name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    unit_type: Mapped[str] = mapped_column(String(100), nullable=False)
    standard_price: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="EGP", nullable=False)
    min_price: Mapped[float] = mapped_column(Float, nullable=True)
    max_price: Mapped[float] = mapped_column(Float, nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    price_list: Mapped["BrokerPriceList"] = relationship(
        "BrokerPriceList", back_populates="items"
    )


class CustomsConsultationSession(Base):
    """
    Master study session for Customs Consultation with Broker (BP-009).
    Tracks document checklist, regulatory approvals, customs calculations,
    and the full itemized Customs Broker Quote breakdown.
    """

    __tablename__ = "customs_consultation_sessions"

    consultation_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    consultation_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    
    # Linked Broker (Customs Broker from external_service_providers)
    broker_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True
    )
    broker_name: Mapped[str] = mapped_column(String(200), nullable=False)
    broker_contact_person: Mapped[str] = mapped_column(String(100), nullable=True)
    broker_price_list_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("broker_price_lists.price_list_id"), nullable=True
    )

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

    # Overall Status: 'Pending Review', 'In Progress', 'Action Required', 'Clearance Ready', 'Blocked'
    overall_status: Mapped[str] = mapped_column(
        String(50), default="Pending Review", nullable=False, index=True
    )
    has_blocking_issues: Mapped[bool] = mapped_column(Boolean, default=False)
    readiness_percentage: Mapped[float] = mapped_column(Float, default=0.0)

    # Financial & Notes
    estimated_duties_egp: Mapped[float] = mapped_column(Float, default=0.0)
    total_broker_fees_egp: Mapped[float] = mapped_column(Float, default=0.0)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    cloned_from_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("customs_consultation_sessions.consultation_id"), nullable=True
    )
    cloned_from_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    updated_by: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Audit & Soft Delete
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    # Relationship to Checklist Items
    checklist_items: Mapped[list["CustomsChecklistItem"]] = relationship(
        "CustomsChecklistItem",
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # Relationship to Broker Quote Breakdown Items (Historical Snapshot)
    broker_quote_items: Mapped[list["CustomsBrokerQuoteItem"]] = relationship(
        "CustomsBrokerQuoteItem",
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class CustomsChecklistItem(Base):
    """
    Individual Document or Regulatory Approval Item in Customs Checklist (BP-009).
    """

    __tablename__ = "customs_checklist_items"

    item_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    consultation_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("customs_consultation_sessions.consultation_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    
    document_type: Mapped[str] = mapped_column(String(100), nullable=False)
    hs_code: Mapped[str] = mapped_column(String(20), nullable=True)
    
    is_required: Mapped[bool] = mapped_column(Boolean, default=True)
    required_text: Mapped[str] = mapped_column(String(50), nullable=True, default="✓")
    is_blocking_shipment: Mapped[bool] = mapped_column(Boolean, default=True)
    responsible_party: Mapped[str] = mapped_column(String(100), default="Customs Broker")
    
    status: Mapped[str] = mapped_column(String(50), default="Pending", nullable=False)
    
    received_date: Mapped[date] = mapped_column(Date, nullable=True)
    verified_date: Mapped[date] = mapped_column(Date, nullable=True)
    
    regulatory_agency: Mapped[str] = mapped_column(String(100), nullable=True)
    remarks: Mapped[str] = mapped_column(Text, nullable=True)
    corrective_action_required: Mapped[str] = mapped_column(Text, nullable=True)

    session: Mapped["CustomsConsultationSession"] = relationship(
        "CustomsConsultationSession", back_populates="checklist_items"
    )


class CustomsBrokerQuoteItem(Base):
    """
    Individual Broker Quote / Clearance Expense Item attached to a Consultation Session.
    Saved as a frozen snapshot so future price list updates never alter past studies.
    """

    __tablename__ = "customs_broker_quote_items"

    quote_item_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    consultation_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("customs_consultation_sessions.consultation_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    expense_type_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("clearance_expense_types.expense_id"), nullable=True
    )
    expense_name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    unit_type: Mapped[str] = mapped_column(String(100), nullable=False, default="Per Invoice")
    unit_price: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="EGP", nullable=False)
    qty: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    is_applicable: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    total_amount: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    notes: Mapped[str] = mapped_column(Text, nullable=True)

    session: Mapped["CustomsConsultationSession"] = relationship(
        "CustomsConsultationSession", back_populates="broker_quote_items"
    )
