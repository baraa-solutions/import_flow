"""
Targeted tests for file_closure domain sub-services and facade parity:
- file_closure_audit_service
- file_closure_workflow_service
- file_closure_reopen_service
- service (Facade)
"""
import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import HTTPException

from database.database import Base
from modules.import_files.model import ImportFile
from modules.users.model import User
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.file_closure.schemas import (
    FileClosureCreate,
    FileClosureUpdate,
    ClosureChecklistSchema,
)
from modules.file_closure.service import (
    close_import_file_service,
    official_close_import_file_service,
    get_closure_service,
    list_closures_service,
    update_closure_service,
    soft_delete_closure_service,
    restore_closure_service,
    get_comprehensive_shipment_dossier_service,
    confirm_dossier_export_service,
    get_closure_precheck_service,
    get_shipment_audit_timeline_service,
    update_audit_meeting_directives_service,
    reopen_closed_file_service,
    reopen_closure_record_service,
    validate_can_reopen_file,
    get_closure_reopen_history,
    verify_customs_release_readiness,
    verify_clearance_settlement_readiness,
    evaluate_file_closure_gate,
)
from modules.file_closure.file_closure_audit_service import (
    verify_customs_release_readiness as audit_verify_customs,
    verify_clearance_settlement_readiness as audit_verify_settlement,
)
from modules.file_closure.file_closure_reopen_service import (
    reopen_closed_file_service as reopen_svc,
    validate_can_reopen_file as validate_reopen,
)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = Session()

    # Create dummy user
    admin_user = User(
        user_id=1,
        username="admin_supervisor",
        full_name="Admin Supervisor",
        email="supervisor@importflow.local",
        hashed_password="hash",
        role="Admin",
        is_active=True,
    )
    session.add(admin_user)

    # Create test import file
    imp = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-TEST",
        company_name="Test Co",
        supplier_name="Test Supplier",
        status="In Progress",
        current_module="Phase 9 - Multi-Party Invoices & Actual Landed Cost",
        is_active=True,
    )
    session.add(imp)
    session.commit()

    yield session
    session.close()


def test_audit_subservice_helpers(db):
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    
    # 1. Customs readiness check before clearance
    customs_res = audit_verify_customs(db, imp)
    assert customs_res["has_final_release"] is False
    assert customs_res["is_customs_released"] is False

    # 2. Add clearance
    clr = CustomsClearanceRecord(
        clearance_code="CLR-001",
        import_file_id=1,
        status="Final Release Granted",
        declaration_46_no="DEC-46-999",
        release_permit_no="PERMIT-888",
        release_date=datetime.now(timezone.utc),
        is_active=True,
    )
    db.add(clr)
    db.commit()

    customs_res2 = audit_verify_customs(db, imp)
    assert customs_res2["has_final_release"] is True

    # 3. Settlement readiness
    settle_res = audit_verify_settlement(db, imp)
    assert settle_res["has_settled_settlement"] is False

    settlement = LandedCostSettlementRecord(
        settlement_code="SET-001",
        import_file_id=1,
        status="Approved",
        total_landed_cost_egp=500000.0,
        is_active=True,
    )
    db.add(settlement)
    db.commit()

    settle_res2 = audit_verify_settlement(db, imp)
    assert settle_res2["has_settled_settlement"] is True
    assert settle_res2["actual_landed_cost_egp"] == 500000.0


def test_timeline_and_directives_service(db):
    # Audit timeline retrieval
    timeline = get_shipment_audit_timeline_service(db, 1)
    assert timeline.import_file_id == 1
    assert len(timeline.milestones) > 0
    assert timeline.financial_radar is not None

    # Update directives
    res = update_audit_meeting_directives_service(
        db, 1, "Review customs tariff exemptions before next session", user="auditor1"
    )
    assert res["success"] is True
    assert res["meeting_directives"] == "Review customs tariff exemptions before next session"

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    assert imp.notes == "Review customs tariff exemptions before next session"


def test_reopen_subservice_protocol(db):
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).first()
    admin_user = db.query(User).filter(User.user_id == 1).first()

    # Cannot reopen non-closed file
    with pytest.raises(HTTPException) as exc:
        validate_reopen(db, imp, actor=admin_user, trusted=True)
    assert exc.value.status_code == 400

    # Simulate closing file
    imp.status = "Closed"
    imp.closed_at_phase = "Phase 8 - Inbound Logistics & Receiving"
    db.commit()

    # Reopening without reason must fail
    with pytest.raises(HTTPException) as exc:
        reopen_svc(db, 1, "", supervisor_actor=admin_user, trusted=True)
    assert exc.value.status_code == 400

    # Successful reopen
    res = reopen_svc(
        db,
        1,
        justification="Supplier issued credit note and revised final invoice",
        supervisor_actor=admin_user,
        trusted=True,
    )
    assert res["success"] is True
    assert res["status"] == "In Progress"
    assert res["current_module"] == "Phase 8 - Inbound Logistics & Receiving"

    # Verify ImportFile state in DB
    db.refresh(imp)
    assert imp.status == "In Progress"
    assert imp.current_module == "Phase 8 - Inbound Logistics & Receiving"
    assert imp.current_stage_code == "REOPENED_IN_PROGRESS"

    # Check reopen audit history
    history = get_closure_reopen_history(db, 1)
    assert len(history) >= 1
    assert history[0]["action"] == "REOPEN"
    assert "credit note" in history[0]["changes_summary"]
