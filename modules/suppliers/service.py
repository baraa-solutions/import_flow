from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from modules.common.pagination import PageParams
from modules.common.sequence_generator import next_global_code
from modules.common.audit_stamp import SYSTEM_ACTOR, resolve_actor, set_updated_info

from .model import Supplier
from .schemas import CREDIT_GOVERNED_FIELDS, SupplierCreate, SupplierUpdate
from .repository import (
    create_supplier,
    get_active_suppliers,
    get_all_suppliers_admin,
    get_paginated_suppliers,
    get_supplier_by_id,
    get_supplier_by_exporter_id,
    count_suppliers,
    update_supplier,
    soft_delete_supplier,
    restore_supplier,
)


# ==================================================
# Generate Supplier Code (e.g. SUP-000001)
# ==================================================

def generate_supplier_code(db: Session) -> str:
    return next_global_code(db, Supplier.supplier_code, "SUP", pad=6)


# ==================================================
# Create Supplier Service
# ==================================================

def create_supplier_service(db: Session, supplier_data: SupplierCreate, actor: str = SYSTEM_ACTOR) -> Supplier:
    from .validators import validate_supplier
    validate_supplier(db, supplier_data)

    explicit_code = bool(getattr(supplier_data, "supplier_code", None))
    exporter_id_supplied = bool((supplier_data.foreign_exporter_id or "").strip())

    supplier = None
    for attempt in range(3):
        code = getattr(supplier_data, "supplier_code", None) if explicit_code else generate_supplier_code(db)
        if not exporter_id_supplied:
            exporter_id = f"EXP-{code}"
            supplier_data.foreign_exporter_id = exporter_id

        supplier_dict = supplier_data.model_dump()
        supplier_dict["supplier_code"] = code
        for governed in CREDIT_GOVERNED_FIELDS:  # credit limit only via the governed endpoint
            supplier_dict.pop(governed, None)
        supplier_dict["created_by"] = resolve_actor(actor)
        supplier_dict["updated_by"] = resolve_actor(actor)

        try:
            supplier = create_supplier(db, supplier_dict)
            break
        except IntegrityError:
            db.rollback()
            if attempt == 2 or explicit_code:
                raise

    AuditLogService(db).log_activity(
        entity_type="Supplier",
        entity_id=supplier.supplier_id,
        entity_code=supplier.supplier_code,
        action="CREATE",
        performed_by=resolve_actor(actor),
        new_data={"company_name": supplier.company_name, "foreign_exporter_id": supplier.foreign_exporter_id, "foreign_exporter_country_code": supplier.foreign_exporter_country_code}
    )
    
    return supplier



# ==================================================
# Get All Active Suppliers Service
# ==================================================

def get_all_suppliers_service(db: Session) -> list[Supplier]:
    return get_active_suppliers(db)


# ==================================================
# Get All Suppliers Admin Service (Active & Inactive)
# ==================================================

def get_all_suppliers_admin_service(db: Session) -> list[Supplier]:
    return get_all_suppliers_admin(db)


# ==================================================
# Get Paginated Suppliers Service
# ==================================================

def get_paginated_suppliers_service(
    db: Session,
    params: PageParams,
    response: Optional[Response] = None,
    supplier_type: Optional[str] = None,
    country: Optional[str] = None,
) -> Dict[str, Any]:
    return get_paginated_suppliers(
        db,
        params,
        response=response,
        supplier_type=supplier_type,
        country=country,
    )


# ==================================================
# Get Supplier By ID Service
# ==================================================

def get_supplier_by_id_service(db: Session, supplier_id: int) -> Supplier | None:
    return get_supplier_by_id(db, supplier_id)


# ==================================================
# Update Supplier Service
# ==================================================

from modules.audit_logs.service import AuditLogService

def update_supplier_service(
    db: Session,
    supplier_id: int,
    supplier_data: SupplierUpdate,
    actor: str = SYSTEM_ACTOR,
) -> Supplier | None:
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        return None
    # The audit actor comes from the authenticated user, never from the request body.
    supplier_data = supplier_data.model_copy(update={"updated_by": None})
    update_data = supplier_data.to_update_dict()
    old_data = {
        k: getattr(supplier, k, None)
        for k in update_data.keys()
    }
    
    set_updated_info(supplier, actor)
    updated = update_supplier(db, supplier, supplier_data)
    
    AuditLogService(db).log_activity(
        entity_type="Supplier",
        entity_id=updated.supplier_id,
        entity_code=updated.supplier_code,
        action="UPDATE",
        performed_by=resolve_actor(actor),
        old_data=old_data,
        new_data=update_data,
    )
    
    return updated


# ==================================================
# Delete Supplier Service
# ==================================================

def delete_supplier_service(db: Session, supplier_id: int, actor: str = SYSTEM_ACTOR) -> Supplier | None:
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        return None
    if not supplier.is_active:
        return supplier
    set_updated_info(supplier, actor)
    deleted = soft_delete_supplier(db, supplier)
    AuditLogService(db).log_activity(
        entity_type="Supplier",
        entity_id=deleted.supplier_id,
        entity_code=deleted.supplier_code,
        action="DELETE",
        performed_by=resolve_actor(actor),
    )
    return deleted


# ==================================================
# Restore Supplier Service
# ==================================================

def restore_supplier_service(db: Session, supplier_id: int, actor: str = SYSTEM_ACTOR) -> Supplier | None:
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        return None
    set_updated_info(supplier, actor)
    restored = restore_supplier(db, supplier)
    AuditLogService(db).log_activity(
        entity_type="Supplier",
        entity_id=restored.supplier_id,
        entity_code=restored.supplier_code,
        action="RESTORE",
        performed_by=resolve_actor(actor),
    )
    return restored


# ==================================================
# Supplier KPI Scorecard (LOG-KPIS-005)
# ==================================================

def get_supplier_scorecard_service(db: Session, supplier_id: int):
    supplier = get_supplier_by_id(db, supplier_id)
    if not supplier:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"المورد رقم [{supplier_id}] غير موجود."
        )

    from modules.purchase_orders.model import PurchaseOrder
    from modules.import_files.model import ImportFile
    from modules.cargo_shipping.model import CargoShippingRecord
    from modules.docs_customs_approval.model import CustomsDocumentApproval, DiscrepancyRectificationTicket
    from .schemas import SupplierScorecardResponse

    # 1. Purchase Orders
    orders = db.query(PurchaseOrder).filter(
        PurchaseOrder.supplier_id == supplier_id,
        PurchaseOrder.is_active == True,
    ).all()
    total_orders = len(orders)
    completed_orders = sum(1 for o in orders if o.status in ["Delivered", "Completed", "Closed"])
    order_fulfillment_rate = round((completed_orders / total_orders * 100.0) if total_orders > 0 else 100.0, 1)

    # 2. CRD Adherence (Cargo Readiness Date)
    import_files = db.query(ImportFile).filter(
        ImportFile.supplier_id == supplier_id,
        ImportFile.is_active == True,
    ).all()
    file_ids = [f.import_file_id for f in import_files]

    crd_records = db.query(CargoShippingRecord).filter(
        CargoShippingRecord.import_file_id.in_(file_ids)
    ).all() if file_ids else []

    total_crd = len(crd_records)
    if total_crd > 0:
        crd_on_time = sum(1 for r in crd_records if r.is_crd_validated is not False)
        crd_adherence_rate = round((crd_on_time / total_crd) * 100.0, 1)
    else:
        crd_adherence_rate = 95.0

    # 3. Documentation Accuracy Rate
    tickets = db.query(DiscrepancyRectificationTicket).join(
        CustomsDocumentApproval,
        DiscrepancyRectificationTicket.approval_id == CustomsDocumentApproval.approval_id
    ).filter(
        CustomsDocumentApproval.import_file_id.in_(file_ids)
    ).all() if file_ids else []

    doc_approvals = db.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.import_file_id.in_(file_ids)
    ).all() if file_ids else []

    total_docs = len(doc_approvals)
    total_tickets = len(tickets)
    if total_docs > 0:
        doc_accuracy_rate = round(max(50.0, 100.0 - (total_tickets / total_docs * 100.0)), 1)
    else:
        doc_accuracy_rate = 98.0

    # 4. Overall Weighted Score
    quality_score = round((crd_adherence_rate * 0.4) + (doc_accuracy_rate * 0.4) + (order_fulfillment_rate * 0.2), 1)
    quality_score = min(100.0, max(40.0, quality_score))
    star_rating = round(quality_score / 20.0, 1)

    if quality_score >= 90:
        tier_badge = "Platinum A+"
    elif quality_score >= 80:
        tier_badge = "Gold A"
    elif quality_score >= 70:
        tier_badge = "Silver B"
    else:
        tier_badge = "Probation C"

    summary_ar = (
        f"بطاقة أداء المورد [{supplier.company_name}]: "
        f"الالتزام بجاهزية البضاعة بنسبة {crd_adherence_rate}%، "
        f"ودقة مستندات الشحن {doc_accuracy_rate}% عبر {total_orders} أمر توريد، "
        f"بتقييم إجمالي {quality_score:.1f}/100 ({star_rating} من 5) وتصنيف [{tier_badge}]."
    )

    return SupplierScorecardResponse(
        supplier_id=supplier.supplier_id,
        supplier_code=supplier.supplier_code,
        company_name=supplier.company_name,
        supplier_type=supplier.supplier_type or "Manufacturer",
        country=supplier.foreign_exporter_country or "Unknown",
        total_orders_completed=total_orders,
        crd_adherence_rate=crd_adherence_rate,
        documentation_accuracy_rate=doc_accuracy_rate,
        order_fulfillment_rate=order_fulfillment_rate,
        quality_score_out_of_100=quality_score,
        star_rating=star_rating,
        tier_badge=tier_badge,
        executive_summary_ar=summary_ar,
    )