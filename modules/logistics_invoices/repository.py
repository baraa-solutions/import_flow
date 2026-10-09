"""
Repository for Logistics Service Invoices & Payments (LSI)
==========================================================
Database CRUD operations and queries without business logic.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import func, select, and_, or_
from sqlalchemy.orm import Session, joinedload

from modules.logistics_invoices.model import (
    LogisticsServiceInvoice,
    LogisticsInvoiceLine,
    LogisticsInvoiceContainer,
    InsurancePolicy,
    ClearanceAdvancePayment,
    ClearanceAdvanceSettlement,
    LogisticsPaymentVoucher,
    InvoiceKnockoff,
)


class LogisticsInvoicesRepository:
    def __init__(self, db: Session):
        self.db = db

    # ========================================================================
    # Sequence / Code Generators
    # ========================================================================

    def get_next_invoice_code(self) -> str:
        count = self.db.query(func.count(LogisticsServiceInvoice.invoice_id)).scalar() or 0
        year = datetime.now(timezone.utc).year
        return f"LSI-{year}-{count + 1:04d}"

    def get_next_policy_code(self) -> str:
        count = self.db.query(func.count(InsurancePolicy.policy_id)).scalar() or 0
        year = datetime.now(timezone.utc).year
        return f"POL-{year}-{count + 1:04d}"

    def get_next_advance_code(self) -> str:
        count = self.db.query(func.count(ClearanceAdvancePayment.advance_id)).scalar() or 0
        year = datetime.now(timezone.utc).year
        return f"ADV-{year}-{count + 1:04d}"

    def get_next_voucher_code(self) -> str:
        count = self.db.query(func.count(LogisticsPaymentVoucher.voucher_id)).scalar() or 0
        year = datetime.now(timezone.utc).year
        return f"LPV-{year}-{count + 1:04d}"

    # ========================================================================
    # Logistics Service Invoices
    # ========================================================================

    def create_invoice(self, invoice: LogisticsServiceInvoice) -> LogisticsServiceInvoice:
        self.db.add(invoice)
        self.db.flush()
        return invoice

    def get_invoice_by_id(self, invoice_id: int) -> Optional[LogisticsServiceInvoice]:
        return (
            self.db.query(LogisticsServiceInvoice)
            .options(
                joinedload(LogisticsServiceInvoice.lines),
                joinedload(LogisticsServiceInvoice.containers),
            )
            .filter(
                LogisticsServiceInvoice.invoice_id == invoice_id,
                LogisticsServiceInvoice.is_active == True,
            )
            .first()
        )

    def get_invoice_by_code(self, invoice_code: str) -> Optional[LogisticsServiceInvoice]:
        return (
            self.db.query(LogisticsServiceInvoice)
            .filter(
                LogisticsServiceInvoice.invoice_code == invoice_code,
                LogisticsServiceInvoice.is_active == True,
            )
            .first()
        )

    def find_duplicate_invoice(self, partner_id: int, invoice_number: str, exclude_id: Optional[int] = None) -> Optional[LogisticsServiceInvoice]:
        q = self.db.query(LogisticsServiceInvoice).filter(
            LogisticsServiceInvoice.partner_id == partner_id,
            LogisticsServiceInvoice.invoice_number == invoice_number,
            LogisticsServiceInvoice.is_active == True,
        )
        if exclude_id:
            q = q.filter(LogisticsServiceInvoice.invoice_id != exclude_id)
        return q.first()

    def list_invoices(
        self,
        shipment_id: Optional[int] = None,
        partner_id: Optional[int] = None,
        partner_type: Optional[str] = None,
        status: Optional[str] = None,
        payment_status: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[LogisticsServiceInvoice], int]:
        q = (
            self.db.query(LogisticsServiceInvoice)
            .options(
                joinedload(LogisticsServiceInvoice.lines),
                joinedload(LogisticsServiceInvoice.containers),
            )
            .filter(LogisticsServiceInvoice.is_active == True)
        )
        if shipment_id:
            q = q.filter(LogisticsServiceInvoice.shipment_id == shipment_id)
        if partner_id:
            q = q.filter(LogisticsServiceInvoice.partner_id == partner_id)
        if partner_type:
            q = q.filter(LogisticsServiceInvoice.partner_type == partner_type)
        if status:
            q = q.filter(LogisticsServiceInvoice.status == status)
        if payment_status:
            q = q.filter(LogisticsServiceInvoice.payment_status == payment_status)

        total = q.count()
        invoices = q.order_by(LogisticsServiceInvoice.invoice_id.desc()).offset(skip).limit(limit).all()
        return invoices, total

    def get_open_invoices_by_partner(self, partner_id: int) -> List[LogisticsServiceInvoice]:
        return (
            self.db.query(LogisticsServiceInvoice)
            .filter(
                LogisticsServiceInvoice.partner_id == partner_id,
                LogisticsServiceInvoice.payment_status.in_(["UNPAID", "PARTIALLY_PAID"]),
                LogisticsServiceInvoice.status == "APPROVED",
                LogisticsServiceInvoice.is_active == True,
            )
            .order_by(LogisticsServiceInvoice.invoice_date.asc())
            .all()
        )

    # ========================================================================
    # Containers & Locks
    # ========================================================================

    def get_containers_for_bl_and_partner(
        self, bl_number: str, partner_id: int
    ) -> List[LogisticsInvoiceContainer]:
        return (
            self.db.query(LogisticsInvoiceContainer)
            .join(LogisticsServiceInvoice, LogisticsInvoiceContainer.invoice_id == LogisticsServiceInvoice.invoice_id)
            .filter(
                LogisticsInvoiceContainer.bl_number == bl_number,
                LogisticsServiceInvoice.partner_id == partner_id,
                LogisticsServiceInvoice.is_active == True,
                LogisticsServiceInvoice.status != "CANCELLED",
            )
            .all()
        )

    def get_containers_by_invoice(self, invoice_id: int) -> List[LogisticsInvoiceContainer]:
        return (
            self.db.query(LogisticsInvoiceContainer)
            .filter(LogisticsInvoiceContainer.invoice_id == invoice_id)
            .all()
        )

    # ========================================================================
    # Insurance Policies
    # ========================================================================

    def create_policy(self, policy: InsurancePolicy) -> InsurancePolicy:
        self.db.add(policy)
        self.db.flush()
        return policy

    def get_policy_by_id(self, policy_id: int) -> Optional[InsurancePolicy]:
        return (
            self.db.query(InsurancePolicy)
            .filter(InsurancePolicy.policy_id == policy_id, InsurancePolicy.is_active == True)
            .first()
        )

    def get_policy_by_shipment(self, shipment_id: int) -> Optional[InsurancePolicy]:
        return (
            self.db.query(InsurancePolicy)
            .filter(InsurancePolicy.shipment_id == shipment_id, InsurancePolicy.is_active == True)
            .first()
        )

    def list_policies(
        self,
        shipment_id: Optional[int] = None,
        insurance_company_id: Optional[int] = None,
        status: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[InsurancePolicy], int]:
        q = self.db.query(InsurancePolicy).filter(InsurancePolicy.is_active == True)
        if shipment_id:
            q = q.filter(InsurancePolicy.shipment_id == shipment_id)
        if insurance_company_id:
            q = q.filter(InsurancePolicy.insurance_company_id == insurance_company_id)
        if status:
            q = q.filter(InsurancePolicy.status == status)

        total = q.count()
        policies = q.order_by(InsurancePolicy.policy_id.desc()).offset(skip).limit(limit).all()
        return policies, total

    # ========================================================================
    # Clearance Advance Payments
    # ========================================================================

    def create_advance(self, advance: ClearanceAdvancePayment) -> ClearanceAdvancePayment:
        self.db.add(advance)
        self.db.flush()
        return advance

    def get_advance_by_id(self, advance_id: int) -> Optional[ClearanceAdvancePayment]:
        return (
            self.db.query(ClearanceAdvancePayment)
            .options(joinedload(ClearanceAdvancePayment.settlements))
            .filter(ClearanceAdvancePayment.advance_id == advance_id, ClearanceAdvancePayment.is_active == True)
            .first()
        )

    def list_advances(
        self,
        shipment_id: Optional[int] = None,
        partner_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[ClearanceAdvancePayment]:
        q = (
            self.db.query(ClearanceAdvancePayment)
            .options(joinedload(ClearanceAdvancePayment.settlements))
            .filter(ClearanceAdvancePayment.is_active == True)
        )
        if shipment_id:
            q = q.filter(ClearanceAdvancePayment.shipment_id == shipment_id)
        if partner_id:
            q = q.filter(ClearanceAdvancePayment.clearance_partner_id == partner_id)
        if status:
            q = q.filter(ClearanceAdvancePayment.status == status)

        return q.order_by(ClearanceAdvancePayment.advance_id.desc()).all()

    def create_advance_settlement(self, settlement: ClearanceAdvanceSettlement) -> ClearanceAdvanceSettlement:
        self.db.add(settlement)
        self.db.flush()
        return settlement

    # ========================================================================
    # Logistics Payment Vouchers & Knock-Offs
    # ========================================================================

    def create_voucher(self, voucher: LogisticsPaymentVoucher) -> LogisticsPaymentVoucher:
        self.db.add(voucher)
        self.db.flush()
        return voucher

    def get_voucher_by_id(self, voucher_id: int) -> Optional[LogisticsPaymentVoucher]:
        return (
            self.db.query(LogisticsPaymentVoucher)
            .options(joinedload(LogisticsPaymentVoucher.knockoffs))
            .filter(LogisticsPaymentVoucher.voucher_id == voucher_id, LogisticsPaymentVoucher.is_active == True)
            .first()
        )

    def list_vouchers(
        self,
        partner_id: Optional[int] = None,
        shipment_id: Optional[int] = None,
        status: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[LogisticsPaymentVoucher], int]:
        q = (
            self.db.query(LogisticsPaymentVoucher)
            .options(joinedload(LogisticsPaymentVoucher.knockoffs))
            .filter(LogisticsPaymentVoucher.is_active == True)
        )
        if partner_id:
            q = q.filter(LogisticsPaymentVoucher.partner_id == partner_id)
        if shipment_id:
            q = q.filter(LogisticsPaymentVoucher.shipment_id == shipment_id)
        if status:
            q = q.filter(LogisticsPaymentVoucher.status == status)

        total = q.count()
        vouchers = q.order_by(LogisticsPaymentVoucher.voucher_id.desc()).offset(skip).limit(limit).all()
        return vouchers, total

    def create_knockoff(self, knockoff: InvoiceKnockoff) -> InvoiceKnockoff:
        self.db.add(knockoff)
        self.db.flush()
        return knockoff

    # ========================================================================
    # Partner Balance & Aggregations
    # ========================================================================

    def get_partner_invoices_for_aging(self, partner_id: int) -> List[LogisticsServiceInvoice]:
        return (
            self.db.query(LogisticsServiceInvoice)
            .filter(
                LogisticsServiceInvoice.partner_id == partner_id,
                LogisticsServiceInvoice.is_active == True,
                LogisticsServiceInvoice.status != "CANCELLED",
            )
            .all()
        )

    def get_invoices_for_ledger(
        self,
        partner_id: int,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
    ) -> List[LogisticsServiceInvoice]:
        q = self.db.query(LogisticsServiceInvoice).filter(
            LogisticsServiceInvoice.partner_id == partner_id,
            LogisticsServiceInvoice.is_active == True,
            LogisticsServiceInvoice.status != "CANCELLED",
        )
        if from_date:
            q = q.filter(LogisticsServiceInvoice.invoice_date >= from_date)
        if to_date:
            q = q.filter(LogisticsServiceInvoice.invoice_date <= to_date)
        return q.order_by(LogisticsServiceInvoice.invoice_date.asc()).all()

    def get_vouchers_for_ledger(
        self,
        partner_id: int,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
    ) -> List[LogisticsPaymentVoucher]:
        q = self.db.query(LogisticsPaymentVoucher).filter(
            LogisticsPaymentVoucher.partner_id == partner_id,
            LogisticsPaymentVoucher.is_active == True,
        )
        if from_date:
            q = q.filter(LogisticsPaymentVoucher.payment_date >= from_date)
        if to_date:
            q = q.filter(LogisticsPaymentVoucher.payment_date <= to_date)
        return q.order_by(LogisticsPaymentVoucher.payment_date.asc()).all()

    def get_invoices_for_wht_report(
        self,
        year: int,
        month: Optional[int] = None,
    ) -> List[LogisticsServiceInvoice]:
        start_date = datetime(year, month or 1, 1, 0, 0, 0, tzinfo=timezone.utc)
        if month:
            if month == 12:
                end_date = datetime(year + 1, 1, 1, 0, 0, 0, tzinfo=timezone.utc)
            else:
                end_date = datetime(year, month + 1, 1, 0, 0, 0, tzinfo=timezone.utc)
        else:
            end_date = datetime(year + 1, 1, 1, 0, 0, 0, tzinfo=timezone.utc)

        start_naive = start_date.replace(tzinfo=None)
        end_naive = end_date.replace(tzinfo=None)

        q = self.db.query(LogisticsServiceInvoice).filter(
            LogisticsServiceInvoice.is_active == True,
            LogisticsServiceInvoice.wht_amount > 0,
            or_(
                and_(LogisticsServiceInvoice.invoice_date >= start_date, LogisticsServiceInvoice.invoice_date < end_date),
                and_(LogisticsServiceInvoice.invoice_date >= start_naive, LogisticsServiceInvoice.invoice_date < end_naive),
            ),
        )
        return q.order_by(LogisticsServiceInvoice.invoice_date.asc()).all()

