"""
Single-language storage, Phase B (group 1): lifecycle_board, import_files, smart_tasks, smart_email_listener.

System text is stored as a message code + params, the legacy text column keeps the English render (no Arabic),
and import files carry structured tracking columns (current_step_code / current_phase_id / current_stage_code /
next_action_code / next_action_params) written by ``modules.common.file_tracking.set_file_tracking``.
"""
import re
from datetime import date
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base.metadata)
import modules.import_files.repository as file_repo
import modules.import_files.service as file_service
import modules.lifecycle_board.repository as repo
import modules.lifecycle_board.service as service
import modules.smart_email_listener.repository as email_repo
import modules.smart_tasks.service as task_service
from database.database import Base
from modules.common.file_tracking import set_file_tracking, step_tracking_columns
from modules.common.system_messages import msg
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.import_files.schemas import CloneImportFileRequest, CloseShipmentSubmit, ImportFileCreate, ReopenShipmentSubmit
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.lifecycle_board.schemas import SkipStepPayload, StepAdvancePayload
from modules.smart_tasks.model import SmartTask
from modules.smart_tasks.schemas import SmartTaskCreate, SmartTaskUpdate
import modules.smart_tasks.repository as task_repo

ARABIC = re.compile(r"[؀-ۿ]")
FILE_CODE = "IMP-2026-0101"


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add(
        ImportFile(
            import_file_code=FILE_CODE,
            company_name="Al-Ahram Industrial",
            supplier_name="Global Steel Italy",
            status="Draft",
            acid_number="1234567890123456789",  # STEP_05 ACID stage gate needs a valid 19-digit ACID
            is_active=True,
        )
    )
    session.add(
        ImportCompany(
            company_id=1, importer_name="Egyptian Import Co", vat_id="100-200-300", registration_number="12345",
            address="Cairo", country="Egypt", importer_id="IMP-001", importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1), registration_expiry=date(2028, 1, 1),
        )
    )
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _file(db) -> ImportFile:
    return db.query(ImportFile).filter(ImportFile.import_file_code == FILE_CODE).one()


def _no_arabic(*values):
    for value in values:
        assert not ARABIC.search(str(value or "")), value


# ── set_file_tracking ─────────────────────────────────────────────────────────


def test_set_file_tracking_step_derives_phase_and_english_texts():
    rec = SimpleNamespace()
    set_file_tracking(rec, step_code="STEP_13", next_action=msg("NA_FOLLOW_UP_STEP", step_code="STEP_13"))
    assert rec.current_step_code == "STEP_13"
    assert rec.current_phase_id == 5
    assert rec.current_stage_code == "PHASE_5"
    assert rec.current_module == "STEP_13 Customs Declaration 46"
    assert rec.current_stage == "Phase 5: Port Operations & Clearance"
    assert rec.next_action_code == "NA_FOLLOW_UP_STEP"
    assert rec.next_action_params == {"step_code": "STEP_13"}
    assert rec.next_action == "Follow up STEP_13"


def test_set_file_tracking_special_stage_code_and_string_phase():
    rec = SimpleNamespace()
    set_file_tracking(rec, phase_id="PHASE_5", stage_code="CUSTOMS_RELEASED")
    assert rec.current_phase_id == 5
    assert rec.current_stage_code == "CUSTOMS_RELEASED"
    assert rec.current_stage == "Customs Released"
    assert not hasattr(rec, "current_step_code")  # untouched
    assert not hasattr(rec, "next_action")


def test_set_file_tracking_next_action_only_leaves_stage_untouched():
    rec = SimpleNamespace(current_stage="Phase 1: X", current_step_code="STEP_01")
    set_file_tracking(rec, next_action=msg("NA_CL_RECORD_INSPECTION"))
    assert rec.current_stage == "Phase 1: X"
    assert rec.current_step_code == "STEP_01"
    assert rec.next_action == "Record inspection & sampling (CL-01)"
    set_file_tracking(None, step_code="STEP_01")  # no-op, no error


def test_step_tracking_columns():
    assert step_tracking_columns("STEP_08_PO") == {
        "current_step_code": "STEP_08_PO", "current_phase_id": 3, "current_stage_code": "PHASE_3"
    }
    assert step_tracking_columns("NOT_A_STEP") == {}
    assert step_tracking_columns(None) == {}


# ── advance / sync ────────────────────────────────────────────────────────────


def test_advance_writes_codes_english_notes_tracking_and_task(db):
    repo.save_or_update_activity(db, FILE_CODE, "STEP_05", "In-Progress")
    res = service.advance_step_service(
        db, StepAdvancePayload(import_file_code=FILE_CODE, current_step_code="STEP_05", next_step_codes=[])
    )
    assert res["current_step_code"] == "STEP_06"
    assert res["current_phase_id"] == 3
    assert res["next_action_code"] == "NA_FOLLOW_UP_STEP"

    done = repo.get_activity(db, FILE_CODE, "STEP_05")
    assert done.msg_code == "LC_STEP_COMPLETED" and done.msg_params == {"step_code": "STEP_05"}
    assert done.notes == "STEP_05 completed"
    nxt = repo.get_activity(db, FILE_CODE, "STEP_06")
    assert nxt.msg_code == "LC_STEP_ACTIVATED" and nxt.notes == "Activated after STEP_05 completed"
    prior = repo.get_activity(db, FILE_CODE, "STEP_01")
    assert prior.msg_code == "LC_STEP_AUTO_COMPLETED" and prior.msg_params == {"target_step_code": "STEP_05"}

    f = _file(db)
    assert (f.current_step_code, f.current_phase_id, f.current_stage_code) == ("STEP_06", 3, "PHASE_3")
    assert f.next_action_params == {"step_code": "STEP_06"}
    _no_arabic(f.current_stage, f.current_module, f.next_action)

    task = db.query(SmartTask).filter(SmartTask.step_code == "STEP_06").one()
    assert task.msg_code == "LC_TASK_NEXT_STEP"
    assert task.msg_params == {
        "import_file_code": FILE_CODE, "step_code": "STEP_06", "completed_step_code": "STEP_05", "phase_id": 3
    }
    assert task.title == f"[{FILE_CODE}] - STEP_06"
    assert task.phase_name == "Phase 3: Booking & Doc Prep"
    _no_arabic(task.title, task.description, task.notes)
    for act in db.query(ShipmentStageActivity).all():
        _no_arabic(act.notes)


def test_advance_with_user_notes_stores_text_without_code(db):
    service.advance_step_service(
        db, StepAdvancePayload(import_file_code=FILE_CODE, current_step_code="STEP_01", notes="Checked by Ali")
    )
    act = repo.get_activity(db, FILE_CODE, "STEP_01")
    assert act.notes == "Checked by Ali" and act.msg_code is None and act.msg_params is None


def test_auto_close_matches_coded_and_legacy_tasks_and_does_not_duplicate(db):
    f = _file(db)
    legacy = task_repo.create_task(
        db,
        SmartTaskCreate(title=f"[{FILE_CODE}] — دراسات ومفاضلة نولون الشحن (STEP_01)", task_type="System Generated",
                        import_file_id=f.import_file_id, status="Pending"),
    )
    service.advance_lifecycle_step_service(db, "STEP_01", import_file_code=FILE_CODE, target_step_codes=["STEP_02"])
    db.refresh(legacy)
    assert legacy.status == "Completed" and legacy.is_auto_closed is True
    coded = db.query(SmartTask).filter(SmartTask.step_code == "STEP_02").one()
    assert coded.status == "Pending"

    # Re-activating STEP_02 must not create a second task for it.
    service.advance_lifecycle_step_service(db, "STEP_01", import_file_code=FILE_CODE, target_step_codes=["STEP_02"])
    assert db.query(SmartTask).filter(SmartTask.step_code == "STEP_02").count() == 1

    service.advance_lifecycle_step_service(db, "STEP_02", import_file_code=FILE_CODE, target_step_codes=["STEP_03"])
    db.refresh(coded)
    assert coded.status == "Completed" and coded.is_auto_closed is True


def test_next_step_task_is_flushed_not_committed(db):
    """The task joins the caller's transaction: a rollback before the caller's commit drops it."""
    f = _file(db)
    service._create_next_step_task(
        db, f, import_file_code=FILE_CODE, completed_step_code="STEP_01", next_step_code="STEP_02", phase_id=1,
        assigned_user="ops", created_by="test",
    )
    assert db.query(SmartTask).filter(SmartTask.step_code == "STEP_02").count() == 1  # visible (flushed)
    db.rollback()
    assert db.query(SmartTask).filter(SmartTask.step_code == "STEP_02").count() == 0


def test_create_task_commit_flag(db):
    t = task_repo.create_task(db, SmartTaskCreate(title="Flush only"), commit=False)
    assert t.task_id is not None
    db.rollback()
    assert db.query(SmartTask).filter(SmartTask.title == "Flush only").count() == 0
    task_repo.create_task(db, SmartTaskCreate(title="Committed"))
    db.rollback()
    assert db.query(SmartTask).filter(SmartTask.title == "Committed").count() == 1


def test_legacy_task_for_next_step_prevents_duplicate(db):
    f = _file(db)
    task_repo.create_task(
        db,
        SmartTaskCreate(title=f"[{FILE_CODE}] — الدراسات والاستشارات الجمركية (STEP_02)", task_type="System Generated",
                        import_file_id=f.import_file_id, status="Pending"),
    )
    service.advance_lifecycle_step_service(db, "STEP_01", import_file_code=FILE_CODE, target_step_codes=["STEP_02"])
    assert db.query(SmartTask).filter(SmartTask.step_code == "STEP_02").count() == 0


def test_step21_closure_sets_file_closed_next_action(db):
    service.advance_lifecycle_step_service(db, "STEP_21", import_file_code=FILE_CODE)
    f = _file(db)
    assert f.next_action_code == "NA_FILE_CLOSED" and f.next_action == "Import file closed"
    assert f.current_step_code == "STEP_21" and f.current_phase_id == 6
    assert f.progress_percent == 100.0


def test_sync_booking_confirmed_uses_codes(db):
    f = _file(db)
    service.sync_booking_lifecycle_stage(
        db, f.import_file_id, booking_code="BKG-1", booking_confirmation_no="CNF-9", vessel_name="MSC ANNA"
    )
    act = repo.get_activity(db, FILE_CODE, "STEP_06")
    assert act.msg_code == "LC_SYNC_BOOKING_CONFIRMED_DETAILS"
    assert act.msg_params == {"booking_code": "BKG-1", "confirmation_no": "CNF-9", "vessel_name": "MSC ANNA"}
    db.refresh(f)
    assert f.next_action_code == "NA_STEP07_AUDIT_ALLOCATION_VGM"
    _no_arabic(act.notes, f.next_action, f.current_module, f.current_stage)


def test_next_action_msg_and_stage_code_kwargs(db):
    service.advance_lifecycle_step_service(
        db, "STEP_17", import_file_code=FILE_CODE, target_step_codes=["STEP_18"],
        notes_msg=msg("LC_SYNC_BUDGET_APPROVED"), next_action_msg=msg("NA_CL_ISSUE_GREEN_RELEASE"),
        stage_code="CUSTOMS_RELEASED",
    )
    f = _file(db)
    assert f.current_stage_code == "CUSTOMS_RELEASED" and f.current_stage == "Customs Released"
    assert f.current_phase_id == 5
    assert f.next_action_code == "NA_CL_ISSUE_GREEN_RELEASE"
    assert repo.get_activity(db, FILE_CODE, "STEP_17").msg_code == "LC_SYNC_BUDGET_APPROVED"


def test_legacy_custom_next_action_is_stored_without_code(db):
    service.advance_lifecycle_step_service(
        db, "STEP_01", import_file_code=FILE_CODE, target_step_codes=["STEP_02"],
        custom_next_action="Legacy caller text", custom_stage_title="ignored", custom_module_name="ignored",
    )
    f = _file(db)
    assert f.next_action == "Legacy caller text" and f.next_action_code is None and f.next_action_params is None
    assert f.current_stage == "Phase 1: Pre-Planning & Studies"
    assert f.current_module == "STEP_02 Customs Studies"


def test_skip_writes_codes(db):
    from modules.lifecycle_board.model import StepConfig

    db.add(StepConfig(step_code="STEP_03", step_name_en="x", step_name_ar="x", phase_id=1, skip_policy="single_approval",
                      approver_roles=["ADMIN"], reason_categories=[]))
    db.commit()
    service.skip_step_service(
        db, SkipStepPayload(import_file_code=FILE_CODE, current_step_code="STEP_03", skip_reason="Not needed here"),
        current_user_role="ADMIN", current_username="admin",
    )
    skipped = repo.get_activity(db, FILE_CODE, "STEP_03")
    assert skipped.msg_code == "LC_STEP_SKIPPED" and skipped.notes == "Step skipped: Not needed here"
    nxt = repo.get_activity(db, FILE_CODE, "STEP_04")
    assert nxt.msg_code == "LC_STEP_ACTIVATED_AFTER_SKIP"
    task = db.query(SmartTask).filter(SmartTask.step_code == "STEP_04").one()
    assert task.msg_code == "LC_TASK_NEXT_STEP_SKIPPED"
    f = _file(db)
    assert f.current_step_code == "STEP_04" and f.next_action_code == "NA_FOLLOW_UP_STEP"


def test_initialize_lifecycle_and_board_card_expose_codes(db):
    service.initialize_file_lifecycle_service(db, FILE_CODE, "STEP_03")
    assert repo.get_activity(db, FILE_CODE, "STEP_01").msg_code == "LC_STEP_BYPASSED_FOR_LATER_START"
    start = repo.get_activity(db, FILE_CODE, "STEP_03")
    assert start.msg_code == "LC_STARTING_POINT_SET" and start.msg_params == {"step_code": "STEP_03"}

    card = next(c for c in service.get_board_summary_service(db).all_shipments if c.step_code == "STEP_03")
    assert card.msg_code == "LC_STARTING_POINT_SET"
    assert card.msg_params == {"step_code": "STEP_03"}
    assert card.notes == "Shipment starting point set to STEP_03"


def test_user_notes_overwrite_clears_stale_code(db):
    service.initialize_file_lifecycle_service(db, FILE_CODE, "STEP_01")
    repo.save_or_update_activity(db, FILE_CODE, "STEP_01", "In-Progress", notes="user text")
    act = repo.get_activity(db, FILE_CODE, "STEP_01")
    assert act.notes == "user text" and act.msg_code is None


def test_live_tracking_next_action_fallback_is_coded(db):
    f = _file(db)
    f.next_action = ""
    db.commit()
    item = next(i for i in service.get_live_logistics_tracking_service(db).items if i.import_file_code == FILE_CODE)
    assert item.next_action_code == "NA_FOLLOW_UP_STEP"
    _no_arabic(item.next_action)


# ── import_files ──────────────────────────────────────────────────────────────


def test_compute_file_formulas_returns_next_action_codes():
    assert file_service.compute_file_formulas(status_str="Closed")["next_action_code"] == "NA_FILE_FULLY_CLOSED_ARCHIVED"
    assert file_service.compute_file_formulas(form46_no="46/1")["next_action_code"] == "NA_CUSTOMS_INSPECTION_DUTY_SETTLEMENT"
    assert file_service.compute_file_formulas(form4_no="F4")["next_action_code"] == "NA_UPLOAD_CARGOX_PREPARE_DECLARATION_46"
    assert file_service.compute_file_formulas(selected_scenario="A")["next_action_code"] == "NA_CREATE_PAYMENT_REQUEST_FORM4"
    step13 = file_service.compute_file_formulas(initial_step="STEP_13")
    assert step13["next_action_code"] == "NA_VALUATION_INSPECTION_SAMPLING"
    assert step13["next_action"] == "Customs valuation, inspection & sampling"
    assert set(file_service.STEP_INITIAL_NEXT_ACTION_CODES) == set(file_service.STEP_INITIAL_CONFIG)


def test_create_close_reopen_clone_use_codes(db):
    created = file_service.create_import_file_service(
        db, ImportFileCreate(custom_file_number="FN-77", company_id=1, company_name="Egyptian Import Co",
                             supplier_name="ABC", initial_starting_step="STEP_13")
    )
    assert (created.current_step_code, created.current_phase_id, created.current_stage_code) == ("STEP_13", 5, "PHASE_5")
    assert created.next_action_code == "NA_VALUATION_INSPECTION_SAMPLING"

    closed = file_service.close_shipment_service(
        db, created.import_file_id, CloseShipmentSubmit(closure_reason="Cancelled", closed_at_phase="Phase 5")
    )
    assert closed.next_action_code == "NA_FILE_CLOSED_EARLY" and closed.next_action_params == {"phase_id": 5}
    reopened = file_service.reopen_shipment_service(
        db, created.import_file_id, ReopenShipmentSubmit(reopen_reason="Client asked")
    )
    assert reopened.next_action_code == "NA_RESUME_OPERATIONS"
    assert reopened.next_action == "Resume operations at 5. Port Operations & Clearance"

    clone = file_service.clone_import_file_service(db, created.import_file_id, CloneImportFileRequest(target_import_file_code="IMP-2026-0999"), current_user="u")
    assert clone.next_action_code == "NA_COMPLETE_CLONED_FILE" and clone.current_stage_code == "DRAFT"
    _no_arabic(clone.next_action)


def test_dashboard_phase_filter_and_counts_for_coded_and_legacy_rows(db):
    legacy = _file(db)
    legacy.current_stage = "Phase 5 - Port Operations & Clearance"  # legacy row, no current_phase_id
    coded = ImportFile(import_file_code="IMP-2026-0102", company_name="C", supplier_name="S", is_active=True,
                       current_stage="Phase 3: Import Documentation", current_phase_id=5, current_stage_code="PHASE_5")
    other = ImportFile(import_file_code="IMP-2026-0103", company_name="C", supplier_name="S", is_active=True,
                       current_stage="Phase 5 text but coded 2", current_phase_id=2)
    ten = ImportFile(import_file_code="IMP-2026-0104", company_name="C", supplier_name="S", is_active=True,
                     current_stage="Phase 10 - Closure")
    db.add_all([coded, other, ten])
    db.commit()

    codes = {f.import_file_code for f in file_repo.get_operational_dashboard_data(db, phase="Phase 5")["shipments"]}
    assert codes == {FILE_CODE, "IMP-2026-0102"}
    codes = {f.import_file_code for f in file_repo.get_operational_dashboard_data(db, phase="Phase 3")["shipments"]}
    assert codes == set()  # coded row's legacy text is ignored
    counts = file_repo.get_operational_dashboard_data(db)["phase_counts"]
    assert counts["Phase 5"] == 2 and counts["Phase 2"] == 1 and counts["Phase 10"] == 1 and counts["Phase 1"] == 0
    # Free-text filter still works on legacy text.
    codes = {f.import_file_code for f in file_repo.get_operational_dashboard_data(db, phase="Closure")["shipments"]}
    assert codes == {"IMP-2026-0104"}


# ── smart_tasks ───────────────────────────────────────────────────────────────


def test_auto_generated_phase_task_is_coded_and_not_duplicated(db):
    f = _file(db)
    f.current_module = "Phase 1 - Planning"
    db.commit()
    task_service.auto_generate_system_tasks_for_file(db, f)
    task_service.auto_generate_system_tasks_for_file(db, f)
    tasks = db.query(SmartTask).filter(SmartTask.import_file_id == f.import_file_id).all()
    assert len(tasks) == 1  # "Phase 1" must not also match "Phase 10"
    t = tasks[0]
    assert t.msg_code == "TASK_AUTO_PHASE_FOLLOW_UP"
    assert t.msg_params["task_enum_phase_follow_up_task"] == "FREIGHT_SCENARIO_FOLLOW_UP"
    assert t.title == f"{FILE_CODE} - Follow up freight studies, scenarios and line availability"
    _no_arabic(t.title, t.description, t.notes)


def test_legacy_arabic_phase_task_prevents_duplicate(db):
    f = _file(db)
    f.current_module = "Phase 2 - Approvals"
    db.commit()
    task_repo.create_task(db, SmartTaskCreate(title=f"{FILE_CODE} — متابعة الاعتماد والموافقة المالية وصرف الدفعة",
                                              import_file_id=f.import_file_id))
    task_service.auto_generate_system_tasks_for_file(db, f)
    assert db.query(SmartTask).filter(SmartTask.import_file_id == f.import_file_id).count() == 1


def test_user_edit_of_coded_text_clears_code_but_status_change_keeps_it(db):
    f = _file(db)
    f.current_module = "Phase 1"
    db.commit()
    task_service.auto_generate_system_tasks_for_file(db, f)
    task = db.query(SmartTask).one()
    same = task_service.update_task_service(db, task.task_id, SmartTaskUpdate(status="In Progress", title=task.title))
    assert same.msg_code == "TASK_AUTO_PHASE_FOLLOW_UP"
    edited = task_service.update_task_service(db, task.task_id, SmartTaskUpdate(title="My own title"))
    assert edited.msg_code is None and edited.msg_params is None and edited.title == "My own title"


def test_user_created_task_never_has_code(db):
    t = task_service.create_task_service(db, SmartTaskCreate(title="Call the broker"))
    assert t.msg_code is None and t.step_code is None


# ── smart_email_listener ──────────────────────────────────────────────────────


def test_email_delivery_order_task_is_coded_with_verbatim_reference(db):
    f = _file(db)
    task = email_repo.create_delivery_order_payment_task(
        db, f, eta_date=date(2026, 10, 5), match_reason="أمر الشراء PO [PO-555]"
    )
    assert task.msg_code == "EMAIL_TASK_DELIVERY_ORDER_PAYMENT"
    assert task.msg_params["import_file_code"] == FILE_CODE
    assert task.msg_params["reference"] == "PO-555"
    assert task.notes == "Auto-generated by the smart email listener based on: PO-555"
    _no_arabic(task.title, task.description, task.notes)


def test_email_parse_log_notes_are_coded(db):
    from modules.smart_email_listener.model import InboundEmailLog
    from modules.smart_email_listener.schemas import InboundEmailCreate
    from modules.smart_email_listener.service import process_inbound_email_service

    res = process_inbound_email_service(
        db, InboundEmailCreate(sender_email="ops@line.com", subject="Arrival notice",
                               body_text="B/L No: MSKU99887766 vessel arriving"),
    )
    log = db.query(InboundEmailLog).one()
    assert log.msg_code == "EMAIL_PARSE_UNMATCHED_BL" and log.msg_params == {"bl_number": "MSKU99887766"}
    assert log.notes == "B/L [MSKU99887766] was extracted but no active shipment is registered with this number."
    assert res.summary_message  # the HTTP message is unchanged


def test_email_sync_status_coded_and_plain(db):
    from modules.smart_email_listener.model import EmailSettings

    db.add(EmailSettings(email_address="u@x.com", username="u@x.com", password="", imap_host="imap.x.com"))
    db.commit()
    s = email_repo.update_email_settings_sync_status(
        db, "SUCCESS", msg("EMAIL_SYNC_SUMMARY", count=3, matched_count=1, tasks_count=1)
    )
    assert s.msg_code == "EMAIL_SYNC_SUMMARY" and s.msg_params == {"count": 3, "matched_count": 1, "tasks_count": 1}
    assert s.last_sync_message == "Scanned 3 e-mails, matched 1 shipments and created 1 payment tasks."
    s = email_repo.update_email_settings_sync_status(db, "SUCCESS", "All emails synced.")
    assert s.msg_code is None and s.msg_params is None and s.last_sync_message == "All emails synced."


def test_email_approve_tasks_codes_only_server_written_text(db):
    f = _file(db)
    count, ids = email_repo.batch_approve_and_route_tasks(
        db,
        [
            {"import_file_id": f.import_file_id, "import_file_code": FILE_CODE, "reminder_type": "A"},
            {"import_file_id": f.import_file_id, "import_file_code": FILE_CODE, "reminder_type": "B",
             "title": "User title"},
        ],
        user_name="kamal",
    )
    assert count == 2
    server, user = (db.get(SmartTask, i) for i in ids)
    assert server.msg_code == "EMAIL_TASK_APPROVED" and server.msg_params == {"import_file_code": FILE_CODE, "user_name": "kamal"}
    assert server.notes == "Approved and routed by user: kamal"
    assert user.msg_code is None and user.title == "User title"
    _no_arabic(server.title, server.description, server.notes, user.notes)
