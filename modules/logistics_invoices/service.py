"""
Service Layer for Logistics Service Invoices & Payments (LSI)
=============================================================
Orchestrates business logic, auto-prefill, container locking,
insurance calculations, advance settlements, and invoice knock-offs.
"""

from __future__ import annotations

from datetime import datetime, date, timezone
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

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
from modules.logistics_invoices.repository import LogisticsInvoicesRepository
from modules.logistics_invoices.validators import LogisticsInvoicesValidator
from modules.logistics_invoices.schemas import (
    LogisticsInvoiceCreate,
    LogisticsInvoiceLineCreate,
    LogisticsInvoiceUpdate,
    InsurancePolicyCreate,
    InsurancePolicyUpdate,
    InsurancePolicyClaimCreate,
    ClearanceAdvancePaymentCreate,
    ClearanceAdvanceSettlementCreate,
    LogisticsPaymentVoucherCreate,
    PartnerBalanceCardResponse,
    AgingBucket,
    ContainerLockStatusResponse,
    ContainerLockStatusItem,
    ThreeWayMatchResponse,
    ThreeWayMatchItem,
    PrefillLinesResponse,
    PrefillLineItem,
    InsurancePreviewResponse,
    PartnerLedgerResponse,
    PartnerLedgerEntrySchema,
    WhtForm41ReportResponse,
    WhtForm41RecordSchema,
    InsurancePolicyClaimStatusUpdate,
)
from modules.import_files.model import ImportFile
from modules.currencies.model import Currency, ExchangeRate


class LogisticsInvoicesService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LogisticsInvoicesRepository(db)
        self.validator = LogisticsInvoicesValidator(db)

    # ========================================================================
    # CBE Exchange Rate Helper
    # ========================================================================

    def get_cbe_exchange_rate(self, currency_code: str, target_date: Optional[date] = None) -> float:
        if currency_code.upper() in ["EGP", "LE"]:
            return 1.0

        q = (
            self.db.query(ExchangeRate)
            .join(Currency, ExchangeRate.currency_id == Currency.currency_id)
            .filter(
                Currency.currency_code == currency_code.upper(),
                ExchangeRate.is_active == True,
            )
        )
        if target_date:
            q = q.filter(ExchangeRate.effective_date <= target_date).order_by(ExchangeRate.effective_date.desc())
        else:
            q = q.order_by(ExchangeRate.effective_date.desc())

        rate_record = q.first()
        if rate_record and rate_record.commercial_rate:
            return float(rate_record.commercial_rate)
        return 1.0

    # ========================================================================
    # Invoices Workflow
    # ========================================================================

    def create_invoice(self, payload: LogisticsInvoiceCreate, user_name: str = "System") -> LogisticsServiceInvoice:
        # 1. Validations
        self.validator.validate_shipment(payload.shipment_id)
        partner = self.validator.validate_partner(payload.partner_id)
        self.validator.validate_no_duplicate_invoice(payload.partner_id, payload.invoice_number)
        self.validator.validate_container_locks(payload.bl_number, payload.partner_id, payload.containers)

        code = self.repo.get_next_invoice_code()

        invoice = LogisticsServiceInvoice(
            invoice_code=code,
            shipment_id=payload.shipment_id,
            bl_number=payload.bl_number,
            partner_id=payload.partner_id,
            partner_type=payload.partner_type,
            partner_name=partner.partner_name or payload.partner_name,
            invoice_number=payload.invoice_number.strip(),
            invoice_date=payload.invoice_date,
            currency=payload.currency.upper(),
            total_amount_fx=payload.total_amount_fx,
            exchange_rate=payload.exchange_rate,
            total_amount_egp=payload.total_amount_egp,
            vat_included=payload.vat_included,
            vat_amount=payload.vat_amount,
            wht_deducted=payload.wht_deducted or (payload.wht_amount > 0),
            wht_amount=payload.wht_amount,
            net_payable_egp=payload.net_payable_egp,
            paid_amount_egp=0.0,
            remaining_amount_egp=payload.net_payable_egp,
            payment_status="UNPAID",
            status="DRAFT",
            approval_status="PENDING",
            insurance_policy_id=payload.insurance_policy_id,
            document_url=payload.document_url,
            notes=payload.notes,
            created_by=user_name,
            updated_by=user_name,
        )

        # Lines
        for line_data in payload.lines:
            line = LogisticsInvoiceLine(
                expense_code=line_data.expense_code,
                line_description=line_data.line_description,
                line_group=line_data.line_group,
                quantity=line_data.quantity,
                unit_price_fx=line_data.unit_price_fx,
                currency=line_data.currency.upper(),
                amount_fx=line_data.amount_fx,
                exchange_rate=line_data.exchange_rate,
                amount_egp=line_data.amount_egp,
                tax_type=line_data.tax_type,
                vat_rate=line_data.vat_rate,
                vat_amount=line_data.vat_amount,
                wht_rate=line_data.wht_rate,
                wht_amount=line_data.wht_amount,
                net_amount_egp=line_data.net_amount_egp,
                is_from_quotation=line_data.is_from_quotation,
            )
            invoice.lines.append(line)

        # Containers lock
        for cont_data in payload.containers:
            cont = LogisticsInvoiceContainer(
                shipment_id=payload.shipment_id,
                bl_number=payload.bl_number or "",
                container_number=cont_data.container_number.strip().upper(),
                seal_number=cont_data.seal_number,
            )
            invoice.containers.append(cont)

        self.repo.create_invoice(invoice)
        self.db.commit()
        self.db.refresh(invoice)
        return invoice

    def get_invoice(self, invoice_id: int) -> LogisticsServiceInvoice:
        invoice = self.repo.get_invoice_by_id(invoice_id)
        if not invoice:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Invoice ID {invoice_id} not found.")
        return invoice

    def update_invoice(self, invoice_id: int, payload: LogisticsInvoiceUpdate, user_name: str = "System") -> LogisticsServiceInvoice:
        invoice = self.get_invoice(invoice_id)
        if invoice.status in ["APPROVED", "CANCELLED"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot edit invoice in {invoice.status} status."
            )

        if payload.invoice_number and payload.invoice_number != invoice.invoice_number:
            self.validator.validate_no_duplicate_invoice(invoice.partner_id, payload.invoice_number, exclude_id=invoice_id)
            invoice.invoice_number = payload.invoice_number.strip()

        if payload.invoice_date:
            invoice.invoice_date = payload.invoice_date
        if payload.currency:
            invoice.currency = payload.currency.upper()
        if payload.total_amount_fx is not None:
            invoice.total_amount_fx = payload.total_amount_fx
        if payload.exchange_rate is not None:
            invoice.exchange_rate = payload.exchange_rate
        if payload.total_amount_egp is not None:
            invoice.total_amount_egp = payload.total_amount_egp
        if payload.vat_included is not None:
            invoice.vat_included = payload.vat_included
        if payload.vat_amount is not None:
            invoice.vat_amount = payload.vat_amount
        if payload.wht_deducted is not None:
            invoice.wht_deducted = payload.wht_deducted
        if payload.wht_amount is not None:
            invoice.wht_amount = payload.wht_amount
        if payload.net_payable_egp is not None:
            invoice.net_payable_egp = payload.net_payable_egp
            invoice.remaining_amount_egp = payload.net_payable_egp - invoice.paid_amount_egp
        if payload.document_url is not None:
            invoice.document_url = payload.document_url
        if payload.notes is not None:
            invoice.notes = payload.notes

        invoice.updated_by = user_name
        invoice.updated_at = datetime.now(timezone.utc)

        # Update lines if provided
        if payload.lines is not None:
            invoice.lines.clear()
            for line_data in payload.lines:
                line = LogisticsInvoiceLine(
                    expense_code=line_data.expense_code,
                    line_description=line_data.line_description,
                    line_group=line_data.line_group,
                    quantity=line_data.quantity,
                    unit_price_fx=line_data.unit_price_fx,
                    currency=line_data.currency.upper(),
                    amount_fx=line_data.amount_fx,
                    exchange_rate=line_data.exchange_rate,
                    amount_egp=line_data.amount_egp,
                    tax_type=line_data.tax_type,
                    vat_rate=line_data.vat_rate,
                    vat_amount=line_data.vat_amount,
                    wht_rate=line_data.wht_rate,
                    wht_amount=line_data.wht_amount,
                    net_amount_egp=line_data.net_amount_egp,
                    is_from_quotation=line_data.is_from_quotation,
                )
                invoice.lines.append(line)

        # Update containers if provided
        if payload.containers is not None:
            self.validator.validate_container_locks(
                invoice.bl_number, invoice.partner_id, payload.containers, exclude_invoice_id=invoice_id
            )
            invoice.containers.clear()
            for cont_data in payload.containers:
                cont = LogisticsInvoiceContainer(
                    shipment_id=invoice.shipment_id,
                    bl_number=invoice.bl_number or "",
                    container_number=cont_data.container_number.strip().upper(),
                    seal_number=cont_data.seal_number,
                )
                invoice.containers.append(cont)

        self.db.commit()
        self.db.refresh(invoice)
        return invoice

    def submit_invoice(self, invoice_id: int, user_name: str = "System") -> LogisticsServiceInvoice:
        invoice = self.get_invoice(invoice_id)
        if invoice.status != "DRAFT":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only DRAFT invoices can be submitted.")
        invoice.status = "SUBMITTED"
        invoice.updated_by = user_name
        self.db.commit()
        self.db.refresh(invoice)
        return invoice

    def approve_invoice(self, invoice_id: int, user_name: str = "System") -> LogisticsServiceInvoice:
        invoice = self.get_invoice(invoice_id)
        if invoice.status not in ["DRAFT", "SUBMITTED"]:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invoice is already approved or cancelled.")
        invoice.status = "APPROVED"
        invoice.approval_status = "APPROVED"
        invoice.updated_by = user_name
        self.db.commit()
        self.db.refresh(invoice)
        return invoice

    def cancel_invoice(self, invoice_id: int, user_name: str = "System") -> LogisticsServiceInvoice:
        invoice = self.get_invoice(invoice_id)
        if invoice.paid_amount_egp > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot cancel an invoice with recorded payments or knock-offs."
            )
        invoice.status = "CANCELLED"
        invoice.updated_by = user_name
        self.db.commit()
        self.db.refresh(invoice)
        return invoice

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
        return self.repo.list_invoices(
            shipment_id=shipment_id,
            partner_id=partner_id,
            partner_type=partner_type,
            status=status,
            payment_status=payment_status,
            skip=skip,
            limit=limit,
        )

    # ========================================================================
    # Prefill Lines
    # ========================================================================

    def get_prefill_lines(self, shipment_id: int, partner_type: str) -> PrefillLinesResponse:
        shipment = self.validator.validate_shipment(shipment_id)
        cbe_rate = self.get_cbe_exchange_rate("USD")
        lines: List[PrefillLineItem] = []

        ptype = partner_type.lower()
        if ptype == "freight":
            # 21 Standard Items
            standard_21 = [
                # Group A: Ocean Freight & Carrier charges
                ("EXP-OF-001", "Ocean Freight (نولون بحري)", "ocean_freight", "professional_fee", 0.05),
                ("EXP-OF-002", "Bunker Adjustment Factor - BAF (تعديل أسعار الوقود)", "ocean_freight", "professional_fee", 0.0),
                ("EXP-OF-003", "Currency Adjustment Factor - CAF (تعديل سعر الصرف)", "ocean_freight", "professional_fee", 0.0),
                ("EXP-OF-004", "ISPS / Security Charge (رسوم الأمن والسلامة الدولية)", "ocean_freight", "government_fee", 0.0),
                # Group B: Port of Discharge Local Charges
                ("EXP-PC-001", "Terminal Handling Charges - THC (رسوم مناولة الرصيف)", "port_charges", "professional_fee", 0.05),
                ("EXP-PC-002", "Port Storage Charges (أرضيات الميناء)", "port_charges", "government_fee", 0.0),
                ("EXP-PC-003", "Demurrage / Detention Charges (غرامات تأخير الحاويات)", "port_charges", "professional_fee", 0.05),
                ("EXP-PC-004", "Port Dues & Harbor Fees (رسوم ورسو الميناء)", "port_charges", "government_fee", 0.0),
                ("EXP-PC-005", "Container Seal Fee (رسوم السيل الجمركي)", "port_charges", "government_fee", 0.0),
                ("EXP-PC-006", "Delivery Order - D/O Fee (مصاريف إذن التسليم)", "port_charges", "professional_fee", 0.05),
                ("EXP-PC-007", "Gate In / Gate Out Charges (رسوم بوابات الميناء)", "port_charges", "government_fee", 0.0),
                ("EXP-PC-008", "Manifest Amendment Fee (رسوم تعديل المانيفست)", "port_charges", "professional_fee", 0.05),
                ("EXP-PC-009", "Container Inspection & Cleaning (فحص وغسيل الحاوية)", "port_charges", "professional_fee", 0.05),
                # Group C: Origin & Documentation Fees
                ("EXP-OC-001", "Export Clearance at Origin (تخليص جمركي صادر بالمنشأ)", "origin_charges", "professional_fee", 0.0),
                ("EXP-OC-002", "Origin Documentation Fee (مصاريف وثائق الشحن بالمنشأ)", "origin_charges", "professional_fee", 0.0),
                ("EXP-OC-003", "Telex Release / Surrender Fee (رسوم التلكس ريليس)", "origin_charges", "professional_fee", 0.05),
                ("EXP-OC-004", "Bill of Lading Issuance Fee (رسوم إصدار البوليصة)", "origin_charges", "professional_fee", 0.05),
                ("EXP-OC-005", "Inland Haulage at Origin (نقل داخلي في بلد المنشأ)", "origin_charges", "professional_fee", 0.0),
                ("EXP-OC-006", "Origin Terminal Handling - OTHC (مناولة ميناء الشحن)", "origin_charges", "professional_fee", 0.0),
                ("EXP-OC-007", "Fumigation & Phytosanitary (رسوم التبخير والصحة النباتية)", "origin_charges", "government_fee", 0.0),
                ("EXP-OC-008", "Certificate of Origin Authentication (توثيق شهادة المنشأ)", "origin_charges", "government_fee", 0.0),
            ]
            for code, desc, grp, ttype, wht in standard_21:
                lines.append(
                    PrefillLineItem(
                        expense_code=code,
                        line_description=desc,
                        line_group=grp,
                        quantity=1.0,
                        unit_price_fx=0.0,
                        currency="USD",
                        amount_fx=0.0,
                        exchange_rate=cbe_rate,
                        amount_egp=0.0,
                        tax_type=ttype,
                        vat_rate=0.14 if ttype == "professional_fee" else 0.0,
                        wht_rate=wht,
                        is_from_quotation=True,
                    )
                )

        elif ptype == "clearance":
            clearance_standard = [
                ("EXP-CLR-001", "Clearance Professional Fees (أتعاب التخليص الجمركي)", "clearance_fees", "professional_fee", 0.05),
                ("EXP-CLR-002", "Form 46 Processing & Customs Stamp (دمغات واستمارة 46)", "clearance_fees", "government_fee", 0.0),
                ("EXP-CLR-003", "Port & Authority Inspection Charges (رسوم الكشف والتثمين)", "clearance_fees", "government_fee", 0.0),
                ("EXP-CLR-004", "Customs Laboratory & Testing (فحص معامل ومختبرات نافذة)", "clearance_fees", "government_fee", 0.0),
                ("EXP-CLR-005", "Stevedoring & Port Labor (عتالة وتعتيق الميناء)", "clearance_fees", "professional_fee", 0.05),
                ("EXP-CLR-006", "X-Ray Scanning Fees (رسوم جهاز الفحص بالأشعة)", "clearance_fees", "government_fee", 0.0),
                ("EXP-CLR-007", "Truck Demurrage at Customs (أرضيات سيارات الكشف)", "clearance_fees", "professional_fee", 0.05),
                ("EXP-CLR-008", "Customs Gate Pass & Release Permit (تصاريح الخروج والبوابة)", "clearance_fees", "government_fee", 0.0),
                ("EXP-CLR-009", "Miscellaneous & Administrative Receipts (إيصالات ونثريات)", "clearance_fees", "government_fee", 0.0),
            ]
            for code, desc, grp, ttype, wht in clearance_standard:
                lines.append(
                    PrefillLineItem(
                        expense_code=code,
                        line_description=desc,
                        line_group=grp,
                        quantity=1.0,
                        unit_price_fx=0.0,
                        currency="EGP",
                        amount_fx=0.0,
                        exchange_rate=1.0,
                        amount_egp=0.0,
                        tax_type=ttype,
                        vat_rate=0.14 if ttype == "professional_fee" else 0.0,
                        wht_rate=wht,
                        is_from_quotation=True,
                    )
                )

        elif ptype == "insurance":
            policy = self.repo.get_policy_by_shipment(shipment_id)
            if policy:
                lines = [
                    PrefillLineItem(
                        expense_code="EXP-INS-001",
                        line_description=f"Marine Cargo Insurance Premium (قسط التأمين البحري) - {policy.policy_number}",
                        line_group="insurance",
                        quantity=1.0,
                        unit_price_fx=policy.premium_amount_fx,
                        currency=policy.insured_value_currency,
                        amount_fx=policy.premium_amount_fx,
                        exchange_rate=policy.exchange_rate,
                        amount_egp=policy.premium_amount_egp,
                        tax_type="insurance_fee",
                        vat_rate=0.0,
                        wht_rate=0.0,
                        net_amount_egp=policy.premium_amount_egp,
                        is_from_quotation=True,
                    ),
                    PrefillLineItem(
                        expense_code="EXP-INS-002",
                        line_description="Proportional Stamp Duty (ضريبة الدمغة النسبية 0.1%)",
                        line_group="insurance",
                        quantity=1.0,
                        unit_price_fx=policy.stamp_duty_egp,
                        currency="EGP",
                        amount_fx=policy.stamp_duty_egp,
                        exchange_rate=1.0,
                        amount_egp=policy.stamp_duty_egp,
                        tax_type="government_fee",
                        vat_rate=0.0,
                        wht_rate=0.0,
                        net_amount_egp=policy.stamp_duty_egp,
                        is_from_quotation=True,
                    ),
                    PrefillLineItem(
                        expense_code="EXP-INS-003",
                        line_description="FRA Supervisory & Inspection Fee (رسوم رقابة مالية 12%)",
                        line_group="insurance",
                        quantity=1.0,
                        unit_price_fx=policy.supervisory_fee_egp,
                        currency="EGP",
                        amount_fx=policy.supervisory_fee_egp,
                        exchange_rate=1.0,
                        amount_egp=policy.supervisory_fee_egp,
                        tax_type="government_fee",
                        vat_rate=0.0,
                        wht_rate=0.0,
                        net_amount_egp=policy.supervisory_fee_egp,
                        is_from_quotation=True,
                    ),
                ]

        return PrefillLinesResponse(
            shipment_id=shipment_id,
            partner_type=partner_type,
            currency="USD" if ptype == "freight" else "EGP",
            exchange_rate=cbe_rate if ptype == "freight" else 1.0,
            lines=lines,
        )

    # ========================================================================
    # Insurance Policies
    # ========================================================================

    def calculate_insurance_preview(
        self,
        shipment_id: int,
        premium_rate: float = 0.35,
        coverage_type: str = "all_risks",
    ) -> InsurancePreviewResponse:
        shipment = self.validator.validate_shipment(shipment_id)
        # CIF base is estimated_cost or 25,000 as fallback
        cif_fx = shipment.estimated_cost or 25000.0
        currency = shipment.estimated_cost_currency or "USD"
        rate = self.get_cbe_exchange_rate(currency)

        insured_value_fx = cif_fx * 1.10  # Standard Egyptian Marine Insurance rule: CIF + 10%
        premium_fx = insured_value_fx * (premium_rate / 100.0)
        premium_egp = premium_fx * rate
        stamp_duty_egp = premium_egp * 0.001  # 0.1% stamp duty
        supervisory_fee_egp = premium_egp * 0.12  # 12% FRA supervisory fee
        net_premium_egp = premium_egp + stamp_duty_egp + supervisory_fee_egp

        return InsurancePreviewResponse(
            shipment_id=shipment_id,
            cif_value_fx=round(cif_fx, 2),
            insured_value_fx=round(insured_value_fx, 2),
            currency=currency,
            exchange_rate=rate,
            premium_rate=premium_rate,
            premium_amount_fx=round(premium_fx, 2),
            premium_amount_egp=round(premium_egp, 2),
            stamp_duty_egp=round(stamp_duty_egp, 2),
            supervisory_fee_egp=round(supervisory_fee_egp, 2),
            net_premium_egp=round(net_premium_egp, 2),
        )

    def create_insurance_policy(self, payload: InsurancePolicyCreate, user_name: str = "System") -> InsurancePolicy:
        self.validator.validate_shipment(payload.shipment_id)
        self.validator.validate_partner(payload.insurance_company_id, expected_types=["Insurance", "Insurance Company"])

        code = self.repo.get_next_policy_code()

        policy = InsurancePolicy(
            policy_code=code,
            shipment_id=payload.shipment_id,
            bl_number=payload.bl_number,
            insurance_company_id=payload.insurance_company_id,
            insurance_company_name=payload.insurance_company_name,
            policy_number=payload.policy_number.strip(),
            policy_date=payload.policy_date,
            coverage_start=payload.coverage_start,
            coverage_end=payload.coverage_end,
            coverage_type=payload.coverage_type,
            insured_value_fx=payload.insured_value_fx,
            insured_value_currency=payload.insured_value_currency.upper(),
            premium_rate=payload.premium_rate,
            premium_amount_fx=payload.premium_amount_fx,
            exchange_rate=payload.exchange_rate,
            premium_amount_egp=payload.premium_amount_egp,
            stamp_duty_egp=payload.stamp_duty_egp,
            supervisory_fee_egp=payload.supervisory_fee_egp,
            net_premium_egp=payload.net_premium_egp,
            beneficiary=payload.beneficiary,
            status="issued",
            claim_amount_egp=0.0,
            invoice_generated=False,
            notes=payload.notes,
            created_by=user_name,
            updated_by=user_name,
        )

        self.repo.create_policy(policy)
        self.db.commit()
        self.db.refresh(policy)
        return policy

    def generate_invoice_from_policy(self, policy_id: int, user_name: str = "System") -> LogisticsServiceInvoice:
        policy = self.repo.get_policy_by_id(policy_id)
        if not policy:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Policy ID {policy_id} not found.")

        if policy.invoice_generated:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An invoice has already been generated for policy {policy.policy_number}."
            )

        invoice_payload = LogisticsInvoiceCreate(
            shipment_id=policy.shipment_id,
            bl_number=policy.bl_number,
            partner_id=policy.insurance_company_id,
            partner_type="insurance",
            partner_name=policy.insurance_company_name,
            invoice_number=f"INV-POL-{policy.policy_number}",
            invoice_date=datetime.now(timezone.utc),
            currency=policy.insured_value_currency,
            total_amount_fx=policy.premium_amount_fx,
            exchange_rate=policy.exchange_rate,
            total_amount_egp=policy.net_premium_egp,
            vat_included=False,
            vat_amount=0.0,
            wht_deducted=False,
            wht_amount=0.0,
            net_payable_egp=policy.net_premium_egp,
            insurance_policy_id=policy.policy_id,
            notes=f"Auto-generated service invoice for Marine Insurance Policy {policy.policy_number}",
            lines=[
                LogisticsInvoiceLineCreate(
                    expense_code="EXP-INS-001",
                    line_description=f"Marine Insurance Premium - {policy.policy_number}",
                    line_group="insurance",
                    quantity=1.0,
                    unit_price_fx=policy.premium_amount_fx,
                    currency=policy.insured_value_currency,
                    amount_fx=policy.premium_amount_fx,
                    exchange_rate=policy.exchange_rate,
                    amount_egp=policy.premium_amount_egp,
                    tax_type="insurance_fee",
                    vat_rate=0.0,
                    wht_rate=0.0,
                    net_amount_egp=policy.premium_amount_egp,
                    is_from_quotation=True,
                ),
                LogisticsInvoiceLineCreate(
                    expense_code="EXP-INS-002",
                    line_description="Proportional Stamp Duty (0.1%)",
                    line_group="insurance",
                    quantity=1.0,
                    unit_price_fx=policy.stamp_duty_egp,
                    currency="EGP",
                    amount_fx=policy.stamp_duty_egp,
                    exchange_rate=1.0,
                    amount_egp=policy.stamp_duty_egp,
                    tax_type="government_fee",
                    vat_rate=0.0,
                    wht_rate=0.0,
                    net_amount_egp=policy.stamp_duty_egp,
                    is_from_quotation=True,
                ),
                LogisticsInvoiceLineCreate(
                    expense_code="EXP-INS-003",
                    line_description="FRA Supervisory & Inspection Fee (12%)",
                    line_group="insurance",
                    quantity=1.0,
                    unit_price_fx=policy.supervisory_fee_egp,
                    currency="EGP",
                    amount_fx=policy.supervisory_fee_egp,
                    exchange_rate=1.0,
                    amount_egp=policy.supervisory_fee_egp,
                    tax_type="government_fee",
                    vat_rate=0.0,
                    wht_rate=0.0,
                    net_amount_egp=policy.supervisory_fee_egp,
                    is_from_quotation=True,
                ),
            ],
        )

        invoice = self.create_invoice(invoice_payload, user_name=user_name)
        policy.invoice_generated = True
        policy.updated_by = user_name
        self.db.commit()
        return invoice

    def record_insurance_claim(self, policy_id: int, payload: InsurancePolicyClaimCreate, user_name: str = "System") -> InsurancePolicy:
        policy = self.repo.get_policy_by_id(policy_id)
        if not policy:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Policy ID {policy_id} not found.")

        policy.claim_reference = payload.claim_reference
        policy.claim_amount_egp = payload.claim_amount_egp
        policy.claim_status = payload.claim_status
        policy.status = "claimed"
        policy.updated_by = user_name
        self.db.commit()
        self.db.refresh(policy)
        return policy

    # ========================================================================
    # Container Locks & 3-Way Match
    # ========================================================================

    def get_container_lock_status(self, shipment_id: int, bl_number: str) -> ContainerLockStatusResponse:
        shipment = self.validator.validate_shipment(shipment_id)
        # Fetch containers from shipment containers_loading_data or booking
        containers_raw = []
        if hasattr(shipment, "containers_loading_data") and shipment.containers_loading_data:
            containers_raw = shipment.containers_loading_data
        elif hasattr(shipment, "packing_lists_data") and shipment.packing_lists_data:
            containers_raw = shipment.packing_lists_data

        items: List[ContainerLockStatusItem] = []
        all_billed = (
            self.db.query(LogisticsInvoiceContainer)
            .join(LogisticsServiceInvoice, LogisticsInvoiceContainer.invoice_id == LogisticsServiceInvoice.invoice_id)
            .filter(
                LogisticsInvoiceContainer.bl_number == bl_number,
                LogisticsServiceInvoice.is_active == True,
                LogisticsServiceInvoice.status != "CANCELLED",
            )
            .all()
        )
        billed_map = {b.container_number.upper(): b for b in all_billed}

        if containers_raw:
            for c in containers_raw:
                c_num = (c.get("container_no") or c.get("container_number") or "").strip().upper()
                if not c_num:
                    continue
                seal = c.get("seal_no") or c.get("seal_number")
                b_info = billed_map.get(c_num)
                items.append(
                    ContainerLockStatusItem(
                        container_number=c_num,
                        seal_number=seal,
                        is_billed=b_info is not None,
                        billed_by_partner_id=b_info.invoice.partner_id if b_info and b_info.invoice else None,
                        billed_by_partner_name=b_info.invoice.partner_name if b_info and b_info.invoice else None,
                        invoice_number=b_info.invoice.invoice_number if b_info and b_info.invoice else None,
                    )
                )
        else:
            # If no raw containers in shipment, populate directly from billed containers
            for b in all_billed:
                items.append(
                    ContainerLockStatusItem(
                        container_number=b.container_number,
                        seal_number=b.seal_number,
                        is_billed=True,
                        billed_by_partner_id=b.invoice.partner_id if b.invoice else None,
                        billed_by_partner_name=b.invoice.partner_name if b.invoice else None,
                        invoice_number=b.invoice.invoice_number if b.invoice else None,
                    )
                )

        return ContainerLockStatusResponse(shipment_id=shipment_id, bl_number=bl_number, containers=items)

    def validate_three_way_match(self, invoice_id: int) -> ThreeWayMatchResponse:
        invoice = self.get_invoice(invoice_id)
        # Compare invoiced amounts against prefill quotation items
        prefill = self.get_prefill_lines(invoice.shipment_id, invoice.partner_type)
        prefill_map = {p.line_description.lower(): p for p in prefill.lines}

        items: List[ThreeWayMatchItem] = []
        total_quoted = 0.0
        total_invoiced = invoice.net_payable_egp
        all_matched = True

        for line in invoice.lines:
            quoted_match = prefill_map.get(line.line_description.lower())
            q_amt = quoted_match.net_amount_egp if quoted_match else 0.0
            total_quoted += q_amt
            variance = line.net_amount_egp - q_amt
            matched = abs(variance) < 1.0  # within 1 EGP
            if not matched:
                all_matched = False
            items.append(
                ThreeWayMatchItem(
                    item_description=line.line_description,
                    quoted_amount_egp=round(q_amt, 2),
                    invoiced_amount_egp=round(line.net_amount_egp, 2),
                    variance_egp=round(variance, 2),
                    is_matched=matched,
                )
            )

        return ThreeWayMatchResponse(
            invoice_id=invoice_id,
            is_fully_matched=all_matched,
            total_quoted_egp=round(total_quoted, 2),
            total_invoiced_egp=round(total_invoiced, 2),
            total_variance_egp=round(total_invoiced - total_quoted, 2),
            items=items,
        )

    # ========================================================================
    # Clearance Advance Payments
    # ========================================================================

    def create_advance(self, payload: ClearanceAdvancePaymentCreate, user_name: str = "System") -> ClearanceAdvancePayment:
        self.validator.validate_shipment(payload.shipment_id)
        partner = self.validator.validate_partner(payload.clearance_partner_id, expected_types=["Customs Broker", "Broker"])

        code = self.repo.get_next_advance_code()

        advance = ClearanceAdvancePayment(
            advance_code=code,
            shipment_id=payload.shipment_id,
            bl_number=payload.bl_number,
            clearance_partner_id=payload.clearance_partner_id,
            clearance_partner_name=partner.partner_name or payload.clearance_partner_name,
            amount=payload.amount,
            currency=payload.currency.upper(),
            exchange_rate=payload.exchange_rate,
            amount_egp=payload.amount_egp,
            payment_date=payload.payment_date,
            cbe_rate_date=payload.cbe_rate_date,
            disbursed_by=user_name,
            settled_amount_egp=0.0,
            remaining_amount_egp=payload.amount_egp,
            status="disbursed",
            notes=payload.notes,
            created_by=user_name,
        )

        self.repo.create_advance(advance)
        self.db.commit()
        self.db.refresh(advance)
        return advance

    def settle_advance(self, advance_id: int, payload: ClearanceAdvanceSettlementCreate, user_name: str = "System") -> ClearanceAdvanceSettlement:
        advance = self.repo.get_advance_by_id(advance_id)
        if not advance:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Advance payment ID {advance_id} not found.")

        invoice = self.get_invoice(payload.invoice_id)
        if invoice.partner_type != "clearance":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Can only settle advance against clearance invoices.")

        settle_amt = min(payload.settled_amount_egp, advance.remaining_amount_egp, invoice.remaining_amount_egp)
        if settle_amt <= 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No remaining amount to settle.")

        settlement = ClearanceAdvanceSettlement(
            advance_id=advance.advance_id,
            invoice_id=invoice.invoice_id,
            settled_amount_egp=settle_amt,
            settlement_date=datetime.now(timezone.utc),
            notes=payload.notes,
        )

        advance.settled_amount_egp += settle_amt
        advance.remaining_amount_egp -= settle_amt
        if advance.remaining_amount_egp <= 0.01:
            advance.status = "fully_settled"
        else:
            advance.status = "partially_settled"

        invoice.paid_amount_egp += settle_amt
        invoice.remaining_amount_egp -= settle_amt
        if invoice.remaining_amount_egp <= 0.01:
            invoice.payment_status = "FULLY_PAID"
            invoice.remaining_amount_egp = 0.0
        else:
            invoice.payment_status = "PARTIALLY_PAID"

        self.repo.create_advance_settlement(settlement)
        self.db.commit()
        self.db.refresh(settlement)
        return settlement

    # ========================================================================
    # Payment Vouchers & Knock-off
    # ========================================================================

    def create_payment_voucher(self, payload: LogisticsPaymentVoucherCreate, user_name: str = "System") -> LogisticsPaymentVoucher:
        partner = self.validator.validate_partner(payload.partner_id)
        self.validator.validate_knockoff_constraints(payload.amount_egp, payload.knockoffs)

        code = self.repo.get_next_voucher_code()
        allocated = sum(k.knocked_amount_egp for k in payload.knockoffs)

        voucher = LogisticsPaymentVoucher(
            voucher_code=code,
            shipment_id=payload.shipment_id,
            partner_id=payload.partner_id,
            partner_name=partner.partner_name or payload.partner_name,
            payment_date=payload.payment_date,
            amount=payload.amount,
            currency=payload.currency.upper(),
            exchange_rate=payload.exchange_rate,
            amount_egp=payload.amount_egp,
            cbe_rate_date=payload.cbe_rate_date,
            payment_method=payload.payment_method,
            bank_reference=payload.bank_reference,
            allocated_amount_egp=allocated,
            unallocated_amount_egp=payload.amount_egp - allocated,
            status="CONFIRMED",
            notes=payload.notes,
            created_by=user_name,
        )

        for k in payload.knockoffs:
            knockoff = InvoiceKnockoff(
                invoice_id=k.invoice_id,
                knocked_amount_egp=k.knocked_amount_egp,
                knock_date=payload.payment_date,
                notes=k.notes,
            )
            voucher.knockoffs.append(knockoff)

            # Update invoice paid and remaining amount
            invoice = self.repo.get_invoice_by_id(k.invoice_id)
            if invoice:
                invoice.paid_amount_egp += k.knocked_amount_egp
                invoice.remaining_amount_egp -= k.knocked_amount_egp
                if invoice.remaining_amount_egp <= 0.01:
                    invoice.payment_status = "FULLY_PAID"
                    invoice.remaining_amount_egp = 0.0
                else:
                    invoice.payment_status = "PARTIALLY_PAID"

        self.repo.create_voucher(voucher)
        self.db.commit()
        self.db.refresh(voucher)
        return voucher

    # ========================================================================
    # Partner Balance Card & Aging
    # ========================================================================

    def get_partner_balance_card(self, partner_id: int) -> PartnerBalanceCardResponse:
        partner = self.validator.validate_partner(partner_id)
        invoices = self.repo.get_partner_invoices_for_aging(partner_id)

        now = datetime.now(timezone.utc)
        total_invoiced = 0.0
        total_paid = 0.0
        balance_due = 0.0
        open_count = 0

        b30 = 0.0
        b60 = 0.0
        b90 = 0.0
        b90p = 0.0

        for inv in invoices:
            total_invoiced += inv.net_payable_egp
            total_paid += inv.paid_amount_egp
            rem = inv.remaining_amount_egp
            if rem > 0.01:
                balance_due += rem
                open_count += 1
                age_days = (now - inv.invoice_date.replace(tzinfo=timezone.utc if inv.invoice_date.tzinfo is None else None)).days
                if age_days <= 30:
                    b30 += rem
                elif age_days <= 60:
                    b60 += rem
                elif age_days <= 90:
                    b90 += rem
                else:
                    b90p += rem

        return PartnerBalanceCardResponse(
            partner_id=partner_id,
            partner_name=partner.partner_name,
            partner_type=partner.partner_type,
            total_invoiced_egp=round(total_invoiced, 2),
            total_paid_egp=round(total_paid, 2),
            balance_due_egp=round(balance_due, 2),
            open_invoices_count=open_count,
            aging=AgingBucket(
                current_30_days=round(b30, 2),
                days_31_to_60=round(b60, 2),
                days_61_to_90=round(b90, 2),
                days_90_plus=round(b90p, 2),
            ),
        )

    # ========================================================================
    # Partner Ledger (Double-Entry Style Statement)
    # ========================================================================

    def get_partner_ledger(
        self,
        partner_id: int,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
    ) -> PartnerLedgerResponse:
        partner = self.validator.validate_partner(partner_id)
        invoices = self.repo.get_invoices_for_ledger(partner_id, from_date, to_date)
        vouchers = self.repo.get_vouchers_for_ledger(partner_id, from_date, to_date)

        raw_events: List[Dict[str, Any]] = []

        for inv in invoices:
            raw_events.append({
                "date": inv.invoice_date,
                "type": "INVOICE",
                "ref": inv.invoice_number or inv.invoice_code,
                "desc": f"Invoice: {inv.partner_type.upper()} ({inv.invoice_code}) - {inv.notes or ''}",
                "debit": inv.net_payable_egp,  # Increase liability (due to partner)
                "credit": 0.0,
            })

        for v in vouchers:
            raw_events.append({
                "date": v.payment_date,
                "type": "PAYMENT",
                "ref": v.voucher_code,
                "desc": f"Payment Voucher: {v.payment_method} ({v.voucher_code}) - Ref: {v.bank_reference or 'N/A'}",
                "debit": 0.0,
                "credit": v.amount_egp,  # Decrease liability (paid to partner)
            })

        # Sort chronologically
        raw_events.sort(key=lambda x: x["date"])

        running_balance = 0.0
        total_invoiced = 0.0
        total_paid = 0.0
        entries: List[PartnerLedgerEntrySchema] = []

        for ev in raw_events:
            total_invoiced += ev["debit"]
            total_paid += ev["credit"]
            running_balance += (ev["debit"] - ev["credit"])

            entries.append(PartnerLedgerEntrySchema(
                entry_date=ev["date"],
                entry_type=ev["type"],
                reference_no=ev["ref"],
                description=ev["desc"],
                debit_egp=round(ev["debit"], 2),
                credit_egp=round(ev["credit"], 2),
                running_balance_egp=round(running_balance, 2),
            ))

        return PartnerLedgerResponse(
            partner_id=partner_id,
            partner_name=partner.partner_name,
            partner_type=partner.partner_type,
            from_date=from_date,
            to_date=to_date,
            total_invoiced_egp=round(total_invoiced, 2),
            total_paid_egp=round(total_paid, 2),
            closing_balance_egp=round(running_balance, 2),
            entries=entries,
        )

    # ========================================================================
    # Monthly WHT Form 41 Report
    # ========================================================================

    def get_wht_form41_report(
        self,
        year: int,
        month: Optional[int] = None,
    ) -> WhtForm41ReportResponse:
        invoices = self.repo.get_invoices_for_wht_report(year, month)

        total_gross = 0.0
        total_wht = 0.0
        records: List[WhtForm41RecordSchema] = []

        for inv in invoices:
            total_gross += inv.total_amount_egp
            total_wht += inv.wht_amount

            # determine service type
            st_map = {
                "freight": "نولون وشحن بحري / دولي",
                "clearance": "خدمات تخليص جمركي واستشارات",
                "inspection": "فحص وتفتيش ومعاينة",
                "insurance": "تأمين ونقل بضائع",
            }
            service_ar = st_map.get(inv.partner_type, "خدمات لوجستية وتوريدات")

            # calculate overall wht rate
            wht_pct = round((inv.wht_amount / inv.total_amount_egp * 100.0), 2) if inv.total_amount_egp > 0 else 1.0

            records.append(WhtForm41RecordSchema(
                invoice_id=inv.invoice_id,
                invoice_code=inv.invoice_code,
                invoice_number=inv.invoice_number,
                invoice_date=inv.invoice_date,
                partner_name=inv.partner_name,
                partner_type=inv.partner_type,
                service_type=service_ar,
                total_amount_egp=round(inv.total_amount_egp, 2),
                wht_rate=wht_pct,
                wht_amount_egp=round(inv.wht_amount, 2),
                net_payable_egp=round(inv.net_payable_egp, 2),
            ))

        return WhtForm41ReportResponse(
            year=year,
            month=month,
            total_gross_amount_egp=round(total_gross, 2),
            total_wht_amount_egp=round(total_wht, 2),
            records_count=len(records),
            records=records,
        )

    # ========================================================================
    # Marine Insurance Claims Workflow
    # ========================================================================

    def update_claim_status(
        self,
        policy_id: int,
        payload: InsurancePolicyClaimStatusUpdate,
        user_name: str = "System",
    ) -> InsurancePolicy:
        policy = self.repo.get_policy_by_id(policy_id)
        if not policy:
            raise HTTPException(status_code=404, detail=f"Policy ID {policy_id} not found.")

        valid_transitions = ["filed", "under_inspection", "accepted", "reimbursed", "rejected"]
        if payload.claim_status not in valid_transitions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid claim status: {payload.claim_status}. Valid: {valid_transitions}",
            )

        policy.claim_status = payload.claim_status
        if payload.claim_amount_egp is not None:
            policy.claim_amount_egp = payload.claim_amount_egp

        if payload.claim_status == "reimbursed":
            policy.status = "claimed"
        elif payload.claim_status == "rejected":
            policy.status = "issued"

        if payload.notes:
            existing = policy.notes or ""
            policy.notes = f"{existing} | Claim Update ({payload.claim_status}): {payload.notes}".strip(" | ")

        self.db.commit()
        self.db.refresh(policy)
        return policy

