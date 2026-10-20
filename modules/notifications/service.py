from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy.orm import Session
from modules.common.pagination import PageParams
from .repository import NotificationRepository
from .schemas import NotificationCreate, NotificationResponse, NotificationSummary
from .expiry_checker import ExpiryCheckerService


class NotificationService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = NotificationRepository(db)

    def get_notifications(
        self,
        unread_only: bool = False,
        target_role: Optional[str] = None,
        severity: Optional[str] = None,
        limit: int = 100,
    ) -> List[NotificationResponse]:
        return self.repo.get_all(unread_only=unread_only, target_role=target_role, severity=severity, limit=limit)

    def get_paginated(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        unread_only: bool = False,
        target_role: Optional[str] = None,
        severity: Optional[str] = None,
        category: Optional[str] = None,
    ) -> Dict[str, Any]:
        return self.repo.get_paginated(
            params,
            response=response,
            unread_only=unread_only,
            target_role=target_role,
            severity=severity,
            category=category,
        )

    def create_notification(self, schema: NotificationCreate) -> NotificationResponse:
        return self.repo.create(schema)

    def mark_read(self, notification_id: int) -> Optional[NotificationResponse]:
        return self.repo.mark_as_read(notification_id)

    def mark_all_read(self, target_role: Optional[str] = None) -> int:
        return self.repo.mark_all_as_read(target_role=target_role)

    def get_summary(self, target_role: Optional[str] = None) -> NotificationSummary:
        all_notifs = self.repo.get_all(unread_only=False, target_role=target_role, limit=500)
        unread = [n for n in all_notifs if not n.is_read]
        critical = [n for n in unread if n.severity == "CRITICAL"]
        warning = [n for n in unread if n.severity == "WARNING"]

        return NotificationSummary(
            unread_count=len(unread),
            total_count=len(all_notifs),
            critical_count=len(critical),
            warning_count=len(warning),
        )

    def trigger_expiry_check(self) -> List[NotificationResponse]:
        checker = ExpiryCheckerService(self.db)
        return checker.check_all_expiries()
