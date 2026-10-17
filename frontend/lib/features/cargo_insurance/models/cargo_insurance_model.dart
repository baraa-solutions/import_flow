class CargoInsuranceModel {
  final int certificateId;
  final String certificateCode;
  final String? policyNumber;
  final String policyType; // SPECIFIC, OPEN_DECLARATION
  final int? importFileId;
  final int? insuranceCompanyId;
  final String? insuranceCompanyName;
  final String insuredEntityName;

  final String transportMode; // OCEAN, AIR, ROAD
  final String? carrierName;
  final String? vesselOrFlightNo;
  final String? voyageNumber;
  final String? trackingReference;
  final String portOfLoading;
  final String portOfDischarge;
  final String? finalDestination;

  final String currency;
  final double exchangeRate;
  final double invoiceValue;
  final double freightCost;
  final double otherLogisticsCosts;
  final double cifValue;
  final double markupPercentage;
  final double insuredValue;

  final String coverageClause; // ICC_A, AIR_ALL_RISKS, ICC_B, ICC_C
  final bool includeWarAndStrikes;
  final double baseRate;
  final double warRate;

  final double basePremium;
  final double warStrikesPremium;
  final double minimumPremium;
  final double netPremium;
  final double issuanceFee;
  final double taxRate;
  final double taxAmount;
  final double totalPayablePremium;

  final String? goodsDescription;
  final int? packageCount;
  final String? packageType;
  final double? grossWeightKg;
  final String? surveyAgentInDestination;
  final String? claimsPayableAt;

  final String status; // DRAFT, ISSUED, CANCELLED, CLAIMED
  final String? issuedAt;
  final String? remarks;
  final String createdAt;
  final String updatedAt;
  final String createdBy;
  final String updatedBy;
  final bool isActive;

  CargoInsuranceModel({
    required this.certificateId,
    required this.certificateCode,
    this.policyNumber,
    this.policyType = 'SPECIFIC',
    this.importFileId,
    this.insuranceCompanyId,
    this.insuranceCompanyName,
    required this.insuredEntityName,
    this.transportMode = 'OCEAN',
    this.carrierName,
    this.vesselOrFlightNo,
    this.voyageNumber,
    this.trackingReference,
    required this.portOfLoading,
    required this.portOfDischarge,
    this.finalDestination,
    this.currency = 'USD',
    this.exchangeRate = 1.0,
    this.invoiceValue = 0.0,
    this.freightCost = 0.0,
    this.otherLogisticsCosts = 0.0,
    this.cifValue = 0.0,
    this.markupPercentage = 0.0,
    this.insuredValue = 0.0,
    this.coverageClause = 'ICC_A',
    this.includeWarAndStrikes = true,
    this.baseRate = 0.0,
    this.warRate = 0.0,
    this.basePremium = 0.0,
    this.warStrikesPremium = 0.0,
    this.minimumPremium = 0.0,
    this.netPremium = 0.0,
    this.issuanceFee = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.totalPayablePremium = 0.0,
    this.goodsDescription,
    this.packageCount,
    this.packageType,
    this.grossWeightKg,
    this.surveyAgentInDestination,
    this.claimsPayableAt,
    this.status = 'DRAFT',
    this.issuedAt,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = 'system',
    this.updatedBy = 'system',
    this.isActive = true,
  });

  factory CargoInsuranceModel.fromJson(Map<String, dynamic> json) {
    return CargoInsuranceModel(
      certificateId: json['certificate_id'] ?? 0,
      certificateCode: json['certificate_code'] ?? '',
      policyNumber: json['policy_number'],
      policyType: json['policy_type'] ?? 'SPECIFIC',
      importFileId: json['import_file_id'],
      insuranceCompanyId: json['insurance_company_id'],
      insuranceCompanyName: json['insurance_company_name'],
      insuredEntityName: json['insured_entity_name'] ?? '',
      transportMode: json['transport_mode'] ?? 'OCEAN',
      carrierName: json['carrier_name'],
      vesselOrFlightNo: json['vessel_or_flight_no'],
      voyageNumber: json['voyage_number'],
      trackingReference: json['tracking_reference'],
      portOfLoading: json['port_of_loading'] ?? '',
      portOfDischarge: json['port_of_discharge'] ?? '',
      finalDestination: json['final_destination'],
      currency: json['currency'] ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      invoiceValue: (json['invoice_value'] as num?)?.toDouble() ?? 0.0,
      freightCost: (json['freight_cost'] as num?)?.toDouble() ?? 0.0,
      otherLogisticsCosts: (json['other_logistics_costs'] as num?)?.toDouble() ?? 0.0,
      cifValue: (json['cif_value'] as num?)?.toDouble() ?? 0.0,
      markupPercentage: (json['markup_percentage'] as num?)?.toDouble() ?? 0.0,
      insuredValue: (json['insured_value'] as num?)?.toDouble() ?? 0.0,
      coverageClause: json['coverage_clause'] ?? 'ICC_A',
      includeWarAndStrikes: json['include_war_and_strikes'] ?? true,
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0.0,
      warRate: (json['war_rate'] as num?)?.toDouble() ?? 0.0,
      basePremium: (json['base_premium'] as num?)?.toDouble() ?? 0.0,
      warStrikesPremium: (json['war_strikes_premium'] as num?)?.toDouble() ?? 0.0,
      minimumPremium: (json['minimum_premium'] as num?)?.toDouble() ?? 0.0,
      netPremium: (json['net_premium'] as num?)?.toDouble() ?? 0.0,
      issuanceFee: (json['issuance_fee'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalPayablePremium: (json['total_payable_premium'] as num?)?.toDouble() ?? 0.0,
      goodsDescription: json['goods_description'],
      packageCount: json['package_count'],
      packageType: json['package_type'],
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble(),
      surveyAgentInDestination: json['survey_agent_in_destination'],
      claimsPayableAt: json['claims_payable_at'],
      status: json['status'] ?? 'DRAFT',
      issuedAt: json['issued_at'],
      remarks: json['remarks'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      createdBy: json['created_by'] ?? 'system',
      updatedBy: json['updated_by'] ?? 'system',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificate_id': certificateId,
      'certificate_code': certificateCode,
      'policy_number': policyNumber,
      'policy_type': policyType,
      'import_file_id': importFileId,
      'insurance_company_id': insuranceCompanyId,
      'insurance_company_name': insuranceCompanyName,
      'insured_entity_name': insuredEntityName,
      'transport_mode': transportMode,
      'carrier_name': carrierName,
      'vessel_or_flight_no': vesselOrFlightNo,
      'voyage_number': voyageNumber,
      'tracking_reference': trackingReference,
      'port_of_loading': portOfLoading,
      'port_of_discharge': portOfDischarge,
      'final_destination': finalDestination,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'invoice_value': invoiceValue,
      'freight_cost': freightCost,
      'other_logistics_costs': otherLogisticsCosts,
      'cif_value': cifValue,
      'markup_percentage': markupPercentage,
      'insured_value': insuredValue,
      'coverage_clause': coverageClause,
      'include_war_and_strikes': includeWarAndStrikes,
      'base_rate': baseRate,
      'war_rate': warRate,
      'base_premium': basePremium,
      'war_strikes_premium': warStrikesPremium,
      'minimum_premium': minimumPremium,
      'net_premium': netPremium,
      'issuance_fee': issuanceFee,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total_payable_premium': totalPayablePremium,
      'goods_description': goodsDescription,
      'package_count': packageCount,
      'package_type': packageType,
      'gross_weight_kg': grossWeightKg,
      'survey_agent_in_destination': surveyAgentInDestination,
      'claims_payable_at': claimsPayableAt,
      'status': status,
      'issued_at': issuedAt,
      'remarks': remarks,
    };
  }
}

class InsuranceCalculationResultModel {
  final double cifValue;
  final double markupPercentage;
  final double insuredValue;
  final String coverageClause;
  final double baseRate;
  final double basePremium;
  final double warRate;
  final double warStrikesPremium;
  final double netPremium;
  final double issuanceFee;
  final double taxRate;
  final double taxAmount;
  final double totalPayablePremium;
  final String currency;

  InsuranceCalculationResultModel({
    required this.cifValue,
    required this.markupPercentage,
    required this.insuredValue,
    required this.coverageClause,
    required this.baseRate,
    required this.basePremium,
    required this.warRate,
    required this.warStrikesPremium,
    required this.netPremium,
    required this.issuanceFee,
    required this.taxRate,
    required this.taxAmount,
    required this.totalPayablePremium,
    required this.currency,
  });

  factory InsuranceCalculationResultModel.fromJson(Map<String, dynamic> json) {
    return InsuranceCalculationResultModel(
      cifValue: (json['cif_value'] as num?)?.toDouble() ?? 0.0,
      markupPercentage: (json['markup_percentage'] as num?)?.toDouble() ?? 0.0,
      insuredValue: (json['insured_value'] as num?)?.toDouble() ?? 0.0,
      coverageClause: json['coverage_clause'] ?? 'ICC_A',
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 0.0,
      basePremium: (json['base_premium'] as num?)?.toDouble() ?? 0.0,
      warRate: (json['war_rate'] as num?)?.toDouble() ?? 0.0,
      warStrikesPremium: (json['war_strikes_premium'] as num?)?.toDouble() ?? 0.0,
      netPremium: (json['net_premium'] as num?)?.toDouble() ?? 0.0,
      issuanceFee: (json['issuance_fee'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalPayablePremium: (json['total_payable_premium'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
    );
  }
}
