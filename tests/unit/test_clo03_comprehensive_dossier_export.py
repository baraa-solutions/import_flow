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
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.inland_transport.model import InlandTransportBooking
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.demurrage_detention.model import DemurrageTracking
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.currencies.model import Currency, ExchangeRate
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.file_closure.schemas import (
    DossierExportConfirmRequest,
    ComprehensiveShipmentDossierResponse,
    DossierExportConfirmResponse,
)
from modules.file_closure.service import (
    get_comprehensive_shipment_dossier_service,
    confirm_dossier_export_service,
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


def _seed_sample_full_shipment(db_session, file_code="IMP-2026-CLO03-01"):
    """Helper to seed a comprehensive 10-stage shipment."""
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

    supplier = db_session.query(Supplier).filter(Supplier.supplier_code == "SUP-DE-01").first()
    if not supplier:
        supplier = Supplier(
            supplier_code="SUP-DE-01",
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

    project = db_session.query(Project).filter(Project.project_code == "PRJ-CLO03").first()
    if not project:
        project = Project(
            project_code="PRJ-CLO03",
            project_name="Comprehensive Test Project",
            project_owner="Kamal",
            company_id=1,
            supplier_id=supplier.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            is_active=True,
        )
        db_session.add(project)
        db_session.flush()

    now_utc = datetime.now(timezone.utc)

    imp = ImportFile(
        import_file_code=file_code,
        company_id=1,
        company_name="Sorour Logistics Co.",
        supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name,
        status="Under Settlement",
        current_stage="Stage 9: Landed Cost & File Closure",
        current_module="CLO-02 Actual Landed Cost Calculation",
        progress_percent=99.0,
        next_action="إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)",
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        priority="High",
        product_category="Industrial Electronics & Machining Parts",
        port_of_loading="Hamburg Port",
        port_of_discharge="El Dekheila Port (non TMT)",
        acid_number="9876543210123456789",
        acid_issue_date=date(2026, 1, 15),
        acid_expiry_date=date(2026, 7, 15),
        form4_no="F4-2026-BANKEGY-001",
        swift_no="SWIFT-CAIRO-9921",
        bl_number="MEDU99221188",
        booking_no="BKG-MSC-9921",
        vessel_name="MSC LORETTO",
        cargox_envelope_id=1099,
        cargox_transferred_at=now_utc,
        form46_no="DEC-46-2026-00445",
        form46_date=now_utc,
        form46_status="ASSESSED_AND_RELEASED",
        is_customs_released=True,
        customs_release_permit_no="REL-PERMIT-2026-9912",
        customs_released_at=now_utc,
        customs_duty_paid_amount=155000.0,
        inland_carrier_name="El-Rowad Transport Fleet",
        inland_truck_plate_no="د هـ ق 9871",
        inland_driver_name="Mahmoud Salem",
        inland_transport_status="COMPLETED",
        inland_actual_arrival_date=now_utc,
        empty_containers_returned_at=now_utc,
        empty_containers_return_status="ALL_RETURNED",
        empty_containers_eir_numbers="EIR-MSC-88912, EIR-MSC-88913",
        empty_containers_depot_name="MSC Dekheila Yard 3",
        financial_settlement_status="COST_ALLOCATED",
        actual_landed_cost_total_egp=895400.0,
        actual_landed_cost_markup_factor=1.435,
        actual_landed_cost_variance_egp=15400.0,
        actual_landed_cost_variance_pct=1.75,
        actual_landed_cost_calculated_at=now_utc,
        is_active=True,
    )
    db_session.add(imp)
    db_session.flush()

    # Seed PO & Line Item
    po = PurchaseOrder(
        po_number=f"PO-{file_code}-01",
        po_reference="CNC Lathe Machines & Accessories",
        proforma_invoice_number="PI-BAV-2026-88",
        import_file_id=imp.import_file_id,
        project_id=project.project_id,
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        currency_id=usd.currency_id,
        total_amount_fob=12000.0,
        total_packages_count=100,
        total_gross_weight_kg=12500.0,
        total_cbm=45.0,
        status="Received",
        is_active=True,
    )
    db_session.add(po)
    db_session.flush()

    line_item = POLineItem(
        po_id=po.po_id,
        item_code="CNC-01",
        description_ar="ماكينات سي إن سي وملحقاتها",
        description_en="CNC Lathe Machine",
        quantity=5.0,
        unit_of_measure="SET",
        unit_price=2400.0,
        total_price=12000.0,
        total_cbm=45.0,
        gross_weight_kg=12500.0,
        net_weight_kg=11800.0,
    )
    db_session.add(line_item)

    # Seed CustomsClearanceRecord
    clearance = CustomsClearanceRecord(
        clearance_code=f"CLR-{file_code}",
        import_file_id=imp.import_file_id,
        declaration_46_no="DEC-46-2026-00445",
        customs_office_name="ميناء الدخيلة الجمركي",
        channel_type="Green Channel",
        broker_name="مكتب الأهرام للتخليص الجمركي",
        import_duty_amount=60000.0,
        vat_amount=84000.0,
        schedule_tax_amount=0.0,
        duty_paid_amount=155000.0,
        total_duty_payable=155000.0,
        release_permit_no="REL-PERMIT-2026-9912",
        release_date=now_utc,
        status="Final Release Granted",
        is_active=True,
    )
    db_session.add(clearance)

    # Seed InlandTransportBooking
    inland = InlandTransportBooking(
        transport_code=f"TR-{file_code}",
        import_file_id=imp.import_file_id,
        waybill_number="WB-2026-9921",
        carrier_name="El-Rowad Transport Fleet",
        truck_plate_number="د هـ ق 9871",
        driver_name="Mahmoud Salem",
        driver_phone="01099887766",
        pickup_port_location="El Dekheila Port",
        destination_warehouse="Cairo Main Warehouse",
        planned_departure_at=now_utc,
        expected_arrival_at=now_utc,
        actual_arrival_at=now_utc,
        transport_fare_egp=18500.0,
        status="Delivered",
        is_active=True,
    )
    db_session.add(inland)

    # Seed WarehouseReceivingRecord
    wh = WarehouseReceivingRecord(
        grn_code=f"GRN-2026-{imp.import_file_id:04d}",
        import_file_id=imp.import_file_id,
        warehouse_name="مستودع 6 أكتوبر المركزي",
        total_invoiced_qty=5,
        total_accepted_qty=5,
        total_shortage_qty=0,
        total_damaged_qty=0,
        seal_intact=True,
    )
    db_session.add(wh)

    # Seed LandedCostSettlementRecord
    settlement = LandedCostSettlementRecord(
        settlement_code=f"LCS-2026-{imp.import_file_id:04d}",
        import_file_id=imp.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[
            {"invoice_no": "INV-FRT-01", "category": "Freight", "amount_egp": 85000.0},
            {"invoice_no": "INV-CUS-01", "category": "Customs", "amount_egp": 155000.0},
            {"invoice_no": "INV-TRK-01", "category": "Inland Transport", "amount_egp": 18500.0},
        ],
        total_fob_egp=600000.0,
        total_expenses_egp=295400.0,
        total_landed_cost_egp=895400.0,
        average_markup_factor=1.492,
        item_landed_costs=[],
        status="Approved",
        accountant_name="Kamal - Senior Cost Accountant",
        is_active=True,
    )
    db_session.add(settlement)

    # Seed SmartTask TSK-0903
    task_903 = SmartTask(
        task_code=f"TSK-0903-{imp.import_file_id}",
        title="إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)",
        description="تصدير ومراجعة الملف الاستيرادي الشامل",
        task_type="System Generated",
        import_file_id=imp.import_file_id,
        import_file_code=imp.import_file_code,
        phase_name="Stage 9: Landed Cost & File Closure",
        assigned_user="Cost Accounting Manager",
        priority="High",
        status="Pending",
        is_active=True,
    )
    db_session.add(task_903)

    db_session.commit()
    db_session.refresh(imp)
    return imp


def test_get_comprehensive_dossier_service_success(db_session):
    imp = _seed_sample_full_shipment(db_session, "IMP-2026-DOSSIER-TEST-01")

    res = get_comprehensive_shipment_dossier_service(db_session, imp.import_file_id)

    assert isinstance(res, ComprehensiveShipmentDossierResponse)
    assert res.import_file_id == imp.import_file_id
    assert res.import_file_code == "IMP-2026-DOSSIER-TEST-01"
    assert res.company_name == "Sorour Logistics Co."
    assert "Bavaria Precision Tools" in res.supplier_name
    assert res.total_fob_fc == 12000.0
    assert res.fob_currency == "USD"
    assert res.items_count == 1
    assert res.acid_number == "9876543210123456789"
    assert res.form4_no == "F4-2026-BANKEGY-001"
    assert res.customs_declaration_no == "DEC-46-2026-00445"
    assert res.customs_channel == "Green Channel"
    assert res.customs_release_permit_no == "REL-PERMIT-2026-9912"
    assert res.inland_truck_plate_no == "د هـ ق 9871"
    assert res.warehouse_accepted_qty == 5
    assert "EIR-MSC-88912" in (res.empty_containers_eir_numbers or "")
    assert res.actual_landed_cost_total_egp == 895400.0
    assert res.financial_settlement_invoices_count == 3

    # Verify 10 sections
    assert len(res.sections) == 10
    sec_codes = [s.section_code for s in res.sections]
    assert sec_codes == [f"SEC-{i:02d}" for i in range(1, 11)]

    # Verify closure readiness
    assert res.closure_readiness["docs_verified"] is True
    assert res.closure_readiness["customs_cleared"] is True
    assert res.closure_readiness["warehouse_received"] is True
    assert res.closure_readiness["eir_returned"] is True
    assert res.closure_readiness["landed_cost_settled"] is True


def test_get_comprehensive_dossier_not_found(db_session):
    with pytest.raises(Exception) as exc:
        get_comprehensive_shipment_dossier_service(db_session, 999999)
    assert "غير موجود" in str(exc.value)


def test_confirm_dossier_export_service(db_session):
    imp = _seed_sample_full_shipment(db_session, "IMP-2026-DOSSIER-CONFIRM-01")

    payload = DossierExportConfirmRequest(
        import_file_id=imp.import_file_id,
        exported_by="Spoofed Exporter in Body",
        export_format="PDF & Excel Full Bundle",
        notes="تم تدقيق كافة بنود الملف الشامل ومطابقتها مع الحسابات.",
    )

    resp = confirm_dossier_export_service(
        db_session,
        payload,
        user="Eng. Ahmed Sorour - Managing Director",
    )

    assert isinstance(resp, DossierExportConfirmResponse)
    assert resp.success is True
    assert resp.import_file_id == imp.import_file_id
    assert resp.dossier_exported_by == "Eng. Ahmed Sorour - Managing Director"
    assert resp.progress_percent >= 99.5
    assert resp.next_task_code == f"TSK-0904-{imp.import_file_id}"

    # Verify ImportFile DB state
    db_session.refresh(imp)
    assert imp.dossier_exported_at is not None
    assert imp.dossier_exported_by == "Eng. Ahmed Sorour - Managing Director"
    assert imp.progress_percent >= 99.5
    assert imp.next_action == "Official closure and digital archiving of the file (CLO-04)"
    assert imp.next_action_code == "NA_CLO_OFFICIAL_CLOSURE"

    # Verify TSK-0903 auto-completed
    task_903 = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == imp.import_file_id,
        SmartTask.task_code.ilike("%0903%"),
    ).first()
    assert task_903.status == "Completed"
    assert task_903.is_auto_closed is True

    # Verify TSK-0904 dispatched
    task_904 = db_session.query(SmartTask).filter(
        SmartTask.task_code == f"TSK-0904-{imp.import_file_id}",
    ).first()
    assert task_904 is not None
    assert task_904.status == "Pending"
    assert "CLO-04" in task_904.title

    # Verify SystemNotification dispatched
    notif = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == imp.import_file_id,
        SystemNotification.category == "FILE_CLOSURE",
    ).first()
    assert notif is not None
    assert "Full dossier exported" in notif.title
    assert notif.msg_code == "CLO_DOSSIER_EXPORTED"


def test_api_get_comprehensive_dossier(client, db_session):
    imp = _seed_sample_full_shipment(db_session, "IMP-2026-API-DOSSIER-01")

    res = client.get(f"/api/v1/file-closure/comprehensive-dossier/{imp.import_file_id}")
    assert res.status_code == 200
    data = res.json()
    assert data["import_file_code"] == "IMP-2026-API-DOSSIER-01"
    assert len(data["sections"]) == 10
    assert data["actual_landed_cost_total_egp"] == 895400.0


def test_api_confirm_dossier_export(client, db_session):
    imp = _seed_sample_full_shipment(db_session, "IMP-2026-API-CONFIRM-01")

    body = {
        "import_file_id": imp.import_file_id,
        "exported_by": "Dr. Tarek Hegazy",
        "export_format": "PDF Full Dossier",
        "notes": "جاهز للأرشفة والمراجعة السنوية.",
    }
    res = client.post("/api/v1/file-closure/confirm-dossier-export", json=body)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["progress_percent"] >= 99.5
    assert "TSK-0904" in data["next_task_code"]
