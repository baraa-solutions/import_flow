from datetime import date, datetime, timezone
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


# ===========================================================================
# Wave 1 Customs Broker Advances & Official Settlement Receipts
# ===========================================================================
class CustomsBrokerAdvance(Base):
    __tablename__ = "customs_broker_advances"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    advance_code = Column(String(50), unique=True, index=True, nullable=False)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id", ondelete="CASCADE"), nullable=False, index=True)
    broker_id = Column(Integer, ForeignKey("external_service_providers.provider_id", ondelete="RESTRICT"), nullable=False, index=True)
    broker_name = Column(String(255), nullable=False)

    advance_amount = Column(Float, nullable=False, default=0.0)
    disbursement_date = Column(Date, nullable=False)
    payment_method = Column(String(50), nullable=False, default="BANK_TRANSFER")  # CASH, BANK_TRANSFER, CHECK
    settled_amount = Column(Float, nullable=False, default=0.0)
    remaining_balance = Column(Float, nullable=False, default=0.0)
    status = Column(String(30), nullable=False, default="OPEN")  # OPEN, PARTIALLY_SETTLED, SETTLED
    notes = Column(Text, nullable=True)

    # Soft delete & Audit fields
    is_active = Column(Boolean, nullable=False, default=True)
    created_by = Column(String(50), nullable=False, default="system")
    updated_by = Column(String(50), nullable=False, default="system")
    created_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    receipts = relationship(
        "BrokerSettlementReceipt",
        back_populates="advance",
        cascade="all, delete-orphan",
        order_by="BrokerSettlementReceipt.receipt_date.asc()",
    )
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
    broker = relationship("ExternalServiceProvider", foreign_keys=[broker_id])


class BrokerSettlementReceipt(Base):
    __tablename__ = "broker_settlement_receipts"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    advance_id = Column(Integer, ForeignKey("customs_broker_advances.id", ondelete="CASCADE"), nullable=False, index=True)

    # Receipt Type:
    # WHITE_RECEIPT_CUSTOMS_DUTIES (إيصال سداد جمركي أبيض)
    # RED_RECEIPT_EXAMINATION_INSPECTION (إيصال كشف ومعاينة أحمر)
    # PORT_AUTHORITY_RECEIPT (إيصال هيئة الميناء)
    # BROKER_SERVICE_FEE (فاتورة أتعاب التخليص الجمركي)
    # STORAGE_RECEIPT (إيصال رسوم تخزين وأرضيات)
    # OTHER_OFFICIAL_RECEIPT (إيصال رسمي آخر)
    receipt_type = Column(String(50), nullable=False)
    receipt_number = Column(String(100), nullable=False)
    receipt_date = Column(Date, nullable=False)
    issuing_entity = Column(String(150), nullable=False)

    amount = Column(Float, nullable=False, default=0.0)
    tax_withholding_rate = Column(Float, nullable=False, default=0.0)  # e.g. 0.01 for 1% WHT on fees
    tax_withheld_amount = Column(Float, nullable=False, default=0.0)
    net_amount = Column(Float, nullable=False, default=0.0)

    e_invoice_uuid = Column(String(100), nullable=True)
    is_official_receipt = Column(Boolean, nullable=False, default=True)
    verification_status = Column(String(30), nullable=False, default="PENDING")  # PENDING, VERIFIED, REJECTED
    notes = Column(Text, nullable=True)

    # Soft delete & Audit fields
    is_active = Column(Boolean, nullable=False, default=True)
    created_by = Column(String(50), nullable=False, default="system")
    updated_by = Column(String(50), nullable=False, default="system")
    created_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationship
    advance = relationship("CustomsBrokerAdvance", back_populates="receipts")


# ===========================================================================
# Legacy / Compatibility models for existing BrokerCustodyAdvance
# ===========================================================================
class BrokerCustodyAdvance(Base):
    __tablename__ = "broker_custody_advances"

    # Primary Key
    advance_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Reference Code
    advance_code = Column(String(50), unique=True, index=True, nullable=False)

    # Linkage to Import File & Broker
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    import_file_code = Column(String(50), nullable=True, index=True)
    broker_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True)
    broker_name = Column(String(255), nullable=False)

    # Financial Advance Details
    advance_amount = Column(Float, nullable=False, default=0.0)
    disbursement_date = Column(Date, nullable=False)
    payment_method = Column(String(50), nullable=False, default="BANK_TRANSFER")
    status = Column(String(50), nullable=False, default="OPEN")
    settled_amount = Column(Float, nullable=False, default=0.0)
    remaining_balance = Column(Float, nullable=False, default=0.0)
    notes = Column(Text, nullable=True)

    # Audit & Status
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    expense_items = relationship(
        "BrokerExpenseItem",
        back_populates="advance",
        cascade="all, delete-orphan",
        order_by="BrokerExpenseItem.item_id",
    )
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
    broker = relationship("ExternalServiceProvider", foreign_keys=[broker_id])


class BrokerExpenseItem(Base):
    __tablename__ = "broker_expense_items"

    # Primary Key
    item_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Foreign Key to Advance
    advance_id = Column(Integer, ForeignKey("broker_custody_advances.advance_id"), nullable=False, index=True)

    # Category & Documentation
    expense_category = Column(String(50), nullable=False)
    is_e_invoice_backed = Column(Boolean, default=False, nullable=False)
    e_invoice_uuid = Column(String(100), nullable=True, index=True)
    receipt_reference = Column(String(100), nullable=True)

    # Amounts & WHT (Form 41)
    amount = Column(Float, nullable=False, default=0.0)
    tax_withholding_rate = Column(Float, default=0.01, nullable=False)
    tax_withheld_amount = Column(Float, default=0.0, nullable=False)
    net_settled_amount = Column(Float, default=0.0, nullable=False)

    # Approval Workflow
    approval_status = Column(String(50), default="PENDING", nullable=False)
    verified_by = Column(String(100), nullable=True)
    notes = Column(Text, nullable=True)

    # Audit & Status
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationship
    advance = relationship("BrokerCustodyAdvance", back_populates="expense_items")
