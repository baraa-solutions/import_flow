from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database.database import Base


class CargoInsuranceCertificate(Base):
    __tablename__ = "cargo_insurance_certificates"

    # Primary Key
    certificate_id = Column(Integer, primary_key=True, autoincrement=True, index=True)

    # Business Reference Codes
    certificate_code = Column(String(50), nullable=False, unique=True, index=True) # e.g. INS-2026-00001
    policy_number = Column(String(100), nullable=True, index=True) # e.g. POL-EGY-98214
    policy_type = Column(String(30), nullable=False, default="SPECIFIC") # SPECIFIC, OPEN_DECLARATION

    # Relationships & Linked Entities
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    insurance_company_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    insurance_company_name = Column(String(150), nullable=True)
    insured_entity_name = Column(String(200), nullable=False) # Importer Name / Consignee

    # Shipment & Voyage Details
    transport_mode = Column(String(30), nullable=False, default="OCEAN") # OCEAN, AIR, ROAD
    carrier_name = Column(String(150), nullable=True) # Shipping Line / Airline
    vessel_or_flight_no = Column(String(150), nullable=True) # Vessel Name / Flight No
    voyage_number = Column(String(50), nullable=True)
    tracking_reference = Column(String(100), nullable=True) # Bill of Lading (B/L) / AWB / CMR
    port_of_loading = Column(String(150), nullable=False)
    port_of_discharge = Column(String(150), nullable=False)
    final_destination = Column(String(150), nullable=True)

    # Financial & Valuation (Incoterms 110% Formula)
    currency = Column(String(10), default="USD", nullable=False)
    exchange_rate = Column(Float, default=1.0, nullable=False)
    invoice_value = Column(Float, default=0.0, nullable=False) # FOB / EXW Value
    freight_cost = Column(Float, default=0.0, nullable=False)
    other_logistics_costs = Column(Float, default=0.0, nullable=False)
    cif_value = Column(Float, default=0.0, nullable=False) # Invoice + Freight + Other
    markup_percentage = Column(Float, default=0.10, nullable=False) # Default 10% (110% CIF)
    insured_value = Column(Float, default=0.0, nullable=False) # CIF * 1.10

    # Coverage Clauses & Risk Add-ons
    coverage_clause = Column(String(50), default="ICC_A", nullable=False) # ICC_A, AIR_ALL_RISKS, ICC_B, ICC_C
    include_war_and_strikes = Column(Boolean, default=True, nullable=False)
    base_rate = Column(Float, default=0.0025, nullable=False)
    war_rate = Column(Float, default=0.0005, nullable=False)

    # Premium Breakdown
    base_premium = Column(Float, default=0.0, nullable=False)
    war_strikes_premium = Column(Float, default=0.0, nullable=False)
    minimum_premium = Column(Float, default=30.0, nullable=False)
    net_premium = Column(Float, default=0.0, nullable=False)
    issuance_fee = Column(Float, default=15.0, nullable=False)
    tax_rate = Column(Float, default=0.05, nullable=False) # 5% Stamp Duty & VAT
    tax_amount = Column(Float, default=0.0, nullable=False)
    total_payable_premium = Column(Float, default=0.0, nullable=False)

    # Cargo Details & Claims Handling
    goods_description = Column(Text, nullable=True)
    package_count = Column(Integer, nullable=True)
    package_type = Column(String(50), nullable=True) # Cartons, Pallets, Containers
    gross_weight_kg = Column(Float, nullable=True)
    survey_agent_in_destination = Column(String(200), nullable=True)
    claims_payable_at = Column(String(150), nullable=True, default=None)

    # Workflow & Lifecycle Status
    status = Column(String(30), default="DRAFT", nullable=False) # DRAFT, ISSUED, CANCELLED, CLAIMED
    issued_at = Column(DateTime, nullable=True)
    remarks = Column(Text, nullable=True)

    # Audit Trail
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(50), default="system", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(50), default="system", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    import_file = relationship("ImportFile", backref="cargo_insurance_certificates", foreign_keys=[import_file_id])
