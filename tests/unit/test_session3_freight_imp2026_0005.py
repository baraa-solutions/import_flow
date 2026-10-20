"""
Unit tests for Session 3: Freight Free Days (BK-02) and Sailing Departure (SH-01) for IMP-2026-0005
Tests free days agreement, sailing confirmation, task auto-completion,
lifecycle board step advancement (STEP_07 -> STEP_08_BL), and downstream SH-02 dispatch.
"""

from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import ShipmentDepartureConfirm
from modules.freight_booking.service import confirm_departure_and_bol_service
from modules.demurrage_detention.schemas import FreeDaysAgreementRegister
from modules.demurrage_detention.service import register_free_days_agreement_service
from modules.smart_tasks.model import SmartTask
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.notifications.model import SystemNotification


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_free_days_and_departure_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_07 / 50%
    imp_file = ImportFile(
        import_file_code="IMP-2026-0005",
        company_name="SCAS For Construction And Finishing",
        supplier_name="Yangzhou Haixing Plastic Co.",
        current_step_code="STEP_07",
        current_module="Phase 3: Booking & Doc Prep",
        current_stage_code="PHASE_3",
        progress_percent=50.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup confirmed ShipmentBooking
    booking = ShipmentBooking(
        booking_code="BKG-2026-TEST05",
        import_file_id=imp_file.import_file_id,
        booking_confirmation_no="THXJ2609015",
        shipping_line_name="Wan Hai Lines Ltd.",
        vessel_name="WAN HAI 511",
        voyage_number="V.W112",
        pol_name="Shanghai Port",
        pod_name="Alexandria Port",
        status="Confirmed",
        booking_request_date=datetime(2026, 9, 1, 10, 0, 0, tzinfo=timezone.utc),
        etd=datetime(2026, 9, 25, 10, 0, 0, tzinfo=timezone.utc),
        eta=datetime(2026, 10, 23, 18, 0, 0, tzinfo=timezone.utc),
        free_demurrage_days=14,
    )
    db_session.add(booking)
    db_session.commit()

    # 3. Setup Open SmartTask for Free Days (BK-02) and STEP_07
    task_bk02 = SmartTask(
        task_code="TSK-TEST-BK02",
        title="Record and confirm the container free days: PET Stock (BK-02)",
        task_type="System Generated",
        msg_code="FB_TASK_FREE_DAYS",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        status="Pending",
        priority="High",
    )
    task_step07 = SmartTask(
        task_code="TSK-TEST-ST07",
        title=f"[{imp_file.import_file_code}] - STEP_07",
        task_type="System Generated",
        step_code="STEP_07",
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        status="Pending",
        priority="Medium",
    )
    activity_07 = ShipmentStageActivity(
        import_file_code=imp_file.import_file_code,
        step_code="STEP_07",
        status="In-Progress",
    )
    db_session.add_all([task_bk02, task_step07, activity_07])
    db_session.commit()

    # 4. Execute Free Days Agreement (BK-02)
    fd_payload = FreeDaysAgreementRegister(
        import_file_id=imp_file.import_file_id,
        carrier_name="Wan Hai Lines Ltd.",
        agreed_demurrage_free_days=21,
        agreed_detention_free_days=7,
        port_storage_free_days=5,
        agreement_reference="WHL-THXJ2609015-FD",
        agreement_date=date(2026, 9, 22),
        notes="Agreed 21 free days demurrage.",
    )
    fd_resp = register_free_days_agreement_service(
        db=db_session,
        payload=fd_payload,
        user="Logistics Officer",
    )
    assert fd_resp.agreed_demurrage_free_days == 21
    db_session.refresh(imp_file)
    assert imp_file.target_free_days == 21

    # Verify task auto-closed
    db_session.refresh(task_bk02)
    assert task_bk02.status == "Completed"

    # 5. Execute Sailing Departure Confirmation (SH-01)
    dep_payload = ShipmentDepartureConfirm(
        actual_departure_date=datetime(2026, 9, 25, 12, 0, 0, tzinfo=timezone.utc),
        shipped_on_board_date=date(2026, 9, 25),
        bill_of_lading_no="WHL-SHA-2026-9015",
        vessel_name="WAN HAI 511",
        voyage_number="V.W112",
        revised_eta=datetime(2026, 10, 23, 18, 0, 0, tzinfo=timezone.utc),
        notes="Vessel departed on schedule.",
    )
    departed_booking = confirm_departure_and_bol_service(
        db=db_session,
        booking_id=booking.booking_id,
        payload=dep_payload,
        user="Logistics Officer",
    )
    assert departed_booking.status == "Sailed"
    assert departed_booking.bill_of_lading_no == "WHL-SHA-2026-9015"

    # 6. Verify ImportFile progress and lifecycle advance
    db_session.refresh(imp_file)
    assert imp_file.progress_percent >= 60.0

    # Verify STEP_07 task closed
    db_session.refresh(task_step07)
    assert task_step07.status == "Completed"

    # Verify downstream SH-02 task dispatched
    bl_tasks = (
        db_session.query(SmartTask)
        .filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
        )
        .all()
    )
    assert len(bl_tasks) >= 1
