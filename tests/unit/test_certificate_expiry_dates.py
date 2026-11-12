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


def test_supplier_update_clears_expiry_on_explicit_null_but_keeps_other_fields(db):
    from modules.suppliers.schemas import SupplierUpdate
    from modules.suppliers.service import update_supplier_service

    supplier = Supplier(supplier_code="SUP-EXP-2", company_name="Clearable Co", supplier_type="Manufacturer",
                        registration_type="Factory", foreign_exporter_id="EXP-2", foreign_exporter_country="Italy",
                        foreign_exporter_country_code="IT", address="Rome", notes="keep me",
                        has_wipo=True, wipo_expiry=date(2027, 1, 1), euipo_expiry=date(2027, 2, 1))
    db.add(supplier)
    db.commit()
    db.refresh(supplier)

    # Explicit null on an expiry clears it; null on a regular field (notes) is still ignored;
    # unset fields (euipo_expiry) are untouched.
    updated = update_supplier_service(db, supplier.supplier_id, SupplierUpdate(wipo_expiry=None, notes=None))
    assert updated.wipo_expiry is None
    assert updated.euipo_expiry == date(2027, 2, 1)
    assert updated.notes == "keep me"
    assert updated.company_name == "Clearable Co"


def test_supplier_update_dict_drops_null_on_non_clearable_fields():
    from modules.suppliers.schemas import SupplierUpdate

    payload = SupplierUpdate.model_validate({"company_name": None, "iso_9001_expiry": None, "city": "Milan"})
    assert payload.to_update_dict() == {"iso_9001_expiry": None, "city": "Milan"}
