import pytest
from datetime import date, timedelta
from fastapi import status
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.port_storage.service import (
    calculate_terminal_storage,
    create_terminal_rate_service,
    create_storage_accrual_service,
    update_storage_accrual_status_service,
)
from modules.port_storage.schemas import (
    PortTerminalRateCreate,
    PortStorageAccrualCreate,
    PortStorageAccrualStatusUpdate,
)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


class TestPortStorageEngine:

    def test_free_days_storage_calculation(self, db_session):
        """Container gated out within free days (1-3 days) incurs 0 storage charges."""
        gate_in = date(2026, 6, 1)
        gate_out = date(2026, 6, 3)  # 3 days inclusive

        breakdown = calculate_terminal_storage(
            terminal_code="ACCHCO",
            container_size="20ft",
            is_reefer=False,
            gate_in=gate_in,
            current_or_gate_out=gate_out,
            include_xray=False,
            include_scale=False,
        )

        assert breakdown.total_days == 3
        assert breakdown.free_days_allowed == 3
        assert breakdown.chargeable_days == 0
        assert breakdown.tier1_days == 0
        assert breakdown.tier2_days == 0
        assert breakdown.penal_days == 0
        assert breakdown.storage_charges_egp == 0.0
        assert breakdown.total_port_storage_egp == 0.0

    def test_tier1_storage_calculation(self, db_session):
        """Days 4-8 fall into Tier 1 tariff."""
        gate_in = date(2026, 6, 1)
        gate_out = date(2026, 6, 6)  # 6 days total: 3 free, 3 in Tier 1

        breakdown = calculate_terminal_storage(
            terminal_code="ACCHCO",
            container_size="20ft",
            is_reefer=False,
            gate_in=gate_in,
            current_or_gate_out=gate_out,
            include_xray=False,
            include_scale=False,
        )

        assert breakdown.total_days == 6
        assert breakdown.chargeable_days == 3
        assert breakdown.tier1_days == 3
        assert breakdown.tier2_days == 0
        assert breakdown.penal_days == 0
        assert breakdown.tier1_rate == 120.0
        assert breakdown.storage_charges_egp == 360.0  # 3 * 120
        assert breakdown.total_port_storage_egp == 360.0

    def test_tier2_storage_calculation(self, db_session):
        """Days 9-15 fall into Tier 2 tariff."""
        gate_in = date(2026, 6, 1)
        gate_out = date(2026, 6, 12)  # 12 days total: 3 free, 5 Tier 1, 4 Tier 2

        breakdown = calculate_terminal_storage(
            terminal_code="ACCHCO",
            container_size="40ft",
            is_reefer=False,
            gate_in=gate_in,
            current_or_gate_out=gate_out,
            include_xray=False,
            include_scale=False,
        )

        assert breakdown.total_days == 12
        assert breakdown.chargeable_days == 9
        assert breakdown.tier1_days == 5
        assert breakdown.tier2_days == 4
        assert breakdown.penal_days == 0
        # 40ft ACCHCO: Tier 1 = 240, Tier 2 = 480
        expected_storage = (5 * 240.0) + (4 * 480.0)  # 1200 + 1920 = 3120
        assert breakdown.storage_charges_egp == expected_storage

    def test_penal_tier_storage_calculation(self, db_session):
        """Days 16+ fall into Penal Tier."""
        gate_in = date(2026, 6, 1)
        gate_out = date(2026, 6, 20)  # 20 days total: 3 free, 5 Tier 1, 7 Tier 2, 5 Penal

        breakdown = calculate_terminal_storage(
            terminal_code="DP_WORLD_SOKHNA",
            container_size="40ft",
            is_reefer=False,
            gate_in=gate_in,
            current_or_gate_out=gate_out,
            include_xray=True,
            include_scale=True,
        )

        assert breakdown.total_days == 20
        assert breakdown.chargeable_days == 17
        assert breakdown.tier1_days == 5
        assert breakdown.tier2_days == 7
        assert breakdown.penal_days == 5
        # DP World Sokhna 40ft: T1=300, T2=600, Penal=1200, Xray=600, Scale=250
        expected_storage = (5 * 300.0) + (7 * 600.0) + (5 * 1200.0)  # 1500 + 4200 + 6000 = 11700
        assert breakdown.storage_charges_egp == expected_storage
        assert breakdown.xray_scan_fee_egp == 600.0
        assert breakdown.scale_fee_egp == 250.0
        assert breakdown.total_port_storage_egp == expected_storage + 600.0 + 250.0

    def test_reefer_plugging_charges(self, db_session):
        """Reefer containers incur daily plugging/electricity charge for all yard days."""
        gate_in = date(2026, 6, 1)
        gate_out = date(2026, 6, 10)  # 10 days

        breakdown = calculate_terminal_storage(
            terminal_code="DCHC",
            container_size="20ft",
            is_reefer=True,
            gate_in=gate_in,
            current_or_gate_out=gate_out,
            include_xray=False,
            include_scale=False,
        )

        assert breakdown.is_reefer is True
        assert breakdown.total_days == 10
        # DCHC 20ft Reefer plug = 450/day -> 10 * 450 = 4500
        assert breakdown.reefer_plugging_charges_egp == 4500.0
        # Storage: 3 free, 5 Tier 1 (110), 2 Tier 2 (220) -> 550 + 440 = 990
        assert breakdown.storage_charges_egp == 990.0
        assert breakdown.total_port_storage_egp == 990.0 + 4500.0

    def test_egyptian_terminal_aliases(self, db_session):
        """Egyptian terminal codes and aliases resolve correctly."""
        for code in ["Alexandria", "Dekheila", "DP World Sokhna", "Damietta", "SCCT", "East Port Said"]:
            breakdown = calculate_terminal_storage(
                terminal_code=code,
                container_size="20ft",
                is_reefer=False,
                gate_in=date(2026, 6, 1),
                current_or_gate_out=date(2026, 6, 5),
            )
            assert breakdown.total_days == 5
            assert breakdown.terminal_code in ["ACCHCO", "DP_WORLD_SOKHNA", "DCHC", "SCCT"]

    def test_custom_rate_card_database(self, db_session):
        """Custom rate card in DB overrides default tariffs."""
        custom_rate = PortTerminalRateCreate(
            terminal_code="ACCHCO",
            terminal_name="Alexandria Yard Special",
            container_size="20ft",
            is_reefer=False,
            free_days=5,  # 5 free days negotiated
            tier1_rate_per_day=90.0,
            tier2_rate_per_day=180.0,
            penal_rate_per_day=360.0,
            reefer_plugging_daily_fee=0.0,
            xray_scan_fee=200.0,
            scale_fee=100.0,
            currency="EGP",
            effective_date=date(2026, 1, 1),
        )
        created = create_terminal_rate_service(db_session, custom_rate)
        assert created.rate_id is not None

        # Calculate using DB session
        breakdown = calculate_terminal_storage(
            terminal_code="ACCHCO",
            container_size="20ft",
            is_reefer=False,
            gate_in=date(2026, 6, 1),
            current_or_gate_out=date(2026, 6, 7),  # 7 days
            db=db_session,
            include_xray=True,
            include_scale=True,
        )
        assert breakdown.free_days_allowed == 5
        assert breakdown.chargeable_days == 2
        assert breakdown.tier1_rate == 90.0
        assert breakdown.xray_scan_fee_egp == 200.0
        assert breakdown.scale_fee_egp == 100.0

    def test_api_port_storage_endpoints(self, client, db_session):
        """Test API endpoints under /api/v1/port-storage."""
        # 1. POST /calculate
        calc_payload = {
            "terminal_code": "SCCT",
            "container_size": "40ft",
            "is_reefer": False,
            "gate_in_date": "2026-07-01",
            "current_or_gate_out_date": "2026-07-10",
            "include_xray": True,
            "include_scale": True,
        }
        res = client.post("/api/v1/port-storage/calculate", json=calc_payload)
        assert res.status_code == status.HTTP_200_OK
        data = res.json()
        assert data["terminal_code"] == "SCCT"
        assert data["total_days"] == 10
        assert data["chargeable_days"] == 7
        assert data["total_port_storage_egp"] > 0

        # 2. POST /accruals
        accrual_payload = {
            "terminal_code": "SCCT",
            "container_number": "MSCU1234567",
            "container_size_type": "40ft",
            "is_reefer": False,
            "gate_in_date": "2026-07-01",
            "gate_out_date": "2026-07-10",
            "auto_calculate": True,
        }
        res_acc = client.post("/api/v1/port-storage/accruals", json=accrual_payload)
        assert res_acc.status_code == status.HTTP_201_CREATED
        acc_data = res_acc.json()
        acc_id = acc_data["accrual_id"]
        assert acc_data["status"] == "ESTIMATED"
        assert acc_data["total_port_storage_egp"] > 0

        # 3. GET /accruals
        res_list = client.get("/api/v1/port-storage/accruals")
        assert res_list.status_code == status.HTTP_200_OK
        assert len(res_list.json()) >= 1

        # 4. POST /accruals/{accrual_id}/status
        status_payload = {
            "status": "PAID",
            "invoice_number": "INV-PORT-9901",
            "paid_amount_egp": acc_data["total_port_storage_egp"],
            "payment_reference": "EGP-TRF-00129",
        }
        res_stat = client.post(f"/api/v1/port-storage/accruals/{acc_id}/status", json=status_payload)
        assert res_stat.status_code == status.HTTP_200_OK
        assert res_stat.json()["status"] == "PAID"
        assert res_stat.json()["invoice_number"] == "INV-PORT-9901"

        # 5. GET /accruals/summary
        res_sum = client.get("/api/v1/port-storage/accruals/summary")
        assert res_sum.status_code == status.HTTP_200_OK
        sum_data = res_sum.json()
        assert sum_data["total_accruals"] >= 1
        assert sum_data["paid_count"] >= 1
