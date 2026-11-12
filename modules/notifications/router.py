import asyncio
import json
import time
import threading
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, Response, WebSocket, WebSocketDisconnect, status
from starlette.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import authenticate_ws_token
from modules.auth.router import get_current_user, require_admin
from modules.users.model import User
from modules.common.pagination import Page, PageParams
from .schemas import NotificationCreate, NotificationResponse, NotificationSummary
from .service import NotificationService
from .websocket_manager import parse_auth_frame, websocket_manager

_LAST_EXPIRY_CHECK_TIMESTAMP: float = 0.0
_EXPIRY_CHECK_LOCK = threading.Lock()
_EXPIRY_CHECK_COOLDOWN_SECONDS: float = 120.0  # 2-minute cooldown between background scans

# Seconds a freshly accepted WebSocket has to send its {"type": "auth", "token": ...} frame.
WS_AUTH_TIMEOUT_SECONDS: float = 10.0
# RFC 6455 "policy violation": used for missing, malformed or invalid auth frames.
WS_POLICY_VIOLATION_CODE = 1008

router = APIRouter(
    prefix="/api/v1/notifications",
    tags=["System Notifications & Real-Time Expiry Engine"],
    dependencies=[Depends(get_current_user)],
)

# WebSocket routes cannot carry the Authorization header from browsers, so they live on a separate
# router without HTTP auth dependencies and authenticate through the first message instead.
ws_router = APIRouter(prefix="/api/v1/notifications", tags=["System Notifications & Real-Time Expiry Engine"])


@router.get("/paginated", response_model=Page[NotificationResponse])
def get_notifications_paginated(
    response: Response,
    params: PageParams = Depends(),
    unread_only: bool = Query(False, description="Filter unread notifications only"),
    target_role: Optional[str] = Query(None, description="Role filter (ADMIN, MANAGER, OPERATOR)"),
    severity: Optional[str] = Query(None, description="Severity filter (INFO, WARNING, CRITICAL)"),
    category: Optional[str] = Query(None, description="Category filter"),
    db: Session = Depends(get_db),
):
    service = NotificationService(db)
    return service.get_paginated(
        params=params,
        response=response,
        unread_only=unread_only,
        target_role=target_role,
        severity=severity,
        category=category,
    )


@router.get("", response_model=List[NotificationResponse])
def get_notifications(
    unread_only: bool = Query(False, description="Filter unread notifications only"),
    target_role: Optional[str] = Query(None, description="Role filter (ADMIN, MANAGER, OPERATOR)"),
    severity: Optional[str] = Query(None, description="Severity filter (INFO, WARNING, CRITICAL)"),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    service = NotificationService(db)
    return service.get_notifications(unread_only=unread_only, target_role=target_role, severity=severity, limit=limit)


@router.get("/summary", response_model=NotificationSummary)
def get_notification_summary(
    target_role: Optional[str] = Query(None, description="Role filter"),
    db: Session = Depends(get_db),
):
    service = NotificationService(db)
    return service.get_summary(target_role=target_role)


@router.post("", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_admin)])
async def create_notification(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
):
    service = NotificationService(db)
    created = service.create_notification(payload)
    
    # Broadcast to all connected clients via WebSocket
    await websocket_manager.broadcast({
        "event": "NEW_NOTIFICATION",
        "data": {
            "notification_id": created.notification_id,
            "title": created.title,
            "message": created.message,
            "severity": created.severity,
            "category": created.category,
            "msg_code": created.msg_code,
            "msg_params": created.msg_params,
            "created_at": created.created_at.isoformat(),
        }
    })
    return created


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = NotificationService(db)
    updated = service.mark_read(notification_id, user=current_user)
    return updated


@router.post("/mark-all-read")
def mark_all_notifications_as_read(
    target_role: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = NotificationService(db)
    count = service.mark_all_read(target_role=target_role, user=current_user)
    return {"message": "All notifications marked as read", "count": count}


@router.post("/trigger-expiry-check", response_model=List[NotificationResponse], dependencies=[Depends(require_admin)])
async def trigger_expiry_check(
    force: bool = Query(False, description="Force expiry check bypassing debounce cooldown"),
    db: Session = Depends(get_db),
):
    global _LAST_EXPIRY_CHECK_TIMESTAMP
    now = time.time()
    with _EXPIRY_CHECK_LOCK:
        if not force and (now - _LAST_EXPIRY_CHECK_TIMESTAMP < _EXPIRY_CHECK_COOLDOWN_SECONDS):
            return []
        _LAST_EXPIRY_CHECK_TIMESTAMP = now

    service = NotificationService(db)
    new_notifs = service.trigger_expiry_check()
    for notif in new_notifs:
        await websocket_manager.broadcast({
            "event": "EXPIRY_ALERT",
            "data": {
                "notification_id": notif.notification_id,
                "title": notif.title,
                "message": notif.message,
                "severity": notif.severity,
                "category": notif.category,
                "msg_code": notif.msg_code,
                "msg_params": notif.msg_params,
                "created_at": notif.created_at.isoformat(),
            }
        })
    return new_notifs


@ws_router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    Protocol: the client connects, then must send {"type": "auth", "token": "<jwt>"} within
    WS_AUTH_TIMEOUT_SECONDS. A valid token gets {"event": "auth_ok"} and the socket starts receiving
    broadcasts; "ping" is answered with {"event": "pong"}. Anything else closes the socket with 1008.
    """
    await websocket_manager.accept(websocket)
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=WS_AUTH_TIMEOUT_SECONDS)
    except WebSocketDisconnect:
        return
    except (asyncio.TimeoutError, KeyError, RuntimeError):
        # Timeout, or a binary / non-text first frame.
        await websocket.close(code=WS_POLICY_VIOLATION_CODE)
        return

    token = parse_auth_frame(raw)
    user = await run_in_threadpool(authenticate_ws_token, token) if token else None
    if user is None:
        await websocket.close(code=WS_POLICY_VIOLATION_CODE)
        return

    await websocket.send_text(json.dumps({"event": "auth_ok"}))
    websocket_manager.register(websocket)
    try:
        while True:
            # Keep connection open and receive ping messages
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text('{"event": "pong"}')
    except WebSocketDisconnect:
        pass
    finally:
        websocket_manager.disconnect(websocket)
