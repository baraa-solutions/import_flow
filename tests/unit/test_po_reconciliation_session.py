import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from fastapi import HTTPException

import main
from database.database import Base, get_db
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.import_documentation.model import POPackingReconciliationSession
from modules.import_documentation.schemas import (
    POReconciliationSessionCreate,
    POReconciliationSessionUpdate,
)
import modules.import_documentation.service as service


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    try:
        company = ImportCompany(
            company_id=1,
            importer_name="ECO ASSOCIATES FOR TRADING",
            vat_id="200-183-044",
            registration_number="12345",
            address="7 Hosni Osman St, Nasr City, Cairo",
            country="Egypt",
            importer_id="IMP-001",
            importer_id_expiry=date(2028, 1, 1),
            vat_id_expiry=date(2028, 1, 1),
            registration_expiry=date(2028, 1, 1),
        )
        db.add(company)
        db.commit()
        db.refresh(company)

        import_file = ImportFile(
            import_file_id=1,
            import_file_code="IMP-2026-0001",
            company_id=company.company_id,
            company_name="ECO ASSOCIATES FOR TRADING",
            supplier_id=1,
            supplier_name="G.I. INDUSTRIAL HOLDING SPA",
            current_stage="3. Booking & Doc Prep",
            is_active=True,
        )
        db.add(import_file)
        from modules.currencies.model import Currency
        db.add(Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True))
        db.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
        db.commit()
        db.refresh(import_file)

        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def test_create_and_get_po_reconciliation_session(db_session):
    file = db_session.query(ImportFile).first()
    assert file is not None

    schema = POReconciliationSessionCreate(
        import_file_id=file.import_file_id,
        final_invoice_number="V1/2562",
        final_packing_list_number="PL-2562",
        acid_number="2001830441013710010",
        shipper_name="G.I. INDUSTRIAL HOLDING SPA",
        total_invoice_amount=37741.0,
        currency="EUR",
        total_packages=4.0,
        total_net_weight_kg=2254.0,
        total_gross_weight_kg=2274.0,
        total_cbm=40.017,
        overall_status="FULLY_MATCHED",
        is_safe_for_certification=True,
        critical_discrepancies_count=0,
        warning_discrepancies_count=0,
        notes="Session verified with 0 discrepancies",
        certified_by="Ahmed Salah",
    )

    # 1. Create session via service
    res = service.create_po_reconciliation_session_service(db_session, schema)
    assert res.session_code.startswith("REC-")
    assert res.import_file_id == file.import_file_id
    assert res.import_file_code == "IMP-2026-0001"
    assert res.importer_name == "ECO ASSOCIATES FOR TRADING"
    assert res.total_invoice_amount == 37741.0
    # Server-owned gate: without extracted_invoice_data, overall_status is DRAFT
    assert res.overall_status == "DRAFT"
    assert res.is_safe_for_certification is False
    session_id = res.session_id

    # 2. Get session by ID
    get_res = service.get_po_reconciliation_session_by_id_service(db_session, session_id)
    assert get_res.session_code == res.session_code

    # 3. List sessions
    list_res = service.get_po_reconciliation_sessions_service(db_session)
    assert len(list_res) == 1
    assert list_res[0].session_id == session_id


def test_prevent_duplicate_session_for_same_import_file(db_session):
    file = db_session.query(ImportFile).first()
    assert file is not None

    schema1 = POReconciliationSessionCreate(
        import_file_id=file.import_file_id,
        final_invoice_number="INV-001",
        final_packing_list_number="PL-001",
        total_invoice_amount=10000.0,
        currency="USD",
    )

    # First creation should succeed
    res1 = service.create_po_reconciliation_session_service(db_session, schema1)
    assert res1.session_id is not None

    # Second creation for the SAME import file should raise HTTPException 400
    schema2 = POReconciliationSessionCreate(
        import_file_id=file.import_file_id,
        final_invoice_number="INV-002",
        final_packing_list_number="PL-002",
        total_invoice_amount=12000.0,
        currency="USD",
    )
    with pytest.raises(HTTPException) as exc_info:
        service.create_po_reconciliation_session_service(db_session, schema2)
    assert exc_info.value.status_code == 400
    assert "يوجد بالفعل جلسة مطابقة محفوظة" in exc_info.value.detail


def test_update_and_delete_po_reconciliation_session(db_session):
    file = db_session.query(ImportFile).first()

    schema = POReconciliationSessionCreate(
        import_file_id=file.import_file_id,
        final_invoice_number="INV-OLD",
        total_invoice_amount=5000.0,
        currency="EUR",
    )
    created = service.create_po_reconciliation_session_service(db_session, schema)
    sess_id = created.session_id

    # Update
    update_schema = POReconciliationSessionUpdate(
        final_invoice_number="INV-UPDATED",
        total_invoice_amount=5500.0,
        overall_status="ACCEPTED_WITH_WARNINGS",
    )
    updated = service.update_po_reconciliation_session_service(db_session, sess_id, update_schema)
    assert updated.final_invoice_number == "INV-UPDATED"
    assert updated.total_invoice_amount == 5500.0
    # Server-owned gate: without extracted data, client overall_status is ignored and stays DRAFT
    assert updated.overall_status == "DRAFT"

    # Delete (soft delete)
    del_res = service.delete_po_reconciliation_session_service(db_session, sess_id)
    assert del_res["deleted"] is True

    # Verify not in active list
    active_list = service.get_po_reconciliation_sessions_service(db_session)
    assert len(active_list) == 0


def test_audit_log_recorded_for_po_reconciliation(db_session):
    from modules.audit_logs.model import AuditLog

    file = db_session.query(ImportFile).first()
    schema = POReconciliationSessionCreate(
        import_file_id=file.import_file_id,
        final_invoice_number="INV-AUDIT-100",
        total_invoice_amount=8800.0,
        currency="USD",
        certified_by="Auditor Karim",
    )
    created = service.create_po_reconciliation_session_service(db_session, schema)

    # Verify CREATE audit log
    create_log = db_session.query(AuditLog).filter(
        AuditLog.entity_type == "POPackingReconciliationSession",
        AuditLog.entity_id == created.session_id,
        AuditLog.action == "CREATE",
    ).first()
    assert create_log is not None
    assert create_log.entity_code == created.session_code
    assert create_log.performed_by == "Auditor Karim"

    # Update session
    update_schema = POReconciliationSessionUpdate(
        final_invoice_number="INV-AUDIT-200",
        total_invoice_amount=9500.0,
        certified_by="Manager Sara",
    )
    updated = service.update_po_reconciliation_session_service(db_session, created.session_id, update_schema)

    # Verify UPDATE audit log
    update_log = db_session.query(AuditLog).filter(
        AuditLog.entity_type == "POPackingReconciliationSession",
        AuditLog.entity_id == created.session_id,
        AuditLog.action == "UPDATE",
    ).first()
    assert update_log is not None
    assert update_log.performed_by == "Manager Sara"
    assert "INV-AUDIT-100" in (update_log.old_values or "")
    assert "INV-AUDIT-200" in (update_log.new_values or "")

