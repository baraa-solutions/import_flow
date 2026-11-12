from typing import Any, Dict, List, Optional, Set
from fastapi import HTTPException, Response, status
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

    @staticmethod
    def audience_roles(user: Any) -> Optional[Set[str]]:
        """Roles whose notifications ``user`` may mark read: None (unrestricted) for an admin, otherwise the
        caller's legacy role and assigned RBAC role code (target_role values are role codes or ALL)."""
        from modules.auth.permissions import is_admin_user

        if user is None:
            return set()
        if is_admin_user(user):
            return None
        roles = {(getattr(user, "role", None) or "").strip().upper()}
        assigned = getattr(user, "assigned_role", None)
        roles.add((getattr(assigned, "role_code", None) or "").strip().upper())
        return {r for r in roles if r}

    def mark_read(self, notification_id: int, user: Any = None) -> Optional[NotificationResponse]:
        """Marks one notification read. A non-admin caller may only touch notifications addressed to ALL or to
        one of its roles (404 otherwise, so other roles' notifications are not even confirmed to exist)."""
        audience = self.audience_roles(user)
        if audience is not None:
            notification = self.repo.get_by_id(notification_id)
            if notification is None or (notification.target_role or "ALL") not in ({"ALL"} | audience):
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
        return self.repo.mark_as_read(notification_id)

    def mark_all_read(self, target_role: Optional[str] = None, user: Any = None) -> int:
        """Marks all visible unread notifications read; a non-admin caller is limited to its own audience."""
        return self.repo.mark_all_as_read(target_role=target_role, audience_roles=self.audience_roles(user))

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
