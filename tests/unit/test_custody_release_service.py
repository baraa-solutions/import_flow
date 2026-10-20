"""
Unit tests for Custody Release Dossier Service & Warehouse Lock Enforcement (modules/custody_release).
Tests custody undertaking registration, lead seals and judicial officer tracking,
warehouse freeze, warehouse dispensing lock enforcement, final lab clearance release,
breach tracking, and soft-delete/restore.
"""

from datetime import datetime, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
import database.models  # Registers all models
from modules.import_files.model import ImportFile
from modules.custody_release.schemas import (
    CustodyBreachReportSubmit,
    CustodyFinalClearanceSubmit,
    CustodyReleaseDossierCreate,
    CustodyReleaseDossierUpdate,
    CustodyWarehouseFreezeSubmit,
)
from modules.custody_release.service import CustodyReleaseService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    imp_file = ImportFile(
        import_file_code="IMP-2026-9002",
        company_name="Egyptian Petrochemicals Co",
        supplier_name="Bayer MaterialScience",
        current_step_code="STEP_14",
        current_module="STEP_14 Clearance Follow-up",
        current_stage_code="PHASE_5",
        progress_percent=88.0,
    )
    session.add(imp_file)
    session.commit()
    session.refresh(imp_file)

    yield session
    session.close()


def test_create_custody_release_dossier_success(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    payload = CustodyReleaseDossierCreate(
        import_file_id=imp_file.import_file_id,
        warehouse_id=12,
        warehouse_address="Amreya Free Zone - Block 4B, Alexandria",
        custody_undertaking_number="UND-EGY-2026-7890",
        judicial_officer_name="Officer Mahmoud Soliman",
        lead_seals_count=3,
        lead_seal_numbers=["SEAL-EGY-001", "SEAL-EGY-002", "SEAL-EGY-003"],
        transport_permit_number="TR-PERMIT-4412",
        status="RELEASED_UNDER_CUSTODY",
        lock_active=True,
        notes="Cargo released from Dekheila Port under official custody bond",
    )

    dossier = service.create_dossier(payload, current_user="customs_broker")

    assert dossier.custody_id is not None
    assert dossier.custody_code.startswith("CUS-")
    assert dossier.custody_undertaking_number == "UND-EGY-2026-7890"
    assert dossier.judicial_officer_name == "Officer Mahmoud Soliman"
    assert dossier.lead_seals_count == 3
    assert dossier.lead_seal_numbers == ["SEAL-EGY-001", "SEAL-EGY-002", "SEAL-EGY-003"]
    assert dossier.transport_permit_number == "TR-PERMIT-4412"
    assert dossier.status == "RELEASED_UNDER_CUSTODY"
    assert dossier.lock_active is True
    assert dossier.is_active is True


def test_duplicate_undertaking_number_rejected(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    payload = CustodyReleaseDossierCreate(
        import_file_id=imp_file.import_file_id,
        custody_undertaking_number="UND-DUPLICATE-001",
    )
    service.create_dossier(payload, current_user="broker1")

    # Attempt second registration with same undertaking number
    with pytest.raises(HTTPException) as exc_info:
        service.create_dossier(payload, current_user="broker2")
    assert exc_info.value.status_code == 409
    assert "مسجل بالفعل" in exc_info.value.detail


def test_warehouse_freeze_and_dispense_lock_enforcement(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    dossier = service.create_dossier(
        CustodyReleaseDossierCreate(
            import_file_id=imp_file.import_file_id,
            warehouse_id=5,
            warehouse_address="6th of October Industrial Zone 3",
            custody_undertaking_number="UND-OCT-2026-1122",
            judicial_officer_name="Eng. Tarek Fathi",
            lead_seals_count=2,
            lead_seal_numbers=["SEAL-A1", "SEAL-A2"],
            status="RELEASED_UNDER_CUSTODY",
            lock_active=True,
        ),
        current_user="broker",
    )

    # 1. Warehouse receipt freeze
    frozen = service.freeze_in_warehouse(
        dossier.custody_id,
        CustodyWarehouseFreezeSubmit(
            warehouse_address="6th of October Industrial Zone 3 - Bay 2",
            notes="Cargo received, all 2 lead seals verified intact by warehouse supervisor",
        ),
        current_user="warehouse_mgr",
    )
    assert frozen.status == "FROZEN_IN_WAREHOUSE"
    assert frozen.lock_active is True

    # 2. Check dispense authorization: must be blocked!
    validation = service.validate_warehouse_dispense(imp_file.import_file_id)
    assert validation.is_allowed is False
    assert validation.lock_active is True
    assert validation.status == "FROZEN_IN_WAREHOUSE"
    assert "صرف البضاعة من المستودع محظور" in validation.message

    # 3. enforce_dispense_check must raise 409 Conflict
    with pytest.raises(HTTPException) as exc_info:
        service.enforce_dispense_check(imp_file.import_file_id)
    assert exc_info.value.status_code == 409
    assert "صرف البضاعة من المستودع محظور قطعيًا" in exc_info.value.detail


def test_final_clearance_lifts_warehouse_lock(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    dossier = service.create_dossier(
        CustodyReleaseDossierCreate(
            import_file_id=imp_file.import_file_id,
            custody_undertaking_number="UND-RELEASE-TEST-88",
            lead_seals_count=1,
            lead_seal_numbers=["SEAL-X"],
            status="FROZEN_IN_WAREHOUSE",
            lock_active=True,
        ),
        current_user="broker",
    )

    # Initially locked
    assert service.validate_warehouse_dispense(imp_file.import_file_id).is_allowed is False

    # Issue final lab clearance
    cleared = service.approve_final_clearance(
        dossier.custody_id,
        CustodyFinalClearanceSubmit(
            final_clearance_letter_number="GOEIC-RELEASE-2026-9901",
            release_approved_at=datetime(2026, 10, 10, 14, 0, tzinfo=timezone.utc),
            notes="All chemical and microbial tests passed. GOEIC issued unconditional release.",
        ),
        current_user="customs_officer",
    )

    assert cleared.status == "SAMPLE_CLEAR_FINAL_RELEASE"
    assert cleared.lock_active is False
    assert cleared.final_clearance_letter_number == "GOEIC-RELEASE-2026-9901"
    assert cleared.release_approved_at is not None

    # Now dispensing is allowed!
    validation = service.validate_warehouse_dispense(imp_file.import_file_id)
    assert validation.is_allowed is True
    assert validation.lock_active is False
    assert validation.status == "CLEARED"

    # enforce_dispense_check does not raise
    service.enforce_dispense_check(imp_file.import_file_id)


def test_custody_breach_reporting_and_lock_retention(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    dossier = service.create_dossier(
        CustodyReleaseDossierCreate(
            import_file_id=imp_file.import_file_id,
            custody_undertaking_number="UND-BREACH-TEST-007",
            lead_seals_count=2,
            lead_seal_numbers=["SEAL-B1", "SEAL-B2"],
            status="FROZEN_IN_WAREHOUSE",
            lock_active=True,
        ),
        current_user="broker",
    )

    # Report breach
    breached = service.report_breach(
        dossier.custody_id,
        CustodyBreachReportSubmit(
            breach_reason="Customs lead seal SEAL-B1 found tampered and severed during routine judicial audit",
            reported_at=datetime(2026, 10, 12, 16, 30, tzinfo=timezone.utc),
            notes="Formal report filed with Alexandria Customs Police and Public Prosecution",
        ),
        current_user="judicial_officer",
    )

    assert breached.status == "BREACH_REPORTED"
    assert breached.lock_active is True
    assert "SEAL-B1 found tampered" in breached.breach_reason

    # Dispense must be blocked with breach rationale
    validation = service.validate_warehouse_dispense(imp_file.import_file_id)
    assert validation.is_allowed is False
    assert validation.status == "BREACH_REPORTED"
    assert "مخالفة فض أختام أو خرق للتحفظ الجمركي" in validation.message

    with pytest.raises(HTTPException) as exc_info:
        service.enforce_dispense_check(imp_file.import_file_id)
    assert exc_info.value.status_code == 409
    assert "مخالفة فض أختام" in exc_info.value.detail

    # Attempting to grant final clearance on a breached dossier must be blocked
    with pytest.raises(HTTPException) as exc_info:
        service.approve_final_clearance(
            dossier.custody_id,
            CustodyFinalClearanceSubmit(final_clearance_letter_number="ATTEMPT-LETTER-01"),
            current_user="officer",
        )
    assert exc_info.value.status_code == 409
    assert "تسوية قضائية وقانونية مسبقة" in exc_info.value.detail


def test_list_and_soft_delete_custody_dossier(db_session):
    service = CustodyReleaseService(db_session)
    imp_file = db_session.query(ImportFile).first()

    d1 = service.create_dossier(
        CustodyReleaseDossierCreate(
            import_file_id=imp_file.import_file_id,
            warehouse_id=1,
            custody_undertaking_number="UND-LIST-1",
        ),
        current_user="user1",
    )
    d2 = service.create_dossier(
        CustodyReleaseDossierCreate(
            import_file_id=imp_file.import_file_id,
            warehouse_id=2,
            custody_undertaking_number="UND-LIST-2",
        ),
        current_user="user1",
    )

    # Filter by warehouse_id
    items, total = service.list_dossiers(warehouse_id=1)
    assert total == 1
    assert items[0].custody_id == d1.custody_id

    # Update d1
    service.update_dossier(
        d1.custody_id,
        CustodyReleaseDossierUpdate(notes="Updated notes"),
        current_user="user1",
    )
    db_session.refresh(d1)
    assert d1.notes == "Updated notes"

    # Soft delete d1
    service.soft_delete(d1.custody_id, current_user="admin")
    items, total = service.list_dossiers(warehouse_id=1)
    assert total == 0

    # Include inactive
    items, total = service.list_dossiers(warehouse_id=1, include_inactive=True)
    assert total == 1

    # Restore d1
    restored = service.restore(d1.custody_id, current_user="admin")
    assert restored.is_active is True
    items, total = service.list_dossiers(warehouse_id=1)
    assert total == 1
