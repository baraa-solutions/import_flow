"""
Notifications WebSocket first-frame authentication:
connect -> send {"type": "auth", "token": "<jwt>"} within the timeout -> {"event": "auth_ok"} -> ping/pong.
Anything else closes the socket with 1008 and the socket is never registered for broadcasts.
"""

import json

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.websockets import WebSocketDisconnect

import main
import modules.auth.permissions as auth_permissions
import modules.notifications.router as notifications_router
from database.database import Base
from modules.auth.permissions import authenticate_ws_token, invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.notifications.websocket_manager import parse_auth_frame, websocket_manager
from modules.users.model import User

WS_PATH = "/api/v1/notifications/ws"


@pytest.fixture
def ws_db(monkeypatch):
    """authenticate_ws_token opens its own SessionLocal: point it at an isolated in-memory DB."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    factory = sessionmaker(bind=engine)
    monkeypatch.setattr(auth_permissions, "SessionLocal", factory)
    # The bypass must never apply to the WebSocket, even when enabled.
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", True)
    invalidate_permission_cache()
    session = factory()
    yield session
    session.close()
    invalidate_permission_cache()
    engine.dispose()


def _user(db, username: str = "ws_user", is_active: bool = True) -> User:
    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role="LOGISTICS_OPERATOR",
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _token(user_id) -> str:
    return create_access_token({"sub": str(user_id), "role": "LOGISTICS_OPERATOR"})


@pytest.fixture
def client():
    return TestClient(main.app)


def _expect_policy_close(ws) -> None:
    with pytest.raises(WebSocketDisconnect) as exc:
        ws.receive_text()
    assert exc.value.code == 1008


def test_no_auth_message_times_out_with_1008(client, ws_db, monkeypatch):
    monkeypatch.setattr(notifications_router, "WS_AUTH_TIMEOUT_SECONDS", 0.2)
    before = len(websocket_manager.active_connections)
    with client.websocket_connect(WS_PATH) as ws:
        _expect_policy_close(ws)
    assert len(websocket_manager.active_connections) == before


def test_bad_token_closes_with_1008(client, ws_db):
    before = len(websocket_manager.active_connections)
    with client.websocket_connect(WS_PATH) as ws:
        ws.send_text(json.dumps({"type": "auth", "token": "not-a-jwt"}))
        _expect_policy_close(ws)
    assert len(websocket_manager.active_connections) == before


@pytest.mark.parametrize("frame", ["ping", "{}", json.dumps({"type": "hello", "token": "x"}), json.dumps({"type": "auth"})])
def test_malformed_first_frame_closes_with_1008(client, ws_db, frame):
    with client.websocket_connect(WS_PATH) as ws:
        ws.send_text(frame)
        _expect_policy_close(ws)


def test_deleted_user_token_closes_with_1008(client, ws_db):
    with client.websocket_connect(WS_PATH) as ws:
        ws.send_text(json.dumps({"type": "auth", "token": _token(424242)}))
        _expect_policy_close(ws)


def test_inactive_user_token_closes_with_1008(client, ws_db):
    user = _user(ws_db, "ws_inactive", is_active=False)
    with client.websocket_connect(WS_PATH) as ws:
        ws.send_text(json.dumps({"type": "auth", "token": _token(user.user_id)}))
        _expect_policy_close(ws)


def test_valid_token_gets_auth_ok_then_pong_and_broadcasts(client, ws_db):
    user = _user(ws_db)
    before = len(websocket_manager.active_connections)
    with client.websocket_connect(WS_PATH) as ws:
        ws.send_text(json.dumps({"type": "auth", "token": _token(user.user_id)}))
        assert ws.receive_json() == {"event": "auth_ok"}
        assert len(websocket_manager.active_connections) == before + 1
        ws.send_text("ping")
        assert ws.receive_json() == {"event": "pong"}
    # TestClient closes the socket on exit; the server loop then unregisters it.
    assert len(websocket_manager.active_connections) == before


def test_parse_auth_frame():
    assert parse_auth_frame(json.dumps({"type": "auth", "token": " abc "})) == "abc"
    assert parse_auth_frame("not json") is None
    assert parse_auth_frame(json.dumps(["auth"])) is None
    assert parse_auth_frame(json.dumps({"type": "auth", "token": 5})) is None
    assert parse_auth_frame(None) is None


def test_authenticate_ws_token_helper(ws_db):
    user = _user(ws_db, "ws_helper")
    resolved = authenticate_ws_token(_token(user.user_id))
    assert resolved is not None and resolved.username == "ws_helper"
    assert authenticate_ws_token(None) is None
    assert authenticate_ws_token("") is None
    assert authenticate_ws_token("garbage") is None
    assert authenticate_ws_token(_token(987654)) is None
