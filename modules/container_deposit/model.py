from datetime import datetime, timezone, date
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    Float,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class ContainerDepositLedger(Base):
    """
    ContainerDepositLedger Model (table: container_deposit_ledgers)
    Tracks shipping line container security deposits paid in Egypt,
    EIR (Equipment Interchange Receipt) empty return logging,
    30-day statutory refund overdue alert countdowns, condition damage/cleaning deductions,
    and refund receipt reconciliation.
    """
    __tablename__ = "container_deposit_ledgers"

    deposit_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    
    # Carrier Information
    carrier_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True)
    carrier_name = Column(String(200), nullable=False)

    # Container Information
    container_number = Column(String(50), nullable=False, index=True)
    container_type = Column(String(50), nullable=False)  # 20ft DRY, 40ft DRY, 40ft HC, 20ft Reefer, etc.

    # Deposit Payment
    deposit_amount_egp = Column(Float, nullable=False)
    payment_reference = Column(String(100), nullable=True)  # Check number, bank voucher or carrier receipt no
    payment_date = Column(Date, nullable=False)

    # Empty Return EIR Information
    eir_return_number = Column(String(100), nullable=True)  # رقم إيصال استرجاع الفارغ
    eir_return_date = Column(Date, nullable=True)
    container_condition = Column(String(50), default="SOUND_CLEAN", nullable=False)  # SOUND_CLEAN, DAMAGE_CLAIMED, CLEANING_FEE_DEDUCTED
    deduction_amount_egp = Column(Float, default=0.0, nullable=False)

    # Refund Reconciliation & Status
    refund_status = Column(String(50), default="PENDING_RETURN", nullable=False)  # PENDING_RETURN, CLAIM_SUBMITTED, OVERDUE_30_DAYS, REFUNDED_FULL, REFUNDED_PARTIAL
    refund_cheque_or_transfer_no = Column(String(100), nullable=True)
    refund_received_date = Column(Date, nullable=True)
    days_overdue = Column(Integer, default=0, nullable=False)

    # Disputes & Operational Notes
    notes = Column(Text, nullable=True)
    dispute_history = Column(JSON, default=list, nullable=False)

    # Audit & Soft-Delete Fields
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=True)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
    carrier = relationship("ExternalServiceProvider", foreign_keys=[carrier_id])

    def refresh_overdue_status(self, as_of_date: date = None) -> int:
        """
        Egyptian shipping regulation standard: Container deposit must be refunded
        within 30 days of returning the empty container (EIR date).
        """
        if as_of_date is None:
            as_of_date = date.today()

        if self.eir_return_date and self.refund_status not in ("REFUNDED_FULL", "REFUNDED_PARTIAL"):
            days_since_return = (as_of_date - self.eir_return_date).days
            if days_since_return > 30:
                self.refund_status = "OVERDUE_30_DAYS"
                self.days_overdue = days_since_return - 30
            else:
                self.days_overdue = 0
                if self.refund_status == "OVERDUE_30_DAYS":
                    self.refund_status = "CLAIM_SUBMITTED"
        elif self.refund_status in ("REFUNDED_FULL", "REFUNDED_PARTIAL"):
            self.days_overdue = 0

        return self.days_overdue
