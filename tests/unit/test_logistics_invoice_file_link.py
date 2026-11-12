"""
Logistics invoices are bound to an active import file and expose its code and project (Trello XpHTWi9u).
"""
import pytest
from fastapi import HTTPException

from modules.import_files.model import ImportFile
from modules.logistics_invoices.model import LogisticsServiceInvoice
from modules.logistics_invoices.schemas import LogisticsInvoiceResponse
from modules.logistics_invoices.validators import LogisticsInvoicesValidator

from test_phase02_support import make_session


@pytest.fixture
def db():
    session = make_session()
    yield session
    session.close()


def _file(db, code, active=True, projects=None) -> ImportFile:
    imp = ImportFile(import_file_code=code, company_name="Co", supplier_name="Sup",
                     project_names=projects, is_active=active)
    db.add(imp)
    db.commit()
    return imp


def test_new_documents_require_an_active_import_file(db):
    validator = LogisticsInvoicesValidator(db)
    active = _file(db, "IMP-LI-1")
    archived = _file(db, "IMP-LI-2", active=False)

    assert validator.validate_shipment(active.import_file_id, require_active=True) is active
    with pytest.raises(HTTPException) as exc:
        validator.validate_shipment(archived.import_file_id, require_active=True)
    assert exc.value.status_code == 400
    # Reading documents of an archived file still works.
    assert validator.validate_shipment(archived.import_file_id) is archived
    with pytest.raises(HTTPException) as exc:
        validator.validate_shipment(999)
    assert exc.value.status_code == 404


def test_invoice_exposes_import_file_code_and_project(db):
    imp = _file(db, "IMP-LI-3", projects="Sokhna Solar Plant")
    invoice = LogisticsServiceInvoice(shipment_id=imp.import_file_id)
    invoice.shipment = imp
    assert invoice.import_file_code == "IMP-LI-3"
    assert invoice.project_names == "Sokhna Solar Plant"
    assert {"import_file_code", "project_names"} <= set(LogisticsInvoiceResponse.model_fields)

    orphan = LogisticsServiceInvoice(shipment_id=None)
    assert orphan.import_file_code is None and orphan.project_names is None
