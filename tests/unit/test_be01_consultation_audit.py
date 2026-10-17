"""
Unit tests for BE01-T09:
Audit wiring for clearance expense types and broker price lists.
Verifies created_by and updated_by through create, update, delete, soft delete, and clone,
as well as backwards compatibility for legacy rows with NULL audit values.
"""
from datetime import date
import pytest
import sqlalchemy as sa
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.customs_consultation.model import (
    BrokerPriceList,
    ClearanceExpenseType,
)
from modules.customs_consultation.schemas import (
    BrokerPriceListCreate,
    BrokerPriceListUpdate,
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    CloneBrokerPriceListRequest,
)
from modules.customs_consultation.service import (
    BrokerPriceListService,
    ClearanceExpenseTypeService,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.users.model import User


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def broker(db):
    b = ExternalServiceProvider(
        provider_id=101,
        partner_code="BRK-00101",
        partner_name="Express Clearance Broker",
        partner_type="Customs Broker",
        is_active=True,
    )
    db.add(b)
    db.commit()
    db.refresh(b)
    return b


# ==============================================================================
# Service & Repository Audit Tests
# ==============================================================================

def test_clearance_expense_type_audit_lifecycle(db):
    # 1. Create with user alice
    create_schema = ClearanceExpenseTypeCreate(
        name_ar="رسوم كشف ومعاينة",
        name_en="Inspection Fee",
        category="CLEARANCE_FEES",
        default_unit="PER_INVOICE",
        default_currency="EGP",
    )
    created = ClearanceExpenseTypeService.create_expense_type(db, create_schema, user="alice")
    assert created.created_by == "alice"
    assert created.updated_by == "alice"

    db_row = db.get(ClearanceExpenseType, created.expense_id)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "alice"

    # 2. Update with user bob
    update_schema = ClearanceExpenseTypeUpdate(name_en="Updated Inspection Fee")
    updated = ClearanceExpenseTypeService.update_expense_type(
        db, created.expense_id, update_schema, user="bob"
    )
    assert updated.created_by == "alice"
    assert updated.updated_by == "bob"

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "bob"

    # 3. Delete (soft-delete is_active=False) with user charlie
    deleted = ClearanceExpenseTypeService.delete_expense_type(
        db, created.expense_id, user="charlie"
    )
    assert deleted.created_by == "alice"
    assert deleted.updated_by == "charlie"
    assert deleted.is_active is False

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "charlie"
    assert db_row.is_active is False


def test_clearance_expense_type_create_default_none_user(db):
    create_schema = ClearanceExpenseTypeCreate(
        name_ar="رسوم أرضيات",
        name_en="Storage Fee",
        category="PORT_FEES",
        default_unit="PER_CONTAINER",
        default_currency="EGP",
    )
    created = ClearanceExpenseTypeService.create_expense_type(db, create_schema, user=None)
    assert created.created_by is None
    assert created.updated_by is None

    db_row = db.get(ClearanceExpenseType, created.expense_id)
    assert db_row.created_by is None
    assert db_row.updated_by is None


def test_broker_price_list_audit_lifecycle(db, broker):
    # 1. Create with user alice
    create_schema = BrokerPriceListCreate(
        broker_id=broker.provider_id,
        broker_name=broker.partner_name,
        title="تعريفة التخليص السخنة 2026",
        port_name="Sokhna",
        effective_from=date(2026, 1, 1),
        effective_to=date(2026, 12, 31),
        items=[],
    )
    created = BrokerPriceListService.create_price_list(db, create_schema, user="alice")
    assert created.created_by == "alice"
    assert created.updated_by == "alice"

    db_row = db.get(BrokerPriceList, created.price_list_id)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "alice"

    # 2. Update with user bob
    update_schema = BrokerPriceListUpdate(notes="ملاحظات محدثة لقائمة الأسعار")
    updated = BrokerPriceListService.update_price_list(
        db, created.price_list_id, update_schema, user="bob"
    )
    assert updated.created_by == "alice"
    assert updated.updated_by == "bob"

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "bob"

    # 3. Soft-delete with user charlie
    deleted = BrokerPriceListService.soft_delete_price_list(
        db, created.price_list_id, user="charlie"
    )
    assert deleted.created_by == "alice"
    assert deleted.updated_by == "charlie"
    assert deleted.is_active is False

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "charlie"
    assert db_row.is_active is False

    # 4. Clone with user dave
    clone_schema = CloneBrokerPriceListRequest(
        new_title="نسخة تعريفة التخليص 2027",
        effective_from=date(2027, 1, 1),
        effective_to=date(2027, 12, 31),
    )
    cloned = BrokerPriceListService.clone_price_list(
        db, created.price_list_id, clone_schema, user="dave"
    )
    assert cloned.created_by == "dave"
    assert cloned.updated_by == "dave"

    db_cloned = db.get(BrokerPriceList, cloned.price_list_id)
    assert db_cloned.created_by == "dave"
    assert db_cloned.updated_by == "dave"


def test_broker_price_list_create_default_none_user(db, broker):
    create_schema = BrokerPriceListCreate(
        broker_id=broker.provider_id,
        broker_name=broker.partner_name,
        title="تعريفة غير منسوبة",
        port_name="Alexandria",
        effective_from=date(2026, 1, 1),
        items=[],
    )
    created = BrokerPriceListService.create_price_list(db, create_schema, user=None)
    assert created.created_by is None
    assert created.updated_by is None

    db_row = db.get(BrokerPriceList, created.price_list_id)
    assert db_row.created_by is None
    assert db_row.updated_by is None


# ==============================================================================
# Legacy Rows with NULL Audit Columns
# ==============================================================================

def test_legacy_rows_read_none_for_audit_fields(db, broker):
    # Insert legacy clearance_expense_type directly with raw SQL
    db.execute(
        sa.text(
            """
            INSERT INTO clearance_expense_types (
                expense_id, expense_code, name_ar, name_en, category, default_unit,
                default_currency, display_order, is_active, created_at, updated_at,
                created_by, updated_by
            ) VALUES (
                9999, 'EXP-LEGACY-001', 'مصروف قديم', 'Legacy Expense', 'CLEARANCE_FEES',
                'PER_INVOICE', 'EGP', 1, 1, '2025-01-01 00:00:00', '2025-01-01 00:00:00',
                NULL, NULL
            )
            """
        )
    )

    # Insert legacy broker_price_list directly with raw SQL
    db.execute(
        sa.text(
            """
            INSERT INTO broker_price_lists (
                price_list_id, price_list_code, broker_id, broker_name, title, port_name,
                effective_from, effective_to, version, is_active, notes,
                created_at, updated_at, created_by, updated_by
            ) VALUES (
                8888, 'BPL-LEGACY-001', :broker_id, :broker_name, 'قائمة قديمة', 'Port Said',
                '2025-01-01', '2025-12-31', 1, 1, 'Legacy notes',
                '2025-01-01 00:00:00', '2025-01-01 00:00:00',
                NULL, NULL
            )
            """
        ),
        {"broker_id": broker.provider_id, "broker_name": broker.partner_name},
    )
    db.commit()

    # Read expense type
    exp = ClearanceExpenseTypeService.get_expense_type(db, 9999)
    assert exp.created_by is None
    assert exp.updated_by is None

    exp_list = ClearanceExpenseTypeService.list_expense_types(db, include_inactive=True)
    legacy_in_list = [e for e in exp_list if e.expense_id == 9999]
    assert len(legacy_in_list) == 1
    assert legacy_in_list[0].created_by is None
    assert legacy_in_list[0].updated_by is None

    # Read price list
    pl = BrokerPriceListService.get_price_list(db, 8888)
    assert pl.created_by is None
    assert pl.updated_by is None

    pl_list = BrokerPriceListService.list_price_lists(db, include_inactive=True)
    legacy_pl_in_list = [p for p in pl_list if p.price_list_id == 8888]
    assert len(legacy_pl_in_list) == 1
    assert legacy_pl_in_list[0].created_by is None
    assert legacy_pl_in_list[0].updated_by is None


# ==============================================================================
# Router Wire-Up Tests (HTTP Integration)
# ==============================================================================

def test_router_audit_wiring_endpoints(db, broker):
    for uname in ["alice", "bob", "charlie", "dave"]:
        db.add(
            User(
                username=uname,
                email=f"{uname}@example.com",
                hashed_password="dummy_password_hash",
                full_name=uname.title(),
                role="ADMIN",
                is_active=True,
            )
        )
    db.commit()

    app = main.app
    app.dependency_overrides[get_db] = lambda: db

    try:
        client = TestClient(app, raise_server_exceptions=True)

        # 1. POST expense type as alice
        resp = client.post(
            "/api/v1/customs-consultations/expense-types",
            json={
                "name_ar": "نولون تخليص",
                "name_en": "Clearance Freight",
                "category": "CLEARANCE_FEES",
                "default_unit": "PER_INVOICE",
                "default_currency": "EGP",
            },
            headers={"X-User-Name": "alice"},
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        exp_id = data["expense_id"]
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "alice"

        # 2. PUT expense type as bob
        resp = client.put(
            f"/api/v1/customs-consultations/expense-types/{exp_id}",
            json={"name_en": "Updated Clearance Freight"},
            headers={"X-User-Name": "bob"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "bob"

        # 3. DELETE expense type as charlie
        resp = client.delete(
            f"/api/v1/customs-consultations/expense-types/{exp_id}",
            headers={"X-User-Name": "charlie"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "charlie"

        # 4. POST price list as alice
        resp = client.post(
            "/api/v1/customs-consultations/price-lists",
            json={
                "broker_id": broker.provider_id,
                "broker_name": broker.partner_name,
                "title": "قائمة الإسكندرية 2026",
                "port_name": "Alexandria",
                "effective_from": "2026-01-01",
                "effective_to": "2026-12-31",
                "items": [],
            },
            headers={"X-User-Name": "alice"},
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        pl_id = data["price_list_id"]
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "alice"

        # 5. PUT price list as bob
        resp = client.put(
            f"/api/v1/customs-consultations/price-lists/{pl_id}",
            json={"notes": "ملاحظات التحديث"},
            headers={"X-User-Name": "bob"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "bob"

        # 6. DELETE price list as charlie
        resp = client.delete(
            f"/api/v1/customs-consultations/price-lists/{pl_id}",
            headers={"X-User-Name": "charlie"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "charlie"

        # 7. POST clone price list as dave
        resp = client.post(
            f"/api/v1/customs-consultations/price-lists/{pl_id}/clone",
            json={
                "new_title": "نسخة قائمة الإسكندرية 2027",
                "effective_from": "2027-01-01",
                "effective_to": "2027-12-31",
            },
            headers={"X-User-Name": "dave"},
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        assert data["created_by"] == "dave"
        assert data["updated_by"] == "dave"

    finally:
        app.dependency_overrides.clear()
