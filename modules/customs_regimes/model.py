"""
SQLAlchemy Model for Egyptian Customs Special & Suspended Duty Regimes
(النظم الجمركية الخاصة والمعلقة للرسوم الجمركية)
Covers:
- TEMPORARY_ADMISSION (سماح مؤقت)
- DRAWBACK (دروباك - رد الضرائب والرسوم)
- FREE_ZONE (مناطق حرة)
- CUSTOMS_WAREHOUSE (مستودعات جمركية / إيداع)
- TRANSIT (ترانزيت)
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


class CustomsSpecialRegime(Base):
    """
    Tracks customs suspended duty regimes, bank letters of guarantee,
    provisional cash deposits/escrows, statutory re-export deadlines,
    and drawback settlement reconciliation under Egyptian Customs Law No. 207 of 2020.
    """

    __tablename__ = "customs_special_regimes"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    regime_code = Column(String(50), nullable=False, unique=True, index=True)
    import_file_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    shipment_id = Column(Integer, nullable=True)

    # Regime Classification
    # TEMPORARY_ADMISSION, DRAWBACK, FREE_ZONE, CUSTOMS_WAREHOUSE, TRANSIT
    regime_type = Column(String(50), nullable=False, index=True)

    # Status: DRAFT, ACTIVE, SETTLED, CLOSED, EXPIRED, DEFAULTED
    status = Column(
        String(30),
        nullable=False,
        default="ACTIVE",
        server_default=text("'ACTIVE'"),
        index=True,
    )

    # Customs Reference
    customs_office = Column(String(100), nullable=True)
    release_form_number = Column(String(100), nullable=True)
    release_date = Column(Date, nullable=True)

    # Guarantee & Escrow Details
    # LETTER_OF_GUARANTEE, CASH_DEPOSIT, INSURANCE_POLICY, PROMISSORY_NOTE
    guarantee_type = Column(String(50), nullable=True)
    guarantee_reference = Column(String(100), nullable=True)
    guarantee_bank = Column(String(100), nullable=True)
    guarantee_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    guarantee_currency = Column(
        String(10),
        nullable=False,
        default="EGP",
        server_default=text("'EGP'"),
    )
    guarantee_issue_date = Column(Date, nullable=True)
    guarantee_expiry_date = Column(Date, nullable=True)

    # Re-export & Drawback Reconciliation
    re_export_deadline = Column(Date, nullable=True)
    actual_re_export_date = Column(Date, nullable=True)
    re_export_export_declaration_no = Column(String(100), nullable=True)
    drawback_reconciliation_ref = Column(String(100), nullable=True)
    drawback_refund_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    reconciled_date = Column(Date, nullable=True)
    is_settled = Column(Boolean, nullable=False, default=False, server_default=text("0"))

    # Operational Notes
    notes = Column(Text, nullable=True)

    # Audit & Soft Delete
    is_deleted = Column(Boolean, nullable=False, default=False, server_default=text("0"), index=True)
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
    created_by_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    updated_by_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
