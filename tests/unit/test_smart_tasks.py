"""
Unit Tests for Smart Task Management & Reminder Engine (Feature 2.4 & 2.5)
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.smart_tasks.schemas import SmartTaskCreate, SmartTaskUpdate
import modules.smart_tasks.service as service
import modules.smart_tasks.repository as repo


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


class TestSmartTasksBackend:
    def test_create_and_get_task(self, db_session):
        schema = SmartTaskCreate(
            title="متابعة صدور نموذج 4 من بنك مصر",
            description="متابعة قسم الاعتماد البنكي للمستندات",
            task_type="Manual To-Do",
            assigned_user="Kamal",
            priority="High",
            reminder_type="Bank Form 4",
            status="Pending",
            due_date="2026-08-20",
        )
        task = service.create_task_service(db_session, schema, user_name="Kamal")

        assert task.task_id is not None
        assert task.task_code.startswith("TSK-")
        assert task.title == "متابعة صدور نموذج 4 من بنك مصر"
        assert task.priority == "High"
        assert task.status == "Pending"

        retrieved = repo.get_task_by_id(db_session, task.task_id)
        assert retrieved is not None
        assert retrieved.task_code == task.task_code

    def test_update_and_soft_delete_restore(self, db_session):
        schema = SmartTaskCreate(
            title="مراجعة مسودة البوليسة Draft B/L",
            task_type="System Generated",
            priority="Critical",
        )
        task = service.create_task_service(db_session, schema)

        # Update
        update_schema = SmartTaskUpdate(status="Completed", notes="تمت المراجعة والاعتماد")
        updated = service.update_task_service(db_session, task.task_id, update_schema)
        assert updated.status == "Completed"
        assert updated.notes == "تمت المراجعة والاعتماد"

        # Soft Delete
        success = repo.soft_delete_task(db_session, task.task_id)
        assert success is True
        assert repo.get_task_by_id(db_session, task.task_id) is None

        # Restore
        restored = repo.restore_task(db_session, task.task_id)
        assert restored is not None
        assert restored.is_active is True

    def test_auto_generate_and_auto_close_system_tasks(self, db_session):
        import_file = ImportFile(
            import_file_id=1,
            custom_file_number="IMP-2026-001",
            import_file_code="IMP-2026-001",
            company_name="Egyptian Import Co",
            supplier_name="ABC Supplier China",
            current_module="Phase 3 - Import Documentation",
            owner="Kamal",
        )
        db_session.add(import_file)
        db_session.commit()

        # Auto generate
        service.auto_generate_system_tasks_for_file(db_session, import_file)

        tasks = repo.get_all_tasks(db_session, import_file_id=1)
        assert len(tasks) >= 1
        assert "Phase 3" in tasks[0].phase_name

        # Auto close
        service.auto_close_completed_phase_tasks(db_session, 1, "Phase 3")
        closed_tasks = repo.get_all_tasks(db_session, import_file_id=1)
        assert closed_tasks[0].status == "Completed"
        assert closed_tasks[0].is_auto_closed is True

    def test_order_by_priority(self, db_session):
        t_low = service.create_task_service(db_session, SmartTaskCreate(title="Low task", priority="Low"))
        t_crit = service.create_task_service(db_session, SmartTaskCreate(title="Critical task", priority="Critical"))
        t_med = service.create_task_service(db_session, SmartTaskCreate(title="Medium task", priority="Medium"))
        t_high = service.create_task_service(db_session, SmartTaskCreate(title="High task", priority="High"))

        prioritized = repo.get_all_tasks(db_session, order_by_priority=True)
        priorities = [t.priority for t in prioritized]
        assert priorities == ["Critical", "High", "Medium", "Low"]
