"""
Financial & Management Approval Models (Phase 2 - BP-012 & BP-013)
"""

from datetime import datetime, date, timezone
from typing import Optional
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Boolean, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from database.database import Base


class PaymentRequestSession(Base):
    """
    Payment Request for Supplier or Financial Settlement (BP-012).
    Tracks requested amounts, beneficiary bank details, exchange rates, remaining PO balance, and payment status.
    """

    __tablename__ = "payment_request_sessions"

    payment_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    payment_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)

    # Optional Link to Import File, Purchase Order or Project
    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    supplier_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("suppliers.supplier_id"), nullable=True, index=True
    )
    supplier_name: Mapped[str] = mapped_column(String(200), nullable=False)
    project_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("projects.project_id"), nullable=True, index=True
    )

    # Payment Type: 'Advance Payment', 'Against B/L', 'Letter of Credit (L/C)', 'Documentary Collection (CAD)', 'Final Settlement'
    payment_type: Mapped[str] = mapped_column(
        String(50), default="Advance Payment", nullable=False
    )

    # Financial Breakdown & Conversion
    requested_amount: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    advance_percentage: Mapped[float] = mapped_column(Float, nullable=True)
    currency_code: Mapped[str] = mapped_column(String(10), default="USD", nullable=False)
    exchange_rate: Mapped[float] = mapped_column(Float, nullable=False)
    requested_amount_egp: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)

    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    request_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)

    # Status: 'Draft', 'Pending Approval', 'Approved', 'Paid', 'Rejected'
    status: Mapped[str] = mapped_column(
        String(50), default="Draft", nullable=False, index=True
    )

    # Beneficiary Bank Details Snapshot
    beneficiary_name: Mapped[str] = mapped_column(String(200), nullable=True)
    bank_name: Mapped[str] = mapped_column(String(200), nullable=True)
    swift_code: Mapped[str] = mapped_column(String(50), nullable=True)
    iban_account_no: Mapped[str] = mapped_column(String(100), nullable=True)
    bank_country: Mapped[str] = mapped_column(String(100), nullable=True)

    # Verification & Confirmation & SWIFT Reconciliation
    swift_reference_no: Mapped[str] = mapped_column(String(100), nullable=True)
    swift_receipt_date: Mapped[date] = mapped_column(Date, nullable=True)
    swift_transferred_amount: Mapped[float] = mapped_column(Float, nullable=True)
    swift_transferred_currency: Mapped[str] = mapped_column(String(10), nullable=True)
    swift_variance_amount: Mapped[float] = mapped_column(Float, nullable=True, default=0.0)
    swift_variance_status: Mapped[str] = mapped_column(String(50), nullable=True, default="Pending") # 'Matched', 'Deficit', 'Surplus', 'Pending'
    swift_processing_days: Mapped[int] = mapped_column(Integer, nullable=True)
    swift_reconciliation_notes: Mapped[str] = mapped_column(Text, nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)

    # Audit & Soft Delete
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )
    created_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    updated_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)


class ImportBudgetApproval(Base):
    """
    Import File Budget Approval (BP-013).
    Consolidates Invoice Cost, Estimated Freight, Estimated Customs & VAT, and Local Handling to form total approved budget.
    """

    __tablename__ = "import_budget_approvals"

    budget_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    budget_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    project_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("projects.project_id"), nullable=True, index=True
    )

    # Financial Components (EGP & Multi-Currency)
    invoice_amount_egp: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    invoice_amount_foreign: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    invoice_currency: Mapped[Optional[str]] = mapped_column(String(10), default="USD", nullable=True)
    freight_cost_egp: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    freight_cost_foreign: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    freight_currency: Mapped[Optional[str]] = mapped_column(String(10), default="USD", nullable=True)
    customs_duties_egp: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    clearance_inland_egp: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    exchange_rate: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    total_budget_egp: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)

    # Budget Status: 'Draft', 'Pending Review', 'Needs Revalidation', 'Budget Approved', 'Superseded', 'Budget Exceeded', 'Rejected'
    budget_status: Mapped[str] = mapped_column(
        String(50), default="Pending Review", nullable=False, index=True
    )
    approved_by: Mapped[str] = mapped_column(String(100), nullable=True)
    approved_date: Mapped[date] = mapped_column(Date, nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)

    # Versioning & Revision Tracking
    parent_budget_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("import_budget_approvals.budget_id"), nullable=True, index=True
    )
    revision_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Upstream Variance & Segregation of Duties Tracking
    last_variance_check: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    has_unresolved_variance: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    variance_override_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    variance_overridden_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    upstream_modified_by: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Audit & Soft Delete
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )
    created_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    updated_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)


class BudgetVarianceLog(Base):
    """
    Detailed audit log of live upstream variances detected between
    upstream costing sessions (customs clearance, freight, invoice) and import budgets.
    """
    __tablename__ = "budget_variance_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True, index=True)
    budget_id: Mapped[int] = mapped_column(Integer, ForeignKey("import_budget_approvals.budget_id"), nullable=False, index=True)
    import_file_id: Mapped[int] = mapped_column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)

    field_name: Mapped[str] = mapped_column(String(100), nullable=False)
    old_value: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    new_value: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    variance_amount: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    variance_percentage: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    threshold_percentage: Mapped[float] = mapped_column(Float, nullable=False, default=5.0)
    is_hard_block: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    detected_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    modified_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    resolved_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    resolution_type: Mapped[str] = mapped_column(String(50), default="pending", nullable=False)  # 'pending', 'synced', 'overridden', 'dismissed', 'auto_updated'
    justification_note: Mapped[str | None] = mapped_column(Text, nullable=True)


class BudgetVarianceSetting(Base):
    """
    Configurable settings for budget variance thresholds and rules.
    """
    __tablename__ = "budget_variance_settings"

    setting_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True, index=True)
    setting_key: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    setting_value: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    updated_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)


# --- SWIFT EXTRACTION REVIEW LAYER MODELS ---
class SwiftExtractionBatch(Base):
    """
    SWIFT MT103 Extraction Batch.
    Tracks batch lifecycle from raw upload through extraction, human review, confirmation, and matching.
    Lifecycle States:
      - 'EXTRACTED_PENDING_REVIEW': Initial extraction completed, pending human review.
      - 'REVIEWED_CONFIRMED': Human confirmed all fields, unlocked for Matching Matrix.
      - 'RECONCILED': Reconciled with payment request.
      - 'REJECTED': Rejected by human reviewer.
    """
    __tablename__ = "swift_extraction_batches"

    batch_id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    batch_code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    source_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    source_file_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    raw_source_text: Mapped[str] = mapped_column(Text, nullable=False)
    normalized_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(50), default="EXTRACTED_PENDING_REVIEW", nullable=False, index=True
    )
    reviewed_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    matched_payment_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("payment_request_sessions.payment_id"), nullable=True, index=True
    )
    reconciled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    fields: Mapped[list["SwiftExtractionField"]] = relationship(
        "SwiftExtractionField", back_populates="batch", cascade="all, delete-orphan", order_by="SwiftExtractionField.id"
    )


class SwiftExtractionField(Base):
    """
    Individual MT103 Extracted Field.
    Tracks raw snippet, parsed value, user edits, confidence score, and mandatory status.
    Downstream services must strictly read from `final_value`.
    """
    __tablename__ = "swift_extraction_fields"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True, index=True)
    batch_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("swift_extraction_batches.batch_id"), nullable=False, index=True
    )
    field_key: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    swift_field_code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    field_label: Mapped[str] = mapped_column(String(100), nullable=False)
    raw_ocr_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    parsed_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    confidence_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    is_edited_by_user: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    edited_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    final_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_mandatory: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_empty: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )

    batch: Mapped["SwiftExtractionBatch"] = relationship("SwiftExtractionBatch", back_populates="fields")


class OcrCorrectionsLog(Base):
    """
    Audit log of manual field edits performed on extracted SWIFT fields.
    Can be used for continuous learning and improving OCR post-processing dictionaries.
    """
    __tablename__ = "ocr_corrections_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True, index=True)
    batch_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("swift_extraction_batches.batch_id"), nullable=False, index=True
    )
    field_key: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    original_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    corrected_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    corrected_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    corrected_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

