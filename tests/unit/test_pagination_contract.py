"""
Tests for List Paging & Sorting Standard Contract (BEW0-04).
Covers:
1. Helper unit tests: like_term, apply_sort, paginate.
2. API integration tests on /api/v1/import-files/paginated:
   - page_size bounds (0 and 201 -> 422)
   - page bounds (0 -> 422)
   - unknown sort field -> 400 LIST_SORT_FIELD_INVALID
   - valid sort order and PK tie-breaking
   - wildcard escaping (e.g. '50%')
   - X-Total-Count header matching total
   - page past end returns empty items with accurate total & total_pages.
"""

import pytest
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Response
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from modules.common.pagination import PageParams, Page, like_term, apply_sort, paginate
from modules.common.system_messages import SysMsg
from modules.auth.router import get_current_user
from modules.users.model import User, Role
from modules.import_files.model import ImportFile
import modules.import_files.router as import_files_router


# ─── 1. Helper Unit Tests ────────────────────────────────────────────────────

SampleBase = declarative_base()


class SampleModel(SampleBase):
    __tablename__ = "sample_items"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    score = Column(Integer, nullable=False)


@pytest.fixture
def sample_db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    SampleBase.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    for i in range(1, 11):
        db.add(SampleModel(name=f"item_{i:02d}", score=100 - i))
    db.commit()
    yield db
    db.close()
    engine.dispose()


def test_like_term_escaping():
    assert like_term(None) is None
    assert like_term("") is None
    assert like_term("   ") is None
    assert like_term("hello") == "%hello%"
    # Wildcards % and _ and \ must be escaped
    assert like_term("50%") == r"%50\%%"
    assert like_term("under_score") == r"%under\_score%"
    assert like_term(r"back\slash") == r"%back\\slash%"
    assert like_term("  clean  ") == "%clean%"


def test_apply_sort_valid(sample_db):
    sort_map = {"score": SampleModel.score, "name": SampleModel.name}
    default = [SampleModel.id.asc()]

    # Sort descending by score
    q = apply_sort(sample_db.query(SampleModel), "-score", sort_map, default, SampleModel.id)
    items = q.all()
    assert items[0].score == 99
    assert items[-1].score == 90

    # Sort ascending by name with PK tie-breaker
    q2 = apply_sort(sample_db.query(SampleModel), "name", sort_map, default, SampleModel.id)
    items2 = q2.all()
    assert items2[0].name == "item_01"
    assert items2[-1].name == "item_10"


def test_apply_sort_invalid_field(sample_db):
    sort_map = {"score": SampleModel.score, "name": SampleModel.name}
    default = [SampleModel.id.asc()]

    with pytest.raises(HTTPException) as exc_info:
        apply_sort(sample_db.query(SampleModel), "hacker_field", sort_map, default, SampleModel.id)

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail["code"] == "LIST_SORT_FIELD_INVALID"
    assert exc_info.value.detail["field"] == "hacker_field"
    assert "score" in exc_info.value.detail["allowed"]


def test_paginate_envelope_and_header(sample_db):
    sort_map = {"score": SampleModel.score}
    default = [SampleModel.id.asc()]
    params = PageParams(page=1, page_size=4)
    resp = Response()

    result = paginate(
        sample_db.query(SampleModel),
        params,
        sort_map=sort_map,
        default_sort=default,
        pk=SampleModel.id,
        response=resp,
    )

    assert result["total"] == 10
    assert result["page"] == 1
    assert result["page_size"] == 4
    assert result["total_pages"] == 3
    assert len(result["items"]) == 4
    assert resp.headers.get("X-Total-Count") == "10"


def test_paginate_page_past_end(sample_db):
    sort_map = {"score": SampleModel.score}
    default = [SampleModel.id.asc()]
    params = PageParams(page=10, page_size=4)
    resp = Response()

    result = paginate(
        sample_db.query(SampleModel),
        params,
        sort_map=sort_map,
        default_sort=default,
        pk=SampleModel.id,
        response=resp,
    )

    assert result["total"] == 10
    assert result["page"] == 10
    assert result["page_size"] == 4
    assert result["total_pages"] == 3
    assert result["items"] == []
    assert resp.headers.get("X-Total-Count") == "10"


def test_paginate_empty(sample_db):
    sort_map = {"score": SampleModel.score}
    default = [SampleModel.id.asc()]
    params = PageParams(page=1, page_size=10)
    resp = Response()

    result = paginate(
        sample_db.query(SampleModel).filter(SampleModel.score > 1000),
        params,
        sort_map=sort_map,
        default_sort=default,
        pk=SampleModel.id,
        response=resp,
    )

    assert result["total"] == 0
    assert result["page"] == 1
    assert result["page_size"] == 10
    assert result["total_pages"] == 1
    assert result["items"] == []
    assert resp.headers.get("X-Total-Count") == "0"


# ─── 2. API Integration Tests ───────────────────────────────────────────────

@pytest.fixture
def api_test_env():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False)

    app = FastAPI()
    app.include_router(import_files_router.router)

    admin_user = User(
        user_id=1,
        username="admin_test",
        full_name="Admin Test",
        email="admin@test.com",
        hashed_password="fake_hashed_password",
        role="ADMIN",
        is_active=True,
    )

    def override_get_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    def override_get_current_user():
        return admin_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    # Seed 5 ImportFiles
    db = Session()
    db.add(admin_user)
    files = [
        ImportFile(
            import_file_id=1,
            import_file_code="IMP-001",
            company_name="Alpha Co",
            supplier_name="Supplier 1",
            progress_percent=20.0,
            status="Open",
            current_module="Module 1",
            current_stage="Stage 1",
            next_action="Action 1",
            is_active=True,
            created_by="system",
            updated_by="system",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
        ImportFile(
            import_file_id=2,
            import_file_code="IMP-002",
            company_name="Beta 50% Corp",  # Contains literal '50%'
            supplier_name="Supplier 2",
            progress_percent=80.0,
            status="Active",
            current_module="Module 2",
            current_stage="Stage 2",
            next_action="Action 2",
            is_active=True,
            created_by="system",
            updated_by="system",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
        ImportFile(
            import_file_id=3,
            import_file_code="IMP-003",
            company_name="Gamma Co",
            supplier_name="Supplier 3",
            progress_percent=50.0,
            status="Active",
            current_module="Module 3",
            current_stage="Stage 3",
            next_action="Action 3",
            is_active=True,
            created_by="system",
            updated_by="system",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
    ]
    for f in files:
        db.add(f)
    db.commit()
    db.close()

    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()
    engine.dispose()


def test_api_page_size_max_limit(api_test_env):
    # page_size > 200 must yield 422
    resp = api_test_env.get("/api/v1/import-files/paginated?page_size=201")
    assert resp.status_code == 422


def test_api_page_size_min_limit(api_test_env):
    # page_size < 1 must yield 422
    resp = api_test_env.get("/api/v1/import-files/paginated?page_size=0")
    assert resp.status_code == 422


def test_api_page_min_limit(api_test_env):
    # page < 1 must yield 422
    resp = api_test_env.get("/api/v1/import-files/paginated?page=0")
    assert resp.status_code == 422


def test_api_invalid_sort_field(api_test_env):
    # Invalid sort key must return 400 with LIST_SORT_FIELD_INVALID
    resp = api_test_env.get("/api/v1/import-files/paginated?sort=non_existent_field")
    assert resp.status_code == 400
    data = resp.json()
    assert data["detail"]["code"] == "LIST_SORT_FIELD_INVALID"
    assert data["detail"]["field"] == "non_existent_field"


def test_api_valid_sort_and_header(api_test_env):
    # Sort descending by progress_percent
    resp = api_test_env.get("/api/v1/import-files/paginated?sort=-progress_percent")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert resp.headers.get("X-Total-Count") == "3"
    items = data["items"]
    assert items[0]["progress_percent"] == 80.0
    assert items[1]["progress_percent"] == 50.0
    assert items[2]["progress_percent"] == 20.0


def test_api_wildcard_search_literal(api_test_env):
    # Searching for literal '50%' should only match 'Beta 50% Corp', not other records
    resp = api_test_env.get("/api/v1/import-files/paginated?q=50%")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["company_name"] == "Beta 50% Corp"


def test_api_page_past_end(api_test_env):
    # Requesting page 5 when total is 3
    resp = api_test_env.get("/api/v1/import-files/paginated?page=5&page_size=2")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert data["page"] == 5
    assert data["page_size"] == 2
    assert data["total_pages"] == 2
    assert data["items"] == []
    assert resp.headers.get("X-Total-Count") == "3"
