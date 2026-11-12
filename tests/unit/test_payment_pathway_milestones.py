"""
Payment pathway milestone gates (Trello p0RG1Nxm): every pathway (SWIFT advance / LC / CAD / Open Account)
x every lifecycle transition is allowed or blocked according to the data-driven gate table, the evidence
rules of each milestone, the GP-002 validator, the lifecycle-board / closure / milestone-progression
enforcement points and the status API used by the Flutter PaymentPathwayGuard.
"""
from datetime import date
from itertools import product

import pytest
from fastapi import HTTPException

import main  # noqa: F401  (registers every model on Base.metadata)
import modules.docs_customs_approval.service as docs_approval_service
import modules.lifecycle_board.service as lifecycle_service
from modules.common.errors import best_effort
from modules.common.file_tracking import set_file_tracking
from modules.common.system_messages import msg
from modules.docs_customs_approval.model import CustomsDocumentApproval, DocsCustomsApprovalSession
from modules.docs_customs_approval.schemas import DocsCustomsApprovalSessionCreate
from modules.financial_approval.model import PaymentRequestSession
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.schemas import ShipmentBookingCreate
from modules.freight_booking.service import create_booking_service
from modules.import_files import payment_milestones as pm
from modules.import_files import validators
from modules.import_files.import_file_payment_pathway_service import (
    advance_tracking_or_hold,
    build_payment_pathway_status,
    enforce_payment_pathway_gate,
    get_payment_pathway_status_service,
)
from modules.lifecycle_board.lifecycle_kanban_service import ORDERED_STEP_CODES, STEP_TO_PHASE_MAP
from modules.notifications.model import SystemNotification
from modules.trade_finance.model import ImportFinanceInstrument
from modules.warehouse_receiving.model import WarehouseReceivingRecord

from test_phase02_support import make_session, seed_file

ADV, LC, CAD, OA = "ADVANCE_PAYMENT", "LC", "CAD", "OPEN_ACCOUNT"

# The business rule, restated independently of the config table.
EXPECTED_GATES = {
    ADV: {"PHASE_3"},
    LC: {"PHASE_3", "STEP_12"},
    CAD: {"PHASE_4", "STEP_12"},
    OA: {"CLOSURE"},
}

# Every phase transition of the 6-phase board, plus Bank Form 4 (STEP_12) and the final closure.
TRANSITIONS = [
    ("STEP_03", "STEP_04", False, {"PHASE_2", "STEP_04"}),
    ("STEP_05", "STEP_06", False, {"PHASE_3", "STEP_06"}),
    ("STEP_09", "STEP_10", False, {"PHASE_4", "STEP_10"}),
    ("STEP_11", "STEP_12", False, {"STEP_12"}),
    ("STEP_12", "STEP_13", False, {"PHASE_5", "STEP_13"}),
    ("STEP_18", "STEP_19", False, {"PHASE_6", "STEP_19"}),
    ("STEP_20", "STEP_21", True, {"STEP_21", "CLOSURE"}),
]

FULL_EVIDENCE = pm.FinancingEvidence(
    instruments=(
        pm.InstrumentEvidence(LC, "SETTLED", "2026-12-31"),
        pm.InstrumentEvidence(CAD, "SETTLED"),
    ),
    payments=(
        pm.PaymentEvidence("ADVANCE_PAYMENT", "Paid"),
        pm.PaymentEvidence("FINAL_SETTLEMENT", "Paid"),
    ),
    grn_count=1,
)


def _crossed(from_step, to_step, closing=False, **kw):
    return pm.gates_crossed(
        from_step, STEP_TO_PHASE_MAP[from_step], to_step,
        ordered_steps=ORDERED_STEP_CODES, step_to_phase=STEP_TO_PHASE_MAP, closing=closing, **kw,
    )


# ── Config sanity ───────────────────────────────────────────────────────────────

def test_gate_table_matches_business_rules():
    assert {k: set(v) for k, v in pm.PATHWAY_GATES.items()} == EXPECTED_GATES


def test_every_gate_milestone_belongs_to_its_pathway():
    for pathway, gates in pm.PATHWAY_GATES.items():
        for codes in gates.values():
            for code in codes:
                assert pm.MILESTONES[code].pathway == pathway


def test_every_milestone_has_bilingual_labels():
    for m in pm.MILESTONES.values():
        assert m.label_en and m.label_ar and m.evidence_en and m.evidence_ar


# ── Gate crossing ───────────────────────────────────────────────────────────────

@pytest.mark.parametrize("from_step,to_step,closing,expected", TRANSITIONS)
def test_gates_crossed_per_transition(from_step, to_step, closing, expected):
    assert set(_crossed(from_step, to_step, closing)) == expected


def test_jumping_several_phases_crosses_every_gate_in_between():
    gates = _crossed("STEP_02", "STEP_13")
    assert {"PHASE_2", "PHASE_3", "PHASE_4", "PHASE_5", "STEP_12"} <= set(gates)


def test_backwards_or_same_step_crosses_nothing():
    assert _crossed("STEP_13", "STEP_06") == []
    assert _crossed("STEP_06", "STEP_06") == []


def test_skipped_step_gate_is_waived():
    assert "STEP_12" not in _crossed("STEP_11", "STEP_13", skipped_steps=["STEP_12"])


def test_phase_only_move_crosses_phase_gates():
    gates = pm.gates_crossed(
        None, 2, None, to_phase=4, ordered_steps=ORDERED_STEP_CODES, step_to_phase=STEP_TO_PHASE_MAP
    )
    assert gates == ["PHASE_3", "PHASE_4"]


def test_new_file_without_position_starts_before_step_01():
    gates = pm.gates_crossed(
        None, None, "STEP_06", ordered_steps=ORDERED_STEP_CODES, step_to_phase=STEP_TO_PHASE_MAP
    )
    assert "PHASE_3" in gates and "STEP_01" in gates


# ── Pathway x transition matrix ─────────────────────────────────────────────────

@pytest.mark.parametrize(
    "pathway,transition", list(product([ADV, LC, CAD, OA], TRANSITIONS)),
    ids=lambda v: v if isinstance(v, str) else f"{v[0]}->{v[1]}",
)
def test_matrix_blocked_without_evidence_allowed_with_evidence(pathway, transition):
    from_step, to_step, closing, crossed = transition
    gates = _crossed(from_step, to_step, closing)
    expected_blocking = crossed & EXPECTED_GATES[pathway]

    blocked = pm.blocking_milestones(pathway, gates, pm.FinancingEvidence())
    assert {g for g, _ in blocked} == expected_blocking
    assert pm.blocking_milestones(pathway, gates, FULL_EVIDENCE) == []


@pytest.mark.parametrize("from_step,to_step,closing,_", TRANSITIONS)
def test_no_pathway_never_blocks(from_step, to_step, closing, _):
    assert pm.blocking_milestones(None, _crossed(from_step, to_step, closing), pm.FinancingEvidence()) == []


# ── Milestone evidence rules ────────────────────────────────────────────────────

def _met(code, **evidence):
    return pm.MILESTONES[code].is_met(pm.FinancingEvidence(**evidence))


def test_advance_swift_requires_paid_or_swift_reference():
    assert not _met("ADV_SWIFT_MT103", payments=(pm.PaymentEvidence("ADVANCE_PAYMENT", "Approved"),))
    assert _met("ADV_SWIFT_MT103", payments=(pm.PaymentEvidence("ADVANCE_PAYMENT", "Approved", "MT103-77"),))
    assert _met("ADV_SWIFT_MT103", payments=(pm.PaymentEvidence("ADVANCE_PAYMENT", "Paid"),))
    assert not _met("ADV_SWIFT_MT103", payments=(pm.PaymentEvidence("FINAL_SETTLEMENT", "Paid"),))


def test_lc_issued_excludes_draft_and_needs_deadline_separately():
    draft = pm.InstrumentEvidence(LC, "DRAFT", "2026-12-31")
    issued = pm.InstrumentEvidence(LC, "ISSUED")
    assert not _met("LC_MT700_ISSUED", instruments=(draft,))
    assert _met("LC_MT700_ISSUED", instruments=(issued,))
    assert not _met("LC_SHIPMENT_DEADLINE", instruments=(issued,))
    assert _met("LC_SHIPMENT_DEADLINE", instruments=(draft,))
    assert not _met("LC_DOCS_HONOURED", instruments=(issued,))
    assert _met("LC_DOCS_HONOURED", instruments=(pm.InstrumentEvidence(LC, "ACCEPTED"),))


def test_cad_docs_released_by_acceptance_or_paid_collection():
    notice = pm.InstrumentEvidence(CAD, "ISSUED")
    assert _met("CAD_COLLECTION_NOTICE", instruments=(notice,))
    assert not _met("CAD_DOCS_RELEASED", instruments=(notice,))
    assert _met("CAD_DOCS_RELEASED", instruments=(pm.InstrumentEvidence(CAD, "ACCEPTED"),))
    assert _met("CAD_DOCS_RELEASED", instruments=(notice,),
                payments=(pm.PaymentEvidence("DOCUMENTARY_COLLECTION", "Paid"),))


def test_open_account_needs_grn_and_settlement():
    assert not _met("OA_GRN_RECEIVED")
    assert _met("OA_GRN_RECEIVED", grn_count=1)
    assert _met("OA_SUPPLIER_SETTLED", payments=(pm.PaymentEvidence("FINAL_SETTLEMENT", "Paid"),))


# ── Validator ───────────────────────────────────────────────────────────────────

def test_validator_passes_when_nothing_blocked():
    validators.validate_payment_pathway_gate("IMP-1", LC, [])


def test_validator_raises_bilingual_coded_409():
    with pytest.raises(HTTPException) as exc:
        validators.validate_payment_pathway_gate(
            "IMP-1", LC, [("PHASE_3", ["LC_MT700_ISSUED"])], {"PHASE_3": ("Phase 3", "المرحلة الثالثة")}
        )
    detail = exc.value.detail
    assert exc.value.status_code == 409
    assert detail["code"] == "PAYMENT_MILESTONE_GATE_BLOCKED"
    assert detail["gate"] == "PHASE_3"
    assert detail["missing_milestones"] == ["LC_MT700_ISSUED"]
    assert "MT700" in detail["message_en"] and "المرحلة الثالثة" in detail["message"]


# ── DB integration ──────────────────────────────────────────────────────────────

@pytest.fixture
def db():
    session = make_session()
    yield session
    session.close()


def _file(db, payment_term, step="STEP_05", **extra):
    return seed_file(
        db, payment_term=payment_term, current_step_code=step, current_phase_id=STEP_TO_PHASE_MAP[step],
        status="In Progress", **extra,
    )


def _instrument(db, file_id, inst_type, status, deadline=None):
    db.add(ImportFinanceInstrument(
        instrument_type=inst_type, instrument_number=f"{inst_type}-{file_id}-{status}", import_file_id=file_id,
        issuing_bank="NBE", amount=1000.0, status=status, shipment_deadline=deadline,
    ))
    db.commit()


def _payment(db, file_id, payment_type, status="Paid"):
    db.add(PaymentRequestSession(
        payment_code=f"PAY-{file_id}-{payment_type}", title="Supplier", supplier_name="Supplier",
        payment_type=payment_type, requested_amount=100.0, currency_code="USD", exchange_rate=50.0, due_date=date(2026, 12, 1),
        status=status, import_file_id=file_id,
    ))
    db.commit()


def _advance(db, imp, completed, target):
    return lifecycle_service.advance_lifecycle_step_service(
        db=db, import_file_id=imp.import_file_id, completed_step_code=completed, target_step_codes=[target],
        auto_complete_prior=False,
    )


def test_lc_file_blocked_from_freight_booking_until_lc_issued(db):
    imp = _file(db, LC, step="STEP_04")
    with pytest.raises(HTTPException) as exc:
        _advance(db, imp, "STEP_04", "STEP_06")
    assert exc.value.detail["code"] == "PAYMENT_MILESTONE_GATE_BLOCKED"
    assert set(exc.value.detail["missing_milestones"]) == {"LC_MT700_ISSUED", "LC_SHIPMENT_DEADLINE"}

    _instrument(db, imp.import_file_id, LC, "ISSUED", date(2026, 12, 31))
    res = _advance(db, imp, "STEP_04", "STEP_06")
    assert res["current_phase_id"] == 3


def test_advance_file_blocked_until_swift_remitted(db):
    imp = _file(db, ADV, step="STEP_04")
    _payment(db, imp.import_file_id, "ADVANCE_PAYMENT", status="Approved")
    with pytest.raises(HTTPException):
        _advance(db, imp, "STEP_04", "STEP_06")
    db.query(PaymentRequestSession).update({"swift_reference_no": "MT103-0001"})
    db.commit()
    assert _advance(db, imp, "STEP_04", "STEP_06")["current_step_code"] == "STEP_06"


def test_cad_file_bank_form4_requires_released_documents(db):
    imp = _file(db, CAD, step="STEP_11")
    _instrument(db, imp.import_file_id, CAD, "ISSUED")
    with pytest.raises(HTTPException) as exc:
        _advance(db, imp, "STEP_11", "STEP_12")
    assert exc.value.detail["gate"] == "STEP_12"
    _payment(db, imp.import_file_id, "DOCUMENTARY_COLLECTION", status="Paid")
    assert _advance(db, imp, "STEP_11", "STEP_12")["current_step_code"] == "STEP_12"


def test_cancelled_instrument_is_not_evidence(db):
    imp = _file(db, CAD, step="STEP_09")
    _instrument(db, imp.import_file_id, CAD, "CANCELLED")
    with pytest.raises(HTTPException):
        enforce_payment_pathway_gate(db, imp, to_step="STEP_10")


def test_open_account_moves_freely_but_closure_needs_grn_and_settlement(db):
    imp = _file(db, OA, step="STEP_02")
    enforce_payment_pathway_gate(db, imp, to_step="STEP_20")  # no pre-shipment gates
    with pytest.raises(HTTPException) as exc:
        enforce_payment_pathway_gate(db, imp, closing=True)
    assert set(exc.value.detail["missing_milestones"]) == {"OA_GRN_RECEIVED", "OA_SUPPLIER_SETTLED"}

    db.add(WarehouseReceivingRecord(grn_code="GRN-T-1", import_file_id=imp.import_file_id))
    db.commit()
    _payment(db, imp.import_file_id, "FINAL_SETTLEMENT", status="Paid")
    enforce_payment_pathway_gate(db, imp, closing=True)


def test_file_without_pathway_is_never_gated(db):
    imp = _file(db, None, step="STEP_04")
    assert _advance(db, imp, "STEP_04", "STEP_06")["current_phase_id"] == 3


def test_board_phase_progression_is_gated(db):
    imp = _file(db, CAD, step="STEP_06")
    with pytest.raises(HTTPException):
        enforce_payment_pathway_gate(db, imp, to_phase=4)
    enforce_payment_pathway_gate(db, imp, to_phase=3)


# ── Status API (PaymentPathwayGuard) ────────────────────────────────────────────

def test_status_lists_pending_milestones_and_next_blocking_gate(db):
    imp = _file(db, LC, step="STEP_04")
    _instrument(db, imp.import_file_id, LC, "ISSUED")
    status = get_payment_pathway_status_service(db, imp.import_file_id)

    assert status["payment_term"] == LC and status["is_pathway_set"]
    by_code = {m["code"]: m for m in status["milestones"]}
    assert by_code["LC_MT700_ISSUED"]["is_completed"]
    assert not by_code["LC_SHIPMENT_DEADLINE"]["is_completed"]
    assert by_code["LC_SHIPMENT_DEADLINE"]["required_before_gate"] == "PHASE_3"
    assert status["completed_count"] == 1 and status["total_count"] == 3
    assert status["next_blocking_gate"] == "PHASE_3" and status["is_blocked"]
    assert len(status["blocking_reasons_en"]) == 1 and len(status["blocking_reasons_ar"]) == 1
    assert [g["gate"] for g in status["gates"]] == ["PHASE_3", "STEP_12"]
    assert not any(g["is_passed"] for g in status["gates"])


def test_status_marks_passed_gates_and_waived_steps():
    class _File:
        import_file_id, import_file_code, payment_term = 1, "IMP-X", CAD
        current_step_code, current_phase_id, status = "STEP_13", 5, "In Progress"
        skipped_stages = ["STEP_12"]

    status = build_payment_pathway_status(_File(), pm.FinancingEvidence())
    gates = {g["gate"]: g for g in status["gates"]}
    assert gates["PHASE_4"]["is_passed"] and gates["STEP_12"]["is_passed"]
    assert gates["STEP_12"]["is_waived"] and gates["STEP_12"]["is_satisfied"]
    assert not status["is_blocked"]


def test_status_without_pathway(db):
    imp = _file(db, None)
    status = get_payment_pathway_status_service(db, imp.import_file_id)
    assert not status["is_pathway_set"] and status["milestones"] == [] and not status["is_blocked"]


def test_status_unknown_file_404(db):
    with pytest.raises(HTTPException) as exc:
        get_payment_pathway_status_service(db, 99999)
    assert exc.value.status_code == 404


# ── Central choke point: every forward tracking write (PR #220 review) ─────────

def test_set_file_tracking_refuses_to_cross_an_unsatisfied_gate(db):
    imp = _file(db, LC, step="STEP_05")
    with pytest.raises(HTTPException) as exc:
        set_file_tracking(imp, step_code="STEP_06", next_action=msg("NA_FILE_CLOSED"))
    assert exc.value.detail["code"] == "PAYMENT_MILESTONE_GATE_BLOCKED"
    assert exc.value.detail["import_file_id"] == imp.import_file_id
    assert imp.current_step_code == "STEP_05" and imp.current_phase_id == 2


def test_set_file_tracking_phase_only_move_is_gated(db):
    imp = _file(db, CAD, step="STEP_09")
    with pytest.raises(HTTPException):
        set_file_tracking(imp, phase_id=4)
    assert imp.current_phase_id == 3


def test_set_file_tracking_next_action_only_and_backwards_moves_are_free(db):
    imp = _file(db, LC, step="STEP_05")
    set_file_tracking(imp, next_action=msg("NA_FILE_CLOSED"))
    set_file_tracking(imp, step_code="STEP_02")
    assert imp.current_step_code == "STEP_02"


def test_advance_tracking_or_hold_keeps_file_and_surfaces_the_hold(db):
    imp = _file(db, CAD, step="STEP_09")
    moved = advance_tracking_or_hold(db, imp, step_code="STEP_10", next_action=msg("NA_FILE_CLOSED"))
    db.commit()
    assert moved is False
    assert imp.current_step_code == "STEP_09"
    assert imp.next_action_code == "NA_PAYMENT_MILESTONE_PENDING"
    assert imp.next_action_params["gate"] == "PHASE_4"
    note = db.query(SystemNotification).filter(SystemNotification.entity_id == imp.import_file_id).one()
    assert note.msg_code == "PAYMENT_MILESTONE_GATE_HOLD" and note.severity == "WARNING"

    _instrument(db, imp.import_file_id, CAD, "ISSUED")
    assert advance_tracking_or_hold(db, imp, step_code="STEP_10", next_action=msg("NA_FILE_CLOSED")) is True
    assert imp.current_phase_id == 4


def test_best_effort_sync_swallowing_the_gate_records_the_hold(db):
    imp = _file(db, LC, step="STEP_05")

    def _sync():
        set_file_tracking(imp, step_code="STEP_06")

    assert best_effort(db, _sync, "test sync") is None
    db.refresh(imp)
    assert imp.current_step_code == "STEP_05"
    assert imp.next_action_code == "NA_PAYMENT_MILESTONE_PENDING"
    assert db.query(SystemNotification).filter(
        SystemNotification.msg_code == "PAYMENT_MILESTONE_GATE_HOLD"
    ).count() == 1


def _booking_payload(file_id):
    return ShipmentBookingCreate(import_file_id=file_id, shipment_type="Ocean LCL", status="Draft")


@pytest.mark.parametrize("pathway,missing", [
    (LC, {"LC_MT700_ISSUED", "LC_SHIPMENT_DEADLINE"}),
    (ADV, {"ADV_SWIFT_MT103"}),
])
def test_create_booking_without_financing_evidence_returns_409(db, pathway, missing):
    imp = _file(db, pathway, step="STEP_05")
    with pytest.raises(HTTPException) as exc:
        create_booking_service(db, _booking_payload(imp.import_file_id))
    assert exc.value.status_code == 409
    assert set(exc.value.detail["missing_milestones"]) == missing
    db.rollback()
    db.refresh(imp)
    assert imp.current_step_code == "STEP_05" and imp.current_phase_id == 2
    assert db.query(ShipmentBooking).count() == 0


def test_create_booking_allowed_once_lc_is_issued(db):
    imp = _file(db, LC, step="STEP_05")
    _instrument(db, imp.import_file_id, LC, "ISSUED", date(2026, 12, 31))
    booking = create_booking_service(db, _booking_payload(imp.import_file_id))
    db.refresh(imp)
    assert booking.booking_id is not None
    assert imp.current_step_code == "STEP_06" and imp.current_phase_id == 3


def test_create_booking_on_file_without_pathway_is_unchanged(db):
    imp = _file(db, None, step="STEP_05")
    create_booking_service(db, _booking_payload(imp.import_file_id))
    db.refresh(imp)
    assert imp.current_phase_id == 3


def _approve_all_documents(db, file_id):
    for i, doc_type in enumerate(["Commercial Invoice", "Packing List", "Bill of Lading", "Certificate of Origin"]):
        db.add(CustomsDocumentApproval(
            approval_code=f"CDA-PPG-{file_id}-{i}", import_file_id=file_id, document_type=doc_type,
            overall_status="Approved for Clearance", is_active=True,
        ))
    db.commit()


def _final_docs_approval(db, file_id):
    return docs_approval_service.create_customs_approval_session_service(db, DocsCustomsApprovalSessionCreate(
        import_file_id=file_id, is_draft=False, final_invoice_status="Approved", final_pl_status="Approved",
        draft_bl_status="Approved", coo_status="Approved", coc_status="Waived / Not Required",
    ))


def test_cad_docs_approval_final_save_is_kept_but_file_held_before_phase_4(db):
    imp = _file(db, CAD, step="STEP_09")
    _approve_all_documents(db, imp.import_file_id)

    session = _final_docs_approval(db, imp.import_file_id)
    db.refresh(imp)
    assert session.session_id is not None and session.is_draft is False
    assert db.query(DocsCustomsApprovalSession).count() == 1
    assert imp.current_step_code == "STEP_09" and imp.current_phase_id == 3
    assert imp.next_action_code == "NA_PAYMENT_MILESTONE_PENDING"


def test_cad_docs_approval_advances_with_collection_notice(db):
    imp = _file(db, CAD, step="STEP_09")
    _instrument(db, imp.import_file_id, CAD, "ISSUED")
    _approve_all_documents(db, imp.import_file_id)
    _final_docs_approval(db, imp.import_file_id)
    db.refresh(imp)
    assert imp.current_step_code == "STEP_10" and imp.current_phase_id == 4
