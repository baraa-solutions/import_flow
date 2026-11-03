"""
SQLAlchemy Model for Preferential Trade Agreements & Origin Verifications
(الاتفاقيات التفضيلية والتحقق من شهادات المنشأ والأمانات الجمركية المؤقتة)
Covers:
- Trade Agreements (EUR1, GAFTA, AGADIR, COMESA, EFTA, TURKEY, MERCOSUR, OTHER)
- Certificate Types (EUR.1, EUR_MED, FORM_A, ARAB_LEAGUE, CERTIFICATE_OF_ORIGIN)
- Origin Criteria (WHOLLY_OBTAINED, VALUE_ADDED, SUFFICIENT_PROCESSING)
- Direct Transport Compliance (الشحن المباشر)
- Original vs Copy Submission & Provisional Escrow Deposit Tracking (أمانة عدم إحضار أصل شهادة المنشأ)
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


class PreferentialOriginVerification(Base):
    """
    Manages preferential certificate of origin checks, validity tracking,
    direct transport compliance, and provisional customs escrow deposits
    demanded by Egyptian Customs Authority when original origin certificate is pending.
    """

    __tablename__ = "preferential_origin_verifications"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    verification_code = Column(String(50), nullable=False, unique=True, index=True)
    import_file_id = Column(
        Integer,
        ForeignKey("import_files.import_file_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    shipment_id = Column(Integer, nullable=True)

    # Agreement details
    # EUR1, GAFTA, AGADIR, COMESA, EFTA, TURKEY, MERCOSUR, OTHER
    agreement_name = Column(String(50), nullable=False, index=True)
    # EUR.1, EUR_MED, FORM_A, ARAB_LEAGUE, CERTIFICATE_OF_ORIGIN
    certificate_type = Column(String(50), nullable=False)
    certificate_number = Column(String(100), nullable=False, index=True)
    issuing_country = Column(String(100), nullable=False)
    issuing_authority = Column(String(150), nullable=True)
    issuing_date = Column(Date, nullable=False)
    validity_months = Column(Integer, nullable=False, default=4, server_default=text("4"))
    expiry_date = Column(Date, nullable=True)

    # Submission & Verification Status
    # ORIGINAL_SUBMITTED, COPY_SUBMITTED, CUSTOMS_ESCHEATED, VERIFIED_ELECTRONICALLY, REJECTED
    submission_status = Column(
        String(50),
        nullable=False,
        default="COPY_SUBMITTED",
        server_default=text("'COPY_SUBMITTED'"),
        index=True,
    )
    has_original_received = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    original_received_date = Column(Date, nullable=True)

    # Provisional Escrow Tracking (الأمانات الجمركية المؤقتة عند تأخر الأصل)
    provisional_escrow_required = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    provisional_escrow_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    provisional_escrow_receipt = Column(String(100), nullable=True)
    provisional_escrow_deadline = Column(Date, nullable=True)
    provisional_escrow_refunded = Column(Boolean, nullable=False, default=False, server_default=text("0"))
    refund_date = Column(Date, nullable=True)

    # Compliance with preferential rules
    direct_transport_compliant = Column(Boolean, nullable=False, default=True, server_default=text("1"))
    rules_of_origin_criterion = Column(String(50), nullable=True)  # WHOLLY_OBTAINED, VALUE_ADDED, SUFFICIENT_PROCESSING
    verification_notes = Column(Text, nullable=True)

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
