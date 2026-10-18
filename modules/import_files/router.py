"""
FastAPI Router for Import Files Master & Tracking Module
"""

from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.common.pagination import PageParams
from utils.export_import_helper import MasterDataExportImportHelper
from modules.import_files.schemas import (
    ImportFileCreate,
    ImportFileUpdate,
    ImportFileResponse,
    PaginatedImportFilesResponse,
    ImportMasterReportSummary,
    OperationalDashboardResponse,
    CloseShipmentSubmit,
    ReopenShipmentSubmit,
    FreightRfqDataResponse,
    HoldShipmentPayload,
    ResumeShipmentPayload,
    CloneImportFileRequest,
    CreatePartialBatchRequest,
)
import modules.import_files.service as service
from modules.auth.permissions import require_permission
from modules.users.model import User

router = APIRouter(prefix="/api/v1/import-files", tags=["Import Files Tracking"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=ImportFileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Import File / Case Tracking record",
)
def create_import_file(
    payload: ImportFileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.create")),
):
    user_name = current_user.username if (current_user and hasattr(current_user, "username")) else "System"
    return service.create_import_file_service(db, payload, current_user=user_name)


@router.get(
    "",
    response_model=List[ImportFileResponse],
    summary="List all import files with filters",
)
def list_import_files(
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.get_all_import_files_service(
        db,
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )


@router.get(
    "/paginated",
    response_model=PaginatedImportFilesResponse,
    summary="List paginated import files with filters",
)
def list_paginated_import_files(
    response: Response,
    params: PageParams = Depends(),
    search: Optional[str] = Query(None, description="Legacy alias for q"),
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    effective_q = params.q if params.q is not None else search
    result = service.get_paginated_import_files_service(
        db,
        params,
        search=effective_q,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )
    response.headers["X-Total-Count"] = str(result["total"])
    return result



@router.get(
    "/report/master",
    response_model=ImportMasterReportSummary,
    summary="Extract & summary report for all import files",
)
def get_master_report(
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.generate_master_report_service(
        db,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        search=search,
    )


@router.get(
    "/operational-dashboard",
    response_model=OperationalDashboardResponse,
    summary="Operational Dashboard multi-criteria AND filtering",
)
def get_operational_dashboard(
    phase: Optional[str] = None,
    priority: Optional[str] = None,
    broker_id: Optional[int] = None,
    broker_name: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.get_operational_dashboard_data_service(
        db,
        phase=phase,
        priority=priority,
        broker_id=broker_id,
        broker_name=broker_name,
        search=search,
    )


@router.get("/export-excel", summary="Export all import files to Excel (XLSX)")
def export_import_files_excel(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports.export")),
):
    files = service.get_all_import_files_service(db, include_inactive=True)
    headers = [
        'File Code', 'Custom File No', 'Company Name', 'Supplier Name',
        'PO Number', 'PI Number', 'Shipment Mode', 'Incoterm', 'Priority',
        'Current Stage', 'Progress %', 'Next Action', 'Owner', 'Status',
        'Estimated Cost', 'Currency', 'POL', 'POD', 'ACID Number', 'Form 4', 'Form 46'
    ]
    rows = service.build_export_rows(files, format="excel")
    content = MasterDataExportImportHelper.export_to_excel("Import Files Master Tracking", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Import_Files_Master", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@router.get("/export-pdf", summary="Export all import files to PDF")
def export_import_files_pdf(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports.export")),
):
    files = service.get_all_import_files_service(db, include_inactive=True)
    headers = ['File / Code', 'Company', 'Supplier', 'PO/PI', 'Mode/Inco', 'Stage', 'Progress', 'Status']
    rows = service.build_export_rows(files, format="pdf")
    content = MasterDataExportImportHelper.export_to_pdf("Import Files & Shipment Tracking", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Import_Files_Master", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@router.get(
    "/{import_file_id}/freight-rfq",
    response_model=FreightRfqDataResponse,
    summary="Generate Freight RFQ data, Email templates, and WhatsApp text for shipment",
)
def get_freight_rfq_data(
    import_file_id: str,
    recipient_name: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    if import_file_id.isdigit():
        fid = int(import_file_id)
        item = service.get_import_file_by_id_service(db, fid)
    else:
        item = service.get_import_file_by_code_service(db, import_file_id)

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )
    return service.generate_freight_rfq_service(db, item.import_file_id, recipient_name=recipient_name)


@router.get(
    "/{import_file_id}",
    response_model=ImportFileResponse,
    summary="Get single import file by ID or custom file number",
)
def get_import_file(
    import_file_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    if import_file_id.isdigit():
        item = service.get_import_file_by_id_service(db, int(import_file_id))
    else:
        item = service.get_import_file_by_code_service(db, import_file_id)

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )
    return item


@router.put(
    "/{import_file_id}",
    response_model=ImportFileResponse,
    summary="Update import file record",
)
def update_import_file(
    import_file_id: int,
    payload: ImportFileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.update_import_file_service(db, import_file_id, payload, actor=current_user)


@router.delete(
    "/{import_file_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete an import file",
)
def soft_delete_import_file(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    success = service.soft_delete_import_file_service(db, import_file_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد '{import_file_id}' غير موجود.",
        )


@router.post(
    "/{import_file_id}/close-shipment",
    response_model=ImportFileResponse,
    summary="Early close and terminate shipment at current phase with reason notes",
)
def close_shipment(
    import_file_id: int,
    payload: CloseShipmentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.close")),
):
    return service.close_shipment_service(db, import_file_id, payload, actor=current_user)


@router.post(
    "/{import_file_id}/reopen-shipment",
    response_model=ImportFileResponse,
    summary="Reopen closed shipment and restore to its original phase with reason notes",
)
def reopen_shipment(
    import_file_id: int,
    payload: ReopenShipmentSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.close")),
):
    return service.reopen_shipment_service(db, import_file_id, payload, actor=current_user)


@router.post(
    "/{import_file_id}/hold",
    response_model=ImportFileResponse,
    summary="Place import file / shipment on hold at current stage",
)
def hold_shipment(
    import_file_id: int,
    payload: HoldShipmentPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.hold_import_file_service(
        db,
        import_file_id=import_file_id,
        hold_reason=payload.hold_reason,
        hold_notes=payload.hold_notes,
        stage_name=payload.stage_name,
        step_name=payload.step_name,
        hold_reason_code=payload.hold_reason_code,
        performed_by=getattr(current_user, "username", None) or "System",
    )


@router.post(
    "/{import_file_id}/resume",
    response_model=ImportFileResponse,
    summary="Resume import file / shipment from on hold state",
)
def resume_shipment(
    import_file_id: int,
    payload: ResumeShipmentPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.resume_import_file_service(
        db,
        import_file_id=import_file_id,
        resume_notes=payload.resume_notes,
        performed_by=getattr(current_user, "username", None) or "System",
    )


@router.post(
    "/{import_file_id}/clone",
    response_model=ImportFileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Clone an Import File / Shipment (Universal Clone Engine UX-CLONE-011)",
)
def clone_shipment(
    import_file_id: int,
    payload: CloneImportFileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.create")),
):
    user_name = current_user.username if (current_user and hasattr(current_user, "username")) else "System"
    return service.clone_import_file_service(
        db,
        import_file_id=import_file_id,
        payload=payload,
        current_user=user_name,
    )


@router.post(
    "/{import_file_id}/create-partial-batch",
    response_model=ImportFileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new independent partial shipment file linked to parent file (DEV-OPS-04)",
)
def create_partial_batch(
    import_file_id: int,
    payload: CreatePartialBatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.create")),
):
    user_name = current_user.username if (current_user and hasattr(current_user, "username")) else "System"
    return service.create_partial_batch_service(
        db,
        parent_file_id=import_file_id,
        payload=payload,
        current_user=user_name,
    )


@router.get(
    "/{import_file_id}/partial-batches",
    response_model=List[ImportFileResponse],
    summary="List all linked partial shipment files for a given import file (DEV-OPS-04)",
)
def list_partial_batches(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.view")),
):
    return service.get_partial_batches_service(db, import_file_id=import_file_id)




