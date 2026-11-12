from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from utils.cache_manager import memory_cache
from utils.export_import_helper import MasterDataExportImportHelper

from .schemas import (
    CostItemCreate,
    CostItemResponse,
    CostItemUpdate,
    IncotermCreate,
    IncotermResponse,
    IncotermResponsibilityCreate,
    IncotermResponsibilityResponse,
    IncotermResponsibilityUpdate,
    IncotermUpdate,
)
from .service import (
    create_cost_item_service,
    create_incoterm_service,
    create_responsibility_service,
    delete_cost_item_service,
    delete_incoterm_service,
    delete_responsibility_service,
    get_all_cost_items_service,
    get_all_incoterms_service,
    get_all_responsibilities_service,
    get_cost_item_by_id_service,
    get_incoterm_by_id_service,
    get_matrix_for_incoterm_service,
    restore_cost_item_service,
    restore_incoterm_service,
    update_cost_item_service,
    update_incoterm_service,
    update_responsibility_service,
)


# ==================================================
# Router
# ==================================================

MASTER_DATA_EDIT = "master_data.edit"

incoterms_router = APIRouter(prefix="/api/v1", tags=["Incoterms"], dependencies=[Depends(get_current_user)])


# ==================================================
# Incoterms Endpoints (MD-006)
# ==================================================

@incoterms_router.post("/incoterms", response_model=IncotermResponse)
@incoterms_router.post("/incoterms/", response_model=IncotermResponse, include_in_schema=False)
def create_incoterm(data: IncotermCreate, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    try:
        res = create_incoterm_service(db, data, actor=current_user.username)
        memory_cache.clear_prefix("incoterms:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.get("/incoterms", response_model=List[IncotermResponse])
@incoterms_router.get("/incoterms/", response_model=List[IncotermResponse], include_in_schema=False)
def list_incoterms(include_inactive: bool = False, db: Session = Depends(get_db)):
    cache_key = f"incoterms:list:{include_inactive}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_all_incoterms_service(db, include_inactive)
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@incoterms_router.get("/incoterms/export-csv", summary="Export all incoterms to CSV")
def export_incoterms_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    incoterms = get_all_incoterms_service(db, include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("incoterms", lang=lang)
    rows = []
    for inc in incoterms:
        rows.append([
            inc.incoterm_code,
            inc.incoterm_name,
            inc.version,
            inc.description or '',
            MasterDataExportImportHelper.format_status(inc.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("incoterms", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Incoterms_Rules", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@incoterms_router.get("/incoterms/export-excel", summary="Export all incoterms to Excel (XLSX)")
def export_incoterms_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    incoterms = get_all_incoterms_service(db, include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("incoterms", lang=lang)
    rows = []
    for inc in incoterms:
        rows.append([
            inc.incoterm_code,
            inc.incoterm_name,
            inc.version,
            inc.description or '',
            MasterDataExportImportHelper.format_status(inc.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("incoterms", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Incoterms_Rules", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@incoterms_router.get("/incoterms/export-pdf", summary="Export all incoterms to PDF")
def export_incoterms_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    incoterms = get_all_incoterms_service(db, include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("incoterms", lang=lang, is_pdf=True)
    rows = []
    for inc in incoterms:
        rows.append([
            inc.incoterm_code,
            inc.incoterm_name,
            inc.version,
            inc.description or '',
            MasterDataExportImportHelper.format_status(inc.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("incoterms", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Incoterms_Rules", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@incoterms_router.get("/incoterms/{incoterm_id}", response_model=IncotermResponse)
def get_incoterm(incoterm_id: int, db: Session = Depends(get_db)):
    return get_incoterm_by_id_service(db, incoterm_id)


@incoterms_router.put("/incoterms/{incoterm_id}", response_model=IncotermResponse)
def update_incoterm(incoterm_id: int, data: IncotermUpdate, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    try:
        res = update_incoterm_service(db, incoterm_id, data, actor=current_user.username)
        memory_cache.clear_prefix("incoterms:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.delete("/incoterms/{incoterm_id}", response_model=IncotermResponse)
def delete_incoterm(incoterm_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    res = delete_incoterm_service(db, incoterm_id, actor=current_user.username)
    memory_cache.clear_prefix("incoterms:")
    return res


@incoterms_router.patch("/incoterms/{incoterm_id}/restore", response_model=IncotermResponse)
def restore_incoterm(incoterm_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    res = restore_incoterm_service(db, incoterm_id, actor=current_user.username)
    memory_cache.clear_prefix("incoterms:")
    return res


# ==================================================
# Cost Items Endpoints (MD-006A)
# ==================================================

@incoterms_router.post("/cost-items", response_model=CostItemResponse)
@incoterms_router.post("/cost-items/", response_model=CostItemResponse, include_in_schema=False)
def create_cost_item(data: CostItemCreate, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    try:
        return create_cost_item_service(db, data, actor=current_user.username)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.get("/cost-items", response_model=List[CostItemResponse])
@incoterms_router.get("/cost-items/", response_model=List[CostItemResponse], include_in_schema=False)
def list_cost_items(include_inactive: bool = False, db: Session = Depends(get_db)):
    cache_key = f"incoterms:cost_items:{include_inactive}"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_all_cost_items_service(db, include_inactive)
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@incoterms_router.get("/cost-items/{cost_item_id}", response_model=CostItemResponse)
def get_cost_item(cost_item_id: int, db: Session = Depends(get_db)):
    return get_cost_item_by_id_service(db, cost_item_id)


@incoterms_router.put("/cost-items/{cost_item_id}", response_model=CostItemResponse)
def update_cost_item(cost_item_id: int, data: CostItemUpdate, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    try:
        res = update_cost_item_service(db, cost_item_id, data, actor=current_user.username)
        memory_cache.clear_prefix("incoterms:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.delete("/cost-items/{cost_item_id}", response_model=CostItemResponse)
def delete_cost_item(cost_item_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    res = delete_cost_item_service(db, cost_item_id, actor=current_user.username)
    memory_cache.clear_prefix("incoterms:")
    return res


@incoterms_router.patch("/cost-items/{cost_item_id}/restore", response_model=CostItemResponse)
def restore_cost_item(cost_item_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    res = restore_cost_item_service(db, cost_item_id, actor=current_user.username)
    memory_cache.clear_prefix("incoterms:")
    return res


# ==================================================
# Responsibility Matrix Endpoints (MD-006B)
# ==================================================

@incoterms_router.post(
    "/incoterm-responsibilities", response_model=IncotermResponsibilityResponse
)
@incoterms_router.post(
    "/incoterm-responsibilities/", response_model=IncotermResponsibilityResponse, include_in_schema=False
)
def create_responsibility(
    data: IncotermResponsibilityCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_DATA_EDIT)),
):
    try:
        res = create_responsibility_service(db, data, actor=current_user.username)
        memory_cache.clear_prefix("incoterms:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.get(
    "/incoterm-responsibilities", response_model=List[IncotermResponsibilityResponse]
)
@incoterms_router.get(
    "/incoterm-responsibilities/", response_model=List[IncotermResponsibilityResponse], include_in_schema=False
)
def list_responsibilities(db: Session = Depends(get_db)):
    cache_key = "incoterms:responsibilities:all"
    cached = memory_cache.get(cache_key)
    if cached is not None:
        return cached
    res = get_all_responsibilities_service(db)
    memory_cache.set(cache_key, res, ttl_seconds=300)
    return res


@incoterms_router.get(
    "/incoterm-responsibilities/matrix/{incoterm_id}",
    response_model=List[IncotermResponsibilityResponse],
)
def get_matrix(incoterm_id: int, db: Session = Depends(get_db)):
    try:
        return get_matrix_for_incoterm_service(db, incoterm_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@incoterms_router.put(
    "/incoterm-responsibilities/{responsibility_id}",
    response_model=IncotermResponsibilityResponse,
)
def update_responsibility(
    responsibility_id: int,
    data: IncotermResponsibilityUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_DATA_EDIT)),
):
    try:
        res = update_responsibility_service(db, responsibility_id, data, actor=current_user.username)
        memory_cache.clear_prefix("incoterms:")
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@incoterms_router.delete(
    "/incoterm-responsibilities/{responsibility_id}",
    response_model=IncotermResponsibilityResponse,
)
def delete_responsibility(responsibility_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission(MASTER_DATA_EDIT))):
    res = delete_responsibility_service(db, responsibility_id)
    memory_cache.clear_prefix("incoterms:")
    return res
