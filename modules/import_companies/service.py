from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams
from .model import ImportCompany
from .repository import (
    create_company,
    get_companies,
    get_all_companies_admin,
    get_paginated_companies,
    get_company_by_id as repo_get_company_by_id,
    update_company_data,
    delete_company as repo_delete_company,
    restore_company as repo_restore_company,
)
from .schemas import ImportCompanyCreate, ImportCompanyUpdate
from .utils import calculate_days_to_renew
from .validators import validate_company


# ==================================================
# Add Days To Renew Calculations
# ==================================================

def add_days_to_renew(company: ImportCompany) -> ImportCompany:
    """Calculates remaining days for importer ID, VAT, and Commercial registration."""
    if company.importer_id_expiry:
        company.importer_id_days_to_renew = calculate_days_to_renew(company.importer_id_expiry)

    if company.vat_id_expiry:
        company.vat_id_days_to_renew = calculate_days_to_renew(company.vat_id_expiry)

    if company.registration_expiry:
        company.registration_days_to_renew = calculate_days_to_renew(company.registration_expiry)

    return company


# ==================================================
# Create Company Service
# ==================================================

def create_import_company(
    db: Session,
    company_data: ImportCompanyCreate
) -> ImportCompany:
    """Validates domain business rules and creates a new ImportCompany record."""
    validate_company(db, company_data)
    result = create_company(db, company_data)
    AuditLogService(db).log_activity(
        entity_type="ImportCompany",
        entity_id=result.company_id,
        entity_code=result.importer_id,
        action="CREATE",
        new_data={
            "importer_name": result.importer_name,
            "importer_id": result.importer_id,
            "vat_id": result.vat_id,
            "has_nafeza_token": result.has_nafeza_token,
        }
    )
    return add_days_to_renew(result)


# ==================================================
# Get All Active Companies Service
# ==================================================

def get_all_companies(db: Session) -> list[ImportCompany]:
    """Retrieves all active import companies with renewal day metrics."""
    companies = get_companies(db)
    for company in companies:
        add_days_to_renew(company)
    return companies


# ==================================================
# Get All Companies (Admin - Including Inactive)
# ==================================================

def get_all_companies_admin_service(db: Session) -> list[ImportCompany]:
    """Retrieves all import companies (active and deactivated) for admin view."""
    companies = get_all_companies_admin(db)
    for company in companies:
        add_days_to_renew(company)
    return companies


# ==================================================
# Get Paginated Companies Service
# ==================================================

def get_paginated_companies_service(
    db: Session,
    params: PageParams,
    response: Optional[Response] = None,
    country: Optional[str] = None,
) -> Dict[str, Any]:
    """Retrieves paginated import companies with renewal day metrics."""
    result = get_paginated_companies(
        db,
        params,
        response=response,
        country=country,
    )
    for company in result["items"]:
        add_days_to_renew(company)
    return result



# ==================================================
# Get Company By ID Service
# ==================================================

def get_company_by_id(db: Session, company_id: int) -> ImportCompany | None:
    """Retrieves a single company by primary key ID."""
    company = repo_get_company_by_id(db, company_id)
    if company:
        add_days_to_renew(company)
    return company


# ==================================================
# Update Company Service
# ==================================================

from modules.audit_logs.service import AuditLogService

def update_import_company(
    db: Session,
    company_id: int,
    company_data: ImportCompanyUpdate
) -> ImportCompany | None:
    """Updates an existing company's attributes via repository pattern."""
    company = repo_get_company_by_id(db, company_id)
    if company is None:
        return None

    update_dict = company_data.model_dump(
        exclude_unset=True
    )

    old_data = {
        k: getattr(company, k, None)
        for k in update_dict.keys()
    }

    updated_company = update_company_data(db, company, update_dict)
    
    # Security: Never log raw secret token into audit logs
    audit_old = {k: v for k, v in old_data.items() if k != "nafeza_token"}
    if "nafeza_token" in old_data:
        audit_old["has_nafeza_token"] = bool(old_data["nafeza_token"])

    audit_new = {k: v for k, v in update_dict.items() if k != "nafeza_token"}
    if "nafeza_token" in update_dict:
        audit_new["has_nafeza_token"] = bool(update_dict["nafeza_token"])

    AuditLogService(db).log_activity(
        entity_type="ImportCompany",
        entity_id=updated_company.company_id,
        entity_code=updated_company.importer_id,
        action="UPDATE",
        old_data=audit_old,
        new_data=audit_new,
    )
    
    return add_days_to_renew(updated_company)


# ==================================================
# Soft Delete Company Service
# ==================================================

def delete_import_company(db: Session, company_id: int) -> ImportCompany | None:
    """Soft deletes a company by setting is_active = False."""
    company = repo_get_company_by_id(db, company_id)
    if not company:
        return None

    if not company.is_active:
        return add_days_to_renew(company)

    deleted_company = repo_delete_company(db, company)
    AuditLogService(db).log_activity(
        entity_type="ImportCompany",
        entity_id=deleted_company.company_id,
        entity_code=deleted_company.importer_id,
        action="DELETE",
    )
    return add_days_to_renew(deleted_company)


# ==================================================
# Restore Company Service
# ==================================================

def restore_import_company(db: Session, company_id: int) -> ImportCompany | None:
    """Restores a soft-deleted company back to active state."""
    company = repo_get_company_by_id(db, company_id)
    if not company:
        return None

    restored_company = repo_restore_company(db, company)
    AuditLogService(db).log_activity(
        entity_type="ImportCompany",
        entity_id=restored_company.company_id,
        entity_code=restored_company.importer_id,
        action="RESTORE",
    )
    return add_days_to_renew(restored_company)