"""
Service layer for System Parameters Settings API (BEX-T17).
"""
import json
import logging
import math
from typing import Any, Dict, List, Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session

from modules.audit_logs.service import AuditLogService
from modules.common.system_parameters import (
    AIR_VOLUMETRIC_KG_PER_CBM,
    SystemParameter,
)
from .schemas import SystemParameterResponse, SystemParameterUpdate

logger = logging.getLogger(__name__)


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={
            "code": code,
            "message": message_ar,
            **params,
        },
    )


def validate_parameter_value(key: str, raw_value: str) -> str:
    """
    Validates parameter value according to its key.
    Raises HTTPException(422, SYSPARAM_INVALID_VALUE) on failure.
    Returns cleaned/normalized string value.
    """
    val = raw_value.strip() if raw_value else ""
    if not val:
        raise coded_error(
            422,
            "SYSPARAM_INVALID_VALUE",
            f"قيمة معلمة النظام '{key}' لا يمكن أن تكون فارغة.",
            param_key=key,
            reason="Value cannot be empty",
        )

    # 1. Tiers validation: JSON list of contiguous tiers
    if key.endswith("_TIERS"):
        try:
            tiers = json.loads(val)
        except Exception:
            raise coded_error(
                422,
                "SYSPARAM_INVALID_VALUE",
                f"فشل قراءة طبقات الرسوم '{key}' كـ JSON صالح.",
                param_key=key,
                reason="Invalid JSON format",
            )
        if not isinstance(tiers, list) or len(tiers) == 0:
            raise coded_error(
                422,
                "SYSPARAM_INVALID_VALUE",
                f"يجب أن تكون طبقات الرسوم '{key}' مصفوفة غير فارغة.",
                param_key=key,
                reason="Tiers must be a non-empty list",
            )

        expected_start = 1
        for idx, tier in enumerate(tiers):
            if not isinstance(tier, dict):
                raise coded_error(
                    422,
                    "SYSPARAM_INVALID_VALUE",
                    f"الطبقة رقم {idx + 1} ليست كائناً صالحاً.",
                    param_key=key,
                    reason=f"Tier at index {idx} must be a dictionary",
                )
            from_day = tier.get("from_day")
            to_day = tier.get("to_day")
            rate = tier.get("rate_per_day")

            if not isinstance(from_day, int) or from_day < 1:
                raise coded_error(
                    422,
                    "SYSPARAM_INVALID_VALUE",
                    f"حقل from_day في الطبقة {idx + 1} يجب أن يكون عدداً صحيحاً >= 1.",
                    param_key=key,
                    reason=f"from_day in tier {idx + 1} must be an integer >= 1",
                )

            if from_day != expected_start:
                raise coded_error(
                    422,
                    "SYSPARAM_INVALID_VALUE",
                    f"الأيام غير متصلة: الطبقة {idx + 1} تبدأ من {from_day} بينما المتوقع {expected_start}.",
                    param_key=key,
                    reason=f"Days are not contiguous: expected from_day {expected_start}, got {from_day}",
                )

            if not isinstance(rate, (int, float)) or rate < 0:
                raise coded_error(
                    422,
                    "SYSPARAM_INVALID_VALUE",
                    f"معدل الرسوم في الطبقة {idx + 1} يجب أن يكون رقماً >= 0.",
                    param_key=key,
                    reason=f"rate_per_day in tier {idx + 1} must be >= 0",
                )

            if to_day is not None:
                if not isinstance(to_day, int) or to_day < from_day:
                    raise coded_error(
                        422,
                        "SYSPARAM_INVALID_VALUE",
                        f"حقل to_day في الطبقة {idx + 1} يجب أن يكون >= from_day.",
                        param_key=key,
                        reason=f"to_day in tier {idx + 1} must be >= from_day",
                    )
                expected_start = to_day + 1
            else:
                if idx != len(tiers) - 1:
                    raise coded_error(
                        422,
                        "SYSPARAM_INVALID_VALUE",
                        "فقط الطبقة الأخيرة يمكن أن تكون مفتوحة (to_day = null).",
                        param_key=key,
                        reason="Only the last tier can have to_day as null",
                    )
        return val

    # 2. Currency validation
    if key == "DD_DEFAULT_TARIFF_CURRENCY":
        clean_curr = val.upper()
        if len(clean_curr) != 3 or not clean_curr.isalpha():
            raise coded_error(
                422,
                "SYSPARAM_INVALID_VALUE",
                f"رمز العملة '{val}' غير صالح؛ يجب أن يتكون من 3 أحرف.",
                param_key=key,
                reason="Currency must be a 3-letter alphabetic code",
            )
        return clean_curr

    # 3. Numeric float validation
    try:
        num = float(val)
    except ValueError:
        raise coded_error(
            422,
            "SYSPARAM_INVALID_VALUE",
            f"قيمة معلمة النظام '{key}' يجب أن تكون رقماً صالحاً.",
            param_key=key,
            reason="Value must be a valid number",
        )
    if not math.isfinite(num):
        raise coded_error(
            422,
            "SYSPARAM_INVALID_VALUE",
            f"قيمة معلمة النظام '{key}' غير صالحة (NaN أو ما لا نهاية).",
            param_key=key,
            reason="Value must be a finite number",
        )

    # Air volumetric factor must be > 0
    if key == AIR_VOLUMETRIC_KG_PER_CBM:
        if num <= 0:
            raise coded_error(
                422,
                "SYSPARAM_INVALID_VALUE",
                f"معامل الحجم الجوي '{key}' يجب أن يكون أكبر من الصفر.",
                param_key=key,
                reason="Value must be greater than 0",
            )
        return val

    # Rate / percentage bounded in [0, 1]
    if key.startswith("INSURANCE_RATE_") or key in ("INSURANCE_MARKUP", "INSURANCE_TAX_RATE", "INSURANCE_WAR_STRIKES_RATE"):
        if num < 0 or num > 1:
            raise coded_error(
                422,
                "SYSPARAM_INVALID_VALUE",
                f"معدل التأمين '{key}' يجب أن يكون بين 0 و 1 (القيمة الحالية: {num}).",
                param_key=key,
                reason=f"Rate must be between 0 and 1, got {num}",
            )
        return val

    # Non-negative numbers for fees, days, deemed percents, defaults
    if num < 0:
        raise coded_error(
            422,
            "SYSPARAM_INVALID_VALUE",
            f"قيمة معلمة النظام '{key}' يجب أن تكون أكبر من أو تساوي الصفر.",
            param_key=key,
            reason="Value must be greater than or equal to 0",
        )

    return val


class SystemParametersService:
    def __init__(self, db: Session):
        self.db = db

    def get_all_parameters(self) -> List[SystemParameter]:
        return (
            self.db.query(SystemParameter)
            .order_by(SystemParameter.param_key.asc())
            .all()
        )

    def get_parameter_by_key(self, key: str) -> SystemParameter:
        param = (
            self.db.query(SystemParameter)
            .filter(SystemParameter.param_key == key)
            .first()
        )
        if not param:
            raise coded_error(
                404,
                "SYSPARAM_UNKNOWN",
                f"معلمة النظام '{key}' غير موجودة.",
                param_key=key,
            )
        return param

    def update_parameter(
        self,
        key: str,
        payload: SystemParameterUpdate,
        actor_username: str,
    ) -> SystemParameter:
        param = self.get_parameter_by_key(key)
        validated_value = validate_parameter_value(key, payload.param_value)

        old_val = param.param_value
        param.param_value = validated_value
        param.updated_by = actor_username

        AuditLogService(self.db).log_activity(
            entity_type="SystemParameter",
            entity_id=param.param_id,
            entity_code=param.param_key,
            action="UPDATE",
            performed_by=actor_username,
            old_data={"param_value": old_val},
            new_data={"param_value": validated_value},
            changes_summary=payload.justification,
        )

        self.db.commit()
        self.db.refresh(param)
        return param
