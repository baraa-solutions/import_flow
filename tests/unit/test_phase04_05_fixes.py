"""
Phases 4-5 regression tests for the BE fixes of docs/plans/phase-04-05-quality-plan.md
(FB-, INS-, CS-, SU-, DD- ids in the test names).
"""
import importlib
from datetime import date, datetime, timedelta

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import modules.auth.permissions as auth_permissions
from database.database import Base, get_db
from modules.auth.permissions import invalidate_permission_cache
from modules.auth.security import create_access_token, hash_password
from modules.auth.seed_rbac import seed_rbac
from modules.common.system_parameters import SystemParameter
from modules.users.model import Role, User

from modules.cargo_insurance.schemas import CargoInsuranceCertificateCreate, CargoInsuranceCertificateUpdate, InsuranceCalculationInput
from modules.cargo_insurance.service import CargoInsuranceService
from modules.cargo_shipping.schemas import (
    CargoShippingCreate, CargoShippingUpdate, CargoXExchangeItem, CargoXVerificationRule, ContainerLoadingItem,
    DualApprovalLevel1Submit, DualApprovalLevel2Submit,
)
import modules.cargo_shipping.service as cs
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.demurrage_detention.schemas import (
    ContainerIndividualUpdate, DemurragePolicyCreate, DemurrageTrackingCreate, DemurrageTrackingUpdate,
    EmptyContainerReturnSubmit, FreeDaysAgreementRegister, PushToSettlementRequest, TierRateItem, ContainerItemInput,
)
import modules.demurrage_detention.service as dd
from modules.freight_booking.schemas import (
    ContainerAllocationItem, ShipmentBookingConfirm, ShipmentBookingCreate, ShipmentDepartureConfirm,
)
import modules.freight_booking.service as fb
from modules.import_files.model import ImportFile
from modules.shipment_updates.schemas import ShipmentUpdateLogCreate
import modules.shipment_updates.service as su
from modules.smart_tasks.model import SmartTask
import modules.inland_transport.model  # noqa: F401  (table used by TR-05)

ROUTERS = [importlib.import_module(f"modules.{m}.router") for m in (
    "freight_booking", "cargo_insurance", "cargo_shipping", "shipment_updates", "demurrage_detention",
)]


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
    session.add(ImportFile(import_file_id=1, import_file_code="IMP-2026-0451", company_name="Co", supplier_name="Sup", owner="tester"))
    session.commit()
    yield session
    session.close()


# ── permissions (403 for a read-only viewer on a mutation) ─────────────────────────────────────────────

@pytest.mark.parametrize("path,body", [
    ("/api/v1/freight-booking", {"shipment_type": "Air"}),
    ("/api/v1/cargo-insurance/certificates", {"insured_entity_name": "X", "port_of_loading": "A", "port_of_discharge": "B", "invoice_value": 1}),
    ("/api/v1/cargo-shipping", {"import_file_id": 1}),
    ("/api/v1/shipment-updates", {"import_file_id": 1, "target_phase": "Phase 1", "log_date": "2026-01-01", "note": "abc"}),
    ("/api/v1/demurrage-detention/policies", {"carrier_name": "MSC", "container_type": "40HC"}),
])
def test_permissions_viewer_gets_403_on_post(session_factory, db, monkeypatch, path, body):
    monkeypatch.setattr(auth_permissions, "ALLOW_DEV_AUTH_BYPASS", False)
    seed_rbac(db)
    role = db.query(Role).filter(Role.role_code == "AUDITOR_VIEWER").one()
    viewer = User(username="viewer45", email="v45@test.com", full_name="v", hashed_password=hash_password("Password123"),
                  role=role.role_code, role_id=role.role_id, is_active=True)
    db.add(viewer)
    db.commit()
    app = FastAPI()
    for r in ROUTERS:
        app.include_router(r.router)

    def override_get_db():
        s = session_factory()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app, raise_server_exceptions=False)
    headers = {"Authorization": f"Bearer {create_access_token({'sub': str(viewer.user_id), 'role': viewer.role})}"}
    assert client.post(path, json=body, headers=headers).status_code == 403
    assert client.post(path, json=body).status_code == 401


# ── freight booking ─────────────────────────────────────────────────────────────────────────────────────

def _booking(db, **kw):
    payload = ShipmentBookingCreate(shipment_type="Ocean FCL", containers_data=[ContainerAllocationItem(container_type="40HC", quantity=1)], **kw)
    booking = fb.create_booking_service(db, payload, user="op1")
    # The tests depart on fixed past dates; ATD may not precede the booking request date (BE45-T11).
    booking.booking_request_date = datetime(2026, 7, 1)
    db.commit()
    return booking


def test_fb02_confirm_on_sailed_is_409_and_depart_needs_confirmation(db):
    booking = _booking(db)
    with pytest.raises(HTTPException) as exc:
        fb.confirm_departure_and_bol_service(db, booking.booking_id, ShipmentDepartureConfirm(
            actual_departure_date=datetime(2026, 8, 1), bill_of_lading_no="BL-001"))
    assert exc.value.status_code == 409
    fb.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CN-1"), user="mgr")
    sailed = fb.confirm_departure_and_bol_service(db, booking.booking_id, ShipmentDepartureConfirm(
        actual_departure_date=datetime(2026, 8, 1), bill_of_lading_no="BL-001"), user="mgr")
    assert sailed.status == "Sailed"
    with pytest.raises(HTTPException) as exc:
        fb.confirm_booking_service(db, booking.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CN-2"))
    assert exc.value.status_code == 409


def test_fb04_fb07_code_sequence_and_owner_from_user(db):
    first = _booking(db)
    year = datetime.now().year
    assert first.booking_code == f"BKG-{year}-0001"
    assert first.owner == "op1"


def test_fb05_restore_refuses_second_active_booking(db):
    first = _booking(db, import_file_id=1)
    fb.soft_delete_booking_service(db, first.booking_id)
    _booking(db, import_file_id=1)
    with pytest.raises(HTTPException) as exc:
        fb.restore_booking_service(db, first.booking_id)
    assert exc.value.status_code == 400


# ── cargo insurance ─────────────────────────────────────────────────────────────────────────────────────

def _certificate(db):
    return CargoInsuranceService(db).create_certificate(CargoInsuranceCertificateCreate(
        insured_entity_name="Importer", port_of_loading="Shanghai", port_of_discharge="Alexandria", invoice_value=5000, freight_cost=500,
    ), current_user="ins_user")


def test_ins02_rates_come_from_system_parameters(db):
    db.add(SystemParameter(param_key="INSURANCE_TAX_RATE", param_value="0.10"))
    db.commit()
    result = CargoInsuranceService(db).calculate_insurance(InsuranceCalculationInput(invoice_value=5000, freight_cost=500))
    assert result.tax_rate == 0.10
    assert result.tax_amount == 4.5  # (30 minimum + 15 fee) * 0.10
    with pytest.raises(HTTPException) as exc:
        CargoInsuranceService(db).calculate_insurance(InsuranceCalculationInput(invoice_value=1, coverage_clause="ICC_Z"))
    assert exc.value.status_code == 400


def test_ins03_ins05_ins06_code_no_invented_insurer_and_user(db):
    cert = _certificate(db)
    assert cert.certificate_code == f"INS-{datetime.now().year}-00001"
    assert cert.insurance_company_name is None and cert.final_destination is None
    assert cert.survey_agent_in_destination is None
    assert cert.created_by == "ins_user"
    assert (cert.minimum_premium, cert.issuance_fee, cert.tax_rate, cert.total_payable_premium) == (30.0, 15.0, 0.05, 47.25)


def test_ins04_status_ignored_and_issued_is_locked(db):
    service = CargoInsuranceService(db)
    cert = _certificate(db)
    updated = service.update_certificate(cert.certificate_id, CargoInsuranceCertificateUpdate(status="ISSUED", remarks="x"))
    assert updated.status == "DRAFT"
    with pytest.raises(HTTPException) as exc:
        service.update_certificate(cert.certificate_id, CargoInsuranceCertificateUpdate(coverage_clause="BAD"))
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        service.update_certificate(cert.certificate_id, CargoInsuranceCertificateUpdate(invoice_value=None))
    assert exc.value.status_code == 422
    service.issue_certificate(cert.certificate_id)
    with pytest.raises(HTTPException) as exc:
        service.update_certificate(cert.certificate_id, CargoInsuranceCertificateUpdate(freight_cost=1))
    assert exc.value.status_code == 409


# ── cargo shipping ──────────────────────────────────────────────────────────────────────────────────────

def _shipping(db, **kw):
    return cs.create_cargo_shipping_service(db, CargoShippingCreate(
        import_file_id=1, containers_loading_data=[ContainerLoadingItem(container_no="COSU1000001", seal_no="S1")], **kw), user="op1")


def test_cs02_put_cannot_inject_checklist_and_no_acid_fails(db):
    rec = _shipping(db)
    forged = CargoXExchangeItem(envelope_status="Checklist Passed", blockchain_tx_hash="0xFAKE",
                                verification_checklist=[CargoXVerificationRule(rule_name="x", passed=True)])
    rec = cs.update_cargo_shipping_service(db, rec.cargo_shipping_id, CargoShippingUpdate(cargox_exchange_data=forged), auto_advance_lifecycle=False)
    assert rec.cargox_exchange_data.get("envelope_status") != "Checklist Passed"
    assert not rec.cargox_exchange_data.get("verification_checklist")
    assert rec.cargox_exchange_data.get("blockchain_tx_hash") is None
    with pytest.raises(HTTPException) as exc:
        cs.advance_cargox_stage_service(db, rec.cargo_shipping_id, "Ready for Upload")
    assert exc.value.status_code == 409
    cs.submit_level1_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="a")
    cs.submit_level2_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="b")
    rec = cs.execute_cargox_checklist_service(db, rec.cargo_shipping_id, invoice_match_confirmed=True, user="a")
    acid_rule = next(r for r in rec.cargox_exchange_data["verification_checklist"] if r["rule_name"].startswith("ACID"))
    assert acid_rule["passed"] is False
    assert rec.cargox_exchange_data["envelope_status"] == "Invited"


def test_cs03_edit_of_deleted_record_is_404_and_upsert_409(db):
    rec = _shipping(db)
    cs.soft_delete_cargo_shipping_service(db, rec.cargo_shipping_id)
    with pytest.raises(HTTPException) as exc:
        cs.update_cargo_shipping_service(db, rec.cargo_shipping_id, CargoShippingUpdate(notes="x"))
    assert exc.value.status_code == 404
    with pytest.raises(HTTPException) as exc:
        cs.create_cargo_shipping_service(db, CargoShippingCreate(import_file_id=1), auto_upsert=True)
    assert exc.value.status_code == 409


def test_cs04_cs05_status_kept_approver_from_user_and_l1_locked(db):
    rec = _shipping(db)
    cs.submit_level1_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel1Submit(approved_by="spoof", approved=True), user="alice")
    rec = cs.submit_level2_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel2Submit(approved_by="spoof", approved=True), user="bob")
    assert (rec.level1_approved_by, rec.level2_approved_by, rec.status) == ("alice", "bob", "Dual Approved")
    rec = cs.update_cargo_shipping_service(db, rec.cargo_shipping_id, CargoShippingUpdate(status="Cargo Ready"), auto_advance_lifecycle=False)
    assert rec.status == "Dual Approved"
    rec = cs.update_cargo_shipping_service(db, rec.cargo_shipping_id, CargoShippingUpdate(status="Docs Dispatched"), auto_advance_lifecycle=False)
    assert rec.status == "Docs Dispatched"
    with pytest.raises(HTTPException) as exc:
        cs.submit_level1_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel1Submit(approved=False), user="alice")
    assert exc.value.status_code == 409


def test_cs07_bad_date_is_422(db):
    with pytest.raises(HTTPException) as exc:
        cs.create_cargo_shipping_service(db, CargoShippingCreate(import_file_id=1, containers_loading_data=[
            ContainerLoadingItem(container_no="COSU1000002", seal_no="S2", container_assignment_date="not-a-date")]))
    assert exc.value.status_code == 422


# ── shipment updates ────────────────────────────────────────────────────────────────────────────────────

def test_su02_phase_10_is_not_phase_1(db):
    db.get(ImportFile, 1).current_module = "Phase 10 - Import File Closure & Historical Archive"
    db.commit()
    phases = su.inspect_shipment_phases_service(db, 1)
    assert phases[9].status == "Current"
    assert phases[0].status == "Completed"


def test_su03_su06_notes_appended_code_and_user_from_server(db):
    db.get(ImportFile, 1).notes = "user note"
    db.commit()
    log = su.create_update_log_service(db, ShipmentUpdateLogCreate(
        import_file_id=1, import_file_code="SPOOF", target_phase="Phase 4", log_date="2026-08-13", note="booked"), user_name="op7")
    assert log.import_file_code == "IMP-2026-0451"
    assert (log.created_by, log.assigned_user) == ("op7", "op7")
    notes = db.get(ImportFile, 1).notes
    assert notes.startswith("user note\n") and "booked" in notes
    with pytest.raises(Exception):
        ShipmentUpdateLogCreate(import_file_id=1, target_phase="Phase 11", log_date="2026-08-13", note="xx")
    with pytest.raises(Exception):
        ShipmentUpdateLogCreate(import_file_id=1, target_phase="Phase 1", log_date="13/08/2026", note="xx")


# ── demurrage ───────────────────────────────────────────────────────────────────────────────────────────

CUSTOM_DEM = [{"from_day": 1, "to_day": None, "rate_per_day": 100.0}]


def _tracking(db, discharge: date, containers=None, policy_id=None, **kw):
    t = DemurrageTracking(
        tracking_code=kw.pop("code", "DND-T-0001"), import_file_id=1, carrier_name="MSC", bill_of_lading_no="BL-DD",
        port_name="Alexandria Port", discharge_date=discharge, policy_id=policy_id,
        containers=containers or [{"container_no": "MSCU0000001", "container_type": "40HC"}],
        currency="USD", exchange_rate=50.0, is_active=True, **kw,
    )
    db.add(t)
    db.commit()
    return t


def _policy(db):
    p = DemurragePolicy(carrier_name="MSC", container_type="40HC", demurrage_free_days=5, detention_free_days=7,
                        port_storage_free_days=5, port_storage_daily_rate_egp=100.0, demurrage_tiers=CUSTOM_DEM,
                        detention_tiers=CUSTOM_DEM)
    db.add(p)
    db.commit()
    return p


def test_dd04_free_days_keep_eir_policy_tiers_and_skip_pushed(db):
    policy = _policy(db)
    t = _tracking(db, date(2026, 8, 1), containers=[{"container_no": "MSCU0000001", "container_type": "40HC",
                  "gate_out_date": "2026-08-20", "eir_number": "EIR-9", "seal_no": "SEAL-1"}], policy_id=policy.policy_id)
    pushed = _tracking(db, date(2026, 8, 1), code="DND-T-0002", is_pushed_to_settlement=True)
    resp = dd.register_free_days_agreement_service(db, FreeDaysAgreementRegister(
        import_file_id=1, agreed_demurrage_free_days=10, agreed_detention_free_days=7, port_storage_free_days=5), user="op")
    db.refresh(t)
    c = t.containers[0]
    assert (c["eir_number"], c["seal_no"], c["gate_out_date"]) == ("EIR-9", "SEAL-1", "2026-08-20")
    # 19 days in port, 10 free -> 9 days at the policy's flat 100/day (not the default tiers)
    assert c["demurrage_days"] == 9 and c["demurrage_fx"] == 900.0
    # lead decision: pushed trackings are recalculated too; no settlement linked -> flagged stale, still pushed
    assert resp.skipped_pushed_tracking_codes == []
    assert resp.stale_settlement_tracking_codes == [pushed.tracking_code]
    db.refresh(pushed)
    assert pushed.status == "Pushed to Settlement" and pushed.is_pushed_to_settlement is True


def test_dd05_put_keeps_container_keys_clears_dates_and_status(db):
    t = _tracking(db, date(2026, 8, 1), containers=[{"container_no": "MSCU0000001", "container_type": "40HC", "eir_number": "EIR-1"}],
                  gate_out_date=date(2026, 8, 10))
    updated = dd.recalculate_and_update_tracking_service(db, t.tracking_id, DemurrageTrackingUpdate(gate_out_date=None, status="Anything"))
    assert updated.gate_out_date is None
    assert updated.containers[0]["eir_number"] == "EIR-1"
    assert updated.status != "Anything"
    closed = dd.recalculate_and_update_tracking_service(db, t.tracking_id, DemurrageTrackingUpdate(status="Closed"))
    assert closed.status == "Closed"
    with pytest.raises(HTTPException):
        dd.recalculate_and_update_tracking_service(db, t.tracking_id, DemurrageTrackingUpdate(exchange_rate=0))


def test_dd06_second_partial_return_and_unknown_container(db):
    today = date.today()
    _tracking(db, today - timedelta(days=5), containers=[
        {"container_no": "MEDU1", "container_type": "20GP", "gate_out_date": (today - timedelta(days=4)).isoformat()},
        {"container_no": "MEDU2", "container_type": "20GP", "gate_out_date": (today - timedelta(days=4)).isoformat()},
    ])
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-X", empty_return_date=today, returned_containers=["NOPE1"]))
    assert exc.value.status_code == 400
    first = dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-A", empty_return_date=today, returned_containers=["MEDU1"]))
    assert first.all_containers_returned is False
    assert db.get(ImportFile, 1).current_step_code != "STEP_20"
    second = dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-B", empty_return_date=today, returned_containers=["MEDU2"]))
    assert second.all_containers_returned is True
    assert db.get(ImportFile, 1).empty_containers_eir_numbers == "EIR-A, EIR-B"
    assert db.query(SmartTask).filter(SmartTask.task_code == "TSK-0901-1").count() == 1


def test_dd07_push_uses_settlement_code_and_recalculates(db, monkeypatch):
    fixed_today = date(2026, 8, 15)
    monkeypatch.setattr(dd, "_today", lambda: fixed_today)
    policy = _policy(db)
    t = _tracking(db, date(2026, 8, 1), policy_id=policy.policy_id)
    res = dd.push_demurrage_to_financial_settlement_service(
        db, PushToSettlementRequest(tracking_id=t.tracking_id, accountant_name="spoof"), user="acct1")
    from modules.financial_settlement.model import LandedCostSettlementRecord
    settlement = db.get(LandedCostSettlementRecord, res["settlement_id"])
    assert settlement.settlement_code == f"LCS-{datetime.now().year}-0001"
    assert settlement.accountant_name == "acct1"
    assert res["settlement_recalculated"] is True
    # two rows (carrier USD x rate, storage EGP at 1.0), each amount_fx x rate == amount_egp
    rows = {i["invoice_no"]: i for i in settlement.expense_invoices if i["invoice_no"].startswith("INV-")}
    assert set(rows) == {"INV-DND-DND-T-0001", "INV-STO-DND-T-0001"}
    assert (rows["INV-DND-DND-T-0001"]["amount_fx"], rows["INV-DND-DND-T-0001"]["amount_egp"]) == (900.0, 45000.0)
    assert (rows["INV-STO-DND-T-0001"]["currency"], rows["INV-STO-DND-T-0001"]["exchange_rate"], rows["INV-STO-DND-T-0001"]["amount_egp"]) == ("EGP", 1.0, 900.0)
    for row in rows.values():
        assert round(row["amount_fx"] * row["exchange_rate"], 2) == row["amount_egp"]
    assert settlement.total_landed_cost_egp == 45900.0
    # a second push replaces the rows (no duplicates)
    dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=t.tracking_id), user="acct1")
    db.refresh(settlement)
    assert sum(1 for i in settlement.expense_invoices if i["invoice_no"].startswith("INV-")) == 2


def test_dd09_tracking_without_rate_uses_bank_rate_or_409(db):
    req = DemurrageTrackingCreate(port_name="Alexandria", import_file_id=1, carrier_name="MSC", bill_of_lading_no="BL-NR", discharge_date=date(2026, 8, 1),
                                  containers=[ContainerItemInput(container_no="MSCU0000009", container_type="40HC")])
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_tracking_service(db, req)
    assert exc.value.status_code == 409
    from modules.currencies.model import Currency, ExchangeRate
    cur = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(cur)
    db.flush()
    db.add(ExchangeRate(currency_id=cur.currency_id, commercial_rate=48.0, customs_rate=47.0, effective_date=date(2026, 7, 1), is_active=True))
    db.commit()
    tracking = dd.create_demurrage_tracking_service(db, req, user="op")
    assert tracking.exchange_rate == 48.0
    assert tracking.tracking_code == f"DND-{datetime.now().year}-0001"


def test_dd11_tier_gap_is_422(db):
    with pytest.raises(HTTPException) as exc:
        dd.create_demurrage_policy_service(db, DemurragePolicyCreate(carrier_name="MSC", container_type="40HC", demurrage_tiers=[
            TierRateItem(from_day=1, to_day=5, rate_per_day=10), TierRateItem(from_day=7, to_day=None, rate_per_day=20)]))
    assert exc.value.status_code == 422


def test_dd03_radar_prices_with_policy_tiers(db):
    policy = _policy(db)
    _tracking(db, date.today() - timedelta(days=8), policy_id=policy.policy_id)
    item = dd.get_containers_radar_overview_service(db).radar_items[0]
    # 8 days, 5 free -> 3 days at 100 USD (policy) instead of the old flat 70; storage 3 days at 100 EGP
    assert item.accrued_demurrage_usd == 300.0
    assert item.accrued_storage_egp == 300.0
    assert item.total_accrued_egp == 300.0 * 50 + 300.0


def test_dd_single_container_update_keeps_other_keys(db):
    t = _tracking(db, date(2026, 8, 1), containers=[{"container_no": "MSCU0000001", "container_type": "40HC", "depot_name": "D1"}])
    updated = dd.update_single_container_service(db, t.tracking_id, "mscu0000001", ContainerIndividualUpdate(eir_number="E-1"))
    assert updated.containers[0]["depot_name"] == "D1"
    assert updated.containers[0]["eir_number"] == "E-1"


# ── completion pass: defaults, explicit nulls, EIR re-stamping, locked settlement ───────────────────────

def test_schema_defaults_do_not_invent_user_or_vgm_submission():
    from modules.cargo_shipping.schemas import ContainerLoadingTrackingItem
    assert ShipmentUpdateLogCreate(import_file_id=1, target_phase="Phase 1", log_date="2026-08-13", note="xx").assigned_user is None
    assert CargoShippingCreate(import_file_id=1).owner is None
    assert ShipmentBookingCreate(shipment_type="Air").owner is None
    assert ContainerLoadingItem(container_no="C1", seal_no="S1").vgm_status == "Pending"
    assert ContainerLoadingTrackingItem(container_no="C1").vgm_status == "Pending"


def test_su_put_explicit_null_keeps_not_null_columns(db):
    from modules.shipment_updates.schemas import ShipmentUpdateLogUpdate
    log = su.create_update_log_service(db, ShipmentUpdateLogCreate(
        import_file_id=1, target_phase="Phase 2", log_date="2026-08-13", note="first"), user_name="op7")
    updated = su.update_log_record_service(db, log.update_id, ShipmentUpdateLogUpdate(note=None, assigned_user=None, adjusted_cost_item=None), user_name="op8")
    assert (updated.note, updated.assigned_user, updated.updated_by) == ("first", "op7", "op8")


def test_dd06_return_without_list_keeps_earlier_eir_then_409_and_task_matching(db):
    today = date.today()
    gate_out = (today - timedelta(days=4)).isoformat()
    _tracking(db, today - timedelta(days=5), containers=[
        {"container_no": "MEDU1", "container_type": "20GP", "gate_out_date": gate_out},
        {"container_no": "MEDU2", "container_type": "20GP", "gate_out_date": gate_out},
    ])
    db.add_all([
        SmartTask(task_code="TSK-T-1", import_file_id=1, title="Collect EIR from depot", status="Pending", is_active=True),
        SmartTask(task_code="TSK-T-2", import_file_id=1, title="Send their invoices", status="Pending", is_active=True),
    ])
    db.commit()
    dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(
        import_file_id=1, eir_number="EIR-A", empty_return_date=today - timedelta(days=2), returned_containers=["MEDU1"]))
    # partial return: the TR-05 task stays open
    assert db.query(SmartTask).filter(SmartTask.task_code == "TSK-T-1").one().status == "Pending"
    res = dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-B", empty_return_date=today))
    assert res.returned_containers == ["MEDU2"] and res.all_containers_returned is True
    containers = {c["container_no"]: c for c in db.query(DemurrageTracking).one().containers}
    assert containers["MEDU1"]["eir_number"] == "EIR-A"
    assert containers["MEDU1"]["empty_return_date"] == (today - timedelta(days=2)).isoformat()
    assert containers["MEDU2"]["eir_number"] == "EIR-B"
    assert db.query(SmartTask).filter(SmartTask.task_code == "TSK-T-1").one().status == "Completed"
    assert db.query(SmartTask).filter(SmartTask.task_code == "TSK-T-2").one().status == "Pending"
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-C", empty_return_date=today))
    assert exc.value.status_code == 409


def test_dd07_push_into_locked_settlement_is_409_and_code_skips_taken(db):
    from modules.financial_settlement.model import LandedCostSettlementRecord
    year = datetime.now().year
    db.add(ImportFile(import_file_id=2, import_file_code="IMP-2026-0452", company_name="Co", supplier_name="Sup", owner="t"))
    db.add(LandedCostSettlementRecord(settlement_code=f"LCS-{year}-0007", import_file_id=2, status="Approved", expense_invoices=[]))
    db.commit()
    locked = _tracking(db, date(2026, 8, 1), code="DND-T-0010", total_cost_egp=10.0, total_demurrage_fx=0.2, total_detention_fx=0.0)
    locked.import_file_id = 2
    db.commit()
    with pytest.raises(HTTPException) as exc:
        dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=locked.tracking_id), user="acct")
    assert exc.value.status_code == 409
    db.rollback()
    assert db.get(DemurrageTracking, locked.tracking_id).is_pushed_to_settlement is not True
    fresh = _tracking(db, date(2026, 8, 1), code="DND-T-0011", total_cost_egp=10.0, total_demurrage_fx=0.2, total_detention_fx=0.0)
    res = dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=fresh.tracking_id), user="acct")
    assert res["settlement_code"] == f"LCS-{year}-0008"


# ── review round (lead diff review, customs review, security review) ────────────────────────────────────

def test_su_inspection_uses_step_code_and_milestone_goes_through_tracking_writer(db):
    f = db.get(ImportFile, 1)
    f.current_step_code, f.current_phase_id, f.current_module = "STEP_13", 5, "STEP_13 Customs Declaration 46"
    db.commit()
    phases = su.inspect_shipment_phases_service(db, 1)
    assert phases[5].status == "Current" and phases[4].status == "Completed" and phases[6].status == "Future"
    su.create_update_log_service(db, ShipmentUpdateLogCreate(
        import_file_id=1, update_category="Milestone Phase Progression", target_phase="Phase 8", log_date="2026-08-13", note="moved"),
        user_name="op")
    f = db.get(ImportFile, 1)
    assert (f.current_step_code, f.current_module, f.current_phase_id) == ("STEP_13", "STEP_13 Customs Declaration 46", 6)
    assert f.current_stage.startswith("Phase 6")
    assert su.inspect_shipment_phases_service(db, 1)[7].status == "Current"
    # a milestone to an earlier phase never moves the board back
    su.create_update_log_service(db, ShipmentUpdateLogCreate(
        import_file_id=1, update_category="Milestone Phase Progression", target_phase="Phase 2", log_date="2026-08-14", note="back"),
        user_name="op")
    assert db.get(ImportFile, 1).current_phase_id == 6


def _booking_for_file(db, free_days):
    from modules.freight_booking.model import ShipmentBooking
    db.add(ShipmentBooking(booking_code="BKG-T-1", import_file_id=1, shipment_type="Ocean FCL", status="Confirmed",
                           owner="op", free_demurrage_days=free_days, is_active=True))
    db.commit()


@pytest.mark.parametrize("with_booking", [True, False])
def test_dd_put_after_bk02_keeps_agreed_free_days(db, with_booking):
    if with_booking:
        _booking_for_file(db, 14)
    t = _tracking(db, date(2026, 8, 1), containers=[{"container_no": "MSCU0000001", "container_type": "40HC"}],
                  gate_out_date=date(2026, 8, 25), empty_return_date=date(2026, 9, 10))
    dd.register_free_days_agreement_service(db, FreeDaysAgreementRegister(
        import_file_id=1, agreed_demurrage_free_days=20, agreed_detention_free_days=10), user="op")
    db.refresh(t)
    after_bk02 = (t.total_demurrage_fx, t.total_detention_fx, t.total_storage_egp, t.total_cost_egp)
    # 24 days in port - 20 free = 4 x 40; return 16 days after gate-out - 10 free = 6 x 35; storage 24 - 5 = 19 x 250
    assert after_bk02 == (160.0, 210.0, 4750.0, round(370.0 * 50 + 4750.0, 2))
    for put in (DemurrageTrackingUpdate(notes="x"), DemurrageTrackingUpdate(exchange_rate=50.0)):
        updated = dd.recalculate_and_update_tracking_service(db, t.tracking_id, put)
        assert (updated.total_demurrage_fx, updated.total_detention_fx, updated.total_storage_egp, updated.total_cost_egp) == after_bk02
    single = dd.update_single_container_service(db, t.tracking_id, "MSCU0000001", ContainerIndividualUpdate(seal_no="S-9"))
    assert single.total_cost_egp == after_bk02[3]
    clock = dd.get_dual_clock_status_service(db, t.tracking_id)
    assert clock.carrier_clock.free_days_allowed == 20


def test_dd_no_policy_parameter_path_equals_head_numbers(db):
    req = DemurrageTrackingCreate(port_name="Alexandria", import_file_id=None, carrier_name="NOPOLICY", bill_of_lading_no="BL-HEAD",
                                  discharge_date=date(2026, 8, 1), gate_out_date=date(2026, 8, 21),
                                  empty_return_date=date(2026, 8, 25), exchange_rate=50.0,
                                  containers=[ContainerItemInput(container_no="MSCU0000005", container_type="40HC")])
    # HEAD constants: 20 days - 14 free = 6 days x 40; storage 20 - 5 = 15 x 250; EGP = 240 x 50 + 3750
    head = (240.0, 0.0, 3750.0, 15750.0)
    t1 = dd.create_demurrage_tracking_service(db, req)
    assert (t1.total_demurrage_fx, t1.total_detention_fx, t1.total_storage_egp, t1.total_cost_egp) == head
    for key, value in (("DD_DEFAULT_DEMURRAGE_TIERS", '[{"from_day":1,"to_day":7,"rate_per_day":40.0},{"from_day":8,"to_day":14,"rate_per_day":70.0},{"from_day":15,"to_day":null,"rate_per_day":120.0}]'),
                       ("DD_DEFAULT_FREE_DAYS_DEMURRAGE", "14"), ("DD_DEFAULT_STORAGE_FREE_DAYS", "5"),
                       ("DD_DEFAULT_STORAGE_RATE_EGP", "250")):
        db.add(SystemParameter(param_key=key, param_value=value))
    db.commit()
    # BE45-T06: one active tracking per B/L, so the parameter-path tracking uses its own B/L.
    t2 = dd.create_demurrage_tracking_service(db, req.model_copy(update={"bill_of_lading_no": "BL-HEAD-PARAMS"}))
    assert (t2.total_demurrage_fx, t2.total_detention_fx, t2.total_storage_egp, t2.total_cost_egp) == head
    put = dd.recalculate_and_update_tracking_service(db, t2.tracking_id, DemurrageTrackingUpdate(notes="n"))
    assert (put.total_demurrage_fx, put.total_detention_fx, put.total_storage_egp, put.total_cost_egp) == head


def test_dd_simulator_without_tiers_uses_parameter_tiers(db):
    from modules.demurrage_detention.schemas import DemurrageSimulationRequest
    db.add(SystemParameter(param_key="DD_DEFAULT_DEMURRAGE_TIERS", param_value='[{"from_day":1,"to_day":null,"rate_per_day":100.0}]'))
    db.commit()
    sim = dd.simulate_with_defaults(db, DemurrageSimulationRequest(
        discharge_date=date(2026, 8, 1), gate_out_date=date(2026, 8, 18), demurrage_free_days=14, exchange_rate=50.0))
    assert sim.demurrage_fee_fx == 300.0  # 3 days x 100 (parameter), not 3 x 40


def _pushed_with_settlement(db, status_value="Draft"):
    from modules.financial_settlement.model import LandedCostSettlementRecord
    t = _tracking(db, date(2026, 8, 1), containers=[{"container_no": "MSCU0000001", "container_type": "40HC"}],
                  gate_out_date=date(2026, 8, 20))
    dd.recalculate_and_update_tracking_service(db, t.tracking_id, DemurrageTrackingUpdate(notes="calc"))
    res = dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=t.tracking_id), user="acct")
    settlement = db.get(LandedCostSettlementRecord, res["settlement_id"])
    if status_value != "Draft":
        settlement.status = status_value
        db.commit()
    return t, settlement


def test_dd_put_on_pushed_tracking_repushes_or_warns_when_locked(db):
    t, settlement = _pushed_with_settlement(db)
    updated = dd.recalculate_and_update_tracking_service(db, t.tracking_id, DemurrageTrackingUpdate(gate_out_date=date(2026, 8, 25)))
    assert updated.status == "Pushed to Settlement" and updated.is_pushed_to_settlement is True
    assert updated.settlement_warning_code is None
    db.refresh(settlement)
    row = next(i for i in settlement.expense_invoices if i["invoice_no"] == f"INV-DND-{t.tracking_code}")
    assert row["amount_fx"] == round(updated.total_demurrage_fx + updated.total_detention_fx, 2)

    t2, locked = _pushed_with_settlement_locked(db)
    before = list(locked.expense_invoices)
    res = dd.recalculate_and_update_tracking_service(db, t2.tracking_id, DemurrageTrackingUpdate(gate_out_date=date(2026, 8, 28)))
    assert res.settlement_warning_code == "DD_SETTLEMENT_STALE"
    assert res.status == "Pushed to Settlement" and res.gate_out_date == date(2026, 8, 28)
    db.refresh(locked)
    assert locked.expense_invoices == before


def _pushed_with_settlement_locked(db):
    from modules.financial_settlement.model import LandedCostSettlementRecord
    db.add(ImportFile(import_file_id=3, import_file_code="IMP-2026-0453", company_name="Co", supplier_name="Sup", owner="t"))
    db.commit()
    t = _tracking(db, date(2026, 8, 1), code="DND-T-0030", gate_out_date=date(2026, 8, 20))
    t.import_file_id = 3
    db.commit()
    res = dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=t.tracking_id), user="acct")
    settlement = db.get(LandedCostSettlementRecord, res["settlement_id"])
    settlement.status = "Approved"
    db.commit()
    return t, settlement


def test_dd_push_security_file_mismatch_and_permission(db, monkeypatch):
    t = _tracking(db, date(2026, 8, 1))
    with pytest.raises(HTTPException) as exc:
        dd.push_demurrage_to_financial_settlement_service(db, PushToSettlementRequest(tracking_id=t.tracking_id, import_file_id=99))
    assert exc.value.status_code == 400
    import modules.auth.permissions as perms
    monkeypatch.setattr(perms, "has_user_permission", lambda _db, _user, code: code != "financial_settlement.calculate")
    with pytest.raises(HTTPException) as exc:
        dd.push_demurrage_to_financial_settlement_service(
            db, PushToSettlementRequest(tracking_id=t.tracking_id), user="op", actor=User(username="op", role="LOGISTICS_OPERATOR", is_active=True))
    assert exc.value.status_code == 403


def test_dd_radar_skips_bad_rate_and_groups_currencies(db):
    today = date.today()
    _tracking(db, today - timedelta(days=20), code="DND-T-0040")
    eur = _tracking(db, today - timedelta(days=20), code="DND-T-0041")
    eur.currency = "EUR"
    bad = _tracking(db, today - timedelta(days=20), code="DND-T-0042")
    bad.exchange_rate = 0.0
    db.commit()
    radar = dd.get_containers_radar_overview_service(db)
    assert radar.skipped_tracking_codes == ["DND-T-0042"]
    assert set(radar.total_accrued_carrier_fx_by_currency) == {"USD", "EUR"}
    assert radar.total_accrued_demurrage_usd == radar.total_accrued_carrier_fx_by_currency["USD"]
    assert {i.currency for i in radar.radar_items} == {"USD", "EUR"}


def test_dd_eir_on_tracking_without_containers_and_no_list_is_404(db):
    t = _tracking(db, date(2026, 8, 1))
    t.containers = []
    db.commit()
    with pytest.raises(HTTPException) as exc:
        dd.record_empty_container_return_service(db, EmptyContainerReturnSubmit(import_file_id=1, eir_number="EIR-404", empty_return_date=date(2026, 8, 10)))
    assert exc.value.status_code == 404


def test_cs_checklist_rerun_after_upload_stage_409_delete_guard_and_same_approver_audit(db):
    from modules.audit_logs.model import AuditLog
    rec = _shipping(db)
    cs.submit_level1_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="alice")
    rec = cs.submit_level2_approval_service(db, rec.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="alice")
    audit = db.query(AuditLog).filter(AuditLog.entity_type == "CargoShippingRecord", AuditLog.action == "DUAL_APPROVAL_SAME_APPROVER").one()
    assert audit.performed_by == "alice" and '"same_approver": true' in audit.new_values
    with pytest.raises(HTTPException) as exc:
        cs.soft_delete_cargo_shipping_service(db, rec.cargo_shipping_id)
    assert exc.value.status_code == 409
    rec.cargox_exchange_data = {"envelope_status": "Ready for Upload", "verification_checklist": [{"rule_name": "x", "passed": True}]}
    db.commit()
    with pytest.raises(HTTPException) as exc:
        cs.execute_cargox_checklist_service(db, rec.cargo_shipping_id)
    assert exc.value.status_code == 409


def test_fb_status_downgrade_blocked_step06_not_rewritten_and_delete_guard(db):
    f = db.get(ImportFile, 1)
    f.current_step_code, f.current_module = "STEP_13", "STEP_13 Customs Declaration 46"
    db.commit()
    draft = _booking(db, import_file_id=1)
    assert db.get(ImportFile, 1).current_step_code == "STEP_13"  # a Draft booking never pulls the file back to STEP_06
    from modules.freight_booking.schemas import ShipmentBookingUpdate
    fb.update_booking_service(db, draft.booking_id, ShipmentBookingUpdate(notes="n"))
    assert db.get(ImportFile, 1).current_step_code == "STEP_13"
    fb.confirm_booking_service(db, draft.booking_id, ShipmentBookingConfirm(booking_confirmation_no="CN-9"), user="mgr")
    assert db.get(ImportFile, 1).current_step_code == "STEP_13"
    for target in ("Draft", "Booking Requested"):
        with pytest.raises(HTTPException) as exc:
            fb.update_booking_service(db, draft.booking_id, ShipmentBookingUpdate(status=target))
        assert exc.value.status_code == 409
    with pytest.raises(HTTPException) as exc:
        fb.soft_delete_booking_service(db, draft.booking_id)
    assert exc.value.status_code == 409
    assert fb.update_booking_service(db, draft.booking_id, ShipmentBookingUpdate(status="Amended")).status == "Amended"
    assert fb.update_booking_service(db, draft.booking_id, ShipmentBookingUpdate(status="Cancelled")).status == "Cancelled"


def test_ins_null_rate_resets_to_configured_value_and_issued_not_deletable(db):
    service = CargoInsuranceService(db)
    cert = service.create_certificate(CargoInsuranceCertificateCreate(
        insured_entity_name="Importer", port_of_loading="Shanghai", port_of_discharge="Alexandria", invoice_value=5000,
        freight_cost=500, tax_rate=0.2, minimum_premium=50), current_user="u")
    assert (cert.tax_rate, cert.minimum_premium) == (0.2, 50)
    db.add(SystemParameter(param_key="INSURANCE_TAX_RATE", param_value="0.07"))
    db.commit()
    updated = service.update_certificate(cert.certificate_id, CargoInsuranceCertificateUpdate(tax_rate=None, minimum_premium=None))
    assert (updated.tax_rate, updated.minimum_premium) == (0.07, 30.0)
    assert updated.tax_amount == round((30.0 + 15.0) * 0.07, 2)
    service.issue_certificate(cert.certificate_id)
    with pytest.raises(HTTPException) as exc:
        service.delete_certificate(cert.certificate_id)
    assert exc.value.status_code == 409
