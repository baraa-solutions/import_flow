from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Float,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

class InlandTransportBooking(Base):
    """
    Stage 8: TR-01 Inland Transport Coordination Model
    تنسيق وحجز سيارات وسائقي النقل الداخلي للمخزن وتتبع زمن الخروج والوصول
    """
    __tablename__ = "inland_transport_bookings"

    transport_id = Column(Integer, primary_key=True, index=True)
    transport_code = Column(String(50), unique=True, index=True, nullable=False) # e.g. TR-2026-0001

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    waybill_number = Column(String(100), nullable=False) # رقم بوليصة النقل البري / إذن التحميل
    booking_date = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Carrier / Transport Company
    carrier_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    carrier_name = Column(String(255), nullable=False)

    # Truck & Driver details
    truck_plate_number = Column(String(50), nullable=False) # رقم لوحة الشاحنة
    truck_type = Column(String(100), default="FLATBED", nullable=False)
    driver_name = Column(String(100), nullable=False)
    driver_phone = Column(String(50), nullable=False)
    driver_national_id = Column(String(50), nullable=True)
    container_numbers = Column(String(255), nullable=True) # e.g. "MSCU1234567, TGHU7654321"

    # Route & Schedule
    pickup_port_location = Column(String(200), nullable=False) # ميناء وموقع الشحن
    destination_warehouse = Column(String(200), nullable=False) # المستودع الوجهة
    planned_departure_at = Column(DateTime, nullable=False) # موعد التحميل والخروج المخطط
    actual_departure_at = Column(DateTime, nullable=True) # موعد الخروج الفعلي من بوابة الميناء
    expected_arrival_at = Column(DateTime, nullable=False) # موعد الوصول المتوقع للمخزن
    actual_arrival_at = Column(DateTime, nullable=True) # موعد الوصول الفعلي للمخزن

    # Financials
    transport_fare_egp = Column(Float, default=0.0, nullable=False) # نولون النقل البري

    # Status & Notes
    status = Column(String(50), default="Booking Confirmed", nullable=False) # Booking Confirmed, Dispatched, In Transit, Arrived at Warehouse, Delivered
    tracking_notes = Column(Text, nullable=True)

    # Audit Trail & Soft Delete
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationships
    import_file = relationship("ImportFile", backref="inland_transport_bookings")
    carrier = relationship("ExternalServiceProvider", foreign_keys=[carrier_id])
