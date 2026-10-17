"""
SQLAlchemy Models for Logistics Service Invoices & Payments (LSI)
================================================================
Covers service invoices for freight forwarders, customs brokers, inspection agencies,
and marine insurance companies; along with invoice knock-off, container locks,
advance payments, and insurance policies.
"""

from __future__ import annotations

from datetime import datetime, date, timezone
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from database.database import Base
from modules.expense_catalog.model import ExpenseCatalog


class LogisticsServiceInvoice(Base):
    """
    Header record for service invoices from freight forwarders, customs brokers,
    inspection agencies, and marine cargo insurance companies.
    """
    __tablename__ = "logistics_service_invoices"

    invoice_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    invoice_code = Column(String(50), unique=True, index=True, nullable=False)

    shipment_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    bl_number = Column(String(100), nullable=True, index=True)

    partner_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True)
    partner_type = Column(String(50), nullable=False, index=True)  # freight, clearance, inspection, insurance
    partner_name = Column(String(255), nullable=False)

    invoice_number = Column(String(100), nullable=False, index=True)  # Partner's formal invoice/receipt number
    invoice_date = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    currency = Column(String(10), nullable=False, default="EGP")  # EGP, USD, EUR, GBP
    total_amount_fx = Column(Float, nullable=False, default=0.0)
    exchange_rate = Column(Float, nullable=False, default=1.0)
    total_amount_egp = Column(Float, nullable=False, default=0.0)

    vat_included = Column(Boolean, default=False, nullable=False)
    vat_amount = Column(Float, default=0.0, nullable=False)
    wht_deducted = Column(Boolean, default=False, nullable=False)
    wht_amount = Column(Float, default=0.0, nullable=False)
    net_payable_egp = Column(Float, nullable=False, default=0.0)

    paid_amount_egp = Column(Float, default=0.0, nullable=False)
    remaining_amount_egp = Column(Float, default=0.0, nullable=False)

    # Status tracking
    payment_status = Column(String(50), default="UNPAID", nullable=False, index=True)  # UNPAID, PARTIALLY_PAID, FULLY_PAID
    status = Column(String(50), default="DRAFT", nullable=False, index=True)  # DRAFT, SUBMITTED, APPROVED, CANCELLED
    approval_status = Column(String(50), default="PENDING", nullable=False)  # PENDING, APPROVED, REJECTED

    # Link to insurance policy if this is an insurance invoice
    insurance_policy_id = Column(Integer, ForeignKey("insurance_policies.policy_id"), nullable=True, index=True)

    document_url = Column(String(500), nullable=True)
    notes = Column(Text, nullable=True)

    # Soft delete & audit
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Relationships
    shipment = relationship("ImportFile", foreign_keys=[shipment_id])
    partner = relationship("ExternalServiceProvider", foreign_keys=[partner_id])
    insurance_policy = relationship("InsurancePolicy", foreign_keys=[insurance_policy_id])
    lines = relationship("LogisticsInvoiceLine", back_populates="invoice", cascade="all, delete-orphan")
    containers = relationship("LogisticsInvoiceContainer", back_populates="invoice", cascade="all, delete-orphan")
    knockoffs = relationship("InvoiceKnockoff", back_populates="invoice")
    advance_settlements = relationship("ClearanceAdvanceSettlement", back_populates="invoice")


class LogisticsInvoiceLine(Base):
    """
    Line item for logistics invoice (e.g. 21 standard freight lines, clearance fee list,
    or insurance breakdown: premium + stamp duty + supervisory fee).
    """
    __tablename__ = "logistics_invoice_lines"

    line_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    invoice_id = Column(Integer, ForeignKey("logistics_service_invoices.invoice_id"), nullable=False, index=True)

    expense_code = Column(String(50), ForeignKey("expense_catalog.code"), nullable=True, index=True)
    line_description = Column(String(255), nullable=False)
    line_group = Column(String(50), nullable=True)  # ocean_freight, port_charges, origin_charges, clearance_fees, inspection, insurance

    quantity = Column(Float, default=1.0, nullable=False)
    unit_price_fx = Column(Float, default=0.0, nullable=False)
    currency = Column(String(10), default="EGP", nullable=False)
    amount_fx = Column(Float, default=0.0, nullable=False)
    exchange_rate = Column(Float, default=1.0, nullable=False)
    amount_egp = Column(Float, default=0.0, nullable=False)

    tax_type = Column(String(50), default="professional_fee", nullable=False)  # professional_fee, government_fee, insurance_fee, other
    vat_rate = Column(Float, default=0.0, nullable=False)
    vat_amount = Column(Float, default=0.0, nullable=False)
    wht_rate = Column(Float, default=0.0, nullable=False)
    wht_amount = Column(Float, default=0.0, nullable=False)
    net_amount_egp = Column(Float, default=0.0, nullable=False)

    is_from_quotation = Column(Boolean, default=False, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    invoice = relationship("LogisticsServiceInvoice", back_populates="lines")
    expense_catalog_entry = relationship("ExpenseCatalog", foreign_keys=[expense_code])


class LogisticsInvoiceContainer(Base):
    """
    Locks specific containers on a B/L to an invoice to guarantee no container is double-billed.
    """
    __tablename__ = "logistics_invoice_containers"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    invoice_id = Column(Integer, ForeignKey("logistics_service_invoices.invoice_id"), nullable=False, index=True)
    shipment_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    bl_number = Column(String(100), nullable=False, index=True)
    container_number = Column(String(50), nullable=False, index=True)
    seal_number = Column(String(50), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        UniqueConstraint("invoice_id", "container_number", name="uq_invoice_container"),
    )

    # Relationships
    invoice = relationship("LogisticsServiceInvoice", back_populates="containers")
    shipment = relationship("ImportFile", foreign_keys=[shipment_id])


class InsurancePolicy(Base):
    """
    Marine cargo insurance policy record.
    Calculates insured value (CIF + 10%), premium, statutory stamp duty (0.1%),
    and FRA supervisory fee (12%).
    """
    __tablename__ = "insurance_policies"

    policy_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    policy_code = Column(String(50), unique=True, index=True, nullable=False)

    shipment_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    bl_number = Column(String(100), nullable=True, index=True)

    insurance_company_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True)
    insurance_company_name = Column(String(255), nullable=False)

    policy_number = Column(String(100), nullable=False, index=True)
    policy_date = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    coverage_start = Column(Date, nullable=True)
    coverage_end = Column(Date, nullable=True)
    coverage_type = Column(String(50), default="all_risks", nullable=False)  # all_risks, icc_a, icc_b, icc_c, war_srcc

    insured_value_fx = Column(Float, default=0.0, nullable=False)  # CIF + 10%
    insured_value_currency = Column(String(10), default="USD", nullable=False)

    premium_rate = Column(Float, default=0.0, nullable=False)  # percentage rate, e.g. 0.35%
    premium_amount_fx = Column(Float, default=0.0, nullable=False)
    exchange_rate = Column(Float, default=1.0, nullable=False)
    premium_amount_egp = Column(Float, default=0.0, nullable=False)

    stamp_duty_egp = Column(Float, default=0.0, nullable=False)  # 0.1% of premium
    supervisory_fee_egp = Column(Float, default=0.0, nullable=False)  # 12% of premium
    net_premium_egp = Column(Float, default=0.0, nullable=False)  # Total payable in EGP

    beneficiary = Column(String(255), nullable=True)  # Company or financing bank
    status = Column(String(50), default="draft", nullable=False, index=True)  # draft, issued, active, expired, claimed, cancelled

    # Claims tracking
    claim_reference = Column(String(100), nullable=True)
    claim_amount_egp = Column(Float, default=0.0, nullable=False)
    claim_status = Column(String(50), nullable=True)  # filed, under_inspection, accepted, reimbursed, rejected

    invoice_generated = Column(Boolean, default=False, nullable=False)
    notes = Column(Text, nullable=True)

    # Soft delete & audit
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Relationships
    shipment = relationship("ImportFile", foreign_keys=[shipment_id])
    insurance_company = relationship("ExternalServiceProvider", foreign_keys=[insurance_company_id])


class ClearanceAdvancePayment(Base):
    """
    Advance payment disbursed to a customs broker, tied to a specific shipment and B/L.
    Later settled against actual customs clearance fee invoices.
    """
    __tablename__ = "clearance_advance_payments"

    advance_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    advance_code = Column(String(50), unique=True, index=True, nullable=False)

    shipment_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    bl_number = Column(String(100), nullable=True, index=True)

    clearance_partner_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True)
    clearance_partner_name = Column(String(255), nullable=False)

    amount = Column(Float, default=0.0, nullable=False)
    currency = Column(String(10), default="EGP", nullable=False)
    exchange_rate = Column(Float, default=1.0, nullable=False)
    amount_egp = Column(Float, default=0.0, nullable=False)

    payment_date = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    cbe_rate_date = Column(Date, nullable=True)
    disbursed_by = Column(String(100), default="Finance", nullable=False)

    settled_amount_egp = Column(Float, default=0.0, nullable=False)
    remaining_amount_egp = Column(Float, default=0.0, nullable=False)

    status = Column(String(50), default="pending", nullable=False, index=True)  # pending, approved, disbursed, partially_settled, fully_settled, overpaid
    notes = Column(Text, nullable=True)

    # Soft delete & audit
    is_active = Column(Boolean, default=True, nullable=False)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)

    # Relationships
    shipment = relationship("ImportFile", foreign_keys=[shipment_id])
    clearance_partner = relationship("ExternalServiceProvider", foreign_keys=[clearance_partner_id])
    settlements = relationship("ClearanceAdvanceSettlement", back_populates="advance_payment", cascade="all, delete-orphan")


class ClearanceAdvanceSettlement(Base):
    """
    Settlement link between a customs broker advance payment and an actual clearance invoice.
    """
    __tablename__ = "clearance_advance_settlements"

    settlement_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    advance_id = Column(Integer, ForeignKey("clearance_advance_payments.advance_id"), nullable=False, index=True)
    invoice_id = Column(Integer, ForeignKey("logistics_service_invoices.invoice_id"), nullable=False, index=True)

    settled_amount_egp = Column(Float, default=0.0, nullable=False)
    settlement_date = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    notes = Column(Text, nullable=True)

    # Relationships
    advance_payment = relationship("ClearanceAdvancePayment", back_populates="settlements")
    invoice = relationship("LogisticsServiceInvoice", back_populates="advance_settlements")


class LogisticsPaymentVoucher(Base):
    """
    Payment voucher issued to settle service invoices (freight, clearance, inspection, insurance).
    Can knock off multiple invoices in full or in part.
    """
    __tablename__ = "logistics_payment_vouchers"

    voucher_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    voucher_code = Column(String(50), unique=True, index=True, nullable=False)

    shipment_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)

    partner_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=False, index=True)
    partner_name = Column(String(255), nullable=False)

    payment_date = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    amount = Column(Float, default=0.0, nullable=False)
    currency = Column(String(10), default="EGP", nullable=False)
    exchange_rate = Column(Float, default=1.0, nullable=False)
    amount_egp = Column(Float, default=0.0, nullable=False)
    cbe_rate_date = Column(Date, nullable=True)

    payment_method = Column(String(50), default="BANK_TRANSFER", nullable=False)  # BANK_TRANSFER, CHEQUE, CASH
    bank_reference = Column(String(100), nullable=True)

    allocated_amount_egp = Column(Float, default=0.0, nullable=False)
    unallocated_amount_egp = Column(Float, default=0.0, nullable=False)

    status = Column(String(50), default="CONFIRMED", nullable=False, index=True)  # DRAFT, CONFIRMED, CANCELLED
    notes = Column(Text, nullable=True)

    # Soft delete & audit
    is_active = Column(Boolean, default=True, nullable=False)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    created_by = Column(String(100), default="System", nullable=False)

    # Relationships
    shipment = relationship("ImportFile", foreign_keys=[shipment_id])
    partner = relationship("ExternalServiceProvider", foreign_keys=[partner_id])
    knockoffs = relationship("InvoiceKnockoff", back_populates="voucher", cascade="all, delete-orphan")


class InvoiceKnockoff(Base):
    """
    M-to-M Knock-off link between a LogisticsPaymentVoucher and a LogisticsServiceInvoice.
    Allows partial and multi-invoice settlement.
    """
    __tablename__ = "invoice_knockoffs"

    knockoff_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    voucher_id = Column(Integer, ForeignKey("logistics_payment_vouchers.voucher_id"), nullable=False, index=True)
    invoice_id = Column(Integer, ForeignKey("logistics_service_invoices.invoice_id"), nullable=False, index=True)

    knocked_amount_egp = Column(Float, default=0.0, nullable=False)
    knock_date = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    notes = Column(String(255), nullable=True)

    # Relationships
    voucher = relationship("LogisticsPaymentVoucher", back_populates="knockoffs")
    invoice = relationship("LogisticsServiceInvoice", back_populates="knockoffs")
