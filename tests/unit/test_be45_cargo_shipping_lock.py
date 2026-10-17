import unittest
from datetime import datetime, timezone, date
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
)
from modules.cargo_shipping.service import (
    create_cargo_shipping_service,
    update_cargo_shipping_service,
    update_container_loading_tracking_service,
    update_lcl_loading_tracking_service,
    submit_level1_approval_service,
    submit_level2_approval_service,
    execute_cargox_checklist_service,
)


class TestBE45CargoShippingLock(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        self.db = TestingSessionLocal()

        # Seed import company
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

        # Seed import file 1
        file_1 = ImportFile(
            import_file_code="IMP-FILE-2026-0001",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Global Supplier Inc",
            po_number="PO-2026-88",
            acid_number="9876543210123456",
        )
        self.db.add(file_1)

        # Seed import file 2
        file_2 = ImportFile(
            import_file_code="IMP-FILE-2026-0002",
            company_id=company.company_id,
            company_name=company.importer_name,
            supplier_name="Second Supplier Inc",
            po_number="PO-2026-89",
        )
        self.db.add(file_2)
        self.db.commit()

        self.file_1_id = file_1.import_file_id
        self.file_2_id = file_2.import_file_id

        # Seed active booking for file 1
        booking_1 = ShipmentBooking(
            booking_code="BKG-2026-0001",
            import_file_id=self.file_1_id,
            shipment_type="FCL",
            status="Draft",
            is_active=True,
        )
        # Seed inactive booking for file 1
        booking_inactive = ShipmentBooking(
            booking_code="BKG-2026-0002",
            import_file_id=self.file_1_id,
            shipment_type="FCL",
            status="Cancelled",
            is_active=False,
        )
        # Seed active booking for file 2
        booking_2 = ShipmentBooking(
            booking_code="BKG-2026-0003",
            import_file_id=self.file_2_id,
            shipment_type="FCL",
            status="Draft",
            is_active=True,
        )
        self.db.add_all([booking_1, booking_inactive, booking_2])
        self.db.commit()

        self.booking_1_id = booking_1.booking_id
        self.booking_inactive_id = booking_inactive.booking_id
        self.booking_2_id = booking_2.booking_id

    def tearDown(self):
        self.db.close()

    def _create_sample_fcl(self) -> CargoShippingRecord:
        schema = CargoShippingCreate(
            import_file_id=self.file_1_id,
            shipment_type="FCL",
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSCU1234567",
                    seal_no="SL-9901",
                    container_type="40HC",
                    tare_weight_kg=3800.0,
                    net_weight_kg=22000.0,
                    gross_weight_kg=25800.0,
                    container_assignment_date="2026-09-01",
                    arrival_at_supplier_at="2026-09-02T10:00:00Z",
                    loading_start_at="2026-09-02T12:00:00Z",
                    loading_end_at="2026-09-02T16:00:00Z",
                    port_gate_in_at="2026-09-03T08:00:00Z",
                )
            ],
            status="Loaded & Sealed",
        )
        return create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=False)

    def test_put_containers_on_dual_approved_gives_409(self):
        """PUT of containers on Dual Approved status raises 409 Conflict."""
        record = self._create_sample_fcl()

        # Approve Level 1 and Level 2 -> status becomes Dual Approved
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        submit_level2_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="mgmt_head")
        self.db.refresh(record)
        self.assertEqual(record.status, "Dual Approved")

        # Attempt to update containers via PUT
        update_schema = CargoShippingUpdate(
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSCU1234567",
                    seal_no="SL-NEW-SEAL",
                    container_type="40HC",
                    tare_weight_kg=3800.0,
                    net_weight_kg=23000.0,
                    gross_weight_kg=26800.0,
                )
            ]
        )
        with self.assertRaises(HTTPException) as cm:
            update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_schema, auto_advance_lifecycle=False)
        self.assertEqual(cm.exception.status_code, 409)
        self.assertIn("لا يمكن تعديل بيانات الحاويات", cm.exception.detail)

    def test_patch_container_tracking_on_dual_approved_gives_409(self):
        """PATCH container loading tracking on Dual Approved status raises 409 Conflict."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        submit_level2_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="mgmt_head")

        patch_payload = ContainerLoadingTrackingUpdate(
            container_no="MSCU1234567",
            seal_no="SL-CHANGED-SEAL",
        )
        with self.assertRaises(HTTPException) as cm:
            update_container_loading_tracking_service(
                self.db, record.cargo_shipping_id, "MSCU1234567", patch_payload, user="ops_lead"
            )
        self.assertEqual(cm.exception.status_code, 409)

    def test_post_lcl_tracking_on_dual_approved_gives_409(self):
        """POST LCL loading tracking on Dual Approved status raises 409 Conflict."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        submit_level2_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="mgmt_head")

        lcl_payload = LclLoadingTrackingItem(
            cfs_warehouse_name="Alex CFS",
            port_gate_in_at="2026-09-05T10:00:00Z",
        )
        with self.assertRaises(HTTPException) as cm:
            update_lcl_loading_tracking_service(self.db, record.cargo_shipping_id, lcl_payload, user="ops_lead")
        self.assertEqual(cm.exception.status_code, 409)

    def test_level1_reset_on_container_change_before_dual_approved(self):
        """Before Dual Approved, changing containers or seals resets Level 1 approval to Pending with note."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(
            self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True, notes="Initial level 1 ok"), user="ops_lead"
        )
        self.db.refresh(record)
        self.assertEqual(record.level1_approval_status, "Approved")
        self.assertEqual(record.dual_approval_status, "In Progress")

        # Edit containers (changing seal_no)
        update_schema = CargoShippingUpdate(
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSCU1234567",
                    seal_no="SL-MODIFIED-SEAL",
                    container_type="40HC",
                    tare_weight_kg=3800.0,
                    net_weight_kg=22000.0,
                    gross_weight_kg=25800.0,
                )
            ]
        )
        updated = update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_schema, auto_advance_lifecycle=False)
        self.assertEqual(updated.level1_approval_status, "Pending")
        self.assertEqual(updated.level2_approval_status, "Pending")
        self.assertEqual(updated.dual_approval_status, "Pending")
        self.assertIn("Initial level 1 ok", updated.level1_notes)
        self.assertIn("Approval reset", updated.level1_notes)

    def test_level1_reset_on_seal_patch_before_dual_approved(self):
        """Patching container seal_no before Dual Approved resets Level 1 approval to Pending."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        self.db.refresh(record)
        self.assertEqual(record.level1_approval_status, "Approved")

        # Patch seal_no
        patch_payload = ContainerLoadingTrackingUpdate(
            container_no="MSCU1234567",
            seal_no="SL-NEW-SEAL-99",
        )
        updated = update_container_loading_tracking_service(
            self.db, record.cargo_shipping_id, "MSCU1234567", patch_payload, user="ops_lead"
        )
        self.assertEqual(updated.level1_approval_status, "Pending")
        self.assertEqual(updated.dual_approval_status, "Pending")
        self.assertIn("Approval reset: the seal number", updated.level1_notes)

    def test_level1_not_reset_when_containers_unchanged(self):
        """PUT without modifying containers or seals preserves Level 1 approval."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        self.db.refresh(record)
        self.assertEqual(record.level1_approval_status, "Approved")

        # Re-send unchanged container data with notes update
        update_schema = CargoShippingUpdate(
            notes="Updated note only",
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MSCU1234567",
                    seal_no="SL-9901",
                    container_type="40HC",
                    tare_weight_kg=3800.0,
                    net_weight_kg=22000.0,
                    gross_weight_kg=25800.0,
                )
            ],
        )
        updated = update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_schema, auto_advance_lifecycle=False)
        self.assertEqual(updated.level1_approval_status, "Approved")
        self.assertEqual(updated.dual_approval_status, "In Progress")

    def test_cargox_checklist_fcl_without_seal_fails(self):
        """In FCL, container without seal fails BL match rule."""
        schema = CargoShippingCreate(
            import_file_id=self.file_1_id,
            shipment_type="FCL",
            containers_loading_data=[
                ContainerLoadingItem(
                    container_no="MEDU9876543",
                    seal_no="",  # Missing seal
                    container_type="40HC",
                )
            ],
        )
        record = create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=False)
        checked = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        rules = {r["rule_name"]: r for r in checked.cargox_exchange_data["verification_checklist"]}
        bl_rule = rules["Bill of Lading (BL) & Container List Match"]
        self.assertFalse(bl_rule["passed"])
        self.assertIn("missing seal numbers", bl_rule["details"])

    def test_cargox_checklist_fcl_with_seal_passes(self):
        """In FCL, container with seal passes BL match rule."""
        record = self._create_sample_fcl()
        checked = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        rules = {r["rule_name"]: r for r in checked.cargox_exchange_data["verification_checklist"]}
        bl_rule = rules["Bill of Lading (BL) & Container List Match"]
        self.assertTrue(bl_rule["passed"])
        self.assertIn("Container numbers & seal numbers populated", bl_rule["details"])

    def test_cargox_checklist_lcl_with_gate_in_passes(self):
        """In LCL, presence of port_gate_in_at passes BL match rule."""
        schema = CargoShippingCreate(
            import_file_id=self.file_1_id,
            shipment_type="LCL",
            lcl_tracking_data={
                "cfs_warehouse_name": "Sokhna CFS",
                "port_gate_in_at": "2026-09-04T14:30:00Z",
            },
        )
        record = create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=False)
        checked = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        rules = {r["rule_name"]: r for r in checked.cargox_exchange_data["verification_checklist"]}
        bl_rule = rules["Bill of Lading (BL) & Container List Match"]
        self.assertTrue(bl_rule["passed"])
        self.assertIn("gated in at port", bl_rule["details"])

    def test_cargox_checklist_lcl_without_gate_in_fails(self):
        """In LCL, missing port_gate_in_at fails BL match rule."""
        schema = CargoShippingCreate(
            import_file_id=self.file_1_id,
            shipment_type="LCL",
            lcl_tracking_data={
                "cfs_warehouse_name": "Sokhna CFS",
            },
        )
        record = create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=False)
        checked = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        rules = {r["rule_name"]: r for r in checked.cargox_exchange_data["verification_checklist"]}
        bl_rule = rules["Bill of Lading (BL) & Container List Match"]
        self.assertFalse(bl_rule["passed"])
        self.assertIn("missing", bl_rule["details"])

    def test_cargox_checklist_air_passes_not_applicable(self):
        """In Air shipment, BL match rule passes with details NOT_APPLICABLE."""
        schema = CargoShippingCreate(
            import_file_id=self.file_1_id,
            shipment_type="Air",
        )
        record = create_cargo_shipping_service(self.db, schema, auto_advance_lifecycle=False)
        checked = execute_cargox_checklist_service(self.db, record.cargo_shipping_id)
        rules = {r["rule_name"]: r for r in checked.cargox_exchange_data["verification_checklist"]}
        bl_rule = rules["Bill of Lading (BL) & Container List Match"]
        self.assertTrue(bl_rule["passed"])
        self.assertEqual(bl_rule["details"], "NOT_APPLICABLE")

    def test_booking_link_checks_create_and_update(self):
        """booking_id must exist, be active, and belong to the same import_file_id; else 422."""
        # 1. Non-existent booking on create -> 422
        schema_invalid_id = CargoShippingCreate(
            import_file_id=self.file_1_id,
            booking_id=999999,
        )
        with self.assertRaises(HTTPException) as cm:
            create_cargo_shipping_service(self.db, schema_invalid_id, auto_advance_lifecycle=False)
        self.assertEqual(cm.exception.status_code, 422)
        self.assertEqual(cm.exception.detail, "الحجز لا يخص نفس ملف الاستيراد")

        # 2. Inactive booking on create -> 422
        schema_inactive = CargoShippingCreate(
            import_file_id=self.file_1_id,
            booking_id=self.booking_inactive_id,
        )
        with self.assertRaises(HTTPException) as cm:
            create_cargo_shipping_service(self.db, schema_inactive, auto_advance_lifecycle=False)
        self.assertEqual(cm.exception.status_code, 422)
        self.assertEqual(cm.exception.detail, "الحجز لا يخص نفس ملف الاستيراد")

        # 3. Foreign booking (belongs to file 2, not file 1) on create -> 422
        schema_foreign = CargoShippingCreate(
            import_file_id=self.file_1_id,
            booking_id=self.booking_2_id,
        )
        with self.assertRaises(HTTPException) as cm:
            create_cargo_shipping_service(self.db, schema_foreign, auto_advance_lifecycle=False)
        self.assertEqual(cm.exception.status_code, 422)
        self.assertEqual(cm.exception.detail, "الحجز لا يخص نفس ملف الاستيراد")

        # 4. Valid booking on create -> succeeds
        schema_valid = CargoShippingCreate(
            import_file_id=self.file_1_id,
            booking_id=self.booking_1_id,
        )
        record = create_cargo_shipping_service(self.db, schema_valid, auto_advance_lifecycle=False)
        self.assertEqual(record.booking_id, self.booking_1_id)

        # 5. Foreign booking on update -> 422
        update_foreign = CargoShippingUpdate(booking_id=self.booking_2_id)
        with self.assertRaises(HTTPException) as cm:
            update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_foreign, auto_advance_lifecycle=False)
        self.assertEqual(cm.exception.status_code, 422)
        self.assertEqual(cm.exception.detail, "الحجز لا يخص نفس ملف الاستيراد")

        # 6. Valid booking on update -> succeeds
        update_valid = CargoShippingUpdate(booking_id=self.booking_1_id, notes="Updated with booking")
        updated = update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_valid, auto_advance_lifecycle=False)
        self.assertEqual(updated.booking_id, self.booking_1_id)
        self.assertEqual(updated.notes, "Updated with booking")

    def test_put_non_container_fields_on_dual_approved_succeeds(self):
        """Updating non-container fields (like notes) on Dual Approved records succeeds."""
        record = self._create_sample_fcl()
        submit_level1_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel1Submit(approved=True), user="ops_lead")
        submit_level2_approval_service(self.db, record.cargo_shipping_id, DualApprovalLevel2Submit(approved=True), user="mgmt_head")
        self.assertEqual(record.status, "Dual Approved")

        update_notes = CargoShippingUpdate(notes="Important tracking notice")
        updated = update_cargo_shipping_service(self.db, record.cargo_shipping_id, update_notes, auto_advance_lifecycle=False)
        self.assertEqual(updated.notes, "Important tracking notice")
        self.assertEqual(updated.status, "Dual Approved")


if __name__ == "__main__":
    unittest.main()
