import unittest
from datetime import datetime, date, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.freight_quotations.model import FreightRFQRequest
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    CustomsClearanceCreate,
    CustomsClearanceUpdate,
    DutyPaymentSubmit,
    CompleteReleaseSubmit,
    FinalDutyAssessmentSubmit,
)
from modules.customs_clearance.service import (
    create_customs_clearance_service,
    get_customs_clearance_service,
    list_customs_clearances_service,
    submit_duty_payment_service,
    complete_customs_release_service,
    soft_delete_customs_clearance_service,
    restore_customs_clearance_service,
    update_customs_clearance_service,
    assess_final_customs_duties_service,
)
from modules.customs_clearance.validators import validate_bank_receipt_no, validate_release_permit
from fastapi import HTTPException
from pydantic import ValidationError

class TestCustomsClearanceModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        company = ImportCompany(
            company_id=1,
            importer_name="Delta Import Ltd",
            vat_id="100-200-300",
            registration_number="12345",
            address="Alexandria, Egypt",
            country="Egypt",
            importer_id="IMP-002",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        self.db.add(company)
        self.db.commit()

        imp_file = ImportFile(
            import_file_code="IMP-FILE-2026-0002",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Sino Cargo Ltd",
            po_number="PO-2026-99",
        )
        self.db.add(imp_file)
        self.db.commit()
        self.db.refresh(imp_file)
        self.import_file_id = imp_file.import_file_id

    def tearDown(self):
        self.db.close()

    def test_create_customs_clearance_and_duty_total(self):
        schema = CustomsClearanceCreate(
            import_file_id=self.import_file_id,
            declaration_46_no="DECL-46-99001",
            customs_office_name="Alexandria Dekheila Port",
            channel_type="Red Channel",
            regulatory_bodies=["GOEIC", "Food Safety Authority"],
            import_duty_amount=62300.0,
            vat_amount=95942.0,
            schedule_tax_amount=6230.0,
            wht_amount=6230.0,
            lab_service_fees=1200.0,
        )

        record = create_customs_clearance_service(self.db, schema)
        self.assertIsNotNone(record.customs_clearance_id)
        self.assertTrue(record.clearance_code.startswith("CLR-"))
        self.assertEqual(record.declaration_46_no, "DECL-46-99001")
        self.assertEqual(record.total_duty_payable, 62300.0 + 95942.0 + 6230.0 + 6230.0 + 1200.0)

    def test_duty_payment_and_release_workflow(self):
        schema = CustomsClearanceCreate(
            import_file_id=self.import_file_id,
            declaration_46_no="DECL-46-99001",
            import_duty_amount=1000.0,
            vat_amount=140.0,
        )
        record = create_customs_clearance_service(self.db, schema)
        self.assertEqual(record.total_duty_payable, 1140.0)

        # Cannot issue release before payment
        with self.assertRaises(HTTPException):
            complete_customs_release_service(self.db, record.customs_clearance_id, CompleteReleaseSubmit(
                release_permit_no="REL-PERMIT-100",
                release_date=datetime.now(timezone.utc),
            ))

        # Submit Bank Duty Payment payload
        payment_payload = DutyPaymentSubmit(
            bank_receipt_no="RCPT-BANK-998877",
            paying_bank_name="National Bank of Egypt (NBE)",
            payment_date=datetime.now(timezone.utc),
            payment_notes="Paid via Customs e-payment portal",
            duty_paid_amount=1140.0,
        )

        # Attempting payment without CL-02 claim raises 409 CC_DUTY_NOT_ASSESSED
        with self.assertRaises(HTTPException) as unassessed:
            submit_duty_payment_service(self.db, record.customs_clearance_id, payment_payload)
        self.assertEqual(unassessed.exception.status_code, 409)
        self.assertEqual(unassessed.exception.detail["code"], "CC_DUTY_NOT_ASSESSED")

        # PUT with notes or nafeza_claim_number is ignored/does not assess record
        update_schema = CustomsClearanceUpdate(notes="Attempted update")
        updated = update_customs_clearance_service(self.db, record.customs_clearance_id, update_schema)
        self.assertIsNone(updated.nafeza_claim_number)

        # Run CL-02 with nafeza_claim_number="NFZ-123"
        record = assess_final_customs_duties_service(
            self.db,
            FinalDutyAssessmentSubmit(
                import_file_id=self.import_file_id,
                nafeza_claim_number="NFZ-123",
                cif_base_amount=10000.0,
                import_duty_amount=1000.0,
                vat_amount=140.0,
            ),
        )
        self.assertEqual(record.nafeza_claim_number, "NFZ-123")
        self.assertEqual(record.total_duty_payable, 1140.0)

        # The legacy route needs the paid amount now (CL-07) and refuses a partial payment.
        with self.assertRaises(HTTPException) as no_amount:
            submit_duty_payment_service(
                self.db, record.customs_clearance_id, payment_payload.model_copy(update={"duty_paid_amount": None, "actual_duty_total": None})
            )
        self.assertEqual(no_amount.exception.status_code, 400)
        with self.assertRaises(HTTPException) as partial:
            submit_duty_payment_service(
                self.db, record.customs_clearance_id, payment_payload.model_copy(update={"duty_paid_amount": 1000.0, "actual_duty_total": None})
            )
        self.assertEqual(partial.exception.detail["code"], "CC_DUTY_UNDERPAID")

        record = submit_duty_payment_service(
            self.db, record.customs_clearance_id, payment_payload.model_copy(update={"duty_paid_amount": 1140.0})
        )
        self.assertEqual(record.payment_status, "Paid & Verified")
        self.assertEqual(record.status, "Duty Paid")
        self.assertEqual(record.actual_duty_total, 1140.0)

        # Now issue Final Customs Release Permit
        release_payload = CompleteReleaseSubmit(
            release_permit_no="REL-PERMIT-100",
            release_date=datetime.now(timezone.utc),
            demurrage_storage_fees=450.0,
            dispatch_authorized=True,
        )
        record = complete_customs_release_service(self.db, record.customs_clearance_id, release_payload)
        self.assertEqual(record.release_permit_no, "REL-PERMIT-100")
        self.assertEqual(record.status, "Final Release Granted")
        self.assertTrue(record.dispatch_authorized)

    def test_negative_money_and_rate_bounds_validation(self):
        # Create rejects negative money
        with self.assertRaises(ValidationError):
            CustomsClearanceCreate(import_file_id=self.import_file_id, vat_amount=-5.0)

        with self.assertRaises(ValidationError):
            CustomsClearanceCreate(import_file_id=self.import_file_id, import_duty_amount=-1.0)

        # Create rejects non-positive customs_exchange_rate
        with self.assertRaises(ValidationError):
            CustomsClearanceCreate(import_file_id=self.import_file_id, customs_exchange_rate=0.0)

        with self.assertRaises(ValidationError):
            CustomsClearanceCreate(import_file_id=self.import_file_id, customs_exchange_rate=-1.5)

        # Update rejects negative money
        with self.assertRaises(ValidationError):
            CustomsClearanceUpdate(vat_amount=-5.0)

        with self.assertRaises(ValidationError):
            CustomsClearanceUpdate(import_duty_amount=-100.0)

        # Update rejects non-positive customs_exchange_rate
        with self.assertRaises(ValidationError):
            CustomsClearanceUpdate(customs_exchange_rate=0.0)

        with self.assertRaises(ValidationError):
            CustomsClearanceUpdate(customs_exchange_rate=-2.0)

    def test_soft_delete_and_restore(self):
        schema = CustomsClearanceCreate(import_file_id=self.import_file_id)
        record = create_customs_clearance_service(self.db, schema)
        rec_id = record.customs_clearance_id

        # Delete
        success = soft_delete_customs_clearance_service(self.db, rec_id)
        self.assertTrue(success)

        # Restore
        restored = restore_customs_clearance_service(self.db, rec_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.customs_clearance_id, rec_id)
        self.assertTrue(restored.is_active)

    def test_closed_file_guards_customs_clearance(self):
        """BEW0-03: Closed import file prevents create, update, delete, restore, and assessment."""
        # 1. Closed file prevents create
        closed_file = ImportFile(
            import_file_code="IMP-CLOSED-CC",
            company_name="Delta Import Ltd",
            supplier_name="Global Steel Ltd",
            status="Closed",
        )
        self.db.add(closed_file)
        self.db.commit()
        self.db.refresh(closed_file)

        create_schema = CustomsClearanceCreate(import_file_id=closed_file.import_file_id)
        with self.assertRaises(HTTPException) as ctx:
            create_customs_clearance_service(self.db, create_schema)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "IMPORT_FILE_CLOSED")

        # 2. Existing record on a file that gets closed
        record = create_customs_clearance_service(self.db, CustomsClearanceCreate(import_file_id=self.import_file_id))
        rec_id = record.customs_clearance_id

        # Mark file as Closed
        file_obj = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        file_obj.status = "Closed"
        self.db.commit()

        # Update should fail with 409
        with self.assertRaises(HTTPException) as ctx:
            update_customs_clearance_service(self.db, rec_id, CustomsClearanceUpdate(notes="new notes"))
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "IMPORT_FILE_CLOSED")

        # Delete should fail with 409
        with self.assertRaises(HTTPException) as ctx:
            soft_delete_customs_clearance_service(self.db, rec_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "IMPORT_FILE_CLOSED")

        # Assessment (CL-02) should fail with 409
        cl02_data = FinalDutyAssessmentSubmit(
            import_file_id=self.import_file_id,
            nafeza_claim_number="CLM-TEST-001",
            cif_base_amount=100000.0,
            import_duty_amount=5000.0,
            vat_amount=14000.0,
        )
        with self.assertRaises(HTTPException) as ctx:
            assess_final_customs_duties_service(self.db, cl02_data)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "IMPORT_FILE_CLOSED")

if __name__ == "__main__":
    unittest.main()

