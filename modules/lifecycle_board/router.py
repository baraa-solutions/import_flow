"""
FastAPI Router for 6-Phase Lifecycle Board & Stage Transitions
"""

from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import effective_role_code, require_permission
from modules.auth.router import get_current_user
from modules.users.model import User
from modules.lifecycle_board.schemas import (
    LifecycleBoardSummaryResponse,
    LiveLogisticsSummaryResponse,
    StageActivityResponse,
    StepAdvancePayload,
    SkipStepPayload,
    MultiStageSetPayload,
    LifecycleSyncRequest,
    StepConfigResponse,
    StepConfigUpdateRequest,
    StepConfigAuditLogResponse,
    RegisterPendingReferenceRequest,
    RegisterPendingReferenceResponse,
    ShipmentTimelineResponse,
)
import modules.lifecycle_board.service as service

router = APIRouter(
    prefix="/api/v1/lifecycle-board",
    tags=["Shipment Lifecycle Board (6 Phases / 25 Steps)"],
    dependencies=[Depends(get_current_user)],
)


# ─── Configurable Step Risk & Settings Endpoints (Addendum: Section 10) ───

@router.get(
    "/step-configs",
    response_model=List[StepConfigResponse],
    summary="Get configuration of all lifecycle steps (Addendum: Section 10)",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_all_step_configs(
    db: Session = Depends(get_db),
):
    return service.get_all_step_configs_service(db)


@router.get(
    "/step-configs/{step_code}",
    response_model=StepConfigResponse,
    summary="Get configuration for a specific lifecycle step",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_step_config(
    step_code: str,
    db: Session = Depends(get_db),
):
    return service.get_step_config_service(db, step_code)


@router.put(
    "/step-configs/{step_code}",
    response_model=StepConfigResponse,
    summary="Update step skip policy, reason categories, approver roles, or pending ref eligibility (Manager Only, Section 10.7)",
    dependencies=[Depends(require_permission("users.manage"))],
)
def update_step_config(
    step_code: str,
    payload: StepConfigUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.update_step_config_service(
        db=db,
        step_code=step_code,
        payload=payload,
        current_user_role=effective_role_code(current_user),
        current_username=current_user.username,
        actor=current_user,
    )


@router.get(
    "/step-configs/{step_code}/audit-logs",
    response_model=List[StepConfigAuditLogResponse],
    summary="Get change audit trail for a step's classification rules (Section 10.3)",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_step_config_audit_logs(
    step_code: str,
    db: Session = Depends(get_db),
):
    return service.get_step_config_audit_logs_service(db, step_code=step_code)


@router.post(
    "/stages/register-pending-reference",
    response_model=RegisterPendingReferenceResponse,
    status_code=status.HTTP_200_OK,
    summary="Register reference number now, complete full compliance later (Section 10.4)",
    dependencies=[Depends(require_permission("lifecycle_board.advance"))],
)
def register_pending_reference(
    payload: RegisterPendingReferenceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.register_pending_reference_service(
        db=db,
        payload=payload,
        current_username=current_user.username,
    )


# ─── Operational Board & Lifecycle Endpoints ───

@router.get(
    "/summary",
    response_model=LifecycleBoardSummaryResponse,
    summary="Get 6-phase board summary with active shipment cards and phase counts",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_board_summary(db: Session = Depends(get_db)):
    return service.get_board_summary_service(db)


@router.get(
    "/live-tracking",
    response_model=LiveLogisticsSummaryResponse,
    summary="Get aggregated live logistics tracking intelligence (ETA, Demurrage Risk, Samples, Document Completeness)",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_live_logistics_tracking(db: Session = Depends(get_db)):
    return service.get_live_logistics_tracking_service(db)


@router.get(
    "/shipments/{import_file_code}/stages",
    response_model=List[StageActivityResponse],
    summary="Get all stage activities for a specific shipment",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_shipment_stages(import_file_code: str, db: Session = Depends(get_db)):
    return service.get_all_activities_service(db, import_file_code=import_file_code)


@router.get(
    "/shipments/{import_file_code}/timeline",
    response_model=ShipmentTimelineResponse,
    summary="Get execution timeline and sequence integrity report for a specific shipment",
    dependencies=[Depends(require_permission("lifecycle_board.view"))],
)
def get_shipment_timeline(import_file_code: str, db: Session = Depends(get_db)):
    return service.get_shipment_timeline_service(db, import_file_code=import_file_code)


@router.post(
    "/stages/advance",
    status_code=status.HTTP_200_OK,
    summary="Mark step completed and advance to next target step(s)",
    dependencies=[Depends(require_permission("lifecycle_board.advance"))],
)
def advance_step(
    payload: StepAdvancePayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.advance_step_service(db, payload, actor=current_user)


@router.post(
    "/stages/sync",
    status_code=status.HTTP_200_OK,
    summary="Generic centralized lifecycle synchronization engine for all 21 operational steps",
    dependencies=[Depends(require_permission("lifecycle_board.advance"))],
)
def sync_lifecycle_step(
    payload: LifecycleSyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.http_advance_step_service(
        db=db,
        completed_step_code=payload.completed_step_code,
        import_file_code=payload.import_file_code,
        import_file_id=payload.import_file_id,
        target_step_codes=payload.target_step_codes,
        auto_complete_prior=payload.auto_complete_prior,
        action_data=payload.action_data,
        notes=payload.notes,
        enforce_gatekeeper=payload.enforce_gatekeeper,
        actor=current_user,
    )


@router.post(
    "/stages/skip",
    status_code=status.HTTP_200_OK,
    summary="Skip an operational step enforcing live step_config policy and audit logging",
    dependencies=[Depends(require_permission("lifecycle_board.advance"))],
)
def skip_step(
    payload: SkipStepPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.skip_step_service(
        db=db,
        payload=payload,
        actor=current_user,
        current_user_role=effective_role_code(current_user),
        current_username=current_user.username,
    )


@router.post(
    "/stages/set-active",
    status_code=status.HTTP_200_OK,
    summary="Set concurrent active stages for a shipment",
    dependencies=[Depends(require_permission("lifecycle_board.advance"))],
)
def set_multi_active_stages(
    payload: MultiStageSetPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.set_multi_active_stages_service(db, payload, actor=current_user)


