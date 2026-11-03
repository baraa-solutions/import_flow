"""
SQLAlchemy Model for Logistics Operational Rules
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
    ForeignKey,
    UniqueConstraint,
    Index,
    func,
    text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class LogisticsOperationalRule(Base):
    """
    Logistics Operational Rules Table.
    Stores domain rules, legal thresholds, and operational constraints
    with verification audit trails and conservative fallbacks.
    """

    __tablename__ = "logistics_operational_rules"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    rule_key = Column(String(100), nullable=False, index=True)
    rule_name_ar = Column(Text, nullable=False)
    rule_name_en = Column(Text, nullable=False)

    scope_type = Column(
        String(20),
        nullable=False,
        default="GLOBAL",
        server_default=text("'GLOBAL'"),
    )  # GLOBAL / SHIPPING_LINE / PORT / COMMODITY / CONTAINER_TYPE
    scope_id = Column(Integer, nullable=True)

    conservative_default = Column(Text, nullable=True)
    verified_value = Column(Text, nullable=True)
    value_unit = Column(
        String(20), nullable=False
    )  # DAYS / HOURS / PERCENTAGE / KG / BOOLEAN / MONTHS / CURRENCY / TEXT

    enforcement_level = Column(
        String(10),
        nullable=False,
        default="WARNING",
        server_default=text("'WARNING'"),
    )  # INFO / WARNING / BLOCKING

    verification_status = Column(
        String(15),
        nullable=False,
        default="UNVERIFIED",
        server_default=text("'UNVERIFIED'"),
    )  # UNVERIFIED / VERIFIED / REJECTED

    verified_by_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True
    )
    verified_on = Column(DateTime, nullable=True)
    evidence_ref = Column(Text, nullable=True)
    source_ref = Column(Text, nullable=True)

    effective_from = Column(Date, nullable=True)
    effective_to = Column(Date, nullable=True)
    review_due_on = Column(Date, nullable=True)

    version_id = Column(Integer, nullable=False, default=1, server_default=text("1"))
    is_latest = Column(Boolean, nullable=False, default=True, server_default=text("1"))
    is_active = Column(Boolean, nullable=False, default=True, server_default=text("1"))

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
        UniqueConstraint("rule_key", "version_id", name="uq_rule_key_version"),
        Index("ix_rule_lookup", "rule_key", "scope_type", "scope_id", "is_latest"),
    )
