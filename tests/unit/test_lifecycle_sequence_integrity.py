"""
Unit tests for Lifecycle Sequence Integrity & Timeline Reporting
"""

import pytest
from datetime import datetime
from fastapi.testclient import TestClient

from main import app
from database.database import get_db
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.smart_tasks.model import SmartTask
import modules.lifecycle_board.service as service


@pytest.fixture
def client_and_db():
    client = TestClient(app)
    db_gen = get_db()
    db = next(db_gen)
    try:
        yield client, db
    finally:
        try:
            next(db_gen)
        except StopIteration:
            pass


def test_timeline_detects_auto_completed_sequence_gaps(client_and_db):
    client, db = client_and_db
    code = f"TEST-SEQ-{int(datetime.now().timestamp())}"

    file_rec = ImportFile(
        import_file_code=code,
        company_name="Test Importer",
        supplier_name="Test Supplier",
        status="Open",
        is_active=True,
    )
    db.add(file_rec)
    db.commit()

    # Advance directly to STEP_06 without doing STEP_01..STEP_05 explicitly
    res = service.advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_06",
        import_file_code=code,
        auto_complete_prior=True,
    )
    assert res["completed_step"] == "STEP_06"
    assert len(res["auto_completed_prior_steps"]) == 5  # STEP_01..STEP_05

    # Check timeline reporting
    timeline = service.get_shipment_timeline_service(db, import_file_code=code)
    assert timeline.import_file_code == code
    assert timeline.completed_real_count == 1  # STEP_06
    assert timeline.completed_auto_count == 5  # STEP_01..STEP_05
    assert timeline.sequence_integrity == "Sequence Gaps Detected"
    assert len(timeline.sequence_warnings) == 5

    # Check that STEP_04 has completion_type='auto' and is_sequence_gap=True
    step_04_item = next(s for s in timeline.steps if s.step_code == "STEP_04")
    assert step_04_item.status == "Completed"
    assert step_04_item.completion_type == "auto"
    assert step_04_item.is_sequence_gap is True


def test_skip_step_blocks_on_open_tasks_without_force(client_and_db):
    client, db = client_and_db
    code = f"TEST-TASK-{int(datetime.now().timestamp())}"

    file_rec = ImportFile(
        import_file_code=code,
        company_name="Task Test Co",
        supplier_name="Task Supplier",
        status="Open",
        is_active=True,
    )
    db.add(file_rec)
    db.commit()
    db.refresh(file_rec)

    # Allow skip on STEP_04 for testing
    cfg = service.repo.get_step_config(db, "STEP_04")
    if not cfg:
        service._ensure_step_configs(db)
        cfg = service.repo.get_step_config(db, "STEP_04")
    cfg.skip_policy = "single_approval"
    db.commit()

    # Add an active SmartTask for STEP_04
    task = SmartTask(
        task_code=f"TSK-{int(datetime.now().timestamp())}",
        title="Review swift transfer details",
        task_type="Manual",
        status="Pending",
        import_file_id=file_rec.import_file_id,
        import_file_code=code,
        step_code="STEP_04",
        is_active=True,
    )
    db.add(task)
    db.commit()

    from modules.lifecycle_board.schemas import SkipStepPayload
    from modules.common.errors import CodedHTTPException

    payload = SkipStepPayload(
        import_file_code=code,
        current_step_code="STEP_04",
        skip_reason="Skipping due to direct advance",
        force_skip=False,
    )

    # Should raise LC_SKIP_HAS_OPEN_TASKS
    with pytest.raises(CodedHTTPException) as excinfo:
        service.skip_step_service(db, payload=payload, current_user_role="Manager")
    assert excinfo.value.code == "LC_SKIP_HAS_OPEN_TASKS"

    # With force_skip=True, should succeed with warning
    payload.force_skip = True
    result = service.skip_step_service(db, payload=payload, current_user_role="Manager")
    assert result["skipped_step"] == "STEP_04"
    assert len(result["warnings"]) == 1
    assert result["warnings"][0]["code"] == "OPEN_TASKS_BYPASSED"
