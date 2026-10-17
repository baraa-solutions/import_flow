"""
Unit Tests for BE45-T14: Shipment update cost adjustment, transactions, and not_found delegation
"""

import pytest
from datetime import datetime, timezone
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipment_updates.schemas import (
    ShipmentUpdateLogCreate,
    ShipmentUpdateLogUpdate,
)
import modules.shipment_updates.service as service


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def _create_import_file(db, file_id: int = 1, file_code: str = "IMP-2026-001", estimated_cost: float = 24500.0) -> ImportFile:
    import_file = ImportFile(
        import_file_id=file_id,
        import_file_code=file_code,
        custom_file_number=file_code,
        company_name="Test Company",
        supplier_name="Test Supplier",
        current_module="Phase 1",
        estimated_cost=estimated_cost,
        estimated_cost_currency="USD",
        is_active=True,
    )
    db.add(import_file)
    db.commit()
    db.refresh(import_file)
    return import_file


class TestBE45ShipmentUpdateCost:
    def test_cost_adjustment_reads_server_cost_and_reverts_on_delete(self, db):
        """
        Acceptance criteria:
        A file at 24500.00 adjusted to 26000.00 stores previous_cost 24500.00 even when
        the client sends 1.00; deleting that log restores 24500.00.
        """
        file = _create_import_file(db, file_id=10, file_code="IMP-2026-010", estimated_cost=24500.00)

        # Client attempts to send fabricated previous_cost=1.00
        schema = ShipmentUpdateLogCreate(
            import_file_id=10,
            update_category="Phase Cost Adjustment",
            target_phase="Phase 1",
            phase_status="Current",
            log_date="2026-10-16",
            note="Adjusting ocean freight cost",
            adjusted_cost_item="Ocean Freight",
            previous_cost=1.00,  # Fabricated client input: MUST BE IGNORED
            new_cost=26000.00,
        )

        log = service.create_update_log_service(db, schema, user_name="auditor1")

        # 1. previous_cost was read from the server (24500.00), not the client's 1.00
        assert log.previous_cost == 24500.00
        assert log.new_cost == 26000.00

        # 2. File estimated_cost was updated to 26000.00
        db.refresh(file)
        assert file.estimated_cost == 26000.00

        # 3. Soft deleting the cost adjustment log restores the previous_cost (24500.00)
        success = service.soft_delete_update_log_service(db, log.update_id, user_name="auditor1")
        assert success is True

        db.refresh(file)
        assert file.estimated_cost == 24500.00

    def test_cost_adjustment_new_cost_must_be_positive_422(self, db):
        """new_cost is required and must be > 0 (422) for Phase Cost Adjustment."""
        _create_import_file(db, file_id=20, file_code="IMP-2026-020", estimated_cost=15000.0)

        # 1. new_cost is 0.0 -> 422
        schema_zero = ShipmentUpdateLogCreate(
            import_file_id=20,
            update_category="Phase Cost Adjustment",
            target_phase="Phase 2",
            log_date="2026-10-16",
            note="Zero cost adjustment",
            new_cost=0.0,
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_update_log_service(db, schema_zero)
        assert exc_info.value.status_code == 422

        # 2. new_cost is negative -> 422
        schema_neg = ShipmentUpdateLogCreate(
            import_file_id=20,
            update_category="Phase Cost Adjustment",
            target_phase="Phase 2",
            log_date="2026-10-16",
            note="Negative cost adjustment",
            new_cost=-500.0,
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_update_log_service(db, schema_neg)
        assert exc_info.value.status_code == 422

        # 3. new_cost is None -> 422
        schema_none = ShipmentUpdateLogCreate(
            import_file_id=20,
            update_category="Phase Cost Adjustment",
            target_phase="Phase 2",
            log_date="2026-10-16",
            note="Missing cost adjustment",
            new_cost=None,
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_update_log_service(db, schema_none)
        assert exc_info.value.status_code == 422

    def test_put_new_cost_or_previous_cost_raises_409(self, db):
        """PUT of new_cost or previous_cost gives 409."""
        _create_import_file(db, file_id=30, file_code="IMP-2026-030", estimated_cost=10000.0)

        schema = ShipmentUpdateLogCreate(
            import_file_id=30,
            update_category="Phase Cost Adjustment",
            target_phase="Phase 1",
            log_date="2026-10-16",
            note="Initial cost adjustment",
            new_cost=12000.0,
        )
        log = service.create_update_log_service(db, schema)

        # Updating new_cost gives 409
        with pytest.raises(HTTPException) as exc_info:
            service.update_log_record_service(db, log.update_id, ShipmentUpdateLogUpdate(new_cost=15000.0))
        assert exc_info.value.status_code == 409

        # Updating previous_cost gives 409
        with pytest.raises(HTTPException) as exc_info:
            service.update_log_record_service(db, log.update_id, ShipmentUpdateLogUpdate(previous_cost=9000.0))
        assert exc_info.value.status_code == 409

        # Updating normal fields like note succeeds
        updated = service.update_log_record_service(db, log.update_id, ShipmentUpdateLogUpdate(note="Corrected note"))
        assert updated.note == "Corrected note"

    def test_delete_non_latest_cost_adjustment_does_not_revert_newer_file_cost(self, db):
        """
        When multiple cost adjustments exist, deleting an older one does not revert
        the file's estimated cost. Only deleting the latest one does.
        """
        file = _create_import_file(db, file_id=40, file_code="IMP-2026-040", estimated_cost=20000.0)

        # Log 1: adjust from 20000.0 to 25000.0
        log1 = service.create_update_log_service(
            db,
            ShipmentUpdateLogCreate(
                import_file_id=40,
                update_category="Phase Cost Adjustment",
                target_phase="Phase 1",
                log_date="2026-10-16",
                note="Adjustment 1",
                new_cost=25000.0,
            ),
        )
        db.refresh(file)
        assert file.estimated_cost == 25000.0

        # Log 2: adjust from 25000.0 to 30000.0
        log2 = service.create_update_log_service(
            db,
            ShipmentUpdateLogCreate(
                import_file_id=40,
                update_category="Phase Cost Adjustment",
                target_phase="Phase 1",
                log_date="2026-10-16",
                note="Adjustment 2",
                new_cost=30000.0,
            ),
        )
        db.refresh(file)
        assert file.estimated_cost == 30000.0

        # Delete older Log 1: file cost must stay 30000.0
        service.soft_delete_update_log_service(db, log1.update_id)
        db.refresh(file)
        assert file.estimated_cost == 30000.0

        # Now delete latest Log 2: file cost reverts to log2.previous_cost (25000.0)
        service.soft_delete_update_log_service(db, log2.update_id)
        db.refresh(file)
        assert file.estimated_cost == 25000.0

    def test_not_found_delegation_for_missing_records(self, db):
        """Service raises 404 via not_found helper on get, update, and delete."""
        with pytest.raises(HTTPException) as exc_get:
            service.get_update_log_by_id_service(db, 8888)
        assert exc_get.value.status_code == 404
        assert "تحديث الشحنة رقم 8888 غير موجود." in exc_get.value.detail

        with pytest.raises(HTTPException) as exc_put:
            service.update_log_record_service(db, 8888, ShipmentUpdateLogUpdate(note="Hello"))
        assert exc_put.value.status_code == 404
        assert "تحديث الشحنة رقم 8888 غير موجود." in exc_put.value.detail

        with pytest.raises(HTTPException) as exc_del:
            service.soft_delete_update_log_service(db, 8888)
        assert exc_del.value.status_code == 404
        assert "تحديث الشحنة رقم 8888 غير موجود." in exc_del.value.detail
