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
            swift_no="SWIFT-EUR-15000",
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
            swift_no="SWIFT-USD-50000",
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

    def test_acc2_t04_readiness_on_net_payable_basis(self, db_session):
        """ACC2-T04: CLO-01 settlement_readiness_percent computed on net-payable basis."""
        # 1. goods 100,000 PAID + CL-05 invoice amount 50,000, wht_amount 1,500, net 48,500, Paid -> readiness 100.0, total_net_payable_egp 148,500.00
        imp1 = ImportFile(
            import_file_code="IMP-ACC2-04-1",
            company_name="Co",
            supplier_name="Sup",
            invoices_data=[{"invoice_no": "CI-1", "currency": "EGP", "amount": 100000.0, "payment_status": "PAID"}],
            is_active=True,
        )
        db_session.add(imp1)
        db_session.flush()

        inv1 = ClearanceExpenseInvoice(
            invoice_code="CEI-ACC2-1",
            import_file_id=imp1.import_file_id,
            invoice_number="CLI-1",
            provider_name="Broker",
            expense_category="CUSTOMS_CLEARANCE_FEES",
            currency="EGP",
            amount_egp=50000.0,
            vat_amount=0.0,
            wht_amount=1500.0,
            net_payable_egp=48500.0,
            payment_status="Paid",
            is_active=True,
        )
        db_session.add(inv1)
        db_session.commit()

        agg1 = aggregate_shipment_invoices_service(db_session, imp1.import_file_id)
        assert agg1.settlement_readiness_percent == 100.0
        assert agg1.total_net_payable_egp == 148500.0

        # 2. Broker 10,000 + VAT 1,400 - WHT 300 (net 11,100) Paid + goods 100,000 PAID -> 100.0
        imp2 = ImportFile(
            import_file_code="IMP-ACC2-04-2",
            company_name="Co",
            supplier_name="Sup",
            invoices_data=[{"invoice_no": "CI-2", "currency": "EGP", "amount": 100000.0, "payment_status": "PAID"}],
            is_active=True,
        )
        db_session.add(imp2)
        db_session.flush()

        inv2 = ClearanceExpenseInvoice(
            invoice_code="CEI-ACC2-2",
            import_file_id=imp2.import_file_id,
            invoice_number="CLI-2",
            provider_name="Broker",
            expense_category="CUSTOMS_CLEARANCE_FEES",
            currency="EGP",
            amount_egp=10000.0,
            vat_amount=1400.0,
            wht_amount=300.0,
            net_payable_egp=11100.0,
            payment_status="Paid",
            is_active=True,
        )
        db_session.add(inv2)
        db_session.commit()

        agg2 = aggregate_shipment_invoices_service(db_session, imp2.import_file_id)
        assert agg2.settlement_readiness_percent == 100.0

        # 3. Goods 100,000 PAID + transport 5,000 UNPAID (WHT rate 0) -> 100,000 / 105,000 = 95.2
        imp3 = ImportFile(
            import_file_code="IMP-ACC2-04-3",
            company_name="Co",
            supplier_name="Sup",
            invoices_data=[{"invoice_no": "CI-3", "currency": "EGP", "amount": 100000.0, "payment_status": "PAID"}],
            is_active=True,
        )
        db_session.add(imp3)
        db_session.flush()

        tr3 = InlandTransportBooking(
            transport_code="TR-3",
            waybill_number="WB-3",
            import_file_id=imp3.import_file_id,
            carrier_name="Trucker",
            truck_plate_number="س ب ع 1234",
            driver_name="أحمد حسن",
            driver_phone="01012345678",
            pickup_port_location="Alexandria Port",
            destination_warehouse="Cairo Depot",
            planned_departure_at=datetime.now(timezone.utc),
            expected_arrival_at=datetime.now(timezone.utc),
            transport_fare_egp=5000.0,
            status="Booked",
            is_active=True,
        )
        db_session.add(tr3)
        db_session.commit()

        agg3 = aggregate_shipment_invoices_service(db_session, imp3.import_file_id)
        assert agg3.settlement_readiness_percent == 95.2

    def test_be09_t13_confirm_readiness_gate_and_cairo_date(self, db_session, client, monkeypatch):
        """BE09-T13: CLO-01 confirm readiness gate (< 100% requires acknowledge_unpaid) and Cairo date."""
        from fastapi import HTTPException
        from modules.financial_settlement.service import cairo_today

        # 1. Setup file with 1 unpaid invoice (readiness 95.2%, 1 unpaid)
        imp = ImportFile(
            import_file_code="IMP-BE09-T13-01",
            company_name="Sorour Logistics Co.",
            supplier_name="Global Trading Co",
            invoices_data=[{"invoice_no": "INV-T13-1", "currency": "EGP", "amount": 100000.0, "payment_status": "PAID"}],
            is_active=True,
            current_stage="Stage 8: Inland Transport & Receiving",
        )
        db_session.add(imp)
        db_session.flush()

        # Unpaid transport: 5,000 EGP
        tr = InlandTransportBooking(
            transport_code="TR-T13-01",
            waybill_number="WB-T13-01",
            import_file_id=imp.import_file_id,
            carrier_name="Cairo Express",
            truck_plate_number="س ب ع 1234",
            driver_name="أحمد حسن",
            driver_phone="01012345678",
            pickup_port_location="Alexandria Port",
            destination_warehouse="Cairo Depot",
            planned_departure_at=datetime.now(timezone.utc),
            expected_arrival_at=datetime.now(timezone.utc),
            transport_fare_egp=5000.0,
            status="Booked",
            is_active=True,
        )
        db_session.add(tr)

        task_901 = SmartTask(
            task_code=f"TSK-0901-{imp.import_file_id}",
            title="تجميع وتسوية الفواتير الختامية للملف (CLO-01)",
            description="مراجعة وتجميع فواتير الشحنة",
            task_type="System Generated",
            import_file_id=imp.import_file_id,
            import_file_code=imp.import_file_code,
            phase_name="Stage 9: Landed Cost & File Closure",
            status="Pending",
        )
        db_session.add(task_901)
        db_session.commit()

        # 2. Try confirming with acknowledge_unpaid=False -> raises 409 INVOICES_NOT_READY
        req_unacknowledged = ConfirmInvoicesSettlementRequest(
            import_file_id=imp.import_file_id,
            acknowledge_unpaid=False,
        )
        with pytest.raises(HTTPException) as exc_info:
            confirm_invoices_settlement_service(db_session, req_unacknowledged, actor="Tester")
        assert exc_info.value.status_code == 409
        detail = exc_info.value.detail
        assert detail["code"] == "INVOICES_NOT_READY"
        assert detail["readiness"] == 95.2
        assert detail["unpaid_count"] == 1

        # Also verify HTTP 409 endpoint response
        api_res = client.post(
            "/api/v1/financial-settlement/confirm-invoices-settlement",
            json={"import_file_id": imp.import_file_id, "acknowledge_unpaid": False},
        )
        assert api_res.status_code == 409
        assert api_res.json()["detail"]["code"] == "INVOICES_NOT_READY"

        # 3. Confirm with acknowledge_unpaid=True -> 200 OK, sets Cairo date, appends note to TSK-0901
        req_acknowledged = ConfirmInvoicesSettlementRequest(
            import_file_id=imp.import_file_id,
            acknowledge_unpaid=True,
        )
        res = confirm_invoices_settlement_service(db_session, req_acknowledged, actor="Lead Auditor")
        assert res.success is True
        assert res.financial_settlement_status == "INVOICES_SETTLED"

        db_session.refresh(imp)
        assert imp.financial_settlement_date == cairo_today()
        assert res.financial_settlement_date == str(cairo_today())

        db_session.refresh(task_901)
        assert task_901.status == "Completed"
        assert "unpaid acknowledged" in task_901.notes

        # 4. Cairo date verification when UTC time is 23:30 (next Cairo day)
        from modules.financial_settlement import actual_settlement_service
        fake_cairo_date = date(2026, 12, 31)
        monkeypatch.setattr(actual_settlement_service, "cairo_today", lambda: fake_cairo_date)

        imp_late = ImportFile(
            import_file_code="IMP-BE09-T13-LATE",
            company_name="Late Test Co",
            supplier_name="Late Test Sup",
            invoices_data=[{"invoice_no": "INV-LATE", "currency": "EGP", "amount": 50000.0, "payment_status": "PAID"}],
            is_active=True,
        )
        db_session.add(imp_late)
        db_session.commit()

        res_late = confirm_invoices_settlement_service(
            db_session,
            ConfirmInvoicesSettlementRequest(import_file_id=imp_late.import_file_id),
            actor="Late Worker",
        )
        assert res_late.financial_settlement_date == "2026-12-31"
        db_session.refresh(imp_late)
        assert imp_late.financial_settlement_date == fake_cairo_date

