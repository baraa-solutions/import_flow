"""
Customs Tariff Service Coordinator / Facade (modules/customs_tariff/service.py)

Decomposed into focused domain-specific sub-services:
- tariff_search_service: HS code lookup, chapter/heading filtering, fuzzy text search, smart parser integration, tariff CRUD
- tariff_calculation_service: Customs duty, VAT, schedule tax, dev fee calculations, fee codes, CIF/insurance/freight resolution
- tariff_agreements_service: Trade agreements, preferential exemptions, historical tariff version tracking and diffs

Maintains 100% backward compatibility for all routers, modules, and tests importing from modules.customs_tariff.service.
"""
from . import repository
from .model import CustomsTariff, PreferentialAgreement
from .schemas import (
    CustomsDutyBreakdown,
    CustomsDutyEstimateRequest,
    CustomsTariffCreate,
    CustomsTariffResponse,
    CustomsTariffUpdate,
    FeeCodeCreate,
    FeeCodeResponse,
    ImportFileCustomsSimulationRequest,
    ImportFileCustomsSimulationResponse,
    MultiItemCustomsBreakdown,
    MultiItemCustomsEstimateLine,
    MultiItemCustomsEstimateRequest,
    MultiItemCustomsLineBreakdown,
    OriginDutyCheckRequest,
    OriginDutyCheckResponse,
    PreferentialAgreementCreate,
    PreferentialAgreementResponse,
    SmartTariffParseRequest,
    SmartTariffParseResponse,
    TariffAgreementBulkSaveRequest,
    TariffDiffItem,
    TariffVerificationRequest,
    TariffVersionComparisonResponse,
    normalize_customs_category,
)
from .tariff_agreements_service import (
    EXEMPTIONS_REGISTRY,
    _agreement_duty_rate,
    _resolve_origin_iso2,
    apply_exemption,
    compare_tariff_versions_service,
    create_preferential_agreement_service,
    evaluate_duty_by_origin_and_document_service,
    get_agreements_by_hs_code_service,
    get_tariff_version_history_service,
    save_tariff_with_agreements_service,
)
from .tariff_calculation_service import (
    _allocate,
    _customs_rate,
    _parse_decimal,
    _round,
    calc_collection_fees,
    estimate_customs_duty_service,
    estimate_multi_item_customs_duty_service,
    resolve_insurance_freight,
    simulate_import_file_customs_duty_service,
)
from .tariff_search_service import (
    bulk_import_tariffs_service,
    create_fee_code_service,
    create_tariff_service,
    customs_category_search_values,
    delete_tariff_service,
    get_all_fee_codes_service,
    get_all_tariffs_service,
    get_tariff_by_hs_code_service,
    get_tariff_by_id_service,
    parse_smart_nafeza_tariff_text_service,
    restore_tariff_service,
    update_tariff_service,
    verify_and_update_tariff_service,
)

__all__ = [
    # Sub-service modules
    "repository",
    # Search & Tariff Master CRUD
    "create_tariff_service",
    "get_all_tariffs_service",
    "customs_category_search_values",
    "get_tariff_by_id_service",
    "get_tariff_by_hs_code_service",
    "update_tariff_service",
    "delete_tariff_service",
    "restore_tariff_service",
    "verify_and_update_tariff_service",
    "bulk_import_tariffs_service",
    "get_all_fee_codes_service",
    "create_fee_code_service",
    "parse_smart_nafeza_tariff_text_service",
    # Calculation & Simulation Engine
    "_round",
    "_parse_decimal",
    "_allocate",
    "resolve_insurance_freight",
    "calc_collection_fees",
    "_customs_rate",
    "estimate_customs_duty_service",
    "estimate_multi_item_customs_duty_service",
    "simulate_import_file_customs_duty_service",
    # Agreements & Exemptions & History
    "_agreement_duty_rate",
    "create_preferential_agreement_service",
    "get_agreements_by_hs_code_service",
    "EXEMPTIONS_REGISTRY",
    "apply_exemption",
    "compare_tariff_versions_service",
    "save_tariff_with_agreements_service",
    "get_tariff_version_history_service",
    "evaluate_duty_by_origin_and_document_service",
    "_resolve_origin_iso2",
    # Models & Schemas
    "CustomsTariff",
    "PreferentialAgreement",
    "CustomsDutyBreakdown",
    "CustomsDutyEstimateRequest",
    "CustomsTariffCreate",
    "CustomsTariffResponse",
    "CustomsTariffUpdate",
    "FeeCodeCreate",
    "FeeCodeResponse",
    "ImportFileCustomsSimulationRequest",
    "ImportFileCustomsSimulationResponse",
    "MultiItemCustomsBreakdown",
    "MultiItemCustomsEstimateLine",
    "MultiItemCustomsEstimateRequest",
    "MultiItemCustomsLineBreakdown",
    "OriginDutyCheckRequest",
    "OriginDutyCheckResponse",
    "PreferentialAgreementCreate",
    "PreferentialAgreementResponse",
    "SmartTariffParseRequest",
    "SmartTariffParseResponse",
    "TariffAgreementBulkSaveRequest",
    "TariffDiffItem",
    "TariffVerificationRequest",
    "TariffVersionComparisonResponse",
    "normalize_customs_category",
]
