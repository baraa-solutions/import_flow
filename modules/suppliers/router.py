from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.common.pagination import Page, PageParams
from .schemas import SupplierCreate, SupplierUpdate, SupplierResponse, SupplierScorecardResponse
from .service import (
    create_supplier_service,
    get_all_suppliers_service,
    get_all_suppliers_admin_service,
    get_paginated_suppliers_service,
    get_supplier_by_id_service,
    update_supplier_service,
    delete_supplier_service,
    restore_supplier_service,
    get_supplier_scorecard_service,
)

# ==================================================
# Router Setup
# ==================================================

supplier_router = APIRouter(
    prefix="/api/v1/suppliers",
    tags=["Suppliers & Foreign Exporters"],
    dependencies=[Depends(get_current_user)],
)


# ==================================================
# Create Supplier Endpoint
# ==================================================

@supplier_router.post(
    "",
    response_model=SupplierResponse,
    status_code=status.HTTP_201_CREATED
)
def create_supplier(supplier: SupplierCreate, db: Session = Depends(get_db)):
    created = create_supplier_service(db, supplier)
    if not created:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Foreign Exporter ID '{supplier.foreign_exporter_id}' already exists."
        )
    return created


# ==================================================
# Get Paginated Suppliers Endpoint
# ==================================================

@supplier_router.get(
    "/paginated",
    response_model=Page[SupplierResponse]
)
def get_paginated_suppliers_endpoint(
    response: Response,
    params: PageParams = Depends(),
    supplier_type: Optional[str] = Query(None, description="Filter by supplier type"),
    country: Optional[str] = Query(None, description="Filter by foreign exporter country"),
    db: Session = Depends(get_db),
):
    return get_paginated_suppliers_service(
        db,
        params=params,
        response=response,
        supplier_type=supplier_type,
        country=country,
    )


# ==================================================
# Get All Suppliers (Active or All) Endpoint
# ==================================================

@supplier_router.get(
    "",
    response_model=list[SupplierResponse]
)
def get_suppliers(include_inactive: bool = False, db: Session = Depends(get_db)):
    if include_inactive:
        return get_all_suppliers_admin_service(db)
    return get_all_suppliers_service(db)



# ==================================================
# Excel Template & Bulk Import
# ==================================================

from fastapi import Response, UploadFile, File
from utils.export_import_helper import MasterDataExportImportHelper

@supplier_router.get("/excel-template")
def download_suppliers_excel_template():
    cols = [
        'company_name', 'supplier_type', 'registration_type', 'foreign_exporter_id',
        'foreign_exporter_country', 'foreign_exporter_country_code', 'address',
        'phone', 'mobile', 'fax', 'email', 'secondary_email', 'website',
        'has_iso', 'registered_decree_43', 'white_list_registered', 'brands', 'notes'
    ]
    sample = {
        'company_name': 'G.I. Industrial Holding S.p.A.',
        'supplier_type': 'Manufacturer',
        'registration_type': 'Factory Registration',
        'foreign_exporter_id': 'EXP-IT-992211',
        'foreign_exporter_country': 'Italy',
        'foreign_exporter_country_code': 'IT',
        'address': 'Via G. Agnelli, 7 - 33053 Latisana (UD) - Italy',
        'phone': '+39 0432 823011',
        'mobile': '+39 335 1234567',
        'fax': '+39 0432 773855',
        'email': 'info@gind.it',
        'secondary_email': 'sales@gind.it',
        'website': 'www.gind.it',
        'has_iso': 'true',
        'registered_decree_43': 'true',
        'white_list_registered': 'true',
        'brands': 'Clint, Novair',
        'notes': 'Registered under Decree 43',
    }
    content = MasterDataExportImportHelper.create_excel_template(cols, sample)
    return MasterDataExportImportHelper.as_excel_response("Foreign_Suppliers_Template.xlsx", content)


@supplier_router.post("/import-excel")
async def import_excel_suppliers(file: UploadFile = File(...), db: Session = Depends(get_db)):
    file_bytes = await file.read()
    cols = ['company_name', 'supplier_type', 'registration_type', 'foreign_exporter_id', 'foreign_exporter_country', 'foreign_exporter_country_code', 'address']
    rows = MasterDataExportImportHelper.parse_excel_file(file_bytes, cols)

    imported_count = 0
    errors = []

    for idx, r in enumerate(rows, start=2):
        try:
            c_name = r.get('company_name')
            exp_id = r.get('foreign_exporter_id')
            c_country = r.get('foreign_exporter_country') or 'China'
            c_code = r.get('foreign_exporter_country_code') or 'CN'

            if not c_name or not exp_id:
                errors.append(f"Row {idx}: Missing required company_name or foreign_exporter_id.")
                continue

            schema = SupplierCreate(
                company_name=c_name,
                supplier_type=r.get('supplier_type') or 'Manufacturer',
                registration_type=r.get('registration_type') or 'Factory Registration',
                foreign_exporter_id=exp_id,
                foreign_exporter_country=c_country,
                foreign_exporter_country_code=c_code,
                address=r.get('address') or 'Main Industrial Zone',
                phone=r.get('phone'),
                mobile=r.get('mobile'),
                fax=r.get('fax'),
                email=r.get('email'),
                secondary_email=r.get('secondary_email'),
                website=r.get('website'),
                has_iso=MasterDataExportImportHelper.parse_bool_safe(r.get('has_iso')),
                registered_decree_43=MasterDataExportImportHelper.parse_bool_safe(r.get('registered_decree_43')),
                white_list_registered=MasterDataExportImportHelper.parse_bool_safe(r.get('white_list_registered')),
                brands=r.get('brands'),
                notes=r.get('notes'),
            )
            create_supplier_service(db, schema)
            imported_count += 1
        except Exception as e:
            errors.append(f"Row {idx}: {str(e)}")

    return {"message": f"Successfully imported {imported_count} foreign suppliers.", "errors": errors}


@supplier_router.get("/export-csv")
def export_suppliers_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    suppliers = get_all_suppliers_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("suppliers", lang=lang)
    rows = []
    for s in suppliers:
        rows.append([
            s.supplier_code,
            s.company_name,
            s.supplier_type,
            s.registration_type,
            s.foreign_exporter_id,
            getattr(s, 'cargox_platform_id', '') or '',
            s.foreign_exporter_country,
            s.foreign_exporter_country_code,
            s.address,
            s.phone or '',
            getattr(s, 'mobile', '') or '',
            getattr(s, 'fax', '') or '',
            s.email or '',
            getattr(s, 'secondary_email', '') or '',
            s.website or '',
            getattr(s, 'bank_name', '') or '',
            getattr(s, 'swift_code', '') or '',
            getattr(s, 'account_number', '') or '',
            getattr(s, 'iban', '') or '',
            MasterDataExportImportHelper.format_bool(getattr(s, 'has_iso', False), lang=lang),
            MasterDataExportImportHelper.format_bool(getattr(s, 'registered_decree_43', False), lang=lang),
            MasterDataExportImportHelper.format_bool(getattr(s, 'white_list_registered', False), lang=lang),
            getattr(s, 'brands', '') or '',
            getattr(s, 'notes', '') or '',
            MasterDataExportImportHelper.format_status(s.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("suppliers", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Foreign_Suppliers", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@supplier_router.get("/export-excel")
def export_suppliers_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    suppliers = get_all_suppliers_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("suppliers", lang=lang)
    rows = []
    for s in suppliers:
        rows.append([
            s.supplier_code,
            s.company_name,
            s.supplier_type,
            s.registration_type,
            s.foreign_exporter_id,
            getattr(s, 'cargox_platform_id', '') or '',
            s.foreign_exporter_country,
            s.foreign_exporter_country_code,
            s.address,
            s.phone or '',
            getattr(s, 'mobile', '') or '',
            getattr(s, 'fax', '') or '',
            s.email or '',
            getattr(s, 'secondary_email', '') or '',
            s.website or '',
            getattr(s, 'bank_name', '') or '',
            getattr(s, 'swift_code', '') or '',
            getattr(s, 'account_number', '') or '',
            getattr(s, 'iban', '') or '',
            MasterDataExportImportHelper.format_bool(getattr(s, 'has_iso', False), lang=lang),
            MasterDataExportImportHelper.format_bool(getattr(s, 'registered_decree_43', False), lang=lang),
            MasterDataExportImportHelper.format_bool(getattr(s, 'white_list_registered', False), lang=lang),
            getattr(s, 'brands', '') or '',
            getattr(s, 'notes', '') or '',
            MasterDataExportImportHelper.format_status(s.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("suppliers", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Foreign_Suppliers", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@supplier_router.get("/export-pdf")
def export_suppliers_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    suppliers = get_all_suppliers_admin_service(db)
    headers = MasterDataExportImportHelper.get_localized_headers("suppliers", lang=lang, is_pdf=True)
    rows = []
    for s in suppliers:
        flags = []
        if getattr(s, 'has_iso', False):
            flags.append("آيزو" if lang == "ar" else "ISO")
        if getattr(s, 'registered_decree_43', False):
            flags.append("قرار 43" if lang == "ar" else "D43")
        if getattr(s, 'white_list_registered', False):
            flags.append("بيضاء" if lang == "ar" else "WL")
        flag_str = ", ".join(flags) if flags else "-"

        bank_swift = f"{getattr(s, 'bank_name', '') or '-'}/{getattr(s, 'swift_code', '') or '-'}"

        rows.append([
            s.supplier_code,
            s.company_name,
            s.supplier_type,
            s.foreign_exporter_id,
            getattr(s, 'cargox_platform_id', '') or '-',
            s.foreign_exporter_country,
            s.phone or '',
            s.email or '',
            bank_swift,
            flag_str,
            MasterDataExportImportHelper.format_status(s.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("suppliers", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Foreign_Suppliers", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


# ==================================================
# Get Supplier By ID Endpoint
# ==================================================

@supplier_router.get(
    "/{supplier_id}",
    response_model=SupplierResponse
)
def get_supplier_by_id(supplier_id: int, db: Session = Depends(get_db)):
    supplier = get_supplier_by_id_service(db, supplier_id)
    if not supplier:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found."
        )
    return supplier


# ==================================================
# Update Supplier Endpoint
# ==================================================

@supplier_router.put(
    "/{supplier_id}",
    response_model=SupplierResponse
)
def update_supplier(
    supplier_id: int,
    supplier_data: SupplierUpdate,
    db: Session = Depends(get_db)
):
    updated = update_supplier_service(db, supplier_id, supplier_data)
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found."
        )
    return updated


# ==================================================
# Soft Delete Supplier Endpoint
# ==================================================

@supplier_router.delete(
    "/{supplier_id}",
    response_model=SupplierResponse
)
def delete_supplier(supplier_id: int, db: Session = Depends(get_db)):
    deleted = delete_supplier_service(db, supplier_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found."
        )
    return deleted


# ==================================================
# Restore Supplier Endpoint
# ==================================================

@supplier_router.patch(
    "/{supplier_id}/restore",
    response_model=SupplierResponse
)
def restore_supplier(supplier_id: int, db: Session = Depends(get_db)):
    restored = restore_supplier_service(db, supplier_id)
    if not restored:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found."
        )
    return restored


# ==================================================
# Supplier Scorecard Endpoint (LOG-KPIS-005)
# ==================================================

@supplier_router.get(
    "/{supplier_id}/scorecard",
    response_model=SupplierScorecardResponse
)
def get_supplier_scorecard(supplier_id: int, db: Session = Depends(get_db)):
    scorecard = get_supplier_scorecard_service(db, supplier_id)
    if not scorecard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier with ID {supplier_id} not found."
        )
    return scorecard