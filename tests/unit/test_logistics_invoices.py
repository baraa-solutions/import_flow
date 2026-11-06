"""
Unit Tests for Logistics Service Invoices & Payments Module (LSI)
=================================================================
Tests:
1. Freight invoice creation with 21 items and container lock
2. Container double-billing prevention (Invoice-to-Container Lock)
3. Marine insurance policy calculation (CIF + 10%), stamp duty, and invoice generation
4. Clearance advance payment and actual invoice settlement (surplus/deficit)
5. Payment vouchers and invoice knock-off (FIFO / partial settlement)
6. Live partner balance card and aging calculation
7. 3-Way match validation
"""

from datetime import datetime, date, timedelta, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider
from modules.currencies.model import Currency, ExchangeRate
from modules.logistics_invoices.model import (
    LogisticsServiceInvoice,
    InsurancePolicy,
    ClearanceAdvancePayment,
    LogisticsPaymentVoucher,
)
from modules.logistics_invoices.service import LogisticsInvoicesService
from modules.logistics_invoices.schemas import (
    LogisticsInvoiceCreate,
    LogisticsInvoiceLineCreate,
    LogisticsInvoiceContainerCreate,
    InsurancePolicyCreate,
    InsurancePolicyClaimCreate,
    ClearanceAdvancePaymentCreate,
    ClearanceAdvanceSettlementCreate,
    LogisticsPaymentVoucherCreate,
    InvoiceKnockoffItem,
    InsurancePolicyClaimStatusUpdate,
)


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = Session()

    # Seed a Currency and ExchangeRate
    curr = Currency(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_base_currency=False,
    )
    session.add(curr)
    session.flush()

    rate = ExchangeRate(
        currency_id=curr.currency_id,
        commercial_rate=48.50,
        customs_rate=48.50,
        effective_date=date.today(),
    )
    session.add(rate)

    # Seed an ImportFile
    shipment = ImportFile(
        import_file_code="IMP-2026-TEST-01",
        company_name="Sorour Logistics Co.",
        supplier_name="Global Tech Industrial",
        bl_number="MSCU98765432",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
        packing_lists_data=[
            {"container_no": "MSCU1112223", "seal_no": "SL-001"},
            {"container_no": "MSCU3334445", "seal_no": "SL-002"},
        ],
    )
    session.add(shipment)

    # Seed Partners
    shipping_line = ExternalServiceProvider(
        partner_code="PRV-MSC-01",
        partner_name="MSC Mediterranean Shipping Co.",
        partner_type="Shipping Line",
    )
    broker = ExternalServiceProvider(
        partner_code="PRV-BRK-01",
        partner_name="Al-Ahram Clearance Agency",
        partner_type="Customs Broker",
    )
    insurance_co = ExternalServiceProvider(
        partner_code="PRV-INS-01",
        partner_name="Misr Insurance Company",
        partner_type="Insurance Company",
    )
    session.add_all([shipping_line, broker, insurance_co])
    session.commit()

    try:
        yield session
    finally:
        session.close()


def test_create_freight_invoice_and_container_lock(db_session):
    service = LogisticsInvoicesService(db_session)

    payload = LogisticsInvoiceCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        partner_id=1,
        partner_type="freight",
        partner_name="MSC Mediterranean Shipping Co.",
        invoice_number="INV-MSC-2026-001",
        currency="USD",
        total_amount_fx=2500.0,
        exchange_rate=48.50,
        total_amount_egp=121250.0,
        net_payable_egp=121250.0,
        lines=[
            LogisticsInvoiceLineCreate(
                line_description="Ocean Freight",
                line_group="ocean_freight",
                quantity=1.0,
                unit_price_fx=2000.0,
                currency="USD",
                amount_fx=2000.0,
                exchange_rate=48.50,
                amount_egp=97000.0,
                net_amount_egp=97000.0,
            ),
            LogisticsInvoiceLineCreate(
                line_description="Terminal Handling Charges (THC)",
                line_group="port_charges",
                quantity=1.0,
                unit_price_fx=500.0,
                currency="USD",
                amount_fx=500.0,
                exchange_rate=48.50,
                amount_egp=24250.0,
                net_amount_egp=24250.0,
            ),
        ],
        containers=[
            LogisticsInvoiceContainerCreate(container_number="MSCU1112223", seal_number="SL-001"),
        ],
    )

    invoice = service.create_invoice(payload, user_name="Accountant")
    assert invoice.invoice_id is not None
    assert invoice.invoice_code.startswith("LSI-")
    assert invoice.net_payable_egp == 121250.0
    assert invoice.remaining_amount_egp == 121250.0
    assert invoice.payment_status == "UNPAID"
    assert len(invoice.lines) == 2
    assert len(invoice.containers) == 1


def test_container_lock_prevents_duplicate_billing(db_session):
    service = LogisticsInvoicesService(db_session)

    # 1. First invoice with container MSCU1112223
    p1 = LogisticsInvoiceCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        partner_id=1,
        partner_type="freight",
        partner_name="MSC Mediterranean Shipping Co.",
        invoice_number="INV-MSC-FIRST",
        currency="USD",
        total_amount_egp=10000.0,
        net_payable_egp=10000.0,
        containers=[
            LogisticsInvoiceContainerCreate(container_number="MSCU1112223"),
        ],
    )
    service.create_invoice(p1)

    # 2. Second invoice attempting to bill the same container MSCU1112223 for the same partner on same B/L
    p2 = LogisticsInvoiceCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        partner_id=1,
        partner_type="freight",
        partner_name="MSC Mediterranean Shipping Co.",
        invoice_number="INV-MSC-DUPLICATE",
        currency="USD",
        total_amount_egp=12000.0,
        net_payable_egp=12000.0,
        containers=[
            LogisticsInvoiceContainerCreate(container_number="MSCU1112223"),
        ],
    )
    with pytest.raises(HTTPException) as exc:
        service.create_invoice(p2)
    assert exc.value.status_code == 400
    assert "already billed" in exc.value.detail


def test_prefill_21_freight_items(db_session):
    service = LogisticsInvoicesService(db_session)
    prefill = service.get_prefill_lines(shipment_id=1, partner_type="freight")
    assert len(prefill.lines) == 21
    descriptions = [line.line_description for line in prefill.lines]
    assert any("Ocean Freight" in d for d in descriptions)
    assert any("Terminal Handling Charges" in d for d in descriptions)
    assert any("Telex Release" in d for d in descriptions)


def test_marine_insurance_policy_calculation_and_invoice(db_session):
    service = LogisticsInvoicesService(db_session)

    # 1. Preview: CIF = $50,000 -> Insured Value = CIF + 10% = $55,000
    preview = service.calculate_insurance_preview(shipment_id=1, premium_rate=0.35)
    assert preview.cif_value_fx == 50000.0
    assert preview.insured_value_fx == 55000.0
    # Premium FX = 55,000 * 0.35% = $192.50
    assert preview.premium_amount_fx == 192.50
    # In EGP = 192.50 * 48.50 = 9336.25 EGP
    assert preview.premium_amount_egp == 9336.25
    # Stamp duty = 9336.25 * 0.1% = 9.34 EGP
    assert preview.stamp_duty_egp == 9.34
    # Supervisory fee = 9336.25 * 12% = 1120.35 EGP
    assert preview.supervisory_fee_egp == 1120.35

    # 2. Create Policy
    policy_payload = InsurancePolicyCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        insurance_company_id=3,
        insurance_company_name="Misr Insurance Company",
        policy_number="POL-MISR-889900",
        coverage_type="all_risks",
        insured_value_fx=preview.insured_value_fx,
        insured_value_currency="USD",
        premium_rate=0.35,
        premium_amount_fx=preview.premium_amount_fx,
        exchange_rate=preview.exchange_rate,
        premium_amount_egp=preview.premium_amount_egp,
        stamp_duty_egp=preview.stamp_duty_egp,
        supervisory_fee_egp=preview.supervisory_fee_egp,
        net_premium_egp=preview.net_premium_egp,
    )
    policy = service.create_insurance_policy(policy_payload, user_name="Underwriter")
    assert policy.policy_id is not None
    assert policy.status == "issued"
    assert policy.invoice_generated is False

    # 3. Generate Service Invoice from Policy
    invoice = service.generate_invoice_from_policy(policy.policy_id, user_name="Finance")
    assert invoice.insurance_policy_id == policy.policy_id
    assert invoice.partner_type == "insurance"
    assert len(invoice.lines) == 3
    assert policy.invoice_generated is True

    # 4. Record Claim
    claim_payload = InsurancePolicyClaimCreate(
        claim_reference="CLM-2026-DAMAGE-01",
        claim_amount_egp=15000.0,
        claim_status="filed",
    )
    updated_policy = service.record_insurance_claim(policy.policy_id, claim_payload)
    assert updated_policy.status == "claimed"
    assert updated_policy.claim_reference == "CLM-2026-DAMAGE-01"


def test_clearance_advance_and_invoice_settlement(db_session):
    service = LogisticsInvoicesService(db_session)

    # 1. Disburse advance payment to broker: 30,000 EGP
    adv_payload = ClearanceAdvancePaymentCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        clearance_partner_id=2,
        clearance_partner_name="Al-Ahram Clearance Agency",
        amount=30000.0,
        currency="EGP",
        exchange_rate=1.0,
        amount_egp=30000.0,
        notes="Customs and port charges advance",
    )
    advance = service.create_advance(adv_payload, user_name="FinanceOfficer")
    assert advance.advance_id is not None
    assert advance.status == "disbursed"
    assert advance.remaining_amount_egp == 30000.0

    # 2. Broker presents actual invoice of 20,000 EGP
    inv_payload = LogisticsInvoiceCreate(
        shipment_id=1,
        bl_number="MSCU98765432",
        partner_id=2,
        partner_type="clearance",
        partner_name="Al-Ahram Clearance Agency",
        invoice_number="INV-BRK-ACTUAL-01",
        currency="EGP",
        total_amount_egp=20000.0,
        net_payable_egp=20000.0,
    )
    invoice = service.create_invoice(inv_payload, user_name="BrokerDesk")

    # 3. Settle invoice from the advance
    settle_payload = ClearanceAdvanceSettlementCreate(
        invoice_id=invoice.invoice_id,
        settled_amount_egp=20000.0,
        notes="Settling actual port inspection invoice",
    )
    settlement = service.settle_advance(advance.advance_id, settle_payload, user_name="FinanceOfficer")
    assert settlement.settled_amount_egp == 20000.0

    # Verify advance remaining: 30,000 - 20,000 = 10,000 EGP (partially settled)
    assert advance.remaining_amount_egp == 10000.0
    assert advance.status == "partially_settled"

    # Verify invoice is fully paid
    assert invoice.paid_amount_egp == 20000.0
    assert invoice.remaining_amount_egp == 0.0
    assert invoice.payment_status == "FULLY_PAID"


def test_payment_voucher_and_knockoff(db_session):
    service = LogisticsInvoicesService(db_session)

    # 1. Create two invoices for MSC
    i1 = service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC",
            invoice_number="INV-MSC-101",
            currency="EGP",
            total_amount_egp=50000.0,
            net_payable_egp=50000.0,
        )
    )
    i2 = service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC",
            invoice_number="INV-MSC-102",
            currency="EGP",
            total_amount_egp=30000.0,
            net_payable_egp=30000.0,
        )
    )

    # 2. Issue payment voucher for 70,000 EGP:
    # 50,000 for INV-MSC-101 (Full) and 20,000 for INV-MSC-102 (Partial)
    voucher_payload = LogisticsPaymentVoucherCreate(
        shipment_id=1,
        partner_id=1,
        partner_name="MSC",
        amount=70000.0,
        currency="EGP",
        exchange_rate=1.0,
        amount_egp=70000.0,
        payment_method="BANK_TRANSFER",
        bank_reference="CIB-TX-998811",
        knockoffs=[
            InvoiceKnockoffItem(invoice_id=i1.invoice_id, knocked_amount_egp=50000.0),
            InvoiceKnockoffItem(invoice_id=i2.invoice_id, knocked_amount_egp=20000.0),
        ],
    )
    voucher = service.create_payment_voucher(voucher_payload, user_name="Treasurer")
    assert voucher.voucher_id is not None
    assert voucher.allocated_amount_egp == 70000.0
    assert voucher.unallocated_amount_egp == 0.0

    # Check i1
    assert i1.paid_amount_egp == 50000.0
    assert i1.remaining_amount_egp == 0.0
    assert i1.payment_status == "FULLY_PAID"

    # Check i2
    assert i2.paid_amount_egp == 20000.0
    assert i2.remaining_amount_egp == 10000.0
    assert i2.payment_status == "PARTIALLY_PAID"


def test_partner_balance_card_and_aging(db_session):
    service = LogisticsInvoicesService(db_session)

    # Create an unpaid invoice
    service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC",
            invoice_number="INV-MSC-AGING-01",
            currency="EGP",
            total_amount_egp=15000.0,
            net_payable_egp=15000.0,
            invoice_date=datetime.now(timezone.utc) - timedelta(days=45),
        )
    )

    card = service.get_partner_balance_card(partner_id=1)
    assert card.partner_id == 1
    assert card.balance_due_egp >= 15000.0
    assert card.open_invoices_count >= 1
    # Check that aging placed the 45-day invoice in days_31_to_60
    assert card.aging.days_31_to_60 >= 15000.0


def test_partner_ledger_double_entry(db_session):
    service = LogisticsInvoicesService(db_session)

    # 1. Create an invoice (Debit to partner)
    inv = service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC Mediterranean Shipping Co.",
            invoice_number="INV-MSC-LEDGER-01",
            currency="EGP",
            total_amount_egp=30000.0,
            net_payable_egp=30000.0,
            invoice_date=datetime.now(timezone.utc) - timedelta(days=5),
        )
    )

    # 2. Create a payment voucher (Credit to partner)
    vouch = service.create_payment_voucher(
        LogisticsPaymentVoucherCreate(
            shipment_id=1,
            partner_id=1,
            partner_name="MSC Mediterranean Shipping Co.",
            amount=12000.0,
            currency="EGP",
            exchange_rate=1.0,
            amount_egp=12000.0,
            payment_date=datetime.now(timezone.utc) - timedelta(days=2),
            payment_method="bank_transfer",
            knockoffs=[
                InvoiceKnockoffItem(invoice_id=inv.invoice_id, knocked_amount_egp=12000.0)
            ],
        )
    )

    # 3. Retrieve partner ledger statement
    ledger = service.get_partner_ledger(partner_id=1)
    assert ledger.partner_id == 1
    assert ledger.total_invoiced_egp >= 30000.0
    assert ledger.total_paid_egp >= 12000.0
    assert ledger.closing_balance_egp >= 18000.0
    assert len(ledger.entries) >= 2

    # Verify chronological sequence & running balance
    debits = sum(e.debit_egp for e in ledger.entries)
    credits = sum(e.credit_egp for e in ledger.entries)
    assert round(debits - credits, 2) == round(ledger.closing_balance_egp, 2)


def test_wht_form41_report(db_session):
    service = LogisticsInvoicesService(db_session)

    now = datetime.now(timezone.utc)
    service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=2,
            partner_type="clearance",
            partner_name="Al-Ahram Clearance Agency",
            invoice_number="INV-BRK-WHT-01",
            currency="EGP",
            total_amount_egp=50000.0,
            wht_amount=1500.0,  # 3%
            net_payable_egp=48500.0,
            invoice_date=now,
        )
    )

    report = service.get_wht_form41_report(year=now.year, month=now.month)
    assert report.year == now.year
    assert report.month == now.month
    assert report.records_count >= 1
    assert report.total_gross_amount_egp >= 50000.0
    assert report.total_wht_amount_egp >= 1500.0

    # Verify at least one record has Arabic service type
    clearance_rec = next((r for r in report.records if r.partner_type == "clearance"), None)
    assert clearance_rec is not None
    assert "تخليص" in clearance_rec.service_type


def test_marine_insurance_claim_status_transitions(db_session):
    service = LogisticsInvoicesService(db_session)

    policy = service.create_insurance_policy(
        InsurancePolicyCreate(
            shipment_id=1,
            bl_number="MSCU98765432",
            insurance_company_id=3,
            insurance_company_name="Misr Insurance Company",
            policy_number="POL-CLAIM-TEST-01",
            coverage_type="all_risks",
            insured_value_fx=55000.0,
            premium_rate=0.35,
            premium_amount_fx=192.5,
            premium_amount_egp=9336.25,
            stamp_duty_egp=9.34,
            supervisory_fee_egp=1120.35,
            net_premium_egp=10465.94,
        )
    )
    assert policy.status == "issued"

    # Step 1: File claim
    policy = service.record_insurance_claim(
        policy.policy_id,
        InsurancePolicyClaimCreate(
            claim_reference="CLM-2026-001",
            claim_amount_egp=25000.0,
            claim_status="filed",
            notes="Cargo water damage detected at Alexandria port",
        ),
    )
    assert policy.claim_status == "filed"
    assert policy.claim_amount_egp == 25000.0

    # Step 2: Under inspection
    policy = service.update_claim_status(
        policy.policy_id,
        InsurancePolicyClaimStatusUpdate(
            claim_status="under_inspection",
            notes="Insurance surveyor inspected goods",
        ),
    )
    assert policy.claim_status == "under_inspection"

    # Step 3: Accepted
    policy = service.update_claim_status(
        policy.policy_id,
        InsurancePolicyClaimStatusUpdate(
            claim_status="accepted",
            claim_amount_egp=24000.0,
            notes="Claim approved with slight adjustment",
        ),
    )
    assert policy.claim_status == "accepted"
    assert policy.claim_amount_egp == 24000.0

    # Step 4: Reimbursed -> sets status to CLAIMED
    policy = service.update_claim_status(
        policy.policy_id,
        InsurancePolicyClaimStatusUpdate(
            claim_status="reimbursed",
            notes="Bank transfer received from insurer",
        ),
    )
    assert policy.claim_status == "reimbursed"
    assert policy.status == "claimed"

    # Invalid status should raise 400
    with pytest.raises(HTTPException) as exc:
        service.update_claim_status(
            policy.policy_id,
            InsurancePolicyClaimStatusUpdate(claim_status="invalid_claim_state"),
        )
    assert exc.value.status_code == 400



def test_logistics_invoices_api_endpoints(db_session):
    from fastapi.testclient import TestClient
    from main import app
    from database.database import get_db
    from modules.auth.router import get_current_user
    from modules.users.model import User

    def override_get_db():
        yield db_session

    admin_user = User(
        user_id=1,
        username="admin_tester",
        email="admin@test.com",
        hashed_password="mock_hashed_password",
        full_name="Admin Tester",
        role="ADMIN",
        is_active=True,
    )

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    client = TestClient(app)

    try:
        # 1. Test GET /prefill-lines
        res = client.get("/api/v1/logistics-invoices/prefill-lines?shipment_id=1&partner_type=freight")
        assert res.status_code == 200
        assert len(res.json()["lines"]) == 21

        # 2. Test GET /container-lock-status
        res = client.get("/api/v1/logistics-invoices/container-lock-status?shipment_id=1&bl_number=MSCU98765432")
        assert res.status_code == 200

        # 3. Test GET /insurance/preview
        res = client.get("/api/v1/logistics-invoices/insurance/preview?shipment_id=1&premium_rate=0.35")
        assert res.status_code == 200
        assert res.json()["insured_value_fx"] == 55000.0

        # 4. Test POST /insurance/policies
        res = client.post(
            "/api/v1/logistics-invoices/insurance/policies",
            json={
                "shipment_id": 1,
                "bl_number": "MSCU98765432",
                "insurance_company_id": 3,
                "insurance_company_name": "Misr Insurance Company",
                "policy_number": "POL-API-9900",
                "coverage_type": "all_risks",
                "insured_value_fx": 55000.0,
                "premium_rate": 0.35,
                "premium_amount_fx": 192.5,
                "premium_amount_egp": 9336.25,
                "stamp_duty_egp": 9.34,
                "supervisory_fee_egp": 1120.35,
                "net_premium_egp": 10465.94,
            },
        )
        assert res.status_code == 201
        pol_id = res.json()["policy_id"]

        # 5. Test POST /insurance/policies/{id}/generate-invoice
        res = client.post(f"/api/v1/logistics-invoices/insurance/policies/{pol_id}/generate-invoice")
        assert res.status_code == 200
        assert res.json()["partner_type"] == "insurance"

        # 6. Test GET /partners/{id}/balance-card
        res = client.get("/api/v1/logistics-invoices/partners/3/balance-card")
        assert res.status_code == 200
        assert res.json()["partner_id"] == 3

        # 7. Test POST /advances
        res = client.post(
            "/api/v1/logistics-invoices/advances",
            json={
                "shipment_id": 1,
                "bl_number": "MSCU98765432",
                "clearance_partner_id": 2,
                "clearance_partner_name": "Al-Ahram Clearance Agency",
                "amount": 15000.0,
                "currency": "EGP",
                "exchange_rate": 1.0,
                "amount_egp": 15000.0,
            },
        )
        assert res.status_code == 201
        assert res.json()["remaining_amount_egp"] == 15000.0

        # 8. Test GET /partners/{id}/ledger
        res = client.get("/api/v1/logistics-invoices/partners/3/ledger")
        assert res.status_code == 200
        assert res.json()["partner_id"] == 3
        assert "entries" in res.json()

        # 9. Test GET /reports/wht-form41
        res = client.get(f"/api/v1/logistics-invoices/reports/wht-form41?year={date.today().year}")
        assert res.status_code == 200
        assert "records" in res.json()
        assert res.json()["year"] == date.today().year

        # 10. Test PATCH /insurance/policies/{id}/claim-status
        res = client.patch(
            f"/api/v1/logistics-invoices/insurance/policies/{pol_id}/claim-status",
            json={"claim_status": "under_inspection", "notes": "Survey in progress"},
        )
        assert res.status_code == 200
        assert res.json()["claim_status"] == "under_inspection"

        # 11. List endpoints next to GET /{id} reach their own handlers (were 422: "advances" is not an int)
        res = client.get("/api/v1/logistics-invoices/advances")
        assert res.status_code == 200
        assert isinstance(res.json(), list)
        res = client.get("/api/v1/logistics-invoices/payments")
        assert res.status_code == 200
        assert isinstance(res.json(), list)
        res = client.get("/api/v1/logistics-invoices/999999")
        assert res.status_code == 404
    finally:
        app.dependency_overrides.pop(get_db, None)
        app.dependency_overrides.pop(get_current_user, None)


def test_open_invoices_excludes_fully_paid(db_session):
    """
    Verifies that get_open_invoices_by_partner returns unpaid/partially paid invoices,
    and immediately excludes invoices once they are fully knocked off / paid.
    """
    service = LogisticsInvoicesService(db_session)

    # 1. Create two invoices for partner 1
    i1 = service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC",
            invoice_number="INV-OPEN-001",
            currency="USD",
            exchange_rate=48.5,
            total_amount_fx=1000.0,
            total_amount_egp=48500.0,
            net_payable_egp=48500.0,
        )
    )
    i2 = service.create_invoice(
        LogisticsInvoiceCreate(
            shipment_id=1,
            partner_id=1,
            partner_type="freight",
            partner_name="MSC",
            invoice_number="INV-OPEN-002",
            currency="EGP",
            exchange_rate=1.0,
            total_amount_fx=20000.0,
            total_amount_egp=20000.0,
            net_payable_egp=20000.0,
        )
    )

    # 2. Both newly created DRAFT invoices must be returned in open invoices
    open_invs = service.repo.get_open_invoices_by_partner(1)
    open_ids = [inv.invoice_id for inv in open_invs]
    assert i1.invoice_id in open_ids
    assert i2.invoice_id in open_ids

    # 3. Pay i1 fully (48,500 EGP) and i2 partially (5,000 EGP)
    voucher_payload = LogisticsPaymentVoucherCreate(
        shipment_id=1,
        partner_id=1,
        partner_name="MSC",
        amount=53500.0,
        currency="EGP",
        exchange_rate=1.0,
        amount_egp=53500.0,
        payment_method="BANK_TRANSFER",
        knockoffs=[
            InvoiceKnockoffItem(invoice_id=i1.invoice_id, knocked_amount_egp=48500.0),
            InvoiceKnockoffItem(invoice_id=i2.invoice_id, knocked_amount_egp=5000.0),
        ],
    )
    service.create_payment_voucher(voucher_payload, user_name="Accountant")

    # 4. Check open invoices again: i1 must NOT appear anymore, i2 must appear with remaining 15,000 EGP
    open_invs_after = service.repo.get_open_invoices_by_partner(1)
    open_ids_after = [inv.invoice_id for inv in open_invs_after]
    assert i1.invoice_id not in open_ids_after
    assert i2.invoice_id in open_ids_after

    i2_refreshed = next(inv for inv in open_invs_after if inv.invoice_id == i2.invoice_id)
    assert i2_refreshed.payment_status == "PARTIALLY_PAID"
    assert i2_refreshed.remaining_amount_egp == 15000.0
