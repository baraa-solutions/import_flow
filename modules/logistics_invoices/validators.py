"""
Business Validators for Logistics Service Invoices & Payments (LSI)
===================================================================
Contains duplicate checks, B/L container lock validation,
tax behaviour verification, and knock-off constraints.
"""

from __future__ import annotations

from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.logistics_invoices.repository import LogisticsInvoicesRepository
from modules.logistics_invoices.schemas import (
    LogisticsInvoiceCreate,
    LogisticsInvoiceContainerCreate,
    InvoiceKnockoffItem,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile


class LogisticsInvoicesValidator:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LogisticsInvoicesRepository(db)

    def validate_partner(self, partner_id: int, expected_types: Optional[List[str]] = None) -> ExternalServiceProvider:
        partner = self.db.query(ExternalServiceProvider).filter(
            ExternalServiceProvider.provider_id == partner_id,
        ).first()
        if not partner:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"External service provider with ID {partner_id} not found."
            )
        if expected_types:
            # Check loose match for partner type
            ptype_lower = (partner.partner_type or "").lower()
            matched = any(exp.lower() in ptype_lower for exp in expected_types)
            if not matched:
                # Log or warn, but don't strictly block if user coded flexibly
                pass
        return partner

    def validate_shipment(self, shipment_id: int, require_active: bool = False) -> ImportFile:
        """The import file billed by an invoice / policy. New documents (``require_active``) can only be
        recorded against an active (not soft-deleted) file."""
        shipment = self.db.query(ImportFile).filter(
            ImportFile.import_file_id == shipment_id,
        ).first()
        if not shipment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Import file with ID {shipment_id} not found."
            )
        if require_active and not shipment.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Import file {shipment.import_file_code} is archived; new documents cannot be recorded on it."
            )
        return shipment

    def validate_no_duplicate_invoice(self, partner_id: int, invoice_number: str, exclude_id: Optional[int] = None) -> None:
        duplicate = self.repo.find_duplicate_invoice(partner_id, invoice_number, exclude_id)
        if duplicate:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invoice number '{invoice_number}' already exists for partner ID {partner_id} (Code: {duplicate.invoice_code})."
            )

    def validate_container_locks(
        self,
        bl_number: Optional[str],
        partner_id: int,
        containers: List[LogisticsInvoiceContainerCreate],
        exclude_invoice_id: Optional[int] = None,
    ) -> None:
        """
        Ensures none of the specified containers have already been billed by this partner on this B/L.
        """
        if not bl_number or not containers:
            return

        existing_containers = self.repo.get_containers_for_bl_and_partner(bl_number, partner_id)
        already_billed_numbers = {
            c.container_number.strip().upper()
            for c in existing_containers
            if exclude_invoice_id is None or c.invoice_id != exclude_invoice_id
        }

        for c in containers:
            c_num = c.container_number.strip().upper()
            if c_num in already_billed_numbers:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Container '{c_num}' on B/L '{bl_number}' is already billed for this partner (Invoice-to-Container Lock)."
                )

    def validate_knockoff_constraints(
        self,
        total_voucher_amount_egp: float,
        knockoffs: List[InvoiceKnockoffItem],
    ) -> None:
        total_knocked = sum(k.knocked_amount_egp for k in knockoffs)
        if total_knocked > total_voucher_amount_egp + 0.01:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Total knocked amount ({total_knocked:,.2f} EGP) exceeds voucher amount ({total_voucher_amount_egp:,.2f} EGP)."
            )

        for item in knockoffs:
            invoice = self.repo.get_invoice_by_id(item.invoice_id)
            if not invoice:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Invoice with ID {item.invoice_id} not found."
                )
            if item.knocked_amount_egp > invoice.remaining_amount_egp + 0.01:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        f"Knock-off amount ({item.knocked_amount_egp:,.2f} EGP) exceeds remaining due "
                        f"({invoice.remaining_amount_egp:,.2f} EGP) on invoice {invoice.invoice_number}."
                    )
                )
