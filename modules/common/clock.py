"""
modules/common/clock.py
Cairo business-date helpers.

Copy of ``modules/financial_settlement/service.py`` ``cairo_today`` / ``cairo_date`` (that module keeps its own
copy until its owner switches to this one). Business dates (transit days, SLA ages, due dates) are counted in
Cairo, not UTC: after 22:00 UTC (00:00 Cairo) the UTC date is one day behind.
"""
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

logger = logging.getLogger(__name__)

_CAIRO_FALLBACK_TZ = timezone(timedelta(hours=2), "EET")


def _cairo_tz():
    try:
        return ZoneInfo("Africa/Cairo")
    except ZoneInfoNotFoundError:  # tzdata missing (frozen build): standard time, no DST
        logger.warning("Africa/Cairo time zone data unavailable; using a fixed UTC+2 offset")
        return _CAIRO_FALLBACK_TZ


def cairo_date(value: Optional[datetime]) -> Optional[date]:
    """Business date in Cairo of a stored timestamp. Naive values are stored UTC."""
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(_cairo_tz()).date()


def cairo_today() -> date:
    """Today's business date in Cairo."""
    return datetime.now(timezone.utc).astimezone(_cairo_tz()).date()
