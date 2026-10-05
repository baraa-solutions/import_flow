from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.customs_tariff.schemas import CustomsTariffCreate
from modules.customs_tariff.service import create_tariff_service
from modules.import_companies.schemas import ImportCompanyCreate
from modules.import_companies.service import create_import_company
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ImportFileCreate
from modules.import_files.service import create_import_file_service
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.projects.schemas import ProjectCreate
from modules.projects.service import ProjectService
from modules.purchase_orders.model import PurchaseOrder
from modules.purchase_orders.schemas import (
    POLineItemCreate,
    PackingListItemCreate,
    PalletPlanItem,
    PurchaseOrderCreate,
    PurchaseOrderUpdate,
)
from modules.purchase_orders.service import PurchaseOrderService
from modules.suppliers.model import Supplier


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()

    # 1. Company
    company_data = ImportCompanyCreate(
        importer_name="المتحدة للتوريدات الصناعية",
        address="العاشر من رمضان، المنطقة الصناعية",
        country="Egypt",
        importer_id="IMP-EG-2026-99",
        importer_id_expiry=date.today() + timedelta(days=365),
        vat_id="VAT-EG-112233",
        vat_id_expiry=date.today() + timedelta(days=365),
        registration_number="REG-EG-445566",
        registration_expiry=date.today() + timedelta(days=365),
    )
    company = create_import_company(session, company_data)

    # 2. Supplier
    supplier = Supplier(
        supplier_code="SUP-EU-001",
        company_name="Siemens Industrial Solutions GmbH",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-DE-889900",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Munich, Germany",
        is_active=True,
    )

    # 3. Incoterm
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)

    # 4. Currency
    currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)

    session.add_all([supplier, incoterm, currency])
    session.commit()

    # 5. Tariff
    tariff_data = CustomsTariffCreate(
        hs_code="8415820010",
        hs_description="وحدات تكييف وتبريد صناعية مركزية",
        customs_duty_rate=Decimal("5.00"),
        vat_rate=Decimal("14.00"),
    )
    tariff = create_tariff_service(session, tariff_data)

    # 6. Project with Budget
    prj_service = ProjectService(session)
    project_data = ProjectCreate(
        project_code="PRJ-2026-PL03",
        project_name="مشروع تطوير محطة تبريد وتكييف مصنع الدلتا",
        project_owner="م. أحمد الشناوي",
        company_id=company.company_id,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        import_type="Direct Commercial",
        priority="High",
        shipment_category="FCL Container",
        total_budget_usd=100000.0,
    )
    project = prj_service.create(project_data)

    # 7. Import File
    file_data = ImportFileCreate(
        company_id=company.company_id,
        company_name=company.importer_name,
        supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name,
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        priority="High",
        custom_file_number="IMP-PL03-001",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
        owner="م. أحمد الشناوي",
    )
    import_file = create_import_file_service(session, file_data)

    yield {
        "session": session,
        "company": company,
        "supplier": supplier,
        "incoterm": incoterm,
        "currency": currency,
        "tariff": tariff,
        "project": project,
        "import_file": import_file,
    }

    session.close()


class TestPL03PurchaseOrderRegistration:

    def test_po_creation_with_line_items_and_financial_calculations(self, db_session):
        session = db_session["session"]
        service = PurchaseOrderService(session)

        item1 = POLineItemCreate(
            item_code="CHILLER-500KW",
            main_description="Industrial Water Chiller 500kW",
            description_ar="وحدة تبريد مياه صناعية 500 كيلوواط",
            description_en="Industrial Water Chiller 500kW",
            tariff_id=db_session["tariff"].tariff_id,
            quantity=2.0,
            unit_of_measure="PCS",
            unit_price=25000.0,
            cbm_per_unit=12.5,
            gross_weight_kg=4500.0,
            net_weight_kg=4200.0,
        )

        item2 = POLineItemCreate(
            item_code="PUMP-CIRC-50",
            main_description="Primary Circulation Pumps",
            description_ar="طلمبات تدوير مياه التبريد الأولية",
            description_en="Primary Circulation Pumps",
            tariff_id=db_session["tariff"].tariff_id,
            quantity=4.0,
            unit_of_measure="PCS",
            unit_price=2500.0,
            cbm_per_unit=1.25,
            gross_weight_kg=350.0,
            net_weight_kg=320.0,
        )

        packing_item = PackingListItemCreate(
            hs_code="8415820010",
            item_code="CHILLER-500KW",
            main_description="Industrial Water Chiller 500kW",
            description="2 Heavy Duty Wooden Crates",
            qty_pcs=2.0,
            qty_pkg=2.0,
            package_type="Crate",
            length_cm=350.0,
            width_cm=200.0,
            height_cm=220.0,
            net_weight_unit_kg=4200.0,
            gross_weight_unit_kg=4500.0,
            is_stackable=False,
        )

        po_payload = PurchaseOrderCreate(
            po_reference="Delta Factory Cooling Units Order",
            proforma_invoice_number="PI-DE-2026-8801",
            country_of_origin="DE - Germany",
            project_id=db_session["project"].project_id,
            company_id=db_session["company"].company_id,
            supplier_id=db_session["supplier"].supplier_id,
            incoterm_id=db_session["incoterm"].incoterm_id,
            currency_id=db_session["currency"].currency_id,
            exchange_rate=50.0,
            payment_terms="LC at Sight / اعتماد مستندي",
            notes="شامل الضمان وكتالوجات التشغيل",
            items=[item1, item2],
            packing_list_items=[packing_item],
        )

        po = service.create(po_payload)

        # Verification of calculations
        assert po.po_id is not None
        assert po.po_number.startswith("PO-")
        assert po.po_reference == "Delta Factory Cooling Units Order"
        assert po.proforma_invoice_number == "PI-DE-2026-8801"
        assert po.country_of_origin == "DE - Germany"

        # Financial totals: (2 * 25000) + (4 * 2500) = 50000 + 10000 = 60000
        assert po.total_amount_fob == 60000.0
        # Volume totals: computed accurately from packing list crates: (350 * 200 * 220 / 1,000,000) * 2 = 30.8 m³
        assert po.total_cbm == 30.8
        # Weight totals: 4500 * 2 = 9000 kg gross weight from packing list
        assert po.total_gross_weight_kg == 9000.0
        assert po.total_net_weight_kg == 8400.0
        assert po.total_packages_count == 2  # 2 crates

        # Line items details
        assert len(po.items) == 2
        assert po.items[0].hs_code == "8415820010"
        assert po.items[0].duty_rate == 5.0
        assert po.items[0].vat_rate == 14.0
        assert len(po.packing_list_items) == 1
        assert po.packing_list_items[0].is_stackable is False

    def test_po_linking_to_import_file_bidirectional_sync(self, db_session):
        session = db_session["session"]
        service = PurchaseOrderService(session)
        import_file_id = db_session["import_file"].import_file_id

        po_data = PurchaseOrderCreate(
            po_reference="Linked Equipment Shipment Order",
            proforma_invoice_number="PI-LINK-001",
            import_file_id=import_file_id,
            project_id=db_session["project"].project_id,
            company_id=db_session["company"].company_id,
            supplier_id=db_session["supplier"].supplier_id,
            incoterm_id=db_session["incoterm"].incoterm_id,
            currency_id=db_session["currency"].currency_id,
            items=[],
        )

        po = service.create(po_data)
        assert po.import_file_id == import_file_id

        # Check ImportFile bidirectional sync
        session.expire_all()
        imp_file = session.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        assert imp_file.po_ids is not None
        assert po.po_id in imp_file.po_ids
        assert imp_file.po_number == po.po_number
        assert imp_file.pi_number == "PI-LINK-001"

        # Soft delete PO -> should remove link from import file
        service.soft_delete(po.po_id)
        session.expire_all()
        imp_file = session.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        assert po.po_id not in (imp_file.po_ids or [])

        # Restore PO -> should restore link to import file
        service.restore(po.po_id)
        session.expire_all()
        imp_file = session.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        assert po.po_id in imp_file.po_ids

    def test_po_project_financial_commitments_dashboard_effect(self, db_session):
        session = db_session["session"]
        po_service = PurchaseOrderService(session)
        prj_service = ProjectService(session)
        project_id = db_session["project"].project_id

        # 1. Check Initial Project State (Zero commitments)
        prj_resp = prj_service.get_by_id(project_id)
        assert prj_resp.total_budget_usd == 100000.0
        assert prj_resp.total_committed_usd == 0.0
        assert prj_resp.po_count == 0
        assert prj_resp.remaining_budget_usd == 100000.0

        # 2. Register PO 1 with $35,000
        item1 = POLineItemCreate(
            item_code="EQ-01",
            description_ar="معدات التبريد - الدفعة الأولى",
            quantity=1.0,
            unit_price=35000.0,
        )
        po1 = po_service.create(
            PurchaseOrderCreate(
                po_reference="PO #1 - First Batch",
                project_id=project_id,
                company_id=db_session["company"].company_id,
                supplier_id=db_session["supplier"].supplier_id,
                incoterm_id=db_session["incoterm"].incoterm_id,
                currency_id=db_session["currency"].currency_id,
                items=[item1],
            )
        )

        # Verify updated project commitments
        prj_resp = prj_service.get_by_id(project_id)
        assert prj_resp.total_committed_usd == 35000.0
        assert prj_resp.po_count == 1
        assert prj_resp.remaining_budget_usd == 65000.0

        # 3. Register PO 2 with $25,000
        item2 = POLineItemCreate(
            item_code="EQ-02",
            description_ar="معدات التبريد - الدفعة الثانية",
            quantity=5.0,
            unit_price=5000.0,
        )
        po2 = po_service.create(
            PurchaseOrderCreate(
                po_reference="PO #2 - Second Batch",
                project_id=project_id,
                company_id=db_session["company"].company_id,
                supplier_id=db_session["supplier"].supplier_id,
                incoterm_id=db_session["incoterm"].incoterm_id,
                currency_id=db_session["currency"].currency_id,
                items=[item2],
            )
        )

        # Verify updated project commitments with both POs
        prj_resp = prj_service.get_by_id(project_id)
        assert prj_resp.total_committed_usd == 60000.0
        assert prj_resp.po_count == 2
        assert prj_resp.remaining_budget_usd == 40000.0

        # 4. Check detailed financial commitments summary
        commitments = prj_service.get_financial_commitments(project_id)
        assert commitments["project_id"] == project_id
        assert commitments["total_budget_usd"] == 100000.0
        assert commitments["total_committed_usd"] == 60000.0
        assert commitments["remaining_budget_usd"] == 40000.0
        assert commitments["budget_utilization_percent"] == 60.0
        assert commitments["po_count"] == 2
        assert len(commitments["purchase_orders"]) == 2

        # 5. Soft-delete PO 2 -> commitments should automatically recalibrate
        po_service.soft_delete(po2.po_id)
        prj_resp_after_delete = prj_service.get_by_id(project_id)
        assert prj_resp_after_delete.total_committed_usd == 35000.0
        assert prj_resp_after_delete.po_count == 1
        assert prj_resp_after_delete.remaining_budget_usd == 65000.0

    def test_po_validation_guards(self, db_session):
        import pydantic
        session = db_session["session"]
        service = PurchaseOrderService(session)

        # 1. Inactive / Non-existent project
        with pytest.raises(HTTPException) as exc_info:
            service.create(
                PurchaseOrderCreate(
                    project_id=99999,
                    company_id=db_session["company"].company_id,
                    supplier_id=db_session["supplier"].supplier_id,
                    incoterm_id=db_session["incoterm"].incoterm_id,
                    currency_id=db_session["currency"].currency_id,
                    items=[],
                )
            )
        assert exc_info.value.status_code == 400
        assert "99999" in exc_info.value.detail  # Arabic detail (PO-16)

        # 2. Inactive / Non-existent import file
        with pytest.raises(HTTPException) as exc_info:
            service.create(
                PurchaseOrderCreate(
                    project_id=db_session["project"].project_id,
                    company_id=db_session["company"].company_id,
                    supplier_id=db_session["supplier"].supplier_id,
                    incoterm_id=db_session["incoterm"].incoterm_id,
                    currency_id=db_session["currency"].currency_id,
                    import_file_id=88888,
                    items=[],
                )
            )
        assert exc_info.value.status_code == 400
        assert "88888" in exc_info.value.detail

        # 3. Invalid / Non-existent tariff on item
        with pytest.raises(HTTPException) as exc_info:
            service.create(
                PurchaseOrderCreate(
                    project_id=db_session["project"].project_id,
                    company_id=db_session["company"].company_id,
                    supplier_id=db_session["supplier"].supplier_id,
                    incoterm_id=db_session["incoterm"].incoterm_id,
                    currency_id=db_session["currency"].currency_id,
                    items=[
                        POLineItemCreate(
                            item_code="BAD-HS",
                            description_ar="بند بتعريفة خاطئة",
                            tariff_id=77777,
                            quantity=10.0,
                            unit_price=100.0,
                        )
                    ],
                )
            )
        assert exc_info.value.status_code == 400
        assert "77777" in exc_info.value.detail

        # 4. Zero or Negative Quantity (rejected by Pydantic schema validation)
        with pytest.raises(pydantic.ValidationError):
            POLineItemCreate(
                item_code="BAD-QTY",
                description_ar="بند بكمية صفر",
                quantity=0.0,
                unit_price=100.0,
            )

        # 5. Negative Unit Price (rejected by Pydantic schema validation)
        with pytest.raises(pydantic.ValidationError):
            POLineItemCreate(
                item_code="BAD-PRICE",
                description_ar="بند بسعر سالب",
                quantity=10.0,
                unit_price=-50.0,
            )

        # 6. Duplicate PO Number
        po_existing = service.create(
            PurchaseOrderCreate(
                po_number="PO-2026-DUP-CHECK",
                project_id=db_session["project"].project_id,
                company_id=db_session["company"].company_id,
                supplier_id=db_session["supplier"].supplier_id,
                incoterm_id=db_session["incoterm"].incoterm_id,
                currency_id=db_session["currency"].currency_id,
                items=[],
            )
        )
        assert po_existing.po_id is not None

        with pytest.raises(HTTPException) as exc_info:
            service.create(
                PurchaseOrderCreate(
                    po_number="PO-2026-DUP-CHECK",
                    project_id=db_session["project"].project_id,
                    company_id=db_session["company"].company_id,
                    supplier_id=db_session["supplier"].supplier_id,
                    incoterm_id=db_session["incoterm"].incoterm_id,
                    currency_id=db_session["currency"].currency_id,
                    items=[],
                )
            )
        assert exc_info.value.status_code == 400
        assert "مستخدم بالفعل" in exc_info.value.detail
