"""
Unit Tests for System Version, Updates Distribution, and UAT Staging API Endpoints
"""
import sqlite3
import pytest
from fastapi.testclient import TestClient
from main import app
from pathlib import Path
from scripts.publish_release import check_version_status, load_version_json
from scripts.prepare_uat_environment import status_uat, UAT_DB

client = TestClient(app)


def test_get_system_version_info():
    """Verifies that GET /api/v1/production-sync/version-info returns valid system and database metadata."""
    response = client.get("/api/v1/production-sync/version-info")
    assert response.status_code == 200
    data = response.json()
    assert "version" in data
    assert "build_number" in data
    assert "tables_count" in data
    assert "total_backups_count" in data
    assert data["system_name"] == "Sorour Logistics ERP"


def test_check_for_system_updates():
    """Verifies that GET /api/v1/production-sync/check-updates returns a structured status."""
    response = client.get("/api/v1/production-sync/check-updates")
    assert response.status_code == 200
    data = response.json()
    assert "has_update" in data
    assert "current_version" in data
    assert "latest_version" in data
    assert "check_status" in data
    assert isinstance(data["release_notes"], list)


def test_system_version_check_endpoint():
    """Verifies that GET /api/v1/system/version-check returns release info and installer metadata."""
    response = client.get("/api/v1/system/version-check")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "OK"
    assert data["system_name"] == "Sorour Logistics ERP"
    assert any(data["current_version"].startswith(prefix) for prefix in ("1.0.", "2.0."))
    assert "installer_url" in data
    assert "installer_filename" in data
    assert "installer_size_mb" in data
    assert isinstance(data["release_notes"], list)
    assert len(data["release_notes"]) > 0


def test_system_version_check_with_matching_client():
    """Verifies that an up-to-date client receives has_update=False and force_update=False."""
    v_data = load_version_json()
    latest_ver = v_data["version"]
    response = client.get(f"/api/v1/system/version?client_version={latest_ver}")
    assert response.status_code == 200
    data = response.json()
    assert data["has_update"] is False
    assert data["is_compatible"] is True
    assert data["force_update"] is False
    assert data["check_status"] == "up_to_date"


def test_system_version_check_with_older_compatible_client():
    """Verifies that an older but compatible client receives has_update=True and force_update=False."""
    response = client.get("/api/v1/system/version?client_version=1.0.185")
    assert response.status_code == 200
    data = response.json()
    assert data["has_update"] is True
    assert data["is_compatible"] is True
    assert data["force_update"] is False
    assert data["check_status"] == "update_available"


def test_system_version_check_with_incompatible_client():
    """Verifies that a client below min_compatible_version receives force_update=True and is_compatible=False."""
    response = client.get("/api/v1/system/version?client_version=1.0.150")
    assert response.status_code == 200
    data = response.json()
    assert data["has_update"] is True
    assert data["is_compatible"] is False
    assert data["force_update"] is True


def test_system_version_check_via_x_client_version_header():
    """Verifies that X-Client-Version header is respected if query param is absent."""
    response = client.get("/api/v1/system/version", headers={"X-Client-Version": "1.0.180"})
    assert response.status_code == 200
    data = response.json()
    assert data["client_version"] == "1.0.180"
    assert data["has_update"] is True


def test_download_system_installer_endpoint_is_removed():
    """The unauthenticated installer download was removed (updates come from app_update)."""
    response = client.get("/api/v1/system/download-installer", follow_redirects=False)
    assert response.status_code == 404
    assert "local_download_url" not in client.get("/api/v1/system/version").json()


def test_publish_release_script_zero_drift():
    """Verifies that all project configuration files have zero version drift."""
    is_synchronized = check_version_status()
    assert is_synchronized is True


@pytest.mark.skipif(
    not UAT_DB.exists(),
    reason=f"UAT staging database not prepared on this machine ({UAT_DB}); run scripts/prepare_uat_environment.py",
)
def test_uat_environment_staging_integrity():
    """Verifies that the UAT staging database exists, has 0 operational rows, and passes integrity checks."""
    assert UAT_DB.exists()
    assert status_uat() is True

    conn = sqlite3.connect(UAT_DB)
    cursor = conn.cursor()
    integrity = cursor.execute("PRAGMA integrity_check;").fetchall()
    fk_check = cursor.execute("PRAGMA foreign_key_check;").fetchall()
    tariff_count = cursor.execute("SELECT COUNT(*) FROM customs_tariffs;").fetchone()[0]
    import_files_count = cursor.execute("SELECT COUNT(*) FROM import_files;").fetchone()[0]
    conn.close()

    assert integrity == [('ok',)]
    assert len(fk_check) == 0, f"Foreign key check violations: {fk_check}"
    assert tariff_count > 0, "Customs tariffs must be preserved in UAT"
    assert import_files_count == 0, "Operational import files must be 0 in clean UAT baseline"
