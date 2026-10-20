from datetime import date, datetime, timezone
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


class BankForm4Record(Base):
    __tablename__ = "bank_form4_records"

    # Primary Key
    form4_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Import File Linkage
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    import_file_code = Column(String(50), nullable=False, index=True)

    # Bank Details
    bank_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True)
    bank_name = Column(String(200), nullable=False)
    bank_branch = Column(String(150), nullable=True)
    bank_officer_name = Column(String(150), nullable=True)

    # Financing & FX
    financing_mode = Column(String(50), nullable=False, default="CAD")  # CAD, LC, ADVANCE, OPEN_ACCOUNT
    currency = Column(String(10), nullable=False, default="USD")  # USD, EUR, EGP
    fx_amount = Column(Float, nullable=False, default=0.0)
    fx_allotment_status = Column(String(50), nullable=False, default="PENDING")  # PENDING, ALLOTTED, TRANSFERRED
    swift_reference = Column(String(100), nullable=True, index=True)

    # Form 4 Registration & Nafeza
    form4_number = Column(String(100), nullable=True, unique=True, index=True)
    form4_issue_date = Column(Date, nullable=True)
    nafeza_transmission_status = Column(String(50), nullable=False, default="AWAITING_BANK")  # AWAITING_BANK, TRANSMITTED, VALUE_MISMATCH, ACCEPTED

    # Financing Delay Tracking
    bank_delay_days = Column(Integer, default=0, nullable=False)
    daily_financing_cost = Column(Float, default=0.0, nullable=False)
    total_financing_delay_cost = Column(Float, default=0.0, nullable=False)

    notes = Column(Text, nullable=True)

    # Audit & Status
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id], backref="bank_form4_records")
    bank = relationship("ExternalServiceProvider", foreign_keys=[bank_id])
