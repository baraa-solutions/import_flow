from typing import List, Optional
from pydantic import BaseModel, Field


class ACIDLiveRequest(BaseModel):
    importer_id: str = Field(..., description="Importer Tax ID / Code")
    exporter_id: str = Field(..., description="Foreign Exporter Registration Code")
    exporter_country_code: str = Field("CN", min_length=2, max_length=2)
    tariff_hs_codes: List[str] = Field(..., min_length=1)
    invoice_value_usd: float = Field(..., gt=0)
    mode: Optional[str] = Field(None, description="Deprecated and ignored: the integration mode comes from server settings")


class CargoXEnvelopeLiveRequest(BaseModel):
    acid_number: str = Field(..., min_length=5)
    importer_company_code: str
    foreign_exporter_cargox_id: str
    document_types: List[str] = Field(default=["Commercial Invoice", "Bill of Lading", "Certificate of Origin", "Packing List"])
    mode: Optional[str] = Field(None, description="Deprecated and ignored: the integration mode comes from server settings")


class CargoXTransferLiveRequest(BaseModel):
    envelope_id: str
    bl_number: str
    mode: Optional[str] = Field(None, description="Deprecated and ignored: the integration mode comes from server settings")


class PKISignPayloadRequest(BaseModel):
    payload_data: dict
    mode: Optional[str] = Field(None, description="Deprecated and ignored: the integration mode comes from server settings")


# =========================================================================
# INT-NAFEZA-008: Nafeza Tariff & Customs Exchange Rate Schemas
# =========================================================================

class NafezaTariffParseRequest(BaseModel):
    raw_text: str = Field(..., min_length=10, description="نص البند المنسوخ من موقع نافذة")
    mode: Optional[str] = Field(None, description="Deprecated and ignored: the integration mode comes from server settings")


class NafezaTariffSyncResponse(BaseModel):
    hs_code: str
    hs_description: str
    customs_duty_rate: float
    vat_rate: float
    schedule_tax_rate: float
    development_fee_rate: float
    import_fee_rate: float
    requires_inspection: bool
    regulatory_authority: Optional[str] = None
    agreements_count: int
    agreements_summary: List[dict] = []
    message: str


class CustomsExchangeRateItem(BaseModel):
    currency_code: str
    currency_name: str
    exchange_rate: float
    previous_rate: Optional[float] = None
    effective_date: str
    source: str = "Egyptian Customs Authority (مصلحة الجمارك المصرية)"


class CustomsExchangeRateSyncResponse(BaseModel):
    status: str
    synced_count: int
    rates: List[CustomsExchangeRateItem]
    announcement_date: str
    message: str


# =========================================================================
# INT-GOEIC-009: GOEIC Quality Inspection & Decree 43 Schemas
# =========================================================================

class GOEICComplianceCheckRequest(BaseModel):
    supplier_id: int
    hs_code: str
    country_of_origin: Optional[str] = None
    has_coi_certificate: bool = False
    coi_agency: Optional[str] = None
    coi_number: Optional[str] = None


class GOEICComplianceCheckResponse(BaseModel):
    supplier_id: int
    supplier_name: str
    hs_code: str
    is_decree_43_mandated: bool
    is_factory_registered: bool
    factory_registration_number: Optional[str] = None
    decree_43_status: str  # Registered, Not Registered, Pending Verification
    requires_preshipment_inspection: bool
    coi_valid: bool
    overall_compliance_verdict: str  # CLEARED_FOR_IMPORT, BLOCKED_DECREE_43_VIOLATION, PENDING_COI_CERTIFICATE
    warning_message_ar: Optional[str] = None
    recommended_action_ar: str


class AccreditedInspectionBody(BaseModel):
    body_id: str
    name_en: str
    name_ar: str
    country_headquarters: str
    accreditation_scope: str
    is_active: bool = True



# =========================================================================
# Production Mock Guard (NLv0Dpj5): integration status panel
# =========================================================================

class IntegrationProviderStatus(BaseModel):
    provider: str
    integration_mode: str = Field(..., description="MOCK, SANDBOX or LIVE")
    is_simulated: bool
    is_available: bool
    message: str


class IntegrationStatusResponse(BaseModel):
    is_production_build: bool
    any_simulated: bool
    providers: List[IntegrationProviderStatus]
