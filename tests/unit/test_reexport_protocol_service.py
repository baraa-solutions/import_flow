import pytest
from datetime import date, datetime, timedelta, timezone
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.import_files.model import ImportFile
from modules.users.model import User
from modules.reexport_protocol.model import ReexportDossier
from modules.reexport_protocol.schemas import (
    ReexportDossierCreate,
    ReexportDossierUpdate,
    OutboundBookingRequest,
    SupervisionCommitteeRequest,
    CreditNoteRequest,
    DutyDrawbackRequest,
    StatusTransitionRequest,
    ReexportStatus,
    DutyDrawbackStatus,
    SupplierCreditNoteStatus,
)
from modules.reexport_protocol.validators import (
    validate_legal_deadline,
    calculate_destruction_countdown,
    clean_container_numbers,
    validate_amounts,
    validate_status_transition,
)
from modules.reexport_protocol.service import ReexportProtocolService

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # Create dummy import file
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            company_name="El-Nasr Chemical Co.",
            supplier_name="Bavaria Chem GmbH",
            is_active=True,
            created_by="Tester",
        )
        db.add(imp_file)
        db.commit()
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    mock_admin = User(
        user_id=1,
        username="admin_tester",
        email="admin@test.com",
        full_name="Admin Tester",
        role_id=1,
        is_active=True,
    )

    def override_get_current_user():
        return mock_admin

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(main.app, headers={"X-User-Role": "ADMIN", "X-User-Name": "admin_tester"}) as c:
        yield c

    main.app.dependency_overrides.clear()


# ─── 1. Statutory Deadline & Validator Tests ─────────────────────────────────

def test_statutory_reexport_deadline_30_days_rule():
    rejection_date = date(2026, 8, 1)
    # Law 207/2020: 30 days statutory default
    deadline = validate_legal_deadline(rejection_date, None)
    assert deadline == rejection_date + timedelta(days=30)
    assert deadline == date(2026, 8, 31)

    # Valid explicit deadline
    explicit_valid = validate_legal_deadline(rejection_date, date(2026, 9, 15))
    assert explicit_valid == date(2026, 9, 15)

    # Rejection date after deadline must fail
    with pytest.raises(HTTPException) as exc_info:
        validate_legal_deadline(rejection_date, date(2026, 7, 25))
    assert exc_info.value.status_code == 400


def test_calculate_destruction_countdown_severities():
    today = date(2026, 10, 20)

    # Critical: deadline today or past
    rem, level = calculate_destruction_countdown(date(2026, 10, 20), today)
    assert rem == 0
    assert level == "CRITICAL"

    rem_neg, level_neg = calculate_destruction_countdown(date(2026, 10, 18), today)
    assert rem_neg == -2
    assert level_neg == "CRITICAL"

    # Urgent: 1 to 7 days
    rem_urg, level_urg = calculate_destruction_countdown(date(2026, 10, 25), today)
    assert rem_urg == 5
    assert level_urg == "URGENT"

    # Warning: 8 to 14 days
    rem_warn, level_warn = calculate_destruction_countdown(date(2026, 11, 2), today)
    assert rem_warn == 13
    assert level_warn == "WARNING"

    # Normal: > 14 days
    rem_norm, level_norm = calculate_destruction_countdown(date(2026, 11, 15), today)
    assert rem_norm == 26
    assert level_norm == "NORMAL"


def test_clean_container_numbers_and_amount_validators():
    raw_containers = [" msck1234567 ", "CMAU9988776", "msck1234567", "", None]
    cleaned = clean_container_numbers(raw_containers)
    assert cleaned == ["MSCK1234567", "CMAU9988776"]

    validate_amounts(1000.0, 500.0)  # should not raise
    with pytest.raises(HTTPException) as exc:
        validate_amounts(-50.0, 100.0)
    assert exc.value.status_code == 400

    with pytest.raises(HTTPException) as exc2:
        validate_amounts(50.0, -100.0)
    assert exc2.value.status_code == 400


# ─── 2. Service Level Creation & Query Tests ─────────────────────────────────

def test_create_reexport_dossier_service_success(db_session):
    today = date.today()
    payload = ReexportDossierCreate(
        import_file_id=1,
        import_file_code="IMP-2026-TEST",
        rejection_authority="GOIEC",
        rejection_decree_number="DEC-2026-8801",
        rejection_date=today,
        reexport_reason="Non-compliance with Egyptian Standard ES 4521/2020",
        container_numbers=["MSCU1122334", "MSCU4455667"],
        duty_amount_refundable_egp=85000.0,
        credit_note_amount_usd=12000.0,
    )

    dossier = ReexportProtocolService.create_dossier(db_session, payload, user="Inspector_Ahmed")
    assert dossier.reexport_id is not None
    assert dossier.import_file_code == "IMP-2026-TEST"
    assert dossier.rejection_authority == "GOIEC"
    assert dossier.rejection_decree_number == "DEC-2026-8801"
    assert dossier.legal_reexport_deadline == today + timedelta(days=30)
    assert dossier.status == "MANDATED"
    assert dossier.duty_drawback_status == "PENDING_APPLICATION"
    assert dossier.supplier_credit_note_status == "REQUESTED"
    assert len(dossier.container_numbers) == 2


def test_create_reexport_dossier_duplicate_conflict(db_session):
    today = date.today()
    payload = ReexportDossierCreate(
        import_file_id=1,
        import_file_code="IMP-2026-TEST",
        rejection_authority="NFSA",
        rejection_decree_number="NFSA-DECREE-99",
        rejection_date=today,
        reexport_reason="Aflatoxin above maximum permissible Egyptian limits",
    )
    ReexportProtocolService.create_dossier(db_session, payload)

    # Creating with same decree number must raise 409
    with pytest.raises(HTTPException) as exc:
        ReexportProtocolService.create_dossier(db_session, payload)
    assert exc.value.status_code == 409


def test_get_and_list_reexport_dossiers(db_session):
    today = date.today()
    dossier1 = ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="CAPQ",
            rejection_decree_number="CAPQ-001",
            rejection_date=today,
            reexport_reason="Quarantine insect detected in timber",
        ),
    )

    fetched = ReexportProtocolService.get_dossier(db_session, dossier1.reexport_id)
    assert fetched.reexport_id == dossier1.reexport_id
    assert fetched.rejection_decree_number == "CAPQ-001"

    # List with search
    items, total = ReexportProtocolService.list_dossiers(db_session, search="CAPQ")
    assert total >= 1
    assert any(i.rejection_decree_number == "CAPQ-001" for i in items)

    # 404 for non-existent
    with pytest.raises(HTTPException) as exc:
        ReexportProtocolService.get_dossier(db_session, 9999)
    assert exc.value.status_code == 404


def test_update_and_soft_delete_reexport_dossier(db_session):
    today = date.today()
    dossier = ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="MOH",
            rejection_decree_number="MOH-DEC-77",
            rejection_date=today,
            reexport_reason="Substandard assay potency",
        ),
    )

    updated = ReexportProtocolService.update_dossier(
        db_session,
        dossier.reexport_id,
        ReexportDossierUpdate(notes="Samples reviewed by central lab"),
        user="Tester",
    )
    assert updated.notes == "Samples reviewed by central lab"

    # Soft delete
    deleted = ReexportProtocolService.soft_delete_dossier(db_session, dossier.reexport_id, user="Tester")
    assert deleted.is_active is False

    with pytest.raises(HTTPException) as exc:
        ReexportProtocolService.get_dossier(db_session, dossier.reexport_id)
    assert exc.value.status_code == 404


# ─── 3. Operational Workflow & Statutory Milestones ──────────────────────────

def test_outbound_booking_and_supervision_committee_workflow(db_session):
    today = date.today()
    dossier = ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="GOIEC",
            rejection_decree_number="DEC-OPS-01",
            rejection_date=today,
            reexport_reason="Failed mechanical load test",
            container_numbers=["CMAU7788990"],
        ),
    )
    assert dossier.status == "MANDATED"

    # 1. Outbound return freight booking
    b_req = OutboundBookingRequest(
        return_booking_number="BK-MSC-EG-2026",
        return_port_of_discharge="Hamburg Port, Germany",
    )
    dossier_booked = ReexportProtocolService.record_outbound_booking(
        db_session, dossier.reexport_id, b_req, user="LogisticsOfficer"
    )
    assert dossier_booked.return_booking_number == "BK-MSC-EG-2026"
    assert dossier_booked.status == "BOOKING_CONFIRMED"

    # 2. Formation of customs supervision committee
    c_req = SupervisionCommitteeRequest(
        supervision_committee_formed=True,
        customs_officer_in_charge="Director Mahmoud Ibrahim",
        customs_outbound_declaration_no="EXP-DECL-4601-2026",
    )
    dossier_inspected = ReexportProtocolService.form_supervision_committee(
        db_session, dossier.reexport_id, c_req, user="CustomsOfficer"
    )
    assert dossier_inspected.supervision_committee_formed is True
    assert dossier_inspected.customs_outbound_declaration_no == "EXP-DECL-4601-2026"
    assert dossier_inspected.status == "CUSTOMS_INSPECTED"

    # 3. Transition to LADEN_ON_BOARD requires outbound B/L
    with pytest.raises(HTTPException) as exc:
        ReexportProtocolService.transition_status(db_session, dossier.reexport_id, "LADEN_ON_BOARD")
    assert exc.value.status_code == 400

    # Provide outbound BL
    ReexportProtocolService.update_dossier(
        db_session,
        dossier.reexport_id,
        ReexportDossierUpdate(outbound_bl_number="MEDUEG99887766"),
    )
    dossier_laden = ReexportProtocolService.transition_status(
        db_session, dossier.reexport_id, "LADEN_ON_BOARD"
    )
    assert dossier_laden.status == "LADEN_ON_BOARD"

    # 4. Final closure
    dossier_closed = ReexportProtocolService.transition_status(
        db_session, dossier.reexport_id, "COMPLETED_CLOSED"
    )
    assert dossier_closed.status == "COMPLETED_CLOSED"


def test_credit_note_and_duty_drawback_settlements(db_session):
    today = date.today()
    dossier = ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="NFSA",
            rejection_decree_number="NFSA-SETTLE-01",
            rejection_date=today,
            reexport_reason="Moisture content out of specs",
        ),
    )

    # Record Credit Note
    cn_req = CreditNoteRequest(
        supplier_credit_note_status=SupplierCreditNoteStatus.RECEIVED,
        credit_note_amount_usd=14500.0,
    )
    res_cn = ReexportProtocolService.record_credit_note(db_session, dossier.reexport_id, cn_req)
    assert res_cn.supplier_credit_note_status == "RECEIVED"
    assert res_cn.credit_note_amount_usd == 14500.0

    # Record Duty Drawback
    dd_req = DutyDrawbackRequest(
        duty_drawback_status=DutyDrawbackStatus.APPROVED_REFUNDED,
        duty_amount_refundable_egp=72300.0,
    )
    res_dd = ReexportProtocolService.record_duty_drawback(db_session, dossier.reexport_id, dd_req)
    assert res_dd.duty_drawback_status == "APPROVED_REFUNDED"
    assert res_dd.duty_amount_refundable_egp == 72300.0


def test_destruction_countdown_alerts_overview_service(db_session):
    today = date.today()
    # Dossier 1: Critical (deadline is 10 days ago)
    ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="GOIEC",
            rejection_decree_number="DEC-CRIT-01",
            rejection_date=today - timedelta(days=40),
            legal_reexport_deadline=today - timedelta(days=10),
            reexport_reason="Expired statutory deadline",
        ),
    )

    # Dossier 2: Urgent (5 days remaining)
    ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="CAPQ",
            rejection_decree_number="DEC-URG-02",
            rejection_date=today - timedelta(days=25),
            legal_reexport_deadline=today + timedelta(days=5),
            reexport_reason="Urgent re-export",
        ),
    )

    # Dossier 3: Warning (12 days remaining)
    ReexportProtocolService.create_dossier(
        db_session,
        ReexportDossierCreate(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            rejection_authority="NFSA",
            rejection_decree_number="DEC-WARN-03",
            rejection_date=today - timedelta(days=18),
            legal_reexport_deadline=today + timedelta(days=12),
            reexport_reason="Warning re-export",
        ),
    )

    overview = ReexportProtocolService.get_destruction_countdown_alerts(db_session, as_of_date=today)
    assert overview.total_active_dossiers >= 3
    assert overview.critical_count >= 1
    assert overview.urgent_count >= 1
    assert overview.warning_count >= 1


# ─── 4. REST API Endpoint Integration Tests ──────────────────────────────────

def test_reexport_protocol_rest_api_full_journey(client):
    today = date.today().isoformat()
    create_payload = {
        "import_file_id": 1,
        "import_file_code": "IMP-2026-TEST",
        "rejection_authority": "الهيئة العامة للرقابة على الصادرات والواردات (GOIEC)",
        "rejection_decree_number": "DEC-API-FULL-2026",
        "rejection_date": today,
        "reexport_reason": "عدم مطابقة الشحنة للمواصفة القياسية المصرية 2020",
        "container_numbers": ["TGHU1234567"],
        "duty_amount_refundable_egp": 95000.0,
        "credit_note_amount_usd": 15000.0,
    }

    # 1. POST create dossier
    post_res = client.post("/api/v1/reexport-protocol", json=create_payload)
    assert post_res.status_code == 201
    created_data = post_res.json()
    dossier_id = created_data["reexport_id"]
    assert created_data["rejection_decree_number"] == "DEC-API-FULL-2026"
    assert created_data["status"] == "MANDATED"

    # 2. GET by ID
    get_res = client.get(f"/api/v1/reexport-protocol/{dossier_id}")
    assert get_res.status_code == 200
    assert get_res.json()["reexport_id"] == dossier_id

    # 3. GET list
    list_res = client.get("/api/v1/reexport-protocol?search=DEC-API-FULL-2026")
    assert list_res.status_code == 200
    assert list_res.json()["total"] >= 1

    # 4. Outbound booking endpoint
    book_res = client.post(
        f"/api/v1/reexport-protocol/{dossier_id}/outbound-declaration",
        json={
            "return_booking_number": "BOOK-RET-9988",
            "return_port_of_discharge": "Rotterdam, Netherlands",
        },
    )
    assert book_res.status_code == 200
    assert book_res.json()["status"] == "BOOKING_CONFIRMED"

    # 5. Supervision committee endpoint
    comm_res = client.post(
        f"/api/v1/reexport-protocol/{dossier_id}/supervision-committee",
        json={
            "supervision_committee_formed": True,
            "customs_officer_in_charge": "المستشار الجمركي كمال رضوان",
            "customs_outbound_declaration_no": "EXP-DEC-887766",
        },
    )
    assert comm_res.status_code == 200
    assert comm_res.json()["status"] == "CUSTOMS_INSPECTED"

    # 6. Credit note endpoint
    cn_res = client.post(
        f"/api/v1/reexport-protocol/{dossier_id}/credit-note",
        json={
            "supplier_credit_note_status": "RECEIVED",
            "credit_note_amount_usd": 15000.0,
        },
    )
    assert cn_res.status_code == 200
    assert cn_res.json()["supplier_credit_note_status"] == "RECEIVED"

    # 7. Duty drawback endpoint
    dd_res = client.post(
        f"/api/v1/reexport-protocol/{dossier_id}/duty-drawback",
        json={
            "duty_drawback_status": "APPROVED_REFUNDED",
            "duty_amount_refundable_egp": 95000.0,
        },
    )
    assert dd_res.status_code == 200
    assert dd_res.json()["duty_drawback_status"] == "APPROVED_REFUNDED"

    # 8. Destruction alerts overview endpoint
    alerts_res = client.get("/api/v1/reexport-protocol/alerts/destruction-countdown")
    assert alerts_res.status_code == 200
    assert "alerts" in alerts_res.json()

    # 9. DELETE soft-delete
    del_res = client.delete(f"/api/v1/reexport-protocol/{dossier_id}")
    assert del_res.status_code == 200
    assert del_res.json()["is_active"] is False
