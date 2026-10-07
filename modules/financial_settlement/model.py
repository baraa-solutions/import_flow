from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Date,
    Integer,
    Numeric,
    UniqueConstraint,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Float,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile

class LandedCostSettlementRecord(Base):
    """
    Phase 9 Financial Settlement & Landed Cost Engine Model (BP-036 to BP-039)
    Tracks expense invoices (freight, customs duties, brokerage, local transport, storage),
    allocates costs by Value/Weight/Volume/Equal, and calculates unit landed cost and markup factor per item line.
    """
    __tablename__ = "financial_settlement_records"

    settlement_id = Column(Integer, primary_key=True, index=True)
    settlement_code = Column(String(50), unique=True, index=True, nullable=False) # e.g. LCS-2026-0001

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False)
    incoterm_code = Column(String(20), default="FOB", nullable=False) # FOB, CIF, CFR, EXW, DDP, etc.
    # Schema: [{"invoice_no": "INV-100", "category": "Freight", "provider_name": "Maersk", "currency": "USD", "amount_fx": 1000.0, "exchange_rate": 50.0, "amount_egp": 50000.0, "allocation_rule": "Volume-Based"}]
    expense_invoices = Column(JSON, default=list, nullable=False)
    
    total_fob_egp = Column(Float, default=0.0, nullable=False)
    total_expenses_egp = Column(Float, default=0.0, nullable=False)
    total_landed_cost_egp = Column(Float, default=0.0, nullable=False)
    average_markup_factor = Column(Float, default=1.0, nullable=False)

    # BP-038 & BP-039 Item Landed Cost Breakdown JSON
    # Schema: [{"item_code": "ITM-001", "item_name": "Steel Valves", "qty": 100, "fob_unit_egp": 100.0, "fob_total_egp": 10000.0, "allocated_freight_egp": 2000.0, "allocated_customs_egp": 1400.0, "allocated_clearance_egp": 500.0, "allocated_transport_egp": 300.0, "allocated_other_egp": 100.0, "total_landed_cost_egp": 14300.0, "unit_landed_cost_egp": 143.0, "markup_factor": 1.43}]
    item_landed_costs = Column(JSON, default=list, nullable=False)

    status = Column(String(50), default="Draft", index=True) # Draft, Expenses Logged, Calculated, Approved, Closed
    accountant_name = Column(String(100), default="Kamal", nullable=False)
    notes = Column(Text, nullable=True)

    is_active = Column(Boolean, default=True, index=True)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationships
    import_file = relationship("ImportFile", backref="financial_settlement_records")


# Tax codes of the withholding tax (deduction at source) taken from customs broker / port invoices and from
# inland transport invoices. Rates live in tax_rates (seeded by MasterDataSyncService.sync_tax_rates).
WHT_CLEARANCE_SERVICES = "WHT_CLEARANCE_SERVICES"
WHT_TRANSPORT_SERVICES = "WHT_TRANSPORT_SERVICES"


class TaxRate(Base):
    """
    Effective-dated tax rates that are not part of the HS-code tariff (e.g. withholding tax deducted from
    clearance invoices). One row per (tax_code, effective_from); the rate valid on a date is the active,
    non-deleted row with effective_from <= date <= effective_to (open-ended when effective_to is NULL).
    """
    __tablename__ = "tax_rates"
    __table_args__ = (UniqueConstraint("tax_code", "effective_from", name="uq_tax_rates_code_effective_from"),)

    tax_rate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    tax_code = Column(String(50), nullable=False, index=True)
    rate_percent = Column(Numeric(7, 4), nullable=False)
    effective_from = Column(Date, nullable=False)
    effective_to = Column(Date, nullable=True)
    description = Column(String(255), nullable=True)

    is_active = Column(Boolean, default=True, server_default="1", nullable=False)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")
