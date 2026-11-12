"""
Security hardening (Trello UOroUoqq): short-lived JWT + revocation window, CORS allow-list, upload defense.
"""
import asyncio
import io
import time
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException, UploadFile

import main
import settings
from modules.auth import security
from modules.common import upload_guard
from modules.common.audit_stamp import SYSTEM_ACTOR, actor_name, set_created_info, set_updated_info


# ─── Short-lived JWT ─────────────────────────────────────────────────────────

def test_access_token_default_lifetime_is_short():
    assert settings.JWT_ACCESS_TOKEN_EXPIRE_SECONDS <= 60 * 60


def test_token_expires_after_its_lifetime():
    token = security.create_access_token({"sub": "1"}, expires_in_seconds=60)
    assert security.decode_access_token(token, check_revocation=False) is not None
    expired = security.create_access_token({"sub": "1"}, expires_in_seconds=-1)
    assert security.decode_access_token(expired, check_revocation=False) is None


def test_expired_token_is_refreshable_only_inside_grace_period():
    expired = security.create_access_token({"sub": "1"}, expires_in_seconds=-10)
    assert security.decode_access_token(expired, check_revocation=False, ignore_expiration=True) is not None
    too_old = security.create_access_token({"sub": "1"}, expires_in_seconds=-(settings.JWT_REFRESH_GRACE_PERIOD_SECONDS + 60))
    assert security.decode_access_token(too_old, check_revocation=False, ignore_expiration=True) is None


def test_revocation_outlives_the_refresh_grace_period():
    exp = int(time.time()) + 3600
    expiry = security.revocation_expiry(exp)
    expected = datetime.fromtimestamp(exp, tz=timezone.utc) + timedelta(seconds=settings.JWT_REFRESH_GRACE_PERIOD_SECONDS)
    assert expiry == expected


def test_revocation_expiry_without_exp_still_covers_grace():
    expiry = security.revocation_expiry(None)
    assert expiry > datetime.now(timezone.utc) + timedelta(seconds=settings.JWT_REFRESH_GRACE_PERIOD_SECONDS)


# ─── CORS allow-list ─────────────────────────────────────────────────────────

def test_parse_cors_allowed_origins_drops_wildcards_and_garbage():
    parsed = settings.parse_cors_allowed_origins(" https://erp.example.com/ ,*,null,ftp://x, http://a.b ,https://erp.example.com")
    assert parsed == ("https://erp.example.com", "http://a.b")


@pytest.mark.parametrize("origin", ["http://localhost:5000", "http://127.0.0.1", "http://192.168.1.20:8080"])
def test_local_origins_allowed_by_default(origin):
    assert main.is_cors_origin_allowed(origin) is True


@pytest.mark.parametrize("origin", ["https://evil.example.com", "null", "*", ""])
def test_foreign_origins_rejected(origin):
    assert main.is_cors_origin_allowed(origin) is False


def test_configured_origin_allowed_and_private_network_can_be_disabled(monkeypatch):
    monkeypatch.setattr(settings, "CORS_ALLOWED_ORIGINS", ("https://erp.example.com",))
    monkeypatch.setattr(settings, "CORS_ALLOW_PRIVATE_NETWORK_ORIGINS", False)
    assert main.is_cors_origin_allowed("https://erp.example.com") is True
    assert main.is_cors_origin_allowed("https://erp.example.com/") is True
    assert main.is_cors_origin_allowed("http://localhost:5000") is False


# ─── Upload defense ──────────────────────────────────────────────────────────

def _upload(name: str, content: bytes) -> UploadFile:
    return UploadFile(file=io.BytesIO(content), filename=name)


def _read(name, content, allowed, max_bytes=upload_guard.DEFAULT_MAX_UPLOAD_BYTES):
    return asyncio.run(upload_guard.read_upload_bytes(_upload(name, content), allowed, max_bytes))


def test_valid_xlsx_signature_accepted():
    data = b"PK\x03\x04" + b"0" * 100
    assert _read("Suppliers.XLSX", data, upload_guard.EXCEL_EXTENSIONS) == data


@pytest.mark.parametrize("name", ["payload.exe", "noext", "sheet.xlsx.exe", "script.py"])
def test_disallowed_extension_rejected(name):
    with pytest.raises(HTTPException) as exc:
        _read(name, b"PK\x03\x04data", upload_guard.EXCEL_EXTENSIONS)
    assert exc.value.status_code == 415


def test_renamed_executable_rejected_by_signature():
    with pytest.raises(HTTPException) as exc:
        _read("invoice.xlsx", b"MZ\x90\x00 this is a PE file", upload_guard.EXCEL_EXTENSIONS)
    assert exc.value.status_code == 415


def test_binary_content_in_csv_rejected():
    with pytest.raises(HTTPException) as exc:
        _read("tariffs.csv", b"hs_code,rate\x00\x01", upload_guard.TEXT_EXTENSIONS)
    assert exc.value.status_code == 415


def test_oversized_upload_rejected():
    with pytest.raises(HTTPException) as exc:
        _read("big.csv", b"a" * 2048, upload_guard.TEXT_EXTENSIONS, max_bytes=1024)
    assert exc.value.status_code == 413


def test_empty_upload_rejected():
    with pytest.raises(HTTPException) as exc:
        _read("empty.csv", b"", upload_guard.TEXT_EXTENSIONS)
    assert exc.value.status_code == 400


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("../../etc/passwd", "passwd"),
        ("C:\\Windows\\system32\\evil.xlsx", "evil.xlsx"),
        ("in\x00voice<>.pdf", "invoice_.pdf"),
        ("", "upload"),
        ("....", "upload"),
        ("فاتورة 1.pdf", "فاتورة 1.pdf"),
    ],
)
def test_safe_filename(raw, expected):
    assert upload_guard.safe_filename(raw) == expected


def test_safe_filename_truncates_keeping_extension():
    name = upload_guard.safe_filename("a" * 400 + ".xlsx")
    assert len(name) == upload_guard.MAX_FILENAME_LENGTH and name.endswith(".xlsx")


def test_master_data_excel_import_rejects_non_excel(monkeypatch):
    from fastapi.testclient import TestClient

    client = TestClient(main.app, raise_server_exceptions=False)
    response = client.post(
        "/api/v1/suppliers/import-excel",
        files={"file": ("evil.exe", b"MZ\x90\x00", "application/octet-stream")},
    )
    assert response.status_code == 415


# ─── Audit stamping helpers ──────────────────────────────────────────────────

class _Entity:
    created_by = None
    updated_by = None


class _User:
    username = "kamal"


def test_audit_stamp_helpers():
    entity = _Entity()
    set_created_info(entity, "kamal")
    assert (entity.created_by, entity.updated_by) == ("kamal", "kamal")
    set_updated_info(entity, "  ")
    assert entity.updated_by == SYSTEM_ACTOR and entity.created_by == "kamal"
    assert actor_name(_User()) == "kamal"
    assert actor_name(None) == SYSTEM_ACTOR
