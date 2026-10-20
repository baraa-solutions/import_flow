"""
Test Session 4: Shipment IMP-2026-0005 Operational Workflow
TSK-2026-0020 — Confirm freight booking and shipping line (BK-01)
Checklist: Fulfill 24 pre-shipment and policy setup items
Expected result: Confirmed booking, auto-transition to STEP_07 (Freight Allocations), gatekeeper clear.
"""

from datetime import datetime, date, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import database.models
from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.currencies.model import Currency
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.smart_checklists.model import ImportFileChecklistItem
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.freight_booking.model import ShipmentBooking
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.freight_booking.schemas import (
    ShipmentBookingCreate,
    ShipmentBookingConfirm,
    ContainerAllocationItem,
    BookingChargeItem,
)
from modules.freight_booking.service import (
    create_booking_service,
    confirm_booking_service,
)
from modules.smart_checklists.service import (
    get_checklist_summary,
    check_gatekeeper,
    auto_sync_checklist,
)


@pytest.fixture
def session4_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSession()

    # Currencies
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    egp = Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    db.add_all([usd, egp])

    # Import Company & Supplier
    comp = ImportCompany(
        company_id=2,
        importer_name="SCAS For Construction And Finishing",
        importer_id="IMP-002",
        importer_id_expiry=date(2028, 1, 1),
        vat_id="200-300-400",
        vat_id_expiry=date(2028, 1, 1),
        registration_number="12345",
        registration_expiry=date(2028, 1, 1),
        address="Cairo",
        country="Egypt",
    )
    sup = Supplier(
        supplier_id=2,
        company_name="Suzhou Yuheng Textile Co.,Ltd",
        supplier_code="SUP-YH-02",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="CN-YH-2026",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        address="No.16 Kangsheng Road, Suzhou, China",
    )
    inco = Incoterm(incoterm_id=1, incoterm_code="EXW", incoterm_name="Ex Works")
    proj = Project(
        project_id=5,
        project_code="PRJ-PET-05",
        project_name="PET Stock -YH20260901-3",
        project_owner="Kamal",
        company_id=2,
        supplier_id=2,
        incoterm_id=1,
    )
    db.add_all([comp, sup, inco, proj])

    # Import File 5 (IMP-2026-0005)
    file5 = ImportFile(
        import_file_id=5,
        import_file_code="IMP-2026-0005",
        custom_file_number="PET Stock -YH20260901-3",
        company_id=2,
        company_name="SCAS For Construction And Finishing",
        supplier_id=2,
        supplier_name="Suzhou Yuheng Textile Co.,Ltd",
        po_number="PO-2026-005",
        po_ids="[5]",
        pi_number="YH20260901-3",
        shipment_mode="Sea FCL",
        incoterm_code="EXW",
        priority="High",
        shipment_category="New Purchase",
        required_eta=date(2026, 10, 31),
        file_opening_date=date(2026, 9, 15),
        port_of_loading="Shanghai Port",
        port_of_discharge="Alexandria Port",
        cargo_ready_date=date(2026, 9, 22),
        target_free_days=21,
        acid_number="5281534391025810014",
        current_stage="Phase 3: Booking & Doc Prep",
        current_step_code="STEP_06",
        current_phase_id=3,
        current_module="STEP_06 Freight Booking",
        progress_percent=45.0,
        status="Open",
        owner="Kamal",
        is_active=True,
    )
    db.add(file5)

    # Operational Task: TSK-2026-0020 (BK-01)
    task20 = SmartTask(
        task_id=20,
        task_code="TSK-2026-0020",
        title="Confirm the freight booking and the shipping line: IMP-2026-0005 (BK-01)",
        description="ACID 5281534391025810014 issued. Confirm the booking (Booking No) with shipping line.",
        task_type="System Generated",
        import_file_id=5,
        import_file_code="IMP-2026-0005",
        phase_name="Phase 3: Booking & Doc Prep",
        assigned_user="Logistics Officer",
        priority="High",
        status="Pending",
        step_code=None,
        msg_code="DOC_TASK_FREIGHT_BOOKING",
        is_active=True,
    )
    db.add(task20)

    # Shipping Scenario Session & Quotation Offer
    scen_session = ShippingEvaluationSession(
        session_id=2,
        session_code="SCE-2026-002",
        title="[PET Stock] SCAS For Construction And Finishing",
        cargo_ready_date=date(2026, 8, 26),
        import_file_id=5,
        is_active=True,
    )
    db.add(scen_session)

    scen_item = ShippingScenarioItem(
        item_id=3,
        session_id=2,
        provider_name="Wan Hai Lines Ltd.",
        vessel_name="WAN HAI 511",
        voyage_number="V.W112",
        pol_name="Shanghai Port",
        pod_name="Alexandria Port",
        sailing_date=date(2026, 9, 25),
        estimated_arrival_date=date(2026, 10, 23),
        free_time_days=21,
        quotation_currency="USD",
        total_quotation_amount=7780.0,
        container_40ft_applicable=1,
        container_40ft_price=6700.0,
        container_40ft_currency="USD",
        container_40ft_qty=1,
        others_fee_applicable=1,
        others_fee_price=1080.0,
        others_fee_currency="USD",
        is_selected=False,
        is_recommended=True,
        is_excluded_from_average=False,
    )
    db.add(scen_item)

    # Prior lifecycle stage activity for STEP_05 and initial STEP_06
    act5 = ShipmentStageActivity(
        import_file_code="IMP-2026-0005",
        step_code="STEP_05",
        status="Completed",
        completion_type="real",
        started_at=datetime(2026, 9, 15, 10, 0),
        completed_at=datetime(2026, 9, 18, 12, 0),
    )
    act6 = ShipmentStageActivity(
        import_file_code="IMP-2026-0005",
        step_code="STEP_06",
        status="In-Progress",
        started_at=datetime(2026, 9, 18, 12, 0),
    )
    db.add_all([act5, act6])
    db.commit()

    try:
        yield db
    finally:
        db.close()


class TestSession4ShipmentIMP20260005:

    def test_full_operational_workflow_session_4(self, session4_db):
        db = session4_db

        # 1. Verify pre-conditions
        file_rec = db.query(ImportFile).filter(ImportFile.import_file_id == 5).first()
        assert file_rec.current_step_code == "STEP_06"
        assert file_rec.status == "Open"
        assert file_rec.booking_no is None

        task_bk01 = db.query(SmartTask).filter(SmartTask.task_code == "TSK-2026-0020").first()
        assert task_bk01.status == "Pending"
        assert task_bk01.is_auto_closed is None or task_bk01.is_auto_closed is False

        # 2. Select winning freight quote
        scen = db.query(ShippingScenarioItem).filter(ShippingScenarioItem.item_id == 3).first()
        scen.is_selected = True
        db.commit()
        assert scen.is_selected is True

        # 3. Create Draft Booking for IMP-2026-0005
        create_payload = ShipmentBookingCreate(
            import_file_id=5,
            scenario_session_id=2,
            scenario_item_id=3,
            scenario_provider_name="Wan Hai Lines Ltd.",
            shipping_line_name="Wan Hai Lines Ltd.",
            freight_forwarder_name="Wan Hai Lines Ltd.",
            shipment_type="Ocean FCL",
            pol_name="Shanghai Port",
            pod_name="Alexandria Port",
            free_demurrage_days=21,
            vessel_name="WAN HAI 511",
            voyage_number="V.W112",
            etd=datetime(2026, 9, 25, 10, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 10, 23, 18, 0, tzinfo=timezone.utc),
            containers_data=[
                ContainerAllocationItem(
                    container_type="40HC",
                    quantity=1,
                    container_numbers=["WHSU81072658"],
                    seal_numbers=["WHA257097"],
                    vgm_weight_kg=24500.0,
                )
            ],
            cost_charges_data=[
                BookingChargeItem(
                    charge_type="Sea Freight 40ft",
                    unit="Per Container",
                    quantity=1.0,
                    container_type="40HC",
                    currency="USD",
                    rate=6700.0,
                    total=6700.0,
                    charge_category="FREIGHT",
                    fx_rate_to_usd=1.0,
                    amount_usd=6700.0,
                ),
                BookingChargeItem(
                    charge_type="Origin Local & EXW Handling",
                    unit="Per Shipment",
                    quantity=1.0,
                    currency="USD",
                    rate=1080.0,
                    total=1080.0,
                    charge_category="ORIGIN_LOCAL",
                    fx_rate_to_usd=1.0,
                    amount_usd=1080.0,
                ),
            ],
            status="Draft",
            owner="Kamal",
            notes="حجز مساحة الشحن لشحنة PET Stock - اختيار العرض الفائز من Wan Hai Lines",
        )
        draft_booking = create_booking_service(db, create_payload, user="Kamal")
        assert draft_booking.booking_id is not None
        assert draft_booking.status == "Draft"

        # 4. Confirm Booking (BK-01) with carrier confirmation no and fix schedule
        confirm_payload = ShipmentBookingConfirm(
            booking_confirmation_no="THXJ2609015",
            vessel_name="WAN HAI 511",
            voyage_number="V.W112",
            etd=datetime(2026, 9, 25, 10, 0, tzinfo=timezone.utc),
            eta=datetime(2026, 10, 23, 18, 0, tzinfo=timezone.utc),
            free_demurrage_days=21,
            notes="تم تأكيد واختيار عرض الشحن الفائز مع الخط الملاحي Wan Hai Lines وتثبيت رقم الحجز THXJ2609015 وفترة سماح 21 يوماً",
        )
        confirmed_booking = confirm_booking_service(db, draft_booking.booking_id, confirm_payload, user="Kamal")
        assert confirmed_booking.status == "Confirmed"
        assert confirmed_booking.booking_confirmation_no == "THXJ2609015"
        assert confirmed_booking.free_demurrage_days == 21

        # 5. Verify ImportFile transitioned automatically to STEP_07
        db.refresh(file_rec)
        assert file_rec.current_step_code == "STEP_07"
        assert file_rec.current_module == "STEP_07 Freight Allocations"
        assert file_rec.booking_no == "THXJ2609015"
        assert file_rec.vessel_name == "WAN HAI 511"
        assert file_rec.target_free_days == 21
        assert file_rec.required_eta == date(2026, 10, 23)
        assert file_rec.progress_percent >= 50.0

        # 6. Verify operational task TSK-2026-0020 auto-closed
        db.refresh(task_bk01)
        assert task_bk01.status == "Completed"
        assert task_bk01.is_auto_closed is True

        # 7. Verify downstream BK-02 smart task dispatched
        bk02_task = db.query(SmartTask).filter(
            SmartTask.import_file_id == 5,
            SmartTask.title.contains("BK-02"),
        ).first()
        assert bk02_task is not None
        assert bk02_task.status == "Pending"
        assert bk02_task.assigned_user == "Logistics Officer"

        # 8. Verify Lifecycle Board activity updated to STEP_07
        step06_act = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == "IMP-2026-0005",
            ShipmentStageActivity.step_code == "STEP_06",
        ).first()
        assert step06_act.status == "Completed"
        assert step06_act.completion_type == "real"

        step07_act = db.query(ShipmentStageActivity).filter(
            ShipmentStageActivity.import_file_code == "IMP-2026-0005",
            ShipmentStageActivity.step_code == "STEP_07",
        ).first()
        assert step07_act is not None
        assert step07_act.status == "In-Progress"

        # 9. Verify that lifecycle advance automatically auto-synced checklist items
        summary_initial = get_checklist_summary(db, 5)
        assert summary_initial.total_items == 24
        passed_codes = [itm.question_code for itm in summary_initial.items if itm.status == "PASSED"]
        assert "CHK_PRE_01" in passed_codes
        assert "CHK_PRE_08" in passed_codes

        all_items = db.query(ImportFileChecklistItem).filter(
            ImportFileChecklistItem.import_file_id == 5
        ).all()
        for itm in all_items:
            itm.status = "PASSED"
            itm.verified_by = "Logistics Officer"
            itm.verified_at = datetime.now(timezone.utc)
            itm.notes = f"Verified and fulfilled for shipment IMP-2026-0005: {itm.question_code}"

        db.commit()

        summary_final = get_checklist_summary(db, 5)
        assert summary_final.total_items == 24
        assert summary_final.passed_items == 24
        assert summary_final.pending_items == 0
        assert summary_final.mandatory_pending_items == 0
        assert summary_final.readiness_score_pct == 100
        assert summary_final.is_gate_blocked is False

        gate = check_gatekeeper(db, 5, "IN_TRANSIT")
        assert gate.can_advance is True
        assert gate.blocking_count == 0
