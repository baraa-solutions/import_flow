"""
Unit tests for BE45-T23: Soft-delete and restore endpoints for:
- cargo_insurance (certificates)
- shipment_updates (logs)
- demurrage_detention (trackings + 409 guard when pushed to settlement)
"""
from datetime import date, datetime, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.cargo_insurance.service import CargoInsuranceService
from modules.cargo_insurance.schemas import CargoInsuranceCertificateCreate
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipment_updates.schemas import ShipmentUpdateLogCreate
from modules.shipment_updates.service import (
    create_update_log_service,
    soft_delete_update_log_service,
    restore_update_log_service,
)
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import DemurrageTrackingCreate, ContainerItemInput
from modules.demurrage_detention.service import (
    create_demurrage_tracking_service,
    delete_demurrage_tracking_service,
    restore_demurrage_tracking_service,
)


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_cargo_insurance_restore_and_uniqueness_guard(db):
    file = ImportFile(
        import_file_code="IMP-2026-INS-RESTORE",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="Active",
    )
    db.add(file)
    db.commit()
    db.refresh(file)

    service = CargoInsuranceService(db)
    cert_data = CargoInsuranceCertificateCreate(
        import_file_id=file.import_file_id,
        insured_entity_name="Sorour Logistics",
        port_of_loading="Shanghai",
        port_of_discharge="Alexandria",
        coverage_clause="ICC_A",
        transport_mode="OCEAN",
        policy_type="SPECIFIC",
        invoice_value=10000.0,
        freight_cost=1500.0,
        currency="USD",
    )
    cert1 = service.create_certificate(cert_data, current_user="admin")
    cert1_id = cert1.certificate_id

    # 1. Soft-delete cert1
    service.delete_certificate(cert1_id, current_user="admin")
    assert not cert1.is_active

    # 2. Restore cert1
    restored = service.restore_certificate(cert1_id, current_user="admin")
    assert restored.is_active
    assert restored.updated_by == "admin"

    # 3. Soft-delete cert1 again
    service.delete_certificate(cert1_id, current_user="admin")

    # Create cert2 for same file
    cert2 = service.create_certificate(cert_data, current_user="admin")
    assert cert2.is_active

    # 4. Attempt to restore cert1 while cert2 is active for the same file -> 409 Conflict
    with pytest.raises(HTTPException) as exc_info:
        service.restore_certificate(cert1_id, current_user="admin")
    assert exc_info.value.status_code == 409
    assert "وثيقة تأمين نشطة" in exc_info.value.detail


def test_shipment_updates_restore_and_cost_adjustment(db):
    file = ImportFile(
        import_file_code="IMP-2026-UPD-RESTORE",
        company_name="Test Company",
        supplier_name="Test Supplier",
        estimated_cost=5000.0,
        status="Active",
    )
    db.add(file)
    db.commit()
    db.refresh(file)

    # 1. Normal log
    log_create = ShipmentUpdateLogCreate(
        import_file_id=file.import_file_id,
        update_category="Daily Check-in",
        target_phase="Phase 1",
        phase_status="Current",
        note="Normal daily check-in",
        log_date=date.today().isoformat(),
    )
    log = create_update_log_service(db, log_create, user_name="operator")
    log_id = log.update_id

    # Soft delete
    soft_delete_update_log_service(db, log_id, user_name="operator")
    db.refresh(log)
    assert not log.is_active

    # Restore
    restored = restore_update_log_service(db, log_id, user_name="operator")
    assert restored.is_active
    assert restored.updated_by == "operator"

    # 2. Cost adjustment log
    cost_log_create = ShipmentUpdateLogCreate(
        import_file_id=file.import_file_id,
        update_category="Phase Cost Adjustment",
        target_phase="Phase 2",
        phase_status="Current",
        previous_cost=5000.0,
        new_cost=6500.0,
        note="Freight increase adjustment",
        log_date=date.today().isoformat(),
    )
    cost_log = create_update_log_service(db, cost_log_create, user_name="operator")
    db.refresh(file)
    assert file.estimated_cost == 6500.0

    # Soft delete reverts to previous_cost
    soft_delete_update_log_service(db, cost_log.update_id, user_name="operator")
    db.refresh(file)
    assert file.estimated_cost == 5000.0

    # Restore reapplies new_cost
    restore_update_log_service(db, cost_log.update_id, user_name="operator")
    db.refresh(file)
    assert file.estimated_cost == 6500.0


def test_demurrage_detention_tracking_delete_and_restore(db):
    file = ImportFile(
        import_file_code="IMP-2026-DND-RESTORE",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="Active",
    )
    db.add(file)
    db.commit()
    db.refresh(file)

    req = DemurrageTrackingCreate(
        import_file_id=file.import_file_id,
        carrier_name="Maersk Line",
        port_name="Alexandria",
        bill_of_lading_no="MSK12345678",
        discharge_date=date.today(),
        exchange_rate=50.0,
        containers=[
            ContainerItemInput(
                container_no="MSKU1122334",
                container_type="40ft High Cube",
            )
        ],
    )
    tracking = create_demurrage_tracking_service(db, req, user="manager")
    tracking_id = tracking.tracking_id

    # Guard: if is_pushed_to_settlement is True, delete raises 409
    tracking.is_pushed_to_settlement = True
    db.commit()

    with pytest.raises(HTTPException) as exc_info:
        delete_demurrage_tracking_service(db, tracking_id, user="manager")
    assert exc_info.value.status_code == 409
    assert "ترحيلها للتسوية المالية" in exc_info.value.detail

    # Allow delete when not pushed
    tracking.is_pushed_to_settlement = False
    db.commit()

    delete_demurrage_tracking_service(db, tracking_id, user="manager")
    db.refresh(tracking)
    assert not tracking.is_active

    # Restore tracking
    restored = restore_demurrage_tracking_service(db, tracking_id, user="manager")
    assert restored.is_active

    # Soft-delete again and test uniqueness conflict on restore
    delete_demurrage_tracking_service(db, tracking_id, user="manager")

    # Create new active tracking for same file
    tracking2 = create_demurrage_tracking_service(db, req, user="manager")
    assert tracking2.is_active

    with pytest.raises(HTTPException) as exc_info:
        restore_demurrage_tracking_service(db, tracking_id, user="manager")
    assert exc_info.value.status_code == 409
    assert "نشطة لهذا الملف" in exc_info.value.detail
