"""
FastAPI Router for Smart Shipment Experience Guide (KB-GUIDE-012)
Institutional Knowledge Engine & Operational Memory + Autonomous Learning Engine (Section 5A)
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user, require_manager_or_admin
from sqlalchemy.orm import Session

from database.database import get_db
from modules.experience_guide.schemas import (
    GuideEntryCreate,
    GuideEntryUpdate,
    GuideEntryResponse,
    GuideMatchRequest,
    GuideMatchResponse,
    SimilarShipmentResponse,
    DetectedPatternResponse,
    SmartReferenceCardResponse,
    GuideEntryPromoteRequest,
    GuideEntryRejectRequest,
    ProvenanceResponse,
    AutonomousAuditLogResponse,
    AutonomousRecalculateResponse,
)
from modules.experience_guide.service import ExperienceGuideService

router = APIRouter(
    prefix="/api/v1/experience-guide",
    tags=["Experience Guide & Institutional Knowledge Engine (KB-GUIDE-012)"],
    dependencies=[Depends(require_permission("import_files.view"))],
)


@router.get("", response_model=List[GuideEntryResponse], summary="List experience guide entries")
def list_guide_entries(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    search: Optional[str] = Query(None, description="Search in title, content, or department"),
    scope_type: Optional[str] = Query(None, description="Filter by scope_type"),
    scope_value: Optional[str] = Query(None, description="Filter by scope_value"),
    is_active: Optional[bool] = Query(True, description="Filter by active status"),
    source_type: Optional[str] = Query(None, description="Filter by source_type (HUMAN_AUTHORED, SYSTEM_INFERRED)"),
    entry_status: Optional[str] = Query(None, alias="status", description="Filter by status (ACTIVE, CONFIRMED, ARCHIVED, REJECTED)"),
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.list_entries(
        skip=skip,
        limit=limit,
        search=search,
        scope_type=scope_type,
        scope_value=scope_value,
        is_active=is_active,
        source_type=source_type,
        status=entry_status,
    )


@router.get("/search", response_model=List[GuideEntryResponse], summary="Semantic / Free-text search")
def search_guide_entries(
    q: str = Query(..., min_length=1, description="Search query string"),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.search_entries(q, limit=limit)


# =============================================================================
# Autonomous Learning Engine (Section 5A) Endpoints
# Placed before /{entry_id} so "autonomous" is not parsed as integer ID
# =============================================================================

@router.post(
    "/autonomous/recalculate",
    response_model=AutonomousRecalculateResponse,
    summary="Trigger autonomous statistical mining recalculation cycle",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def recalculate_autonomous_learning(
    trigger_import_file_id: Optional[int] = Query(None, description="Optional ID of the shipment file that triggered recalculation"),
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.recalculate_autonomous(trigger_import_file_id=trigger_import_file_id)


@router.get("/autonomous/audit-log", response_model=List[AutonomousAuditLogResponse], summary="Get autonomous pattern audit logs")
def get_autonomous_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    entry_id: Optional[int] = Query(None, description="Filter logs by entry ID"),
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.get_autonomous_audit_logs(limit=limit, entry_id=entry_id)


@router.get("/detected-patterns", response_model=List[DetectedPatternResponse], summary="Detect recurring operational patterns across shipments")
def get_detected_patterns(
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.get_detected_patterns()


@router.get("/similar-shipments/{import_file_id}", response_model=List[SimilarShipmentResponse], summary="Get historically similar shipments sharing key dimensions")
def get_similar_shipments(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.get_similar_shipments(import_file_id)


@router.post(
    "",
    response_model=GuideEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create new guide entry with scopes",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def create_guide_entry(
    payload: GuideEntryCreate,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.create_entry(payload)


@router.get("/{entry_id}", response_model=GuideEntryResponse, summary="Get single guide entry by ID")
def get_guide_entry(
    entry_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.get_entry(entry_id)


@router.get("/{entry_id}/provenance", response_model=ProvenanceResponse, summary="Get provenance evidence trail for system-inferred guide entry")
def get_guide_entry_provenance(
    entry_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.get_entry_provenance(entry_id)


@router.post(
    "/{entry_id}/promote",
    response_model=GuideEntryResponse,
    summary="Promote system-inferred note to confirmed human standard",
    dependencies=[Depends(require_permission("import_files.edit")), Depends(require_manager_or_admin)],
)
def promote_guide_entry(
    entry_id: int,
    payload: GuideEntryPromoteRequest,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.promote_inferred_entry(entry_id, payload)


@router.post(
    "/{entry_id}/reject",
    response_model=GuideEntryResponse,
    summary="Reject and suppress system-inferred note",
    dependencies=[Depends(require_permission("import_files.edit")), Depends(require_manager_or_admin)],
)
def reject_guide_entry(
    entry_id: int,
    payload: GuideEntryRejectRequest,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.reject_inferred_entry(entry_id, payload)


@router.put(
    "/{entry_id}",
    response_model=GuideEntryResponse,
    summary="Update existing guide entry",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def update_guide_entry(
    entry_id: int,
    payload: GuideEntryUpdate,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.update_entry(entry_id, payload)


@router.delete(
    "/{entry_id}",
    summary="Deactivate/delete guide entry",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def delete_guide_entry(
    entry_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    service.delete_entry(entry_id)
    return {"message": "Guide entry deactivated successfully", "entry_id": entry_id}


@router.post(
    "/{entry_id}/upvote",
    response_model=GuideEntryResponse,
    summary="Upvote / record feedback for guide entry",
    dependencies=[Depends(require_permission("import_files.edit"))],
)
def upvote_guide_entry(
    entry_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.upvote_entry(entry_id)


@router.post("/match", response_model=GuideMatchResponse, summary="Match shipment against guide entries")
def match_shipment_against_guide(
    payload: GuideMatchRequest,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.match_shipment(payload)


@router.get("/reference-card/{import_file_id}", response_model=SmartReferenceCardResponse, summary="Get dynamic smart reference card for shipment")
def get_smart_reference_card(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    service = ExperienceGuideService(db)
    return service.generate_smart_reference_card(import_file_id)
