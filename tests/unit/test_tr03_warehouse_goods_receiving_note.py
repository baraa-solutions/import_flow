import pytest
from datetime import datetime, date, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.inland_transport.model import InlandTransportBooking
from modules.demurrage_detention.model import DemurrageTracking
from modules.warehouse_receiving.schemas import (
    WarehouseReceivingCreate,
    GrnItemSchema,
    DiscrepancyReportSubmit,
)
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    report_receiving_discrepancy_service,
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


class TestWarehouseGoodsReceivingNoteTR03:

    def test_create_grn_and_synchronize_transport_and_timers(self, db_session, client):
        """إصدار إذن استلام البضاعة في المخزن وتحديث وصول الشاحنة وإيقاف عدادات النقل"""
        # 1. Create Import File
        imp_file = ImportFile(
            import_file_code="IMP-2026-0088",
            company_name="Al-Amal Co",
            supplier_name="Bavaria Tech",
            current_stage="In Transit to Warehouse",
            inland_transport_status="IN_TRANSIT",
            progress_percent=90.0,
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        # 2. Create an in-transit booking
        booking = InlandTransportBooking(
            transport_code="TR-2026-0088",
            import_file_id=imp_file.import_file_id,
            waybill_number="WB-2026-ALX-0088",
            carrier_name="Nile Logistics",
            truck_plate_number="ط د ر 7541",
            driver_name="Mohamed Ahmed",
            driver_phone="01012345678",
            pickup_port_location="Alexandria Port",
            destination_warehouse="Main Warehouse - Cairo",
            planned_departure_at=datetime.now(timezone.utc),
            expected_arrival_at=datetime.now(timezone.utc),
            status="In Transit",
            is_active=True,
        )
        db_session.add(booking)

        # 3. Create an active demurrage tracking with gate_out_date missing
        dem_tracking = DemurrageTracking(
            tracking_code="TRK-2026-0088",
            import_file_id=imp_file.import_file_id,
            import_file_code=imp_file.import_file_code,
            carrier_name="MSC",
            bill_of_lading_no="MEDU8888888",
            port_name="Alexandria Port",
            discharge_date=date.today(),
            gate_out_date=None,
            containers=[{"container_no": "MSCU8888888", "container_type": "40ft High Cube"}],
            total_demurrage_fx=0.0,
            total_detention_fx=0.0,
            total_storage_egp=0.0,
            currency="USD",
            exchange_rate=50.0,
            total_cost_egp=0.0,
            status="In Free Period",
            is_active=True,
        )
        db_session.add(dem_tracking)
        db_session.commit()

        # 4. Issue Warehouse Goods Receiving Note (GRN)
        grn_schema = WarehouseReceivingCreate(
            import_file_id=imp_file.import_file_id,
            warehouse_name="Main Warehouse - Cairo (6th of October)",
            arrival_datetime=datetime.now(timezone.utc),
            truck_plate_number="ط د ر 7541",
            driver_name="Mohamed Ahmed",
            driver_phone="01012345678",
            seal_number="SEAL-998822",
            seal_intact=True,
            grn_items=[
                GrnItemSchema(
                    item_code="SRV-101",
                    item_name="Industrial Servers",
                    invoiced_qty=50,
                    accepted_qty=48,
                    shortage_qty=1,
                    damaged_qty=1,
                ),
                GrnItemSchema(
                    item_code="SWT-202",
                    item_name="Network Switches",
                    invoiced_qty=100,
                    accepted_qty=100,
                    shortage_qty=0,
                    damaged_qty=0,
                ),
            ],
            inspector_name="Eng. Kamal",
            notes="تم فريغ البضاعة وتطابق الأختام",
        )

        record = create_warehouse_receiving_service(db_session, grn_schema)

        # Assertions on GRN Record
        assert record.receiving_id is not None
        assert record.grn_code.startswith("GRN-")
        assert record.total_invoiced_qty == 150
        assert record.total_accepted_qty == 148
        assert record.total_shortage_qty == 1
        assert record.total_damaged_qty == 1
        assert record.seal_intact is True

        # Assertions on Import File Sync
        db_session.refresh(imp_file)
        assert imp_file.inland_transport_status == "ARRIVED"
        assert imp_file.inland_actual_arrival_date is not None
        assert imp_file.progress_percent >= 98.0
        assert imp_file.current_stage == "Goods Received"
        assert imp_file.current_stage_code == "GOODS_RECEIVED"
        assert imp_file.next_action_code == "NA_TR_INSPECTION_DISCREPANCY_LANDED_COST"
        from modules.notifications.model import SystemNotification
        grn_notif = db_session.query(SystemNotification).filter(SystemNotification.msg_code == "WH_GRN_ISSUED").first()
        assert grn_notif is not None
        assert grn_notif.msg_params["grn_code"] == record.grn_code
        assert record.grn_code in grn_notif.title

        # Assertions on Inland Transport Booking Sync
        db_session.refresh(booking)
        assert booking.status == "Arrived at Warehouse"
        assert booking.actual_arrival_at is not None

        # Assertions on Demurrage Tracking Gate-Out timer stop
        db_session.refresh(dem_tracking)
        assert dem_tracking.gate_out_date is not None

        # Test API Endpoint GET /by-file/{import_file_id}
        res = client.get(f"/api/v1/warehouse-receiving/by-file/{imp_file.import_file_id}")
        assert res.status_code == 200
        data = res.json()
        assert data["grn_code"] == record.grn_code
        assert data["total_accepted_qty"] == 148

    def test_report_discrepancy_and_quarantine(self, db_session, client):
        """تسجيل محضر عجز وتلف وتحويل البضاعة لمنطقة الحجز المؤقت (Quarantine)"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-0089",
            company_name="Al-Amal Co",
            supplier_name="Global Tech",
            current_stage="Customs",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()
        db_session.refresh(imp_file)

        grn_schema = WarehouseReceivingCreate(
            import_file_id=imp_file.import_file_id,
            warehouse_name="Main Warehouse - Cairo",
            seal_intact=True,
            grn_items=[
                GrnItemSchema(
                    item_code="VALVE-01",
                    item_name="Hydraulic Valves",
                    invoiced_qty=20,
                    accepted_qty=15,
                    shortage_qty=5,
                    damaged_qty=0,
                )
            ],
            inspector_name="Hassan",
        )
        rec = create_warehouse_receiving_service(db_session, grn_schema)

        # Report discrepancy
        disc_req = DiscrepancyReportSubmit(
            discrepancy_type="Shortage",
            discrepancy_notes="عجز 5 صمامات عن الفاتورة المعتمدة",
            quarantine_zone_assigned=True,
            insurance_claim_filed=True,
            insurance_claim_ref="CLM-2026-VALVE-001",
        )
        updated = report_receiving_discrepancy_service(db_session, rec.receiving_id, disc_req)
        assert updated.discrepancy_type == "Shortage"
        assert updated.quarantine_zone_assigned is True
        assert updated.insurance_claim_filed is True
        assert updated.insurance_claim_ref == "CLM-2026-VALVE-001"
        assert updated.status == "Discrepancy Reported"

        # Via API
        res = client.post(
            f"/api/v1/warehouse-receiving/{rec.receiving_id}/report-discrepancy",
            json={
                "discrepancy_type": "Damage",
                "discrepancy_notes": "تلف كلي في الكرتونة",
                "quarantine_zone_assigned": True,
                "insurance_claim_filed": False,
            },
        )
        assert res.status_code == 200
        assert res.json()["discrepancy_type"] == "Damage"
