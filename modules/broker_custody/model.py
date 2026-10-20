from datetime import date, datetime, timezone
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


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
    payment_method = Column(String(50), nullable=False, default="BANK_TRANSFER")  # CASH, BANK_TRANSFER, CHECK
    status = Column(String(50), nullable=False, default="OPEN")  # OPEN, PARTIALLY_SETTLED, SETTLED
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
    # Categories:
    # OFFICIAL_DUTIES_TAXES, PORT_AUTHORITY_FEES, LAB_TESTING_FEES,
    # HANDLING_AND_PORTERAGE, INSPECTION_TRANSPORT, SUNDRY_PETTY_CASH

    is_e_invoice_backed = Column(Boolean, default=False, nullable=False)
    e_invoice_uuid = Column(String(100), nullable=True, index=True)
    receipt_reference = Column(String(100), nullable=True)

    # Amounts & WHT (Form 41)
    amount = Column(Float, nullable=False, default=0.0)
    tax_withholding_rate = Column(Float, default=0.01, nullable=False)  # default 0.01 for 1% W-41
    tax_withheld_amount = Column(Float, default=0.0, nullable=False)
    net_settled_amount = Column(Float, default=0.0, nullable=False)

    # Approval Workflow
    approval_status = Column(String(50), default="PENDING", nullable=False)  # PENDING, APPROVED, REJECTED
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
