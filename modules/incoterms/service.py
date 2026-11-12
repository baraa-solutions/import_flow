import time
import threading
from typing import List, Optional, Dict, Tuple

from fastapi import HTTPException
from sqlalchemy.orm import Session

from .model import CostItem, Incoterm, IncotermResponsibility
from .schemas import (
    CostItemCreate,
    CostItemUpdate,
    IncotermCreate,
    IncotermResponsibilityCreate,
    IncotermResponsibilityUpdate,
    IncotermUpdate,
)
from . import repository
from modules.common.audit_stamp import SYSTEM_ACTOR, resolve_actor, set_updated_info
from .validators import (
    validate_cost_item_exists,
    validate_incoterm_exists,
    validate_no_duplicate_cost_item_code,
    validate_no_duplicate_incoterm_code,
    validate_no_duplicate_responsibility,
)

_INCOTERMS_CACHE: Dict[Tuple[int, bool], Tuple[float, List[Incoterm]]] = {}
_INCOTERMS_LOCK = threading.Lock()
_INCOTERMS_TTL = 300.0  # 5 minutes


def invalidate_incoterms_cache():
    """Invalidates the in-memory Incoterms cache."""
    with _INCOTERMS_LOCK:
        _INCOTERMS_CACHE.clear()


# ==================================================
# Incoterm Services (MD-006)
# ==================================================

def _created_fields(actor: str) -> dict:
    name = resolve_actor(actor)
    return {"created_by": name, "updated_by": name}


def create_incoterm_service(db: Session, data: IncotermCreate, actor: str = SYSTEM_ACTOR) -> Incoterm:
    validate_no_duplicate_incoterm_code(db, data.incoterm_code)
    created = repository.create_incoterm(db, {**data.model_dump(), **_created_fields(actor)})
    invalidate_incoterms_cache()
    return created


def get_all_incoterms_service(db: Session, include_inactive: bool = False) -> List[Incoterm]:
    now = time.time()
    bind_id = id(db.get_bind())
    cache_key = (bind_id, include_inactive)
    with _INCOTERMS_LOCK:
        cached = _INCOTERMS_CACHE.get(cache_key)
        if cached is not None:
            cached_time, cached_items = cached
            if now - cached_time < _INCOTERMS_TTL:
                return [db.merge(item, load=False) for item in cached_items]

    items = repository.get_all_incoterms(db, include_inactive)
    with _INCOTERMS_LOCK:
        _INCOTERMS_CACHE[cache_key] = (now, items)
    return items


def get_incoterm_by_id_service(db: Session, incoterm_id: int) -> Incoterm:
    incoterm = repository.get_incoterm_by_id(db, incoterm_id)
    if not incoterm:
        raise HTTPException(status_code=404, detail="Incoterm not found")
    return incoterm


def update_incoterm_service(db: Session, incoterm_id: int, data: IncotermUpdate, actor: str = SYSTEM_ACTOR) -> Incoterm:
    incoterm = repository.get_incoterm_by_id(db, incoterm_id)
    if not incoterm:
        raise HTTPException(status_code=404, detail="Incoterm not found")
    update_dict = data.model_dump(exclude_unset=True, exclude_none=True)
    update_dict.pop("created_by", None)
    update_dict["updated_by"] = resolve_actor(actor)
    updated = repository.update_incoterm(db, incoterm_id, update_dict)
    invalidate_incoterms_cache()
    return updated


def delete_incoterm_service(db: Session, incoterm_id: int, actor: str = SYSTEM_ACTOR) -> Incoterm:
    incoterm = repository.get_incoterm_by_id(db, incoterm_id)
    if not incoterm:
        raise HTTPException(status_code=404, detail="Incoterm not found")
    set_updated_info(incoterm, actor)
    toggled = repository.toggle_incoterm_active(db, incoterm_id, is_active=False)
    invalidate_incoterms_cache()
    return toggled


def restore_incoterm_service(db: Session, incoterm_id: int, actor: str = SYSTEM_ACTOR) -> Incoterm:
    incoterm = repository.get_incoterm_by_id(db, incoterm_id)
    if not incoterm:
        raise HTTPException(status_code=404, detail="Incoterm not found")
    set_updated_info(incoterm, actor)
    restored = repository.toggle_incoterm_active(db, incoterm_id, is_active=True)
    invalidate_incoterms_cache()
    return restored


# ==================================================
# Cost Item Services (MD-006A)
# ==================================================

def create_cost_item_service(db: Session, data: CostItemCreate, actor: str = SYSTEM_ACTOR) -> CostItem:
    validate_no_duplicate_cost_item_code(db, data.cost_item_code)
    return repository.create_cost_item(db, {**data.model_dump(), **_created_fields(actor)})


def get_all_cost_items_service(db: Session, include_inactive: bool = False) -> List[CostItem]:
    return repository.get_all_cost_items(db, include_inactive)


def get_cost_item_by_id_service(db: Session, cost_item_id: int) -> CostItem:
    item = repository.get_cost_item_by_id(db, cost_item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Cost item not found")
    return item


def update_cost_item_service(db: Session, cost_item_id: int, data: CostItemUpdate, actor: str = SYSTEM_ACTOR) -> CostItem:
    item = repository.get_cost_item_by_id(db, cost_item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Cost item not found")
    update_dict = data.model_dump(exclude_unset=True, exclude_none=True)
    update_dict.pop("created_by", None)
    update_dict["updated_by"] = resolve_actor(actor)
    return repository.update_cost_item(db, cost_item_id, update_dict)


def delete_cost_item_service(db: Session, cost_item_id: int, actor: str = SYSTEM_ACTOR) -> CostItem:
    item = repository.get_cost_item_by_id(db, cost_item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Cost item not found")
    set_updated_info(item, actor)
    return repository.toggle_cost_item_active(db, cost_item_id, is_active=False)


def restore_cost_item_service(db: Session, cost_item_id: int, actor: str = SYSTEM_ACTOR) -> CostItem:
    item = repository.get_cost_item_by_id(db, cost_item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Cost item not found")
    set_updated_info(item, actor)
    return repository.toggle_cost_item_active(db, cost_item_id, is_active=True)


# ==================================================
# Responsibility Matrix Services (MD-006B)
# ==================================================

def create_responsibility_service(
    db: Session, data: IncotermResponsibilityCreate, actor: str = SYSTEM_ACTOR
) -> IncotermResponsibility:
    validate_incoterm_exists(db, data.incoterm_id)
    validate_cost_item_exists(db, data.cost_item_id)
    validate_no_duplicate_responsibility(db, data.incoterm_id, data.cost_item_id)
    return repository.create_responsibility(db, {**data.model_dump(), **_created_fields(actor)})


def get_all_responsibilities_service(db: Session) -> List[IncotermResponsibility]:
    return repository.get_all_responsibilities(db)


def get_matrix_for_incoterm_service(
    db: Session, incoterm_id: int
) -> List[IncotermResponsibility]:
    validate_incoterm_exists(db, incoterm_id)
    return repository.get_matrix_for_incoterm(db, incoterm_id)


def update_responsibility_service(
    db: Session, responsibility_id: int, data: IncotermResponsibilityUpdate, actor: str = SYSTEM_ACTOR
) -> IncotermResponsibility:
    responsibility = repository.get_responsibility_by_id(db, responsibility_id)
    if not responsibility:
        raise HTTPException(status_code=404, detail="Responsibility record not found")
    update_dict = data.model_dump(exclude_unset=True, exclude_none=True)
    update_dict.pop("created_by", None)
    update_dict["updated_by"] = resolve_actor(actor)
    return repository.update_responsibility(db, responsibility_id, update_dict)


def delete_responsibility_service(
    db: Session, responsibility_id: int
) -> IncotermResponsibility:
    responsibility = repository.get_responsibility_by_id(db, responsibility_id)
    if not responsibility:
        raise HTTPException(status_code=404, detail="Responsibility record not found")
    return repository.delete_responsibility(db, responsibility_id)
