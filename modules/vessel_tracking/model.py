from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Float,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking


class Vessel(Base):
    """
    Vessel Master Record (LOG-TRACK-001)
    Stores merchant vessel identifiers, flag, capacity, and owning shipping line.
    """
    __tablename__ = "vessels"

    vessel_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    vessel_name = Column(String(150), nullable=False, index=True)
    imo_number = Column(String(20), unique=True, index=True, nullable=True)
    mmsi_number = Column(String(20), unique=True, index=True, nullable=True)
    call_sign = Column(String(30), nullable=True)
    flag_country = Column(String(50), default="Panama", nullable=False)
    vessel_type = Column(String(50), default="Container Ship", nullable=False)
    built_year = Column(Integer, nullable=True)
    capacity_teu = Column(Integer, nullable=True)
    shipping_line_name = Column(String(150), nullable=True, index=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=True)

    # Relationships
    positions = relationship("VesselPositionLog", back_populates="vessel", cascade="all, delete-orphan")
    trackings = relationship("ShipmentVesselTracking", back_populates="vessel")


class VesselPositionLog(Base):
    """
    Vessel Position Telemetry Log (LOG-TRACK-002)
    Stores real-time AIS/Satellite telemetry coordinates, speed, heading, and remaining distance.
    """
    __tablename__ = "vessel_position_logs"

    position_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    vessel_id = Column(Integer, ForeignKey("vessels.vessel_id"), nullable=False, index=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    speed_knots = Column(Float, default=14.5, nullable=False)
    course_degrees = Column(Float, default=0.0, nullable=False)
    heading_degrees = Column(Float, default=0.0, nullable=False)
    nav_status = Column(String(50), default="Underway Using Engine", nullable=False)
    current_zone = Column(String(100), default="Open Sea", nullable=False)
    destination_port_code = Column(String(50), nullable=True)
    distance_remaining_nm = Column(Float, nullable=True)
    eta_predicted = Column(DateTime, nullable=True)
    source = Column(String(50), default="AIS_LIVE", nullable=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationship
    vessel = relationship("Vessel", back_populates="positions")


class ShipmentVesselTracking(Base):
    """
    Shipment Live Vessel Tracking Session (LOG-TRACK-003)
    Binds an ImportFile and ShipmentBooking to real-time vessel telemetry,
    calculating route progress percentage and delay alerts.
    """
    __tablename__ = "shipment_vessel_trackings"

    tracking_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    tracking_code = Column(String(50), unique=True, index=True, nullable=False)

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), unique=True, nullable=False, index=True)
    booking_id = Column(Integer, ForeignKey("shipment_bookings.booking_id"), nullable=True, index=True)
    vessel_id = Column(Integer, ForeignKey("vessels.vessel_id"), nullable=False, index=True)
    voyage_number = Column(String(50), nullable=True)

    pol_port_code = Column(String(50), nullable=False)  # e.g. CNSHA
    pol_port_name = Column(String(150), nullable=False)
    pod_port_code = Column(String(50), nullable=False)  # e.g. EGALY
    pod_port_name = Column(String(150), nullable=False)

    scheduled_departure = Column(DateTime, nullable=True)
    actual_departure = Column(DateTime, nullable=True)
    scheduled_arrival = Column(DateTime, nullable=True)
    estimated_arrival = Column(DateTime, nullable=True)
    actual_arrival = Column(DateTime, nullable=True)

    tracking_milestone = Column(String(50), default="In Transit", nullable=False, index=True)
    voyage_progress_pct = Column(Float, default=0.0, nullable=False)
    delay_hours = Column(Float, default=0.0, nullable=False)
    delay_severity = Column(String(20), default="ON_TIME", nullable=False)

    last_polled_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    route_waypoints = Column(JSON, default=list, nullable=False)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=True)

    # Relationships
    import_file = relationship("ImportFile", backref="vessel_tracking")
    booking = relationship("ShipmentBooking", backref="vessel_tracking")
    vessel = relationship("Vessel", back_populates="trackings")
