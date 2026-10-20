from datetime import datetime, timezone, date
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    Float,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from database.database import Base


class PortTerminalRate(Base):
    """
    Port Terminal Storage Rate Card Model
    Defines terminal storage tariffs, tiered rates, reefer plugging, and fixed port inspection/scale fees
    across Egyptian container terminals (ACCHCO, DP World Sokhna, DCHC, SCCT).
    """
    __tablename__ = "port_terminal_rates"

    rate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    terminal_code = Column(String(50), nullable=False, index=True)  # ACCHCO, DP_WORLD_SOKHNA, DCHC, SCCT
    terminal_name = Column(String(150), nullable=False)
    container_size = Column(String(20), nullable=False, index=True)  # 20ft, 40ft
    is_reefer = Column(Boolean, default=False, nullable=False, index=True)
    
    # Tiered Structure: Free days (1-3), Tier 1 (4-8), Tier 2 (9-15), Penal (16+)
    free_days = Column(Integer, default=3, nullable=False)
    tier1_rate_per_day = Column(Float, default=0.0, nullable=False)  # Days 4-8
    tier2_rate_per_day = Column(Float, default=0.0, nullable=False)  # Days 9-15
    penal_rate_per_day = Column(Float, default=0.0, nullable=False)  # Days 16+
    
    # Reefer & Terminal Specific Fees (EGP)
    reefer_plugging_daily_fee = Column(Float, default=0.0, nullable=False)
    xray_scan_fee = Column(Float, default=0.0, nullable=False)
    scale_fee = Column(Float, default=0.0, nullable=False)
    currency = Column(String(10), default="EGP", nullable=False)
    
    effective_date = Column(Date, default=date.today, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    __table_args__ = (
        UniqueConstraint("terminal_code", "container_size", "is_reefer", "effective_date", name="uq_port_terminal_rate_unique"),
    )


class PortStorageAccrual(Base):
    """
    Port Storage Accrual Model
    Tracks yard storage days, reefer plugging charges, terminal ancillary fees, and payment status
    per individual container at Egyptian ports.
    """
    __tablename__ = "port_storage_accruals"

    accrual_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    terminal_code = Column(String(50), nullable=False, index=True)
    container_number = Column(String(50), nullable=False, index=True)
    container_size_type = Column(String(50), nullable=False)  # 20ft, 40ft, 40HC, etc.
    is_reefer = Column(Boolean, default=False, nullable=False)
    
    # Milestone Dates
    gate_in_date = Column(Date, nullable=False, index=True)
    customs_release_date = Column(Date, nullable=True)
    gate_out_date = Column(Date, nullable=True)
    
    # Days & Breakdown
    free_days_allowed = Column(Integer, default=3, nullable=False)
    chargeable_days = Column(Integer, default=0, nullable=False)
    storage_charges_egp = Column(Float, default=0.0, nullable=False)
    reefer_plugging_charges_egp = Column(Float, default=0.0, nullable=False)
    xray_scan_fee_egp = Column(Float, default=0.0, nullable=False)
    scale_fee_egp = Column(Float, default=0.0, nullable=False)
    total_port_storage_egp = Column(Float, default=0.0, nullable=False)
    
    # Financial / Settlement Status (ESTIMATED / INVOICED / PAID)
    status = Column(String(50), default="ESTIMATED", nullable=False, index=True)
    invoice_number = Column(String(100), nullable=True)
    invoice_date = Column(Date, nullable=True)
    paid_amount_egp = Column(Float, nullable=True)
    payment_reference = Column(String(100), nullable=True)
    
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Relationships
    import_file = relationship("ImportFile", foreign_keys=[import_file_id])
