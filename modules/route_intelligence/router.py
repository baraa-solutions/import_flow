"""
Route & Supplier Intelligence Router (AI-ROUTE-006)
"""

from typing import List
from fastapi import APIRouter, Depends, status
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db

from .schemas import (
    SupplierRouteIntelligenceResponse,
    OperationalNoteItem,
    RouteOperationalNoteCreate,
)
from .service import (
    get_supplier_route_intelligence_service,
    add_route_operational_note_service,
)
from . import repository

router = APIRouter(prefix="/api/v1/route-intelligence", tags=["Route & Supplier Intelligence"], dependencies=[Depends(get_current_user)])


@router.get(
    "/supplier/{supplier_id}",
    response_model=SupplierRouteIntelligenceResponse,
    summary="جلب بطاقة الذكاء التاريخية والتفاوضية للمورد والمسار اللوجستي",
)
def get_supplier_intelligence_endpoint(supplier_id: int, db: Session = Depends(get_db)):
    return get_supplier_route_intelligence_service(db, supplier_id)


@router.post(
    "/notes",
    response_model=OperationalNoteItem,
    status_code=status.HTTP_201_CREATED,
    summary="تسجيل ملاحظة تشغيلية أو تحذير تفاوضي لمسار ومورد",
    dependencies=[Depends(require_permission("logistics_rules.create"))],
)
def create_operational_note_endpoint(req: RouteOperationalNoteCreate, db: Session = Depends(get_db)):
    return add_route_operational_note_service(db, req)


@router.get(
    "/supplier/{supplier_id}/notes",
    response_model=List[OperationalNoteItem],
    summary="جلب قائمة الملاحظات التشغيلية والتاريخية للمورد",
)
def get_supplier_notes_endpoint(supplier_id: int, db: Session = Depends(get_db)):
    notes = repository.get_notes_by_supplier(db, supplier_id)
    return notes
