from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.common.validators import not_null_columns
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import ShipmentBookingCreate, ShipmentBookingUpdate


def generate_booking_code(db: Session) -> str:
    """Next ``BKG-YYYY-NNNN`` (highest suffix of the year + 1; the unique constraint stays the final guard)."""
    return next_yearly_code(db, ShipmentBooking.booking_code, "BKG", pad=4)


def create_booking(db: Session, payload: ShipmentBookingCreate, owner: str) -> ShipmentBooking:
    """Adds and flushes the booking (the service commits)."""
    code = generate_booking_code(db)
    containers_json = [c.model_dump() for c in payload.containers_data]
    costs_json = [c.model_dump() for c in payload.cost_charges_data]

    booking = ShipmentBooking(
        booking_code=code,
        booking_confirmation_no=payload.booking_confirmation_no,
        bill_of_lading_no=payload.bill_of_lading_no,
        import_file_id=payload.import_file_id,
        rfq_request_id=payload.rfq_request_id,
        scenario_session_id=payload.scenario_session_id,
        scenario_item_id=payload.scenario_item_id,
        scenario_provider_name=payload.scenario_provider_name,
        freight_forwarder_id=payload.freight_forwarder_id,
        freight_forwarder_name=payload.freight_forwarder_name,
        shipping_line_id=payload.shipping_line_id,
        shipping_line_name=payload.shipping_line_name,
        shipment_type=payload.shipment_type,
        pol_location_id=payload.pol_location_id,
        pol_name=payload.pol_name,
        pod_location_id=payload.pod_location_id,
        pod_name=payload.pod_name,
        etd=payload.etd,
        eta=payload.eta,
        atd=payload.atd,
        departure_delay_days=payload.departure_delay_days or 0,
        expected_warehouse_days=payload.expected_warehouse_days or 7,
        expected_warehouse_arrival_date=payload.expected_warehouse_arrival_date,
        free_demurrage_days=payload.free_demurrage_days,
        cargo_cutoff_date=payload.cargo_cutoff_date,
        si_cutoff_date=payload.si_cutoff_date,
        vessel_name=payload.vessel_name,
        voyage_number=payload.voyage_number,
        container_release_order_no=payload.container_release_order_no,
        freight_terms=payload.freight_terms,
        container_mismatch_reason=payload.container_mismatch_reason,
        containers_data=containers_json,
        cost_charges_data=costs_json,
        quotation_details_data=payload.quotation_details_data or {},
        original_freight_cost_usd=payload.original_freight_cost_usd or 0.0,
        cost_savings_usd=payload.cost_savings_usd or 0.0,
        cost_variance_usd=payload.cost_variance_usd or 0.0,
        savings_notes=payload.savings_notes,
        status=payload.status,
        owner=owner,
        notes=payload.notes,
    )

    db.add(booking)
    db.flush()
    return booking


def get_booking_by_id(db: Session, booking_id: int, include_inactive: bool = False) -> Optional[ShipmentBooking]:
    query = db.query(ShipmentBooking).filter(ShipmentBooking.booking_id == booking_id)
    if not include_inactive:
        query = query.filter(ShipmentBooking.is_active == True)
    return query.first()


def list_bookings(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None
) -> List[ShipmentBooking]:
    query = db.query(ShipmentBooking)
    if not include_inactive:
        query = query.filter(ShipmentBooking.is_active == True)
    if import_file_id is not None:
        query = query.filter(ShipmentBooking.import_file_id == import_file_id)
    if status is not None and status != "All":
        query = query.filter(ShipmentBooking.status == status)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (ShipmentBooking.booking_code.like(pattern)) |
            (ShipmentBooking.booking_confirmation_no.like(pattern)) |
            (ShipmentBooking.bill_of_lading_no.like(pattern)) |
            (ShipmentBooking.vessel_name.like(pattern)) |
            (ShipmentBooking.freight_forwarder_name.like(pattern))
        )
    return query.order_by(ShipmentBooking.created_at.desc()).all()


def apply_booking_update(booking: ShipmentBooking, payload: ShipmentBookingUpdate) -> None:
    """Copies the sent fields onto the booking (no commit). An explicit null on a NOT NULL column is skipped."""
    required = not_null_columns(ShipmentBooking)
    data = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if not (v is None and k in required)}
    if "containers_data" in data and data["containers_data"] is not None:
        data["containers_data"] = [c.model_dump() if hasattr(c, "model_dump") else c for c in data["containers_data"]]
    if "cost_charges_data" in data and data["cost_charges_data"] is not None:
        data["cost_charges_data"] = [c.model_dump() if hasattr(c, "model_dump") else c for c in data["cost_charges_data"]]

    for key, val in data.items():
        setattr(booking, key, val)

    booking.updated_at = datetime.now(timezone.utc)


def set_booking_active(booking: ShipmentBooking, is_active: bool) -> None:
    booking.is_active = is_active
    booking.updated_at = datetime.now(timezone.utc)
