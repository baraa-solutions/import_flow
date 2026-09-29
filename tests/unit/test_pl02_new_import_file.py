"""
Unit Tests for Task PL-02: New Import File (فتح ملف شحنة استيرادية جديد وإدراجه في دورة الحياة)
Verifies:
1. File creation with master data associations (company, supplier, broker, projects).
2. Auto-generated import_file_code and default status 'Open'.
3. Formula calculations: current_stage='Phase 1: Import Planning & Feasibility', current_module, progress_percent=15.0.
4. Lifecycle Board integration: initial stage activity at STEP_01 (In-Progress) and board summary count increment.
5. Operational Dashboard effect: active shipments count increment and Phase 1 distribution.
6. Validation guards: cross-company project linking prevention and duplicate custom file number rejection.
"""

import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ImportFileCreate
import modules.import_files.service as import_file_service
import modules.lifecycle_board.service as lifecycle_service


@pytest.fixture
def db_session():
    """Creates an in-memory SQLite database seeded with master data."""
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

    # 1. Seed Companies
    comp1 = ImportCompany(
        company_id=1,
        importer_name="SCAS For Construction And Finishing",
        vat_id="100-200-300",
        registration_number="12345",
        address="Cairo, Egypt",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date(2028, 1, 1),
        vat_id_expiry=date(2028, 1, 1),
        registration_expiry=date(2028, 1, 1),
    )
    comp2 = ImportCompany(
        company_id=2,
        importer_name="Delta Trading Co",
        vat_id="200-300-400",
        registration_number="67890",
        address="Alexandria, Egypt",
        country="Egypt",
        importer_id="IMP-002",
        importer_id_expiry=date(2028, 1, 1),
        vat_id_expiry=date(2028, 1, 1),
        registration_expiry=date(2028, 1, 1),
    )

    # 2. Seed Supplier
    sup1 = Supplier(
        supplier_id=10,
        company_name="G.I. Industrial Holding S.p.A.",
        supplier_code="SUP-001",
        supplier_type="Manufacturer",
        registration_type="Foreign Exporter",
        foreign_exporter_id="IT-EXP-9901",
        foreign_exporter_country="Italy",
        foreign_exporter_country_code="IT",
        address="Via Roma 1, Milan",
    )

    # 3. Seed Customs Broker
    broker1 = ExternalServiceProvider(
        provider_id=5,
        partner_code="PRT-005",
        partner_name="Al-Ahram Customs Clearance",
        partner_type="Customs Broker",
        phone="+20100998877",
        country="Egypt",
        clearance_license_number="LIC-EG-4402",
        authorized_ports="Alexandria Port, El Dekheila Port",
    )

    # 4. Seed Incoterm
    inco1 = Incoterm(
        incoterm_id=1,
        incoterm_code="FOB",
        incoterm_name="Free On Board",
        description="Seller delivers on board vessel",
    )

    # 5. Seed Projects
    proj1 = Project(
        project_id=100,
        project_code="PRJ-SCAS-01",
        project_name="Central HVAC Chillers",
        project_owner="Ahmed Sorour",
        company_id=1,
        supplier_id=10,
        incoterm_id=1,
        import_type="Direct Commercial",
        target_end_date="2026-12-31",
    )
    proj_other = Project(
        project_id=200,
        project_code="PRJ-DELTA-01",
        project_name="Delta Solar Panels",
        project_owner="Delta Team",
        company_id=2,
        supplier_id=10,
        incoterm_id=1,
        import_type="Direct Commercial",
    )

    db.add_all([comp1, comp2, sup1, broker1, inco1, proj1, proj_other])
    db.commit()

    try:
        yield db
    finally:
        db.close()


class TestPL02NewImportFile:
    def test_pl02_create_import_file_successful(self, db_session):
        """
        PL-02: Test creating a new import file with complete metadata.
        Verifies code generation, formulas, and stage attributes.
        """
        payload = ImportFileCreate(
            custom_file_number="FILE-2026-0001",
            company_id=1,
            company_name="SCAS For Construction And Finishing",
            supplier_id=10,
            supplier_name="G.I. Industrial Holding S.p.A.",
            broker_id=5,
            broker_name="Al-Ahram Customs Clearance",
            project_ids=[100],
            shipment_mode="Sea FCL",
            incoterm_code="FOB",
            priority="High",
            shipment_category="New Purchase",
            port_of_loading="Genoa Port (ITGOA)",
            port_of_discharge="El Dekheila Port (EGDKH)",
            target_free_days=21,
            estimated_cost=65000.0,
            estimated_cost_currency="EUR",
            owner="Ahmed Sorour",
        )

        file = import_file_service.create_import_file_service(db_session, payload, current_user="Ahmed Sorour")

        # 1. Assert entity attributes
        assert file.import_file_id is not None
        assert file.import_file_code.startswith("IMP-")
        assert file.custom_file_number == "FILE-2026-0001"
        assert file.company_id == 1
        assert file.company_name == "SCAS For Construction And Finishing"
        assert file.supplier_id == 10
        assert file.supplier_name == "G.I. Industrial Holding S.p.A."
        assert file.broker_id == 5
        assert file.broker_name == "Al-Ahram Customs Clearance"
        assert file.project_ids == [100]
        assert file.shipment_mode == "Sea FCL"
        assert file.incoterm_code == "FOB"
        assert file.port_of_loading == "Genoa Port (ITGOA)"
        assert file.port_of_discharge == "El Dekheila Port (EGDKH)"
        assert file.target_free_days == 21
        assert file.estimated_cost == 65000.0
        assert file.estimated_cost_currency == "EUR"
        assert file.owner == "Ahmed Sorour"
        assert file.status == "Open"
        assert file.is_active is True

        # 2. Assert calculated formulas for new draft/planning file
        assert file.current_stage == "Phase 1: Import Planning & Feasibility"
        assert file.current_module == "BP-001 Receive Purchase Order & Planning"
        assert file.progress_percent == 15.0
        assert "Evaluate shipping scenarios" in file.next_action
        assert file.next_action_code == "NA_EVALUATE_SCENARIOS_REQUEST_QUOTES"
        assert file.current_step_code == "STEP_01"
        assert file.current_phase_id == 1

    def test_pl02_lifecycle_board_and_dashboard_integration(self, db_session):
        """
        PL-02: Test that creating an import file:
        1. Seeds the initial stage activity at STEP_01 (In-Progress).
        2. Reflects in the Operational Dashboard with incremented shipment_count & Phase 1 count.
        3. Appears in the Lifecycle Board summary in Phase 1 / STEP_01.
        """
        # Baseline dashboard checks before creation
        dashboard_before = import_file_service.get_operational_dashboard_data_service(db_session)
        assert dashboard_before["shipment_count"] == 0

        payload = ImportFileCreate(
            company_id=1,
            company_name="SCAS For Construction And Finishing",
            supplier_id=10,
            supplier_name="G.I. Industrial Holding S.p.A.",
            shipment_mode="Sea FCL",
            incoterm_code="FOB",
            port_of_loading="Shanghai Port (CNSHA)",
            port_of_discharge="Alexandria Port (EGALY)",
            target_free_days=14,
            estimated_cost=45000.0,
            estimated_cost_currency="USD",
        )

        file = import_file_service.create_import_file_service(db_session, payload)

        # 1. Verify Operational Dashboard effect
        dashboard_after = import_file_service.get_operational_dashboard_data_service(db_session)
        assert dashboard_after["shipment_count"] == 1
        assert dashboard_after["phase_counts"]["Phase 1"] == 1
        assert len(dashboard_after["shipments"]) == 1
        assert dashboard_after["shipments"][0].import_file_code == file.import_file_code

        # 2. Verify Lifecycle Board integration
        board_summary = lifecycle_service.get_board_summary_service(db_session)
        assert board_summary.total_active_files >= 1
        # Phase 1 summary
        phase_1 = next(p for p in board_summary.phases if p.phase_id == 1)
        assert phase_1.total_active_shipments == 1
        assert phase_1.step_counts.get("STEP_01") == 1

        # Shipment stage card in STEP_01
        card = next((c for c in board_summary.all_shipments if c.import_file_code == file.import_file_code), None)
        assert card is not None
        assert card.step_code == "STEP_01"
        assert "STEP_01" in phase_1.step_codes
        assert card.status == "In-Progress"

    def test_pl02_project_cross_company_validation(self, db_session):
        """
        PL-02: Test that attempting to link a project belonging to a different company raises HTTP 400.
        """
        payload = ImportFileCreate(
            company_id=1,  # SCAS
            company_name="SCAS For Construction And Finishing",
            supplier_id=10,
            supplier_name="G.I. Industrial Holding S.p.A.",
            project_ids=[200],  # Belongs to Company 2 (Delta)
            shipment_mode="Sea FCL",
            incoterm_code="FOB",
            estimated_cost=10000.0,
        )

        with pytest.raises(HTTPException) as exc_info:
            import_file_service.create_import_file_service(db_session, payload)

        assert exc_info.value.status_code == 400
        assert "مرتبط بشركة مستوردة أخرى" in exc_info.value.detail

    def test_pl02_custom_file_number_uniqueness(self, db_session):
        """
        PL-02: Test that duplicate custom_file_number is rejected with HTTP 400.
        """
        payload1 = ImportFileCreate(
            custom_file_number="UNIQUE-FILE-889",
            company_id=1,
            company_name="SCAS For Construction And Finishing",
            supplier_id=10,
            supplier_name="G.I. Industrial Holding S.p.A.",
            shipment_mode="Sea FCL",
            incoterm_code="FOB",
            estimated_cost=20000.0,
        )
        import_file_service.create_import_file_service(db_session, payload1)

        payload2 = ImportFileCreate(
            custom_file_number="UNIQUE-FILE-889",
            company_id=1,
            company_name="SCAS For Construction And Finishing",
            supplier_id=10,
            supplier_name="G.I. Industrial Holding S.p.A.",
            shipment_mode="Air",
            incoterm_code="CIF",
            estimated_cost=15000.0,
        )
        with pytest.raises(HTTPException) as exc_info:
            import_file_service.create_import_file_service(db_session, payload2)

        assert exc_info.value.status_code == 400
        assert "مستخدم بالفعل لشحنة أخرى" in exc_info.value.detail
