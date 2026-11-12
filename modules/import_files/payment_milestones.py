"""
Payment Pathway Milestone Gates (بوابات العبور المصرفية لكل مسار دفع).

Each import file runs on ONE exclusive payment pathway (``import_files.payment_term``, see
``modules.trade_finance.payment_pathway``). Real-world banking rules (ICC UCP 600 for LCs, URC 522 for
documentary collections) decide which banking milestones must exist before the shipment may move forward
on the 6-phase lifecycle board.

This module is the single, data-driven definition of those rules:

- ``MILESTONES``: every banking milestone, its pathway, labels (ar/en) and the evidence rule that proves it.
- ``PATHWAY_GATES``: pathway -> gate point -> required milestone codes. A gate point is:
    ``PHASE_n``  entering board phase ``n`` (``import_files.current_phase_id``),
    ``STEP_xx``  entering lifecycle step ``STEP_xx`` (waived when the step is in ``skipped_stages``),
    ``CLOSURE``  completing the final closure step (STEP_21).

Everything here is pure (no DB access): the evidence snapshot is built by the repository and the blocking
decision is raised by ``validators.validate_payment_pathway_gate``.

Progressive entry (GP-001): a file without a payment pathway has no gates.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple

from modules.trade_finance.payment_pathway import (
    PAYMENT_TERM_ADVANCE,
    PAYMENT_TERM_CAD,
    PAYMENT_TERM_LC,
    PAYMENT_TERM_OPEN_ACCOUNT,
)

GATE_CLOSURE = "CLOSURE"
CLOSURE_STEP_CODE = "STEP_21"

# Instrument statuses (trade_finance.validators.VALID_INSTRUMENT_STATUSES)
_INSTRUMENT_ISSUED = frozenset({"ISSUED", "ACCEPTED", "SETTLED"})
_INSTRUMENT_HONOURED = frozenset({"ACCEPTED", "SETTLED"})
_PAYMENT_PAID = "Paid"


# ── Evidence snapshot ───────────────────────────────────────────────────────────

@dataclass(frozen=True)
class InstrumentEvidence:
    instrument_type: str
    status: str
    shipment_deadline: Optional[str] = None


@dataclass(frozen=True)
class PaymentEvidence:
    payment_type: Optional[str]  # normalized PAYMENT_TYPE code
    status: Optional[str]
    swift_reference_no: Optional[str] = None


@dataclass(frozen=True)
class FinancingEvidence:
    """Active financing facts of one import file (cancelled / rejected / soft-deleted rows excluded)."""

    instruments: Tuple[InstrumentEvidence, ...] = ()
    payments: Tuple[PaymentEvidence, ...] = ()
    grn_count: int = 0


def _instrument(evidence: FinancingEvidence, inst_type: str, statuses: Iterable[str]) -> bool:
    allowed = set(statuses)
    return any(i.instrument_type == inst_type and i.status in allowed for i in evidence.instruments)


def _payment_remitted(evidence: FinancingEvidence, payment_type: str) -> bool:
    """A payment request of ``payment_type`` paid, or carrying its SWIFT (MT103) reference."""
    return any(
        p.payment_type == payment_type and (p.status == _PAYMENT_PAID or bool((p.swift_reference_no or "").strip()))
        for p in evidence.payments
    )


# ── Milestone catalog ───────────────────────────────────────────────────────────

@dataclass(frozen=True)
class MilestoneDefinition:
    code: str
    pathway: str
    label_en: str
    label_ar: str
    evidence_en: str
    evidence_ar: str
    is_met: Callable[[FinancingEvidence], bool] = field(compare=False)


MILESTONES: Dict[str, MilestoneDefinition] = {
    m.code: m
    for m in (
        MilestoneDefinition(
            code="ADV_SWIFT_MT103",
            pathway=PAYMENT_TERM_ADVANCE,
            label_en="Advance payment remitted (SWIFT MT103)",
            label_ar="تحويل الدفعة المقدمة للمورد (سويفت MT103)",
            evidence_en="Advance-payment request marked Paid or carrying a SWIFT reference",
            evidence_ar="طلب صرف دفعة مقدمة بحالة (مدفوع) أو مسجل عليه رقم السويفت",
            is_met=lambda e: _payment_remitted(e, "ADVANCE_PAYMENT"),
        ),
        MilestoneDefinition(
            code="LC_MT700_ISSUED",
            pathway=PAYMENT_TERM_LC,
            label_en="Letter of Credit issued (SWIFT MT700)",
            label_ar="إصدار الاعتماد المستندي (سويفت MT700)",
            evidence_en="LC instrument with status Issued, Accepted or Settled",
            evidence_ar="أداة اعتماد مستندي بحالة (صادر / مقبول / مسدد)",
            is_met=lambda e: _instrument(e, PAYMENT_TERM_LC, _INSTRUMENT_ISSUED),
        ),
        MilestoneDefinition(
            code="LC_SHIPMENT_DEADLINE",
            pathway=PAYMENT_TERM_LC,
            label_en="LC latest shipment date recorded",
            label_ar="تسجيل آخر موعد للشحن في الاعتماد",
            evidence_en="LC instrument with a shipment deadline",
            evidence_ar="أداة اعتماد مسجل عليها آخر موعد للشحن",
            is_met=lambda e: any(
                i.instrument_type == PAYMENT_TERM_LC and i.shipment_deadline for i in e.instruments
            ),
        ),
        MilestoneDefinition(
            code="LC_DOCS_HONOURED",
            pathway=PAYMENT_TERM_LC,
            label_en="LC documents accepted / honoured by the bank",
            label_ar="قبول البنك لمستندات الاعتماد (سداد أو قبول)",
            evidence_en="LC instrument with status Accepted or Settled",
            evidence_ar="أداة اعتماد بحالة (مقبول / مسدد)",
            is_met=lambda e: _instrument(e, PAYMENT_TERM_LC, _INSTRUMENT_HONOURED),
        ),
        MilestoneDefinition(
            code="CAD_COLLECTION_NOTICE",
            pathway=PAYMENT_TERM_CAD,
            label_en="Bank collection notice received (URC 522)",
            label_ar="استلام إشعار التحصيل المستندي من البنك",
            evidence_en="CAD instrument with status Issued, Accepted or Settled",
            evidence_ar="أداة تحصيل مستندي بحالة (صادر / مقبول / مسدد)",
            is_met=lambda e: _instrument(e, PAYMENT_TERM_CAD, _INSTRUMENT_ISSUED),
        ),
        MilestoneDefinition(
            code="CAD_DOCS_RELEASED",
            pathway=PAYMENT_TERM_CAD,
            label_en="Documents released by the bank (D/P paid or D/A accepted)",
            label_ar="الإفراج البنكي عن المستندات (سداد D/P أو قبول كمبيالة D/A)",
            evidence_en="CAD instrument Accepted/Settled, or a documentary-collection payment marked Paid",
            evidence_ar="أداة التحصيل بحالة (مقبول / مسدد) أو طلب صرف تحصيل مستندي مدفوع",
            is_met=lambda e: _instrument(e, PAYMENT_TERM_CAD, _INSTRUMENT_HONOURED)
            or _payment_remitted(e, "DOCUMENTARY_COLLECTION"),
        ),
        MilestoneDefinition(
            code="OA_GRN_RECEIVED",
            pathway=PAYMENT_TERM_OPEN_ACCOUNT,
            label_en="Goods received in warehouse (GRN)",
            label_ar="الاستلام المخزني الفعلي للبضاعة (إذن إضافة GRN)",
            evidence_en="Active warehouse receiving record (GRN)",
            evidence_ar="سجل استلام مخزني نشط (GRN)",
            is_met=lambda e: e.grn_count > 0,
        ),
        MilestoneDefinition(
            code="OA_SUPPLIER_SETTLED",
            pathway=PAYMENT_TERM_OPEN_ACCOUNT,
            label_en="Deferred supplier payment settled",
            label_ar="سداد مستحقات المورد الآجلة",
            evidence_en="Final-settlement payment request marked Paid or carrying a SWIFT reference",
            evidence_ar="طلب صرف تسوية نهائية بحالة (مدفوع) أو مسجل عليه رقم السويفت",
            is_met=lambda e: _payment_remitted(e, "FINAL_SETTLEMENT"),
        ),
    )
}

# pathway -> gate point -> milestone codes required before crossing it.
PATHWAY_GATES: Dict[str, Dict[str, Tuple[str, ...]]] = {
    # Freight booking (phase 3) is blocked until the advance is remitted.
    PAYMENT_TERM_ADVANCE: {
        "PHASE_3": ("ADV_SWIFT_MT103",),
    },
    # Freight booking needs the issued LC and its latest shipment date; Bank Form 4 needs honoured documents.
    PAYMENT_TERM_LC: {
        "PHASE_3": ("LC_MT700_ISSUED", "LC_SHIPMENT_DEADLINE"),
        "STEP_12": ("LC_DOCS_HONOURED",),
    },
    # Digital & banking (phase 4) starts with the bank's collection notice; Form 4 / document release need
    # D/P payment or D/A acceptance.
    PAYMENT_TERM_CAD: {
        "PHASE_4": ("CAD_COLLECTION_NOTICE",),
        "STEP_12": ("CAD_DOCS_RELEASED",),
    },
    # No pre-shipment financing gates: the deferred payment follows the GRN and must be settled before closure.
    PAYMENT_TERM_OPEN_ACCOUNT: {
        GATE_CLOSURE: ("OA_GRN_RECEIVED", "OA_SUPPLIER_SETTLED"),
    },
}


# ── Pure evaluation ─────────────────────────────────────────────────────────────

def pathway_milestones(payment_term: Optional[str]) -> List[MilestoneDefinition]:
    """Milestones of a pathway in the order they occur."""
    return [m for m in MILESTONES.values() if m.pathway == payment_term]


def completed_milestones(payment_term: Optional[str], evidence: FinancingEvidence) -> List[str]:
    return [m.code for m in pathway_milestones(payment_term) if m.is_met(evidence)]


def gate_order_key(gate: str, ordered_steps: Sequence[str], step_to_phase: Dict[str, int]) -> int:
    """Sort key placing a gate on the lifecycle axis (phase gate before the first step of that phase)."""
    if gate == GATE_CLOSURE:
        return len(ordered_steps) * 10 + 9
    if gate.startswith("PHASE_"):
        phase = int(gate.split("_", 1)[1])
        first = next((i for i, s in enumerate(ordered_steps) if step_to_phase.get(s) == phase), len(ordered_steps))
        return first * 10
    if gate in ordered_steps:
        return ordered_steps.index(gate) * 10 + 1
    return len(ordered_steps) * 10


def gates_crossed(
    from_step: Optional[str],
    from_phase: Optional[int],
    to_step: Optional[str],
    *,
    to_phase: Optional[int] = None,
    ordered_steps: Sequence[str],
    step_to_phase: Dict[str, int],
    closing: bool = False,
    skipped_steps: Iterable[str] = (),
) -> List[str]:
    """Gate points crossed when a file moves from its current position to ``to_step``.

    - ``PHASE_n`` for every phase ``n`` above the current phase up to the target phase;
    - ``STEP_xx`` for every step after the current step up to and including the target step (skipped steps
      are waived);
    - ``CLOSURE`` when ``closing`` (completing STEP_21).
    Moving backwards or staying in place crosses nothing (except an explicit closure).
    """
    gates: List[str] = []
    skipped = set(skipped_steps or ())

    if from_step in ordered_steps:
        from_idx = ordered_steps.index(from_step)
    elif from_phase:
        # Position = just before the first step of the current phase (the phase itself is already entered).
        first = next((i for i, s in enumerate(ordered_steps) if step_to_phase.get(s) == from_phase), 0)
        from_idx = first - 1
    else:
        from_idx = -1
    current_phase = from_phase or (step_to_phase.get(from_step) if from_step else None) or 1

    if to_step in ordered_steps:
        to_idx = ordered_steps.index(to_step)
        target_phase = step_to_phase.get(to_step, current_phase)
        for phase in range(current_phase + 1, target_phase + 1):
            gates.append(f"PHASE_{phase}")
        for step in ordered_steps[from_idx + 1: to_idx + 1]:
            if step not in skipped:
                gates.append(step)
    elif to_phase:
        # Board-phase only move (milestone progression): the phase gates, no step gates.
        for phase in range(current_phase + 1, to_phase + 1):
            gates.append(f"PHASE_{phase}")

    if closing:
        gates.append(GATE_CLOSURE)
    return gates


def blocking_milestones(
    payment_term: Optional[str], gates: Iterable[str], evidence: FinancingEvidence
) -> List[Tuple[str, List[str]]]:
    """``[(gate, [missing milestone codes]), ...]`` for the crossed gates that are not satisfied."""
    if not payment_term:
        return []
    config = PATHWAY_GATES.get(payment_term, {})
    done = set(completed_milestones(payment_term, evidence))
    blocked: List[Tuple[str, List[str]]] = []
    for gate in gates:
        missing = [code for code in config.get(gate, ()) if code not in done]
        if missing:
            blocked.append((gate, missing))
    return blocked


def required_before(payment_term: Optional[str]) -> Dict[str, str]:
    """milestone code -> the first gate that requires it."""
    result: Dict[str, str] = {}
    for gate, codes in PATHWAY_GATES.get(payment_term or "", {}).items():
        for code in codes:
            result.setdefault(code, gate)
    return result
