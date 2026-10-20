"""
Unit test asserting full lifecycle of Draft B/L Dual Review & Approval (SH-02)
for Shipment IMP-2026-0005 (PET Stock).
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.import_documentation.schemas import (
    DraftBLReviewCreate,
    DualApprovalRequest,
)
from modules.import_documentation.service import (
    create_draft_bl_review_service,
    process_dual_approval_service,
)
from modules.import_documentation.model import DraftBLReviewSession


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_shipment_5_draft_bl_dual_approval_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_08_BL
    imp_file = ImportFile(
        import_file_code="IMP-2026-0005",
        company_name="SCAS",
        supplier_name="Global PET Supplier",
        current_step_code="STEP_08_BL",
        current_module="STEP_08_BL Draft B/L Review & Approval",
        current_stage_code="PHASE_3",
        progress_percent=60.0,
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup PO and Booking
    po = PurchaseOrder(
        po_number="PO-2026-005",
        import_file_id=imp_file.import_file_id,
        supplier_id=1,
        company_id=1,
        project_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=50000.0,
        status="Approved",
    )
    bkg = ShipmentBooking(
        booking_code="BKG-2026-0002",
        booking_confirmation_no="THXJ2609015",
        import_file_id=imp_file.import_file_id,
        status="Sailed",
    )
    db_session.add_all([po, bkg])
    db_session.commit()

    # 3. Create Draft BL Review session
    review_payload = DraftBLReviewCreate(
        import_file_id=imp_file.import_file_id,
        po_id=po.po_id,
        booking_id=bkg.booking_id,
        draft_bl_number="WHL-SHA-2026-9015",
        shipping_line="Wan Hai Lines Ltd.",
        vessel_name="WAN HAI 511",
        voyage_number="V.W112",
        booking_no="THXJ2609015",
        mbl_no="WHL-SHA-2026-9015",
        freight_terms="Prepaid",
        stage="Stage 1: Draft Review",
        status="PENDING_APPROVAL",
        is_draft=False,
        open_discrepancies_count=0,
        has_blocking_mismatch=False,
    )
    review = create_draft_bl_review_service(db_session, review_payload, user="Logistics Officer")
    assert review.bl_review_code is not None

    # 4. Importer Approval
    importer_req = DualApprovalRequest(
        bl_review_id=review.bl_review_id,
        role="importer",
        action="Approved",
        approved_by="Eng. Maro",
        notes="Draft B/L fully verified against PO SCAS-2026-PO-0005.",
    )
    review = process_dual_approval_service(db_session, importer_req, user="Eng. Maro")
    assert review.importer_approval_status == "Approved"

    # 5. Customs Broker Approval
    broker_req = DualApprovalRequest(
        bl_review_id=review.bl_review_id,
        role="customs_broker",
        action="Approved",
        approved_by="Customs Broker",
        notes="Consignee and description conform to Egyptian customs import regulations.",
    )
    review = process_dual_approval_service(db_session, broker_req, user="Customs Broker")
    db_session.refresh(imp_file)

    assert review.status == "FINAL"
    assert imp_file.progress_percent >= 65.0
    assert imp_file.bl_number == "WHL-SHA-2026-9015"
