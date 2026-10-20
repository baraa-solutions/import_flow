import pytest
from datetime import date, datetime, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.demurrage_detention.model import DemurrageTracking, DemurragePolicy
from modules.demurrage_detention.schemas import EmptyContainerReturnSubmit
from modules.demurrage_detention.service import (
    record_empty_container_return_service,
    get_containers_radar_overview_service,
)
from modules.smart_tasks.model import SmartTask

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


class TestEmptyContainerReturnServiceAndAPI:

    def test_record_empty_container_return_all_containers_success(self, db_session):
        """إرجاع كافة حاويات الشحنة بالكامل وإيقاف العدادات ونقل الملف للمرحلة 9"""
        # 1. Setup Policy
        policy = DemurragePolicy(
            carrier_name="MSC",
            container_type="40ft High Cube",
            demurrage_free_days=14,
            detention_free_days=7,
            port_storage_free_days=5,
        )
        db_session.add(policy)
        db_session.flush()

        # 2. Setup Import File in Phase 8
        imp_file = ImportFile(
            import_file_code="IMP-2026-TR05-01",
            custom_file_number="CFN-TR05-01",
            company_id=1,
            company_name="شركة النيل الدولية",
            supplier_id=1,
            supplier_name="Bavaria Chem GmbH",
            current_stage="Phase 8 - Inland Transport & Warehouse Receiving",
            current_module="TR-03 Warehouse Receiving Note",
            progress_percent=95.0,
            inland_transport_status="ARRIVED",
            is_active=True,
            created_by="Tester",
        )
        db_session.add(imp_file)
        db_session.flush()

        # 3. Setup Demurrage Tracking with 2 containers
        today = date.today()
        discharge = today - timedelta(days=10)
        gate_out = today - timedelta(days=2)

        containers_data = [
            {
                "container_no": "MSCU1001234",
                "container_type": "40ft High Cube",
                "gate_out_date": gate_out.isoformat(),
                "empty_return_date": None,
                "status": "Gated-Out",
            },
            {
                "container_no": "MSCU1002345",
                "container_type": "40ft High Cube",
                "gate_out_date": gate_out.isoformat(),
                "empty_return_date": None,
                "status": "Gated-Out",
            },
        ]

        tracking = DemurrageTracking(
            port_name="Alexandria",
            tracking_code="DND-2026-0099",
            import_file_id=imp_file.import_file_id,
            import_file_code=imp_file.import_file_code,
            policy_id=policy.policy_id,
            carrier_name="MSC",
            bill_of_lading_no="MEDU99887766",
            port_name="Alexandria Port",
            discharge_date=discharge,
            gate_out_date=gate_out,
            containers=containers_data,
            exchange_rate=50.0,
            status="Free Time Active",
            is_active=True,
        )
        db_session.add(tracking)

        # 4. Setup pending TR-05 SmartTask
        task = SmartTask(
            task_code="TSK-TR05-01",
            import_file_id=imp_file.import_file_id,
            title="إرجاع الحاويات الفارغة للخط الملاحي (TR-05)",
            status="Pending",
            created_by="System",
        )
        db_session.add(task)
        db_session.commit()

        # 5. Execute Return Service for all containers
        payload = EmptyContainerReturnSubmit(
            import_file_id=imp_file.import_file_id,
            eir_number="EIR-2026-88001",
            empty_return_date=today,
            depot_name="Alexandria Port Empty Depot Yard 4",
            container_condition="SOUND_CLEAN",
            driver_name="أحمد حسن السائق",
            truck_plate_no="ط ر ج 7812",
            notes="تم التسليم بسلام وخلو الحاويات من أي عيوب.",
        )

        res = record_empty_container_return_service(db_session, payload, user="Logistics Officer")

        # 6. Assertions
        assert res.import_file_id == imp_file.import_file_id
        assert res.eir_number == "EIR-2026-88001"
        assert res.all_containers_returned is True
        assert res.containers_returned_count == 2
        assert res.tracking_status == "All Containers Returned"
        assert res.progress_percent >= 98.0
        assert res.current_stage == "Phase 6: Inbound & Final Closure"

        # Verify ImportFile DB state
        db_session.refresh(imp_file)
        assert imp_file.current_phase_id == 6
        assert imp_file.current_step_code == "STEP_20"
        assert imp_file.next_action_code == "NA_CLO_SETTLE_FINAL_INVOICES"
        assert imp_file.empty_containers_return_status == "ALL_RETURNED"
        assert imp_file.empty_containers_eir_numbers == "EIR-2026-88001"
        assert imp_file.empty_containers_depot_name == "Alexandria Port Empty Depot Yard 4"
        assert imp_file.inland_transport_status == "COMPLETED"
        assert "CLO-01" in imp_file.next_action

        # Verify Tracking DB state
        db_session.refresh(tracking)
        assert tracking.status == "All Containers Returned"
        assert tracking.empty_return_date == today
        for c in tracking.containers:
            assert c.get("empty_return_date") == today.isoformat()
            assert c.get("eir_number") == "EIR-2026-88001"
            assert c.get("status") == "Empty-Returned"

        # Verify SmartTasks: previous closed, downstream TSK-0901 created
        db_session.refresh(task)
        assert task.status == "Completed"

        downstream = db_session.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_code.like("TSK-0901%"),
        ).first()
        assert downstream is not None
        assert "CLO-01" in downstream.title
        assert downstream.assigned_user == "Finance Team"

        # BE45-T16: a tracking with every container returned leaves the radar (it carries no more exposure).
        radar = get_containers_radar_overview_service(db_session)
        assert radar.returned_containers_count == 0
        assert all(r_item.import_file_id != imp_file.import_file_id for r_item in radar.radar_items)

    def test_record_empty_container_return_partial_containers(self, db_session):
        """إرجاع جزئي لإحدى الحاويات مع بقاء الحاوية الأخرى قيد التشغيل"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-TR05-PARTIAL",
            company_id=1,
            company_name="المصرية للمواد الغذائية",
            supplier_id=1,
            supplier_name="Global Food Traders",
            current_stage="Phase 8 - Inland Transport & Warehouse Receiving",
            progress_percent=95.0,
            is_active=True,
            created_by="Tester",
        )
        db_session.add(imp_file)
        db_session.flush()

        today = date.today()
        discharge = today - timedelta(days=5)

        containers_data = [
            {"container_no": "MEDU1111111", "container_type": "20ft Standard", "gate_out_date": discharge.isoformat()},
            {"container_no": "MEDU2222222", "container_type": "20ft Standard", "gate_out_date": discharge.isoformat()},
        ]

        tracking = DemurrageTracking(
            port_name="Alexandria",
            tracking_code="DND-2026-0100",
            # the model has no default rate any more (no fake FX): the service always sets one
            exchange_rate=50.0,
            import_file_id=imp_file.import_file_id,
            carrier_name="MSC",
            bill_of_lading_no="MEDU12345678",
            port_name="Alexandria Port",
            discharge_date=discharge,
            containers=containers_data,
            is_active=True,
        )
        db_session.add(tracking)
        db_session.commit()

        # Return only MEDU1111111
        payload = EmptyContainerReturnSubmit(
            import_file_id=imp_file.import_file_id,
            eir_number="EIR-PARTIAL-01",
            empty_return_date=today,
            returned_containers=["MEDU1111111"],
            depot_name="Dekheila Yard",
        )

        res = record_empty_container_return_service(db_session, payload)

        assert res.all_containers_returned is False
        assert res.containers_returned_count == 1
        assert res.tracking_status == "Partially Returned"

        db_session.refresh(imp_file)
        assert imp_file.empty_containers_return_status == "PARTIALLY_RETURNED"

    def test_record_empty_container_return_with_damage_fee(self, db_session):
        """تسجيل إرجاع الحاوية مع رصد تلفيات ومصاريف إصلاح تقديرية"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-TR05-DMG",
            company_id=1,
            company_name="شركة الدلتا",
            supplier_id=1,
            supplier_name="Bavaria Chem GmbH",
            is_active=True,
            created_by="Tester",
        )
        db_session.add(imp_file)
        db_session.flush()

        today = date.today()
        tracking = DemurrageTracking(
            port_name="Alexandria",
            tracking_code="DND-2026-0101",
            # the model has no default rate any more (no fake FX): the service always sets one
            exchange_rate=50.0,
            import_file_id=imp_file.import_file_id,
            carrier_name="CMA CGM",
            bill_of_lading_no="CMAU88776655",
            port_name="Alexandria Port",
            discharge_date=today - timedelta(days=6),
            # ACC3-T04: an empty return needs the container's gate-out from the port first.
            containers=[{
                "container_no": "CMAU9900112",
                "container_type": "40ft High Cube",
                "gate_out_date": (today - timedelta(days=4)).isoformat(),
            }],
            is_active=True,
        )
        db_session.add(tracking)
        db_session.commit()

        payload = EmptyContainerReturnSubmit(
            import_file_id=imp_file.import_file_id,
            eir_number="EIR-DMG-001",
            empty_return_date=today,
            container_condition="MINOR_DAMAGE",
            damage_notes="خدش بالباب الأيمن وانحناء بسيط في القائم الخلفي",
            damage_fee_estimated=150.0,
            damage_currency="USD",
        )

        res = record_empty_container_return_service(db_session, payload)
        assert res.container_condition == "MINOR_DAMAGE"
        assert res.damage_fee_estimated == 150.0

        db_session.refresh(tracking)
        c = tracking.containers[0]
        assert c.get("condition") == "MINOR_DAMAGE"
        assert c.get("damage_fee") == 150.0
        assert "خدش بالباب" in c.get("damage_notes", "")

    def test_empty_container_return_rest_api_endpoint(self, client, db_session):
        """اختبار نقطة النهاية REST API POST /api/v1/demurrage-detention/empty-container-return"""
        imp_file = ImportFile(
            import_file_code="IMP-2026-API-TR05",
            company_id=1,
            company_name="المتحدة للكيماويات",
            supplier_id=1,
            supplier_name="Global Chem Co",
            is_active=True,
            created_by="Tester",
        )
        db_session.add(imp_file)
        db_session.commit()

        payload = {
            "import_file_id": imp_file.import_file_id,
            "eir_number": "EIR-API-99221",
            "empty_return_date": date.today().isoformat(),
            "depot_name": "Sokhna Logistics Depot",
            "container_condition": "SOUND_CLEAN",
            "driver_name": "محمد علي السائق",
            "truck_plate_no": "س ق ر 1234",
            "notes": "تم الاستلام من خلال API بنجاح",
        }

        # DD-06e / Q10: no tracking session and no container list -> 404
        res_404 = client.post("/api/v1/demurrage-detention/empty-container-return", json=payload)
        assert res_404.status_code == 404
        payload["returned_containers"] = ["MSCU7766554"]

        res = client.post("/api/v1/demurrage-detention/empty-container-return", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["eir_number"] == "EIR-API-99221"
        assert data["import_file_id"] == imp_file.import_file_id
        assert data["all_containers_returned"] is True
        assert "EIR" in data["message_ar"]
