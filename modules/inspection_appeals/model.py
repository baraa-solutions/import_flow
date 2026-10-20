from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


class InspectionAppeal(Base):
    """
    Inspection Appeal Model (Laboratory & Regulatory Appeals Lifecycle).
    Tracks regulatory authority appeals, progression from 1st appeal to triplicate sample,
    laboratory assignment, committee hearings, and official letter references.
    """
    __tablename__ = "inspection_appeals"

    # Primary Key & Business Code
    appeal_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    appeal_code = Column(String(50), unique=True, index=True, nullable=False)  # e.g. APP-2026-00001

    # Linked Entities
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    clearance_id = Column(Integer, ForeignKey("customs_clearance_records.customs_clearance_id"), nullable=True, index=True)

    # Authority & Sampling Details
    regulatory_authority = Column(String(50), nullable=False, index=True)  # GOEIC, NFSA, EDA, NTRA, ATOMIC_ENERGY
    sample_number = Column(String(100), nullable=True, index=True)
    sample_draw_date = Column(DateTime, nullable=True)

    # Initial Test Assessment
    initial_test_result = Column(String(50), nullable=False)  # CONFORMING, NON_CONFORMING_VISUAL, NON_CONFORMING_CHEMICAL, NON_CONFORMING_MICROBIAL
    rejection_reason = Column(Text, nullable=True)

    # Appeal Tier & Escalation Progression
    appeal_tier = Column(String(50), default="FIRST_APPEAL", nullable=False)  # FIRST_APPEAL, SECOND_APPEAL, TRIPLICATE_SAMPLE
    appeal_submission_date = Column(DateTime, nullable=True)
    appeal_committee_date = Column(DateTime, nullable=True)
    triplicate_lab_assigned = Column(String(150), nullable=True)

    # Committee Outcome & Official Letters
    appeal_result = Column(String(50), default="PENDING", nullable=False)  # PENDING, OVERTURNED_CONFORMING, UPHELD_REJECTED
    official_letter_ref = Column(String(100), nullable=True)
    notes = Column(Text, nullable=True)

    # Audit Trail & Soft-Delete
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    import_file = relationship("ImportFile", backref="inspection_appeals", foreign_keys=[import_file_id])
    clearance = relationship("CustomsClearanceRecord", backref="inspection_appeals", foreign_keys=[clearance_id])
