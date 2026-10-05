import pytest
from datetime import date, datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice
from modules.inland_transport.model import InlandTransportBooking
from modules.demurrage_detention.model import DemurrageTracking
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.schemas import (
    ActualLandedCostCalculationRequest,
    ApproveActualLandedCostRequest,
)
from modules.financial_settlement.service import (
    calculate_actual_landed_cost_service,
    approve_actual_landed_cost_service,
)

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
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


from modules.currencies.model import Currency, ExchangeRate
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.customs_tariff.model import CustomsTariff, FeeCode

def _seed_sample_shipment(db_session, file_code="IMP-2026-CLO02-01"):
    """Helper to seed a complete shipment with PO, line items, and invoices across modules."""
    # Setup Currency & Rate
    usd = db_session.query(Currency).filter(Currency.currency_code == "USD").first()
    if not usd:
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        db_session.add(usd)
        db_session.flush()

    rate = db_session.query(ExchangeRate).filter(ExchangeRate.currency_id == usd.currency_id).first()
    if not rate:
        rate = ExchangeRate(
            currency_id=usd.currency_id,
            customs_rate=50.0,
            commercial_rate=50.0,
            effective_date=date.today(),
            is_active=True,
        )
        db_session.add(rate)
        db_session.flush()

    supplier = db_session.query(Supplier).filter(Supplier.supplier_code == "SUP-DE-99").first()
    if not supplier:
        supplier = Supplier(
            supplier_code="SUP-DE-99",
            company_name="Bavaria Precision Tools GmbH",
            supplier_type="Manufacturer",
            registration_type="CargoX",
            foreign_exporter_id="EXP-DE-8899",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
            address="Munich, Germany",
            is_active=True,
        )
        db_session.add(supplier)
        db_session.flush()

    incoterm = db_session.query(Incoterm).filter(Incoterm.incoterm_code == "FOB").first()
    if not incoterm:
        incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
        db_session.add(incoterm)
        db_session.flush()

    project = db_session.query(Project).filter(Project.project_code == "PRJ-CLO02").first()
    if not project:
        project = Project(
            project_code="PRJ-CLO02",
            project_name="Precision Machine Expansion",
            project_owner="Kamal",
            company_id=1,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            is_active=True,
        )
        db_session.add(project)
        db_session.flush()

    imp = ImportFile(
        import_file_code=file_code,
        company_id=1,
        company_name="Sorour Logistics Co.",
        supplier_id=supplier.supplier_id,
        supplier_name="Bavaria Precision Tools GmbH",
        broker_name="Al-Amal Customs Brokerage",
        estimated_cost=25000.0,
        estimated_cost_currency="USD",
        progress_percent=98.5,
        current_stage="Stage 9: Landed Cost & File Closure",
        financial_settlement_status="INVOICES_SETTLED",
        invoices_data=[
            {
                "invoice_no": "INV-COMM-9912",
                "currency": "USD",
                "amount": 25000.0,
                "exchange_rate": 50.0,
                "payment_status": "PAID",
                "description": "Industrial Laser Cutters & Accessories",
            }
        ],
        swift_no="SWIFT-DE-2026-0099",
    )
    db_session.add(imp)
    db_session.flush()

    # Purchase Order with 2 Line Items
    po = PurchaseOrder(
        po_number=f"PO-2026-{file_code}",
        import_file_id=imp.import_file_id,
        project_id=project.project_id,
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        currency_id=usd.currency_id,
        total_amount_fob=25000.0,
        country_of_origin="DE",
        status="Approved",
        is_active=True,
    )
    db_session.add(po)
    db_session.flush()

    line1 = POLineItem(
        po_id=po.po_id,
        item_code="ITM-LASER-01",
        description_ar="ماكينة ليزر صناعية طراز أ",
        quantity=5.0,
        unit_price=3000.0,
        total_price=15000.0,
        gross_weight_kg=1500.0,
        total_cbm=12.0,
        country_of_origin="DE",
    )
    line2 = POLineItem(
        po_id=po.po_id,
        item_code="ITM-OPTIC-02",
        description_ar="رؤوس بصرية دقيقة",
        quantity=10.0,
        unit_price=1000.0,
        total_price=10000.0,
        gross_weight_kg=500.0,
        total_cbm=4.0,
        country_of_origin="DE",
    )
    db_session.add(line1)
    db_session.add(line2)

    # Freight Booking ($3,000 * 50 = 150,000 EGP)
    bkg = ShipmentBooking(
        booking_code="FRT-2026-902",
        booking_confirmation_no="BKG-HAPAG-7712",
        bill_of_lading_no="HLCU123456789",
        import_file_id=imp.import_file_id,
        freight_forwarder_name="Hapag-Lloyd Egypt",
        total_freight_cost_usd=3000.0,
        status="Confirmed",
        is_active=True,
    )
    db_session.add(bkg)

    # Cargo Insurance ($200 * 50 = 10,000 EGP)
    ins = CargoInsuranceCertificate(
        certificate_code="INS-2026-902",
        policy_number="POL-MISR-9921",
        import_file_id=imp.import_file_id,
        insurance_company_name="Misr Insurance Co.",
        insured_entity_name="Sorour Logistics",
        currency="USD",
        exchange_rate=50.0,
        total_payable_premium=200.0,
        port_of_loading="Hamburg",
        port_of_discharge="Alexandria",
    )
    db_session.add(ins)

    # Customs Duty & DO (160,000 EGP + 15,000 EGP)
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-902",
        import_file_id=imp.import_file_id,
        declaration_46_no="DECL-46-99221",
        total_duty_payable=160000.0,
        duty_paid_amount=160000.0,
        delivery_order_fees=15000.0,
        delivery_order_number="DO-REC-991",
        status="Final Release Granted",
        is_active=True,
    )
    db_session.add(clr)

    # Clearance Invoice (12,000 EGP)
    inv_c = ClearanceExpenseInvoice(
        invoice_code="INV-CLR-902",
        import_file_id=imp.import_file_id,
        provider_name="Al-Amal Customs Brokerage",
        invoice_number="INV-BRK-9901",
        expense_category="Customs Brokerage Fees",
        currency="EGP",
        amount_egp=12000.0,
        payment_status="Paid",
        is_active=True,
    )
    db_session.add(inv_c)

    # Inland Transport (18,000 EGP)
    trp = InlandTransportBooking(
        transport_code="TR-2026-902",
        waybill_number="WB-2026-902",
        import_file_id=imp.import_file_id,
        carrier_name="Al-Nile Heavy Transport",
        truck_plate_number="س ب ع 1234",
        driver_name="أحمد حسن",
        driver_phone="01012345678",
        driver_national_id="29001011234567",
        pickup_port_location="Alexandria Port",
        destination_warehouse="Cairo Warehouse",
        planned_departure_at=datetime.now(timezone.utc),
        expected_arrival_at=datetime.now(timezone.utc),
        transport_fare_egp=18000.0,
        status="Delivered",
        is_active=True,
    )
    db_session.add(trp)

    # Pending SmartTask TSK-0902
    tsk = SmartTask(
        task_code=f"TSK-0902-{imp.import_file_id}",
        title="احتساب تكلفة الوصول الفعلية وتوزيعها على الأصناف (CLO-02)",
        status="Pending",
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code,
    )
    db_session.add(tsk)

    db_session.commit()
    db_session.refresh(imp)
    return imp


class TestCLO02ActualLandedCost:

    def test_calculate_actual_landed_cost_allocation_rules(self, db_session):
        """CLO-02: احتساب تكلفة الوصول الفعلية وتوزيع المصاريف طبقا لقواعد التوزيع المختلفة (Value / Weight / Volume / Equal)"""
        imp = _seed_sample_shipment(db_session, "IMP-2026-CLO02-01")

        # 1. Test Value-Based Allocation
        req_val = ActualLandedCostCalculationRequest(allocation_preference="Value-Based")
        res_val = calculate_actual_landed_cost_service(db_session, imp.import_file_id, req_val)

        assert res_val.import_file_id == imp.import_file_id
        assert res_val.total_items_count == 2
        assert res_val.actual_total_fob_egp > 0
        assert res_val.actual_total_expenses_egp > 0
        assert res_val.actual_total_landed_cost_egp == res_val.actual_total_fob_egp + res_val.actual_total_expenses_egp
        assert res_val.actual_markup_factor > 1.0

        # Item 1 has 60% of FOB (15k / 25k), Item 2 has 40% (10k / 25k)
        item1 = res_val.items_breakdown[0]
        item2 = res_val.items_breakdown[1]
        assert item1.qty == 5.0
        assert item2.qty == 10.0
        assert item1.actual_unit_landed_cost_egp > item1.fob_unit_egp
        assert item2.actual_unit_landed_cost_egp > item2.fob_unit_egp
        # Sum of allocated expenses must equal total actual expenses
        sum_alloc = sum(itm.total_allocated_expenses_egp for itm in res_val.items_breakdown)
        assert abs(sum_alloc - res_val.actual_total_expenses_egp) < 1.0

        # 2. Test Weight-Based Allocation
        req_wt = ActualLandedCostCalculationRequest(allocation_preference="Weight-Based")
        res_wt = calculate_actual_landed_cost_service(db_session, imp.import_file_id, req_wt)
        assert res_wt.allocation_preference == "Weight-Based"
        # Item 1 is 1500kg / 2000kg = 75% of weight
        # Item 2 is 500kg / 2000kg = 25% of weight
        item1_wt = res_wt.items_breakdown[0]
        item2_wt = res_wt.items_breakdown[1]
        assert item1_wt.allocated_inland_transport_egp > item2_wt.allocated_inland_transport_egp

        # 3. Test Volume-Based Allocation
        req_vol = ActualLandedCostCalculationRequest(allocation_preference="Volume-Based")
        res_vol = calculate_actual_landed_cost_service(db_session, imp.import_file_id, req_vol)
        assert res_vol.allocation_preference == "Volume-Based"
        # Item 1 is 12 CBM / 16 CBM = 75% of volume
        item1_vol = res_vol.items_breakdown[0]
        item2_vol = res_vol.items_breakdown[1]
        assert item1_vol.allocated_freight_egp > item2_vol.allocated_freight_egp

    def test_actual_vs_estimated_variance_calculation(self, db_session):
        """CLO-02: التحقق من حساب الانحرافات بين التقديري والفعلي وتحديد حالة الميزانية (Variance Status)"""
        imp = _seed_sample_shipment(db_session, "IMP-2026-CLO02-02")

        res = calculate_actual_landed_cost_service(db_session, imp.import_file_id)

        # Check category breakdowns
        assert len(res.categories_breakdown) >= 6
        freight_cat = next((c for c in res.categories_breakdown if c.category == "Freight"), None)
        assert freight_cat is not None
        assert freight_cat.actual_egp > 0
        assert freight_cat.invoices_count >= 1

        customs_cat = next((c for c in res.categories_breakdown if c.category == "Customs Duty"), None)
        assert customs_cat is not None
        assert customs_cat.actual_egp == 160000.0

        # Check overall file variance
        assert res.variance_status in ("UNDER_BUDGET", "ON_BUDGET", "OVER_BUDGET")
        assert len(res.variance_status_ar) > 5
        assert len(res.executive_summary_ar) > 30

        # Check item variance status
        for itm in res.items_breakdown:
            assert itm.item_variance_status in ("SAVING", "MATCHED", "INCREASED")
            assert itm.actual_markup_factor >= 1.0

    def test_approve_actual_landed_cost_workflow(self, db_session):
        """CLO-02: اعتماد تكلفة الوصول الفعلية للشحنة وترقية مرحلة الملف وإغلاق TSK-0902 وإطلاق TSK-0903"""
        imp = _seed_sample_shipment(db_session, "IMP-2026-CLO02-03")

        app_req = ApproveActualLandedCostRequest(
            import_file_id=imp.import_file_id,
            approved_by="Financial Controller Magdy",
            allocation_preference="Value-Based",
            notes="تم تدقيق فواتير الشحن والتخليص ومطابقتها مع الإقرار الجمركي 46.",
        )
        app_res = approve_actual_landed_cost_service(db_session, app_req, actor="Financial Controller Magdy")  # FS-04: login user, not the body

        assert app_res.success is True
        assert app_res.financial_settlement_status == "COST_ALLOCATED"
        assert app_res.actual_landed_cost_total_egp > 0
        assert app_res.actual_landed_cost_markup_factor > 1.0
        assert app_res.progress_percent >= 99.0
        assert app_res.next_task_code.startswith("TSK-0903")
        assert "CLO-03" in app_res.next_task_title

        # Verify ImportFile updated
        db_session.refresh(imp)
        assert imp.financial_settlement_status == "COST_ALLOCATED"
        assert imp.actual_landed_cost_total_egp == app_res.actual_landed_cost_total_egp
        assert imp.actual_landed_cost_markup_factor == app_res.actual_landed_cost_markup_factor
        assert imp.actual_landed_cost_calculated_at is not None
        assert imp.progress_percent >= 99.0
        assert "CLO-03" in imp.next_action

        # Verify LandedCostSettlementRecord
        settlement = db_session.query(LandedCostSettlementRecord).filter(
            LandedCostSettlementRecord.import_file_id == imp.import_file_id
        ).first()
        assert settlement is not None
        assert settlement.status == "Approved"
        assert settlement.accountant_name == "Financial Controller Magdy"
        assert len(settlement.item_landed_costs) == 2

        # Verify SmartTask TSK-0902 closed
        task_902 = db_session.query(SmartTask).filter(
            SmartTask.task_code == f"TSK-0902-{imp.import_file_id}"
        ).first()
        assert task_902.status == "Completed"
        assert task_902.is_auto_closed is True

        # Verify SmartTask TSK-0903 created
        task_903 = db_session.query(SmartTask).filter(
            SmartTask.task_code == f"TSK-0903-{imp.import_file_id}"
        ).first()
        assert task_903 is not None
        assert task_903.status == "Pending"
        assert task_903.priority == "High"

        # Verify SystemNotification emitted
        notif = db_session.query(SystemNotification).filter(
            SystemNotification.entity_id == imp.import_file_id,
            SystemNotification.category == "FINANCIAL_SETTLEMENT",
        ).first()
        assert notif is not None
        assert "Actual landed cost approved" in notif.title
        assert notif.msg_code == "FS_LANDED_COST_APPROVED"

    def test_actual_landed_cost_api_endpoints(self, client, db_session):
        """CLO-02: اختبار نقاط النهاية REST API لحساب واعتماد تكلفة الوصول الفعلية"""
        imp = _seed_sample_shipment(db_session, "IMP-2026-CLO02-04")

        # 1. Test POST /calculate-actual-landed-cost/{import_file_id}
        calc_res = client.post(
            f"/api/v1/financial-settlement/calculate-actual-landed-cost/{imp.import_file_id}",
            json={"allocation_preference": "Value-Based"},
        )
        assert calc_res.status_code == 200
        data = calc_res.json()
        assert data["import_file_id"] == imp.import_file_id
        assert data["actual_total_landed_cost_egp"] > 0
        assert len(data["items_breakdown"]) == 2
        assert len(data["categories_breakdown"]) >= 6

        # 2. Test POST /approve-actual-landed-cost
        app_res = client.post(
            "/api/v1/financial-settlement/approve-actual-landed-cost",
            json={
                "import_file_id": imp.import_file_id,
                "approved_by": "Audit Lead Tamer",
                "allocation_preference": "Value-Based",
                "notes": "اعتماد مالي نهائي",
            },
        )
        assert app_res.status_code == 200
        app_data = app_res.json()
        assert app_data["success"] is True
        assert app_data["financial_settlement_status"] == "COST_ALLOCATED"
        assert app_data["progress_percent"] >= 99.0
        assert app_data["next_task_code"].startswith("TSK-0903")
