from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status, UploadFile, File
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.projects.schemas import ProjectCreate, ProjectResponse, ProjectUpdate
from modules.projects.service import ProjectService
from utils.export_import_helper import MasterDataExportImportHelper

router = APIRouter(prefix="/api/v1/projects", tags=["Projects Module"], dependencies=[Depends(get_current_user)])


@router.get("", response_model=List[ProjectResponse])
def get_all_projects(
    include_inactive: bool = Query(False, description="Include inactive projects"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status (Open, Closed, On Hold)"),
    company_id: Optional[int] = Query(None, description="Filter by Import Company ID"),
    supplier_id: Optional[int] = Query(None, description="Filter by Supplier ID"),
    search: Optional[str] = Query(None, description="Search by code, name or owner"),
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.get_all(
        include_inactive=include_inactive,
        status_filter=status_filter,
        company_id=company_id,
        supplier_id=supplier_id,
        search=search,
    )


# ==================================================
# Excel Template & Bulk Import & Export (Defined before /{project_id})
# ==================================================

@router.get("/export-csv")
def export_projects_csv(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    projects = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("projects", lang=lang)
    rows = []
    for p in projects:
        rows.append([
            p.project_id,
            p.project_code,
            p.project_name,
            p.client_name or '',
            p.manager_name or '',
            p.budget or 0.0,
            p.currency or 'USD',
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("projects", lang=lang)
    content = MasterDataExportImportHelper.export_to_csv(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Projects_CostCenters", "csv")
    return MasterDataExportImportHelper.as_csv_response(filename, content)


@router.get("/export-excel")
def export_projects_excel(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    projects = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("projects", lang=lang)
    rows = []
    for p in projects:
        rows.append([
            p.project_id,
            p.project_code,
            p.project_name,
            p.client_name or '',
            p.manager_name or '',
            p.budget or 0.0,
            p.currency or 'USD',
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("projects", lang=lang)
    content = MasterDataExportImportHelper.export_to_excel(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Projects_CostCenters", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@router.get("/export-pdf")
def export_projects_pdf(
    lang: str = Query("ar", pattern="^(ar|en)$"),
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    projects = service.get_all(include_inactive=True)
    headers = MasterDataExportImportHelper.get_localized_headers("projects", lang=lang, is_pdf=True)
    rows = []
    for p in projects:
        rows.append([
            p.project_id,
            p.project_code,
            p.project_name,
            p.client_name or '',
            p.manager_name or '',
            f"{p.budget or 0.0:,.2f} {p.currency or 'USD'}",
            MasterDataExportImportHelper.format_status(p.is_active, lang=lang),
        ])
    title = MasterDataExportImportHelper.get_localized_title("projects", lang=lang)
    content = MasterDataExportImportHelper.export_to_pdf(title, headers, rows, lang=lang)
    filename = MasterDataExportImportHelper.standard_export_filename("Projects_CostCenters", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@router.get("/excel-template")
def download_projects_excel_template():
    cols = ['project_code', 'project_name', 'client_name', 'manager_name', 'budget', 'currency', 'company_id', 'description']
    sample = {
        'project_code': 'PRJ-2026-001',
        'project_name': 'Solar Power Plant Expansion Phase 1',
        'client_name': 'Ministry of Electricity',
        'manager_name': 'Eng. Mohamed Ali',
        'budget': '5000000',
        'currency': 'EGP',
        'company_id': '1',
        'description': 'Main solar component importing project',
    }
    content = MasterDataExportImportHelper.create_excel_template(cols, sample)
    return MasterDataExportImportHelper.as_excel_response("Projects_CostCenters_Template.xlsx", content)


@router.post("/import-excel")
async def import_excel_projects(file: UploadFile = File(...), db: Session = Depends(get_db)):
    file_bytes = await file.read()
    cols = ['project_code', 'project_name', 'client_name', 'manager_name', 'budget', 'currency', 'company_id', 'description']
    rows = MasterDataExportImportHelper.parse_excel_file(file_bytes, cols)

    service = ProjectService(db)
    imported_count = 0
    errors = []

    for idx, r in enumerate(rows, start=2):
        try:
            p_code = r.get('project_code')
            p_name = r.get('project_name')

            if not p_code or not p_name:
                errors.append(f"Row {idx}: Missing required project_code or project_name.")
                continue

            comp_id = int(r.get('company_id')) if r.get('company_id') and str(r.get('company_id')).isdigit() else 1
            bud = float(r.get('budget')) if r.get('budget') and str(r.get('budget')).replace('.', '', 1).isdigit() else 0.0

            schema = ProjectCreate(
                project_code=p_code,
                project_name=p_name,
                company_id=comp_id,
                client_name=r.get('client_name'),
                manager_name=r.get('manager_name'),
                budget=bud,
                currency=r.get('currency') or 'USD',
                description=r.get('description'),
            )
            service.create(schema)
            imported_count += 1
        except Exception as e:
            errors.append(f"Row {idx}: {str(e)}")

    return {"message": f"Successfully imported {imported_count} projects & cost centers.", "errors": errors}


# ==================================================
# Parameterized Project Routes
# ==================================================

@router.get("/{project_id}", response_model=ProjectResponse)
def get_project_by_id(
    project_id: int,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.get_by_id(project_id)


@router.get("/{project_id}/financial-commitments")
def get_project_financial_commitments(
    project_id: int,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.get_financial_commitments(project_id)


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(
    data: ProjectCreate,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.create(data)


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: int,
    data: ProjectUpdate,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.update(project_id, data)


@router.delete("/{project_id}", response_model=ProjectResponse)
def soft_delete_project(
    project_id: int,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.soft_delete(project_id)


@router.post("/{project_id}/restore", response_model=ProjectResponse)
def restore_project(
    project_id: int,
    db: Session = Depends(get_db),
):
    service = ProjectService(db)
    return service.restore(project_id)
