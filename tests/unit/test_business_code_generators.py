import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
import modules.import_files.repository as import_file_repo
from modules.import_files.schemas import ImportFileCreate
from modules.import_files.service import create_import_file_service

from modules.projects.model import Project
from modules.projects.repository import ProjectRepository
from modules.projects.schemas import ProjectCreate

from modules.suppliers.model import Supplier
from modules.suppliers.service import generate_supplier_code, create_supplier_service
from modules.suppliers.schemas import SupplierCreate

from modules.smart_tasks.model import SmartTask
from modules.smart_tasks.repository import generate_task_code, create_task
from modules.smart_tasks.schemas import SmartTaskCreate

from modules.import_companies.model import ImportCompany
from modules.incoterms.model import Incoterm


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()

    # Seed required reference data
    company = ImportCompany(
        company_id=1,
        importer_name="Al-Sorour Trading Co.",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100200",
        importer_id_expiry=date.today() + timedelta(days=180),
        vat_id="VAT-998877",
        vat_id_expiry=date.today() + timedelta(days=180),
        registration_number="REG-554433",
        registration_expiry=date.today() + timedelta(days=180),
        is_active=True,
    )
    session.add(company)

    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-000001",
        company_name="Shanghai Machinery Ltd",
        supplier_type="Manufacturer",
        registration_type="Factory",
        foreign_exporter_id="EXP-SUP-000001",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai, China",
        is_active=True,
    )
    session.add(supplier)

    incoterm = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free on Board",
        description="Free on Board",
        is_active=True,
    )
    session.add(incoterm)
    session.commit()

    yield session
    session.close()
    Base.metadata.drop_all(engine)


def test_import_file_code_generator_with_gaps_and_soft_delete(db_session):
    """
    Acceptance criteria BEX-T12:
    Existing codes IMP-2026-0001, IMP-2026-0002, IMP-2026-0007 (clone)
    and one soft-deleted IMP-2026-0003 -> next is IMP-2026-0008.
    """
    # Insert existing records
    records = [
        ImportFile(
            import_file_code="IMP-2026-0001",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=True,
        ),
        ImportFile(
            import_file_code="IMP-2026-0002",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=True,
        ),
        ImportFile(
            import_file_code="IMP-2026-0007",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=True,
        ),
        ImportFile(
            import_file_code="IMP-2026-0003",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=False,  # soft deleted
        ),
    ]
    for r in records:
        db_session.add(r)
    db_session.commit()

    # Verify generate_import_file_code returns next highest + 1
    next_code = import_file_repo.generate_import_file_code(db_session, year=2026)
    assert next_code == "IMP-2026-0008"

    # Creating a new import file generates IMP-2026-0008
    created = create_import_file_service(
        db_session,
        ImportFileCreate(
            company_id=1,
            company_name="Al-Sorour Trading Co.",
            supplier_id=1,
            supplier_name="Shanghai Machinery Ltd",
            shipment_mode="Sea Freight FCL",
            port_of_loading="Shanghai",
            port_of_discharge="Alexandria Port",
        ),
    )
    assert created.import_file_code == "IMP-2026-0008"


def test_project_code_generator_restarts_per_year(db_session):
    """
    Acceptance criteria BEX-T12:
    Projects PRJ-2025-001..010 and none in 2026 -> PRJ-2026-001.
    """
    repo = ProjectRepository(db_session)

    # Insert 10 projects for 2025
    for i in range(1, 11):
        db_session.add(
            Project(
                project_code=f"PRJ-2025-{i:03d}",
                project_name=f"Project 2025-{i}",
                project_owner="Ahmed",
                company_id=1,
                supplier_id=1,
                incoterm_id=1,
                is_active=True,
            )
        )
    db_session.commit()

    # Year 2026 code generation must restart at PRJ-2026-001 (not PRJ-2026-011)
    next_code = repo.generate_project_code(year=2026)
    assert next_code == "PRJ-2026-001"


def test_supplier_code_generator_with_gaps_and_soft_delete(db_session):
    """
    Acceptance criteria BEX-T12:
    Suppliers SUP-000001 (from fixture), SUP-000002, SUP-000005 (gap),
    and one soft-deleted SUP-000003 -> next is SUP-000006.
    """
    db_session.add(
        Supplier(
            supplier_code="SUP-000002",
            company_name="Supplier 2",
            supplier_type="Trader",
            registration_type="Company",
            foreign_exporter_id="EXP-SUP-000002",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
            is_active=True,
        )
    )
    db_session.add(
        Supplier(
            supplier_code="SUP-000005",
            company_name="Supplier 5",
            supplier_type="Trader",
            registration_type="Company",
            foreign_exporter_id="EXP-SUP-000005",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
            is_active=True,
        )
    )
    db_session.add(
        Supplier(
            supplier_code="SUP-000003",
            company_name="Supplier 3",
            supplier_type="Trader",
            registration_type="Company",
            foreign_exporter_id="EXP-SUP-000003",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
            is_active=False,  # soft deleted
        )
    )
    db_session.commit()

    next_code = generate_supplier_code(db_session)
    assert next_code == "SUP-000006"

    # Creating a supplier via service creates SUP-000006
    created = create_supplier_service(
        db_session,
        SupplierCreate(
            company_name="New Supplier 6",
            supplier_type="Manufacturer",
            registration_type="Factory",
            foreign_exporter_country="Germany",
            foreign_exporter_country_code="DE",
        ),
    )
    assert created.supplier_code == "SUP-000006"


def test_smart_task_code_generator_yearly_and_gaps(db_session):
    """
    Smart tasks: TSK-2025-0001..0010, and in 2026: TSK-2026-0001, TSK-2026-0004 (gap).
    Next for 2026 must be TSK-2026-0005.
    """
    # 2025 tasks
    for i in range(1, 11):
        db_session.add(
            SmartTask(
                task_code=f"TSK-2025-{i:04d}",
                title=f"Task 2025 {i}",
                is_active=True,
            )
        )
    # 2026 tasks with gap
    db_session.add(
        SmartTask(
            task_code="TSK-2026-0001",
            title="Task 2026 1",
            is_active=True,
        )
    )
    db_session.add(
        SmartTask(
            task_code="TSK-2026-0004",
            title="Task 2026 4",
            is_active=True,
        )
    )
    db_session.commit()

    next_code = generate_task_code(db_session, year=2026)
    assert next_code == "TSK-2026-0005"


def test_non_digit_suffixes_are_ignored(db_session):
    """
    Non-numeric suffixes like COPY, DRAFT, OLD should be ignored by numeric max sequence.
    """
    db_session.add(
        ImportFile(
            import_file_code="IMP-2026-COPY",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=True,
        )
    )
    db_session.add(
        Supplier(
            supplier_code="SUP-LEGACY-01",
            company_name="Legacy Supplier",
            supplier_type="Trader",
            registration_type="Company",
            foreign_exporter_id="EXP-LEGACY-01",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Shanghai, China",
            is_active=True,
        )
    )
    db_session.add(
        Project(
            project_code="PRJ-2026-DRAFT",
            project_name="Draft Project",
            project_owner="Ahmed",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            is_active=True,
        )
    )
    db_session.add(
        SmartTask(
            task_code="TSK-2026-NOTE",
            title="Note task",
            is_active=True,
        )
    )
    db_session.commit()

    # All should ignore non-digit codes and pick next numeric suffix
    # For IMP: no numeric codes exist yet -> IMP-2026-0001
    assert import_file_repo.generate_import_file_code(db_session, year=2026) == "IMP-2026-0001"
    # For PRJ: no numeric 2026 codes exist yet -> PRJ-2026-001
    repo = ProjectRepository(db_session)
    assert repo.generate_project_code(year=2026) == "PRJ-2026-001"
    # For TSK: no numeric 2026 codes exist yet -> TSK-2026-0001
    assert generate_task_code(db_session, year=2026) == "TSK-2026-0001"
    # For SUP: SUP-000001 exists from fixture -> SUP-000002
    assert generate_supplier_code(db_session) == "SUP-000002"


def test_import_file_create_retry_on_collision(db_session):
    """
    Test that when an IntegrityError occurs on the first attempt due to a race
    condition, the service/repo retries, generates the next code, and succeeds.
    """
    attempt_count = 0
    orig_generate = import_file_repo.generate_import_file_code

    def colliding_generate(db, year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            # First attempt returns a code that already exists
            return "IMP-2026-0001"
        return orig_generate(db, year=year)

    # Insert an existing file with IMP-2026-0001
    db_session.add(
        ImportFile(
            import_file_code="IMP-2026-0001",
            custom_file_number="FILE-2026-0001",
            company_name="Al-Sorour",
            supplier_name="Shanghai",
            is_active=True,
        )
    )
    db_session.commit()

    import modules.import_files.repository as if_repo
    saved_gen = if_repo.generate_import_file_code
    if_repo.generate_import_file_code = colliding_generate
    try:
        created = create_import_file_service(
            db_session,
            ImportFileCreate(
                company_id=1,
                company_name="Al-Sorour Trading Co.",
                supplier_id=1,
                supplier_name="Shanghai Machinery Ltd",
                shipment_mode="Sea Freight FCL",
                port_of_loading="Shanghai",
                port_of_discharge="Alexandria Port",
            ),
        )
        assert created.import_file_code == "IMP-2026-0002"
        assert attempt_count >= 2
    finally:
        if_repo.generate_import_file_code = saved_gen


def test_supplier_create_retry_on_collision(db_session):
    """
    Test that create_supplier_service retries on IntegrityError and succeeds.
    """
    attempt_count = 0
    import modules.suppliers.service as sup_service
    orig_gen = sup_service.generate_supplier_code

    def colliding_gen(db):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return "SUP-000001"  # Already in fixture
        return orig_gen(db)

    sup_service.generate_supplier_code = colliding_gen
    try:
        created = create_supplier_service(
            db_session,
            SupplierCreate(
                company_name="Retried Supplier",
                supplier_type="Manufacturer",
                registration_type="Factory",
                foreign_exporter_country="Japan",
                foreign_exporter_country_code="JP",
            ),
        )
        assert created.supplier_code == "SUP-000002"
        assert attempt_count >= 2
    finally:
        sup_service.generate_supplier_code = orig_gen


def test_project_create_retry_on_collision(db_session):
    """
    Test that ProjectRepository.create retries on IntegrityError and succeeds.
    """
    repo = ProjectRepository(db_session)
    # Insert existing project
    db_session.add(
        Project(
            project_code="PRJ-2026-001",
            project_name="Existing Project",
            project_owner="Ahmed",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    orig_gen = repo.generate_project_code

    def colliding_gen(year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return "PRJ-2026-001"
        return orig_gen(year=year)

    repo.generate_project_code = colliding_gen
    created = repo.create(
        ProjectCreate(
            project_name="New Project",
            project_owner="Ahmed",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
        )
    )
    assert created.project_code == "PRJ-2026-002"
    assert attempt_count >= 2


def test_smart_task_create_retry_on_collision(db_session):
    """
    Test that smart_tasks.create_task retries on IntegrityError and succeeds.
    """
    # Insert existing task
    db_session.add(
        SmartTask(
            task_code="TSK-2026-0001",
            title="Existing Task",
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    import modules.smart_tasks.repository as task_repo
    orig_gen = task_repo.generate_task_code

    def colliding_gen(db, year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return "TSK-2026-0001"
        return orig_gen(db, year=year)

    task_repo.generate_task_code = colliding_gen
    try:
        created = create_task(
            db_session,
            SmartTaskCreate(
                title="New Retried Task",
            ),
        )
        assert created.task_code == "TSK-2026-0002"
        assert attempt_count >= 2
    finally:
        task_repo.generate_task_code = orig_gen
