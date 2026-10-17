"""
Legacy additive schema upgrade (create_all + ALTER TABLE ADD COLUMN + one customs_tariffs table rebuild).

``migrate_db()`` (used by seed.py / reset_clean_production_db.py) upgrades ``database.DB_PATH`` — the same
file the SQLAlchemy engine uses — or an explicit ``db_path``. The customs_tariffs rebuild drops a table,
so it first takes a verified pre_migration_ backup and aborts if that fails.

CLI (update-system-plan A13/R12):
    python update_db_schema.py --db <path/to/db> --confirm
The target must not be in use, and a verified pre_migration_ backup is taken first (abort on failure).
"""
import sqlite3
import sys
from pathlib import Path
from typing import List, Optional, Union

from sqlalchemy import create_engine

from database.database import Base, engine, DB_PATH
from scripts.db_script_guard import (
    add_target_arguments,
    guard_destructive_target,
    run_cli_action,
    take_verified_backup,
)
from utils.db_safety import same_file
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.users.model import User
from modules.audit_logs.model import AuditLog
from modules.incoterms.model import Incoterm, CostItem, IncotermResponsibility
from modules.customs_tariff.model import CustomsTariff, PreferentialAgreement
from modules.transport_locations.model import TransportLocation
from modules.currencies.model import Currency, ExchangeRate
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PackingListItem, PurchaseOrder
from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.customs_consultation.model import CustomsConsultationSession, CustomsChecklistItem
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.customs_clearance_quotations.model import CustomsClearanceRFQ, CustomsClearanceQuotationItem, ClearanceServicePriceListItem
from modules.financial_approval.model import PaymentRequestSession, ImportBudgetApproval
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    POPackingReconciliationSession,
    DraftBLReviewSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
)
from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.file_closure.model import ImportFileClosureRecord
from modules.notifications.model import SystemNotification
from modules.smart_tasks.model import SmartTask
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.smart_document_upload.model import UploadSession
from modules.docs_customs_approval.model import CustomsDocumentApproval, DiscrepancyRectificationTicket
from modules.cargox.model import CargoXEnvelope, CargoXEnvelopeDocument, CargoXStandardInvoiceReviewSession
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.import_requirements.model import ImportRequirementAssessment
from modules.lifecycle_board.model import (
    ShipmentStageActivity,
    StepConfig,
    StepConfigAuditLog,
    PendingReferenceRecord,
)


SCRIPT_TAG = "update_db_schema"


def migrate_db(db_path: Optional[Union[str, Path]] = None, *, backups_dir: Optional[Path] = None):
    """Upgrade ``db_path`` (default: ``database.DB_PATH``, the engine's database)."""
    target = Path(db_path) if db_path else Path(DB_PATH)
    if same_file(target, DB_PATH):
        target_engine = engine
    else:
        target_engine = create_engine(f"sqlite:///{target.resolve().as_posix()}")
    try:
        _migrate(target, target_engine, backups_dir)
    finally:
        if target_engine is not engine:
            target_engine.dispose()


def _migrate(db_path: Path, engine, backups_dir: Optional[Path]):
    # 1. Create any missing tables
    Base.metadata.create_all(bind=engine)

    # 2. Migration for columns
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='external_service_providers'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(external_service_providers)")
        existing_cols = [info[1] for info in cursor.fetchall()]

        new_columns = [
            ("tax_id", "VARCHAR(50)"),
            ("commercial_register", "VARCHAR(50)"),
            ("clearance_license_number", "VARCHAR(50)"),
            ("scac_code", "VARCHAR(20)"),
            ("tracking_url", "VARCHAR(300)"),
            ("swift_code", "VARCHAR(20)"),
            ("bank_code", "VARCHAR(20)"),
            ("branch_name", "VARCHAR(100)"),
            ("rating", "FLOAT DEFAULT 5.0"),
            ("secondary_email", "VARCHAR(150)"),
            ("fax", "VARCHAR(50)"),
            ("website", "VARCHAR(200)"),
        ]

        for col_name, col_type in new_columns:
            if col_name not in existing_cols:
                try:
                    cursor.execute(f"ALTER TABLE external_service_providers ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to external_service_providers table.")
                except Exception as e:
                    print(f"Error adding column {col_name}: {e}")

    # Migration for suppliers table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='suppliers'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(suppliers)")
        sup_cols = [info[1] for info in cursor.fetchall()]
        sup_new_cols = [
            ("secondary_email", "VARCHAR(150)"),
            ("mobile", "VARCHAR(50)"),
            ("fax", "VARCHAR(50)"),
            ("bank_name", "VARCHAR(200)"),
            ("swift_code", "VARCHAR(50)"),
            ("account_number", "VARCHAR(100)"),
            ("iban", "VARCHAR(100)"),
            ("has_iso", "BOOLEAN DEFAULT 0"),
            ("registered_decree_43", "BOOLEAN DEFAULT 0"),
            ("white_list_registered", "BOOLEAN DEFAULT 0"),
            ("cargox_platform_id", "VARCHAR(100)"),
        ]
        for col_name, col_type in sup_new_cols:
            if col_name not in sup_cols:
                try:
                    cursor.execute(f"ALTER TABLE suppliers ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to suppliers table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to suppliers: {e}")


    # Migration for acid_registration_sessions table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='acid_registration_sessions'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(acid_registration_sessions)")
        acid_cols = [info[1] for info in cursor.fetchall()]
        acid_new_cols = [
            ("proforma_invoice_date", "DATE"),
        ]
        for col_name, col_type in acid_new_cols:
            if col_name not in acid_cols:
                try:
                    cursor.execute(f"ALTER TABLE acid_registration_sessions ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to acid_registration_sessions table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to acid_registration_sessions: {e}")

    # Migration for projects table

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='projects'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(projects)")
        proj_cols = [info[1] for info in cursor.fetchall()]
        if "additional_company_ids" not in proj_cols:
            try:
                cursor.execute("ALTER TABLE projects ADD COLUMN additional_company_ids VARCHAR(250);")
                print("Added column 'additional_company_ids' to projects table.")
            except Exception as e:
                print(f"Error adding column additional_company_ids: {e}")

    # Migration for banking_document_sessions table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='banking_document_sessions'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(banking_document_sessions)")
        bdoc_cols = [info[1] for info in cursor.fetchall()]
        bdoc_new_cols = [
            ("request_date", "DATE"),
            ("received_date", "DATE"),
            ("execution_days", "INTEGER DEFAULT 0"),
            ("tax_coding_sheet_status", "VARCHAR(50) DEFAULT 'NOT_STARTED'"),
            ("tax_coding_sheet_file_url", "VARCHAR(500)"),
            ("tax_coding_pulled_date", "DATE"),
            ("tax_coding_broker_id", "INTEGER"),
            ("tax_coding_broker_name", "VARCHAR(200)"),
            ("tax_coding_uploaded_date", "DATE"),
            ("tax_coding_accountant_name", "VARCHAR(200)"),
            ("items_pulled_verified", "BOOLEAN DEFAULT 0"),
            ("items_pulled_date", "DATE"),
            ("items_count_total", "INTEGER DEFAULT 0"),
            ("items_count_coded", "INTEGER DEFAULT 0"),
            ("regulatory_bodies_detected", "JSON"),
            ("nafeza_bank_link_status", "VARCHAR(50) DEFAULT 'PENDING'"),
            ("nafeza_bank_link_date", "DATE"),
            ("nafeza_linked_bank_id", "INTEGER"),
            ("nafeza_linked_bank_name", "VARCHAR(200)"),
            ("swift_executing_bank_id", "INTEGER"),
            ("swift_executing_bank_name", "VARCHAR(200)"),
            ("swift_reference_no", "VARCHAR(100)"),
            ("is_bank_matching_swift", "BOOLEAN DEFAULT 1"),
        ]
        for col_name, col_type in bdoc_new_cols:
            if col_name not in bdoc_cols:
                try:
                    cursor.execute(f"ALTER TABLE banking_document_sessions ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to banking_document_sessions table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to banking_document_sessions: {e}")

    # Migration for import_files table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='import_files'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(import_files)")
        imp_cols = [info[1] for info in cursor.fetchall()]
        imp_form4_cols = [
            ("form4_request_date", "DATE"),
            ("form4_received_date", "DATE"),
            ("form4_execution_days", "INTEGER"),
        ]
        for col_name, col_type in imp_form4_cols:
            if col_name not in imp_cols:
                try:
                    cursor.execute(f"ALTER TABLE import_files ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to import_files table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to import_files: {e}")
        if "closure_reason" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN closure_reason TEXT;")
                print("Added column 'closure_reason' to import_files table.")
            except Exception as e:
                print(f"Error adding column closure_reason: {e}")
        if "closed_at_phase" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN closed_at_phase VARCHAR(100);")
                print("Added column 'closed_at_phase' to import_files table.")
            except Exception as e:
                print(f"Error adding column closed_at_phase: {e}")
        if "acid_number" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN acid_number VARCHAR(50);")
                print("Added column 'acid_number' to import_files table.")
            except Exception as e:
                print(f"Error adding column acid_number: {e}")
        if "acid_issue_date" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN acid_issue_date DATE;")
                print("Added column 'acid_issue_date' to import_files table.")
            except Exception as e:
                print(f"Error adding column acid_issue_date: {e}")
        if "acid_expiry_date" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN acid_expiry_date DATE;")
                print("Added column 'acid_expiry_date' to import_files table.")
            except Exception as e:
                print(f"Error adding column acid_expiry_date: {e}")
        if "is_customs_released" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN is_customs_released BOOLEAN DEFAULT 0;")
                print("Added column 'is_customs_released' to import_files table.")
            except Exception as e:
                print(f"Error adding column is_customs_released: {e}")
        if "customs_released_at" not in imp_cols:
            try:
                cursor.execute("ALTER TABLE import_files ADD COLUMN customs_released_at DATETIME;")
                print("Added column 'customs_released_at' to import_files table.")
            except Exception as e:
                print(f"Error adding column customs_released_at: {e}")

        # Flexible Stage Navigation & Hold/Skip Lifecycle columns
        flexible_lifecycle_cols = [
            ("initial_starting_stage", "VARCHAR(100)"),
            ("initial_starting_step", "VARCHAR(100)"),
            ("paused_at_stage", "VARCHAR(100)"),
            ("paused_at_step", "VARCHAR(100)"),
            ("hold_reason", "TEXT"),
            ("hold_date", "DATETIME"),
            ("skipped_stages", "TEXT"),
        ]
        for col_name, col_type in flexible_lifecycle_cols:
            if col_name not in imp_cols:
                try:
                    cursor.execute(f"ALTER TABLE import_files ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to import_files table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to import_files: {e}")


    # Universal import_file_id migration for all operational tables
    target_tables = [
        "purchase_orders",
        "cbm_calculations",
        "shipping_evaluation_sessions",
        "freight_rfq_requests",
        "customs_consultation_sessions",
        "payment_request_sessions",
        "import_budget_approvals",
        "acid_registration_sessions",
        "banking_document_sessions",
        "shipment_document_items",
        "customs_declaration_drafts",
    ]

    for table_name in target_tables:
        cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}'")
        if cursor.fetchone():
            cursor.execute(f"PRAGMA table_info({table_name})")
            cols = [info[1] for info in cursor.fetchall()]
            if "import_file_id" not in cols:
                try:
                    cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN import_file_id INTEGER REFERENCES import_files(import_file_id);")
                    print(f"Added column 'import_file_id' to '{table_name}' table.")
                except Exception as e:
                    print(f"Error adding column import_file_id to {table_name}: {e}")

    # Migration for customs_tariffs table
    cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='customs_tariffs'")
    row = cursor.fetchone()
    if row:
        table_sql = row[0]
        if "uq_customs_tariff_hs_code_eff_from" not in table_sql and ("uq_customs_tariff_hs_code" in table_sql or "UNIQUE (hs_code)" in table_sql):
            print("Migrating customs_tariffs table schema to support date-based versioning...")
            # The rebuild drops tables: verified backup first, abort (raise) if it fails.
            conn.commit()
            take_verified_backup(db_path, tag=f"{SCRIPT_TAG}_customs_tariffs", backups_dir=backups_dir)
            cursor.execute("DROP INDEX IF EXISTS uq_customs_tariff_hs_code;")
            cursor.execute("DROP INDEX IF EXISTS ix_customs_tariffs_hs_code;")
            cursor.execute("DROP INDEX IF EXISTS ix_customs_tariffs_tariff_id;")
            cursor.execute("DROP TABLE IF EXISTS customs_tariffs_old;")
            cursor.execute("ALTER TABLE customs_tariffs RENAME TO customs_tariffs_old;")
            conn.commit()
            Base.metadata.tables["customs_tariffs"].create(bind=engine)
            cursor.execute("""
                INSERT INTO customs_tariffs (
                    tariff_id, hs_code, hs_description, customs_category,
                    customs_duty_rate, vat_rate, schedule_tax_rate, development_fee_rate, import_fee_rate, customs_service_fee_rate,
                    requires_coo, requires_inspection, requires_acid, regulatory_authority,
                    prior_approval_note, effective_from, effective_to, source_url,
                    last_verified_date, verified_by, confidence, notes, is_active, created_at, updated_at
                )
                SELECT 
                    tariff_id, hs_code, hs_description, customs_category,
                    customs_duty_rate, vat_rate, schedule_tax_rate, development_fee_rate, import_fee_rate, 1.00,
                    requires_coo, requires_inspection, requires_acid, regulatory_authority,
                    prior_approval_note, effective_from, effective_to, source_url,
                    last_verified_date, verified_by, confidence, notes, is_active, created_at, updated_at
                FROM customs_tariffs_old;
            """)
            cursor.execute("DROP TABLE customs_tariffs_old;")
            conn.commit()
            print("customs_tariffs table schema migration completed.")
        else:
            cursor.execute("PRAGMA table_info(customs_tariffs)")
            ct_cols = [info[1] for info in cursor.fetchall()]
            ct_new_cols = [
                ("prior_approval_note", "TEXT"),
                ("source_url", "VARCHAR(500)"),
                ("last_verified_date", "DATE"),
                ("verified_by", "VARCHAR(100)"),
                ("confidence", "VARCHAR(50)"),
            ]
            for col_name, col_type in ct_new_cols:
                if col_name not in ct_cols:
                    try:
                        cursor.execute(f"ALTER TABLE customs_tariffs ADD COLUMN {col_name} {col_type};")
                        print(f"Added column '{col_name}' ({col_type}) to customs_tariffs table.")
                    except Exception as e:
                        print(f"Error adding column {col_name} to customs_tariffs: {e}")

    # Migration for customs_consultation_sessions table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='customs_consultation_sessions'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(customs_consultation_sessions)")
        cc_cols = [info[1] for info in cursor.fetchall()]
        cc_new_cols = [
            ("total_broker_fees_egp", "FLOAT DEFAULT 0.0"),
            ("broker_price_list_id", "INTEGER"),
        ]
        for col_name, col_type in cc_new_cols:
            if col_name not in cc_cols:
                try:
                    cursor.execute(f"ALTER TABLE customs_consultation_sessions ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to customs_consultation_sessions table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to customs_consultation_sessions: {e}")

    # Migration for import_budget_approvals table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='import_budget_approvals'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(import_budget_approvals)")
        iba_cols = [info[1] for info in cursor.fetchall()]
        iba_new_cols = [
            ("invoice_amount_foreign", "FLOAT DEFAULT 0.0"),
            ("invoice_currency", "VARCHAR(10) DEFAULT 'USD'"),
            ("freight_cost_foreign", "FLOAT DEFAULT 0.0"),
            ("freight_currency", "VARCHAR(10) DEFAULT 'USD'"),
            ("exchange_rate", "FLOAT DEFAULT 50.0"),
        ]
        for col_name, col_type in iba_new_cols:
            if col_name not in iba_cols:
                try:
                    cursor.execute(f"ALTER TABLE import_budget_approvals ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to import_budget_approvals table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to import_budget_approvals: {e}")

    # Migration for payment_request_sessions table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='payment_request_sessions'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(payment_request_sessions)")
        prs_cols = [info[1] for info in cursor.fetchall()]
        prs_new_cols = [
            ("swift_receipt_date", "DATE"),
            ("swift_transferred_amount", "FLOAT"),
            ("swift_transferred_currency", "VARCHAR(10)"),
            ("swift_variance_amount", "FLOAT DEFAULT 0.0"),
            ("swift_variance_status", "VARCHAR(50) DEFAULT 'Pending'"),
            ("swift_processing_days", "INTEGER"),
            ("swift_reconciliation_notes", "TEXT"),
        ]
        for col_name, col_type in prs_new_cols:
            if col_name not in prs_cols:
                try:
                    cursor.execute(f"ALTER TABLE payment_request_sessions ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to payment_request_sessions table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to payment_request_sessions: {e}")

    # Migration for import_requirement_assessments table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='import_requirement_assessments'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(import_requirement_assessments)")
        ira_cols = [info[1] for info in cursor.fetchall()]
        ira_new_cols = [
            ("acid_number", "VARCHAR(50)"),
            ("consultation_id", "INTEGER"),
            ("consultation_code", "VARCHAR(50)"),
            ("confirmation_status", "VARCHAR(50) DEFAULT 'Pending Confirmation'"),
            ("is_post_acid_confirmed", "BOOLEAN DEFAULT 0"),
            ("confirmed_at", "DATETIME"),
            ("confirmed_by", "VARCHAR(100)"),
        ]
        for col_name, col_type in ira_new_cols:
            if col_name not in ira_cols:
                try:
                    cursor.execute(f"ALTER TABLE import_requirement_assessments ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to import_requirement_assessments table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to import_requirement_assessments: {e}")

    # Migration for acid_registration_sessions table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='acid_registration_sessions'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(acid_registration_sessions)")
        acid_cols = [info[1] for info in cursor.fetchall()]
        acid_new_cols = [
            ("po_number", "VARCHAR(100)"),
            ("po_date", "DATE"),
            ("importer_address", "VARCHAR(300)"),
            ("exporter_reg_type", "VARCHAR(100) DEFAULT 'VAT Number'"),
            ("exporter_country_code", "VARCHAR(10)"),
            ("exporter_address", "VARCHAR(300)"),
            ("exporter_phone", "VARCHAR(50)"),
            ("cargox_id", "VARCHAR(100)"),
            ("invoice_date", "DATE"),
            ("invoice_type", "VARCHAR(50) DEFAULT 'Proforma Invoice'"),
            ("invoice_attachment_name", "VARCHAR(255)"),
            ("customs_broker_id", "INTEGER"),
            ("customs_broker_name", "VARCHAR(200)"),
            ("customs_broker_phone", "VARCHAR(50)"),
            ("raw_nafeza_text", "TEXT"),
            ("requested_data", "JSON"),
            ("generated_data", "JSON"),
            ("discrepancies_data", "JSON"),
            ("discrepancy_override_reason", "TEXT"),
            ("has_discrepancies", "BOOLEAN DEFAULT 0"),
            ("execution_days", "INTEGER"),
        ]
        for col_name, col_type in acid_new_cols:
            if col_name not in acid_cols:
                try:
                    cursor.execute(f"ALTER TABLE acid_registration_sessions ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to acid_registration_sessions table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to acid_registration_sessions: {e}")

    # Migration for import_files table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='import_files'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(import_files)")
        imp_cols = [info[1] for info in cursor.fetchall()]
        imp_new_cols = [
            ("acid_request_date", "DATE"),
            ("acid_execution_days", "INTEGER"),
            ("form4_request_date", "DATE"),
            ("form4_received_date", "DATE"),
            ("form4_execution_days", "INTEGER"),
        ]
        for col_name, col_type in imp_new_cols:
            if col_name not in imp_cols:
                try:
                    cursor.execute(f"ALTER TABLE import_files ADD COLUMN {col_name} {col_type};")
                    print(f"Added column '{col_name}' ({col_type}) to import_files table.")
                except Exception as e:
                    print(f"Error adding column {col_name} to import_files: {e}")

    # Backfill execution days and sync ACID with linked ImportFiles
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='acid_registration_sessions'")
    if cursor.fetchone():
        cursor.execute("""
            SELECT acid_id, import_file_id, acid_number, requested_date, generated_date, expiry_date
            FROM acid_registration_sessions
            WHERE is_active = 1
        """)
        rows = cursor.fetchall()
        for row in rows:
            acid_id, import_file_id, acid_num, req_date, gen_date, exp_date = row
            exec_days = None
            if req_date and gen_date:
                try:
                    from datetime import datetime
                    d1 = datetime.strptime(str(req_date)[:10], "%Y-%m-%d")
                    d2 = datetime.strptime(str(gen_date)[:10], "%Y-%m-%d")
                    exec_days = max(0, (d2 - d1).days)
                except Exception:
                    pass
            
            if exec_days is not None:
                cursor.execute("UPDATE acid_registration_sessions SET execution_days = ? WHERE acid_id = ?", (exec_days, acid_id))

            if import_file_id and acid_num and acid_num != "PENDING":
                issue_d = gen_date or req_date
                cursor.execute("""
                    UPDATE import_files 
                    SET acid_number = ?, acid_request_date = ?, acid_issue_date = ?, acid_expiry_date = ?, acid_execution_days = ?
                    WHERE import_file_id = ?
                """, (acid_num, req_date, issue_d, exp_date, exec_days, import_file_id))


    # Migration for purchase_orders & po_line_items tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='purchase_orders'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(purchase_orders)")
        po_cols = [info[1] for info in cursor.fetchall()]
        if "country_of_origin" not in po_cols:
            try:
                cursor.execute("ALTER TABLE purchase_orders ADD COLUMN country_of_origin VARCHAR(100);")
                print("Added column 'country_of_origin' to purchase_orders table.")
            except Exception as e:
                print(f"Error adding column country_of_origin to purchase_orders: {e}")

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='po_line_items'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(po_line_items)")
        poli_cols = [info[1] for info in cursor.fetchall()]
        if "country_of_origin" not in poli_cols:
            try:
                cursor.execute("ALTER TABLE po_line_items ADD COLUMN country_of_origin VARCHAR(100);")
                print("Added column 'country_of_origin' to po_line_items table.")
            except Exception as e:
                print(f"Error adding column country_of_origin to po_line_items: {e}")

    conn.commit()
    conn.close()
    print("Database migration and ACID sync completed successfully.")


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Apply the legacy additive schema upgrade to ONE database.")
    add_target_arguments(parser, target_help="Database file to upgrade")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        guard_destructive_target(target, confirm=True, tag=SCRIPT_TAG, backups_dir=backups_dir)
        migrate_db(target, backups_dir=backups_dir)
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
