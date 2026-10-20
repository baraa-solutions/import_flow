"""
Unit tests for Session 2: Customs Declaration 46 (CS-03) and Inspection Dispatch
Tests registration of Form 46 on Nafeza MTS, task auto-completion,
lifecycle board step advancement (STEP_13 -> STEP_14/15), and downstream inspection dispatch.
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsDeclaration46Submit
from modules.customs_clearance.service import register_customs_declaration_46_service
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


def test_customs_declaration_46_full_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_13
    imp_file = ImportFile(
        import_file_code="IMP-2026-TEST01",
        company_name="El-Nasr Imports",
        supplier_name="Global Tech Ltd",
        current_step_code="STEP_13",
        current_module="STEP_13 Customs Declaration 46",
        current_stage_code="PHASE_5",
        progress_percent=83.0,
        delivery_order_no="DO-MAEU-2026-0001",
        delivery_order_status="PAID_AND_RECEIVED",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup existing CustomsClearanceRecord with D/O received
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-TEST01",
        import_file_id=imp_file.import_file_id,
        delivery_order_number="DO-MAEU-2026-0001",
        delivery_order_status="Paid & Received",
        owner="Kamal",
        status="D/O Received - Ready for 46",
    )
    db_session.add(clr)

    # 3. Setup Open SmartTask for Declaration 46
    task_d46 = SmartTask(
        task_code="TASK-TEST-D46",
        title=f"Register customs declaration Form 46 - {imp_file.import_file_code}",
        task_type="CUSTOMS_DECLARATION_46",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        status="Pending",
        priority="High",
        msg_code="CC_TASK_DECLARATION_46",
    )
    db_session.add(task_d46)

    # 4. Setup Lifecycle Activity for STEP_13
    activity_13 = ShipmentStageActivity(
        import_file_code=imp_file.import_file_code,
        step_code="STEP_13",
        status="In-Progress",
    )
    db_session.add(activity_13)
    db_session.commit()

    # 5. Execute Customs Declaration 46 Registration
    payload = CustomsDeclaration46Submit(
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-46-2026-9999",
        declaration_46_date=datetime(2026, 9, 14, 10, 0, 0, tzinfo=timezone.utc),
        customs_office_name="Alexandria Port Customs",
        channel_type="Yellow Channel",
        regulatory_bodies=["GOEIC"],
        mts_certificate_number="MTS-2026-8888",
        customs_tariff_items_count=2,
        inspection_notes="Yellow Channel with GOEIC presentation.",
    )

    result_record = register_customs_declaration_46_service(
        db=db_session,
        payload=payload,
        user="Customs Broker",
    )

    # 6. Verify CustomsClearanceRecord state
    assert result_record.declaration_46_no == "DEC-46-2026-9999"
    assert result_record.channel_type == "Yellow Channel"
    assert result_record.customs_office_name == "Alexandria Port Customs"
    assert result_record.regulatory_bodies == ["GOEIC"]
    assert result_record.mts_certificate_number == "MTS-2026-8888"
    assert result_record.customs_tariff_items_count == 2
    assert result_record.status == "Under Customs Clearance"

    # 7. Verify ImportFile synchronization
    db_session.refresh(imp_file)
    assert imp_file.form46_no == "DEC-46-2026-9999"
    assert imp_file.form46_status == "REGISTERED"
    assert imp_file.progress_percent >= 86.0
    assert imp_file.current_step_code in ("STEP_14", "STEP_15")
    assert imp_file.current_phase_id == 5

    # 8. Verify Prior SmartTask auto-closure
    db_session.refresh(task_d46)
    assert task_d46.status == "Completed"

    # 9. Verify Downstream Inspection Task dispatch
    downstream_task = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.task_type.in_(["CUSTOMS_INSPECTION_SAMPLING", "CL-01"]),
            SmartTask.status != "Completed",
        )
        .first()
    )
    assert downstream_task is not None
    assert downstream_task.status == "Pending"
    assert downstream_task.priority == "High"

    # 10. Verify SystemNotification emission
    notif = (
        db_session.query(SystemNotification)
        .filter(
            SystemNotification.entity_id == imp_file.import_file_id,
            SystemNotification.msg_code == "CC_DECLARATION_46_REGISTERED",
        )
        .first()
    )
    assert notif is not None
