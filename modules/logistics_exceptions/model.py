"""
SQLAlchemy Model for Logistics Exceptions & Operational Disruptions
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


class LogisticsException(Base):
    """
    Tracks supply chain disruptions:
    - Vessel roll-over & blank sailing
    - Port congestion & customs hold
    - Valuation / tariff appraisal dispute
    - ACID validity alignment & automated delay KPI suspension
    """

    __tablename__ = "logistics_exceptions"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    exception_code = Column(String(50), nullable=False, unique=True, index=True)

    import_file_id = Column(
        Integer, ForeignKey("import_files.import_file_id", ondelete="SET NULL"), nullable=True, index=True
    )
    shipment_id = Column(Integer, nullable=True)

    exception_type = Column(String(50), nullable=False, index=True)
    severity = Column(
        String(20), nullable=False, default="MEDIUM", server_default=text("'MEDIUM'")
    )  # LOW, MEDIUM, HIGH, CRITICAL

    title_ar = Column(String(255), nullable=False)
    title_en = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)

    delay_impact_days = Column(Integer, nullable=False, default=0, server_default=text("0"))

    # ACID alignment
    acid_number = Column(String(50), nullable=True)
    acid_original_expiry = Column(Date, nullable=True)
    acid_adjusted_expiry = Column(Date, nullable=True)
    acid_impact_status = Column(
        String(30), nullable=False, default="NOT_AFFECTED", server_default=text("'NOT_AFFECTED'")
    )  # NOT_AFFECTED, ACTION_REQUIRED, EXTENSION_REQUESTED, SUSPENDED, RESOLVED

    # Delay KPI suspension
    delay_kpi_suspended = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    suspension_reason = Column(Text, nullable=True)

    # Valuation & Tariff dispute
    valuation_dispute_amount = Column(Float, nullable=True)
    valuation_original_customs_val = Column(Float, nullable=True)
    valuation_declared_val = Column(Float, nullable=True)
    appeal_status = Column(String(30), nullable=True)  # NONE, PENDING_APPEAL, COMMITTEE_HEARING, APPEAL_ACCEPTED, APPEAL_REJECTED
    resolution_strategy = Column(Text, nullable=True)

    status = Column(
        String(30), nullable=False, default="OPEN", server_default=text("'OPEN'")
    )  # OPEN, UNDER_REVIEW, MITIGATED, RESOLVED, CLOSED
    resolved_at = Column(DateTime, nullable=True)
    resolved_by_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True
    )

    is_active = Column(Boolean, nullable=False, default=True, server_default=text("1"))
    is_deleted = Column(Boolean, nullable=False, default=False, server_default=text("0"))

    created_by_user_id = Column(
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
        Index("ix_exceptions_import_file_status", "import_file_id", "status"),
        Index("ix_exceptions_type_severity", "exception_type", "severity"),
    )
