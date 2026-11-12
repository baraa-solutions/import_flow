"""
Payment Pathway Milestone Gates — service layer.

- ``enforce_payment_pathway_gate``: called by every lifecycle transition (step advance on the lifecycle
  board, board-phase milestone progression) before the file moves forward. Blocks with 409
  ``PAYMENT_MILESTONE_GATE_BLOCKED`` when a crossed gate of the file's pathway has missing milestones.
- ``get_payment_pathway_status_service``: completed / pending milestones and gates of one file for the
  Flutter ``PaymentPathwayGuard``.

The rules themselves live in ``modules/import_files/payment_milestones.py`` (data-driven tables).
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.import_files import payment_milestones as pm
from modules.import_files import repository as repo
from modules.import_files import validators


def _lifecycle_catalog():
    # Lazy import: lifecycle_board imports half the application.
    from modules.lifecycle_board.lifecycle_kanban_service import (
        ORDERED_STEP_CODES,
        PHASES_DEFINITION,
        STEP_NAME_MAP,
        STEP_TO_PHASE_MAP,
    )

    return ORDERED_STEP_CODES, STEP_TO_PHASE_MAP, STEP_NAME_MAP, PHASES_DEFINITION


def gate_labels() -> Dict[str, Tuple[str, str]]:
    """gate point -> (English label, Arabic label)."""
    ordered, _, names, phases = _lifecycle_catalog()
    labels: Dict[str, Tuple[str, str]] = {
        f"PHASE_{p['phase_id']}": (f"Phase {p['phase_id']}: {p['title_en'].split('. ', 1)[-1]}", p["title_ar"])
        for p in phases
    }
    for code in ordered:
        en, ar = names.get(code, (code, code))
        labels[code] = (f"{code} {en}", f"{code} {ar}")
    labels[pm.GATE_CLOSURE] = ("Final file closure", "الإغلاق النهائي للملف")
    return labels


def _position(file_rec: Any) -> Tuple[Optional[str], Optional[int]]:
    return getattr(file_rec, "current_step_code", None), getattr(file_rec, "current_phase_id", None)


def find_payment_gate_block(
    db: Session,
    file_rec: Any,
    *,
    to_step: Optional[str] = None,
    to_phase: Optional[int] = None,
    closing: bool = False,
) -> List[Tuple[str, List[str]]]:
    """``[(gate, [missing milestones]), ...]`` crossed by moving ``file_rec`` to ``to_step`` / ``to_phase`` (or
    closing it); empty when the move is allowed. No pathway (GP-001) or unsaved file → no gates."""
    if file_rec is None or getattr(file_rec, "import_file_id", None) is None:
        return []
    payment_term = getattr(file_rec, "payment_term", None)
    if not payment_term or payment_term not in pm.PATHWAY_GATES:
        return []
    ordered, step_to_phase, _, _ = _lifecycle_catalog()
    from_step, from_phase = _position(file_rec)
    gates = pm.gates_crossed(
        from_step,
        from_phase,
        to_step,
        to_phase=to_phase,
        ordered_steps=ordered,
        step_to_phase=step_to_phase,
        closing=closing,
        skipped_steps=getattr(file_rec, "skipped_stages", None) or (),
    )
    configured = pm.PATHWAY_GATES[payment_term]
    if not any(g in configured for g in gates):
        return []
    with db.no_autoflush:
        evidence = repo.get_financing_evidence(db, file_rec.import_file_id)
    return pm.blocking_milestones(payment_term, gates, evidence)


def enforce_payment_pathway_gate(
    db: Session,
    file_rec: Any,
    *,
    to_step: Optional[str] = None,
    to_phase: Optional[int] = None,
    closing: bool = False,
) -> None:
    """Raise 409 ``PAYMENT_MILESTONE_GATE_BLOCKED`` when the move crosses an unsatisfied gate."""
    blocked = find_payment_gate_block(db, file_rec, to_step=to_step, to_phase=to_phase, closing=closing)
    if blocked:
        validators.validate_payment_pathway_gate(
            file_rec.import_file_code, file_rec.payment_term, blocked, gate_labels(),
            import_file_id=file_rec.import_file_id,
        )


def hold_file_on_payment_gate(db: Session, file_rec: Any, blocked: List[Tuple[str, List[str]]]) -> None:
    """Keep the file where it is and surface why: next action = complete the pending banking milestones, plus
    a SystemNotification. Never commits (the caller owns the transaction)."""
    from modules.common.file_tracking import set_file_tracking
    from modules.common.system_messages import msg, render_en
    from modules.notifications.model import SystemNotification

    if not blocked or file_rec is None:
        return
    gate, missing = blocked[0]
    message = msg(
        "NA_PAYMENT_MILESTONE_PENDING",
        payment_term_enum_payment_term=file_rec.payment_term,
        gate=gate,
        missing_milestones=", ".join(missing),
    )
    set_file_tracking(file_rec, next_action=message)
    note = msg(
        "PAYMENT_MILESTONE_GATE_HOLD",
        import_file_code=file_rec.import_file_code,
        payment_term_enum_payment_term=file_rec.payment_term,
        gate=gate,
        missing_milestones=", ".join(missing),
    )
    db.add(SystemNotification(
        title=render_en(note.code, note.params, "title")[:200],
        message=render_en(note.code, note.params, "body"),
        msg_code=note.code,
        msg_params=note.params,
        category="STAGE_PROGRESSION",
        severity="WARNING",
        entity_type="ImportFile",
        entity_id=file_rec.import_file_id,
        target_role="ALL",
        is_read=False,
    ))


def advance_tracking_or_hold(
    db: Session,
    file_rec: Any,
    *,
    step_code: Optional[str] = None,
    phase_id: Optional[int] = None,
    next_action: Any = None,
    stage_code: Optional[str] = None,
) -> bool:
    """Automatic (system-driven) forward move: ``set_file_tracking`` when the payment pathway gates allow it,
    otherwise keep the file in place, record the hold (``hold_file_on_payment_gate``) and return ``False``.
    The business record that triggered the move is kept either way."""
    from modules.common.file_tracking import set_file_tracking

    blocked = find_payment_gate_block(db, file_rec, to_step=step_code, to_phase=phase_id)
    if blocked:
        hold_file_on_payment_gate(db, file_rec, blocked)
        return False
    set_file_tracking(
        file_rec, step_code=step_code, phase_id=phase_id, next_action=next_action, stage_code=stage_code,
        enforce_payment_gate=False,
    )
    return True


def record_payment_gate_hold(db: Session, exc: BaseException) -> None:
    """Surface a ``PAYMENT_MILESTONE_GATE_BLOCKED`` swallowed by a best-effort follow-up (after its rollback):
    hold next action + notification on the file, committed on their own."""
    detail = exc.detail  # type: ignore[attr-defined]
    file_id = detail.get("import_file_id")
    if not file_id:
        return
    file_rec = repo.get_import_file_by_id(db, int(file_id))
    blocked = [(b["gate"], list(b["missing_milestones"])) for b in detail.get("blocked_gates") or []]
    if file_rec is None or not blocked:
        return
    hold_file_on_payment_gate(db, file_rec, blocked)
    db.commit()


def _gate_passed(file_rec: Any, gate: str, ordered: List[str], step_to_phase: Dict[str, int]) -> bool:
    if gate == pm.GATE_CLOSURE:
        return (getattr(file_rec, "status", "") or "").strip().lower() == "closed"
    from_step, from_phase = _position(file_rec)
    if from_step in ordered:
        current_key = ordered.index(from_step) * 10 + 1
    elif from_phase:
        current_key = pm.gate_order_key(f"PHASE_{from_phase}", ordered, step_to_phase)
    else:
        current_key = -1
    return pm.gate_order_key(gate, ordered, step_to_phase) <= current_key


def build_payment_pathway_status(file_rec: Any, evidence: pm.FinancingEvidence) -> Dict[str, Any]:
    """Status payload of ``PaymentPathwayStatusResponse`` (pure: no DB access)."""
    payment_term = getattr(file_rec, "payment_term", None)
    ordered, step_to_phase, _, _ = _lifecycle_catalog()
    labels = gate_labels()
    done = set(pm.completed_milestones(payment_term, evidence))
    first_gate = pm.required_before(payment_term)

    milestones = []
    for m in pm.pathway_milestones(payment_term):
        gate = first_gate.get(m.code)
        gate_en, gate_ar = labels.get(gate, (gate, gate)) if gate else (None, None)
        milestones.append({
            "code": m.code,
            "label_en": m.label_en,
            "label_ar": m.label_ar,
            "evidence_en": m.evidence_en,
            "evidence_ar": m.evidence_ar,
            "is_completed": m.code in done,
            "required_before_gate": gate,
            "required_before_label_en": gate_en,
            "required_before_label_ar": gate_ar,
        })

    gates = []
    config = pm.PATHWAY_GATES.get(payment_term or "", {})
    for gate in sorted(config, key=lambda g: pm.gate_order_key(g, ordered, step_to_phase)):
        required = list(config[gate])
        missing = [c for c in required if c not in done]
        en, ar = labels.get(gate, (gate, gate))
        skipped = gate in (getattr(file_rec, "skipped_stages", None) or [])
        gates.append({
            "gate": gate,
            "label_en": en,
            "label_ar": ar,
            "required_milestones": required,
            "missing_milestones": missing,
            "is_satisfied": not missing or skipped,
            "is_passed": _gate_passed(file_rec, gate, ordered, step_to_phase),
            "is_waived": skipped,
        })

    next_blocking = next((g for g in gates if not g["is_passed"] and not g["is_satisfied"]), None)
    blocking_reasons_en: List[str] = []
    blocking_reasons_ar: List[str] = []
    if next_blocking:
        for code in next_blocking["missing_milestones"]:
            m = pm.MILESTONES[code]
            blocking_reasons_en.append(f"{m.label_en} — required before {next_blocking['label_en']}")
            blocking_reasons_ar.append(f"{m.label_ar} — مطلوب قبل {next_blocking['label_ar']}")

    return {
        "import_file_id": file_rec.import_file_id,
        "import_file_code": file_rec.import_file_code,
        "payment_term": payment_term,
        "payment_term_label_en": enum_codes.label_en(enum_codes.PAYMENT_TERM, payment_term) if payment_term else None,
        "is_pathway_set": bool(payment_term),
        "current_phase_id": getattr(file_rec, "current_phase_id", None),
        "current_step_code": getattr(file_rec, "current_step_code", None),
        "milestones": milestones,
        "gates": gates,
        "completed_count": len(done),
        "total_count": len(milestones),
        "next_blocking_gate": next_blocking["gate"] if next_blocking else None,
        "is_blocked": next_blocking is not None,
        "blocking_reasons_en": blocking_reasons_en,
        "blocking_reasons_ar": blocking_reasons_ar,
    }


def get_payment_pathway_status_service(db: Session, import_file_id: int) -> Dict[str, Any]:
    file_rec = repo.get_import_file_by_id(db, import_file_id)
    if not file_rec:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد برقم المعرف {import_file_id} غير موجود.",
        )
    evidence = repo.get_financing_evidence(db, import_file_id) if file_rec.payment_term else pm.FinancingEvidence()
    return build_payment_pathway_status(file_rec, evidence)
