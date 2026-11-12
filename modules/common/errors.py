"""
modules/common/errors.py
Shared failure handling for services: coded HTTP errors and best-effort follow-up steps.
"""
import logging
from typing import Any, Callable, Optional, TypeVar

from fastapi import HTTPException
from sqlalchemy.orm import Session

from modules.common.system_messages import msg

logger = logging.getLogger(__name__)

T = TypeVar("T")


class CodedHTTPException(HTTPException):
    """HTTP error with a system-message code the client can render (shape of ``ConcurrencyConflictException``).

    ``detail = {"code": code, "message": message_ar, **params}``: the Arabic message keeps old clients working,
    ``code`` + params (validated through ``system_messages.msg``: known code, JSON-primitive values) are the
    language-neutral contract. Params may carry extra context fields that the template does not use."""

    def __init__(self, status_code: int, code: str, message_ar: str, **params: Any):
        m = msg(code, **params)
        self.code = m.code
        self.params = m.params
        super().__init__(status_code=status_code, detail={"code": m.code, "message": message_ar, **m.params})


def best_effort(db: Session, fn: Callable[..., T], label: str, *args: Any, **kwargs: Any) -> Optional[T]:
    """Run a follow-up step that must never undo the caller's saved work: on any failure the session is rolled
    back, the error is logged with ``label`` and ``None`` is returned."""
    try:
        return fn(*args, **kwargs)
    except Exception as exc:
        db.rollback()
        if _is_payment_gate_block(exc):
            # A payment-pathway milestone gate kept the file in place: surface it (next action + notification)
            # instead of only logging it.
            logger.info("%s held by payment pathway gate: %s", label, getattr(exc, "detail", exc))
            _record_payment_gate_hold(db, exc)
        else:
            logger.exception("%s failed", label)
        return None


def _is_payment_gate_block(exc: BaseException) -> bool:
    detail = getattr(exc, "detail", None)
    return isinstance(detail, dict) and detail.get("code") == "PAYMENT_MILESTONE_GATE_BLOCKED"


def _record_payment_gate_hold(db: Session, exc: BaseException) -> None:
    try:
        from modules.import_files.import_file_payment_pathway_service import record_payment_gate_hold

        record_payment_gate_hold(db, exc)
    except Exception:
        db.rollback()
        logger.exception("Recording the payment pathway hold failed")
