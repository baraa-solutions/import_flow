from typing import Any, Dict, List, Optional

from fastapi import HTTPException, Response, status
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams
from modules.transport_locations.model import TransportLocation
from modules.transport_locations.repository import TransportLocationRepository
from modules.transport_locations.schemas import TransportLocationCreate, TransportLocationUpdate
from modules.transport_locations.validators import TransportLocationValidator


class TransportLocationService:

    def __init__(self, db: Session):
        self.db = db
        self.repo = TransportLocationRepository(db)
        self.validator = TransportLocationValidator(db)

    def get_all(
        self,
        include_inactive: bool = False,
        location_type: Optional[str] = None,
        country: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: Optional[int] = None,
    ) -> List[TransportLocation]:
        return self.repo.get_all(
            include_inactive=include_inactive,
            location_type=location_type,
            country=country,
            search=search,
            skip=skip,
            limit=limit,
        )

    def get_paginated(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        location_type: Optional[str] = None,
        country: Optional[str] = None,
    ) -> Dict[str, Any]:
        return self.repo.get_paginated(
            params,
            response=response,
            location_type=location_type,
            country=country,
        )

    def get_by_id(self, location_id: int) -> TransportLocation:
        location = self.repo.get_by_id(location_id)
        if not location:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Transport location with ID {location_id} not found.",
            )
        return location

    def create(self, data: TransportLocationCreate, commit: bool = True) -> TransportLocation:
        self.validator.validate_no_duplicate_locode(data.un_locode)
        return self.repo.create(data, commit=commit)

    def update(self, location_id: int, data: TransportLocationUpdate) -> TransportLocation:
        location = self.get_by_id(location_id)
        return self.repo.update(location, data)

    def soft_delete(self, location_id: int) -> TransportLocation:
        location = self.get_by_id(location_id)
        return self.repo.soft_delete(location)

    def restore(self, location_id: int) -> TransportLocation:
        location = self.get_by_id(location_id)
        return self.repo.restore(location)
