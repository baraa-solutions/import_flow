from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


# -------------------------------------------------------------
# Calculation Engine Schemas
# -------------------------------------------------------------
class InsuranceCalculationInput(BaseModel):
    invoice_value: float = Field(..., ge=0.0, description="Commercial invoice value (FOB/EXW)")
    freight_cost: float = Field(0.0, ge=0.0, description="Ocean/Air/Road freight charges")
    other_costs: float = Field(0.0, ge=0.0, description="Inland transport, packing or other costs")
    markup_percentage: Optional[float] = Field(None, ge=0.0, le=1.0, description="Incoterms markup ratio (null = system parameter INSURANCE_MARKUP, today 0.10 for 110% CIF)")
    coverage_clause: str = Field("ICC_A", description="Coverage clause: ICC_A, AIR_ALL_RISKS, ICC_B, ICC_C")
    transport_mode: str = Field("OCEAN", description="Transport mode: OCEAN, AIR, ROAD")
    include_war_and_strikes: bool = Field(True, description="Include War & Strikes Risk clauses")
    currency: str = Field("USD", description="Currency code")
    minimum_premium: Optional[float] = Field(None, ge=0.0, description="Minimum policy net premium (null = system parameter INSURANCE_MIN_PREMIUM)")
    issuance_fee: Optional[float] = Field(None, ge=0.0, description="Fixed issuance administrative fee (null = system parameter INSURANCE_ISSUANCE_FEE)")
    tax_rate: Optional[float] = Field(None, ge=0.0, description="Applicable tax / stamp duty rate (null = system parameter INSURANCE_TAX_RATE)")


class InsuranceCalculationResult(BaseModel):
    cif_value: float
    markup_percentage: float
    insured_value: float
    coverage_clause: str
    base_rate: float
    base_premium: float
    war_rate: float
    war_strikes_premium: float
    net_premium: float
    minimum_premium: float = 0.0
    issuance_fee: float
    tax_rate: float
    tax_amount: float
    total_payable_premium: float
    currency: str


# -------------------------------------------------------------
# Certificate Entity Schemas
# -------------------------------------------------------------
class CargoInsuranceCertificateCreate(BaseModel):
    policy_number: Optional[str] = None
    policy_type: str = "SPECIFIC" # SPECIFIC, OPEN_DECLARATION
    import_file_id: Optional[int] = None
    insurance_company_id: Optional[int] = None
    insurance_company_name: Optional[str] = None
    insured_entity_name: str

    transport_mode: str = "OCEAN"
    carrier_name: Optional[str] = None
    vessel_or_flight_no: Optional[str] = None
    voyage_number: Optional[str] = None
    tracking_reference: Optional[str] = None
    port_of_loading: str
    port_of_discharge: str
    final_destination: Optional[str] = None

    currency: str = "USD"
    exchange_rate: float = 1.0
    invoice_value: float = Field(..., ge=0.0)
    freight_cost: float = Field(0.0, ge=0.0)
    other_logistics_costs: float = Field(0.0, ge=0.0)
    markup_percentage: Optional[float] = Field(None, ge=0.0, le=1.0)  # null = system parameter INSURANCE_MARKUP

    coverage_clause: str = "ICC_A"
    include_war_and_strikes: bool = True
    # null = system parameters INSURANCE_MIN_PREMIUM / INSURANCE_ISSUANCE_FEE / INSURANCE_TAX_RATE
    minimum_premium: Optional[float] = Field(None, ge=0.0)
    issuance_fee: Optional[float] = Field(None, ge=0.0)
    tax_rate: Optional[float] = Field(None, ge=0.0)

    goods_description: Optional[str] = None
    package_count: Optional[int] = None
    package_type: Optional[str] = None
    gross_weight_kg: Optional[float] = None
    survey_agent_in_destination: Optional[str] = None
    claims_payable_at: Optional[str] = "Cairo, Egypt"
    remarks: Optional[str] = None


class CargoInsuranceCertificateUpdate(BaseModel):
    policy_number: Optional[str] = None
    policy_type: Optional[str] = None
    insurance_company_id: Optional[int] = None
    insurance_company_name: Optional[str] = None
    insured_entity_name: Optional[str] = None

    transport_mode: Optional[str] = None
    carrier_name: Optional[str] = None
    vessel_or_flight_no: Optional[str] = None
    voyage_number: Optional[str] = None
    tracking_reference: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    final_destination: Optional[str] = None

    currency: Optional[str] = None
    exchange_rate: Optional[float] = None
    invoice_value: Optional[float] = None
    freight_cost: Optional[float] = None
    other_logistics_costs: Optional[float] = None
    markup_percentage: Optional[float] = None

    coverage_clause: Optional[str] = None
    include_war_and_strikes: Optional[bool] = None
    minimum_premium: Optional[float] = None
    issuance_fee: Optional[float] = None
    tax_rate: Optional[float] = None

    goods_description: Optional[str] = None
    package_count: Optional[int] = None
    package_type: Optional[str] = None
    gross_weight_kg: Optional[float] = None
    survey_agent_in_destination: Optional[str] = None
    claims_payable_at: Optional[str] = None
    status: Optional[str] = Field(None, description="Deprecated and ignored: the status only changes through /issue")
    remarks: Optional[str] = None


@read_model
class CargoInsuranceCertificateResponse(LegacyRowTolerantModel):
    certificate_id: int
    certificate_code: str
    policy_number: Optional[str] = None
    policy_type: str = "SPECIFIC"
    import_file_id: Optional[int] = None
    insurance_company_id: Optional[int] = None
    insurance_company_name: Optional[str] = None
    insured_entity_name: str = ""

    transport_mode: str = "OCEAN"
    carrier_name: Optional[str] = None
    vessel_or_flight_no: Optional[str] = None
    voyage_number: Optional[str] = None
    tracking_reference: Optional[str] = None
    port_of_loading: str = ""
    port_of_discharge: str = ""
    final_destination: Optional[str] = None

    currency: str = "USD"
    exchange_rate: Optional[float] = None
    invoice_value: Optional[float] = None
    freight_cost: Optional[float] = None
    other_logistics_costs: Optional[float] = None
    cif_value: Optional[float] = None
    markup_percentage: Optional[float] = None
    insured_value: Optional[float] = None

    coverage_clause: str = "ICC_A"
    include_war_and_strikes: bool = True
    base_rate: Optional[float] = None
    war_rate: Optional[float] = None

    base_premium: Optional[float] = None
    war_strikes_premium: Optional[float] = None
    minimum_premium: Optional[float] = None
    net_premium: Optional[float] = None
    issuance_fee: Optional[float] = None
    tax_rate: Optional[float] = None
    tax_amount: Optional[float] = None
    total_payable_premium: Optional[float] = None

    goods_description: Optional[str] = None
    package_count: Optional[int] = None
    package_type: Optional[str] = None
    gross_weight_kg: Optional[float] = None
    survey_agent_in_destination: Optional[str] = None
    claims_payable_at: Optional[str] = None

    status: str = "Draft"
    issued_at: Optional[datetime] = None
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: str = "System"
    updated_by: str = "System"
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class CargoInsuranceCertificateListResponse(BaseModel):
    total: int
    items: List[CargoInsuranceCertificateResponse]
