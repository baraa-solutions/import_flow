"""
Unit Tests for Operational & Daily Shipment Update Engine
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipment_updates.schemas import ShipmentUpdateLogCreate, ShipmentUpdateLogUpdate
import modules.shipment_updates.service as service
import modules.shipment_updates.repository as repo


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


class TestShipmentUpdateEngine:
    def test_create_and_inspect_phases(self, db_session):
        # Create dummy ImportFile
        import_file = ImportFile(
            import_file_id=10,
            custom_file_number="IMP-2026-010",
            import_file_code="IMP-2026-010",
            company_name="Al-Ahram Trading",
            supplier_name="Ningbo Freight China",
            current_module="Phase 4 - Freight Booking",
            owner="Kamal",
        )
        db_session.add(import_file)
        db_session.commit()

        # Create Follow-up Update
        schema1 = ShipmentUpdateLogCreate(
            import_file_id=10,
            import_file_code="IMP-2026-010",
            update_category="Follow-up & Notes",
            target_phase="Phase 4",
            phase_status="Current",
            log_date="2026-08-13",
            note="تم تأكيد حجز 2 حاويات 40 قدم مع الخط الملاحي Maersk",
            assigned_user="Kamal",
        )
        log1 = service.create_update_log_service(db_session, schema1)

        assert log1.update_id is not None
        assert log1.update_code.startswith("UPD-")
        assert log1.target_phase == "Phase 4"

        # Create Cost Adjustment Update
        schema2 = ShipmentUpdateLogCreate(
            import_file_id=10,
            import_file_code="IMP-2026-010",
            update_category="Phase Cost Adjustment",
            target_phase="Phase 1",
            phase_status="Completed",
            log_date="2026-08-13",
            note="تعديل تكلفة النولون البحري للحاوية",
            adjusted_cost_item="Freight Fee",
            previous_cost=2500.0,
            new_cost=2800.0,
        )
        log2 = service.create_update_log_service(db_session, schema2)
        assert log2.new_cost == 2800.0

        # Inspect Phases
        inspections = service.inspect_shipment_phases_service(db_session, 10)
        assert len(inspections) == 10

        # Phase 1, 2, 3 should be Completed
        assert inspections[0].status == "Completed"
        assert inspections[1].status == "Completed"
        assert inspections[2].status == "Completed"
        # Phase 4 should be Current
        assert inspections[3].status == "Current"
        assert inspections[3].update_count == 1
        # Phase 5..10 should be Future
        assert inspections[4].status == "Future"

    def test_soft_delete_and_list_filters(self, db_session):
        from fastapi import HTTPException
        missing = ShipmentUpdateLogCreate(import_file_id=1, target_phase="Phase 5", log_date="2026-08-13", note="no file yet")
        with pytest.raises(HTTPException) as exc:  # SU-03: the import file must exist and be active
            service.create_update_log_service(db_session, missing)
        assert exc.value.status_code == 404
        db_session.add(ImportFile(import_file_id=1, import_file_code="IMP-001", company_name="X", supplier_name="Y", owner="Kamal"))
        db_session.commit()

        schema = ShipmentUpdateLogCreate(
            import_file_id=1,
            import_file_code="IMP-001",
            update_category="Daily Check-in",
            target_phase="Phase 5",
            log_date="2026-08-13",
            note="تحديث يومي: وصول الشحنة لميناء التفريغ بالسكندرية",
        )
        log = service.create_update_log_service(db_session, schema)

        all_logs, _ = repo.get_all_update_logs(db_session, import_file_id=1)
        assert len(all_logs) == 1

        success = repo.soft_delete_update_log(db_session, log.update_id)
        assert success is True
        logs_after, _ = repo.get_all_update_logs(db_session, import_file_id=1)
        assert len(logs_after) == 0
