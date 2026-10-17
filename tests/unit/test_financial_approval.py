"""
Unit Tests for Phase 2 Financial & Management Approval Module (BP-012 & BP-013)
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_tariff.model import CustomsTariff
from modules.purchase_orders.model import PurchaseOrder
from modules.import_files.model import ImportFile
from modules.shipping_scenarios.model import ShippingEvaluationSession
from modules.customs_consultation.model import CustomsConsultationSession
from modules.financial_approval.model import PaymentRequestSession, ImportBudgetApproval
from modules.financial_approval.schemas import (
    PaymentRequestCreate,
    ClonePaymentRequestRequest,
    PaymentRequestUpdate,
    ImportBudgetCreate,
    CloneImportBudgetRequest,
    ImportBudgetUpdate,
)
import modules.financial_approval.service as service
import modules.financial_approval.repository as repo
from fastapi import HTTPException
from modules.users.model import User


def _admin():
    return User(user_id=1, username="finance_director", email="cfo@example.com", role="ADMIN", is_active=True)


@pytest.fixture
def db_session():
    """Creates in-memory SQLite DB fixture."""
    engine = create_engine(
        "sqlite:///:memory:",
        echo=False,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    # Phase 2 quality (FA-04): there is no 50.0 fallback rate any more, so the prefill needs a recorded USD rate.
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$")
    db.add(usd)
    db.commit()
    db.add(ExchangeRate(currency_id=usd.currency_id, commercial_rate=50.0, customs_rate=50.0,
                        effective_date=date(2020, 1, 1), is_active=True))
    db.commit()
    try:
        yield db
    finally:
        db.close()


class TestFinancialApprovalBackend:
    def test_create_payment_request_service(self, db_session):
        payload = PaymentRequestCreate(
            title="Advance Payment for Equipment",
            supplier_name="Shanghai Industrial Co.",
            payment_type="Advance Payment",
            requested_amount=15000.0,
            currency_code="USD",
            exchange_rate=50.0,
            due_date=date(2026, 9, 1),
            bank_name="Bank of China",
            swift_code="BKCHCN2S",
            iban_account_no="CN123456789",
        )
        item = service.create_payment_request_service(db_session, payload)

        assert item.payment_id is not None
        assert item.payment_code.startswith("PAY-2026-")
        assert item.requested_amount == 15000.0
        assert item.requested_amount_egp == 750000.0
        assert item.status == "Draft"

    def test_negative_requested_amount_raises_error(self, db_session):
        from pydantic import ValidationError

        with pytest.raises((ValidationError, HTTPException)):
            PaymentRequestCreate(
                title="Invalid Payment Amount",
                supplier_name="Test Supplier",
                requested_amount=-500.0,
                due_date=date(2026, 9, 1),
                exchange_rate=50.0,
            )

    def test_approve_and_pay_payment_request(self, db_session):
        payload = PaymentRequestCreate(
            title="Final Settlement",
            supplier_name="Germany Heavy Duty Machinery GMBH",
            payment_type="Final Settlement",
            requested_amount=10000.0,
            currency_code="USD",
            due_date=date(2026, 9, 15),
            exchange_rate=50.0,
        )
        created = service.create_payment_request_service(db_session, payload)

        # Approve
        approved = service.approve_payment_request_service(db_session, created.payment_id)
        assert approved.status == "Approved"

        # Pay with SWIFT copy
        paid = service.execute_payment_service(
            db_session, created.payment_id, swift_reference_no="SWIFT-998877"
        )
        assert paid.status == "Paid"
        assert paid.swift_reference_no == "SWIFT-998877"

    def test_create_and_approve_import_budget(self, db_session):
        payload = ImportBudgetCreate(
            title="Total Import Budget for Textile Machines Project",
            invoice_amount_egp=3000000.0,
            freight_cost_egp=200000.0,
            customs_duties_egp=800000.0,
            clearance_inland_egp=50000.0,
            exchange_rate=50.0,
        )
        budget = service.create_import_budget_service(db_session, payload)

        assert budget.budget_id is not None
        assert budget.budget_code.startswith("BGT-2026-")
        assert budget.total_budget_egp == 4050000.0
        assert budget.budget_status == "Pending Review"

        approved_budget = service.approve_import_budget_service(
            db_session, budget.budget_id, approved_by="CFO"
        )
        assert approved_budget.budget_status == "Budget Approved"
        assert approved_budget.approved_by == "CFO"
        assert approved_budget.approved_date == date.today()

    def test_soft_delete_and_restore_payment_request(self, db_session):
        payload = PaymentRequestCreate(
            title="Draft Payment to be deleted",
            supplier_name="Test Supplier",
            requested_amount=1000.0,
            currency_code="USD",
            due_date=date(2026, 9, 1),
            exchange_rate=50.0,
        )
        created = service.create_payment_request_service(db_session, payload)
        payment_id = created.payment_id

        # Delete
        success = service.soft_delete_payment_request_service(db_session, payment_id)
        assert success is True
        assert repo.get_payment_request_by_id(db_session, payment_id) is None

        # Restore
        restore_success = service.restore_payment_request_service(db_session, payment_id)
        assert restore_success is True
        restored = repo.get_payment_request_by_id(db_session, payment_id)
        assert restored is not None
        assert restored.is_active is True

    def test_duplicate_payment_request_prevention(self, db_session):
        from modules.import_companies.model import ImportCompany
        from modules.suppliers.model import Supplier
        from modules.import_files.model import ImportFile

        comp = ImportCompany(
            importer_name="Egyptian Import Co",
            address="Cairo, Egypt",
            country="Egypt",
            importer_id="IMP-ID-001",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="VAT-001",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="CR-001",
            registration_expiry=date(2030, 1, 1),
        )
        db_session.add(comp)
        db_session.commit()
        db_session.refresh(comp)

        sup = Supplier(
            supplier_code="SUP-TEST-001",
            company_name="Shanghai Super Machinery Ltd",
            supplier_type="Manufacturer",
            registration_type="Factory",
            foreign_exporter_id="EXP-CN-001",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
        )
        db_session.add(sup)
        db_session.commit()
        db_session.refresh(sup)

        imp = ImportFile(
            import_file_code="IMP-2026-099",
            custom_file_number="FILE-099",
            company_id=comp.company_id,
            company_name=comp.importer_name,
            supplier_id=sup.supplier_id,
            supplier_name=sup.company_name,
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        payload1 = PaymentRequestCreate(
            title="First Payment Request",
            import_file_id=imp.import_file_id,
            supplier_name="Shanghai Super Machinery Ltd",
            requested_amount=5000.0,
            currency_code="USD",
            due_date=date(2026, 9, 1),
            exchange_rate=50.0,
        )
        service.create_payment_request_service(db_session, payload1)

        payload2 = PaymentRequestCreate(
            title="Duplicate Payment Request",
            import_file_id=imp.import_file_id,
            supplier_name="Shanghai Super Machinery Ltd",
            requested_amount=7000.0,
            currency_code="USD",
            due_date=date(2026, 9, 1),
            exchange_rate=50.0,
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_payment_request_service(db_session, payload2)
        assert exc_info.value.status_code == 400
        assert exc_info.value.detail["code"] == "FA_PAYMENT_DUPLICATE_TYPE"
        assert "يوجد بالفعل طلب سداد مالي قيد الإجراء" in exc_info.value.detail["message"]

    def test_duplicate_budget_approval_prevention(self, db_session):
        from modules.import_companies.model import ImportCompany
        from modules.import_files.model import ImportFile

        comp = ImportCompany(
            importer_name="Nile Trading Co",
            address="Alexandria, Egypt",
            country="Egypt",
            importer_id="IMP-ID-002",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="VAT-002",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="CR-002",
            registration_expiry=date(2030, 1, 1),
        )
        db_session.add(comp)
        db_session.commit()
        db_session.refresh(comp)

        imp = ImportFile(
            import_file_code="IMP-2026-088",
            custom_file_number="FILE-088",
            company_id=comp.company_id,
            company_name=comp.importer_name,
            supplier_name="Generic Supplier",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        bgt1 = ImportBudgetCreate(
            title="First Budget Approval",
            import_file_id=imp.import_file_id,
            invoice_amount_egp=100000.0,
            exchange_rate=50.0,
        )
        service.create_import_budget_service(db_session, bgt1)

        bgt2 = ImportBudgetCreate(
            title="Duplicate Budget Approval",
            import_file_id=imp.import_file_id,
            invoice_amount_egp=200000.0,
            exchange_rate=50.0,
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_import_budget_service(db_session, bgt2)
        assert exc_info.value.status_code == 400
        assert exc_info.value.detail["code"] == "FA_BUDGET_DUPLICATE_FILE"
        assert "يوجد بالفعل اعتماد ميزانية محفوظ" in exc_info.value.detail["message"]

    def test_budget_prefill_service_aggregation(self, db_session):
        from modules.import_companies.model import ImportCompany
        from modules.import_files.model import ImportFile
        from modules.purchase_orders.model import PurchaseOrder
        from modules.suppliers.model import Supplier

        comp = ImportCompany(
            importer_name="General Agencies Co",
            address="Giza, Egypt",
            country="Egypt",
            importer_id="IMP-ID-003",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="VAT-003",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="CR-003",
            registration_expiry=date(2030, 1, 1),
        )
        db_session.add(comp)
        db_session.commit()
        db_session.refresh(comp)

        sup = Supplier(
            supplier_code="SUP-TEST-003",
            company_name="Shanghai Super Machinery Ltd",
            supplier_type="Manufacturer",
            registration_type="Factory",
            foreign_exporter_id="EXP-CN-003",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
            bank_name="Industrial and Commercial Bank of China",
            swift_code="ICBKCNBJ",
            account_number="6222000011112222",
            iban="CN99ICBK6222000011112222",
        )
        db_session.add(sup)
        db_session.commit()
        db_session.refresh(sup)

        imp = ImportFile(
            import_file_code="IMP-2026-777",
            custom_file_number="FILE-777",
            incoterm_code="FOB",
            supplier_id=sup.supplier_id,
            supplier_name=sup.company_name,
            company_id=comp.company_id,
            company_name=comp.importer_name,
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        inc = Incoterm(incoterm_code="FOB", incoterm_name="Free on Board")
        db_session.add(inc)
        db_session.commit()
        db_session.refresh(inc)
        curr = db_session.query(Currency).filter_by(currency_code="USD").one()

        prj = Project(
            project_code="PRJ-001",
            project_name="Factory Project",
            project_owner="Project Manager",
            company_id=comp.company_id,
            supplier_id=sup.supplier_id,
            incoterm_id=inc.incoterm_id,
        )
        db_session.add(prj)
        db_session.commit()
        db_session.refresh(prj)

        po1 = PurchaseOrder(
            po_number="PO-2026-777-1",
            import_file_id=imp.import_file_id,
            company_id=comp.company_id,
            supplier_id=sup.supplier_id,
            project_id=prj.project_id,
            incoterm_id=inc.incoterm_id,
            currency_id=curr.currency_id,
            payment_terms="Advance 30%",
            total_amount_fob=20000.0,
        )
        po2 = PurchaseOrder(
            po_number="PO-2026-777-2",
            import_file_id=imp.import_file_id,
            company_id=comp.company_id,
            supplier_id=sup.supplier_id,
            project_id=prj.project_id,
            incoterm_id=inc.incoterm_id,
            currency_id=curr.currency_id,
            payment_terms="CAD 70%",
            total_amount_fob=30000.0,
        )
        db_session.add_all([po1, po2])
        db_session.commit()

        prefill = service.get_budget_prefill_service(db_session, imp.import_file_id)

        assert prefill.import_file_id == imp.import_file_id
        assert prefill.total_invoice_amount == 50000.0
        assert prefill.total_invoice_amount_egp == 2500000.0
        assert prefill.bank_name == "Industrial and Commercial Bank of China"
        assert prefill.swift_code == "ICBKCNBJ"
        assert prefill.payment_terms_summary.startswith("Multiple (")  # C2: English, never Arabic text
        assert len(prefill.linked_pos) == 2

    def test_swift_reconciliation_matched_and_syncs_import_file(self, db_session):
        from modules.import_companies.model import ImportCompany
        from modules.import_files.model import ImportFile
        from modules.suppliers.model import Supplier
        from modules.financial_approval.schemas import SwiftReconciliationRequest

        comp = ImportCompany(
            importer_name="Swift Test Importer",
            address="Cairo, Egypt",
            country="Egypt",
            importer_id="IMP-SWIFT-01",
            importer_id_expiry=date(2030, 1, 1),
            vat_id="VAT-SWIFT-01",
            vat_id_expiry=date(2030, 1, 1),
            registration_number="CR-SWIFT-01",
            registration_expiry=date(2030, 1, 1),
        )
        sup = Supplier(
            supplier_code="SUP-SWIFT-01",
            company_name="Global Steel Exporter",
            supplier_type="Exporter",
            registration_type="Factory",
            foreign_exporter_id="EXP-GS-01",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
            address="Hamburg, Germany",
        )
        db_session.add_all([comp, sup])
        db_session.commit()
        db_session.refresh(comp)
        db_session.refresh(sup)

        imp = ImportFile(
            import_file_code="IMP-2026-SWIFT-01",
            custom_file_number="FILE-SWIFT-01",
            company_id=comp.company_id,
            company_name=comp.importer_name,
            supplier_id=sup.supplier_id,
            supplier_name=sup.company_name,
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        pay = PaymentRequestCreate(
            title="Advance 30% Payment for Steel",
            import_file_id=imp.import_file_id,
            supplier_name="Global Steel Exporter",
            requested_amount=15000.0,
            currency_code="USD",
            due_date=date(2026, 8, 20),
            request_date=date(2026, 8, 10),
            exchange_rate=50.0,
        )
        created_pay = service.create_payment_request_service(db_session, pay)
        # Phase 2 quality (FA-02): a SWIFT reconciles an Approved request only, so approve it first.
        service.approve_payment_request_service(db_session, created_pay.payment_id)

        # Reconcile SWIFT received on 2026-08-14 (4 days later), exactly 15000.0 USD
        swift_payload = SwiftReconciliationRequest(
            swift_reference_no="SWIFT-MT103-99887766",
            swift_receipt_date=date(2026, 8, 14),
            swift_transferred_amount=15000.0,
            swift_transferred_currency="USD",
            swift_reconciliation_notes="Full payment executed seamlessly by NBE Bank",
        )
        reconciled = service.reconcile_swift_service(db_session, created_pay.payment_id, swift_payload)

        assert reconciled.status == "Paid"
        assert reconciled.swift_reference_no == "SWIFT-MT103-99887766"
        assert reconciled.swift_processing_days == 4
        assert reconciled.swift_variance_amount == 0.0
        assert reconciled.swift_variance_status == "Matched"

        # Verify automatic update of import_files.swift_no
        db_session.refresh(imp)
        assert imp.swift_no == "SWIFT-MT103-99887766"

    def test_swift_reconciliation_deficit_and_surplus(self, db_session):
        from modules.financial_approval.schemas import SwiftReconciliationRequest

        pay = PaymentRequestCreate(
            title="Final Payment Test",
            supplier_name="Tech Parts Co",
            requested_amount=10000.0,
            currency_code="USD",
            due_date=date(2026, 8, 25),
            request_date=date(2026, 8, 10),
            exchange_rate=50.0,
        )
        created_pay = service.create_payment_request_service(db_session, pay)
        service.approve_payment_request_service(db_session, created_pay.payment_id)  # FA-02: Approved only

        # Deficit test (e.g. 9950 USD due to bank fee deduction)
        swift_deficit = SwiftReconciliationRequest(
            swift_reference_no="SWIFT-DEFICIT-01",
            swift_receipt_date=date(2026, 8, 12),
            swift_transferred_amount=9950.0,
            swift_transferred_currency="USD",
            swift_reconciliation_notes="50 USD intermediary bank fee deducted",
        )
        res_deficit = service.reconcile_swift_service(db_session, created_pay.payment_id, swift_deficit)
        assert res_deficit.swift_variance_amount == -50.0
        assert res_deficit.swift_variance_status == "Deficit"
        assert res_deficit.swift_processing_days == 2

    def test_multi_payment_requests_for_same_file_different_types(self, db_session):
        from modules.import_files.model import ImportFile

        imp = ImportFile(
            import_file_code="IMP-2026-MULTI-01",
            custom_file_number="FILE-MULTI-01",
            company_name="Test Company",
            supplier_name="Global Supplier A",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        # 1. Advance Payment
        pay1 = PaymentRequestCreate(
            title="30% Advance Payment",
            import_file_id=imp.import_file_id,
            supplier_name="Global Supplier A",
            payment_type="Advance Payment",
            requested_amount=3000.0,
            currency_code="USD",
            due_date=date(2026, 9, 1),
            exchange_rate=50.0,
        )
        created1 = service.create_payment_request_service(db_session, pay1)
        assert created1.payment_id is not None

        # 2. Final Settlement for same file should succeed because it's a different payment_type
        pay2 = PaymentRequestCreate(
            title="70% Final Settlement Against B/L",
            import_file_id=imp.import_file_id,
            supplier_name="Global Supplier A",
            payment_type="Against B/L",
            requested_amount=7000.0,
            currency_code="USD",
            due_date=date(2026, 10, 1),
            exchange_rate=50.0,
        )
        created2 = service.create_payment_request_service(db_session, pay2)
        assert created2.payment_id is not None
        assert created2.payment_id != created1.payment_id

    def test_payment_status_transition_validation(self, db_session):
        """Phase 2 quality (FA-02): PUT only moves Draft <-> Pending Approval, to Rejected, Rejected -> Draft.
        Approved and Paid are reached through /approve and /pay; an Approved or Paid request is locked (409)."""
        pay = PaymentRequestCreate(
            title="Status Transition Test",
            supplier_name="Transition Supplier",
            requested_amount=1000.0,
            currency_code="USD",
            exchange_rate=50.0,
            due_date=date(2026, 9, 1),
        )
        created = service.create_payment_request_service(db_session, pay)
        assert created.status == "Draft"

        # Valid: Draft -> Pending Approval
        service.update_payment_request_service(db_session, created.payment_id, PaymentRequestUpdate(status="Pending Approval"))
        db_session.refresh(created)
        assert created.status == "Pending Approval"

        # Invalid through PUT: Pending Approval -> Approved
        with pytest.raises(HTTPException) as exc_info:
            service.update_payment_request_service(db_session, created.payment_id, PaymentRequestUpdate(status="Approved"))
        assert exc_info.value.status_code == 400
        assert exc_info.value.detail["code"] == "FA_PAYMENT_STATUS_INVALID"

        service.approve_payment_request_service(db_session, created.payment_id)
        db_session.refresh(created)
        assert created.status == "Approved"

        # Approved is locked for PUT (except a move to Rejected)
        with pytest.raises(HTTPException) as exc_info:
            service.update_payment_request_service(db_session, created.payment_id, PaymentRequestUpdate(status="Paid"))
        assert exc_info.value.status_code == 409
        assert exc_info.value.detail["code"] == "FA_PAYMENT_LOCKED"

        service.execute_payment_service(db_session, created.payment_id, swift_reference_no="SWIFT-TRANSITION")
        db_session.refresh(created)
        assert created.status == "Paid"

        # Paid is terminal
        with pytest.raises(HTTPException) as exc_info:
            service.update_payment_request_service(db_session, created.payment_id, PaymentRequestUpdate(status="Draft"))
        assert exc_info.value.status_code == 409

    def test_smart_reconcile_swift_service_matched_status(self, db_session):
        from modules.financial_approval.schemas import SmartSwiftReconcileRequest

        pay = PaymentRequestCreate(
            title="Smart Reconcile Test",
            supplier_name="Smart Beneficiary Co",
            requested_amount=5000.0,
            currency_code="USD",
            due_date=date(2026, 9, 10),
            request_date=date(2026, 9, 1),
            exchange_rate=50.0,
        )
        created = service.create_payment_request_service(db_session, pay)
        service.approve_payment_request_service(db_session, created.payment_id)  # FA-02: Approved only

        smart_req = SmartSwiftReconcileRequest(
            payment_id=created.payment_id,
            swift_reference_no="SMART-SWIFT-12345",
            swift_receipt_date=date(2026, 9, 5),
            swift_transferred_amount=5000.0,
            swift_transferred_currency="USD",
            bank_name="Test Partner Bank",
            swift_code="TPBKUS33",
            iban_account_no="US1234567890",
            auto_execute=True,
        )
        reconciled = service.smart_reconcile_swift_service(db_session, smart_req)

        assert reconciled.status == "Paid"
        assert reconciled.swift_variance_amount == 0.0
        assert reconciled.swift_variance_status == "Matched"
        assert reconciled.swift_processing_days == 4
        assert reconciled.bank_name == "Test Partner Bank"
        assert reconciled.swift_code == "TPBKUS33"

    def test_import_budget_update_and_soft_delete_restore(self, db_session):
        payload = ImportBudgetCreate(
            title="Initial Budget",
            invoice_amount_egp=1000000.0,
            freight_cost_egp=100000.0,
            customs_duties_egp=200000.0,
            clearance_inland_egp=50000.0,
            exchange_rate=50.0,
        )
        budget = service.create_import_budget_service(db_session, payload)
        assert budget.total_budget_egp == 1350000.0

        # Update budget
        up_payload = ImportBudgetUpdate(
            title="Updated Budget Title",
            freight_cost_egp=150000.0,
        )
        updated = service.update_import_budget_service(db_session, budget.budget_id, up_payload)
        assert updated.title == "Updated Budget Title"
        assert updated.freight_cost_egp == 150000.0
        assert updated.total_budget_egp == 1400000.0

        # Soft Delete
        del_success = service.soft_delete_import_budget_service(db_session, budget.budget_id)
        assert del_success is True
        with pytest.raises(HTTPException) as gone:  # the get service raises the 404 itself now
            service.get_import_budget_by_id_service(db_session, budget.budget_id)
        assert gone.value.status_code == 404

        # Restore
        res_success = service.restore_import_budget_service(db_session, budget.budget_id)
        assert res_success is True
        restored = service.get_import_budget_by_id_service(db_session, budget.budget_id)
        assert restored is not None
        assert restored.is_active is True

    def test_clone_payment_request(self, db_session):
        """Tests cloning a payment request with mandatory invariant resets."""
        # 1. Create an executed payment request
        payload = PaymentRequestCreate(
            title="Original Advance Payment for Machinery",
            supplier_name="Shanghai Super Machinery Ltd",
            payment_type="Advance Payment",
            requested_amount=15000.0,
            currency_code="USD",
            exchange_rate=50.0,
            due_date=date(2026, 9, 30),
            bank_name="Bank of China",
            swift_code="BKCHCNBJ",
            iban_account_no="CN9988776655",
            bank_country="China",
            notes="Original critical payment",
        )
        orig = service.create_payment_request_service(db_session, payload)
        # Approve and execute it (FA-02: /pay is allowed from Approved only)
        service.approve_payment_request_service(db_session, orig.payment_id)
        service.execute_payment_service(db_session, orig.payment_id, swift_reference_no="SWIFT-998877")
        assert orig.status == "Paid"
        assert orig.swift_reference_no == "SWIFT-998877"

        # 2. Clone it
        clone_req = ClonePaymentRequestRequest(
            new_title="Cloned Advance Payment - Second Batch",
            new_requested_amount=12000.0,
            unlink_import_file=True,
            remarks="Cloned for batch 2",
        )
        cloned = service.clone_payment_request_service(db_session, orig.payment_id, clone_req)

        # 3. Verify invariants
        assert cloned.payment_id != orig.payment_id
        assert cloned.payment_code != orig.payment_code
        assert cloned.title == "Cloned Advance Payment - Second Batch"
        default_clone = service.clone_payment_request_service(db_session, orig.payment_id, ClonePaymentRequestRequest())
        assert default_clone.title == "Original Advance Payment for Machinery (Copy)"
        assert cloned.status == "Draft"  # Invariant: Status MUST reset to Draft
        assert cloned.swift_reference_no is None  # Invariant: SWIFT reference MUST be cleared
        assert cloned.swift_receipt_date is None
        assert cloned.swift_transferred_amount is None
        assert cloned.import_file_id is None  # Invariant: unlinked as requested
        assert cloned.requested_amount == 12000.0
        assert cloned.currency_code == "USD"
        assert cloned.exchange_rate == 50.0
        assert cloned.requested_amount_egp == 600000.0
        assert cloned.bank_name == "Bank of China"
        assert cloned.swift_code == "BKCHCNBJ"
        assert cloned.iban_account_no == "CN9988776655"
        assert cloned.bank_country == "China"
        assert "Cloned for batch 2" in (cloned.notes or "")
        assert cloned.is_active is True

    def test_clone_import_budget(self, db_session):
        """Tests cloning an import budget with mandatory invariant resets."""
        # 1. Create and approve an import budget
        payload = ImportBudgetCreate(
            title="Original Machinery Import Budget 2026",
            invoice_amount_foreign=20000.0,
            invoice_currency="USD",
            invoice_amount_egp=1000000.0,
            freight_cost_foreign=3000.0,
            freight_currency="USD",
            freight_cost_egp=150000.0,
            customs_duties_egp=200000.0,
            clearance_inland_egp=40000.0,
            exchange_rate=50.0,
            notes="Original high-priority budget",
        )
        orig = service.create_import_budget_service(db_session, payload)
        approved = service.approve_import_budget_service(db_session, orig.budget_id, approved_by="CFO Ahmed")
        assert approved.budget_status == "Budget Approved"
        assert approved.approved_by == "CFO Ahmed"
        assert approved.approved_date is not None

        # 2. Clone it with new rate and title
        clone_req = CloneImportBudgetRequest(
            new_title="Cloned Machinery Budget - 2027 Expansion",
            new_exchange_rate=52.0,
            unlink_import_file=True,
            remarks="Cloned for expansion review",
        )
        cloned = service.clone_import_budget_service(db_session, orig.budget_id, clone_req)

        # 3. Verify invariants
        assert cloned.budget_id != orig.budget_id
        assert cloned.budget_code != orig.budget_code
        assert cloned.title == "Cloned Machinery Budget - 2027 Expansion"
        default_clone = service.clone_import_budget_service(db_session, orig.budget_id, CloneImportBudgetRequest())
        assert default_clone.title == "Original Machinery Import Budget 2026 (Copy)"
        assert cloned.budget_status == "Pending Review"  # Invariant: Status MUST reset to Pending Review / Draft
        assert cloned.approved_by is None  # Invariant: Approval signatures MUST be cleared
        assert cloned.approved_date is None
        assert cloned.import_file_id is None  # Invariant: Unlinked from original file
        assert cloned.exchange_rate == 52.0
        # Recalculated amounts: 20000 * 52 = 1,040,000, 3000 * 52 = 156,000
        assert cloned.invoice_amount_foreign == 20000.0
        assert cloned.invoice_amount_egp == 1040000.0
        assert cloned.freight_cost_foreign == 3000.0
        assert cloned.freight_cost_egp == 156000.0
        assert cloned.customs_duties_egp == 200000.0
        assert cloned.clearance_inland_egp == 40000.0
        # Total = 1040000 + 156000 + 200000 + 40000 = 1436000.0
        assert cloned.total_budget_egp == 1436000.0
        assert "Cloned for expansion review" in (cloned.notes or "")
        assert cloned.is_active is True

    def test_budget_prefill_includes_broker_details(self, db_session):
        from modules.import_files.model import ImportFile
        from modules.customs_consultation.model import CustomsConsultationSession
        from modules.financial_approval.service import get_budget_prefill_service

        imp = ImportFile(
            import_file_code="IMP-2026-BRK-01",
            custom_file_number="FILE-BRK-01",
            company_name="Test Importer Co",
            supplier_name="Broker Test Supplier",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        # Create customs consultation session with broker info
        session = CustomsConsultationSession(
            consultation_code="CS-2026-BRK-01",
            title="Customs Clearance Study for IMP-BRK-01",
            broker_id=12,
            broker_name="Nabil Naseef .ACC",
            import_file_id=imp.import_file_id,
            estimated_duties_egp=350000.0,
            total_broker_fees_egp=50800.0,
            overall_status="Clearance Ready",
        )
        db_session.add(session)
        db_session.commit()

        prefill = get_budget_prefill_service(db_session, imp.import_file_id)
        assert prefill.estimated_clearance_fees_egp == 50800.0
        assert prefill.broker_id == 12
        assert prefill.broker_name == "Nabil Naseef .ACC"

    def test_sync_budget_with_upstream_service(self, db_session):
        from modules.import_files.model import ImportFile
        from modules.customs_consultation.model import CustomsConsultationSession
        from modules.financial_approval.model import ImportBudgetApproval
        from modules.financial_approval.service import sync_budget_with_upstream_service
        from fastapi import HTTPException

        imp = ImportFile(
            import_file_code="IMP-2026-SYNC-01",
            custom_file_number="FILE-SYNC-01",
            company_name="Sync Test Importer",
            supplier_name="Sync Test Supplier",
            estimated_cost=10000.0,
            estimated_cost_currency="USD",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        # 1. Budget created initially with clearance = 0
        budget = ImportBudgetApproval(
            budget_code="BGT-2026-SYNC-01",
            title="Budget for IMP-SYNC-01",
            import_file_id=imp.import_file_id,
            invoice_amount_foreign=10000.0,
            invoice_currency="USD",
            invoice_amount_egp=500000.0,
            freight_cost_foreign=1000.0,
            freight_currency="USD",
            freight_cost_egp=50000.0,
            customs_duties_egp=100000.0,
            clearance_inland_egp=0.0,  # Initially 0
            exchange_rate=50.0,
            total_budget_egp=650000.0,
            budget_status="Budget Approved",
            approved_by="Finance Director",
            approved_date=date.today(),
            is_active=True,
        )
        db_session.add(budget)
        db_session.commit()
        db_session.refresh(budget)

        # 2. Later, customs consultation adds clearance expenses = 50,800 EGP
        session = CustomsConsultationSession(
            consultation_code="CS-2026-SYNC-01",
            title="Customs Clearance Study for IMP-SYNC-01",
            broker_id=5,
            broker_name="Nabil Naseef .ACC",
            import_file_id=imp.import_file_id,
            estimated_duties_egp=100000.0,
            total_broker_fees_egp=50800.0,
            overall_status="Clearance Ready",
        )
        db_session.add(session)
        db_session.commit()

        # 3. Hard Block test: Syncing without justification when variance > 5% raises 400
        try:
            sync_budget_with_upstream_service(db_session, budget.budget_id, current_user=_admin())
            assert False, "Should have raised HTTPException 400 for Hard Block without justification"
        except HTTPException as exc:
            assert exc.status_code == 400
            assert exc.detail["code"] == "FA_BUDGET_HARD_BLOCK"
            assert "Hard Block" in exc.detail["message"]

        # 4. Sync with justification: Creates Revision 2, archives original as Superseded
        result = sync_budget_with_upstream_service(
            db_session,
            budget.budget_id,
            current_user=_admin(),
            override_justification="Authorized broker fees addition by CFO",
        )

        assert result.revision_created is True
        assert result.action_taken == "revision_created"
        assert result.budget.revision_number == 2
        assert result.budget.parent_budget_id == budget.budget_id
        assert result.budget.budget_code == "BGT-2026-SYNC-01-REV2"
        assert result.budget.budget_status == "Pending Review"
        assert result.budget.clearance_inland_egp == 50800.0
        assert result.budget.total_budget_egp == 500000.0 + 100000.0 + 50800.0

        # Verify original budget is now Superseded (strict immutability)
        db_session.refresh(budget)
        assert budget.budget_status == "Superseded"

    def test_segregation_of_duties_enforcement(self, db_session):
        from modules.import_files.model import ImportFile
        from modules.customs_consultation.model import CustomsConsultationSession
        from modules.financial_approval.model import ImportBudgetApproval
        from modules.financial_approval.service import sync_budget_with_upstream_service
        from modules.users.model import User
        from fastapi import HTTPException

        imp = ImportFile(
            import_file_code="IMP-2026-SOD-01",
            custom_file_number="FILE-SOD-01",
            company_name="SoD Test Importer",
            supplier_name="SoD Test Supplier",
            estimated_cost=10000.0,
            estimated_cost_currency="USD",
        )
        db_session.add(imp)
        db_session.commit()

        budget = ImportBudgetApproval(
            budget_code="BGT-2026-SOD-01",
            title="Budget for SoD Test",
            import_file_id=imp.import_file_id,
            invoice_amount_egp=500000.0,
            freight_cost_egp=50000.0,
            customs_duties_egp=100000.0,
            clearance_inland_egp=0.0,
            total_budget_egp=650000.0,
            budget_status="Budget Approved",
            upstream_modified_by="customs_agent_ali",
            is_active=True,
        )
        db_session.add(budget)
        db_session.commit()

        session = CustomsConsultationSession(
            consultation_code="CS-2026-SOD-01",
            title="Customs Study",
            broker_id=1,
            broker_name="Nabil Naseef",
            import_file_id=imp.import_file_id,
            total_broker_fees_egp=20000.0,
            overall_status="Clearance Ready",
        )
        db_session.add(session)
        db_session.commit()

        # User who modified upstream (customs_agent_ali) cannot sync approved budget
        modifier_user = User(
            user_id=101,
            username="customs_agent_ali",
            email="ali@example.com",
            role="USER",
            is_active=True,
        )
        try:
            sync_budget_with_upstream_service(
                db_session,
                budget.budget_id,
                current_user=modifier_user,
                override_justification="Trying to sync my own change",
            )
            assert False, "Should raise 403 Forbidden for Segregation of Duties"
        except HTTPException as exc:
            assert exc.status_code == 403

        # Another authorized user (e.g. Admin or Finance Officer) CAN sync
        admin_user = User(
            user_id=1,
            username="finance_director",
            email="cfo@example.com",
            role="ADMIN",
            is_active=True,
        )
        result = sync_budget_with_upstream_service(
            db_session,
            budget.budget_id,
            current_user=admin_user,
            override_justification="Authorized by CFO",
        )
        assert result.revision_created is True

    def test_status_machine_and_variance_evaluation(self, db_session):
        from modules.import_files.model import ImportFile
        from modules.customs_consultation.model import CustomsConsultationSession
        from modules.financial_approval.model import ImportBudgetApproval
        from modules.financial_approval.service import (
            evaluate_and_record_budget_variance_service,
            override_budget_variance_service,
        )

        imp = ImportFile(
            import_file_code="IMP-2026-STAT-01",
            custom_file_number="FILE-STAT-01",
            company_name="Stat Test Importer",
            supplier_name="Stat Test Supplier",
            estimated_cost=10000.0,
            estimated_cost_currency="USD",
        )
        db_session.add(imp)
        db_session.commit()

        # 1. Test Pending Review budget transitions to Needs Revalidation
        pending_budget = ImportBudgetApproval(
            budget_code="BGT-2026-PENDING-01",
            title="Pending Budget",
            import_file_id=imp.import_file_id,
            invoice_amount_egp=500000.0,
            freight_cost_egp=50000.0,
            customs_duties_egp=100000.0,
            clearance_inland_egp=10000.0,
            total_budget_egp=660000.0,
            budget_status="Pending Review",
            is_active=True,
        )
        db_session.add(pending_budget)
        db_session.commit()

        # Add consultation with different clearance fees (from 10k to 35k)
        session = CustomsConsultationSession(
            consultation_code="CS-2026-STAT-01",
            title="Customs Study",
            broker_id=1,
            broker_name="Nabil Naseef",
            import_file_id=imp.import_file_id,
            total_broker_fees_egp=35000.0,
            overall_status="Clearance Ready",
        )
        db_session.add(session)
        db_session.commit()

        # Trigger event evaluation
        logs = evaluate_and_record_budget_variance_service(
            db_session, imp.import_file_id, modified_by="broker_specialist"
        )
        assert len(logs) > 0

        db_session.refresh(pending_budget)
        assert pending_budget.budget_status == "Needs Revalidation"
        assert pending_budget.has_unresolved_variance is True
        assert pending_budget.upstream_modified_by == "broker_specialist"

        # 2. Test Override Service
        override_budget_variance_service(
            db_session,
            pending_budget.budget_id,
            current_user=_admin(),
            justification_note="Variance accepted after vendor confirmation",
        )
        db_session.refresh(pending_budget)
        assert pending_budget.variance_override_reason == "Variance accepted after vendor confirmation"

    def test_payment_requests_pagination_and_x_total_count(self, db_session):
        """BE02-T08: Test pagination with skip, limit, and X-Total-Count header on payment requests."""
        # 1. Direct repository & service test with 30 items
        for i in range(1, 31):
            service.create_payment_request_service(
                db_session,
                PaymentRequestCreate(
                    title=f"Payment Request {i}",
                    supplier_name="Global Supplier",
                    requested_amount=100.0 * i,
                    currency_code="USD",
                    exchange_rate=50.0,
                    due_date=date(2026, 9, 1),
                ),
            )

        # Direct repo test
        items, total = repo.get_all_payment_requests(db_session, skip=10, limit=5)
        assert total == 30
        assert len(items) == 5
        assert [item.payment_id for item in items] == [20, 19, 18, 17, 16]

        # Direct service test
        s_items, s_total = service.get_all_payment_requests_service(db_session, skip=10, limit=5)
        assert s_total == 30
        assert len(s_items) == 5
        assert [item.payment_id for item in s_items] == [20, 19, 18, 17, 16]

        # Without params: returns all 30
        all_items, all_total = service.get_all_payment_requests_service(db_session)
        assert all_total == 30
        assert len(all_items) == 30

        # 2. REST API endpoint test with TestClient
        from fastapi.testclient import TestClient
        from main import app
        from database.database import get_db
        from modules.auth.seed_rbac import seed_rbac
        from modules.auth.security import create_access_token, hash_password
        from modules.users.model import Role, User

        seed_rbac(db_session)

        def override_get_db():
            try:
                yield db_session
            finally:
                pass

        app.dependency_overrides[get_db] = override_get_db
        try:
            client = TestClient(app, raise_server_exceptions=False)

            role = db_session.query(Role).filter(Role.role_code == "FINANCE_OFFICER").one()
            user = User(
                username="fin_officer_page",
                email="fin_page@test.com",
                full_name="Finance Officer Page",
                hashed_password=hash_password("Password123"),
                role=role.role_code,
                role_id=role.role_id,
                is_active=True,
            )
            db_session.add(user)
            db_session.commit()
            db_session.refresh(user)

            headers = {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}

            # 30 rows with skip=10&limit=5 -> 5 items (ids 20..16) and X-Total-Count: 30
            resp = client.get("/api/v1/financial-approval/payment-requests?skip=10&limit=5", headers=headers)
            assert resp.status_code == 200, resp.text
            assert resp.headers.get("X-Total-Count") == "30"
            data = resp.json()
            assert len(data) == 5
            assert [item["payment_id"] for item in data] == [20, 19, 18, 17, 16]

            # No params -> 30 items and X-Total-Count: 30
            resp_all = client.get("/api/v1/financial-approval/payment-requests", headers=headers)
            assert resp_all.status_code == 200
            assert resp_all.headers.get("X-Total-Count") == "30"
            assert len(resp_all.json()) == 30

            # Boundary checks
            assert client.get("/api/v1/financial-approval/payment-requests?skip=-1", headers=headers).status_code == 422
            assert client.get("/api/v1/financial-approval/payment-requests?limit=0", headers=headers).status_code == 422
            assert client.get("/api/v1/financial-approval/payment-requests?limit=501", headers=headers).status_code == 422
        finally:
            app.dependency_overrides.clear()

    def test_import_budgets_pagination_and_x_total_count(self, db_session):
        """BE02-T08: Test pagination with skip, limit, and X-Total-Count header on import budgets."""
        # 1. Direct repository & service test with 30 items
        for i in range(1, 31):
            service.create_import_budget_service(
                db_session,
                ImportBudgetCreate(
                    title=f"Budget Plan {i}",
                    exchange_rate=50.0,
                    invoice_amount_egp=10000.0 * i,
                ),
            )

        # Direct repo test
        items, total = repo.get_all_import_budgets(db_session, skip=10, limit=5)
        assert total == 30
        assert len(items) == 5
        assert [item.budget_id for item in items] == [20, 19, 18, 17, 16]

        # Direct service test
        s_items, s_total = service.get_all_import_budgets_service(db_session, skip=10, limit=5)
        assert s_total == 30
        assert len(s_items) == 5
        assert [item.budget_id for item in s_items] == [20, 19, 18, 17, 16]

        # Without params: returns all 30
        all_items, all_total = service.get_all_import_budgets_service(db_session)
        assert all_total == 30
        assert len(all_items) == 30

        # 2. REST API endpoint test with TestClient
        from fastapi.testclient import TestClient
        from main import app
        from database.database import get_db
        from modules.auth.seed_rbac import seed_rbac
        from modules.auth.security import create_access_token, hash_password
        from modules.users.model import Role, User

        seed_rbac(db_session)

        def override_get_db():
            try:
                yield db_session
            finally:
                pass

        app.dependency_overrides[get_db] = override_get_db
        try:
            client = TestClient(app, raise_server_exceptions=False)

            role = db_session.query(Role).filter(Role.role_code == "FINANCE_OFFICER").one()
            user = User(
                username="fin_officer_bgt_page",
                email="fin_bgt_page@test.com",
                full_name="Finance Officer Budget Page",
                hashed_password=hash_password("Password123"),
                role=role.role_code,
                role_id=role.role_id,
                is_active=True,
            )
            db_session.add(user)
            db_session.commit()
            db_session.refresh(user)

            headers = {"Authorization": f"Bearer {create_access_token({'sub': str(user.user_id), 'role': user.role})}"}

            # 30 rows with skip=10&limit=5 -> 5 items (ids 20..16) and X-Total-Count: 30
            resp = client.get("/api/v1/financial-approval/import-budgets?skip=10&limit=5", headers=headers)
            assert resp.status_code == 200, resp.text
            assert resp.headers.get("X-Total-Count") == "30"
            data = resp.json()
            assert len(data) == 5
            assert [item["budget_id"] for item in data] == [20, 19, 18, 17, 16]

            # No params -> 30 items and X-Total-Count: 30
            resp_all = client.get("/api/v1/financial-approval/import-budgets", headers=headers)
            assert resp_all.status_code == 200
            assert resp_all.headers.get("X-Total-Count") == "30"
            assert len(resp_all.json()) == 30

            # Boundary checks
            assert client.get("/api/v1/financial-approval/import-budgets?skip=-1", headers=headers).status_code == 422
            assert client.get("/api/v1/financial-approval/import-budgets?limit=0", headers=headers).status_code == 422
            assert client.get("/api/v1/financial-approval/import-budgets?limit=501", headers=headers).status_code == 422
        finally:
            app.dependency_overrides.clear()


