from datetime import datetime, timezone, date
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Text,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
)
from sqlalchemy.orm import relationship

from database.database import Base


class ShippingEvaluationSession(Base):
    """
    BP-007 Shipping Scenarios Evaluation Session Model
    Stores multi-carrier evaluation studies for estimated transit time and warehouse arrival calculation.
    """

    __tablename__ = "shipping_evaluation_sessions"

    session_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_code = Column(String(50), unique=True, index=True, nullable=False)
    title = Column(String(200), nullable=True)

    cargo_ready_date = Column(Date, nullable=False, default=date.today)
    pick_up_address = Column(String(500), nullable=True)
    port_of_loading_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True)
    port_of_discharge_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True)

    avg_form4_days = Column(Integer, default=5, nullable=False)
    avg_clearance_days = Column(Integer, default=7, nullable=False)

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    po_id = Column(Integer, ForeignKey("purchase_orders.po_id"), nullable=True)
    project_id = Column(Integer, ForeignKey("projects.project_id"), nullable=True)

    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    items = relationship(
        "ShippingScenarioItem",
        back_populates="session",
        cascade="all, delete-orphan",
    )


class ShippingScenarioItem(Base):
    """
    BP-007 Shipping Scenario Item Model
    Stores individual carrier voyage options for a shipping evaluation session.
    """

    __tablename__ = "shipping_scenario_items"

    item_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("shipping_evaluation_sessions.session_id"), nullable=False)

    provider_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    provider_name = Column(String(150), nullable=False)
    customs_broker_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    customs_broker_name = Column(String(150), nullable=True)
    vessel_name = Column(String(150), nullable=False)
    voyage_number = Column(String(50), nullable=True)

    port_of_loading_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True)
    port_of_discharge_id = Column(Integer, ForeignKey("transport_locations.location_id"), nullable=True)
    pol_name = Column(String(150), nullable=True)
    pod_name = Column(String(150), nullable=True)

    sailing_date = Column(Date, nullable=False)
    estimated_arrival_date = Column(Date, nullable=False)
    expected_line_delay_days = Column(Integer, default=0, nullable=False)

    is_excluded_from_average = Column(Boolean, default=False, nullable=False)
    is_recommended = Column(Boolean, default=False, nullable=False)
    is_selected = Column(Boolean, default=False, nullable=False)

    risk_level = Column(String(50), default="Low", nullable=False)  # Low, Medium, High
    notes = Column(Text, nullable=True)

    # BP-008 Freight Quotations integration fields
    free_time_days = Column(Integer, default=14, nullable=False)
    quotation_currency = Column(String(10), default="USD", nullable=False)
    total_quotation_amount = Column(Float, default=0.0, nullable=False)

    container_40ft_applicable = Column(Boolean, default=False, nullable=False)
    container_40ft_price = Column(Float, default=0.0, nullable=False)
    container_40ft_currency = Column(String(10), default="USD", nullable=False)
    container_40ft_qty = Column(Integer, default=0, nullable=False)

    container_20ft_applicable = Column(Boolean, default=False, nullable=False)
    container_20ft_price = Column(Float, default=0.0, nullable=False)
    container_20ft_currency = Column(String(10), default="USD", nullable=False)
    container_20ft_qty = Column(Integer, default=0, nullable=False)

    lcl_cbm_applicable = Column(Boolean, default=False, nullable=False)
    lcl_cbm_price = Column(Float, default=0.0, nullable=False)
    lcl_cbm_currency = Column(String(10), default="USD", nullable=False)
    lcl_cbm_qty = Column(Float, default=0.0, nullable=False)

    express_courier_applicable = Column(Boolean, default=False, nullable=False)
    express_courier_price = Column(Float, default=0.0, nullable=False)
    express_courier_currency = Column(String(10), default="USD", nullable=False)

    eur_atr_applicable = Column(Boolean, default=False, nullable=False)
    eur_atr_price = Column(Float, default=0.0, nullable=False)
    eur_atr_currency = Column(String(10), default="USD", nullable=False)

    solas_vgm_applicable = Column(Boolean, default=False, nullable=False)
    solas_vgm_price = Column(Float, default=0.0, nullable=False)
    solas_vgm_currency = Column(String(10), default="USD", nullable=False)

    vgm_notification_applicable = Column(Boolean, default=False, nullable=False)
    vgm_notification_price = Column(Float, default=0.0, nullable=False)
    vgm_notification_currency = Column(String(10), default="USD", nullable=False)

    telex_release_applicable = Column(Boolean, default=False, nullable=False)
    telex_release_price = Column(Float, default=0.0, nullable=False)
    telex_release_currency = Column(String(10), default="USD", nullable=False)

    insurance_applicable = Column(Boolean, default=False, nullable=False)
    insurance_price = Column(Float, default=0.0, nullable=False)
    insurance_currency = Column(String(10), default="USD", nullable=False)

    booking_cancellation_applicable = Column(Boolean, default=False, nullable=False)
    booking_cancellation_price = Column(Float, default=0.0, nullable=False)
    booking_cancellation_currency = Column(String(10), default="USD", nullable=False)

    ics2_filing_fee_applicable = Column(Boolean, default=False, nullable=False)
    ics2_filing_fee_price = Column(Float, default=0.0, nullable=False)
    ics2_filing_fee_currency = Column(String(10), default="USD", nullable=False)

    others_fee_applicable = Column(Boolean, default=False, nullable=False)
    others_fee_price = Column(Float, default=0.0, nullable=False)
    others_fee_currency = Column(String(10), default="USD", nullable=False)

    document_fees_applicable = Column(Boolean, default=False, nullable=False)
    document_fees_price = Column(Float, default=0.0, nullable=False)
    document_fees_currency = Column(String(10), default="USD", nullable=False)

    waiver_letter_fee_applicable = Column(Boolean, default=False, nullable=False)
    waiver_letter_fee_price = Column(Float, default=0.0, nullable=False)
    waiver_letter_fee_currency = Column(String(10), default="USD", nullable=False)

    dthc_applicable = Column(Boolean, default=False, nullable=False)
    dthc_price = Column(Float, default=0.0, nullable=False)
    dthc_currency = Column(String(10), default="USD", nullable=False)

    storage_per_week_applicable = Column(Boolean, default=False, nullable=False)
    storage_per_week_price = Column(Float, default=0.0, nullable=False)
    storage_per_week_currency = Column(String(10), default="USD", nullable=False)

    extra_day_storage_applicable = Column(Boolean, default=False, nullable=False)
    extra_day_storage_price = Column(Float, default=0.0, nullable=False)
    extra_day_storage_currency = Column(String(10), default="USD", nullable=False)

    # Customs clearance quotation integration fields
    clearance_fee_applicable = Column(Boolean, default=False, nullable=False)
    clearance_fee_price = Column(Float, default=0.0, nullable=False)
    clearance_fee_currency = Column(String(10), default="EGP", nullable=False)

    inspection_fee_applicable = Column(Boolean, default=False, nullable=False)
    inspection_fee_price = Column(Float, default=0.0, nullable=False)
    inspection_fee_currency = Column(String(10), default="EGP", nullable=False)

    inland_transport_fee_applicable = Column(Boolean, default=False, nullable=False)
    inland_transport_fee_price = Column(Float, default=0.0, nullable=False)
    inland_transport_fee_currency = Column(String(10), default="EGP", nullable=False)

    port_expenses_applicable = Column(Boolean, default=False, nullable=False)
    port_expenses_price = Column(Float, default=0.0, nullable=False)
    port_expenses_currency = Column(String(10), default="EGP", nullable=False)

    session = relationship("ShippingEvaluationSession", back_populates="items")
