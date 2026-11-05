"""
Unit Tests: unallocated PO lines of an import file (Split Shipments screen data source).
The screen used to render a hard-coded PO list; it now reads the file's real PO lines.
"""

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
import database.models  # noqa: F401 - registers all tables in Base.metadata
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PurchaseOrder
from modules.split_shipments.model import SplitShipmentAllocation
from modules.split_shipments.service import SplitShipmentService


engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def _po(po_id, po_number, import_file_id=None, is_active=True):
    return PurchaseOrder(
        po_id=po_id,
        po_number=po_number,
        import_file_id=import_file_id,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        is_active=is_active,
    )


def _line(item_id, po_id, qty, item_code=None, description_ar="بند"):
    return POLineItem(
        item_id=item_id,
        po_id=po_id,
        item_code=item_code,
        description_ar=description_ar,
        quantity=qty,
        unit_of_measure="PCS",
    )


@pytest.fixture
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    db.add_all([
        ImportFile(
            import_file_id=201,
            import_file_code="IMP-SPLIT-201",
            company_id=1,
            company_name="Test Company",
            supplier_name="Test Supplier",
            status="ACTIVE",
            bl_number="MSCU1234567",
            po_ids=[30],
        ),
        ImportFile(
            import_file_id=202,
            import_file_code="IMP-SPLIT-202",
            company_id=1,
            company_name="Test Company",
            supplier_name="Test Supplier",
            status="ACTIVE",
        ),
        # Linked by FK
        _po(10, "PO-REAL-010", import_file_id=201),
        # Linked by PO shipment allocation
        _po(20, "PO-REAL-020"),
        # Linked by the file's po_ids list
        _po(30, "PO-REAL-030"),
        # Belongs to another file
        _po(40, "PO-OTHER-040", import_file_id=202),
        # Linked but deactivated
        _po(50, "PO-INACTIVE-050", import_file_id=201, is_active=False),
        _line(1, 10, 100, item_code="SKU-A"),
        _line(2, 10, 50, item_code="SKU-B"),
        _line(3, 20, 10, item_code=None, description_ar="بند بدون كود"),
        _line(4, 30, 7, item_code="SKU-C"),
        _line(5, 40, 999, item_code="SKU-OTHER"),
        _line(6, 50, 5, item_code="SKU-INACTIVE"),
        POShipmentAllocation(po_id=20, import_file_id=201, allocated_quantity=10),
    ])
    db.commit()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def _allocate(db, po_item_id, qty, total, deleted=False):
    db.add(SplitShipmentAllocation(
        shipment_id=201,
        parent_bl_number="MSCU1234567",
        split_bl_number="MSCU1234567-A",
        po_item_id=po_item_id,
        item_sku="SKU",
        allocated_quantity=qty,
        total_item_quantity=total,
        allocation_ratio=qty / total,
        is_deleted=deleted,
    ))
    db.commit()


def test_lists_only_po_lines_linked_to_the_file(db_session):
    result = SplitShipmentService(db_session).list_unallocated_po_items(201)

    assert result.shipment_id == 201
    assert result.bl_number == "MSCU1234567"
    assert [i.po_item_id for i in result.items] == [1, 2, 3, 4]
    assert {i.po_number for i in result.items} == {"PO-REAL-010", "PO-REAL-020", "PO-REAL-030"}
    assert result.total == 4


def test_remaining_quantity_subtracts_active_split_allocations(db_session):
    _allocate(db_session, po_item_id=1, qty=30, total=100)
    _allocate(db_session, po_item_id=1, qty=20, total=100, deleted=True)
    _allocate(db_session, po_item_id=2, qty=50, total=50)

    items = {i.po_item_id: i for i in SplitShipmentService(db_session).list_unallocated_po_items(201).items}

    assert items[1].total_quantity == 100
    assert items[1].allocated_quantity == 30
    assert items[1].remaining_quantity == 70
    # Fully allocated line is no longer "unallocated"
    assert 2 not in items


def test_line_without_item_code_gets_traceable_sku(db_session):
    items = {i.po_item_id: i for i in SplitShipmentService(db_session).list_unallocated_po_items(201).items}

    assert items[3].item_sku == "PO-LINE-3"
    assert items[3].item_name == "بند بدون كود"


def test_file_without_po_lines_returns_empty_list(db_session):
    result = SplitShipmentService(db_session).list_unallocated_po_items(202)
    assert [i.po_number for i in result.items] == ["PO-OTHER-040"]

    db_session.add(ImportFile(
        import_file_id=203,
        import_file_code="IMP-SPLIT-203",
        company_id=1,
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="ACTIVE",
    ))
    db_session.commit()
    empty = SplitShipmentService(db_session).list_unallocated_po_items(203)
    assert empty.items == []
    assert empty.total == 0
    assert empty.bl_number is None


def test_unknown_file_returns_404(db_session):
    with pytest.raises(HTTPException) as exc:
        SplitShipmentService(db_session).list_unallocated_po_items(9999)
    assert exc.value.status_code == 404


def test_endpoint_returns_unallocated_po_items(db_session):
    def override_get_db():
        yield db_session

    main.app.dependency_overrides[get_db] = override_get_db
    try:
        client = TestClient(main.app)
        response = client.get("/api/v1/split-shipments/shipments/201/unallocated-po-items")
        missing = client.get("/api/v1/split-shipments/shipments/9999/unallocated-po-items")
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["bl_number"] == "MSCU1234567"
    assert body["total"] == 4
    assert body["items"][0]["po_number"] == "PO-REAL-010"
    assert body["items"][0]["remaining_quantity"] == 100
    assert missing.status_code == 404
