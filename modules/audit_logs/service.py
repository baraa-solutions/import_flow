import json
from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy import or_
from sqlalchemy.orm import Session
from modules.common.pagination import PageParams, like_term, paginate
from .model import AuditLog
from .schemas import AuditLogResponse


AUDIT_LOG_SORT_MAP = {
    "log_id": AuditLog.log_id,
    "entity_type": AuditLog.entity_type,
    "entity_id": AuditLog.entity_id,
    "entity_code": AuditLog.entity_code,
    "action": AuditLog.action,
    "performed_at": AuditLog.performed_at,
    "performed_by": AuditLog.performed_by,
}


class AuditLogService:
    def __init__(self, db: Session):
        self.db = db

    def log_activity(
        self,
        entity_type: str,
        entity_id: int,
        action: str,
        entity_code: Optional[str] = None,
        old_data: Optional[Dict[str, Any]] = None,
        new_data: Optional[Dict[str, Any]] = None,
        performed_by: str = "System Admin",
        changes_summary: Optional[str] = None,
    ) -> AuditLog:
        changes = []
        old_json = json.dumps(old_data, default=str) if old_data else None
        new_json = json.dumps(new_data, default=str) if new_data else None

        if changes_summary is None:
            if action == "CREATE":
                changes_summary = f"Created new {entity_type} record"
            elif action == "DELETE":
                changes_summary = f"Deactivated {entity_type} record"
            elif action == "RESTORE":
                changes_summary = f"Reactivated {entity_type} record"
            elif action == "UPDATE" and old_data and new_data:
                for key, new_val in new_data.items():
                    if key in old_data and old_data[key] != new_val:
                        changes.append(f"{key}: '{old_data[key]}' -> '{new_val}'")
                changes_summary = "Updated fields: " + (", ".join(changes) if changes else "No field values changed")
            else:
                changes_summary = f"Performed {action} on {entity_type}"

        log_obj = AuditLog(
            entity_type=entity_type,
            entity_id=entity_id,
            entity_code=entity_code,
            action=action,
            changes_summary=changes_summary,
            old_values=old_json,
            new_values=new_json,
            performed_by=performed_by,
        )
        self.db.add(log_obj)
        self.db.commit()
        self.db.refresh(log_obj)
        return log_obj

    def get_logs_for_entity(self, entity_type: str, entity_id: int) -> List[AuditLogResponse]:
        return self.db.query(AuditLog).filter(
            AuditLog.entity_type == entity_type,
            AuditLog.entity_id == entity_id
        ).order_by(AuditLog.log_id.desc()).all()

    def get_all_logs(self, limit: int = 100) -> List[AuditLogResponse]:
        return self.db.query(AuditLog).order_by(AuditLog.log_id.desc()).limit(limit).all()

    def get_paginated_logs(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        entity_type: Optional[str] = None,
        action: Optional[str] = None,
        performed_by: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = self.db.query(AuditLog)
        if entity_type:
            query = query.filter(AuditLog.entity_type == entity_type)
        if action:
            query = query.filter(AuditLog.action == action)
        if performed_by:
            query = query.filter(AuditLog.performed_by == performed_by)

        term = like_term(params.q)
        if term:
            query = query.filter(
                or_(
                    AuditLog.entity_type.ilike(term, escape="\\"),
                    AuditLog.entity_code.ilike(term, escape="\\"),
                    AuditLog.action.ilike(term, escape="\\"),
                    AuditLog.performed_by.ilike(term, escape="\\"),
                    AuditLog.changes_summary.ilike(term, escape="\\"),
                )
            )

        return paginate(
            query,
            params,
            sort_map=AUDIT_LOG_SORT_MAP,
            default_sort=[AuditLog.log_id.desc()],
            pk=AuditLog.log_id,
            response=response,
        )

    def get_paginated_logs_for_entity(
        self,
        entity_type: str,
        entity_id: int,
        params: PageParams,
        response: Optional[Response] = None,
        action: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = self.db.query(AuditLog).filter(
            AuditLog.entity_type == entity_type,
            AuditLog.entity_id == entity_id,
        )
        if action:
            query = query.filter(AuditLog.action == action)

        term = like_term(params.q)
        if term:
            query = query.filter(
                or_(
                    AuditLog.entity_code.ilike(term, escape="\\"),
                    AuditLog.action.ilike(term, escape="\\"),
                    AuditLog.performed_by.ilike(term, escape="\\"),
                    AuditLog.changes_summary.ilike(term, escape="\\"),
                )
            )

        return paginate(
            query,
            params,
            sort_map=AUDIT_LOG_SORT_MAP,
            default_sort=[AuditLog.log_id.desc()],
            pk=AuditLog.log_id,
            response=response,
        )
