"""
Pydantic Schemas for Smart Email Listener (INT-EMAIL-010)
"""

from datetime import datetime, date
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, ConfigDict


class InboundEmailCreate(BaseModel):
    sender_email: str = Field(...)
    subject: str = Field(...)
    body_text: str = Field(..., description="نص الإيميل الكامل المستلم من التوكيل الملاحي")
    email_type: Optional[str] = "Arrival Notice"


class InboundEmailParsePreviewRequest(BaseModel):
    subject: str
    body_text: str


class ArrivalNoticeParseResult(BaseModel):
    extracted_bl_number: Optional[str] = None
    extracted_eta: Optional[date] = None
    extracted_vessel: Optional[str] = None
    extracted_voyage: Optional[str] = None
    extracted_containers: List[str] = []
    is_matched_file: bool = False
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    payment_task_created: bool = False
    task_id: Optional[int] = None
    summary_message: str
    email_id: Optional[int] = None
    sender_email: Optional[str] = None
    subject: Optional[str] = None
    shipment_title: Optional[str] = None
    match_reason: Optional[str] = None
    task_code: Optional[str] = None
    task_title: Optional[str] = None
    assigned_user: Optional[str] = "Finance Team"
    priority: Optional[str] = "High"
    due_date: Optional[str] = None


class InboundEmailLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    email_id: int
    sender_email: str
    subject: str
    body_text: str
    received_at: datetime
    email_type: str
    extracted_bl_number: Optional[str] = None
    extracted_eta: Optional[date] = None
    extracted_vessel: Optional[str] = None
    extracted_voyage: Optional[str] = None
    extracted_containers: Optional[str] = None
    import_file_id: Optional[int] = None
    processing_status: str
    task_id: Optional[int] = None
    notes: Optional[str] = None
    created_at: datetime
    msg_code: Optional[str] = None  # system message code of ``notes`` (English render in ``notes``)
    msg_params: Optional[Dict[str, Any]] = None


# ---------------------------------------------------------
# Email Settings Schemas
# ---------------------------------------------------------

class EmailSettingsBase(BaseModel):
    provider_type: str = Field("LOCAL_OUTLOOK", description="LOCAL_OUTLOOK, GMAIL, OUTLOOK, or CUSTOM")
    email_address: str = Field("", description="Email address, e.g. user@company.com")
    username: str = Field("", description="Username for authentication")
    imap_host: str = Field("outlook.office365.com", description="IMAP server hostname")
    imap_port: int = Field(993, description="IMAP server port")
    imap_use_ssl: bool = Field(True, description="Whether to use SSL for IMAP")
    smtp_host: str = Field("smtp.office365.com", description="SMTP server hostname")
    smtp_port: int = Field(587, description="SMTP server port")
    smtp_use_tls: bool = Field(True, description="Whether to use STARTTLS for SMTP")
    smtp_use_ssl: bool = Field(False, description="Whether to use direct SSL for SMTP")
    sender_display_name: str = Field("Sorour Logistics Operations", description="Display name for sent emails")
    auto_fetch_enabled: bool = Field(False, description="Enable automatic periodic polling")
    fetch_interval_minutes: int = Field(15, description="Polling interval in minutes")


class EmailSettingsCreate(EmailSettingsBase):
    password: Optional[str] = Field("LOCAL_OUTLOOK", description="Account password or App Password")


class EmailSettingsUpdate(BaseModel):
    provider_type: Optional[str] = None
    email_address: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    imap_host: Optional[str] = None
    imap_port: Optional[int] = None
    imap_use_ssl: Optional[bool] = None
    smtp_host: Optional[str] = None
    smtp_port: Optional[int] = None
    smtp_use_tls: Optional[bool] = None
    smtp_use_ssl: Optional[bool] = None
    sender_display_name: Optional[str] = None
    auto_fetch_enabled: Optional[bool] = None
    fetch_interval_minutes: Optional[int] = None


class EmailSettingsResponse(EmailSettingsBase):
    model_config = ConfigDict(from_attributes=True)

    settings_id: int
    has_password: bool = True
    last_sync_at: Optional[datetime] = None
    last_sync_status: Optional[str] = None
    last_sync_message: Optional[str] = None
    msg_code: Optional[str] = None  # system message code of ``last_sync_message``
    msg_params: Optional[Dict[str, Any]] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime


class EmailConnectionTestRequest(BaseModel):
    provider_type: str = "LOCAL_OUTLOOK"
    email_address: Optional[str] = ""
    username: Optional[str] = ""
    password: Optional[str] = ""
    imap_host: Optional[str] = "outlook.office365.com"
    imap_port: Optional[int] = 993
    imap_use_ssl: Optional[bool] = True
    smtp_host: Optional[str] = "smtp.office365.com"
    smtp_port: Optional[int] = 587
    smtp_use_tls: Optional[bool] = True
    smtp_use_ssl: Optional[bool] = False


class EmailConnectionTestResult(BaseModel):
    imap_connected: bool
    imap_message: str
    smtp_connected: bool
    smtp_message: str
    overall_success: bool
    details: Optional[str] = None


class InboxFetchRequest(BaseModel):
    max_emails: int = Field(20, ge=1, le=100, description="Max recent emails to inspect")
    folder: str = Field("INBOX", description="Mailbox folder name")
    only_unseen: bool = Field(False, description="Whether to filter by UNSEEN / unread only")


class InboxFetchResult(BaseModel):
    total_fetched: int
    matched_files_count: int
    tasks_created_count: int
    results: List[ArrivalNoticeParseResult] = []
    message: str


class OutboundEmailSendRequest(BaseModel):
    recipient_emails: List[str] = Field(..., min_length=1, description="List of recipient email addresses")
    subject: str = Field(...)
    body_text: str = Field(...)
    is_html: bool = Field(False, description="Send as HTML email if True")
    import_file_id: Optional[int] = None
    attachments: Optional[List[dict]] = None  # [{'filename': 'report.pdf', 'content_base64': '...'}]


class OutboundEmailSendResult(BaseModel):
    success: bool
    message: str
    sent_at: datetime
    recipients: List[str]


# ---------------------------------------------------------
# User Approval & Task Routing Schemas
# ---------------------------------------------------------

class TaskRouteApprovalItem(BaseModel):
    import_file_id: int
    import_file_code: str
    title: str
    description: Optional[str] = None
    assigned_user: str = Field("Finance Team", description="Assigned team/person, e.g. Finance Team, Clearance Team, Ahmed Sorour")
    priority: str = Field("High", description="Critical, High, Medium, or Low")
    due_date: Optional[str] = None
    reminder_type: str = "Arrival Notice Payment"
    bl_number: Optional[str] = None
    notes: Optional[str] = None
    email_id: Optional[int] = None
    task_id: Optional[int] = None


class TasksBatchApprovalRequest(BaseModel):
    tasks: List[TaskRouteApprovalItem] = Field(..., min_length=1, description="List of approved tasks to route/save")


class TasksBatchApprovalResult(BaseModel):
    approved_count: int
    created_task_ids: List[int] = []
    message: str
