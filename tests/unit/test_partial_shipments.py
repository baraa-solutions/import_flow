"""
Unit Tests for Partial Shipments Linkage (DEV-OPS-04)
Tests parent_import_file_id, is_partial_shipment, create_partial_batch_service, and router endpoints.
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.import_files.model import ImportFile
from modules.import_files.schemas import (
    ImportFileCreate,
    CreatePartialBatchRequest,
)
import modules.import_files.service as service
import modules.import_files.repository as repo
from fastapi import HTTPException


@pytest.fixture
def db_session():
    """Creates in-memory SQLite DB fixture."""
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    comp1 = ImportCompany(
        company_id=1,
        importer_name="Egyptian Import Co",
        vat_id="100-200-300",
        registration_number="12345",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date(2028, 1, 1),
        vat_id_expiry=date(2028, 1, 1),
        registration_expiry=date(2028, 1, 1),
    )
    sup1 = Supplier(
        supplier_id=1,
        company_name="ABC China",
        supplier_code="SUP-01",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="CN-99",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="Shanghai",
    )
    inco1 = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        description="Seller delivers goods on board vessel",
    )
    proj1 = Project(
        project_id=1,
        project_code="PRJ-01",
        project_name="Textile Expansion",
        project_owner="Kamal",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        import_type="Direct Commercial",
    )
    db.add_all([comp1, sup1, inco1, proj1])
    db.commit()

    try:
        yield db
    finally:
        db.close()


def test_create_partial_batch_success(db_session):
    # 1. Create a parent file
    parent_payload = ImportFileCreate(
        custom_file_number="PARENT-001",
        company_id=1,
        company_name="Egyptian Import Co",
        supplier_id=1,
        supplier_name="ABC China",
        po_number="PO-7788",
        po_ids=[101],
        project_ids=[1],
        project_names="Textile Expansion",
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        hs_code="8520",
        port_of_loading="Shanghai Port",
        port_of_discharge="El Dekheila Port",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
    )
    parent = service.create_import_file_service(db_session, parent_payload)
    assert parent.import_file_id is not None
    assert parent.is_partial_shipment is False

    # 2. Create first partial batch from parent
    batch1_payload = CreatePartialBatchRequest(
        notes="First batch: 40% cargo shipped by air",
        shipment_mode="Air",
        estimated_cost=20000.0,
        initial_starting_step="STEP_01",
    )
    child1 = service.create_partial_batch_service(db_session, parent.import_file_id, batch1_payload, current_user="Ahmed")

    # Verify child1 attributes
    assert child1.import_file_id is not None
    assert child1.parent_import_file_id == parent.import_file_id
    assert child1.parent_file_code == parent.import_file_code
    assert child1.is_partial_shipment is True
    assert child1.import_file_code == f"{parent.import_file_code}-P1"
    assert child1.shipment_mode == "Air"
    assert child1.estimated_cost == 20000.0
    assert child1.company_id == parent.company_id
    assert child1.supplier_name == parent.supplier_name
    assert child1.po_number == "PO-7788"
    assert child1.po_ids == [101]
    assert child1.status == "Open"

    # Verify parent is now marked as is_partial_shipment = True
    db_session.refresh(parent)
    assert parent.is_partial_shipment is True

    # 3. Create second partial batch from parent with custom code
    batch2_payload = CreatePartialBatchRequest(
        target_import_file_code=f"{parent.import_file_code}-SEA-BATCH2",
        target_custom_file_number="CUSTOM-P2",
        estimated_cost=30000.0,
    )
    child2 = service.create_partial_batch_service(db_session, parent.import_file_id, batch2_payload, current_user="Kamal")

    assert child2.import_file_code == f"{parent.import_file_code}-SEA-BATCH2"
    assert child2.custom_file_number == "CUSTOM-P2"
    assert child2.parent_import_file_id == parent.import_file_id
    assert child2.is_partial_shipment is True
    assert child2.shipment_mode == parent.shipment_mode  # Inherited Sea FCL


def test_get_partial_batches_service(db_session):
    parent_payload = ImportFileCreate(
        custom_file_number="PARENT-MULTI",
        company_id=1,
        company_name="Egyptian Import Co",
        supplier_id=1,
        supplier_name="ABC China",
        po_number="PO-9900",
    )
    parent = service.create_import_file_service(db_session, parent_payload)

    # Spawn 2 batches
    child1 = service.create_partial_batch_service(
        db_session, parent.import_file_id, CreatePartialBatchRequest(notes="Batch 1")
    )
    child2 = service.create_partial_batch_service(
        db_session, parent.import_file_id, CreatePartialBatchRequest(notes="Batch 2")
    )

    # Fetching from parent returns all 3 linked files (parent + children)
    parent_tree = service.get_partial_batches_service(db_session, parent.import_file_id)
    codes_parent_tree = [f.import_file_code for f in parent_tree]
    assert parent.import_file_code in codes_parent_tree
    assert child1.import_file_code in codes_parent_tree
    assert child2.import_file_code in codes_parent_tree

    # Fetching from child also resolves root parent and returns all 3
    child1_tree = service.get_partial_batches_service(db_session, child1.import_file_id)
    codes_child1_tree = [f.import_file_code for f in child1_tree]
    assert parent.import_file_code in codes_child1_tree
    assert child1.import_file_code in codes_child1_tree
    assert child2.import_file_code in codes_child1_tree


def test_create_partial_batch_non_existent_parent(db_session):
    with pytest.raises(HTTPException) as exc_info:
        service.create_partial_batch_service(
            db_session, 99999, CreatePartialBatchRequest(notes="Non existent")
        )
    assert exc_info.value.status_code == 404


def test_create_partial_batch_duplicate_code(db_session):
    parent_payload = ImportFileCreate(
        company_id=1,
        company_name="Egyptian Import Co",
        supplier_id=1,
        supplier_name="ABC China",
    )
    parent = service.create_import_file_service(db_session, parent_payload)

    # First batch with code "DUPLICATE-CODE-TEST"
    service.create_partial_batch_service(
        db_session,
        parent.import_file_id,
        CreatePartialBatchRequest(target_import_file_code="DUPLICATE-CODE-TEST"),
    )

    # Second batch attempting to use same code
    with pytest.raises(HTTPException) as exc_info:
        service.create_partial_batch_service(
            db_session,
            parent.import_file_id,
            CreatePartialBatchRequest(target_import_file_code="DUPLICATE-CODE-TEST"),
        )
    assert exc_info.value.status_code == 409


def test_filter_by_parent_and_partial_flag(db_session):
    parent_payload = ImportFileCreate(
        company_id=1,
        company_name="Egyptian Import Co",
        supplier_id=1,
        supplier_name="ABC China",
    )
    parent = service.create_import_file_service(db_session, parent_payload)

    child = service.create_partial_batch_service(
        db_session, parent.import_file_id, CreatePartialBatchRequest()
    )

    # Filter parent_import_file_id
    children = repo.get_all_import_files(db_session, parent_import_file_id=parent.import_file_id)
    assert len(children) == 1
    assert children[0].import_file_id == child.import_file_id

    # Filter is_partial_shipment = True
    partials = repo.get_all_import_files(db_session, is_partial_shipment=True)
    partial_ids = [p.import_file_id for p in partials]
    assert parent.import_file_id in partial_ids
    assert child.import_file_id in partial_ids
