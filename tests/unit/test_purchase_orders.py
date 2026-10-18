from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.audit_logs.model import AuditLog
from modules.common.errors import CodedHTTPException
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.customs_tariff.schemas import CustomsTariffCreate
from modules.customs_tariff.service import create_tariff_service
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.schemas import ClonePurchaseOrderRequest, POLineItemCreate, PackingListItemCreate, PurchaseOrderCreate, PurchaseOrderUpdate
from modules.purchase_orders.service import PurchaseOrderService
from modules.suppliers.model import Supplier


from datetime import date, timedelta
from modules.import_companies.schemas import ImportCompanyCreate
from modules.import_companies.service import create_import_company

@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()

    # Seed prerequisites
    company_data = ImportCompanyCreate(
        importer_name="Test Importer",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100200",
        importer_id_expiry=date.today() + timedelta(days=120),
        vat_id="VAT-998877",
        vat_id_expiry=date.today() + timedelta(days=90),
        registration_number="REG-554433",
        registration_expiry=date.today() + timedelta(days=60),
    )
    company = create_import_company(session, company_data)
    supplier = Supplier(
        supplier_code="SUP-001",
        company_name="Test Supplier",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-123",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)

    session.add_all([company, supplier, incoterm, currency])
    session.commit()

    project = Project(
        project_code="PRJ-2026-001",
        project_name="Test Project",
        project_owner="Eng. Test",
        company_id=company.company_id,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        is_active=True,
    )
    session.add(project)
    session.commit()

    tariff_data = CustomsTariffCreate(
        hs_code="85414000",
        hs_description="Solar Panels",
        customs_duty_rate=Decimal("5.00"),
        vat_rate=Decimal("14.00"),
    )
    tariff = create_tariff_service(session, tariff_data)

    yield session
    session.close()


class TestPurchaseOrdersBackend:

    def test_create_purchase_order_with_line_items(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()
        tariff = db_session.query(CustomsTariff).first()

        item1 = POLineItemCreate(
            item_code="SOLAR-550",
            description_ar="ألواح شمسية 550 واط",
            description_en="Solar Panel 550W",
            tariff_id=tariff.tariff_id,
            quantity=100.0,
            unit_of_measure="PCS",
            unit_price=200.00,
            cbm_per_unit=0.2,
            gross_weight_kg=5000.0,
            net_weight_kg=4800.0,
        )

        create_data = PurchaseOrderCreate(
            proforma_invoice_number="PI-99001",
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inco.incoterm_id,
            currency_id=curr.currency_id,
            exchange_rate=50.0,
            payment_terms="LC at Sight",
            items=[item1],
        )

        po_resp = service.create(create_data)

        assert po_resp.po_id is not None
        assert po_resp.po_number.startswith("PO-")
        assert po_resp.total_amount_fob == 20000.00  # 100 * 200
        assert po_resp.total_cbm == 20.0  # 100 * 0.2
        assert po_resp.total_gross_weight_kg == 5000.0
        assert len(po_resp.items) == 1
        assert po_resp.items[0].hs_code == "85414000"

    def test_update_and_soft_delete_purchase_order(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        po_resp = service.create(
            PurchaseOrderCreate(
                project_id=proj.project_id,
                company_id=comp.company_id,
                supplier_id=supp.supplier_id,
                incoterm_id=inco.incoterm_id,
                currency_id=curr.currency_id,
                items=[],
            )
        )

        updated = service.update(po_resp.po_id, PurchaseOrderUpdate(status="Approved", notes="Approved for shipment"))
        assert updated.status == "APPROVED"  # legacy label in, PO_STATUS code out
        assert updated.notes == "Approved for shipment"

        deleted = service.soft_delete(po_resp.po_id)
        assert deleted.is_active is False

        restored = service.restore(po_resp.po_id)
        assert restored.is_active is True

    def test_packing_list_is_stackable_create_and_update(self, db_session):
        from modules.purchase_orders.schemas import PackingListItemCreate
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        pkg1 = PackingListItemCreate(
            hs_code="8415820010",
            item_code="ITEM-001",
            qty_pcs=2.0,
            qty_pkg=2.0,
            package_type="Pallet",
            length_cm=395.0,
            width_cm=225.0,
            height_cm=225.0,
            net_weight_unit_kg=1125.0,
            gross_weight_unit_kg=1135.0,
            is_stackable=False,
        )

        po = service.create(
            PurchaseOrderCreate(
                project_id=proj.project_id,
                company_id=comp.company_id,
                supplier_id=supp.supplier_id,
                incoterm_id=inco.incoterm_id,
                currency_id=curr.currency_id,
                items=[],
                packing_list_items=[pkg1],
            )
        )

        assert len(po.packing_list_items) == 1
        assert po.packing_list_items[0].is_stackable is False

        # Now update to is_stackable = True
        pkg1_updated = PackingListItemCreate(
            hs_code="8415820010",
            item_code="ITEM-001",
            qty_pcs=2.0,
            qty_pkg=2.0,
            package_type="Pallet",
            length_cm=395.0,
            width_cm=225.0,
            height_cm=225.0,
            net_weight_unit_kg=1125.0,
            gross_weight_unit_kg=1135.0,
            is_stackable=True,
        )

        updated_po = service.update(
            po.po_id,
            PurchaseOrderUpdate(
                packing_list_items=[pkg1_updated],
            ),
        )

        assert len(updated_po.packing_list_items) == 1
        assert updated_po.packing_list_items[0].is_stackable is True

        # Now update back to is_stackable = False
        pkg1_false = PackingListItemCreate(
            hs_code="8415820010",
            item_code="ITEM-001",
            qty_pcs=2.0,
            qty_pkg=2.0,
            package_type="Pallet",
            length_cm=395.0,
            width_cm=225.0,
            height_cm=225.0,
            net_weight_unit_kg=1125.0,
            gross_weight_unit_kg=1135.0,
            is_stackable=False,
        )

        updated_po2 = service.update(
            po.po_id,
            PurchaseOrderUpdate(
                packing_list_items=[pkg1_false],
            ),
        )

        assert len(updated_po2.packing_list_items) == 1
        assert updated_po2.packing_list_items[0].is_stackable is False

    def test_create_and_search_po_with_po_reference(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        po_data = PurchaseOrderCreate(
            po_number="PO-2026-REF01",
            po_reference="Chiller Units 500kW - Delta Plant",
            proforma_invoice_number="PI-DELTA-2026",
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inco.incoterm_id,
            currency_id=curr.currency_id,
            exchange_rate=50.0,
            items=[],
            packing_list_items=[],
        )

        po = service.create(po_data)
        assert po.po_id is not None
        assert po.po_reference == "Chiller Units 500kW - Delta Plant"

        # Test search by po_reference substring
        results = service.get_all(search="Delta Plant")
        assert len(results) >= 1
        assert any(p.po_number == "PO-2026-REF01" for p in results)

        # Test update po_reference
        updated_po = service.update(
            po.po_id,
            PurchaseOrderUpdate(po_reference="Updated Chiller Units 600kW"),
        )
        assert updated_po.po_reference == "Updated Chiller Units 600kW"

    def test_create_po_with_line_item_main_description(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        item = POLineItemCreate(
            item_code="PET-001",
            main_description="PET Acoustic Panels",
            description_ar="ألواح امتصاص صوت PET (YH-652)",
            description_en="PET Acoustic Panels (YH-652)",
            quantity=100.0,
            unit_of_measure="PCS",
            unit_price=15.5,
            cbm_per_unit=0.05,
            gross_weight_kg=250.0,
            net_weight_kg=240.0,
        )

        po_data = PurchaseOrderCreate(
            po_number="PO-2026-MAIN-DESC",
            proforma_invoice_number="INV-2026-MAIN",
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inco.incoterm_id,
            currency_id=curr.currency_id,
            exchange_rate=50.0,
            items=[item],
            packing_list_items=[],
        )

        po = service.create(po_data)
        assert po.po_id is not None
        assert len(po.items) == 1
        assert po.items[0].main_description == "PET Acoustic Panels"
        assert po.items[0].description_ar == "ألواح امتصاص صوت PET (YH-652)"

    def test_create_and_update_packing_list_main_description(self, db_session):
        service = PurchaseOrderService(db_session)

        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        pkg = PackingListItemCreate(
            hs_code="5602290000",
            item_code="PET-PKG-01",
            main_description="PET Acoustic Panels",
            description="PET Acoustic Panels (2400x1200x9mm) - 100 Cartons",
            qty_pcs=100.0,
            qty_pkg=10.0,
            package_type="Carton",
            length_cm=120.0,
            width_cm=60.0,
            height_cm=40.0,
            net_weight_unit_kg=20.0,
            gross_weight_unit_kg=22.0,
        )

        po_data = PurchaseOrderCreate(
            po_number="PO-2026-PKG-MAIN-DESC",
            proforma_invoice_number="INV-2026-PKG-MAIN",
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inco.incoterm_id,
            currency_id=curr.currency_id,
            exchange_rate=50.0,
            items=[],
            packing_list_items=[pkg],
        )

        po = service.create(po_data)
        assert po.po_id is not None
        assert len(po.packing_list_items) == 1
        assert po.packing_list_items[0].main_description == "PET Acoustic Panels"
        assert po.packing_list_items[0].description == "PET Acoustic Panels (2400x1200x9mm) - 100 Cartons"

        # Update packing list item main_description
        updated_pkg = PackingListItemCreate(
            hs_code="5602290000",
            item_code="PET-PKG-01",
            main_description="Engineered Acoustic Panels",
            description="Engineered Acoustic Panels (2400x1200x9mm) - 100 Cartons",
            qty_pcs=100.0,
            qty_pkg=10.0,
            package_type="Carton",
            length_cm=120.0,
            width_cm=60.0,
            height_cm=40.0,
            net_weight_unit_kg=20.0,
            gross_weight_unit_kg=22.0,
        )

        updated_po = service.update(
            po.po_id,
            PurchaseOrderUpdate(
                packing_list_items=[updated_pkg],
            ),
        )
        assert len(updated_po.packing_list_items) == 1
        assert updated_po.packing_list_items[0].main_description == "Engineered Acoustic Panels"

    def test_clone_purchase_order(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inco = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        # 1. Create source PO
        source_item = POLineItemCreate(
            item_code="CLONE-ITM-01",
            description_ar="بند تجريبي للاستنساخ",
            description_en="Test Item for Cloning",
            quantity=10.0,
            unit_price=50.0,
            unit_of_measure="PCS",
            cbm_per_unit=0.01,
            gross_weight_kg=100.0,
            net_weight_kg=90.0,
        )
        source_pkg = PackingListItemCreate(
            hs_code="84151000",
            item_code="CLONE-ITM-01",
            main_description="Packaged Item",
            qty_pcs=10.0,
            qty_pkg=2.0,
            package_type="Carton",
            length_cm=40.0,
            width_cm=30.0,
            height_cm=20.0,
            net_weight_unit_kg=45.0,
            gross_weight_unit_kg=50.0,
        )
        po_data = PurchaseOrderCreate(
            po_number="PO-2026-SOURCE",
            po_reference="Original Equipment Order",
            proforma_invoice_number="PI-ORIG-01",
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inco.incoterm_id,
            currency_id=curr.currency_id,
            exchange_rate=50.0,
            items=[source_item],
            packing_list_items=[source_pkg],
        )
        orig_po = service.create(po_data)
        assert orig_po.po_id is not None
        assert len(orig_po.items) == 1

        # 2. Clone the PO
        clone_payload = ClonePurchaseOrderRequest(
            new_po_number="PO-2026-CLONED",
            new_po_reference="Cloned Equipment Order",
            copy_items=True,
            copy_packing_list=True,
            copy_pallet_plan=True,
            notes="Cloned in automated test",
        )
        cloned_po = service.clone_purchase_order(orig_po.po_id, clone_payload)

        # 3. Verify cloned PO attributes
        assert cloned_po.po_id != orig_po.po_id
        assert cloned_po.po_number == "PO-2026-CLONED"
        assert cloned_po.po_reference == "Cloned Equipment Order"
        # Defaults are language-independent: reference (a code field) gets "-COPY", notes "Cloned from: <po_number>"
        default_clone = service.clone_purchase_order(
            orig_po.po_id, ClonePurchaseOrderRequest(new_po_number="PO-2026-CLONED-2")
        )
        assert default_clone.po_reference == "Original Equipment Order-COPY"
        assert default_clone.notes == "Cloned from: PO-2026-SOURCE"
        assert cloned_po.status == "DRAFT"
        assert cloned_po.import_file_id is None
        assert cloned_po.company_id == comp.company_id
        assert cloned_po.supplier_id == supp.supplier_id
        assert cloned_po.project_id == proj.project_id
        assert len(cloned_po.items) == 1
        assert cloned_po.items[0].item_id != orig_po.items[0].item_id
        assert cloned_po.items[0].description_ar == "بند تجريبي للاستنساخ"
        assert len(cloned_po.packing_list_items) == 1
        assert cloned_po.total_amount_fob == 500.0

        # 4. Verify duplicate code raises error
        with pytest.raises(Exception):
            service.clone_purchase_order(orig_po.po_id, clone_payload)

    def test_packing_list_weight_16_decimal_precision(self, db_session):
        service = PurchaseOrderService(db_session)
        comp = db_session.query(ImportCompany).first()
        supp = db_session.query(Supplier).first()
        inc = db_session.query(Incoterm).first()
        curr = db_session.query(Currency).first()
        proj = db_session.query(Project).first()

        high_prec_net = 72.98611111111111
        high_prec_gross = 75.12345678901234

        pkg_item = PackingListItemCreate(
            hs_code="8415.10.00",
            item_code="HIGH-PREC-01",
            main_description="High Precision Weight Test Item",
            description="Testing 16 decimal places in packing list",
            qty_pcs=10.0,
            qty_pkg=1.0,
            package_type="Carton",
            unit="cm",
            length_cm=50.0,
            width_cm=40.0,
            height_cm=30.0,
            net_weight_unit_kg=high_prec_net,
            gross_weight_unit_kg=high_prec_gross,
            weight_unit="KGM",
            is_stackable=True,
        )

        line_item = POLineItemCreate(
            item_code="HIGH-PREC-01",
            description_ar="صنف اختبار دقة الأوزان حتى 16 رقم عشري",
            description_en="High precision weight item",
            quantity=10.0,
            unit_of_measure="PCS",
            unit_price=100.0,
            cbm_per_unit=0.06,
            gross_weight_kg=high_prec_gross,
            net_weight_kg=high_prec_net,
        )

        po_data = PurchaseOrderCreate(
            po_number="PO-2026-PREC-16",
            po_reference="High Precision Weights Test",
            company_id=comp.company_id,
            supplier_id=supp.supplier_id,
            incoterm_id=inc.incoterm_id,
            currency_id=curr.currency_id,
            project_id=proj.project_id,
            exchange_rate=1.0,
            items=[line_item],
            packing_list_items=[pkg_item],
        )

        created_po = service.create(po_data)
        assert created_po.po_id is not None
        assert len(created_po.packing_list_items) == 1

        saved_pkg = created_po.packing_list_items[0]
        # Assert net and gross weights preserved up to 14-16 decimal digits
        assert abs(float(saved_pkg.net_weight_unit_kg) - high_prec_net) < 1e-12
        assert abs(float(saved_pkg.gross_weight_unit_kg) - high_prec_gross) < 1e-12
        assert abs(float(saved_pkg.total_net_weight_kg) - high_prec_net) < 1e-12
        assert abs(float(saved_pkg.total_gross_weight_kg) - high_prec_gross) < 1e-12


# =========================================================================================================
# Phase 1 regression tests (plan docs/plans/phase-01-quality-simplify-plan.md, PO-01..PO-18)
# =========================================================================================================

import importlib
from datetime import datetime

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.common.concurrency import ConcurrencyConflictException
from modules.common.system_parameters import AIR_VOLUMETRIC_KG_PER_CBM, SystemParameter
from modules.purchase_orders.model import POLineItem, PackingListItem, POShipmentAllocation, PurchaseOrder
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.schemas import PalletPlanItem, POShipmentAllocationCreate
from modules.users.model import Role, User

purchase_orders_router = importlib.import_module("modules.purchase_orders.router")


def _header(db, **overrides):
    data = dict(
        project_id=db.query(Project).first().project_id,
        company_id=db.query(ImportCompany).first().company_id,
        supplier_id=db.query(Supplier).first().supplier_id,
        incoterm_id=db.query(Incoterm).first().incoterm_id,
        currency_id=db.query(Currency).first().currency_id,
    )
    data.update(overrides)
    return data


def _line(**overrides):
    data = dict(item_code="L-1", description_ar="بند اختبار", quantity=100.0, unit_price=10.0,
                cbm_per_unit=0.01, gross_weight_kg=500.0, net_weight_kg=450.0)
    data.update(overrides)
    return POLineItemCreate(**data)


def _pkg(**overrides):
    data = dict(hs_code="85414000", item_code="L-1", qty_pcs=100.0, qty_pkg=10.0, length_cm=50.0, width_cm=40.0,
                height_cm=30.0, net_weight_unit_kg=45.0, gross_weight_unit_kg=50.0)
    data.update(overrides)
    return PackingListItemCreate(**data)


def _create(db, user="creator", **overrides):
    items = overrides.pop("items", [_line()])
    return PurchaseOrderService(db).create(PurchaseOrderCreate(items=items, **_header(db, **overrides)), current_user_name=user)


def _import_file(db, code="IMP-2026-0001", active=True):
    f = ImportFile(import_file_code=code, company_name="Importer", supplier_name="Supplier", is_active=active)
    db.add(f)
    db.commit()
    return f


def _alloc(db, po_id, qty, item_id=None, **kw):
    return PurchaseOrderService(db).allocate_shipment(
        po_id, POShipmentAllocationCreate(po_item_id=item_id, shipment_ref="BL-REG", shipped_quantity=qty,
                                          shipped_amount_fob=qty * 10.0, **kw),
        current_user_name="shipper",
    )


class TestPhase1Regressions:

    # ── PO-01: upsert by id ──

    def test_item_id_is_stable_and_allocations_keep_resolving(self, db_session):
        po = _create(db_session)
        item_id = po.items[0].item_id
        _alloc(db_session, po.po_id, 10.0, item_id=item_id)

        updated = PurchaseOrderService(db_session).update(
            po.po_id, PurchaseOrderUpdate(items=[_line(item_id=item_id, quantity=120.0), _line(item_code="L-2")])
        )
        assert updated.items[0].item_id == item_id
        assert len(updated.items) == 2
        assert updated.total_amount_fob == 2200.0  # 120 x 10 + 100 x 10
        alloc = db_session.query(POShipmentAllocation).one()
        assert alloc.po_item is not None and alloc.po_item.item_id == item_id
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert [b.shipped_qty for b in bal.line_items_balance if b.item_id == item_id] == [10.0]

    def test_removing_an_allocated_line_is_409(self, db_session):
        po = _create(db_session)
        _alloc(db_session, po.po_id, 10.0, item_id=po.items[0].item_id)
        with pytest.raises(HTTPException) as exc:
            PurchaseOrderService(db_session).update(po.po_id, PurchaseOrderUpdate(items=[_line()]))  # no item_id
        assert exc.value.status_code == 409
        assert exc.value.detail["code"] == "PO_ITEMS_ALLOCATED"
        assert exc.value.detail["item_ids"] == str(po.items[0].item_id)

    def test_foreign_or_duplicate_item_id_is_400(self, db_session):
        po = _create(db_session)
        other = _create(db_session, po_number="PO-OTHER-1")
        service = PurchaseOrderService(db_session)
        for rows in ([_line(item_id=other.items[0].item_id)], [_line(item_id=po.items[0].item_id)] * 2):
            with pytest.raises(HTTPException) as exc:
                service.update(po.po_id, PurchaseOrderUpdate(items=rows))
            assert exc.value.status_code == 400

    def test_packing_rows_upsert_keeps_pallet_and_carton_numbers(self, db_session):
        po = _create(db_session, packing_list_items=[_pkg()])
        pid = po.packing_list_items[0].packing_item_id
        row = db_session.get(PackingListItem, pid)
        row.pallet_number = 3
        row.carton_numbers = [1, 2, 3]
        db_session.commit()

        updated = PurchaseOrderService(db_session).update(
            po.po_id, PurchaseOrderUpdate(packing_list_items=[_pkg(packing_item_id=pid, qty_pkg=20.0)])
        )
        assert updated.packing_list_items[0].packing_item_id == pid
        assert updated.packing_list_items[0].qty_pkg == 20.0
        db_session.expire_all()
        kept = db_session.get(PackingListItem, pid)
        assert (kept.pallet_number, kept.carton_numbers) == (3, [1, 2, 3])

    # ── PO-02: explicit null on a NOT NULL field ──

    @pytest.mark.parametrize("field", ["project_id", "supplier_id", "currency_id", "exchange_rate", "status"])
    def test_null_required_field_on_update_is_400(self, db_session, field):
        po = _create(db_session)
        with pytest.raises(HTTPException) as exc:
            PurchaseOrderService(db_session).update(po.po_id, PurchaseOrderUpdate(**{field: None}))
        assert exc.value.status_code == 400

    def test_changed_fk_is_validated_but_unchanged_inactive_fk_is_not(self, db_session):
        po = _create(db_session)
        service = PurchaseOrderService(db_session)
        with pytest.raises(HTTPException) as exc:
            service.update(po.po_id, PurchaseOrderUpdate(supplier_id=99999))
        assert exc.value.status_code == 400 and "99999" in exc.value.detail
        db_session.query(Supplier).update({Supplier.is_active: False})
        db_session.commit()
        assert service.update(po.po_id, PurchaseOrderUpdate(notes="still editable")).notes == "still editable"

    # ── PO-03: status codes ──

    def test_status_codes_legacy_labels_and_unknown_status(self, db_session):
        po = _create(db_session)
        assert po.status == "DRAFT"
        service = PurchaseOrderService(db_session)
        with pytest.raises(HTTPException) as exc:
            service.update(po.po_id, PurchaseOrderUpdate(status="Lost at sea"))
        assert exc.value.status_code == 400
        assert service.update(po.po_id, PurchaseOrderUpdate(status="Approved")).status == "APPROVED"
        assert service.update(po.po_id, PurchaseOrderUpdate(status="cancelled")).status == "CANCELLED"

    def test_legacy_status_rows_are_returned_as_codes_and_filtered_by_label_or_code(self, db_session):
        po = _create(db_session)
        db_session.query(PurchaseOrder).update({PurchaseOrder.status: "Approved"})
        db_session.commit()
        service = PurchaseOrderService(db_session)
        assert service.get_by_id(po.po_id).status == "APPROVED"
        assert [p.po_id for p in service.get_all(status_filter="APPROVED")] == [po.po_id]
        assert [p.po_id for p in service.get_all(status_filter="Approved")] == [po.po_id]
        assert service.get_all(status_filter="DRAFT") == []

    @pytest.mark.parametrize("final", ["CANCELLED", "Closed"])
    def test_allocation_never_overwrites_a_closed_or_cancelled_po(self, db_session, final):
        po = _create(db_session)
        db_session.query(PurchaseOrder).update({PurchaseOrder.status: final})
        db_session.commit()
        with pytest.raises(CodedHTTPException) as exc:
            _alloc(db_session, po.po_id, 100.0)
        assert exc.value.status_code == 409
        assert exc.value.code == "PO_NOT_EDITABLE"
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == final

    # ── PO-04: allocation validation ──

    def test_item_over_allocation_is_allowed_with_warning(self, db_session):
        po = _create(db_session, items=[_line(item_code="A", quantity=10.0), _line(item_code="B", quantity=90.0)])
        item_a = po.items[0]
        ok = _alloc(db_session, po.po_id, 10.0, item_id=item_a.item_id)
        assert ok.messages == [] and ok.created_by == "shipper"
        over = _alloc(db_session, po.po_id, 5.0, item_id=item_a.item_id)
        assert over.allocation_id is not None
        assert [(m.code, m.params) for m in over.messages] == [
            ("OVER_SHIPPED", {"shipped_qty": 15.0, "ordered_qty": 10.0, "po_number": po.po_number, "item_code": "A"})
        ]
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == "PARTIALLY_SHIPPED"  # 15 of 100 overall

    def test_allocation_on_inactive_po_is_404(self, db_session):
        po = _create(db_session)
        PurchaseOrderService(db_session).soft_delete(po.po_id)
        with pytest.raises(HTTPException) as exc:
            _alloc(db_session, po.po_id, 1.0)
        assert exc.value.status_code == 404

    def test_allocation_with_unknown_or_inactive_import_file_is_400(self, db_session):
        po = _create(db_session)
        inactive = _import_file(db_session, active=False)
        for file_id in (inactive.import_file_id, 99999):
            with pytest.raises(HTTPException) as exc:
                _alloc(db_session, po.po_id, 1.0, import_file_id=file_id)
            assert exc.value.status_code == 400
        assert db_session.query(POShipmentAllocation).count() == 0
        active = _import_file(db_session, code="IMP-2026-0002")
        assert _alloc(db_session, po.po_id, 1.0, import_file_id=active.import_file_id).import_file_id == active.import_file_id

    def test_allocation_status_change_bumps_version_in_one_commit(self, db_session):
        po = _create(db_session)
        _alloc(db_session, po.po_id, 10.0)
        db_session.expire_all()
        stored = db_session.get(PurchaseOrder, po.po_id)
        assert (stored.status, stored.version, stored.updated_by) == ("PARTIALLY_SHIPPED", 2, "shipper")

    # ── PO-05: is_active no longer accepted on PUT ──

    def test_update_ignores_is_active(self, db_session):
        po = _create(db_session)
        updated = PurchaseOrderService(db_session).update(po.po_id, PurchaseOrderUpdate(is_active=False, notes="x"))
        assert updated.is_active is True and "is_active" not in PurchaseOrderUpdate.model_fields

    # ── PO-06: per-year numbering + retry ──

    def test_po_number_is_per_year_max_suffix(self, db_session):
        year = datetime.now().year
        _create(db_session, po_number=f"PO-{year}-041")
        _create(db_session, po_number=f"PO-{year}-REF01")
        assert _create(db_session).po_number == f"PO-{year}-042"

    def test_po_number_collision_is_retried(self, db_session, monkeypatch):
        year = datetime.now().year
        taken = _create(db_session, po_number=f"PO-{year}-007").po_number
        numbers = iter([taken, f"PO-{year}-008"])
        monkeypatch.setattr(PurchaseOrderRepository, "next_po_number", lambda self: next(numbers))
        po = _create(db_session)
        assert po.po_number == f"PO-{year}-008"
        assert db_session.query(PurchaseOrder).count() == 2

    def test_po_number_collision_gives_409_after_retries(self, db_session, monkeypatch):
        taken = _create(db_session, po_number="PO-TAKEN-1").po_number
        monkeypatch.setattr(PurchaseOrderRepository, "next_po_number", lambda self: taken)
        with pytest.raises(HTTPException) as exc:
            _create(db_session)
        assert exc.value.status_code == 409
        assert (exc.value.detail["code"], exc.value.detail["po_number"]) == ("PO_NUMBER_TAKEN", taken)

    # ── PO-07 / PO-09: single transaction + audit-by columns ──

    def test_audit_by_columns_and_import_file_link_in_one_transaction(self, db_session):
        imp = _import_file(db_session)
        po = _create(db_session, user="alice", import_file_id=imp.import_file_id, proforma_invoice_number="PI-9")
        assert (po.created_by, po.updated_by, po.import_file_code) == ("alice", "alice", "IMP-2026-0001")
        db_session.expire_all()
        assert po.po_id in db_session.get(ImportFile, imp.import_file_id).po_ids
        service = PurchaseOrderService(db_session)
        assert service.update(po.po_id, PurchaseOrderUpdate(notes="n"), current_user_name="bob").updated_by == "bob"
        deleted = service.soft_delete(po.po_id, current_user_name="carol")
        assert (deleted.is_active, deleted.updated_by) == (False, "carol")
        db_session.expire_all()
        assert po.po_id not in (db_session.get(ImportFile, imp.import_file_id).po_ids or [])
        restored = service.restore(po.po_id, current_user_name="dave")
        assert (restored.is_active, restored.updated_by) == (True, "dave")

    def test_failed_link_validation_leaves_no_po(self, db_session):
        with pytest.raises(HTTPException):
            _create(db_session, import_file_id=4242)
        assert db_session.query(PurchaseOrder).count() == 0

    # ── PO-10: optimistic lock in the service, conflict names the editor ──

    def test_stale_version_conflict_names_the_last_editor(self, db_session):
        po = _create(db_session)
        service = PurchaseOrderService(db_session)
        service.update(po.po_id, PurchaseOrderUpdate(notes="first", version=1), current_user_name="alice")
        with pytest.raises(ConcurrencyConflictException) as exc:
            service.update(po.po_id, PurchaseOrderUpdate(notes="stale", version=1), current_user_name="bob")
        assert exc.value.detail["updated_by"] == "alice"
        assert exc.value.detail["current_version"] == 2

    # ── PO-08: clone ──

    def test_clone_rejects_inactive_source_and_revalidates_master_data(self, db_session):
        po = _create(db_session)
        service = PurchaseOrderService(db_session)
        db_session.query(Supplier).update({Supplier.is_active: False})
        db_session.commit()
        with pytest.raises(HTTPException) as exc:
            service.clone_purchase_order(po.po_id, ClonePurchaseOrderRequest(new_po_number="PO-CL-1"))
        assert exc.value.status_code == 400
        db_session.query(Supplier).update({Supplier.is_active: True})
        db_session.commit()
        service.soft_delete(po.po_id)
        with pytest.raises(HTTPException) as exc:
            service.clone_purchase_order(po.po_id, ClonePurchaseOrderRequest(new_po_number="PO-CL-2"))
        assert exc.value.status_code == 404

    def test_clone_keeps_extraction_columns_and_pallet_plan(self, db_session):
        plan = [PalletPlanItem(pallet_count=2, length_cm=120.0, width_cm=80.0, height_cm=150.0, gross_weight_per_pallet_kg=300.0)]
        po = _create(db_session, packing_list_items=[_pkg()], pallet_plan=plan)
        line = db_session.get(POLineItem, po.items[0].item_id)
        line.invoice_number, line.invoice_line_number, line.customs_unit_price = "INV-7", 4, Decimal("9.5000")
        pkg = db_session.get(PackingListItem, po.packing_list_items[0].packing_item_id)
        pkg.invoice_number, pkg.pallet_number, pkg.carton_numbers = "INV-7", 2, [5, 6]
        db_session.commit()

        clone = PurchaseOrderService(db_session).clone_purchase_order(
            po.po_id, ClonePurchaseOrderRequest(new_po_number="PO-CL-3"), current_user_name="cloner")
        assert clone.created_by == "cloner"
        assert [p.pallet_count for p in clone.pallet_plan] == [2]
        assert (clone.total_cbm, clone.total_gross_weight_kg, clone.total_packages_count) == (2.88, 600.0, 2)
        new_line = db_session.get(POLineItem, clone.items[0].item_id)
        assert (new_line.invoice_number, new_line.invoice_line_number, float(new_line.customs_unit_price)) == ("INV-7", 4, 9.5)
        new_pkg = db_session.get(PackingListItem, clone.packing_list_items[0].packing_item_id)
        assert (new_pkg.invoice_number, new_pkg.pallet_number, new_pkg.carton_numbers) == ("INV-7", 2, [5, 6])

    # ── PO-13 / Q6: units ──

    def test_unknown_length_unit_is_rejected(self):
        with pytest.raises(ValidationError):
            _pkg(unit="in")
        assert _pkg(unit=" MM ").unit == "mm"
        assert _pkg(unit=None).unit == "cm"

    @pytest.mark.parametrize("given, stored", [(None, "KG"), ("", "KG"), ("kg", "KG"), ("KGS", "KG"), ("KGM", "KG"),
                                               ("grm", "GRM"), ("TON", "STN"), ("SET", "SET")])
    def test_weight_unit_is_normalized_and_persisted_without_conversion(self, db_session, given, stored):
        po = _create(db_session, packing_list_items=[_pkg(weight_unit=given)])
        row = po.packing_list_items[0]
        assert row.weight_unit == stored
        assert row.total_gross_weight_kg == 500.0  # 10 x 50 kg whatever the label says

    def test_legacy_kgm_rows_are_returned_as_kg(self, db_session):
        po = _create(db_session, packing_list_items=[_pkg()])
        db_session.query(PackingListItem).update({PackingListItem.weight_unit: "KGM"})
        db_session.commit()
        assert PurchaseOrderService(db_session).get_by_id(po.po_id).packing_list_items[0].weight_unit == "KG"

    def test_unknown_weight_unit_is_rejected(self):
        with pytest.raises(ValidationError):
            _pkg(weight_unit="LBS")

    # ── Q1: the configured volumetric factor feeds the chargeable weight ──

    def test_chargeable_weight_uses_the_system_parameter(self, db_session):
        db_session.add(SystemParameter(param_key=AIR_VOLUMETRIC_KG_PER_CBM, param_value="200"))
        db_session.commit()
        po = _create(db_session, packing_list_items=[_pkg(gross_weight_unit_kg=1.0, net_weight_unit_kg=1.0)])
        # 10 x 0.5 x 0.4 x 0.3 = 0.6 CBM x 200 = 120 kg > 10 kg gross
        assert po.packing_list_items[0].chargeable_weight_kg == 120.0

    # ── PO-14: coded report messages next to the English text ──

    def test_packing_report_messages_mirror_errors_and_warnings(self, db_session):
        po = _create(db_session, packing_list_items=[
            _pkg(item_code="BAD", gross_weight_unit_kg=10.0, net_weight_unit_kg=20.0, length_cm=0.0, hs_code="99999999"),
        ])
        report = PurchaseOrderService(db_session).get_packing_list_report(po.po_id)
        codes = [m.code for m in report.messages]
        assert codes[0] == "PO_PL_GROSS_BELOW_NET" and report.messages[0].severity == "error"
        assert "PO_PL_DIMENSIONS_MISSING" in codes and "PO_PL_HS_MISSING_IN_INVOICE" in codes
        assert len(report.messages) == len(report.errors) + len(report.warnings)
        assert report.errors[0] == "Item #1 (BAD): Gross weight per unit (10.0 kg) cannot be less than Net weight (20.0 kg)."
        empty = _create(db_session, po_number="PO-EMPTY-1")
        assert [m.code for m in PurchaseOrderService(db_session).get_packing_list_report(empty.po_id).messages] == ["PO_PL_NO_ITEMS"]

    def test_unknown_po_is_404_with_arabic_detail(self, db_session):
        with pytest.raises(HTTPException) as exc:
            PurchaseOrderService(db_session).get_by_id(4242)
        assert exc.value.status_code == 404 and "4242" in exc.value.detail

    # ── Lead finding (3) + Q2: header-only updates keep measured totals; apply_measurements ──

    def test_apply_measurements_bumps_version_and_header_update_keeps_them(self, db_session):
        po = _create(db_session, pallet_count=4, pallet_length_cm=120.0, pallet_width_cm=100.0, pallet_height_cm=160.0)
        assert (po.total_cbm, po.total_packages_count) == (7.68, 4)
        service = PurchaseOrderService(db_session)
        measured = service.apply_measurements(po.po_id, 10.5, 777.0, 9, "cbm-user")
        assert (measured.total_cbm, measured.total_gross_weight_kg, measured.total_packages_count) == (10.5, 777.0, 9)
        assert (measured.version, measured.updated_by) == (2, "cbm-user")

        header = service.update(po.po_id, PurchaseOrderUpdate(notes="header only", payment_terms="TT", version=2))
        assert (header.total_cbm, header.total_gross_weight_kg, header.total_packages_count) == (10.5, 777.0, 9)
        assert header.version == 3

        # a pallet field is a measurement change: totals are recomputed from the fallback again
        recomputed = service.update(po.po_id, PurchaseOrderUpdate(pallet_count=5))
        assert (recomputed.total_cbm, recomputed.total_packages_count) == (9.6, 5)

    def test_apply_measurements_rejects_inactive_po_and_keeps_none_values(self, db_session):
        po = _create(db_session)
        service = PurchaseOrderService(db_session)
        kept = service.apply_measurements(po.po_id, None, 123.0, None, "u", commit=False)
        assert (kept.total_cbm, kept.total_gross_weight_kg) == (1.0, 123.0)
        db_session.commit()
        service.soft_delete(po.po_id)
        with pytest.raises(HTTPException) as exc:
            service.apply_measurements(po.po_id, 1.0, 1.0, 1, "u")
        assert exc.value.status_code == 404


class TestBalanceAcrossUnits:
    """Lead finding (4): lines in different units must not be summed into the overall percentage."""

    def _po(self, db, fridge_price, bulb_price):
        return _create(db, items=[
            _line(item_code="FRIDGE", unit_of_measure="PCS", quantity=120.0, unit_price=fridge_price),
            _line(item_code="BULB", unit_of_measure="PCS", quantity=20000.0, unit_price=bulb_price),
        ])

    def test_overall_percent_is_value_weighted(self, db_session):
        po = self._po(db_session, 500.0, 1.0)
        fridge = next(i for i in po.items if i.item_code == "FRIDGE")
        _alloc(db_session, po.po_id, 60.0, item_id=fridge.item_id)
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        lines = {b.item_code: b for b in bal.line_items_balance}
        assert (lines["FRIDGE"].fulfillment_percent, lines["BULB"].fulfillment_percent) == (50.0, 0.0)
        # 60 x 500 shipped of 120 x 500 + 20000 x 1 ordered = 30000 / 80000 (not 60 / 20120 = 0.3 %)
        assert bal.overall_fulfillment_percent == 37.5
        assert (bal.total_ordered_qty, bal.total_shipped_qty) == (20120.0, 60.0)
        assert bal.fulfillment_status == "Partially Shipped"

    def test_without_prices_the_mean_of_line_percents_is_used(self, db_session):
        # lines in different units, all allocations on lines: (50 % + 0 %) / 2, not 60 / 20120 = 0.3 %
        po = self._po(db_session, 0.0, 0.0)
        fridge = next(i for i in po.items if i.item_code == "FRIDGE")
        _alloc(db_session, po.po_id, 60.0, item_id=fridge.item_id)
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert bal.overall_fulfillment_percent == 25.0
        assert "متوسط نسب البنود" in bal.executive_summary_ar

    def test_mixed_priced_and_unpriced_lines_use_the_line_mean(self, db_session):
        # customs review M3 (a): value share would say 100 % while line B is not shipped; (100 % + 0 %) / 2
        po = _create(db_session, items=[_line(item_code="A", quantity=100.0, unit_price=10.0),
                                        _line(item_code="B", quantity=100.0, unit_price=0.0)])
        _alloc(db_session, po.po_id, 100.0, item_id=po.items[0].item_id)
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert (bal.overall_fulfillment_percent, bal.fulfillment_status) == (50.0, "Partially Shipped")

    def test_po_level_allocation_without_fob_uses_the_quantity_share(self, db_session):
        # customs review M3 (b): a zero-FOB PO-level allocation would give 0 % while the PO is fully shipped
        po = _create(db_session, items=[_line(item_code="A", quantity=60.0), _line(item_code="B", quantity=40.0)])
        PurchaseOrderService(db_session).allocate_shipment(
            po.po_id, POShipmentAllocationCreate(shipment_ref="BL-0", shipped_quantity=100.0, shipped_amount_fob=0.0))
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert (bal.overall_fulfillment_percent, bal.fulfillment_status) == (100.0, "Fully Shipped")

    def test_unpriced_lines_with_po_level_allocation_count_its_quantity(self, db_session):
        # customs review M3 (c): the fallback counts the PO-level quantity
        po = _create(db_session, items=[_line(item_code="A", quantity=60.0, unit_price=0.0),
                                        _line(item_code="B", quantity=40.0, unit_price=0.0)])
        PurchaseOrderService(db_session).allocate_shipment(
            po.po_id, POShipmentAllocationCreate(shipment_ref="BL-1", shipped_quantity=25.0, shipped_amount_fob=0.0))
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert (bal.overall_fulfillment_percent, bal.fulfillment_status) == (25.0, "Partially Shipped")
        assert "حسب إجمالي الكميات" in bal.executive_summary_ar

    def test_value_share_summary_says_so(self, db_session):
        po = self._po(db_session, 500.0, 1.0)
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert "حسب القيمة التعاقدية" in bal.executive_summary_ar

    def test_status_needs_every_line_complete(self, db_session):
        po = self._po(db_session, 500.0, 1.0)
        ids = {i.item_code: i.item_id for i in po.items}
        _alloc(db_session, po.po_id, 120.0, item_id=ids["FRIDGE"])
        _alloc(db_session, po.po_id, 19999.0, item_id=ids["BULB"])
        service = PurchaseOrderService(db_session)
        assert service.compute_po_balance(po.po_id).fulfillment_status == "Partially Shipped"
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == "PARTIALLY_SHIPPED"
        _alloc(db_session, po.po_id, 1.0, item_id=ids["BULB"])
        assert service.compute_po_balance(po.po_id).fulfillment_status == "Fully Shipped"
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == "FULLY_SHIPPED"


# ── Router: delete / restore need purchase_orders.delete; audit user comes from the token ──

@pytest.fixture
def api(monkeypatch):
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    invalidate_permission_cache()
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    session = factory()
    seed_rbac(session)
    users = {}
    for code in ("ADMIN", "GENERAL_MANAGER", "LOGISTICS_OPERATOR", "AUDITOR_VIEWER"):
        role = session.query(Role).filter_by(role_code=code).one()
        user = User(username=f"u_{code.lower()}", email=f"{code.lower()}@test.com", full_name=code,
                    hashed_password=hash_password("Password123"), role=code, role_id=role.role_id, is_active=True)
        session.add(user)
        session.commit()
        users[code] = {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': code})}"}
    po = PurchaseOrder(po_number="PO-API-1", project_id=1, company_id=1, supplier_id=1, incoterm_id=1, currency_id=1,
                       status="DRAFT", is_active=True)
    session.add(po)
    session.commit()

    app = FastAPI()
    app.include_router(purchase_orders_router.router)

    def override_get_db():
        db = factory()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app), users, po.po_id, factory
    session.close()
    invalidate_permission_cache()
    engine.dispose()


@pytest.mark.parametrize("role", ["LOGISTICS_OPERATOR", "AUDITOR_VIEWER"])
def test_delete_and_restore_are_403_without_delete_permission(api, role):
    client, users, po_id, _ = api
    assert client.delete(f"/api/v1/purchase-orders/{po_id}", headers=users[role]).status_code == 403
    assert client.post(f"/api/v1/purchase-orders/{po_id}/restore", headers=users[role]).status_code == 403


def test_manager_can_delete_and_restore_and_is_recorded(api):
    client, users, po_id, _ = api
    resp = client.delete(f"/api/v1/purchase-orders/{po_id}", headers=users["GENERAL_MANAGER"])
    assert resp.status_code == 200, resp.text
    assert (resp.json()["is_active"], resp.json()["updated_by"]) == (False, "u_general_manager")
    resp = client.post(f"/api/v1/purchase-orders/{po_id}/restore", headers=users["ADMIN"])
    assert resp.status_code == 200 and resp.json()["updated_by"] == "u_admin"


def test_viewer_cannot_allocate_and_operator_put_records_user(api):
    client, users, po_id, _ = api
    body = {"shipment_ref": "BL-1", "shipped_quantity": 1.0, "shipped_amount_fob": 1.0}
    resp = client.post(f"/api/v1/purchase-orders/{po_id}/allocations", json=body, headers=users["AUDITOR_VIEWER"])
    assert resp.status_code == 403
    resp = client.put(f"/api/v1/purchase-orders/{po_id}", json={"notes": "op", "status": "Approved"},
                      headers=users["LOGISTICS_OPERATOR"])
    assert resp.status_code == 200, resp.text
    assert (resp.json()["status"], resp.json()["updated_by"]) == ("APPROVED", "u_logistics_operator")
    resp = client.put(f"/api/v1/purchase-orders/{po_id}", json={"project_id": None}, headers=users["LOGISTICS_OPERATOR"])
    assert resp.status_code == 400


def test_full_form_resave_after_cbm_push_keeps_the_measured_totals(api):
    """Review finding 3: the Flutter form resends lines, packing rows, pallet plan and pallet fields on every save."""
    client, users, po_id, factory = api
    db = factory()
    db.add(POLineItem(po_id=po_id, item_code="L-1", description_ar="بند", quantity=10, unit_price=12.5, total_price=125.0,
                      cbm_per_unit=0.1, total_cbm=1.0, gross_weight_kg=100.0, net_weight_kg=90.0))
    db.add(PackingListItem(po_id=po_id, hs_code="84151000", item_code="L-1", qty_pcs=10, qty_pkg=2, length_cm=50.0,
                           width_cm=40.0, height_cm=30.0, net_weight_unit_kg=45.0, gross_weight_unit_kg=50.0,
                           weight_unit="KGM", total_net_weight_kg=90.0, total_gross_weight_kg=100.0, total_cbm=0.12,
                           chargeable_weight_kg=100.0))
    db.commit()
    PurchaseOrderService(db).apply_measurements(po_id, 7.5, 999.0, 42, "cbm-user")
    db.close()

    form = client.get(f"/api/v1/purchase-orders/{po_id}", headers=users["ADMIN"]).json()
    form["notes"] = "only the notes changed"
    resp = client.put(f"/api/v1/purchase-orders/{po_id}", json=form, headers=users["ADMIN"])
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert (body["total_cbm"], body["total_gross_weight_kg"], body["total_packages_count"]) == (7.5, 999.0, 42)
    assert (body["notes"], body["version"]) == ("only the notes changed", form["version"] + 1)
    assert [i["item_id"] for i in body["items"]] == [i["item_id"] for i in form["items"]]

    # a real change in the same full form recomputes
    form = body
    form["items"][0]["quantity"] = 20
    resp = client.put(f"/api/v1/purchase-orders/{po_id}", json=form, headers=users["ADMIN"])
    assert resp.status_code == 200, resp.text
    assert resp.json()["total_amount_fob"] == 250.0
    assert resp.json()["total_cbm"] == 0.12  # packing CBM again (2 x 0.5 x 0.4 x 0.3)


@pytest.fixture
def measured_form(api):
    """A PO with two lines, one packing row and a pallet plan, CBM-pushed totals, and the full GET payload."""
    client, users, po_id, factory = api
    db = factory()
    for code in ("L-1", "L-2"):
        db.add(POLineItem(po_id=po_id, item_code=code, description_ar="بند", quantity=10, unit_price=12.5, total_price=125.0,
                          cbm_per_unit=0.1, total_cbm=1.0, gross_weight_kg=100.0, net_weight_kg=90.0))
    db.add(PackingListItem(po_id=po_id, hs_code="84151000", item_code="L-1", qty_pcs=10, qty_pkg=2, length_cm=50.0,
                           width_cm=40.0, height_cm=30.0, net_weight_unit_kg=45.0, gross_weight_unit_kg=50.0,
                           total_net_weight_kg=90.0, total_gross_weight_kg=100.0, total_cbm=0.12, chargeable_weight_kg=100.0))
    po = db.get(PurchaseOrder, po_id)
    po.pallet_plan = '[{"pallet_type": "Euro Pallet (120x80)", "pallet_count": 2, "length_cm": 120.0, "width_cm": 80.0, ' \
                     '"height_cm": 150.0, "gross_weight_per_pallet_kg": 0.0, "is_stackable": false, "notes": null}]'
    db.commit()
    PurchaseOrderService(db).apply_measurements(po_id, 7.5, 999.0, 42, "cbm-user")
    db.close()
    form = client.get(f"/api/v1/purchase-orders/{po_id}", headers=users["ADMIN"]).json()
    return client, users["ADMIN"], po_id, form


def _put(client, headers, po_id, form):
    resp = client.put(f"/api/v1/purchase-orders/{po_id}", json=form, headers=headers)
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_full_form_unchanged_resave_keeps_pushed_totals(measured_form):
    client, headers, po_id, form = measured_form
    body = _put(client, headers, po_id, dict(form, notes="n"))
    assert (body["total_cbm"], body["total_gross_weight_kg"], body["total_packages_count"]) == (7.5, 999.0, 42)


def test_full_form_removed_line_recomputes(measured_form):
    client, headers, po_id, form = measured_form
    form["items"] = form["items"][:1]
    body = _put(client, headers, po_id, form)
    assert len(body["items"]) == 1 and body["total_amount_fob"] == 125.0
    assert (body["total_cbm"], body["total_packages_count"]) == (2.88, 2)  # pallet plan wins again


def test_full_form_unit_price_change_recomputes(measured_form):
    client, headers, po_id, form = measured_form
    form["items"][0]["unit_price"] = 20.0
    body = _put(client, headers, po_id, form)
    assert body["total_amount_fob"] == 325.0  # 10 x 20 + 10 x 12.5
    assert body["total_cbm"] == 2.88


def test_full_form_pallet_plan_change_recomputes(measured_form):
    client, headers, po_id, form = measured_form
    form["pallet_plan"][0]["pallet_count"] = 3
    body = _put(client, headers, po_id, form)
    assert (body["total_cbm"], body["total_packages_count"], body["pallet_count"]) == (4.32, 3, 3)


def test_full_form_dimension_unit_change_recomputes(measured_form):
    client, headers, po_id, form = measured_form
    form["pallet_plan"] = []
    row = form["packing_list_items"][0]
    row.update(unit="m", length_cm=0.6, width_cm=0.4, height_cm=0.3)  # 60 cm instead of 50 cm
    body = _put(client, headers, po_id, form)
    assert body["packing_list_items"][0]["length_cm"] == 60.0
    assert body["total_cbm"] == 0.144  # 2 x 0.6 x 0.4 x 0.3


class TestReviewFindings:

    # ── finding 1: allocations pointing at a line that no longer exists ──

    def _orphan(self, db, po_id, qty):
        db.add(POShipmentAllocation(po_id=po_id, po_item_id=987654, shipment_ref="BL-OLD", shipped_quantity=qty,
                                    shipped_amount_fob=qty * 10.0))
        db.commit()

    def test_two_line_po_counts_orphan_allocations_at_po_level(self, db_session):
        po = _create(db_session, items=[_line(item_code="A", quantity=60.0), _line(item_code="B", quantity=40.0)])
        self._orphan(db_session, po.po_id, 60.0)
        _alloc(db_session, po.po_id, 40.0, item_id=po.items[1].item_id)
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == "FULLY_SHIPPED"  # 100 of 100, not downgraded
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert [b.shipped_qty for b in bal.line_items_balance] == [0.0, 40.0]
        assert (bal.total_shipped_qty, bal.fulfillment_status) == (100.0, "Fully Shipped")

    def test_single_line_po_attributes_orphan_allocations_to_the_line(self, db_session):
        po = _create(db_session, items=[_line(quantity=100.0)])
        self._orphan(db_session, po.po_id, 30.0)
        bal = PurchaseOrderService(db_session).compute_po_balance(po.po_id)
        assert bal.line_items_balance[0].shipped_qty == 30.0
        assert (bal.overall_fulfillment_percent, bal.fulfillment_status) == (30.0, "Partially Shipped")
        _alloc(db_session, po.po_id, 70.0, item_id=po.items[0].item_id)
        db_session.expire_all()
        assert db_session.get(PurchaseOrder, po.po_id).status == "FULLY_SHIPPED"

    # ── finding 2: legacy weight units on stored rows ──

    def test_clone_and_read_with_legacy_package_word_as_weight_unit(self, db_session):
        po = _create(db_session, packing_list_items=[_pkg()])
        db_session.query(PackingListItem).update({PackingListItem.weight_unit: "CTN"})
        db_session.commit()
        service = PurchaseOrderService(db_session)
        assert service.get_by_id(po.po_id).packing_list_items[0].weight_unit == "KG"
        clone = service.clone_purchase_order(po.po_id, ClonePurchaseOrderRequest(new_po_number="PO-CL-CTN"))
        assert clone.packing_list_items[0].weight_unit == "KG"

    # ── finding 5: delete / restore bump the version ──

    def test_delete_and_restore_bump_the_version_so_a_stale_form_conflicts(self, db_session):
        po = _create(db_session)
        service = PurchaseOrderService(db_session)
        assert service.soft_delete(po.po_id).version == 2
        assert service.restore(po.po_id).version == 3
        with pytest.raises(ConcurrencyConflictException):
            service.update(po.po_id, PurchaseOrderUpdate(notes="stale", version=1))
