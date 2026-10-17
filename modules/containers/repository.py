from datetime import datetime, timezone
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import desc

from .model import ShipmentContainer


def create_container(db: Session, container: ShipmentContainer) -> ShipmentContainer:
    """Inserts a new shipment container record."""
    db.add(container)
    db.flush()
    db.refresh(container)
    return container


def get_container_by_id(db: Session, container_id: int) -> Optional[ShipmentContainer]:
    """Retrieves an active container by its primary key."""
    return db.query(ShipmentContainer).filter(
        ShipmentContainer.container_id == container_id,
        ShipmentContainer.is_active == True,
    ).first()


def get_container_by_file_and_number(
    db: Session, import_file_id: int, container_number: str
) -> Optional[ShipmentContainer]:
    """Finds a container by import file ID and container number."""
    return db.query(ShipmentContainer).filter(
        ShipmentContainer.import_file_id == import_file_id,
        ShipmentContainer.container_number == container_number,
        ShipmentContainer.is_active == True,
    ).first()


def get_containers_by_file_id(
    db: Session, import_file_id: int
) -> List[ShipmentContainer]:
    """Retrieves all active containers associated with an import file."""
    return db.query(ShipmentContainer).filter(
        ShipmentContainer.import_file_id == import_file_id,
        ShipmentContainer.is_active == True,
    ).order_by(ShipmentContainer.container_id.asc()).all()


def get_containers(
    db: Session,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    container_number: Optional[str] = None,
    carrier_name: Optional[str] = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 100,
) -> Tuple[List[ShipmentContainer], int]:
    """Filters containers with pagination."""
    query = db.query(ShipmentContainer).filter(ShipmentContainer.is_active == is_active)

    if import_file_id is not None:
        query = query.filter(ShipmentContainer.import_file_id == import_file_id)

    if status:
        query = query.filter(ShipmentContainer.status == status)

    if container_number:
        query = query.filter(ShipmentContainer.container_number.ilike(f"%{container_number.strip()}%"))

    if carrier_name:
        query = query.filter(ShipmentContainer.carrier_name.ilike(f"%{carrier_name.strip()}%"))

    total = query.count()
    items = query.order_by(desc(ShipmentContainer.created_at)).offset(skip).limit(limit).all()
    return items, total


def update_container(db: Session, container: ShipmentContainer) -> ShipmentContainer:
    """Persists updates to an existing container."""
    container.updated_at = datetime.now(timezone.utc)
    db.flush()
    db.refresh(container)
    return container


def soft_delete_container(
    db: Session, container: ShipmentContainer, user: str
) -> ShipmentContainer:
    """Soft deletes a container record."""
    container.is_active = False
    container.updated_at = datetime.now(timezone.utc)
    container.updated_by = user
    db.flush()
    return container
