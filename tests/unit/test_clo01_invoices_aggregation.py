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
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.financial_settlement.schemas import ConfirmInvoicesSettlementRequest
from modules.financial_settlement.service import (
    aggregate_shipment_invoices_service,
    confirm_invoices_settlement_service,
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
    from decimal import Decimal
    from modules.currencies.model import Currency, ExchangeRate
    from modules.currencies.service import clear_currency_cache

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    # Phase 09 (FS-02): foreign amounts need a configured rate (no hard-coded 48.5 any more).
    for code, rate in (("USD", "48.5"), ("EUR", "52.8")):
        cur = Currency(currency_code=code, currency_name=code, currency_symbol=code, is_active=True)
        db.add(cur)
        db.flush()
        db.add(ExchangeRate(currency_id=cur.currency_id, customs_rate=Decimal(rate), commercial_rate=Decimal(rate),
                            effective_date=date(2020, 1, 1), is_active=True))
    db.commit()
    clear_currency_cache()
    try:
        yield db
    finally:
        db.close()
        clear_currency_cache()
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


class TestCLO01InvoicesAggregation:

    def test_aggregate_invoices_multi_source_harvest(self, db_session):
        """CLO-01: تجميع الفواتير والمستندات المالية من كافة المصادر والمراحل السابقة"""
        # 1. Setup Import File with Commercial Goods
        imp = ImportFile(
            import_file_code="IMP-2026-CLO01-01",
            company_name="Sorour Logistics Co.",
            supplier_name="Bavaria Chemical GmbH",
            broker_name="Al-Amal Customs Brokerage",
            estimated_cost=20000.0,
            estimated_cost_currency="USD",
            progress_percent=95.0,
            current_stage="Stage 8: Inland Transport & Receiving",
            invoices_data=[
                {
                    "invoice_no": "INV-DE-8821",
                    "currency": "USD",
                    "amount": 20000.0,
                    "exchange_rate": 48.5,
                    "payment_status": "PAID",
                }
            ],
            swift_no="SWIFT-DE-2026-00192",
        )
        db_session.add(imp)
        db_session.flush()

        # 2. Freight Booking (Carrier / Freight Forwarder)
        booking = ShipmentBooking(
            booking_code="FRT-2026-001",
            booking_confirmation_no="BKG-MSC-9921",
            bill_of_lading_no="MSCU123456789",
            import_file_id=imp.import_file_id,
            freight_forwarder_name="Kuehne + Nagel Egypt",
            total_freight_cost_usd=2500.0,
            status="Confirmed",
            is_active=True,
        )
        db_session.add(booking)

        # 3. Cargo Insurance
        ins = CargoInsuranceCertificate(
            certificate_code="INS-2026-0001",
            policy_number="POL-MISR-7712",
            import_file_id=imp.import_file_id,
            insurance_company_name="Misr Insurance Co.",
            insured_entity_name="Sorour Logistics",
            currency="USD",
            exchange_rate=48.5,
            total_payable_premium=150.0,
            port_of_loading="Hamburg",
            port_of_discharge="Alexandria",
        )
        db_session.add(ins)

        # 4. Customs Clearance (Declaration 46 & Duty + Delivery Order)
        clearance = CustomsClearanceRecord(
            clearance_code="CLR-2026-001",
            import_file_id=imp.import_file_id,
            declaration_46_no="DECL-46-99120",
            total_duty_payable=120000.0,
            duty_paid_amount=120000.0,
            sadad_number="SADAD-2026-4412",
            payment_status="Paid & Verified",
            shipping_agent_name="MSC Egypt Agency",
            delivery_order_number="DO-MSC-881",
            delivery_order_fees=4500.0,
            delivery_order_status="Paid & Received",
        )
        db_session.add(clearance)

        # 5. Clearance Expense Invoices (CL-05: Broker Fee & Port Handling)
        cl_inv = ClearanceExpenseInvoice(
            invoice_code="INV-CLR-001",
            import_file_id=imp.import_file_id,
            invoice_number="INV-BRK-331",
            provider_name="Al-Amal Customs Brokerage",
            expense_category="Customs Brokerage Fees",
            currency="EGP",
            amount_egp=8000.0,
            wht_deducted=True,
            wht_amount=80.0,
            net_payable_egp=7920.0,
            payment_status="Paid",
            is_active=True,
        )
        db_session.add(cl_inv)

        # 6. Inland Transport (TR-01)
        tr = InlandTransportBooking(
            transport_code="TR-2026-001",
            waybill_number="WB-CAIRO-9921",
            import_file_id=imp.import_file_id,
            carrier_name="Alexandria Star Logistics",
            truck_plate_number="س ب ع 1234",
            driver_name="أحمد حسن",
            driver_phone="01012345678",
            pickup_port_location="Alexandria Port",
            destination_warehouse="Cairo 6th of October Depot",
            planned_departure_at=datetime.now(timezone.utc),
            expected_arrival_at=datetime.now(timezone.utc),
            transport_fare_egp=6000.0,
            status="Delivered",
            is_active=True,
        )
        db_session.add(tr)

        # 7. Demurrage & Detention (TR-02)
        demurrage = DemurrageTracking(
            port_name="Alexandria",
            tracking_code="DND-2026-001",
            import_file_id=imp.import_file_id,
            carrier_name="MSC",
            bill_of_lading_no="MSCU123456789",
            discharge_date=date(2026, 9, 1),
            total_demurrage_fx=100.0,
            currency="USD",
            exchange_rate=48.5,
            total_cost_egp=4850.0,
            is_pushed_to_settlement=True,
            status="Closed",
            is_active=True,
        )
        db_session.add(demurrage)

        db_session.commit()

        # Run service
        result = aggregate_shipment_invoices_service(db_session, imp.import_file_id)

        assert result.import_file_id == imp.import_file_id
        assert result.total_invoices_count >= 7
        assert len(result.parties_summary) >= 6

        # Check party types present
        party_types = [inv.party_type for inv in result.invoices]
        assert "SUPPLIER" in party_types
        assert "CARRIER" in party_types
        assert "INSURANCE" in party_types
        assert "CUSTOMS" in party_types
        assert "BROKER" in party_types
        assert "TRANSPORT" in party_types
        assert "DEMURRAGE" in party_types

        # Balance check: Total = Paid + Remaining
        assert result.total_amount_egp == pytest.approx(result.total_paid_egp + result.total_remaining_egp, 0.01)
        assert result.total_amount_egp > 1000000.0
        assert result.settlement_readiness_percent == 100.0

    def test_invoices_aggregation_with_unpaid_amounts(self, db_session):
        """CLO-01: التحقق من معالجة الفواتير غير المسددة وظهور التحذيرات المالية"""
        imp = ImportFile(
            import_file_code="IMP-2026-CLO01-02",
            company_name="Sorour Logistics Co.",
            supplier_name="Global Steel Inc",
            estimated_cost=10000.0,
            estimated_cost_currency="USD",
            invoices_data=[],
            total_clearance_expenses_egp=0.0,
        )
        db_session.add(imp)
        db_session.flush()

        # Unpaid inland transport booking
        tr = InlandTransportBooking(
            transport_code="TR-2026-002",
            waybill_number="WB-9944",
            import_file_id=imp.import_file_id,
            carrier_name="Cairo Express Trucking",
            truck_plate_number="ق ر ط 9988",
            driver_name="محمود السيد",
            driver_phone="01198765432",
            pickup_port_location="Dekheila Port",
            destination_warehouse="10th of Ramadan Warehouse",
            planned_departure_at=datetime.now(timezone.utc),
            expected_arrival_at=datetime.now(timezone.utc),
            transport_fare_egp=7500.0,
            status="In Transit",
            is_active=True,
        )
        db_session.add(tr)
        db_session.commit()

        result = aggregate_shipment_invoices_service(db_session, imp.import_file_id)

        assert result.total_remaining_egp > 0.0
        assert len(result.unsettled_warnings) > 0
        assert result.settlement_readiness_percent < 100.0

    def test_confirm_invoices_settlement_workflow(self, db_session):
        """CLO-01: اعتماد تسوية الفواتير وإغلاق TSK-0901 وإنشاء المهمة اللاحقة TSK-0902"""
        imp = ImportFile(
            import_file_code="IMP-2026-CLO01-03",
            company_name="Sorour Logistics Co.",
            supplier_name="Milan Leather SpA",
            estimated_cost=15000.0,
            estimated_cost_currency="EUR",
            progress_percent=95.0,
            current_stage="Stage 8: Inland Transport & Receiving",
        )
        db_session.add(imp)
        db_session.flush()

        # Existing Smart Task TSK-0901
        task_901 = SmartTask(
            task_code=f"TSK-0901-{imp.import_file_id}",
            title="تجميع وتسوية الفواتير الختامية للملف (CLO-01)",
            description="مراجعة وتجميع فواتير الشحنة",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 9: Landed Cost & File Closure",
            assigned_user="Cost Accounting Specialist",
            priority="High",
            status="Pending",
        )
        db_session.add(task_901)
        db_session.commit()

        # Run confirmation
        req = ConfirmInvoicesSettlementRequest(
            import_file_id=imp.import_file_id,
            settled_by="Ahmed Kamal",
            settlement_notes="تمت مراجعة ومطابقة كافة فواتير الشحنة بنجاح بدون فروقات",
        )
        res = confirm_invoices_settlement_service(db_session, req, actor="Ahmed Kamal")

        assert res.success is True
        assert res.financial_settlement_status == "INVOICES_SETTLED"
        assert res.progress_percent >= 98.5
        assert res.current_stage == "Stage 9: Landed Cost & File Closure"
        assert res.next_task_code == f"TSK-0902-{imp.import_file_id}"

        # Verify DB states
        db_session.refresh(imp)
        assert imp.financial_settlement_status == "INVOICES_SETTLED"
        assert imp.financial_settlement_invoices_count > 0
        assert imp.financial_settlement_total_egp > 0

        # Verify Task 901 is completed
        db_session.refresh(task_901)
        assert task_901.status == "Completed"
        assert task_901.is_auto_closed is True

        # Verify Task 902 created
        task_902 = db_session.query(SmartTask).filter(
            SmartTask.task_code == f"TSK-0902-{imp.import_file_id}"
        ).first()
        assert task_902 is not None
        assert "CLO-02" in task_902.title
        assert task_902.status == "Pending"

        # Verify SystemNotification created
        notif = db_session.query(SystemNotification).filter(
            SystemNotification.entity_id == imp.import_file_id,
            SystemNotification.category == "FINANCIAL_SETTLEMENT"
        ).first()
        assert notif is not None
        assert "Ahmed Kamal" in notif.message

    def test_api_endpoints_get_and_confirm(self, client, db_session):
        """CLO-01: اختبار نقاط النهاية API للتجميع والاعتماد عبر HTTP"""
        imp = ImportFile(
            import_file_code="IMP-2026-CLO01-04",
            company_name="Sorour Logistics Co.",
            supplier_name="Tokyo Electronics Ltd",
            estimated_cost=50000.0,
            estimated_cost_currency="USD",
            progress_percent=95.0,
            current_stage="Stage 8: Inland Transport & Receiving",
        )
        db_session.add(imp)
        db_session.commit()

        # 1. Test GET aggregation endpoint
        get_res = client.get(f"/api/v1/financial-settlement/invoices-aggregation/{imp.import_file_id}")
        assert get_res.status_code == 200
        get_data = get_res.json()
        assert get_data["import_file_id"] == imp.import_file_id
        assert get_data["import_file_code"] == "IMP-2026-CLO01-04"
        assert "invoices" in get_data
        assert "parties_summary" in get_data
        assert get_data["total_amount_egp"] > 0

        # 2. Test POST confirm endpoint
        post_payload = {
            "import_file_id": imp.import_file_id,
            "settled_by": "Mona Accounting",
            "settlement_notes": "Approved via API",
        }
        post_res = client.post("/api/v1/financial-settlement/confirm-invoices-settlement", json=post_payload)
        assert post_res.status_code == 200
        post_data = post_res.json()
        assert post_data["success"] is True
        assert post_data["financial_settlement_status"] == "INVOICES_SETTLED"
        assert post_data["progress_percent"] >= 98.5

        # 3. Test 404 on non-existent file
        res_404 = client.get("/api/v1/financial-settlement/invoices-aggregation/999999")
        assert res_404.status_code == 404
