from datetime import date
from datetime import datetime

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import EmailStr
from pydantic import model_validator


# ==========================================================
# Base Schema
# ==========================================================

class ImportCompanyBase(BaseModel):

    importer_name: str
    address: str = "Cairo, Egypt"
    country: str = "Egypt"
    foreign_exporter_registration_type: str | None = None

    importer_id: str = "IMP-REG-001"
    importer_id_expiry: date = date(2030, 12, 31)

    vat_id: str = "000000000"
    vat_id_expiry: date = date(2030, 12, 31)

    registration_number: str = "000000"
    registration_expiry: date = date(2030, 12, 31)

    phone: str | None = None
    mobile: str | None = None
    fax: str | None = None
    email: str | None = None
    secondary_email: str | None = None
    website: str | None = None
    nafeza_token: str | None = None

    # Trademark & Quality Certificates
    has_wipo: bool = False
    wipo_number: str | None = None
    has_euipo: bool = False
    euipo_number: str | None = None
    has_global_brand: bool = False
    global_brand_number: str | None = None
    has_iso_9001: bool = False
    iso_9001_number: str | None = None
    nafeza_token_expiry: date | None = None
    wipo_expiry: date | None = None
    euipo_expiry: date | None = None
    global_brand_expiry: date | None = None
    iso_9001_expiry: date | None = None

    notes: str | None = None


# ==========================================================
# Create Schema
# ==========================================================

class ImportCompanyCreate(ImportCompanyBase):

    created_by: str | None = None


# ==========================================================
# Update Schema
# ==========================================================

class ImportCompanyUpdate(BaseModel):

    importer_name: str | None = None
    address: str | None = None
    country: str | None = None

    foreign_exporter_registration_type: str | None = None

    importer_id: str | None = None
    importer_id_expiry: date | None = None

    vat_id: str | None = None
    vat_id_expiry: date | None = None

    registration_number: str | None = None
    registration_expiry: date | None = None

    phone: str | None = None
    mobile: str | None = None
    fax: str | None = None
    email: str | None = None
    secondary_email: str | None = None
    website: str | None = None
    nafeza_token: str | None = None

    has_wipo: bool | None = None
    wipo_number: str | None = None
    has_euipo: bool | None = None
    euipo_number: str | None = None
    has_global_brand: bool | None = None
    global_brand_number: str | None = None
    has_iso_9001: bool | None = None
    iso_9001_number: str | None = None
    nafeza_token_expiry: date | None = None
    wipo_expiry: date | None = None
    euipo_expiry: date | None = None
    global_brand_expiry: date | None = None
    iso_9001_expiry: date | None = None

    notes: str | None = None

    is_active: bool | None = None

    updated_by: str | None = None


# ==========================================================
# Response Schema
# ==========================================================

class ImportCompanyResponse(ImportCompanyBase):

    company_id: int

    importer_id_days_to_renew: int | None = None
    vat_id_days_to_renew: int | None = None
    registration_days_to_renew: int | None = None

    is_active: bool

    created_at: datetime
    updated_at: datetime

    created_by: str | None = None
    updated_by: str | None = None

    # Security: never return plaintext nafeza_token; provide presence flag & masked last-4
    has_nafeza_token: bool = False
    masked_nafeza_token: str | None = None
    nafeza_token: str | None = None

    model_config = ConfigDict(
        from_attributes=True
    )

    @model_validator(mode="after")
    def sanitize_secret_token(self) -> "ImportCompanyResponse":
        raw = self.nafeza_token
        if raw and str(raw).strip():
            self.has_nafeza_token = True
            if not self.masked_nafeza_token:
                from utils.crypto_utils import mask_secret_token
                self.masked_nafeza_token = mask_secret_token(raw)
        elif self.masked_nafeza_token:
            self.has_nafeza_token = True
        self.nafeza_token = None
        return self
