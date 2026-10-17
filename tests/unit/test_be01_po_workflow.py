"""
Unit tests for BE01-T11:
PO status workflow and lifecycle guards (PurchaseOrder, POShipmentAllocation).
Verifies:
- Allowed status transition matrix (DRAFT -> APPROVED, CANCELLED; APPROVED -> DRAFT, CANCELLED, CLOSED; etc.)
- Rejection of manual PUT transitions to shipped states (400)
- Rejection of edits and allocations on CLOSED / CANCELLED POs (409 PO_NOT_EDITABLE)
- Guard against soft deletion of POs with shipment allocations (409 PO_HAS_ALLOCATIONS)
- 404 when attempting to update a soft-deleted PO
- Inactive import file validation on restore (400)
- Normalization and enforcement of PO_ALLOCATION_STATUS enum codes
- HTTP endpoints via TestClient
"""
from datetime import date, datetime, timedelta, timezone
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.common.errors import CodedHTTPException
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.import_companies.model import ImportCompany
from modules.import_companies.schemas import ImportCompanyCreate
from modules.import_companies.service import create_import_company
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PurchaseOrder
from modules.purchase_orders.schemas import (
    POLineItemCreate,
    POShipmentAllocationCreate,
    POShipmentAllocationResponse,
    PurchaseOrderCreate,
    PurchaseOrderUpdate,
)
from modules.purchase_orders.service import PurchaseOrderService
from modules.suppliers.model import Supplier
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
def master_data(db):
    company_data = ImportCompanyCreate(
        importer_name="Import Corp",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100200",
        importer_id_expiry=date.today() + timedelta(days=120),
        vat_id="VAT-998877",
        vat_id_expiry=date.today() + timedelta(days=90),
        registration_number="REG-554433",
        registration_expiry=date.today() + timedelta(days=60),
    )
    comp = create_import_company(db, company_data)
    supp = Supplier(
        supplier_id=1,
        company_name="Global Supplier Ltd",
        supplier_code="SUP-001",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-123",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    inco = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free on Board", is_active=True)
    curr = Currency(currency_id=1, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    proj = Project(
        project_id=1,
        project_name="Project Alpha",
        project_code="PRJ-001",
        project_owner="Eng. Test",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=True,
    )
    tariff = CustomsTariff(
        tariff_id=1,
        hs_code="8471.30.00",
        hs_description="أجهزة حاسب آلي محمولة",
        customs_duty_rate=5.0,
        vat_rate=14.0,
        is_active=True,
    )
    import_file = ImportFile(
        import_file_id=10,
        import_file_code="IF-2026-00010",
        company_id=1,
        company_name="Import Corp",
        supplier_id=1,
        supplier_name="Global Supplier Ltd",
        is_active=True,
        po_ids=[],
    )
    db.add_all([proj, comp, supp, inco, curr, tariff, import_file])
    db.commit()
    return {
        "project": proj,
        "company": comp,
        "supplier": supp,
        "incoterm": inco,
        "currency": curr,
        "tariff": tariff,
        "import_file": import_file,
    }


def _create_po(db, master_data, po_number="PO-2026-001", status="DRAFT", import_file_id=10):
    po = PurchaseOrder(
        po_number=po_number,
        company_id=master_data["company"].company_id,
        supplier_id=master_data["supplier"].supplier_id,
        project_id=master_data["project"].project_id,
        incoterm_id=master_data["incoterm"].incoterm_id,
        currency_id=master_data["currency"].currency_id,
        import_file_id=import_file_id,
        status=status,
        exchange_rate=50.0,
        is_active=True,
        version=1,
    )
    db.add(po)
    db.flush()
    line = POLineItem(
        po_id=po.po_id,
        item_code="LAP-01",
        description_ar="لابتوب مكتبي",
        tariff_id=master_data["tariff"].tariff_id,
        quantity=100.0,
        unit_price=500.0,
        total_price=50000.0,
    )
    db.add(line)
    db.commit()
    db.refresh(po)
    return po


# ==============================================================================
# 1. Status Transition Guards
# ==============================================================================

def test_po_draft_forbidden_transitions(db, master_data):
    po = _create_po(db, master_data)
    service = PurchaseOrderService(db)

    # DRAFT -> FULLY_SHIPPED is rejected (400)
    with pytest.raises(HTTPException) as exc:
        service.update(po.po_id, PurchaseOrderUpdate(status="FULLY_SHIPPED"))
    assert exc.value.status_code == 400
    assert "DRAFT" in exc.value.detail and "FULLY_SHIPPED" in exc.value.detail

    # DRAFT -> PARTIALLY_SHIPPED is rejected (400)
    with pytest.raises(HTTPException) as exc:
        service.update(po.po_id, PurchaseOrderUpdate(status="PARTIALLY_SHIPPED"))
    assert exc.value.status_code == 400

    # DRAFT -> CLOSED is rejected (400)
    with pytest.raises(HTTPException) as exc:
        service.update(po.po_id, PurchaseOrderUpdate(status="CLOSED"))
    assert exc.value.status_code == 400


def test_po_allowed_status_lifecycle(db, master_data):
    po = _create_po(db, master_data)
    service = PurchaseOrderService(db)

    # 1. DRAFT -> APPROVED (allowed)
    res = service.update(po.po_id, PurchaseOrderUpdate(status="APPROVED"))
    assert res.status == "APPROVED"

    # 2. APPROVED -> DRAFT (allowed)
    res = service.update(po.po_id, PurchaseOrderUpdate(status="DRAFT"))
    assert res.status == "DRAFT"

    # 3. DRAFT -> CANCELLED (allowed)
    res = service.update(po.po_id, PurchaseOrderUpdate(status="CANCELLED"))
    assert res.status == "CANCELLED"


# ==============================================================================
# 2. Edits & Allocations on Final Statuses (409 PO_NOT_EDITABLE)
# ==============================================================================

def test_po_closed_or_cancelled_not_editable(db, master_data):
    po_closed = _create_po(db, master_data, po_number="PO-CLOSED", status="CLOSED")
    service = PurchaseOrderService(db)

    # Update on CLOSED PO -> 409 PO_NOT_EDITABLE
    with pytest.raises(CodedHTTPException) as exc:
        service.update(po_closed.po_id, PurchaseOrderUpdate(notes="ملاحظات جديدة"))
    assert exc.value.status_code == 409
    assert exc.value.code == "PO_NOT_EDITABLE"
    assert exc.value.params.get("status") == "CLOSED"

    # Allocation on CLOSED PO -> 409 PO_NOT_EDITABLE
    alloc_in = POShipmentAllocationCreate(
        shipment_ref="BL-001",
        shipped_quantity=10.0,
        shipped_amount_fob=5000.0,
    )
    with pytest.raises(CodedHTTPException) as exc:
        service.allocate_shipment(po_closed.po_id, alloc_in)
    assert exc.value.status_code == 409
    assert exc.value.code == "PO_NOT_EDITABLE"
    assert exc.value.params.get("status") == "CLOSED"

    # CANCELLED PO
    po_cancelled = _create_po(db, master_data, po_number="PO-CANCELLED", status="CANCELLED")

    # Update on CANCELLED PO -> 409 PO_NOT_EDITABLE
    with pytest.raises(CodedHTTPException) as exc:
        service.update(po_cancelled.po_id, PurchaseOrderUpdate(status="DRAFT"))
    assert exc.value.status_code == 409
    assert exc.value.code == "PO_NOT_EDITABLE"

    # Allocation on CANCELLED PO -> 409 PO_NOT_EDITABLE
    with pytest.raises(CodedHTTPException) as exc:
        service.allocate_shipment(po_cancelled.po_id, alloc_in)
    assert exc.value.status_code == 409
    assert exc.value.code == "PO_NOT_EDITABLE"


# ==============================================================================
# 3. Soft Delete Guarded by Allocations (409 PO_HAS_ALLOCATIONS)
# ==============================================================================

def test_soft_delete_guarded_by_allocations(db, master_data):
    po = _create_po(db, master_data, po_number="PO-ALLOC")
    service = PurchaseOrderService(db)

    # Add allocation
    alloc_in = POShipmentAllocationCreate(
        shipment_ref="BL-ALLOC-1",
        shipped_quantity=20.0,
        shipped_amount_fob=10000.0,
    )
    service.allocate_shipment(po.po_id, alloc_in)

    # Deleting PO with allocation raises 409 PO_HAS_ALLOCATIONS
    with pytest.raises(CodedHTTPException) as exc:
        service.soft_delete(po.po_id)
    assert exc.value.status_code == 409
    assert exc.value.code == "PO_HAS_ALLOCATIONS"

    # PO without allocations can be soft-deleted
    po_empty = _create_po(db, master_data, po_number="PO-EMPTY")
    del_res = service.soft_delete(po_empty.po_id)
    assert del_res.is_active is False


# ==============================================================================
# 4. Update on Soft-Deleted PO Returns 404
# ==============================================================================

def test_update_on_soft_deleted_po_returns_404(db, master_data):
    po = _create_po(db, master_data, po_number="PO-DEL")
    service = PurchaseOrderService(db)

    file_before = db.get(ImportFile, master_data["import_file"].import_file_id)
    initial_po_ids = list(file_before.po_ids or [])

    service.soft_delete(po.po_id)

    # Updating a soft-deleted PO raises 404
    with pytest.raises(HTTPException) as exc:
        service.update(po.po_id, PurchaseOrderUpdate(notes="محاولة تعديل محذوف"))
    assert exc.value.status_code == 404

    # import_file.po_ids remains unchanged
    db.refresh(file_before)
    assert po.po_id not in (file_before.po_ids or [])


# ==============================================================================
# 5. Restore Validation with Active/Inactive ImportFile
# ==============================================================================

def test_restore_checks_import_file_active(db, master_data):
    po = _create_po(db, master_data, po_number="PO-RESTORE")
    service = PurchaseOrderService(db)
    service.soft_delete(po.po_id)

    # Deactivate linked ImportFile
    import_file = master_data["import_file"]
    import_file.is_active = False
    db.commit()

    # Restoring PO linked to inactive ImportFile raises 400
    with pytest.raises(HTTPException) as exc:
        service.restore(po.po_id)
    assert exc.value.status_code == 400
    assert "غير نشط" in exc.value.detail

    # Reactivate ImportFile and restore should succeed
    import_file.is_active = True
    db.commit()

    restored = service.restore(po.po_id)
    assert restored.is_active is True
    db.refresh(import_file)
    assert po.po_id in (import_file.po_ids or [])


# ==============================================================================
# 6. Allocation Status Normalization & Enum Codes
# ==============================================================================

def test_allocation_status_normalization(db, master_data):
    po = _create_po(db, master_data, po_number="PO-STATUS-NORM")
    service = PurchaseOrderService(db)

    # 1. Create with legacy label "In Transit" -> normalized to "IN_TRANSIT"
    alloc_in = POShipmentAllocationCreate(
        shipment_ref="BL-NORM-1",
        shipped_quantity=5.0,
        shipped_amount_fob=2500.0,
        status="In Transit",
    )
    res = service.allocate_shipment(po.po_id, alloc_in)
    assert res.status == "IN_TRANSIT"

    # 2. Create with legacy alias "Received at Warehouse" -> normalized to "RECEIVED"
    alloc_in2 = POShipmentAllocationCreate(
        shipment_ref="BL-NORM-2",
        shipped_quantity=5.0,
        shipped_amount_fob=2500.0,
        status="Received at Warehouse",
    )
    res2 = service.allocate_shipment(po.po_id, alloc_in2)
    assert res2.status == "RECEIVED"

    # 3. Unknown allocation status raises 400
    with pytest.raises(HTTPException) as exc:
        alloc_invalid = POShipmentAllocationCreate(
            shipment_ref="BL-INVALID",
            shipped_quantity=1.0,
            shipped_amount_fob=500.0,
            status="Unknown Status",
        )
        service.allocate_shipment(po.po_id, alloc_invalid)
    assert exc.value.status_code == 400
    assert "غير معروفة" in exc.value.detail


# ==============================================================================
# 7. HTTP API Endpoints via TestClient
# ==============================================================================

def test_http_po_workflow_and_guards(db, master_data):
    po = _create_po(db, master_data, po_number="PO-HTTP-001")

    admin_user = User(
        user_id=1,
        username="admin",
        full_name="Admin User",
        email="admin@example.com",
        hashed_password="pw",
        role="Admin",
        is_active=True,
    )
    db.add(admin_user)
    db.commit()

    def override_get_db():
        yield db

    app = main.app
    app.dependency_overrides[get_db] = override_get_db

    try:
        from modules.auth.security import create_access_token
        token = create_access_token(data={"sub": str(admin_user.user_id), "role": "Admin"})
        headers = {"Authorization": f"Bearer {token}"}
        client = TestClient(app)

        # 1. PUT forbidden transition: DRAFT -> FULLY_SHIPPED -> 400
        put_resp = client.put(
            f"/api/v1/purchase-orders/{po.po_id}",
            json={"status": "FULLY_SHIPPED"},
            headers=headers,
        )
        assert put_resp.status_code == 400

        # 2. PUT transition: DRAFT -> APPROVED -> 200
        put_resp2 = client.put(
            f"/api/v1/purchase-orders/{po.po_id}",
            json={"status": "APPROVED"},
            headers=headers,
        )
        assert put_resp2.status_code == 200
        assert put_resp2.json()["status"] == "APPROVED"

        # 3. PUT transition: APPROVED -> CLOSED -> 200
        put_resp3 = client.put(
            f"/api/v1/purchase-orders/{po.po_id}",
            json={"status": "CLOSED"},
            headers=headers,
        )
        assert put_resp3.status_code == 200
        assert put_resp3.json()["status"] == "CLOSED"

        # 4. PUT on CLOSED PO -> 409 PO_NOT_EDITABLE
        put_resp4 = client.put(
            f"/api/v1/purchase-orders/{po.po_id}",
            json={"notes": "تعديل مرفوض"},
            headers=headers,
        )
        assert put_resp4.status_code == 409
        assert put_resp4.json()["detail"]["code"] == "PO_NOT_EDITABLE"

        # 5. POST allocation on CLOSED PO -> 409 PO_NOT_EDITABLE
        alloc_resp = client.post(
            f"/api/v1/purchase-orders/{po.po_id}/allocations",
            json={
                "shipment_ref": "BL-HTTP-01",
                "shipped_quantity": 10.0,
                "shipped_amount_fob": 5000.0,
            },
            headers=headers,
        )
        assert alloc_resp.status_code == 409
        assert alloc_resp.json()["detail"]["code"] == "PO_NOT_EDITABLE"

    finally:
        app.dependency_overrides.pop(get_db, None)
