import pytest
from fastapi.testclient import TestClient
from main import app
from database.database import get_db, SessionLocal
from modules.users.model import User

client = TestClient(app)


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def auth_headers(db_session):
    from modules.auth.router import get_current_user

    user = db_session.query(User).first()
    if not user:
        user = User(
            username="testadmin",
            full_name="Test Admin",
            email="testadmin@sorour.com",
            role="ADMIN",
            is_active=True,
            hashed_password="hashed_placeholder"
        )
        db_session.add(user)
        db_session.commit()
    else:
        user.role = "ADMIN"
        user.is_active = True
        user.must_change_password = False
        db_session.commit()

    from modules.auth.security import create_access_token
    # BEX-T08: carry the user's current token_version, other tests may have bumped it in the shared DB.
    token = create_access_token({"sub": str(user.user_id), "username": user.username, "tv": user.token_version or 0})

    app.dependency_overrides[get_current_user] = lambda: user
    yield {"Authorization": f"Bearer {token}"}
    app.dependency_overrides.pop(get_current_user, None)


def test_import_companies_exports_csv_excel_pdf(auth_headers):
    # Test CSV Arabic
    r_csv_ar = client.get("/api/v1/import-companies/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    assert r_csv_ar.headers["content-type"].startswith("text/csv")
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود الشركة" in csv_text_ar
    assert "اسم الشركة المستوردة" in csv_text_ar
    assert "(" not in csv_text_ar.splitlines()[0]  # No bilingual parentheses

    # Test CSV English
    r_csv_en = client.get("/api/v1/import-companies/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    csv_text_en = r_csv_en.content.decode("utf-8")
    assert "Company Name" in csv_text_en
    assert "كود الشركة" not in csv_text_en

    # Test Excel
    r_xlsx_ar = client.get("/api/v1/import-companies/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200
    assert len(r_xlsx_ar.content) > 1000

    r_xlsx_en = client.get("/api/v1/import-companies/export-excel?lang=en", headers=auth_headers)
    assert r_xlsx_en.status_code == 200

    # Test PDF
    r_pdf_ar = client.get("/api/v1/import-companies/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200
    assert r_pdf_ar.headers["content-type"] == "application/pdf"

    r_pdf_en = client.get("/api/v1/import-companies/export-pdf?lang=en", headers=auth_headers)
    assert r_pdf_en.status_code == 200


def test_suppliers_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/suppliers/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود المورد" in csv_text_ar

    r_csv_en = client.get("/api/v1/suppliers/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    csv_text_en = r_csv_en.content.decode("utf-8")
    assert "Company Name" in csv_text_en

    r_xlsx_ar = client.get("/api/v1/suppliers/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/suppliers/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_partners_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/external-service-providers/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود الشريك" in csv_text_ar

    r_csv_en = client.get("/api/v1/external-service-providers/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    csv_text_en = r_csv_en.content.decode("utf-8")
    assert "Partner Name" in csv_text_en

    r_xlsx_ar = client.get("/api/v1/external-service-providers/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/external-service-providers/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_customs_tariff_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/customs-tariff/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "بند التعريفة" in csv_text_ar

    r_csv_en = client.get("/api/v1/customs-tariff/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    csv_text_en = r_csv_en.content.decode("utf-8")
    assert "HS Code" in csv_text_en

    r_xlsx_ar = client.get("/api/v1/customs-tariff/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/customs-tariff/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_projects_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/projects/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود المشروع" in csv_text_ar

    r_csv_en = client.get("/api/v1/projects/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    assert "Project Code" in r_csv_en.content.decode("utf-8")

    r_xlsx_ar = client.get("/api/v1/projects/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/projects/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_transport_locations_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/transport-locations/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "اسم الموقع" in csv_text_ar or "كود لوكود" in csv_text_ar

    r_csv_en = client.get("/api/v1/transport-locations/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    assert "Location Name" in r_csv_en.content.decode("utf-8")

    r_xlsx_ar = client.get("/api/v1/transport-locations/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/transport-locations/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_incoterms_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/incoterms/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "شرط الشحن" in csv_text_ar or "Incoterm" in csv_text_ar

    r_csv_en = client.get("/api/v1/incoterms/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    assert "Incoterm Code" in r_csv_en.content.decode("utf-8")

    r_xlsx_ar = client.get("/api/v1/incoterms/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/incoterms/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_currencies_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/currencies/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود العملة" in csv_text_ar

    r_csv_en = client.get("/api/v1/currencies/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    assert "Currency Code" in r_csv_en.content.decode("utf-8")

    r_xlsx_ar = client.get("/api/v1/currencies/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/currencies/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200


def test_import_files_exports_csv_excel_pdf(auth_headers):
    r_csv_ar = client.get("/api/v1/import-files/export-csv?lang=ar", headers=auth_headers)
    assert r_csv_ar.status_code == 200
    csv_text_ar = r_csv_ar.content.decode("utf-8")
    assert "كود الملف" in csv_text_ar

    r_csv_en = client.get("/api/v1/import-files/export-csv?lang=en", headers=auth_headers)
    assert r_csv_en.status_code == 200
    assert "File Code" in r_csv_en.content.decode("utf-8")

    r_xlsx_ar = client.get("/api/v1/import-files/export-excel?lang=ar", headers=auth_headers)
    assert r_xlsx_ar.status_code == 200

    r_pdf_ar = client.get("/api/v1/import-files/export-pdf?lang=ar", headers=auth_headers)
    assert r_pdf_ar.status_code == 200

