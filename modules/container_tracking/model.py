"""
SQLAlchemy Models for Container Tracking & Demurrage Charges
"""

from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    func,
    text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class ContainerLifecycleUnit(Base):
    """
    Individual container lifecycle tracking unit.
    Tracks ISO specifications, tare/payload/gross/VGM weights, milestone dates,
    and operational lifecycle statuses.
    """

    __tablename__ = "container_lifecycle_units"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    container_number = Column(String(50), nullable=False, index=True)
    seal_number = Column(String(50), nullable=True)
    iso_type = Column(String(20), nullable=False, default="40HC", server_default=text("'40HC'"))

    tare_weight = Column(Float, nullable=True)
    payload_weight = Column(Float, nullable=True)
    gross_weight = Column(Float, nullable=True)
    vgm_weight = Column(Float, nullable=True)

    discharge_date = Column(Date, nullable=True)
    gate_out_held_date = Column(Date, nullable=True)  # خروج تحت التحفظ
    empty_returned_date = Column(Date, nullable=True)  # إرجاع الفارغ

    status = Column(
        String(30),
        nullable=False,
        default="ON_VESSEL",
        server_default=text("'ON_VESSEL'"),
    )  # ON_VESSEL, DISCHARGED, GATE_OUT_HELD, RETURNED_EMPTY, DAMAGED

    shipment_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
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

    # Relationships
    demurrage_charges = relationship(
        "ContainerDemurrageCharge",
        back_populates="container",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    __table_args__ = (
        Index("ix_container_units_shipment_status", "shipment_id", "status"),
    )


class ContainerDemurrageCharge(Base):
    """
    Individual container demurrage and free time calculation charges.
    Tracks allowable free time days, demurrage end dates, daily penalty rates,
    and actual return delays.
    """

    __tablename__ = "container_demurrage_charges"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    container_id = Column(
        Integer,
        ForeignKey("container_lifecycle_units.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    free_time_days = Column(Integer, nullable=False, default=14, server_default=text("14"))
    free_time_end_date = Column(Date, nullable=True)
    daily_demurrage_rate = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    actual_return_date = Column(Date, nullable=True)
    days_overdue = Column(Integer, nullable=False, default=0, server_default=text("0"))
    total_demurrage_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    currency = Column(String(10), nullable=False, default="USD", server_default=text("'USD'"))
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

    # Relationships
    container = relationship(
        "ContainerLifecycleUnit",
        back_populates="demurrage_charges",
    )
