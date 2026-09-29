import main
import unittest
from datetime import datetime, date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

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
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.file_closure.model import ImportFileClosureRecord
from modules.file_closure.schemas import (
    FileClosureCreate,
    ClosureChecklistSchema,
    FileClosureUpdate,
)
from modules.file_closure.service import (
    close_import_file_service,
    get_closure_service,
    list_closures_service,
    soft_delete_closure_service,
    restore_closure_service,
)


def _create_prerequisite_records(db, import_file_id: int):
    """Helper: create the three prerequisite records needed for final closure."""
    clearance = CustomsClearanceRecord(
        clearance_code="CLR-TEST-001",
        import_file_id=import_file_id,
        status="Final Release Granted",
        declaration_46_no="46-TEST-001",
        actual_duty_total=0.0,
        total_duty_payable=0.0,
        is_active=True,
    )
    db.add(clearance)
    grn = WarehouseReceivingRecord(
        grn_code="GRN-TEST-001",
        import_file_id=import_file_id,
        warehouse_name="Test Warehouse",
        status="Received",
        is_active=True,
    )
    db.add(grn)
    settlement = LandedCostSettlementRecord(
        settlement_code="SET-TEST-001",
        import_file_id=import_file_id,
        status="Calculated",
        incoterm_code="FOB",
        total_fob_egp=0.0,
        total_expenses_egp=0.0,
        total_landed_cost_egp=0.0,
        is_active=True,
    )
    db.add(settlement)
    db.commit()



class TestFileClosureModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        company = ImportCompany(
            company_id=1,
            importer_name="Universal Trade Corp",
            vat_id="111-222-333",
            registration_number="54321",
            address="Alexandria, Egypt",
            country="Egypt",
            importer_id="IMP-010",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        self.db.add(company)
        self.db.commit()

        imp_file = ImportFile(
            import_file_code="IMP-FILE-2026-0010",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Global Heavy Industries",
            po_number="PO-2026-1000",
            status="In Progress",
            progress_percent=95.0,
        )
        self.db.add(imp_file)
        self.db.commit()
        self.db.refresh(imp_file)
        self.import_file_id = imp_file.import_file_id

    def tearDown(self):
        self.db.close()

    def test_close_import_file_checklist_validation_failure(self):
        # Need prerequisite records so DB check passes, then checklist check raises 400
        _create_prerequisite_records(self.db, self.import_file_id)

        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            closure_checklist=ClosureChecklistSchema(
                docs_verified=True,
                customs_cleared=True,
                warehouse_received=False, # Unmet!
                landed_cost_settled=True,
                tasks_closed=True,
            ),
            auditor_name="Adel Auditor",
            archive_location="Vault A",
        )

        with self.assertRaises(HTTPException) as ctx:
            close_import_file_service(self.db, schema)
        self.assertEqual(ctx.exception.status_code, 400)

    def test_close_import_file_success(self):
        # Create prerequisite DB records first (mandatory for final closure)
        _create_prerequisite_records(self.db, self.import_file_id)

        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            closure_checklist=ClosureChecklistSchema(
                docs_verified=True,
                customs_cleared=True,
                warehouse_received=True,
                landed_cost_settled=True,
                tasks_closed=True,
            ),
            auditor_name="Adel Auditor",
            archive_location="Vault A - Digital 2026",
            archival_notes="All customs duties paid, landed cost calculated, GRN received.",
        )

        record = close_import_file_service(self.db, schema)
        self.assertIsNotNone(record.closure_id)
        self.assertTrue(record.closure_code.startswith("CLR-"))
        self.assertEqual(record.status, "Closed")

        # Verify ImportFile state updated to Closed and 100%
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        self.assertEqual(imp_file.status, "Closed")
        self.assertEqual(imp_file.progress_percent, 100.0)
        self.assertTrue("Phase 10" in imp_file.current_module or "STEP_21" in imp_file.current_module)

    def test_soft_delete_and_restore(self):
        # Create prerequisite DB records first
        _create_prerequisite_records(self.db, self.import_file_id)

        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            closure_checklist=ClosureChecklistSchema(
                docs_verified=True,
                customs_cleared=True,
                warehouse_received=True,
                landed_cost_settled=True,
                tasks_closed=True,
            ),
        )
        record = close_import_file_service(self.db, schema)
        c_id = record.closure_id

        # Delete
        success = soft_delete_closure_service(self.db, c_id)
        self.assertTrue(success)

        # Restore
        restored = restore_closure_service(self.db, c_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.closure_id, c_id)
        self.assertTrue(restored.is_active)

    def test_close_import_file_with_skipped_stages_allowed(self):
        # Skip all three required stages on import file (STEP_17=customs, STEP_19=GRN, STEP_20=settlement)
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        imp_file.skipped_stages = ["STEP_17", "STEP_19", "STEP_20", "warehouse_received"]
        self.db.commit()

        # Try closing with warehouse_received=False (all three DB checks bypassed via skipped_stages)
        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            closure_checklist=ClosureChecklistSchema(
                docs_verified=True,
                customs_cleared=True,
                warehouse_received=False, # Skipped legally
                landed_cost_settled=True,
                tasks_closed=True,
            ),
        )
        record = close_import_file_service(self.db, schema)
        self.assertIsNotNone(record.closure_id)
        self.assertEqual(record.status, "Closed")


    def test_save_draft_intermediate_closure_success(self):
        # Schema with only 2 out of 5 items completed and is_draft=True
        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            closure_checklist=ClosureChecklistSchema(
                docs_verified=True,
                customs_cleared=True,
                warehouse_received=False,
                landed_cost_settled=False,
                tasks_closed=False,
            ),
            auditor_name="Adel Auditor",
            archive_location="Draft Vault",
            is_draft=True,
        )

        record = close_import_file_service(self.db, schema)
        self.assertIsNotNone(record.closure_id)
        self.assertEqual(record.status, "Draft")
        self.assertEqual(record.closure_checklist["docs_verified"], True)
        self.assertEqual(record.closure_checklist["warehouse_received"], False)

        # Import file should remain open with in-progress closure status
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        self.assertNotEqual(imp_file.status, "Closed")
        self.assertEqual("Closure In-Progress", imp_file.current_stage)
        self.assertEqual("CLOSURE_IN_PROGRESS", imp_file.current_stage_code)
        self.assertEqual("NA_CLO_COMPLETE_CHECKLIST", imp_file.next_action_code)

if __name__ == "__main__":
    unittest.main()
