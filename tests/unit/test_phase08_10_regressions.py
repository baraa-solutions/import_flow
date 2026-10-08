"""
Phases 8 / 10 regression tests, one per BLOCKER / CRITICAL fix of docs/plans/phase-08-10-quality-plan.md
(plus the MAJOR fixes that change the API contract).
"""
import importlib
from datetime import date, datetime, timedelta, timezone

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model)
import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.file_closure import repository as fc_repo
from modules.file_closure import service as fc_service
from modules.file_closure.model import ImportFileClosureRecord
from modules.file_closure.schemas import FileClosureCreate, FileClosureUpdate
from modules.file_closure.validators import ClosureFacts, evaluate_closure_gate
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.import_files.model import ImportFile
from modules.inland_transport.model import InlandTransportBooking
from modules.inland_transport.schemas import (
    InlandTransportArrivalSubmit,
    InlandTransportBookingCreate,
    InlandTransportBookingUpdate,
    InlandTransportGateOutSubmit,
)
from modules.inland_transport import service as it_service
from modules.notifications.model import SystemNotification
from modules.users.model import Role, User
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import (
    DiscrepancyReportSubmit,
    GrnItemSchema,
    WarehouseInspectionSubmit,
    WarehouseReceivingCreate,
    WarehouseReceivingUpdate,
)
from modules.warehouse_receiving import service as wr_service

wr_router = importlib.import_module("modules.warehouse_receiving.router")
it_router = importlib.import_module("modules.inland_transport.router")
fc_router = importlib.import_module("modules.file_closure.router")


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    invalidate_permission_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    invalidate_permission_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    yield session
    session.close()


def _file(db, code="IMP-REG-0001", **extra) -> ImportFile:
    imp = ImportFile(import_file_code=code, company_name="Co", supplier_name="Sup", status="Active",
                     progress_percent=90.0, is_active=True, **extra)
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _wr_file(db, code="IMP-REG-0001", **extra) -> ImportFile:
    return _file(db, code, is_customs_released=True, **extra)


def _items(*rows):
    return [GrnItemSchema(item_code=f"I{n}", item_name=f"Item {n}", invoiced_qty=i, accepted_qty=a, shortage_qty=s,
                          damaged_qty=d) for n, (i, a, s, d) in enumerate(rows)]


def _grn(file_id, items=None):
    return WarehouseReceivingCreate(import_file_id=file_id, warehouse_name="WH", grn_items=items or _items((10, 10, 0, 0)))


def _booking(file_id, waybill="WB-1"):
    now = datetime.now(timezone.utc)
    return InlandTransportBookingCreate(
        import_file_id=file_id, waybill_number=waybill, carrier_name="Carrier", truck_plate_number="ABC 1",
        truck_type="FLATBED",
        driver_name="Driver", driver_phone="0101234567", pickup_port_location="Port", destination_warehouse="WH",
        planned_departure_at=now + timedelta(hours=1), expected_arrival_at=now + timedelta(hours=5),
        transport_fare_egp=1000.0,
    )


def _ready_file(db, code="IMP-REG-READY", **extra) -> ImportFile:
    imp = _file(db, code, customs_release_permit_no="REL-1", dossier_exported_at=datetime.now(timezone.utc),
                current_module="Phase 10 - Comprehensive Dossier Export & Digital Archiving", **extra)
    db.add_all([
        WarehouseReceivingRecord(grn_code=f"GRN-{code}", import_file_id=imp.import_file_id, warehouse_name="WH", is_active=True),
        LandedCostSettlementRecord(settlement_code=f"SET-{code}", import_file_id=imp.import_file_id,
                                   status="Calculated", total_landed_cost_egp=100.0, is_active=True),
    ])
    db.commit()
    return imp


# ─── Permissions (WR-01, IT-01, FC-06) ───────────────────────────────────────

@pytest.fixture
def strict_client(session_factory, monkeypatch):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    app = FastAPI()
    for module in (wr_router, it_router, fc_router):
        app.include_router(module.router)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app, raise_server_exceptions=False)


def _user(db, username, role_code) -> User:
    role = db.query(Role).filter(Role.role_code == role_code).one()
    user = User(username=username, email=f"{username}@t.com", full_name=username,
                hashed_password=hash_password("Password123"), role=role.role_code, role_id=role.role_id, is_active=True)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _bearer(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}


@pytest.fixture
def rbac(db):
    seed_rbac(db)
    return {
        "viewer": _user(db, "reg_viewer", "AUDITOR_VIEWER"),
        "operator": _user(db, "reg_operator", "LOGISTICS_OPERATOR"),
        "manager": _user(db, "reg_manager", "GENERAL_MANAGER"),
    }


@pytest.mark.parametrize("method,path", [
    ("POST", "/api/v1/warehouse-receiving"),
    ("PUT", "/api/v1/warehouse-receiving/1"),
    ("DELETE", "/api/v1/warehouse-receiving/1"),
    ("POST", "/api/v1/warehouse-receiving/1/inspection-protocol"),
    ("POST", "/api/v1/inland-transport/bookings"),
    ("POST", "/api/v1/inland-transport/bookings/1/gate-out"),
    ("DELETE", "/api/v1/inland-transport/bookings/1"),
    ("POST", "/api/v1/file-closure/official-close"),
    ("DELETE", "/api/v1/file-closure/1"),
    ("PUT", "/api/v1/file-closure/1"),
    # confirm-dossier-export: view at the route, edit|close in the service (see test_confirm_dossier_export_...)
])
def test_viewer_gets_403_on_mutations(strict_client, rbac, method, path):
    res = strict_client.request(method, path, headers=_bearer(rbac["viewer"]), json={})
    assert res.status_code == 403


@pytest.mark.parametrize("path", [
    "/api/v1/warehouse-receiving",
    "/api/v1/inland-transport/bookings",
    "/api/v1/file-closure",
])
def test_viewer_can_read(strict_client, rbac, path):
    assert strict_client.get(path, headers=_bearer(rbac["viewer"])).status_code == 200


def test_no_token_is_401(strict_client):
    assert strict_client.get("/api/v1/warehouse-receiving").status_code == 401


def test_closure_post_permission_depends_on_draft_flag(strict_client, rbac, db):
    imp = _file(db, "IMP-REG-PERM")
    final = {"import_file_id": imp.import_file_id, "is_draft": False}
    draft = {"import_file_id": imp.import_file_id, "is_draft": True}
    assert strict_client.post("/api/v1/file-closure", json=final, headers=_bearer(rbac["viewer"])).status_code == 403
    assert strict_client.post("/api/v1/file-closure", json=draft, headers=_bearer(rbac["viewer"])).status_code == 403
    # operator has import_files.edit but not .close
    assert strict_client.post("/api/v1/file-closure", json=final, headers=_bearer(rbac["operator"])).status_code == 403
    res = strict_client.post("/api/v1/file-closure", json=draft, headers=_bearer(rbac["operator"]))
    assert res.status_code == 201
    assert res.json()["status"] == "Draft"
    assert res.json()["auditor_name"] == "reg_operator"  # FC-10
    # manager has .close: passes auth, then the server gate blocks (nothing is ready)
    res = strict_client.post("/api/v1/file-closure", json=final, headers=_bearer(rbac["manager"]))
    assert res.status_code == 400
    assert res.json()["detail"]["code"] == "FC_CLOSURE_BLOCKED"


def test_wr_create_records_signed_in_user(strict_client, rbac, db):
    imp = _wr_file(db, "IMP-REG-WRUSER")
    body = {"import_file_id": imp.import_file_id, "warehouse_name": "WH", "grn_items": [
        {"item_code": "A", "item_name": "A", "invoiced_qty": 5, "accepted_qty": 5}]}
    res = strict_client.post("/api/v1/warehouse-receiving", json=body, headers=_bearer(rbac["operator"]))
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["created_by"] == "reg_operator"
    assert data["inspector_name"] == "reg_operator"  # WR-06: no "Kamal" default


# ─── Warehouse receiving ─────────────────────────────────────────────────────

def test_wr02_second_grn_is_409_with_code(db):
    imp = _wr_file(db)
    first = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id), user="u")
    with pytest.raises(HTTPException) as exc:
        wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id), user="u")
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "WR_GRN_EXISTS"
    assert exc.value.detail["grn_code"] == first.grn_code


def test_wr02_create_writes_audit_row(db):
    from modules.audit_logs.model import AuditLog
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id), user="auditor-u")
    log = db.query(AuditLog).filter(AuditLog.entity_type == "WarehouseReceivingRecord",
                                    AuditLog.entity_id == rec.receiving_id).one()
    assert log.entity_code == rec.grn_code
    assert log.performed_by == "auditor-u"


def test_wr03_accepted_full_with_shortage_is_400(db):
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id, _items((10, 8, 2, 0))))
    with pytest.raises(HTTPException) as exc:
        wr_service.submit_warehouse_inspection_protocol_service(
            db, rec.receiving_id, WarehouseInspectionSubmit(inspection_verdict="ACCEPTED_FULL"))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "WR_VERDICT_INCONSISTENT"


def test_wr03_unknown_verdict_is_400_and_default_committee_english(db):
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        wr_service.submit_warehouse_inspection_protocol_service(
            db, rec.receiving_id, WarehouseInspectionSubmit(inspection_verdict="LOOKS_FINE"))
    assert exc.value.detail["code"] == "WR_VERDICT_INVALID"
    out = wr_service.submit_warehouse_inspection_protocol_service(db, rec.receiving_id, WarehouseInspectionSubmit())
    assert out.inspection_verdict == "ACCEPTED_FULL"
    assert out.inspection_committee == wr_service.DEFAULT_INSPECTION_COMMITTEE


def test_wr04_unbalanced_line_is_400_and_excess_allowed(db):
    imp = _wr_file(db)
    with pytest.raises(HTTPException) as exc:
        wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id, _items((10, 10, 2, 0))))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] == "WR_GRN_LINE_UNBALANCED"
    assert exc.value.detail["item_code"] == "I0"
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id, _items((10, 12, 0, 0))))
    assert rec.discrepancy_type == "Excess"
    with pytest.raises(HTTPException):
        wr_service.update_warehouse_receiving_service(
            db, rec.receiving_id, WarehouseReceivingUpdate(grn_items=_items((10, 5, 0, 0))))


def test_wr07_put_rejects_unknown_status(db):
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        wr_service.update_warehouse_receiving_service(db, rec.receiving_id, WarehouseReceivingUpdate(status="Whatever"))
    assert exc.value.detail["code"] == "WR_STATUS_INVALID"
    out = wr_service.update_warehouse_receiving_service(db, rec.receiving_id, WarehouseReceivingUpdate(status="GRN Audited"), user="u2")
    assert out.status == "GRN Audited" and out.updated_by == "u2"


def test_wr09_restore_with_other_active_grn_is_409(db):
    imp = _wr_file(db)
    first = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id))
    wr_service.soft_delete_warehouse_receiving_service(db, first.receiving_id)
    second = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id))
    assert second.grn_code != first.grn_code  # WR-08: yearly sequence, deletions never reuse a number
    with pytest.raises(HTTPException) as exc:
        wr_service.restore_warehouse_receiving_service(db, first.receiving_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["grn_code"] == second.grn_code


# ─── Inland transport ────────────────────────────────────────────────────────

def test_it02_retried_create_is_409(db):
    imp = _file(db)
    first = it_service.create_transport_booking_service(db, _booking(imp.import_file_id, "WB-7"))
    with pytest.raises(HTTPException) as exc:
        it_service.create_transport_booking_service(db, _booking(imp.import_file_id, "  wb-7 "))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IT_BOOKING_EXISTS"
    assert exc.value.detail["transport_code"] == first.transport_code
    # another truck (different waybill) is still allowed
    it_service.create_transport_booking_service(db, _booking(imp.import_file_id, "WB-8"))


def test_it03_deleted_booking_is_404(db):
    imp = _file(db)
    b = it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    it_service.soft_delete_transport_booking_service(db, b.transport_id)
    with pytest.raises(HTTPException) as exc:
        it_service.record_port_gate_out_service(db, b.transport_id, InlandTransportGateOutSubmit())
    assert exc.value.status_code == 404


def test_it04_notification_row_exists(db):
    imp = _file(db)
    it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    notif = db.query(SystemNotification).filter(SystemNotification.msg_code == "TR_BOOKING_CONFIRMED").one()
    assert notif.entity_type == "ImportFile" and notif.entity_id == imp.import_file_id


def test_it05_gate_out_after_arrival_is_409(db):
    imp = _file(db)
    b = it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    later = datetime.now(timezone.utc) + timedelta(hours=3)
    it_service.record_warehouse_arrival_service(db, b.transport_id, InlandTransportArrivalSubmit(actual_arrival_at=later))
    with pytest.raises(HTTPException) as exc:
        it_service.record_port_gate_out_service(db, b.transport_id, InlandTransportGateOutSubmit())
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IT_TRANSITION_NOT_ALLOWED"
    with pytest.raises(HTTPException) as exc:
        it_service.record_warehouse_arrival_service(db, b.transport_id, InlandTransportArrivalSubmit())
    assert exc.value.status_code == 409


def test_it05_put_validates_status_and_merged_dates(db):
    imp = _file(db)
    b = it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        it_service.update_transport_booking_service(db, b.transport_id, InlandTransportBookingUpdate(status="Flying"))
    assert exc.value.detail["code"] == "IT_STATUS_INVALID"
    with pytest.raises(HTTPException) as exc:
        it_service.update_transport_booking_service(
            db, b.transport_id,
            InlandTransportBookingUpdate(expected_arrival_at=datetime.now(timezone.utc) - timedelta(days=1)))
    assert exc.value.status_code == 400


# ─── File closure ────────────────────────────────────────────────────────────

def test_fc01_empty_checklist_without_prerequisites_is_400(db):
    imp = _file(db)
    with pytest.raises(HTTPException) as exc:
        fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    assert exc.value.status_code == 400
    blocking = exc.value.detail["blocking"]
    assert {"customs_cleared", "warehouse_received", "landed_cost_settled", "dossier_exported"} <= set(blocking)
    db.refresh(imp)
    assert imp.status == "Active"


def test_fc01_db_error_fails_the_close(db, monkeypatch):
    imp = _ready_file(db)

    def broken(*_a, **_k):
        raise RuntimeError("db down")

    monkeypatch.setattr(fc_repo, "has_final_release_clearance", broken)
    with pytest.raises(RuntimeError):
        fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    db.rollback()
    db.refresh(imp)
    assert imp.status == "Active"


def test_fc01_quarantined_grn_blocks(db):
    imp = _ready_file(db)
    db.query(WarehouseReceivingRecord).filter(WarehouseReceivingRecord.import_file_id == imp.import_file_id).update(
        {"quarantine_lock_active": True})
    db.commit()
    with pytest.raises(HTTPException) as exc:
        fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    assert exc.value.detail["blocking"] == ["warehouse_quarantine"]


@pytest.mark.parametrize("customs,grn,landed,dossier,skipped", [
    (c, g, l, d, s)
    for c in (False, True) for g in (False, True) for l in (False, True) for d in (False, True)
    for s in ([], ["STEP_13", "STEP_19", "STEP_20"])
])
def test_fc03_precheck_and_close_agree(db, customs, grn, landed, dossier, skipped):
    imp = _file(db, skipped_stages=skipped,
                customs_release_permit_no="REL" if customs else None,
                dossier_exported_at=datetime.now(timezone.utc) if dossier else None,
                actual_landed_cost_total_egp=10.0 if landed else 0.0)
    if grn:
        db.add(WarehouseReceivingRecord(grn_code="GRN-M", import_file_id=imp.import_file_id, warehouse_name="WH", is_active=True))
        db.commit()
    pre = fc_service.get_closure_precheck_service(db, imp.import_file_id)
    try:
        fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
        closed = True
    except HTTPException as exc:
        assert exc.status_code == 400
        closed = False
    assert pre.can_close is closed


def test_fc04_second_close_is_409_and_draft_on_closed_is_409(db):
    imp = _ready_file(db)
    fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    for draft in (False, True):
        with pytest.raises(HTTPException) as exc:
            fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=draft))
        assert exc.value.status_code == 409
        assert exc.value.detail["code"] == "FC_ALREADY_CLOSED"
    assert db.query(SystemNotification).filter(SystemNotification.msg_code == "CLO_FILE_CLOSED").count() == 1


def test_fc05_closed_at_phase_is_set(db):
    imp = _ready_file(db)
    rec = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id), user="closer")
    db.refresh(imp)
    assert imp.closed_at_phase == "Phase 10 - Comprehensive Dossier Export & Digital Archiving"
    assert rec.closed_at is not None
    assert rec.auditor_name == "closer"


def test_fc09_restore_with_other_active_closure_is_409_and_put_locks_closed(db):
    imp = _file(db)
    first = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=True))
    fc_service.soft_delete_closure_service(db, first.closure_id)
    second = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=True))
    with pytest.raises(HTTPException) as exc:
        fc_service.restore_closure_service(db, first.closure_id)
    assert exc.value.status_code == 409 and exc.value.detail["closure_code"] == second.closure_code
    with pytest.raises(HTTPException) as exc:
        fc_service.update_closure_service(db, second.closure_id, FileClosureUpdate(status="Closed"))
    assert exc.value.detail["code"] == "FC_STATUS_INVALID"
    second.status = "Closed"
    imp.status = "Closed"  # the lock applies while the file itself is Closed (same rule as DELETE)
    db.commit()
    with pytest.raises(HTTPException) as exc:
        fc_service.update_closure_service(db, second.closure_id, FileClosureUpdate(auditor_name="x"))
    assert exc.value.detail["code"] == "FC_CLOSED_RECORD_LOCKED"
    ok = fc_service.update_closure_service(db, second.closure_id, FileClosureUpdate(archival_notes="note"))
    assert ok.archival_notes == "note"


def test_fc12_precheck_preview_matches_issued_code(db):
    imp = _ready_file(db)
    preview = fc_service.get_closure_precheck_service(db, imp.import_file_id).certificate_code_preview
    rec = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    assert rec.closure_code == preview


def test_fc02_no_rate_gives_null_never_48_5(db):
    fc_repo  # noqa: B018
    imp = _file(db, estimated_cost=100.0, estimated_cost_currency="USD")
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.total_fob_egp is None
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.flush()
    db.add(ExchangeRate(currency_id=usd.currency_id, customs_rate=50.0, commercial_rate=51.0,
                        effective_date=date.today() - timedelta(days=1), is_active=True))
    db.commit()
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.total_fob_egp == 5000.0


def test_fc07_dossier_without_broker_or_master_data_invents_nothing(db):
    imp = _file(db, empty_containers_return_status="PENDING_RETURN")
    imp.company_name = ""
    imp.supplier_name = ""
    db.commit()
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.company_name == "" and res.supplier_name == ""
    assert res.broker_name is None and res.customs_office is None and res.warehouse_name is None
    # model defaults (e.g. shipment_mode "Sea FCL") are real stored values; only missing values become ""
    assert res.incoterm_code == (imp.incoterm_code or "") and res.priority == (imp.priority or "")
    assert res.target_free_days == int(imp.target_free_days or 0)
    assert all(not i["description"] or i["description"] != "بند استيرادي" for i in res.items_detail)
    assert res.closure_readiness["empty_containers_returned"] is False


def test_fc08_deleted_grn_is_not_received(db):
    imp = _file(db)
    db.add(WarehouseReceivingRecord(grn_code="GRN-DEL", import_file_id=imp.import_file_id, warehouse_name="WH", is_active=False))
    db.commit()
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.closure_readiness["warehouse_received"] is False
    assert res.warehouse_grn_code is None


def test_gate_containers_and_docs_are_warnings_only():
    gate = evaluate_closure_gate(ClosureFacts(
        has_final_release_clearance=True, active_grn_count=1, has_settled_settlement=True,
        dossier_exported_at=datetime.now(), shipment_mode="SEA", empty_containers_return_status="PENDING_RETURN",
        open_operational_task_count=2,
    ))
    assert gate.can_close
    assert gate.checklist["empty_containers_returned"] is False
    assert gate.checklist["docs_verified"] is False
    assert gate.checklist["tasks_closed"] is False
    assert len(gate.warnings) == 3


def _usd_rates(db, *rows):
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.flush()
    for eff, rate in rows:
        db.add(ExchangeRate(currency_id=usd.currency_id, customs_rate=rate, commercial_rate=rate,
                            effective_date=eff, is_active=True))
    db.commit()


def test_fc02_stored_clearance_rate_wins_when_single_currency(db):
    imp = _file(db, estimated_cost=100.0, estimated_cost_currency="USD")
    _usd_rates(db, (date.today() - timedelta(days=30), 50.0))
    db.add(CustomsClearanceRecord(clearance_code="CC-FX", import_file_id=imp.import_file_id,
                                  customs_exchange_rate=47.25, is_active=True))
    db.commit()
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.total_fob_egp == 4725.0


def test_fc02_default_clearance_rate_ignored_and_form46_date_preferred(db):
    today = date.today()
    form46 = datetime.combine(today - timedelta(days=20), datetime.min.time())
    released = datetime.combine(today - timedelta(days=5), datetime.min.time())
    imp = _file(db, estimated_cost=100.0, estimated_cost_currency="USD", form46_date=form46, customs_released_at=released)
    # rate valid on the Form 46 date = 40, a newer rate valid on the release date = 60
    _usd_rates(db, (today - timedelta(days=25), 40.0), (today - timedelta(days=10), 60.0))
    db.add(CustomsClearanceRecord(clearance_code="CC-DEF", import_file_id=imp.import_file_id,
                                  customs_exchange_rate=1.0, is_active=True))  # column default: never entered
    db.commit()
    res = fc_service.get_comprehensive_shipment_dossier_service(db, imp.import_file_id)
    assert res.total_fob_egp == 4000.0


# ─── Diff-review follow-ups ──────────────────────────────────────────────────

def test_confirm_dossier_export_accepts_edit_or_close(strict_client, rbac, db):
    imp = _ready_file(db, "IMP-REG-DOSSIER")
    imp.dossier_exported_at = None
    db.commit()
    body = {"import_file_id": imp.import_file_id}
    assert strict_client.post("/api/v1/file-closure/confirm-dossier-export", json=body,
                              headers=_bearer(rbac["viewer"])).status_code == 403
    res = strict_client.post("/api/v1/file-closure/confirm-dossier-export", json=body, headers=_bearer(rbac["manager"]))
    assert res.status_code == 200, res.text
    assert res.json()["dossier_exported_by"] == "reg_manager"


@pytest.mark.parametrize("rows,quarantine,verdict", [
    ((10, 10, 0, 0), False, "ACCEPTED_WITH_DISCREPANCY"),  # clean receipt
    ((10, 8, 2, 0), False, "REJECTED_QUARANTINED"),  # discrepancy, no quarantine
    ((10, 10, 0, 0), True, "ACCEPTED_WITH_DISCREPANCY"),  # quarantine branch
])
def test_wr_verdict_contradicting_outcome_is_400(db, rows, quarantine, verdict):
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id, _items(rows)))
    with pytest.raises(HTTPException) as exc:
        wr_service.submit_warehouse_inspection_protocol_service(
            db, rec.receiving_id,
            WarehouseInspectionSubmit(inspection_verdict=verdict, quarantine_zone_assigned=quarantine))
    assert exc.value.status_code == 400
    assert exc.value.detail["code"] in {"WR_VERDICT_INCONSISTENT", "WR_VERDICT_INCONSISTENT_EXPECTED"}


def test_wr_damage_claim_pending_allowed_with_discrepancy(db):
    imp = _wr_file(db)
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id, _items((10, 8, 0, 2))))
    out = wr_service.submit_warehouse_inspection_protocol_service(
        db, rec.receiving_id, WarehouseInspectionSubmit(inspection_verdict="DAMAGE_CLAIM_PENDING"))
    assert out.inspection_verdict == "DAMAGE_CLAIM_PENDING"


def test_it_put_status_change_goes_through_transition_rules(db):
    imp = _file(db)
    b = it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        it_service.update_transport_booking_service(db, b.transport_id, InlandTransportBookingUpdate(status="Arrived at Warehouse"))
    assert exc.value.status_code == 409
    assert exc.value.detail["action"] == "status_change"
    out = it_service.update_transport_booking_service(db, b.transport_id, InlandTransportBookingUpdate(status="Dispatched"))
    assert out.status == "Dispatched"


def test_it_tr01_autocomplete_does_not_close_coded_unrelated_task(db):
    from modules.smart_tasks.model import SmartTask
    imp = _file(db)
    unrelated = SmartTask(task_code="TSK-X1", title="نقل مستندات للبنك", import_file_id=imp.import_file_id,
                          status="Pending", msg_code="DOC_TASK_SOMETHING", is_active=True)
    legacy = SmartTask(task_code="TSK-X2", title="حجز النقل الداخلي TR-01", import_file_id=imp.import_file_id,
                       status="Pending", is_active=True)
    db.add_all([unrelated, legacy])
    db.commit()
    it_service.create_transport_booking_service(db, _booking(imp.import_file_id))
    db.refresh(unrelated)
    db.refresh(legacy)
    assert unrelated.status == "Pending"
    assert legacy.status == "Completed"


def test_precheck_preview_shows_existing_draft_code(db):
    imp = _ready_file(db)
    draft = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=True))
    pre = fc_service.get_closure_precheck_service(db, imp.import_file_id)
    assert pre.certificate_code_preview == draft.closure_code
    rec = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    assert rec.closure_code == draft.closure_code


def test_put_lock_follows_file_status(db):
    imp = _ready_file(db)
    rec = fc_service.close_import_file_service(db, FileClosureCreate(import_file_id=imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        fc_service.update_closure_service(db, rec.closure_id, FileClosureUpdate(auditor_name="x"))
    assert exc.value.status_code == 409
    imp.status = "Active"  # reopened
    db.commit()
    out = fc_service.update_closure_service(
        db,
        rec.closure_id,
        FileClosureUpdate(auditor_name="Spoofed In Body"),
        user="Reviewer",
    )
    assert out.auditor_name == "Reviewer"
def test_be810_t18_pagination_grn_and_it(strict_client, db, rbac):
    """BE810-T18: /paginated contract and skip/limit + X-Total-Count on WR and IT lists."""
    file1 = _wr_file(db, code="IMP-PAG-0001")
    file2 = _wr_file(db, code="IMP-PAG-0002")
    file3 = _wr_file(db, code="IMP-PAG-0003")

    now = datetime.now(timezone.utc)
    # Seed 3 GRNs
    rec1 = WarehouseReceivingRecord(grn_code="GRN-PAG-001", import_file_id=file1.import_file_id, warehouse_name="WH-1", created_at=now, is_active=True)
    rec2 = WarehouseReceivingRecord(grn_code="GRN-PAG-002", import_file_id=file2.import_file_id, warehouse_name="WH-2", created_at=now, is_active=True)
    rec3 = WarehouseReceivingRecord(grn_code="GRN-PAG-003", import_file_id=file3.import_file_id, warehouse_name="WH-3", created_at=now, is_active=True)
    db.add_all([rec1, rec2, rec3])

    # Seed 3 IT Bookings
    db.add_all([
        InlandTransportBooking(transport_code="TR-PAG-001", import_file_id=file1.import_file_id, waybill_number="WB-001",
                               carrier_name="Carrier", truck_plate_number="A1", truck_type="Trailer", driver_name="D1", driver_phone="010111",
                               pickup_port_location="Port", destination_warehouse="WH-1", planned_departure_at=now, expected_arrival_at=now,
                               status="Booking Confirmed", created_at=now, is_active=True),
        InlandTransportBooking(transport_code="TR-PAG-002", import_file_id=file2.import_file_id, waybill_number="WB-002",
                               carrier_name="Carrier", truck_plate_number="A2", truck_type="Trailer", driver_name="D2", driver_phone="010222",
                               pickup_port_location="Port", destination_warehouse="WH-2", planned_departure_at=now, expected_arrival_at=now,
                               status="Booking Confirmed", created_at=now, is_active=True),
        InlandTransportBooking(transport_code="TR-PAG-003", import_file_id=file3.import_file_id, waybill_number="WB-003",
                               carrier_name="Carrier", truck_plate_number="A3", truck_type="Trailer", driver_name="D3", driver_phone="010333",
                               pickup_port_location="Port", destination_warehouse="WH-3", planned_departure_at=now, expected_arrival_at=now,
                               status="Booking Confirmed", created_at=now, is_active=True),
    ])
    db.commit()

    headers = _bearer(rbac["operator"])

    # 1. WR skip/limit and X-Total-Count
    resp_wr_list = strict_client.get("/api/v1/warehouse-receiving?limit=2", headers=headers)
    assert resp_wr_list.status_code == 200, resp_wr_list.text
    assert len(resp_wr_list.json()) == 2
    assert resp_wr_list.headers.get("X-Total-Count") == "3"

    # WR skip=2 & limit=2 returns 1 item with X-Total-Count 3
    resp_wr_skip = strict_client.get("/api/v1/warehouse-receiving?skip=2&limit=2", headers=headers)
    assert resp_wr_skip.status_code == 200
    assert len(resp_wr_skip.json()) == 1
    assert resp_wr_skip.headers.get("X-Total-Count") == "3"

    # WR search=PAG-002 returns 1 row
    resp_wr_search = strict_client.get("/api/v1/warehouse-receiving?search=PAG-002", headers=headers)
    assert resp_wr_search.status_code == 200
    assert len(resp_wr_search.json()) == 1
    assert resp_wr_search.json()[0]["grn_code"] == "GRN-PAG-002"

    # Soft-delete one GRN: active total is 2, include_inactive=true gives 3
    rec3.is_active = False
    db.commit()
    resp_wr_active = strict_client.get("/api/v1/warehouse-receiving", headers=headers)
    assert resp_wr_active.status_code == 200
    assert len(resp_wr_active.json()) == 2
    assert resp_wr_active.headers.get("X-Total-Count") == "2"

    resp_wr_all = strict_client.get("/api/v1/warehouse-receiving?include_inactive=true", headers=headers)
    assert resp_wr_all.status_code == 200
    assert len(resp_wr_all.json()) == 3
    assert resp_wr_all.headers.get("X-Total-Count") == "3"
    rec3.is_active = True
    db.commit()

    # 2. WR /paginated endpoint
    resp_wr_page = strict_client.get("/api/v1/warehouse-receiving/paginated?page=1&page_size=2", headers=headers)
    assert resp_wr_page.status_code == 200, resp_wr_page.text
    wr_body = resp_wr_page.json()
    assert wr_body["total"] == 3
    assert wr_body["page"] == 1
    assert wr_body["page_size"] == 2
    assert wr_body["total_pages"] == 2
    assert len(wr_body["items"]) == 2
    assert resp_wr_page.headers.get("X-Total-Count") == "3"

    # WR /paginated sorting
    resp_wr_sort = strict_client.get("/api/v1/warehouse-receiving/paginated?sort=grn_code", headers=headers)
    assert resp_wr_sort.status_code == 200, resp_wr_sort.text
    assert resp_wr_sort.json()["items"][0]["grn_code"] == "GRN-PAG-001"

    # 3. IT skip/limit and X-Total-Count
    resp_it_list = strict_client.get("/api/v1/inland-transport/bookings?limit=2", headers=headers)
    assert resp_it_list.status_code == 200, resp_it_list.text
    assert len(resp_it_list.json()) == 2
    assert resp_it_list.headers.get("X-Total-Count") == "3"

    # 4. IT /bookings/paginated and /paginated endpoints
    resp_it_page = strict_client.get("/api/v1/inland-transport/bookings/paginated?page=2&page_size=2", headers=headers)
    assert resp_it_page.status_code == 200, resp_it_page.text
    it_body = resp_it_page.json()
    assert it_body["total"] == 3
    assert it_body["page"] == 2
    assert it_body["page_size"] == 2
    assert it_body["total_pages"] == 2
    assert len(it_body["items"]) == 1
    assert resp_it_page.headers.get("X-Total-Count") == "3"

    # IT alias endpoint /api/v1/inland-transport/paginated
    resp_it_alias = strict_client.get("/api/v1/inland-transport/paginated?page=1&page_size=10", headers=headers)
    assert resp_it_alias.status_code == 200, resp_it_alias.text
    assert resp_it_alias.json()["total"] == 3

    # Negative security tests:
    # No auth header -> 401
    assert strict_client.get("/api/v1/warehouse-receiving/paginated").status_code == 401
    assert strict_client.get("/api/v1/inland-transport/paginated").status_code == 401

    # Invalid sort field -> 400
    resp_bad_sort = strict_client.get("/api/v1/warehouse-receiving/paginated?sort=driver_phone", headers=headers)
    assert resp_bad_sort.status_code == 400
    assert resp_bad_sort.json()["detail"]["code"] == "LIST_SORT_FIELD_INVALID"


def test_closed_file_blocks_warehouse_receiving_writes(db):
    imp = _wr_file(db, code="IMP-WR-CLOSED")
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id))

    # Close the file
    imp.status = "Closed"
    db.commit()

    # 1. Update (PUT) -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        wr_service.update_warehouse_receiving_service(db, rec.receiving_id, WarehouseReceivingUpdate(notes="updated"))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc.value.detail.get("import_file_code") == "IMP-WR-CLOSED"

    # 2. Report Discrepancy -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        wr_service.report_receiving_discrepancy_service(
            db, rec.receiving_id,
            DiscrepancyReportSubmit(discrepancy_type="Shortage", discrepancy_notes="Shortage notes"),
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 3. Inspection -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        wr_service.submit_warehouse_inspection_protocol_service(
            db, rec.receiving_id,
            WarehouseInspectionSubmit(inspection_verdict="ACCEPTED_FULL"),
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 4. Soft Delete -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        wr_service.soft_delete_warehouse_receiving_service(db, rec.receiving_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 5. Restore -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        wr_service.restore_warehouse_receiving_service(db, rec.receiving_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 6. Create on closed file -> 409 IMPORT_FILE_CLOSED
    imp2 = _file(db, code="IMP-WR-CLOSED-2")
    imp2.status = "Closed"
    db.commit()
    with pytest.raises(HTTPException) as exc:
        wr_service.create_warehouse_receiving_service(db, _grn(imp2.import_file_id))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # Reads still work
    loaded = wr_service.get_warehouse_receiving_service(db, rec.receiving_id)
    assert loaded.receiving_id == rec.receiving_id


def test_closed_file_blocks_inland_transport_writes(db):
    imp = _file(db, code="IMP-IT-CLOSED", current_module="Phase 7 - Customs Clearance")
    b = it_service.create_transport_booking_service(db, _booking(imp.import_file_id, waybill="WB-IT-1"))

    # Close the file
    imp.status = "Closed"
    db.commit()

    # 1. Create on closed file -> 409 IMPORT_FILE_CLOSED and current_module unchanged
    imp2 = _file(db, code="IMP-IT-CLOSED-2", current_module="Phase 10 - File Closure")
    imp2.status = "Closed"
    db.commit()
    with pytest.raises(HTTPException) as exc:
        it_service.create_transport_booking_service(db, _booking(imp2.import_file_id, waybill="WB-IT-2"))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"
    db.refresh(imp2)
    assert imp2.current_module == "Phase 10 - File Closure"

    # 2. Update (PUT) -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        it_service.update_transport_booking_service(
            db, b.transport_id,
            InlandTransportBookingUpdate(carrier_name="New Carrier"),
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 3. Gate Out -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        it_service.record_port_gate_out_service(
            db, b.transport_id,
            InlandTransportGateOutSubmit(actual_departure_at=datetime.now(timezone.utc)),
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 4. Warehouse Arrival -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        it_service.record_warehouse_arrival_service(
            db, b.transport_id,
            InlandTransportArrivalSubmit(actual_arrival_at=datetime.now(timezone.utc)),
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # 5. Soft Delete -> 409 IMPORT_FILE_CLOSED
    with pytest.raises(HTTPException) as exc:
        it_service.soft_delete_transport_booking_service(db, b.transport_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "IMPORT_FILE_CLOSED"

    # Reads still work
    bookings = it_service.list_transport_bookings_service(db, import_file_id=imp.import_file_id)
    assert len(bookings) == 1


def test_be810_t04_legacy_tolerant_schemas(db, strict_client, rbac):
    from sqlalchemy import text
    file = _file(db, code="IMP-LEGACY-01")
    now_dt = datetime.now(timezone.utc)

    # 1. Insert an InlandTransportBooking row with driver_phone="123", created_by=NULL, is_active=NULL, transport_fare_egp=NULL
    db.execute(text("""
        INSERT INTO inland_transport_bookings (
            transport_code, import_file_id, waybill_number, booking_date,
            carrier_name, truck_plate_number, truck_type, driver_name,
            driver_phone, pickup_port_location, destination_warehouse,
            planned_departure_at, expected_arrival_at, transport_fare_egp,
            status, is_active, created_at, created_by, updated_at, updated_by
        ) VALUES (
            'TR-LEG-001', :file_id, 'WB-LEG-01', :now,
            'Carrier', 'ABC 123', 'FLATBED', 'Driver Ali',
            '123', 'Alexandria Port', 'Cairo Warehouse',
            :now, :now, 500.0,
            'Booking Confirmed', 1, :now, NULL, :now, NULL
        )
    """), {"file_id": file.import_file_id, "now": now_dt})

    # Row with is_active=NULL (listed via include_inactive=True)
    db.execute(text("""
        INSERT INTO inland_transport_bookings (
            transport_code, import_file_id, waybill_number, booking_date,
            carrier_name, truck_plate_number, truck_type, driver_name,
            driver_phone, pickup_port_location, destination_warehouse,
            planned_departure_at, expected_arrival_at, transport_fare_egp,
            status, is_active, created_at, created_by, updated_at, updated_by
        ) VALUES (
            'TR-LEG-002', :file_id, 'WB-LEG-02', :now,
            'Carrier', 'ABC 124', 'FLATBED', 'Driver Hassan',
            '456', 'Alexandria Port', 'Cairo Warehouse',
            :now, :now, 600.0,
            'Booking Confirmed', NULL, :now, NULL, :now, NULL
        )
    """), {"file_id": file.import_file_id, "now": now_dt})

    # 2. Insert a FileClosureRecord row with status=NULL, created_by=NULL, closed_at=NULL, closure_checklist with nulls
    db.execute(text("""
        INSERT INTO file_closure_records (
            closure_code, import_file_id, closure_checklist, auditor_name,
            archive_location, status, is_active, closed_at,
            created_at, created_by, updated_at, updated_by
        ) VALUES (
            'CLR-LEG-001', :file_id, '{"docs_verified": null, "customs_cleared": true}', 'Old Auditor',
            'Old Archive', NULL, 1, NULL,
            :now, NULL, :now, NULL
        )
    """), {"file_id": file.import_file_id, "now": now_dt})
    db.commit()

    # Query GET /api/v1/inland-transport/bookings
    res_it = strict_client.get("/api/v1/inland-transport/bookings", headers=_bearer(rbac["operator"]))
    assert res_it.status_code == 200, res_it.text
    bookings = res_it.json()
    leg_booking = next(b for b in bookings if b["transport_code"] == "TR-LEG-001")
    assert leg_booking["driver_phone"] == "123"
    assert leg_booking["created_by"] is None or leg_booking["created_by"] == "System"
    assert leg_booking["transport_fare_egp"] == 500.0

    # Query GET /api/v1/inland-transport/bookings?include_inactive=true
    res_it_all = strict_client.get("/api/v1/inland-transport/bookings?include_inactive=true", headers=_bearer(rbac["operator"]))
    assert res_it_all.status_code == 200, res_it_all.text
    all_bookings = res_it_all.json()
    leg_booking_2 = next(b for b in all_bookings if b["transport_code"] == "TR-LEG-002")
    assert leg_booking_2["driver_phone"] == "456"
    assert leg_booking_2["is_active"] is True  # LegacyRowTolerantModel normalized None -> True

    # Query GET /api/v1/file-closure
    res_fc = strict_client.get("/api/v1/file-closure", headers=_bearer(rbac["operator"]))
    assert res_fc.status_code == 200, res_fc.text
    closures = res_fc.json()
    leg_closure = next(c for c in closures if c["closure_code"] == "CLR-LEG-001")
    assert leg_closure["status"] is None or leg_closure["status"] == "Closed"
    assert leg_closure["closed_at"] is None
    assert leg_closure["closure_checklist"]["docs_verified"] is None
    assert leg_closure["closure_checklist"]["customs_cleared"] is True




# ─── Audit Trail Tests (BE810-T17) ───────────────────────────────────────────

def test_be810_t17_audit_trail_warehouse_receiving(db):
    from modules.audit_logs.model import AuditLog
    imp = _wr_file(db, "IMP-REG-AUDIT-WR")
    rec = wr_service.create_warehouse_receiving_service(db, _grn(imp.import_file_id), user="user-wr-1")

    # UPDATE
    wr_service.update_warehouse_receiving_service(
        db, rec.receiving_id, WarehouseReceivingUpdate(notes="Updated notes"), user="user-wr-2"
    )
    upd_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "WarehouseReceivingRecord",
        AuditLog.entity_id == rec.receiving_id,
        AuditLog.action == "UPDATE",
    ).first()
    assert upd_log is not None
    assert upd_log.performed_by == "user-wr-2"

    # INSPECTION_PROTOCOL
    wr_service.submit_warehouse_inspection_protocol_service(
        db, rec.receiving_id, WarehouseInspectionSubmit(inspection_verdict="ACCEPTED_FULL"), user_name="user-wr-3"
    )
    insp_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "WarehouseReceivingRecord",
        AuditLog.entity_id == rec.receiving_id,
        AuditLog.action == "INSPECTION_PROTOCOL",
    ).first()
    assert insp_log is not None
    assert insp_log.performed_by == "user-wr-3"

    # DELETE & RESTORE on clean GRN
    imp2 = _wr_file(db, "IMP-REG-AUDIT-WR-2")
    rec2 = wr_service.create_warehouse_receiving_service(db, _grn(imp2.import_file_id), user="user-wr-4")
    wr_service.soft_delete_warehouse_receiving_service(db, rec2.receiving_id, user="user-wr-5")
    del_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "WarehouseReceivingRecord",
        AuditLog.entity_id == rec2.receiving_id,
        AuditLog.action == "DELETE",
    ).first()
    assert del_log is not None
    assert del_log.performed_by == "user-wr-5"

    wr_service.restore_warehouse_receiving_service(db, rec2.receiving_id, user="user-wr-6")
    res_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "WarehouseReceivingRecord",
        AuditLog.entity_id == rec2.receiving_id,
        AuditLog.action == "RESTORE",
    ).first()
    assert res_log is not None
    assert res_log.performed_by == "user-wr-6"


def test_be810_t17_audit_trail_inland_transport(db):
    from modules.audit_logs.model import AuditLog
    imp = _file(db, "IMP-REG-AUDIT-IT")
    now = datetime.now(timezone.utc)

    # CREATE
    booking = it_service.create_transport_booking_service(db, _booking(imp.import_file_id, "WB-AUD-1"), user="user-it-1")
    cr_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "CREATE",
    ).first()
    assert cr_log is not None
    assert cr_log.performed_by == "user-it-1"

    # GATE_OUT
    it_service.record_port_gate_out_service(
        db, booking.transport_id, InlandTransportGateOutSubmit(actual_departure_at=now, gate_pass_no="GP-01"), user="user-it-2"
    )
    go_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "GATE_OUT",
    ).first()
    assert go_log is not None
    assert go_log.performed_by == "user-it-2"

    # ARRIVAL
    it_service.record_warehouse_arrival_service(
        db, booking.transport_id, InlandTransportArrivalSubmit(actual_arrival_at=now + timedelta(minutes=5), seal_intact=True), user="user-it-3"
    )
    arr_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "ARRIVAL",
    ).first()
    assert arr_log is not None
    assert arr_log.performed_by == "user-it-3"

    # UPDATE
    it_service.update_transport_booking_service(
        db, booking.transport_id, InlandTransportBookingUpdate(driver_phone="0109999999"), user="user-it-4"
    )
    upd_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "UPDATE",
    ).first()
    assert upd_log is not None
    assert upd_log.performed_by == "user-it-4"

    # DELETE
    it_service.soft_delete_transport_booking_service(db, booking.transport_id, user="user-it-5")
    del_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "DELETE",
    ).first()
    assert del_log is not None
    assert del_log.performed_by == "user-it-5"

    # RESTORE
    it_service.restore_transport_booking_service(db, booking.transport_id, user="user-it-6")
    res_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "InlandTransportBooking",
        AuditLog.entity_id == booking.transport_id,
        AuditLog.action == "RESTORE",
    ).first()
    assert res_log is not None
    assert res_log.performed_by == "user-it-6"


def test_be810_t17_audit_trail_file_closure(db):
    from modules.audit_logs.model import AuditLog
    from modules.file_closure.schemas import DossierExportConfirmRequest
    imp = _ready_file(db, "IMP-REG-AUDIT-FC")

    # DOSSIER_EXPORT
    fc_service.confirm_dossier_export_service(
        db, DossierExportConfirmRequest(import_file_id=imp.import_file_id, export_format="PDF"), user="user-fc-export"
    )
    exp_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFile",
        AuditLog.entity_id == imp.import_file_id,
        AuditLog.action == "DOSSIER_EXPORT",
    ).first()
    assert exp_log is not None
    assert exp_log.performed_by == "user-fc-export"

    # DRAFT CREATE
    draft = fc_service.close_import_file_service(
        db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=True), user="user-fc-1"
    )
    cr_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFileClosureRecord",
        AuditLog.entity_id == draft.closure_id,
        AuditLog.action == "CREATE",
    ).first()
    assert cr_log is not None
    assert cr_log.performed_by == "user-fc-1"

    # UPDATE
    fc_service.update_closure_service(
        db, draft.closure_id, FileClosureUpdate(archival_notes="Audit note"), user="user-fc-2"
    )
    upd_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFileClosureRecord",
        AuditLog.entity_id == draft.closure_id,
        AuditLog.action == "UPDATE",
    ).first()
    assert upd_log is not None
    assert upd_log.performed_by == "user-fc-2"

    # DELETE
    fc_service.soft_delete_closure_service(db, draft.closure_id, user="user-fc-3")
    del_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFileClosureRecord",
        AuditLog.entity_id == draft.closure_id,
        AuditLog.action == "DELETE",
    ).first()
    assert del_log is not None
    assert del_log.performed_by == "user-fc-3"

    # RESTORE
    fc_service.restore_closure_service(db, draft.closure_id, user="user-fc-4")
    res_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFileClosureRecord",
        AuditLog.entity_id == draft.closure_id,
        AuditLog.action == "RESTORE",
    ).first()
    assert res_log is not None
    assert res_log.performed_by == "user-fc-4"

    # OFFICIAL CLOSE
    closed = fc_service.close_import_file_service(
        db, FileClosureCreate(import_file_id=imp.import_file_id, is_draft=False), user="user-fc-final"
    )
    close_log = db.query(AuditLog).filter(
        AuditLog.entity_type == "ImportFileClosureRecord",
        AuditLog.entity_id == closed.closure_id,
        AuditLog.action == "CLOSE",
    ).first()
    assert close_log is not None
    assert close_log.performed_by == "user-fc-final"

