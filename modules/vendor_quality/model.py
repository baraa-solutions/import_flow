"""
SQLAlchemy Model for Pre-Shipment Inspection (PSI) and Vendor Quality Rating
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
from database.database import Base


class VendorQualityAndPSI(Base):
    """
    Stores Pre-Shipment Inspection (PSI) reports from international inspection
    agencies (SGS, BV, Cotecna) and evaluates vendor performance rating scorecards.
    """

    __tablename__ = "vendor_quality_and_psi"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    assessment_code = Column(String(50), nullable=False, unique=True, index=True)

    vendor_id = Column(
        Integer, ForeignKey("suppliers.supplier_id", ondelete="SET NULL"), nullable=True, index=True
    )
    vendor_name = Column(String(255), nullable=False)

    purchase_order_id = Column(
        Integer, ForeignKey("purchase_orders.po_id", ondelete="SET NULL"), nullable=True, index=True
    )
    import_file_id = Column(
        Integer, ForeignKey("import_files.import_file_id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Inspection details
    inspection_agency = Column(
        String(50), nullable=False
    )  # SGS, BUREAU_VERITAS, COTECNA, TUV, INTERTEK, INTERNAL_QA, OTHER
    psi_certificate_number = Column(String(100), nullable=True)
    inspection_date = Column(Date, nullable=True)
    psi_result = Column(
        String(30), nullable=False, default="PENDING", server_default=text("'PENDING'")
    )  # PENDING, PASSED, PASSED_WITH_CONDITIONS, FAILED, WAIVED

    defects_count = Column(Integer, nullable=False, default=0, server_default=text("0"))
    critical_defects_count = Column(Integer, nullable=False, default=0, server_default=text("0"))
    inspection_certificate_file = Column(String(500), nullable=True)

    # Scorecard Pillars (0.0 - 100.0)
    quality_score = Column(Float, nullable=False, default=100.0, server_default=text("100.0"))
    delivery_timeliness_score = Column(Float, nullable=False, default=100.0, server_default=text("100.0"))
    documentation_accuracy_score = Column(Float, nullable=False, default=100.0, server_default=text("100.0"))
    compliance_score = Column(Float, nullable=False, default=100.0, server_default=text("100.0"))

    overall_vendor_rating = Column(Float, nullable=False, default=100.0, server_default=text("100.0"))
    rating_grade = Column(String(10), nullable=False, default="A", server_default=text("'A'"))  # A, B, C, D, F

    corrective_action_required = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    corrective_action_plan = Column(Text, nullable=True)
    inspector_notes = Column(Text, nullable=True)

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
        Index("ix_vendor_psi_vendor_result", "vendor_id", "psi_result"),
        Index("ix_vendor_psi_overall_rating", "overall_vendor_rating"),
    )
