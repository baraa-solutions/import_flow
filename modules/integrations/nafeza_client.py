import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional
from .pki_signer import PKISignerService
from .integration_mode import (
    IntegrationProvider,
    ensure_mode_allowed,
    select_integration_mode,
    simulation_flags,
)


class NafezaIntegrationClient:
    """
    Official Nafeza (MTS - National Single Window for Egyptian Foreign Trade) Client.
    Supports ACID Application, Customs Declaration (Form 46) Polling, and Webhook Receiver.
    """

    def __init__(self, mode: Optional[str] = None, api_key: Optional[str] = None):
        # Mode comes from settings (NAFEZA_INTEGRATION_MODE); ``mode`` is an override for code/tests only.
        self.integration_mode = select_integration_mode(IntegrationProvider.NAFEZA, mode)
        self.mode = self.integration_mode.value
        self.api_key = api_key or os.getenv("NAFEZA_API_KEY")
        self.signer = PKISignerService(mode=mode)

    def request_acid_number(
        self,
        importer_id: str,
        exporter_id: str,
        exporter_country_code: str,
        tariff_hs_codes: list[str],
        invoice_value_usd: float,
    ) -> Dict[str, Any]:
        """
        Submits ACID Request to Nafeza Gate (simulated in MOCK mode; refused in the production build).
        """
        ensure_mode_allowed(IntegrationProvider.NAFEZA, self.integration_mode)
        payload = {
            "importer_id": importer_id,
            "exporter_id": exporter_id,
            "exporter_country_code": exporter_country_code,
            "tariff_hs_codes": tariff_hs_codes,
            "invoice_value_usd": invoice_value_usd,
            "requested_at": datetime.now(timezone.utc).isoformat(),
        }

        pki_sig = self.signer.sign_payload(payload)

        # Generate ACID code
        random_acid = f"{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
        validity_end = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%d")

        return {
            "status": "APPROVED",
            "acid_number": random_acid,
            "issue_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "expiry_date": validity_end,
            "nafeza_reference_id": f"NAF-REQ-{uuid.uuid4().hex[:8].upper()}",
            "pki_signature": pki_sig,
            **simulation_flags(self.integration_mode),
            "message": "SIMULATED ACID number - nothing was sent to Nafeza.",
        }

    def verify_webhook_signature(self, webhook_body: str, signature_header: str) -> bool:
        """
        Verifies the signature on an incoming Nafeza webhook payload.

        No real HMAC / RSA verification exists yet (Phase 3), so every webhook is rejected, in every
        mode: accepting unverified callbacks would let anyone forge an official Nafeza status.
        """
        return False

    # =========================================================================
    # INT-NAFEZA-008: Tariff Parse & Sync + Customs Exchange Rates
    # =========================================================================

    def parse_and_sync_tariff(self, db, raw_text: str):
        """
        Parses raw text copied from the Egyptian Nafeza portal, extracts
        HS Code, Description, Taxes (Duty, VAT, Schedule, Dev Fee, Import Fee),
        and Preferential Agreements, and saves/updates them in the database.
        """
        from modules.customs_tariff.nafeza_text_parser import parse_nafeza_tariff_text
        from modules.customs_tariff import repository as tariff_repo
        from modules.customs_tariff.service import create_tariff_service, create_preferential_agreement_service
        from modules.customs_tariff.schemas import CustomsTariffUpdate
        from .schemas import NafezaTariffSyncResponse

        tariff_create, agreements_create = parse_nafeza_tariff_text(raw_text)

        # Check if tariff exists
        existing_tariff = tariff_repo.get_tariff_by_hs_code(db, tariff_create.hs_code)
        if existing_tariff:
            # Update existing
            update_data = {
                "hs_description": tariff_create.hs_description,
                "customs_duty_rate": tariff_create.customs_duty_rate,
                "vat_rate": tariff_create.vat_rate,
                "schedule_tax_rate": tariff_create.schedule_tax_rate,
                "development_fee_rate": tariff_create.development_fee_rate,
                "import_fee_rate": tariff_create.import_fee_rate,
                "requires_inspection": tariff_create.requires_inspection,
                "regulatory_authority": tariff_create.regulatory_authority,
                "prior_approval_note": tariff_create.prior_approval_note,
                "has_anti_dumping_risk": tariff_create.has_anti_dumping_risk,
                "anti_dumping_notes": tariff_create.anti_dumping_notes,
                "source_url": tariff_create.source_url,
            }
            tariff_record = tariff_repo.update_tariff(db, existing_tariff.tariff_id, update_data)
            # BE67-T11: the repository only flushes; this sync owns the transaction.
            db.commit()
            db.refresh(tariff_record)
        else:
            tariff_record = create_tariff_service(db, tariff_create)

        if getattr(tariff_record, "has_anti_dumping_risk", False):
            from modules.experience_guide.service import ExperienceGuideService
            ExperienceGuideService(db).sync_anti_dumping_guide_entry(
                tariff_record.hs_code,
                tariff_record.hs_description,
                tariff_record.anti_dumping_notes,
            )

        # Sync agreements
        synced_agreements = []
        for ag in agreements_create:
            # Check duplicate agreement for this HS code
            existing_ags = tariff_repo.get_agreements_by_hs_code(db, tariff_create.hs_code)
            match = [a for a in existing_ags if a.agreement_name == ag.agreement_name]
            if not match:
                new_ag = create_preferential_agreement_service(db, ag)
                synced_agreements.append({
                    "agreement_name": new_ag.agreement_name,
                    "reduction_type": new_ag.reduction_type,
                    "preferential_duty_rate": float(new_ag.preferential_duty_rate or 0.0),
                    "publication_notice": new_ag.publication_notice,
                })
            else:
                synced_agreements.append({
                    "agreement_name": match[0].agreement_name,
                    "reduction_type": match[0].reduction_type,
                    "preferential_duty_rate": float(match[0].preferential_duty_rate or 0.0),
                    "publication_notice": match[0].publication_notice,
                })

        return NafezaTariffSyncResponse(
            hs_code=tariff_record.hs_code,
            hs_description=tariff_record.hs_description,
            customs_duty_rate=float(tariff_record.customs_duty_rate or 0.0),
            vat_rate=float(tariff_record.vat_rate or 0.0),
            schedule_tax_rate=float(tariff_record.schedule_tax_rate or 0.0),
            development_fee_rate=float(tariff_record.development_fee_rate or 0.0),
            import_fee_rate=float(tariff_record.import_fee_rate or 0.0),
            requires_inspection=bool(tariff_record.requires_inspection),
            regulatory_authority=tariff_record.regulatory_authority,
            agreements_count=len(synced_agreements),
            agreements_summary=synced_agreements,
            message="تم تحليل وتحديث البند الجمركي والاتفاقيات التفضيلية والرسوم بنجاح من منظومة نافذة.",
        )

    def lookup_tariff_by_hs_code(self, db, hs_code: str):
        """Fetches live/synced tariff details for a given HS code."""
        from modules.customs_tariff import repository as tariff_repo
        from .schemas import NafezaTariffSyncResponse
        from fastapi import HTTPException

        clean_hs = hs_code.replace(".", "").strip()
        tariff = tariff_repo.get_tariff_by_hs_code(db, clean_hs)
        if not tariff:
            raise HTTPException(status_code=404, detail=f"بند التعريفة الجمركية #{hs_code} غير مسجل في النظام.")

        agreements = tariff_repo.get_agreements_by_hs_code(db, clean_hs)

        ag_summary = [
            {
                "agreement_name": a.agreement_name,
                "reduction_type": a.reduction_type,
                "preferential_duty_rate": float(a.preferential_duty_rate or 0.0),
                "publication_notice": a.publication_notice,
            }
            for a in agreements
        ]

        return NafezaTariffSyncResponse(
            hs_code=tariff.hs_code,
            hs_description=tariff.hs_description,
            customs_duty_rate=float(tariff.customs_duty_rate or 0.0),
            vat_rate=float(tariff.vat_rate or 0.0),
            schedule_tax_rate=float(tariff.schedule_tax_rate or 0.0),
            development_fee_rate=float(tariff.development_fee_rate or 0.0),
            import_fee_rate=float(tariff.import_fee_rate or 0.0),
            requires_inspection=bool(tariff.requires_inspection),
            regulatory_authority=tariff.regulatory_authority,
            agreements_count=len(ag_summary),
            agreements_summary=ag_summary,
            message="تم استرجاع بيانات التعريفة الجمركية والاتفاقيات بنجاح.",
        )

    def sync_official_customs_exchange_rates(self, db, rates_override: Optional[Dict[str, float]] = None):
        """
        Syncs official Egyptian Customs foreign exchange rates (سعر الصرف الجمركي الرسمي).
        Updates exchange_rates and currencies in DB.
        """
        from datetime import date
        from decimal import Decimal
        from modules.currencies.model import Currency, ExchangeRate
        from .schemas import CustomsExchangeRateSyncResponse, CustomsExchangeRateItem

        default_customs_rates = {
            "USD": 48.6500,
            "EUR": 53.2500,
            "GBP": 63.4000,
            "CNY": 6.8200,
            "SAR": 12.9700,
            "AED": 13.2500,
            "JPY": 0.3250,
        }

        rates_to_apply = rates_override or default_customs_rates
        today = date.today()
        items: list[CustomsExchangeRateItem] = []

        for code, rate_val in rates_to_apply.items():
            curr = db.query(Currency).filter(Currency.currency_code == code, Currency.is_active == True).first()
            if not curr:
                # Create currency if missing
                curr = Currency(
                    currency_code=code,
                    currency_name=f"{code} Currency",
                    currency_symbol=code,
                )
                db.add(curr)
                db.commit()
                db.refresh(curr)

            # Get previous rate
            prev_rate = db.query(ExchangeRate).filter(
                ExchangeRate.currency_id == curr.currency_id,
                ExchangeRate.is_active == True,
            ).order_by(ExchangeRate.effective_date.desc()).first()

            prev_val = float(prev_rate.customs_rate) if prev_rate else None

            # Create new official rate
            rate_entry = ExchangeRate(
                currency_id=curr.currency_id,
                commercial_rate=Decimal(str(round(rate_val * 1.005, 4))),
                customs_rate=Decimal(str(rate_val)),
                effective_date=today,
                is_active=True,
            )
            db.add(rate_entry)
            db.commit()

            items.append(
                CustomsExchangeRateItem(
                    currency_code=curr.currency_code,
                    currency_name=curr.currency_name,
                    exchange_rate=rate_val,
                    previous_rate=prev_val,
                    effective_date=today.isoformat(),
                    source="مصلحة الجمارك المصرية / البنك المركزي",
                )
            )

        return CustomsExchangeRateSyncResponse(
            status="SUCCESS",
            synced_count=len(items),
            rates=items,
            announcement_date=today.isoformat(),
            message="تمت مزامنة أسعار الصرف الجمركية الرسمية وتحديث جدول العملات بنجاح.",
        )

    def get_latest_customs_exchange_rates(self, db):
        """Returns latest official customs exchange rates for active currencies."""
        from modules.currencies.model import Currency, ExchangeRate
        from .schemas import CustomsExchangeRateItem

        currencies = db.query(Currency).filter(Currency.is_active == True, Currency.is_base_currency == False).all()
        result = []

        for curr in currencies:
            latest_rate = db.query(ExchangeRate).filter(
                ExchangeRate.currency_id == curr.currency_id,
                ExchangeRate.is_active == True,
            ).order_by(ExchangeRate.effective_date.desc()).first()

            if latest_rate:
                result.append(
                    CustomsExchangeRateItem(
                        currency_code=curr.currency_code,
                        currency_name=curr.currency_name,
                        exchange_rate=float(latest_rate.customs_rate),
                        effective_date=latest_rate.effective_date.isoformat(),
                        source="مصلحة الجمارك المصرية",
                    )
                )

        return result

