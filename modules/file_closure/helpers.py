"""
Shared internal helpers and constants for the file_closure module.
"""
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.auth.permissions import has_user_permission
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.users.model import User

OPEN_TASK_STATUSES = ("Pending", "In Progress", "In-Progress", "Under Review")
CLOSURE_MODULE = "Phase 10 - Import File Closure & Historical Archive"
# Defaults older clients send verbatim: treated as "not given" so the signed-in user is recorded instead (FC-10).
LEGACY_AUDITOR_DEFAULTS = frozenset({"Internal Auditor", "Finance & Audit Controller", "Finance Manager"})
LEGACY_EXPORTER_DEFAULTS = frozenset({"Finance & Logistics Controller"})


def _get_active_file(db: Session, import_file_id: Optional[int]) -> ImportFile:
    if not import_file_id or import_file_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="معرف ملف الشحنة الاستيرادية (import_file_id) مطلوب ولا يمكن أن يكون فارغاً أو صفراً.",
        )
    imp = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not imp:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة الاستيرادية رقم {import_file_id} غير موجود أو محذوف.",
        )
    return imp


def _party_names(imp: ImportFile) -> Tuple[str, str]:
    """Company and supplier names from master data, else the file's stored names, else "" (never invented)."""
    company = getattr(imp, "company", None)
    supplier = getattr(imp, "supplier", None)
    company_name = (
        getattr(company, "importer_name", None)
        or getattr(company, "company_name", None)
        or imp.company_name
        or ""
    )
    supplier_name = (
        getattr(supplier, "company_name", None)
        or getattr(supplier, "supplier_name", None)
        or imp.supplier_name
        or ""
    )
    return company_name, supplier_name


def _resolve_user_name(value: Optional[str], legacy_defaults: frozenset, user: str) -> str:
    # BE810-T10: Client values in request bodies are ignored; acting user is taken from token.
    return user


def _require_any_permission(db: Session, actor: Optional[User], *codes: str, trusted: bool = False) -> None:
    """Route-level auth only proves the user may read closures; the write permission depends on the payload (BE810-F31)."""
    if trusted:
        return
    if actor is None:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Permission '{codes[-1]}' required.",
        )
    if not any(has_user_permission(db, actor, code) for code in codes):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Permission '{codes[-1]}' required.",
        )


def _is_closure_task(task: SmartTask) -> bool:
    return (
        task.msg_code == "CLO_TASK_OFFICIAL_CLOSURE"
        or task.task_type == "CLO-04"
        or "0904" in (task.task_code or "")
        # legacy rows created before msg codes existed: exact CLO-04 match in title only (BE810-F27)
        or "CLO-04" in (task.title or "")
    )


def _to_date(value) -> Optional[date]:
    if value is None:
        return None
    return value.date() if isinstance(value, datetime) else value
