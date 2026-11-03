"""
HS Code Regulatory Requirements Model (Regulatory Matrix)
"""

from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text

from database.database import Base


class HsCodeRegulatoryRequirement(Base):
    __tablename__ = "hs_code_regulatory_requirements"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    hs_code = Column(String(20), nullable=False, index=True)
    agency_code = Column(String(30), nullable=False, index=True)
    agency_name_ar = Column(String(255), nullable=False)
    agency_name_en = Column(String(255), nullable=False)
    stage_timing = Column(String(50), nullable=False, default="PRE_ARRIVAL")
    required_documents = Column(Text, nullable=True)  # JSON-encoded list or comma-separated string
    inspection_type = Column(String(50), nullable=True)  # PHYSICAL_INSPECTION, DOCUMENTARY_CHECK, LAB_SAMPLING
    regulatory_notes = Column(Text, nullable=True)
    is_mandatory = Column(Boolean, nullable=False, default=True)

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
