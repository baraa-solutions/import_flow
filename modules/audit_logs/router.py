from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db
from modules.common.pagination import Page, PageParams
from .schemas import AuditLogResponse
from .service import AuditLogService

router = APIRouter(prefix="/api/v1/audit-logs", tags=["Audit Logs Engine"], dependencies=[Depends(get_current_user)])


@router.get("/paginated", response_model=Page[AuditLogResponse])
def get_all_audit_logs_paginated(
    response: Response,
    params: PageParams = Depends(),
    entity_type: Optional[str] = Query(None, description="Filter by entity type"),
    action: Optional[str] = Query(None, description="Filter by action (CREATE, UPDATE, DELETE, RESTORE)"),
    performed_by: Optional[str] = Query(None, description="Filter by performed_by user"),
    db: Session = Depends(get_db),
):
    service = AuditLogService(db)
    return service.get_paginated_logs(
        params=params,
        response=response,
        entity_type=entity_type,
        action=action,
        performed_by=performed_by,
    )


@router.get("/{entity_type}/{entity_id}/paginated", response_model=Page[AuditLogResponse])
def get_entity_audit_timeline_paginated(
    entity_type: str,
    entity_id: int,
    response: Response,
    params: PageParams = Depends(),
    action: Optional[str] = Query(None, description="Filter by action"),
    db: Session = Depends(get_db),
):
    service = AuditLogService(db)
    return service.get_paginated_logs_for_entity(
        entity_type=entity_type,
        entity_id=entity_id,
        params=params,
        response=response,
        action=action,
    )


@router.get("", response_model=List[AuditLogResponse])
def get_all_audit_logs(limit: int = Query(100, ge=1, le=500), db: Session = Depends(get_db)):
    service = AuditLogService(db)
    return service.get_all_logs(limit=limit)


@router.get("/{entity_type}/{entity_id}", response_model=List[AuditLogResponse])
def get_entity_audit_timeline(entity_type: str, entity_id: int, db: Session = Depends(get_db)):
    service = AuditLogService(db)
    return service.get_logs_for_entity(entity_type=entity_type, entity_id=entity_id)
