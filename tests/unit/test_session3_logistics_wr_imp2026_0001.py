"""
Unit test asserting full lifecycle of Inland Transport and Warehouse Receiving GRN
for Shipment IMP-2026-0001 (Air Cooled Water Chillers).
"""

from datetime import datetime, timedelta, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.inland_transport.model import InlandTransportBooking
from modules.inland_transport.schemas import (
    InlandTransportBookingCreate,
    InlandTransportGateOutSubmit,
    InlandTransportArrivalSubmit,
)
from modules.inland_transport.service import (
    create_transport_booking_service,
    record_port_gate_out_service,
    record_warehouse_arrival_service,
)
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import WarehouseReceivingCreate, GrnItemSchema
from modules.warehouse_receiving.service import create_warehouse_receiving_service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_shipment_1_inland_transport_and_grn_lifecycle(db_session):
    now = datetime.now(timezone.utc)

    # 1. Setup released ImportFile at 95.0%
    imp_file = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="ECO ASSOCIATES",
        supplier_name="Global Chillers Ltd",
        current_step_code="STEP_18",
        current_module="STEP_18 Demurrage & Detention",
        current_stage_code="CUSTOMS_RELEASED",
        progress_percent=95.0,
        is_customs_released=True,
        customs_release_permit_no="REL-ALX-2026-0091",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Book Inland Transport (TR-01)
    booking_payload = InlandTransportBookingCreate(
        import_file_id=imp_file.import_file_id,
        waybill_number="WB-ALX-2026-001",
        booking_date=now - timedelta(hours=6),
        carrier_name="Al-Buraq Heavy Transport & Logistics",
        truck_plate_number="أ ل ج 9812",
        truck_type="CONTAINER_CHASSIS",
        driver_name="Ahmed Kamal Abdel-Rahman",
        driver_phone="01001234567",
        pickup_port_location="Alexandria Port Berth 42",
        destination_warehouse="Tenth of Ramadan Factory Warehouse",
        planned_departure_at=now - timedelta(hours=4),
        expected_arrival_at=now,
        transport_fare_egp=12000.0,
    )
    transport = create_transport_booking_service(db_session, booking_payload, user="Logistics Officer")
    assert transport.transport_id is not None

    # 3. Port Gate-Out (TR-03)
    gate_out_payload = InlandTransportGateOutSubmit(
        actual_departure_at=now - timedelta(hours=3),
        gate_pass_no="GP-ALX-2026-1102",
    )
    transport = record_port_gate_out_service(db_session, transport.transport_id, gate_out_payload, user="Customs Broker")
    assert transport.status == "In Transit"

    # 4. Warehouse Arrival (TR-04)
    arrival_payload = InlandTransportArrivalSubmit(
        actual_arrival_at=now,
        seal_intact=True,
        seal_number="ML-EG-99881",
    )
    transport = record_warehouse_arrival_service(db_session, transport.transport_id, arrival_payload, user="Warehouse Manager")
    assert transport.status == "Arrived at Warehouse"

    # 5. Create Warehouse GRN (WR-01)
    grn_payload = WarehouseReceivingCreate(
        import_file_id=imp_file.import_file_id,
        warehouse_name="Tenth of Ramadan Factory Warehouse",
        arrival_datetime=now,
        truck_plate_number="أ ل ج 9812",
        driver_name="Ahmed Kamal Abdel-Rahman",
        seal_number="ML-EG-99881",
        seal_intact=True,
        grn_items=[
            GrnItemSchema(
                item_code="CHL-AC-500TR",
                item_name="Air Cooled Water Chillers 500TR",
                invoiced_qty=2,
                accepted_qty=2,
                shortage_qty=0,
                damaged_qty=0,
                quarantine_flag=False,
            )
        ],
    )
    grn = create_warehouse_receiving_service(db_session, grn_payload, user="Warehouse Manager")
    db_session.refresh(imp_file)

    assert grn.grn_code.startswith("GRN-")
    assert imp_file.progress_percent >= 98.0
    assert grn.total_accepted_qty == 2
