import pytest
from datetime import datetime, timezone, date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from main import app
from database.database import Base, get_db
from modules.purchase_orders.model import PurchaseOrder
from modules.purchase_orders.schemas import PurchaseOrderUpdate
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.service import PurchaseOrderService
from modules.common.concurrency import ConcurrencyConflictException, ConcurrencyConflictLog
from modules.docs_customs_approval.model import CustomsDocumentApproval, DocsCustomsApprovalSession
from modules.docs_customs_approval.schemas import CommercialReviewPayload, CustomsBrokerReviewPayload, DocsCustomsApprovalSessionUpdate
from modules.docs_customs_approval.service import submit_commercial_review_service, submit_customs_broker_review_service
from modules.financial_approval.model import PaymentRequestSession, ImportBudgetApproval
from modules.financial_approval.schemas import PaymentRequestUpdate, ImportBudgetUpdate
from modules.financial_approval.service import update_payment_request_service, update_import_budget_service
from modules.import_files.model import ImportFile


@pytest.fixture
def test_engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture
def SessionLocal(test_engine):
    return sessionmaker(bind=test_engine)


def test_monotonic_version_increment(SessionLocal):
    db = SessionLocal()
    repo = PurchaseOrderRepository(db)

    # 1. Create Initial PO
    po = PurchaseOrder(
        po_number="PO-TEST-MONO-01",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        version=1,
        status="Draft",
        notes="Initial Note",
        is_active=True,
    )
    db.add(po)
    db.commit()
    assert po.version == 1

    # 2. Update with version 1
    updated_1 = PurchaseOrderService(db).update(po.po_id, PurchaseOrderUpdate(notes="Note 1", version=1), current_user_name="User1")
    assert updated_1.version == 2
    assert updated_1.notes == "Note 1"

    # 3. Update with version 2
    updated_2 = PurchaseOrderService(db).update(po.po_id, PurchaseOrderUpdate(notes="Note 2", version=2), current_user_name="User1")
    assert updated_2.version == 3
    assert updated_2.notes == "Note 2"


def test_concurrent_edit_conflict_detection(SessionLocal):
    db_setup = SessionLocal()
    po = PurchaseOrder(
        po_number="PO-TEST-CONCURRENT-01",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        payment_terms="100% CAD",
        version=1,
        status="Draft",
        is_active=True,
    )
    db_setup.add(po)
    db_setup.commit()
    po_id = po.po_id

    # User A and User B open record simultaneously (both see version 1)
    db_user_a = SessionLocal()
    repo_a = PurchaseOrderRepository(db_user_a)
    po_user_a = repo_a.get_by_id(po_id)
    assert po_user_a.version == 1

    db_user_b = SessionLocal()
    repo_b = PurchaseOrderRepository(db_user_b)
    po_user_b = repo_b.get_by_id(po_id)
    assert po_user_b.version == 1

    # User A saves first
    saved_a = PurchaseOrderService(db_user_a).update(
        po_id,
        PurchaseOrderUpdate(payment_terms="30% Advance, 70% LC", version=1),
        current_user_name="UserA",
    )
    assert saved_a.version == 2

    # User B attempts to save stale version 1
    with pytest.raises(ConcurrencyConflictException) as exc_info:
        PurchaseOrderService(db_user_b).update(
            po_id,
            PurchaseOrderUpdate(payment_terms="Net 60 Days", version=1),
            current_user_name="UserB",
        )

    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["error"] == "CONCURRENCY_CONFLICT"
    assert exc.detail["entity"] == "PurchaseOrder"
    assert exc.detail["record_id"] == po_id
    assert exc.detail["current_version"] == 2
    assert exc.detail["submitted_version"] == 1

    # Verify audit log in DB
    db_audit = SessionLocal()
    conflict_logs = db_audit.query(ConcurrencyConflictLog).filter_by(record_id=po_id).all()
    assert len(conflict_logs) == 1
    assert conflict_logs[0].entity_name == "PurchaseOrder"
    assert conflict_logs[0].current_version == 2
    assert conflict_logs[0].submitted_version == 1
    assert conflict_logs[0].attempted_by == "UserB"

    # User B recovers: reloads latest record, resolves conflict and saves on top of version 2
    db_user_b_refresh = SessionLocal()
    repo_b_refresh = PurchaseOrderRepository(db_user_b_refresh)
    po_fresh = repo_b_refresh.get_by_id(po_id)
    assert po_fresh.version == 2
    assert po_fresh.payment_terms == "30% Advance, 70% LC"

    saved_b = PurchaseOrderService(db_user_b_refresh).update(
        po_id,
        PurchaseOrderUpdate(payment_terms="30% Advance, 70% LC (Confirmed by B)", version=2),
        current_user_name="UserB",
    )
    assert saved_b.version == 3
    assert saved_b.payment_terms == "30% Advance, 70% LC (Confirmed by B)"


def test_api_concurrency_conflict_409(SessionLocal):
    db = SessionLocal()
    from modules.users.model import User
    user_b = User(
        username="UserB",
        email="userb@sorour.com",
        hashed_password="test_hash",
        full_name="User B",
        role="ADMIN",
        is_active=True,
    )
    db.add(user_b)

    po = PurchaseOrder(
        po_number="PO-TEST-API-CONCURRENT",
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        notes="Original Notes",
        version=1,
        status="Draft",
        is_active=True,
    )
    db.add(po)
    db.commit()
    po_id = po.po_id

    # User A bumps version to 2
    repo = PurchaseOrderRepository(db)
    PurchaseOrderService(db).update(po.po_id, PurchaseOrderUpdate(notes="User A Note", version=1), current_user_name="UserA")

    # User B calls PUT /api/purchase-orders/{po_id} with stale version=1
    def override_get_db():
        session = SessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)
    try:
        response = client.put(
            f"/api/v1/purchase-orders/{po_id}",
            json={"notes": "User B Stale Note", "version": 1},
            headers={"x-user-name": "UserB"},
        )
        assert response.status_code == 409
        body = response.json()
        assert body["detail"]["error"] == "CONCURRENCY_CONFLICT"
        assert body["detail"]["current_version"] == 2
        assert body["detail"]["submitted_version"] == 1
    finally:
        app.dependency_overrides.clear()


def test_payment_request_concurrency_conflict(SessionLocal):
    db_setup = SessionLocal()
    pay = PaymentRequestSession(
        payment_code="PAY-CONC-01",
        title="Supplier Advance Payment",
        requested_amount=10000.0,
        supplier_name="Alpha Trading Co",
        payment_type="Advance Payment",
        requested_amount_egp=500000.0,
        due_date=date(2026, 10, 1),
        request_date=date(2026, 9, 19),
        version=1,
        status="Draft",
        is_active=True,
    )
    db_setup.add(pay)
    db_setup.commit()
    pay_id = pay.payment_id

    # User A updates amount to 15,000 with version 1
    db_a = SessionLocal()
    saved_a = update_payment_request_service(
        db_a,
        pay_id,
        PaymentRequestUpdate(requested_amount=15000.0, version=1),
        current_user_name="UserA",
    )
    assert saved_a.version == 2
    assert saved_a.requested_amount == 15000.0

    # User B attempts to update amount to 12,000 with stale version 1
    db_b = SessionLocal()
    with pytest.raises(ConcurrencyConflictException) as exc_info:
        update_payment_request_service(
            db_b,
            pay_id,
            PaymentRequestUpdate(requested_amount=12000.0, version=1),
            current_user_name="UserB",
        )
    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["error"] == "CONCURRENCY_CONFLICT"
    assert exc.detail["entity"] == "PaymentRequestSession"
    assert exc.detail["current_version"] == 2
    assert exc.detail["submitted_version"] == 1

    # Verify audit log in DB
    db_audit = SessionLocal()
    logs = db_audit.query(ConcurrencyConflictLog).filter_by(record_id=pay_id).all()
    assert len(logs) == 1
    assert logs[0].entity_name == "PaymentRequestSession"
    assert logs[0].attempted_by == "UserB"

    # User B recovers: loads latest and updates on top of version 2
    db_b_fresh = SessionLocal()
    saved_b = update_payment_request_service(
        db_b_fresh,
        pay_id,
        PaymentRequestUpdate(requested_amount=12000.0, version=2),
        current_user_name="UserB",
    )
    assert saved_b.version == 3
    assert saved_b.requested_amount == 12000.0


def test_import_budget_concurrency_conflict(SessionLocal):
    db_setup = SessionLocal()
    budget = ImportBudgetApproval(
        budget_code="BGT-CONC-01",
        title="Import Budget Phase 1",
        invoice_amount_egp=500000.0,
        freight_cost_egp=50000.0,
        total_budget_egp=550000.0,
        budget_status="Pending Review",
        version=1,
        is_active=True,
    )
    db_setup.add(budget)
    db_setup.commit()
    budget_id = budget.budget_id

    # User A updates freight cost to 60,000
    db_a = SessionLocal()
    saved_a = update_import_budget_service(
        db_a,
        budget_id,
        ImportBudgetUpdate(freight_cost_egp=60000.0, version=1),
        current_user_name="UserA",
    )
    assert saved_a.version == 2
    assert saved_a.freight_cost_egp == 60000.0

    # User B attempts update with stale version 1
    db_b = SessionLocal()
    with pytest.raises(ConcurrencyConflictException) as exc_info:
        update_import_budget_service(
            db_b,
            budget_id,
            ImportBudgetUpdate(freight_cost_egp=55000.0, version=1),
            current_user_name="UserB",
        )
    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["entity"] == "ImportBudgetApproval"
    assert exc.detail["current_version"] == 2
    assert exc.detail["submitted_version"] == 1


def test_customs_document_approval_commercial_and_broker_review_occ(SessionLocal):
    db_setup = SessionLocal()
    import_file = ImportFile(
        import_file_code="IMP-2026-TEST-OCC",
        company_name="Test Company",
        supplier_name="Test Supplier",
    )
    db_setup.add(import_file)
    db_setup.commit()

    approval = CustomsDocumentApproval(
        approval_code="CDA-CONC-01",
        import_file_id=import_file.import_file_id,
        document_type="Commercial Invoice",
        commercial_status="Pending",
        customs_status="Pending",
        overall_status="Draft",
        version=1,
        is_active=True,
    )
    db_setup.add(approval)
    db_setup.commit()
    approval_id = approval.approval_id

    # User A signs off commercial review
    db_a = SessionLocal()
    saved_a = submit_commercial_review_service(
        db_a,
        approval_id,
        CommercialReviewPayload(
            reviewer_name="Reviewer A",
            status="Approved",
            notes="Passed commercial check",
            version=1,
        ),
    )
    assert saved_a.version == 2
    assert saved_a.commercial_status == "Approved"

    # User B tries to submit commercial review with stale version 1
    db_b = SessionLocal()
    with pytest.raises(ConcurrencyConflictException) as exc_info:
        submit_commercial_review_service(
            db_b,
            approval_id,
            CommercialReviewPayload(
                reviewer_name="Reviewer B",
                status="Rejected",
                notes="Price mismatch",
                version=1,
            ),
        )
    exc = exc_info.value
    assert exc.status_code == 409
    assert exc.detail["entity"] == "CustomsDocumentApproval"
    assert exc.detail["current_version"] == 2
    assert exc.detail["submitted_version"] == 1

    # Verify audit log in DB
    db_audit = SessionLocal()
    logs = db_audit.query(ConcurrencyConflictLog).filter_by(record_id=approval_id).all()
    assert len(logs) == 1
    assert logs[0].entity_name == "CustomsDocumentApproval"
    assert logs[0].attempted_by == "Reviewer B"

    # Broker review now succeeds on top of version 2
    db_c = SessionLocal()
    saved_c = submit_customs_broker_review_service(
        db_c,
        approval_id,
        CustomsBrokerReviewPayload(
            broker_name="Broker Express",
            reviewer_name="Legal Officer 1",
            status="Approved",
            version=2,
        ),
    )
    assert saved_c.version == 3
    assert saved_c.customs_status == "Approved"


def test_api_payment_request_concurrency_conflict_409(SessionLocal):
    db = SessionLocal()
    pay = PaymentRequestSession(
        payment_code="PAY-API-CONC",
        title="API Test Advance",
        requested_amount=5000.0,
        supplier_name="Beta Corp",
        payment_type="Advance Payment",
        requested_amount_egp=250000.0,
        due_date=date(2026, 10, 1),
        request_date=date(2026, 9, 19),
        version=1,
        status="Draft",
        is_active=True,
    )
    db.add(pay)
    db.commit()
    pay_id = pay.payment_id

    # User A updates payment request, version becomes 2
    update_payment_request_service(
        db,
        pay_id,
        PaymentRequestUpdate(requested_amount=6000.0, version=1),
        current_user_name="UserA",
    )

    def override_get_db():
        session = SessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)
    try:
        response = client.put(
            f"/api/v1/financial-approval/payment-requests/{pay_id}",
            json={"requested_amount": 7000.0, "version": 1},
            headers={"x-user-name": "UserB"},
        )
        assert response.status_code == 409
        body = response.json()
        assert body["detail"]["error"] == "CONCURRENCY_CONFLICT"
        assert body["detail"]["entity"] == "PaymentRequestSession"
        assert body["detail"]["current_version"] == 2
        assert body["detail"]["submitted_version"] == 1
    finally:
        app.dependency_overrides.clear()


