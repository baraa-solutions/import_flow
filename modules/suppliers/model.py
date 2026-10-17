from datetime import datetime, timezone

from sqlalchemy import Boolean
from sqlalchemy import Column
from sqlalchemy import DateTime
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