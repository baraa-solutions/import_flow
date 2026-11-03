import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.transport_locations.model import TransportLocation
from modules.transport_locations.schemas import TransportLocationCreate, TransportLocationUpdate
from modules.transport_locations.service import TransportLocationService
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
    try:
        yield session
    finally:
        session.close()


class TestTransportLocationsBackend:

    def test_create_transport_location(self, db_session):
        service = TransportLocationService(db_session)
        data = TransportLocationCreate(
            un_locode="egaly",
            location_name="Alexandria Port",
            location_type="Sea Port",
            country="Egypt",
            city="Alexandria",
            notes="Main Port",
        )
        loc = service.create(data)

        assert loc.location_id is not None
        assert loc.un_locode == "EGALY"  # Uppercased automatically
        assert loc.location_name == "Alexandria Port"
        assert loc.is_active is True

    def test_duplicate_un_locode_raises_400(self, db_session):
        service = TransportLocationService(db_session)
        data = TransportLocationCreate(
            un_locode="EGCAI",
            location_name="Cairo Airport",
            location_type="Airport",
            country="Egypt",
            city="Cairo",
        )
        service.create(data)

        with pytest.raises(HTTPException) as exc_info:
            service.create(data)

        assert exc_info.value.status_code == 400
        assert "already exists" in exc_info.value.detail

    def test_get_all_filtering_and_search(self, db_session):
        service = TransportLocationService(db_session)
        service.create(TransportLocationCreate(un_locode="EGALY", location_name="Alexandria Port", location_type="Sea Port", country="Egypt", city="Alexandria"))
        service.create(TransportLocationCreate(un_locode="EGCAI", location_name="Cairo Airport", location_type="Airport", country="Egypt", city="Cairo"))
        service.create(TransportLocationCreate(un_locode="CNSHA", location_name="Shanghai Port", location_type="Sea Port", country="China", city="Shanghai"))

        sea_ports = service.get_all(location_type="Sea Port")
        assert len(sea_ports) == 2

        china_locs = service.get_all(country="China")
        assert len(china_locs) == 1
        assert china_locs[0].un_locode == "CNSHA"

        search_results = service.get_all(search="Cairo")
        assert len(search_results) == 1
        assert search_results[0].un_locode == "EGCAI"

    def test_update_transport_location(self, db_session):
        service = TransportLocationService(db_session)
        loc = service.create(TransportLocationCreate(un_locode="EGSOK", location_name="Sokhna Port", location_type="Sea Port", country="Egypt", city="Suez"))

        updated = service.update(loc.location_id, TransportLocationUpdate(location_name="Ain Sokhna Deepwater Port"))
        assert updated.location_name == "Ain Sokhna Deepwater Port"

    def test_soft_delete_and_restore(self, db_session):
        service = TransportLocationService(db_session)
        loc = service.create(TransportLocationCreate(un_locode="EGSLM", location_name="Salloum Port", location_type="Land Border", country="Egypt", city="Matrouh"))

        # Soft delete
        service.soft_delete(loc.location_id)
        active_list = service.get_all(include_inactive=False)
        assert len(active_list) == 0

        # Restore
        restored = service.restore(loc.location_id)
        assert restored.is_active is True
        active_list = service.get_all(include_inactive=False)
        assert len(active_list) == 1

    def test_create_location_rbac_enforcement(self, db_session):
        """Verify require_permission('master_data.edit') blocks unauthorized calls (BEX-T05)."""
        from fastapi.testclient import TestClient
        from main import app
        from database.database import get_db
        from modules.users.model import User, Role, Permission, RolePermission
        from modules.auth.security import create_access_token, hash_password

        app.dependency_overrides[get_db] = lambda: db_session
        client = TestClient(app)

        # 1. User without master_data.edit
        role_op = Role(role_code="OPERATOR", name_en="Operator", name_ar="مشغل", is_active=True)
        db_session.add(role_op)
        db_session.flush()

        user_viewer = User(
            username="loc_viewer",
            full_name="Location Viewer",
            email="v@ex.com",
            hashed_password=hash_password("Secret123!"),
            is_active=True,
            role="OPERATOR",
            role_id=role_op.role_id,
        )
        db_session.add(user_viewer)
        db_session.commit()
        token_viewer = create_access_token({"sub": str(user_viewer.user_id), "username": user_viewer.username, "role": user_viewer.role})

        payload = {
            "un_locode": "EGRBC",
            "location_name": "RBAC Port",
            "location_type": "Sea Port",
            "country": "Egypt",
            "city": "Alexandria",
        }
        res_denied = client.post("/api/v1/transport-locations", json=payload, headers={"Authorization": f"Bearer {token_viewer}"})
        assert res_denied.status_code == 403
        assert "permission" in res_denied.text.lower() or "denied" in res_denied.text.lower() or "forbidden" in res_denied.text.lower()

        # 2. User with master_data.edit
        p_edit = Permission(permission_code="master_data.edit", module_name="master_data", action="edit", name_en="Edit Master Data", name_ar="تعديل البيانات المرجعية")
        db_session.add(p_edit)
        db_session.flush()

        role_editor = Role(role_code="DATA_EDITOR", name_en="Editor", name_ar="محرر", is_active=True)
        db_session.add(role_editor)
        db_session.flush()
        db_session.add(RolePermission(role_id=role_editor.role_id, permission_id=p_edit.permission_id))

        user_editor = User(
            username="loc_editor",
            full_name="Location Editor",
            email="ed@ex.com",
            hashed_password=hash_password("Secret123!"),
            is_active=True,
            role="DATA_EDITOR",
            role_id=role_editor.role_id,
        )
        db_session.add(user_editor)
        db_session.commit()
        token_editor = create_access_token({"sub": str(user_editor.user_id), "username": user_editor.username, "role": user_editor.role})

        res_allowed = client.post("/api/v1/transport-locations", json=payload, headers={"Authorization": f"Bearer {token_editor}"})
        assert res_allowed.status_code == 201
        assert res_allowed.json()["un_locode"] == "EGRBC"
        app.dependency_overrides.clear()
