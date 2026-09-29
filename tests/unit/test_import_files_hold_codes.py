"""
Hold / resume with language-independent storage (single-language storage, Phase A).

- ``hold_reason_code`` (HOLD_REASON) is stored; a legacy chip label in ``hold_reason`` is mapped to its code;
  an unknown code -> 422 "رمز سبب الإيقاف غير معروف".
- ``paused_at_stage`` gets the English phase title resolved from a stage code; ``paused_at_step`` the step code.
- Bug fix: hold/resume never overwrite the file's user ``notes``. The system text goes to the lifecycle
  activities (msg_code + English notes, appended) and to an audit_logs HOLD/RESUME entry (keeps hold_notes).
"""
import importlib
from datetime import date

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401
import modules.auth.permissions as auth_permissions
import modules.import_files.service as service
from database.database import Base, get_db
from modules.audit_logs.model import AuditLog
from modules.import_companies.model import ImportCompany
from modules.import_files.schemas import ImportFileCreate
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.lifecycle_board.service import resolve_hold_stage

USER_NOTES = "ملاحظات المستخدم الأصلية - لا تُمسح"


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = factory()
    db.add(ImportCompany(company_id=1, importer_name="Egyptian Import Co", vat_id="100-200-300", registration_number="12345",
                         address="Cairo", country="Egypt", importer_id="IMP-001", importer_id_expiry=date(2028, 1, 1),
                         vat_id_expiry=date(2028, 1, 1), registration_expiry=date(2028, 1, 1)))
    db.commit()
    db.close()
    yield factory
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    yield session
    session.close()


def _file(db, number="6701069001"):
    created = service.create_import_file_service(
        db,
        ImportFileCreate(custom_file_number=number, company_id=1, company_name="Egyptian Import Co",
                         supplier_name="ABC China", notes=USER_NOTES),
    )
    db.query(ShipmentStageActivity).filter(ShipmentStageActivity.import_file_code == created.import_file_code).delete()
    db.add(ShipmentStageActivity(import_file_code=created.import_file_code, step_code="STEP_09",
                                 status="In-Progress", notes="Activated after STEP_08_COC completed"))
    db.commit()
    return created


def _activity(db, file_code):
    return db.query(ShipmentStageActivity).filter(ShipmentStageActivity.import_file_code == file_code,
                                                  ShipmentStageActivity.step_code == "STEP_09").one()


def _audit(db, file_id, action):
    return db.query(AuditLog).filter(AuditLog.entity_type == "ImportFile", AuditLog.entity_id == file_id,
                                     AuditLog.action == action).all()


# ─── Service ───────────────────────────────────────────────────────────────────

def test_hold_with_code_keeps_user_notes_and_writes_system_notes(db):
    created = _file(db)
    held = service.hold_import_file_service(
        db, created.import_file_id,
        hold_reason="Temporary administrative hold", hold_reason_code="ADMIN_HOLD",
        hold_notes="Waiting for GM", stage_name="Docs Customs Approval", step_name="STEP_09",
        performed_by="ops1",
    )
    assert held.status == "On Hold"
    assert held.notes == USER_NOTES  # the bug: this used to be replaced by Arabic system text
    assert held.hold_reason_code == "ADMIN_HOLD"
    assert held.hold_reason == "Temporary administrative hold"
    assert held.paused_at_stage == "Docs Customs Approval"  # explicit English title kept
    assert held.paused_at_step == "STEP_09"

    act = _activity(db, created.import_file_code)
    assert act.status == "On-Hold"
    assert act.msg_code == "LC_STEP_ON_HOLD_CODED"
    assert act.msg_params == {"reason_enum_hold_reason": "ADMIN_HOLD"}
    assert act.notes == "Activated after STEP_08_COC completed | On hold: Temporary administrative hold"

    [log] = _audit(db, created.import_file_id, "HOLD")
    assert log.performed_by == "ops1"
    assert log.changes_summary == (
        "Shipment put on hold at [Docs Customs Approval]: Temporary administrative hold | Waiting for GM"
    )
    assert "LC_FILE_ON_HOLD_WITH_NOTES" in log.new_values


def test_hold_with_legacy_arabic_label_derives_code_and_resolves_english_stage(db):
    created = _file(db, "6701069002")
    held = service.hold_import_file_service(
        db, created.import_file_id,
        hold_reason="في انتظار موافقة البنك وإصدار نموذج 4",
        stage_name="مراجعة وتدقيق مسودات مستندات الشحن",  # RTL title sent by old clients
        step_name="PHASE-4: STEP_11",
    )
    assert held.hold_reason_code == "AWAITING_BANK_FORM4"
    assert held.hold_reason == "في انتظار موافقة البنك وإصدار نموذج 4"  # user-visible text stored as sent
    assert held.paused_at_stage == "4. Digital & Banking"
    assert held.paused_at_step == "STEP_11"
    assert held.notes == USER_NOTES
    act = _activity(db, created.import_file_code)
    assert act.msg_code == "LC_STEP_ON_HOLD_CODED"
    assert act.notes.endswith("On hold: Awaiting bank Form 4 issuance")


def test_hold_with_free_text_has_no_code(db):
    created = _file(db, "6701069003")
    held = service.hold_import_file_service(db, created.import_file_id, hold_reason="Supplier factory closed for Eid")
    assert held.hold_reason_code is None
    act = _activity(db, created.import_file_code)
    assert act.msg_code == "LC_STEP_ON_HOLD"
    assert act.msg_params == {"reason": "Supplier factory closed for Eid"}
    assert held.notes == USER_NOTES
    assert held.paused_at_stage == created.current_stage  # nothing to resolve -> previous behaviour


def test_hold_with_unknown_code_is_422_and_changes_nothing(db):
    created = _file(db, "6701069004")
    with pytest.raises(HTTPException) as exc:
        service.hold_import_file_service(db, created.import_file_id, hold_reason="whatever reason",
                                         hold_reason_code="NOT_A_REASON")
    assert exc.value.status_code == 422
    assert exc.value.detail == "رمز سبب الإيقاف غير معروف"
    db.expire_all()
    assert _activity(db, created.import_file_code).status == "In-Progress"
    assert _audit(db, created.import_file_id, "HOLD") == []


def test_resume_keeps_user_notes_and_clears_code(db):
    created = _file(db, "6701069005")
    service.hold_import_file_service(db, created.import_file_id, hold_reason="Temporary administrative hold",
                                     hold_reason_code="ADMIN_HOLD")
    resumed = service.resume_import_file_service(db, created.import_file_id, resume_notes="GM approved",
                                                 performed_by="ops2")
    assert resumed.status == "In Progress"
    assert resumed.notes == USER_NOTES
    assert resumed.hold_reason is None and resumed.hold_reason_code is None
    act = _activity(db, created.import_file_code)
    assert act.status == "In-Progress"
    assert act.msg_code == "LC_STEP_RESUMED" and act.msg_params == {"notes": "GM approved"}
    assert act.notes.endswith("On hold: Temporary administrative hold | Resumed: GM approved")
    [log] = _audit(db, created.import_file_id, "RESUME")
    assert log.changes_summary == "Operations resumed: GM approved" and log.performed_by == "ops2"


@pytest.mark.parametrize(
    "stage_name,step_name,expected",
    [
        ("Customs Clearance", "PHASE-5", {"phase_id": 5, "step_code": None, "stage_title": "Customs Clearance"}),
        ("الإفراج الجمركي", "PHASE-5", {"phase_id": 5, "step_code": None, "stage_title": "5. Port Operations & Clearance"}),
        (None, "STEP_08_BL", {"phase_id": 3, "step_code": "STEP_08_BL", "stage_title": "3. Booking & Doc Prep"}),
        ("PHASE_6", None, {"phase_id": 6, "step_code": None, "stage_title": "6. Inbound & Final Closure"}),
        ("مرحلة غير معروفة", "PHASE-3-INS", {"phase_id": 3, "step_code": None, "stage_title": "3. Booking & Doc Prep"}),
        ("مرحلة غير معروفة", None, {"phase_id": None, "step_code": None, "stage_title": None}),
        (None, "STEP_99", {"phase_id": None, "step_code": None, "stage_title": None}),
    ],
)
def test_resolve_hold_stage(stage_name, step_name, expected):
    assert resolve_hold_stage(stage_name, step_name) == expected


# ─── HTTP ──────────────────────────────────────────────────────────────────────

@pytest.fixture
def client(session_factory):
    router_module = importlib.import_module("modules.import_files.router")
    app = FastAPI()
    app.include_router(router_module.router)

    def _get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = _get_db
    auth_permissions.invalidate_permission_cache()
    yield TestClient(app)
    auth_permissions.invalidate_permission_cache()


def _hold_path(client, session_factory):
    db = session_factory()
    try:
        created = _file(db, "6701069100")
        return f"/api/v1/import-files/{created.import_file_id}/hold", created.import_file_id
    finally:
        db.close()


def test_hold_endpoint_requires_auth(client, session_factory, monkeypatch):
    path, _ = _hold_path(client, session_factory)
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    res = client.post(path, json={"hold_reason": "Temporary administrative hold", "hold_reason_code": "ADMIN_HOLD"})
    assert res.status_code == 401


def test_hold_endpoint_contract(client, session_factory):
    path, file_id = _hold_path(client, session_factory)
    bad = client.post(path, json={"hold_reason": "Temporary administrative hold", "hold_reason_code": "NOPE"})
    assert bad.status_code == 422, bad.text
    assert bad.json()["detail"] == "رمز سبب الإيقاف غير معروف"

    ok = client.post(path, json={"hold_reason": "Temporary administrative hold", "hold_reason_code": "ADMIN_HOLD",
                                 "stage_name": "Docs Customs Approval", "step_name": "STEP_09"})
    assert ok.status_code == 200, ok.text
    body = ok.json()
    assert body["hold_reason_code"] == "ADMIN_HOLD"
    assert body["notes"] == USER_NOTES
    for key in ("current_step_code", "current_phase_id", "current_stage_code", "next_action_code", "next_action_params"):
        assert key in body  # additive nullable fields
