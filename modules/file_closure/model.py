from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile

class ImportFileClosureRecord(Base):
    """
    Phase 10 File Closure & Historical Archival Model (BP-040)
    Tracks the final verification checklist, archival metadata, and closure certificate for import files.
    """
    __tablename__ = "file_closure_records"

    closure_id = Column(Integer, primary_key=True, index=True)
    closure_code = Column(String(50), unique=True, index=True, nullable=False) # e.g. CLR-2026-0001

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False)
    
    # BP-040 Verification Checklist JSON
    # Schema: {"docs_verified": true, "customs_cleared": true, "warehouse_received": true, "landed_cost_settled": true, "tasks_closed": true}
    closure_checklist = Column(JSON, default=dict, nullable=False)
    
    auditor_name = Column(String(100), default="Internal Auditor", nullable=False)
    archive_location = Column(String(100), default="Digital Archive Vault - 2026", nullable=False)
    archival_notes = Column(Text, nullable=True)

    status = Column(String(50), default="Closed", index=True) # Closed, Archived

    is_active = Column(Boolean, default=True, index=True)
    closed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationships
    import_file = relationship("ImportFile", backref="file_closure_records")
