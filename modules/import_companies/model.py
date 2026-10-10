from datetime import datetime, timezone

from sqlalchemy import Boolean
from sqlalchemy import Column
from sqlalchemy import Date
from sqlalchemy import DateTime
from sqlalchemy import Integer
from sqlalchemy import String

from database.database import Base


class ImportCompany(Base):


    __tablename__ = "import_companies"

    # ==================================================
    # Primary Key
    # ==================================================
    company_id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        index=True
    )

    # ==================================================
    # Company Information
    # ==================================================
    importer_name = Column(
        String(200),
        nullable=False
    )

    address = Column(
        String(300),
        nullable=False
    )

    country = Column(
        String(100),
        nullable=False
    )

    foreign_exporter_registration_type = Column(
        String(100)
    )

    # ==================================================
    # Importer ID
    # ==================================================
    importer_id = Column(
        String(100),
        nullable=False,
        unique=True
    )

    importer_id_expiry = Column(
        Date,
        nullable=False
    )

    # ==================================================
    # VAT Registration
    # ==================================================
    vat_id = Column(
        String(100),
        nullable=False,
        unique=True
    )

    vat_id_expiry = Column(
        Date,
        nullable=False
    )

    # ==================================================
    # Commercial Registration
    # ==================================================
    registration_number = Column(
        String(100),
        nullable=False,
        unique=True
    )

    registration_expiry = Column(
        Date,
        nullable=False
    )

    # ==================================================
    # Contact Information
    # ==================================================
    phone = Column(
        String(50)
    )

    mobile = Column(
        String(50),
        nullable=True
    )

    fax = Column(
        String(50),
        nullable=True
    )

    email = Column(
        String(150)
    )

    secondary_email = Column(
        String(150),
        nullable=True
    )

    website = Column(
        String(200),
        nullable=True
    )

    # Nafeza API / Integration Token (Encrypted/Masked in UI)
    nafeza_token = Column(
        String(500),
        nullable=True
    )

    # ==================================================
    # Trademark & Quality Certificates
    # ==================================================
    has_wipo = Column(
        Boolean,
        default=False,
        nullable=False
    )

    wipo_number = Column(
        String(100),
        nullable=True
    )

    has_euipo = Column(
        Boolean,
        default=False,
        nullable=False
    )

    euipo_number = Column(
        String(100),
        nullable=True
    )

    has_global_brand = Column(
        Boolean,
        default=False,
        nullable=False
    )

    global_brand_number = Column(
        String(100),
        nullable=True
    )

    has_iso_9001 = Column(
        Boolean,
        default=False,
        nullable=False
    )

    iso_9001_number = Column(
        String(100),
        nullable=True
    )

    # ==================================================
    # System Fields
    # ==================================================
    is_active = Column(
        Boolean,
        default=True,
        nullable=False
    )

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
        String(100)
    )

    updated_by = Column(
        String(100)
    )

    notes = Column(
        String(500)
    )

    @property
    def has_nafeza_token(self) -> bool:
        """Returns True if nafeza token is configured."""
        return bool(self.nafeza_token and str(self.nafeza_token).strip())

    @property
    def masked_nafeza_token(self) -> str | None:
        """Returns masked token representation (****1234) without exposing secret."""
        if not self.has_nafeza_token:
            return None
        from utils.crypto_utils import mask_secret_token
        return mask_secret_token(self.nafeza_token)