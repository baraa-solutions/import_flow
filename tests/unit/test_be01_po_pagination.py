"""
Unit and integration tests for BE01-T15:
Paginated Purchase Orders List (GET /api/v1/purchase-orders and /api/v1/purchase-orders/paginated).
"""
from datetime import date, datetime, timedelta, timezone
import pytest
from fastapi import FastAPI, status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from modules.auth.permissions import require_permission
from modules.auth.security import create_access_token
from modules.auth.seed_rbac import seed_rbac
from modules.currencies.model import Currency
from modules.currencies.service import clear_currency_cache
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PurchaseOrder
from modules.purchase_orders.router import router as po_router
from modules.suppliers.model import Supplier
from modules.users.model import Role, User


@pytest.fixture
def session_factory():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    clear_currency_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    clear_currency_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)

    # Base Currency
    usd = Currency(
        currency_id=1,
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_active=True,
    )
    egp = Currency(
        currency_id=2,
        currency_code="EGP",
        currency_name="Egyptian Pound",
        currency_symbol="EGP",
        is_active=True,
    )
    session.add_all([usd, egp])

    # Incoterm
    fob = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        is_active=True,
    )
    session.add(fob)

    # Supplier
    sup1 = Supplier(
        supplier_id=1,
        supplier_code="SUP-001",
        company_name="Global Supplier Co",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-123",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    sup2 = Supplier(
        supplier_id=2,
        supplier_code="SUP-002",
        company_name="Delta Chemical Ltd",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-124",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Munich",
        is_active=True,
    )
    session.add_all([sup1, sup2])

    # Import Company
    comp = ImportCompany(
        company_id=1,
        importer_name="Sorour Logistics Import",
        address="Cairo, Egypt",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date.today() + timedelta(days=365),
        vat_id="VAT-001",
        vat_id_expiry=date.today() + timedelta(days=365),
        registration_number="REG-001",
        registration_expiry=date.today() + timedelta(days=365),
        is_active=True,
    )
    session.add(comp)

    # Project
    proj = Project(
        project_id=1,
        project_code="PRJ-001",
        project_name="Solar Plant Expansion",
        project_owner="Eng. Ahmed",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=True,
    )
    session.add(proj)

    # Import File
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-FILE-2026-001",
        company_name="Sorour Logistics Import",
        supplier_name="Global Supplier Co",
        is_active=True,
    )
    session.add(imp_file)

    # Admin User with permissions
    user = User(
        user_id=1,
        username="admin_test",
        full_name="Admin Test",
        email="admin@test.com",
        hashed_password="test_hash",
        is_active=True,
        role="ADMIN",
        role_id=1,
    )
    session.add(user)
    session.commit()

    # 7 Purchase Orders
    base_time = datetime(2026, 3, 1, 10, 0, 0, tzinfo=timezone.utc)
    for i in range(1, 8):
        po = PurchaseOrder(
            po_id=i,
            po_number=f"PO-2026-00{i}",
            po_reference=f"Reference PO {i}",
            proforma_invoice_number=f"PI-88{i}",
            project_id=1,
            company_id=1,
            supplier_id=1 if i <= 4 else 2,
            incoterm_id=1,
            currency_id=1,
            exchange_rate=50.0,
            total_amount_fob=1000.0 * i,
            order_date=base_time + timedelta(days=i),
            status="DRAFT" if i <= 3 else ("APPROVED" if i <= 5 else "CLOSED"),
            import_file_id=1 if i <= 3 else None,
            is_active=True,
            created_at=base_time + timedelta(hours=i),
            created_by="admin_test",
        )
        session.add(po)
        session.flush()

        line = POLineItem(
            po_id=po.po_id,
            item_code=f"ITEM-{i:03d}",
            main_description=f"Main Description {i}",
            description_ar=f"وصف الصنف {i}",
            quantity=10.0 * i,
            unit_of_measure="PCS",
            unit_price=100.0,
            total_price=1000.0 * i,
        )
        session.add(line)

    session.commit()
    yield session
    session.close()


@pytest.fixture
def client(db):
    app = FastAPI()
    app.include_router(po_router)
    app.dependency_overrides[get_db] = lambda: db

    token = create_access_token(data={"sub": "1", "username": "admin_test", "role": "admin"})
    test_client = TestClient(app)
    test_client.headers.update({"Authorization": f"Bearer {token}"})
    yield test_client
    app.dependency_overrides.clear()


# ==============================================================================
# 1. Plain GET /api/v1/purchase-orders Tests (BE01-T15 specification)
# ==============================================================================

def test_po_list_all_default(client):
    """GET /api/v1/purchase-orders with default query params returns all 7 POs + header X-Total-Count: 7."""
    resp = client.get("/api/v1/purchase-orders")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.headers.get("X-Total-Count") == "7"
    data = resp.json()
    assert len(data) == 7
    # Eager loaded line items present on full response model
    assert len(data[0]["items"]) >= 1


def test_po_list_skip_and_limit(client):
    """GET /api/v1/purchase-orders?skip=5&limit=5 returns 2 rows and X-Total-Count: 7."""
    resp = client.get("/api/v1/purchase-orders?skip=5&limit=5")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.headers.get("X-Total-Count") == "7"
    data = resp.json()
    assert len(data) == 2


def test_po_list_skip_past_end(client):
    """GET /api/v1/purchase-orders?skip=10&limit=5 returns empty list and X-Total-Count: 7."""
    resp = client.get("/api/v1/purchase-orders?skip=10&limit=5")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.headers.get("X-Total-Count") == "7"
    data = resp.json()
    assert len(data) == 0


def test_po_list_limit_validation(client):
    """Validation bounds for skip and limit on GET /api/v1/purchase-orders."""
    # Negative skip -> 422
    resp = client.get("/api/v1/purchase-orders?skip=-1")
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # Zero limit -> 422
    resp = client.get("/api/v1/purchase-orders?limit=0")
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # Limit > 500 -> 422
    resp = client.get("/api/v1/purchase-orders?limit=501")
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


# ==============================================================================
# 2. Paginated GET /api/v1/purchase-orders/paginated Tests (BEW0-04 standard)
# ==============================================================================

def test_po_paginated_envelope(client):
    """GET /api/v1/purchase-orders/paginated returns standard page envelope and headers."""
    resp = client.get("/api/v1/purchase-orders/paginated?page=1&page_size=3")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.headers.get("X-Total-Count") == "7"

    data = resp.json()
    assert data["total"] == 7
    assert data["page"] == 1
    assert data["page_size"] == 3
    assert data["total_pages"] == 3
    assert len(data["items"]) == 3

    # Lightweight summary structure verified
    item = data["items"][0]
    assert "po_id" in item
    assert "po_number" in item
    assert "supplier_name" in item
    assert "company_name" in item
    assert "total_amount_fob" in item
    assert "currency_code" in item
    assert "status" in item
    assert "order_date" in item
    assert "created_at" in item
    # Heavy children (line items / packing items) are excluded from summary row
    assert "items" not in item
    assert "packing_list_items" not in item


def test_po_paginated_page_2(client):
    """GET /api/v1/purchase-orders/paginated?page=2&page_size=3 returns items 4..6."""
    resp = client.get("/api/v1/purchase-orders/paginated?page=2&page_size=3")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["page"] == 2
    assert len(data["items"]) == 3


def test_po_paginated_page_past_end(client):
    """Requesting page beyond total_pages returns empty items with accurate total."""
    resp = client.get("/api/v1/purchase-orders/paginated?page=10&page_size=3")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 7
    assert data["total_pages"] == 3


def test_po_paginated_sorting_whitelisted(client):
    """Valid sort keys order rows deterministically."""
    # Descending amount
    resp = client.get("/api/v1/purchase-orders/paginated?sort=-total_amount_fob&page_size=7")
    assert resp.status_code == status.HTTP_200_OK
    items = resp.json()["items"]
    amounts = [i["total_amount_fob"] for i in items]
    assert amounts == sorted(amounts, reverse=True)

    # Ascending po_number
    resp = client.get("/api/v1/purchase-orders/paginated?sort=po_number&page_size=7")
    assert resp.status_code == status.HTTP_200_OK
    items = resp.json()["items"]
    codes = [i["po_number"] for i in items]
    assert codes == sorted(codes)


def test_po_paginated_sorting_invalid_field_raises_400(client):
    """Non-whitelisted sort field raises 400 with LIST_SORT_FIELD_INVALID."""
    resp = client.get("/api/v1/purchase-orders/paginated?sort=nonexistent_field")
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    detail = resp.json().get("detail", {})
    code = detail.get("code") if isinstance(detail, dict) else None
    assert code == "LIST_SORT_FIELD_INVALID"


def test_po_paginated_filters(client):
    """Filters by status, supplier_id, and search query q."""
    # Filter by status = APPROVED (POs 4 and 5)
    resp = client.get("/api/v1/purchase-orders/paginated?status=APPROVED")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["total"] == 2
    for item in data["items"]:
        assert item["status"] == "APPROVED"

    # Filter by supplier_id = 2 (POs 5, 6, 7)
    resp = client.get("/api/v1/purchase-orders/paginated?supplier_id=2")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["total"] == 3

    # Search by code
    resp = client.get("/api/v1/purchase-orders/paginated?q=PO-2026-003")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["po_number"] == "PO-2026-003"

    # Search with legacy alias 'search'
    resp = client.get("/api/v1/purchase-orders/paginated?search=PO-2026-004")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["po_number"] == "PO-2026-004"


def test_po_paginated_wildcard_escaping(client):
    """Search query with wildcard characters %, _, \\ does not fail."""
    resp = client.get("/api/v1/purchase-orders/paginated?q=50%")
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["total"] == 0
