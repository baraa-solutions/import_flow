"""
Unit Tests for Shipment Stage Activity & 6-Phase Lifecycle Board
"""

import main
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.lifecycle_board.model import ShipmentStageActivity
import modules.lifecycle_board.service as service
import modules.lifecycle_board.repository as repo
from modules.lifecycle_board.schemas import StepAdvancePayload, SkipStepPayload, MultiStageSetPayload


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()


    # Seed an import file
    file1 = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="Al-Ahram Industrial",
        supplier_name="Global Steel Italy",
        po_number="PO-2026-101",
        shipment_mode="Sea FCL",
        incoterm_code="FOB",
        priority="High",
        estimated_cost=45000.0,
        estimated_cost_currency="USD",
        status="Draft",
        is_active=True,
    )
    session.add(file1)
    act1 = ShipmentStageActivity(
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="In-Progress",
        started_at="2026-10-08 10:00:00",
    )
    session.add(act1)
    session.commit()

    yield session
    session.close()


def test_board_summary_generation(db_session):
    summary = service.get_board_summary_service(db_session)
    assert len(summary.phases) == 6
    assert summary.total_active_files >= 1
    assert summary.phases[0].phase_id == 1
    assert summary.phases[0].title_en == "1. Pre-Planning & Studies"


def test_set_multi_active_stages(db_session):
    payload = MultiStageSetPayload(
        import_file_code="IMP-2026-0001",
        active_step_codes=["STEP_01", "STEP_02", "STEP_03"],
        notes="Multiple studies concurrently",
    )
    res = service.set_multi_active_stages_service(db_session, payload)
    assert len(res["active_steps"]) == 3

    # Check repository
    acts = repo.get_all_activities(db_session, import_file_code="IMP-2026-0001", status="In-Progress")
    assert len(acts) == 3


def test_advance_step_service(db_session):
    # Set step 1
    repo.save_or_update_activity(
        db_session,
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="In-Progress",
    )

    # Advance to step 4
    advance_payload = StepAdvancePayload(
        import_file_code="IMP-2026-0001",
        current_step_code="STEP_01",
        next_step_codes=["STEP_04"],
        notes="Freight study MSC approved, moving to finance",
    )
    res = service.advance_step_service(db_session, advance_payload)
    assert res["completed_step"] == "STEP_01"
    assert res["activated_steps"] == ["STEP_04"]

    step1 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_01")
    assert step1.status == "Completed"

    step4 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_04")
    assert step4.status == "In-Progress"


def test_skip_step_service(db_session):
    # Set step 6 (Freight booking)
    repo.save_or_update_activity(
        db_session,
        import_file_code="IMP-2026-0001",
        step_code="STEP_06",
        status="In-Progress",
    )

    # Configure STEP_06 as skippable per Section 10
    from modules.lifecycle_board.schemas import StepConfigUpdateRequest
    service.update_step_config_service(
        db_session,
        step_code="STEP_06",
        payload=StepConfigUpdateRequest(
            skip_policy="single_approval",
            approver_roles=["Manager"],
            justification="Allow CIF shipment freight skip per SLA",
        ),
        current_user_role="MANAGER",
    )

    # Skip step 6 because terms are CIF (freight handled by supplier) and advance to STEP_08 (Draft Docs Review)
    skip_payload = SkipStepPayload(
        import_file_code="IMP-2026-0001",
        current_step_code="STEP_06",
        skip_reason="شحنة بنظام CIF - النولون مسدد ومحجوز من المورد الأجنبي",
        next_step_codes=["STEP_08"],
    )
    res = service.skip_step_service(db_session, skip_payload, current_user_role="MANAGER")
    assert res["skipped_step"] == "STEP_06"
    assert res["activated_steps"] == ["STEP_08"]

    step6 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_06")
    assert step6.status == "Skipped"
    assert "CIF" in step6.notes

    step8 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_08")
    assert step8.status == "In-Progress"

    # Check that ImportFile has STEP_06 in skipped_stages
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    assert "STEP_06" in file1.skipped_stages


def test_initialize_file_lifecycle_service_from_custom_step(db_session):
    # Initialize a new shipment file starting from STEP_13 (Customs Clearance Declaration 46)
    service.initialize_file_lifecycle_service(db_session, "IMP-2026-0001", starting_step="STEP_13")

    # Verify that prior steps 1..12 are marked Completed
    for i in range(1, 13):
        code = f"STEP_{str(i).zfill(2)}"
        act = repo.get_activity(db_session, "IMP-2026-0001", code)
        assert act is not None
        assert act.status == "Completed"

    # Verify that STEP_13 is In-Progress
    step13 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_13")
    assert step13 is not None
    assert step13.status == "In-Progress"


def test_hold_and_resume_activities(db_session):
    # Set step 13 In-Progress
    repo.save_or_update_activity(
        db_session,
        import_file_code="IMP-2026-0001",
        step_code="STEP_13",
        status="In-Progress",
    )

    # Hold shipment
    service.hold_shipment_activities_service(db_session, "IMP-2026-0001", "في انتظار موافقة هيئة الرقابة على الصادرات والواردات")
    step13 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_13")
    assert step13.status == "On-Hold"
    assert "في انتظار موافقة" in step13.notes

    # Resume shipment
    service.resume_shipment_activities_service(db_session, "IMP-2026-0001", "تم صدور الموافقة الرقابية")
    step13_resumed = repo.get_activity(db_session, "IMP-2026-0001", "STEP_13")
    assert step13_resumed.status == "In-Progress"
    assert "تم صدور الموافقة" in step13_resumed.notes


def test_previous_and_next_step_tracking(db_session):
    # Set STEP_02 as current active step for IMP-2026-0001
    repo.save_or_update_activity(
        db_session,
        import_file_code="IMP-2026-0001",
        step_code="STEP_01",
        status="Completed",
        completed_at="2026-08-31 10:00:00",
    )
    repo.save_or_update_activity(
        db_session,
        import_file_code="IMP-2026-0001",
        step_code="STEP_02",
        status="In-Progress",
        started_at="2026-08-31 10:05:00",
    )

    summary = service.get_board_summary_service(db_session)
    matching = [s for s in summary.all_shipments if s.import_file_code == "IMP-2026-0001"]
    assert len(matching) == 1
    card = matching[0]

    # Verify Previous, Current, and Next steps
    assert card.step_code == "STEP_02"
    assert card.step_name_ar == "الدراسات والاستشارات الجمركية"
    assert card.previous_step_code == "STEP_01"
    assert card.previous_step_name_ar == "دراسات ومفاضلة نولون الشحن"
    assert card.next_step_code == "STEP_03"
    assert card.next_step_name_ar == "متطلبات واشتراطات الاستيراد للشحنة"


def test_sync_consultation_lifecycle_stage(db_session):
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    assert file1 is not None

    # Call sync
    service.sync_consultation_lifecycle_stage(db_session, file1.import_file_id)

    # Check that STEP_01 is Completed and STEP_02 is In-Progress
    step1 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_01")
    assert step1.status == "Completed"

    step2 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_02")
    assert step2.status == "In-Progress"

    # Check that ImportFile next action points to STEP_03
    db_session.refresh(file1)
    assert "STEP_02" in file1.current_module
    assert file1.next_action_code == "NA_STEP03_REVIEW_REGULATORY_APPROVALS"
    assert file1.next_action == "Review the shipment's import requirements and regulatory approvals"


def test_sync_budget_lifecycle_stage(db_session):
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    assert file1 is not None

    # Case 1: Budget created but not approved yet -> moves to STEP_04 In-Progress
    service.sync_budget_lifecycle_stage(db_session, file1.import_file_id, is_approved=False)
    db_session.refresh(file1)

    step1 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_01")
    assert step1.status == "Completed"
    step2 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_02")
    assert step2.status == "Completed"
    step3 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_03")
    assert step3.status == "Completed"
    step4 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_04")
    assert step4.status == "In-Progress"
    assert file1.current_stage == "Phase 2: Shipment Initiation"
    assert file1.current_phase_id == 2
    assert "STEP_04" in file1.current_module

    # Case 2: Budget approved -> completes STEP_04 and activates STEP_05 (ACID)
    service.sync_budget_lifecycle_stage(db_session, file1.import_file_id, is_approved=True, approved_by="Finance Admin")
    db_session.refresh(file1)

    step4 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_04")
    assert step4.status == "Completed"
    step5 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_05")
    assert step5.status == "In-Progress"
    assert file1.current_stage == "Phase 2: Shipment Initiation"
    assert "STEP_05" in file1.current_module
    assert file1.current_step_code == "STEP_05"
    assert file1.next_action_code == "NA_STEP05_REQUEST_ACID"


def test_full_stage_advancement_and_phase_transition(db_session):
    from modules.smart_tasks.model import SmartTask

    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    assert file1 is not None

    # Start at STEP_05 (in Phase 2)
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_05", "In-Progress")
    file1.current_stage = "Phase 2: Approvals & ACID"
    file1.current_module = "STEP_05 إصدار رقم ACID نافذة"
    file1.acid_number = "5281534391025810014"
    db_session.commit()

    # Advance without next_step_codes -> should auto-infer STEP_06 (Phase 3 transition)
    payload = StepAdvancePayload(
        import_file_code="IMP-2026-0001",
        current_step_code="STEP_05",
        next_step_codes=[], # auto-infer
        notes="تم استخراج وتوثيق رقم ACID بنجاح",
    )
    res = service.advance_step_service(db_session, payload)
    assert res["completed_step"] == "STEP_05"
    assert res["activated_steps"] == ["STEP_06"]

    # Verify activities
    act_step5 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_05")
    assert act_step5.status == "Completed"
    act_step6 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_06")
    assert act_step6.status == "In-Progress"

    # Verify ImportFile updated to Phase 3
    db_session.refresh(file1)
    assert file1.current_stage == "Phase 3: Booking & Doc Prep"
    assert "STEP_06" in file1.current_module
    assert file1.current_module == "STEP_06 Freight Booking"
    assert file1.progress_percent >= 24.0

    # Verify SmartTask created for STEP_06
    task = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == file1.import_file_id,
        SmartTask.title.ilike("%STEP_06%"),
        SmartTask.is_active == True,
    ).first()
    assert task is not None
    assert task.status == "Pending"

    # Advance to Final Step STEP_21
    payload_final = StepAdvancePayload(
        import_file_code="IMP-2026-0001",
        current_step_code="STEP_20",
        next_step_codes=["STEP_21"],
    )
    service.advance_step_service(db_session, payload_final)
    db_session.refresh(file1)
    assert file1.current_stage == "Phase 6: Inbound & Final Closure"
    assert "STEP_21" in file1.current_module
    assert file1.progress_percent == 100.0


def test_sync_booking_lifecycle_stage(db_session):
    from modules.smart_tasks.model import SmartTask
    from modules.lifecycle_board.service import sync_booking_lifecycle_stage

    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    file1.acid_number = "5281534391023010013"
    db_session.commit()

    # Call sync_booking_lifecycle_stage with confirmed booking
    sync_booking_lifecycle_stage(
        db=db_session,
        import_file_id=file1.import_file_id,
        booking_code="BKG-2026-0001",
        booking_confirmation_no="MSC-CN-889001",
        is_confirmed=True,
        vessel_name="MSC ISABELLA",
    )

    db_session.refresh(file1)
    assert file1.current_stage == "Phase 3: Booking & Doc Prep"
    assert "STEP_07" in file1.current_module
    assert file1.progress_percent >= 50.0

    # Verify activities
    act_step5 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_05")
    assert act_step5.status == "Completed"

    act_step6 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_06")
    assert act_step6.status == "Completed"
    assert "MSC-CN-889001" in act_step6.notes

    act_step7 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_07")
    assert act_step7.status == "In-Progress"

    # Verify smart task created for STEP_07
    task7 = db_session.query(SmartTask).filter(
        SmartTask.import_file_id == file1.import_file_id,
        SmartTask.title.ilike("%STEP_07%"),
        SmartTask.is_active == True,
    ).first()
    assert task7 is not None
    assert task7.status == "Pending"


def test_generic_advance_lifecycle_step_auto_reconciliation(db_session):
    """
    Validates that leaping to a later milestone (e.g. STEP_06) automatically reconciles
    all prior steps (STEP_01 to STEP_05), preventing the shipment from being trapped
    in earlier phases on the lifecycle board.
    """
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    assert file1 is not None

    # Step 1 was initially In-Progress
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_01", "In-Progress")

    # Now execute generic advance on STEP_06 with target STEP_07
    res = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_06",
        target_step_codes=["STEP_07"],
        auto_complete_prior=True,
        notes="Booking confirmed on vessel EVER GIVEN",
        source_module="Freight Booking",
    )

    assert res["completed_step"] == "STEP_06"
    assert "STEP_07" in res["activated_steps"]
    assert "STEP_01" in res["auto_completed_prior_steps"]

    # Verify all prior steps are marked Completed
    for i in range(1, 6):
        code = f"STEP_{str(i).zfill(2)}"
        act = repo.get_activity(db_session, "IMP-2026-0001", code)
        assert act is not None, f"Expected {code} activity to exist"
        assert act.status == "Completed", f"Expected {code} to be Completed, got {act.status}"

    # Verify STEP_06 is Completed and STEP_07 is In-Progress
    step6 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_06")
    assert step6.status == "Completed"
    step7 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_07")
    assert step7.status == "In-Progress"

    # Verify that board active query ONLY returns STEP_07 for this shipment (no duplicate phase cards)
    active_cards = repo.get_active_shipments_with_details(db_session)
    matching_cards = [c for c in active_cards if c[0].import_file_code == "IMP-2026-0001"]
    assert len(matching_cards) == 1
    assert matching_cards[0][0].step_code == "STEP_07"


def test_generic_advance_lifecycle_step_idempotency(db_session):
    """
    Validates that calling advance_lifecycle_step_service repeatedly with the same
    parameters produces the exact same clean state without duplicating activities or failing.
    """
    # First invocation
    res1 = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_03",
        target_step_codes=["STEP_04"],
    )
    # Second invocation (idempotency check)
    res2 = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_03",
        target_step_codes=["STEP_04"],
    )

    assert res1["completed_step"] == res2["completed_step"]
    assert res1["activated_steps"] == res2["activated_steps"]

    # Ensure no duplicates in DB
    all_acts = repo.get_all_activities(db_session, import_file_code="IMP-2026-0001")
    step3_records = [a for a in all_acts if a.step_code == "STEP_03"]
    step4_records = [a for a in all_acts if a.step_code == "STEP_04"]
    assert len(step3_records) == 1
    assert len(step4_records) == 1


def test_generic_advance_lifecycle_step_natural_next_inference(db_session):
    """
    Validates that when target_step_codes is None, the engine automatically infers
    the sequential natural next step.
    """
    res = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_10",
        target_step_codes=None, # should auto-infer STEP_11
    )
    assert res["completed_step"] == "STEP_10"
    assert res["activated_steps"] == ["STEP_11"]

    step11 = repo.get_activity(db_session, "IMP-2026-0001", "STEP_11")
    assert step11.status == "In-Progress"


def test_generic_advance_lifecycle_step_by_file_id(db_session):
    """
    Validates that passing import_file_id without import_file_code resolves properly.
    """
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    res = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_id=file1.import_file_id,
        completed_step_code="STEP_08",
        target_step_codes=["STEP_09"],
    )
    assert res["import_file_code"] == "IMP-2026-0001"
    assert res["completed_step"] == "STEP_08"
    assert res["activated_steps"] == ["STEP_09"]


def test_generic_advance_lifecycle_step_final_closure(db_session):
    """
    Validates that completing STEP_21 transitions shipment to Phase 6 with 100% progress.
    """
    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == "IMP-2026-0001").first()
    res = service.advance_lifecycle_step_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_21",
        target_step_codes=None,
    )
    assert res["completed_step"] == "STEP_21"
    assert res["activated_steps"] == []
    assert res["progress_percent"] == 100.0

    db_session.refresh(file1)
    assert file1.current_stage == "Phase 6: Inbound & Final Closure"
    assert file1.progress_percent == 100.0


def test_sync_lifecycle_step_api(db_session):
    """
    Tests the POST /api/v1/lifecycle-board/stages/sync endpoint via FastAPI TestClient.
    """
    from fastapi.testclient import TestClient
    from database.database import get_db

    app = main.app

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_06", status="In-Progress")
    try:
        with TestClient(app) as client:
            payload = {
                "completed_step_code": "STEP_06",
                "import_file_code": "IMP-2026-0001",
                "target_step_codes": ["STEP_07"],
                "auto_complete_prior": True,
                "notes": "Freight booking confirmed via API",
                "source_module": "API Test",
            }
            resp = client.post("/api/v1/lifecycle-board/stages/sync", json=payload)
            assert resp.status_code == 200, resp.text
            data = resp.json()
            assert data["completed_step"] == "STEP_06"
            assert "STEP_07" in data["activated_steps"]
            assert "STEP_01" in data["auto_completed_prior_steps"]
    finally:
        app.dependency_overrides.clear()


def test_transition_stage_activity_service_wrapper(db_session):
    """Verify that transition_stage_activity_service functions seamlessly for 25-step sub-step transitions."""
    res = service.transition_stage_activity_service(
        db=db_session,
        import_file_code="IMP-2026-0001",
        completed_step_code="STEP_08_MATCH",
        target_step_codes=["STEP_08_COO"],
        notes="Testing automated 25-step sub-step transition",
        performed_by="Compliance Officer",
    )
    assert res["completed_step"] == "STEP_08_MATCH"
    assert "STEP_08_COO" in res["activated_steps"]
    assert "Phase 3" in res["current_stage"]


def test_25_steps_ordered_flow_and_neighbors():
    """Verify all 25 steps in ORDERED_STEP_CODES and neighbor resolution."""
    assert len(service.ORDERED_STEP_CODES) == 25
    assert "STEP_08_PO" in service.ORDERED_STEP_CODES
    assert "STEP_08_BL" in service.ORDERED_STEP_CODES
    assert "STEP_08_MATCH" in service.ORDERED_STEP_CODES
    assert "STEP_08_COO" in service.ORDERED_STEP_CODES
    assert "STEP_08_COC" in service.ORDERED_STEP_CODES
    assert "STEP_15" in service.ORDERED_STEP_CODES
    assert "STEP_16" in service.ORDERED_STEP_CODES
    assert "STEP_18" in service.ORDERED_STEP_CODES

    # Verify legacy STEP_08 neighbor fallback
    prev_code, next_code = service.get_step_neighbors("STEP_08")
    assert prev_code == "STEP_07"
    assert next_code == "STEP_08_PO"

    # Verify sequential neighbors across sub-steps
    prev_po, next_po = service.get_step_neighbors("STEP_08_PO")
    assert prev_po == "STEP_07"
    assert next_po == "STEP_08_BL"

    prev_coc, next_coc = service.get_step_neighbors("STEP_08_COC")
    assert prev_coc == "STEP_08_COO"
    assert next_coc == "STEP_09"


def test_initialize_file_lifecycle_from_alphanumeric_substep(db_session):
    """Verify initialize_file_lifecycle_service gracefully handles alphanumeric 25-step codes like STEP_08_COO."""
    file2 = ImportFile(
        import_file_code="IMP-2026-0002",
        company_name="Al-Ahram Industrial",
        supplier_name="Global Steel Italy",
        status="Draft",
        is_active=True,
    )
    db_session.add(file2)
    db_session.commit()

    # Initialize from STEP_08_COO
    service.initialize_file_lifecycle_service(db_session, "IMP-2026-0002", starting_step="STEP_08_COO")

    # Verify prior steps up to STEP_08_MATCH are Completed
    assert repo.get_activity(db_session, "IMP-2026-0002", "STEP_01").status == "Completed"
    assert repo.get_activity(db_session, "IMP-2026-0002", "STEP_07").status == "Completed"
    assert repo.get_activity(db_session, "IMP-2026-0002", "STEP_08_PO").status == "Completed"
    assert repo.get_activity(db_session, "IMP-2026-0002", "STEP_08_BL").status == "Completed"
    assert repo.get_activity(db_session, "IMP-2026-0002", "STEP_08_MATCH").status == "Completed"

    # Verify target step is In-Progress
    coo = repo.get_activity(db_session, "IMP-2026-0002", "STEP_08_COO")
    assert coo is not None
    assert coo.status == "In-Progress"


def test_kpi_engine_and_phase_summary_metrics(db_session):
    """
    Test ShipmentKpiMetrics calculation:
    - health_score_pct = (completed + skipped) / 25 * 100
    - free_time_burn_pct and free_days_remaining
    - cost_variance_pct
    - overdue_steps_count and risk_level (SAFE, WARNING, CRITICAL)
    - PhaseSummary pending_shipments_count & delayed_shipments_count
    """
    from datetime import datetime, timedelta
    from modules.lifecycle_board.schemas import ShipmentKpiMetrics

    # Initially IMP-2026-0001 has STEP_01 In-Progress (started_at was 2026-10-08, which is > 3 days SLA from today)
    summary = service.get_board_summary_service(db_session)
    assert len(summary.all_shipments) >= 1
    card = next(c for c in summary.all_shipments if c.import_file_code == "IMP-2026-0001")
    
    assert card.kpi_metrics is not None
    assert isinstance(card.kpi_metrics, ShipmentKpiMetrics)
    assert card.kpi_metrics.health_score_pct == 0.0
    assert card.kpi_metrics.free_time_burn_pct == 0.0
    assert card.kpi_metrics.free_days_remaining == 21
    # 22 days elapsed > 3 days SLA -> 1 overdue step -> WARNING
    assert card.kpi_metrics.overdue_steps_count == 1
    assert card.kpi_metrics.risk_level == "WARNING"
    assert "STEP_02" in card.pending_step_codes
    assert "STEP_21" in card.pending_step_codes
    assert card.skipped_step_codes == []

    # Reset started_at to now -> should become SAFE with 0 overdue
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_01", "In-Progress", started_at=now_str)
    summary_fresh = service.get_board_summary_service(db_session)
    card_fresh = next(c for c in summary_fresh.all_shipments if c.import_file_code == "IMP-2026-0001")
    assert card_fresh.kpi_metrics.overdue_steps_count == 0
    assert card_fresh.kpi_metrics.risk_level == "SAFE"

    # Phase 1 summary from initial summary (with overdue step) should show 1 delayed shipment
    phase_1 = next(p for p in summary.phases if p.phase_id == 1)
    assert phase_1.total_active_shipments == 1
    assert phase_1.pending_shipments_count >= 1
    assert phase_1.delayed_shipments_count == 1

    # Fresh phase 1 summary after resetting started_at should have 0 delayed shipments
    phase_1_fresh = next(p for p in summary_fresh.phases if p.phase_id == 1)
    assert phase_1_fresh.delayed_shipments_count == 0

    # Test alias get_lifecycle_board_summary
    alias_summary = service.get_lifecycle_board_summary(db_session)
    assert alias_summary.total_active_files == summary.total_active_files

    # Now let's complete 4 steps and skip 1 step -> 5 / 25 * 100 = 20.0%
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    for sc in ["STEP_01", "STEP_02", "STEP_03", "STEP_04"]:
        repo.save_or_update_activity(db_session, "IMP-2026-0001", sc, "Completed", completed_at=now_str)
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_05", "Skipped", completed_at=now_str)
    # Activate STEP_06
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_06", "In-Progress", started_at=now_str)

    summary2 = service.get_board_summary_service(db_session)
    card2 = next(c for c in summary2.all_shipments if c.import_file_code == "IMP-2026-0001")
    assert card2.kpi_metrics.health_score_pct == 20.0  # (4 + 1) / 25 * 100
    assert "STEP_05" in card2.skipped_step_codes
    assert "STEP_01" not in card2.pending_step_codes
    assert "STEP_07" in card2.pending_step_codes

    # Now simulate an overdue delay: step started 10 days ago (SLA is 3 days)
    old_date = (datetime.now() - timedelta(days=10)).strftime("%Y-%m-%d %H:%M:%S")
    repo.save_or_update_activity(db_session, "IMP-2026-0001", "STEP_06", "In-Progress", started_at=old_date)

    summary3 = service.get_board_summary_service(db_session)
    card3 = next(c for c in summary3.all_shipments if c.import_file_code == "IMP-2026-0001")
    assert card3.kpi_metrics.overdue_steps_count >= 1
    assert card3.kpi_metrics.risk_level in ["WARNING", "CRITICAL"]

    phase_3 = next(p for p in summary3.phases if p.phase_id == 3)
    assert phase_3.delayed_shipments_count >= 1







