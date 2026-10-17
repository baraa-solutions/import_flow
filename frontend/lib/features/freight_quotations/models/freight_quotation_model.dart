class FreightQuotationItemModel {
  final int? quotationId;
  final int? rfqId;
  final int providerId;
  final String providerName;
  final String? vesselName;
  final String? voyageNumber;
  final String? currencyCode;
  final double oceanFreightCost;
  final double localChargesCost;
  final double inlandCost;
  final double totalCost;
  final String sailingDate;
  final String estimatedArrivalDate;
  final int transitDays;
  final int freeDaysAtPod;
  final bool isAwarded;
  final bool isExcludedFromAvg;
  final String? remarks;

  FreightQuotationItemModel({
    this.quotationId,
    this.rfqId,
    required this.providerId,
    required this.providerName,
    this.vesselName,
    this.voyageNumber,
    this.currencyCode,
    required this.oceanFreightCost,
    this.localChargesCost = 0.0,
    this.inlandCost = 0.0,
    required this.totalCost,
    required this.sailingDate,
    required this.estimatedArrivalDate,
    this.transitDays = 0,
    this.freeDaysAtPod = 14,
    this.isAwarded = false,
    this.isExcludedFromAvg = false,
    this.remarks,
  });

  factory FreightQuotationItemModel.fromJson(Map<String, dynamic> json) {
    return FreightQuotationItemModel(
      quotationId: json['quotation_id'],
      rfqId: json['rfq_id'],
      providerId: json['provider_id'],
      providerName: json['provider_name'] ?? '',
      vesselName: json['vessel_name'],
      voyageNumber: json['voyage_number'],
      currencyCode: json['currency_code'] as String?,
      oceanFreightCost: (json['ocean_freight_cost'] as num?)?.toDouble() ?? 0.0,
      localChargesCost: (json['local_charges_cost'] as num?)?.toDouble() ?? 0.0,
      inlandCost: (json['inland_cost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      sailingDate: json['sailing_date'] ?? '',
      estimatedArrivalDate: json['estimated_arrival_date'] ?? '',
      transitDays: json['transit_days'] ?? 0,
      freeDaysAtPod: json['free_days_at_pod'] ?? 14,
      isAwarded: json['is_awarded'] ?? false,
      isExcludedFromAvg: json['is_excluded_from_avg'] ?? false,
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (quotationId != null) 'quotation_id': quotationId,
      if (rfqId != null) 'rfq_id': rfqId,
      'provider_id': providerId,
      'provider_name': providerName,
      'vessel_name': vesselName,
      'voyage_number': voyageNumber,
      'currency_code': currencyCode,
      'ocean_freight_cost': oceanFreightCost,
      'local_charges_cost': localChargesCost,
      'inland_cost': inlandCost,
      'total_cost': totalCost,
      'sailing_date': sailingDate,
      'estimated_arrival_date': estimatedArrivalDate,
      'transit_days': transitDays,
      'free_days_at_pod': freeDaysAtPod,
      'is_awarded': isAwarded,
      'is_excluded_from_avg': isExcludedFromAvg,
      'remarks': remarks,
    };
  }

  FreightQuotationItemModel copyWith({
    int? quotationId,
    int? rfqId,
    int? providerId,
    String? providerName,
    String? vesselName,
    String? voyageNumber,
    String? currencyCode,
    double? oceanFreightCost,
    double? localChargesCost,
    double? inlandCost,
    double? totalCost,
    String? sailingDate,
    String? estimatedArrivalDate,
    int? transitDays,
    int? freeDaysAtPod,
    bool? isAwarded,
    bool? isExcludedFromAvg,
    String? remarks,
  }) {
    return FreightQuotationItemModel(
      quotationId: quotationId ?? this.quotationId,
      rfqId: rfqId ?? this.rfqId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      vesselName: vesselName ?? this.vesselName,
      voyageNumber: voyageNumber ?? this.voyageNumber,
      currencyCode: currencyCode ?? this.currencyCode,
      oceanFreightCost: oceanFreightCost ?? this.oceanFreightCost,
      localChargesCost: localChargesCost ?? this.localChargesCost,
      inlandCost: inlandCost ?? this.inlandCost,
      totalCost: totalCost ?? this.totalCost,
      sailingDate: sailingDate ?? this.sailingDate,
      estimatedArrivalDate: estimatedArrivalDate ?? this.estimatedArrivalDate,
      transitDays: transitDays ?? this.transitDays,
      freeDaysAtPod: freeDaysAtPod ?? this.freeDaysAtPod,
      isAwarded: isAwarded ?? this.isAwarded,
      isExcludedFromAvg: isExcludedFromAvg ?? this.isExcludedFromAvg,
      remarks: remarks ?? this.remarks,
    );
  }
}

class FreightRFQRequestModel {
  final int rfqId;
  final String rfqCode;
  final String title;
  final int? importFileId;
  final String shippingMethod;
  final String crdDate;
  final int? polId;
  final String polName;
  final int? podId;
  final String podName;
  final int? poId;
  final int? projectId;
  final double totalCbm;
  final double totalGrossWeightKg;
  final double chargeableWeightKg;
  final String status;
  final int? selectedQuotationId;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;
  final List<FreightQuotationItemModel> quotations;
  final int totalQuotationsCount;
  final double lowestFreightCost;
  final double averageFreightCost;
  final int fastestTransitDays;
  final double averageTransitDays;
  final String? awardedProviderName;

  FreightRFQRequestModel({
    required this.rfqId,
    required this.rfqCode,
    required this.title,
    this.importFileId,
    required this.shippingMethod,
    required this.crdDate,
    this.polId,
    required this.polName,
    this.podId,
    required this.podName,
    this.poId,
    this.projectId,
    this.totalCbm = 0.0,
    this.totalGrossWeightKg = 0.0,
    this.chargeableWeightKg = 0.0,
    required this.status,
    this.selectedQuotationId,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
    this.quotations = const [],
    this.totalQuotationsCount = 0,
    this.lowestFreightCost = 0.0,
    this.averageFreightCost = 0.0,
    this.fastestTransitDays = 0,
    this.averageTransitDays = 0.0,
    this.awardedProviderName,
  });

  factory FreightRFQRequestModel.fromJson(Map<String, dynamic> json) {
    return FreightRFQRequestModel(
      rfqId: json['rfq_id'],
      rfqCode: json['rfq_code'] ?? '',
      title: json['title'] ?? '',
      importFileId: json['import_file_id'],
      shippingMethod: json['shipping_method'] ?? 'Ocean FCL',
      crdDate: json['crd_date'] ?? '',
      polId: json['pol_id'],
      polName: json['pol_name'] ?? '',
      podId: json['pod_id'],
      podName: json['pod_name'] ?? '',
      poId: json['po_id'],
      projectId: json['project_id'],
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      totalGrossWeightKg: (json['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      chargeableWeightKg: (json['chargeable_weight_kg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Draft',
      selectedQuotationId: json['selected_quotation_id'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
      quotations: (json['quotations'] as List<dynamic>?)
              ?.map((q) => FreightQuotationItemModel.fromJson(q))
              .toList() ??
          [],
      totalQuotationsCount: json['total_quotations_count'] ?? 0,
      lowestFreightCost: (json['lowest_freight_cost'] as num?)?.toDouble() ?? 0.0,
      averageFreightCost: (json['average_freight_cost'] as num?)?.toDouble() ?? 0.0,
      fastestTransitDays: json['fastest_transit_days'] ?? 0,
      averageTransitDays: (json['average_transit_days'] as num?)?.toDouble() ?? 0.0,
      awardedProviderName: json['awarded_provider_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rfq_id': rfqId,
      'rfq_code': rfqCode,
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'shipping_method': shippingMethod,
      'crd_date': crdDate,
      'pol_id': polId,
      'pol_name': polName,
      'pod_id': podId,
      'pod_name': podName,
      'po_id': poId,
      'project_id': projectId,
      'total_cbm': totalCbm,
      'total_gross_weight_kg': totalGrossWeightKg,
      'chargeable_weight_kg': chargeableWeightKg,
      'status': status,
      'selected_quotation_id': selectedQuotationId,
      'notes': notes,
      'is_active': isActive,
      'quotations': quotations.map((q) => q.toJson()).toList(),
    };
  }
}
