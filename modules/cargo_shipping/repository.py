from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from sqlalchemy.orm.attributes import flag_modified

from .model import CargoShippingRecord
from .schemas import CargoShippingCreate, CargoShippingUpdate
from .validators import SERVER_MANAGED_CARGOX_KEYS
from modules.common.sequence_generator import next_yearly_code
from modules.common.validators import not_null_columns

def generate_cargo_shipping_code(db: Session) -> str:
    """Next Cargo Shipping Code ``SHP-YYYY-XXXX`` (highest suffix of the year + 1)."""
    return next_yearly_code(db, CargoShippingRecord.cargo_shipping_code, "SHP", pad=4)

def get_cargo_shipping_by_id(db: Session, record_id: int, include_inactive: bool = False) -> Optional[CargoShippingRecord]:
    query = db.query(CargoShippingRecord).filter(CargoShippingRecord.cargo_shipping_id == record_id)
    if not include_inactive:
        query = query.filter(CargoShippingRecord.is_active == True)
    return query.first()

def get_cargo_shipping_by_import_file(db: Session, import_file_id: int, include_inactive: bool = False) -> Optional[CargoShippingRecord]:
    query = db.query(CargoShippingRecord).filter(CargoShippingRecord.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(CargoShippingRecord.is_active == True)
    return query.order_by(desc(CargoShippingRecord.cargo_shipping_id)).first()

def get_cargo_shipping_list(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CargoShippingRecord]:
    query = db.query(CargoShippingRecord)
    if not include_inactive:
        query = query.filter(CargoShippingRecord.is_active == True)
    if import_file_id:
        query = query.filter(CargoShippingRecord.import_file_id == import_file_id)
    if status:
        query = query.filter(CargoShippingRecord.status == status)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (CargoShippingRecord.cargo_shipping_code.ilike(pattern)) |
            (CargoShippingRecord.owner.ilike(pattern))
        )
    return query.order_by(desc(CargoShippingRecord.cargo_shipping_id)).all()

def _client_cargox_data(cargox_item, current: Optional[dict]) -> dict:
    """cargox_exchange_data from a request: client fields (platform provider) are taken, the server-managed
    keys (checklist, envelope status, tx hash, envelope id) keep their stored values."""
    data = dict(current or {})
    incoming = cargox_item.model_dump() if hasattr(cargox_item, "model_dump") else dict(cargox_item or {})
    for key, value in incoming.items():
        if key not in SERVER_MANAGED_CARGOX_KEYS:
            data[key] = value
    if current is None:
        data.update({"verification_checklist": [], "envelope_status": "Created", "blockchain_tx_hash": None, "envelope_id": None})
    return data


def create_cargo_shipping(db: Session, schema: CargoShippingCreate, code: str, processed_containers: list, processed_lcl: dict,
                          status: str, owner: str, user: str) -> CargoShippingRecord:
    """Adds and flushes the record (the service commits)."""
    db_obj = CargoShippingRecord(
        cargo_shipping_code=code,
        import_file_id=schema.import_file_id,
        booking_id=schema.booking_id,
        shipment_type=schema.shipment_type or "FCL",
        crd_date=schema.crd_date,
        cargo_cutoff_date=schema.cargo_cutoff_date,
        containers_loading_data=processed_containers,
        lcl_tracking_data=processed_lcl,
        courier_tracking_data=schema.courier_tracking_data.model_dump() if schema.courier_tracking_data else {},
        cargox_exchange_data=_client_cargox_data(schema.cargox_exchange_data, None) if schema.cargox_exchange_data else {},
        live_tracking_url=schema.live_tracking_url,
        status=status,
        owner=owner,
        notes=schema.notes,
        is_active=True,
        created_at=datetime.now(timezone.utc),
        created_by=user,
        updated_at=datetime.now(timezone.utc),
        updated_by=user,
    )
    db.add(db_obj)
    db.flush()
    return db_obj


def apply_cargo_shipping_update(db_obj: CargoShippingRecord, schema: CargoShippingUpdate, processed_containers: Optional[list] = None,
                                processed_lcl: Optional[dict] = None) -> CargoShippingRecord:
    """Copies the sent fields onto an ACTIVE record (no commit). ``status`` is resolved by the service and the
    server-managed CargoX keys are never taken from the payload."""
    update_data = schema.model_dump(exclude_unset=True)
    update_data.pop("status", None)
    if processed_containers is not None:
        db_obj.containers_loading_data = processed_containers
        flag_modified(db_obj, "containers_loading_data")
    update_data.pop("containers_loading_data", None)

    if processed_lcl is not None:
        db_obj.lcl_tracking_data = processed_lcl
        flag_modified(db_obj, "lcl_tracking_data")
    update_data.pop("lcl_tracking_data", None)

    if update_data.get("courier_tracking_data") is not None:
        db_obj.courier_tracking_data = schema.courier_tracking_data.model_dump()
        flag_modified(db_obj, "courier_tracking_data")
    update_data.pop("courier_tracking_data", None)

    if update_data.get("cargox_exchange_data") is not None:
        db_obj.cargox_exchange_data = _client_cargox_data(schema.cargox_exchange_data, db_obj.cargox_exchange_data or {})
        flag_modified(db_obj, "cargox_exchange_data")
    update_data.pop("cargox_exchange_data", None)

    required = not_null_columns(CargoShippingRecord)
    for key, value in update_data.items():
        if value is None and key in required:
            continue
        setattr(db_obj, key, value)

    db_obj.updated_at = datetime.now(timezone.utc)
    return db_obj


def set_cargo_shipping_active(db_obj: CargoShippingRecord, is_active: bool, user: str) -> None:
    db_obj.is_active = is_active
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = user
