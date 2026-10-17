from datetime import datetime

from pydantic import BaseModel
from pydantic import ConfigDict


# ==================================================
# Base Schema
# ==================================================

class SupplierBase(BaseModel):

    company_name: str

    # Supplier Classification

    supplier_type: str = "Manufacturer"

    registration_type: str = "Foreign Exporter"

    foreign_exporter_id: str = ""

    cargox_platform_id: str | None = None

    foreign_exporter_country: str = "United Kingdom"

    foreign_exporter_country_code: str = "GB"

    tax_id: str | None = None

    currency: str = "USD"

    # Contact & Location Information

    contact_person: str | None = None

    city: str | None = None

    postal_code: str | None = None

    address: str = "Exporter Address"

    phone: str | None = None

    mobile: str | None = None

    fax: str | None = None

    email: str | None = None

    secondary_email: str | None = None

    website: str | None = None

    bank_name: str | None = None

    swift_code: str | None = None

    account_number: str | None = None

    iban: str | None = None

    has_iso: bool = False

    # Trademark & Quality Certificates
    has_wipo: bool = False
    wipo_number: str | None = None
    has_euipo: bool = False
    euipo_number: str | None = None
    has_global_brand: bool = False
    global_brand_number: str | None = None
    has_iso_9001: bool = False
    iso_9001_number: str | None = None

    registered_decree_43: bool = False

    white_list_registered: bool = False

    brands: str | None = None

    payment_terms: str | None = None

    credit_limit: float = 0.0

    rating: float = 5.0

    notes: str | None = None


# ==================================================
# Create Supplier
# ==================================================

class SupplierCreate(SupplierBase):

    created_by: str | None = None


# ==================================================
# Update Supplier
# ==================================================

class SupplierUpdate(BaseModel):

    company_name: str | None = None

    supplier_type: str | None = None

    registration_type: str | None = None

    foreign_exporter_id: str | None = None

    cargox_platform_id: str | None = None

    tax_id: str | None = None

    currency: str | None = None

    foreign_exporter_country: str | None = None

    foreign_exporter_country_code: str | None = None

    contact_person: str | None = None

    city: str | None = None

    postal_code: str | None = None

    address: str | None = None

    phone: str | None = None

    mobile: str | None = None

    fax: str | None = None

    email: str | None = None

    secondary_email: str | None = None

    website: str | None = None

    bank_name: str | None = None

    swift_code: str | None = None

    account_number: str | None = None

    iban: str | None = None

    has_iso: bool | None = None

    has_wipo: bool | None = None
    wipo_number: str | None = None
    has_euipo: bool | None = None
    euipo_number: str | None = None
    has_global_brand: bool | None = None
    global_brand_number: str | None = None
    has_iso_9001: bool | None = None
    iso_9001_number: str | None = None

    registered_decree_43: bool | None = None

    white_list_registered: bool | None = None

    brands: str | None = None

    payment_terms: str | None = None

    credit_limit: float | None = None

    rating: float | None = None

    notes: str | None = None

    is_active: bool | None = None

    updated_by: str | None = None



# ==================================================
# Response Schema
# ==================================================

class SupplierResponse(SupplierBase):

    supplier_id: int

    # Auto Generated Supplier Code
    supplier_code: str

    is_active: bool

    created_at: datetime

    updated_at: datetime | None = None

    created_by: str | None = None

    updated_by: str | None = None


    model_config = ConfigDict(
        from_attributes=True
    )


class SupplierScorecardResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    supplier_id: int
    supplier_code: str
    company_name: str
    supplier_type: str
    country: str
    total_orders_completed: int
    crd_adherence_rate: float
    documentation_accuracy_rate: float
    order_fulfillment_rate: float
    quality_score_out_of_100: float
    star_rating: float
    tier_badge: str
    executive_summary_ar: str