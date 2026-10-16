from typing import Any, Dict
from fastapi import HTTPException, status
from modules.cargo_insurance.schemas import CargoInsuranceCertificateCreate, CargoInsuranceCertificateUpdate

VALID_CLAUSES = ("ICC_A", "AIR_ALL_RISKS", "ICC_B", "ICC_C")
VALID_MODES = ("OCEAN", "AIR", "ROAD")
VALID_POLICY_TYPES = ("SPECIFIC", "OPEN_DECLARATION")
# Certificates in these statuses are final: no edit, no premium recalculation.
LOCKED_STATUSES = ("ISSUED", "CANCELLED")

CERTIFICATE_LABEL_AR = "وثيقة تأمين البضائع"
# Premium parameters stored on a certificate: null on update = back to the system-parameter value.
RESETTABLE_RATE_FIELDS = ("markup_percentage", "minimum_premium", "issuance_fee", "tax_rate")


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def validate_coverage_clause(clause: Any) -> None:
    if clause not in VALID_CLAUSES:
        raise _bad_request(f"بند التغطية غير معروف: {clause}. البنود المتاحة: {', '.join(VALID_CLAUSES)}")


def validate_transport_mode(mode: Any) -> None:
    if mode not in VALID_MODES:
        raise _bad_request(f"وسيلة النقل غير معروفة: {mode}. الوسائل المتاحة: {', '.join(VALID_MODES)}")


def validate_policy_type(policy_type: Any) -> None:
    if policy_type not in VALID_POLICY_TYPES:
        raise _bad_request(f"نوع الوثيقة غير معروف: {policy_type}. الأنواع المتاحة: {', '.join(VALID_POLICY_TYPES)}")


def validate_cargo_insurance_create(data: CargoInsuranceCertificateCreate) -> None:
    if data.invoice_value < 0:
        raise _bad_request("قيمة الفاتورة لا يمكن أن تكون سالبة.")
    if data.freight_cost < 0:
        raise _bad_request("تكلفة الشحن لا يمكن أن تكون سالبة.")
    if not data.insured_entity_name or not data.insured_entity_name.strip():
        raise _bad_request("اسم المؤمَّن له (المستورد / المرسل إليه) مطلوب.")
    if not data.port_of_loading or not data.port_of_loading.strip():
        raise _bad_request("ميناء الشحن مطلوب.")
    if not data.port_of_discharge or not data.port_of_discharge.strip():
        raise _bad_request("ميناء التفريغ مطلوب.")
    validate_coverage_clause(data.coverage_clause)
    validate_transport_mode(data.transport_mode)
    validate_policy_type(data.policy_type)


def validate_cargo_insurance_update(data: CargoInsuranceCertificateUpdate, required_fields: frozenset) -> Dict[str, Any]:
    """Returns the fields to apply. ``status`` is ignored (only /issue changes it). An explicit null on a
    required column is rejected; the enum fields get the same checks as on create."""
    update_dict = data.model_dump(exclude_unset=True)
    update_dict.pop("status", None)

    # an explicit null on a premium parameter means "use the configured value" (the service resets it)
    cleared = sorted(k for k, v in update_dict.items() if v is None and k in required_fields and k not in RESETTABLE_RATE_FIELDS)
    if cleared:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"لا يمكن مسح الحقول الإلزامية: {', '.join(cleared)}",
        )
    for field in ("invoice_value", "freight_cost", "other_logistics_costs", "minimum_premium", "issuance_fee", "tax_rate"):
        if update_dict.get(field) is not None and update_dict[field] < 0:
            raise _bad_request(f"الحقل {field} لا يمكن أن يكون سالبًا.")
    if update_dict.get("markup_percentage") is not None and not 0 <= update_dict["markup_percentage"] <= 1:
        raise _bad_request("نسبة الزيادة على قيمة CIF يجب أن تكون بين 0 و 1.")
    for field in ("insured_entity_name", "port_of_loading", "port_of_discharge"):
        if field in update_dict and not str(update_dict[field]).strip():
            raise _bad_request(f"الحقل {field} لا يمكن أن يكون فارغًا.")
    if "coverage_clause" in update_dict:
        validate_coverage_clause(update_dict["coverage_clause"])
    if "transport_mode" in update_dict:
        validate_transport_mode(update_dict["transport_mode"])
    if "policy_type" in update_dict:
        validate_policy_type(update_dict["policy_type"])
    return update_dict


def validate_certificate_editable(cert_status: str, certificate_code: str) -> None:
    if cert_status in LOCKED_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تعديل وثيقة التأمين {certificate_code} لأنها في حالة {cert_status}.",
        )


def validate_certificate_deletable(cert_status: str, certificate_code: str) -> None:
    if cert_status == "ISSUED":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن حذف وثيقة التأمين {certificate_code} بعد إصدارها.",
        )


def validate_no_active_certificate_for_file(existing: Optional[Any]) -> None:
    if existing:
        code = getattr(existing, "certificate_code", None) or getattr(existing, "certificate_id", "")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"يوجد بالفعل وثيقة تأمين نشطة لهذا الملف ({code})",
        )
