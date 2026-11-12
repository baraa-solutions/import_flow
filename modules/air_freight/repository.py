"""Database access of the air freight suite (queries only, no business rules)."""
from typing import List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.transport_locations.model import TransportLocation

from .model import AirShipmentRecord, DraftAwbReviewSession


# ── Referenced master / operational data ─────────────────────────────────────

def get_import_file(db: Session, import_file_id: int) -> Optional[ImportFile]:
    return db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()


def get_location(db: Session, location_id: int) -> Optional[TransportLocation]:
    return db.query(TransportLocation).filter(TransportLocation.location_id == location_id).first()


def get_provider(db: Session, provider_id: int) -> Optional[ExternalServiceProvider]:
    return db.query(ExternalServiceProvider).filter(ExternalServiceProvider.provider_id == provider_id).first()


# ── Air shipment records ─────────────────────────────────────────────────────

def get_air_record(db: Session, air_record_id: int, include_inactive: bool = False) -> Optional[AirShipmentRecord]:
    query = db.query(AirShipmentRecord).filter(AirShipmentRecord.air_record_id == air_record_id)
    if not include_inactive:
        query = query.filter(AirShipmentRecord.is_active.is_(True))
    return query.first()


def list_air_records(db: Session, import_file_id: Optional[int] = None, include_inactive: bool = False) -> List[AirShipmentRecord]:
    query = db.query(AirShipmentRecord)
    if import_file_id is not None:
        query = query.filter(AirShipmentRecord.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(AirShipmentRecord.is_active.is_(True))
    return query.order_by(AirShipmentRecord.air_record_id.desc()).all()


def find_by_awb(
    db: Session, mawb_number: str, hawb_number: Optional[str], exclude_id: Optional[int] = None
) -> Optional[AirShipmentRecord]:
    """Any record (active or soft-deleted) with the same MAWB and house number (``None`` matches ``None``;
    house numbers compare case-insensitively)."""
    query = db.query(AirShipmentRecord).filter(AirShipmentRecord.mawb_number == mawb_number)
    if hawb_number:
        query = query.filter(func.upper(AirShipmentRecord.hawb_number) == hawb_number.strip().upper())
    else:
        query = query.filter(AirShipmentRecord.hawb_number.is_(None))
    if exclude_id is not None:
        query = query.filter(AirShipmentRecord.air_record_id != exclude_id)
    return query.first()


def add(db: Session, entity) -> None:
    db.add(entity)


# ── Draft AWB review sessions ────────────────────────────────────────────────

def get_review(db: Session, awb_review_id: int) -> Optional[DraftAwbReviewSession]:
    return (
        db.query(DraftAwbReviewSession)
        .filter(DraftAwbReviewSession.awb_review_id == awb_review_id, DraftAwbReviewSession.is_active.is_(True))
        .first()
    )


def list_reviews(db: Session, air_record_id: int) -> List[DraftAwbReviewSession]:
    return (
        db.query(DraftAwbReviewSession)
        .filter(DraftAwbReviewSession.air_record_id == air_record_id, DraftAwbReviewSession.is_active.is_(True))
        .order_by(DraftAwbReviewSession.version_number.desc())
        .all()
    )


def latest_review_version(db: Session, air_record_id: int) -> int:
    row = (
        db.query(DraftAwbReviewSession.version_number)
        .filter(DraftAwbReviewSession.air_record_id == air_record_id)
        .order_by(DraftAwbReviewSession.version_number.desc())
        .first()
    )
    return int(row[0]) if row else 0
