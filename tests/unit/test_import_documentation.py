"""
Unit Tests for Phase 3 Import Documentation & ACI Module (BP-014 to BP-019)
"""

import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.projects.model import Project
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.customs_tariff.model import CustomsTariff
from modules.purchase_orders.model import PurchaseOrder
from modules.import_files.model import ImportFile
from modules.shipping_scenarios.model import ShippingEvaluationSession
from modules.freight_booking.model import ShipmentBooking
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    AcidRegistrationUpdate,
    BankingDocumentCreate,
    ShipmentDocumentCreate,
    CustomsDeclarationCreate,
)
import modules.import_documentation.service as service
import modules.import_documentation.repository as repo
from fastapi import HTTPException


@pytest.fixture
def db_session():
    """Creates in-memory SQLite DB fixture."""
    engine = create_engine("sqlite:///:memory:", echo=False)
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    db.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    db.add(Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True))
    db.commit()
    try:
        yield db
    finally:
        db.close()


class TestImportDocumentationBackend:
    def test_create_acid_session_service(self, db_session):
        payload = AcidRegistrationCreate(
            acid_number="1987654321098765432",
            importer_name="Egyptian Textile Corp",
            importer_tax_id="100-200-300",
            exporter_name="Shanghai Exports Ltd",
            exporter_reg_id="CN-SH-9876",
            exporter_country="China",
            proforma_invoice_no="PI-2026-001",
            pol_name="Shanghai Port, China",
            pod_name="Alexandria Port, Egypt",
            requested_date=date.today() - timedelta(days=30),
            generated_date=date.today() - timedelta(days=29),
            expiry_date=date.today() + timedelta(days=90),
            verification_notes="Automatic 100% match",
        )
        res = service.create_acid_session_service(db_session, payload)

        assert res.acid_id is not None
        assert res.acid_code.startswith("ACID-2026-")
        assert res.acid_number == "1987654321098765432"
        assert res.status == "Verified"
        assert res.is_verified is True
        assert res.days_to_expiry > 0

    def test_invalid_acid_number_length_raises_error(self, db_session):
        from pydantic import ValidationError

        with pytest.raises((ValidationError, HTTPException)):
            AcidRegistrationCreate(
                acid_number="1234567890",  # Only 10 digits instead of 19
                importer_name="Egyptian Import Co",
                importer_tax_id="100-200-300",
                exporter_name="Shanghai Exports",
                exporter_reg_id="CN-9900",
                exporter_country="China",
                proforma_invoice_no="PI-001",
                pol_name="Shanghai",
                pod_name="Alexandria",
                expiry_date=date.today() + timedelta(days=90),
            )

    def test_create_banking_document_service(self, db_session):
        payload = BankingDocumentCreate(
            doc_type="Form 4",
            bank_name="National Bank of Egypt",
            doc_reference_number="F4-998877",
            amount=50000.0,
            currency_code="USD",
            issue_date=date(2026, 8, 5),
            expiry_date=date(2026, 12, 31),
        )
        doc = service.create_banking_document_service(db_session, payload)

        assert doc.bank_doc_id is not None
        assert doc.bank_doc_code.startswith("FORM4-2026-")
        assert doc.amount == 50000.0
        assert doc.status in ["Received", "Form Issued", "Requested"]

    def test_cargox_and_bl_endorsement_service(self, db_session):
        doc_payload = ShipmentDocumentCreate(
            doc_name="Bill of Lading (B/L)",
            doc_number="MAEU123456789",
            issue_date=date(2026, 8, 8),
        )
        doc = service.create_shipment_document_service(db_session, doc_payload)

        # Upload CargoX & Endorse B/L
        updated = service.update_cargox_and_bl_endorsement_service(
            db_session,
            doc_id=doc.document_id,
            cargox_envelope_id="ENV-CGX-990011",
            endorsement_number="END-BL-776655",
        )
        assert updated.is_cargox_uploaded is True
        assert updated.cargox_envelope_id == "ENV-CGX-990011"
        assert updated.is_bl_endorsed is True
        assert updated.endorsement_number == "END-BL-776655"
        assert updated.status == "Endorsed"

    def test_create_customs_declaration_service(self, db_session):
        payload = CustomsDeclarationCreate(
            acid_number="1987654321098765432",
            form4_number="F4-998877",
            bl_number="MAEU123456789",
            total_cif_val_egp=2500000.0,
            total_customs_duties_egp=250000.0,
            total_vat_egp=385000.0,
        )
        dec = service.create_customs_declaration_service(db_session, payload)

        assert dec.declaration_id is not None
        assert dec.declaration_code.startswith("DEC46-2026-")
        assert dec.declaration_status == "Draft Prepared"

    def test_soft_delete_acid_session(self, db_session):
        payload = AcidRegistrationCreate(
            acid_number="9988776655443322110",
            importer_name="Egyptian Import Co",
            importer_tax_id="100-200-300",
            exporter_name="Shanghai Exports",
            exporter_reg_id="CN-9900",
            exporter_country="China",
            proforma_invoice_no="PI-001",
            pol_name="Shanghai",
            pod_name="Alexandria",
            expiry_date=date.today() + timedelta(days=90),
        )
        created = service.create_acid_session_service(db_session, payload)
        acid_id = created.acid_id

        success = repo.soft_delete_acid_session(db_session, acid_id)
        assert success is True
        assert repo.get_acid_session_by_id(db_session, acid_id) is None

        # Restore
        restored = service.restore_acid_session_service(db_session, acid_id)
        assert restored.acid_id == acid_id
        assert restored.is_active is True
