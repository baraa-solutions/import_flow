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
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile
from modules.financial_settlement.model import LandedCostSettlementRecord



class DemurragePolicy(Base):
    """
    Demurrage & Detention Tariff Policy Model
    Stores carrier free days and tiered daily rate schedules per container type.
    """
    __tablename__ = "demurrage_policies"

    policy_id = Column(Integer, primary_key=True, index=True)
    carrier_name = Column(String(100), index=True, nullable=False)  # e.g. "MSC", "Maersk", "CMA CGM"
    container_type = Column(String(50), nullable=False)  # e.g. "20ft Standard", "40ft Standard", "40ft High Cube", "Reefer"
    
    demurrage_free_days = Column(Integer, default=14, nullable=False)
    detention_free_days = Column(Integer, default=7, nullable=False)
    port_storage_free_days = Column(Integer, default=5, nullable=False)
    
    currency = Column(String(10), default="USD", nullable=False)
    port_storage_daily_rate_egp = Column(Float, default=250.0, nullable=False)

    # Tiered rate structures (list of {from_day, to_day, rate_per_day})
    demurrage_tiers = Column(JSON, default=lambda: [
        {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
        {"from_day": 15, "to_day": None, "rate_per_day": 120.0},
    ], nullable=False)

    detention_tiers = Column(JSON, default=lambda: [
        {"from_day": 1, "to_day": 7, "rate_per_day": 35.0},
        {"from_day": 8, "to_day": 14, "rate_per_day": 65.0},
        {"from_day": 15, "to_day": None, "rate_per_day": 110.0},
    ], nullable=False)

    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")


class DemurrageTracking(Base):
    """
    Demurrage & Detention Live Tracking Session Model
    Monitors discharge date, gate out date, return date, counts free days, and calculates financial penalties.
    """
    __tablename__ = "demurrage_trackings"

    tracking_id = Column(Integer, primary_key=True, index=True)
    tracking_code = Column(String(50), unique=True, index=True, nullable=False)  # e.g. DND-2026-0001
    
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    import_file_code = Column(String(50), nullable=True)

    policy_id = Column(Integer, ForeignKey("demurrage_policies.policy_id"), nullable=True)
    carrier_name = Column(String(100), index=True, nullable=False)
    bill_of_lading_no = Column(String(100), index=True, nullable=False)
    port_name = Column(String(100), nullable=False)

    discharge_date = Column(Date, nullable=False)  # Date containers discharged from vessel
    gate_out_date = Column(Date, nullable=True)   # Date container cleared & left port gate
    empty_return_date = Column(Date, nullable=True)  # Date empty container returned to carrier depot

    # Container-level details: [{container_no, container_type, demurrage_days, detention_days, storage_days, demurrage_fx, detention_fx, storage_egp, status}]
    containers = Column(JSON, default=list, nullable=False)
    
    total_demurrage_fx = Column(Float, default=0.0, nullable=False)
    total_detention_fx = Column(Float, default=0.0, nullable=False)
    total_storage_egp = Column(Float, default=0.0, nullable=False)
    
    currency = Column(String(10), default="USD", nullable=False)
    exchange_rate = Column(Float, nullable=False)  # always set by the service (request value or bank rate)
    total_cost_egp = Column(Float, default=0.0, nullable=False)

    status = Column(String(50), default="Free Time Active", index=True)  # Free Time Active, Warning, Demurrage Incurred, Detention Incurred, Closed, Pushed to Settlement
    is_pushed_to_settlement = Column(Boolean, default=False, index=True)
    settlement_record_id = Column(Integer, ForeignKey("financial_settlement_records.settlement_id"), nullable=True)

    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationship
    import_file = relationship("ImportFile", backref="demurrage_trackings", foreign_keys=[import_file_id])
    policy = relationship("DemurragePolicy", backref="trackings", foreign_keys=[policy_id])
    settlement_record = relationship("LandedCostSettlementRecord", backref="demurrage_trackings", foreign_keys=[settlement_record_id])
