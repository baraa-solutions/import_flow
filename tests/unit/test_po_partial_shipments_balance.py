import pytest
from datetime import datetime, timezone, date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.purchase_orders.schemas import POShipmentAllocationCreate
from modules.purchase_orders.service import PurchaseOrderService


SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


class TestPOPartialShipmentsAndBalance:
    """
    LOG-PART-004: Partial Shipments Allocation & PO Remaining Balance Ledger.
    """

    def test_po_balance_and_partial_shipments_lifecycle(self, db_session):
        # 1. Setup Master Entities
        company = ImportCompany(
            importer_name="El-Sorour Industries",
            country="Egypt",
            address="Cairo Industrial Park",
            importer_id="IMP-SR-01",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="TAX-SR-01",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="REG-SR-01",
            registration_expiry=date(2030, 1, 1),
        )
        db_session.add(company)

        supplier = Supplier(
            company_name="Shanghai CNC Machinery Ltd",
            supplier_code="SUP-SH-001",
            supplier_type="Manufacturer",
            registration_type="Commercial Registration",
            foreign_exporter_id="CN-SH-8877",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Pudong High-Tech Zone, Shanghai",
        )
        db_session.add(supplier)

        incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board")
        db_session.add(incoterm)

        currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$")
        db_session.add(currency)

        db_session.commit()
        db_session.refresh(company)
        db_session.refresh(supplier)
        db_session.refresh(incoterm)
        db_session.refresh(currency)

        project = Project(
            project_name="Heavy CNC Line",
            project_code="PRJ-CNC-01",
            project_owner="Ahmed Sorour",
            company_id=company.company_id,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
        )
        db_session.add(project)
        db_session.commit()
        db_session.refresh(project)

        # 2. Create PO with 2 Line Items
        po = PurchaseOrder(
            po_number="PO-2026-CNC-001",
            project_id=project.project_id,
            company_id=company.company_id,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            currency_id=currency.currency_id,
            total_amount_fob=70000.0,
            status="Draft",
        )
        db_session.add(po)
        db_session.commit()
        db_session.refresh(po)

        item1 = POLineItem(
            po_id=po.po_id,
            item_code="CUTTER-CNC-01",
            description_ar="شفرات قطع كربيدية",
            quantity=600,
            unit_price=50.0,
            total_price=30000.0,
        )
        item2 = POLineItem(
            po_id=po.po_id,
            item_code="DRILL-CNC-02",
            description_ar="رؤوس حفر صناعية",
            quantity=400,
            unit_price=100.0,
            total_price=40000.0,
        )
        db_session.add_all([item1, item2])
        db_session.commit()
        db_session.refresh(item1)
        db_session.refresh(item2)

        service = PurchaseOrderService(db_session)

        # 3. Initial Balance check: 0% shipped, Pending
        initial_balance = service.compute_po_balance(po.po_id)
        assert initial_balance.total_ordered_qty == 1000.0
        assert initial_balance.total_shipped_qty == 0.0
        assert initial_balance.total_remaining_qty == 1000.0
        assert initial_balance.total_ordered_amount_fob == 70000.0
        assert initial_balance.overall_fulfillment_percent == 0.0
        assert initial_balance.fulfillment_status == "Pending"

        # 4. Allocate Partial Shipment 1 (300 units of Item 1)
        alloc1 = service.allocate_shipment(
            po.po_id,
            POShipmentAllocationCreate(
                po_item_id=item1.item_id,
                shipment_ref="B/L # MEDU-SH-101",
                shipped_quantity=300.0,
                shipped_amount_fob=15000.0,
                notes="الشحنة الأولى على خط MSC",
            ),
        )
        assert alloc1.shipped_quantity == 300.0
        assert po.status == "PARTIALLY_SHIPPED"  # stored as PO_STATUS code

        # 5. Allocate Partial Shipment 2 (200 units of Item 2)
        alloc2 = service.allocate_shipment(
            po.po_id,
            POShipmentAllocationCreate(
                po_item_id=item2.item_id,
                shipment_ref="B/L # CMA-SH-202",
                shipped_quantity=200.0,
                shipped_amount_fob=20000.0,
                notes="الشحنة الثانية على خط CMA CGM",
            ),
        )

        # 6. Check Balance after 2 Partial Shipments (50% fulfillment)
        mid_balance = service.compute_po_balance(po.po_id)
        assert mid_balance.total_shipped_qty == 500.0
        assert mid_balance.total_remaining_qty == 500.0
        assert mid_balance.total_shipped_amount_fob == 35000.0
        assert mid_balance.total_remaining_amount_fob == 35000.0
        assert mid_balance.overall_fulfillment_percent == 50.0
        assert mid_balance.fulfillment_status == "Partially Shipped"
        assert len(mid_balance.allocations) == 2

        # Item-level breakdown
        it1_bal = [b for b in mid_balance.line_items_balance if b.item_id == item1.item_id][0]
        it2_bal = [b for b in mid_balance.line_items_balance if b.item_id == item2.item_id][0]
        assert it1_bal.shipped_qty == 300.0
        assert it1_bal.remaining_qty == 300.0
        assert it1_bal.fulfillment_percent == 50.0
        assert it2_bal.shipped_qty == 200.0
        assert it2_bal.remaining_qty == 200.0
        assert it2_bal.fulfillment_percent == 50.0

        # 7. Complete Remaining Quantity (Shipment 3: remaining 300 + 200)
        service.allocate_shipment(
            po.po_id,
            POShipmentAllocationCreate(
                po_item_id=item1.item_id,
                shipment_ref="B/L # COSCO-SH-303",
                shipped_quantity=300.0,
                shipped_amount_fob=15000.0,
            ),
        )
        service.allocate_shipment(
            po.po_id,
            POShipmentAllocationCreate(
                po_item_id=item2.item_id,
                shipment_ref="B/L # COSCO-SH-303",
                shipped_quantity=200.0,
                shipped_amount_fob=20000.0,
            ),
        )

        # 8. Check Final Balance: 100% Shipped
        final_balance = service.compute_po_balance(po.po_id)
        assert final_balance.total_shipped_qty == 1000.0
        assert final_balance.total_remaining_qty == 0.0
        assert final_balance.overall_fulfillment_percent == 100.0
        assert final_balance.fulfillment_status == "Fully Shipped"
        assert po.status == "FULLY_SHIPPED"

    def test_api_po_balance_endpoints(self, client, db_session):
        # Create minimal entities
        company = ImportCompany(
            importer_name="Cairo Metals Co",
            country="Egypt",
            address="Helwan",
            importer_id="IMP-CR-01",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="TAX-CR-01",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="REG-CR-01",
            registration_expiry=date(2030, 1, 1),
        )
        db_session.add(company)
        supplier = Supplier(
            company_name="Tokyo Steel Co",
            supplier_code="SUP-TK-01",
            supplier_type="Manufacturer",
            registration_type="Commercial Registration",
            foreign_exporter_id="JP-9988",
            foreign_exporter_country="Japan",
            foreign_exporter_country_code="JP",
            address="Tokyo Bay",
        )
        db_session.add(supplier)
        incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board")
        db_session.add(incoterm)
        currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$")
        db_session.add(currency)
        db_session.commit()

        project = Project(
            project_name="Rail Expansion",
            project_code="PRJ-RAIL-01",
            project_owner="Ahmed Sorour",
            company_id=company.company_id,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
        )
        db_session.add(project)
        db_session.commit()

        po = PurchaseOrder(
            po_number="PO-RAIL-2026",
            project_id=project.project_id,
            company_id=company.company_id,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            currency_id=currency.currency_id,
            total_amount_fob=25000.0,
        )
        db_session.add(po)
        db_session.commit()

        item = POLineItem(
            po_id=po.po_id,
            item_code="RAIL-BEAM-01",
            description_ar="قضبان فولاذية",
            quantity=500,
            unit_price=50.0,
            total_price=25000.0,
        )
        db_session.add(item)
        db_session.commit()

        from modules.users.model import User
        from modules.auth.security import create_access_token

        # Create authenticated Admin user
        admin = User(
            user_id=101,
            username="admin_tester",
            email="admin@importflow.com",
            hashed_password="test_hash",
            full_name="Admin Tester",
            role="ADMIN",
            is_active=True,
        )
        db_session.add(admin)
        db_session.commit()

        token = create_access_token({"sub": "101", "role": "ADMIN"})
        auth_headers = {"Authorization": f"Bearer {token}"}

        # 1. Verify Invalid/Forged Token Request is rejected with 401 (Security IDOR / Access Control)
        unauth_resp = client.get(
            f"/api/v1/purchase-orders/{po.po_id}/balance",
            headers={"Authorization": "Bearer invalid.fake.token"},
        )
        assert unauth_resp.status_code == 401

        # 2. POST allocation with authorized Bearer Token
        resp1 = client.post(
            f"/api/v1/purchase-orders/{po.po_id}/allocations",
            headers=auth_headers,
            json={
                "po_item_id": item.item_id,
                "shipment_ref": "B/L # TOKYO-ALX-01",
                "shipped_quantity": 250.0,
                "shipped_amount_fob": 12500.0,
                "notes": "الدفعة الأولى 50%",
            },
        )
        assert resp1.status_code == 201
        data1 = resp1.json()
        assert data1["shipped_quantity"] == 250.0
        assert data1["shipment_ref"] == "B/L # TOKYO-ALX-01"

        # 3. GET balance with authorized Bearer Token
        resp2 = client.get(
            f"/api/v1/purchase-orders/{po.po_id}/balance",
            headers=auth_headers,
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["total_ordered_qty"] == 500.0
        assert data2["total_shipped_qty"] == 250.0
        assert data2["total_remaining_qty"] == 250.0
        assert data2["overall_fulfillment_percent"] == 50.0
        assert data2["fulfillment_status"] == "Partially Shipped"
