from datetime import datetime, timezone
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from .model import CustomsAbandonmentRadar


class CustomsAbandonmentRepository:

    @staticmethod
    def get_radar(db: Session, radar_id: int) -> Optional[CustomsAbandonmentRadar]:
        return db.query(CustomsAbandonmentRadar).filter(
            CustomsAbandonmentRadar.radar_id == radar_id,
            CustomsAbandonmentRadar.is_active == True,
        ).first()

    @staticmethod
    def get_radar_by_import_file_id(db: Session, import_file_id: int) -> Optional[CustomsAbandonmentRadar]:
        return db.query(CustomsAbandonmentRadar).filter(
            CustomsAbandonmentRadar.import_file_id == import_file_id,
            CustomsAbandonmentRadar.is_active == True,
        ).first()

    @staticmethod
    def list_radars(
        db: Session,
        risk_level: Optional[str] = None,
        abandonment_status: Optional[str] = None,
        port_type: Optional[str] = None,
        search: Optional[str] = None,
        is_active: bool = True,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[CustomsAbandonmentRadar], int]:
        query = db.query(CustomsAbandonmentRadar)
        if is_active is not None:
            query = query.filter(CustomsAbandonmentRadar.is_active == is_active)
        if risk_level:
            query = query.filter(CustomsAbandonmentRadar.risk_level == risk_level)
        if abandonment_status:
            query = query.filter(CustomsAbandonmentRadar.abandonment_status == abandonment_status)
        if port_type:
            query = query.filter(CustomsAbandonmentRadar.port_type == port_type)
        if search:
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    CustomsAbandonmentRadar.import_file_code.ilike(term),
                    CustomsAbandonmentRadar.importer_name.ilike(term),
                    CustomsAbandonmentRadar.bl_number.ilike(term),
                    CustomsAbandonmentRadar.customs_declaration_no.ilike(term),
                    CustomsAbandonmentRadar.acid_number.ilike(term),
                    CustomsAbandonmentRadar.port_name.ilike(term),
                )
            )

        total = query.count()
        # Sort by most urgent risk: days_remaining ascending
        radars = query.order_by(CustomsAbandonmentRadar.days_remaining.asc(), desc(CustomsAbandonmentRadar.radar_id)).offset(skip).limit(limit).all()
        return radars, total

    @staticmethod
    def get_all_active_radars(db: Session) -> List[CustomsAbandonmentRadar]:
        return db.query(CustomsAbandonmentRadar).filter(
            CustomsAbandonmentRadar.is_active == True,
            CustomsAbandonmentRadar.abandonment_status != "RESOLVED_RELEASED",
        ).all()

    @staticmethod
    def create_radar(db: Session, radar_obj: CustomsAbandonmentRadar) -> CustomsAbandonmentRadar:
        db.add(radar_obj)
        db.commit()
        db.refresh(radar_obj)
        return radar_obj

    @staticmethod
    def update_radar(db: Session, radar_id: int, updates: Dict[str, Any]) -> Optional[CustomsAbandonmentRadar]:
        radar = db.query(CustomsAbandonmentRadar).filter(CustomsAbandonmentRadar.radar_id == radar_id).first()
        if not radar:
            return None
        for key, value in updates.items():
            if hasattr(radar, key) and value is not None:
                setattr(radar, key, value)
        radar.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(radar)
        return radar

    @staticmethod
    def delete_radar(db: Session, radar_id: int, user: str = "System") -> bool:
        radar = db.query(CustomsAbandonmentRadar).filter(CustomsAbandonmentRadar.radar_id == radar_id).first()
        if not radar:
            return False
        radar.is_active = False
        radar.updated_by = user
        radar.updated_at = datetime.now(timezone.utc)
        db.commit()
        return True

    @staticmethod
    def get_summary(db: Session) -> Dict[str, int]:
        rows = db.query(CustomsAbandonmentRadar).filter(CustomsAbandonmentRadar.is_active == True).all()
        
        return {
            "total_radars": len(rows),
            "normal_count": sum(1 for r in rows if r.risk_level == "NORMAL"),
            "warning_15_days_count": sum(1 for r in rows if r.risk_level == "WARNING_15_DAYS"),
            "critical_7_days_count": sum(1 for r in rows if r.risk_level == "CRITICAL_7_DAYS"),
            "under_inventory_count": sum(1 for r in rows if r.risk_level == "UNDER_ABANDONMENT_INVENTORY"),
            "extension_pending_count": sum(1 for r in rows if r.abandonment_status == "EXTENSION_PENDING"),
            "moved_to_warehouse_count": sum(1 for r in rows if r.abandonment_status == "MOVED_TO_ABANDONED_WAREHOUSE"),
            "auction_scheduled_count": sum(1 for r in rows if r.abandonment_status == "AUCTION_SCHEDULED"),
            "resolved_released_count": sum(1 for r in rows if r.abandonment_status == "RESOLVED_RELEASED"),
            "seaport_count": sum(1 for r in rows if r.port_type == "SEAPORT"),
            "dry_port_count": sum(1 for r in rows if r.port_type == "DRY_PORT"),
            "airport_count": sum(1 for r in rows if r.port_type == "AIRPORT"),
        }
