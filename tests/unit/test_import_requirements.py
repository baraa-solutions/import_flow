import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import main # Import main to register all SQLAlchemy models in Base.metadata
from database.database import Base, get_db
from main import app

engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    Base.metadata.drop_all(bind=engine)
    app.dependency_overrides.clear()

client = TestClient(app)


def test_create_assessment_success():
    payload = {
        "shipment_value_usd": 1000.5,
        "coo_required": True,
        "coo_status": "Pending",
        "overall_status": "Draft",
        "risk_level": "Low"
    }
    response = client.post("/api/v1/import-requirements", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["assessment_code"].startswith("BP011-")
    assert data["shipment_value_usd"] == 1000.5
    assert data["coo_required"] is True
    assert data["coo_status"] == "Pending"
    assert data["risk_level"] == "Low"


def test_update_coo_status():
    payload = {
        "shipment_value_usd": 500,
        "overall_status": "Draft",
        "risk_level": "Medium"
    }
    response = client.post("/api/v1/import-requirements", json=payload)
    assert response.status_code == 201
    assessment_id = response.json()["assessment_id"]

    update_payload = {
        "coo_status": "Obtained"
    }
    update_res = client.put(f"/api/v1/import-requirements/{assessment_id}", json=update_payload)
    assert update_res.status_code == 200
    assert update_res.json()["coo_status"] == "Obtained"


def test_invalid_risk_level_raises_error():
    payload = {
        "shipment_value_usd": 100,
        "risk_level": "InvalidRisk"
    }
    response = client.post("/api/v1/import-requirements", json=payload)
    assert response.status_code == 422


def test_soft_delete_assessment():
    payload = {
        "shipment_value_usd": 200,
        "overall_status": "Draft",
        "risk_level": "Low"
    }
    response = client.post("/api/v1/import-requirements", json=payload)
    assert response.status_code == 201
    assessment_id = response.json()["assessment_id"]

    delete_res = client.delete(f"/api/v1/import-requirements/{assessment_id}")
    assert delete_res.status_code == 204

    get_res = client.get(f"/api/v1/import-requirements/{assessment_id}")
    assert get_res.status_code == 404


def test_create_full_5_pillars_assessment():
    payload = {
        "hs_code": "8415820010",
        "commodity_description": "Air Conditioning Units",
        "country_of_origin": "China",
        "shipment_value_usd": 65000.0,
        # Pillar 1
        "decree_43_applicable": True,
        "white_list_required": True,
        "white_list_verified": True,
        "factory_registration_no": "GOEIC-REG-12345",
        "supplier_name": "Gree Electric Appliances",
        # Pillar 2
        "coo_required": True,
        "coo_type": "EUR.1",
        "coo_status": "Obtained",
        "coo_notes": "100% duty reduction under agreement",
        # Pillar 3
        "inspection_required": True,
        "inspection_body": "SGS",
        "inspection_status": "Completed",
        "inspection_report_no": "SGS-2026-9900",
        # Pillar 4
        "import_permit_required": True,
        "permit_issuing_authority": "EEAA",
        "permit_number": "EEAA-9988",
        "permit_status": "Approved",
        # Pillar 5
        "msds_required": True,
        "msds_status": "Obtained",
        "coa_required": True,
        "coa_status": "Obtained",
        # Summary
        "overall_status": "Complete",
        "risk_level": "Low",
        "assessed_by": "Kamal"
    }
    response = client.post("/api/v1/import-requirements", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["factory_registration_no"] == "GOEIC-REG-12345"
    assert data["inspection_report_no"] == "SGS-2026-9900"
    assert data["permit_number"] == "EEAA-9988"
    assert data["decree_43_applicable"] is True
    assert data["white_list_verified"] is True
    assert data["coa_required"] is True
    assert data["overall_status"] == "Complete"


def test_import_file_prefill_endpoint():
    db = TestingSessionLocal()
    from modules.import_files.model import ImportFile
    from modules.suppliers.model import Supplier
    from modules.customs_consultation.model import CustomsConsultationSession, CustomsChecklistItem

    supp = Supplier(
        supplier_code="SUP-TEST-001",
        company_name="Suzhou Yuheng Textile Co., Ltd.",
        supplier_type="Manufacturer",
        foreign_exporter_country="China",
        foreign_exporter_country_code="CN",
        foreign_exporter_id="CN99887766",
        registration_type="Tax Number",
        address="Suzhou Industrial Park, China",
    )
    db.add(supp)
    db.commit()
    db.refresh(supp)

    file_obj = ImportFile(
        import_file_code="IMP-2026-0002",
        company_name="Arki Brands",
        supplier_id=supp.supplier_id,
        supplier_name=supp.company_name,
        po_number="PO-2026-888",
        acid_number="7595528271015010011",
        invoices_data=[{"invoice_no": "INV-001", "amount": 45000.0, "currency": "USD"}],
        shipment_mode="Sea Freight",
        incoterm_code="FOB",
        status="Active",
        owner="Kamal",
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)

    # Add Consultation session
    consult = CustomsConsultationSession(
        consultation_code="CS-2026-0001",
        title="Customs study for Textile Import",
        broker_id=1,
        broker_name="El-Ahram Brokerage",
        import_file_id=file_obj.import_file_id,
        overall_status="Clearance Ready",
        readiness_percentage=100.0,
    )
    db.add(consult)
    db.commit()
    db.refresh(consult)

    item1 = CustomsChecklistItem(
        consultation_id=consult.consultation_id,
        document_type="قرار 43 وتسجيل المصانع المؤهلة (GOEIC)",
        regulatory_agency="الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)",
        status="Verified",
        is_required=True,
    )
    item2 = CustomsChecklistItem(
        consultation_id=consult.consultation_id,
        document_type="Certificate of Origin (EUR.1 / Agadir)",
        status="Obtained",
        is_required=True,
        remarks="100% preferential reduction",
    )
    db.add_all([item1, item2])
    file_id = file_obj.import_file_id
    db.commit()
    db.close()

    res = client.get(f"/api/v1/import-requirements/prefill/{file_id}")
    assert res.status_code == 200
    pdata = res.json()
    assert pdata["import_file_code"] == "IMP-2026-0002"
    assert pdata["supplier_name"] == "Suzhou Yuheng Textile Co., Ltd."
    assert pdata["country_of_origin"] == "China"
    assert pdata["acid_number"] == "7595528271015010011"
    assert pdata["consultation_code"] == "CS-2026-0001"
    assert pdata["decree_43_applicable"] is True
    assert pdata["white_list_verified"] is True
    assert pdata["coo_required"] is True
    assert pdata["coo_status"] == "Obtained"
    assert len(pdata["hs_code_items"]) > 0


def test_prevent_duplicate_assessment_for_same_import_file():
    payload1 = {
        "import_file_id": 99,
        "import_file_code": "IMP-2026-0099",
        "shipment_value_usd": 15000.0,
        "coo_required": True,
        "overall_status": "Draft",
        "risk_level": "Low",
    }
    res1 = client.post("/api/v1/import-requirements", json=payload1)
    assert res1.status_code == 201

    # Second creation with same import_file_id must be blocked
    payload2 = {
        "import_file_id": 99,
        "import_file_code": "IMP-2026-0099",
        "shipment_value_usd": 20000.0,
        "coo_required": True,
        "overall_status": "Draft",
        "risk_level": "Medium",
    }
    with pytest.raises(Exception):
        client.post("/api/v1/import-requirements", json=payload2)


def test_restore_soft_deleted_assessment():
    payload = {
        "import_file_id": 105,
        "shipment_value_usd": 8000.0,
        "overall_status": "Draft",
        "risk_level": "Low",
    }
    res = client.post("/api/v1/import-requirements", json=payload)
    assert res.status_code == 201
    assessment_id = res.json()["assessment_id"]

    # Delete
    del_res = client.delete(f"/api/v1/import-requirements/{assessment_id}")
    assert del_res.status_code == 204

    # Restore via restore endpoint
    restore_res = client.post(f"/api/v1/import-requirements/{assessment_id}/restore")
    assert restore_res.status_code == 200
    assert restore_res.json()["is_active"] is True


def test_optional_acid_and_smart_tasks_generation():
    db = TestingSessionLocal()
    from modules.import_files.model import ImportFile
    from modules.smart_tasks.model import SmartTask

    # 1. Create an import file without ACID (Draft phase)
    file_obj = ImportFile(
        import_file_code="IMP-2026-TEST1",
        company_name="Test Importer Co",
        supplier_name="Test Global Supplier",
        estimated_cost=50000.0,
        estimated_cost_currency="USD",
        acid_number=None, # Not issued yet
        status="Draft",
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)

    # 2. Create Assessment without ACID, but with uncompleted regulatory requirements
    payload = {
        "import_file_id": file_obj.import_file_id,
        "import_file_code": file_obj.import_file_code,
        "shipment_value_usd": 50000.0,
        "decree_43_applicable": True,
        "white_list_verified": False, # Uncompleted Decree 43
        "import_permit_required": True,
        "permit_issuing_authority": "EEAA",
        "permit_status": "Pending", # Uncompleted permit
        "overall_status": "In Progress",
        "risk_level": "High",
    }
    res = client.post("/api/v1/import-requirements", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["acid_number"] is None # Cleanly allowed without error!

    # 3. Verify that SmartTasks were generated for uncompleted regulatory requirements
    tasks = db.query(SmartTask).filter(SmartTask.import_file_id == file_obj.import_file_id).all()
    assert len(tasks) >= 2
    task_titles = [t.title for t in tasks]
    assert any("Decree 43" in t for t in task_titles)
    assert any("EEAA" in t or "approval" in t for t in task_titles)
    req_tasks = [t for t in tasks if "REQ_TYPE:" in (t.notes or "")]
    assert req_tasks
    assert all(t.msg_code and t.msg_code.startswith("REQ_TASK_") for t in req_tasks)
    assert all(t.step_code == "STEP_03" for t in req_tasks)
    assert all(t.msg_params.get("acid_number") == "PENDING" for t in req_tasks)

    # 4. Now simulate updating the import file with the 19-digit ACID issued later
    from modules.import_files.service import update_import_file_service
    from modules.import_files.schemas import ImportFileUpdate
    update_import_file_service(
        db,
        file_obj.import_file_id,
        ImportFileUpdate(acid_number="1987654321098765432")
    )

    # 5. Check that assessment was auto-synchronized with the new ACID
    from modules.import_requirements.model import ImportRequirementAssessment
    updated_assessment = db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.import_file_id == file_obj.import_file_id
    ).first()
    assert updated_assessment.acid_number == "1987654321098765432"

    db.close()


