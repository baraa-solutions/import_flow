import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession
from modules.original_documents_collection.service import OriginalDocumentsCollectionService
from modules.original_documents_collection.schemas import (
    OriginalDocumentsCollectionCreate,
    CourierEntry,
    OriginalDocumentItem,
)

# Test in-memory DB
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

    # Seed test company
    company = ImportCompany(
        company_id=1,
        importer_name="Al-Sorour Logistics",
        address="Cairo, Egypt",
        country="Egypt",
        importer_id="100294812",
        importer_id_expiry=datetime(2028, 1, 1),
        vat_id="100294812",
        vat_id_expiry=datetime(2028, 1, 1),
        registration_number="REG-99120",
        registration_expiry=datetime(2028, 1, 1),
    )
    db.add(company)

    # Seed test supplier
    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-001",
        company_name="Narbutas International UAB",
        foreign_exporter_id="LT300591314",
        foreign_exporter_country="Lithuania",
        foreign_exporter_country_code="LT",
        address="Vilnius, Lithuania",
        supplier_type="Manufacturer",
        registration_type="Standard",
    )
    db.add(supplier)

    # Seed test import file
    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_id=1,
        company_name="Al-Sorour Logistics",
        supplier_id=1,
        supplier_name="Narbutas International UAB",
        acid_number="7595528271020210010",
        custom_file_number="44901",
        status="Under Review",
        incoterm_code="EXW",
        port_of_loading="Vilnius Port",
        port_of_discharge="Alexandria Port",
    )
    db.add(import_file)
    db.commit()

    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_auto_populate_from_central_archive(db_session):
    res = OriginalDocumentsCollectionService.auto_populate_from_central_archive(db_session, 1)
    assert res.import_file_id == 1
    assert res.import_file_code == "IMP-2026-0001"
    assert res.acid_number == "7595528271020210010"
    assert len(res.required_documents) >= 8

    doc_names = [d.document_name for d in res.required_documents]
    assert "Commercial Invoice" in doc_names
    assert "Packing List" in doc_names
    assert "Certificate of Origin (COO)" in doc_names
    assert "Final House Bill of Lading" in doc_names
    assert "Final Master Bill of Lading" in doc_names
    assert "E.Invoice" in doc_names
    assert len(res.default_couriers) == 2
    assert all(c.courier_company is None for c in res.default_couriers)


def test_courier_no_dhl_defaults(db_session):
    # Verify build_carrier_tracking_url returns None when company or awb is missing
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url(None, "12345") is None
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url("", "12345") is None
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url("DHL", None) is None
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url("DHL", "  ") is None

    # Verify courier with courier_company=None generates no DHL fallback in flat list or alerts
    file = ImportFile(
        import_file_code="IMP-2026-NO-COMP",
        company_name="No DHL Importer",
        supplier_name="No DHL Supplier",
    )
    db_session.add(file)
    db_session.commit()

    payload = OriginalDocumentsCollectionCreate(
        import_file_id=file.import_file_id,
        import_file_code=file.import_file_code,
        couriers_list=[
            CourierEntry(
                courier_no="AWB-NO-COMP",
                courier_company=None,
                dispatch_date="2026-09-01",
                is_received=False,
            ),
        ],
        documents_list=[],
    )
    OriginalDocumentsCollectionService.save_or_upsert_collection_session(db_session, payload)

    flat = OriginalDocumentsCollectionService.get_all_couriers_flat(db_session)
    no_comp_item = next(x for x in flat if x.courier_no == "AWB-NO-COMP")
    assert no_comp_item.courier_company == ""
    assert no_comp_item.tracking_url is None

    alerts = OriginalDocumentsCollectionService.get_courier_alerts(db_session)
    alert = next(x for x in alerts.alerts if x.courier_no == "AWB-NO-COMP")
    assert alert.courier_company == ""
    assert "DHL" not in alert.alert_message_ar
    assert "DHL" not in alert.alert_message_en
    payload = OriginalDocumentsCollectionCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        acid_number="7595528271020210010",
        importer_name="Al-Sorour Logistics",
        supplier_name="Narbutas International UAB",
        status="DRAFT",
        couriers_list=[
            CourierEntry(
                courier_no="DHL-99881122",
                courier_company="DHL",
                dispatch_date="2026-08-20",
                is_received=True,
                received_date="2026-08-21",
                received_by="Ahmed Salah",
                notes="Original Supplier Invoices Package",
            )
        ],
        documents_list=[
            OriginalDocumentItem(
                category="Commercial",
                document_name="Commercial Invoice",
                is_required="Yes",
                responsible_party="Supplier",
                courier_no="DHL-99881122",
                is_received=True,
                received_date="2026-08-21",
                is_verified=True,
                verified_by="Kamal",
                verification_date="2026-08-21",
                status="Verified",
                remarks="Matching stamp and signatures",
            ),
            OriginalDocumentItem(
                category="Commercial",
                document_name="Packing List",
                is_required="Yes",
                responsible_party="Supplier",
                courier_no="DHL-99881122",
                is_received=True,
                received_date="2026-08-21",
                is_verified=False,
                status="Received",
            ),
            OriginalDocumentItem(
                category="Shipping",
                document_name="Final House Bill of Lading",
                is_required="Yes",
                responsible_party="Freight Forwarder",
                is_received=False,
                status="Pending",
            ),
        ],
        notes="First batch received via DHL",
    )

    session_res = OriginalDocumentsCollectionService.save_or_upsert_collection_session(
        db_session, payload, username="TEST_USER"
    )

    assert session_res.collection_id is not None
    assert session_res.collection_code.startswith("DOC-COL-")
    assert session_res.total_documents_count == 3
    assert session_res.received_documents_count == 2
    assert session_res.verified_documents_count == 1
    assert session_res.pending_documents_count == 1
    assert session_res.completion_percentage == 33.3
    assert session_res.status == "PARTIALLY_RECEIVED"

    # Test Upsert: update to 100% verified
    payload.documents_list[1].is_verified = True
    payload.documents_list[2].is_received = True
    payload.documents_list[2].is_verified = True

    updated_res = OriginalDocumentsCollectionService.save_or_upsert_collection_session(
        db_session, payload, username="TEST_USER"
    )

    assert updated_res.collection_id == session_res.collection_id
    assert updated_res.collection_code == session_res.collection_code
    assert updated_res.verified_documents_count == 3
    assert updated_res.completion_percentage == 100.0
    assert updated_res.status == "FULLY_VERIFIED"


def test_export_collection_to_excel(db_session):
    excel_bytes = OriginalDocumentsCollectionService.export_collection_to_excel_bytes(
        db_session, 1
    )
    assert excel_bytes is not None
    assert len(excel_bytes) > 2000
    assert excel_bytes.startswith(b"PK")  # ZIP / xlsx signature


def test_api_endpoints(client, db_session):
    # 1. Auto populate
    resp = client.get("/api/v1/original-documents-collection/auto-populate/1")
    assert resp.status_code == 200
    data = resp.json()
    assert data["import_file_code"] == "IMP-2026-0001"
    assert len(data["required_documents"]) >= 8

    # 2. Save Session
    post_payload = {
        "import_file_id": 1,
        "import_file_code": "IMP-2026-0001",
        "acid_number": "7595528271020210010",
        "importer_name": "Al-Sorour Logistics",
        "supplier_name": "Narbutas International UAB",
        "status": "DRAFT",
        "couriers_list": [
            {
                "courier_no": "DHL-991200",
                "courier_company": "DHL",
                "dispatch_date": "2026-08-20",
                "is_received": True,
                "received_date": "2026-08-21",
                "received_by": "Ahmed",
                "notes": "Fast track",
            }
        ],
        "documents_list": [
            {
                "category": "Commercial",
                "document_name": "Commercial Invoice",
                "is_required": "Yes",
                "responsible_party": "Supplier",
                "courier_no": "DHL-991200",
                "is_received": True,
                "received_date": "2026-08-21",
                "is_verified": True,
                "verified_by": "Kamal",
                "verification_date": "2026-08-21",
                "status": "Verified",
                "remarks": "OK",
            }
        ],
    }

    create_resp = client.post("/api/v1/original-documents-collection/sessions", json=post_payload)
    assert create_resp.status_code == 200
    created_data = create_resp.json()
    assert created_data["collection_id"] is not None
    session_id = created_data["collection_id"]

    # 3. Get by File
    file_resp = client.get("/api/v1/original-documents-collection/sessions/by-file/1")
    assert file_resp.status_code == 200
    assert file_resp.json()["collection_code"] == created_data["collection_code"]

    # 4. Get by ID
    id_resp = client.get(f"/api/v1/original-documents-collection/sessions/{session_id}")
    assert id_resp.status_code == 200
    assert id_resp.json()["import_file_id"] == 1

    # 5. List Sessions
    list_resp = client.get("/api/v1/original-documents-collection/sessions")
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1

    # 6. Export Excel
    excel_resp = client.get("/api/v1/original-documents-collection/export/excel/1")
    assert excel_resp.status_code == 200
    assert len(excel_resp.content) > 1000
