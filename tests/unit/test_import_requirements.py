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
    # No HS code anywhere (no tariff on PO lines, none on the invoice or checklist): nothing is invented.
    assert pdata["hs_code_items"] == []
    assert pdata["hs_code"] is None
    assert [m["code"] for m in pdata["messages"]] == ["PREFILL_NO_HS"]


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
    res2 = client.post("/api/v1/import-requirements", json=payload2)
    assert res2.status_code == 409
    detail = res2.json()["detail"]
    assert detail["code"] == "IR_ASSESSMENT_EXISTS"
    assert detail["assessment_code"] == res1.json()["assessment_code"]
    assert "IMP-2026-0099" in detail["message"]


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


# ── Phase-1 fixes: IR-01..04 ────────────────────────────────────────────────────

def _make_file(db, code="IMP-2026-PF01", **extra):
    from modules.import_files.model import ImportFile

    file_obj = ImportFile(import_file_code=code, company_name="Importer", supplier_name="Supplier", status="Draft", **extra)
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)
    return file_obj


def test_get_update_restore_delete_unknown_id_is_404():
    assert client.get("/api/v1/import-requirements/9999").status_code == 404
    assert client.put("/api/v1/import-requirements/9999", json={"coo_status": "Pending"}).status_code == 404
    assert client.post("/api/v1/import-requirements/9999/restore").status_code == 404
    assert client.delete("/api/v1/import-requirements/9999").status_code == 404


def test_prefill_unknown_file_is_404():
    res = client.get("/api/v1/import-requirements/prefill/9999")
    assert res.status_code == 404


def test_update_explicit_null_clears_optional_field():
    created = client.post("/api/v1/import-requirements", json={
        "shipment_value_usd": 10.0, "coo_notes": "to clear", "overall_status": "Draft", "risk_level": "Low",
    }).json()
    res = client.put(f"/api/v1/import-requirements/{created['assessment_id']}", json={"coo_notes": None})
    assert res.status_code == 200
    assert res.json()["coo_notes"] is None
    # Fields that were not sent are untouched.
    assert res.json()["shipment_value_usd"] == 10.0


def test_update_null_on_required_column_is_422():
    created = client.post("/api/v1/import-requirements", json={
        "shipment_value_usd": 10.0, "overall_status": "Draft", "risk_level": "Low",
    }).json()
    res = client.put(f"/api/v1/import-requirements/{created['assessment_id']}", json={"coo_status": None})
    assert res.status_code == 422


def test_update_moving_to_a_file_that_has_an_assessment_is_409():
    a = client.post("/api/v1/import-requirements", json={"import_file_id": 501, "shipment_value_usd": 1.0}).json()
    b = client.post("/api/v1/import-requirements", json={"import_file_id": 502, "shipment_value_usd": 1.0}).json()
    res = client.put(f"/api/v1/import-requirements/{b['assessment_id']}", json={"import_file_id": 501})
    assert res.status_code == 409
    assert res.json()["detail"]["assessment_code"] == a["assessment_code"]


def test_assessment_codes_continue_from_highest_suffix():
    first = client.post("/api/v1/import-requirements", json={"shipment_value_usd": 1.0}).json()
    second = client.post("/api/v1/import-requirements", json={"shipment_value_usd": 1.0}).json()
    client.delete(f"/api/v1/import-requirements/{second['assessment_id']}")
    third = client.post("/api/v1/import-requirements", json={"shipment_value_usd": 1.0}).json()
    n1, n2, n3 = (int(x["assessment_code"].rsplit("-", 1)[1]) for x in (first, second, third))
    assert (n2, n3) == (n1 + 1, n1 + 2)


def test_audit_user_is_recorded_on_create_and_update():
    created = client.post("/api/v1/import-requirements", json={"shipment_value_usd": 1.0}).json()
    assert created["created_by"] == created["updated_by"] != "System"
    updated = client.put(f"/api/v1/import-requirements/{created['assessment_id']}", json={"coo_status": "Pending"})
    assert updated.json()["updated_by"] == created["created_by"]


def test_task_sync_failure_is_logged_not_raised(monkeypatch, caplog):
    import modules.import_requirements.service as ir_service

    def boom(db, assessment_id):
        raise RuntimeError("sync down")

    monkeypatch.setattr(ir_service, "sync_regulatory_tasks_and_alerts", boom)
    with caplog.at_level("ERROR"):
        res = client.post("/api/v1/import-requirements", json={"shipment_value_usd": 1.0})
    assert res.status_code == 201
    assert any("Regulatory requirement sync" in r.getMessage() and "failed" in r.getMessage() for r in caplog.records)


def test_prefill_without_any_data_never_fabricates():
    db = TestingSessionLocal()
    file_id = _make_file(db).import_file_id
    db.close()

    pdata = client.get(f"/api/v1/import-requirements/prefill/{file_id}").json()
    assert pdata["hs_code_items"] == []
    assert pdata["hs_code"] is None
    assert pdata["commodity_description"] is None
    assert pdata["country_of_origin"] is None
    assert pdata["coo_type"] is None
    assert pdata["permit_issuing_authority"] is None
    assert pdata["inspection_body"] is None
    assert pdata["messages"] == [{"code": "PREFILL_NO_HS", "params": {"import_file_code": "IMP-2026-PF01"}, "severity": "warning"}]


def test_prefill_uses_po_line_tariff_and_goeic_code_for_decree_43():
    from datetime import date
    from modules.currencies.model import Currency
    from modules.customs_tariff.model import CustomsTariff
    from modules.purchase_orders.model import POLineItem, PurchaseOrder

    db = TestingSessionLocal()
    file_obj = _make_file(db, code="IMP-2026-PF02")
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    t_goeic = CustomsTariff(
        hs_code="8516.60", hs_description="Ovens", customs_duty_rate=20, vat_rate=14, requires_coo=True,
        regulatory_authority="الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)", effective_from=date(2020, 1, 1),
    )
    # "43" inside free text no longer marks Decree 43: only the GOEIC body code does.
    t_other = CustomsTariff(
        hs_code="3926.90", hs_description="Plastics", customs_duty_rate=10, vat_rate=14,
        regulatory_authority="Ministerial decree 43 annex", effective_from=date(2020, 1, 1),
    )
    db.add_all([usd, t_goeic, t_other])
    db.commit()
    po = PurchaseOrder(po_number="PO-2026-PF2", import_file_id=file_obj.import_file_id, project_id=1, company_id=1,
                       supplier_id=1, incoterm_id=1, currency_id=usd.currency_id)
    db.add(po)
    db.commit()
    db.add_all([
        POLineItem(po_id=po.po_id, item_code="OV-1", description_ar="Oven", tariff_id=t_goeic.tariff_id,
                   quantity=2, unit_price=50, total_price=100),
        POLineItem(po_id=po.po_id, item_code="PL-1", description_ar="Plastic", tariff_id=t_other.tariff_id,
                   quantity=1, unit_price=30, total_price=30),
        POLineItem(po_id=po.po_id, item_code="NO-HS", description_ar="Untariffed", quantity=1, unit_price=5, total_price=5),
    ])
    db.commit()
    file_id = file_obj.import_file_id
    db.close()

    pdata = client.get(f"/api/v1/import-requirements/prefill/{file_id}").json()
    items = {i["hs_code"]: i for i in pdata["hs_code_items"]}
    assert set(items) == {"8516.60", "3926.90"}
    assert items["8516.60"]["decree_43_applicable"] is True
    assert items["8516.60"]["regulatory_authority"] == "GOEIC"
    assert items["8516.60"]["coo_required"] is True
    assert items["8516.60"]["coo_type"] is None  # no EUR.1 default
    assert items["8516.60"]["item_code"] == "OV-1"
    assert items["3926.90"]["decree_43_applicable"] is False
    assert pdata["shipment_value"] == 135.0  # untariffed line still counts in the value
    assert pdata["currency"] == "USD"
    assert pdata["messages"] == [{"code": "PREFILL_LINE_NO_HS", "params": {"po_number": "PO-2026-PF2", "item_code": "NO-HS"}, "severity": "warning"}]


def test_prefill_uses_consultation_hs_when_nothing_else():
    from modules.customs_consultation.model import CustomsChecklistItem, CustomsConsultationSession

    db = TestingSessionLocal()
    file_obj = _make_file(db, code="IMP-2026-PF03")
    consult = CustomsConsultationSession(consultation_code="CS-PF3", title="t", broker_id=1, broker_name="b",
                                         import_file_id=file_obj.import_file_id)
    db.add(consult)
    db.commit()
    db.add(CustomsChecklistItem(consultation_id=consult.consultation_id, document_type="Inspection certificate",
                                hs_code="7308.90", regulatory_agency="GOEIC", status="Pending", is_required=True))
    db.commit()
    file_id = file_obj.import_file_id
    db.close()

    pdata = client.get(f"/api/v1/import-requirements/prefill/{file_id}").json()
    assert [i["hs_code"] for i in pdata["hs_code_items"]] == ["7308.90"]
    assert pdata["hs_code_items"][0]["item_code"] is None
    assert pdata["inspection_body"] == "GOEIC"
    assert pdata["decree_43_applicable"] is True
    assert pdata["messages"] == []


def test_restore_or_reactivating_update_respects_one_assessment_per_file():
    a = client.post("/api/v1/import-requirements", json={"import_file_id": 601, "shipment_value_usd": 1.0}).json()
    client.delete(f"/api/v1/import-requirements/{a['assessment_id']}")
    client.post("/api/v1/import-requirements", json={"import_file_id": 601, "shipment_value_usd": 2.0})
    restore = client.post(f"/api/v1/import-requirements/{a['assessment_id']}/restore")
    assert restore.status_code == 409
    assert restore.json()["detail"]["code"] == "IR_ASSESSMENT_EXISTS"
    update = client.put(f"/api/v1/import-requirements/{a['assessment_id']}", json={"coo_status": "Pending"})
    assert update.status_code == 409


def test_decree_43_flag_only_on_the_hs_line_of_the_goeic_finding():
    from datetime import date
    from modules.currencies.model import Currency
    from modules.customs_consultation.model import CustomsChecklistItem, CustomsConsultationSession
    from modules.customs_tariff.model import CustomsTariff
    from modules.purchase_orders.model import POLineItem, PurchaseOrder

    db = TestingSessionLocal()
    file_obj = _make_file(db, code="IMP-2026-D43")
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    t1 = CustomsTariff(hs_code="8418.10", hs_description="Fridges", customs_duty_rate=20, vat_rate=14,
                       effective_from=date(2020, 1, 1))
    t2 = CustomsTariff(hs_code="9403.20", hs_description="Furniture", customs_duty_rate=20, vat_rate=14,
                       effective_from=date(2020, 1, 1))
    db.add_all([usd, t1, t2])
    db.commit()
    po = PurchaseOrder(po_number="PO-2026-D43", import_file_id=file_obj.import_file_id, project_id=1, company_id=1,
                       supplier_id=1, incoterm_id=1, currency_id=usd.currency_id)
    db.add(po)
    db.commit()
    db.add_all([
        POLineItem(po_id=po.po_id, item_code="F-1", description_ar="Fridge", tariff_id=t1.tariff_id, quantity=1, unit_price=10, total_price=10),
        POLineItem(po_id=po.po_id, item_code="T-1", description_ar="Table", tariff_id=t2.tariff_id, quantity=1, unit_price=10, total_price=10),
    ])
    consult = CustomsConsultationSession(consultation_code="CS-D43", title="t", broker_id=1, broker_name="b",
                                         import_file_id=file_obj.import_file_id)
    db.add(consult)
    db.commit()
    db.add(CustomsChecklistItem(consultation_id=consult.consultation_id, document_type="Factory registration",
                                hs_code="84181000", regulatory_agency="GOEIC", status="Pending", is_required=True))
    db.commit()
    file_id = file_obj.import_file_id
    db.close()

    pdata = client.get(f"/api/v1/import-requirements/prefill/{file_id}").json()
    items = {i["hs_code"]: i for i in pdata["hs_code_items"]}
    assert pdata["decree_43_applicable"] is True              # file-level finding
    assert items["8418.10"]["decree_43_applicable"] is True   # the line the GOEIC finding names
    assert items["9403.20"]["decree_43_applicable"] is False  # other lines are not flagged


def test_advanced_operational_pillars_and_adaptive_shelflife():
    """Verify the new operational pillars: adaptive shelf-life, CargoX readiness, sampling, detention, and maker-checker."""
    from modules.currencies.model import Currency
    db = TestingSessionLocal()
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.commit()
    file_obj = _make_file(db, code="IF-ADV-001")

    # Create assessment with advanced operational pillars
    payload = {
        "import_file_id": file_obj.import_file_id,
        "import_file_code": file_obj.import_file_code,
        "hs_code": "0406.90",
        "commodity_description": "Cheddar Cheese",
        "country_of_origin": "NL",
        "currency": "USD",
        "shipment_value": 25000.0,
        "shipment_value_usd": 27000.0,
        "cargox_verified": True,
        "cargox_status": "Verified",
        "ready_for_acid": True,
        "triple_match_status": "Matched",
        "commodity_group_matched": True,
        "import_card_group_code": "GRP-FOOD-04",
        "is_shelflife_applicable": True,
        "shelf_life_total_days": 365,
        "shelf_life_remaining_percent": 75.0,
        "artwork_arabic_approved": True,
        "labeling_notes": "Complies with ES 1008/2020",
        "sampling_required": True,
        "lab_type": "Central Food Safety Lab",
        "detention_allowed": True,
        "estimated_lab_fees": 4500.0,
        "cold_chain_required": True,
        "target_temperature": "+4C",
        "data_logger_verified": True,
        "is_hazmat": False,
        "checker_user_id": 10,
        "checker_approved": True,
        "checker_notes": "Double-checked against NFSA requirements",
        "is_overridden": False,
        "overall_status": "Cleared",
        "risk_level": "Low",
        "assessed_by": "Compliance Lead",
        "hs_code_items": [
            {
                "hs_code": "0406.90",
                "commodity_description": "Cheddar Cheese",
                "item_value": 25000.0,
                "quantity": 1000.0,
                "cargox_verified": True,
                "ready_for_acid": True,
                "commodity_group_matched": True,
                "is_shelflife_applicable": True,
                "shelf_life_total_days": 365,
                "shelf_life_remaining_percent": 75.0,
                "artwork_arabic_approved": True,
                "sampling_required": True,
                "detention_allowed": True,
                "cold_chain_required": True,
                "target_temperature": "+4C",
            }
        ],
    }

    resp = client.post("/api/v1/import-requirements", json=payload)
    assert resp.status_code == 201, resp.text
    created = resp.json()
    assert created["cargox_verified"] is True
    assert created["cargox_status"] == "Verified"
    assert created["ready_for_acid"] is True
    assert created["is_shelflife_applicable"] is True
    assert created["shelf_life_remaining_percent"] == 75.0
    assert created["artwork_arabic_approved"] is True
    assert created["detention_allowed"] is True
    assert created["cold_chain_required"] is True
    assert created["checker_approved"] is True
    assert created["checker_notes"] == "Double-checked against NFSA requirements"

    # Verify retrieval
    get_resp = client.get(f"/api/v1/import-requirements/{created['assessment_id']}")
    assert get_resp.status_code == 200
    retrieved = get_resp.json()
    assert retrieved["assessment_code"] == created["assessment_code"]
    assert retrieved["cargox_verified"] is True
    assert retrieved["detention_allowed"] is True
    assert retrieved["estimated_lab_fees"] == 4500.0
    db.close()
