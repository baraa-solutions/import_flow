import os
import json
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from database.database import Base
from modules.system_observability.alert_dispatcher import (
    AlertDispatcher,
    AlertPayload,
    alert_dispatcher,
)
from modules.system_observability.service import slow_query_tracker


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def isolated_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_alert_cooldown_manager():
    dispatcher = AlertDispatcher()
    dispatcher.reset_cooldown()

    # Initially all conditions can fire
    assert dispatcher.can_fire("DISK_SPACE_WARNING") is True
    assert dispatcher.can_fire("BACKUP_OVERDUE") is True

    # Mark fired
    dispatcher.mark_fired("DISK_SPACE_WARNING")
    assert dispatcher.can_fire("DISK_SPACE_WARNING") is False

    # Other conditions unaffected
    assert dispatcher.can_fire("BACKUP_OVERDUE") is True

    # Reset cooldown allows firing again
    dispatcher.reset_cooldown("DISK_SPACE_WARNING")
    assert dispatcher.can_fire("DISK_SPACE_WARNING") is True


def test_toast_delivery_mocked():
    dispatcher = AlertDispatcher()
    payload = AlertPayload(
        condition_key="DISK_SPACE_CRITICAL",
        title="Critical Low Disk Space",
        message="Free disk space is below 2GB",
        severity="CRITICAL",
        channels=["TOAST"],
        target_tab="deep-health",
    )

    with patch("subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(returncode=0, stdout="TOAST_SUCCESS\n", stderr="")
        success = dispatcher.send_toast(payload)
        assert success is True
        assert len(dispatcher.toast_history) > 0
        assert dispatcher.toast_history[-1]["condition_key"] == "DISK_SPACE_CRITICAL"


def test_email_offline_fallback():
    dispatcher = AlertDispatcher()
    payload = AlertPayload(
        condition_key="ACID_EXPIRING",
        title="Expiring ACID",
        message="Session expires in 3 days",
        severity="MEDIUM",
        channels=["EMAIL"],
        target_tab="domain-radar",
    )

    # With no SMTP configured, falls back to offline log
    with patch.dict(os.environ, {"SMTP_HOST": "", "ALERT_RECIPIENT_EMAIL": "admin@importflow.local"}):
        success = dispatcher.send_email(payload, db=None)
        assert success is True
        assert len(dispatcher.email_history) > 0
        latest = dispatcher.email_history[-1]
        assert latest["delivery_mode"] == "OFFLINE_AUDIT_LOG"
        assert latest["delivered"] is True


def test_evaluate_all_conditions_with_overrides(isolated_db):
    dispatcher = AlertDispatcher()
    dispatcher.reset_cooldown()

    # Simulate Backup Overdue & Degraded DB
    results = dispatcher.evaluate_all(
        isolated_db,
        force=True,
        backup_age_hours_override=30.0,
        disk_free_gb_override=50.0,
        probe_override={
            "verdict": "DEGRADED",
            "issues": ["Integrity warning"],
        },
    )

    conditions = [r["condition_key"] for r in results if r.get("dispatched")]
    assert "BACKUP_OVERDUE" in conditions
    assert "DB_HEALTH_UNHEALTHY" in conditions


def test_evaluate_all_cooldown_suppression(isolated_db):
    dispatcher = AlertDispatcher()
    dispatcher.reset_cooldown()

    # First run: force=True fires
    res1 = dispatcher.evaluate_all(
        isolated_db,
        force=True,
        backup_age_hours_override=35.0,
    )
    overdue1 = next((r for r in res1 if r["condition_key"] == "BACKUP_OVERDUE"), None)
    assert overdue1 is not None and overdue1["dispatched"] is True

    # Second run immediately without force: should be suppressed
    res2 = dispatcher.evaluate_all(
        isolated_db,
        force=False,
        backup_age_hours_override=35.0,
    )
    overdue2 = next((r for r in res2 if r["condition_key"] == "BACKUP_OVERDUE"), None)
    assert overdue2 is not None and overdue2["dispatched"] is False
    assert overdue2["reason"] == "COOLDOWN_ACTIVE"


def test_alerts_api_endpoints(client: TestClient):
    # 1. Test test-trigger endpoint
    trigger_resp = client.post(
        "/api/v1/system/observability/alerts/test-trigger",
        params={"channel": "TOAST"},
    )
    assert trigger_resp.status_code == 200
    data = trigger_resp.json()
    assert data["status"] == "success"
    assert "dispatched_channels" in data

    # 2. Test history endpoint
    hist_resp = client.get("/api/v1/system/observability/alerts/history")
    assert hist_resp.status_code == 200
    hist_data = hist_resp.json()
    assert "total_toasts_sent" in hist_data
    assert "total_emails_sent" in hist_data
    assert "cooldown_active" in hist_data

    # 3. Test reset cooldown endpoint
    reset_resp = client.post("/api/v1/system/observability/alerts/reset-cooldown")
    assert reset_resp.status_code == 200
    assert reset_resp.json()["status"] == "success"

    # 4. Test evaluate endpoint
    eval_resp = client.post(
        "/api/v1/system/observability/alerts/evaluate",
        params={"force": True},
    )
    assert eval_resp.status_code == 200
    eval_data = eval_resp.json()
    assert "evaluated_at" in eval_data
    assert "results" in eval_data


# ── Single-language storage (Phase B): coded alert notifications ─────────────
def test_coded_alert_persists_code_and_english_text(isolated_db, tmp_path, monkeypatch):
    from modules.common.system_messages import msg
    from modules.notifications.model import SystemNotification
    import modules.system_observability.alert_dispatcher as ad

    monkeypatch.setattr(ad, "LOGS_DIR", tmp_path)
    monkeypatch.setattr(ad, "ALERTS_LOG_FILE", tmp_path / "alerts.log")
    for var in ("ALERT_SMTP_HOST", "SMTP_HOST"):
        monkeypatch.delenv(var, raising=False)

    payload = AlertPayload(
        condition_key="DISK_SPACE_WARNING", title=None, message=None, severity="HIGH",
        channels=["EMAIL"], target_tab="deep-health", msg=msg("ALERT_DISK_LOW", free_gb=4.2),
    )
    assert payload.title == "Low disk space warning"
    assert "(4.2 GB)" in payload.message
    assert payload.to_dict()["msg_code"] == "ALERT_DISK_LOW"

    AlertDispatcher().send_email(payload, db=isolated_db)
    notif = isolated_db.query(SystemNotification).one()
    assert notif.msg_code == "ALERT_DISK_LOW"
    assert notif.msg_params == {"free_gb": 4.2}
    assert notif.title == "[High] Low disk space warning"  # ALERT_SEVERITY label
    assert notif.message.endswith("(Action: check the deep-health tab)")


def test_uncoded_alert_uses_dispatch_wrapper(isolated_db, tmp_path, monkeypatch):
    from modules.notifications.model import SystemNotification
    import modules.system_observability.alert_dispatcher as ad

    monkeypatch.setattr(ad, "LOGS_DIR", tmp_path)
    monkeypatch.setattr(ad, "ALERTS_LOG_FILE", tmp_path / "alerts.log")
    for var in ("ALERT_SMTP_HOST", "SMTP_HOST"):
        monkeypatch.delenv(var, raising=False)

    payload = AlertPayload(
        condition_key="X", title="Custom", message="Body", severity="LOW", channels=["EMAIL"], target_tab="telemetry",
    )
    AlertDispatcher().send_email(payload, db=isolated_db)
    notif = isolated_db.query(SystemNotification).one()
    assert notif.msg_code == "ALERT_DISPATCHED"
    assert notif.title == "[LOW] Custom"
    assert notif.message == "Body (Action: check the telemetry tab)"


def test_evaluate_all_writes_no_arabic(isolated_db):
    from modules.notifications.model import SystemNotification

    dispatcher = AlertDispatcher()
    dispatcher.reset_cooldown()
    results = dispatcher.evaluate_all(
        isolated_db, force=True, disk_free_gb_override=1.0, backup_age_hours_override=30.0,
        offsite_age_hours_override=30.0, probe_override={"verdict": "DEGRADED", "issues": ["wal"]},
    )
    assert results
    for rec in dispatcher.toast_history + dispatcher.email_history:
        assert not any("؀" <= ch <= "ۿ" for ch in rec["title"] + rec["message"])
    codes = {n.msg_code for n in isolated_db.query(SystemNotification).all()}
    assert {"ALERT_BACKUP_OVERDUE", "ALERT_OFFSITE_BACKUP_OVERDUE", "ALERT_DB_HEALTH_DEGRADED"} <= codes
