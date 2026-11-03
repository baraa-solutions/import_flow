from datetime import datetime, timezone, date
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    Float,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.demurrage_detention.model import DemurrageTracking


class ShipmentContainer(Base):
    """
    Independent Shipment Container Entity (DEV-OPS-01)
    Provides first-class relational tracking for individual containers across
    booking, shipping milestones, customs gate-out, demurrage/detention, and EIR return.
    """
    __tablename__ = "shipment_containers"

    # Primary Key
    container_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Business Identifiers
    container_number = Column(String(50), nullable=False, index=True)
    container_type = Column(String(50), nullable=False)  # e.g. 20GP, 40GP, 40HC, Reefer
    seal_number = Column(String(50), nullable=True)

    # Relational Links
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    booking_id = Column(Integer, ForeignKey("shipment_bookings.booking_id"), nullable=True, index=True)
    shipping_record_id = Column(Integer, ForeignKey("cargo_shipping_records.cargo_shipping_id"), nullable=True, index=True)
    demurrage_tracking_id = Column(Integer, ForeignKey("demurrage_trackings.tracking_id"), nullable=True, index=True)

    # Carrier / Transport Context
    carrier_name = Column(String(100), nullable=True)
    bill_of_lading_no = Column(String(100), nullable=True, index=True)

    # Milestone Dates
    gate_in_date = Column(DateTime, nullable=True)     # Origin port gate-in
    stuffing_date = Column(DateTime, nullable=True)    # Stuffing / loading
    discharge_date = Column(Date, nullable=True)       # POD vessel discharge
    gate_out_date = Column(Date, nullable=True)        # POD customs gate-out
    gate_out_timestamp = Column(DateTime, nullable=True)
    empty_return_date = Column(Date, nullable=True)    # Carrier depot return (EIR)
    eir_timestamp = Column(DateTime, nullable=True)
    customs_inspection_seal = Column(String(100), nullable=True)
    truck_plate_number = Column(String(50), nullable=True)

    # Weights & VGM
    tare_weight_kg = Column(Float, nullable=False, default=0.0)
    net_weight_kg = Column(Float, nullable=False, default=0.0)
    gross_weight_kg = Column(Float, nullable=False, default=0.0)
    vgm_weight_kg = Column(Float, nullable=False, default=0.0)
    vgm_status = Column(String(30), nullable=False, default="Pending")  # Pending, Verified
    vgm_ref_no = Column(String(50), nullable=True)

    # Demurrage & Detention Link
    demurrage_days = Column(Integer, nullable=False, default=0)
    detention_days = Column(Integer, nullable=False, default=0)
    storage_days = Column(Integer, nullable=False, default=0)
    demurrage_cost_fx = Column(Float, nullable=False, default=0.0)
    detention_cost_fx = Column(Float, nullable=False, default=0.0)
    storage_cost_egp = Column(Float, nullable=False, default=0.0)
    total_cost_egp = Column(Float, nullable=False, default=0.0)
    individual_demurrage_cost = Column(Float, nullable=False, default=0.0)
    currency = Column(String(10), nullable=False, default="USD")

    # Lifecycle Status & Return Info
    status = Column(String(50), nullable=False, default="Allocated", index=True)
    # Allocated, Loaded & Sealed, Gate In Origin, On Board, Discharged, Gate Out, At Warehouse, Returned Empty
    eir_number = Column(String(100), nullable=True)
    eir_condition_status = Column(String(50), nullable=True, default="Good")
    depot_name = Column(String(150), nullable=True)
    condition_at_return = Column(String(50), nullable=True, default="Good")  # Good, Damaged, Requires Cleaning
    notes = Column(Text, nullable=True)

    # Soft Delete & Audit Trail
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Relationships
    import_file = relationship("ImportFile", backref="shipment_containers")
    booking = relationship("ShipmentBooking", backref="shipment_containers")
    shipping_record = relationship("CargoShippingRecord", backref="shipment_containers")
    demurrage_tracking = relationship("DemurrageTracking", backref="shipment_containers")
