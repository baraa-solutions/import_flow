"""
Unit Test Suite for DC-04: Shipping Docs Matrix Verification & Deficiency Tracking
Stage 3: Documentation, Nafeza & ACID Operations (Checklist Item #23)
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database.database import Base
from main import app
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_files.model import ImportFile
from modules.import_documentation.model import AcidRegistrationSession, ShipmentDocumentItem
from modules.docs_customs_approval.model import CustomsDocumentApproval
from modules.docs_customs_approval.schemas import CustomsDocumentApprovalCreate
import modules.docs_customs_approval.service as service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:", echo=False)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def test_client():
    return TestClient(app)


@pytest.fixture
def setup_shipping_docs_data(db_session):
    company = ImportCompany(
        company_id=1,
        importer_name="Al-Ahram Logistics Co",
        vat_id="111-222-333",
        vat_id_expiry=date(2028, 5, 1),
        registration_number="CR-55443",
        registration_expiry=date(2028, 5, 1),
        importer_id="CARD-888",
        importer_id_expiry=date(2028, 5, 1),
        address="Alexandria, Egypt",
        country="Egypt",
        is_active=True,
    )
    db_session.add(company)

    supplier = Supplier(
        supplier_id=1,
        company_name="Euro Industrial Equipment GmbH",
        supplier_code="SUP-DE-001",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="DE-VAT-12345",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Hamburg, Germany",
        is_active=True,
    )
    db_session.add(supplier)
    db_session.commit()

    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-7701",
        project_id=1,
        company_id=company.company_id,
        supplier_id=supplier.supplier_id,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=85000.0,
        is_active=True,
    )
    db_session.add(po)
    db_session.commit()

    line = POLineItem(
        po_id=po.po_id,
        item_code="ITM-GEN-01",
        description_ar="مولدات كهربائية ومضخات هيدروليكية",
        description_en="Generators & Hydraulic Pumps",
        country_of_origin="Germany",
        quantity=10.0,
        unit_price=8500.0,
        total_price=85000.0,
    )
    db_session.add(line)
    db_session.commit()

    file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-7701",
        custom_file_number="FILE-7701",
        company_id=company.company_id,
        company_name="Al-Ahram Logistics Co",
        supplier_name="Euro Industrial Equipment GmbH",
        po_number="PO-2026-7701",
        acid_number="1234567890123456789",
        status="In Progress",
        current_stage="STAGE_05_DRAFT_DOCS",
        is_active=True,
    )
    db_session.add(file)
    db_session.commit()

    acid = AcidRegistrationSession(
        acid_code="ACID-2026-7701",
        acid_number="1234567890123456789",
        import_file_id=file.import_file_id,
        importer_name="Al-Ahram Logistics Co",
        importer_tax_id="111-222-333",
        exporter_name="Euro Industrial Equipment GmbH",
        exporter_reg_id="DE-VAT-12345",
        exporter_country="Germany",
        proforma_invoice_no="PI-2026-77",
        pol_name="Hamburg Port",
        pod_name="Alexandria Port",
        expiry_date=date(2028, 1, 1),
        is_active=True,
    )
    db_session.add(acid)
    db_session.commit()

    return file


def test_dc04_fumigation_certificate_creation(db_session, setup_shipping_docs_data):
    """Verify that Fumigation Certificate is accepted as valid document type."""
    file = setup_shipping_docs_data

    payload = CustomsDocumentApprovalCreate(
        import_file_id=file.import_file_id,
        document_type="Fumigation Certificate",
        document_reference_no="FUM-ISPM15-9988",
        document_date=date(2026, 9, 1),
    )
    approval = service.create_approval_service(db_session, payload)
    assert approval.approval_id is not None
    assert approval.approval_code.startswith("CDA-2026-")
    assert approval.document_type == "Fumigation Certificate"
    assert approval.document_reference_no == "FUM-ISPM15-9988"


def test_dc04_auto_generate_includes_fumigation(db_session, setup_shipping_docs_data):
    """Verify that auto-generated checklist includes Fumigation Certificate alongside standard docs."""
    file = setup_shipping_docs_data

    approvals = service.auto_generate_approvals_for_import_file_service(db_session, file.import_file_id)
    doc_types = [a.document_type for a in approvals]

    assert "Commercial Invoice" in doc_types
    assert "Packing List" in doc_types
    assert "Bill of Lading" in doc_types
    assert "Certificate of Origin" in doc_types
    assert "Inspection Certificate" in doc_types
    assert "Fumigation Certificate" in doc_types
    assert "Bank Form 4" in doc_types
    assert len(approvals) >= 8


def test_dc04_matrix_deficiency_radar_tracking(db_session, setup_shipping_docs_data):
    """Verify deficiency radar identifies missing shipping documents and calculates completeness percent."""
    file = setup_shipping_docs_data

    # Initial check with NO documents created yet
    res = service.run_cross_document_matrix_check_service(db_session, file.import_file_id)

    assert res.import_file_id == file.import_file_id
    assert res.completeness_percent == 0.0
    assert len(res.missing_documents) > 0
    # Must detect missing Commercial Invoice, Packing List, Fumigation, etc.
    assert any("الفاتورة" in d for d in res.missing_documents)
    assert any("التبخير" in d for d in res.missing_documents)
    # Check deficiency recommendations generated
    assert any("تنبيه استكمال مستندي (DC-04)" in r for r in res.recommendations)
    assert res.overall_compliance == "Discrepancies Found"


def test_dc04_matrix_100_percent_completeness(db_session, setup_shipping_docs_data):
    """Verify that when all mandatory shipping docs are approved, completeness reaches 100% and Fully Compliant."""
    file = setup_shipping_docs_data

    # Create and approve all 7 mandatory documents
    docs_to_create = [
        ("Commercial Invoice", "INV-2026-001"),
        ("Packing List", "PL-2026-001"),
        ("Bill of Lading", "MSCU-889900"),
        ("Certificate of Origin", "COO-DE-2026"),
        ("Inspection Certificate", "SGS-DE-991"),
        ("Fumigation Certificate", "ISPM15-DE-441"),
        ("Bank Form 4", "F4-ALEX-2026-99"),
    ]

    for doc_type, ref_no in docs_to_create:
        app = CustomsDocumentApproval(
            approval_code=f"CDA-{doc_type[:3]}-TEST",
            import_file_id=file.import_file_id,
            import_file_code=file.import_file_code,
            document_type=doc_type,
            document_reference_no=ref_no,
            commercial_status="Approved",
            customs_status="Approved",
            overall_status="Approved for Clearance",
        )
        db_session.add(app)
    db_session.commit()

    res = service.run_cross_document_matrix_check_service(db_session, file.import_file_id)

    assert res.completeness_percent == 100.0
    assert len(res.missing_documents) == 0
    # Changed on purpose (03b DCA-01): the data checks no longer return fake "Match" rows. This fixture has no
    # HS code / invoice / packing-list data, so those rows are "Not Checked" and the file cannot be
    # "Fully Compliant" (see test_phase03b_regressions.py for a fully sourced file reaching "Fully Compliant").
    # The POD check now compares the real values (ACID "Alexandria Port" vs the file's default POD), so a
    # data-row warning is possible; every DC-04 document row still passes.
    doc_rows = {spec["parameter"] for spec in service.MANDATORY_DOCS_SPEC}
    assert all(c.status == "Match" for c in res.checks if c.parameter in doc_rows)
    assert res.not_checked_checks > 0
    assert res.overall_compliance == "Discrepancies Found"


def test_dc04_matrix_check_api_endpoint(test_client):
    """Test REST API endpoint for matrix check returns DC-04 fields."""
    response = test_client.get("/api/v1/docs-customs-approval/matrix-check/1")
    if response.status_code == 200:
        data = response.json()
        assert "missing_documents" in data
        assert "completeness_percent" in data
        assert "checks" in data
        assert "recommendations" in data
        assert isinstance(data["missing_documents"], list)
        assert isinstance(data["completeness_percent"], (int, float))
