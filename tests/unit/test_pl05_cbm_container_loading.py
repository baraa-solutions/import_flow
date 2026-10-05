"""
Unit tests for PL-05: CBM & 3D Container Loading
(حاسبة الأحجام CBM ومحاكاة التحميل واقتراح الحاوية)
"""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.cbm_calculator.schemas import (
    CBMCalculationCreate,
    CBMItemCreate,
    CBMQuickCalcRequest,
    CloneCBMCalculationRequest,
    LinkToPORequest,
)
from modules.cbm_calculator.service import CBMService
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder


@pytest.fixture(scope="module")
def db_session():
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    session = TestingSession()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


class TestPL05CBMContainerLoading:
    """Test suite verifying CBM formulas, unit normalizations, shipping mode recommendations, and PO synchronization."""

    def test_cbm_formulas_and_unit_normalization(self):
        """Verify normalizations for mm, cm, m and exact calculation of CBM, Volumetric Wt, and Air Chargeable Wt."""
        # 1. Item with cm: 120 x 80 x 100 cm, qty = 2, gross wt = 150 kg each
        item_cm = CBMItemCreate(
            package_type="Pallet",
            quantity=2,
            length=120.0,
            width=80.0,
            height=100.0,
            unit="cm",
            gross_weight_per_unit_kg=150.0,
        )
        # 2. Item with mm: 1000 x 500 x 400 mm, qty = 5, gross wt = 20 kg each
        item_mm = CBMItemCreate(
            package_type="Carton",
            quantity=5,
            length=1000.0,
            width=500.0,
            height=400.0,
            unit="mm",
            gross_weight_per_unit_kg=20.0,
        )
        # 3. Item with m: 2.0 x 1.0 x 1.5 m, qty = 1, gross wt = 400 kg each
        item_m = CBMItemCreate(
            package_type="Crate",
            quantity=1,
            length=2.0,
            width=1.0,
            height=1.5,
            unit="m",
            gross_weight_per_unit_kg=400.0,
        )

        req = CBMQuickCalcRequest(items=[item_cm, item_mm, item_m])
        res = CBMService.quick_calculate(req)

        # Total Qty = 2 + 5 + 1 = 8
        assert res.total_qty == 8

        # CBM Calculations:
        # item_cm: 2 * (1.2 * 0.8 * 1.0) = 1.92 m3
        # item_mm: 5 * (1.0 * 0.5 * 0.4) = 1.00 m3
        # item_m:  1 * (2.0 * 1.0 * 1.5) = 3.00 m3
        # Total CBM = 1.92 + 1.00 + 3.00 = 5.92 m3
        assert pytest.approx(res.total_cbm, 0.001) == 5.92

        # Gross Weight: (2 * 150) + (5 * 20) + (1 * 400) = 300 + 100 + 400 = 800 kg
        assert res.total_gross_weight_kg == 800.0

        # Volumetric Weight = CBM x 167 kg/CBM (configurable air factor): 5.92 x 167 = 988.64 kg
        # Total Volumetric Wt = 320 + 166.67 + 500 = 986.67 kg
        assert res.total_volumetric_weight_kg == 988.64

        # Air Chargeable Weight = max(Gross Wt, Volumetric Wt) = max(800, 986.67) = 986.67 kg
        assert res.air_chargeable_weight_kg == 988.64

        # Since Total CBM is 5.92 m3 (<= 15.0), recommended method is LCL Ocean Freight
        assert res.recommended_shipping_method == "LCL"

    def test_recommendation_brackets_and_container_types(self):
        """Verify shipping method and container allocation brackets for Air, LCL, FCL 20, FCL 40, FCL 40HC, and Multi-HC."""
        # 1. Air Freight: CBM <= 1.5 and Gross Wt <= 300
        air_item = CBMItemCreate(
            package_type="Carton",
            quantity=2,
            length=50.0,
            width=40.0,
            height=30.0,
            unit="cm",
            gross_weight_per_unit_kg=10.0,
        )
        res_air = CBMService.quick_calculate(CBMQuickCalcRequest(items=[air_item]))
        assert res_air.total_cbm == 0.12
        assert res_air.recommended_shipping_method == "AIR"
        assert res_air.recommended_container_type is None
        assert res_air.recommended_container_count == 0

        # 2. 20FT Standard Container: 15 < CBM <= 33
        item_20ft = CBMItemCreate(
            package_type="Pallet",
            quantity=15,
            length=120.0,
            width=100.0,
            height=130.0,
            unit="cm",
            gross_weight_per_unit_kg=200.0,
        )
        res_20ft = CBMService.quick_calculate(CBMQuickCalcRequest(items=[item_20ft]))
        assert 15.0 < res_20ft.total_cbm <= 33.0
        assert res_20ft.recommended_shipping_method == "FCL"
        assert res_20ft.recommended_container_type == "C20_ST"
        assert res_20ft.recommended_container_count == 1

        # 3. 40FT Standard Container: 33 < CBM <= 67
        item_40ft = CBMItemCreate(
            package_type="Pallet",
            quantity=30,
            length=120.0,
            width=100.0,
            height=140.0,
            unit="cm",
            gross_weight_per_unit_kg=200.0,
        )
        res_40ft = CBMService.quick_calculate(CBMQuickCalcRequest(items=[item_40ft]))
        assert 33.0 < res_40ft.total_cbm <= 67.0
        assert res_40ft.recommended_container_type == "C40_ST"
        assert res_40ft.recommended_container_count == 1

        # 4. 40FT High Cube: 67 < CBM <= 76
        item_40hc = CBMItemCreate(
            package_type="Pallet",
            quantity=36,
            length=120.0,
            width=100.0,
            height=160.0,
            unit="cm",
            gross_weight_per_unit_kg=200.0,
        )
        res_40hc = CBMService.quick_calculate(CBMQuickCalcRequest(items=[item_40hc]))
        assert 67.0 < res_40hc.total_cbm <= 76.0
        assert res_40hc.recommended_container_type == "C40_HC"
        assert res_40hc.recommended_container_count == 1

        # 5. Multi-Container Allocation: CBM > 76 (e.g. 160 CBM) -> ceil(160 / 76) = 3 containers
        item_multi = CBMItemCreate(
            package_type="Pallet",
            quantity=85,
            length=120.0,
            width=100.0,
            height=160.0,
            unit="cm",
            gross_weight_per_unit_kg=200.0,
        )
        res_multi = CBMService.quick_calculate(CBMQuickCalcRequest(items=[item_multi]))
        assert res_multi.total_cbm > 76.0
        assert res_multi.recommended_container_count == 3
        assert res_multi.recommended_container_type == "C40_HC"
        assert res_multi.smart_hybrid_containers is not None
        assert res_multi.flat_only_containers is not None

    def test_cbm_database_crud_and_po_bidirectional_sync(self, db_session):
        """Verify creating a CBM calculation, persisting line items, and synchronizing measurements with Purchase Order."""
        # 1. Create a dummy project and PO
        project = Project(
            project_code="PRJ-CBM-001",
            project_name="CBM Logistics Expansion",
            project_owner="Logistics Lead",
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            total_budget_usd=100000.0,
            status="Open",
        )
        db_session.add(project)
        db_session.flush()

        po = PurchaseOrder(
            po_number="PO-CBM-SYNC-01",
            project_id=project.project_id,
            company_id=1,
            supplier_id=1,
            incoterm_id=1,
            currency_id=1,
            total_amount_fob=50000.0,
            status="Draft",
        )
        db_session.add(po)
        db_session.commit()

        # 2. Create CBM Calculation linked to the PO
        item1 = CBMItemCreate(
            package_type="Euro Pallet",
            quantity=10,
            length=120.0,
            width=80.0,
            height=150.0,
            unit="cm",
            gross_weight_per_unit_kg=250.0,
            is_stackable=True,
        )
        calc_create = CBMCalculationCreate(
            title="Cooling Units Cargo CBM Plan",
            project_id=project.project_id,
            po_id=po.po_id,
            items=[item1],
            notes="Automated CBM sync test",
        )

        calc_resp = CBMService.create_calculation_service(db_session, calc_create)
        assert calc_resp.calc_id is not None
        assert calc_resp.total_qty == 10
        assert calc_resp.total_cbm == 14.4  # 10 * 1.2 * 0.8 * 1.5
        assert calc_resp.total_gross_weight_kg == 2500.0  # 10 * 250

        # Verify measurements were pushed to the linked Purchase Order
        db_session.refresh(po)
        assert float(po.total_cbm) == 14.4
        assert float(po.total_gross_weight_kg) == 2500.0
        assert po.total_packages_count == 10

        # 3. Soft Delete and Restore
        del_result = CBMService.soft_delete_service(db_session, calc_resp.calc_id)
        assert "soft deleted successfully" in del_result["message"]

        restored = CBMService.restore_service(db_session, calc_resp.calc_id)
        assert restored.is_active is True

    def test_cbm_clone_calculation(self, db_session):
        """Verify cloning an existing CBM calculation with independent code and duplicated items."""
        # Create base calculation
        item = CBMItemCreate(
            package_type="Carton",
            quantity=20,
            length=60.0,
            width=40.0,
            height=50.0,
            unit="cm",
            gross_weight_per_unit_kg=12.0,
        )
        base_create = CBMCalculationCreate(
            title="Base Electronic Parts CBM",
            items=[item],
        )
        base_calc = CBMService.create_calculation_service(db_session, base_create)

        # Clone calculation
        clone_req = CloneCBMCalculationRequest(
            new_title="Cloned Electronic Parts CBM - Revision 2",
            copy_items=True,
        )
        cloned = CBMService.clone_cbm_calculation(db_session, base_calc.calc_id, clone_req)

        assert cloned.calc_id != base_calc.calc_id
        assert cloned.calc_code != base_calc.calc_code
        assert cloned.title == "Cloned Electronic Parts CBM - Revision 2"
        assert cloned.total_qty == 20
        assert cloned.total_cbm == base_calc.total_cbm
        assert cloned.po_id is None  # Linkage cleanly reset for standalone draft
