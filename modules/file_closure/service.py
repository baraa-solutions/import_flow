"""
Unified Coordinator / Facade for Phase 10 - Import File Closure & Historical Archive.

Decomposed into focused domain-specific sub-services:
- file_closure_audit_service.py: Pre-closure audit checklist, customs release verification,
  clearance settlement validation, and 36-date lifecycle audit timeline.
- file_closure_workflow_service.py: Closure approval, state transition to CLOSED, archive registration,
  final comprehensive dossier generation, and closure records management.
- file_closure_reopen_service.py: Reopening protocol, supervisor overrides, justification logging,
  and audit trail verification.
- helpers.py: Shared internal helpers and constants.

All public and internal functions are re-exported here for 100% backward compatibility.
"""
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session

from .model import ImportFileClosureRecord
from .schemas import (
    FileClosureCreate,
    FileClosureUpdate,
    ComprehensiveShipmentDossierResponse,
    DossierExportConfirmRequest,
    DossierExportConfirmResponse,
    ClosurePrecheckResponse,
    OfficialClosureCertificateResponse,
    ShipmentAuditTimelineResponse,
)
from .helpers import (
    OPEN_TASK_STATUSES,
    CLOSURE_MODULE,
    LEGACY_AUDITOR_DEFAULTS,
    LEGACY_EXPORTER_DEFAULTS,
    _get_active_file,
    _party_names,
    _resolve_user_name,
    _require_any_permission,
    _is_closure_task,
    _to_date,
)
from .file_closure_audit_service import (
    _closure_facts,
    evaluate_file_closure_gate,
    verify_customs_release_readiness,
    verify_clearance_settlement_readiness,
    get_closure_precheck_service,
    get_shipment_audit_timeline_service,
    update_audit_meeting_directives_service,
)
from .file_closure_workflow_service import (
    CLOSED_RECORD_EDITABLE,
    _insert_closure,
    _is_locked_closure,
    _fob_egp,
    _stored_clearance_fob_egp,
    close_import_file_service,
    official_close_import_file_service,
    get_closure_service,
    list_closures_service,
    update_closure_service,
    soft_delete_closure_service,
    restore_closure_service,
    get_comprehensive_shipment_dossier_service,
    confirm_dossier_export_service,
)
from .file_closure_reopen_service import (
    validate_can_reopen_file,
    reopen_closed_file_service,
    reopen_closure_record_service,
    get_closure_reopen_history,
)

__all__ = [
    # Constants
    "OPEN_TASK_STATUSES",
    "CLOSURE_MODULE",
    "LEGACY_AUDITOR_DEFAULTS",
    "LEGACY_EXPORTER_DEFAULTS",
    "CLOSED_RECORD_EDITABLE",
    # Shared helpers
    "_get_active_file",
    "_party_names",
    "_resolve_user_name",
    "_require_any_permission",
    "_is_closure_task",
    "_to_date",
    "_closure_facts",
    "evaluate_file_closure_gate",
    "_insert_closure",
    "_is_locked_closure",
    "_fob_egp",
    "_stored_clearance_fob_egp",
    # Workflow Services
    "close_import_file_service",
    "official_close_import_file_service",
    "get_closure_service",
    "list_closures_service",
    "update_closure_service",
    "soft_delete_closure_service",
    "restore_closure_service",
    "get_comprehensive_shipment_dossier_service",
    "confirm_dossier_export_service",
    # Audit Services
    "get_closure_precheck_service",
    "get_shipment_audit_timeline_service",
    "update_audit_meeting_directives_service",
    "verify_customs_release_readiness",
    "verify_clearance_settlement_readiness",
    # Reopen Services
    "validate_can_reopen_file",
    "reopen_closed_file_service",
    "reopen_closure_record_service",
    "get_closure_reopen_history",
]
