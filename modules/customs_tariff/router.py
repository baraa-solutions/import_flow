from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from modules.auth.router import get_current_user
from fastapi.responses import Response
from sqlalchemy.orm import Session

from database.database import get_db
from utils.cache_manager import memory_cache
from utils.export_import_helper import MasterDataExportImportHelper

from .schemas import (
    CustomsDutyBreakdown,
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    CustomsTariffResponse,
    CustomsTariffUpdate,
    MultiItemCustomsBreakdown,
    MultiItemCustomsEstimateRequest,
    PreferentialAgreementCreate,
    PreferentialAgreementResponse,
    TariffVerificationRequest,
    ImportFileCustomsSimulationRequest,
    ImportFileCustomsSimulationResponse,
)
from .service import (
    bulk_import_tariffs_service,
    create_preferential_agreement_service,
    create_tariff_service,
    delete_tariff_service,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
    simulate_import_file_customs_duty_service,
    get_agreements_by_hs_code_service,
    get_all_tariffs_service,
    get_tariff_by_hs_code_service,
    get_tariff_by_id_service,
    restore_tariff_service,
    update_tariff_service,
    verify_and_update_tariff_service,
)

customs_tariff_router = APIRouter(prefix="/api/v1/customs-tariff", tags=["Customs Tariff"], dependencies=[Depends(get_current_user)])


@customs_tariff_router.get("", response_model=List[CustomsTariffResponse])
def get_all_tariffs(
    include_inactive: bool = Query(False),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0, description="Offset for pagination"),
    limit: Optional[int] = Query(None, ge=1, le=5000, description="Page limit"),
    db: Session = Depends(get_db),
):
    cache_key = f"customs_tariff:list:{include_inactive}:{search}:{skip}:{limit}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_all_tariffs_service(
        db,
        include_inactive=include_inactive,
        search=search,
        skip=skip,
        limit=limit,
    )
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@customs_tariff_router.post("", response_model=CustomsTariffResponse)
def create_tariff(data: CustomsTariffCreate, db: Session = Depends(get_db)):
    try:
        res = create_tariff_service(db, data)
        memory_cache.clear_prefix("customs_tariff:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@customs_tariff_router.get("/", response_model=List[CustomsTariffResponse])
def list_tariffs(
    include_inactive: bool = Query(False),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0, description="Offset for pagination"),
    limit: Optional[int] = Query(None, ge=1, le=5000, description="Page limit"),
    db: Session = Depends(get_db),
):
    cache_key = f"customs_tariff:list:{include_inactive}:{search}:{skip}:{limit}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_all_tariffs_service(
        db,
        include_inactive=include_inactive,
        search=search,
        skip=skip,
        limit=limit,
    )
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@customs_tariff_router.post("/estimate", response_model=CustomsDutyBreakdown)
def estimate_customs_duty(request: CustomsDutyEstimateRequest, db: Session = Depends(get_db)):
    """
    Egyptian Customs Calculation Engine API Endpoint.
    Estimates customs duties, VAT, schedule tax, and development fees based on the HS Code.
    """
    return estimate_customs_duty_service(db, request)


@customs_tariff_router.post("/estimate-multi", response_model=MultiItemCustomsBreakdown)
def estimate_multi_item_customs_duty(
    request: MultiItemCustomsEstimateRequest, db: Session = Depends(get_db)
):
    """
    Egyptian Multi-Item Customs Calculation Engine API Endpoint.
    Estimates customs duties, VAT, schedule taxes, and grand totals for multi-item invoices based on official Nafeza specifications.
    """
    return estimate_multi_item_customs_duty_service(db, request)


@customs_tariff_router.get("/export-excel", summary="Export all customs tariffs to Excel (XLSX)")
def export_tariffs_excel(db: Session = Depends(get_db)):
    tariffs = get_all_tariffs_service(db, include_inactive=True)
    headers = [
        'HS Code', 'Description', 'Category', 'Duty %', 'VAT %',
        'Schedule Tax %', 'Development Fee %', 'Service Fee %',
        'ACID Req', 'COO Req', 'Inspection Req', 'Regulatory Authorities',
        'Effective From', 'Effective To', 'Status'
    ]
    rows = []
    for t in tariffs:
        rows.append([
            t.hs_code,
            t.hs_description,
            t.customs_category or '',
            t.customs_duty_rate,
            t.vat_rate,
            t.schedule_tax_rate,
            t.development_fee_rate,
            t.customs_service_fee_rate,
            'Yes' if t.requires_acid else 'No',
            'Yes' if t.requires_coo else 'No',
            'Yes' if t.requires_inspection else 'No',
            t.regulatory_authority or '',
            t.effective_from,
            t.effective_to or '',
            'Active' if t.is_active else 'Inactive',
        ])
    content = MasterDataExportImportHelper.export_to_excel("Customs Tariff Schedule", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Customs_Tariff_Schedule", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@customs_tariff_router.get("/export-pdf", summary="Export all customs tariffs to PDF")
def export_tariffs_pdf(db: Session = Depends(get_db)):
    tariffs = get_all_tariffs_service(db, include_inactive=True)
    headers = ['HS Code', 'Description', 'Category', 'Duty %', 'VAT %', 'ACID', 'Status']
    rows = []
    for t in tariffs:
        rows.append([
            t.hs_code,
            t.hs_description,
            t.customs_category or '',
            f"{t.customs_duty_rate}%",
            f"{t.vat_rate}%",
            'Yes' if t.requires_acid else 'No',
            'Active' if t.is_active else 'Inactive',
        ])
    content = MasterDataExportImportHelper.export_to_pdf("Egyptian Customs Tariff Schedule (MD-008)", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Customs_Tariff_Schedule", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@customs_tariff_router.get("/hs/{hs_code}", response_model=CustomsTariffResponse)
def get_tariff_by_hs_code(hs_code: str, db: Session = Depends(get_db)):
    cache_key = f"customs_tariff:hs:{hs_code}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_tariff_by_hs_code_service(db, hs_code)
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@customs_tariff_router.get("/{tariff_id}", response_model=CustomsTariffResponse)
def get_tariff(tariff_id: int, db: Session = Depends(get_db)):
    return get_tariff_by_id_service(db, tariff_id)


@customs_tariff_router.put("/{tariff_id}", response_model=CustomsTariffResponse)
def update_tariff(tariff_id: int, data: CustomsTariffUpdate, db: Session = Depends(get_db)):
    try:
        res = update_tariff_service(db, tariff_id, data)
        memory_cache.clear_prefix("customs_tariff:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@customs_tariff_router.delete("/{tariff_id}", response_model=CustomsTariffResponse)
def delete_tariff(tariff_id: int, db: Session = Depends(get_db)):
    res = delete_tariff_service(db, tariff_id)
    memory_cache.clear_prefix("customs_tariff:")
    return res


@customs_tariff_router.patch("/{tariff_id}/restore", response_model=CustomsTariffResponse)
def restore_tariff(tariff_id: int, db: Session = Depends(get_db)):
    res = restore_tariff_service(db, tariff_id)
    memory_cache.clear_prefix("customs_tariff:")
    return res


@customs_tariff_router.post("/hs/{hs_code}/verify", response_model=CustomsTariffResponse)
def verify_and_update_tariff(
    hs_code: str, request: TariffVerificationRequest, db: Session = Depends(get_db)
):
    """
    تسجيل مراجعة يدوية وتحديث لبيانات البند الجمركي (Addendum 3 Workflow).
    في حال تغيير نسب الضرائب، يتم إنشاء إيراد جديد أوتوماتيكياً والحفاظ على السجل التاريخي.
    """
    res = verify_and_update_tariff_service(db, hs_code, request)
    memory_cache.clear_prefix("customs_tariff:")
    return res


@customs_tariff_router.get("/hs/{hs_code}/agreements", response_model=List[PreferentialAgreementResponse])
def get_agreements_by_hs_code(
    hs_code: str, origin_country: Optional[str] = Query(None), db: Session = Depends(get_db)
):
    """
    استرجاع الاتفاقيات التجارية التفضيلية الخاصة ببند جمركي معين.
    """
    return get_agreements_by_hs_code_service(db, hs_code, origin_country)


@customs_tariff_router.post("/agreements", response_model=PreferentialAgreementResponse)
def create_preferential_agreement(
    data: PreferentialAgreementCreate, db: Session = Depends(get_db)
):
    """
    إضافة اتفاقية تفضيلية جديدة مرتبط بدولة منشأ وبند جمركي.
    """
    res = create_preferential_agreement_service(db, data)
    memory_cache.clear_prefix("customs_tariff:")
    return res


@customs_tariff_router.post("/upload-excel")
async def upload_customs_tariffs(file: UploadFile = File(...), db: Session = Depends(get_db)):
    """
    Upload Excel/CSV file containing Nafeza/Egyptian Customs Tariffs (HS Codes) for bulk creation or update.
    """
    contents = await file.read()
    res = bulk_import_tariffs_service(db, contents, file.filename or "uploaded.csv")
    memory_cache.clear_prefix("customs_tariff:")
    return res


@customs_tariff_router.get("/export-template")
def export_customs_tariff_template():
    """
    Download sample CSV template for Egyptian Customs Tariff (MD-008).
    """
    csv_content = (
        "hs_code,hs_description,customs_category,customs_duty_rate,vat_rate,schedule_tax_rate,development_fee_rate,import_fee_rate,regulatory_authority,requires_coo,requires_inspection,requires_acid,notes\n"
        "1001.99.00,Wheat and meslin (Other than durum wheat),Agriculture & Food,0.0,0.0,0.0,0.0,0.0,GOEIC & NFSA,true,true,true,Essential Strategic Commodity\n"
        "8471.30.00,Portable laptops & notebooks,Electronics,5.0,14.0,0.0,5.0,0.0,NTRA,true,true,true,NTRA Approval Required\n"
        "8703.23.00,Passenger cars 1600cc to 2000cc,Automotive,135.0,14.0,15.0,5.5,0.0,GOEIC,true,true,true,Schedule Tax 15%\n"
    )
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=customs_tariff_template.csv"},
    )


from .schemas import FeeCodeCreate, FeeCodeResponse
from .service import create_fee_code_service, get_all_fee_codes_service


@customs_tariff_router.get("/fee-codes", response_model=List[FeeCodeResponse])
def get_all_fee_codes(include_inactive: bool = Query(False), db: Session = Depends(get_db)):
    """
    استرجاع رسوم الإقرارات والنافذة الموحدة الرسمية.
    """
    return get_all_fee_codes_service(db, include_inactive)


@customs_tariff_router.post("/fee-codes", response_model=FeeCodeResponse)
def create_fee_code(data: FeeCodeCreate, db: Session = Depends(get_db)):
    """
    إضافة كود رسم جديد لقائمة تحصيل نافذة والجمارك المصرية.
    """
    return create_fee_code_service(db, data)


# ==================================================
# Smart Nafeza Text Parser & Origin Check Endpoints
# ==================================================

from .schemas import (
    SmartTariffParseRequest,
    SmartTariffParseResponse,
    TariffAgreementBulkSaveRequest,
    OriginDutyCheckRequest,
    OriginDutyCheckResponse,
)
from .service import (
    parse_smart_nafeza_tariff_text_service,
    save_tariff_with_agreements_service,
    evaluate_duty_by_origin_and_document_service,
    get_tariff_version_history_service,
)


@customs_tariff_router.post("/parse-text", response_model=SmartTariffParseResponse)
def parse_smart_nafeza_tariff_text(payload: SmartTariffParseRequest, db: Session = Depends(get_db)):
    """
    محلل وصائغ النصوص الجمركية الذكي (Smart Nafeza Tariff Text Parser).
    يقوم بتحليل نص البند المجمع المنسوخ من موقع/شيت نافذة واستخراج كود البند والوصف والضرائب والاتفاقيات،
    مع مقارنة التعديلات والإضافات والمحذوفات فورياً بالنسخة السابقة الفعالة في قاعدة البيانات.
    """
    try:
        return parse_smart_nafeza_tariff_text_service(payload.raw_text, db=db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@customs_tariff_router.post("/with-agreements")
def save_tariff_with_agreements(payload: TariffAgreementBulkSaveRequest, db: Session = Depends(get_db)):
    """
    حفظ/تحديث البند الجمركي مع كافة الاتفاقيات التفضيلية الخاصة به مع الحفاظ الكامل على السجلات واللقطات التاريخية.
    """
    return save_tariff_with_agreements_service(db, payload)


@customs_tariff_router.post("/check-duty-for-origin", response_model=OriginDutyCheckResponse)
def check_duty_for_origin_and_document(payload: OriginDutyCheckRequest, db: Session = Depends(get_db)):
    """
    استعلام وتقييم فئة الضريبة الجمركية والتنبيهات حسب بلد المنشأ وتأكيد المستند المطلوب (EUR.1).
    """
    return evaluate_duty_by_origin_and_document_service(db, payload)


@customs_tariff_router.get("/history/{hs_code}")
def get_tariff_version_history(hs_code: str, db: Session = Depends(get_db)):
    """
    استعلام سجل تاريخ السريان والإصدارات السابقة والحالية للبند الجمركي (HS Code Tariff History).
    """
    return get_tariff_version_history_service(db, hs_code)


@customs_tariff_router.post("/simulate-file/{import_file_id}", response_model=ImportFileCustomsSimulationResponse)
def simulate_import_file_customs_duties(
    import_file_id: int,
    payload: Optional[ImportFileCustomsSimulationRequest] = None,
    db: Session = Depends(get_db),
):
    """
    محاكاة واحتساب الرسوم والضرائب التقديرية لملف استيرادي (PL-07: Customs Duty Simulation)
    تستخرج بنود أمر الشراء أو الفواتير والنولون المعتمد وأسعار الصرف، وتحسب الرسوم وتحدث دراسة الاستشارة.
    """
    return simulate_import_file_customs_duty_service(db, import_file_id, payload)


