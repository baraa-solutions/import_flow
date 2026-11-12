from typing import List, Optional

from fastapi import APIRouter, Depends, Query, Response, status
from modules.common.upload_guard import EXCEL_EXTENSIONS, read_upload_bytes
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from sqlalchemy.orm import Session

from database.database import get_db
from modules.common.pagination import Page, PageParams
from modules.transport_locations.schemas import (
    TransportLocationCreate,
    TransportLocationResponse,
    TransportLocationUpdate,
)
from modules.transport_locations.service import TransportLocationService
from utils.cache_manager import memory_cache

router = APIRouter(prefix="/api/v1/transport-locations", tags=["Transport Locations (MD-009)"], dependencies=[Depends(get_current_user)])


@router.get("/paginated", response_model=Page[TransportLocationResponse])
def get_paginated_locations(
    response: Response,
    params: PageParams = Depends(),
    location_type: Optional[str] = Query(None, description="Filter by type (Sea Port, Airport, Dry Port, Land Border)"),
    country: Optional[str] = Query(None, description="Filter by country"),
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    return service.get_paginated(
        params=params,
        response=response,
        location_type=location_type,
        country=country,
    )


@router.get("", response_model=List[TransportLocationResponse])
def get_all_locations(
    include_inactive: bool = Query(False, description="Include inactive locations"),
    location_type: Optional[str] = Query(None, description="Filter by type (Sea Port, Airport, Dry Port, Land Border)"),
    country: Optional[str] = Query(None, description="Filter by country"),
    search: Optional[str] = Query(None, description="Search by code, name, city or country"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: Optional[int] = Query(None, ge=1, le=5000, description="Max number of records to return"),
    db: Session = Depends(get_db),
):
    cache_key = f"transport_locations:{include_inactive}:{location_type}:{country}:{search}:{skip}:{limit}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached

    service = TransportLocationService(db)
    results = service.get_all(
        include_inactive=include_inactive,
        location_type=location_type,
        country=country,
        search=search,
        skip=skip,
        limit=limit,
    )
    memory_cache.set(cache_key, results, ttl_seconds=300)
    return results


# ==================================================
# Excel Template & Bulk Import & Export (MD-009)
# ==================================================

from fastapi import Response, UploadFile, File
from utils.export_import_helper import MasterDataExportImportHelper

@router.get("/excel-template")
def download_locations_excel_template():
    cols = ['location_name', 'un_locode', 'location_type', 'country', 'city', 'notes']
    sample = {
        'location_name': 'Alexandria Port',
        'un_locode': 'EGALY',
        'location_type': 'Sea Port',
        'country': 'Egypt',
        'city': 'Alexandria',
        'notes': 'Primary Mediterranean Container Port',
    }
    content = MasterDataExportImportHelper.create_excel_template(cols, sample)
    return MasterDataExportImportHelper.as_excel_response("Transport_Locations_Template.xlsx", content)


@router.post("/import-excel", dependencies=[Depends(require_permission("master_data.edit"))])
async def import_excel_locations(file: UploadFile = File(...), db: Session = Depends(get_db)):
    file_bytes = await read_upload_bytes(file, EXCEL_EXTENSIONS)
    cols = ['location_name', 'un_locode', 'location_type', 'country', 'city']
    rows = MasterDataExportImportHelper.parse_excel_file(file_bytes, cols)
    service = TransportLocationService(db)

    def process_row(idx: int, r: dict):
        name = r.get('location_name')
        locode = r.get('un_locode')
        l_type = r.get('location_type') or 'Sea Port'
        c_country = r.get('country') or 'Egypt'
        c_city = r.get('city') or 'Alexandria'

        if not name or not locode:
            raise ValueError("Missing required location_name or un_locode.")

        schema = TransportLocationCreate(
            location_name=name,
            un_locode=locode,
            location_type=l_type,
            country=c_country,
            city=c_city,
            notes=r.get('notes'),
        )
        service.create(schema, commit=False)

    result = MasterDataExportImportHelper.execute_atomic_import(db, rows, process_row)
    memory_cache.clear_prefix("transport_locations:")
    return result


@router.get("/export-csv")
def export_locations_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    locations = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("transport_locations", lang=lang)
    rows = []
    for loc in locations:
        rows.append([
            loc.location_id,
            loc.un_locode,
            loc.location_name,
            loc.location_type,
            loc.country,
            loc.city,
            MasterDataExportImportHelper.format_status(loc.is_active, lang=lang),
            loc.notes or '',
        ])
    title = MasterDataExportImportHelper.get_localized_title("transport_locations", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Transport_Locations", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@router.get("/export-excel")
def export_locations_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    locations = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("transport_locations", lang=lang)
    rows = []
    for loc in locations:
        rows.append([
            loc.location_id,
            loc.un_locode,
            loc.location_name,
            loc.location_type,
            loc.country,
            loc.city,
            MasterDataExportImportHelper.format_status(loc.is_active, lang=lang),
            loc.notes or '',
        ])
    title = MasterDataExportImportHelper.get_localized_title("transport_locations", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Transport_Locations", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@router.get("/export-pdf")
def export_locations_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    locations = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("transport_locations", lang=lang, is_pdf=True)
    rows = []
    for loc in locations:
        rows.append([
            loc.location_id,
            loc.un_locode,
            loc.location_name,
            loc.location_type,
            loc.country,
            loc.city,
            MasterDataExportImportHelper.format_status(loc.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("transport_locations", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Transport_Locations", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@router.get("/{location_id}", response_model=TransportLocationResponse)
def get_location_by_id(
    location_id: int,
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    return service.get_by_id(location_id)


@router.post("", response_model=TransportLocationResponse, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_permission("master_data.edit"))])
def create_location(
    data: TransportLocationCreate,
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    res = service.create(data)
    memory_cache.clear_prefix("transport_locations:")
    return res


@router.put("/{location_id}", response_model=TransportLocationResponse, dependencies=[Depends(require_permission("master_data.edit"))])
def update_location(
    location_id: int,
    data: TransportLocationUpdate,
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    res = service.update(location_id, data)
    memory_cache.clear_prefix("transport_locations:")
    return res


@router.delete("/{location_id}", response_model=TransportLocationResponse, dependencies=[Depends(require_permission("master_data.edit"))])
def soft_delete_location(
    location_id: int,
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    res = service.soft_delete(location_id)
    memory_cache.clear_prefix("transport_locations:")
    return res


@router.post("/{location_id}/restore", response_model=TransportLocationResponse, dependencies=[Depends(require_permission("master_data.edit"))])
def restore_location(
    location_id: int,
    db: Session = Depends(get_db),
):
    service = TransportLocationService(db)
    res = service.restore(location_id)
    memory_cache.clear_prefix("transport_locations:")
    return res
