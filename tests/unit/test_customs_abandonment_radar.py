import pytest
from datetime import date, timedelta
from fastapi import status
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.customs_abandonment.service import (
    evaluate_abandonment_risk,
    create_radar_service,
    recalculate_open_files_service,
    generate_extension_letter_draft,
    request_extension_service,
    grant_extension_service,
)
from modules.customs_abandonment.schemas import (
    CustomsAbandonmentRadarCreate,
    ExtensionRequestCreate,
    ExtensionGrantCreate,
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


class TestCustomsAbandonmentRadar:

    def test_seaport_statutory_countdown_60_days(self):
        """Under Art. 67 Law 207/2020, seaports have 60 statutory legal days."""
        arrival = date(2026, 5, 1)
        curr = date(2026, 5, 11)  # 10 days in port

        max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type="SEAPORT",
            arrival_date=arrival,
            current_date=curr,
        )

        assert max_days == 60
        assert days_in == 10
        assert days_rem == 50
        assert risk == "NORMAL"

    def test_dry_port_and_airport_statutory_countdown_30_days(self):
        """Under Art. 67 Law 207/2020, dry ports & airports have 30 statutory legal days."""
        arrival = date(2026, 5, 1)
        curr = date(2026, 5, 11)  # 10 days in port

        max_days, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type="AIRPORT",
            arrival_date=arrival,
            current_date=curr,
        )

        assert max_days == 30
        assert days_in == 10
        assert days_rem == 20
        assert risk == "NORMAL"

        # Also test DRY_PORT
        max_days_dry, _, days_rem_dry, _ = evaluate_abandonment_risk(
            port_type="DRY_PORT",
            arrival_date=arrival,
            current_date=curr,
        )
        assert max_days_dry == 30
        assert days_rem_dry == 20

    def test_risk_level_warning_15_days(self):
        """Warning level triggers when 8 to 15 days remain."""
        arrival = date(2026, 5, 1)
        # Seaport: 60 - 48 = 12 days remaining -> WARNING_15_DAYS
        curr = arrival + timedelta(days=48)

        _, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type="SEAPORT",
            arrival_date=arrival,
            current_date=curr,
        )

        assert days_rem == 12
        assert risk == "WARNING_15_DAYS"

    def test_risk_level_critical_7_days(self):
        """Critical level triggers when 1 to 7 days remain."""
        arrival = date(2026, 5, 1)
        # Seaport: 60 - 55 = 5 days remaining -> CRITICAL_7_DAYS
        curr = arrival + timedelta(days=55)

        _, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type="SEAPORT",
            arrival_date=arrival,
            current_date=curr,
        )

        assert days_rem == 5
        assert risk == "CRITICAL_7_DAYS"

    def test_risk_level_under_abandonment_inventory(self):
        """When legal days expire (days_remaining <= 0), cargo enters statutory inventory."""
        arrival = date(2026, 5, 1)
        # Seaport: 60 days elapsed + 1 = 61 days -> days_rem = -1
        curr = arrival + timedelta(days=61)

        _, days_in, days_rem, risk = evaluate_abandonment_risk(
            port_type="SEAPORT",
            arrival_date=arrival,
            current_date=curr,
        )

        assert days_rem <= 0
        assert risk == "UNDER_ABANDONMENT_INVENTORY"

    def test_extension_request_and_grant_workflow(self, db_session):
        """Extension approval resets legal days and reduces risk level."""
        arrival = date.today() - timedelta(days=55)  # 5 days remaining (CRITICAL)

        radar = create_radar_service(
            db_session,
            CustomsAbandonmentRadarCreate(
                import_file_code="IMP-2026-TEST01",
                port_type="SEAPORT",
                port_name="El Dekheila Port",
                arrival_date=arrival,
                importer_name="Sorour Logistics Trading",
                cargo_description="Industrial Transformers",
            ),
        )

        assert radar.risk_level == "CRITICAL_7_DAYS"
        assert radar.abandonment_status == "ACTIVE_CLEARING"

        # Request extension
        req_payload = ExtensionRequestCreate(
            reason="Waiting for Radiation Safety and GOIEC chemical approval",
            requested_days=30,
        )
        updated_req = request_extension_service(db_session, radar.radar_id, req_payload)
        assert updated_req.extension_requested is True
        assert updated_req.abandonment_status == "EXTENSION_PENDING"

        # Grant extension for 30 additional days (total 90 days from arrival)
        grant_date = arrival + timedelta(days=90)
        grant_payload = ExtensionGrantCreate(
            extension_granted_until=grant_date,
            official_approval_ref="DECREE-CUST-8802/2026",
            notes="Extension granted by Customs Central Director",
        )
        granted_radar = grant_extension_service(db_session, radar.radar_id, grant_payload)
        assert granted_radar.max_legal_days == 90
        assert granted_radar.days_remaining == 35  # 90 - 55 = 35
        assert granted_radar.risk_level == "NORMAL"
        assert granted_radar.abandonment_status == "ACTIVE_CLEARING"

    def test_official_extension_letter_draft(self, db_session):
        """Official petition draft contains Egyptian Customs Law 207/2020 Art. 67 legal references."""
        arrival = date.today() - timedelta(days=52)

        radar = create_radar_service(
            db_session,
            CustomsAbandonmentRadarCreate(
                import_file_code="IMP-2026-LET01",
                port_type="SEAPORT",
                port_name="ميناء الإسكندرية البحري",
                arrival_date=arrival,
                importer_name="شركة سرور للاستيراد والتصدير",
                cargo_description="خط إنتاج وتصنيع متكامل",
                bl_number="MEDU99887766",
                customs_declaration_no="46/2026/12345",
                acid_number="1987654321098765432",
            ),
        )

        letter = generate_extension_letter_draft(
            db_session,
            radar_id=radar.radar_id,
            requested_days=30,
            reason="انتظار فحص معمل متبقيات المبيدات والمطابقة الفنية",
        )

        assert "قانون الجمارك" in letter.formal_body_ar
        assert "207 لسنة 2020" in letter.formal_body_ar
        assert "المادة (67)" in letter.formal_body_ar
        assert "مهمل" in letter.formal_body_ar
        assert "IMP-2026-LET01" in letter.formal_body_ar
        assert "MEDU99887766" in letter.formal_body_ar
        assert "46/2026/12345" in letter.formal_body_ar
        assert "1987654321098765432" in letter.formal_body_ar
        assert letter.legal_basis == "Egyptian Customs Law No. 207 of 2020, Article 67"

    def test_recalculate_open_files(self, db_session):
        """Recalculation engine updates countdown and status across active records."""
        arr_norm = date.today() - timedelta(days=10)
        arr_warn = date.today() - timedelta(days=48)
        arr_crit = date.today() - timedelta(days=56)

        create_radar_service(db_session, CustomsAbandonmentRadarCreate(import_file_code="F-NORM", port_type="SEAPORT", arrival_date=arr_norm))
        create_radar_service(db_session, CustomsAbandonmentRadarCreate(import_file_code="F-WARN", port_type="SEAPORT", arrival_date=arr_warn))
        create_radar_service(db_session, CustomsAbandonmentRadarCreate(import_file_code="F-CRIT", port_type="SEAPORT", arrival_date=arr_crit))

        result = recalculate_open_files_service(db_session)
        assert result.total_evaluated >= 3
        assert result.critical_count >= 1
        assert result.warning_count >= 1
        assert result.normal_count >= 1

    def test_api_customs_abandonment_endpoints(self, client, db_session):
        """Test API endpoints under /api/v1/customs-abandonment."""
        # 1. POST /radars
        payload = {
            "import_file_code": "IMP-2026-API01",
            "port_type": "SEAPORT",
            "port_name": "Ain Sokhna Port",
            "arrival_date": str(date.today() - timedelta(days=54)),
            "importer_name": "Egyptian Engineering Co.",
            "cargo_description": "Solar Panels",
            "bl_number": "COSU654321",
        }
        res = client.post("/api/v1/customs-abandonment/radars", json=payload)
        assert res.status_code == status.HTTP_201_CREATED
        data = res.json()
        radar_id = data["radar_id"]
        assert data["risk_level"] == "CRITICAL_7_DAYS"

        # 2. GET /radars
        res_list = client.get("/api/v1/customs-abandonment/radars?risk_level=CRITICAL_7_DAYS")
        assert res_list.status_code == status.HTTP_200_OK
        assert len(res_list.json()) >= 1

        # 3. GET /radars/summary
        res_sum = client.get("/api/v1/customs-abandonment/radars/summary")
        assert res_sum.status_code == status.HTTP_200_OK
        summary = res_sum.json()
        assert summary["total_radars"] >= 1
        assert summary["critical_7_days_count"] >= 1

        # 4. POST /radars/{radar_id}/request-extension
        ext_req = {
            "reason": "Clearance delayed awaiting GOIEC certification",
            "requested_days": 30,
        }
        res_ext = client.post(f"/api/v1/customs-abandonment/radars/{radar_id}/request-extension", json=ext_req)
        assert res_ext.status_code == status.HTTP_200_OK
        assert res_ext.json()["abandonment_status"] == "EXTENSION_PENDING"

        # 5. GET /radars/{radar_id}/extension-letter-draft
        res_let = client.get(f"/api/v1/customs-abandonment/radars/{radar_id}/extension-letter-draft")
        assert res_let.status_code == status.HTTP_200_OK
        let_data = res_let.json()
        assert "المادة (67)" in let_data["formal_body_ar"]
        assert "IMP-2026-API01" in let_data["formal_body_ar"]

        # 6. POST /radars/{radar_id}/grant-extension
        grant_date = str(date.today() + timedelta(days=25))
        grant_req = {
            "extension_granted_until": grant_date,
            "official_approval_ref": "MIN-DEC-1209",
            "notes": "Approved by Customs Undersecretary",
        }
        res_grant = client.post(f"/api/v1/customs-abandonment/radars/{radar_id}/grant-extension", json=grant_req)
        assert res_grant.status_code == status.HTTP_200_OK
        assert res_grant.json()["risk_level"] == "NORMAL"

        # 7. POST /recalculate
        res_recalc = client.post("/api/v1/customs-abandonment/recalculate")
        assert res_recalc.status_code == status.HTTP_200_OK
        assert res_recalc.json()["total_evaluated"] >= 1

        # 8. POST /radars/{radar_id}/resolve
        res_res = client.post(f"/api/v1/customs-abandonment/radars/{radar_id}/resolve")
        assert res_res.status_code == status.HTTP_200_OK
        assert res_res.json()["abandonment_status"] == "RESOLVED_RELEASED"
