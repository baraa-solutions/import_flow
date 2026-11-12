"""
Import-file tracking writer (single-language storage, Phase B).

``set_file_tracking`` is the ONE place that writes the tracking state of an ``ImportFile``:

- structured columns: ``current_step_code``, ``current_phase_id``, ``current_stage_code``,
  ``next_action_code``, ``next_action_params`` (Flutter renders them in the UI language);
- legacy text columns, always in English: ``current_module`` (``"<STEP_xx> <English step name>"``),
  ``current_stage`` (``"Phase n: <English phase title>"`` or the English label of a special stage code) and
  ``next_action`` (``render_en(code, params, "action")``).

Every argument left as ``None`` leaves its columns untouched, so callers can update only the next action
or only the stage. It never commits: the caller owns the transaction.
"""

from __future__ import annotations

import re
from typing import Any, Optional, Tuple

from modules.common import enum_codes
from modules.common.system_messages import SysMsg, render_en

_PHASE_NUM_RE = re.compile(r"(\d{1,2})")
_TITLE_PREFIX_RE = re.compile(r"^\s*\d+\.\s*")
_STEP_NUMBER_RE = re.compile(r"^STEP_(\d+)")


def file_past_step(file_rec: Any, step_code: str) -> bool:
    """True when the file's GP-002 step is beyond ``step_code`` (e.g. STEP_21 is past STEP_20):
    prevents moving a file backwards on the lifecycle board."""
    if file_rec is None or not getattr(file_rec, "current_step_code", None):
        return False
    current = _STEP_NUMBER_RE.match(file_rec.current_step_code)
    target = _STEP_NUMBER_RE.match(step_code)
    if not current or not target:
        return False
    return int(current.group(1)) > int(target.group(1))


_file_past_step = file_past_step


def _step_catalog() -> Tuple[dict, dict, list]:
    # Lazy import: lifecycle_board.service imports half the application; common helpers must not.
    from modules.lifecycle_board.service import PHASES_DEFINITION, STEP_NAME_MAP, STEP_TO_PHASE_MAP

    return STEP_NAME_MAP, STEP_TO_PHASE_MAP, PHASES_DEFINITION


def _parse_phase_id(phase_id: Any) -> Optional[int]:
    """Accept 5, "5", "PHASE_5", "Phase 5". Returns None when nothing usable is given."""
    if phase_id is None or isinstance(phase_id, bool):
        return None
    if isinstance(phase_id, int):
        return phase_id
    match = _PHASE_NUM_RE.search(str(phase_id))
    return int(match.group(1)) if match else None


def phase_title_en(phase_id: int) -> str:
    """Legacy English stage text: ``"Phase 5: Port Operations & Clearance"`` (keeps the ``Phase n`` substring
    the dashboard legacy filter and phase counts look for)."""
    _, _, phases = _step_catalog()
    for phase in phases:
        if phase["phase_id"] == phase_id:
            return f"Phase {phase_id}: {_TITLE_PREFIX_RE.sub('', phase['title_en'])}"
    return f"Phase {phase_id}"


def step_module_en(step_code: str) -> str:
    """Legacy English module text: ``"STEP_13 Customs Declaration 46"``."""
    names, _, _ = _step_catalog()
    english = names.get(step_code, (None, None))[0]
    return f"{step_code} {english}" if english else step_code


def step_tracking_columns(step_code: Optional[str]) -> dict:
    """Structured stage columns of a step, for insert/update dicts that keep their own legacy texts:
    ``{"current_step_code", "current_phase_id", "current_stage_code"}``. Unknown steps give ``{}``."""
    if not step_code:
        return {}
    _, step_to_phase, _ = _step_catalog()
    phase = step_to_phase.get(step_code)
    if phase is None:
        return {}
    return {"current_step_code": step_code, "current_phase_id": phase, "current_stage_code": f"PHASE_{phase}"}


def _enforce_payment_gate(file_rec, step_code, phase_id, stage_code) -> None:
    """Single choke point of forward lifecycle moves: refuse to cross an unsatisfied payment-pathway gate."""
    if not getattr(file_rec, "payment_term", None) or getattr(file_rec, "import_file_id", None) is None:
        return
    target_phase = phase_id
    if target_phase is None and stage_code and stage_code.upper().startswith("PHASE"):
        target_phase = _parse_phase_id(stage_code)
    if not step_code and target_phase is None:
        return
    from sqlalchemy.orm import object_session

    db = object_session(file_rec)
    if db is None:
        return
    # Lazy import: import_files imports half the application; common helpers must not.
    from modules.import_files.import_file_payment_pathway_service import enforce_payment_pathway_gate

    enforce_payment_pathway_gate(db, file_rec, to_step=step_code, to_phase=target_phase)


def set_file_tracking(
    file_rec,
    *,
    step_code: str | None = None,
    phase_id: str | None = None,
    next_action: "SysMsg | None" = None,
    stage_code: str | None = None,
    enforce_payment_gate: bool = True,
) -> None:
    """Write the structured tracking columns plus their English legacy text (see the module docstring).

    - ``step_code``: sets ``current_step_code`` + ``current_module``. When ``phase_id`` is not given it is
      derived from the step.
    - ``phase_id``: int or a string such as ``"5"`` / ``"PHASE_5"``; sets ``current_phase_id`` and, unless a
      ``stage_code`` is given, ``current_stage_code = "PHASE_n"`` + ``current_stage``.
    - ``stage_code``: a STAGE enum code (``CUSTOMS_RELEASED``, ``PHASE_n``, ...); sets ``current_stage_code``
      and ``current_stage`` = its English label.
    - ``next_action``: a ``SysMsg`` (``NA_*``); sets ``next_action_code`` / ``next_action_params`` +
      ``next_action``.
    - ``enforce_payment_gate``: every forward step / phase move is checked against the file's payment pathway
      milestone gates (modules/import_files/payment_milestones.py) and refused with 409
      ``PAYMENT_MILESTONE_GATE_BLOCKED`` before anything is written. Only callers that already checked the
      gate (``advance_tracking_or_hold``) pass ``False``.
    """
    if file_rec is None:
        return

    resolved_phase = _parse_phase_id(phase_id)
    if enforce_payment_gate and (step_code or resolved_phase or stage_code):
        _enforce_payment_gate(file_rec, step_code, resolved_phase, stage_code)
    if step_code:
        _, step_to_phase, _ = _step_catalog()
        file_rec.current_step_code = step_code
        file_rec.current_module = step_module_en(step_code)[:100]
        if resolved_phase is None:
            resolved_phase = step_to_phase.get(step_code)

    if stage_code:
        file_rec.current_stage_code = stage_code
        stage_phase = _parse_phase_id(stage_code) if stage_code.upper().startswith("PHASE") else None
        if stage_phase is not None:
            resolved_phase = resolved_phase or stage_phase
            file_rec.current_stage = phase_title_en(stage_phase)[:100]
        else:
            file_rec.current_stage = str(enum_codes.label_en(enum_codes.STAGE, stage_code))[:100]

    if resolved_phase is not None:
        file_rec.current_phase_id = resolved_phase
        if not stage_code:
            file_rec.current_stage_code = f"PHASE_{resolved_phase}"
            file_rec.current_stage = phase_title_en(resolved_phase)[:100]

    if next_action is not None:
        file_rec.next_action_code = next_action.code
        file_rec.next_action_params = dict(next_action.params or {})
        file_rec.next_action = render_en(next_action.code, next_action.params, "action")[:255]
