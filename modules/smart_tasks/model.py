"""
SQLAlchemy Models for Smart Task Management & Reminder Engine (Feature 2.4 & 2.5)
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, Index, JSON
from database.database import Base


class SmartTask(Base):
    __tablename__ = "smart_tasks"

    task_id = Column(Integer, primary_key=True, index=True)
    task_code = Column(String(50), unique=True, index=True, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    task_type = Column(String(50), default="Manual To-Do", nullable=False)  # System Generated or Manual To-Do
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id", ondelete="SET NULL"), nullable=True, index=True)
    import_file_code = Column(String(100), nullable=True)
    phase_name = Column(String(100), nullable=True)
    assigned_user = Column(String(100), default="Kamal", nullable=False)
    priority = Column(String(50), default="Medium", nullable=False)  # Low, Medium, High, Critical
    reminder_type = Column(String(100), default="General Reminder", nullable=False)
    due_date = Column(String(50), nullable=True)
    reminder_date = Column(String(50), nullable=True)
    status = Column(String(50), default="Pending", nullable=False)  # Pending, In Progress, Completed, Cancelled
    notes = Column(Text, nullable=True)
    attachment_url = Column(String(255), nullable=True)
    is_auto_closed = Column(Boolean, default=False)
    # Single-language storage: system tasks carry a message code + params (title/description/notes = English render)
    msg_code = Column(String(80), nullable=True)
    msg_params = Column(JSON, nullable=True)
    step_code = Column(String(50), nullable=True)  # lifecycle step this system task belongs to
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    __table_args__ = (
        Index("idx_smart_tasks_status", "status"),
        Index("idx_smart_tasks_type", "task_type"),
        Index("idx_smart_tasks_import_file", "import_file_id"),
        Index("idx_smart_tasks_step_code", "import_file_id", "step_code"),
    )
