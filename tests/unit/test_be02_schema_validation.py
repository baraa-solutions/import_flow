"""
Unit tests for BE02-T10: Money and currency input validation on request schemas
(modules/financial_approval/schemas.py).
"""
from datetime import date, timedelta
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError

from database.database import get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.financial_approval.schemas import (
    ImportBudgetCreate,
    PaymentRequestCreate,
    PaymentRequestResponse,
    SmartSwiftReconcileRequest,
    SwiftReconciliationRequest,
)
from modules.users.model import Role, User
from test_phase02_support import make_session, seed_file, seed_rate

BASE = "/api/v1/financial-approval"


@pytest.fixture
def db():
    session = make_session()
    seed_rate(session, "USD", 50.0)
    seed_rate(session, "EUR", 55.0)
    invalidate_permission_cache()
    try:
        yield session
    finally:
        invalidate_permission_cache()
        session.close()


@pytest.fixture
def api(db):
    seed_rbac(db)
    from main import app

    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _user(db, username: str, role_code: str) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
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


def _bearer(user: User) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


# ==============================================================================
# 1. PaymentRequestCreate
# ==============================================================================

def test_payment_request_create_requires_currency_code():
    valid_data = {
        "title": "Advance for machines",
        "supplier_name": "Supplier X",
        "requested_amount": 1000.0,
        "exchange_rate": 50.0,
        "due_date": date(2026, 9, 1),
    }

    # Missing currency_code -> ValidationError
    with pytest.raises(ValidationError) as exc:
        PaymentRequestCreate(**valid_data)
    assert any("currency_code" in str(err["loc"]) for err in exc.value.errors())

    # currency_code too short (< 3 chars) -> ValidationError
    with pytest.raises(ValidationError) as exc:
        PaymentRequestCreate(**valid_data, currency_code="US")
    assert any("currency_code" in str(err["loc"]) for err in exc.value.errors())

    # currency_code too long (> 10 chars) -> ValidationError
    with pytest.raises(ValidationError) as exc:
        PaymentRequestCreate(**valid_data, currency_code="TOOLONGCURRENCY")
    assert any("currency_code" in str(err["loc"]) for err in exc.value.errors())

    # Valid currency_code -> passes
    p = PaymentRequestCreate(**valid_data, currency_code="USD")
    assert p.currency_code == "USD"


# ==============================================================================
# 2. SwiftReconciliationRequest
# ==============================================================================

def test_swift_reconciliation_requires_currency():
    valid_data = {
        "swift_reference_no": "MT103-9999",
        "swift_receipt_date": date(2026, 8, 14),
        "swift_transferred_amount": 5000.0,
    }

    # Missing currency -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SwiftReconciliationRequest(**valid_data)
    assert any("swift_transferred_currency" in str(err["loc"]) for err in exc.value.errors())

    # Too short -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SwiftReconciliationRequest(**valid_data, swift_transferred_currency="EU")
    assert any("swift_transferred_currency" in str(err["loc"]) for err in exc.value.errors())

    # Valid -> passes
    req = SwiftReconciliationRequest(**valid_data, swift_transferred_currency="EUR")
    assert req.swift_transferred_currency == "EUR"


# ==============================================================================
# 3. SmartSwiftReconcileRequest
# ==============================================================================

def test_smart_swift_reconcile_validation():
    base_data = {
        "payment_id": 1,
        "swift_reference_no": "SWIFT-REF-1234",
        "swift_receipt_date": date(2026, 8, 14),
        "swift_transferred_amount": 10000.0,
        "swift_transferred_currency": "USD",
    }

    # Missing currency -> ValidationError
    data_no_curr = {k: v for k, v in base_data.items() if k != "swift_transferred_currency"}
    with pytest.raises(ValidationError) as exc:
        SmartSwiftReconcileRequest(**data_no_curr)
    assert any("swift_transferred_currency" in str(err["loc"]) for err in exc.value.errors())

    # swift_transferred_amount = 0.0 -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SmartSwiftReconcileRequest(**{**base_data, "swift_transferred_amount": 0.0})
    assert any("swift_transferred_amount" in str(err["loc"]) for err in exc.value.errors())

    # swift_transferred_amount < 0.0 -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SmartSwiftReconcileRequest(**{**base_data, "swift_transferred_amount": -50.0})
    assert any("swift_transferred_amount" in str(err["loc"]) for err in exc.value.errors())

    # swift_reference_no too short (< 2 chars) -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SmartSwiftReconcileRequest(**{**base_data, "swift_reference_no": "A"})
    assert any("swift_reference_no" in str(err["loc"]) for err in exc.value.errors())

    # swift_reference_no too long (> 100 chars) -> ValidationError
    with pytest.raises(ValidationError) as exc:
        SmartSwiftReconcileRequest(**{**base_data, "swift_reference_no": "X" * 101})
    assert any("swift_reference_no" in str(err["loc"]) for err in exc.value.errors())

    # Valid -> passes
    req = SmartSwiftReconcileRequest(**base_data)
    assert req.swift_transferred_amount == 10000.0
    assert req.swift_reference_no == "SWIFT-REF-1234"


# ==============================================================================
# 4. ImportBudgetCreate
# ==============================================================================

def test_import_budget_create_currencies_required_when_foreign_amount_positive():
    base_data = {
        "title": "Machinery Import Budget",
        "exchange_rate": 50.0,
    }

    # Foreign amount = 0 -> currencies optional, default None
    b_zero = ImportBudgetCreate(**base_data, invoice_amount_foreign=0.0, freight_cost_foreign=0.0)
    assert b_zero.invoice_currency is None
    assert b_zero.freight_currency is None

    # invoice_amount_foreign > 0 and no invoice_currency -> ValidationError
    with pytest.raises(ValidationError) as exc:
        ImportBudgetCreate(**base_data, invoice_amount_foreign=1000.0)
    assert any("عملة الفاتورة" in str(err.get("msg", "")) for err in exc.value.errors())

    # invoice_amount_foreign > 0 and whitespace invoice_currency -> ValidationError
    with pytest.raises(ValidationError) as exc:
        ImportBudgetCreate(**base_data, invoice_amount_foreign=1000.0, invoice_currency="   ")
    assert any("عملة الفاتورة" in str(err.get("msg", "")) for err in exc.value.errors())

    # freight_cost_foreign > 0 and no freight_currency -> ValidationError
    with pytest.raises(ValidationError) as exc:
        ImportBudgetCreate(**base_data, freight_cost_foreign=500.0)
    assert any("عملة النولون" in str(err.get("msg", "")) for err in exc.value.errors())

    # freight_cost_foreign > 0 and empty freight_currency -> ValidationError
    with pytest.raises(ValidationError) as exc:
        ImportBudgetCreate(**base_data, freight_cost_foreign=500.0, freight_currency="   ")
    assert any("عملة النولون" in str(err.get("msg", "")) for err in exc.value.errors())

    # Currency too short (< 3 chars) -> ValidationError
    with pytest.raises(ValidationError) as exc:
        ImportBudgetCreate(**base_data, invoice_amount_foreign=1000.0, invoice_currency="US")
    assert any("invoice_currency" in str(err["loc"]) for err in exc.value.errors())

    # Valid foreign amounts and currencies -> passes
    b_valid = ImportBudgetCreate(
        **base_data,
        invoice_amount_foreign=1000.0,
        invoice_currency="USD",
        freight_cost_foreign=500.0,
        freight_currency="EUR",
    )
    assert b_valid.invoice_currency == "USD"
    assert b_valid.freight_currency == "EUR"


# ==============================================================================
# 5. REST API (422 status code contracts)
# ==============================================================================

def test_api_payment_request_create_without_currency_code_is_422(api, db):
    officer = _user(db, "fin_officer_val1", "FINANCE_OFFICER")
    imp = seed_file(db)
    body = {
        "title": "API payment request",
        "supplier_name": "Supplier ABC",
        "payment_type": "Against B/L",
        "requested_amount": 1000.0,
        "exchange_rate": 50.0,
        "due_date": str(date.today() + timedelta(days=10)),
        "import_file_id": imp.import_file_id,
    }
    # No currency_code -> 422
    resp = api.post(f"{BASE}/payment-requests", headers=_bearer(officer), json=body)
    assert resp.status_code == 422, resp.text

    # With valid currency_code -> 201
    resp_ok = api.post(f"{BASE}/payment-requests", headers=_bearer(officer), json={**body, "currency_code": "USD"})
    assert resp_ok.status_code == 201, resp_ok.text


def test_api_smart_reconcile_with_zero_or_missing_amount_is_422(api, db):
    officer = _user(db, "fin_officer_val2", "FINANCE_OFFICER")
    body = {
        "payment_id": 1,
        "swift_reference_no": "MT103-TEST",
        "swift_receipt_date": str(date.today()),
        "swift_transferred_amount": 0.0,
        "swift_transferred_currency": "USD",
    }
    resp = api.post(f"{BASE}/swift/smart-reconcile", headers=_bearer(officer), json=body)
    assert resp.status_code == 422, resp.text


def test_api_smart_reconcile_without_currency_is_422(api, db):
    officer = _user(db, "fin_officer_val3", "FINANCE_OFFICER")
    body = {
        "payment_id": 1,
        "swift_reference_no": "MT103-TEST",
        "swift_receipt_date": str(date.today()),
        "swift_transferred_amount": 5000.0,
    }
    resp = api.post(f"{BASE}/swift/smart-reconcile", headers=_bearer(officer), json=body)
    assert resp.status_code == 422, resp.text


def test_api_reconcile_swift_without_currency_is_422(api, db):
    officer = _user(db, "fin_officer_val4", "FINANCE_OFFICER")
    body = {
        "swift_reference_no": "MT103-TEST",
        "swift_receipt_date": str(date.today()),
        "swift_transferred_amount": 5000.0,
    }
    resp = api.post(f"{BASE}/payment-requests/1/reconcile-swift", headers=_bearer(officer), json=body)
    assert resp.status_code == 422, resp.text


def test_api_import_budget_create_with_foreign_amount_and_no_currency_is_422(api, db):
    officer = _user(db, "fin_officer_val5", "FINANCE_OFFICER")
    imp = seed_file(db)
    body = {
        "title": "Budget with foreign amount",
        "import_file_id": imp.import_file_id,
        "exchange_rate": 50.0,
        "invoice_amount_foreign": 1000.0,
    }
    # Foreign invoice amount > 0 without invoice_currency -> 422
    resp = api.post(f"{BASE}/import-budgets", headers=_bearer(officer), json=body)
    assert resp.status_code == 422, resp.text

    # Foreign freight cost > 0 without freight_currency -> 422
    body2 = {
        "title": "Budget with freight foreign amount",
        "import_file_id": imp.import_file_id,
        "exchange_rate": 50.0,
        "invoice_amount_foreign": 1000.0,
        "invoice_currency": "USD",
        "freight_cost_foreign": 500.0,
    }
    resp2 = api.post(f"{BASE}/import-budgets", headers=_bearer(officer), json=body2)
    assert resp2.status_code == 422, resp2.text

    # Valid foreign amounts with currencies -> 201
    body_ok = {
        **body2,
        "freight_currency": "EUR",
    }
    resp_ok = api.post(f"{BASE}/import-budgets", headers=_bearer(officer), json=body_ok)
    assert resp_ok.status_code == 201, resp_ok.text
