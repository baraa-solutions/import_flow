from typing import Any, Dict, Iterable, Optional, Sequence, Set

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.errors import CodedHTTPException
from modules.common.validators import not_null_columns, require_active
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.schemas import POShipmentAllocationCreate, PurchaseOrderUpdate
from modules.suppliers.model import Supplier

# field -> (master model, Arabic label)
FOREIGN_KEYS = {
    "project_id": (Project, "المشروع"),
    "company_id": (ImportCompany, "شركة الاستيراد"),
    "supplier_id": (Supplier, "المورد"),
    "incoterm_id": (Incoterm, "شرط التسليم"),
    "currency_id": (Currency, "العملة"),
    "import_file_id": (ImportFile, "ملف الاستيراد"),
}

# Arabic labels of the PO header fields an update can set.
FIELD_LABELS_AR = {
    "project_id": "المشروع",
    "company_id": "شركة الاستيراد",
    "supplier_id": "المورد",
    "incoterm_id": "شرط التسليم",
    "currency_id": "العملة",
    "order_date": "تاريخ الفاتورة",
    "exchange_rate": "سعر الصرف",
    "status": "حالة أمر الشراء",
}

# NOT NULL columns an update may change but never clear (an explicit null used to fail on commit with a 500).
REQUIRED_UPDATE_FIELDS = {
    field: FIELD_LABELS_AR.get(field, field)
    for field in sorted(not_null_columns(PurchaseOrder) & set(PurchaseOrderUpdate.model_fields) - {"version"})
}

FINAL_STATUSES = frozenset({"CLOSED", "CANCELLED"})

PO_STATUS_TRANSITIONS: Dict[str, Set[str]] = {
    "DRAFT": {"APPROVED", "CANCELLED"},
    "APPROVED": {"DRAFT", "CANCELLED", "CLOSED"},
    "PARTIALLY_SHIPPED": {"CLOSED"},
    "FULLY_SHIPPED": {"CLOSED"},
    "CLOSED": set(),
    "CANCELLED": set(),
}


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


class PurchaseOrderValidator:

    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseOrderRepository(db)

    # ── master data ──

    def validate_foreign_keys(
        self,
        project_id: int,
        company_id: int,
        supplier_id: int,
        incoterm_id: int,
        currency_id: int,
        import_file_id: Optional[int] = None,
    ) -> None:
        """Create: every master-data reference must exist and be active."""
        values = dict(project_id=project_id, company_id=company_id, supplier_id=supplier_id,
                      incoterm_id=incoterm_id, currency_id=currency_id, import_file_id=import_file_id)
        for field, value in values.items():
            model, label = FOREIGN_KEYS[field]
            require_active(self.db, model, value, label)

    def validate_changed_foreign_keys(self, po: PurchaseOrder, changes: Dict[str, Any]) -> None:
        """Update: only references the payload changes are checked, so an old PO whose supplier was later
        deactivated can still be edited (notes, status, ...)."""
        for field, (model, label) in FOREIGN_KEYS.items():
            if field in changes and changes[field] is not None and changes[field] != getattr(po, field):
                require_active(self.db, model, changes[field], label)

    def reject_cleared_required_fields(self, changes: Dict[str, Any]) -> None:
        for field, label in REQUIRED_UPDATE_FIELDS.items():
            if field in changes and changes[field] is None:
                raise _bad_request(f"لا يمكن مسح الحقل الإلزامي ({label}) من أمر الشراء.")

    # ── line items ──

    def validate_line_items(self, items: Iterable[Any]) -> None:
        for idx, item in enumerate(items, start=1):
            if item.quantity is not None and item.quantity <= 0:
                raise _bad_request(f"البند رقم {idx}: الكمية يجب أن تكون أكبر من صفر.")
            if item.unit_price is not None and item.unit_price < 0:
                raise _bad_request(f"البند رقم {idx}: سعر الوحدة لا يمكن أن يكون سالباً.")
            require_active(self.db, CustomsTariff, item.tariff_id, f"البند رقم {idx}: بند التعريفة الجمركية")

    def validate_row_ids_belong(self, existing_ids: Set[int], sent_ids: Sequence[Optional[int]], label_ar: str) -> None:
        """Every id sent on update must be a row of this PO and appear once."""
        seen: Set[int] = set()
        for row_id in sent_ids:
            if row_id is None:
                continue
            if row_id not in existing_ids or row_id in seen:
                raise _bad_request(f"{label_ar} رقم {row_id} غير تابع لأمر الشراء أو مكرر في الطلب.")
            seen.add(row_id)

    def validate_removed_items_not_allocated(self, po_id: int, removed_ids: Set[int]) -> None:
        referenced = removed_ids & self.repo.allocated_item_ids(po_id)
        if referenced:
            ids = ", ".join(str(i) for i in sorted(referenced))
            raise CodedHTTPException(
                status.HTTP_409_CONFLICT,
                "PO_ITEMS_ALLOCATED",
                f"لا يمكن حذف بنود أمر الشراء ({ids}) لأنها مرتبطة بشحنات مسجلة. أرسل رقم البند (item_id) لتعديله بدلاً من حذفه.",
                item_ids=ids,
            )

    # ── header ──

    def validate_po_number_unique(self, po_number: str, exclude_id: Optional[int] = None) -> None:
        """``po_number`` is already normalized (trimmed, upper-case) by the request schema."""
        if self.repo.po_number_exists(po_number, exclude_id=exclude_id):
            raise _bad_request(f"رقم أمر الشراء '{po_number}' مستخدم بالفعل.")

    def normalize_status(self, value: Any) -> str:
        code = enum_codes.normalize(enum_codes.PO_STATUS, value)
        if not enum_codes.is_code(enum_codes.PO_STATUS, code):
            allowed = ", ".join(enum_codes.codes(enum_codes.PO_STATUS))
            raise _bad_request(f"حالة أمر الشراء '{value}' غير معروفة. القيم المسموحة: {allowed}.")
        return code

    def validate_status_transition(self, current_status: str, new_status: str) -> None:
        """Validates that a status change follows the allowed PO lifecycle transitions.
        A no-op transition (new_status == current_status) is always allowed.
        Shipped states are set only by fulfillment sync, not manual PUT."""
        if new_status == current_status:
            return
        allowed = PO_STATUS_TRANSITIONS.get(current_status, set())
        if new_status not in allowed:
            allowed_str = ", ".join(sorted(allowed)) if allowed else "لا توجد انتقالات مسموحة"
            raise _bad_request(
                f"لا يمكن تغيير حالة أمر الشراء من '{current_status}' إلى '{new_status}'. الانتقالات المسموحة: {allowed_str}."
            )

    # ── shipment allocations ──

    def normalize_allocation_status(self, value: Any) -> str:
        code = enum_codes.normalize(enum_codes.PO_ALLOCATION_STATUS, value)
        if not enum_codes.is_code(enum_codes.PO_ALLOCATION_STATUS, code):
            allowed = ", ".join(enum_codes.codes(enum_codes.PO_ALLOCATION_STATUS))
            raise _bad_request(f"حالة تخصيص الشحنة '{value}' غير معروفة. القيم المسموحة: {allowed}.")
        return code

    def validate_allocation(self, po: PurchaseOrder, data: POShipmentAllocationCreate) -> Optional[Any]:
        """Returns the allocated line item (None for a PO-level allocation)."""
        self.normalize_allocation_status(data.status)
        item = None
        target_item_id = getattr(data, "po_line_item_id", None) or getattr(data, "po_item_id", None)
        if target_item_id:
            item = next((it for it in po.line_items if it.item_id == target_item_id), None)
            if item is None:
                raise _bad_request(f"البند رقم #{target_item_id} غير مرتبط بأمر الشراء #{po.po_number}.")
        if data.import_file_id:
            require_active(self.db, ImportFile, data.import_file_id, "ملف الاستيراد")
        return item
