from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db
from modules.common.pagination import Page, PageParams
from .schemas import PartnerCreate, PartnerResponse, PartnerUpdate, PartnerStatementOfAccountResponse, PartnerScorecardResponse
from .service import ExternalServiceProviderService




router = APIRouter(
    prefix="/api/v1/external-service-providers",
    tags=["External Service Providers & Financial Partners (MD-003)"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/paginated", response_model=Page[PartnerResponse])
def get_paginated_partners(
    response: Response,
    params: PageParams = Depends(),
    partner_type: Optional[str] = Query(None, description="Filter by partner type e.g. Bank, Shipping Line, Customs Broker"),
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.get_paginated(params=params, response=response, partner_type=partner_type)


@router.get("", response_model=List[PartnerResponse])
def list_partners(
    partner_type: Optional[str] = Query(None, description="Filter by partner type e.g. Bank, Shipping Line, Customs Broker"),
    include_inactive: bool = Query(False, description="Set True to include deactivated partners"),
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.get_all_partners(partner_type=partner_type, include_inactive=include_inactive)


@router.post("", response_model=PartnerResponse, status_code=status.HTTP_201_CREATED)
def create_partner(
    partner_data: PartnerCreate,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.create_partner(partner_data)


# ==================================================
# Excel Template & Bulk Import & Export
# ==================================================

from fastapi import Response, UploadFile, File
from utils.export_import_helper import MasterDataExportImportHelper

@router.get("/excel-template")
def download_partners_excel_template():
    cols = [
        'partner_name', 'partner_type', 'tax_id', 'commercial_register',
        'contact_person', 'phone', 'mobile', 'fax', 'email', 'secondary_email',
        'website', 'address', 'country', 'notes'
    ]
    sample = {
        'partner_name': 'National Bank of Egypt (NBE)',
        'partner_type': 'Bank',
        'tax_id': 'TAX-100200300',
        'commercial_register': 'REG-8877',
        'contact_person': 'Trade Finance Dept',
        'phone': '+20 2 19623',
        'mobile': '+20 100 1234567',
        'fax': '+20 2 2577 0000',
        'email': 'trade@nbe.com.eg',
        'secondary_email': 'support@nbe.com.eg',
        'website': 'www.nbe.com.eg',
        'address': 'Corniche El Nile, Cairo',
        'country': 'Egypt',
        'notes': 'Primary LC & CAD Bank',
    }
    content = MasterDataExportImportHelper.create_excel_template(cols, sample)
    return MasterDataExportImportHelper.as_excel_response("Partners_Banks_Template.xlsx", content)


@router.post("/import-excel")
async def import_excel_partners(file: UploadFile = File(...), db: Session = Depends(get_db)):
    file_bytes = await file.read()
    cols = ['partner_name', 'partner_type', 'tax_id', 'commercial_register']
    rows = MasterDataExportImportHelper.parse_excel_file(file_bytes, cols)

    service = ExternalServiceProviderService(db)
    imported_count = 0
    errors = []

    for idx, r in enumerate(rows, start=2):
        try:
            name = r.get('partner_name')
            p_type = r.get('partner_type') or 'Bank'

            if not name:
                errors.append(f"Row {idx}: Missing required partner_name.")
                continue

            schema = PartnerCreate(
                partner_name=name,
                partner_type=p_type,
                tax_id=r.get('tax_id'),
                commercial_register=r.get('commercial_register'),
                contact_person=r.get('contact_person'),
                phone=r.get('phone'),
                mobile=r.get('mobile'),
                fax=r.get('fax'),
                email=r.get('email'),
                secondary_email=r.get('secondary_email'),
                website=r.get('website'),
                address=r.get('address'),
                country=r.get('country') or 'Egypt',
                notes=r.get('notes'),
            )
            service.create_partner(schema)
            imported_count += 1
        except Exception as e:
            errors.append(f"Row {idx}: {str(e)}")

    return {"message": f"Successfully imported {imported_count} partners & banks.", "errors": errors}


@router.get("/export-csv")
def export_partners_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ExternalServiceProviderService(db)
    partners = service.get_all_partners(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("partners", lang=lang)
    rows = []
    for p in partners:
        rows.append([
            p.partner_code,
            p.partner_name,
            p.partner_type,
            p.tax_id or '',
            p.commercial_register or '',
            getattr(p, 'clearance_license_number', '') or '',
            getattr(p, 'authorized_ports', '') or '',
            getattr(p, 'scac_code', '') or '',
            str(getattr(p, 'default_free_days', '')) if getattr(p, 'default_free_days', None) is not None else '',
            getattr(p, 'fiata_id', '') or '',
            getattr(p, 'shipping_modes', '') or '',
            getattr(p, 'supported_currencies', '') or '',
            getattr(p, 'transport_license_number', '') or '',
            getattr(p, 'fleet_types', '') or '',
            getattr(p, 'coverage_areas', '') or '',
            getattr(p, 'insurance_license_number', '') or '',
            getattr(p, 'insurance_coverage_types', '') or '',
            getattr(p, 'swift_code', '') or '',
            getattr(p, 'bank_code', '') or '',
            getattr(p, 'branch_name', '') or '',
            getattr(p, 'payment_type', '') or '',
            str(getattr(p, 'credit_limit', 0.0) or 0.0),
            str(getattr(p, 'rating', 5.0) or 5.0),
            p.contact_person or '',
            p.phone or '',
            p.mobile or '',
            getattr(p, 'fax', '') or '',
            p.email or '',
            getattr(p, 'secondary_email', '') or '',
            getattr(p, 'website', '') or '',
            p.address or '',
            p.country or ('مصر' if lang == 'ar' else 'Egypt'),
            getattr(p, 'notes', '') or '',
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("partners", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Partners_Banks", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@router.get("/export-excel")
def export_partners_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ExternalServiceProviderService(db)
    partners = service.get_all_partners(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("partners", lang=lang)
    rows = []
    for p in partners:
        rows.append([
            p.partner_code,
            p.partner_name,
            p.partner_type,
            p.tax_id or '',
            p.commercial_register or '',
            getattr(p, 'clearance_license_number', '') or '',
            getattr(p, 'authorized_ports', '') or '',
            getattr(p, 'scac_code', '') or '',
            str(getattr(p, 'default_free_days', '')) if getattr(p, 'default_free_days', None) is not None else '',
            getattr(p, 'fiata_id', '') or '',
            getattr(p, 'shipping_modes', '') or '',
            getattr(p, 'supported_currencies', '') or '',
            getattr(p, 'transport_license_number', '') or '',
            getattr(p, 'fleet_types', '') or '',
            getattr(p, 'coverage_areas', '') or '',
            getattr(p, 'insurance_license_number', '') or '',
            getattr(p, 'insurance_coverage_types', '') or '',
            getattr(p, 'swift_code', '') or '',
            getattr(p, 'bank_code', '') or '',
            getattr(p, 'branch_name', '') or '',
            getattr(p, 'payment_type', '') or '',
            str(getattr(p, 'credit_limit', 0.0) or 0.0),
            str(getattr(p, 'rating', 5.0) or 5.0),
            p.contact_person or '',
            p.phone or '',
            p.mobile or '',
            getattr(p, 'fax', '') or '',
            p.email or '',
            getattr(p, 'secondary_email', '') or '',
            getattr(p, 'website', '') or '',
            p.address or '',
            p.country or ('مصر' if lang == 'ar' else 'Egypt'),
            getattr(p, 'notes', '') or '',
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("partners", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Partners_Banks", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@router.get("/export-pdf")
def export_partners_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ExternalServiceProviderService(db)
    partners = service.get_all_partners(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("partners", lang=lang, is_pdf=True)
    rows = []
    for p in partners:
        code_spec = (
            getattr(p, 'clearance_license_number', '') or
            getattr(p, 'scac_code', '') or
            getattr(p, 'swift_code', '') or
            getattr(p, 'transport_license_number', '') or
            getattr(p, 'insurance_license_number', '') or
            '-'
        )
        pay_info = f"{getattr(p, 'payment_type', 'Credit') or 'Credit'} / {getattr(p, 'credit_limit', 0.0) or 0.0}"
        rows.append([
            p.partner_code,
            p.partner_name,
            p.partner_type,
            p.tax_id or '',
            code_spec,
            p.phone or p.mobile or '',
            p.email or '',
            pay_info,
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("partners", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Partners_Banks", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@router.get("/{provider_id}", response_model=PartnerResponse)
def get_partner(
    provider_id: int,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.get_partner_by_id(provider_id)


@router.get("/{provider_id}/statement-of-account", response_model=PartnerStatementOfAccountResponse)
def get_partner_statement_of_account(
    provider_id: int,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.get_partner_statement_of_account(provider_id)


@router.get("/{provider_id}/scorecard", response_model=PartnerScorecardResponse, summary="استخراج بطاقة أداء وتقييم الشريك اللوجستي ومعدل الالتزام")
def get_partner_scorecard(
    provider_id: int,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.get_partner_scorecard(provider_id)



@router.put("/{provider_id}", response_model=PartnerResponse)
def update_partner(
    provider_id: int,
    partner_data: PartnerUpdate,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.update_partner(provider_id, partner_data)


@router.delete("/{provider_id}")
def delete_partner(
    provider_id: int,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.soft_delete_partner(provider_id)


@router.patch("/{provider_id}/restore")
def restore_partner(
    provider_id: int,
    db: Session = Depends(get_db)
):
    service = ExternalServiceProviderService(db)
    return service.restore_partner(provider_id)