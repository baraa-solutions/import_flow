"""
SQLAlchemy Model for Inbound Email Logs (INT-EMAIL-010)
"""

from datetime import datetime, timezone, date
from sqlalchemy import JSON, Column, Integer, String, Text, Date, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import synonym
from database.database import Base
from .crypto import encrypt_email_password, decrypt_email_password


class InboundEmailLog(Base):
    __tablename__ = "inbound_email_logs"

    email_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    sender_email = Column(String(150), nullable=False, default="notifications@carrier.com")
    subject = Column(String(300), nullable=False)
    body_text = Column(Text, nullable=False)
    received_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    email_type = Column(String(50), default="Arrival Notice", nullable=False)

    # Extracted data
    extracted_bl_number = Column(String(100), nullable=True, index=True)
    extracted_eta = Column(Date, nullable=True)
    extracted_vessel = Column(String(150), nullable=True)
    extracted_voyage = Column(String(50), nullable=True)
    extracted_containers = Column(String(300), nullable=True)

    # Association & Outcome
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    processing_status = Column(String(50), default="Processed", nullable=False)  # Matched, Unmatched, Task_Created
    task_id = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    msg_code = Column(String(80), nullable=True)  # system message code of notes (English render in notes)
    msg_params = Column(JSON, nullable=True)

    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="SmartEmailListener", nullable=False)


class EmailSettings(Base):
    __tablename__ = "email_settings"

    settings_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    provider_type = Column(String(50), default="CUSTOM", nullable=False)  # GMAIL, OUTLOOK, CUSTOM
    email_address = Column(String(150), nullable=False)
    username = Column(String(150), nullable=False)
    _password = Column("password", String(255), nullable=False)  # Encrypted App Password or account secret

    def _get_password(self) -> str:
        return decrypt_email_password(self._password) if self._password else ""

    def _set_password(self, val: str):
        self._password = encrypt_email_password(val) if val else ""

    password = synonym("_password", descriptor=property(_get_password, _set_password))

    # Inbound (IMAP)
    imap_host = Column(String(150), nullable=False, default="imap.gmail.com")
    imap_port = Column(Integer, nullable=False, default=993)
    imap_use_ssl = Column(Boolean, nullable=False, default=True)

    # Outbound (SMTP)
    smtp_host = Column(String(150), nullable=False, default="smtp.gmail.com")
    smtp_port = Column(Integer, nullable=False, default=587)
    smtp_use_tls = Column(Boolean, nullable=False, default=True)
    smtp_use_ssl = Column(Boolean, nullable=False, default=False)

    sender_display_name = Column(String(150), nullable=False, default="Sorour Logistics Operations")
    auto_fetch_enabled = Column(Boolean, nullable=False, default=False)
    fetch_interval_minutes = Column(Integer, nullable=False, default=15)

    last_sync_at = Column(DateTime, nullable=True)
    last_sync_status = Column(String(50), nullable=True)  # SUCCESS, ERROR, IDLE
    last_sync_message = Column(Text, nullable=True)
    msg_code = Column(String(80), nullable=True)  # system message code of last_sync_message
    msg_params = Column(JSON, nullable=True)

    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="Admin", nullable=False)
    updated_by = Column(String(100), default="Admin", nullable=False)

    @property
    def has_password(self) -> bool:
        return bool(self.password and len(self.password.strip()) > 0)

