from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy import exists, func, or_
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams, like_term, paginate
from .model import ExternalServiceProvider
from .schemas import PartnerCreate, PartnerUpdate

PARTNER_SORT_MAP = {
    "provider_id": ExternalServiceProvider.provider_id,
    "partner_code": ExternalServiceProvider.partner_code,
    "partner_name": ExternalServiceProvider.partner_name,
    "partner_type": ExternalServiceProvider.partner_type,
    "tax_id": ExternalServiceProvider.tax_id,
    "commercial_register": ExternalServiceProvider.commercial_register,
    "created_at": ExternalServiceProvider.created_at,
    "updated_at": ExternalServiceProvider.updated_at,
}


class ExternalServiceProviderRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_paginated(
        self,
        params: PageParams,
        response: Optional[Response] = None,
        partner_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = self.db.query(ExternalServiceProvider)
        if not params.include_inactive:
            query = query.filter(ExternalServiceProvider.is_active.is_(True))
        if partner_type and partner_type.strip().lower() != 'all':
            query = query.filter(func.lower(ExternalServiceProvider.partner_type).contains(partner_type.strip().lower()))

        term = like_term(params.q)
        if term:
            query = query.filter(
                or_(
                    ExternalServiceProvider.partner_name.ilike(term, escape="\\"),
                    ExternalServiceProvider.partner_code.ilike(term, escape="\\"),
                    ExternalServiceProvider.tax_id.ilike(term, escape="\\"),
                    ExternalServiceProvider.commercial_register.ilike(term, escape="\\"),
                    ExternalServiceProvider.contact_person.ilike(term, escape="\\"),
                )
            )
        return paginate(
            query,
            params,
            sort_map=PARTNER_SORT_MAP,
            default_sort=[ExternalServiceProvider.partner_name.asc()],
            pk=ExternalServiceProvider.provider_id,
            response=response,
        )

    def get_all(self, partner_type: Optional[str] = None, include_inactive: bool = False) -> List[ExternalServiceProvider]:
        query = self.db.query(ExternalServiceProvider)
        if not include_inactive:
            query = query.filter(ExternalServiceProvider.is_active.is_(True))
        if partner_type and partner_type.strip().lower() != 'all':
            query = query.filter(func.lower(ExternalServiceProvider.partner_type).contains(partner_type.strip().lower()))
        return query.order_by(ExternalServiceProvider.provider_id.desc()).all()

    def get_by_id(self, provider_id: int) -> Optional[ExternalServiceProvider]:
        return self.db.query(ExternalServiceProvider).filter(ExternalServiceProvider.provider_id == provider_id).first()

    def get_by_code(self, partner_code: str) -> Optional[ExternalServiceProvider]:
        return self.db.query(ExternalServiceProvider).filter(ExternalServiceProvider.partner_code == partner_code).first()

    def exists_by_code(self, partner_code: str) -> bool:
        return self.db.query(exists().where(ExternalServiceProvider.partner_code == partner_code)).scalar()

    def exists_by_swift_code(self, swift_code: str, exclude_id: Optional[int] = None) -> bool:
        if not swift_code or not swift_code.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.swift_code) == swift_code.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_scac_code(self, scac_code: str, exclude_id: Optional[int] = None) -> bool:
        if not scac_code or not scac_code.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.scac_code) == scac_code.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_fiata_id(self, fiata_id: str, exclude_id: Optional[int] = None) -> bool:
        if not fiata_id or not fiata_id.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.fiata_id) == fiata_id.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_accreditation_number(self, accreditation_number: str, exclude_id: Optional[int] = None) -> bool:
        if not accreditation_number or not accreditation_number.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.inspection_accreditation_number) == accreditation_number.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_clearance_license_number(self, clearance_license_number: str, exclude_id: Optional[int] = None) -> bool:
        if not clearance_license_number or not clearance_license_number.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.clearance_license_number) == clearance_license_number.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_transport_license_number(self, transport_license_number: str, exclude_id: Optional[int] = None) -> bool:
        if not transport_license_number or not transport_license_number.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.transport_license_number) == transport_license_number.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def exists_by_insurance_license_number(self, insurance_license_number: str, exclude_id: Optional[int] = None) -> bool:
        if not insurance_license_number or not insurance_license_number.strip():
            return False
        stmt = exists().where(func.lower(ExternalServiceProvider.insurance_license_number) == insurance_license_number.strip().lower())
        if exclude_id:
            stmt = stmt.where(ExternalServiceProvider.provider_id != exclude_id)
        return self.db.query(stmt).scalar()

    def get_last_partner_id(self) -> int:
        last = self.db.query(ExternalServiceProvider.provider_id).order_by(ExternalServiceProvider.provider_id.desc()).first()
        return last[0] if last else 0

    def create(self, partner_data: PartnerCreate, partner_code: str) -> ExternalServiceProvider:
        db_obj = ExternalServiceProvider(
            partner_code=partner_code,
            **partner_data.model_dump()
        )
        self.db.add(db_obj)
        self.db.commit()
        self.db.refresh(db_obj)

        from modules.audit_logs.service import AuditLogService
        AuditLogService(self.db).log_activity(
            entity_type="ExternalServiceProvider",
            entity_id=db_obj.provider_id,
            entity_code=db_obj.partner_code,
            action="CREATE",
            performed_by="SYSTEM",
            new_data={"partner_name": db_obj.partner_name, "partner_type": db_obj.partner_type}
        )

        return db_obj

    def update(self, provider_id: int, partner_data: PartnerUpdate) -> Optional[ExternalServiceProvider]:
        db_obj = self.get_by_id(provider_id)
        if not db_obj:
            return None
        update_data = partner_data.model_dump(exclude_unset=True)
        old_data = {
            k: getattr(db_obj, k, None)
            for k in update_data.keys()
        }
        for key, value in update_data.items():
            setattr(db_obj, key, value)
        self.db.commit()
        self.db.refresh(db_obj)

        from modules.audit_logs.service import AuditLogService
        AuditLogService(self.db).log_activity(
            entity_type="ExternalServiceProvider",
            entity_id=db_obj.provider_id,
            entity_code=db_obj.partner_code,
            action="UPDATE",
            performed_by="SYSTEM",
            old_data=old_data,
            new_data=update_data,
        )

        return db_obj

    def soft_delete(self, provider_id: int) -> bool:
        db_obj = self.get_by_id(provider_id)
        if not db_obj:
            return False
        db_obj.is_active = False
        self.db.commit()

        from modules.audit_logs.service import AuditLogService
        AuditLogService(self.db).log_activity(
            entity_type="ExternalServiceProvider",
            entity_id=db_obj.provider_id,
            entity_code=db_obj.partner_code,
            action="DELETE",
            performed_by="SYSTEM",
        )

        return True

    def restore(self, provider_id: int) -> bool:
        db_obj = self.get_by_id(provider_id)
        if not db_obj:
            return False
        db_obj.is_active = True
        self.db.commit()

        from modules.audit_logs.service import AuditLogService
        AuditLogService(self.db).log_activity(
            entity_type="ExternalServiceProvider",
            entity_id=db_obj.provider_id,
            entity_code=db_obj.partner_code,
            action="RESTORE",
            performed_by="SYSTEM",
        )

        return True