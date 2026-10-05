from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from .model import SystemNotification
from .schemas import NotificationCreate


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

    def mark_all_as_read(self, target_role: Optional[str] = None) -> int:
        query = self.db.query(SystemNotification).filter(SystemNotification.is_read == False)
        if target_role and target_role != "ALL":
            query = query.filter(SystemNotification.target_role.in_(["ALL", target_role]))
        
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
