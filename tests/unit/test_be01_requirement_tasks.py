"""
Test BE01-T19: Requirement task sync hygiene.
Verifies exact token delimiter REQ_TYPE:<key>| matching, escaping of wildcard characters,
and that completing global 'COO' closes only the 'COO' task without accidentally closing 'COO_8415820010'.
"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.import_requirements.model import ImportRequirementAssessment
from modules.smart_tasks.model import SmartTask
from modules.import_requirements.service import sync_regulatory_tasks_and_alerts


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_be01_t19_coo_tasks_close_isolation(db_session):
    # 1. Setup ImportFile
    file = ImportFile(
        import_file_code="IMP-2026-TEST",
        company_name="Test Company",
        supplier_name="Test Supplier",
        owner="test_user",
        status="Active",
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # 2. Open tasks COO and COO_8415820010
    task_global = SmartTask(
        task_code="TASK-001",
        title="Global COO",
        import_file_id=file.import_file_id,
        import_file_code=file.import_file_code,
        notes="REQ_TYPE:COO| ASSESSMENT:REQ-2026-0001",
        status="Pending",
        is_active=True,
        assigned_user=file.owner,
        due_date=None,
    )
    task_hs = SmartTask(
        task_code="TASK-002",
        title="HS COO",
        import_file_id=file.import_file_id,
        import_file_code=file.import_file_code,
        notes="REQ_TYPE:COO_8415820010| ASSESSMENT:REQ-2026-0001",
        status="Pending",
        is_active=True,
        assigned_user=file.owner,
        due_date=None,
    )
    db_session.add_all([task_global, task_hs])
    db_session.commit()

    # 3. Setup Assessment where global COO is completed
    assessment = ImportRequirementAssessment(
        assessment_code="REQ-2026-0001",
        import_file_id=file.import_file_id,
        coo_required=True,
        coo_status="Approved",
        hs_code_items=[],
    )
    db_session.add(assessment)
    db_session.commit()
    db_session.refresh(assessment)

    # 4. Trigger sync
    sync_regulatory_tasks_and_alerts(db_session, assessment.assessment_id)
    db_session.commit()

    db_session.refresh(task_global)
    db_session.refresh(task_hs)

    # Assert that completing global COO closes ONLY the COO task
    assert task_global.status == "Completed"
    assert task_global.is_auto_closed is True

    # And COO_8415820010 remains Pending and not auto closed
    assert task_hs.status == "Pending"
    assert task_hs.is_auto_closed is not True


def test_be01_t19_task_creation_owner_and_no_due_date(db_session):
    # Setup ImportFile with owner
    file = ImportFile(
        import_file_code="IMP-2026-OWNER",
        company_name="Owner Co",
        supplier_name="Supplier Co",
        owner="procurement_mgr",
        status="Active",
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # Assessment with uncompleted import permit
    assessment = ImportRequirementAssessment(
        assessment_code="REQ-2026-PERMIT",
        import_file_id=file.import_file_id,
        import_permit_required=True,
        permit_status="Required",
        hs_code_items=[],
    )
    db_session.add(assessment)
    db_session.commit()
    db_session.refresh(assessment)

    sync_regulatory_tasks_and_alerts(db_session, assessment.assessment_id)
    db_session.commit()

    task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == file.import_file_id,
        SmartTask.notes.like("%REQ_TYPE:Permit|%", escape="\\"),
    ).first()

    assert task is not None
    assert task.assigned_user == "procurement_mgr"
    assert task.due_date is None
    assert task.import_file_code == "IMP-2026-OWNER"
    assert "REQ_TYPE:Permit|" in task.notes


def test_be01_t19_task_creation_without_owner(db_session):
    # Setup ImportFile without owner (empty string)
    file = ImportFile(
        import_file_code="IMP-2026-NO-OWNER",
        company_name="Ownerless Co",
        supplier_name="Supplier Co",
        owner="",
        status="Active",
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # Assessment with uncompleted halal cert
    assessment = ImportRequirementAssessment(
        assessment_code="REQ-2026-HALAL",
        import_file_id=file.import_file_id,
        halal_cert_required=True,
        halal_cert_status="Required",
        hs_code_items=[],
    )
    db_session.add(assessment)
    db_session.commit()
    db_session.refresh(assessment)

    sync_regulatory_tasks_and_alerts(db_session, assessment.assessment_id)
    db_session.commit()

    task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == file.import_file_id,
        SmartTask.notes.like("%REQ_TYPE:Halal|%", escape="\\"),
    ).first()

    assert task is not None
    assert task.assigned_user is None
    assert task.due_date is None
    assert task.import_file_code == "IMP-2026-NO-OWNER"
    assert "REQ_TYPE:Halal|" in task.notes
