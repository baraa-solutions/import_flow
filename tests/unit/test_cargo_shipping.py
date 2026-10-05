import unittest
from datetime import datetime
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
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.cargo_shipping.model import CargoShippingRecord
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.cargo_shipping.schemas import (
    CargoShippingCreate,
    CargoShippingUpdate,
    ContainerLoadingTrackingUpdate,
    LclLoadingTrackingItem,
    DualApprovalLevel1Submit,
    DualApprovalLevel2Submit,
    ContainerLoadingItem,
    CourierTrackingItem,
    CargoXExchangeItem,
)
from modules.cargo_shipping.service import (
    create_cargo_shipping_service,
    get_cargo_shipping_service,
    list_cargo_shippings_service,
    update_container_loading_tracking_service,
    update_lcl_loading_tracking_service,
    submit_level1_approval_service,
    submit_level2_approval_service,
    execute_cargox_checklist_service,
    advance_cargox_stage_service,
    update_cargo_shipping_service,
    soft_delete_cargo_shipping_service,
    restore_cargo_shipping_service,
)
from modules.cargo_shipping.validators import (
    validate_crd_against_cutoff,
    validate_dual_approval_sequence,
    validate_cargox_ready_for_upload,
    validate_container_tracking_timestamps,
    calculate_container_sla_and_status,
)
from fastapi import HTTPException

class TestCargoShippingModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        # Seed import company & import file
        from datetime import date
        company = ImportCompany(
            company_id=1,
            importer_name="Alpha Import Ltd",
            vat_id="100-200-300",
            registration_number="12345",
            address="Cairo, Egypt",
            country="Egypt",
            importer_id="IMP-001",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        self.db.add(company)
        self.db.commit()
        self.db.refresh(company)

        imp_file = ImportFile(
            import_file_code="IMP-FILE-2026-0001",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Global Supplier Inc",
            po_number="PO-2026-88",
        )
        self.db.add(imp_file)
        self.db.commit()
        self.db.refresh(imp_file)
        self.import_file = imp_file
        self.import_file_id = imp_file.import_file_id

        # Second import file for duplicate check
        imp_file_2 = ImportFile(
            import_file_code="IMP-FILE-2026-0002",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Second Supplier Inc",
            po_number="PO-2026-89",
        )
        self.db.add(imp_file_2)
        self.db.commit()
        self.db.refresh(imp_file_2)
        self.import_file_id_2 = imp_file_2.import_file_id

    def tearDown(self):
        self.db.close()

    def test_crd_validator(self):
        crd = datetime(2026, 8, 15)
        cutoff = datetime(2026, 8, 20)
        self.assertTrue(validate_crd_against_cutoff(crd, cutoff))

        late_crd = datetime(2026, 8, 25)
        self.assertFalse(validate_crd_against_cutoff(late_crd, cutoff))

    def test_create_cargo_shipping_with_container_tracking(self):
        schema = CargoShippingCreate(
            import_file_id=self.import_file_id,
            crd_date=datetime(2026, 8, 10),
            cargo_cutoff_date=datetime(2026, 8, 15),
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSKU9988776",
                    seal_no="SL-9001",
                    tare_weight_kg=2200.0,
                    net_weight_kg=18500.0,
                    gross_weight_kg=20700.0,
                    vgm_status="Submitted",
                    vgm_ref_no="VGM-REF-100",
                    container_assignment_date="2026-08-16",
                )
            ],
            courier_tracking_data=CourierTrackingItem(
                courier_provider="DHL Express",
                tracking_number="DHL-992211",
                receipt_status="Dispatched",
            ),
            cargox_exchange_data=CargoXExchangeItem(
                platform_provider="CargoX Platform",
                envelope_status="Created",
            ),
        )

        record = create_cargo_shipping_service(self.db, schema)
        self.assertIsNotNone(record.cargo_shipping_id)
        self.assertTrue(record.cargo_shipping_code.startswith("SHP-"))
        self.assertEqual(len(record.containers_loading_data), 1)
        container = record.containers_loading_data[0]
        self.assertEqual(container["container_no"], "MSKU9988776")
        self.assertEqual(container["tracking_status"], "ASSIGNED")
        self.assertIsNotNone(container["sla_deadline_at"])
        self.assertTrue(record.is_crd_validated)

    def test_duplicate_cargo_shipping_prevention(self):
        # 1. First record creation succeeds
        schema = CargoShippingCreate(import_file_id=self.import_file_id)
        create_cargo_shipping_service(self.db, schema)

        # 2. Duplicate creation for same import_file_id must raise HTTPException 400
        with self.assertRaises(HTTPException) as ctx:
            create_cargo_shipping_service(self.db, schema)
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("يوجد سجل متابعة وشحن محفوظ بالفعل", ctx.exception.detail)

    def test_container_tracking_sequential_validations(self):
        # Arrival before assignment should fail
        with self.assertRaises(HTTPException) as ctx1:
            validate_container_tracking_timestamps(
                container_assignment_date="2026-08-16",
                arrival_at_supplier_at="2026-08-15T10:00:00",
            )
        self.assertEqual(ctx1.exception.status_code, 400)

        # Loading start before arrival should fail
        with self.assertRaises(HTTPException) as ctx2:
            validate_container_tracking_timestamps(
                container_assignment_date="2026-08-16",
                arrival_at_supplier_at="2026-08-16T10:00:00",
                loading_start_at="2026-08-16T09:00:00",
            )
        self.assertEqual(ctx2.exception.status_code, 400)

        # Loading end before loading start should fail
        with self.assertRaises(HTTPException) as ctx3:
            validate_container_tracking_timestamps(
                container_assignment_date="2026-08-16",
                arrival_at_supplier_at="2026-08-16T10:00:00",
                loading_start_at="2026-08-16T12:00:00",
                loading_end_at="2026-08-16T11:00:00",
            )
        self.assertEqual(ctx3.exception.status_code, 400)

        # Gate-in before loading end should fail
        with self.assertRaises(HTTPException) as ctx4:
            validate_container_tracking_timestamps(
                container_assignment_date="2026-08-16",
                arrival_at_supplier_at="2026-08-16T10:00:00",
                loading_start_at="2026-08-16T12:00:00",
                loading_end_at="2026-08-16T16:00:00",
                port_gate_in_at="2026-08-16T15:00:00",
            )
        self.assertEqual(ctx4.exception.status_code, 400)

    def test_container_tracking_sla_and_auto_status(self):
        today_str = datetime.now().strftime("%Y-%m-%d")
        # 1. Only assignment
        res1 = calculate_container_sla_and_status({"container_assignment_date": today_str})
        self.assertEqual(res1["tracking_status"], "ASSIGNED")
        self.assertFalse(res1["is_sla_breached"])

        # 2. Arrived at supplier
        res2 = calculate_container_sla_and_status({
            "container_assignment_date": "2026-08-16",
            "arrival_at_supplier_at": "2026-08-16T10:00:00",
        })
        self.assertEqual(res2["tracking_status"], "ARRIVED_AT_SUPPLIER")

        # 3. Loading in progress
        res3 = calculate_container_sla_and_status({
            "container_assignment_date": "2026-08-16",
            "arrival_at_supplier_at": "2026-08-16T10:00:00",
            "loading_start_at": "2026-08-16T12:00:00",
        })
        self.assertEqual(res3["tracking_status"], "LOADING_IN_PROGRESS")

        # 4. Loading completed
        res4 = calculate_container_sla_and_status({
            "container_assignment_date": "2026-08-16",
            "arrival_at_supplier_at": "2026-08-16T10:00:00",
            "loading_start_at": "2026-08-16T12:00:00",
            "loading_end_at": "2026-08-16T16:00:00",
        })
        self.assertEqual(res4["tracking_status"], "LOADING_COMPLETED")

        # 5. Gated in on time
        res5 = calculate_container_sla_and_status({
            "container_assignment_date": "2026-08-16",
            "arrival_at_supplier_at": "2026-08-16T10:00:00",
            "loading_start_at": "2026-08-16T12:00:00",
            "loading_end_at": "2026-08-16T16:00:00",
            "port_gate_in_at": "2026-08-17T10:00:00", # within 48h
        })
        self.assertEqual(res5["tracking_status"], "GATED_IN_AT_PORT")
        self.assertFalse(res5["is_sla_breached"])

        # 6. Gated in after 48h (SLA Breached)
        res6 = calculate_container_sla_and_status({
            "container_assignment_date": "2026-08-10",
            "port_gate_in_at": "2026-08-15T10:00:00", # 5 days later (> 48h)
        })
        self.assertEqual(res6["tracking_status"], "GATED_IN_AT_PORT")
        self.assertTrue(res6["is_sla_breached"])

    def test_multi_container_independent_tracking_and_patch(self):
        schema = CargoShippingCreate(
            import_file_id=self.import_file_id,
            containers_loading_data=[
                ContainerLoadingItem(container_no="MSCU1111111", seal_no="SL-1", container_assignment_date="2026-08-16"),
                ContainerLoadingItem(container_no="MSCU2222222", seal_no="SL-2", container_assignment_date="2026-08-16"),
            ],
        )
        record = create_cargo_shipping_service(self.db, schema)
        self.assertEqual(len(record.containers_loading_data), 2)

        # Patch only container 1
        patch_payload = ContainerLoadingTrackingUpdate(
            container_no="MSCU1111111",
            arrival_at_supplier_at="2026-08-16T08:00:00",
            loading_start_at="2026-08-16T10:00:00",
            loading_end_at="2026-08-16T14:00:00",
            port_gate_in_at="2026-08-16T20:00:00",
            notes="وصلت الحاوية ودخلت ميناء الإسكندرية بنجاح",
        )
        updated_rec = update_container_loading_tracking_service(
            self.db,
            record.cargo_shipping_id,
            "MSCU1111111",
            patch_payload,
        )

        c1 = [c for c in updated_rec.containers_loading_data if c["container_no"] == "MSCU1111111"][0]
        c2 = [c for c in updated_rec.containers_loading_data if c["container_no"] == "MSCU2222222"][0]

        self.assertEqual(c1["tracking_status"], "GATED_IN_AT_PORT")
        self.assertEqual(len(c1["tracking_history"]), 1)
        self.assertEqual(c2["tracking_status"], "ASSIGNED") # Independent!

    def test_lcl_consolidation_tracking(self):
        schema = CargoShippingCreate(
            import_file_id=self.import_file_id,
            shipment_type="LCL",
            lcl_tracking_data={
                "cfs_warehouse_name": "Shanghai CFS Warehouse #4",
                "consolidation_scheduled_date": "2026-08-16",
                "arrival_at_cfs_at": "2026-08-16T09:00:00",
                "stuffing_start_at": "2026-08-16T11:00:00",
                "stuffing_end_at": "2026-08-16T15:00:00",
                "port_gate_in_at": "2026-08-17T08:00:00",
            }
        )
        record = create_cargo_shipping_service(self.db, schema)
        self.assertEqual(record.shipment_type, "LCL")
        self.assertEqual(record.lcl_tracking_data["tracking_status"], "GATED_IN_AT_PORT")
        self.assertFalse(record.lcl_tracking_data["is_sla_breached"])

    def test_soft_delete_and_restore_on_edit(self):
        from modules.cargo_shipping.repository import get_cargo_shipping_by_id
        schema = CargoShippingCreate(import_file_id=self.import_file_id)
        record = create_cargo_shipping_service(self.db, schema)
        rec_id = record.cargo_shipping_id

        # 1. Soft Delete
        soft_delete_cargo_shipping_service(self.db, rec_id)
        deleted_check = get_cargo_shipping_by_id(self.db, rec_id, include_inactive=False)
        self.assertIsNone(deleted_check)

        # 2. CS-03: editing a deleted record is a 404; only /restore reactivates it
        with self.assertRaises(HTTPException) as ctx:
            update_cargo_shipping_service(self.db, rec_id, CargoShippingUpdate(notes="Updated and restored"))
        self.assertEqual(ctx.exception.status_code, 404)
        restore_cargo_shipping_service(self.db, rec_id)
        update_cargo_shipping_service(self.db, rec_id, CargoShippingUpdate(notes="Updated and restored"))
        restored_check = get_cargo_shipping_service(self.db, rec_id, include_inactive=False)
        self.assertIsNotNone(restored_check)
        self.assertTrue(restored_check.is_active)
        self.assertEqual(restored_check.notes, "Updated and restored")

    def test_dual_approval_workflow(self):
        schema = CargoShippingCreate(import_file_id=self.import_file_id)
        record = create_cargo_shipping_service(self.db, schema)

        # Level 1 Approval
        l1_payload = DualApprovalLevel1Submit(approved_by="Operational Manager Kamal", approved=True, notes="Verified containers and ACID")
        record = submit_level1_approval_service(self.db, record.cargo_shipping_id, l1_payload)
        self.assertEqual(record.level1_approval_status, "Approved")
        self.assertEqual(record.dual_approval_status, "In Progress")

        # Level 2 Approval
        l2_payload = DualApprovalLevel2Submit(approved_by="Customs Director Ahmed", approved=True, notes="Verified legal documents")
        record = submit_level2_approval_service(self.db, record.cargo_shipping_id, l2_payload)
        self.assertEqual(record.level2_approval_status, "Approved")
        self.assertEqual(record.dual_approval_status, "Dual Approved")

    def test_cargox_checklist_and_stage_advance(self):
        schema = CargoShippingCreate(
            import_file_id=self.import_file_id,
            containers_loading_data=[
                ContainerLoadingItem(container_no="COSU1234567", seal_no="SL-100")
            ]
        )
        record = create_cargo_shipping_service(self.db, schema)

        # Run Level 1 and Level 2 approvals
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved_by="Op User", approved=True))
        submit_level2_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel2Submit(approved_by="Mgr User", approved=True))

        # Run CargoX verification checklist: no ACID and no invoice confirmation -> not passed (CS-02)
        record = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        self.assertEqual(record.cargox_exchange_data["envelope_status"], "Invited")
        self.import_file.acid_number = "1234567890123456789"
        self.db.commit()
        record = execute_cargox_checklist_service(self.db, record.cargo_shipping_id, invoice_match_confirmed=True, user="op1")
        self.assertEqual(record.cargox_exchange_data["envelope_status"], "Checklist Passed")

        # Advance to Ready for Upload
        record = advance_cargox_stage_service(self.db, record.cargo_shipping_id, "Ready for Upload")
        self.assertEqual(record.cargox_exchange_data["envelope_status"], "Ready for Upload")

        # Advance to Uploaded
        record = advance_cargox_stage_service(self.db, record.cargo_shipping_id, "Uploaded")
        self.assertEqual(record.cargox_exchange_data["envelope_status"], "Uploaded")
        self.assertIsNone(record.cargox_exchange_data["blockchain_tx_hash"])  # never invented (CS-02)
        self.assertEqual(record.status, "CargoX Transfer Completed")

    def test_container_reuse_conflict_15_day_window(self):
        # 1. Create first shipment with container MSKU9999999 and seal SL-001 on 2026-08-16
        schema1 = CargoShippingCreate(
            import_file_id=self.import_file_id,
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSKU9999999",
                    seal_no="SL-001",
                    container_assignment_date="2026-08-16T10:00:00",
                )
            ]
        )
        create_cargo_shipping_service(self.db, schema1)

        # 2. Create second file
        file2 = ImportFile(
            import_file_code="IMP-2026-0002",
            company_name="Beta Company",
            company_id=1,
            supplier_name="Global Supplier Inc",
            is_active=True,
        )
        self.db.add(file2)
        self.db.commit()
        self.db.refresh(file2)

        # 3. Same container + SAME seal within 15 days (e.g. 5 days later) -> MUST FAIL (HTTP 400)
        schema2_conflict = CargoShippingCreate(
            import_file_id=file2.import_file_id,
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSKU9999999",
                    seal_no="SL-001", # Same seal!
                    container_assignment_date="2026-08-20T10:00:00", # 4 days later (<= 15 days)
                )
            ]
        )
        with self.assertRaises(HTTPException) as ctx:
            create_cargo_shipping_service(self.db, schema2_conflict)
        self.assertEqual(ctx.exception.status_code, 400)
        self.assertIn("لا يمكن استخدام نفس رقم الحاوية (MSKU9999999) ونفس رقم السيل (SL-001) في محيط زمني 15 يوماً", ctx.exception.detail)

        # 4. Same container + DIFFERENT seal within 15 days -> MUST SUCCEED
        schema2_ok_diff_seal = CargoShippingCreate(
            import_file_id=file2.import_file_id,
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSKU9999999",
                    seal_no="SL-NEW-999", # Different seal!
                    container_assignment_date="2026-08-20T10:00:00",
                )
            ]
        )
        rec2 = create_cargo_shipping_service(self.db, schema2_ok_diff_seal)
        self.assertIsNotNone(rec2)
        self.assertEqual(rec2.containers_loading_data[0]["seal_no"], "SL-NEW-999")

    def test_cargo_shipping_lifecycle_advance_on_create_and_update(self):
        from modules.lifecycle_board.repository import get_activity
        # Create record with auto_advance_lifecycle=True
        schema = CargoShippingCreate(
            import_file_id=self.import_file.import_file_id,
            shipment_type="FCL",
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="WHSU8107265",
                    seal_no="SL-WHA2570978",
                    vgm_status="Submitted",
                    tracking_status="GATED_IN_AT_PORT",
                )
            ]
        )
        record = create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=True)
        self.assertIsNotNone(record)

        # Verify STEP_07 is Completed
        act_07 = get_activity(self.db, self.import_file.import_file_code, "STEP_07")
        self.assertIsNotNone(act_07)
        self.assertEqual(act_07.status, "Completed")

        # Verify STEP_08_PO is In-Progress
        act_08 = get_activity(self.db, self.import_file.import_file_code, "STEP_08_PO")
        self.assertIsNotNone(act_08)
        self.assertEqual(act_08.status, "In-Progress")

        # Verify import_file fields updated
        self.db.refresh(self.import_file)
        self.assertIn("STEP_08", self.import_file.current_module)
        self.assertGreaterEqual(self.import_file.progress_percent, 38.0)

if __name__ == "__main__":
    unittest.main()
