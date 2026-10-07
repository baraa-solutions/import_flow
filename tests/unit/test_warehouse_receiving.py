import unittest
from datetime import datetime, date
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
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import (
    WarehouseReceivingCreate,
    GrnItemSchema,
    WarehouseReceivingUpdate,
    DiscrepancyReportSubmit,
)
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    get_warehouse_receiving_service,
    list_warehouse_receivings_service,
    report_receiving_discrepancy_service,
    soft_delete_warehouse_receiving_service,
    restore_warehouse_receiving_service,
)
from modules.warehouse_receiving.validators import validate_seal_integrity, validate_discrepancy_claim
from fastapi import HTTPException

class TestWarehouseReceivingModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        company = ImportCompany(
            company_id=1,
            importer_name="Gamma Import Ltd",
            vat_id="111-222-333",
            registration_number="54321",
            address="Cairo, Egypt",
            country="Egypt",
            importer_id="IMP-003",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        self.db.add(company)
        self.db.commit()

        imp_file = ImportFile(
            import_file_code="IMP-FILE-2026-0003",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Global Tech Inc",
            po_number="PO-2026-100",
            is_customs_released=True,
        )
        self.db.add(imp_file)
        self.db.commit()
        self.db.refresh(imp_file)
        self.import_file_id = imp_file.import_file_id

    def tearDown(self):
        self.db.close()

    def _create_valid_grn(self):
        schema = WarehouseReceivingCreate(
            import_file_id=self.import_file_id,
            warehouse_name="Cairo Logistics Depot",
            grn_items=[
                GrnItemSchema(item_code="ITM-01", item_name="Pipes", invoiced_qty=100, accepted_qty=100),
            ],
        )
        return create_warehouse_receiving_service(self.db, schema)

    def test_create_warehouse_receiving_and_grn_totals(self):
        schema = WarehouseReceivingCreate(
            import_file_id=self.import_file_id,
            warehouse_name="Cairo Logistics Depot",
            truck_plate_number="TRK-9988",
            driver_name="Ahmed Hassan",
            seal_number="SEAL-776655",
            seal_intact=True,
            grn_items=[
                GrnItemSchema(item_code="ITM-01", item_name="Pipes", invoiced_qty=100, accepted_qty=95, shortage_qty=3, damaged_qty=2),
                GrnItemSchema(item_code="ITM-02", item_name="Fittings", invoiced_qty=50, accepted_qty=50, shortage_qty=0, damaged_qty=0),
            ],
        )

        record = create_warehouse_receiving_service(self.db, schema)
        self.assertIsNotNone(record.receiving_id)
        self.assertTrue(record.grn_code.startswith("GRN-"))
        self.assertEqual(record.total_invoiced_qty, 150)
        self.assertEqual(record.total_accepted_qty, 145)
        self.assertEqual(record.total_shortage_qty, 3)
        self.assertEqual(record.total_damaged_qty, 2)
        self.assertEqual(record.discrepancy_type, "Shortage")

    def test_discrepancy_reporting_and_quarantine(self):
        record = self._create_valid_grn()

        payload = DiscrepancyReportSubmit(
            discrepancy_type="Damage",
            discrepancy_notes="2 boxes found crushed during unloading.",
            quarantine_zone_assigned=True,
            insurance_claim_filed=True,
            insurance_claim_ref="CLAIM-INS-99001",
        )

        record = report_receiving_discrepancy_service(self.db, record.receiving_id, payload)
        self.assertEqual(record.discrepancy_type, "Damage")
        self.assertTrue(record.quarantine_zone_assigned)
        self.assertTrue(record.insurance_claim_filed)
        self.assertEqual(record.insurance_claim_ref, "CLAIM-INS-99001")
        self.assertEqual(record.status, "Discrepancy Reported")

    def test_soft_delete_and_restore(self):
        record = self._create_valid_grn()
        rec_id = record.receiving_id

        # Delete
        success = soft_delete_warehouse_receiving_service(self.db, rec_id)
        self.assertTrue(success)

        # Restore
        restored = restore_warehouse_receiving_service(self.db, rec_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.receiving_id, rec_id)
        self.assertTrue(restored.is_active)

    def test_soft_delete_blocked_when_protocol_exists(self):
        record = self._create_valid_grn()
        record.inspection_protocol_number = "INSP-2026-0001"
        self.db.commit()

        with self.assertRaises(HTTPException) as ctx:
            soft_delete_warehouse_receiving_service(self.db, record.receiving_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "WR_GRN_LOCKED")

    def test_soft_delete_blocked_when_insurance_claim_filed(self):
        record = self._create_valid_grn()
        record.insurance_claim_filed = True
        self.db.commit()

        with self.assertRaises(HTTPException) as ctx:
            soft_delete_warehouse_receiving_service(self.db, record.receiving_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "WR_GRN_LOCKED")

    def test_soft_delete_blocked_when_supplier_claim_filed(self):
        record = self._create_valid_grn()
        record.supplier_claim_filed = True
        self.db.commit()

        with self.assertRaises(HTTPException) as ctx:
            soft_delete_warehouse_receiving_service(self.db, record.receiving_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "WR_GRN_LOCKED")

    def test_soft_delete_blocked_when_quarantine_lock_active(self):
        record = self._create_valid_grn()
        record.quarantine_lock_active = True
        self.db.commit()

        with self.assertRaises(HTTPException) as ctx:
            soft_delete_warehouse_receiving_service(self.db, record.receiving_id)
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(ctx.exception.detail["code"], "WR_GRN_LOCKED")

if __name__ == "__main__":
    unittest.main()

