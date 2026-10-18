"""
Pydantic Schemas for Smart Task Management & Reminder Engine (Feature 2.4 & 2.5)
"""

from typing import Any, Dict, Optional, List
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class SmartTaskBase(BaseModel):
    title: str = Field(..., min_length=2, description="Task Title")
    description: Optional[str] = None
    task_type: str = Field("Manual To-Do", description="System Generated or Manual To-Do")
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    phase_name: Optional[str] = None
    assigned_user: Optional[str] = Field(None, description="Assigned User")
    priority: str = Field("Medium", description="Low, Medium, High, Critical")
    reminder_type: str = Field("General Reminder", description="Supplier, Bank, Shipping, Broker, Document, ETA, General")
    due_date: Optional[str] = None
    reminder_date: Optional[str] = None
    status: str = Field("Pending", description="Pending, In Progress, Completed, Cancelled")
    notes: Optional[str] = None
    attachment_url: Optional[str] = None


class SmartTaskCreate(SmartTaskBase):
    pass


class SmartTaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    task_type: Optional[str] = None
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    phase_name: Optional[str] = None
    assigned_user: Optional[str] = None
    priority: Optional[str] = None
    reminder_type: Optional[str] = None
    due_date: Optional[str] = None
    reminder_date: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None
    attachment_url: Optional[str] = None


class SmartTaskResponse(SmartTaskBase):
    task_id: int
    task_code: str
    is_auto_closed: bool
    is_active: bool
    msg_code: Optional[str] = None
    msg_params: Optional[Dict[str, Any]] = None
    step_code: Optional[str] = None
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


class SmartTaskSummaryMetrics(BaseModel):
    total_tasks: int
    todays_tasks: int
    pending_tasks: int
    upcoming_shipments: int
    arriving_this_week: int
    eta_changes: int
    waiting_for_payment: int
    waiting_for_form4: int
    pending_requirements: int
    high_priority_alerts: int


class ReminderEngineResponse(BaseModel):
    """Feature 2.5 — Reminder Engine: Due, Overdue & Upcoming tasks"""
    target_date: str
    overdue: List[SmartTaskResponse]
    due_today: List[SmartTaskResponse]
    due_this_week: List[SmartTaskResponse]
    overdue_count: int
    due_today_count: int
    due_this_week_count: int
