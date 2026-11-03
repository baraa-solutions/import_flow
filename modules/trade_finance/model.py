"""
Trade Finance Models (LC, CAD, Advance Payments, Bank Charges & FX Hedging)
"""

from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


class ImportFinanceInstrument(Base):
    __tablename__ = "import_finance_instruments"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    instrument_type = Column(String(30), nullable=False)  # LC, CAD, ADVANCE_PAYMENT, OPEN_ACCOUNT
    instrument_number = Column(String(100), unique=True, index=True, nullable=False)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id", ondelete="CASCADE"), nullable=False, index=True)
    issuing_bank = Column(String(150), nullable=False)
    advising_bank = Column(String(150), nullable=True)
    currency = Column(String(10), nullable=False, default="USD")
    amount = Column(Float, nullable=False, default=0.0)
    issue_date = Column(Date, nullable=True)
    expiry_date = Column(Date, nullable=True)
    shipment_deadline = Column(Date, nullable=True)
    presentation_period_days = Column(Integer, nullable=False, default=21)
    payment_terms = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="DRAFT")  # DRAFT, ISSUED, ACCEPTED, SETTLED, CANCELLED
    tolerance_percentage = Column(Float, nullable=False, default=0.0)
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
    charges = relationship(
        "LcBankCharge",
        back_populates="instrument",
        cascade="all, delete-orphan",
        order_by="LcBankCharge.debit_date.asc()",
    )
    fx_records = relationship(
        "FxHedgingAndVariance",
        back_populates="instrument",
        cascade="all, delete-orphan",
        order_by="FxHedgingAndVariance.booking_date.asc()",
    )
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])


class LcBankCharge(Base):
    __tablename__ = "lc_bank_charges"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    finance_instrument_id = Column(Integer, ForeignKey("import_finance_instruments.id", ondelete="CASCADE"), nullable=False, index=True)
    charge_type = Column(String(50), nullable=False)  # ISSUANCE_COMMISSION, AMENDMENT_FEE, SWIFT_CHARGE, etc.
    currency = Column(String(10), nullable=False, default="EGP")
    amount = Column(Float, nullable=False, default=0.0)
    amount_egp = Column(Float, nullable=False, default=0.0)
    debit_date = Column(Date, nullable=False)
    debit_account = Column(String(50), nullable=True)
    swift_reference = Column(String(100), nullable=True)
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
    instrument = relationship("ImportFinanceInstrument", back_populates="charges")


class FxHedgingAndVariance(Base):
    __tablename__ = "fx_hedging_and_variance"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    finance_instrument_id = Column(Integer, ForeignKey("import_finance_instruments.id", ondelete="CASCADE"), nullable=False, index=True)
    foreign_currency = Column(String(10), nullable=False, default="USD")
    original_amount = Column(Float, nullable=False, default=0.0)
    booking_date = Column(Date, nullable=False)
    booking_rate = Column(Float, nullable=False, default=1.0)
    booking_total_egp = Column(Float, nullable=False, default=0.0)
    settlement_date = Column(Date, nullable=True)
    settlement_rate = Column(Float, nullable=True)
    settlement_total_egp = Column(Float, nullable=True)
    hedging_contract_ref = Column(String(100), nullable=True)
    variance_amount_egp = Column(Float, nullable=False, default=0.0)
    variance_nature = Column(String(20), nullable=False, default="NEUTRAL")  # UNFAVORABLE_LOSS, FAVORABLE_GAIN, NEUTRAL
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
    instrument = relationship("ImportFinanceInstrument", back_populates="fx_records")
