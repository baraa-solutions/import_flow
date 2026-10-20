from datetime import date, datetime, timezone
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Ensures all models and routers are registered
from database.database import Base, get_db
from modules.broker_custody.model import BrokerCustodyAdvance, BrokerExpenseItem
from modules.broker_custody.schemas import (
    BrokerCustodyAdvanceCreate,
    BrokerCustodyAdvanceUpdate,
    BrokerExpenseItemCreate,
    BrokerExpenseItemUpdate,
    ExpenseItemApprovalRequest,
)
from modules.broker_custody.service import BrokerCustodyService
from modules.broker_custody.validators import (
    validate_expense_category,
    validate_payment_method,
    validate_wht_rate,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile


# Test database setup
engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()

    # Seed test broker
    broker = ExternalServiceProvider(
        provider_id=20,
        partner_code="BRK-ALEX-01",
        partner_name="Alexandria Customs Clearance Agency",
        partner_type="Customs Broker",
        is_active=True,
    )
    session.add(broker)

    # Seed test import file
    imp_file = ImportFile(
        import_file_id=202,
        import_file_code="IMP-2026-0002",
        company_name="Delta Industrial Supplies",
        supplier_name="Euro Parts GmbH",
        is_active=True,
    )
    session.add(imp_file)
    session.commit()

    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Unit Tests: Validators
# ---------------------------------------------------------------------------
def test_validate_expense_categories():
    assert validate_expense_category("OFFICIAL_DUTIES_TAXES") == "OFFICIAL_DUTIES_TAXES"
    assert validate_expense_category("sundry_petty_cash") == "SUNDRY_PETTY_CASH"
    with pytest.raises(HTTPException):
        validate_expense_category("PERSONAL_EXPENSE")


def test_validate_wht_rate():
    assert validate_wht_rate(0.01) == 0.01
    assert validate_wht_rate(0.0) == 0.0
    with pytest.raises(HTTPException):
        validate_wht_rate(-0.05)
    with pytest.raises(HTTPException):
        validate_wht_rate(1.5)


def test_validate_e_invoice_requirement(db):
    service = BrokerCustodyService(db)
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=50000.0,
            disbursement_date=date(2026, 4, 1),
        )
    )

    # If is_e_invoice_backed is True, e_invoice_uuid must be provided
    with pytest.raises(HTTPException) as exc:
        service.add_expense_item(
            adv.advance_id,
            BrokerExpenseItemCreate(
                expense_category="HANDLING_AND_PORTERAGE",
                is_e_invoice_backed=True,
                e_invoice_uuid=None,  # Missing UUID
                amount=2000.0,
            ),
        )
    assert exc.value.status_code == 400


# ---------------------------------------------------------------------------
# Unit Tests: Advance CRUD
# ---------------------------------------------------------------------------
def test_create_broker_custody_advance(db):
    service = BrokerCustodyService(db)
    payload = BrokerCustodyAdvanceCreate(
        import_file_id=202,
        broker_id=20,
        advance_amount=75000.0,
        disbursement_date=date(2026, 4, 10),
        payment_method="BANK_TRANSFER",
        notes="Port Said customs clearance advance",
    )

    advance = service.create_advance(payload, current_user="treasurer")
    assert advance.advance_id is not None
    assert advance.advance_code.startswith("ADV-")
    assert advance.import_file_code == "IMP-2026-0002"
    assert advance.broker_name == "Alexandria Customs Clearance Agency"
    assert advance.advance_amount == 75000.0
    assert advance.status == "OPEN"
    assert advance.settled_amount == 0.0
    assert advance.remaining_balance == 75000.0


def test_update_and_delete_advance(db):
    service = BrokerCustodyService(db)
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=20000.0,
            disbursement_date=date(2026, 4, 12),
        )
    )

    updated = service.update_advance(
        adv.advance_id,
        BrokerCustodyAdvanceUpdate(advance_amount=25000.0, notes="Increased advance"),
    )
    assert updated.advance_amount == 25000.0
    assert updated.remaining_balance == 25000.0

    service.delete_advance(adv.advance_id)
    with pytest.raises(HTTPException) as exc:
        service.get_advance(adv.advance_id)
    assert exc.value.status_code == 404


# ---------------------------------------------------------------------------
# Unit Tests: 1% WHT Calculation and Expense Workflow
# ---------------------------------------------------------------------------
def test_expense_item_wht_calculation(db):
    service = BrokerCustodyService(db)
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=50000.0,
            disbursement_date=date(2026, 4, 15),
        )
    )

    # 1. Service subject to 1% WHT (Form 41)
    # Amount = 10,000 -> 1% tax withheld = 100.0 -> net settled = 9,900.0
    item1 = service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="HANDLING_AND_PORTERAGE",
            is_e_invoice_backed=True,
            e_invoice_uuid="INV-ETA-UUID-12345",
            amount=10000.0,
            tax_withholding_rate=0.01,
            approval_status="APPROVED",
        ),
    )
    assert item1.tax_withholding_rate == 0.01
    assert item1.tax_withheld_amount == 100.0
    assert item1.net_settled_amount == 9900.0

    # 2. Government official duty (0% WHT)
    # Amount = 25,000 -> tax withheld = 0 -> net settled = 25,000.0
    item2 = service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="OFFICIAL_DUTIES_TAXES",
            is_e_invoice_backed=False,
            receipt_reference="EGY-CUSTOMS-RCPT-8871",
            amount=25000.0,
            tax_withholding_rate=0.0,
            approval_status="APPROVED",
        ),
    )
    assert item2.tax_withheld_amount == 0.0
    assert item2.net_settled_amount == 25000.0


# ---------------------------------------------------------------------------
# Unit Tests: Petty Cash Approval Workflow
# ---------------------------------------------------------------------------
def test_petty_cash_approval_workflow(db):
    service = BrokerCustodyService(db)
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=10000.0,
            disbursement_date=date(2026, 4, 16),
        )
    )

    # Sundry petty cash added without approval -> must be PENDING
    petty_item = service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="SUNDRY_PETTY_CASH",
            is_e_invoice_backed=False,
            receipt_reference="PETTY-001",
            amount=1500.0,
            tax_withholding_rate=0.0,
            approval_status="PENDING",
            notes="Sundry photocopy and local porterage tips",
        ),
    )
    assert petty_item.approval_status == "PENDING"
    assert petty_item.verified_by is None

    # Supervisor approves petty cash
    approved = service.approve_petty_cash(
        petty_item.item_id,
        ExpenseItemApprovalRequest(
            approval_status="APPROVED",
            verified_by="logistics_supervisor",
            notes="Receipts inspected and approved",
        ),
    )
    assert approved.approval_status == "APPROVED"
    assert approved.verified_by == "logistics_supervisor"
    assert "Receipts inspected" in (approved.notes or "")


# ---------------------------------------------------------------------------
# Unit Tests: Settlement Reconciliation (/settle)
# ---------------------------------------------------------------------------
def test_settlement_reconciliation_partial_and_full(db):
    service = BrokerCustodyService(db)
    # Advance of 50,000 EGP
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=50000.0,
            disbursement_date=date(2026, 4, 18),
        )
    )

    # Add approved expense 1: Official Duties 30,000 (0% WHT -> net 30,000)
    service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="OFFICIAL_DUTIES_TAXES",
            amount=30000.0,
            tax_withholding_rate=0.0,
            approval_status="APPROVED",
        ),
    )

    # Add approved expense 2: Lab Testing 10,000 (1% WHT -> 100 tax -> net 9,900)
    service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="LAB_TESTING_FEES",
            amount=10000.0,
            tax_withholding_rate=0.01,
            approval_status="APPROVED",
        ),
    )

    # Add unapproved/pending petty cash: 2,000 (should NOT be settled yet)
    service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="SUNDRY_PETTY_CASH",
            amount=2000.0,
            tax_withholding_rate=0.0,
            approval_status="PENDING",
        ),
    )

    # First reconciliation: Partial settlement
    # Total net settled = 30,000 + 9,900 = 39,900
    # Balance remaining = 50,000 - 39,900 = 10,100
    recon1 = service.reconcile_and_settle(adv.advance_id, current_user="finance_mgr")
    assert recon1.status == "PARTIALLY_SETTLED"
    assert recon1.total_expenses_claimed == 40000.0
    assert recon1.total_tax_withheld_w41 == 100.0
    assert recon1.total_net_settled == 39900.0
    assert recon1.balance_remaining == 10100.0
    assert recon1.approved_items_count == 2
    assert recon1.pending_items_count == 1

    # Now add expense item that settles the remaining balance exactly:
    # 10,100 / 0.99 = 10202.02 -> Or simply add 0% WHT official port fee of 10,100
    service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="PORT_AUTHORITY_FEES",
            amount=10100.0,
            tax_withholding_rate=0.0,
            approval_status="APPROVED",
        ),
    )

    recon2 = service.reconcile_and_settle(adv.advance_id, current_user="finance_mgr")
    assert recon2.status == "SETTLED"
    assert recon2.total_net_settled == 50000.0
    assert recon2.balance_remaining == 0.0


def test_settlement_reconciliation_excess_expenses(db):
    service = BrokerCustodyService(db)
    # Advance of 20,000 EGP
    adv = service.create_advance(
        BrokerCustodyAdvanceCreate(
            import_file_id=202,
            broker_id=20,
            advance_amount=20000.0,
            disbursement_date=date(2026, 4, 20),
        )
    )

    # Broker spent 25,000 on official duties
    service.add_expense_item(
        adv.advance_id,
        BrokerExpenseItemCreate(
            expense_category="OFFICIAL_DUTIES_TAXES",
            amount=25000.0,
            tax_withholding_rate=0.0,
            approval_status="APPROVED",
        ),
    )

    recon = service.reconcile_and_settle(adv.advance_id)
    assert recon.status == "SETTLED"
    assert recon.total_net_settled == 25000.0
    assert recon.balance_remaining == -5000.0  # Company owes broker 5,000 EGP


# ---------------------------------------------------------------------------
# Integration Tests: FastAPI Endpoints (/api/v1/broker-custody)
# ---------------------------------------------------------------------------
def test_broker_custody_api_endpoints(client):
    # 1. Create Advance
    res = client.post(
        "/api/v1/broker-custody/advances",
        json={
            "import_file_id": 202,
            "broker_id": 20,
            "advance_amount": 40000.0,
            "disbursement_date": "2026-04-22",
            "payment_method": "BANK_TRANSFER",
            "notes": "API test advance",
        },
    )
    assert res.status_code == 201
    adv_data = res.json()
    advance_id = adv_data["advance_id"]
    assert adv_data["advance_code"].startswith("ADV-")
    assert adv_data["advance_amount"] == 40000.0

    # 2. Add Expense Item
    res = client.post(
        f"/api/v1/broker-custody/advances/{advance_id}/expenses",
        json={
            "expense_category": "HANDLING_AND_PORTERAGE",
            "is_e_invoice_backed": True,
            "e_invoice_uuid": "API-UUID-9988",
            "amount": 20000.0,
            "tax_withholding_rate": 0.01,
            "approval_status": "PENDING",
        },
    )
    assert res.status_code == 201
    item_data = res.json()
    item_id = item_data["item_id"]
    assert item_data["tax_withheld_amount"] == 200.0
    assert item_data["net_settled_amount"] == 19800.0
    assert item_data["approval_status"] == "PENDING"

    # 3. Approve Expense Item
    res = client.post(
        f"/api/v1/broker-custody/expenses/{item_id}/approve",
        json={
            "approval_status": "APPROVED",
            "verified_by": "auditor_1",
            "notes": "E-Invoice verified on ETA portal",
        },
    )
    assert res.status_code == 200
    assert res.json()["approval_status"] == "APPROVED"
    assert res.json()["verified_by"] == "auditor_1"

    # 4. Settle Advance
    res = client.post(f"/api/v1/broker-custody/advances/{advance_id}/settle")
    assert res.status_code == 200
    settle_data = res.json()
    assert settle_data["status"] == "PARTIALLY_SETTLED"
    assert settle_data["total_net_settled"] == 19800.0
    assert settle_data["balance_remaining"] == 20200.0
    assert settle_data["approved_items_count"] == 1

    # 5. Delete Advance
    res = client.delete(f"/api/v1/broker-custody/advances/{advance_id}")
    assert res.status_code == 204
