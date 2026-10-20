from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response
from modules.auth.router import get_current_user

from sqlalchemy.orm import Session

from database.database import get_db
from modules.common.pagination import Page, PageParams

from .schemas import ImportCompanyCreate
from .schemas import ImportCompanyUpdate
from .schemas import ImportCompanyResponse

from .service import create_import_company
from .service import get_all_companies
from .service import get_all_companies_admin_service
from .service import get_paginated_companies_service
from .service import get_company_by_id
from .service import update_import_company
from .service import delete_import_company
from .service import restore_import_company


# ==================================================
# Router
# ==================================================

import_router = APIRouter(
    prefix="/api/v1/import-companies",
    tags=["Import Companies"],
    dependencies=[Depends(get_current_user)],
)


# ==================================================
# Create Company
# ==================================================

@import_router.post(
    "",
    response_model=ImportCompanyResponse
)
def create_company(
    company: ImportCompanyCreate,
    db: Session = Depends(get_db)
):

    return create_import_company(
        db,
        company
    )


# ==================================================
# Get Paginated Companies
# ==================================================

@import_router.get(
    "/paginated",
    response_model=Page[ImportCompanyResponse]
)
def get_paginated_companies_endpoint(
    response: Response,
    params: PageParams = Depends(),
    country: Optional[str] = Query(None, description="Filter by country"),
    db: Session = Depends(get_db)
):
    return get_paginated_companies_service(
        db,
        params=params,
        response=response,
        country=country,
    )


# ==================================================
# Get Companies (Active or All)
# ==================================================

@import_router.get(
    "",
    response_model=list[ImportCompanyResponse]
)
def get_companies(
    include_inactive: bool = False,
    db: Session = Depends(get_db)
):

    if include_inactive:
        return get_all_companies_admin_service(db)

    return get_all_companies(
        db
    )



# ==================================================
# Excel Template & Bulk Import
# ==================================================

from fastapi import Response, UploadFile, File
from datetime import datetime, date
from utils.export_import_helper import MasterDataExportImportHelper

@import_router.get("/excel-template")
def download_excel_template():
    cols = ['importer_name', 'address', 'country', 'importer_id', 'importer_id_expiry', 'vat_id', 'vat_id_expiry', 'registration_number', 'registration_expiry', 'phone', 'email']
    sample = {
        'importer_name': 'Pharaohs Import & Export LLC',
        'address': '12 Ramses St, Cairo',
        'country': 'Egypt',
        'importer_id': 'IMP-100200',
        'importer_id_expiry': '2027-12-31',
        'vat_id': 'VAT-998877665',
        'vat_id_expiry': '2027-12-31',
        'registration_number': 'REG-554433221',
        'registration_expiry': '2027-12-31',
        'phone': '+20 2 2577 8899',
        'email': 'info@pharaohs.com',
    }
    content = MasterDataExportImportHelper.create_excel_template(cols, sample)
    return MasterDataExportImportHelper.as_excel_response("Import_Companies_Template.xlsx", content)


@import_router.post("/import-excel")
async def import_excel_companies(file: UploadFile = File(...), db: Session = Depends(get_db)):
    file_bytes = await file.read()
    cols = ['importer_name', 'address', 'country', 'importer_id', 'importer_id_expiry', 'vat_id', 'vat_id_expiry', 'registration_number', 'registration_expiry', 'phone', 'email']
    rows = MasterDataExportImportHelper.parse_excel_file(file_bytes, cols)

    imported_count = 0
    errors = []

    for idx, r in enumerate(rows, start=2):
        try:
            name = r.get('importer_name')
            imp_id = r.get('importer_id')
            vat_id = r.get('vat_id')
            reg_num = r.get('registration_number')

            if not name or not imp_id or not vat_id or not reg_num:
                errors.append(f"Row {idx}: Missing required fields (importer_name, importer_id, vat_id, registration_number).")
                continue

            default_expiry = date(2027, 12, 31)
            schema = ImportCompanyCreate(
                importer_name=name,
                address=r.get('address') or 'Cairo, Egypt',
                country=r.get('country') or 'Egypt',
                importer_id=imp_id,
                importer_id_expiry=MasterDataExportImportHelper.parse_date_safe(r.get('importer_id_expiry'), default_expiry),
                vat_id=vat_id,
                vat_id_expiry=MasterDataExportImportHelper.parse_date_safe(r.get('vat_id_expiry'), default_expiry),
                registration_number=reg_num,
                registration_expiry=MasterDataExportImportHelper.parse_date_safe(r.get('registration_expiry'), default_expiry),
                phone=r.get('phone'),
                email=r.get('email'),
            )
            create_import_company(db, schema)
            imported_count += 1
        except Exception as e:
            errors.append(f"Row {idx}: {str(e)}")

    return {"message": f"Successfully imported {imported_count} import companies.", "errors": errors}


@import_router.get("/export-csv")
def export_companies_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    companies = get_all_companies_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("import_companies", lang=lang)
    rows = []
    for c in companies:
        rows.append([
            c.company_id,
            c.importer_name,
            c.importer_id,
            MasterDataExportImportHelper.format_date_safe(c.importer_id_expiry),
            c.vat_id,
            MasterDataExportImportHelper.format_date_safe(c.vat_id_expiry),
            c.registration_number,
            MasterDataExportImportHelper.format_date_safe(c.registration_expiry),
            c.address,
            c.country,
            c.phone or '',
            c.email or '',
            c.notes or '',
            MasterDataExportImportHelper.format_status(c.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("import_companies", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Egyptian_Import_Companies", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@import_router.get("/export-excel")
def export_companies_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    companies = get_all_companies_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("import_companies", lang=lang)
    rows = []
    for c in companies:
        rows.append([
            c.company_id,
            c.importer_name,
            c.importer_id,
            MasterDataExportImportHelper.format_date_safe(c.importer_id_expiry),
            c.vat_id,
            MasterDataExportImportHelper.format_date_safe(c.vat_id_expiry),
            c.registration_number,
            MasterDataExportImportHelper.format_date_safe(c.registration_expiry),
            c.address,
            c.country,
            c.phone or '',
            c.email or '',
            c.notes or '',
            MasterDataExportImportHelper.format_status(c.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("import_companies", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Egyptian_Import_Companies", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@import_router.get("/export-pdf")
def export_companies_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    companies = get_all_companies_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("import_companies", lang=lang, is_pdf=True)
    rows = []
    for c in companies:
        rows.append([
            c.company_id,
            c.importer_name,
            c.importer_id,
            MasterDataExportImportHelper.format_date_safe(c.importer_id_expiry),
            c.vat_id,
            MasterDataExportImportHelper.format_date_safe(c.vat_id_expiry),
            c.registration_number,
            MasterDataExportImportHelper.format_date_safe(c.registration_expiry),
            c.phone or '',
            c.email or '',
            MasterDataExportImportHelper.format_status(c.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("import_companies", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Egyptian_Import_Companies", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


# ==================================================
# Get Company By ID
# ==================================================

@import_router.get(
    "/{company_id}",
    response_model=ImportCompanyResponse
)
def get_company(
    company_id: int,
    db: Session = Depends(get_db)
):

    company = get_company_by_id(
        db,
        company_id
    )

    if company is None:
        raise HTTPException(
            status_code=404,
            detail="Import Company not found"
        )

    return company


# ==================================================
# Update Company
# ==================================================

@import_router.put(
    "/{company_id}",
    response_model=ImportCompanyResponse
)
def update_company(
    company_id: int,
    company: ImportCompanyUpdate,
    db: Session = Depends(get_db)
):

    updated_company = update_import_company(
        db,
        company_id,
        company
    )

    if updated_company is None:
        raise HTTPException(
            status_code=404,
            detail="Import Company not found"
        )

    return updated_company


# ==================================================
# Soft Delete Company
# ==================================================

@import_router.delete(
    "/{company_id}",
    response_model=ImportCompanyResponse
)
def delete_company(
    company_id: int,
    db: Session = Depends(get_db)
):

    deleted_company = delete_import_company(
        db,
        company_id
    )

    if deleted_company is None:
        raise HTTPException(
            status_code=404,
            detail="Import Company not found"
        )

    return deleted_company


# ==================================================
# Restore Company
# ==================================================

@import_router.patch(
    "/{company_id}/restore",
    response_model=ImportCompanyResponse
)
def restore_company(
    company_id: int,
    db: Session = Depends(get_db)
):

    restored_company = restore_import_company(
        db,
        company_id
    )

    if restored_company is None:
        raise HTTPException(
            status_code=404,
            detail="Import Company not found"
        )

    return restored_company