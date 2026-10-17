"""
Unit tests for BE09-T01: Closed import file makes the settlement read-only (F02).

Contract:
- On a Closed/Archived import file:
  - create / PUT / recalculate / DELETE / restore / confirm / approve on financial settlement
    raise 409 with code "IMPORT_FILE_CLOSED".
  - recalculation apply on financial_settlement raises 409 "IMPORT_FILE_CLOSED" and creates
    a log row with result_status="blocked_file_closed".
  - recalculation preview returns can_apply=False and blocked_by_status=True.
  - total_landed_cost_egp and settlement data remain unchanged.
  - reads, simulation (simulate-file), aggregation, and exports still work.
  - after reopening the file via reopen_shipment_service, writes succeed.
"""
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
import pytest
from fastapi import HTTPException, status
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

import main  # registers models
from database.database import Base, get_db
from modules.auth.security import create_access_token
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.schemas import (
    ApproveActualLandedCostRequest,
    ConfirmInvoicesSettlementRequest,
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
)
from modules.financial_settlement import service as fs_service
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ReopenShipmentSubmit
from modules.import_files import service as imp_service
from modules.recalculation.model import RecalculationDependencyMap, RecalculationLog
from modules.recalculation import service as recalc_service
from modules.recalculation.schemas import RecalculationApplyRequest
from modules.users.model import User


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def db() -> Session:
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db: Session):
    def override_get_db():
        yield db

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


def make_test_user(db: Session, username: str = "finance_user", role: str = "FINANCE_OFFICER") -> User:
    user = User(
        username=username,
        full_name="Finance Tester",
        email=f"{username}@sorour.com",
        role=role,
        is_active=True,
        hashed_password="hashed_pw",
    )
    db.add(user)
    db.commit()
    return user


def make_closed_file(db: Session, code: str = "IMP-2026-9001", status: str = "Closed") -> ImportFile:
    imp = ImportFile(
        import_file_code=code,
        company_name="Test Company",
        supplier_name="Test Supplier",
        status=status,
        incoterm_code="FOB",
        current_stage="Stage 9: Landed Cost & File Closure",
        current_module="Phase 10 - Closed",
        is_active=True,
        actual_landed_cost_total_egp=140_000.0,
        actual_landed_cost_variance_egp=5_000.0,
        financial_settlement_status="Calculated",
        estimated_cost_currency="EGP",
        estimated_cost=100_000.0,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def make_settlement_record(
    db: Session,
    imp_file: ImportFile,
    settlement_code: str = "LCS-2026-9001",
    status: str = "Calculated",
    is_active: bool = True,
) -> LandedCostSettlementRecord:
    rec = LandedCostSettlementRecord(
        settlement_code=settlement_code,
        import_file_id=imp_file.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[
            {
                "invoice_no": "INV-FREIGHT-01",
                "category": "Freight",
                "provider_name": "Maersk",
                "currency": "EGP",
                "amount_fx": 20_000.0,
                "exchange_rate": 1.0,
                "amount_egp": 20_000.0,
                "allocation_rule": "Equal",
            },
            {
                "invoice_no": "INV-DUTY-01",
                "category": "Customs Duty",
                "provider_name": "Customs Authority",
                "currency": "EGP",
                "amount_fx": 20_000.0,
                "exchange_rate": 1.0,
                "amount_egp": 20_000.0,
                "allocation_rule": "Equal",
            },
        ],
        total_fob_egp=100_000.0,
        total_expenses_egp=40_000.0,
        total_landed_cost_egp=140_000.0,
        average_markup_factor=1.40,
        item_landed_costs=[
            {
                "item_code": "ITM-01",
                "item_name": "Valves",
                "qty": 10,
                "fob_unit_egp": 10000.0,
                "fob_total_egp": 100000.0,
                "total_landed_cost_egp": 140000.0,
                "unit_landed_cost_egp": 14000.0,
                "markup_factor": 1.40,
            }
        ],
        status=status,
        accountant_name="Kamal",
        is_active=is_active,
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


# ── Tests ─────────────────────────────────────────────────────────────────────

def test_closed_file_blocks_update_settlement_service(db: Session):
    """PUT on a settlement of a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    update_payload = FinancialSettlementUpdate(notes="Attempted modification")
    with pytest.raises(HTTPException) as exc_info:
        fs_service.update_settlement_service(db, settlement.settlement_id, update_payload, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code

    # Verify no state change
    db.refresh(settlement)
    assert settlement.total_landed_cost_egp == 140_000.0
    assert settlement.notes != "Attempted modification"


def test_closed_file_blocks_recalculate_settlement_service(db: Session):
    """POST /recalculate on a settlement of a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    with pytest.raises(HTTPException) as exc_info:
        fs_service.recalculate_settlement_service(db, settlement.settlement_id, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code


def test_closed_file_blocks_soft_delete_settlement_service(db: Session):
    """DELETE on a settlement of a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    with pytest.raises(HTTPException) as exc_info:
        fs_service.soft_delete_settlement_service(db, settlement.settlement_id, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code

    db.refresh(settlement)
    assert settlement.is_active is True


def test_closed_file_blocks_restore_settlement_service(db: Session):
    """PATCH restore on a settlement of a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated", is_active=False)

    with pytest.raises(HTTPException) as exc_info:
        fs_service.restore_settlement_service(db, settlement.settlement_id, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code

    db.refresh(settlement)
    assert settlement.is_active is False


def test_closed_file_blocks_create_settlement_service(db: Session):
    """POST create on a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")

    create_payload = FinancialSettlementCreate(
        import_file_id=imp.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[],
    )
    with pytest.raises(HTTPException) as exc_info:
        fs_service.create_settlement_service(db, create_payload, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code


def test_closed_file_blocks_confirm_invoices_settlement(db: Session):
    """Confirm invoices settlement on a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")

    confirm_payload = ConfirmInvoicesSettlementRequest(
        import_file_id=imp.import_file_id,
    )
    with pytest.raises(HTTPException) as exc_info:
        fs_service.confirm_invoices_settlement_service(db, confirm_payload, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code


def test_closed_file_blocks_approve_actual_landed_cost(db: Session):
    """Approve actual landed cost on a Closed file raises 409 IMPORT_FILE_CLOSED."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    approve_payload = ApproveActualLandedCostRequest(
        import_file_id=imp.import_file_id,
        allocation_preference="Equal",
    )
    with pytest.raises(HTTPException) as exc_info:
        fs_service.approve_actual_landed_cost_service(db, approve_payload, actor="Accountant")

    assert exc_info.value.status_code == status.HTTP_409_CONFLICT
    assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
    assert exc_info.value.detail["import_file_code"] == imp.import_file_code


def test_closed_file_recalculation_preview_and_apply(db: Session):
    """
    Recalculation on financial_settlement for a Closed file:
    - preview returns can_apply=False and blocked_by_status=True.
    - apply raises 409 IMPORT_FILE_CLOSED and logs result_status='blocked_file_closed'.
    """
    from modules.recalculation.seed_dependencies import run_seed
    run_seed(db)

    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")
    user = make_test_user(db, "gm_user", role="GENERAL_MANAGER")

    with patch("modules.recalculation.service.has_user_permission", return_value=True):
        # 1. Preview
        preview_res = recalc_service.preview(
            db=db,
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
            performed_by=user.username,
        )
        assert preview_res.can_apply is False
        assert preview_res.blocked_by_status is True

        # 2. Apply
        apply_req = RecalculationApplyRequest(
            target_entity_type="financial_settlement",
            target_entity_id=settlement.settlement_id,
            source_page="SettlementTest",
            justification="Emergency sync attempt",
        )
        with pytest.raises(HTTPException) as exc_info:
            recalc_service.apply(db=db, request=apply_req, current_user=user)

        assert exc_info.value.status_code == status.HTTP_409_CONFLICT
        assert exc_info.value.detail["code"] == "IMPORT_FILE_CLOSED"
        assert exc_info.value.detail["import_file_code"] == imp.import_file_code

        # 3. Verify audit log recorded blocked_file_closed
        logs = (
            db.query(RecalculationLog)
            .filter(
                RecalculationLog.target_entity_type == "financial_settlement",
                RecalculationLog.target_entity_id == settlement.settlement_id,
                RecalculationLog.action == "apply",
            )
            .all()
        )
        assert len(logs) == 1
        assert logs[0].result_status == "blocked_file_closed"


def test_closed_file_reads_and_simulations_remain_functional(db: Session):
    """GET settlement, simulation, and aggregation still work for a Closed file (read-only)."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    # 1. Get settlement
    res = fs_service.get_settlement_service(db, settlement.settlement_id)
    assert res.settlement_id == settlement.settlement_id
    assert res.total_landed_cost_egp == 140_000.0

    # 2. Aggregation
    agg = fs_service.aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert agg is not None

    # 3. Simulate file (does not persist changes)
    sim = fs_service.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert sim is not None


def test_reopen_shipment_allows_settlement_modification(db: Session):
    """After reopen_shipment_service, the settlement can be modified (PUT -> 200)."""
    imp = make_closed_file(db, status="Closed")
    settlement = make_settlement_record(db, imp, status="Calculated")

    # Reopen file
    reopen_payload = ReopenShipmentSubmit(reopen_reason="Audit and Landed Cost Adjustment Required")
    reopened = imp_service.reopen_shipment_service(db, imp.import_file_id, reopen_payload)
    assert reopened.status != "Closed"

    # Now PUT succeeds
    update_payload = FinancialSettlementUpdate(notes="Updated after shipment reopen")
    updated = fs_service.update_settlement_service(
        db, settlement.settlement_id, update_payload, actor="Accountant"
    )
    assert updated.notes == "Updated after shipment reopen"


def test_closed_file_settlement_http_endpoints_return_409(client: TestClient, db: Session):
    """Verify HTTP router endpoints return 409 IMPORT_FILE_CLOSED for closed file."""
    user = make_test_user(db, "http_admin", role="ADMIN")
    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    headers = {"Authorization": f"Bearer {token}"}

    imp = make_closed_file(db, code="IMP-2026-HTTP", status="Closed")
    settlement = make_settlement_record(db, imp, settlement_code="LCS-2026-HTTP", status="Calculated")

    # 1. PUT
    res = client.put(
        f"/api/v1/financial-settlement/{settlement.settlement_id}",
        json={"notes": "HTTP attempt"},
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"
    assert res.json()["detail"]["import_file_code"] == imp.import_file_code

    # 2. POST recalculate
    res = client.post(
        f"/api/v1/financial-settlement/{settlement.settlement_id}/recalculate",
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 3. DELETE
    res = client.delete(
        f"/api/v1/financial-settlement/{settlement.settlement_id}",
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 4. PATCH restore
    res = client.patch(
        f"/api/v1/financial-settlement/{settlement.settlement_id}/restore",
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 5. POST create
    res = client.post(
        "/api/v1/financial-settlement",
        json={"import_file_id": imp.import_file_id, "incoterm_code": "FOB", "expense_invoices": []},
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 6. POST confirm
    res = client.post(
        "/api/v1/financial-settlement/confirm-invoices-settlement",
        json={"import_file_id": imp.import_file_id},
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 7. POST approve
    res = client.post(
        "/api/v1/financial-settlement/approve-actual-landed-cost",
        json={"import_file_id": imp.import_file_id, "allocation_preference": "Equal"},
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 8. POST recalculation/apply
    res = client.post(
        "/api/v1/recalculation/apply",
        json={
            "target_entity_type": "financial_settlement",
            "target_entity_id": settlement.settlement_id,
            "source_page": "HttpTest",
        },
        headers=headers,
    )
    assert res.status_code == 409
    assert res.json()["detail"]["code"] == "IMPORT_FILE_CLOSED"

    # 9. POST recalculation/preview
    res = client.post(
        "/api/v1/recalculation/preview",
        params={
            "target_entity_type": "financial_settlement",
            "target_entity_id": settlement.settlement_id,
            "source_page": "HttpTest",
        },
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["can_apply"] is False
    assert data["blocked_by_status"] is True

