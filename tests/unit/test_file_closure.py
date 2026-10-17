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
    # FC-01: the server gate also requires the comprehensive dossier export (CLO-03).
    db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first().dossier_exported_at = datetime.now()
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
        # FC-01: the server gate decides. All prerequisites except the GRN exist -> 400 whatever the client says.
        _create_prerequisite_records(self.db, self.import_file_id)
        self.db.query(WarehouseReceivingRecord).filter(
            WarehouseReceivingRecord.import_file_id == self.import_file_id
        ).first().is_active = False
        self.db.commit()

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
            close_import_file_service(self.db, schema, trusted=True)
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

        record = close_import_file_service(self.db, schema, trusted=True)
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
        record = close_import_file_service(self.db, schema, trusted=True)
        c_id = record.closure_id

        # FC-09 / Q5: the closure of a Closed file cannot be deleted (reopen first)
        with self.assertRaises(HTTPException) as ctx:
            soft_delete_closure_service(self.db, c_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "FC_CLOSED_RECORD_LOCKED")

        # Once the file is reopened the record can be deleted and restored
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        imp_file.status = "Active"
        self.db.commit()
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
        record = close_import_file_service(self.db, schema, trusted=True)
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

        record = close_import_file_service(self.db, schema, trusted=True)
        self.assertIsNotNone(record.closure_id)
        self.assertEqual(record.status, "Draft")
        self.assertEqual(record.closure_checklist["docs_verified"], True)
        self.assertEqual(record.closure_checklist["warehouse_received"], False)

        # BE810-T09 / F19: Import file without dossier_exported_at leaves current_stage and current_module unchanged
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        self.assertNotEqual(imp_file.status, "Closed")
        self.assertEqual("Phase 1 - Planning & Feasibility", imp_file.current_stage)

        # When dossier_exported_at is set, draft update moves tracking to CLOSURE_IN_PROGRESS
        imp_file.dossier_exported_at = datetime.now()
        self.db.commit()
        record_after_export = close_import_file_service(self.db, schema, trusted=True)
        self.db.refresh(imp_file)
        self.assertEqual("Closure In-Progress", imp_file.current_stage)
        self.assertEqual("CLOSURE_IN_PROGRESS", imp_file.current_stage_code)
        self.assertEqual("NA_CLO_COMPLETE_CHECKLIST", imp_file.next_action_code)
        self.assertEqual("Phase 10 - Import File Closure & Historical Archive (Draft)", imp_file.current_module)

    def test_draft_post_on_phase_6_file_leaves_module_and_stage_unchanged(self):
        """BE810-T09: Draft POST on a Phase 6 file leaves current_module and current_stage unchanged."""
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        imp_file.current_stage = "Stage 6: Customs Clearance & Final Release"
        imp_file.current_module = "Phase 6: Customs Clearance & Form 46"
        imp_file.dossier_exported_at = None
        self.db.commit()

        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            is_draft=True,
        )
        record = close_import_file_service(self.db, schema, trusted=True)
        self.assertEqual(record.status, "Draft")

        self.db.refresh(imp_file)
        self.assertEqual("Stage 6: Customs Clearance & Final Release", imp_file.current_stage)
        self.assertEqual("Phase 6: Customs Clearance & Form 46", imp_file.current_module)

    def test_official_close_strips_trailing_draft_from_closed_at_phase(self):
        """BE810-T09: Official close strips trailing ' (Draft)' from imp.closed_at_phase."""
        _create_prerequisite_records(self.db, self.import_file_id)
        imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == self.import_file_id).first()
        imp_file.current_module = "Phase 10 - Import File Closure & Historical Archive (Draft)"
        self.db.commit()

        schema = FileClosureCreate(
            import_file_id=self.import_file_id,
            is_draft=False,
        )
        record = close_import_file_service(self.db, schema, trusted=True)
        self.assertEqual(record.status, "Closed")

        self.db.refresh(imp_file)
        self.assertEqual("Phase 10 - Import File Closure & Historical Archive", imp_file.closed_at_phase)

    def test_comprehensive_dossier_expanded_schema(self):
        """TASK-01: Verify ComprehensiveShipmentDossierResponse schema supports ETA revisions, physical summary, and patterns."""
        from modules.file_closure.schemas import ComprehensiveShipmentDossierResponse
        
        dossier = ComprehensiveShipmentDossierResponse(
            import_file_id=1,
            import_file_code="IMP-2026-TEST",
            status="Open",
            current_stage="Stage 3",
            current_module="Phase 3",
            progress_percent=55.0,
            next_action="Reconcile packing list",
            created_at=datetime.now(),
            updated_at=datetime.now(),
            company_name="SCAS",
            supplier_name="Suzhou Yuheng",
            shipment_mode="Sea FCL",
            incoterm_code="EXW",
            shipment_category="Commercial",
            priority="High",
            pos_count=1,
            invoices_count=1,
            eta_revisions_log=[
                {
                    "logged_at": "2026-10-13T10:00:00",
                    "previous_eta": "2026-10-20",
                    "revised_eta": "2026-10-25",
                    "drift_days": 5,
                    "reason": "Vessel transshipment delay",
                }
            ],
            cargo_physical_summary={
                "total_cbm": 66.388,
                "total_gross_weight_kg": 10510.0,
                "invoices_count": 1,
                "pos_count": 1,
            },
            similar_past_shipments=[
                {
                    "file_code": "IMP-2025-012",
                    "variance_pct": -2.4,
                    "performance": "On-time",
                }
            ],
            recurring_patterns=[
                {
                    "pattern_code": "PAT-001",
                    "title": "Supplier booking lead time",
                }
            ],
        )
        self.assertEqual(dossier.pos_count, 1)
        self.assertEqual(dossier.invoices_count, 1)
        self.assertEqual(len(dossier.eta_revisions_log), 1)
        self.assertEqual(dossier.eta_revisions_log[0]["drift_days"], 5)
        self.assertIsNotNone(dossier.cargo_physical_summary)
        self.assertEqual(dossier.cargo_physical_summary["total_cbm"], 66.388)
        self.assertEqual(len(dossier.similar_past_shipments), 1)
        self.assertEqual(len(dossier.recurring_patterns), 1)

    def test_get_comprehensive_dossier_populates_physical_summary_and_logs(self):
        """TASK-02: Verify get_comprehensive_shipment_dossier_service populates physical summary, eta log, and patterns."""
        from modules.file_closure.service import get_comprehensive_shipment_dossier_service
        dossier = get_comprehensive_shipment_dossier_service(self.db, self.import_file_id)
        self.assertIsNotNone(dossier.cargo_physical_summary)
        self.assertIn("total_cbm", dossier.cargo_physical_summary)
        self.assertIn("total_gross_weight_kg", dossier.cargo_physical_summary)
        self.assertIsInstance(dossier.eta_revisions_log, list)
        self.assertIsInstance(dossier.similar_past_shipments, list)
        self.assertIsInstance(dossier.recurring_patterns, list)


if __name__ == "__main__":
    unittest.main()
