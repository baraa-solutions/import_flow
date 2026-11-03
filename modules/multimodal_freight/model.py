"""
SQLAlchemy Model for Multimodal Freight Details (Air, LCL, Ro-Ro, Bulk)
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
from database.database import Base


class MultimodalFreightDetails(Base):
    """
    Multimodal freight specifics entity.
    Stores operational and financial parameters for non-standard containerized cargo,
    including Air Freight (AWB, THC), LCL consolidation (CBM, CFS), Ro-Ro vehicles, and Bulk cargo.
    """

    __tablename__ = "multimodal_freight_details"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    shipment_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    transport_mode = Column(
        String(20),
        nullable=False,
        default="AIR",
        server_default=text("'AIR'"),
    )  # AIR, LCL, RORO, BULK

    # Air Freight Specifics
    awb_number = Column(String(100), nullable=True)
    airline_code = Column(String(20), nullable=True)
    flight_number = Column(String(50), nullable=True)
    terminal_handling_charges = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))

    # LCL (Less than Container Load) Specifics
    lcl_cbm = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))
    lcl_rate_per_cbm = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))
    lcl_cfs_fee = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))  # CFS handling fee

    # Ro-Ro (Roll-on/Roll-off) Specifics
    roro_vehicle_type = Column(String(100), nullable=True)  # TRUCK, PASSENGER_CAR, HEAVY_MACHINERY
    roro_dimensions_cbm = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))

    # Bulk Cargo Specifics
    bulk_cargo_type = Column(String(100), nullable=True)  # GRAIN, COAL, LIQUID_CHEMICALS, STEEL
    bulk_tonnage = Column(Float, nullable=True, default=0.0, server_default=text("0.0"))
    special_handling_notes = Column(Text, nullable=True)

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
        Index("ix_multimodal_shipment_mode", "shipment_id", "transport_mode"),
    )
