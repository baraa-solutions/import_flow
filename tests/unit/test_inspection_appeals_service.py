"""
Unit tests for Inspection Appeals Service & Lifecycle (modules/inspection_appeals).
Tests laboratory appeal lodging, tier progression, triplicate sample lab assignment,
committee hearing outcomes, and soft-delete/restore.
"""

from datetime import datetime, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
import database.models  # Registers all models
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.inspection_appeals.schemas import (
    AppealCommitteeDecisionSubmit,
    AppealTierProgression,
    InspectionAppealCreate,
    InspectionAppealUpdate,
    TriplicateLabAssignSubmit,
)
from modules.inspection_appeals.service import InspectionAppealService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import company and import file
    imp_file = ImportFile(
        import_file_code="IMP-2026-9001",
        company_name="Al-Amal Import & Export",
        supplier_name="Global Steel Corp",
        current_step_code="STEP_14",
        current_module="STEP_14 Clearance Follow-up",
        current_stage_code="PHASE_5",
        progress_percent=85.0,
    )
    session.add(imp_file)
    session.commit()
    session.refresh(imp_file)

    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-9001",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-46-2026-9001",
        status="Under Customs Clearance",
    )
    session.add(clr)
    session.commit()
    session.refresh(clr)

    yield session
    session.close()


def test_create_inspection_appeal_success(db_session):
    service = InspectionAppealService(db_session)
    imp_file = db_session.query(ImportFile).first()
    clr = db_session.query(CustomsClearanceRecord).first()

    payload = InspectionAppealCreate(
        import_file_id=imp_file.import_file_id,
        clearance_id=clr.customs_clearance_id,
        regulatory_authority="GOEIC",
        sample_number="SMP-2026-0042",
        sample_draw_date=datetime(2026, 9, 20, 10, 0, tzinfo=timezone.utc),
        initial_test_result="NON_CONFORMING_CHEMICAL",
        rejection_reason="Excessive zinc content exceeding Egyptian standard ES 1042/2020",
        appeal_tier="FIRST_APPEAL",
        appeal_submission_date=datetime(2026, 9, 21, 9, 0, tzinfo=timezone.utc),
        official_letter_ref="LTR-GOEIC-2026-001",
        notes="Lodging initial laboratory appeal before Alexandria Port Committee",
    )

    appeal = service.create_appeal(payload, current_user="broker_user")

    assert appeal.appeal_id is not None
    assert appeal.appeal_code.startswith("APP-")
    assert appeal.regulatory_authority == "GOEIC"
    assert appeal.appeal_tier == "FIRST_APPEAL"
    assert appeal.appeal_result == "PENDING"
    assert appeal.sample_number == "SMP-2026-0042"
    assert appeal.is_active is True


def test_create_inspection_appeal_validation_failures(db_session):
    service = InspectionAppealService(db_session)
    imp_file = db_session.query(ImportFile).first()

    # 1. Invalid regulatory authority
    with pytest.raises(HTTPException) as exc_info:
        service.create_appeal(
            InspectionAppealCreate(
                import_file_id=imp_file.import_file_id,
                regulatory_authority="UNKNOWN_AUTHORITY",
                initial_test_result="NON_CONFORMING_VISUAL",
            ),
            current_user="test_user",
        )
    assert exc_info.value.status_code == 400
    assert "جهة الفحص الرقابي غير صحيحة" in exc_info.value.detail

    # 2. Invalid initial test result
    with pytest.raises(HTTPException) as exc_info:
        service.create_appeal(
            InspectionAppealCreate(
                import_file_id=imp_file.import_file_id,
                regulatory_authority="NFSA",
                initial_test_result="INVALID_RESULT",
            ),
            current_user="test_user",
        )
    assert exc_info.value.status_code == 400
    assert "نتيجة الفحص المعملي الأولية غير صحيحة" in exc_info.value.detail

    # 3. Missing triplicate lab when starting at TRIPLICATE_SAMPLE
    with pytest.raises(HTTPException) as exc_info:
        service.create_appeal(
            InspectionAppealCreate(
                import_file_id=imp_file.import_file_id,
                regulatory_authority="EDA",
                initial_test_result="NON_CONFORMING_MICROBIAL",
                appeal_tier="TRIPLICATE_SAMPLE",
                triplicate_lab_assigned=None,
            ),
            current_user="test_user",
        )
    assert exc_info.value.status_code == 400
    assert "يجب تحديد معمل فحص العينة الثلاثية" in exc_info.value.detail


def test_appeal_progression_lifecycle(db_session):
    service = InspectionAppealService(db_session)
    imp_file = db_session.query(ImportFile).first()

    # Step 1: Create First Appeal
    appeal = service.create_appeal(
        InspectionAppealCreate(
            import_file_id=imp_file.import_file_id,
            regulatory_authority="NFSA",
            sample_number="SMP-NFSA-101",
            initial_test_result="NON_CONFORMING_MICROBIAL",
            rejection_reason="Total yeast and mold count slightly elevated",
            appeal_tier="FIRST_APPEAL",
        ),
        current_user="qa_user",
    )
    assert appeal.appeal_tier == "FIRST_APPEAL"

    # Step 2: First Appeal Hearing upholds rejection
    service.record_committee_decision(
        appeal.appeal_id,
        AppealCommitteeDecisionSubmit(
            appeal_committee_date=datetime(2026, 9, 25, 12, 0, tzinfo=timezone.utc),
            appeal_result="UPHELD_REJECTED",
            official_letter_ref="DEC-COMM-01",
            notes="First committee confirms initial test result",
        ),
        current_user="qa_user",
    )
    db_session.refresh(appeal)
    assert appeal.appeal_result == "UPHELD_REJECTED"

    # Step 3: Escalate to Second Appeal
    service.progress_tier(
        appeal.appeal_id,
        AppealTierProgression(
            target_tier="SECOND_APPEAL",
            official_letter_ref="APP-ESC-2ND",
            notes="Escalating to Higher Appeals Committee at NFSA HQ",
        ),
        current_user="qa_user",
    )
    db_session.refresh(appeal)
    assert appeal.appeal_tier == "SECOND_APPEAL"
    assert appeal.appeal_result == "PENDING"

    # Step 4: Escalate from Second Appeal to Triplicate Sample (العينة الثلاثية)
    service.progress_tier(
        appeal.appeal_id,
        AppealTierProgression(
            target_tier="TRIPLICATE_SAMPLE",
            triplicate_lab_assigned="Central Public Health Laboratories (CPHL) - Ministry of Health",
            official_letter_ref="TRIP-REF-99",
            notes="Reference lab assigned for binding triplicate sample testing",
        ),
        current_user="qa_user",
    )
    db_session.refresh(appeal)
    assert appeal.appeal_tier == "TRIPLICATE_SAMPLE"
    assert appeal.triplicate_lab_assigned == "Central Public Health Laboratories (CPHL) - Ministry of Health"
    assert appeal.appeal_result == "PENDING"

    # Step 5: Triplicate Sample is final tier -> attempting further escalation must fail with 409 Conflict
    with pytest.raises(HTTPException) as exc_info:
        service.progress_tier(
            appeal.appeal_id,
            AppealTierProgression(
                target_tier="SECOND_APPEAL",
            ),
            current_user="qa_user",
        )
    assert exc_info.value.status_code == 409
    assert "وصل التظلم إلى مرحلة العينة الثلاثية النهائية" in exc_info.value.detail

    # Step 6: Triplicate Lab overturns rejection (CONFORMING)
    service.record_committee_decision(
        appeal.appeal_id,
        AppealCommitteeDecisionSubmit(
            appeal_committee_date=datetime(2026, 10, 5, 11, 0, tzinfo=timezone.utc),
            appeal_result="OVERTURNED_CONFORMING",
            official_letter_ref="FINAL-CLEAR-LTR-440",
            notes="CPHL analysis confirms conformity with international Codex standards",
        ),
        current_user="qa_user",
    )
    db_session.refresh(appeal)
    assert appeal.appeal_result == "OVERTURNED_CONFORMING"

    # Step 7: Attempting escalation after overturning must be blocked
    with pytest.raises(HTTPException) as exc_info:
        service.progress_tier(
            appeal.appeal_id,
            AppealTierProgression(target_tier="TRIPLICATE_SAMPLE"),
            current_user="qa_user",
        )
    assert exc_info.value.status_code == 409
    assert "تم قبول التظلم وقبول الرسالة كمطابقة بالفعل" in exc_info.value.detail


def test_assign_triplicate_lab_and_update(db_session):
    service = InspectionAppealService(db_session)
    imp_file = db_session.query(ImportFile).first()

    appeal = service.create_appeal(
        InspectionAppealCreate(
            import_file_id=imp_file.import_file_id,
            regulatory_authority="NTRA",
            sample_number="NTRA-SMP-77",
            initial_test_result="NON_CONFORMING_CHEMICAL",
            appeal_tier="FIRST_APPEAL",
        ),
        current_user="user1",
    )

    # Assign lab directly
    service.assign_triplicate_lab(
        appeal.appeal_id,
        TriplicateLabAssignSubmit(
            triplicate_lab_assigned="Atomic Energy & Radiation Safety Lab",
            official_letter_ref="LTR-AE-2026",
            notes="Testing shielding frequencies",
        ),
        current_user="user1",
    )
    db_session.refresh(appeal)
    assert appeal.triplicate_lab_assigned == "Atomic Energy & Radiation Safety Lab"
    assert appeal.official_letter_ref == "LTR-AE-2026"

    # Update general fields
    service.update_appeal(
        appeal.appeal_id,
        InspectionAppealUpdate(
            sample_number="NTRA-SMP-77-REVISED",
            notes="Updated sample tag barcode",
        ),
        current_user="user1",
    )
    db_session.refresh(appeal)
    assert appeal.sample_number == "NTRA-SMP-77-REVISED"


def test_list_and_soft_delete_inspection_appeal(db_session):
    service = InspectionAppealService(db_session)
    imp_file = db_session.query(ImportFile).first()

    app1 = service.create_appeal(
        InspectionAppealCreate(
            import_file_id=imp_file.import_file_id,
            regulatory_authority="EDA",
            initial_test_result="NON_CONFORMING_CHEMICAL",
        ),
        current_user="user1",
    )
    app2 = service.create_appeal(
        InspectionAppealCreate(
            import_file_id=imp_file.import_file_id,
            regulatory_authority="ATOMIC_ENERGY",
            initial_test_result="NON_CONFORMING_VISUAL",
        ),
        current_user="user1",
    )

    # List with filtering
    items, total = service.list_appeals(regulatory_authority="EDA")
    assert total == 1
    assert items[0].appeal_id == app1.appeal_id

    # Soft delete app1
    service.soft_delete(app1.appeal_id, current_user="admin")
    items, total = service.list_appeals(regulatory_authority="EDA")
    assert total == 0

    # Include inactive
    items, total = service.list_appeals(regulatory_authority="EDA", include_inactive=True)
    assert total == 1

    # Restore app1
    restored = service.restore(app1.appeal_id, current_user="admin")
    assert restored.is_active is True
    items, total = service.list_appeals(regulatory_authority="EDA")
    assert total == 1
