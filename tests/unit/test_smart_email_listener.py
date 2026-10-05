"""
Unit Tests for Smart Email Listener (INT-EMAIL-010)
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.smart_email_listener.model import InboundEmailLog
from modules.smart_email_listener.schemas import (
    InboundEmailCreate,
    InboundEmailParsePreviewRequest,
    TaskRouteApprovalItem,
    TasksBatchApprovalRequest,
)
from modules.smart_email_listener.service import (
    preview_arrival_notice_service,
    process_inbound_email_service,
    approve_and_route_tasks_service,
)
import modules.smart_email_listener.repository as repo


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    company = ImportCompany(
        importer_name="شركة الفتح للاستيراد والتصدير",
        country="Egypt",
        address="القاهرة - مصر",
        importer_id="IMP-TEST-001",
        importer_id_expiry=date(2030, 1, 1),
        vat_id="100200300",
        vat_id_expiry=date(2030, 1, 1),
        registration_number="REG-998877",
        registration_expiry=date(2030, 1, 1),
    )
    supplier = Supplier(
        company_name="Global Steel Mills Ltd",
        supplier_code="SUP-GSM-001",
        supplier_type="Manufacturer",
        registration_type="Commercial Registration",
        foreign_exporter_id="EXP-GSM-001",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Hamburg, Germany",
    )
    carrier = ExternalServiceProvider(
        partner_code="PRV-MSK-001",
        partner_name="Maersk Line Egypt",
        partner_type="Shipping Line",
    )
    session.add_all([company, supplier, carrier])
    session.commit()

    import_file = ImportFile(
        import_file_code="IMP-2026-00088",
        company_id=company.company_id,
        company_name=company.importer_name,
        supplier_id=supplier.supplier_id,
        supplier_name=supplier.company_name,
        status="Open",
        current_stage="Phase 3 - Cargo Preparation & Shipping",
        required_eta=date(2026, 9, 20),
    )
    session.add(import_file)
    session.commit()

    from modules.import_documentation.model import CustomsDeclarationDraft
    decl = CustomsDeclarationDraft(
        declaration_code="DEC-2026-001",
        import_file_id=import_file.import_file_id,
        acid_number="1234567890123456789",
        bl_number="MSK9876543210",
        declaration_status="Draft Prepared",
    )
    session.add(decl)
    session.commit()

    yield session
    session.close()


class TestSmartEmailListener:
    def test_preview_arrival_notice_parsing(self):
        email_body = """
        DEAR CUSTOMER,
        PLEASE BE ADVISED THAT VESSEL MSC OSCAR VOYAGE 2401W
        IS SCHEDULED TO ARRIVE AT ALEXANDRIA PORT.
        BILL OF LADING: MEDU123456789
        ESTIMATED TIME OF ARRIVAL (ETA): 2026-09-25
        CONTAINERS:
        MSCU1234567
        MSCU7654321
        KINDLY ARRANGE PAYMENT OF DELIVERY ORDER CHARGES.
        """
        req = InboundEmailParsePreviewRequest(
            subject="ARRIVAL NOTICE - B/L: MEDU123456789 - MSC OSCAR",
            body_text=email_body,
        )
        result = preview_arrival_notice_service(req)

        assert result.extracted_bl_number == "MEDU123456789"
        assert result.extracted_eta == date(2026, 9, 25)
        assert result.extracted_vessel == "MSC OSCAR"
        assert result.extracted_voyage == "2401W"
        assert "MSCU1234567" in result.extracted_containers
        assert "MSCU7654321" in result.extracted_containers

    def test_process_inbound_email_with_matching_import_file(self, db_session):
        email_body = """
        Arrival Notice / Cargo Notification
        Vessel: MAERSK MC-KINNEY MOLLER
        Voyage: 007E
        B/L No: MSK9876543210
        ETA: 2026-09-28
        Container: MSKU9988776
        Please settle all terminal & delivery order fees.
        """
        email_create = InboundEmailCreate(
            sender_email="arrival@maersk.com",
            subject="Notice of Cargo Arrival MSK9876543210",
            body_text=email_body,
        )

        res = process_inbound_email_service(db_session, email_create, user="TestAgent")

        assert res.is_matched_file is True
        assert res.import_file_id is not None
        assert res.import_file_code == "IMP-2026-00088"
        assert res.extracted_bl_number == "MSK9876543210"
        assert res.extracted_eta == date(2026, 9, 28)
        assert res.payment_task_created is True
        assert res.task_id is not None

        # Verify ImportFile ETA updated
        matched_file = db_session.query(ImportFile).filter_by(import_file_id=res.import_file_id).first()
        assert matched_file.required_eta == date(2026, 9, 28)

        # Verify SmartTask created
        task = db_session.query(SmartTask).filter_by(task_id=res.task_id).first()
        assert task is not None
        assert task.title.startswith("Pay the delivery order charges")
        assert task.msg_code == "EMAIL_TASK_DELIVERY_ORDER_PAYMENT"
        assert task.import_file_code == "IMP-2026-00088"
        assert task.priority == "High"

        # Verify Email Log created
        logs = repo.get_email_logs(db_session)
        assert len(logs) == 1
        assert logs[0].extracted_bl_number == "MSK9876543210"
        assert logs[0].task_id == task.task_id

    def test_process_inbound_email_without_matching_import_file(self, db_session):
        email_body = """
        ARRIVAL NOTICE
        B/L: CMA9999999999
        ETA: 2026-10-05
        VESSEL: CMA CGM ANTOINE
        """
        email_create = InboundEmailCreate(
            sender_email="import@cma-cgm.com",
            subject="Arrival Notice CMA9999999999",
            body_text=email_body,
        )

        res = process_inbound_email_service(db_session, email_create, user="TestAgent")

        assert res.is_matched_file is False
        assert res.import_file_id is None
        assert res.extracted_bl_number == "CMA9999999999"
        assert res.payment_task_created is False
        assert res.task_id is None

        logs = repo.get_email_logs(db_session)
        assert len(logs) == 1
        assert logs[0].processing_status == "Unmatched_BL"

    def test_process_inbound_email_with_acid_match(self, db_session):
        email_body = """
        Dear Sir,
        Please note the status update for Egyptian customs declaration.
        ACID: 1234567890123456789
        Estimated arrival date is 2026-09-30.
        """
        email_create = InboundEmailCreate(
            sender_email="customs@cargo-egypt.com",
            subject="ACID Update 1234567890123456789",
            body_text=email_body,
        )
        res = process_inbound_email_service(db_session, email_create, user="TestAgent")

        assert res.is_matched_file is True
        assert res.import_file_id is not None
        assert res.import_file_code == "IMP-2026-00088"
        assert res.payment_task_created is True

    def test_process_inbound_email_with_project_name_match(self, db_session):
        # Update import file custom name
        file = db_session.query(ImportFile).filter_by(import_file_code="IMP-2026-00088").first()
        file.custom_file_number = "Monorail Orascom Project"
        db_session.commit()

        email_create = InboundEmailCreate(
            sender_email="shipping@orascom.com",
            subject="RE: Condenser Fan Failure - Monorail Orascom Project",
            body_text="Kindly check the attached shipping invoice and ETA.",
        )
        res = process_inbound_email_service(db_session, email_create, user="TestAgent")

        assert res.is_matched_file is True
        assert res.import_file_id == file.import_file_id
        assert res.payment_task_created is True

    def test_false_positive_words_excluded_from_bl(self):
        email_body = """
        BL signed by carrier.
        BL loading confirmed for tomorrow.
        BL description attached.
        BL uemail acknowledged.
        """
        req = InboundEmailParsePreviewRequest(
            subject="Documentation updates",
            body_text=email_body,
        )
        res = preview_arrival_notice_service(req)
        assert res.extracted_bl_number is None

    def test_batch_approve_and_route_tasks(self, db_session):
        file = db_session.query(ImportFile).filter_by(import_file_code="IMP-2026-00088").first()
        req = TasksBatchApprovalRequest(
            tasks=[
                TaskRouteApprovalItem(
                    import_file_id=file.import_file_id,
                    import_file_code=file.import_file_code,
                    title="سداد مصاريف إذن تسليم ملاحي معتمد",
                    description="تم الاعتماد من المستخدم وتوجيهه لفريق التخليص",
                    assigned_user="Clearance Team",
                    priority="Critical",
                    due_date="2026-09-30",
                    reminder_type="Arrival Notice Payment",
                )
            ]
        )
        result = approve_and_route_tasks_service(db_session, req, user_name="Ahmed Sorour")
        assert result.approved_count == 1
        assert len(result.created_task_ids) == 1

        # Verify task was saved with assigned user and priority
        task = db_session.query(SmartTask).filter_by(task_id=result.created_task_ids[0]).first()
        assert task is not None
        assert task.assigned_user == "Clearance Team"
        assert task.priority == "Critical"
        assert task.due_date == "2026-09-30"
        assert task.created_by == "Ahmed Sorour" or task.updated_by == "Ahmed Sorour"
