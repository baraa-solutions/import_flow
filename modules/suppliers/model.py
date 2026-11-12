from datetime import datetime, timezone

from sqlalchemy import Boolean
from sqlalchemy import CheckConstraint
from sqlalchemy import ForeignKey
from sqlalchemy import Index
from sqlalchemy import UniqueConstraint
from sqlalchemy import Column
from sqlalchemy import DateTime
from sqlalchemy import Date
from sqlalchemy import Float
from sqlalchemy import Integer
from sqlalchemy import String
from sqlalchemy import Text

from database.database import Base



class Supplier(Base):

    __tablename__ = "suppliers"


    # ==================================================
    # Primary Key
    # ==================================================

    supplier_id = Column(
        Integer,
        primary_key=True,
        autoincrement=True
    )


    supplier_code = Column(
        String(50),
        nullable=False,
        unique=True,
        index=True
    )


    # ==================================================
    # Company Information
    # ==================================================

    company_name = Column(
        String(200),
        nullable=False,
        index=True
    )


    supplier_type = Column(
        String(50),
        nullable=False,
        index=True
    )


    registration_type = Column(
        String(50),
        nullable=False
    )


    foreign_exporter_id = Column(
        String(100),
        nullable=False,
        unique=True
    )


    # CargoX Platform Registration ID
    cargox_platform_id = Column(
        String(100),
        nullable=True
    )


    # Foreign Tax / VAT Registration ID
    tax_id = Column(
        String(50),
        nullable=True
    )

    # Contract / Transacting Currency (e.g. USD, EUR, CNY)
    currency = Column(
        String(10),
        default="USD",
        nullable=False
    )


    # ==================================================
    # Country Information
    # ==================================================

    foreign_exporter_country = Column(
        String(100),
        nullable=False
    )


    foreign_exporter_country_code = Column(
        String(10),
        nullable=False
    )

    city = Column(
        String(100),
        nullable=True
    )

    postal_code = Column(
        String(20),
        nullable=True
    )


    # ==================================================
    # Contact Information
    # ==================================================

    contact_person = Column(
        String(150),
        nullable=True
    )

    address = Column(
        String(300),
        nullable=False
    )


    phone = Column(
        String(50),
        nullable=True
    )


    email = Column(
        String(150),
        nullable=True,
        index=True
    )

    secondary_email = Column(
        String(150),
        nullable=True
    )

    mobile = Column(
        String(50),
        nullable=True
    )

    fax = Column(
        String(50),
        nullable=True
    )

    website = Column(
        String(200),
        nullable=True
    )

    # ==================================================
    # Banking Information
    # ==================================================

    bank_name = Column(
        String(200),
        nullable=True
    )

    swift_code = Column(
        String(50),
        nullable=True
    )

    account_number = Column(
        String(100),
        nullable=True
    )

    iban = Column(
        String(100),
        nullable=True
    )

    # ==================================================
    # Business & Compliance Flags
    # ==================================================

    has_iso = Column(
        Boolean,
        default=False,
        nullable=False
    )

    # Trademark & Quality Certificates
    has_wipo = Column(Boolean, default=False, nullable=False)
    wipo_number = Column(String(100), nullable=True)
    has_euipo = Column(Boolean, default=False, nullable=False)
    euipo_number = Column(String(100), nullable=True)
    has_global_brand = Column(Boolean, default=False, nullable=False)
    global_brand_number = Column(String(100), nullable=True)
    has_iso_9001 = Column(Boolean, default=False, nullable=False)
    iso_9001_number = Column(String(100), nullable=True)
    # Expiry dates (Trello TJ6Guorp): nullable — rows saved before the feature have none.
    wipo_expiry = Column(Date, nullable=True)
    euipo_expiry = Column(Date, nullable=True)
    global_brand_expiry = Column(Date, nullable=True)
    iso_9001_expiry = Column(Date, nullable=True)

    registered_decree_43 = Column(
        Boolean,
        default=False,
        nullable=False
    )

    white_list_registered = Column(
        Boolean,
        default=False,
        nullable=False
    )

    brands = Column(
        Text,
        nullable=True
    )

    payment_terms = Column(
        String(100),
        nullable=True
    )

    credit_limit = Column(
        Float,
        default=0.0,
        nullable=False
    )

    # Credit limit governance (Trello GzFff0Pc). ``credit_limit`` <= 0 means "no limit". The limit is expressed
    # in ``credit_limit_currency`` (NULL -> the supplier contract ``currency``). Policy BLOCK refuses a new
    # commitment beyond the limit unless an ADMIN records an override; WARN only warns.
    credit_limit_currency = Column(
        String(10),
        nullable=True
    )

    credit_limit_policy = Column(
        String(10),
        CheckConstraint("credit_limit_policy IN ('WARN', 'BLOCK')", name="credit_limit_policy"),
        default="BLOCK",
        server_default="BLOCK",
        nullable=False
    )

    rating = Column(
        Float,
        default=5.0,
        nullable=False
    )

    notes = Column(
        Text,
        nullable=True
    )


    # ==================================================
    # ERP Status
    # ==================================================

    is_active = Column(
        Boolean,
        default=True,
        nullable=False
    )


    # ==================================================
    # Audit Fields
    # ==================================================

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )


    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )



    created_by = Column(
        String(100),
        nullable=True
    )


    updated_by = Column(
        String(100),
        nullable=True
    )


    # ==================================================
    # Representation
    # ==================================================

    def __repr__(self):

        return (
            f"<Supplier "
            f"id={self.supplier_id} "
            f"name={self.company_name}>"
        )


# ==================================================
# Foreign Vendor Multi-Currency Sub-Ledger (Trello GzFff0Pc)
# ==================================================

LEDGER_ENTRY_TYPES = ("ADVANCE_PAID", "LC_COMMITTED", "CAD_ACCEPTED", "INVOICE_BILLED", "PAYMENT_SETTLED")
LEDGER_DIRECTIONS = ("CREDIT", "DEBIT", "MEMO")
LEDGER_STATUSES = ("OPEN", "PARTIAL", "SETTLED", "UNAPPLIED")


class SupplierLedgerEntry(Base):
    """One movement of a foreign supplier account, in the movement currency.

    System generated from the sources of truth (``suppliers.ledger_service.sync_supplier_ledger``): commercial
    invoices valued by the net FOB engine (CREDIT, liability up), paid payment requests and bank-settled LC/CAD
    instruments (DEBIT, liability down) and LC / CAD commitments (MEMO, never part of the balance). ``source_key``
    identifies the source row so a re-sync updates the entry in place instead of adding a second one.
    """

    __tablename__ = "supplier_ledger_entries"

    entry_id = Column(Integer, primary_key=True, autoincrement=True)
    entry_code = Column(String(30), nullable=False, unique=True, index=True)  # SLE-000001
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False, index=True)
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True)
    payment_id = Column(Integer, ForeignKey("payment_request_sessions.payment_id"), nullable=True, index=True)
    finance_instrument_id = Column(Integer, ForeignKey("import_finance_instruments.id"), nullable=True, index=True)
    source_key = Column(String(160), nullable=False)
    entry_type = Column(
        String(20),
        CheckConstraint(
            "entry_type IN ('ADVANCE_PAID', 'LC_COMMITTED', 'CAD_ACCEPTED', 'INVOICE_BILLED', 'PAYMENT_SETTLED')",
            name="entry_type",
        ),
        nullable=False,
    )
    direction = Column(
        String(10), CheckConstraint("direction IN ('CREDIT', 'DEBIT', 'MEMO')", name="direction"), nullable=False,
    )
    payment_pathway = Column(String(20), nullable=True)
    reference = Column(String(120), nullable=True)
    entry_date = Column(Date, nullable=False)
    due_date = Column(Date, nullable=True)
    currency = Column(String(10), nullable=False)
    amount_fx = Column(Float, CheckConstraint("amount_fx >= 0", name="amount_fx"), nullable=False)
    exchange_rate = Column(Float, nullable=True)
    amount_egp = Column(Float, nullable=False, default=0.0)
    open_amount_fx = Column(Float, nullable=False, default=0.0)
    status = Column(
        String(10),
        CheckConstraint("status IN ('OPEN', 'PARTIAL', 'SETTLED', 'UNAPPLIED')", name="status"),
        nullable=False,
        default="OPEN",
    )
    description = Column(Text, nullable=True)

    is_active = Column(Boolean, nullable=False, default=True)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

    __table_args__ = (
        UniqueConstraint("supplier_id", "source_key", name="uq_supplier_ledger_source"),
        Index("ix_supplier_ledger_supplier_currency", "supplier_id", "currency"),
    )


class SupplierCreditOverride(Base):
    """Audit record of an ADMIN override of a BLOCK credit limit (who, why, and the figures at that moment)."""

    __tablename__ = "supplier_credit_overrides"

    override_id = Column(Integer, primary_key=True, autoincrement=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False, index=True)
    context = Column(String(30), nullable=False)  # PURCHASE_ORDER
    reference = Column(String(100), nullable=True)  # e.g. the PO number
    currency = Column(String(10), nullable=False)  # the credit limit currency
    limit_amount = Column(Float, nullable=False)
    utilization_amount = Column(Float, nullable=False)
    requested_amount = Column(Float, nullable=False)
    projected_amount = Column(Float, nullable=False)
    reason = Column(Text, nullable=False)

    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, nullable=False, default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    created_by = Column(String(100), nullable=False)
    updated_by = Column(String(100), nullable=True)
