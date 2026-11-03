import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.projects.schemas import ProjectCreate, ProjectUpdate
from modules.projects.service import ProjectService
from modules.suppliers.model import Supplier
from fastapi import HTTPException


from sqlalchemy.pool import StaticPool

@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()

    from modules.import_companies.service import create_import_company
    from modules.import_companies.schemas import ImportCompanyCreate
    from datetime import date, timedelta

    # Seed required FKs
    company = create_import_company(session, ImportCompanyCreate(
        importer_name="Test Company",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-100200",
        importer_id_expiry=date.today() + timedelta(days=120),
        vat_id="VAT-998877",
        vat_id_expiry=date.today() + timedelta(days=90),
        registration_number="REG-554433",
        registration_expiry=date.today() + timedelta(days=60),
    ))
    from modules.suppliers.service import create_supplier_service
    from modules.suppliers.schemas import SupplierCreate

    supplier = create_supplier_service(session, SupplierCreate(
        company_name="Test Supplier",
        supplier_type="Manufacturer",
        registration_type="Factory",
        foreign_exporter_id="EXP-CN-8899",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="China",
    ))
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free on Board", is_active=True)
    session.add(incoterm)
    session.commit()

    try:
        yield session
    finally:
        session.close()


class TestProjectsBackend:

    def test_create_project(self, db_session):
        service = ProjectService(db_session)
        data = ProjectCreate(
            project_name="Solar Power Project",
            project_owner="Eng. Ali",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            import_type="Direct Commercial",
            priority="High",
            shipment_category="FCL Container",
            allow_multi_shipment=True,
            allow_multi_company=True,
            total_budget_usd=500000.0,
        )
        proj = service.create(data)

        assert proj.project_id is not None
        assert proj.project_code.startswith("PRJ-")
        assert proj.allow_multi_shipment is True
        assert proj.allow_multi_company is True
        assert proj.status == "Open"

    def test_pl01_new_import_project_creation_and_budget_tracking(self, db_session):
        """PL-01: Create new import project with estimated budget and target end date tracking."""
        service = ProjectService(db_session)
        data = ProjectCreate(
            project_name="خط إنتاج آلات صناعية 2026",
            project_owner="Eng. Ahmed Salah",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            import_type="Direct Commercial",
            priority="High",
            shipment_category="FCL Container",
            total_budget_usd=250000.0,
            target_end_date="2026-12-31",
            notes="مشروع استيراد وتوريد خطوط إنتاج صناعية شاملة التركيب",
        )
        proj = service.create(data)

        assert proj.project_id is not None
        assert proj.project_code.startswith("PRJ-")
        assert proj.project_name == "خط إنتاج آلات صناعية 2026"
        assert proj.total_budget_usd == 250000.0
        assert proj.target_end_date == "2026-12-31"
        assert proj.status == "Open"
        assert proj.is_active is True

        # Test updating target end date and budget
        updated = service.update(
            proj.project_id,
            ProjectUpdate(total_budget_usd=275000.0, target_end_date="2027-01-15")
        )
        assert updated.total_budget_usd == 275000.0
        assert updated.target_end_date == "2027-01-15"

    def test_invalid_fk_raises_400(self, db_session):
        service = ProjectService(db_session)
        data = ProjectCreate(
            project_name="Invalid Project",
            project_owner="Owner",
            company_id=999,  # Non-existent
            supplier_id=1,
            incoterm_id=1,
        )

        with pytest.raises(HTTPException) as exc:
            service.create(data)

        assert exc.value.status_code == 400
        assert "Company with ID 999 does not exist" in exc.value.detail

    def test_update_and_soft_delete_project(self, db_session):
        service = ProjectService(db_session)
        proj = service.create(ProjectCreate(
            project_name="Raw Materials Q3",
            project_owner="Owner",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
        ))

        updated = service.update(proj.project_id, ProjectUpdate(status="Closed", priority="Low"))
        assert updated.status == "Closed"
        assert updated.priority == "Low"

        # Soft Delete
        service.soft_delete(proj.project_id)
        active_list = service.get_all(include_inactive=False)
        assert len(active_list) == 0

        # Restore
        restored = service.restore(proj.project_id)
        assert restored.is_active is True
        active_list = service.get_all(include_inactive=False)
        assert len(active_list) == 1

    def test_create_project_rbac_enforcement(self, db_session):
        """Verify require_permission('master_data.edit') blocks unauthorized project creation (BEX-T06)."""
        from fastapi.testclient import TestClient
        from main import app
        from database.database import get_db
        from modules.users.model import User, Role, Permission, RolePermission
        from modules.auth.security import create_access_token, hash_password

        app.dependency_overrides[get_db] = lambda: db_session
        client = TestClient(app)

        # 1. User without master_data.edit
        role_op = Role(role_code="OP_PROJ", name_en="Operator", name_ar="مشغل", is_active=True)
        db_session.add(role_op)
        db_session.flush()

        user_viewer = User(
            username="proj_viewer",
            full_name="Project Viewer",
            email="pv@ex.com",
            hashed_password=hash_password("Secret123!"),
            is_active=True,
            role="OP_PROJ",
            role_id=role_op.role_id,
        )
        db_session.add(user_viewer)
        db_session.commit()
        token_viewer = create_access_token({"sub": str(user_viewer.user_id), "username": user_viewer.username, "role": user_viewer.role})

        payload = {
            "project_name": "Unauthorized Project",
            "project_owner": "Eng. Test",
            "company_id": 1,
            "supplier_id": 1,
            "incoterm_id": 1,
        }
        res_denied = client.post("/api/v1/projects", json=payload, headers={"Authorization": f"Bearer {token_viewer}"})
        assert res_denied.status_code == 403
        assert "permission" in res_denied.text.lower() or "denied" in res_denied.text.lower() or "forbidden" in res_denied.text.lower()

        # 2. User with master_data.edit
        p_edit = Permission(permission_code="master_data.edit", module_name="master_data", action="edit", name_en="Edit Master Data", name_ar="تعديل البيانات المرجعية")
        db_session.add(p_edit)
        db_session.flush()

        role_editor = Role(role_code="PROJ_EDITOR", name_en="Project Editor", name_ar="محرر مشاريع", is_active=True)
        db_session.add(role_editor)
        db_session.flush()
        db_session.add(RolePermission(role_id=role_editor.role_id, permission_id=p_edit.permission_id))

        user_editor = User(
            username="proj_editor",
            full_name="Project Editor",
            email="pe@ex.com",
            hashed_password=hash_password("Secret123!"),
            is_active=True,
            role="PROJ_EDITOR",
            role_id=role_editor.role_id,
        )
        db_session.add(user_editor)
        db_session.commit()
        token_editor = create_access_token({"sub": str(user_editor.user_id), "username": user_editor.username, "role": user_editor.role})

        res_allowed = client.post("/api/v1/projects", json=payload, headers={"Authorization": f"Bearer {token_editor}"})
        assert res_allowed.status_code == 201
        assert res_allowed.json()["project_name"] == "Unauthorized Project"
        app.dependency_overrides.clear()
