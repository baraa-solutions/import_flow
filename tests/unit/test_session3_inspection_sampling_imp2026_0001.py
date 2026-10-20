"""
Unit tests for Session 3: Customs Inspection & Sampling (CL-01 / STEP_14 -> STEP_15/17)
Tests recording of field inspection, GOEIC sampling, lab fees, task auto-completion,
lifecycle board step advancement, and downstream duty assessment dispatch.
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsInspectionSamplingSubmit
from modules.customs_clearance.service import record_customs_inspection_sampling_service
from modules.smart_tasks.model import SmartTask
from modules.notifications.model import SystemNotification
from modules.lifecycle_board.model import ShipmentStageActivity


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_inspection_sampling_full_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_14 / 86%
    imp_file = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="ECO ASSOCIATES for Trading and Contracting",
        supplier_name="G.I. Industrial Holding S.p.A.",
        current_step_code="STEP_14",
        current_module="Phase 5: Port Operations & Clearance",
        current_stage_code="PHASE_5",
        progress_percent=86.0,
        form46_no="DEC-46-2026-0001",
        form46_date=datetime(2026, 9, 14, 10, 0, 0, tzinfo=timezone.utc),
        form46_status="REGISTERED",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup CustomsClearanceRecord from Form 46
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-0002",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-46-2026-0001",
        declaration_46_date=datetime(2026, 9, 14, 10, 0, 0, tzinfo=timezone.utc),
        customs_office_name="Alexandria Port Customs",
        channel_type="Yellow Channel",
        regulatory_bodies=["GOEIC"],
        status="Under Customs Clearance",
        owner="Kamal",
    )
    db_session.add(clr)

    # 3. Setup Open SmartTask for Inspection & Sampling
    task_insp = SmartTask(
        task_code="TASK-E516EBE9",
        title=f"Record inspection & sampling (CL-01) - {imp_file.import_file_code}",
        task_type="CUSTOMS_INSPECTION_SAMPLING",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        status="Pending",
        priority="High",
        msg_code="CC_TASK_INSPECTION",
    )
    db_session.add(task_insp)

    # 4. Setup Lifecycle Activity for STEP_14
    activity_14 = ShipmentStageActivity(
        import_file_code=imp_file.import_file_code,
        step_code="STEP_14",
        status="In-Progress",
    )
    db_session.add(activity_14)
    db_session.commit()

    # 5. Execute Inspection & Sampling (CL-01)
    payload = CustomsInspectionSamplingSubmit(
        import_file_id=imp_file.import_file_id,
        inspection_date=datetime(2026, 9, 15, 10, 0, 0, tzinfo=timezone.utc),
        inspection_type="Physical & Sampling",
        inspection_yard="ALEXANDRIA_BERTH_42",
        inspector_name="Eng. Tarek Mahmoud (Joint Inspection Committee)",
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_date=datetime(2026, 9, 15, 11, 30, 0, tzinfo=timezone.utc),
        sampling_record_no="SMP-2026-0012",
        sample_test_status="Samples Under Testing",
        sampled_regulatory_bodies=["GOEIC"],
        goeic_certificate_no="GOEIC-ALX-2026-9901",
        lab_service_fees=2450.0,
        inspection_notes="Joint committee inspection conducted. Conforming seals and contents. Sample drawn for GOEIC laboratory testing.",
    )

    rec = record_customs_inspection_sampling_service(
        db=db_session,
        payload=payload,
        user="Customs Broker",
    )

    # 6. Verify clearance record updates
    assert rec.status == "Inspection & Sampling Recorded"
    assert rec.inspection_yard == "ALEXANDRIA_BERTH_42"
    assert rec.inspection_result == "Conforming"
    assert rec.is_sample_drawn is True
    assert rec.sampling_record_no == "SMP-2026-0012"
    assert rec.sample_test_status == "Samples Under Testing"
    assert "GOEIC" in rec.sampled_regulatory_bodies
    assert rec.goeic_certificate_no == "GOEIC-ALX-2026-9901"
    assert rec.lab_service_fees == 2450.0

    # 7. Verify ImportFile progress advanced to at least 88%
    db_session.refresh(imp_file)
    assert imp_file.progress_percent >= 88.0

    # 8. Verify SmartTask auto-closed
    db_session.refresh(task_insp)
    assert task_insp.status == "Completed"

    # 9. Verify downstream duty assessment task dispatched (CL-02)
    next_tasks = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type.in_(["FINAL_DUTY_ASSESSMENT", "CL-02"]),
        )
        .all()
    )
    assert len(next_tasks) >= 1
    assert any(t.status == "Pending" for t in next_tasks)

    # 10. Verify notification created
    notifications = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.entity_id == imp_file.import_file_id,
            SystemNotification.msg_code == "CC_INSPECTION_RECORDED",
        )
        .all()
    )
    assert len(notifications) >= 1
