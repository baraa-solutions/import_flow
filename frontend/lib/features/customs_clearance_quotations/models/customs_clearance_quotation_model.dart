class CustomsClearanceQuotationItemModel {
  final int? quotationId;
  final int? rfqId;
  final int providerId;
  final String providerName;
  final String? licenseNumber;
  final double clearanceFee;
  final double inlandTransportFee;
  final double inspectionFee;
  final double portExpenses;
  final double miscellaneousFee;
  final double totalCost;
  final String currency;
  final int estimatedTurnaroundDays;
  final String? validityDate;
  final bool isAwarded;
  final String? remarks;
  final bool isActive;
  final String? createdAt;

  CustomsClearanceQuotationItemModel({
    this.quotationId,
    this.rfqId,
    required this.providerId,
    required this.providerName,
    this.licenseNumber,
    this.clearanceFee = 0.0,
    this.inlandTransportFee = 0.0,
    this.inspectionFee = 0.0,
    this.portExpenses = 0.0,
    this.miscellaneousFee = 0.0,
    required this.totalCost,
    this.currency = 'EGP',
    this.estimatedTurnaroundDays = 3,
    this.validityDate,
    this.isAwarded = false,
    this.remarks,
    this.isActive = true,
    this.createdAt,
  });

  factory CustomsClearanceQuotationItemModel.fromJson(Map<String, dynamic> json) {
    return CustomsClearanceQuotationItemModel(
      quotationId: json['quotation_id'],
      rfqId: json['rfq_id'],
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? '',
      licenseNumber: json['license_number'],
      clearanceFee: (json['clearance_fee'] as num?)?.toDouble() ?? 0.0,
      inlandTransportFee: (json['inland_transport_fee'] as num?)?.toDouble() ?? 0.0,
      inspectionFee: (json['inspection_fee'] as num?)?.toDouble() ?? 0.0,
      portExpenses: (json['port_expenses'] as num?)?.toDouble() ?? 0.0,
      miscellaneousFee: (json['miscellaneous_fee'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      estimatedTurnaroundDays: json['estimated_turnaround_days'] ?? 3,
      validityDate: json['validity_date'],
      isAwarded: json['is_awarded'] ?? false,
      remarks: json['remarks'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'provider_name': providerName,
      if (licenseNumber != null) 'license_number': licenseNumber,
      'clearance_fee': clearanceFee,
      'inland_transport_fee': inlandTransportFee,
      'inspection_fee': inspectionFee,
      'port_expenses': portExpenses,
      'miscellaneous_fee': miscellaneousFee,
      'total_cost': totalCost,
      'currency': currency,
      'estimated_turnaround_days': estimatedTurnaroundDays,
      if (validityDate != null) 'validity_date': validityDate,
      if (remarks != null) 'remarks': remarks,
    };
  }
}


class CustomsClearanceRFQModel {
  final int rfqId;
  final String rfqCode;
  final String title;
  final int? portId;
  final String portName;
  final int? importFileId;
  final int? projectId;
  final String? commodityDescription;
  final String? hsCode;
  final String shipmentType;
  final int containersCount;
  final int packagesCount;
  final double grossWeightKg;
  final double cbm;
  final String status;
  final double lowestClearanceCost;
  final int fastestTurnaroundDays;
  final int? awardedProviderId;
  final String? awardedProviderName;
  final int? awardedQuotationId;
  final String? awardedAt;
  final bool isActive;
  final String createdAt;
  final List<CustomsClearanceQuotationItemModel> quotations;

  CustomsClearanceRFQModel({
    required this.rfqId,
    required this.rfqCode,
    required this.title,
    this.portId,
    required this.portName,
    this.importFileId,
    this.projectId,
    this.commodityDescription,
    this.hsCode,
    required this.shipmentType,
    required this.containersCount,
    required this.packagesCount,
    required this.grossWeightKg,
    required this.cbm,
    required this.status,
    required this.lowestClearanceCost,
    required this.fastestTurnaroundDays,
    this.awardedProviderId,
    this.awardedProviderName,
    this.awardedQuotationId,
    this.awardedAt,
    this.isActive = true,
    required this.createdAt,
    this.quotations = const [],
  });

  factory CustomsClearanceRFQModel.fromJson(Map<String, dynamic> json) {
    return CustomsClearanceRFQModel(
      rfqId: json['rfq_id'] ?? 0,
      rfqCode: json['rfq_code'] ?? '',
      title: json['title'] ?? '',
      portId: json['port_id'],
      portName: json['port_name'] ?? '',
      importFileId: json['import_file_id'],
      projectId: json['project_id'],
      commodityDescription: json['commodity_description'],
      hsCode: json['hs_code'],
      shipmentType: json['shipment_type'] ?? 'Ocean FCL (40HQ)',
      containersCount: json['containers_count'] ?? 1,
      packagesCount: json['packages_count'] ?? 0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      cbm: (json['cbm'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Draft',
      lowestClearanceCost: (json['lowest_clearance_cost'] as num?)?.toDouble() ?? 0.0,
      fastestTurnaroundDays: json['fastest_turnaround_days'] ?? 0,
      awardedProviderId: json['awarded_provider_id'],
      awardedProviderName: json['awarded_provider_name'],
      awardedQuotationId: json['awarded_quotation_id'],
      awardedAt: json['awarded_at'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      quotations: (json['quotations'] as List<dynamic>?)
              ?.map((q) => CustomsClearanceQuotationItemModel.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      if (portId != null) 'port_id': portId,
      'port_name': portName,
      if (importFileId != null) 'import_file_id': importFileId,
      if (projectId != null) 'project_id': projectId,
      if (commodityDescription != null) 'commodity_description': commodityDescription,
      if (hsCode != null) 'hs_code': hsCode,
      'shipment_type': shipmentType,
      'containers_count': containersCount,
      'packages_count': packagesCount,
      'gross_weight_kg': grossWeightKg,
      'cbm': cbm,
      'quotations': quotations.map((q) => q.toJson()).toList(),
    };
  }
}


class ClearancePriceListItemModel {
  final int priceItemId;
  final int providerId;
  final String providerName;
  final String portName;
  final String serviceCategory;
  final String containerType;
  final double unitPrice;
  final String currency;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String? notes;
  final bool isActive;
  final String? createdAt;

  ClearancePriceListItemModel({
    required this.priceItemId,
    required this.providerId,
    required this.providerName,
    required this.portName,
    required this.serviceCategory,
    required this.containerType,
    required this.unitPrice,
    this.currency = 'EGP',
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  factory ClearancePriceListItemModel.fromJson(Map<String, dynamic> json) {
    return ClearancePriceListItemModel(
      priceItemId: json['price_item_id'] ?? 0,
      providerId: json['provider_id'] ?? 0,
      providerName: json['provider_name'] ?? '',
      portName: json['port_name'] ?? '',
      serviceCategory: json['service_category'] ?? 'CLEARANCE_FEE',
      containerType: json['container_type'] ?? '40HQ',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      effectiveFrom: json['effective_from'],
      effectiveTo: json['effective_to'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'provider_id': providerId,
      'provider_name': providerName,
      'port_name': portName,
      'service_category': serviceCategory,
      'container_type': containerType,
      'unit_price': unitPrice,
      'currency': currency,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (effectiveTo != null) 'effective_to': effectiveTo,
      if (notes != null) 'notes': notes,
    };
  }
}
