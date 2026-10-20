import pytest
from datetime import datetime, date, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import (
    WarehouseInspectionSubmit,
    GrnItemSchema,
)
from modules.warehouse_receiving.service import (
    submit_warehouse_inspection_protocol_service,
    get_inspection_summary_service,
)

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


from modules.currencies.model import Currency
from datetime import datetime, date, timedelta, timezone


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    db.add(Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True))
    db.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    db.commit()
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


class TestWarehouseInspectionDiscrepancyTR04:

    def test_submit_inspection_protocol_with_discrepancies_and_claims(self, db_session):
        """TR-04: الفحص الفني ومحضر مطابقة العجز والتالف وحصر مطالبات التأمين والمورد"""
        # 1. Create Import File
        imp_file = ImportFile(
            import_file_code="IMP-2026-0099",
            company_name="Al-Amal Co",
            supplier_name="Bavaria Tech",
            current_stage="Goods Received at Main Warehouse (GRN: GRN-2026-0099)",
            inland_transport_status="ARRIVED",
            progress_percent=98.0,
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        # 2. Create Active Smart Task for TR-04
        smart_task = SmartTask(
            task_code="TSK-2026-0099",
            import_file_id=imp_file.import_file_id,
            title="الفحص الفني ومطابقة العجز والتالف (TR-04) - GRN-2026-0099",
            task_type="TR-04",
            status="In Progress",
            priority="Medium",
        )
        db_session.add(smart_task)

        # 3. Create Warehouse Receiving Record
        receiving_rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0099",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Main Warehouse - Cairo (6th of October)",
            arrival_datetime=datetime.now(timezone.utc),
            truck_plate_number="ط د ر 7541",
            driver_name="Mohamed Ahmed",
            seal_number="SEAL-8899",
            seal_intact=True,
            grn_items=[
                {"item_code": "ITM-01", "item_name": "Servers", "invoiced_qty": 100, "accepted_qty": 97, "shortage_qty": 1, "damaged_qty": 2, "quarantine_flag": False},
                {"item_code": "ITM-02", "item_name": "Cables", "invoiced_qty": 50, "accepted_qty": 50, "shortage_qty": 0, "damaged_qty": 0, "quarantine_flag": False},
            ],
            total_invoiced_qty=150,
            total_accepted_qty=147,
            total_shortage_qty=1,
            total_damaged_qty=2,
            status="Goods Received",
            is_active=True,
        )
        db_session.add(receiving_rec)
        db_session.commit()
        db_session.refresh(receiving_rec)

        # 4. Submit Inspection Protocol
        inspection_payload = WarehouseInspectionSubmit(
            inspection_date=datetime.now(timezone.utc),
            inspection_committee="لجنة الفحص الهندسي والمخزني (م. كمال، م. حسام)",
            inspection_verdict="ACCEPTED_WITH_DISCREPANCY",
            root_cause="Port Mishandling & Rough Transit Shock",
            discrepancy_type="Shortage & Damaged",
            discrepancy_notes="كسر في غلاف وحدتي خوادم وعجز صريح في وحدة واحدة",
            quarantine_zone_assigned=False,
            insurance_claim_filed=True,
            insurance_claim_ref="CLM-2026-INS-0099",
            supplier_claim_filed=True,
            supplier_claim_ref="CN-REQ-BAV-0099",
            claim_amount_estimated=35000.0,
            claim_currency="EGP",
            inspector_name="Eng. Kamal",
            notes="تم استبعاد التالف وعزل السليم في الموقع A-14",
        )

        record = submit_warehouse_inspection_protocol_service(
            db=db_session,
            record_id=receiving_rec.receiving_id,
            schema=inspection_payload,
            user_name="Quality Inspector",
        )

        # Assertions on Inspection Record
        assert record.inspection_protocol_number is not None
        assert record.inspection_protocol_number.startswith("INSP-")
        assert record.inspection_verdict == "ACCEPTED_WITH_DISCREPANCY"
        assert record.status == "Discrepancy Reported"
        assert record.total_shortage_qty == 1
        assert record.total_damaged_qty == 2
        # (3 / 150) * 100 = 2.0%
        assert record.discrepancy_rate_percent == 2.0
        assert record.root_cause == "Port Mishandling & Rough Transit Shock"
        assert record.insurance_claim_filed is True
        assert record.insurance_claim_ref == "CLM-2026-INS-0099"
        assert record.supplier_claim_filed is True
        assert record.claim_amount_estimated == 35000.0

        # Assertions on Import File
        db_session.refresh(imp_file)
        assert imp_file.current_stage_code == "DISCREPANCY_PROTOCOL_FILED"
        assert imp_file.next_action_code == "NA_FOLLOW_COMPENSATION_LANDED_COST"
        assert "Discrepancy Protocol Filed" in imp_file.current_stage
        assert "CLO-01" in imp_file.next_action
        assert imp_file.progress_percent >= 99.0

        # Assertions on SmartTask auto-resolution
        db_session.refresh(smart_task)
        assert smart_task.status == "Completed"
        assert smart_task.completed_at is not None
        assert "INSP-" in smart_task.resolution_notes

    def test_submit_clean_inspection_protocol_qc_passed(self, db_session):
        """TR-04: الفحص الفني المطابق بنسبة 100% واعتماد الانتقال لتكلفة الوصول CLO-02"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-0100",
            company_name="El-Nour Corp",
            supplier_name="Siemens AG",
            current_stage="Goods Received at Main Warehouse (GRN: GRN-2026-0100)",
            inland_transport_status="ARRIVED",
            progress_percent=98.0,
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        receiving_rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0100",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Main Warehouse - Cairo",
            arrival_datetime=datetime.now(timezone.utc),
            truck_plate_number="ق هـ ص 1234",
            driver_name="Ali Mahmoud",
            seal_number="SEAL-7711",
            seal_intact=True,
            grn_items=[
                {"item_code": "PLC-01", "item_name": "PLC Controllers", "invoiced_qty": 200, "accepted_qty": 200, "shortage_qty": 0, "damaged_qty": 0, "quarantine_flag": False},
            ],
            total_invoiced_qty=200,
            total_accepted_qty=200,
            total_shortage_qty=0,
            total_damaged_qty=0,
            status="Goods Received",
            is_active=True,
        )
        db_session.add(receiving_rec)
        db_session.commit()
        db_session.refresh(receiving_rec)

        clean_payload = WarehouseInspectionSubmit(
            inspection_date=datetime.now(timezone.utc),
            inspection_committee="لجنة الاستلام والرقابة",
            inspection_verdict="ACCEPTED_FULL",
            root_cause="None - Clean Delivery",
            grn_items=None,
            discrepancy_type="None",
            quarantine_zone_assigned=False,
            insurance_claim_filed=False,
            supplier_claim_filed=False,
            notes="البضاعة كاملة ومطابقة للمواصفات الفنية والفاتورة بنسبة 100%",
        )

        record = submit_warehouse_inspection_protocol_service(
            db=db_session,
            record_id=receiving_rec.receiving_id,
            schema=clean_payload,
        )

        assert record.inspection_verdict == "ACCEPTED_FULL"
        assert record.status == "Inspection Passed / Clean Receipt"
        assert record.discrepancy_rate_percent == 0.0

        db_session.refresh(imp_file)
        assert "QC Passed" in imp_file.current_stage
        assert "CLO-02" in imp_file.next_action

        # Check Summary
        summary = get_inspection_summary_service(db_session, record.receiving_id)
        assert summary.is_ready_for_landed_cost is True
        assert summary.inspection_verdict == "ACCEPTED_FULL"

    def test_inspection_protocol_api_endpoints(self, db_session, client):
        """TR-04: اختبار نقاط النهاية API لمحضر الفحص والمطابقة"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-0101",
            company_name="Tech Global",
            supplier_name="Lenovo EMEA",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        receiving_rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0101",
            import_file_id=imp_file.import_file_id,
            warehouse_name="6th October Warehouse",
            arrival_datetime=datetime.now(timezone.utc),
            seal_intact=True,
            grn_items=[
                {"item_code": "LAP-01", "item_name": "Laptops", "invoiced_qty": 50, "accepted_qty": 49, "shortage_qty": 1, "damaged_qty": 0, "quarantine_flag": False},
            ],
            total_invoiced_qty=50,
            total_accepted_qty=49,
            total_shortage_qty=1,
            total_damaged_qty=0,
            status="Goods Received",
            is_active=True,
        )
        db_session.add(receiving_rec)
        db_session.commit()
        db_session.refresh(receiving_rec)

        # 1. POST inspection protocol
        payload = {
            "inspection_committee": "لجنة فحص تكنولوجيا المعلومات",
            "inspection_verdict": "ACCEPTED_WITH_DISCREPANCY",
            "root_cause": "Supplier Factory Shortage",
            "discrepancy_type": "Shortage",
            "discrepancy_notes": "عجز عبوة واحدة من المورد",
            "quarantine_zone_assigned": False,
            "insurance_claim_filed": False,
            "supplier_claim_filed": True,
            "supplier_claim_ref": "CN-LENOVO-0101",
            "claim_amount_estimated": 1200.0,
            "claim_currency": "USD",
        }

        post_res = client.post(f"/api/v1/warehouse-receiving/{receiving_rec.receiving_id}/inspection-protocol", json=payload)
        assert post_res.status_code == 200
        data = post_res.json()
        assert data["inspection_protocol_number"].startswith("INSP-")
        assert data["supplier_claim_filed"] is True
        assert data["supplier_claim_ref"] == "CN-LENOVO-0101"
        assert data["discrepancy_rate_percent"] == 2.0

        # 2. GET inspection protocol summary
        get_res = client.get(f"/api/v1/warehouse-receiving/{receiving_rec.receiving_id}/inspection-protocol")
        assert get_res.status_code == 200
        summary_data = get_res.json()
        assert summary_data["inspection_protocol_number"] == data["inspection_protocol_number"]
        assert summary_data["supplier_claim_filed"] is True
        assert summary_data["total_shortage_qty"] == 1
        assert summary_data["is_ready_for_landed_cost"] is True
        assert summary_data["claim_amount_estimated"] == 1200.0
        assert summary_data["claim_currency"] == "USD"

    def test_claim_validation_negative_amount_yields_422(self, db_session, client):
        """BE810-T12: negative claim amount yields 422 validation error."""
        imp_file = ImportFile(import_file_code="IMP-2026-0102", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0102",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot A",
            grn_items=[{"item_code": "A", "item_name": "A", "invoiced_qty": 10, "accepted_qty": 10, "shortage_qty": 0, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        # POST inspection protocol with negative amount
        post_res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"claim_amount_estimated": -5.0, "claim_currency": "USD"},
        )
        assert post_res.status_code == 422

        # PUT update with negative amount
        put_res = client.put(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}",
            json={"claim_amount_estimated": -5.0},
        )
        assert put_res.status_code == 422

    def test_claim_validation_invalid_currency_yields_400(self, db_session, client):
        """BE810-T12: unknown or inactive currency yields 400 WR_CLAIM_CURRENCY_INVALID."""
        imp_file = ImportFile(import_file_code="IMP-2026-0103", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0103",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot B",
            grn_items=[{"item_code": "B", "item_name": "B", "invoiced_qty": 10, "accepted_qty": 8, "shortage_qty": 2, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        # POST inspection protocol with unknown currency "XYZ"
        post_res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"claim_amount_estimated": 1200.0, "claim_currency": "XYZ"},
        )
        assert post_res.status_code == 400
        detail = post_res.json()["detail"]
        assert detail["code"] == "WR_CLAIM_CURRENCY_INVALID"
        assert detail["currency_code"] == "XYZ"

        # PUT update with unknown currency "XYZ"
        put_res = client.put(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}",
            json={"claim_amount_estimated": 1200.0, "claim_currency": "XYZ"},
        )
        assert put_res.status_code == 400
        assert put_res.json()["detail"]["code"] == "WR_CLAIM_CURRENCY_INVALID"

    def test_claim_validation_lowercase_currency_normalized(self, db_session, client):
        """BE810-T12: lowercase currency is normalized to uppercase."""
        imp_file = ImportFile(import_file_code="IMP-2026-0104", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0104",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot C",
            grn_items=[{"item_code": "C", "item_name": "C", "invoiced_qty": 10, "accepted_qty": 8, "shortage_qty": 2, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        post_res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"claim_amount_estimated": 1200.0, "claim_currency": "usd"},
        )
        assert post_res.status_code == 200
        db_session.refresh(rec)
        assert rec.claim_amount_estimated == 1200.0
        assert rec.claim_currency == "USD"

    def test_claim_validation_zero_or_null_amount_stores_null(self, db_session, client):
        """BE810-T12: zero or absent claim amount stores None for amount and currency."""
        imp_file = ImportFile(import_file_code="IMP-2026-0105", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0105",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot D",
            grn_items=[{"item_code": "D", "item_name": "D", "invoiced_qty": 10, "accepted_qty": 10, "shortage_qty": 0, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        # Submit inspection with 0.0 amount
        post_res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"claim_amount_estimated": 0.0, "claim_currency": "USD"},
        )
        assert post_res.status_code == 200
        db_session.refresh(rec)
        assert rec.claim_amount_estimated is None
        assert rec.claim_currency is None

        # Check inspection summary returns None for both fields (BE810-T12)
        summary_res = client.get(f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol")
        assert summary_res.status_code == 200
        summary_data = summary_res.json()
        assert summary_data["claim_amount_estimated"] is None
        assert summary_data["claim_currency"] is None

        # PUT update to set claim, then PUT to clear
        put_res = client.put(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}",
            json={"claim_amount_estimated": 500.0, "claim_currency": "USD"},
        )
        assert put_res.status_code == 200
        db_session.refresh(rec)
        assert rec.claim_amount_estimated == 500.0
        assert rec.claim_currency == "USD"

        # Clear with None
        put_clear = client.put(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}",
            json={"claim_amount_estimated": None},
        )
        assert put_clear.status_code == 200
        db_session.refresh(rec)
        assert rec.claim_amount_estimated is None
        assert rec.claim_currency is None

        summary_clear = client.get(f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol")
        assert summary_clear.status_code == 200
        assert summary_clear.json()["claim_amount_estimated"] is None
        assert summary_clear.json()["claim_currency"] is None

    def test_be810_t19_clean_quantities_with_inconsistent_verdict_raises_expected_code(self, db_session, client):
        """BE810-T19: Clean quantities + inconsistent verdict -> 400 WR_VERDICT_INCONSISTENT_EXPECTED with expected_verdict."""
        imp_file = ImportFile(import_file_code="IMP-2026-0106", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0106",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot E",
            grn_items=[{"item_code": "E", "item_name": "E", "invoiced_qty": 10, "accepted_qty": 10, "shortage_qty": 0, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"inspection_verdict": "DAMAGE_CLAIM_PENDING"},
        )
        assert res.status_code == 400
        detail = res.json()["detail"]
        assert detail["code"] == "WR_VERDICT_INCONSISTENT_EXPECTED"
        assert detail["verdict"] == "DAMAGE_CLAIM_PENDING"
        assert detail["expected_verdict"] == "ACCEPTED_FULL"

    def test_be810_t19_report_discrepancy_rejects_none_type(self, db_session, client):
        """BE810-T19: Report discrepancy with type 'None' is rejected with 400 WR_DISCREPANCY_TYPE_INVALID."""
        imp_file = ImportFile(import_file_code="IMP-2026-0107", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0107",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot F",
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/report-discrepancy",
            json={"discrepancy_type": "None", "discrepancy_notes": "All good no discrepancy"},
        )
        assert res.status_code == 400
        detail = res.json()["detail"]
        assert detail["code"] == "WR_DISCREPANCY_TYPE_INVALID"

    def test_be810_t19_report_discrepancy_defaults_quarantine_false(self, db_session, client):
        """BE810-T19: Report discrepancy defaults quarantine_zone_assigned to False."""
        imp_file = ImportFile(import_file_code="IMP-2026-0108", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0108",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot G",
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/report-discrepancy",
            json={"discrepancy_type": "Shortage", "discrepancy_notes": "Missing 2 boxes"},
        )
        assert res.status_code == 200
        db_session.refresh(rec)
        assert rec.quarantine_zone_assigned is False

    def test_be810_t19_inspection_date_in_future_raises_400(self, db_session, client):
        """BE810-T19: Inspection date > now + 24 hours raises 400 WR_DATE_IN_FUTURE."""
        imp_file = ImportFile(import_file_code="IMP-2026-0109", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0109",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot H",
            grn_items=[{"item_code": "H", "item_name": "H", "invoiced_qty": 10, "accepted_qty": 10, "shortage_qty": 0, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        future_dt = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"inspection_date": future_dt},
        )
        assert res.status_code == 400
        detail = res.json()["detail"]
        assert detail["code"] == "WR_DATE_IN_FUTURE"

    def test_be810_t19_report_discrepancy_rejects_none_case_variations(self, db_session, client):
        """BE810-T19: Report discrepancy rejects 'none', '  None  ', and whitespace with 400 WR_DISCREPANCY_TYPE_INVALID."""
        imp_file = ImportFile(import_file_code="IMP-2026-0110", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0110",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot I",
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        for variant in ["none", "  None  ", ""]:
            res = client.post(
                f"/api/v1/warehouse-receiving/{rec.receiving_id}/report-discrepancy",
                json={"discrepancy_type": variant, "discrepancy_notes": "test note"},
            )
            assert res.status_code == 400
            assert res.json()["detail"]["code"] == "WR_DISCREPANCY_TYPE_INVALID"

    def test_be810_t19_discrepancy_quantities_with_clean_verdict_raises_expected_code(self, db_session, client):
        """BE810-T19: Discrepancy quantities + ACCEPTED_FULL verdict -> 400 WR_VERDICT_INCONSISTENT_EXPECTED with expected_verdict ACCEPTED_WITH_DISCREPANCY."""
        imp_file = ImportFile(import_file_code="IMP-2026-0111", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0111",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot J",
            grn_items=[{"item_code": "J", "item_name": "J", "invoiced_qty": 10, "accepted_qty": 8, "shortage_qty": 2, "damaged_qty": 0}],
            total_invoiced_qty=10,
            total_accepted_qty=8,
            total_shortage_qty=2,
            total_damaged_qty=0,
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"inspection_verdict": "ACCEPTED_FULL"},
        )
        assert res.status_code == 400
        detail = res.json()["detail"]
        assert detail["code"] == "WR_VERDICT_INCONSISTENT_EXPECTED"
        assert detail["verdict"] == "ACCEPTED_FULL"
        assert detail["expected_verdict"] == "ACCEPTED_WITH_DISCREPANCY"

    def test_be810_t19_quarantine_with_clean_verdict_raises_expected_code(self, db_session, client):
        """BE810-T19: Quarantine assigned + ACCEPTED_FULL verdict -> 400 WR_VERDICT_INCONSISTENT_EXPECTED with expected_verdict REJECTED_QUARANTINED."""
        imp_file = ImportFile(import_file_code="IMP-2026-0112", company_name="Tech Global", supplier_name="Lenovo EMEA", is_active=True)
        db_session.add(imp_file)
        db_session.commit()

        rec = WarehouseReceivingRecord(
            grn_code="GRN-2026-0112",
            import_file_id=imp_file.import_file_id,
            warehouse_name="Depot K",
            grn_items=[{"item_code": "K", "item_name": "K", "invoiced_qty": 10, "accepted_qty": 10, "shortage_qty": 0, "damaged_qty": 0}],
            status="Goods Received",
            is_active=True,
        )
        db_session.add(rec)
        db_session.commit()

        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/inspection-protocol",
            json={"quarantine_zone_assigned": True, "inspection_verdict": "ACCEPTED_FULL"},
        )
        assert res.status_code == 400
        detail = res.json()["detail"]
        assert detail["code"] == "WR_VERDICT_INCONSISTENT_EXPECTED"
        assert detail["verdict"] == "ACCEPTED_FULL"
        assert detail["expected_verdict"] == "REJECTED_QUARANTINED"
