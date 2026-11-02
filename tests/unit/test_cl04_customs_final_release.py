from modules.import_requirements.model import ImportRequirementAssessment
from fastapi import HTTPException
import pytest
from datetime import date, datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from main import app
from database.database import get_db
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsFinalReleaseSubmit
from modules.customs_clearance.service import issue_final_customs_release_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification

client = TestClient(app)

@pytest.fixture
def db_session():
    generator = get_db()
    db = next(generator)
    try:
        yield db
    finally:
        pass


def test_issue_final_customs_release_success(db_session: Session):
    # 1. Setup active import file with paid duties
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-CL04-{int(datetime.now().timestamp())}",
        company_id=None,  # FK enforced (PRAGMA foreign_keys): no invented company row
        company_name="Delta Industrial Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech GmbH",
        port_of_discharge="El Dekheila Port",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_paid_amount=165801.50,
        customs_duty_receipt_no="REC-EFIN-8877123",
        customs_duty_sadad_no="SADAD-2026-998811",
        customs_duty_payment_status="PAID",
        current_module="Phase 7 - Customs Clearance & Duty Payment",
        current_stage="Duty Paid (تم سداد الرسوم الجمركية بسداد)",
        progress_percent=92.0,
        owner="Kamal",
        created_by="TestRunner",
        updated_by="TestRunner",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    # 2. Setup clearance record with paid duties
    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-TEST-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-9988",
        customs_office_name="El Dekheila Port Customs",
        channel_type="Red Channel",
        actual_duty_total=165801.50,
        duty_paid_amount=165801.50,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
        created_by="TestRunner",
        updated_by="TestRunner",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    # 3. Issue Final Customs Release Order
    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr_record.customs_clearance_id,
        release_permit_no="REL-2026-DKH-9988",
        release_date=datetime.now(timezone.utc),
        release_officer_name="م/ أحمد فؤاد - مأمور حركة الجمرك",
        release_type="نهائي وبات (Final Green Release)",
        release_document_url="/uploads/releases/rel_dkh_9988.pdf",
        gate_pass_number="GATE-PASS-2026-5511",
        demurrage_storage_fees=0.0,
        dispatch_authorized=True,
        transport_instructions="تحميل على 3 تريلات لنقل الحاويات إلى مستودع العاشر من رمضان",
        notes="تمت المطابقة واستيفاء الفحص واستلام إذن الإفراج الأخضر النهائي",
    )

    result = issue_final_customs_release_service(db_session, payload, user="TestRunner")

    # 4. Assertions on CustomsClearanceRecord
    assert result.release_permit_no == "REL-2026-DKH-9988"
    assert result.status == "Final Release Granted"
    assert result.release_officer_name == "م/ أحمد فؤاد - مأمور حركة الجمرك"
    assert result.gate_pass_number == "GATE-PASS-2026-5511"
    assert result.dispatch_authorized is True
    assert result.transport_instructions is not None

    # 5. Assertions on ImportFile
    db_session.refresh(imp_file)
    assert imp_file.is_customs_released is True
    assert imp_file.customs_released_at is not None
    assert imp_file.customs_release_permit_no == "REL-2026-DKH-9988"
    assert imp_file.customs_release_officer == "م/ أحمد فؤاد - مأمور حركة الجمرك"
    assert imp_file.customs_gate_pass_no == "GATE-PASS-2026-5511"
    assert imp_file.progress_percent >= 95.0
    assert "Customs Released" in imp_file.current_stage
    assert "TR-01" in imp_file.next_action

    # 6. Assertions on SmartTasks
    tasks = db_session.query(SmartTask).filter(SmartTask.import_file_id == imp_file.import_file_id).all()
    task_types = [t.task_type for t in tasks]
    assert "INLAND_TRANSPORT" in task_types
    assert "DEMURRAGE_TRACKING" in task_types

    # 7. Assertions on SystemNotification
    notifs = db_session.query(SystemNotification).filter(
        SystemNotification.entity_id == imp_file.import_file_id,
        SystemNotification.entity_type == "ImportFile",
    ).all()
    assert any("Green customs release issued" in n.title and n.msg_code == "CC_RELEASE_ISSUED" for n in notifs)


def test_issue_final_customs_release_blocks_if_duties_unpaid(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-UNPAID-{int(datetime.now().timestamp())}",
        company_id=None,  # FK enforced (PRAGMA foreign_keys): no invented company row
        company_name="Delta Industrial Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech GmbH",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_payment_status="UNPAID",
        customs_duty_paid_amount=0.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-UNPAID-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-0001",
        customs_office_name="El Dekheila Port Customs",
        channel_type="Red Channel",
        payment_status="Unpaid",
        duty_paid_amount=0.0,
        status="Duty Requested",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr_record.customs_clearance_id,
        release_permit_no="REL-UNPAID-FAIL",
    )

    with pytest.raises(Exception) as exc_info:
        issue_final_customs_release_service(db_session, payload, user="TestRunner")

    assert "الرسوم الجمركية" in str(exc_info.value.detail)


def test_issue_final_customs_release_blocks_if_acid_expired(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-EXPIRED-{int(datetime.now().timestamp())}",
        company_id=None,  # FK enforced (PRAGMA foreign_keys): no invented company row
        company_name="Delta Industrial Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech GmbH",
        acid_number="1234567890123456789",
        acid_expiry_date=date.today() - timedelta(days=5), # Expired!
        customs_duty_payment_status="PAID",
        customs_duty_paid_amount=50000.0,
        is_customs_released=False,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        release_permit_no="REL-EXPIRED-FAIL",
    )

    with pytest.raises(Exception) as exc_info:
        issue_final_customs_release_service(db_session, payload, user="TestRunner")

    assert "ACID" in str(exc_info.value.detail)


def test_issue_final_customs_release_api_endpoint(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-API-{int(datetime.now().timestamp())}",
        company_id=None,  # FK enforced (PRAGMA foreign_keys): no invented company row
        company_name="Delta Industrial Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech GmbH",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=60),
        customs_duty_paid_amount=99000.0,
        customs_duty_receipt_no="REC-API-99000",
        customs_duty_sadad_no="SADAD-API-99000",
        customs_duty_payment_status="PAID",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-API-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-API",
        customs_office_name="El Dekheila Port Customs",
        channel_type="Green Channel",
        actual_duty_total=99000.0,
        duty_paid_amount=99000.0,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    payload = {
        "import_file_id": imp_file.import_file_id,
        "clearance_id": clr_record.customs_clearance_id,
        "release_permit_no": "REL-2026-DKH-API",
        "release_officer_name": "م/ يوسف النجار - مفتش الجمارك",
        "release_type": "نهائي وبات (Final Green Release)",
        "gate_pass_number": "GATE-API-99",
        "dispatch_authorized": True,
        "transport_instructions": "جاهز للتحميل ونقل المستودع",
    }

    response = client.post("/api/v1/customs-clearance/issue-final-release", json=payload)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["release_permit_no"] == "REL-2026-DKH-API"
    assert data["status"] == "Final Release Granted"
    assert data["dispatch_authorized"] is True
    assert data["gate_pass_number"] == "GATE-API-99"


def test_issue_final_customs_release_blocks_if_regulatory_permit_unapproved(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-REG-PERMIT-{int(datetime.now().timestamp())}",
        company_id=None,
        company_name="Delta Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_payment_status="PAID",
        customs_duty_paid_amount=50000.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-REG-PERMIT-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-PERMIT",
        customs_office_name="El Dekheila Port",
        channel_type="Red Channel",
        actual_duty_total=50000.0,
        duty_paid_amount=50000.0,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    # Attach ImportRequirementAssessment with unapproved permit
    assessment = ImportRequirementAssessment(
        assessment_code=f"BP011-TEST-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        import_permit_required=True,
        permit_issuing_authority="GOEIC (الهيئة العامة للرقابة على الصادرات والواردات)",
        permit_status="Pending Approval",
        inspection_required=False,
        inspection_status="Not Required",
        is_active=True,
    )
    db_session.add(assessment)
    db_session.commit()

    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr_record.customs_clearance_id,
        release_permit_no="REL-PERMIT-FAIL",
    )

    with pytest.raises(HTTPException) as exc_info:
        issue_final_customs_release_service(db_session, payload, user="TestRunner")

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CC_REGULATORY_REQUIREMENTS_NOT_MET"
    assert exc_info.value.detail["import_permit_required"] is True
    assert exc_info.value.detail["permit_status"] == "Pending Approval"


def test_issue_final_customs_release_blocks_if_inspection_incomplete(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-REG-INSP-{int(datetime.now().timestamp())}",
        company_id=None,
        company_name="Delta Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_payment_status="PAID",
        customs_duty_paid_amount=60000.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-REG-INSP-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-INSP",
        customs_office_name="El Dekheila Port",
        channel_type="Red Channel",
        actual_duty_total=60000.0,
        duty_paid_amount=60000.0,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    # Attach assessment with incomplete inspection
    assessment = ImportRequirementAssessment(
        assessment_code=f"BP011-INSP-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        import_permit_required=False,
        permit_status="Not Required",
        inspection_required=True,
        inspection_body="SGS International Inspection",
        inspection_status="Scheduled",
        is_active=True,
    )
    db_session.add(assessment)
    db_session.commit()

    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr_record.customs_clearance_id,
        release_permit_no="REL-INSP-FAIL",
    )

    with pytest.raises(HTTPException) as exc_info:
        issue_final_customs_release_service(db_session, payload, user="TestRunner")

    assert exc_info.value.status_code == 422
    assert exc_info.value.detail["code"] == "CC_REGULATORY_REQUIREMENTS_NOT_MET"
    assert exc_info.value.detail["inspection_required"] is True
    assert exc_info.value.detail["inspection_status"] == "Scheduled"


def test_issue_final_customs_release_succeeds_when_regulatory_requirements_fulfilled(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-REG-OK-{int(datetime.now().timestamp())}",
        company_id=None,
        company_name="Delta Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_payment_status="PAID",
        customs_duty_paid_amount=75000.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-REG-OK-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-OK",
        customs_office_name="El Dekheila Port",
        channel_type="Red Channel",
        actual_duty_total=75000.0,
        duty_paid_amount=75000.0,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    # Attach assessment with approved permit and completed inspection
    assessment = ImportRequirementAssessment(
        assessment_code=f"BP011-OK-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        import_permit_required=True,
        permit_issuing_authority="GOEIC",
        permit_status="Approved",
        permit_number="PERMIT-GOEIC-2026-99",
        inspection_required=True,
        inspection_body="SGS Inspection",
        inspection_status="Completed",
        inspection_report_no="REP-SGS-8822",
        is_active=True,
    )
    db_session.add(assessment)
    db_session.commit()

    payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr_record.customs_clearance_id,
        release_permit_no="REL-REG-OK-99",
    )

    result = issue_final_customs_release_service(db_session, payload, user="TestRunner")
    assert result.status == "Final Release Granted"
    assert result.release_permit_no == "REL-REG-OK-99"


def test_issue_final_customs_release_api_blocks_when_regulatory_not_met(db_session: Session):
    imp_file = ImportFile(
        import_file_code=f"IMP-TEST-API-BLOCKED-{int(datetime.now().timestamp())}",
        company_id=None,
        company_name="Delta Machinery LLC",
        supplier_id=None,
        supplier_name="Bavaria Tech",
        acid_number="9876543210123456789",
        acid_expiry_date=date.today() + timedelta(days=90),
        customs_duty_payment_status="PAID",
        customs_duty_paid_amount=88000.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clr_record = CustomsClearanceRecord(
        clearance_code=f"CLR-API-BLOCKED-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="46-2026-DKH-API-BLOCKED",
        customs_office_name="El Dekheila Port Customs",
        channel_type="Red Channel",
        actual_duty_total=88000.0,
        duty_paid_amount=88000.0,
        payment_status="Paid & Verified",
        status="Duty Paid - Ready for Final Release",
        owner="Kamal",
    )
    db_session.add(clr_record)
    db_session.commit()
    db_session.refresh(clr_record)

    # Attach assessment with unapproved permit
    assessment = ImportRequirementAssessment(
        assessment_code=f"BP011-API-BLOCKED-{imp_file.import_file_id}",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        import_permit_required=True,
        permit_issuing_authority="الهيئة القومية لسلامة الغذاء (NFSA)",
        permit_status="Pending Approval",
        inspection_required=True,
        inspection_status="Pending",
        is_active=True,
    )
    db_session.add(assessment)
    db_session.commit()

    payload = {
        "import_file_id": imp_file.import_file_id,
        "clearance_id": clr_record.customs_clearance_id,
        "release_permit_no": "REL-BLOCKED-API",
        "release_type": "FINAL_GREEN",
    }

    response = client.post("/api/v1/customs-clearance/issue-final-release", json=payload)
    assert response.status_code == 422, response.text
    data = response.json()
    assert "detail" in data
    assert data["detail"]["code"] == "CC_REGULATORY_REQUIREMENTS_NOT_MET"
    assert data["detail"]["import_permit_required"] is True
