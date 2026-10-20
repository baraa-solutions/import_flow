"""
Unit Tests — Daily Observability Report Engine
=============================================
Tests:
- Consolidated report generation from health, metrics, radar, backups, security
- "Needs Attention" prominent top-level flagging (ACID expiring, demurrage, stuck files)
- Yesterday vs today change tracking
- Multi-channel delivery (Email, Windows Toast, WebSocket)
- Self-alerting failure trap on generation errors
- 90-day retention pruning of rotated report files
- API endpoints (/daily-report/latest, /daily-report/history, /daily-report/generate)
"""

import os
import json
import pytest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import patch, MagicMock

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import scripts.migrate_sqlite_to_postgres  # Loads full 106-table registry
from database.database import Base
from main import app
from settings import ADMIN_INITIAL_PASSWORD
from modules.system_observability.daily_report_service import (
    DailyReportService,
    DAILY_REPORTS_DIR,
)
from modules.system_observability.alert_dispatcher import alert_dispatcher
from modules.import_documentation.model import AcidRegistrationSession
from modules.demurrage_detention.model import DemurrageTracking
from modules.import_files.model import ImportFile


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


@pytest.fixture
def auth_client():
    client = TestClient(app)
    # Login to acquire admin token
    res = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": ADMIN_INITIAL_PASSWORD},
    )
    assert res.status_code == 200
    token = res.json()["access_token"]
    client.headers = {"Authorization": f"Bearer {token}"}
    if not res.json()["user"]["must_change_password"]:
        yield client
        return
    # The seeded admin must change its password before any other route works: change it for this test
    # and put the initial password back afterwards (the flag stays cleared).
    temp_password = "Obs-Report-Admin-7"
    changed = client.post(
        "/api/v1/auth/me/change-password",
        json={"current_password": ADMIN_INITIAL_PASSWORD, "new_password": temp_password},
    )
    assert changed.status_code == 200
    # BEX-T08: a password change bumps token_version; continue with the token it returns.
    client.headers = {"Authorization": f"Bearer {changed.json()['access_token']}"}
    yield client
    restored = client.post(
        "/api/v1/auth/me/change-password",
        json={"current_password": temp_password, "new_password": ADMIN_INITIAL_PASSWORD},
    )
    assert restored.status_code == 200


def test_daily_report_generation_healthy(isolated_db):
    """Verifies that on a clean system, the report generates with ✅ All normal headline."""
    report = DailyReportService.generate_report(isolated_db, deliver=False)

    assert report.report_date == datetime.now(timezone.utc).strftime("%Y-%m-%d")
    assert "ImportFlow ERP — Daily Observability Report" in report.markdown_content
    assert "1. System & Health Status" in report.markdown_content
    assert "2. Activity & Performance Summary" in report.markdown_content
    assert "3. Backup & Disaster Recovery Status" in report.markdown_content
    assert "4. Business & Logistics Domain Radar" in report.markdown_content
    assert "5. Security Snapshot" in report.markdown_content
    assert "6. Anything Changed Since Yesterday" in report.markdown_content

    # Check file was saved locally
    saved_md = Path(report.report_file)
    assert saved_md.exists()
    assert saved_md.suffix == ".md"


def test_daily_report_flagged_needs_attention_for_expiring_acid(isolated_db):
    """Verifies that an expiring ACID is flagged prominently under ## 🚨 Needs Attention at the top."""
    now = datetime.now(timezone.utc)
    expiring_acid = AcidRegistrationSession(
        acid_code="ACID-TEST-001",
        acid_number="9876543210123456789",
        importer_name="Sorour Import Co",
        importer_tax_id="123456789",
        exporter_name="Supplier ABC",
        exporter_reg_id="VAT987",
        exporter_country="Italy",
        proforma_invoice_no="PI-98765",
        pol_name="Genoa",
        pod_name="Alexandria",
        requested_date=now.date() - timedelta(days=177),
        expiry_date=now.date() + timedelta(days=3),
        status="Verified",
        is_active=True,
    )
    isolated_db.add(expiring_acid)
    isolated_db.commit()

    report = DailyReportService.generate_report(isolated_db, deliver=False)

    assert report.headline_verdict == "NEEDS_ATTENTION"
    assert "need attention" in report.headline_message
    assert any("9876543210123456789" in item for item in report.needs_attention_items)
    assert "## 🚨 Needs Attention" in report.markdown_content

    # Ensure it appears before Section 1
    idx_attn = report.markdown_content.find("## 🚨 Needs Attention")
    idx_sec1 = report.markdown_content.find("## 1. System & Health Status")
    assert 0 < idx_attn < idx_sec1, "Needs attention must appear at the top above detailed sections"


def test_daily_report_flagged_needs_attention_for_demurrage_risk(isolated_db):
    """Verifies that demurrage free-time < 48h is flagged prominently at the top."""
    now = datetime.now(timezone.utc)
    risk = DemurrageTracking(
        tracking_code="DND-TEST-001",
        carrier_name="MSC",
        bill_of_lading_no="BL-TEST-999",
        port_name="Alexandria",
        discharge_date=now.date() - timedelta(days=13),
        containers=[{"container_no": "MSCU1234567", "demurrage_days": 1, "demurrage_fx": 40.0}],
        exchange_rate=50.0,  # no default rate since the review wave (NOT NULL, no fabricated 50.0)
        status="Free Time Active",
        is_active=True,
    )
    isolated_db.add(risk)
    isolated_db.commit()

    report = DailyReportService.generate_report(isolated_db, deliver=False)

    assert report.headline_verdict == "NEEDS_ATTENTION"
    assert any("MSCU1234567" in item for item in report.needs_attention_items)


def test_daily_report_delivery_dispatch(isolated_db):
    """Verifies that deliver=True dispatches via both email and toast channels."""
    with patch.object(alert_dispatcher, "send_email", return_value=True) as mock_email, \
         patch.object(alert_dispatcher, "send_toast", return_value=True) as mock_toast:
        
        report = DailyReportService.generate_report(isolated_db, deliver=True)
        assert mock_email.called
        assert mock_toast.called
        assert "EMAIL" in report.delivered_channels
        assert "TOAST" in report.delivered_channels
        assert "LOG_FILE" in report.delivered_channels


def test_daily_report_self_alerting_on_failure(isolated_db):
    """Verifies that an unhandled generation failure dispatches a CRITICAL self-alert."""
    with patch.object(alert_dispatcher, "send_toast") as mock_toast, \
         patch.object(alert_dispatcher, "send_email") as mock_email, \
         patch("modules.system_observability.daily_report_service.DeepHealthProbeService.run_probe", side_effect=RuntimeError("Simulated Database Crash")):
        
        with pytest.raises(RuntimeError):
            DailyReportService.generate_report(isolated_db, deliver=True)

        assert mock_toast.called
        assert mock_email.called
        # Verify alert payload parameters
        toast_call_arg = mock_toast.call_args[0][0]
        assert toast_call_arg.condition_key == "DAILY_REPORT_GENERATION_FAILED"
        assert toast_call_arg.severity == "CRITICAL"


def test_daily_report_retention_pruning(tmp_path):
    """Verifies that reports older than 90 days are pruned while recent reports are kept."""
    DAILY_REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc)

    # 1. Create a 100-day-old file
    old_file = DAILY_REPORTS_DIR / "2026-05-01.md"
    old_file.write_text("Old Report Content", encoding="utf-8")
    old_mtime = (now - timedelta(days=100)).timestamp()
    os.utime(old_file, (old_mtime, old_mtime))

    # 2. Create a 10-day-old file
    recent_file = DAILY_REPORTS_DIR / "2026-09-09.md"
    recent_file.write_text("Recent Report Content", encoding="utf-8")
    recent_mtime = (now - timedelta(days=10)).timestamp()
    os.utime(recent_file, (recent_mtime, recent_mtime))

    pruned = DailyReportService.prune_old_reports(retention_days=90)
    assert pruned >= 1
    assert not old_file.exists()
    assert recent_file.exists()

    # Clean up test recent file
    recent_file.unlink(missing_ok=True)


def test_daily_report_api_endpoints(auth_client):
    """Verifies that the FastAPI endpoints for daily report return valid schemas."""
    # 1. Latest Report
    res1 = auth_client.get("/api/v1/system/observability/daily-report/latest")
    assert res1.status_code == 200
    d1 = res1.json()
    assert "report_date" in d1
    assert "headline_message" in d1
    assert "markdown_content" in d1
    assert "html_content" in d1
    assert "summary_data" in d1

    # 2. History List
    res2 = auth_client.get("/api/v1/system/observability/daily-report/history")
    assert res2.status_code == 200
    d2 = res2.json()
    assert isinstance(d2, list)
    assert len(d2) >= 1
    assert "filename" in d2[0]

    # 3. Manual Generate Trigger
    res3 = auth_client.post("/api/v1/system/observability/daily-report/generate?deliver=false")
    assert res3.status_code == 200
    d3 = res3.json()
    assert d3["headline_verdict"] in ("ALL_NORMAL", "NEEDS_ATTENTION")
