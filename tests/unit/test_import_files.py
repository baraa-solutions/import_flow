"""
Unit Tests for Import Files Master & Tracking Module (ملفات الشحنات الاستيرادية)
"""

import main
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.purchase_orders.model import PurchaseOrder
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ImportFileCreate, ImportFileUpdate
import modules.import_files.service as service
import modules.import_files.repository as repo
from fastapi import HTTPException


@pytest.fixture
def db_session():
    """Creates in-memory SQLite DB fixture."""
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    # Seed company, supplier, incoterm & projects
    comp1 = ImportCompany(company_id=1, importer_name="Egyptian Import Co", vat_id="100-200-300", registration_number="12345", address="Cairo", country="Egypt", importer_id="IMP-001", importer_id_expiry=date(2028,1,1), vat_id_expiry=date(2028,1,1), registration_expiry=date(2028,1,1))
    comp2 = ImportCompany(company_id=2, importer_name="Delta Trading", vat_id="200-300-400", registration_number="67890", address="Alex", country="Egypt", importer_id="IMP-002", importer_id_expiry=date(2028,1,1), vat_id_expiry=date(2028,1,1), registration_expiry=date(2028,1,1))
    sup1 = Supplier(supplier_id=1, company_name="ABC China", supplier_code="SUP-01", supplier_type="Manufacturer", registration_type="Foreign Exporter", foreign_exporter_id="CN-99", foreign_exporter_country="China", foreign_exporter_country_code="CN", address="Shanghai")
    inco1 = Incoterm(incoterm_id=1, incoterm_code="FOB", incoterm_name="Free On Board", description="Seller delivers goods on board vessel")

    proj1 = Project(project_id=1, project_code="PRJ-01", project_name="Textile Expansion", project_owner="Kamal", company_id=1, supplier_id=1, incoterm_id=1, import_type="Direct Commercial")
    proj2 = Project(project_id=2, project_code="PRJ-02", project_name="Delta Factory", project_owner="Kamal", company_id=2, supplier_id=1, incoterm_id=1, import_type="Direct Commercial")
    db.add_all([comp1, comp2, sup1, inco1, proj1, proj2])
    db.commit()

    try:
        yield db
    finally:
        db.close()


class TestImportFilesBackend:
    def test_create_import_file_service_success(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068100",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            po_number="PO-1001",
            pi_number="PI-889",
            invoices_data=[
                {"invoice_no": "PI-889", "amount": 24500.0, "currency": "USD"},
                {"invoice_no": "INV-990", "amount": 24500.0, "currency": "USD"},
            ],
            packing_lists_data=[
                {"pl_no": "PL-889", "total_packages": 50, "gross_weight_kg": 12000.0}
            ],
            project_ids=[1],
            shipment_mode="Sea",
            incoterm_code="FOB",
            priority="High",
            shipment_category="New Purchase",
            required_eta=date(2026, 8, 15),
            selected_scenario="MSC Option",
            acid_number="1987654321098765432",
            estimated_cost=24500.0,
            owner="Kamal",
        )
        res = service.create_import_file_service(db_session, payload)

        assert res.import_file_id is not None
        assert res.custom_file_number == "6701068100"
        assert res.acid_number == "1987654321098765432"
        assert res.company_name == "Egyptian Import Co"
        assert res.supplier_name == "ABC China"
        assert len(res.invoices_data) == 2
        assert len(res.packing_lists_data) == 1
        assert res.owner == "Kamal"
        assert res.progress_percent == 25.0

    def test_multi_project_company_mismatch_raises_error(self, db_session):
        # Attempting to assign Project 2 (which belongs to Company 2) to an Import File for Company 1
        payload = ImportFileCreate(
            custom_file_number="6701069999",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            project_ids=[1, 2], # Project 2 is for Company 2!
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_import_file_service(db_session, payload)
        assert exc_info.value.status_code == 400
        assert "مرتبط بشركة مستوردة أخرى" in str(exc_info.value.detail)

    def test_formula_progression(self, db_session):
        payload = ImportFileCreate(
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            form4_no="F4-9988",
            form46_no="DEC46-1122",
        )
        file_obj = service.create_import_file_service(db_session, payload)
        assert file_obj.current_module == "BP-019 Prepare Customs Declaration 46"
        assert file_obj.progress_percent == 65.0

    def test_master_report_summary(self, db_session):
        payload1 = ImportFileCreate(
            custom_file_number="6701068101",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            estimated_cost=10000.0,
            status="Open",
        )
        payload2 = ImportFileCreate(
            custom_file_number="6701068102",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="XYZ Germany",
            estimated_cost=15000.0,
            status="In Progress",
        )
        service.create_import_file_service(db_session, payload1)
        service.create_import_file_service(db_session, payload2)

        report = service.generate_master_report_service(db_session)
        assert report.total_import_files == 2
        assert report.open_files_count == 1
        assert report.in_progress_count == 1
        assert report.total_estimated_cost == 25000.0
        assert len(report.files) == 2

    def test_soft_delete_import_file(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068103",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
        )
        created = service.create_import_file_service(db_session, payload)
        file_id = created.import_file_id

        success = repo.soft_delete_import_file(db_session, file_id)
        assert success is True
        assert repo.get_import_file_by_id(db_session, file_id) is None

    def test_close_shipment_early_service(self, db_session):
        from modules.import_files.schemas import CloseShipmentSubmit
        payload = ImportFileCreate(
            custom_file_number="6701068104",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
        )
        created = service.create_import_file_service(db_session, payload)

        close_payload = CloseShipmentSubmit(
            closure_reason="إلغاء الطلب من المورد الخارجي لظروف الشحن",
            closed_at_phase="Phase 3 - Import Documentation",
        )
        closed_file = service.close_shipment_service(db_session, created.import_file_id, close_payload)

        assert closed_file.status == "Closed"
        assert closed_file.current_module == "Phase 10 - Import File Closure & Historical Archive"
        assert closed_file.progress_percent == 100.0
        assert closed_file.closure_reason == "إلغاء الطلب من المورد الخارجي لظروف الشحن"
        assert closed_file.closed_at_phase == "Phase 3 - Import Documentation"

    def test_reopen_shipment_service(self, db_session):
        from modules.import_files.schemas import CloseShipmentSubmit, ReopenShipmentSubmit
        payload = ImportFileCreate(
            custom_file_number="6701068105",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
        )
        created = service.create_import_file_service(db_session, payload)

        close_payload = CloseShipmentSubmit(
            closure_reason="إلغاء المؤقت",
            closed_at_phase="Phase 4 - Freight Booking",
        )
        closed_file = service.close_shipment_service(db_session, created.import_file_id, close_payload)
        assert closed_file.status == "Closed"

        reopen_payload = ReopenShipmentSubmit(
            reopen_reason="تم حل المشكلة وتحديد موعد إبحار جديد مع الخط الملاحي",
        )
        reopened_file = service.reopen_shipment_service(db_session, created.import_file_id, reopen_payload)

        assert reopened_file.status == "In Progress"
        assert reopened_file.current_module == "Phase 4 - Freight Booking"
        assert reopened_file.closure_reason is None
        assert reopened_file.closed_at_phase is None

    def test_invoices_currency_mismatch_raises_error(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068199",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            invoices_data=[
                {"invoice_no": "PI-001", "amount": 10000.0, "currency": "EUR"},
                {"invoice_no": "PI-002", "amount": 5000.0, "currency": "USD"},
            ],
        )
        with pytest.raises(HTTPException) as exc_info:
            service.create_import_file_service(db_session, payload)
        assert exc_info.value.status_code == 400
        assert "يجب أن تكون جميع الفواتير المربوطة بملف الشحنة بنفس العملة الموحدة" in exc_info.value.detail

    def test_create_import_file_starting_from_clearance_stage(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068177",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            initial_starting_step="STEP_13",
            initial_starting_stage="Phase 5 - Port Operations & Clearance",
        )
        created = service.create_import_file_service(db_session, payload)
        assert created.initial_starting_step == "STEP_13"
        assert created.current_stage == "Phase 5 - Port Operations & Clearance"
        assert created.progress_percent == 75.0
        assert "BP-013" in created.current_module

    def test_hold_and_resume_import_file(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068188",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
            initial_starting_step="STEP_06",
        )
        created = service.create_import_file_service(db_session, payload)

        # Hold shipment
        held = service.hold_import_file_service(
            db_session,
            created.import_file_id,
            hold_reason="إيقاف مؤقت لحين مراجعة اعتماد البنك المركزي",
            hold_notes="مطلوب موافقة مدير الاستيراد",
        )
        assert held.status == "On Hold"
        assert held.hold_reason == "إيقاف مؤقت لحين مراجعة اعتماد البنك المركزي"
        assert held.paused_at_stage == "Phase 3 - Booking & Doc Prep"

        # Resume shipment
        resumed = service.resume_import_file_service(
            db_session,
            created.import_file_id,
            resume_notes="تم استلام موافقة البنك واستئناف العمل",
        )
        assert resumed.status == "In Progress"
        assert resumed.hold_reason is None

    def test_hold_shipment_at_specific_stage(self, db_session):
        payload = ImportFileCreate(
            custom_file_number="6701068199",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
        )
        created = service.create_import_file_service(db_session, payload)

        held = service.hold_import_file_service(
            db_session,
            created.import_file_id,
            hold_reason="في انتظار تعديل مانيفست الشحن",
            stage_name="مراجعة وتدقيق مسودات مستندات الشحن وكارجو إكس",
            step_name="STEP-09",
        )
        assert held.status == "On Hold"
        # Single-language storage: the Arabic title resolves to the English phase title of the step code,
        # and the file's user notes are no longer overwritten by the system hold text.
        assert held.paused_at_stage == "3. Booking & Doc Prep"
        assert held.paused_at_step == "STEP_09"
        assert held.notes == created.notes

        resumed = service.resume_import_file_service(
            db_session,
            created.import_file_id,
            resume_notes="تم تعديل المانيفست بنجاح",
        )
        assert resumed.status == "In Progress"
        assert resumed.hold_reason is None

    def test_clone_import_file_audit_user_tracking(self, db_session):
        from modules.import_files.schemas import CloneImportFileRequest
        payload = ImportFileCreate(
            custom_file_number="6701068200",
            company_id=1,
            company_name="Egyptian Import Co",
            supplier_name="ABC China",
        )
        created = service.create_import_file_service(db_session, payload, current_user="ahmed_ops")
        assert created.created_by == "ahmed_ops"
        assert created.owner == "ahmed_ops"

        clone_req = CloneImportFileRequest(
            target_import_file_code="IMP-2026-TESTCLONE",
            copy_items=False,
            notes="Cloned for testing audit trail",
        )
        cloned = service.clone_import_file_service(
            db_session,
            created.import_file_id,
            clone_req,
            current_user="sarah_logistics",
        )
        assert cloned.import_file_code == "IMP-2026-TESTCLONE"
        assert cloned.created_by == "sarah_logistics"
        assert cloned.updated_by == "sarah_logistics"
        assert cloned.cloned_from_id == created.import_file_id



