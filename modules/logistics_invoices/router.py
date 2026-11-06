"""
FastAPI Router for Logistics Service Invoices & Payments (LSI)
==============================================================
Provides endpoints for service invoices, 21 standard lines, B/L container locks,
marine insurance policies, advance payments, vouchers, and knock-offs.
"""

from __future__ import annotations

from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from modules.logistics_invoices.schemas import (
    LogisticsInvoiceCreate,
    LogisticsInvoiceUpdate,
    LogisticsInvoiceResponse,
    InsurancePolicyCreate,
    InsurancePolicyClaimCreate,
    InsurancePolicyResponse,
    InsurancePreviewResponse,
    ClearanceAdvancePaymentCreate,
    ClearanceAdvancePaymentResponse,
    ClearanceAdvanceSettlementCreate,
    ClearanceAdvanceSettlementResponse,
    LogisticsPaymentVoucherCreate,
    LogisticsPaymentVoucherResponse,
    PartnerBalanceCardResponse,
    ContainerLockStatusResponse,
    ThreeWayMatchResponse,
    PrefillLinesResponse,
    PartnerLedgerResponse,
    WhtForm41ReportResponse,
    InsurancePolicyClaimStatusUpdate,
)
from modules.logistics_invoices.service import LogisticsInvoicesService

router = APIRouter(
    prefix="/api/v1/logistics-invoices",
    tags=["Logistics Service Invoices & Payments"],
    dependencies=[Depends(get_current_user)],
)


# ============================================================================
# Invoices Endpoints
# ============================================================================

@router.post("", response_model=LogisticsInvoiceResponse, status_code=status.HTTP_201_CREATED)
def create_invoice(
    payload: LogisticsInvoiceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.create_invoice(payload, user_name=current_user.full_name or current_user.username)


@router.get("/prefill-lines", response_model=PrefillLinesResponse)
def get_prefill_lines(
    shipment_id: int = Query(...),
    partner_type: str = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_prefill_lines(shipment_id, partner_type)


@router.get("/container-lock-status", response_model=ContainerLockStatusResponse)
def get_container_lock_status(
    shipment_id: int = Query(...),
    bl_number: str = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_container_lock_status(shipment_id, bl_number)


@router.get("/exchange-rate/cbe")
def get_cbe_exchange_rate(
    currency: str = Query(...),
    target_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    rate = service.get_cbe_exchange_rate(currency, target_date)
    return {"currency": currency.upper(), "date": target_date or date.today(), "rate": rate}


@router.get("/partners/{partner_id}/balance-card", response_model=PartnerBalanceCardResponse)
def get_partner_balance_card(
    partner_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_partner_balance_card(partner_id)


@router.get("/partners/{partner_id}/open-invoices", response_model=List[LogisticsInvoiceResponse])
def get_open_invoices(
    partner_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.repo.get_open_invoices_by_partner(partner_id)


@router.get("/partners/{partner_id}/ledger", response_model=PartnerLedgerResponse)
def get_partner_ledger(
    partner_id: int,
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_partner_ledger(partner_id=partner_id, from_date=from_date, to_date=to_date)


@router.get("/reports/wht-form41", response_model=WhtForm41ReportResponse)
def get_wht_form41_report(
    year: int = Query(...),
    month: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_wht_form41_report(year=year, month=month)


# Literal list routes must be declared before GET /{id}: otherwise /{id} captures
# 'advances' / 'payments' and answers 422 (FastAPI matches routes in declaration order).
@router.get("/advances", response_model=List[ClearanceAdvancePaymentResponse])
def list_clearance_advances(
    shipment_id: Optional[int] = Query(None),
    partner_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.repo.list_advances(shipment_id=shipment_id, partner_id=partner_id, status=status)


@router.get("/payments", response_model=List[LogisticsPaymentVoucherResponse])
def list_payment_vouchers(
    partner_id: Optional[int] = Query(None),
    shipment_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    vouchers, _ = service.repo.list_vouchers(
        partner_id=partner_id, shipment_id=shipment_id, status=status, skip=skip, limit=limit
    )
    return vouchers


@router.get("/{id}", response_model=LogisticsInvoiceResponse)
def get_invoice(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.get_invoice(id)


@router.patch("/{id}", response_model=LogisticsInvoiceResponse)
def update_invoice(
    id: int,
    payload: LogisticsInvoiceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.update_invoice(id, payload, user_name=current_user.full_name or current_user.username)


@router.post("/{id}/submit", response_model=LogisticsInvoiceResponse)
def submit_invoice(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.submit_invoice(id, user_name=current_user.full_name or current_user.username)


@router.post("/{id}/approve", response_model=LogisticsInvoiceResponse)
def approve_invoice(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.approve")),
):
    service = LogisticsInvoicesService(db)
    return service.approve_invoice(id, user_name=current_user.full_name or current_user.username)


@router.post("/{id}/cancel", response_model=LogisticsInvoiceResponse)
def cancel_invoice(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.cancel_invoice(id, user_name=current_user.full_name or current_user.username)


@router.get("/{id}/three-way-match", response_model=ThreeWayMatchResponse)
def get_three_way_match(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    return service.validate_three_way_match(id)


@router.get("", response_model=List[LogisticsInvoiceResponse])
def list_invoices(
    shipment_id: Optional[int] = Query(None),
    partner_id: Optional[int] = Query(None),
    partner_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    payment_status: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.view")),
):
    service = LogisticsInvoicesService(db)
    invoices, _ = service.list_invoices(
        shipment_id=shipment_id,
        partner_id=partner_id,
        partner_type=partner_type,
        status=status,
        payment_status=payment_status,
        skip=skip,
        limit=limit,
    )
    return invoices


# ============================================================================
# Insurance Policies Endpoints
# ============================================================================

@router.get("/insurance/preview", response_model=InsurancePreviewResponse)
def get_insurance_preview(
    shipment_id: int = Query(...),
    premium_rate: float = Query(0.35),
    coverage_type: str = Query("all_risks"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    service = LogisticsInvoicesService(db)
    return service.calculate_insurance_preview(shipment_id, premium_rate, coverage_type)


@router.post("/insurance/policies", response_model=InsurancePolicyResponse, status_code=status.HTTP_201_CREATED)
def create_insurance_policy(
    payload: InsurancePolicyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.create_insurance_policy(payload, user_name=current_user.full_name or current_user.username)


@router.post("/insurance/policies/{id}/generate-invoice", response_model=LogisticsInvoiceResponse)
def generate_invoice_from_policy(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.generate_invoice_from_policy(id, user_name=current_user.full_name or current_user.username)


@router.post("/insurance/policies/{id}/claim", response_model=InsurancePolicyResponse)
def record_insurance_claim(
    id: int,
    payload: InsurancePolicyClaimCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.record_insurance_claim(id, payload, user_name=current_user.full_name or current_user.username)


@router.patch("/insurance/policies/{id}/claim-status", response_model=InsurancePolicyResponse)
def update_insurance_claim_status(
    id: int,
    payload: InsurancePolicyClaimStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.update_claim_status(policy_id=id, payload=payload, user_name=current_user.full_name or current_user.username)


@router.get("/insurance/policies/{id}", response_model=InsurancePolicyResponse)
def get_insurance_policy(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    service = LogisticsInvoicesService(db)
    policy = service.repo.get_policy_by_id(id)
    if not policy:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail=f"Policy ID {id} not found.")
    return policy


@router.get("/insurance/policies", response_model=List[InsurancePolicyResponse])
def list_insurance_policies(
    shipment_id: Optional[int] = Query(None),
    insurance_company_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    service = LogisticsInvoicesService(db)
    policies, _ = service.repo.list_policies(
        shipment_id=shipment_id,
        insurance_company_id=insurance_company_id,
        status=status,
        skip=skip,
        limit=limit,
    )
    return policies


# ============================================================================
# Clearance Advance Payments Endpoints
# ============================================================================

@router.post("/advances", response_model=ClearanceAdvancePaymentResponse, status_code=status.HTTP_201_CREATED)
def create_clearance_advance(
    payload: ClearanceAdvancePaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.create_advance(payload, user_name=current_user.full_name or current_user.username)


@router.post("/advances/{id}/settle", response_model=ClearanceAdvanceSettlementResponse)
def settle_clearance_advance(
    id: int,
    payload: ClearanceAdvanceSettlementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.manage")),
):
    service = LogisticsInvoicesService(db)
    return service.settle_advance(id, payload, user_name=current_user.full_name or current_user.username)


# ============================================================================
# Payment Vouchers & Knock-Off Endpoints
# ============================================================================

@router.post("/payments", response_model=LogisticsPaymentVoucherResponse, status_code=status.HTTP_201_CREATED)
def create_payment_voucher(
    payload: LogisticsPaymentVoucherCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("financial_approval.approve")),
):
    service = LogisticsInvoicesService(db)
    return service.create_payment_voucher(payload, user_name=current_user.full_name or current_user.username)
