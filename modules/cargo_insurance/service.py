from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.cargo_insurance.repository import CargoInsuranceRepository
from modules.cargo_insurance.schemas import (
    InsuranceCalculationInput,
    InsuranceCalculationResult,
    CargoInsuranceCertificateCreate,
    CargoInsuranceCertificateUpdate,
)
from modules.cargo_insurance.validators import (
    CERTIFICATE_LABEL_AR,
    RESETTABLE_RATE_FIELDS,
    validate_certificate_deletable,
    validate_cargo_insurance_create,
    validate_cargo_insurance_update,
    validate_certificate_editable,
    validate_coverage_clause,
    validate_no_active_certificate_for_file,
    validate_transport_mode,
)
from modules.common.system_parameters import get_float_parameter
from modules.common.validators import not_found, not_null_columns

# System parameter keys (seeded by the lead) and today's values, used when a key is missing or invalid.
INSURANCE_RATE_KEYS: Dict[str, str] = {
    "ICC_A": "INSURANCE_RATE_ICC_A",                  # 0.25% All Risks (Institute Cargo Clauses A)
    "AIR_ALL_RISKS": "INSURANCE_RATE_AIR_ALL_RISKS",  # 0.20% Air Cargo All Risks
    "ICC_B": "INSURANCE_RATE_ICC_B",                  # 0.15% Intermediate (Institute Cargo Clauses B)
    "ICC_C": "INSURANCE_RATE_ICC_C",                  # 0.10% Minimum (Institute Cargo Clauses C)
}
DEFAULT_RATE_TABLE: Dict[str, float] = {"ICC_A": 0.0025, "AIR_ALL_RISKS": 0.0020, "ICC_B": 0.0015, "ICC_C": 0.0010}
INSURANCE_WAR_STRIKES_RATE = "INSURANCE_WAR_STRIKES_RATE"
DEFAULT_WAR_STRIKES_RATE = 0.0005  # 0.05% Institute War & Strikes Clauses
INSURANCE_TAX_RATE = "INSURANCE_TAX_RATE"
DEFAULT_TAX_RATE = 0.05
INSURANCE_ISSUANCE_FEE = "INSURANCE_ISSUANCE_FEE"
DEFAULT_ISSUANCE_FEE = 15.0
INSURANCE_MIN_PREMIUM = "INSURANCE_MIN_PREMIUM"
DEFAULT_MIN_PREMIUM = 30.0
INSURANCE_MARKUP = "INSURANCE_MARKUP"
DEFAULT_MARKUP = 0.10


@dataclass(frozen=True)
class InsuranceRates:
    """Configured premium rates; a request value (markup, minimum, fee, tax) overrides the configured default."""
    clause_rates: Dict[str, float]
    war_strikes_rate: float
    tax_rate: float
    issuance_fee: float
    minimum_premium: float
    markup: float


DEFAULT_INSURANCE_RATES = InsuranceRates(
    clause_rates=dict(DEFAULT_RATE_TABLE),
    war_strikes_rate=DEFAULT_WAR_STRIKES_RATE,
    tax_rate=DEFAULT_TAX_RATE,
    issuance_fee=DEFAULT_ISSUANCE_FEE,
    minimum_premium=DEFAULT_MIN_PREMIUM,
    markup=DEFAULT_MARKUP,
)


def load_insurance_rates(db: Session) -> InsuranceRates:
    """The premium rates from ``system_parameters`` (defaults = today's values, so results stay identical)."""
    return InsuranceRates(
        clause_rates={clause: get_float_parameter(db, key, DEFAULT_RATE_TABLE[clause]) for clause, key in INSURANCE_RATE_KEYS.items()},
        war_strikes_rate=get_float_parameter(db, INSURANCE_WAR_STRIKES_RATE, DEFAULT_WAR_STRIKES_RATE),
        tax_rate=get_float_parameter(db, INSURANCE_TAX_RATE, DEFAULT_TAX_RATE),
        issuance_fee=get_float_parameter(db, INSURANCE_ISSUANCE_FEE, DEFAULT_ISSUANCE_FEE),
        minimum_premium=get_float_parameter(db, INSURANCE_MIN_PREMIUM, DEFAULT_MIN_PREMIUM),
        markup=get_float_parameter(db, INSURANCE_MARKUP, DEFAULT_MARKUP),
    )


def calculate_cargo_insurance_engine(
    input_data: InsuranceCalculationInput, rates: Optional[InsuranceRates] = None
) -> InsuranceCalculationResult:
    """Premium engine. ``rates`` = ``load_insurance_rates(db)``; ``None`` uses today's default values."""
    rates = rates or DEFAULT_INSURANCE_RATES
    validate_coverage_clause(input_data.coverage_clause)
    validate_transport_mode(input_data.transport_mode)

    markup = input_data.markup_percentage if input_data.markup_percentage is not None else rates.markup
    issuance_fee = input_data.issuance_fee if input_data.issuance_fee is not None else rates.issuance_fee
    min_premium = input_data.minimum_premium if input_data.minimum_premium is not None else rates.minimum_premium
    tax_rate = input_data.tax_rate if input_data.tax_rate is not None else rates.tax_rate

    # 1. Calculate CIF / CIP Base and Insured Value (110% CIF standard)
    cif_value = round(input_data.invoice_value + input_data.freight_cost + (input_data.other_costs or 0.0), 2)
    insured_value = round(cif_value * (1.0 + markup), 2)

    # 2. Base rate of the coverage clause
    base_rate = rates.clause_rates[input_data.coverage_clause]
    base_premium = round(insured_value * base_rate, 2)

    # 3. War & Strikes Add-on
    war_rate = rates.war_strikes_rate if input_data.include_war_and_strikes else 0.0
    war_strikes_premium = round(insured_value * war_rate, 2)

    # 4. Apply Policy Minimum Premium Threshold
    calculated_net = round(base_premium + war_strikes_premium, 2)
    net_premium = round(max(calculated_net, min_premium), 2)

    # 5. Administrative Issuance Fee, Stamp Duty & Taxes
    taxable_base = net_premium + issuance_fee
    tax_amount = round(taxable_base * tax_rate, 2)
    total_payable = round(net_premium + issuance_fee + tax_amount, 2)

    return InsuranceCalculationResult(
        cif_value=cif_value,
        markup_percentage=markup,
        insured_value=insured_value,
        coverage_clause=input_data.coverage_clause,
        base_rate=base_rate,
        base_premium=base_premium,
        war_rate=war_rate,
        war_strikes_premium=war_strikes_premium,
        net_premium=net_premium,
        minimum_premium=min_premium,
        issuance_fee=issuance_fee,
        tax_rate=tax_rate,
        tax_amount=tax_amount,
        total_payable_premium=total_payable,
        currency=input_data.currency,
    )


def _blank_to_none(value: Optional[str]) -> Optional[str]:
    return value.strip() if value and value.strip() else None


class CargoInsuranceService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CargoInsuranceRepository(db)

    def calculate_insurance(self, input_data: InsuranceCalculationInput) -> InsuranceCalculationResult:
        return calculate_cargo_insurance_engine(input_data, load_insurance_rates(self.db))

    def create_certificate(
        self,
        data: CargoInsuranceCertificateCreate,
        current_user: str = "system",
    ) -> CargoInsuranceCertificate:
        validate_cargo_insurance_create(data)
        if data.import_file_id:
            existing = self.repo.get_active_for_file(data.import_file_id)
            validate_no_active_certificate_for_file(existing)

        # 1. Run Financial Engine Calculation
        calc_result = calculate_cargo_insurance_engine(InsuranceCalculationInput(
            invoice_value=data.invoice_value,
            freight_cost=data.freight_cost,
            other_costs=data.other_logistics_costs,
            markup_percentage=data.markup_percentage,
            coverage_clause=data.coverage_clause,
            transport_mode=data.transport_mode,
            include_war_and_strikes=data.include_war_and_strikes,
            currency=data.currency,
            minimum_premium=data.minimum_premium,
            issuance_fee=data.issuance_fee,
            tax_rate=data.tax_rate,
        ), load_insurance_rates(self.db))

        def build() -> CargoInsuranceCertificate:
            cert_code = self.repo.generate_next_certificate_code()
            certificate = CargoInsuranceCertificate(
                certificate_code=cert_code,
                # Q5 (safe default): a missing policy number is still generated from the certificate sequence
                policy_number=data.policy_number or f"POL-{datetime.now().strftime('%Y%m')}-{cert_code.split('-')[-1]}",
                policy_type=data.policy_type,
                import_file_id=data.import_file_id,
                insurance_company_id=data.insurance_company_id,
                insurance_company_name=_blank_to_none(data.insurance_company_name),
                insured_entity_name=data.insured_entity_name,
                transport_mode=data.transport_mode,
                carrier_name=data.carrier_name,
                vessel_or_flight_no=data.vessel_or_flight_no,
                voyage_number=data.voyage_number,
                tracking_reference=data.tracking_reference,
                port_of_loading=data.port_of_loading,
                port_of_discharge=data.port_of_discharge,
                final_destination=_blank_to_none(data.final_destination),
                currency=data.currency,
                exchange_rate=data.exchange_rate,
                invoice_value=data.invoice_value,
                freight_cost=data.freight_cost,
                other_logistics_costs=data.other_logistics_costs,
                cif_value=calc_result.cif_value,
                markup_percentage=calc_result.markup_percentage,
                insured_value=calc_result.insured_value,
                coverage_clause=calc_result.coverage_clause,
                include_war_and_strikes=data.include_war_and_strikes,
                base_rate=calc_result.base_rate,
                war_rate=calc_result.war_rate,
                base_premium=calc_result.base_premium,
                war_strikes_premium=calc_result.war_strikes_premium,
                minimum_premium=calc_result.minimum_premium,
                net_premium=calc_result.net_premium,
                issuance_fee=calc_result.issuance_fee,
                tax_rate=calc_result.tax_rate,
                tax_amount=calc_result.tax_amount,
                total_payable_premium=calc_result.total_payable_premium,
                goods_description=data.goods_description,
                package_count=data.package_count,
                package_type=data.package_type,
                gross_weight_kg=data.gross_weight_kg,
                survey_agent_in_destination=_blank_to_none(data.survey_agent_in_destination),
                claims_payable_at=_blank_to_none(data.claims_payable_at),
                status="DRAFT",
                remarks=data.remarks,
                created_by=current_user,
                updated_by=current_user,
            )
            self.repo.add(certificate)
            return certificate

        try:
            certificate = build()
            self.db.commit()
        except IntegrityError:
            # a concurrent create took the same INS code: retry once with the next one
            self.db.rollback()
            certificate = build()
            self.db.commit()
        self.db.refresh(certificate)
        return certificate

    def get_certificate(self, certificate_id: int) -> CargoInsuranceCertificate:
        cert = self.repo.get_by_id(certificate_id)
        if not cert:
            raise not_found(CERTIFICATE_LABEL_AR, certificate_id)
        return cert

    def list_certificates(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CargoInsuranceCertificate], int]:
        return self.repo.list_certificates(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            status=status,
            search=search,
        )

    def update_certificate(
        self,
        certificate_id: int,
        data: CargoInsuranceCertificateUpdate,
        current_user: str = "system",
    ) -> CargoInsuranceCertificate:
        cert = self.get_certificate(certificate_id)
        validate_certificate_editable(cert.status, cert.certificate_code)
        update_dict = validate_cargo_insurance_update(data, not_null_columns(CargoInsuranceCertificate))
        rates = load_insurance_rates(self.db)
        configured = {
            "markup_percentage": rates.markup,
            "minimum_premium": rates.minimum_premium,
            "issuance_fee": rates.issuance_fee,
            "tax_rate": rates.tax_rate,
        }
        for field in RESETTABLE_RATE_FIELDS:
            if field in update_dict and update_dict[field] is None:
                update_dict[field] = configured[field]

        for key, value in update_dict.items():
            if hasattr(cert, key):
                setattr(cert, key, value)

        # Recalculate the premium from the stored inputs (markup, minimum, fee and tax stored on the certificate)
        calc_result = calculate_cargo_insurance_engine(InsuranceCalculationInput(
            invoice_value=cert.invoice_value,
            freight_cost=cert.freight_cost,
            other_costs=cert.other_logistics_costs,
            markup_percentage=cert.markup_percentage,
            coverage_clause=cert.coverage_clause,
            transport_mode=cert.transport_mode,
            include_war_and_strikes=cert.include_war_and_strikes,
            currency=cert.currency,
            minimum_premium=cert.minimum_premium,
            issuance_fee=cert.issuance_fee,
            tax_rate=cert.tax_rate,
        ), rates)
        cert.cif_value = calc_result.cif_value
        cert.insured_value = calc_result.insured_value
        cert.base_rate = calc_result.base_rate
        cert.base_premium = calc_result.base_premium
        cert.war_rate = calc_result.war_rate
        cert.war_strikes_premium = calc_result.war_strikes_premium
        cert.net_premium = calc_result.net_premium
        cert.tax_amount = calc_result.tax_amount
        cert.total_payable_premium = calc_result.total_payable_premium

        cert.updated_at = datetime.now(timezone.utc)
        cert.updated_by = current_user
        self.db.commit()
        self.db.refresh(cert)
        return cert

    def issue_certificate(
        self,
        certificate_id: int,
        current_user: str = "system",
    ) -> CargoInsuranceCertificate:
        cert = self.get_certificate(certificate_id)
        if cert.status == "ISSUED":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"وثيقة التأمين {cert.certificate_code} صادرة بالفعل.",
            )
        if cert.status == "CANCELLED":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"لا يمكن إصدار وثيقة التأمين {cert.certificate_code} لأنها ملغاة.",
            )

        cert.status = "ISSUED"
        cert.issued_at = datetime.now(timezone.utc)
        cert.updated_at = datetime.now(timezone.utc)
        cert.updated_by = current_user
        self.db.commit()
        self.db.refresh(cert)
        return cert

    def delete_certificate(self, certificate_id: int, current_user: str = "system") -> None:
        cert = self.get_certificate(certificate_id)
        validate_certificate_deletable(cert.status, cert.certificate_code)
        self.repo.soft_delete(cert)
        cert.updated_by = current_user
        cert.updated_at = datetime.now(timezone.utc)
        self.db.commit()

    def restore_certificate(self, certificate_id: int, current_user: str = "system") -> CargoInsuranceCertificate:
        cert = self.repo.get_by_id(certificate_id, include_inactive=True)
        if not cert:
            raise not_found(CERTIFICATE_LABEL_AR, certificate_id)
        if cert.is_active:
            return cert
        if cert.import_file_id and cert.status != "CANCELLED":
            existing = self.repo.get_active_for_file(cert.import_file_id)
            if existing and existing.certificate_id != cert.certificate_id:
                validate_no_active_certificate_for_file(existing)
        cert.is_active = True
        cert.updated_by = current_user
        cert.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(cert)
        return cert

