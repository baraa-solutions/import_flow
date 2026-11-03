"""
Import Files Master Service (Unified Facade & Coordinator).

Decomposed into focused domain sub-services:
- import_file_lifecycle_service.py: Creation, formulas, transitions, cloning, batches, freight RFQ.
- import_file_hold_service.py: Hold codes, reasons, regulatory locks, halts, and release validations.
- import_file_cost_service.py: Master reports, landed cost summaries, customs duty references, export rows.

This coordinator file provides 100% backward compatibility for router.py, submodules, and tests.
"""

from datetime import date
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams
from modules.common.system_messages import SysMsg
from modules.import_files.model import ImportFile
import modules.import_files.repository as repo
from modules.import_files.schemas import (
    ImportFileCreate,
    ImportFileUpdate,
    ImportFileResponse,
    ImportMasterReportSummary,
    CloneImportFileRequest,
    CreatePartialBatchRequest,
    CloseShipmentSubmit,
    ReopenShipmentSubmit,
)

# Re-exports from import_file_lifecycle_service
from modules.import_files.import_file_lifecycle_service import (
    STEP_INITIAL_CONFIG,
    STEP_INITIAL_NEXT_ACTION_CODES,
    COURIER_KG_PER_CBM,
    _next_action_fields,
    _phase_action,
    compute_file_formulas,
    create_import_file_service,
    update_import_file_service,
    close_shipment_service,
    reopen_shipment_service,
    clone_import_file_service,
    create_partial_batch_service,
    get_partial_batches_service,
    generate_freight_rfq_service,
)

# Re-exports from import_file_hold_service
from modules.import_files.import_file_hold_service import (
    hold_import_file_service,
    resume_import_file_service,
    validate_regulatory_clearance_lock,
    validate_release_readiness,
    apply_inspection_halt_service,
)

# Re-exports from import_file_cost_service
from modules.import_files.import_file_cost_service import (
    STATUS_TRANSLATIONS,
    STAGE_TRANSLATIONS,
    generate_master_report_service,
    get_landed_cost_summary_service,
    build_export_rows,
)


# =========================================================================
# Query & Dashboard Services (Delegated to Repository)
# =========================================================================

def get_all_import_files_service(
    db: Session,
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
) -> List[ImportFile]:
    """Retrieve all import files matching optional filters."""
    return repo.get_all_import_files(
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


def get_paginated_import_files_service(
    db: Session,
    params: PageParams,
    *,
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
) -> dict:
    """Retrieve paginated import files with metadata and total count."""
    return repo.get_paginated_import_files(
        db,
        params,
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


def get_search_insights_service(
    db: Session,
    *,
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
) -> dict:
    """Retrieve aggregated counts and facets for the active search criteria."""
    return repo.get_search_insights(
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


def get_operational_dashboard_data_service(
    db: Session,
    phase: Optional[str] = None,
    priority: Optional[str] = None,
    broker_id: Optional[int] = None,
    broker_name: Optional[str] = None,
    search: Optional[str] = None,
) -> dict:
    """Retrieve operational dashboard summary metrics and distributions."""
    return repo.get_operational_dashboard_data(
        db,
        phase=phase,
        priority=priority,
        broker_id=broker_id,
        broker_name=broker_name,
        search=search,
    )


def get_import_file_by_id_service(db: Session, import_file_id: int) -> Optional[ImportFile]:
    """Get import file by its integer ID."""
    return repo.get_import_file_by_id(db, import_file_id)


def get_import_file_by_code_service(
    db: Session, import_file_code: str, include_inactive: bool = False
) -> Optional[ImportFile]:
    """Get import file by its business code (e.g. IMP-2026-0001)."""
    return repo.get_import_file_by_code(db, import_file_code, include_inactive=include_inactive)


def soft_delete_import_file_service(db: Session, import_file_id: int) -> bool:
    """Soft delete an import file."""
    return repo.soft_delete_import_file(db, import_file_id)


__all__ = [
    # Lifecycle constants & helpers
    "STEP_INITIAL_CONFIG",
    "STEP_INITIAL_NEXT_ACTION_CODES",
    "COURIER_KG_PER_CBM",
    "_next_action_fields",
    "_phase_action",
    "compute_file_formulas",
    # Lifecycle mutations
    "create_import_file_service",
    "update_import_file_service",
    "close_shipment_service",
    "reopen_shipment_service",
    "clone_import_file_service",
    "create_partial_batch_service",
    "get_partial_batches_service",
    "generate_freight_rfq_service",
    # Holds & regulatory locks
    "hold_import_file_service",
    "resume_import_file_service",
    "validate_regulatory_clearance_lock",
    "validate_release_readiness",
    "apply_inspection_halt_service",
    # Cost & Reporting
    "STATUS_TRANSLATIONS",
    "STAGE_TRANSLATIONS",
    "generate_master_report_service",
    "get_landed_cost_summary_service",
    "build_export_rows",
    # Query & Repo delegates
    "get_all_import_files_service",
    "get_paginated_import_files_service",
    "get_search_insights_service",
    "get_operational_dashboard_data_service",
    "get_import_file_by_id_service",
    "get_import_file_by_code_service",
    "soft_delete_import_file_service",
]
