from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String
from database.database import Base


class ExternalServiceProvider(Base):
    __tablename__ = "external_service_providers"

    # ==================================================
    # Primary Key
    # ==================================================
    provider_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # ==================================================
    # System Code
    # ==================================================
    partner_code = Column(String(20), unique=True, index=True, nullable=False)

    # ==================================================
    # Partner Category & Name
    # ==================================================
    partner_name = Column(String(200), nullable=False)
    partner_type = Column(String(100), nullable=False)  # Bank, Shipping Line, Customs Broker, Freight Forwarder, Inland Transport, Inspection Agency

    # ==================================================
    # Registration & Tax Information
    # ==================================================
    tax_id = Column(String(50))
    commercial_register = Column(String(50))

    # ==================================================
    # Category-Specific Details
    # ==================================================
    # For Customs Brokers:
    clearance_license_number = Column(String(50))
    authorized_ports = Column(String(300))  # e.g. Alexandria, Port Said, Ain Sokhna, Cairo Airport, Damietta

    # For Shipping Lines & Carriers:
    scac_code = Column(String(20))
    tracking_url = Column(String(300))
    default_free_days = Column(Integer, default=None, nullable=True)
    local_agent_name = Column(String(200))
    booking_email = Column(String(150))

    # For Freight Forwarders:
    fiata_id = Column(String(50))
    shipping_modes = Column(String(200))
    supported_currencies = Column(String(100))

    # For Inspection & Quality Agencies:
    inspection_accreditation_number = Column(String(100))
    inspection_scope = Column(String(300))

    # For Inland Transport Carriers:
    transport_license_number = Column(String(100))
    fleet_types = Column(String(300))
    coverage_areas = Column(String(300))

    # For Marine Cargo Insurance Companies:
    insurance_license_number = Column(String(100))
    insurance_coverage_types = Column(String(300))

    # For Commercial Banks & Financial Accounts:
    swift_code = Column(String(20))
    bank_code = Column(String(20))
    branch_name = Column(String(100))
    account_number = Column(String(100))
    iban = Column(String(100))

    # ==================================================
    # Contact Information
    # ==================================================
    contact_person = Column(String(150))
    phone = Column(String(50))
    mobile = Column(String(50))
    fax = Column(String(50))
    email = Column(String(150))
    secondary_email = Column(String(150))
    website = Column(String(200))
    address = Column(String(300))
    country = Column(String(100), default="Egypt")

    # ==================================================
    # Financial & Performance Rating
    # ==================================================
    payment_type = Column(String(50), default="Credit")  # Cash, Credit, Deferred
    payment_terms = Column(String(100), nullable=True)  # Net 30, Net 60, Advance, etc.
    credit_limit = Column(Float, default=0.0)
    rating = Column(Float, default=5.0)  # 1 to 5 stars

    # ==================================================
    # Notes
    # ==================================================
    notes = Column(String(1000))

    # ==================================================
    # Status & Audit
    # ==================================================
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100))
    updated_by = Column(String(100))