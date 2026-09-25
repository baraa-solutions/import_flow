from typing import List
from fastapi import APIRouter, Depends, Query
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db
from .schemas import AuditLogResponse
from .service import AuditLogService

router = APIRouter(prefix="/api/v1/audit-logs", tags=["Audit Logs Engine"], dependencies=[Depends(get_current_user)])


@router.get("", response_model=List[AuditLogResponse])
def get_all_audit_logs(limit: int = Query(100, ge=1, le=500), db: Session = Depends(get_db)):
    service = AuditLogService(db)
    return service.get_all_logs(limit=limit)


@router.get("/{entity_type}/{entity_id}", response_model=List[AuditLogResponse])
def get_entity_audit_timeline(entity_type: str, entity_id: int, db: Session = Depends(get_db)):
    service = AuditLogService(db)
    return service.get_logs_for_entity(entity_type=entity_type, entity_id=entity_id)
