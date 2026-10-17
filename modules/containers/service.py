from datetime import datetime, timezone, date
from typing import Optional, List, Tuple
from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified

from modules.common.validators import not_found
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.demurrage_detention.model import DemurrageTracking

from .model import ShipmentContainer
from .schemas import (
    ContainerCreate,
    ContainerUpdate,
    ContainerGateOutRequest,
    ContainerEmptyReturnRequest,
)
from .validators import (
    normalize_container_number,
    validate_container_dates,
    validate_unique_container_number,
)
from . import repository


def create_container_service(
    db: Session, req: ContainerCreate, user: str = "System"
) -> ShipmentContainer:
    """Creates a new shipment container entity."""
    clean_number = normalize_container_number(req.container_number)

    import_file = db.query(ImportFile).filter(
        ImportFile.import_file_id == req.import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not import_file:
        raise not_found("الملف الاستيرادي", req.import_file_id)

    validate_unique_container_number(db, req.import_file_id, clean_number)
    validate_container_dates(
        discharge_date=req.discharge_date,
        gate_out_date=req.gate_out_date,
        empty_return_date=req.empty_return_date,
    )

    container = ShipmentContainer(
        container_number=clean_number,
        container_type=req.container_type.strip(),
        seal_number=req.seal_number.strip() if req.seal_number else None,
        import_file_id=req.import_file_id,
        booking_id=req.booking_id,
        shipping_record_id=req.shipping_record_id,
        demurrage_tracking_id=req.demurrage_tracking_id,
        carrier_name=req.carrier_name.strip() if req.carrier_name else None,
        bill_of_lading_no=req.bill_of_lading_no.strip() if req.bill_of_lading_no else None,
        gate_in_date=req.gate_in_date,
        stuffing_date=req.stuffing_date,
        discharge_date=req.discharge_date,
        gate_out_date=req.gate_out_date,
        empty_return_date=req.empty_return_date,
        tare_weight_kg=req.tare_weight_kg,
        net_weight_kg=req.net_weight_kg,
        gross_weight_kg=req.gross_weight_kg,
        vgm_weight_kg=req.vgm_weight_kg,
        vgm_status=req.vgm_status,
        vgm_ref_no=req.vgm_ref_no,
        demurrage_days=req.demurrage_days,
        detention_days=req.detention_days,
        storage_days=req.storage_days,
        demurrage_cost_fx=req.demurrage_cost_fx,
        detention_cost_fx=req.detention_cost_fx,
        storage_cost_egp=req.storage_cost_egp,
        total_cost_egp=req.total_cost_egp,
        currency=req.currency or "USD",
        status=req.status or "Allocated",
        eir_number=req.eir_number,
        depot_name=req.depot_name,
        condition_at_return=req.condition_at_return or "Good",
        notes=req.notes,
        created_by=user,
        updated_by=user,
    )

    created = repository.create_container(db, container)
    db.commit()
    db.refresh(created)
    return created


def get_container_by_id_service(db: Session, container_id: int) -> ShipmentContainer:
    """Retrieves single container by primary key or raises 404."""
    container = repository.get_container_by_id(db, container_id)
    if not container:
        raise not_found("الحاوية", container_id)
    return container


def get_containers_service(
    db: Session,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    container_number: Optional[str] = None,
    carrier_name: Optional[str] = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 100,
) -> Tuple[List[ShipmentContainer], int]:
    """Retrieves paginated and filtered list of containers."""
    return repository.get_containers(
        db,
        import_file_id=import_file_id,
        status=status,
        container_number=container_number,
        carrier_name=carrier_name,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )


def update_container_service(
    db: Session, container_id: int, req: ContainerUpdate, user: str = "System"
) -> ShipmentContainer:
    """Updates an existing container entity."""
    container = get_container_by_id_service(db, container_id)

    if req.container_number is not None:
        clean_num = normalize_container_number(req.container_number)
        if clean_num != container.container_number:
            validate_unique_container_number(
                db, container.import_file_id, clean_num, exclude_container_id=container_id
            )
            container.container_number = clean_num

    update_data = req.model_dump(exclude_unset=True)
    update_data.pop("container_number", None)

    for field, val in update_data.items():
        setattr(container, field, val)

    validate_container_dates(
        discharge_date=container.discharge_date,
        gate_out_date=container.gate_out_date,
        empty_return_date=container.empty_return_date,
    )

    container.updated_by = user
    updated = repository.update_container(db, container)
    db.commit()
    db.refresh(updated)
    return updated


def gate_out_container_service(
    db: Session, container_id: int, req: ContainerGateOutRequest, user: str = "System"
) -> ShipmentContainer:
    """
    Registers container customs gate-out milestone and synchronizes with demurrage tracking session.
    """
    container = get_container_by_id_service(db, container_id)

    validate_container_dates(
        discharge_date=container.discharge_date,
        gate_out_date=req.gate_out_date,
        empty_return_date=container.empty_return_date,
    )

    container.gate_out_date = req.gate_out_date
    container.status = "Gate Out"
    note_add = f"[Gate Out] Date: {req.gate_out_date}"
    if req.truck_plate_number:
        note_add += f" | Truck: {req.truck_plate_number}"
    if req.driver_name:
        note_add += f" | Driver: {req.driver_name}"
    if req.notes:
        note_add += f" | {req.notes}"
    container.notes = f"{container.notes or ''}\n{note_add}".strip()
    container.updated_by = user

    # Bidirectional sync: update matching container in DemurrageTracking session if linked
    if container.demurrage_tracking_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.tracking_id == container.demurrage_tracking_id,
            DemurrageTracking.is_active == True,
        ).first()
        if tracking and isinstance(tracking.containers, list):
            modified = False
            for c in tracking.containers:
                if str(c.get("container_no", "")).strip().upper() == container.container_number:
                    c["gate_out_date"] = req.gate_out_date.isoformat()
                    modified = True
            if modified:
                flag_modified(tracking, "containers")

    updated = repository.update_container(db, container)
    db.commit()
    db.refresh(updated)
    return updated


def empty_return_container_service(
    db: Session, container_id: int, req: ContainerEmptyReturnRequest, user: str = "System"
) -> ShipmentContainer:
    """
    Registers container empty return (EIR) milestone, stops demurrage accrual, and syncs with demurrage session.
    """
    container = get_container_by_id_service(db, container_id)

    validate_container_dates(
        discharge_date=container.discharge_date,
        gate_out_date=container.gate_out_date,
        empty_return_date=req.empty_return_date,
    )

    container.empty_return_date = req.empty_return_date
    container.eir_number = req.eir_number.strip()
    if req.depot_name:
        container.depot_name = req.depot_name.strip()
    if req.condition_at_return:
        container.condition_at_return = req.condition_at_return.strip()
    container.status = "Returned Empty"

    note_add = f"[EIR #{container.eir_number}] Returned on: {req.empty_return_date} at Depot: {container.depot_name or 'N/A'}"
    if req.notes:
        note_add += f" | {req.notes}"
    container.notes = f"{container.notes or ''}\n{note_add}".strip()
    container.updated_by = user

    # Bidirectional sync: update matching container in DemurrageTracking session if linked
    if container.demurrage_tracking_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.tracking_id == container.demurrage_tracking_id,
            DemurrageTracking.is_active == True,
        ).first()
        if tracking and isinstance(tracking.containers, list):
            modified = False
            for c in tracking.containers:
                if str(c.get("container_no", "")).strip().upper() == container.container_number:
                    c["empty_return_date"] = req.empty_return_date.isoformat()
                    c["eir_number"] = req.eir_number.strip()
                    c["status"] = "Returned Empty"
                    if req.depot_name:
                        c["depot_name"] = req.depot_name.strip()
                    if req.condition_at_return:
                        c["condition_at_return"] = req.condition_at_return.strip()
                    modified = True
            if modified:
                flag_modified(tracking, "containers")

    updated = repository.update_container(db, container)
    db.commit()
    db.refresh(updated)
    return updated


def delete_container_service(
    db: Session, container_id: int, user: str = "System"
) -> ShipmentContainer:
    """Soft deletes container entity."""
    container = get_container_by_id_service(db, container_id)
    deleted = repository.soft_delete_container(db, container, user)
    db.commit()
    return deleted


def sync_containers_from_file_service(
    db: Session, import_file_id: int, user: str = "System"
) -> List[ShipmentContainer]:
    """
    Synchronizes / backfills shipment_containers records from existing Phase 4 Booking,
    Phase 5 Cargo Shipping, and Demurrage & Detention sessions for an import file.
    """
    import_file = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not import_file:
        raise not_found("الملف الاستيرادي", import_file_id)

    # 1. Booking & Shipping Records
    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True,
    ).first()

    shipping = db.query(CargoShippingRecord).filter(
        CargoShippingRecord.import_file_id == import_file_id,
        CargoShippingRecord.is_active == True,
    ).first()

    demurrage = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == import_file_id,
        DemurrageTracking.is_active == True,
    ).first()

    carrier_name = (
        (demurrage.carrier_name if demurrage else None)
        or (booking.shipping_line_name if booking else None)
        or (booking.freight_forwarder_name if booking else None)
    )
    bl_no = (
        (demurrage.bill_of_lading_no if demurrage else None)
        or (booking.bill_of_lading_no if booking else None)
    )

    containers_map = {}

    # Read from CargoShippingRecord (rich milestone data)
    if shipping and isinstance(shipping.containers_loading_data, list):
        for item in shipping.containers_loading_data:
            c_no = str(item.get("container_no", "")).strip().upper()
            if c_no:
                containers_map[c_no] = {
                    "container_number": c_no,
                    "container_type": item.get("container_type") or "40HC",
                    "seal_number": item.get("seal_number") or item.get("seal_no"),
                    "tare_weight_kg": float(item.get("tare_weight_kg") or 0.0),
                    "net_weight_kg": float(item.get("net_weight_kg") or 0.0),
                    "gross_weight_kg": float(item.get("gross_weight_kg") or 0.0),
                    "vgm_weight_kg": float(item.get("vgm_weight_kg") or item.get("gross_weight_kg") or 0.0),
                    "vgm_status": item.get("vgm_status") or "Pending",
                    "vgm_ref_no": item.get("vgm_ref_no"),
                    "status": "Loaded & Sealed",
                }

    # Read from DemurrageTracking (dates & costs)
    if demurrage and isinstance(demurrage.containers, list):
        for item in demurrage.containers:
            c_no = str(item.get("container_no", "")).strip().upper()
            if c_no:
                existing = containers_map.setdefault(c_no, {
                    "container_number": c_no,
                    "container_type": item.get("container_type") or "40HC",
                    "status": item.get("status") or "Discharged",
                })
                # Merge demurrage dates
                discharge_str = item.get("discharge_date")
                gate_out_str = item.get("gate_out_date")
                return_str = item.get("empty_return_date")
                if discharge_str and isinstance(discharge_str, str):
                    try:
                        existing["discharge_date"] = date.fromisoformat(discharge_str[:10])
                    except ValueError:
                        pass
                if gate_out_str and isinstance(gate_out_str, str):
                    try:
                        existing["gate_out_date"] = date.fromisoformat(gate_out_str[:10])
                    except ValueError:
                        pass
                if return_str and isinstance(return_str, str):
                    try:
                        existing["empty_return_date"] = date.fromisoformat(return_str[:10])
                    except ValueError:
                        pass

                existing["demurrage_days"] = int(item.get("demurrage_days") or 0)
                existing["detention_days"] = int(item.get("detention_days") or 0)
                existing["storage_days"] = int(item.get("storage_days") or 0)
                existing["demurrage_cost_fx"] = float(item.get("demurrage_fx") or 0.0)
                existing["detention_cost_fx"] = float(item.get("detention_fx") or 0.0)
                existing["storage_cost_egp"] = float(item.get("storage_egp") or 0.0)
                existing["total_cost_egp"] = float(item.get("total_egp") or 0.0)
                if item.get("eir_number"):
                    existing["eir_number"] = item.get("eir_number")
                if item.get("status"):
                    existing["status"] = item.get("status")

    # Upsert into shipment_containers table
    result_list = []
    for c_no, data in containers_map.items():
        existing_rec = repository.get_container_by_file_and_number(db, import_file_id, c_no)
        if not existing_rec:
            rec = ShipmentContainer(
                container_number=c_no,
                container_type=data.get("container_type", "40HC"),
                seal_number=data.get("seal_number"),
                import_file_id=import_file_id,
                booking_id=booking.booking_id if booking else None,
                shipping_record_id=shipping.cargo_shipping_id if shipping else None,
                demurrage_tracking_id=demurrage.tracking_id if demurrage else None,
                carrier_name=carrier_name,
                bill_of_lading_no=bl_no,
                discharge_date=data.get("discharge_date"),
                gate_out_date=data.get("gate_out_date"),
                empty_return_date=data.get("empty_return_date"),
                tare_weight_kg=data.get("tare_weight_kg", 0.0),
                net_weight_kg=data.get("net_weight_kg", 0.0),
                gross_weight_kg=data.get("gross_weight_kg", 0.0),
                vgm_weight_kg=data.get("vgm_weight_kg", 0.0),
                vgm_status=data.get("vgm_status", "Pending"),
                vgm_ref_no=data.get("vgm_ref_no"),
                demurrage_days=data.get("demurrage_days", 0),
                detention_days=data.get("detention_days", 0),
                storage_days=data.get("storage_days", 0),
                demurrage_cost_fx=data.get("demurrage_cost_fx", 0.0),
                detention_cost_fx=data.get("detention_cost_fx", 0.0),
                storage_cost_egp=data.get("storage_cost_egp", 0.0),
                total_cost_egp=data.get("total_cost_egp", 0.0),
                currency=demurrage.currency if demurrage else "USD",
                status=data.get("status", "Allocated"),
                eir_number=data.get("eir_number"),
                created_by=user,
                updated_by=user,
            )
            created = repository.create_container(db, rec)
            result_list.append(created)
        else:
            # Update missing or newer attributes
            if booking and not existing_rec.booking_id:
                existing_rec.booking_id = booking.booking_id
            if shipping and not existing_rec.shipping_record_id:
                existing_rec.shipping_record_id = shipping.cargo_shipping_id
            if demurrage and not existing_rec.demurrage_tracking_id:
                existing_rec.demurrage_tracking_id = demurrage.tracking_id
            if carrier_name and not existing_rec.carrier_name:
                existing_rec.carrier_name = carrier_name
            if bl_no and not existing_rec.bill_of_lading_no:
                existing_rec.bill_of_lading_no = bl_no
            if data.get("seal_number") and not existing_rec.seal_number:
                existing_rec.seal_number = data.get("seal_number")
            if data.get("discharge_date") and not existing_rec.discharge_date:
                existing_rec.discharge_date = data.get("discharge_date")
            if data.get("gate_out_date") and not existing_rec.gate_out_date:
                existing_rec.gate_out_date = data.get("gate_out_date")
            if data.get("empty_return_date") and not existing_rec.empty_return_date:
                existing_rec.empty_return_date = data.get("empty_return_date")
            if data.get("eir_number") and not existing_rec.eir_number:
                existing_rec.eir_number = data.get("eir_number")
            if data.get("demurrage_days") is not None:
                existing_rec.demurrage_days = data["demurrage_days"]
                existing_rec.detention_days = data["detention_days"]
                existing_rec.storage_days = data["storage_days"]
                existing_rec.demurrage_cost_fx = data["demurrage_cost_fx"]
                existing_rec.detention_cost_fx = data["detention_cost_fx"]
                existing_rec.storage_cost_egp = data["storage_cost_egp"]
                existing_rec.total_cost_egp = data["total_cost_egp"]

            existing_rec.updated_by = user
            repository.update_container(db, existing_rec)
            result_list.append(existing_rec)

    db.commit()
    return result_list
