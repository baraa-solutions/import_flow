from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


class CustodyReleaseDossier(Base):
    """
    Custody Release Dossier Model (Warehouse Custody & Under-Bond Release).
    Tracks shipments released under official customs undertaking / custody,
    enforcing warehouse dispatch locks until laboratory clearance is granted,
    and recording lead seals, judicial officers, and breach tracking.
    """
    __tablename__ = "custody_release_dossiers"

    # Primary Key & Business Code
    custody_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    custody_code = Column(String(50), unique=True, index=True, nullable=False)  # e.g. CUS-2026-00001

    # Linked Entities
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    warehouse_id = Column(Integer, nullable=True, index=True)
    warehouse_address = Column(String(255), nullable=True)

    # Official Custody Undertaking & Officers
    custody_undertaking_number = Column(String(100), nullable=False, unique=True, index=True)  # إقرار / تعهد التحفظ
    judicial_officer_name = Column(String(150), nullable=True)  # مأمور الضبط القضائي الجمركي

    # Lead Seals & Transport Authorization
    lead_seals_count = Column(Integer, default=0, nullable=False)
    lead_seal_numbers = Column(JSON, default=list, nullable=False)  # JSON list of strings e.g. ["SEAL-01", "SEAL-02"]
    transport_permit_number = Column(String(100), nullable=True)  # تصريح النقل

    # Status & Warehouse Lock Enforcement
    status = Column(String(50), default="RELEASED_UNDER_CUSTODY", nullable=False)  # RELEASED_UNDER_CUSTODY, FROZEN_IN_WAREHOUSE, SAMPLE_CLEAR_FINAL_RELEASE, BREACH_REPORTED
    lock_active = Column(Boolean, default=True, nullable=False)  # Prevents warehouse dispensing until final lab clearance

    # Final Clearance & Lab Sign-Off
    final_clearance_letter_number = Column(String(100), nullable=True)  # رقم خطاب الإفراج النهائي
    release_approved_at = Column(DateTime, nullable=True)

    # Breach & Operational Notes
    breach_reason = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)

    # Audit Trail & Soft-Delete
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    import_file = relationship("ImportFile", backref="custody_release_dossiers", foreign_keys=[import_file_id])
