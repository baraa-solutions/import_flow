from typing import Any, Dict, Iterable, List, Optional
from datetime import datetime, timezone
from fastapi import Response
from sqlalchemy import or_
from sqlalchemy.orm import Session
from modules.common.pagination import PageParams, like_term, paginate
from .model import SystemNotification
from .schemas import NotificationCreate
from .utils import normalized_target_role_column


NOTIFICATION_SORT_MAP = {
    "notification_id": SystemNotification.notification_id,
    "title": SystemNotification.title,
    "severity": SystemNotification.severity,
    "category": SystemNotification.category,
    "target_role": SystemNotification.target_role,
    "is_read": SystemNotification.is_read,
    "created_at": SystemNotification.created_at,
    "updated_at": SystemNotification.updated_at,
}


class NotificationRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(
        self,
        unread_only: bool = False,
        target_role: Optional[str] = None,
        severity: Optional[str] = None,
        limit: int = 100,
    ) -> List[SystemNotification]:
        query = self.db.query(SystemNotification)
        if unread_only:
            query = query.filter(SystemNotification.is_read == False)
        if target_role and target_role != "ALL":
            query = query.filter(SystemNotification.target_role.in_(["ALL", target_role]))
        if severity:
            query = query.filter(SystemNotification.severity == severity)
        
        return query.order_by(SystemNotification.created_at.desc()).limit(limit).all()

    def get_paginated(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        unread_only: bool = False,
        target_role: Optional[str] = None,
        severity: Optional[str] = None,
        category: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = self.db.query(SystemNotification)
        if unread_only:
            query = query.filter(SystemNotification.is_read == False)
        if target_role and target_role != "ALL":
            query = query.filter(SystemNotification.target_role.in_(["ALL", target_role]))
        if severity:
            query = query.filter(SystemNotification.severity == severity)
        if category:
            query = query.filter(SystemNotification.category == category)

        term = like_term(params.q)
        if term:
            query = query.filter(
                or_(
                    SystemNotification.title.ilike(term, escape="\\"),
                    SystemNotification.message.ilike(term, escape="\\"),
                    SystemNotification.category.ilike(term, escape="\\"),
                    SystemNotification.severity.ilike(term, escape="\\"),
                )
            )

        return paginate(
            query,
            params,
            sort_map=NOTIFICATION_SORT_MAP,
            default_sort=[SystemNotification.notification_id.desc()],
            pk=SystemNotification.notification_id,
            response=response,
        )

    def get_by_id(self, notification_id: int) -> Optional[SystemNotification]:
        return self.db.query(SystemNotification).filter(SystemNotification.notification_id == notification_id).first()

    def create(self, schema: NotificationCreate) -> SystemNotification:
        db_obj = SystemNotification(
            title=schema.title,
            message=schema.message,
            severity=schema.severity,
            category=schema.category,
            entity_type=schema.entity_type,
            entity_id=schema.entity_id,
            target_role=schema.target_role,
            msg_code=getattr(schema, "msg_code", None),
            msg_params=getattr(schema, "msg_params", None),
            is_read=False,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        self.db.add(db_obj)
        self.db.commit()
        self.db.refresh(db_obj)
        return db_obj

    def mark_as_read(self, notification_id: int) -> Optional[SystemNotification]:
        db_obj = self.get_by_id(notification_id)
        if db_obj:
            db_obj.is_read = True
            db_obj.updated_at = datetime.now(timezone.utc)
            self.db.commit()
            self.db.refresh(db_obj)
        return db_obj

    def mark_all_as_read(self, target_role: Optional[str] = None, audience_names: Optional[Iterable[str]] = None) -> int:
        """Marks unread notifications read. ``audience_names`` (non-admin callers: the normalised target_role
        values addressed to them, see notifications.utils) limits the update; ``None`` means unrestricted (admin).
        Stored values are compared in normalised form, so legacy rows like "Customs Broker" match too."""
        query = self.db.query(SystemNotification).filter(SystemNotification.is_read == False)
        if target_role and target_role != "ALL":
            query = query.filter(SystemNotification.target_role.in_(["ALL", target_role]))
        if audience_names is not None:
            normalized = normalized_target_role_column(SystemNotification.target_role)
            query = query.filter(normalized.in_(sorted(audience_names)))

        updated_count = query.update({SystemNotification.is_read: True, SystemNotification.updated_at: datetime.now(timezone.utc)}, synchronize_session=False)
        self.db.commit()
        return updated_count

    def exists_active_for_entity(self, entity_type: str, entity_id: int, category: str) -> bool:
        return self.db.query(SystemNotification).filter(
            SystemNotification.entity_type == entity_type,
            SystemNotification.entity_id == entity_id,
            SystemNotification.category == category,
            SystemNotification.is_read == False,
        ).first() is not None
