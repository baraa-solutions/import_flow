import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.users.model import User

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def export_client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    mock_user = User(
        user_id=1,
        username="admin_test",
        email="admin@test.com",
        full_name="Admin Test",
        role="ADMIN",
        is_active=True,
    )

    main.app.dependency_overrides[get_db] = override_get_db
    # Dev bypass returns mock admin for all auth checks
    test_client = TestClient(main.app, headers={"X-User-Role": "ADMIN", "X-User-Name": "admin_test"})
    yield test_client
    main.app.dependency_overrides.clear()


@pytest.mark.parametrize(
    "excel_path,expected_prefix",
    [
        ("/api/v1/import-companies/export-excel", "Egyptian_Import_Companies"),
        ("/api/v1/suppliers/export-excel", "Foreign_Suppliers"),
        ("/api/v1/external-service-providers/export-excel", "Partners_Banks"),
        ("/api/v1/currencies/export-excel", "Currencies_Exchange_Rates"),
        ("/api/v1/incoterms/export-excel", "Incoterms_Rules"),
        ("/api/v1/projects/export-excel", "Projects_CostCenters"),
        ("/api/v1/customs-tariff/export-excel", "Customs_Tariff_Schedule"),
        ("/api/v1/transport-locations/export-excel", "Transport_Locations"),
        ("/api/v1/import-files/export-excel", "Import_Files_Master"),
    ],
)
def test_master_data_excel_exports(export_client, excel_path, expected_prefix):
    res = export_client.get(excel_path)
    assert res.status_code == 200, f"Failed GET {excel_path}: {res.text}"
    assert "application/vnd.openxmlformats" in res.headers["content-type"]
    today_str = date.today().strftime("%Y-%m-%d")
    expected_filename = f"{expected_prefix}_{today_str}.xlsx"
    cd = res.headers.get("content-disposition", "")
    assert f"filename={expected_filename}" in cd or f'filename="{expected_filename}"' in cd
    assert res.content[:2] == b"PK"  # OpenXML ZIP header


@pytest.mark.parametrize(
    "pdf_path,expected_prefix",
    [
        ("/api/v1/import-companies/export-pdf", "Egyptian_Import_Companies"),
        ("/api/v1/suppliers/export-pdf", "Foreign_Suppliers"),
        ("/api/v1/external-service-providers/export-pdf", "Partners_Banks"),
        ("/api/v1/currencies/export-pdf", "Currencies_Exchange_Rates"),
        ("/api/v1/incoterms/export-pdf", "Incoterms_Rules"),
        ("/api/v1/projects/export-pdf", "Projects_CostCenters"),
        ("/api/v1/customs-tariff/export-pdf", "Customs_Tariff_Schedule"),
        ("/api/v1/transport-locations/export-pdf", "Transport_Locations"),
        ("/api/v1/import-files/export-pdf", "Import_Files_Master"),
    ],
)
def test_master_data_pdf_exports(export_client, pdf_path, expected_prefix):
    res = export_client.get(pdf_path)
    assert res.status_code == 200, f"Failed GET {pdf_path}: {res.text}"
    assert "application/pdf" in res.headers["content-type"]
    today_str = date.today().strftime("%Y-%m-%d")
    expected_filename = f"{expected_prefix}_{today_str}.pdf"
    cd = res.headers.get("content-disposition", "")
    assert f"filename={expected_filename}" in cd or f'filename="{expected_filename}"' in cd
    assert res.content[:4] == b"%PDF"  # PDF header
