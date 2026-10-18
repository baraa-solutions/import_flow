from collections import Counter
from datetime import date
from typing import Any, Iterable, List, Optional, Sequence, Set, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.errors import CodedHTTPException
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder
from modules.transport_locations.model import TransportLocation

from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
)

# Error code (detail["code"]) for a second active study on the same import file.
SCENARIO_SESSION_EXISTS = "SCENARIO_SESSION_EXISTS"
SCENARIO_ITEMS_BOOKED = "SCENARIO_ITEMS_BOOKED"


class ShippingScenarioValidator:
    """
    Validation rules for BP-007 Shipping Scenarios Evaluation
    """

    @staticmethod
    def validate_evaluation_create(payload: ShippingEvaluationCreate) -> None:
        if payload.avg_form4_days < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Average Form 4 days cannot be negative.",
            )

        if payload.avg_clearance_days < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Average Customs Clearance days cannot be negative.",
            )

        if payload.items:
            ShippingScenarioValidator.validate_scenario_items(
                payload.cargo_ready_date, payload.items
            )

    @staticmethod
    def validate_evaluation_update(payload: ShippingEvaluationUpdate, stored: Any) -> None:
        if payload.avg_form4_days is not None and payload.avg_form4_days < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Average Form 4 days cannot be negative.",
            )

        if payload.avg_clearance_days is not None and payload.avg_clearance_days < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Average Customs Clearance days cannot be negative.",
            )

        if payload.items is not None:
            ShippingScenarioValidator.validate_scenario_items(
                payload.cargo_ready_date or stored.cargo_ready_date, payload.items
            )
        elif payload.cargo_ready_date is not None and payload.cargo_ready_date != stored.cargo_ready_date:
            if stored.items:
                ShippingScenarioValidator.validate_scenario_items(
                    payload.cargo_ready_date, stored.items
                )

    @staticmethod
    def validate_scenario_items(
        cargo_ready_date: date, items: Iterable[Any]
    ) -> None:
        seen_keys = set()
        for idx, item in enumerate(items, start=1):
            if item.sailing_date < cargo_ready_date:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Option #{idx} ({item.provider_name}): Sailing date ({item.sailing_date}) cannot be before Cargo Ready Date ({cargo_ready_date}).",
                )

            if item.estimated_arrival_date <= item.sailing_date:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Option #{idx} ({item.provider_name}): Estimated Arrival Date (ETA) must be after Sailing Date.",
                )

            if item.expected_line_delay_days < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Option #{idx} ({item.provider_name}): Expected delay days cannot be negative.",
                )

            key = (item.provider_id, item.provider_name.strip().lower(), item.vessel_name.strip().lower(), item.sailing_date)
            if key in seen_keys:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Duplicate shipping option found for Freight Forwarder ID '{item.provider_id}', Shipping Line '{item.provider_name}' on vessel '{item.vessel_name}' with sailing date {item.sailing_date}.",
                )
            seen_keys.add(key)

    @staticmethod
    def validate_foreign_keys(
        db: Session, header: Any, items: Optional[Iterable[Any]] = None, stored: Optional[Any] = None
    ) -> None:
        """Referenced rows must exist (400 otherwise). New references must also be active; on update
        (``stored`` = the saved session) a reference that is already saved may point to a row deactivated
        since, so a resent full payload stays editable. One IN query per model."""
        items = list(items or ())
        saved_items = list(stored.items) if stored is not None else []

        def header_ref(field: str, label: str) -> Tuple[Optional[int], str, bool]:
            value = getattr(header, field)
            return value, label, not (stored is not None and getattr(stored, field) == value)

        def item_refs(field: str, label: str) -> List[Tuple[Optional[int], str, bool]]:
            # Per field and per use: an option may keep a saved (since deactivated) reference, but the
            # same id cannot be reused by an extra option or moved to another field.
            saved = Counter(getattr(it, field) for it in saved_items)
            refs = []
            for it in items:
                value = getattr(it, field)
                kept = saved[value] > 0
                if kept:
                    saved[value] -= 1
                refs.append((value, label, not kept))
            return refs

        _require_refs(db, ImportFile, "import_file_id", [header_ref("import_file_id", "ملف الاستيراد")])
        _require_refs(db, PurchaseOrder, "po_id", [header_ref("po_id", "أمر الشراء")])
        _require_refs(db, Project, "project_id", [header_ref("project_id", "المشروع")])
        _require_refs(
            db, TransportLocation, "location_id",
            [header_ref("port_of_loading_id", "ميناء الشحن"), header_ref("port_of_discharge_id", "ميناء الوصول")]
            + item_refs("port_of_loading_id", "ميناء الشحن")
            + item_refs("port_of_discharge_id", "ميناء الوصول"),
        )
        _require_refs(
            db, ExternalServiceProvider, "provider_id",
            item_refs("provider_id", "مقدم خدمة الشحن") + item_refs("customs_broker_id", "المخلص الجمركي"),
        )

    @staticmethod
    def validate_no_other_session_for_file(existing_sessions: List[Any], session_id: Optional[int] = None) -> None:
        """One active study per import file (create, and update when the file link changes): coded 409."""
        other = next((s for s in existing_sessions if s.session_id != session_id), None)
        if other is None:
            return
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT,
            SCENARIO_SESSION_EXISTS,
            "يوجد بالفعل دراسة سيناريوهات شحن محفوظة لهذا الملف. يرجى الذهاب لتعديل الدراسة الحالية بدلاً من إنشاء دراسة جديدة.",
            session_code=other.session_code,
            session_id=other.session_id,
        )

    @staticmethod
    def validate_item_ids_belong(stored_ids: Set[int], sent_ids: Sequence[Optional[int]]) -> None:
        """400 on foreign or duplicate item IDs in the update payload."""
        seen: Set[int] = set()
        for item_id in sent_ids:
            if item_id is None:
                continue
            if item_id in seen:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"بند السيناريو رقم {item_id} مكرر في الطلب.",
                )
            if item_id not in stored_ids:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"بند السيناريو رقم {item_id} غير تابع لدراسة السيناريوهات.",
                )
            seen.add(item_id)

    @staticmethod
    def validate_removed_not_booked(booked_ids: Set[int]) -> None:
        """409 SCENARIO_ITEMS_BOOKED if any removed item is referenced by an active freight booking."""
        if not booked_ids:
            return
        sorted_ids = sorted(list(booked_ids))
        ids = ", ".join(str(i) for i in sorted_ids)
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT,
            SCENARIO_ITEMS_BOOKED,
            f"لا يمكن حذف خيارات الشحن ({ids}) المرتبطة بحجز شحن.",
            item_ids=ids,
        )

    @staticmethod
    def validate_scenario_currencies(db: Session, items: Iterable[Any]) -> None:
        """Validate currency codes for all scenario items: required when price > 0, normalized to uppercase."""
        from modules.common.validators import validate_price_currency

        for item in items:
            for price_field, curr_field, label in SCENARIO_CURRENCY_PRICE_PAIRS:
                price = getattr(item, price_field, 0.0) if hasattr(item, price_field) else (item.get(price_field, 0.0) if isinstance(item, dict) else 0.0)
                price = price or 0.0
                curr = getattr(item, curr_field, None) if hasattr(item, curr_field) else (item.get(curr_field) if isinstance(item, dict) else None)
                normalized = validate_price_currency(db, price, curr, label_ar=label)
                if hasattr(item, curr_field):
                    setattr(item, curr_field, normalized)
                elif isinstance(item, dict):
                    item[curr_field] = normalized


SCENARIO_CURRENCY_PRICE_PAIRS = (
    ("total_quotation_amount", "quotation_currency", "عملة عرض السعر الإجمالي"),
    ("container_40ft_price", "container_40ft_currency", "عملة حاوية 40 قدم"),
    ("container_20ft_price", "container_20ft_currency", "عملة حاوية 20 قدم"),
    ("lcl_cbm_price", "lcl_cbm_currency", "عملة شحن جزئي LCL"),
    ("express_courier_price", "express_courier_currency", "عملة البريد السريع"),
    ("eur_atr_price", "eur_atr_currency", "عملة شهادة EUR / ATR"),
    ("solas_vgm_price", "solas_vgm_currency", "عملة وزن الحاوية SOLAS VGM"),
    ("vgm_notification_price", "vgm_notification_currency", "عملة إخطار VGM"),
    ("telex_release_price", "telex_release_currency", "عملة إصدار التلكس"),
    ("insurance_price", "insurance_currency", "عملة التأمين"),
    ("booking_cancellation_price", "booking_cancellation_currency", "عملة إلغاء الحجز"),
    ("ics2_filing_fee_price", "ics2_filing_fee_currency", "عملة تسجيل إقرارات ICS2"),
    ("others_fee_price", "others_fee_currency", "عملة المصاريف الأخرى"),
    ("document_fees_price", "document_fees_currency", "عملة رسوم المستندات"),
    ("waiver_letter_fee_price", "waiver_letter_fee_currency", "عملة رسوم خطاب التنازل"),
    ("dthc_price", "dthc_currency", "عملة مصاريف التفريغ DTHC"),
    ("storage_per_week_price", "storage_per_week_currency", "عملة الأرضيات أسبوعياً"),
    ("extra_day_storage_price", "extra_day_storage_currency", "عملة الأرضيات اليومية الإضافية"),
    ("clearance_fee_price", "clearance_fee_currency", "عملة رسوم التخليص الجمركي"),
    ("inspection_fee_price", "inspection_fee_currency", "عملة رسوم الكشف والمعاينة"),
    ("inland_transport_fee_price", "inland_transport_fee_currency", "عملة النقل الداخلي"),
    ("port_expenses_price", "port_expenses_currency", "عملة مصاريف الميناء"),
)


def _require_refs(db: Session, model: Any, pk: str, refs: List[Tuple[Optional[int], str, bool]]) -> None:
    """``refs`` = (id, Arabic label, must_be_active); None ids are skipped. One query; the first missing id,
    or an inactive one that must be active -> 400 (same detail as ``modules.common.validators.require_active``)."""
    wanted = [r for r in refs if r[0] is not None]
    if not wanted:
        return
    column = getattr(model, pk)
    active = {pid: flag for pid, flag in db.query(column, model.is_active).filter(column.in_({r[0] for r in wanted}))}
    for entity_id, label, must_be_active in wanted:
        if entity_id not in active or (must_be_active and not active[entity_id]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{label} رقم {entity_id} غير موجود أو غير نشط.",
            )
