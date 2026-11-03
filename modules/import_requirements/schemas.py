from typing import Optional, List, Any, Dict
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime

from modules.common.system_messages import SystemMessageItem


class ImportRequirementHSCodeItem(BaseModel):
    hs_code: str
    commodity_description: Optional[str] = None
    item_code: Optional[str] = None
    country_of_origin: Optional[str] = None
    currency: Optional[str] = None
    item_value: float = 0.0
    quantity: float = 0.0
    unit_of_measure: Optional[str] = None
    
    # Pillar 1: Decree 43 & Factory Registration
    decree_43_applicable: bool = False
    white_list_verified: bool = False
    factory_registration_no: Optional[str] = None
    decree_43_action: Optional[str] = None  # verified, justified, task_created, pending
    decree_43_justification: Optional[str] = None  # سبب الاعتماد / مبرر الاستثناء
    decree_43_notes: Optional[str] = None

    # Pillar 2: COO & Trade Agreements
    coo_required: bool = False
    coo_type: Optional[str] = None
    coo_status: str = "Not Required"
    coo_notes: Optional[str] = None

    # Pillar 3: Pre-Shipment Inspection
    inspection_required: bool = False
    inspection_body: Optional[str] = None
    inspection_status: str = "Not Required"
    inspection_report_no: Optional[str] = None
    inspection_notes: Optional[str] = None

    # Pillar 4: Prior Regulatory Permits
    permit_required: bool = False
    regulatory_authority: Optional[str] = None
    permit_number: Optional[str] = None
    permit_status: str = "Not Required"
    permit_notes: Optional[str] = None

    # Pillar 5: Technical Certificates
    msds_required: bool = False
    msds_status: str = "Not Required"
    halal_cert_required: bool = False
    halal_cert_status: str = "Not Required"
    coa_required: bool = False
    coa_status: str = "Not Required"
    technical_notes: Optional[str] = None

    # Advanced Operational Pillars per HS Code
    cargox_verified: bool = False
    ready_for_acid: bool = False
    commodity_group_matched: bool = True
    import_card_group_code: Optional[str] = None
    is_shelflife_applicable: bool = False
    shelf_life_total_days: Optional[int] = None
    shelf_life_remaining_percent: Optional[float] = None
    artwork_arabic_approved: Optional[bool] = None
    labeling_notes: Optional[str] = None
    sampling_required: bool = False
    lab_type: Optional[str] = None
    detention_allowed: bool = False
    estimated_lab_fees: float = 0.0
    cold_chain_required: bool = False
    target_temperature: Optional[str] = None
    data_logger_verified: bool = False
    is_hazmat: bool = False
    imo_class: Optional[str] = None


class ImportRequirementBase(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    hs_code: Optional[str] = None
    commodity_description: Optional[str] = None
    country_of_origin: Optional[str] = None
    currency: Optional[str] = Field(None, max_length=10)
    shipment_value: float = Field(0.0, ge=0.0)
    shipment_value_usd: float = Field(0.0, ge=0.0)
    
    # Pillar 1: Decree 43 & Foreign Suppliers
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    decree_43_applicable: bool = False
    white_list_required: bool = False
    white_list_verified: bool = False
    factory_registration_no: Optional[str] = None
    
    # Pillar 2: Certificate of Origin (COO) & Trade Reductions
    coo_required: bool = False
    coo_type: Optional[str] = None
    coo_status: str = Field("Not Required")
    coo_notes: Optional[str] = None
    
    # Pillar 3: Inspection Certificate
    inspection_required: bool = False
    inspection_body: Optional[str] = None
    inspection_status: str = Field("Not Required")
    inspection_report_no: Optional[str] = None
    inspection_notes: Optional[str] = None
    
    # Pillar 4: Import Permit & Regulatory Authorities
    import_permit_required: bool = False
    permit_issuing_authority: Optional[str] = None
    permit_number: Optional[str] = None
    permit_status: str = Field("Not Required")
    permit_notes: Optional[str] = None
    
    # Pillar 5: Technical & Special Certs (MSDS, Halal, COA)
    msds_required: bool = False
    msds_status: str = Field("Not Required")
    msds_notes: Optional[str] = None
    
    halal_cert_required: bool = False
    halal_cert_status: str = Field("Not Required")
    halal_cert_notes: Optional[str] = None
    
    coa_required: bool = False
    coa_status: str = Field("Not Required")
    coa_notes: Optional[str] = None
    
    hs_code_items: Optional[List[Dict[str, Any]]] = None
    other_requirements: Optional[List[Dict[str, Any]]] = None
    
    # Post-ACID Confirmation & Linkage (مرحلة تأكيدية بعد إصدار ACID)
    acid_number: Optional[str] = None
    consultation_id: Optional[int] = None
    consultation_code: Optional[str] = None
    confirmation_status: str = Field("Pending Confirmation")
    is_post_acid_confirmed: bool = False
    confirmed_at: Optional[datetime] = None
    confirmed_by: Optional[str] = None

    # Sailing & Shipping Progress (من إصدار ACID حتى الإبحار)
    sailing_status: Optional[str] = Field("Pre-Sailing", max_length=50) # Pre-Sailing, Cleared for Sailing, Sailed
    sailing_date: Optional[str] = None

    # CargoX & Pre-ACID Readiness (الركيزة 1: التسجيل المسبق وجاهزية كارغو إكس)
    cargox_verified: bool = False
    cargox_status: str = Field("Not Verified")
    ready_for_acid: bool = False
    triple_match_status: str = Field("Pending")

    # Import Card & Commodity Group (الركيزة 2: مطابقة المجموعات السلعية)
    commodity_group_matched: bool = True
    import_card_group_code: Optional[str] = None

    # Adaptive Shelf-Life & Labeling (الركيزة 3: الصلاحية والملصق العربي المشروط)
    is_shelflife_applicable: bool = False
    shelf_life_total_days: Optional[int] = None
    shelf_life_remaining_percent: Optional[float] = None
    artwork_arabic_approved: Optional[bool] = None
    labeling_notes: Optional[str] = None

    # Testing & Physical Sampling (الركيزة 4: مسار الفحص والمعامل والإفراج تحت التحفظ)
    sampling_required: bool = False
    lab_type: Optional[str] = None
    detention_allowed: bool = False
    estimated_lab_fees: float = Field(0.0, ge=0.0)

    # Special Logistics: Cold Chain & Hazmat (الركيزة 5: النقل المبرد والمواد الخطرة)
    cold_chain_required: bool = False
    target_temperature: Optional[str] = None
    data_logger_verified: bool = False
    is_hazmat: bool = False
    imo_class: Optional[str] = None

    # Governance: Maker-Checker & Overrides (الركيزة 6: حوكمة الصلاحيات والاعتماد المزدوج)
    checker_user_id: Optional[int] = None
    checker_approved: bool = False
    checker_notes: Optional[str] = None
    is_overridden: bool = False
    override_reason: Optional[str] = None

    # Overall Assessment & Risk
    overall_status: str = Field("Draft")
    risk_level: str = Field("Low")
    assessed_by: str = Field("Kamal")
    assessment_notes: Optional[str] = None


class ImportRequirementCreate(ImportRequirementBase):
    pass


class ImportRequirementUpdate(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    hs_code: Optional[str] = None
    commodity_description: Optional[str] = None
    country_of_origin: Optional[str] = None
    currency: Optional[str] = None
    shipment_value: Optional[float] = None
    shipment_value_usd: Optional[float] = None
    
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    decree_43_applicable: Optional[bool] = None
    white_list_required: Optional[bool] = None
    white_list_verified: Optional[bool] = None
    factory_registration_no: Optional[str] = None
    
    coo_required: Optional[bool] = None
    coo_type: Optional[str] = None
    coo_status: Optional[str] = None
    coo_notes: Optional[str] = None
    
    inspection_required: Optional[bool] = None
    inspection_body: Optional[str] = None
    inspection_status: Optional[str] = None
    inspection_report_no: Optional[str] = None
    inspection_notes: Optional[str] = None
    
    import_permit_required: Optional[bool] = None
    permit_issuing_authority: Optional[str] = None
    permit_number: Optional[str] = None
    permit_status: Optional[str] = None
    permit_notes: Optional[str] = None
    
    msds_required: Optional[bool] = None
    msds_status: Optional[str] = None
    msds_notes: Optional[str] = None
    
    halal_cert_required: Optional[bool] = None
    halal_cert_status: Optional[str] = None
    halal_cert_notes: Optional[str] = None
    
    coa_required: Optional[bool] = None
    coa_status: Optional[str] = None
    coa_notes: Optional[str] = None
    
    hs_code_items: Optional[List[Dict[str, Any]]] = None
    other_requirements: Optional[List[Dict[str, Any]]] = None
    acid_number: Optional[str] = None
    consultation_id: Optional[int] = None
    consultation_code: Optional[str] = None
    confirmation_status: Optional[str] = None
    is_post_acid_confirmed: Optional[bool] = None
    confirmed_at: Optional[datetime] = None
    confirmed_by: Optional[str] = None
    sailing_status: Optional[str] = None
    sailing_date: Optional[str] = None

    # CargoX & Pre-ACID
    cargox_verified: Optional[bool] = None
    cargox_status: Optional[str] = None
    ready_for_acid: Optional[bool] = None
    triple_match_status: Optional[str] = None

    # Commodity Group
    commodity_group_matched: Optional[bool] = None
    import_card_group_code: Optional[str] = None

    # Adaptive Shelf-Life & Labeling
    is_shelflife_applicable: Optional[bool] = None
    shelf_life_total_days: Optional[int] = None
    shelf_life_remaining_percent: Optional[float] = None
    artwork_arabic_approved: Optional[bool] = None
    labeling_notes: Optional[str] = None

    # Testing & Physical Sampling
    sampling_required: Optional[bool] = None
    lab_type: Optional[str] = None
    detention_allowed: Optional[bool] = None
    estimated_lab_fees: Optional[float] = None

    # Special Logistics: Cold Chain & Hazmat
    cold_chain_required: Optional[bool] = None
    target_temperature: Optional[str] = None
    data_logger_verified: Optional[bool] = None
    is_hazmat: Optional[bool] = None
    imo_class: Optional[str] = None

    # Governance: Maker-Checker & Overrides
    checker_user_id: Optional[int] = None
    checker_approved: Optional[bool] = None
    checker_notes: Optional[str] = None
    is_overridden: Optional[bool] = None
    override_reason: Optional[str] = None

    overall_status: Optional[str] = None
    risk_level: Optional[str] = None
    assessed_by: Optional[str] = None
    assessment_notes: Optional[str] = None


class ImportRequirementPrefillResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    importer_name: Optional[str] = None
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    country_of_origin: Optional[str] = None
    foreign_exporter_id: Optional[str] = None
    currency: Optional[str] = None
    shipment_value: Optional[float] = None
    po_number: Optional[str] = None
    pi_number: Optional[str] = None
    acid_number: Optional[str] = None
    hs_code: Optional[str] = None
    commodity_description: Optional[str] = None
    
    # Linked HS Code breakdown
    hs_code_items: List[ImportRequirementHSCodeItem] = []

    # Linked Consultation Session Details
    consultation_id: Optional[int] = None
    consultation_code: Optional[str] = None
    broker_name: Optional[str] = None
    consultation_status: Optional[str] = None
    readiness_percentage: float = 0.0
    
    # 5 Pillars Extracted from Consultation & Tariff
    decree_43_applicable: bool = False
    white_list_required: bool = False
    white_list_verified: bool = False
    factory_registration_no: Optional[str] = None
    
    coo_required: bool = False
    coo_type: Optional[str] = None
    coo_status: str = "Not Required"
    coo_notes: Optional[str] = None
    
    inspection_required: bool = False
    inspection_body: Optional[str] = None
    inspection_status: str = "Not Required"
    inspection_notes: Optional[str] = None
    
    import_permit_required: bool = False
    permit_issuing_authority: Optional[str] = None
    permit_status: str = "Not Required"
    permit_notes: Optional[str] = None
    
    msds_required: bool = False
    msds_status: str = "Not Required"
    halal_cert_required: bool = False
    halal_cert_status: str = "Not Required"
    coa_required: bool = False
    coa_status: str = "Not Required"
    special_notes: Optional[str] = None

    # CargoX & Pre-ACID Readiness
    cargox_verified: bool = False
    cargox_status: str = "Not Verified"
    ready_for_acid: bool = False
    triple_match_status: str = "Pending"

    # Commodity Group Match
    commodity_group_matched: bool = True
    import_card_group_code: Optional[str] = None

    # Adaptive Shelf-Life & Labeling
    is_shelflife_applicable: bool = False
    shelf_life_total_days: Optional[int] = None
    shelf_life_remaining_percent: Optional[float] = None
    artwork_arabic_approved: Optional[bool] = None
    labeling_notes: Optional[str] = None

    # Testing & Physical Sampling
    sampling_required: bool = False
    lab_type: Optional[str] = None
    detention_allowed: bool = False
    estimated_lab_fees: float = 0.0

    # Special Logistics: Cold Chain & Hazmat
    cold_chain_required: bool = False
    target_temperature: Optional[str] = None
    data_logger_verified: bool = False
    is_hazmat: bool = False
    imo_class: Optional[str] = None

    # Governance: Maker-Checker & Overrides
    checker_user_id: Optional[int] = None
    checker_approved: bool = False
    checker_notes: Optional[str] = None
    is_overridden: bool = False
    override_reason: Optional[str] = None

    # System messages
    messages: List[SystemMessageItem] = []


class ImportRequirementResponse(ImportRequirementBase):
    model_config = ConfigDict(from_attributes=True)
    
    assessment_id: int
    assessment_code: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: str
    updated_by: str
