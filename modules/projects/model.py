from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import relationship

from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm


# ==================================================
# Projects Module (نقطة البداية لكل عملية استيراد)
# ==================================================

class Project(Base):

    __tablename__ = "projects"

    # Primary Key
    project_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Business Reference & Info
    project_code = Column(String(50), nullable=False, unique=True, index=True)  # e.g. PRJ-2026-001
    project_name = Column(String(200), nullable=False)
    project_owner = Column(String(100), nullable=False)

    # Foreign Keys
    company_id = Column(Integer, ForeignKey("import_companies.company_id"), nullable=False, index=True)
    additional_company_ids = Column(String(250), nullable=True)  # Comma-separated extra company IDs for multi-company support
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False, index=True)
    incoterm_id = Column(Integer, ForeignKey("incoterms.incoterm_id"), nullable=False, index=True)

    # Business Categorization
    import_type = Column(String(100), nullable=False, default="Direct Commercial")  # Direct Commercial, Free Zone, Temporary Release, Drawback
    priority = Column(String(50), nullable=False, default="Medium")                   # Low, Medium, High, Urgent
    shipment_category = Column(String(100), nullable=False, default="FCL Container") # FCL Container, LCL, Air Freight, Bulk, Multimodal

    # Multi-Shipment & Multi-Company Capabilities
    allow_multi_shipment = Column(Boolean, default=True, nullable=False)  # شحن على أكثر من شحنة
    allow_multi_company = Column(Boolean, default=True, nullable=False)   # التعامل مع أكثر من شركة/خط شحن

    total_budget_usd = Column(Numeric(14, 2), nullable=True)
    budget_currency = Column(String(10), nullable=False, default="USD", server_default="USD")
    target_end_date = Column(String(50), nullable=True)  # YYYY-MM-DD target completion date
    status = Column(String(50), nullable=False, default="Open", index=True)  # Open, Closed, On Hold
    notes = Column(Text, nullable=True)

    # Soft Delete & Audit Trail
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

    # Relationships
    company = relationship("ImportCompany", foreign_keys=[company_id])
    supplier = relationship("Supplier", foreign_keys=[supplier_id])
    incoterm = relationship("Incoterm", foreign_keys=[incoterm_id])
