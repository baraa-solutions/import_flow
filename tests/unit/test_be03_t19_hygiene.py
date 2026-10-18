import pytest
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.import_files.model import ImportFile
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession
from modules.import_documentation.service import get_central_archive_service
from modules.original_documents_collection.service import OriginalDocumentsCollectionService
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession


@pytest.fixture
def db_session():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()

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

    supplier = Supplier(
        supplier_id=1,
        supplier_code="SUP-001",
        company_name="Test Supplier Ltd",
        foreign_exporter_id="EXP-12345",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin, Germany",
        supplier_type="Manufacturer",
        registration_type="Standard",
    )
    db.add(supplier)

    import_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_id=1,
        company_name="Al-Sorour Logistics",
        supplier_id=1,
        supplier_name="Test Supplier Ltd",
        acid_number="7595528271020210010",
        custom_file_number="44901",
        status="Under Review",
        incoterm_code="FOB",
        estimated_cost_currency="",
        estimated_cost=10000.0,
    )
    db.add(import_file)
    db.commit()

    try:
        yield db
    finally:
        db.close()


def test_po_reconciliation_model_currency_default():
    """BE03-F25: POPackingReconciliationSession currency should not default to 'EUR'."""
    session = POPackingReconciliationSession(
        session_code="PO-REC-TEST",
        import_file_id=1,
    )
    assert session.currency is None


def test_central_archive_currency_none_when_no_recon_and_no_file_currency(db_session):
    """BE03-F25: Central archive returns currency=None when neither recon nor file has currency."""
    res = get_central_archive_service(db_session, import_file_id=1)
    assert res.currency is None
    assert res.final_invoice.details.get("currency") is None


def test_central_archive_currency_with_empty_string_file_currency(db_session):
    """BE03-F25: Central archive returns currency=None even if file currency is empty string."""
    imp_file = db_session.query(ImportFile).filter_by(import_file_id=1).first()
    imp_file.estimated_cost_currency = ""
    db_session.commit()

    res = get_central_archive_service(db_session, import_file_id=1)
    assert res.currency is None
    assert res.final_invoice.details.get("currency") is None


def test_odc_auto_populate_default_couriers_company_is_none(db_session):
    """BE03-F27: Auto-populate default couriers have courier_company=None."""
    res = OriginalDocumentsCollectionService.auto_populate_from_central_archive(db_session, import_file_id=1)
    assert len(res.default_couriers) >= 2
    for courier in res.default_couriers:
        assert courier.courier_company is None


def test_odc_tracking_url_empty_when_carrier_empty():
    """BE03-F27: Empty carrier should result in tracking_url=None, not DHL."""
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url(None, "123456") is None
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url("", "123456") is None
    assert OriginalDocumentsCollectionService.build_carrier_tracking_url("   ", "123456") is None


def test_odc_alerts_and_flat_items_with_empty_carrier(db_session):
    """BE03-F27: Couriers without carrier do not display DHL in alerts or flat list."""
    session = OriginalDocumentsCollectionSession(
        collection_code="ODC-2026-0001",
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        acid_number="7595528271020210010",
        importer_name="Al-Sorour Logistics",
        supplier_name="Test Supplier Ltd",
        status="DRAFT",
        is_active=True,
        couriers_list=[
            {
                "courier_no": "AWB-998877",
                "courier_company": None,
                "dispatch_date": "2026-10-01",
                "is_received": False,
                "notes": "Testing empty carrier",
            }
        ],
        documents_list=[],
    )
    db_session.add(session)
    db_session.commit()

    # Alerts check
    alerts_resp = OriginalDocumentsCollectionService.get_courier_alerts(db_session)
    assert len(alerts_resp.alerts) == 1
    alert = alerts_resp.alerts[0]
    assert alert.courier_company == ""
    assert "DHL" not in alert.alert_message_ar
    assert "DHL" not in alert.alert_message_en
    assert alert.alert_message_ar.startswith("طرد رقم (AWB-998877)")

    # Flat items check
    flat_items = OriginalDocumentsCollectionService.get_all_couriers_flat(db_session)
    assert len(flat_items) == 1
    item = flat_items[0]
    assert item.courier_company == ""
    assert item.tracking_url is None
