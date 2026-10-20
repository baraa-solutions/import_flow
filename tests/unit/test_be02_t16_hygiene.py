"""
Unit tests for BE02-T16:
Financial approval hygiene: status codes, Arabic details, clone schemas, variance logs 404, soft-deleted file prefill 404.
"""
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Registers models on Base.metadata
from database.database import Base
from modules.auth.seed_rbac import seed_rbac
from modules.financial_approval import service
from modules.financial_approval.schemas import (
    ClonePaymentRequestRequest,
    CloneImportBudgetRequest,
    SwiftBatchConfirmResponse,
)
from modules.financial_approval.validators import BATCH_PENDING
from modules.financial_approval.model import SwiftExtractionBatch
from modules.import_files.model import ImportFile


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    seed_rbac(session)
    try:
        yield session
    finally:
        session.close()


def test_match_before_confirm_returns_409(db: Session):
    """Match reviewed batch before confirmation returns 409 FA_SWIFT_BATCH_STATUS_INVALID."""
    batch = SwiftExtractionBatch(
        batch_code="SWF-BATCH-2026-001",
        raw_source_text="Sample raw text",
        status=BATCH_PENDING,
    )
    db.add(batch)
    db.commit()
    db.refresh(batch)

    with pytest.raises(HTTPException) as exc_info:
        service.match_reviewed_batch_service(db, batch.batch_id)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "FA_SWIFT_BATCH_STATUS_INVALID"


def test_clone_with_invalid_amount_or_rate_raises_422():
    """Clone schemas reject amount <= 0 and exchange_rate <= 0 with 422 ValidationError."""
    with pytest.raises(ValidationError):
        ClonePaymentRequestRequest(new_requested_amount=0.0)

    with pytest.raises(ValidationError):
        ClonePaymentRequestRequest(new_requested_amount=-100.0)

    with pytest.raises(ValidationError):
        ClonePaymentRequestRequest(new_exchange_rate=0.0)

    with pytest.raises(ValidationError):
        ClonePaymentRequestRequest(new_exchange_rate=-50.0)

    with pytest.raises(ValidationError):
        CloneImportBudgetRequest(new_exchange_rate=0.0)

    with pytest.raises(ValidationError):
        CloneImportBudgetRequest(new_exchange_rate=-1.5)


def test_variance_logs_of_missing_budget_raises_404(db: Session):
    """Calling variance logs service for a non-existent budget raises 404."""
    with pytest.raises(HTTPException) as exc_info:
        service.get_budget_variance_logs_service(db, 999999)

    assert exc_info.value.status_code == 404


def test_prefill_of_soft_deleted_import_file_raises_404(db: Session):
    """Prefill import budget for a soft-deleted import file raises 404."""
    f = ImportFile(
        import_file_code="IMP-2026-9999",
        company_name="Test Company",
        supplier_name="Test Supplier",
        is_active=False,
    )
    db.add(f)
    db.commit()
    db.refresh(f)

    with pytest.raises(HTTPException) as exc_info:
        service.get_budget_prefill_service(db, f.import_file_id)

    assert exc_info.value.status_code == 404
