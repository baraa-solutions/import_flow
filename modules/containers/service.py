import logging
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
    ContainerEirReturnRequest,
    ContainerEmptyReturnRequest,
    ContainerLedgerItemResponse,
    ContainerLedgerResponse,
)
from .validators import (
    normalize_container_number,
    validate_container_dates,
    validate_unique_container_number,
)
from . import repository

logger = logging.getLogger(__name__)


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

    effective_date = req.gate_out_date
    effective_ts = req.gate_out_timestamp
    if not effective_date and effective_ts:
        effective_date = effective_ts.date()
    elif not effective_ts and effective_date:
        effective_ts = datetime.combine(effective_date, datetime.min.time())
    elif not effective_date and not effective_ts:
        now_utc = datetime.now(timezone.utc)
        effective_date = now_utc.date()
        effective_ts = now_utc

    validate_container_dates(
        discharge_date=container.discharge_date,
        gate_out_date=effective_date,
        empty_return_date=container.empty_return_date,
    )

    container.gate_out_date = effective_date
    container.gate_out_timestamp = effective_ts
    if req.truck_plate_number:
        container.truck_plate_number = req.truck_plate_number.strip()
    if req.customs_inspection_seal:
        container.customs_inspection_seal = req.customs_inspection_seal.strip()
    container.status = "Gate Out"

    note_add = f"[Gate Out] Date: {effective_date}"
    if effective_ts:
        note_add += f" {effective_ts.strftime('%H:%M') if hasattr(effective_ts, 'strftime') else ''}"
    if req.truck_plate_number:
        note_add += f" | Truck: {req.truck_plate_number.strip()}"
    if req.customs_inspection_seal:
        note_add += f" | Customs Seal: {req.customs_inspection_seal.strip()}"
    if req.driver_name:
        note_add += f" | Driver: {req.driver_name.strip()}"
    if req.notes:
        note_add += f" | {req.notes.strip()}"
    container.notes = f"{container.notes or ''}\n{note_add}".strip()
    container.updated_by = user

    # Bidirectional sync: update matching container in DemurrageTracking session if linked
    tracking = None
    if container.demurrage_tracking_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.tracking_id == container.demurrage_tracking_id,
            DemurrageTracking.is_active == True,
        ).first()
    elif container.import_file_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == container.import_file_id,
            DemurrageTracking.is_active == True,
        ).first()
        if tracking:
            container.demurrage_tracking_id = tracking.tracking_id

    if tracking and isinstance(tracking.containers, list):
        modified = False
        for c in tracking.containers:
            if str(c.get("container_no", "")).strip().upper() == container.container_number:
                c["gate_out_date"] = effective_date.isoformat()
                c["gate_out_timestamp"] = effective_ts.isoformat() if effective_ts else None
                if req.truck_plate_number:
                    c["truck_plate_number"] = req.truck_plate_number.strip()
                if req.customs_inspection_seal:
                    c["customs_inspection_seal"] = req.customs_inspection_seal.strip()
                c["status"] = "Gate Out"
                modified = True
        if modified:
            flag_modified(tracking, "containers")
            try:
                from modules.demurrage_detention.service import recalculate_and_update_tracking_service
                recalculate_and_update_tracking_service(db, tracking.tracking_id, user=user)
            except Exception as exc:
                logger.exception("Failed to recalculate demurrage tracking %s on container gate-out: %s", tracking.tracking_id, exc)

    updated = repository.update_container(db, container)
    db.commit()
    db.refresh(updated)
    return updated


def empty_return_eir_service(
    db: Session, container_id: int, req: ContainerEirReturnRequest, user: str = "System"
) -> ShipmentContainer:
    """
    Registers container empty return (EIR) milestone, stops demurrage/detention accumulation
    for this individual container, and synchronizes with demurrage tracking session.
    """
    container = get_container_by_id_service(db, container_id)

    effective_date = req.empty_return_date
    effective_ts = req.eir_timestamp
    if not effective_date and effective_ts:
        effective_date = effective_ts.date()
    elif not effective_ts and effective_date:
        effective_ts = datetime.combine(effective_date, datetime.min.time())
    elif not effective_date and not effective_ts:
        now_utc = datetime.now(timezone.utc)
        effective_date = now_utc.date()
        effective_ts = now_utc

    validate_container_dates(
        discharge_date=container.discharge_date,
        gate_out_date=container.gate_out_date,
        empty_return_date=effective_date,
    )

    clean_eir = req.eir_number.strip()
    clean_condition = (req.eir_condition_status or req.condition_at_return or "Good").strip()

    container.empty_return_date = effective_date
    container.eir_timestamp = effective_ts
    container.eir_number = clean_eir
    container.eir_condition_status = clean_condition
    container.condition_at_return = clean_condition
    if req.depot_name:
        container.depot_name = req.depot_name.strip()
    container.status = "Returned Empty"

    note_add = f"[EIR #{clean_eir}] Returned on: {effective_date} (TS: {effective_ts}) | Condition: {clean_condition} | Depot: {container.depot_name or 'N/A'}"
    if req.notes:
        note_add += f" | {req.notes.strip()}"
    container.notes = f"{container.notes or ''}\n{note_add}".strip()
    container.updated_by = user

    # Sync with DemurrageTracking session
    tracking = None
    if container.demurrage_tracking_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.tracking_id == container.demurrage_tracking_id,
            DemurrageTracking.is_active == True,
        ).first()
    elif container.import_file_id:
        tracking = db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == container.import_file_id,
            DemurrageTracking.is_active == True,
        ).first()
        if tracking:
            container.demurrage_tracking_id = tracking.tracking_id

    if tracking and isinstance(tracking.containers, list):
        modified = False
        for c in tracking.containers:
            if str(c.get("container_no", "")).strip().upper() == container.container_number:
                c["empty_return_date"] = effective_date.isoformat()
                c["eir_timestamp"] = effective_ts.isoformat() if effective_ts else None
                c["eir_number"] = clean_eir
                c["eir_condition_status"] = clean_condition
                c["condition_at_return"] = clean_condition
                c["status"] = "Returned Empty"
                if req.depot_name:
                    c["depot_name"] = req.depot_name.strip()
                modified = True
        if modified:
            flag_modified(tracking, "containers")
            try:
                from modules.demurrage_detention.service import recalculate_and_update_tracking_service
                recalculate_and_update_tracking_service(db, tracking.tracking_id, user=user)
                for c in (tracking.containers or []):
                    if str(c.get("container_no", "")).strip().upper() == container.container_number:
                        container.demurrage_days = int(c.get("demurrage_days") or 0)
                        container.detention_days = int(c.get("detention_days") or 0)
                        container.storage_days = int(c.get("storage_days") or 0)
                        container.demurrage_cost_fx = float(c.get("demurrage_fx") or 0.0)
                        container.detention_cost_fx = float(c.get("detention_fx") or 0.0)
                        container.storage_cost_egp = float(c.get("storage_egp") or 0.0)
                        container.total_cost_egp = float(c.get("total_egp") or 0.0)
                        container.individual_demurrage_cost = round(
                            container.demurrage_cost_fx + container.detention_cost_fx, 2
                        )
            except Exception as exc:
                logger.exception("Failed to recalculate demurrage tracking %s on container EIR return: %s", tracking.tracking_id, exc)

    # Synchronize Import File EIR numbers
    if container.import_file_id:
        imp_file = db.query(ImportFile).filter(
            ImportFile.import_file_id == container.import_file_id,
            ImportFile.is_active == True,
        ).first()
        if imp_file:
            existing_eirs = [e.strip() for e in (imp_file.empty_containers_eir_numbers or "").split(",") if e.strip()]
            if clean_eir not in existing_eirs:
                existing_eirs.append(clean_eir)
                imp_file.empty_containers_eir_numbers = ", ".join(existing_eirs)

    updated = repository.update_container(db, container)
    db.commit()
    db.refresh(updated)
    return updated


def empty_return_container_service(
    db: Session, container_id: int, req: ContainerEmptyReturnRequest, user: str = "System"
) -> ShipmentContainer:
    """Wrapper delegating to empty_return_eir_service."""
    return empty_return_eir_service(db, container_id, req, user=user)


def get_container_ledger_service(db: Session, import_file_id: int) -> ContainerLedgerResponse:
    """
    Retrieves the container ledger for an import file, reflecting operational milestones,
    customs gate-out, empty return EIR records, and frozen/active demurrage cost status per container.
    """
    import_file = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not import_file:
        raise not_found("الملف الاستيرادي", import_file_id)

    containers, _ = repository.get_containers(db, import_file_id=import_file_id, is_active=True, limit=500)
    if not containers:
        try:
            containers = sync_containers_from_file_service(db, import_file_id)
        except Exception:
            containers = []

    items = []
    total_demurrage_fx = 0.0
    total_cost_egp = 0.0
    currency = "USD"
    totals_by_currency = {}

    for c in containers:
        c_curr = (c.currency or "USD").upper().strip()
        currency = c_curr
        is_stopped = bool(c.eir_timestamp or c.empty_return_date or c.status == "Returned Empty")
        stop_reason = None
        if is_stopped:
            if c.eir_number:
                stop_reason = f"مُثبت بموجب إيصال EIR #{c.eir_number}"
            else:
                stop_reason = "تم تسليم الحاوية الفارغة"

        ind_cost = c.individual_demurrage_cost
        if ind_cost <= 0.0 and (c.demurrage_cost_fx > 0 or c.detention_cost_fx > 0):
            ind_cost = round(c.demurrage_cost_fx + c.detention_cost_fx, 2)

        totals_by_currency[c_curr] = round(totals_by_currency.get(c_curr, 0.0) + ind_cost, 2)
        total_cost_egp += (c.total_cost_egp or 0.0)

        items.append(
            ContainerLedgerItemResponse(
                container_id=c.container_id,
                container_number=c.container_number,
                container_type=c.container_type,
                seal_number=c.seal_number,
                customs_inspection_seal=c.customs_inspection_seal,
                carrier_name=c.carrier_name,
                bill_of_lading_no=c.bill_of_lading_no,
                status=c.status,
                discharge_date=c.discharge_date,
                gate_out_date=c.gate_out_date,
                gate_out_timestamp=c.gate_out_timestamp,
                truck_plate_number=c.truck_plate_number,
                empty_return_date=c.empty_return_date,
                eir_number=c.eir_number,
                eir_timestamp=c.eir_timestamp,
                eir_condition_status=c.eir_condition_status or c.condition_at_return,
                depot_name=c.depot_name,
                demurrage_days=c.demurrage_days or 0,
                detention_days=c.detention_days or 0,
                storage_days=c.storage_days or 0,
                demurrage_cost_fx=c.demurrage_cost_fx or 0.0,
                detention_cost_fx=c.detention_cost_fx or 0.0,
                storage_cost_egp=c.storage_cost_egp or 0.0,
                total_cost_egp=c.total_cost_egp or 0.0,
                individual_demurrage_cost=ind_cost,
                currency=c.currency or "USD",
                is_demurrage_stopped=is_stopped,
                stop_reason=stop_reason,
                notes=c.notes,
            )
        )

    # If all containers share one currency, total_demurrage_fx is that total
    if len(totals_by_currency) == 1:
        single_curr, single_tot = next(iter(totals_by_currency.items()))
        total_demurrage_fx = single_tot
        currency = single_curr
    elif len(totals_by_currency) > 1:
        currency = "MIXED"
        total_demurrage_fx = sum(totals_by_currency.values())

    returned_cnt = sum(1 for it in items if it.is_demurrage_stopped)
    active_cnt = len(items) - returned_cnt

    return ContainerLedgerResponse(
        import_file_id=import_file_id,
        total_containers=len(items),
        returned_containers=returned_cnt,
        active_containers=active_cnt,
        total_demurrage_cost_fx=round(total_demurrage_fx, 2),
        total_cost_egp=round(total_cost_egp, 2),
        currency=currency,
        totals_by_currency=totals_by_currency,
        items=items,
    )


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
