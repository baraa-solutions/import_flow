import unittest
from datetime import date, datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

from database.database import Base
import modules.transport_locations.model as loc_models
import modules.freight_quotations.model as rfq_models
import modules.projects.model as proj_models
import modules.incoterms.model as incoterm_models
import modules.currencies.model as curr_models
import modules.customs_tariff.model as tariff_models
import modules.shipping_scenarios.model as scen_models
import modules.import_files.model as imp_models
import modules.import_companies.model as comp_models
import modules.suppliers.model as supp_models
import modules.external_service_providers.model as partner_models
import modules.purchase_orders.model as po_models
import modules.freight_booking.model as fb_models
import modules.cargo_shipping.model as cs_models
import modules.import_documentation.model as doc_models

from modules.import_documentation.schemas import (
    POFinalAdjustmentRequest,
    POReconciliationItem,
    DraftBLComparisonRequest,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    COOComparisonRequest,
    CertificateOfOriginReviewCreate,
    InspectionComparisonRequest,
    InspectionCertificateReviewCreate,
)
import modules.import_documentation.service as service
from modules.common import enum_codes


class TestDraftReviewsAndCompliance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(cls.engine)
        cls.SessionLocal = sessionmaker(bind=cls.engine)

    def setUp(self):
        Base.metadata.drop_all(self.engine)
        Base.metadata.create_all(self.engine)
        self.db = self.SessionLocal()

        # Seed Company
        self.company = comp_models.ImportCompany(
            importer_name="ECO ASSOCIATES EGYPT",
            importer_id="IC-998877",
            importer_id_expiry=date.today() + timedelta(days=90),
            vat_id="EG-123456789",
            vat_id_expiry=date.today() + timedelta(days=90),
            registration_number="CR-554433",
            registration_expiry=date.today() + timedelta(days=90),
            country="Egypt",
            address="15 Industrial Zone, Cairo, Egypt",
            is_active=True,
        )
        self.db.add(self.company)
        self.db.flush()

        # Seed Supplier
        self.supplier = supp_models.Supplier(
            company_name="Siemens Mobility GmbH",
            supplier_code="SUP-001",
            supplier_type="Manufacturer",
            registration_type="VAT / Tax ID",
            foreign_exporter_id="DE123456789",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
            address="Werner-von-Siemens-Strasse 1, Munich, Germany",
            is_active=True,
        )
        self.db.add(self.supplier)
        self.db.flush()

        # Seed Incoterm & Currency
        self.incoterm = incoterm_models.Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
        self.currency = curr_models.Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        self.db.add_all([self.incoterm, self.currency])
        self.db.flush()

        # Seed Project
        self.project = proj_models.Project(
            project_code="PRJ-TEST-01",
            project_name="Test Project Solar",
            project_owner="Eng. Ali",
            company_id=self.company.company_id,
            supplier_id=self.supplier.supplier_id,
            incoterm_id=self.incoterm.incoterm_id,
            is_active=True,
        )
        self.db.add(self.project)
        self.db.flush()

        # Seed Import File
        self.import_file = imp_models.ImportFile(
            import_file_code="6701068100-HSR",
            company_id=self.company.company_id,
            company_name=self.company.importer_name,
            supplier_id=self.supplier.supplier_id,
            supplier_name=self.supplier.company_name,
            acid_number="9876543210123456789",
            is_active=True,
        )
        self.db.add(self.import_file)
        self.db.flush()

        # Seed ACID Session
        self.acid_session = doc_models.AcidRegistrationSession(
            acid_code="ACID-2026-0001",
            acid_number="9876543210123456789",
            import_file_id=self.import_file.import_file_id,
            importer_name=self.company.importer_name,
            importer_tax_id=self.company.vat_id,
            exporter_name=self.supplier.company_name,
            exporter_reg_id="DE123456789",
            exporter_country="Germany",
            proforma_invoice_no="PI-2026-001",
            pol_name="Hamburg Port",
            pod_name="Alexandria Port",
            expiry_date=date.today() + timedelta(days=75),
            status="Verified",
            is_active=True,
        )
        self.db.add(self.acid_session)
        self.db.flush()

        # Seed Freight Booking
        self.booking = fb_models.ShipmentBooking(
            booking_code="BKG-2026-0001",
            import_file_id=self.import_file.import_file_id,
            booking_confirmation_no="BKG-MSC-99001",
            freight_forwarder_name="Kuehne+Nagel Logistics",
            shipping_line_name="MSC Mediterranean Shipping",
            vessel_name="MSC ISABELLA",
            pol_name="Hamburg Port",
            pod_name="Alexandria Port",
            etd=datetime.now(),
            eta=datetime.now() + timedelta(days=20),
            shipment_type="Ocean FCL",
            is_active=True,
        )
        self.db.add(self.booking)
        self.db.flush()

        # Seed Cargo Shipping & Container Loading from Phase 5
        self.cargo_shipping = cs_models.CargoShippingRecord(
            cargo_shipping_code="SHP-2026-0001",
            import_file_id=self.import_file.import_file_id,
            shipment_type="FCL",
            containers_loading_data=[
                {
                    "container_no": "MSCU1234567",
                    "seal_no": "SL-99001",
                    "container_type": "40HC",
                    "gross_weight_kg": 24500.0,
                    "net_weight_kg": 20700.0,
                    "vgm_status": "Submitted",
                }
            ],
            status="Cargo Ready",
            is_active=True,
        )
        self.db.add(self.cargo_shipping)
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def test_po_final_reconciliation_service(self):
        req = POFinalAdjustmentRequest(
            import_file_id=self.import_file.import_file_id,
            final_invoice_number="INV-FINAL-2026-001",
            final_packing_list_number="PL-FINAL-2026-001",
            items=[
                POReconciliationItem(
                    item_code="SIEM-TRAIN-01",
                    description="Industrial Control Unit",
                    package_type="Carton",
                    initial_quantity=100.0,
                    final_quantity=105.0,
                    initial_unit_price=250.0,
                    unit_price=260.0,
                    final_unit_price=260.0,
                    initial_packages_count=10.0,
                    final_packages_count=12.0,
                    initial_net_weight_kg=20000.0,
                    final_net_weight_kg=20700.0,
                    initial_gross_weight_kg=23500.0,
                    final_gross_weight_kg=24500.0,
                    initial_cbm=55.0,
                    final_cbm=58.4,
                )
            ]
        )
        res = service.reconcile_po_final_adjustments_service(self.db, req)
        self.assertEqual(res["status"], "success")
        self.assertEqual(res["total_final_amount"], 105.0 * 260.0)
        self.assertEqual(res["items"][0]["variance_percentage"], 5.0)
        self.assertEqual(res["items"][0]["price_variance_percentage"], 4.0)
        self.assertEqual(res["items"][0]["package_type"], "Carton")
        self.assertEqual(res["items"][0]["final_packages_count"], 12.0)

    def test_draft_bl_comparison_and_blocking_rules(self):
        # 1. Test Matching Draft
        draft_fields_matching = {
            "booking_no": "BKG-MSC-99001",
            "hbl_no": "HBL-KN-2026-001",
            "mbl_no": "MEDU-MBL-99001",
            "consignee": "ECO ASSOCIATES EGYPT\nTax ID: EG-123456789\n15 Industrial Zone, Cairo, Egypt",
            "shipper": "Siemens Mobility GmbH\nWerner-von-Siemens-Strasse 1, Munich, Germany",
            "total_gross_weight_kg": 24510.0, # Within 0.5% tolerance
            "cbm": 58.5,
            "containers": [{"container_no": "MSCU1234567", "seal_no": "SL-99001"}],
        }
        comp_req = DraftBLComparisonRequest(
            import_file_id=self.import_file.import_file_id,
            draft_fields=draft_fields_matching,
        )
        res = service.compare_draft_bl_service(self.db, comp_req)
        self.assertFalse(res["has_blocking_mismatch"])
        self.assertEqual(len(res["blocking_reasons"]), 0)

        # 2. Test Critical Blocking Mismatch (Different Booking No or Container No)
        draft_fields_mismatch = {
            "booking_no": "WRONG-BKG-888",
            "hbl_no": "HBL-KN-2026-001",
            "mbl_no": "MEDU-MBL-99001",
            "consignee": "ECO ASSOCIATES EGYPT",
            "containers": [{"container_no": "WRONG_CONTAINER_999", "seal_no": "SL-99001"}],
        }
        comp_req_bad = DraftBLComparisonRequest(
            import_file_id=self.import_file.import_file_id,
            draft_fields=draft_fields_mismatch,
        )
        res_bad = service.compare_draft_bl_service(self.db, comp_req_bad)
        self.assertTrue(res_bad["has_blocking_mismatch"])
        # English text + coded twin (same order); no Arabic stored.
        self.assertIn("Critical mismatch in Booking Number", res_bad["blocking_reasons"])
        self.assertEqual(len(res_bad["blocking_reasons"]), len(res_bad["blocking_reasons_coded"]))
        self.assertIn(
            {"code": "DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH", "params": {"field_enum_draft_bl_field": "BOOKING_NO"}},
            res_bad["blocking_reasons_coded"],
        )
        self.assertFalse(any(enum_codes.contains_arabic(r) for r in res_bad["blocking_reasons"]))
        self.assertIn("Subject: Urgent: Draft B/L Correction Request", res_bad["correction_request_letter"])

    def test_draft_bl_blocking_reasons_coded_for_empty_critical_field(self):
        from modules.common.system_messages import is_known_code, render_en

        res = service.compare_draft_bl_service(self.db, DraftBLComparisonRequest(
            import_file_id=self.import_file.import_file_id,
            draft_fields={"acid_number": "", "booking_no": "WRONG-BKG-888"},
        ))
        self.assertTrue(res["has_blocking_mismatch"])
        coded = res["blocking_reasons_coded"]
        self.assertIn(
            {"code": "DOC_DRAFT_BLOCKING_FIELD_EMPTY", "params": {"field_enum_draft_bl_field": "ACID_NUMBER"}}, coded
        )
        self.assertIn("Critical field is empty: ACID Number", res["blocking_reasons"])
        for text, item in zip(res["blocking_reasons"], coded):
            self.assertTrue(is_known_code(item["code"]))
            self.assertTrue(enum_codes.is_code(enum_codes.DRAFT_BL_FIELD, item["params"]["field_enum_draft_bl_field"]))
            self.assertEqual(text, render_en(item["code"], item["params"], "reason"))

    def test_draft_bl_blocking_reasons_coded_persisted_and_dropped_on_text_edit(self):
        from modules.import_documentation.schemas import DraftBLReviewCreate, DraftBLReviewUpdate

        review = service.create_draft_bl_review_service(self.db, DraftBLReviewCreate(
            import_file_id=self.import_file.import_file_id,
            draft_input_data={"acid_number": "", "booking_no": "WRONG-BKG-888"},
        ))
        self.assertTrue(review.blocking_reasons_coded)
        self.assertEqual(len(review.blocking_reasons), len(review.blocking_reasons_coded))
        self.assertFalse(any(enum_codes.contains_arabic(r) for r in review.blocking_reasons))

        # A client that rewrites the text without codes invalidates the stale codes.
        updated = service.update_draft_bl_review_service(
            self.db, review.bl_review_id, DraftBLReviewUpdate(blocking_reasons=["manual note"])
        )
        self.assertEqual(updated.blocking_reasons, ["manual note"])
        self.assertIsNone(updated.blocking_reasons_coded)

        # An unrelated update keeps them.
        review2 = service.update_draft_bl_review_service(
            self.db, review.bl_review_id, DraftBLReviewUpdate(
                blocking_reasons=["x"],
                blocking_reasons_coded=[{"code": "DOC_DRAFT_BLOCKING_FIELD_EMPTY",
                                         "params": {"field_enum_draft_bl_field": "POL"}}],
            )
        )
        service.update_draft_bl_review_service(self.db, review2.bl_review_id, DraftBLReviewUpdate(shipping_line="MSC"))
        self.db.refresh(review2)
        self.assertEqual(review2.blocking_reasons_coded[0]["params"]["field_enum_draft_bl_field"], "POL")

    def test_certificate_of_origin_comparison(self):
        coo_req = COOComparisonRequest(
            import_file_id=self.import_file.import_file_id,
            certificate_type="EUR.1",
            draft_fields={
                "exporter_name": "Siemens Mobility GmbH",
                "importer_name": "ECO ASSOCIATES EGYPT",
                "country_of_origin": "Germany",
                "destination_country": "Egypt",
                "invoice_number": "INV-2026-FINAL",
                "certificate_type": "EUR.1",
            }
        )
        res = service.compare_coo_service(self.db, coo_req)
        self.assertFalse(res["has_critical_mismatch"])
        self.assertEqual(res["status"], "Verified")

    def test_inspection_certificate_comparison(self):
        insp_req = InspectionComparisonRequest(
            import_file_id=self.import_file.import_file_id,
            inspection_type="COC (Certificate of Conformity)",
            inspection_agency="SGS",
            draft_fields={
                "inspection_agency": "SGS",
                "importer_name": "ECO ASSOCIATES EGYPT",
                "exporter_name": "Siemens Mobility GmbH",
                "regulatory_authority": "GOEIC (الهيئة العامة للرقابة على الصادرات والواردات)",
                "invoice_number": "INV-2026-FINAL",
                "standard_specification": "Egyptian Standard ES Egyptian Conformity",
            }
        )
        res = service.compare_inspection_cert_service(self.db, insp_req)
        self.assertFalse(res["has_critical_mismatch"])
        self.assertEqual(res["status"], "Verified")

    def test_acid_and_legal_docs_expiry_compliance_engine(self):
        # ETA is today + 20 days. Safety window is ETA + 30 days = today + 50 days.
        # Acid expires in today + 75 days -> Valid!
        # Import Card expires in today + 90 days -> Valid!
        res = service.check_acid_and_company_docs_validity_service(self.db, self.import_file.import_file_id)
        self.assertEqual(res.overall_compliance_status, "COMPLIANT")
        self.assertFalse(res.has_critical_alerts)

        # Now simulate ACID expiring before safety window (e.g. today + 35 days < 50 days)
        self.acid_session.expiry_date = date.today() + timedelta(days=35)
        self.db.commit()

        res_alert = service.check_acid_and_company_docs_validity_service(self.db, self.import_file.import_file_id)
        self.assertEqual(res_alert.overall_compliance_status, "CRITICAL_ACTION_REQUIRED")
    def test_draft_bl_5_stages_and_dual_approval(self):
        from modules.import_documentation.schemas import (
            DraftBLChecklistItem,
            DualApprovalRequest,
            NewDraftVersionRequest,
        )

        # 1. Create a Draft B/L Review Session
        create_payload = DraftBLReviewCreate(
            import_file_id=self.import_file.import_file_id,
            draft_bl_number="MEDU-TEST-5STAGE",
            booking_number="BKG-MSC-99001",
            vessel_name="MSC TEST VESSEL",
            voyage_number="0VEC1W1MA",
            freight_terms="Freight Prepaid",
            place_of_delivery="Alexandria Port, Egypt",
            measurement_cbm=58.5,
            net_weight_kg=20700.0,
            packages_count=24,
            container_summary="MSCU1234567 / SL-99001",
            stage="Stage 1: Draft Review",
            checklist_data=[
                DraftBLChecklistItem(
                    field_key="vessel_name",
                    field_label_ar="اسم السفينة",
                    field_label_en="Vessel Name",
                    source_entity="Final Booking",
                    system_value="MSC TEST VESSEL",
                    draft_value="WRONG VESSEL",
                    status="Incorrect",
                    required_correction="Correct vessel name to MSC TEST VESSEL",
                    reason="Typo in draft",
                    responsible_party="Shipping Provider",
                ),
                DraftBLChecklistItem(
                    field_key="booking_no",
                    field_label_ar="رقم الحجز",
                    field_label_en="Booking No",
                    source_entity="Final Booking",
                    system_value="BKG-MSC-99001",
                    draft_value="BKG-MSC-99001",
                    status="Correct",
                    responsible_party="Shipping Provider",
                )
            ]
        )
        session = service.create_draft_bl_review_service(self.db, create_payload)
        self.assertEqual(session.stage, "Stage 2: Revision Required")
        self.assertEqual(session.open_discrepancies_count, 1)
        self.assertEqual(len(session.revision_report_data), 1)
        self.assertEqual(session.revision_report_data[0]["item"], "اسم السفينة")

        # 2. Test Dual Approval Blocking when Stage is not Stage 4
        dual_req = DualApprovalRequest(
            bl_review_id=session.bl_review_id,
            role="importer",
            action="Approved",
            approved_by="Kamal",
        )
        with self.assertRaises(HTTPException):
            service.process_dual_approval_service(self.db, dual_req)

        # 3. Fix the Checklist Item (All Correct -> Transitions to Stage 4: Dual Approval)
        fixed_items = [
            DraftBLChecklistItem(
                field_key="vessel_name",
                field_label_ar="اسم السفينة",
                field_label_en="Vessel Name",
                source_entity="Final Booking",
                system_value="MSC TEST VESSEL",
                draft_value="MSC TEST VESSEL",
                status="Correct",
                responsible_party="Shipping Provider",
            ),
            DraftBLChecklistItem(
                field_key="booking_no",
                field_label_ar="رقم الحجز",
                field_label_en="Booking No",
                source_entity="Final Booking",
                system_value="BKG-MSC-99001",
                draft_value="BKG-MSC-99001",
                status="Correct",
                responsible_party="Shipping Provider",
            )
        ]
        updated = service.update_draft_bl_checklist_service(self.db, session.bl_review_id, fixed_items, "Kamal")
        self.assertEqual(updated.stage, "Stage 4: Dual Approval")
        self.assertEqual(updated.open_discrepancies_count, 0)
        self.assertEqual(len(updated.revision_report_data), 0)

        # 4. Importer Approval
        app1 = service.process_dual_approval_service(self.db, dual_req)
        self.assertEqual(app1.importer_approval_status, "Approved")
        self.assertEqual(app1.broker_approval_status, "Pending")
        self.assertEqual(app1.stage, "Stage 4: Dual Approval")

        # 5. Customs Broker Approval -> Transitions to Stage 5: Final
        broker_req = DualApprovalRequest(
            bl_review_id=session.bl_review_id,
            role="customs_broker",
            action="Approved",
            approved_by="Ahmed Broker",
        )
        app2 = service.process_dual_approval_service(self.db, broker_req)
        self.assertEqual(app2.broker_approval_status, "Approved")
        self.assertEqual(app2.stage, "Stage 5: Final")
        self.assertEqual(app2.status, "FINAL")

        # 6. Branch into New Draft Version (Stage 3 - Locks unchanged previously approved items)
        new_ver_req = NewDraftVersionRequest(
            parent_session_id=session.bl_review_id,
            draft_fields={
                "vessel_name": "MSC TEST VESSEL",
                "booking_no": "BKG-MSC-99001",
            }
        )
        v2 = service.create_new_draft_version_service(self.db, new_ver_req)
        self.assertEqual(v2.version_number, 2)
        self.assertEqual(v2.stage, "Stage 3: Reviewed")
        vessel_item = next(c for c in v2.checklist_data if c["field_key"] == "vessel_name")
        self.assertTrue(vessel_item["is_locked"])

    def test_extract_text_from_uploaded_files(self):
        # 1. Test Text/CSV extraction
        raw_text_bytes = b"ACID: 7595528271019210013\nEGYPTIAN IMPORTER TAX ID: 759552827\nGross Cargo Weight: 20030.000 kgs\nFREIGHT PREPAID"
        extracted_txt = service.extract_text_from_uploaded_file("draft_bl.txt", raw_text_bytes)
        self.assertIn("7595528271019210013", extracted_txt)

        parsed = service.parse_draft_bl_raw_text(extracted_txt)
        self.assertEqual(parsed["acid_number"], "7595528271019210013")
        self.assertEqual(parsed["importer_tax_id"], "759552827")
        self.assertEqual(parsed["freight_terms"], "Freight Prepaid")
        self.assertEqual(parsed["total_gross_weight_kg"], 20030.0)

    def test_build_system_bl_snapshot_multi_po_multi_line_aggregation(self):
        import modules.purchase_orders.model as po_models
        from modules.purchase_orders.schemas import PurchaseOrderCreate, PackingListItemCreate
        from modules.purchase_orders.service import PurchaseOrderService

        po_srv = PurchaseOrderService(self.db)

        # PO 1 with 2 Packing List Items:
        # Line 1: 2 Pallets, 2250 kg Net, 2270 kg Gross, 39.99 CBM
        # Line 2: 2 Cartons (2 kg Net unit, 2 kg Gross unit) -> 4 kg Net, 4 kg Gross, 0.023 CBM
        po1 = po_srv.create(PurchaseOrderCreate(
            proforma_invoice_number="PI-PO1-MULTI",
            import_file_id=self.import_file.import_file_id,
            company_id=self.company.company_id,
            supplier_id=self.supplier.supplier_id,
            project_id=self.project.project_id,
            incoterm_id=self.incoterm.incoterm_id,
            currency_id=self.currency.currency_id,
            packing_list_items=[
                PackingListItemCreate(
                    hs_code="8471.30.00",
                    item_code="SOLAR-PANEL",
                    qty_pcs=2.0,
                    qty_pkg=2.0,
                    package_type="Pallet",
                    length_cm=200.0,
                    width_cm=100.0,
                    height_cm=100.0,
                    net_weight_unit_kg=1125.0,
                    gross_weight_unit_kg=1135.0,
                ),
                PackingListItemCreate(
                    hs_code="8504.40.90",
                    item_code="SPARE-CARTON",
                    qty_pcs=1.0,
                    qty_pkg=2.0,
                    package_type="Carton",
                    length_cm=35.0,
                    width_cm=25.0,
                    height_cm=26.0,
                    net_weight_unit_kg=2.0,
                    gross_weight_unit_kg=2.0,
                ),
            ],
        ))

        snapshot = service._build_system_bl_snapshot(self.db, self.import_file.import_file_id)

        # Multi-line & Multi-package aggregation assertions
        self.assertEqual(snapshot["qty_pkg"], 4)  # 2 Pallets + 2 Cartons = 4 Packages
        self.assertEqual(snapshot["total_net_weight_kg"], 2254.0)  # (2 * 1125) + (2 * 2) = 2250 + 4 = 2254.0 kg
        self.assertEqual(snapshot["total_gross_weight_kg"], 2274.0)  # (2 * 1135) + (2 * 2) = 2270 + 4 = 2274.0 kg
        self.assertAlmostEqual(snapshot["cbm"], 4.0455, places=2)  # (2 * 2.0 m³) + (2 * 0.02275 m³) = 4.0455 m³
        self.assertIn("SOLAR-PANEL", snapshot["goods_description"])
        self.assertIn("SPARE-CARTON", snapshot["goods_description"])


if __name__ == "__main__":
    unittest.main()
