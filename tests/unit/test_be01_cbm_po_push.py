"""
Unit tests for BE01-T14:
CBM totals pushed on update and link consistently (modules/cbm_calculator).
"""
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Ensures all SQLAlchemy models are registered
from database.database import Base
from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.cbm_calculator.repository import CBMRepository
from modules.cbm_calculator.schemas import (
    CBMCalculationCreate,
    CBMCalculationUpdate,
    CBMItemCreate,
    CloneCBMCalculationRequest,
)
from modules.cbm_calculator.service import CBMService
from modules.purchase_orders.model import PurchaseOrder


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _make_item(quantity: int = 1, length: float = 100.0, width: float = 100.0, height: float = 100.0, unit: str = "cm", weight: float = 10.0):
    # 100x100x100 cm = 1.0 CBM per unit
    return CBMItemCreate(
        package_type="Carton",
        quantity=quantity,
        length=length,
        width=width,
        height=height,
        unit=unit,
        gross_weight_per_unit_kg=weight,
    )


def _create_po(db: Session, po_number: str = "PO-BE01-T14-1", project_id: int = 1, is_active: bool = True) -> PurchaseOrder:
    po = PurchaseOrder(
        po_number=po_number,
        project_id=project_id,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=1000.0,
        status="Draft",
        version=1,
        is_active=is_active,
    )
    db.add(po)
    db.commit()
    db.refresh(po)
    return po


class TestCBMPOPushAndConsistency:

    def test_create_calc_linked_to_po_and_update_items_pushes_cbm_and_bumps_version(self, db: Session):
        """
        Create calc linked to PO (CBM 2.0) -> update items to CBM 3.0 ->
        PurchaseOrder.total_cbm == 3.0 and version + 1.
        """
        po = _create_po(db, po_number="PO-CBM-PUSH-1")
        assert po.version == 1
        assert float(po.total_cbm or 0.0) == 0.0

        # 1. Create calc linked to PO with 2 units of 1.0 CBM each (total CBM = 2.0)
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Shipment Calc Initial",
                po_id=po.po_id,
                items=[_make_item(quantity=2)],
            ),
            user="creator",
        )
        assert calc_resp.total_cbm == 2.0

        db.refresh(po)
        assert float(po.total_cbm) == 2.0
        assert po.total_gross_weight_kg == 20.0
        assert po.total_packages_count == 2
        assert po.version == 2
        assert po.updated_by == "creator"

        # 2. Update calc with 3 units of 1.0 CBM each (total CBM = 3.0)
        updated_resp = CBMService.update_calculation_service(
            db,
            calc_resp.calc_id,
            CBMCalculationUpdate(
                items=[_make_item(quantity=3)],
            ),
            user="updater",
        )
        assert updated_resp.total_cbm == 3.0

        db.refresh(po)
        assert float(po.total_cbm) == 3.0
        assert po.total_gross_weight_kg == 30.0
        assert po.total_packages_count == 3
        assert po.version == 3
        assert po.updated_by == "updater"

    def test_update_calc_without_items_or_po_change_does_not_bump_po(self, db: Session):
        """Updating title or notes without touching items or po_id should not push to PO or bump its version."""
        po = _create_po(db, po_number="PO-CBM-NO-BUMP")
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Initial",
                po_id=po.po_id,
                items=[_make_item(quantity=2)],
            ),
            user="creator",
        )
        db.refresh(po)
        po_ver = po.version

        # Update title only
        CBMService.update_calculation_service(
            db,
            calc_resp.calc_id,
            CBMCalculationUpdate(title="Changed Title Only"),
            user="updater",
        )

        db.refresh(po)
        assert po.version == po_ver

    def test_update_calc_changing_po_id_pushes_to_new_po(self, db: Session):
        """Updating calculation with a new po_id pushes measurements to the newly linked PO."""
        po1 = _create_po(db, po_number="PO-CBM-OLD")
        po2 = _create_po(db, po_number="PO-CBM-NEW")

        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Initial PO1",
                po_id=po1.po_id,
                items=[_make_item(quantity=2)],
            ),
            user="creator",
        )
        db.refresh(po1)
        assert float(po1.total_cbm) == 2.0
        assert po1.version == 2

        assert float(po2.total_cbm or 0.0) == 0.0
        assert po2.version == 1

        # Re-link to PO2 via update_calculation_service
        CBMService.update_calculation_service(
            db,
            calc_resp.calc_id,
            CBMCalculationUpdate(po_id=po2.po_id),
            user="relinker",
        )

        db.refresh(po2)
        assert float(po2.total_cbm) == 2.0
        assert po2.version == 2
        assert po2.updated_by == "relinker"

    def test_update_soft_deleted_calculation_raises_404(self, db: Session):
        """PUT on an inactive calculation must return 404."""
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="To be soft deleted",
                items=[_make_item(quantity=1)],
            ),
        )

        calc = db.get(CBMCalculation, calc_resp.calc_id)
        CBMRepository.soft_delete(db, calc)
        db.commit()

        with pytest.raises(HTTPException) as exc:
            CBMService.update_calculation_service(
                db,
                calc_resp.calc_id,
                CBMCalculationUpdate(title="Attempted update"),
            )
        assert exc.value.status_code == 404
        assert "غير موجود" in exc.value.detail

    def test_link_soft_deleted_calculation_raises_404(self, db: Session):
        """Linking a soft-deleted calculation to a PO must return 404."""
        po = _create_po(db, po_number="PO-LINK-INACTIVE")
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Active Calc",
                items=[_make_item(quantity=1)],
            ),
        )

        calc = db.get(CBMCalculation, calc_resp.calc_id)
        CBMRepository.soft_delete(db, calc)
        db.commit()

        with pytest.raises(HTTPException) as exc:
            CBMService.link_to_po_service(db, calc_resp.calc_id, po_id=po.po_id)
        assert exc.value.status_code == 404
        assert "غير موجود" in exc.value.detail

    def test_clone_calc_with_zero_dimension_item_raises_400(self, db: Session):
        """
        Cloning a calculation that contains stored items with zero dimensions
        must raise HTTP 400 'لا يمكن نسخ بند بأبعاد صفرية.' instead of 500.
        """
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Calc with valid items",
                items=[_make_item(quantity=1, length=100.0, width=50.0, height=50.0)],
            ),
        )

        # Mutate stored item directly in DB to have 0 dimension (e.g. legacy dirty row)
        item = db.query(CBMCalculationItem).filter(CBMCalculationItem.calc_id == calc_resp.calc_id).first()
        item.length_cm = 0.0
        db.commit()

        with pytest.raises(HTTPException) as exc:
            CBMService.clone_cbm_calculation(
                db,
                calc_resp.calc_id,
                CloneCBMCalculationRequest(copy_items=True),
            )
        assert exc.value.status_code == 400
        assert "لا يمكن نسخ بند بأبعاد صفرية" in exc.value.detail

    def test_clone_soft_deleted_calculation_raises_404(self, db: Session):
        """Cloning an inactive calculation must return 404."""
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Calc To Inactivate",
                items=[_make_item(quantity=1)],
            ),
        )

        calc = db.get(CBMCalculation, calc_resp.calc_id)
        CBMRepository.soft_delete(db, calc)
        db.commit()

        with pytest.raises(HTTPException) as exc:
            CBMService.clone_cbm_calculation(
                db,
                calc_resp.calc_id,
                CloneCBMCalculationRequest(copy_items=True),
            )
        assert exc.value.status_code == 404
        assert "غير موجود" in exc.value.detail

    def test_cbm_repository_get_po(self, db: Session):
        """CBMRepository.get_po returns the PurchaseOrder instance or None."""
        po = _create_po(db, po_number="PO-REPO-TEST")
        loaded = CBMRepository.get_po(db, po.po_id)
        assert loaded is not None
        assert loaded.po_id == po.po_id
        assert loaded.po_number == "PO-REPO-TEST"

        assert CBMRepository.get_po(db, 999999) is None

    def test_link_to_po_service_uses_repo_get_po_and_propagates_project_id(self, db: Session):
        """link_to_po_service reads PO via repository and adopts its project_id if present."""
        po = _create_po(db, po_number="PO-LINK-PROJECT", project_id=77)
        calc_resp = CBMService.create_calculation_service(
            db,
            CBMCalculationCreate(
                title="Standalone Calc",
                items=[_make_item(quantity=4)],
            ),
        )
        assert calc_resp.project_id is None

        linked_resp = CBMService.link_to_po_service(db, calc_resp.calc_id, po_id=po.po_id, user="linker")
        assert linked_resp.po_id == po.po_id
        assert linked_resp.project_id == 77

        db.refresh(po)
        assert float(po.total_cbm) == 4.0
        assert po.version == 2
        assert po.updated_by == "linker"
