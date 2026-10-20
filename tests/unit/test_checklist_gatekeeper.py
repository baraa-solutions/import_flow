"""
Unit tests for Smart Import Checklist Gatekeeper Enforcement and Alerts
"""

import pytest
from datetime import date, timedelta
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.smart_checklists.model import ImportFileChecklistItem
from modules.smart_checklists.service import (
    get_checklist_summary,
    check_gatekeeper,
    enforce_gatekeeper_transition,
    auto_sync_checklist,
    resolve_all_checklist_items_for_file,
)
from modules.notifications.expiry_checker import ExpiryCheckerService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSession()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


def test_gatekeeper_enforcement_blocks_and_passes(db_session):
    # 1. Create a test import file
    file = ImportFile(
        import_file_code="IMP-CHK-TEST-01",
        company_name="Test Importer LLC",
        supplier_name="Test Supplier Co",
        status="Open",
        incoterm_code="FOB",
        current_phase_id=1,
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # 2. Initially, pre-shipment checklist items are pending, so target_phase='IN_TRANSIT' should block
    gate = check_gatekeeper(db_session, file.import_file_id, "IN_TRANSIT")
    assert gate.can_advance is False
    assert gate.blocking_count > 0

    # 3. enforce_gatekeeper_transition should raise HTTPException 409
    with pytest.raises(HTTPException) as exc_info:
        enforce_gatekeeper_transition(db_session, file.import_file_id, "IN_TRANSIT")
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "CHECKLIST_GATE_BLOCKED"

    # 4. Mark all PRE_SHIPMENT mandatory items as WAIVED or PASSED
    items = db_session.query(ImportFileChecklistItem).filter(
        ImportFileChecklistItem.import_file_id == file.import_file_id,
        ImportFileChecklistItem.phase_code == "PRE_SHIPMENT",
        ImportFileChecklistItem.is_mandatory == True,
    ).all()
    for itm in items:
        itm.status = "PASSED"
        itm.verified_by = "Test Auditor"
    db_session.commit()

    # 5. Now check_gatekeeper for IN_TRANSIT should be clear
    gate_clear = check_gatekeeper(db_session, file.import_file_id, "IN_TRANSIT")
    assert gate_clear.can_advance is True
    assert gate_clear.blocking_count == 0

    # enforce_gatekeeper_transition should succeed
    passed_gate = enforce_gatekeeper_transition(db_session, file.import_file_id, "IN_TRANSIT")
    assert passed_gate.can_advance is True


def test_checklist_notifications_in_expiry_checker(db_session):
    today = date.today()
    file = ImportFile(
        import_file_code="IMP-CHK-ALERT-01",
        company_name="Alert Importer",
        supplier_name="Alert Supplier",
        status="Open",
        incoterm_code="CIF",
        current_phase_id=4,
        required_eta=today + timedelta(days=3),
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    checker = ExpiryCheckerService(db_session)
    notifs = checker.check_all_expiries()
    
    # Check that notifications for gatekeeper or ETA readiness were generated
    checklist_notifs = [n for n in notifs if "CHECKLIST" in getattr(n, "category", "")]
    assert len(checklist_notifs) > 0
    categories = {n.category for n in checklist_notifs}
    assert "CHECKLIST_GATE_BLOCKED" in categories or "CHECKLIST_ETA_APPROACHING" in categories


def test_resolve_all_checklist_items_clears_all_pending(db_session):
    file = ImportFile(
        import_file_code="IMP-CHK-RESOLVE-01",
        company_name="Batch Test Importer",
        supplier_name="Batch Supplier",
        status="Open",
        incoterm_code="FOB",
        current_phase_id=1,
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # Initial summary seeds all checklist items
    summary = get_checklist_summary(db_session, file.import_file_id)
    assert summary.pending_items > 0

    # Resolve all items
    resolved_summary = resolve_all_checklist_items_for_file(
        db_session,
        file.import_file_id,
        target_status="PASSED",
        verified_by="Lead Operator",
        notes="All operational checks satisfied",
    )
    assert resolved_summary.pending_items == 0
    assert resolved_summary.passed_items == summary.total_items
    assert resolved_summary.readiness_score_pct == 100
    assert resolved_summary.is_gate_blocked is False

    # Gatekeeper for all phases should now pass
    for phase in ["IN_TRANSIT", "PORT_ARRIVAL", "CLEARANCE", "POST_CLEARANCE"]:
        gate = check_gatekeeper(db_session, file.import_file_id, phase)
        assert gate.can_advance is True
        assert gate.blocking_count == 0

