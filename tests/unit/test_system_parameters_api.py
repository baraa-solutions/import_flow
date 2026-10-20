"""
Unit tests for System Parameters Settings API and Version Check Hygiene (BEX-T17).

Verifies:
1. GET /api/v1/system-parameters requires 'reports.view' permission; users without permission get 403, authorized users get 200 with list of parameters.
2. PUT /api/v1/system-parameters/{key} requires Admin role; non-admins get 403.
3. PUT valid value by admin:
   - Updates parameter value and updated_by in DB.
   - Writes AuditLog with actor, old_data, new_data, justification.
   - Subsequent business readers (e.g. load_insurance_rates) reflect the updated value.
4. Typed validation per key:
   - Unknown key -> 404 SYSPARAM_UNKNOWN.
   - Invalid rate (> 1 or < 0 for INSURANCE_RATE_*) -> 422 SYSPARAM_INVALID_VALUE.
   - Non-numeric string -> 422 SYSPARAM_INVALID_VALUE.
   - Short justification (< 5 chars) -> 422.
5. Tiers JSON validation (*_TIERS keys):
   - Malformed JSON -> 422 SYSPARAM_INVALID_VALUE.
   - Non-contiguous days -> 422 SYSPARAM_INVALID_VALUE.
   - Start day != 1 -> 422 SYSPARAM_INVALID_VALUE.
   - Negative rate -> 422 SYSPARAM_INVALID_VALUE.
   - Valid tiers update -> 200 OK.
6. Version-check hygiene (BEX-F39):
   - When version.json is missing or unreadable -> returns check_status='unknown' and null metadata fields without fabricated fallbacks.
   - Public /health does not leak database size_kb or tables_count.
"""

import json
from pathlib import Path
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.audit_logs.model import AuditLog
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.cargo_insurance.service import load_insurance_rates
from modules.common.system_parameters import seed_default_parameters
from modules.system_parameters.router import router as system_parameters_router
from modules.users.model import Role, User
import main


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    yield factory
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)
    seed_default_parameters(session)
    yield session
    session.close()


def _make_user(db, username: str, role_code: str, permissions: list = None) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).first()
    if not role:
        role = Role(role_code=role_code, name_en=role_code, name_ar=role_code, is_system_role=False)
        db.add(role)
        db.commit()
        db.refresh(role)

    user = User(
        username=username,
        email=f"{username}@test.com",
        full_name=username,
        hashed_password=hash_password("Password123"),
        role=role.role_code,
        role_id=role.role_id,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin_user(db):
    return _make_user(db, "sys_admin", "ADMIN")


@pytest.fixture
def operator_user(db):
    return _make_user(db, "sys_operator", "LOGISTICS_OPERATOR")


@pytest.fixture
def restricted_user(db):
    return _make_user(db, "sys_restricted", "EXTERNAL_EXPEDITOR")


@pytest.fixture
def client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    app.include_router(system_parameters_router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


# ─── 1. Access Control Tests ──────────────────────────────────────────────────

def test_get_parameters_access_control(client, admin_user, operator_user, restricted_user):
    # Restricted user lacks reports.view -> 403
    res_restricted = client.get("/api/v1/system-parameters", headers=_bearer(restricted_user))
    assert res_restricted.status_code == 403

    # Operator has reports.view -> 200
    res_op = client.get("/api/v1/system-parameters", headers=_bearer(operator_user))
    assert res_op.status_code == 200
    params = res_op.json()
    assert isinstance(params, list)
    keys = {p["param_key"] for p in params}
    assert "INSURANCE_RATE_ICC_A" in keys
    assert "DD_DEFAULT_DEMURRAGE_TIERS" in keys

    # Admin has all permissions -> 200
    res_admin = client.get("/api/v1/system-parameters", headers=_bearer(admin_user))
    assert res_admin.status_code == 200


def test_put_parameter_requires_admin(client, operator_user):
    # Operator cannot edit system parameters -> 403
    payload = {"param_value": "0.003", "justification": "Attempt by operator"}
    res = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json=payload,
        headers=_bearer(operator_user),
    )
    assert res.status_code == 403


# ─── 2. Update and Audit Trail Tests ──────────────────────────────────────────

def test_admin_updates_insurance_rate_and_verifies_audit_and_reader(client, db, admin_user):
    headers = _bearer(admin_user)
    payload = {
        "param_value": "0.003",
        "justification": "Annual reinsurance rate revision by underwriting",
    }
    res = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json=payload,
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["param_key"] == "INSURANCE_RATE_ICC_A"
    assert data["param_value"] == "0.003"
    assert data["updated_by"] == admin_user.username

    # Reader reflection: load_insurance_rates must return 0.003
    rates = load_insurance_rates(db)
    assert rates.clause_rates["ICC_A"] == 0.003

    # AuditLog verification
    log = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "SystemParameter", AuditLog.entity_code == "INSURANCE_RATE_ICC_A")
        .order_by(AuditLog.log_id.desc())
        .first()
    )
    assert log is not None
    assert log.action == "UPDATE"
    assert log.performed_by == admin_user.username
    assert log.changes_summary == "Annual reinsurance rate revision by underwriting"
    assert "0.0025" in str(log.old_values)
    assert "0.003" in str(log.new_values)


# ─── 3. Validation Tests ──────────────────────────────────────────────────────

def test_unknown_parameter_key_returns_404(client, admin_user):
    headers = _bearer(admin_user)
    payload = {"param_value": "100", "justification": "Non-existent key test"}
    res = client.put(
        "/api/v1/system-parameters/NON_EXISTENT_PARAM_KEY",
        json=payload,
        headers=headers,
    )
    assert res.status_code == 404
    detail = res.json()["detail"]
    assert detail["code"] == "SYSPARAM_UNKNOWN"


def test_invalid_rates_rejected_with_422(client, admin_user):
    headers = _bearer(admin_user)

    # 1. Rate > 1 (e.g. 1.5) -> 422
    res_high = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json={"param_value": "1.5", "justification": "Invalid excessive rate"},
        headers=headers,
    )
    assert res_high.status_code == 422
    assert res_high.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 2. Rate < 0 -> 422
    res_neg = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json={"param_value": "-0.05", "justification": "Invalid negative rate"},
        headers=headers,
    )
    assert res_neg.status_code == 422
    assert res_neg.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 3. Non-numeric value -> 422
    res_str = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json={"param_value": "not-a-number", "justification": "Invalid text string"},
        headers=headers,
    )
    assert res_str.status_code == 422
    assert res_str.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 4. Short justification (< 5 chars) -> 422 (Pydantic schema validation)
    res_short = client.put(
        "/api/v1/system-parameters/INSURANCE_RATE_ICC_A",
        json={"param_value": "0.002", "justification": "abc"},
        headers=headers,
    )
    assert res_short.status_code == 422


# ─── 4. Demurrage / Detention Tiers JSON Validation ──────────────────────────

def test_tiers_json_validation(client, admin_user):
    headers = _bearer(admin_user)
    key = "DD_DEFAULT_DEMURRAGE_TIERS"

    # 1. Invalid JSON string
    res_bad_json = client.put(
        f"/api/v1/system-parameters/{key}",
        json={"param_value": "not-a-json", "justification": "Malformed tier JSON"},
        headers=headers,
    )
    assert res_bad_json.status_code == 422
    assert res_bad_json.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 2. Non-contiguous days (starts at 2 instead of 1)
    bad_start = json.dumps([{"from_day": 2, "to_day": 7, "rate_per_day": 40.0}])
    res_bad_start = client.put(
        f"/api/v1/system-parameters/{key}",
        json={"param_value": bad_start, "justification": "Tier must start at day 1"},
        headers=headers,
    )
    assert res_bad_start.status_code == 422
    assert res_bad_start.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 3. Gap in days: day 1-7 then day 10-14
    gap_days = json.dumps([
        {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
        {"from_day": 10, "to_day": 14, "rate_per_day": 70.0},
    ])
    res_gap = client.put(
        f"/api/v1/system-parameters/{key}",
        json={"param_value": gap_days, "justification": "Gap between day 7 and 10"},
        headers=headers,
    )
    assert res_gap.status_code == 422
    assert res_gap.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 4. Negative rate per day
    neg_rate = json.dumps([{"from_day": 1, "to_day": None, "rate_per_day": -10.0}])
    res_neg_rate = client.put(
        f"/api/v1/system-parameters/{key}",
        json={"param_value": neg_rate, "justification": "Negative rate in tier"},
        headers=headers,
    )
    assert res_neg_rate.status_code == 422
    assert res_neg_rate.json()["detail"]["code"] == "SYSPARAM_INVALID_VALUE"

    # 5. Valid custom tiers
    valid_tiers = json.dumps([
        {"from_day": 1, "to_day": 5, "rate_per_day": 30.0},
        {"from_day": 6, "to_day": 12, "rate_per_day": 60.0},
        {"from_day": 13, "to_day": None, "rate_per_day": 100.0},
    ])
    res_valid = client.put(
        f"/api/v1/system-parameters/{key}",
        json={"param_value": valid_tiers, "justification": "Contract renegotiation tariff update"},
        headers=headers,
    )
    assert res_valid.status_code == 200
    assert json.loads(res_valid.json()["param_value"]) == json.loads(valid_tiers)


# ─── 5. Version-Check & Health Hygiene (BEX-F39) ─────────────────────────────

def test_version_check_returns_unknown_and_null_when_version_json_missing(monkeypatch):
    test_app_client = TestClient(main.app, raise_server_exceptions=False)

    # Point version_file_path to a non-existent file
    monkeypatch.setattr(main, "version_file_path", lambda: Path("/non/existent/path/version.json"))

    res = test_app_client.get("/api/v1/system/version-check")
    assert res.status_code == 200
    data = res.json()
    assert data["check_status"] == "unknown"
    assert data["current_version"] is None
    assert data["installer_url"] is None
    assert data["installer_filename"] is None
    assert data["installer_size_mb"] is None
    assert data["release_notes"] == []


def test_public_health_does_not_expose_db_size_and_table_count():
    test_app_client = TestClient(main.app, raise_server_exceptions=False)
    res = test_app_client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert "status" in data
    assert "version" in data
    db_info = data.get("database", {})
    assert "connected" in db_info
    # BEX-F39 hygiene: size_kb and tables_count are dropped from public /health
    assert "size_kb" not in db_info
    assert "tables_count" not in db_info
