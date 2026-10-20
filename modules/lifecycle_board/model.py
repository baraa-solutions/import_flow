"""
SQLAlchemy Model for Shipment Stage Activity & Lifecycle Board
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Boolean, JSON, Index, DateTime, ForeignKey
from database.database import Base


class ShipmentStageActivity(Base):
    __tablename__ = "shipment_stage_activity"

    id = Column(Integer, primary_key=True, index=True)
    import_file_code = Column(String(50), nullable=False, index=True)
    step_code = Column(String(50), nullable=False, index=True) # e.g. STEP_01 to STEP_21
    status = Column(String(50), nullable=False, default="In-Progress") # In-Progress, Completed, On-Hold, Pending, Skipped, Reference recorded – pending full documentation
    started_at = Column(String(50), nullable=True)
    completed_at = Column(String(50), nullable=True)
    assigned_user = Column(String(100), nullable=True)
    action_data = Column(Text, nullable=True) # JSON String with step parameters
    notes = Column(Text, nullable=True)
    msg_code = Column(String(80), nullable=True)  # system message code for notes (English render in notes)
    msg_params = Column(JSON, nullable=True)
    completion_type = Column(String(30), nullable=True) # real, auto, skipped, bypassed

    __table_args__ = (
        Index("uq_shipment_stage_activity_file_step", "import_file_code", "step_code", unique=True),
    )


class StepConfig(Base):
    """
    Configurable Skip-Risk & Lifecycle Step Settings (Addendum: Section 10).
    Step skippability is never hardcoded; managed by authorized Manager role.
    """
    __tablename__ = "step_configs"

    id = Column(Integer, primary_key=True, index=True)
    step_code = Column(String(50), unique=True, nullable=False, index=True) # e.g. STEP_01 .. STEP_21
    step_name_ar = Column(String(200), nullable=False)
    step_name_en = Column(String(200), nullable=False)
    phase_id = Column(Integer, nullable=False, default=1)
    skip_policy = Column(String(50), nullable=False, default="blocked") # "blocked" | "dual_approval" | "single_approval"
    reason_required = Column(Boolean, nullable=False, default=True) # always True (non-configurable per 9.3/10.1)
    reason_categories = Column(JSON, nullable=False, default=list) # List[str]
    approver_roles = Column(JSON, nullable=False, default=lambda: ["Manager"]) # List[str], default ["Manager"]
    supports_pending_reference = Column(Boolean, nullable=False, default=False) # Section 10.4
    last_modified_by = Column(String(100), nullable=True)
    last_modified_at = Column(String(50), nullable=True)


class StepConfigAuditLog(Base):
    """
    Change control on classification rules themselves (Section 10.3).
    Tracks who changed the policy, from what to what, when, and why.
    """
    __tablename__ = "step_config_audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    step_code = Column(String(50), nullable=False, index=True)
    action = Column(String(50), nullable=False, default="UPDATE_POLICY")
    changed_by = Column(String(100), nullable=False) # user_id or username
    changed_at = Column(String(50), nullable=False)
    old_policy = Column(String(50), nullable=True)
    new_policy = Column(String(50), nullable=True)
    old_approver_roles = Column(JSON, nullable=True)
    new_approver_roles = Column(JSON, nullable=True)
    old_supports_pending_reference = Column(Boolean, nullable=True)
    new_supports_pending_reference = Column(Boolean, nullable=True)
    justification = Column(Text, nullable=False) # mandatory short justification


class PendingReferenceRecord(Base):
    """
    Partial/Reference-only registration (Section 10.4).
    Records reference number early while step remains incomplete for compliance.
    """
    __tablename__ = "pending_reference_records"

    id = Column(Integer, primary_key=True, index=True)
    import_file_code = Column(String(50), nullable=False, index=True)
    step_code = Column(String(50), nullable=False, index=True)
    reference_number = Column(String(100), nullable=False)
    reason_text = Column(Text, nullable=False)
    expected_completion_date = Column(String(50), nullable=True)
    registered_by = Column(String(100), nullable=True)
    registered_at = Column(String(50), nullable=False)
    status = Column(String(50), nullable=False, default="Pending Documentation") # Pending Documentation, Fulfilled, Cancelled


class ShipmentTimelineSnapshot(Base):
    """
    Central 25-stage operational timeline snapshot.
    Tracks planned vs actual dates, variance, SLA compliance, bottleneck flags,
    and sub-event audit linkages across the full shipment lifecycle.
    """
    __tablename__ = "shipment_timeline_snapshots"

    snapshot_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    stage_code = Column(String(50), nullable=False, index=True)  # STAGE_01 to STAGE_25
    stage_name_ar = Column(String(200), nullable=False)
    stage_name_en = Column(String(200), nullable=False)
    phase_number = Column(Integer, nullable=False, default=1)

    status = Column(String(50), nullable=False, default="PENDING")  # PENDING, IN_PROGRESS, COMPLETED, DELAYED, SKIPPED
    planned_date = Column(DateTime, nullable=True)
    actual_date = Column(DateTime, nullable=True)
    variance_days = Column(Integer, nullable=True, default=0)
    sla_days = Column(Integer, nullable=False, default=1)

    is_bottleneck = Column(Boolean, default=False, nullable=False)
    delay_reason = Column(Text, nullable=True)
    event_details_json = Column(JSON, nullable=True)

    completed_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        Index("uq_timeline_file_stage", "import_file_id", "stage_code", unique=True),
    )

