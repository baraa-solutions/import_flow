"""
Unit Tests for Customs Consultation Module (BP-009)
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_consultation.schemas import (
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
    CustomsChecklistItemCreate,
)
from modules.customs_consultation.service import CustomsConsultationService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    # Seed broker partner
    broker = ExternalServiceProvider(
        partner_code="ESP-000005",
        partner_name="El-Ahram Customs Clearance",
        partner_type="Customs Broker",
        is_active=True,
    )
    db.add(broker)
    db.commit()
    db.refresh(broker)

    yield db
    db.close()


class TestCustomsConsultationBackend:

    def test_create_consultation_service(self, db_session):
        broker = db_session.query(ExternalServiceProvider).first()
        
        session_in = CustomsConsultationCreate(
            title="اختبار المراجعة الجمركية لمكائن النسيج",
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
            estimated_duties_egp=50000.0,
            notes="ملاحظات المراجعة الأولية",
            checklist_items=[
                CustomsChecklistItemCreate(
                    document_type="Proforma Invoice",
                    hs_code="8443.19.00",
                    is_required=True,
                    is_blocking_shipment=True,
                    status="Approved",
                ),
                CustomsChecklistItemCreate(
                    document_type="Packing List",
                    hs_code="8443.19.00",
                    is_required=True,
                    is_blocking_shipment=True,
                    status="Pending",
                ),
            ],
        )

        res = CustomsConsultationService.create_consultation(db_session, session_in)
        assert res.consultation_id is not None
        assert res.consultation_code.startswith("CUS-")
        assert res.total_documents_count == 2
        assert res.approved_documents_count == 1
        assert res.readiness_percentage == 50.0
        assert res.has_blocking_issues is False
        assert res.overall_status == "In Progress"

    def test_readiness_calculation_and_clearance_ready(self, db_session):
        broker = db_session.query(ExternalServiceProvider).first()

        session_in = CustomsConsultationCreate(
            title="دراسة مكتملة المراجعة الجمركية",
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
            checklist_items=[
                CustomsChecklistItemCreate(
                    document_type="Proforma Invoice",
                    status="Approved",
                ),
                CustomsChecklistItemCreate(
                    document_type="Packing List",
                    status="Approved",
                ),
            ],
        )

        res = CustomsConsultationService.create_consultation(db_session, session_in)
        assert res.readiness_percentage == 100.0
        assert res.overall_status == "Clearance Ready"

    def test_blocking_issue_sets_status_blocked(self, db_session):
        broker = db_session.query(ExternalServiceProvider).first()

        session_in = CustomsConsultationCreate(
            title="دراسة مع محظورات استيرادية",
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
            checklist_items=[
                CustomsChecklistItemCreate(
                    document_type="Decree 43 Factory Registration",
                    is_blocking_shipment=True,
                    status="Rejected",
                    remarks="المصنع غير مسجل بقائمة المصانع المعتمدة",
                )
            ],
        )

        res = CustomsConsultationService.create_consultation(db_session, session_in)
        assert res.has_blocking_issues is True
        assert res.blocking_issues_count == 1
        assert res.overall_status == "Blocked"

    def test_update_consultation(self, db_session):
        broker = db_session.query(ExternalServiceProvider).first()

        session_in = CustomsConsultationCreate(
            title="مراجعة جمركية أولية",
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
            checklist_items=[
                CustomsChecklistItemCreate(document_type="PI", status="Pending")
            ],
        )

        created = CustomsConsultationService.create_consultation(db_session, session_in)

        update_in = CustomsConsultationUpdate(
            title="عنوان محدث للمراجعة",
            checklist_items=[
                CustomsChecklistItemCreate(document_type="PI", status="Approved")
            ],
        )

        updated = CustomsConsultationService.update_consultation(
            db_session, created.consultation_id, update_in
        )
        assert updated.title == "عنوان محدث للمراجعة"
        assert updated.readiness_percentage == 100.0
        assert updated.overall_status == "Clearance Ready"

    def test_soft_delete_and_restore(self, db_session):
        broker = db_session.query(ExternalServiceProvider).first()

        session_in = CustomsConsultationCreate(
            title="مراجعة للاختبار والحذف",
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
        )

        created = CustomsConsultationService.create_consultation(db_session, session_in)
        deleted = CustomsConsultationService.soft_delete_consultation(
            db_session, created.consultation_id
        )
        assert deleted.is_active is False

        active_list = CustomsConsultationService.list_consultations(db_session, include_inactive=False)
        assert len(active_list) == 0

        restored = CustomsConsultationService.restore_consultation(
            db_session, created.consultation_id
        )
        assert restored.is_active is True

    def test_create_consultation_without_broker_succeeds(self, db_session):
        session_in = CustomsConsultationCreate(
            title="مراجعة جمركية بدون مخلص (وضع الفحص الضريبي)",
            broker_id=None,
            broker_name=None,
        )
        res = CustomsConsultationService.create_consultation(db_session, session_in)
        assert res.consultation_id is not None
        assert res.broker_id is None
        assert res.broker_name is None
