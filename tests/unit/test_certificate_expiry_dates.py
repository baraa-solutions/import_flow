"""
Certificate & Nafeza token expiry dates on import companies and suppliers (Trello TJ6Guorp).
"""
from datetime import date

import pytest

from modules.import_companies.schemas import ImportCompanyCreate, ImportCompanyResponse, ImportCompanyUpdate
from modules.import_companies.service import create_import_company, update_import_company
from modules.suppliers.model import Supplier
from modules.suppliers.schemas import SupplierResponse

from test_phase02_support import make_session


@pytest.fixture
def db():
    session = make_session()
    yield session
    session.close()


def test_company_expiries_are_saved_returned_and_updated(db):
    company = create_import_company(db, ImportCompanyCreate(
        importer_name="Archi Brands", importer_id="IMP-EXP-1", vat_id="V-EXP-1", registration_number="R-EXP-1",
        has_wipo=True, wipo_number="1234567", wipo_expiry=date(2026, 12, 1),
        nafeza_token_expiry=date(2026, 10, 1),
    ))
    assert company.wipo_expiry == date(2026, 12, 1)
    assert company.nafeza_token_expiry == date(2026, 10, 1)
    assert company.iso_9001_expiry is None

    response = ImportCompanyResponse.model_validate(company, from_attributes=True)
    assert response.wipo_expiry == date(2026, 12, 1)

    updated = update_import_company(db, company.company_id, ImportCompanyUpdate(iso_9001_expiry=date(2027, 3, 1)))
    assert updated.iso_9001_expiry == date(2027, 3, 1)
    assert updated.wipo_expiry == date(2026, 12, 1)


def test_supplier_expiries_round_trip(db):
    supplier = Supplier(supplier_code="SUP-EXP-1", company_name="Exporter Co", supplier_type="Manufacturer",
                        registration_type="Factory", foreign_exporter_id="EXP-1", foreign_exporter_country="Italy",
                        foreign_exporter_country_code="IT", address="Milan", has_euipo=True,
                        euipo_number="018345678", euipo_expiry=date(2026, 8, 1))
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    assert supplier.euipo_expiry == date(2026, 8, 1)
    assert "euipo_expiry" in SupplierResponse.model_fields


def test_existing_rows_without_expiries_stay_valid():
    payload = ImportCompanyCreate(importer_name="Legacy Co")
    assert payload.wipo_expiry is None and payload.nafeza_token_expiry is None
