from typing import List, Optional
from fastapi import APIRouter, Depends, status
from modules.auth.router import get_current_user, require_admin
from sqlalchemy.orm import Session

from database.database import get_db
from .schemas import (
    ACIDLiveRequest,
    CargoXEnvelopeLiveRequest,
    CargoXTransferLiveRequest,
    PKISignPayloadRequest,
    NafezaTariffParseRequest,
    NafezaTariffSyncResponse,
    CustomsExchangeRateItem,
    CustomsExchangeRateSyncResponse,
    GOEICComplianceCheckRequest,
    GOEICComplianceCheckResponse,
    AccreditedInspectionBody,
    IntegrationProviderStatus,
    IntegrationStatusResponse,
)
from .integration_mode import integration_status_report
from utils.db_safety import is_frozen_build
from .nafeza_client import NafezaIntegrationClient
from .cargox_client import CargoXIntegrationClient
from .pki_signer import PKISignerService
from .goeic_client import GOEICIntegrationClient

router = APIRouter(prefix="/api/v1/integrations", tags=["Nafeza, CargoX, GOEIC & Customs Integrations"], dependencies=[Depends(get_current_user)])


# The integration mode is read from server settings (Production Mock Guard, NLv0Dpj5); the deprecated
# ``mode`` field of the request bodies is ignored so a client can never pick the mode itself.

@router.get("/status", response_model=IntegrationStatusResponse)
def get_integration_status():
    """Per-provider integration mode for the Flutter Integration Status panel and simulation badges."""
    providers = [IntegrationProviderStatus(**vars(item)) for item in integration_status_report()]
    return IntegrationStatusResponse(
        is_production_build=is_frozen_build(),
        any_simulated=any(p.is_simulated for p in providers),
        providers=providers,
    )


@router.post("/nafeza/request-acid")
def request_acid_from_nafeza(request: ACIDLiveRequest):
    client = NafezaIntegrationClient()
    return client.request_acid_number(
        importer_id=request.importer_id,
        exporter_id=request.exporter_id,
        exporter_country_code=request.exporter_country_code,
        tariff_hs_codes=request.tariff_hs_codes,
        invoice_value_usd=request.invoice_value_usd,
    )


@router.post("/cargox/create-envelope")
def create_cargox_envelope(request: CargoXEnvelopeLiveRequest):
    client = CargoXIntegrationClient()
    return client.create_envelope(
        acid_number=request.acid_number,
        importer_company_code=request.importer_company_code,
        foreign_exporter_cargox_id=request.foreign_exporter_cargox_id,
        document_types=request.document_types,
    )


@router.post("/cargox/transfer-envelope")
def transfer_cargox_envelope(request: CargoXTransferLiveRequest):
    client = CargoXIntegrationClient()
    return client.transfer_envelope_to_customs(
        envelope_id=request.envelope_id,
        bl_number=request.bl_number,
    )


@router.post("/pki/sign-payload", dependencies=[Depends(require_admin)])
def sign_payload_with_pki(request: PKISignPayloadRequest):
    signer = PKISignerService()
    return signer.sign_payload(request.payload_data)


# =========================================================================
# INT-NAFEZA-008: Nafeza Tariff & Exchange Rate Endpoints
# =========================================================================

@router.post("/nafeza/tariffs/parse-and-sync", response_model=NafezaTariffSyncResponse)
def parse_and_sync_nafeza_tariff(
    request: NafezaTariffParseRequest,
    db: Session = Depends(get_db),
):
    """
    محلل ومزامن بنود التعريفة الجمركية من موقع نافذة (Smart Nafeza Tariff Sync).
    يستقبل النص المنسوخ من موقع نافذة ويستخرج البند، الوصف، الضرائب والرسوم،
    والاتفاقيات التفضيلية والتخفيضات ويقوم بحفظها وتحديثها في قاعدة البيانات.
    """
    client = NafezaIntegrationClient()
    return client.parse_and_sync_tariff(db, request.raw_text)


@router.get("/nafeza/tariffs/{hs_code}", response_model=NafezaTariffSyncResponse)
def get_nafeza_tariff_details(
    hs_code: str,
    db: Session = Depends(get_db),
):
    """
    استرجاع بيانات بند التعريفة الجمركية والاتفاقيات التفضيلية من منظومة نافذة/النظام.
    """
    client = NafezaIntegrationClient()
    return client.lookup_tariff_by_hs_code(db, hs_code)


@router.post("/nafeza/exchange-rates/sync", response_model=CustomsExchangeRateSyncResponse)
def sync_customs_exchange_rates(
    rates_override: Optional[dict] = None,
    db: Session = Depends(get_db),
):
    """
    مزامنة أسعار الصرف الجمركية الرسمية (سعر الصرف الجمركي) الصادرة عن مصلحة الجمارك المصرية.
    تحديث جدول العملات وأسعار الصرف الفعّالة للنظام.
    """
    client = NafezaIntegrationClient()
    return client.sync_official_customs_exchange_rates(db, rates_override=rates_override)


@router.get("/nafeza/exchange-rates/latest", response_model=List[CustomsExchangeRateItem])
def get_latest_customs_exchange_rates(
    db: Session = Depends(get_db),
):
    """
    استعراض أحدث أسعار صرف العملات الجمركية الرسمية المعتمدة في النظام.
    """
    client = NafezaIntegrationClient()
    return client.get_latest_customs_exchange_rates(db)


# =========================================================================
# INT-GOEIC-009: GOEIC Quality Inspection & Factory Registration Endpoints
# =========================================================================

@router.post("/goeic/verify-compliance", response_model=GOEICComplianceCheckResponse)
def verify_goeic_compliance(
    request: GOEICComplianceCheckRequest,
    db: Session = Depends(get_db),
):
    """
    بوابة التحقق الاستباقي لهيئة الرقابة على الصادرات والواردات (GOEIC Compliance Hub).
    يتحقق من:
    1. خضوع الصنف للقرار 43 لسنة 2016 وتسجيل المصنع في القائمة البيضاء.
    2. اشتراطات الفحص المسبق قبل الشحن واعتماد شهادة المطابقة (COI).
    """
    client = GOEICIntegrationClient()
    return client.check_compliance(db, request)


@router.get("/goeic/accredited-inspection-bodies", response_model=List[AccreditedInspectionBody])
def get_goeic_accredited_inspection_bodies():
    """
    قائمة شركات التفتيش والفحص الدولية المعتمدة رسمياً لدى الهيئة العامة للرقابة على الصادرات والواردات.
    """
    client = GOEICIntegrationClient()
    return client.get_accredited_inspection_bodies()

