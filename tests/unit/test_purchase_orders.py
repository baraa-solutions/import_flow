from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.audit_logs.model import AuditLog
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
        assert updated.status == "Approved"
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
        assert cloned_po.status == "Draft"
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


