from datetime import datetime, timezone, date
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base


class CustomsAbandonmentRadar(Base):
    """
    Egyptian Customs Abandonment Radar Model (مهمل الجمارك)
    Statutory countdown per Egyptian Customs Law No. 207 of 2020, Article 67:
      - 60 days for seaports (الموانئ البحرية)
      - 30 days for dry ports and airports (الموانئ الجافة والمطارات)
    Tracks elapsed yard days, remaining legal time, escalation tiers,
    extension requests, and transfer to customs auction warehouse.
    """
    __tablename__ = "customs_abandonment_radars"

    radar_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    import_file_code = Column(String(50), nullable=False, index=True)
    
    # Port classification & Arrival
    port_type = Column(String(20), nullable=False, index=True)  # SEAPORT, DRY_PORT, AIRPORT
    port_name = Column(String(100), nullable=True)
    arrival_date = Column(Date, nullable=False, index=True)
    
    # Statutory Countdown Metrics (Art. 67 Law 207/2020)
    max_legal_days = Column(Integer, nullable=False)  # 60 for SEAPORT, 30 for DRY_PORT / AIRPORT
    days_in_port = Column(Integer, nullable=False)
    days_remaining = Column(Integer, nullable=False)
    
    # Risk Escalation Level:
    # NORMAL (>15 days), WARNING_15_DAYS (8-15 days), CRITICAL_7_DAYS (1-7 days), UNDER_ABANDONMENT_INVENTORY (<=0 days)
    risk_level = Column(String(50), nullable=False, index=True)
    
    # Extension Mechanisms
    extension_requested = Column(Boolean, default=False, nullable=False)
    extension_request_date = Column(Date, nullable=True)
    extension_reason = Column(Text, nullable=True)
    extension_request_ref = Column(String(100), nullable=True)
    extension_granted_until = Column(Date, nullable=True)
    official_letter_issued = Column(Boolean, default=False, nullable=False)
    
    # Lifecycle Status:
    # ACTIVE_CLEARING, EXTENSION_PENDING, MOVED_TO_ABANDONED_WAREHOUSE, AUCTION_SCHEDULED, RESOLVED_RELEASED
    abandonment_status = Column(String(50), default="ACTIVE_CLEARING", nullable=False, index=True)
    
    # Operational Dossier Context
    importer_name = Column(String(255), nullable=True)
    cargo_description = Column(String(255), nullable=True)
    customs_declaration_no = Column(String(100), nullable=True)  # نموذج 46 ك.م
    bl_number = Column(String(100), nullable=True)
    acid_number = Column(String(50), nullable=True)
    container_numbers = Column(JSON, nullable=True)
    
    action_plan = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
