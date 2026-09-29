"""
SQLAlchemy Models for Smart Shipment Experience Guide (دليل خبرة المنتج والشحنة الذكي)
Module: KB-GUIDE-012
Institutional Memory for Logistics & Customs Knowledge + Autonomous Learning Engine
"""
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    JSON,
)
from sqlalchemy.orm import relationship

from database.database import Base


class GuideEntry(Base):
    """
    Main Guide Entry / Institutional Memory Record
    Supports both HUMAN_AUTHORED and SYSTEM_INFERRED knowledge
    """
    __tablename__ = "guide_entries"

    entry_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    entry_type = Column(String(30), nullable=False, default="alert")  # alert, required_document, task, info
    severity = Column(String(20), nullable=False, default="info")     # info, warning, critical, positive
    department = Column(String(100), nullable=True)                  # department / originating team
    expires_at = Column(DateTime, nullable=True)                     # optional expiry date for regulation deprecation
    upvotes = Column(Integer, default=0, nullable=False)             # helpful feedback counter
    created_by = Column(String(100), default="System", nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Autonomous Learning Engine (Section 5A) Fields
    source_type = Column(String(30), default="HUMAN_AUTHORED", nullable=False)  # HUMAN_AUTHORED, SYSTEM_INFERRED
    status = Column(String(30), default="ACTIVE", nullable=False)               # ACTIVE, CONFIRMED, ARCHIVED, REJECTED
    pattern_category = Column(String(50), nullable=True)                       # DELIVERY_RELIABILITY, TRANSIT_TIME_ACCURACY, RECONCILIATION_FAILURES, COST_VARIANCE, SEASONAL_EFFECTS, DOCUMENTATION_RISK
    confidence_score = Column(Float, nullable=True)                            # 0.0 to 1.0
    confidence_level = Column(String(20), nullable=True)                       # LOW, MEDIUM, HIGH
    sample_size = Column(Integer, nullable=True)                              # Observed shipment count
    evidence_summary = Column(Text, nullable=True)                             # Comparative statistics summary
    contributing_files_json = Column(Text, nullable=True)                      # JSON list of contributing Import Files
    reason_why = Column(Text, nullable=True)                                   # Why this pattern was inferred
    first_detected_at = Column(DateTime, nullable=True)
    last_recalculated_at = Column(DateTime, nullable=True)
    confirmed_by = Column(String(100), nullable=True)
    confirmed_at = Column(DateTime, nullable=True)
    rejected_by = Column(String(100), nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    rejection_reason = Column(Text, nullable=True)
    # Single-language storage: system-inferred entries render title/content/evidence_summary/reason_why from a code
    msg_code = Column(String(80), nullable=True)
    msg_params = Column(JSON, nullable=True)

    # Relationships
    scopes = relationship("GuideEntryScope", back_populates="guide_entry", cascade="all, delete-orphan", lazy="joined")
    audit_logs = relationship("AutonomousPatternAuditLog", back_populates="guide_entry")


class GuideEntryScope(Base):
    """
    Scope condition for Guide Entry matching (Multi-Scope AND logic)
    """
    __tablename__ = "guide_entry_scopes"

    scope_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    guide_entry_id = Column(Integer, ForeignKey("guide_entries.entry_id", ondelete="CASCADE"), nullable=False, index=True)
    scope_type = Column(String(50), nullable=False)  # hs_code, product_category, destination_port, supplier, shipping_line, etc.
    scope_value = Column(String(150), nullable=False)

    # Relationships
    guide_entry = relationship("GuideEntry", back_populates="scopes")


class AutonomousPatternAuditLog(Base):
    """
    Audit Log for Autonomous Reference Engine state changes and recalculations
    """
    __tablename__ = "autonomous_pattern_audit_logs"

    log_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    entry_id = Column(Integer, ForeignKey("guide_entries.entry_id", ondelete="SET NULL"), nullable=True, index=True)
    pattern_key = Column(String(150), index=True, nullable=False)
    trigger_import_file_id = Column(Integer, nullable=True)
    action = Column(String(50), nullable=False)  # DETECTED_NEW, CONFIDENCE_UPDATED, AUTO_RETIRED, HUMAN_PROMOTED, HUMAN_REJECTED
    previous_confidence = Column(Float, nullable=True)
    new_confidence = Column(Float, nullable=True)
    sample_size = Column(Integer, nullable=False, default=0)
    change_summary = Column(Text, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    guide_entry = relationship("GuideEntry", back_populates="audit_logs")


Index("idx_guide_entry_scopes_type_val", GuideEntryScope.scope_type, GuideEntryScope.scope_value)
Index("idx_guide_entries_source_status", GuideEntry.source_type, GuideEntry.status)
Index("idx_guide_entries_pattern_category", GuideEntry.pattern_category)
