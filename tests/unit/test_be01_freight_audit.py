"""
Unit tests for BE01-T10:
Audit wiring for freight RFQs (FreightRFQRequest).
Verifies created_by and updated_by through create, update, award, soft delete, and restore,
as well as backwards compatibility for legacy rows with NULL audit values.
"""
from datetime import date, timedelta
import pytest
import sqlalchemy as sa
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.external_service_providers.model import ExternalServiceProvider
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.freight_quotations.schemas import (
    FreightQuotationItemCreate,
    FreightRFQRequestCreate,
    FreightRFQRequestUpdate,
)
from modules.freight_quotations.service import FreightQuotationService
from modules.currencies.model import Currency
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
    session.add_all([
        Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True),
        Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True),
    ])
    session.commit()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def carrier(db):
    sp = ExternalServiceProvider(
        provider_id=201,
        partner_code="CAR-00201",
        partner_name="Mediterranean Shipping Line",
        partner_type="Shipping Line",
        is_active=True,
    )
    db.add(sp)
    db.commit()
    db.refresh(sp)
    return sp


def _make_rfq_create(carrier_id: int, carrier_name: str, title: str = "طلب شحن شنغهاي إلى الإسكندرية") -> FreightRFQRequestCreate:
    crd = date.today() + timedelta(days=10)
    sailing = crd + timedelta(days=2)
    arrival = sailing + timedelta(days=20)
    return FreightRFQRequestCreate(
        title=title,
        shipping_method="Ocean FCL",
        crd_date=crd,
        pol_name="Shanghai Port",
        pod_name="Alexandria Port",
        total_cbm=45.0,
        total_gross_weight_kg=18000.0,
        chargeable_weight_kg=18000.0,
        notes="حاويات قطع غيار",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=carrier_id,
                provider_name=carrier_name,
                vessel_name="MSC ISABELLA",
                voyage_number="2601W",
                currency_code="USD",
                ocean_freight_cost=2400.0,
                local_charges_cost=300.0,
                inland_cost=150.0,
                sailing_date=sailing,
                estimated_arrival_date=arrival,
                free_days_at_pod=14,
                remarks="عرض معتمد مع فترة سماح 14 يوم",
            )
        ],
    )


# ==============================================================================
# Service & Repository Audit Tests
# ==============================================================================

def test_freight_rfq_audit_lifecycle(db, carrier):
    # 1. Create with user alice
    create_schema = _make_rfq_create(carrier.provider_id, carrier.partner_name, "شحن إلكترونيات")
    created = FreightQuotationService.create_rfq(db, create_schema, user="alice")
    assert created.created_by == "alice"
    assert created.updated_by == "alice"

    db_row = db.get(FreightRFQRequest, created.rfq_id)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "alice"

    # 2. Update with user bob
    update_schema = FreightRFQRequestUpdate(notes="تم تحديث الملاحظات وإضافة تعليمات خاصة")
    updated = FreightQuotationService.update_rfq(db, created.rfq_id, update_schema, user="bob")
    assert updated.created_by == "alice"
    assert updated.updated_by == "bob"

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "bob"

    # 3. Award quotation with user charlie
    quote_id = created.quotations[0].quotation_id
    awarded = FreightQuotationService.award_quotation(db, created.rfq_id, quote_id, user="charlie")
    assert awarded.created_by == "alice"
    assert awarded.updated_by == "charlie"
    assert awarded.status == "Awarded"

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "charlie"

    # 4. Soft-delete with user dave
    deleted = FreightQuotationService.soft_delete_rfq(db, created.rfq_id, user="dave")
    assert deleted.created_by == "alice"
    assert deleted.updated_by == "dave"
    assert deleted.is_active is False

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "dave"
    assert db_row.is_active is False

    # 5. Restore with user eve
    restored = FreightQuotationService.restore_rfq(db, created.rfq_id, user="eve")
    assert restored.created_by == "alice"
    assert restored.updated_by == "eve"
    assert restored.is_active is True

    db.refresh(db_row)
    assert db_row.created_by == "alice"
    assert db_row.updated_by == "eve"
    assert db_row.is_active is True


def test_freight_rfq_create_default_none_user(db, carrier):
    create_schema = _make_rfq_create(carrier.provider_id, carrier.partner_name, "شحن بدون مستخدم")
    created = FreightQuotationService.create_rfq(db, create_schema, user=None)
    assert created.created_by is None
    assert created.updated_by is None

    db_row = db.get(FreightRFQRequest, created.rfq_id)
    assert db_row.created_by is None
    assert db_row.updated_by is None


# ==============================================================================
# Legacy Rows with NULL Audit Columns
# ==============================================================================

def test_legacy_freight_rfq_rows_read_none_for_audit_fields(db, carrier):
    # Insert legacy freight_rfq_requests row directly with raw SQL (created_by and updated_by = NULL)
    db.execute(
        sa.text(
            """
            INSERT INTO freight_rfq_requests (
                rfq_id, rfq_code, title, shipping_method, crd_date, pol_name, pod_name,
                total_cbm, total_gross_weight_kg, chargeable_weight_kg, status,
                is_active, created_at, updated_at, created_by, updated_by
            ) VALUES (
                7777, 'RFQ-LEGACY-001', 'طلب شحن قديم', 'Ocean FCL', '2025-05-01',
                'Ningbo', 'Alexandria', 30.0, 10000.0, 10000.0, 'Draft',
                1, '2025-05-01 00:00:00', '2025-05-01 00:00:00', NULL, NULL
            )
            """
        )
    )
    db.commit()

    # Read legacy RFQ via service
    rfq = FreightQuotationService.get_rfq(db, 7777)
    assert rfq.created_by is None
    assert rfq.updated_by is None

    # Read via list_rfqs
    rfq_list = FreightQuotationService.list_rfqs(db, include_inactive=True)
    legacy_in_list = [r for r in rfq_list if r.rfq_id == 7777]
    assert len(legacy_in_list) == 1
    assert legacy_in_list[0].created_by is None
    assert legacy_in_list[0].updated_by is None

    # Update legacy row sets updated_by while leaving created_by as None
    update_schema = FreightRFQRequestUpdate(notes="تحديث طلب قديم")
    updated = FreightQuotationService.update_rfq(db, 7777, update_schema, user="frank")
    assert updated.created_by is None
    assert updated.updated_by == "frank"

    db_row = db.get(FreightRFQRequest, 7777)
    assert db_row.created_by is None
    assert db_row.updated_by == "frank"


# ==============================================================================
# Router Wire-Up Tests (HTTP Integration)
# ==============================================================================

def test_router_freight_rfq_audit_wiring(db, carrier):
    for uname in ["alice", "bob", "charlie", "dave", "eve"]:
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

        crd = (date.today() + timedelta(days=10)).isoformat()
        sailing = (date.today() + timedelta(days=12)).isoformat()
        arrival = (date.today() + timedelta(days=32)).isoformat()

        # 1. POST /api/v1/freight-quotations as alice
        resp = client.post(
            "/api/v1/freight-quotations",
            json={
                "title": "طلب شحن حاويات عبر API",
                "shipping_method": "Ocean FCL",
                "crd_date": crd,
                "pol_name": "Qingdao Port",
                "pod_name": "Dekheila Port",
                "total_cbm": 60.0,
                "total_gross_weight_kg": 24000.0,
                "chargeable_weight_kg": 24000.0,
                "notes": "شحن مواد خام",
                "quotations": [
                    {
                        "provider_id": carrier.provider_id,
                        "provider_name": carrier.partner_name,
                        "vessel_name": "CMA CGM ANTOINE",
                        "currency_code": "USD",
                        "ocean_freight_cost": 3100.0,
                        "local_charges_cost": 350.0,
                        "inland_cost": 200.0,
                        "sailing_date": sailing,
                        "estimated_arrival_date": arrival,
                        "free_days_at_pod": 21,
                    }
                ],
            },
            headers={"X-User-Name": "alice"},
        )
        assert resp.status_code == 201, resp.text
        data = resp.json()
        rfq_id = data["rfq_id"]
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "alice"

        quote_id = data["quotations"][0]["quotation_id"]

        # 2. GET /api/v1/freight-quotations/{id}
        resp = client.get(
            f"/api/v1/freight-quotations/{rfq_id}",
            headers={"X-User-Name": "alice"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "alice"

        # 3. PUT /api/v1/freight-quotations/{id} as bob
        resp = client.put(
            f"/api/v1/freight-quotations/{rfq_id}",
            json={"notes": "تحديث ملاحظات الشحن بواسطة بوب"},
            headers={"X-User-Name": "bob"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "bob"

        # 4. POST /api/v1/freight-quotations/{id}/award/{quote_id} as charlie
        resp = client.post(
            f"/api/v1/freight-quotations/{rfq_id}/award/{quote_id}",
            headers={"X-User-Name": "charlie"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "charlie"
        assert data["status"] == "Awarded"

        # 5. DELETE /api/v1/freight-quotations/{id} as dave
        resp = client.delete(
            f"/api/v1/freight-quotations/{rfq_id}",
            headers={"X-User-Name": "dave"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "dave"
        assert data["is_active"] is False

        # 6. POST /api/v1/freight-quotations/{id}/restore as eve
        resp = client.post(
            f"/api/v1/freight-quotations/{rfq_id}/restore",
            headers={"X-User-Name": "eve"},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["created_by"] == "alice"
        assert data["updated_by"] == "eve"
        assert data["is_active"] is True

    finally:
        app.dependency_overrides.clear()
