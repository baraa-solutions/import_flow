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
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile
from modules.financial_settlement.model import LandedCostSettlementRecord
class Terminal(Base):
    """
    Terminals & Yard Operators Master Model (MD-TERM-001)
    Master entity representing port container terminals (e.g. AICTC, TMT, HPH, SCCT, DPW, DCHC).
    """
    __tablename__ = "terminals"

    terminal_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    terminal_code = Column(String(50), unique=True, index=True, nullable=False)
    terminal_name = Column(String(150), nullable=False)
    terminal_name_en = Column(String(150), nullable=True)
    port_name = Column(String(100), nullable=False, index=True)
    country_code = Column(String(10), default="EG", nullable=False)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), nullable=True)

    # Relationships
    storage_rates = relationship("TerminalStorageRate", back_populates="terminal", cascade="all, delete-orphan")


class TerminalStorageRate(Base):
    """
    Terminal Storage Historical Tariff Rate Card Model (MD-TERM-002)
    Historical record of port storage / yard rent tiered daily rates per container type and effective date.
    """
    __tablename__ = "terminal_storage_rates"

    rate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    terminal_id = Column(Integer, ForeignKey("terminals.terminal_id"), nullable=False, index=True)
    container_type = Column(String(50), nullable=False, index=True)  # e.g. "20ft DRY", "40ft DRY", "40ft High Cube", "Reefer", "IMO"
    free_days = Column(Integer, default=7, nullable=False)
    storage_tiers = Column(JSON, default=list, nullable=False)  # [{from_day, to_day, rate_per_day}]
    currency = Column(String(10), nullable=False)
    imo_free_days = Column(Integer, default=0, nullable=False)
    imo_rate_multiplier = Column(Float, default=2.0, nullable=False)
    effective_date = Column(Date, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)

    # Relationship
    terminal = relationship("Terminal", back_populates="storage_rates")

    __table_args__ = (
        UniqueConstraint("terminal_id", "container_type", "effective_date", name="uq_terminal_storage_rate_date"),
    )


class Carrier(Base):
    """
    Carriers & Ocean Shipping Lines Master Model (MD-CARR-001)
    Master entity representing shipping lines (e.g. MSC, Maersk, CMA CGM, Hapag-Lloyd, COSCO, ONE).
    """
    __tablename__ = "carriers"

    carrier_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    carrier_code = Column(String(50), unique=True, index=True, nullable=False)
    carrier_name = Column(String(150), nullable=False)
    carrier_name_ar = Column(String(150), nullable=True)
    scac_code = Column(String(10), unique=True, index=True, nullable=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), nullable=True)

    # Relationships
    demurrage_rates = relationship("CarrierDemurrageRate", back_populates="carrier", cascade="all, delete-orphan")


class CarrierDemurrageRate(Base):
    """
    Carrier Demurrage & Detention Historical Tariff Rate Card Model (MD-CARR-002)
    Historical record of carrier demurrage and detention tiered daily rates per container type and effective date.
    """
    __tablename__ = "carrier_demurrage_rates"

    rate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    carrier_id = Column(Integer, ForeignKey("carriers.carrier_id"), nullable=False, index=True)
    container_type = Column(String(50), nullable=False, index=True)  # e.g. "20ft DRY", "40ft DRY", "40ft High Cube", "Reefer"
    demurrage_free_days_standard = Column(Integer, default=14, nullable=False)
    detention_free_days_standard = Column(Integer, default=7, nullable=False)
    demurrage_tiers = Column(JSON, default=list, nullable=False)  # [{from_day, to_day, rate_per_day}]
    detention_tiers = Column(JSON, default=list, nullable=False)  # [{from_day, to_day, rate_per_day}]
    currency = Column(String(10), nullable=False)
    effective_date = Column(Date, nullable=False, index=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, index=True, nullable=False)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), nullable=True)

    # Relationship
    carrier = relationship("Carrier", back_populates="demurrage_rates")

    __table_args__ = (
        UniqueConstraint("carrier_id", "container_type", "effective_date", name="uq_carrier_demurrage_rate_date"),
    )



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
    carrier_id = Column(Integer, ForeignKey("carriers.carrier_id"), nullable=True, index=True)
    terminal_id = Column(Integer, ForeignKey("terminals.terminal_id"), nullable=True, index=True)
    carrier_name = Column(String(100), index=True, nullable=False)
    bill_of_lading_no = Column(String(100), index=True, nullable=False)
    port_name = Column(String(100), nullable=False)

    discharge_date = Column(Date, nullable=False)  # Date containers discharged from vessel
    gate_out_date = Column(Date, nullable=True)   # Date container cleared & left port gate
    empty_return_date = Column(Date, nullable=True)  # Date empty container returned to carrier depot

    # Container-level details: [{container_no, container_type, demurrage_days, detention_days, storage_days, demurrage_fx, detention_fx, storage_egp, status}]
    containers = Column(JSON, default=list, nullable=False)
    ancillary_fees = Column(JSON, default=list, nullable=False)  # [{fee_type, description, amount_usd, date, notes}]
    
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
    carrier = relationship("Carrier", backref="trackings", foreign_keys=[carrier_id])
    terminal = relationship("Terminal", backref="trackings", foreign_keys=[terminal_id])
    settlement_record = relationship("LandedCostSettlementRecord", backref="demurrage_trackings", foreign_keys=[settlement_record_id])

    @property
    def total_ancillary_usd(self) -> float:
        fees = self.ancillary_fees or []
        return round(sum(float(f.get("amount_usd", 0.0)) for f in fees if isinstance(f, dict)), 2)

    @property
    def total_ancillary_egp(self) -> float:
        fees = self.ancillary_fees or []
        # No fabricated rate: a USD-only fee counts in EGP only when the tracking has a real exchange rate.
        rate = float(self.exchange_rate) if self.exchange_rate else None
        total = 0.0
        for f in fees:
            if isinstance(f, dict):
                if f.get("amount_egp") is not None:
                    total += float(f["amount_egp"])
                elif f.get("amount_usd") is not None and rate is not None:
                    total += float(f["amount_usd"]) * rate
        return round(total, 2)

