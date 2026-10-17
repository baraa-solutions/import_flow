from datetime import date
from typing import List, Optional
from fastapi import HTTPException, status
from .schemas import TierRateItem


def validate_tier_rates(tiers: List[TierRateItem], tier_name: str = "Tiers") -> None:
    """Validates that tier rates are positive and sequentially structured."""
    if not tiers:
        return

    def fail(detail: str) -> HTTPException:
        return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=f"{tier_name}: {detail}")

    sorted_tiers = sorted(tiers, key=lambda t: t.from_day)
    if sorted_tiers[0].from_day != 1:
        raise fail("يجب أن تبدأ الشريحة الأولى من اليوم 1.")

    for i, t in enumerate(sorted_tiers):
        if t.rate_per_day < 0:
            raise fail("قيمة الغرامة اليومية لا يمكن أن تكون سالبة.")
        if t.to_day is not None and t.to_day < t.from_day:
            raise fail(f"نهاية الشريحة ({t.to_day}) يجب أن تكون أكبر من أو تساوي بدايتها ({t.from_day}).")
        is_last = i == len(sorted_tiers) - 1
        if t.to_day is None and not is_last:
            raise fail("الشريحة المفتوحة (بدون نهاية) يجب أن تكون الأخيرة فقط.")
        if not is_last and sorted_tiers[i + 1].from_day != t.to_day + 1:
            raise fail(
                f"الشرائح يجب أن تكون متصلة بدون فجوات أو تداخل: الشريحة التالية يجب أن تبدأ من اليوم {t.to_day + 1} "
                f"وليس {sorted_tiers[i + 1].from_day}."
            )


def validate_demurrage_dates(
    discharge_date: date,
    gate_out_date: Optional[date] = None,
    empty_return_date: Optional[date] = None,
    today: Optional[date] = None,
) -> None:
    """Validates chronological order of container operational milestones."""
    if today:
        if gate_out_date and gate_out_date > today:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ خروج الحاوية من الميناء (Gate-Out) لا يمكن أن يكون في المستقبل.",
            )
        if empty_return_date and empty_return_date > today:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ إعادة الحاوية الفارغة لا يمكن أن يكون في المستقبل.",
            )

    if gate_out_date and gate_out_date < discharge_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ خروج الحاوية من الميناء (Gate-Out) لا يمكن أن يكون قبل تاريخ تفريغها من السفينة (Discharge Date).",
        )

    if empty_return_date:
        if gate_out_date and empty_return_date < gate_out_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ إعادة الحاوية الفارغة لا يمكن أن يكون قبل تاريخ خروجها من الميناء.",
            )
        elif not gate_out_date and empty_return_date < discharge_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ إعادة الحاوية الفارغة لا يمكن أن يكون قبل تاريخ تفريغها.",
            )


def validate_positive_amount(val: float, field_name: str) -> None:
    if val <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"الحقل {field_name} يجب أن يكون أكبر من صفر.",
        )
