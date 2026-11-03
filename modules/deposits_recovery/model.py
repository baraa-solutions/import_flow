"""
SQLAlchemy Model for Refundable Deposits Ledger & Guarantee Releases
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


class RefundableDeposit(Base):
    """
    Tracks all refundable guarantees and cash securities:
    - Shipping line container demurrage/damage deposits
    - Customs duty temporary escrow / security
    - Bank Letters of Guarantee (LG)
    - Port Authority security deposits
    """

    __tablename__ = "refundable_deposits_ledger"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    deposit_code = Column(String(50), nullable=False, unique=True, index=True)

    import_file_id = Column(
        Integer, ForeignKey("import_files.import_file_id", ondelete="SET NULL"), nullable=True, index=True
    )

    deposit_type = Column(
        String(50), nullable=False, index=True
    )  # SHIPPING_LINE_CONTAINER, CUSTOMS_DUTY_SECURITY, BANK_LETTER_OF_GUARANTEE, PORT_AUTHORITY_SECURITY, OTHER
    beneficiary_type = Column(
        String(30), nullable=False
    )  # CARRIER, CUSTOMS, PORT, BANK, OTHER
    beneficiary_name = Column(String(255), nullable=False)

    container_number = Column(String(50), nullable=True, index=True)
    eir_number = Column(String(100), nullable=True)
    eir_return_date = Column(Date, nullable=True)

    deposit_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    currency = Column(String(10), nullable=False, default="EGP", server_default=text("'EGP'"))

    paid_date = Column(Date, nullable=True)
    payment_reference = Column(String(100), nullable=True)

    bank_lg_number = Column(String(100), nullable=True)
    bank_lg_issuing_bank = Column(String(150), nullable=True)
    bank_lg_expiry_date = Column(Date, nullable=True)

    recovery_status = Column(
        String(30), nullable=False, default="PENDING", server_default=text("'PENDING'")
    )  # PENDING, SUBMITTED, CLAIM_APPROVED, REFUNDED, FORFEITED, LG_RELEASED

    refunded_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    refund_date = Column(Date, nullable=True)
    refund_reference = Column(String(100), nullable=True)

    deduction_amount = Column(Float, nullable=False, default=0.0, server_default=text("0.0"))
    deduction_reason = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)

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
        Index("ix_refundable_file_status", "import_file_id", "recovery_status"),
        Index("ix_refundable_type_status", "deposit_type", "recovery_status"),
    )
