from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams, like_term, paginate
from modules.transport_locations.model import TransportLocation
from modules.transport_locations.schemas import TransportLocationCreate, TransportLocationUpdate

TRANSPORT_LOCATION_SORT_MAP = {
    "location_id": TransportLocation.location_id,
    "location_name": TransportLocation.location_name,
    "un_locode": TransportLocation.un_locode,
    "location_type": TransportLocation.location_type,
    "country": TransportLocation.country,
    "city": TransportLocation.city,
    "created_at": TransportLocation.created_at,
    "updated_at": TransportLocation.updated_at,
}


class TransportLocationRepository:

    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, location_id: int) -> Optional[TransportLocation]:
        return self.db.query(TransportLocation).filter(TransportLocation.location_id == location_id).first()

    def get_by_un_locode(self, un_locode: str) -> Optional[TransportLocation]:
        return (
            self.db.query(TransportLocation)
            .filter(TransportLocation.un_locode == un_locode.upper().strip())
            .first()
        )

    def get_all(
        self,
        include_inactive: bool = False,
        location_type: Optional[str] = None,
        country: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: Optional[int] = None,
    ) -> List[TransportLocation]:
        query = self.db.query(TransportLocation)

        if not include_inactive:
            query = query.filter(TransportLocation.is_active.is_(True))

        if location_type:
            query = query.filter(TransportLocation.location_type == location_type)

        if country:
            query = query.filter(TransportLocation.country.ilike(f"%{country}%"))

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    TransportLocation.un_locode.ilike(pattern),
                    TransportLocation.location_name.ilike(pattern),
                    TransportLocation.city.ilike(pattern),
                    TransportLocation.country.ilike(pattern),
                )
            )

        query = query.order_by(TransportLocation.location_name.asc())
        if skip > 0:
            query = query.offset(skip)
        if limit is not None:
            query = query.limit(limit)
        return query.all()

    def get_paginated(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        location_type: Optional[str] = None,
        country: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = self.db.query(TransportLocation)

        if not params.include_inactive:
            query = query.filter(TransportLocation.is_active.is_(True))

        if location_type:
            query = query.filter(TransportLocation.location_type == location_type)

        if country:
            query = query.filter(TransportLocation.country.ilike(f"%{country}%"))

        term = like_term(params.q)
        if term:
            query = query.filter(
                or_(
                    TransportLocation.un_locode.ilike(term, escape="\\"),
                    TransportLocation.location_name.ilike(term, escape="\\"),
                    TransportLocation.city.ilike(term, escape="\\"),
                    TransportLocation.country.ilike(term, escape="\\"),
                )
            )

        return paginate(
            query,
            params,
            sort_map=TRANSPORT_LOCATION_SORT_MAP,
            default_sort=[TransportLocation.location_name.asc()],
            pk=TransportLocation.location_id,
            response=response,
        )

    def create(self, data: TransportLocationCreate, commit: bool = True) -> TransportLocation:
        location = TransportLocation(
            un_locode=data.un_locode.upper().strip(),
            location_name=data.location_name.strip(),
            location_type=data.location_type.strip(),
            country=data.country.strip(),
            city=data.city.strip(),
            notes=data.notes.strip() if data.notes else None,
            is_active=True,
        )
        self.db.add(location)
        if commit:
            self.db.commit()
            self.db.refresh(location)
        else:
            self.db.flush()
        return location

    def update(self, location: TransportLocation, data: TransportLocationUpdate) -> TransportLocation:
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if value is not None and isinstance(value, str):
                value = value.strip()
            setattr(location, field, value)

        self.db.commit()
        self.db.refresh(location)
        return location

    def soft_delete(self, location: TransportLocation) -> TransportLocation:
        location.is_active = False
        self.db.commit()
        self.db.refresh(location)
        return location

    def restore(self, location: TransportLocation) -> TransportLocation:
        location.is_active = True
        self.db.commit()
        self.db.refresh(location)
        return location
