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


class ReexportDossier(Base):
    """
    ReexportDossier Model (table: reexport_dossiers)
    Full statutory workflow under Egyptian Customs Law 207/2020 (Article 37)
    for rejected imported cargo undergoing mandatory re-export or destruction.
    """
    __tablename__ = "reexport_dossiers"

    reexport_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    import_file_code = Column(String(50), nullable=False, index=True)

    # Rejection Decree & Authority
    rejection_authority = Column(String(150), nullable=False)  # GOIEC, NFSA, CAPQ, MOH, Atomic Energy
    rejection_decree_number = Column(String(100), nullable=False, index=True)
    rejection_date = Column(Date, nullable=False)
    legal_reexport_deadline = Column(Date, nullable=False)  # 30 days statutory deadline from rejection_date
    days_remaining_to_destruction = Column(Integer, nullable=False, default=30)
    reexport_reason = Column(Text, nullable=False)

    # Customs Outbound Process & Supervision
    customs_outbound_declaration_no = Column(String(100), nullable=True)  # رقم مظهر / بيان الصادر
    supervision_committee_formed = Column(Boolean, default=False, nullable=False)
    customs_officer_in_charge = Column(String(150), nullable=True)

    # Return Logistics & Shipping Details
    return_carrier_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True)
    return_booking_number = Column(String(100), nullable=True)
    outbound_bl_number = Column(String(100), nullable=True)
    container_numbers = Column(JSON, default=list, nullable=False)
    return_port_of_discharge = Column(String(150), nullable=True)

    # Financial Settlements: Duty Drawback & Supplier Credit Note
    duty_drawback_status = Column(String(50), default="PENDING_APPLICATION", nullable=False)  # PENDING_APPLICATION, APPROVED_REFUNDED, EXEMPTION_SUSPENDED
    duty_amount_refundable_egp = Column(Float, default=0.0, nullable=False)
    supplier_credit_note_status = Column(String(50), default="REQUESTED", nullable=False)  # REQUESTED, RECEIVED, ARBITRATION
    credit_note_amount_usd = Column(Float, default=0.0, nullable=False)

    # Operational Status
    status = Column(String(50), default="MANDATED", nullable=False)  # MANDATED, BOOKING_CONFIRMED, CUSTOMS_INSPECTED, LADEN_ON_BOARD, COMPLETED_CLOSED
    notes = Column(Text, nullable=True)

    # Audit & Soft-Delete Fields
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=True)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
    return_carrier = relationship("ExternalServiceProvider", foreign_keys=[return_carrier_id])

    def calculate_days_remaining(self, as_of_date: date = None) -> int:
        if as_of_date is None:
            as_of_date = date.today()
        if self.legal_reexport_deadline:
            remaining = (self.legal_reexport_deadline - as_of_date).days
            self.days_remaining_to_destruction = remaining
            return remaining
        return 0
