"""
Unit tests for BEX-T11: Import files tracking fields, exact lookup, status workflow, and legacy tolerance.

Acceptance criteria:
1. File at progress_percent=88.0, current_step_code="STEP_19": PUT {"notes":"x"} -> progress stays 88.0, step stays STEP_19.
2. Files id 12 (inactive) and custom number "6701120012": GET /import-files/12 -> 404 (does not return the custom number match).
3. Clone to a code used by an inactive file -> 409.
4. PUT {"status":"Closed"} leaves status unchanged; reopen -> "In Progress" and updates ImportFileClosureRecord & AuditLog; invalid transitions -> 409 IF_STATUS_TRANSITION_INVALID.
5. A legacy row with company_name="X" (1 char) does not break GET /import-files or ImportFileResponse.
"""
from datetime import datetime, timezone, date
from types import SimpleNamespace
import pytest
from fastapi import status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.audit_logs.model import AuditLog
from modules.auth.security import create_access_token
from modules.file_closure.model import ImportFileClosureRecord
from modules.import_files.model import ImportFile
from modules.import_files.schemas import (
    ImportFileCreate,
    ImportFileUpdate,
    ImportFileResponse,
    CloseShipmentSubmit,
    ReopenShipmentSubmit,
    CloneImportFileRequest,
    HoldShipmentPayload,
    ResumeShipmentPayload,
)
from modules.import_files import service as imp_service
from modules.import_files import validators as imp_validators
from modules.users.model import User
from modules.common.errors import CodedHTTPException


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def db() -> Session:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def auth_headers(db: Session):
    user = User(
        username="ops_admin",
        full_name="Operations Admin",
        email="ops@sorour.com",
        role="ADMIN",
        is_active=True,
        hashed_password="pw",
    )
    db.add(user)
    db.commit()
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def client(db: Session):
    def override_get_db():
        yield db

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


# ── Tests ─────────────────────────────────────────────────────────────────────

def test_ac1_update_preserves_tracking_fields_and_ignores_status(db: Session, client: TestClient, auth_headers: dict):
    """File at progress_percent=88.0, current_step_code='STEP_19': PUT {'notes':'x'} -> progress stays 88.0, step stays STEP_19."""
    file_obj = ImportFile(
        import_file_code="IMP-2026-0088",
        custom_file_number="CF-0088",
        company_name="Acme Imports",
        supplier_name="Global Supplier",
        progress_percent=88.0,
        current_step_code="STEP_19",
        current_module="BP-019 Warehouse Receiving",
        current_stage="Phase 5 - Clearance & Delivery",
        status="In Progress",
        notes="Initial note",
        is_active=True,
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)

    # 1. Update via service
    actor = SimpleNamespace(username="operator_1")
    update_payload = ImportFileUpdate(notes="Updated note x")
    updated = imp_service.update_import_file_service(db, file_obj.import_file_id, update_payload, actor=actor)

    assert updated.notes == "Updated note x"
    assert updated.progress_percent == 88.0
    assert updated.current_step_code == "STEP_19"
    assert updated.current_module == "BP-019 Warehouse Receiving"
    assert updated.current_stage == "Phase 5 - Clearance & Delivery"
    assert updated.status == "In Progress"
    assert updated.updated_by == "operator_1"

    # 2. Update via HTTP PUT sending notes and attempting to overwrite status / tracking
    res = client.put(
        f"/api/v1/import-files/{file_obj.import_file_id}",
        json={
            "notes": "Updated via HTTP",
            "status": "Closed",
            "progress_percent": 10.0,
            "current_step_code": "STEP_01",
        },
        headers=auth_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["notes"] == "Updated via HTTP"
    assert data["progress_percent"] == 88.0
    assert data["current_step_code"] == "STEP_19"
    assert data["status"] == "In Progress"


def test_ac2_exact_numeric_id_lookup_does_not_match_custom_file_number(db: Session, client: TestClient, auth_headers: dict):
    """Files id 12 (inactive) and custom number '6701120012': GET /import-files/12 -> 404 (does not return the other file)."""
    # Inactive file with ID 12
    inactive_file = ImportFile(
        import_file_id=12,
        import_file_code="IMP-2026-0012",
        custom_file_number="6701000012",
        company_name="Old Importer",
        supplier_name="Old Supplier",
        is_active=False,
    )
    # Active file with custom_file_number containing "12"
    active_file = ImportFile(
        import_file_id=99,
        import_file_code="IMP-2026-0099",
        custom_file_number="6701120012",
        company_name="Active Importer",
        supplier_name="Active Supplier",
        is_active=True,
    )
    db.add_all([inactive_file, active_file])
    db.commit()

    # GET /import-files/12 should check only id=12, which is inactive -> 404
    res = client.get("/api/v1/import-files/12", headers=auth_headers)
    assert res.status_code == status.HTTP_404_NOT_FOUND

    # Exact lookup by non-numeric code matches via router
    res_code = client.get("/api/v1/import-files/IMP-2026-0099", headers=auth_headers)
    assert res_code.status_code == 200
    assert res_code.json()["import_file_id"] == 99

    # Substring search does not match exact code lookup
    res_partial = client.get("/api/v1/import-files/IMP-2026-009", headers=auth_headers)
    assert res_partial.status_code == status.HTTP_404_NOT_FOUND

    # Repository exact match by custom_file_number succeeds
    found_by_custom = imp_service.get_import_file_by_code_service(db, "6701120012")
    assert found_by_custom is not None
    assert found_by_custom.import_file_id == 99

    # Repository lookup for "12" no longer fuzzy matches "6701120012"
    assert imp_service.get_import_file_by_code_service(db, "12") is None


def test_ac3_clone_to_inactive_code_raises_409(db: Session, client: TestClient, auth_headers: dict):
    """Clone to a code used by an inactive file -> 409 (was 500)."""
    # Inactive file holding the target code
    inactive_file = ImportFile(
        import_file_code="IMP-2026-USED",
        custom_file_number="CF-USED-99",
        company_name="Inactive Co",
        supplier_name="Inactive Sup",
        is_active=False,
    )
    # Active source file to clone
    source_file = ImportFile(
        import_file_code="IMP-2026-ORIG",
        custom_file_number="CF-ORIG-10",
        company_name="Original Co",
        supplier_name="Original Sup",
        is_active=True,
    )
    db.add_all([inactive_file, source_file])
    db.commit()
    db.refresh(source_file)

    # 1. Try cloning to existing inactive code -> 409
    clone_payload = CloneImportFileRequest(
        target_import_file_code="IMP-2026-USED",
        target_custom_file_number="CF-NEW-01",
    )
    with pytest.raises(Exception) as exc_info:
        imp_service.clone_import_file_service(db, source_file.import_file_id, clone_payload)
    assert exc_info.value.status_code == status.HTTP_409_CONFLICT

    # 2. Try cloning to existing inactive custom file number -> 409
    clone_payload_custom = CloneImportFileRequest(
        target_import_file_code="IMP-2026-UNIQUE-1",
        target_custom_file_number="CF-USED-99",
    )
    with pytest.raises(Exception) as exc_info:
        imp_service.clone_import_file_service(db, source_file.import_file_id, clone_payload_custom)
    assert exc_info.value.status_code == status.HTTP_409_CONFLICT

    # 3. Successful clone creates file and initializes lifecycle
    clone_payload_ok = CloneImportFileRequest(
        target_import_file_code="IMP-2026-UNIQUE-OK",
        target_custom_file_number="CF-UNIQUE-OK",
    )
    cloned = imp_service.clone_import_file_service(db, source_file.import_file_id, clone_payload_ok)
    assert cloned.import_file_code == "IMP-2026-UNIQUE-OK"
    assert cloned.cloned_from_id == source_file.import_file_id
    assert cloned.status == "Draft"


def test_ac4_status_workflow_transitions_and_reopen_audit(db: Session, client: TestClient, auth_headers: dict):
    """PUT {'status':'Closed'} leaves status unchanged; reopen -> 'In Progress' and updates ImportFileClosureRecord & AuditLog."""
    file_obj = ImportFile(
        import_file_code="IMP-2026-0044",
        company_name="Workflow Co",
        supplier_name="Workflow Sup",
        status="In Progress",
        closed_at_phase="Phase 3 - Import Documentation",
        is_active=True,
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)

    # Close the shipment properly
    actor = SimpleNamespace(username="closer_user")
    close_payload = CloseShipmentSubmit(
        closure_reason="Commercial cancellation",
        closed_at_phase="Phase 3 - Import Documentation",
    )
    closed = imp_service.close_shipment_service(db, file_obj.import_file_id, close_payload, actor=actor)
    assert closed.status == "Closed"
    assert closed.closure_reason == "Commercial cancellation"
    assert closed.closed_at_phase == "Phase 3 - Import Documentation"

    # Add an active closure record
    closure_rec = ImportFileClosureRecord(
        closure_code="CLR-2026-0044",
        import_file_id=file_obj.import_file_id,
        status="Closed",
        is_active=True,
    )
    db.add(closure_rec)
    db.commit()

    # Closing again -> 409 IF_STATUS_TRANSITION_INVALID
    with pytest.raises(CodedHTTPException) as exc_info:
        imp_service.close_shipment_service(db, file_obj.import_file_id, close_payload, actor=actor)
    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.code == "IF_STATUS_TRANSITION_INVALID"
    assert exc_info.value.params == {"from": "Closed", "to": "Closed"}

    # Placing closed file on hold -> 409 IF_STATUS_TRANSITION_INVALID
    with pytest.raises(CodedHTTPException) as exc_info:
        imp_service.hold_import_file_service(db, file_obj.import_file_id, hold_reason="Some reason")
    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.code == "IF_STATUS_TRANSITION_INVALID"

    # Resuming non-On-Hold file -> 409 IF_STATUS_TRANSITION_INVALID
    with pytest.raises(CodedHTTPException) as exc_info:
        imp_service.resume_import_file_service(db, file_obj.import_file_id)
    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.code == "IF_STATUS_TRANSITION_INVALID"

    # Reopening shipment sets status="In Progress", updates closure record, logs AuditLog
    reopen_actor = SimpleNamespace(username="reopener_user")
    reopen_payload = ReopenShipmentSubmit(reopen_reason="Supplier resolved export issues")
    reopened = imp_service.reopen_shipment_service(db, file_obj.import_file_id, reopen_payload, actor=reopen_actor)

    assert reopened.status == "In Progress"
    assert reopened.closure_reason is None
    assert reopened.closed_at_phase is None
    assert reopened.updated_by == "reopener_user"

    # Check closure record is updated to Reopened
    db.refresh(closure_rec)
    assert closure_rec.status == "Reopened"
    assert closure_rec.updated_by == "reopener_user"

    # Check AuditLog entry
    audit = (
        db.query(AuditLog)
        .filter(AuditLog.entity_type == "ImportFile", AuditLog.entity_id == file_obj.import_file_id)
        .order_by(AuditLog.log_id.desc())
        .first()
    )
    assert audit is not None
    assert audit.action == "REOPEN"
    assert audit.performed_by == "reopener_user"
    assert "Supplier resolved export issues" in audit.changes_summary


def test_ac5_legacy_row_tolerant_response(db: Session, client: TestClient, auth_headers: dict):
    """A legacy row with company_name='X' (1 char) does not break GET /import-files or ImportFileResponse."""
    legacy_file = ImportFile(
        import_file_code="IMP-2026-LEGACY",
        custom_file_number="CF-LEGACY",
        company_name="X",  # 1 char violates min_length=2 on Create/Base schema
        supplier_name="Y",  # 1 char violates min_length=2 on Create/Base schema
        status="Open",
        estimated_cost=100.0,
        actual_landed_cost_markup_factor=None,
        is_active=True,
    )
    db.add(legacy_file)
    db.commit()
    db.refresh(legacy_file)

    # 1. Pydantic model serialization via ImportFileResponse
    resp_model = ImportFileResponse.model_validate(legacy_file)
    assert resp_model.company_name == "X"
    assert resp_model.supplier_name == "Y"
    assert resp_model.actual_landed_cost_markup_factor is None

    # Test that a dict with None for estimated_cost doesn't fail validation
    raw_data = {
        "import_file_id": 999,
        "import_file_code": "IMP-2026-RAW",
        "company_name": "X",
        "supplier_name": "Y",
        "estimated_cost": None,
        "current_module": "BP-001",
        "current_stage": "Stage 1",
        "progress_percent": 0.0,
        "next_action": "Action",
        "status": "Open",
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
        "created_by": "System",
        "updated_at": datetime.now(timezone.utc),
        "updated_by": "System",
    }
    raw_resp = ImportFileResponse.model_validate(raw_data)
    assert raw_resp.company_name == "X"
    assert raw_resp.estimated_cost is None

    # 2. HTTP GET /import-files returns legacy row without 422/500
    res = client.get("/api/v1/import-files", headers=auth_headers)
    assert res.status_code == 200
    items = res.json()
    matched = [item for item in items if item["import_file_code"] == "IMP-2026-LEGACY"]
    assert len(matched) == 1
    assert matched[0]["company_name"] == "X"
    assert matched[0]["supplier_name"] == "Y"
