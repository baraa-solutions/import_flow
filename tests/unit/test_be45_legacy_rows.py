import pytest
from datetime import date
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.auth.router import get_current_user
from modules.users.model import User
from modules.import_files.model import ImportFile


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

    test_user = User(
        user_id=1,
        username="test_admin",
        full_name="Test Admin",
        role="Admin",
        is_active=True,
    )

    def override_get_current_user():
        return test_user

    main.app.dependency_overrides[get_db] = override_get_db
    main.app.dependency_overrides[get_current_user] = override_get_current_user
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


class TestBE45LegacyRows:

    def test_cargo_shipping_legacy_row(self, db_session, client):
        """A raw SQL inserted cargo shipping row with NULL status, created_by, is_crd_validated, and 1-char note does not 500"""
        imp_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0001",
            company_name="Test Company",
            supplier_name="Test Supplier",
            is_active=True,
        )
        db_session.add(imp_file)
        db_session.commit()

        db_session.execute(text("DROP TABLE cargo_shipping_records"))
        db_session.execute(text("""
            CREATE TABLE cargo_shipping_records (
                cargo_shipping_id INTEGER PRIMARY KEY AUTOINCREMENT,
                cargo_shipping_code VARCHAR(50),
                import_file_id INTEGER,
                booking_id INTEGER,
                shipment_type VARCHAR(20),
                crd_date DATETIME,
                cargo_cutoff_date DATETIME,
                is_crd_validated BOOLEAN,
                containers_loading_data JSON,
                lcl_tracking_data JSON,
                level1_approval_status VARCHAR(30),
                level1_approved_by VARCHAR(100),
                level1_approved_at DATETIME,
                level1_notes TEXT,
                level2_approval_status VARCHAR(30),
                level2_approved_by VARCHAR(100),
                level2_approved_at DATETIME,
                level2_notes TEXT,
                dual_approval_status VARCHAR(30),
                courier_tracking_data JSON,
                cargox_exchange_data JSON,
                live_tracking_url VARCHAR(500),
                status VARCHAR(50),
                owner VARCHAR(100),
                notes TEXT,
                is_active BOOLEAN,
                created_at DATETIME,
                created_by VARCHAR(100),
                updated_at DATETIME,
                updated_by VARCHAR(100)
            )
        """))
        db_session.commit()

        db_session.execute(text("""
            INSERT INTO cargo_shipping_records (
                cargo_shipping_code, import_file_id, shipment_type,
                status, created_by, is_crd_validated, notes, is_active
            ) VALUES (
                'SHP-LEGACY-001', 1, 'FCL',
                NULL, NULL, NULL, 'x', 1
            )
        """))
        db_session.commit()

        res = client.get("/api/v1/cargo-shipping")
        assert res.status_code == 200
        data = res.json()
        assert len(data) >= 1
        legacy_item = next(item for item in data if item["cargo_shipping_code"] == "SHP-LEGACY-001")
        assert legacy_item["status"] == "Cargo Ready"
        assert legacy_item["created_by"] is None
        assert legacy_item["is_crd_validated"] is True
        assert legacy_item["notes"] == "x"

    def test_cargo_insurance_legacy_row(self, db_session, client):
        """A raw SQL inserted insurance certificate with NULL status, created_by, exchange_rate, and 1-char remarks does not 500"""
        db_session.execute(text("DROP TABLE cargo_insurance_certificates"))
        db_session.execute(text("""
            CREATE TABLE cargo_insurance_certificates (
                certificate_id INTEGER PRIMARY KEY AUTOINCREMENT,
                certificate_code VARCHAR(50),
                policy_number VARCHAR(100),
                policy_type VARCHAR(30),
                import_file_id INTEGER,
                insurance_company_id INTEGER,
                insurance_company_name VARCHAR(150),
                insured_entity_name VARCHAR(200),
                transport_mode VARCHAR(30),
                carrier_name VARCHAR(150),
                vessel_or_flight_no VARCHAR(150),
                voyage_number VARCHAR(50),
                tracking_reference VARCHAR(100),
                port_of_loading VARCHAR(150),
                port_of_discharge VARCHAR(150),
                final_destination VARCHAR(150),
                currency VARCHAR(10),
                exchange_rate FLOAT,
                invoice_value FLOAT,
                freight_cost FLOAT,
                other_logistics_costs FLOAT,
                cif_value FLOAT,
                markup_percentage FLOAT,
                insured_value FLOAT,
                coverage_clause VARCHAR(50),
                include_war_and_strikes BOOLEAN,
                base_rate FLOAT,
                war_rate FLOAT,
                base_premium FLOAT,
                war_strikes_premium FLOAT,
                minimum_premium FLOAT,
                net_premium FLOAT,
                issuance_fee FLOAT,
                tax_rate FLOAT,
                tax_amount FLOAT,
                total_payable_premium FLOAT,
                goods_description TEXT,
                package_count INTEGER,
                package_type VARCHAR(50),
                gross_weight_kg FLOAT,
                survey_agent_in_destination VARCHAR(200),
                claims_payable_at VARCHAR(150),
                status VARCHAR(30),
                issued_at DATETIME,
                remarks TEXT,
                created_at DATETIME,
                created_by VARCHAR(50),
                updated_at DATETIME,
                updated_by VARCHAR(50),
                is_active BOOLEAN
            )
        """))
        db_session.commit()

        db_session.execute(text("""
            INSERT INTO cargo_insurance_certificates (
                certificate_code, insured_entity_name, port_of_loading, port_of_discharge,
                status, created_by, exchange_rate, base_premium, total_payable_premium, remarks, is_active
            ) VALUES (
                'INS-LEGACY-001', 'Old Importer', 'Shanghai', 'Alexandria',
                NULL, NULL, NULL, NULL, NULL, 'x', 1
            )
        """))
        db_session.commit()

        res = client.get("/api/v1/cargo-insurance/certificates")
        assert res.status_code == 200
        data = res.json()
        items = data["items"] if "items" in data else data
        assert len(items) >= 1
        legacy_item = next(item for item in items if item["certificate_code"] == "INS-LEGACY-001")
        assert legacy_item["status"] == "DRAFT"
        assert legacy_item["created_by"] is None
        assert legacy_item["exchange_rate"] is None
        assert legacy_item["base_premium"] is None
        assert legacy_item["total_payable_premium"] is None
        assert legacy_item["remarks"] == "x"

    def test_shipment_updates_legacy_row(self, db_session, client):
        """A raw SQL inserted shipment update log with NULL phase_status, created_by, previous_cost, new_cost, and 1-char note does not 500"""
        db_session.execute(text("DROP TABLE shipment_update_logs"))
        db_session.execute(text("""
            CREATE TABLE shipment_update_logs (
                update_id INTEGER PRIMARY KEY AUTOINCREMENT,
                update_code VARCHAR(50),
                import_file_id INTEGER,
                import_file_code VARCHAR(100),
                update_category VARCHAR(50),
                target_phase VARCHAR(100),
                phase_status VARCHAR(50),
                log_date VARCHAR(50),
                note TEXT,
                adjusted_cost_item VARCHAR(100),
                previous_cost FLOAT,
                new_cost FLOAT,
                alert_priority VARCHAR(50),
                assigned_user VARCHAR(100),
                is_active BOOLEAN,
                created_at DATETIME,
                created_by VARCHAR(100),
                updated_at DATETIME,
                updated_by VARCHAR(100)
            )
        """))
        db_session.commit()

        db_session.execute(text("""
            INSERT INTO shipment_update_logs (
                update_code, import_file_id, import_file_code, target_phase, log_date,
                note, phase_status, created_by, previous_cost, new_cost, is_active
            ) VALUES (
                'UPD-LEGACY-001', 1, 'IMP-01', 'Phase 1', '2026-01-01',
                'x', NULL, NULL, NULL, NULL, 1
            )
        """))
        db_session.commit()

        res = client.get("/api/v1/shipment-updates")
        assert res.status_code == 200
        data = res.json()
        assert len(data) >= 1
        legacy_item = next(item for item in data if item["update_code"] == "UPD-LEGACY-001")
        assert legacy_item["phase_status"] == "Current"
        assert legacy_item["created_by"] is None
        assert legacy_item["previous_cost"] is None
        assert legacy_item["new_cost"] is None
        assert legacy_item["note"] == "x"

    def test_demurrage_tracking_legacy_row(self, db_session, client):
        """A raw SQL inserted demurrage tracking with NULL status, created_by, exchange_rate, total_cost_egp, and 1-char note does not 500"""
        db_session.execute(text("DROP TABLE demurrage_trackings"))
        db_session.execute(text("""
            CREATE TABLE demurrage_trackings (
                tracking_id INTEGER PRIMARY KEY AUTOINCREMENT,
                tracking_code VARCHAR(50),
                import_file_id INTEGER,
                import_file_code VARCHAR(50),
                policy_id INTEGER,
                carrier_id INTEGER,
                terminal_id INTEGER,
                carrier_name VARCHAR(100),
                bill_of_lading_no VARCHAR(100),
                port_name VARCHAR(100),
                discharge_date DATE,
                gate_out_date DATE,
                empty_return_date DATE,
                containers JSON,
                ancillary_fees JSON,
                total_demurrage_fx FLOAT,
                total_detention_fx FLOAT,
                total_storage_egp FLOAT,
                currency VARCHAR(10),
                exchange_rate FLOAT,
                total_cost_egp FLOAT,
                status VARCHAR(50),
                is_pushed_to_settlement BOOLEAN,
                settlement_record_id INTEGER,
                notes TEXT,
                is_active BOOLEAN,
                created_at DATETIME,
                created_by VARCHAR(100),
                updated_at DATETIME,
                updated_by VARCHAR(100)
            )
        """))
        db_session.commit()

        db_session.execute(text("""
            INSERT INTO demurrage_trackings (
                tracking_code, carrier_name, bill_of_lading_no, discharge_date,
                status, created_by, exchange_rate, total_cost_egp, total_demurrage_fx, is_active, notes
            ) VALUES (
                'TRK-LEGACY-001', 'MSC', 'BL-LEGACY', '2026-01-01',
                NULL, NULL, NULL, NULL, NULL, 1, 'x'
            )
        """))
        db_session.commit()

        res = client.get("/api/v1/demurrage-detention/trackings")
        assert res.status_code == 200
        data = res.json()
        assert len(data) >= 1
        legacy_item = next(item for item in data if item["tracking_code"] == "TRK-LEGACY-001")
        assert legacy_item["status"] == "Free Time Active"
        assert legacy_item["created_by"] is None
        assert legacy_item["exchange_rate"] is None
        assert legacy_item["total_cost_egp"] is None
        assert legacy_item["total_demurrage_fx"] is None
        assert legacy_item["notes"] == "x"
