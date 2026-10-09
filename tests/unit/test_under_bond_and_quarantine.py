import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import HTTPException
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    UnderBondReleaseSubmit,
    LabTestResultSubmit,
)
from modules.customs_clearance.service import (
    issue_under_bond_release_service,
    record_lab_result_and_lift_quarantine_service,
)
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.warehouse_receiving.schemas import (
    WarehouseReceivingCreate,
    GrnItemSchema,
)
from modules.warehouse_receiving.service import (
    create_warehouse_receiving_service,
    validate_warehouse_dispatch_authorization,
)
from modules.file_closure.service import evaluate_file_closure_gate


SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


class TestUnderBondAndQuarantineLock:
    """
    LOG-BOND-003: Under-Bond Clearance, Factory Quarantine Lock, and Lab Result Workflows.
    """

    def test_under_bond_release_and_quarantine_flow(self, db_session):
        # 1. Create Import File
        imp = ImportFile(
            import_file_code="IMP-BOND-001",
            company_name="Delta Engineering",
            supplier_name="Bologna Hydraulics",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        # 2. Create Customs Clearance Record
        clearance = CustomsClearanceRecord(
            clearance_code="CLR-BOND-001",
            import_file_id=imp.import_file_id,
            declaration_46_no="DEC-46-7788",
            channel_type="Red Channel",
            payment_status="Paid & Verified",
            status="Duty Paid",
        )
        db_session.add(clearance)
        db_session.commit()
        db_session.refresh(clearance)

        # 3. Attempt under-bond release with empty whitespace guarantee ref -> should raise HTTP 400
        with pytest.raises(HTTPException) as exc:
            issue_under_bond_release_service(
                db_session,
                clearance.customs_clearance_id,
                UnderBondReleaseSubmit(
                    bond_guarantee_ref="   ",
                    temporary_release_date=datetime.now(timezone.utc),
                ),
            )
        assert exc.value.status_code == 400
        assert "لا يمكن السحب على عهدة بدون إرفاق رقم التعهد" in exc.value.detail


        # 4. Successfully issue Under-Bond Release
        now = datetime.now(timezone.utc)
        updated_clr = issue_under_bond_release_service(
            db_session,
            clearance.customs_clearance_id,
            UnderBondReleaseSubmit(
                bond_guarantee_ref="BOND-GUARANTEE-2026-991",
                temporary_release_date=now,
                customs_warehouse_location="مستودع مصنع العاشر من رمضان",
            ),
        )
        assert updated_clr.is_under_bond_release is True
        assert updated_clr.quarantine_lock is True
        assert updated_clr.dispatch_authorized is False
        assert updated_clr.status == "Under Bond Released"
        assert updated_clr.lab_test_result == "Pending"

        # 5. Receive goods at warehouse -> GRN should inherit quarantine lock
        grn = create_warehouse_receiving_service(
            db_session,
            WarehouseReceivingCreate(
                import_file_id=imp.import_file_id,
                warehouse_name="10th of Ramadan Bonded Storage",
                seal_intact=True,
                seal_number="SL-887766",
                grn_items=[
                    GrnItemSchema(
                        item_code="VALVE-HYD-01",
                        item_name="صمامات هيدروليكية عالية الضغط",
                        invoiced_qty=200,
                        accepted_qty=200,
                        quarantine_flag=True,
                    )
                ],
            ),
        )
        assert grn.is_under_bond_quarantine is True
        assert grn.quarantine_lock_active is True
        assert grn.dispatch_blocked is True
        assert grn.status == "Under Bond Quarantine"

        # 6. Attempt to validate dispatch while under quarantine -> should fail with 400
        with pytest.raises(HTTPException) as exc_disp:
            validate_warehouse_dispatch_authorization(db_session, grn.receiving_id)
        assert exc_disp.value.status_code == 400
        assert "ممنوع الصرف أو التداول" in exc_disp.value.detail

        # 7. Record Conforming Lab Result & Lift Quarantine Lock
        cleared_clr = record_lab_result_and_lift_quarantine_service(
            db_session,
            clearance.customs_clearance_id,
            LabTestResultSubmit(
                lab_test_result="Conforming",
                lab_certificate_number="LAB-GOEIC-2026-4433",
                test_completion_date=datetime.now(timezone.utc),
                lift_quarantine_lock=True,
            ),
            can_release=True,  # the router passes customs_clearance.release of the acting user
        )
        assert cleared_clr.quarantine_lock is False
        assert cleared_clr.dispatch_authorized is True
        assert cleared_clr.status == "Final Release Granted"
        assert cleared_clr.lab_certificate_number == "LAB-GOEIC-2026-4433"

        # 8. Verify GRN quarantine lock is automatically lifted (BE810-T03)
        db_session.refresh(grn)
        assert grn.quarantine_lock_active is False
        assert grn.dispatch_blocked is False
        assert grn.status == "Goods Received"
        assert "Quarantine lock lifted after lab approval" in (grn.discrepancy_notes or "")

        # 9. Validate dispatch is now authorized
        assert validate_warehouse_dispatch_authorization(db_session, grn.receiving_id) is True

        # 10. File closure gate no longer blocks on warehouse_quarantine
        gate = evaluate_file_closure_gate(db_session, imp)
        assert "warehouse_quarantine" not in gate.blocking_reasons

    def test_lab_non_conforming_keeps_lock(self, db_session):
        """BE810-T03: Non-conforming lab result keeps the quarantine lock on GRN and clearance."""
        imp = ImportFile(
            import_file_code="IMP-BOND-FAIL",
            company_name="Chem Co",
            supplier_name="Global Supplier",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        clearance = CustomsClearanceRecord(
            clearance_code="CLR-BOND-FAIL",
            import_file_id=imp.import_file_id,
            is_under_bond_release=True,
            quarantine_lock=True,
            status="Under-Bond Temporary Release",
        )
        db_session.add(clearance)

        grn = WarehouseReceivingRecord(
            grn_code="GRN-BOND-FAIL",
            import_file_id=imp.import_file_id,
            warehouse_name="Bond WH",
            is_under_bond_quarantine=True,
            quarantine_lock_active=True,
            dispatch_blocked=True,
            status="Under Bond Quarantine",
            is_active=True,
        )
        db_session.add(grn)
        db_session.commit()

        record_lab_result_and_lift_quarantine_service(
            db_session,
            clearance.customs_clearance_id,
            LabTestResultSubmit(
                lab_test_result="Non-Conforming",
                lab_certificate_number="LAB-FAIL-001",
                test_completion_date=datetime.now(timezone.utc),
                lift_quarantine_lock=False,
            ),
            can_release=False,
        )

        db_session.refresh(clearance)
        db_session.refresh(grn)
        assert clearance.quarantine_lock is True
        assert grn.quarantine_lock_active is True
        assert grn.dispatch_blocked is True

        with pytest.raises(HTTPException) as exc:
            validate_warehouse_dispatch_authorization(db_session, grn.receiving_id)
        assert exc.value.status_code == 400

    def test_legacy_locked_grn_auto_refreshed_on_dispatch(self, db_session):
        """BE810-T03: Legacy locked GRN whose customs clearance already lifted lock is refreshed on dispatch validation."""
        imp = ImportFile(
            import_file_code="IMP-BOND-LEGACY",
            company_name="Legacy Co",
            supplier_name="Supplier",
            is_customs_released=True,
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        # Clearance already has quarantine_lock = False
        clearance = CustomsClearanceRecord(
            clearance_code="CLR-BOND-LEGACY",
            import_file_id=imp.import_file_id,
            is_under_bond_release=True,
            quarantine_lock=False,
            status="Final Release Granted",
            is_active=True,
        )
        db_session.add(clearance)

        # Legacy GRN still has quarantine_lock_active = True
        grn = WarehouseReceivingRecord(
            grn_code="GRN-BOND-LEGACY",
            import_file_id=imp.import_file_id,
            warehouse_name="Legacy WH",
            is_under_bond_quarantine=True,
            quarantine_lock_active=True,
            dispatch_blocked=True,
            status="Under Bond Quarantine",
            is_active=True,
        )
        db_session.add(grn)
        db_session.commit()

        # Validating dispatch should auto-refresh and return True
        assert validate_warehouse_dispatch_authorization(db_session, grn.receiving_id) is True

        db_session.refresh(grn)
        assert grn.quarantine_lock_active is False
        assert grn.dispatch_blocked is False
        assert grn.status == "Goods Received"

    def test_api_under_bond_endpoints(self, client, db_session):
        imp = ImportFile(
            import_file_code="IMP-BOND-API-01",
            company_name="Alex Petrochem",
            supplier_name="Stuttgart Valves",
        )
        db_session.add(imp)
        db_session.commit()
        db_session.refresh(imp)

        clearance = CustomsClearanceRecord(
            clearance_code="CLR-BOND-API-01",
            import_file_id=imp.import_file_id,
            declaration_46_no="DEC-46-9900",
            payment_status="Paid & Verified",
        )
        db_session.add(clearance)
        db_session.commit()
        db_session.refresh(clearance)

        # API Call: Under-Bond Release
        resp1 = client.post(
            f"/api/v1/customs-clearance/{clearance.customs_clearance_id}/under-bond-release",
            json={
                "bond_guarantee_ref": "BG-ALEX-9988",
                "temporary_release_date": datetime.now(timezone.utc).isoformat(),
                "customs_warehouse_location": "مخزن الإسكندرية تحت التحفظ",
            },
        )
        assert resp1.status_code == 200
        data1 = resp1.json()
        assert data1["is_under_bond_release"] is True
        assert data1["quarantine_lock"] is True
        assert data1["bond_guarantee_ref"] == "BG-ALEX-9988"

        # API Call: Lab Result
        resp2 = client.post(
            f"/api/v1/customs-clearance/{clearance.customs_clearance_id}/lab-test-result",
            json={
                "lab_test_result": "Conforming",
                "lab_certificate_number": "CERT-CHEM-5544",
                "test_completion_date": datetime.now(timezone.utc).isoformat(),
                "lift_quarantine_lock": True,
            },
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["quarantine_lock"] is False
        assert data2["dispatch_authorized"] is True
        assert data2["status"] == "Final Release Granted"
