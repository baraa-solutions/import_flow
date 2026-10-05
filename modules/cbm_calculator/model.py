from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Text,
    Boolean,
    DateTime,
    ForeignKey,
)
from sqlalchemy.orm import relationship

from database.database import Base


class CBMCalculation(Base):
    """
    BP-004 CBM Calculation Model
    Stores Cargo Measurement Engine calculation sessions (Standalone or linked to Project / PO).
    """

    __tablename__ = "cbm_calculations"

    calc_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    calc_code = Column(String(50), unique=True, index=True, nullable=False)
    title = Column(String(200), nullable=True)

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.project_id"), nullable=True)
    po_id = Column(Integer, ForeignKey("purchase_orders.po_id"), nullable=True)

    total_qty = Column(Integer, default=0, nullable=False)
    total_cbm = Column(Float, default=0.0, nullable=False)
    total_gross_weight_kg = Column(Float, default=0.0, nullable=False)
    total_volumetric_weight_kg = Column(Float, default=0.0, nullable=False)
    air_chargeable_weight_kg = Column(Float, default=0.0, nullable=False)

    recommended_shipping_method = Column(String(50), nullable=True)
    recommended_container_type = Column(String(50), nullable=True)
    recommended_container_count = Column(Integer, default=0, nullable=False)
    # SHIPMENT_MODE code (AIR / SEA); NULL on legacy rows = unknown
    shipment_mode = Column(String(10), nullable=True)

    notes = Column(Text, nullable=True)
    is_stackable = Column(Boolean, default=True, nullable=True)
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
        "CBMCalculationItem",
        back_populates="calculation",
        cascade="all, delete-orphan",
    )


class CBMCalculationItem(Base):
    """
    Line item package measurement within a CBM calculation session.
    """

    __tablename__ = "cbm_calculation_items"

    item_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    calc_id = Column(
        Integer, ForeignKey("cbm_calculations.calc_id"), nullable=False
    )

    package_type = Column(String(50), default="Carton", nullable=False)
    quantity = Column(Integer, nullable=False, default=1)

    length_cm = Column(Float, nullable=False)
    width_cm = Column(Float, nullable=False)
    height_cm = Column(Float, nullable=False)
    gross_weight_per_unit_kg = Column(Float, nullable=False, default=0.0)

    total_cbm = Column(Float, default=0.0, nullable=False)
    volumetric_weight_kg = Column(Float, default=0.0, nullable=False)
    total_gross_weight_kg = Column(Float, default=0.0, nullable=False)
    is_stackable = Column(Boolean, default=True, nullable=False)

    calculation = relationship("CBMCalculation", back_populates="items")
