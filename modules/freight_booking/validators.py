from datetime import datetime, date
from typing import Optional, Any, Set, List
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from modules.freight_booking.model import ShipmentBooking

# Booking status labels (legacy labels, validated as a whitelist; T3 codes are deferred).
STATUS_DRAFT = "Draft"
STATUS_REQUESTED = "Booking Requested"
STATUS_CONFIRMED = "Confirmed"
STATUS_AMENDED = "Amended"
STATUS_CANCELLED = "Cancelled"
STATUS_SAILED = "Sailed"

BOOKING_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_CONFIRMED, STATUS_AMENDED, STATUS_CANCELLED, STATUS_SAILED})
# Statuses a user may set by hand on create / PUT. Confirmed and Sailed only come from /confirm and /depart.
MANUAL_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_AMENDED, STATUS_CANCELLED})
CONFIRMABLE_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_AMENDED, STATUS_CONFIRMED})
DEPARTABLE_STATUSES = frozenset({STATUS_CONFIRMED, STATUS_AMENDED})
COMMITTED_STATUSES = frozenset({STATUS_CONFIRMED, STATUS_AMENDED, STATUS_SAILED})

LOCKED_AFTER_CONFIRM = frozenset({"bill_of_lading_no", "atd", "import_file_id"})
SAILED_EDITABLE = frozenset({"notes", "eta", "vessel_name", "voyage_number", "status"})

BOOKING_LABEL_AR = "حجز الشحن"


def _items_match(o: Any, n: Any) -> bool:
    o_dict = o.model_dump() if hasattr(o, "model_dump") else (o if isinstance(o, dict) else None)
    n_dict = n.model_dump() if hasattr(n, "model_dump") else (n if isinstance(n, dict) else None)
    if o_dict is not None and n_dict is not None:
        for k in set(o_dict.keys()) | set(n_dict.keys()):
            ov = o_dict.get(k)
            nv = n_dict.get(k)
            if nv is None and k in ("fx_rate_to_usd", "amount_usd", "charge_category"):
                continue
            if ov is None and nv is None:
                continue
            if isinstance(ov, (int, float)) and isinstance(nv, (int, float)):
                if abs(float(ov) - float(nv)) > 1e-4:
                    return False
            elif ov != nv:
                return False
        return True
    return o == n


def _is_value_unchanged(old_val: Any, new_val: Any) -> bool:
    if old_val == new_val:
        return True
    if old_val is None and new_val is None:
        return True
    if (old_val is None or old_val == "") and (new_val is None or new_val == ""):
        return True
    if isinstance(old_val, datetime) and isinstance(new_val, datetime):
        o = old_val.replace(tzinfo=None) if old_val.tzinfo else old_val
        n = new_val.replace(tzinfo=None) if new_val.tzinfo else new_val
        return o == n
    if isinstance(old_val, (date, datetime)) and isinstance(new_val, (date, datetime)):
        o_date = old_val.date() if isinstance(old_val, datetime) else old_val
        n_date = new_val.date() if isinstance(new_val, datetime) else new_val
        if o_date == n_date:
            return True
    if isinstance(old_val, (int, float)) and isinstance(new_val, (int, float)):
        return abs(float(old_val) - float(new_val)) < 1e-6
    if isinstance(old_val, list) or isinstance(new_val, list):
        o_list = old_val or []
        n_list = new_val or []
        if len(o_list) != len(n_list):
            return False
        return all(_items_match(o, n) for o, n in zip(o_list, n_list))
    if isinstance(old_val, dict) or isinstance(new_val, dict):
        return (old_val or {}) == (new_val or {})
    return False


def validate_editable_fields(
    booking: ShipmentBooking,
    sent_keys: Any,
    payload: Optional[Any] = None,
) -> None:
    if booking.status == STATUS_CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تعديل حجز الشحن {booking.booking_code} وهو في حالة ملغاة (Cancelled).",
        )

    actual_payload: Optional[Any] = None
    if isinstance(sent_keys, (set, frozenset, list, tuple)):
        keys = set(sent_keys)
        actual_payload = payload
    elif hasattr(sent_keys, "model_fields_set"):
        keys = set(sent_keys.model_fields_set)
        actual_payload = sent_keys
    elif isinstance(sent_keys, dict):
        keys = set(sent_keys.keys())
        actual_payload = sent_keys
    else:
        keys = set()
        actual_payload = payload

    modified_keys: set[str] = set()
    for k in keys:
        if actual_payload is not None:
            if isinstance(actual_payload, dict):
                new_val = actual_payload.get(k)
            else:
                new_val = getattr(actual_payload, k, None)
            old_val = getattr(booking, k, None)
            if _is_value_unchanged(old_val, new_val):
                continue
        modified_keys.add(k)

    if not modified_keys:
        return

    if booking.status == STATUS_SAILED:
        disallowed = modified_keys - SAILED_EDITABLE
        if disallowed:
            first_key = sorted(disallowed)[0]
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"لا يمكن تعديل الحقل '{first_key}' لحجز الشحن {booking.booking_code} بعد الإبحار (Sailed).",
            )
    elif booking.status in COMMITTED_STATUSES:
        disallowed = modified_keys & LOCKED_AFTER_CONFIRM
        if disallowed:
            first_key = sorted(disallowed)[0]
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"لا يمكن تعديل الحقل '{first_key}' لحجز الشحن {booking.booking_code} بعد تأكيد الحجز ({booking.status}).",
            )



def validate_booking_dates(etd: datetime, eta: datetime):
    if etd and eta:
        etd_comp = etd.replace(tzinfo=None) if hasattr(etd, "tzinfo") and etd.tzinfo else etd
        eta_comp = eta.replace(tzinfo=None) if hasattr(eta, "tzinfo") and eta.tzinfo else eta
        if eta_comp < etd_comp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="تاريخ الوصول المتوقع (ETA) لا يمكن أن يكون قبل تاريخ الإبحار المتوقع (ETD).",
            )


def validate_container_allocation(shipment_type: str, containers_data: list):
    if shipment_type == "Ocean FCL" and not containers_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="شحنات الحاويات الكاملة (Ocean FCL) تتطلب تخصيص حاوية واحدة على الأقل.",
        )


def validate_manual_status(new_status: Optional[str], current_status: Optional[str] = None) -> None:
    """A status sent on create / PUT: unchanged values pass (the screen re-sends the status on every save);
    otherwise only the manual statuses are accepted, Confirmed / Sailed need their dedicated endpoints."""
    if new_status is None or new_status == current_status:
        return
    if new_status not in MANUAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تغيير حالة الحجز يدويًا إلى {new_status}",
        )
    # A confirmed / amended / sailed booking never goes back to Draft or Booking Requested: it can only be
    # cancelled, or amended from Confirmed.
    if current_status in COMMITTED_STATUSES and not (
        new_status == STATUS_CANCELLED or (new_status == STATUS_AMENDED and current_status == STATUS_CONFIRMED)
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تغيير حالة الحجز من {current_status} إلى {new_status}",
        )


def validate_deletable(booking: ShipmentBooking) -> None:
    if booking.status in COMMITTED_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن حذف حجز الشحن {booking.booking_code} وهو في حالة {booking.status}. يمكن إلغاؤه بدلاً من الحذف.",
        )


def validate_can_confirm(booking: ShipmentBooking) -> None:
    if booking.status not in CONFIRMABLE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تأكيد حجز الشحن {booking.booking_code} وهو في حالة {booking.status}.",
        )


def validate_can_depart(booking: ShipmentBooking) -> None:
    if booking.status not in DEPARTABLE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تسجيل إبحار حجز الشحن {booking.booking_code} قبل تأكيده (الحالة الحالية: {booking.status}).",
        )


def validate_no_duplicate_booking_for_file(
    db: Session, import_file_id: Optional[int], current_booking_id: Optional[int] = None
):
    if not import_file_id:
        return
    query = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True,
    )
    if current_booking_id:
        query = query.filter(ShipmentBooking.booking_id != current_booking_id)
    existing = query.first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"يوجد بالفعل حجز شحن مسجل لهذا الملف الاستيرادي (كود الحجز: {existing.booking_code}). يرجى الذهاب لتعديل الحجز الحالي بدلاً من إنشاء حجز جديد.",
        )


def validate_charge_currencies(db: Session, charges: list) -> None:
    if not charges:
        return
    from modules.currencies.repository import CurrencyRepository

    repo = CurrencyRepository(db)
    for c in charges:
        c_dict = c if isinstance(c, dict) else (c.model_dump() if hasattr(c, "model_dump") else getattr(c, "__dict__", {}))
        raw_cur = c_dict.get("currency")
        ccy = str(raw_cur or "USD").strip().upper()
        curr_obj = repo.get_currency_by_code(ccy)
        if not curr_obj or not getattr(curr_obj, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"عملة البند غير معروفة: {ccy}",
            )


CHARGE_CATEGORIES = (
    "FREIGHT",
    "ORIGIN_LOCAL",
    "DESTINATION_LOCAL",
    "INSURANCE",
    "STORAGE",
    "OTHER",
)


def infer_charge_category(charge_type: Optional[str]) -> str:
    """Infer the category code for legacy charge rows or free-text charge types."""
    if not charge_type:
        return "OTHER"
    ct = str(charge_type).strip().lower()
    if "insurance" in ct or "تأمين" in ct:
        return "INSURANCE"
    if "storage" in ct or "أرضيات" in ct or "تخزين" in ct:
        return "STORAGE"
    if "dthc" in ct or "thc" in ct:
        return "DESTINATION_LOCAL"
    if "freight" in ct or "نولون" in ct:
        return "FREIGHT"
    return "OTHER"


def validate_charges(charges: list) -> None:
    """Validate booking charge lines.
    Rejects any charge with category INSURANCE (or charge_type indicating insurance);
    insurance must be managed in the cargo insurance module to avoid double counting.
    """
    if not charges:
        return
    for c in charges:
        c_dict = c if isinstance(c, dict) else (c.model_dump() if hasattr(c, "model_dump") else getattr(c, "__dict__", {}))
        cat = c_dict.get("charge_category")
        c_type = c_dict.get("charge_type", "")
        if cat:
            cat_upper = str(cat).strip().upper()
            if cat_upper not in CHARGE_CATEGORIES:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"فئة التكلفة غير صحيحة: {cat}. الفئات المسموحة: {', '.join(CHARGE_CATEGORIES)}",
                )
            resolved_cat = cat_upper
        else:
            resolved_cat = infer_charge_category(c_type)

        if resolved_cat == "INSURANCE" or infer_charge_category(c_type) == "INSURANCE":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="التأمين البحري يُسجل في شاشة وثائق التأمين وليس ضمن تكاليف الحجز.",
            )


ALLOWED_SHIPMENT_TYPES = frozenset({"Ocean FCL", "Ocean LCL", "Air"})
ALLOWED_FREIGHT_TERMS = frozenset({"Prepaid", "Collect"})


def validate_master_refs(db: Session, payload: Any) -> None:
    """Validate master data foreign keys on create/update and auto-fill names.
    - freight_forwarder_id -> external_service_providers (must be active)
    - shipping_line_id -> external_service_providers (must be active)
    - pol_location_id -> transport_locations (must be active)
    - pod_location_id -> transport_locations (must be active)
    - rfq_request_id -> freight_rfq_requests (must be active)
    - shipment_type -> Ocean FCL, Ocean LCL, Air
    - freight_terms -> Prepaid, Collect
    Unknown or inactive IDs give HTTP 422.
    When an ID is provided and the corresponding name is missing/empty, sets the name from the master row.
    """
    from modules.external_service_providers.model import ExternalServiceProvider
    from modules.transport_locations.model import TransportLocation
    from modules.freight_quotations.model import FreightRFQRequest

    is_dict = isinstance(payload, dict)

    def _get(k: str) -> Any:
        return payload.get(k) if is_dict else getattr(payload, k, None)

    def _set(k: str, v: Any) -> None:
        if is_dict:
            payload[k] = v
        else:
            if hasattr(payload, k):
                setattr(payload, k, v)
                if hasattr(payload, "model_fields_set"):
                    payload.model_fields_set.add(k)

    # Validate shipment_type if provided
    shipment_type = _get("shipment_type")
    if shipment_type is not None and shipment_type not in ALLOWED_SHIPMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"نوع الشحنة غير صالح: {shipment_type}. القيم المسموحة: {', '.join(sorted(ALLOWED_SHIPMENT_TYPES))}",
        )

    # Validate freight_terms if provided
    freight_terms = _get("freight_terms")
    if freight_terms is not None and freight_terms not in ALLOWED_FREIGHT_TERMS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"شروط النولون غير صالحة: {freight_terms}. القيم المسموحة: {', '.join(sorted(ALLOWED_FREIGHT_TERMS))}",
        )

    # 1. Freight Forwarder
    ff_id = _get("freight_forwarder_id")
    if ff_id is not None:
        provider = db.query(ExternalServiceProvider).filter(
            ExternalServiceProvider.provider_id == ff_id
        ).first()
        if not provider or not getattr(provider, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"شركة الشحن / وكيل الشحن غير موجود أو غير مفعل (المعرف: {ff_id})",
            )
        ff_name = _get("freight_forwarder_name")
        if not ff_name:
            _set("freight_forwarder_name", provider.partner_name)

    # 2. Shipping Line
    sl_id = _get("shipping_line_id")
    if sl_id is not None:
        carrier = db.query(ExternalServiceProvider).filter(
            ExternalServiceProvider.provider_id == sl_id
        ).first()
        if not carrier or not getattr(carrier, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"الخط الملاحي غير موجود أو غير مفعل (المعرف: {sl_id})",
            )
        sl_name = _get("shipping_line_name")
        if not sl_name:
            _set("shipping_line_name", carrier.partner_name)

    # 3. Port of Loading (POL)
    pol_id = _get("pol_location_id")
    if pol_id is not None:
        pol = db.query(TransportLocation).filter(
            TransportLocation.location_id == pol_id
        ).first()
        if not pol or not getattr(pol, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"ميناء الشحن (POL) غير موجود أو غير مفعل (المعرف: {pol_id})",
            )
        pol_name = _get("pol_name")
        if not pol_name:
            _set("pol_name", pol.location_name)

    # 4. Port of Discharge (POD)
    pod_id = _get("pod_location_id")
    if pod_id is not None:
        pod = db.query(TransportLocation).filter(
            TransportLocation.location_id == pod_id
        ).first()
        if not pod or not getattr(pod, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"ميناء الوصول (POD) غير موجود أو غير مفعل (المعرف: {pod_id})",
            )
        pod_name = _get("pod_name")
        if not pod_name:
            _set("pod_name", pod.location_name)

    # 5. RFQ Request
    rfq_id = _get("rfq_request_id")
    if rfq_id is not None:
        rfq = db.query(FreightRFQRequest).filter(
            FreightRFQRequest.rfq_id == rfq_id
        ).first()
        if not rfq or not getattr(rfq, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"طلب تسعير الشحن (RFQ) غير موجود أو غير مفعل (المعرف: {rfq_id})",
            )



