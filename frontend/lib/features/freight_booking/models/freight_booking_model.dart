class SingleContainerItemModel {
  String containerNumber;
  String sealNumber;
  double vgmWeightKg;

  SingleContainerItemModel({
    this.containerNumber = '',
    this.sealNumber = '',
    this.vgmWeightKg = 0.0,
  });

  factory SingleContainerItemModel.fromJson(Map<String, dynamic> json) {
    return SingleContainerItemModel(
      containerNumber: json['container_number'] ?? '',
      sealNumber: json['seal_number'] ?? '',
      vgmWeightKg: (json['vgm_weight_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'container_number': containerNumber,
      'seal_number': sealNumber,
      'vgm_weight_kg': vgmWeightKg,
    };
  }
}

class ContainerAllocationModel {
  final String containerType;
  final int quantity;
  final List<String> containerNumbers;
  final List<String> sealNumbers;
  final double vgmWeightKg;
  final List<SingleContainerItemModel> individualContainers;

  ContainerAllocationModel({
    required this.containerType,
    this.quantity = 1,
    this.containerNumbers = const [],
    this.sealNumbers = const [],
    this.vgmWeightKg = 0.0,
    List<SingleContainerItemModel>? individualContainers,
  }) : individualContainers = individualContainers ?? _buildInitialContainers(quantity, containerNumbers, sealNumbers, vgmWeightKg);

  static List<SingleContainerItemModel> _buildInitialContainers(int qty, List<String> cNos, List<String> sNos, double vgm) {
    final List<SingleContainerItemModel> list = [];
    for (int i = 0; i < qty; i++) {
      list.add(SingleContainerItemModel(
        containerNumber: i < cNos.length ? cNos[i] : '',
        sealNumber: i < sNos.length ? sNos[i] : '',
        vgmWeightKg: vgm > 0 ? (vgm / (qty > 0 ? qty : 1)) : 0.0,
      ));
    }
    return list;
  }

  factory ContainerAllocationModel.fromJson(Map<String, dynamic> json) {
    var rawCNo = json['container_numbers'] as List<dynamic>? ?? [];
    var rawSNo = json['seal_numbers'] as List<dynamic>? ?? [];
    var rawIndiv = json['individual_containers'] as List<dynamic>? ?? [];
    final cNos = rawCNo.map((e) => e.toString()).toList();
    final sNos = rawSNo.map((e) => e.toString()).toList();
    final int qty = json['quantity'] ?? 1;
    final double vgm = (json['vgm_weight_kg'] as num?)?.toDouble() ?? 0.0;

    List<SingleContainerItemModel> indivList = [];
    if (rawIndiv.isNotEmpty) {
      indivList = rawIndiv.map((c) => SingleContainerItemModel.fromJson(c)).toList();
    } else {
      indivList = _buildInitialContainers(qty, cNos, sNos, vgm);
    }

    return ContainerAllocationModel(
      containerType: json['container_type'] ?? '40HC',
      quantity: qty,
      containerNumbers: cNos,
      sealNumbers: sNos,
      vgmWeightKg: vgm,
      individualContainers: indivList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'container_type': containerType,
      'quantity': quantity,
      'container_numbers': individualContainers.map((c) => c.containerNumber).toList(),
      'seal_numbers': individualContainers.map((c) => c.sealNumber).toList(),
      'vgm_weight_kg': vgmWeightKg,
      'individual_containers': individualContainers.map((c) => c.toJson()).toList(),
    };
  }
}

class BookingChargeModel {
  final String chargeType;
  final String unit;
  final double quantity;
  final String? containerType;
  final String currency;
  final double rate;
  final double total;
  final double? fxRateToUsd;
  final double? amountUsd;
  final String? chargeCategory;

  BookingChargeModel({
    required this.chargeType,
    this.unit = 'Per Container',
    this.quantity = 1.0,
    this.containerType,
    this.currency = 'USD',
    this.rate = 0.0,
    this.total = 0.0,
    this.fxRateToUsd,
    this.amountUsd,
    this.chargeCategory,
  });

  factory BookingChargeModel.fromJson(Map<String, dynamic> json) {
    return BookingChargeModel(
      chargeType: json['charge_type'] ?? 'Sea Freight',
      unit: json['unit'] ?? 'Per Container',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      containerType: json['container_type'],
      currency: json['currency'] ?? 'USD',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      fxRateToUsd: (json['fx_rate_to_usd'] as num?)?.toDouble(),
      amountUsd: (json['amount_usd'] as num?)?.toDouble(),
      chargeCategory: json['charge_category'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'charge_type': chargeType,
      'unit': unit,
      'quantity': quantity,
      'currency': currency,
      'rate': rate,
      'total': total,
    };
    if (containerType != null) {
      map['container_type'] = containerType;
    }
    if (fxRateToUsd != null) {
      map['fx_rate_to_usd'] = fxRateToUsd;
    }
    if (amountUsd != null) {
      map['amount_usd'] = amountUsd;
    }
    if (chargeCategory != null) {
      map['charge_category'] = chargeCategory;
    }
    return map;
  }
}


class ShipmentBookingModel {
  final int bookingId;
  final String bookingCode;
  final String? bookingConfirmationNo;
  final String? billOfLadingNo;
  final int? importFileId;
  final int? rfqRequestId;
  final int? scenarioSessionId;
  final int? scenarioItemId;
  final String? scenarioProviderName;
  final int? freightForwarderId;
  final String? freightForwarderName;
  final int? shippingLineId;
  final String? shippingLineName;
  final String shipmentType;
  final int? polLocationId;
  final String? polName;
  final int? podLocationId;
  final String? podName;
  final String? bookingRequestDate;
  final String? bookingConfirmationDate;
  final String? etd;
  final String? eta;
  final String? atd;
  final int departureDelayDays;
  final int expectedWarehouseDays;
  final String? expectedWarehouseArrivalDate;
  final int transitTimeDays;
  final int freeDemurrageDays;
  final String? cargoCutoffDate;
  final String? siCutoffDate;
  final String? vesselName;
  final String? voyageNumber;
  final String? containerReleaseOrderNo;
  final String freightTerms;
  final String? containerMismatchReason;
  final List<ContainerAllocationModel> containersData;
  final List<BookingChargeModel> costChargesData;
  final Map<String, dynamic> quotationDetailsData;
  final double? totalFreightCostUsd;
  final double originalFreightCostUsd;
  final double costSavingsUsd;
  final double costVarianceUsd;
  final String? savingsNotes;
  final String status;
  final String owner;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;

  bool get hasSavings => costSavingsUsd > 0.0;
  bool get hasCostIncrease => costVarianceUsd < 0.0 && originalFreightCostUsd > 0.0;
  double get savingsPercent => originalFreightCostUsd > 0.0 ? (costSavingsUsd / originalFreightCostUsd) * 100.0 : 0.0;

  ShipmentBookingModel({
    required this.bookingId,
    required this.bookingCode,
    this.bookingConfirmationNo,
    this.billOfLadingNo,
    this.importFileId,
    this.rfqRequestId,
    this.scenarioSessionId,
    this.scenarioItemId,
    this.scenarioProviderName,
    this.freightForwarderId,
    this.freightForwarderName,
    this.shippingLineId,
    this.shippingLineName,
    this.shipmentType = 'Ocean FCL',
    this.polLocationId,
    this.polName,
    this.podLocationId,
    this.podName,
    this.bookingRequestDate,
    this.bookingConfirmationDate,
    this.etd,
    this.eta,
    this.atd,
    this.departureDelayDays = 0,
    this.expectedWarehouseDays = 7,
    this.expectedWarehouseArrivalDate,
    this.transitTimeDays = 0,
    this.freeDemurrageDays = 14,
    this.cargoCutoffDate,
    this.siCutoffDate,
    this.vesselName,
    this.voyageNumber,
    this.containerReleaseOrderNo,
    this.freightTerms = 'Collect',
    this.containerMismatchReason,
    this.containersData = const [],
    this.costChargesData = const [],
    this.quotationDetailsData = const {},
    this.totalFreightCostUsd,
    this.originalFreightCostUsd = 0.0,
    this.costSavingsUsd = 0.0,
    this.costVarianceUsd = 0.0,
    this.savingsNotes,
    this.status = 'Draft',
    this.owner = '',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
  });

  factory ShipmentBookingModel.fromJson(Map<String, dynamic> json) {
    var rawCont = json['containers_data'] as List<dynamic>? ?? [];
    var rawCost = json['cost_charges_data'] as List<dynamic>? ?? [];
    var rawQuote = json['quotation_details_data'] as Map<String, dynamic>? ?? {};

    return ShipmentBookingModel(
      bookingId: json['booking_id'],
      bookingCode: json['booking_code'] ?? '',
      bookingConfirmationNo: json['booking_confirmation_no'],
      billOfLadingNo: json['bill_of_lading_no'],
      importFileId: json['import_file_id'],
      rfqRequestId: json['rfq_request_id'],
      scenarioSessionId: json['scenario_session_id'],
      scenarioItemId: json['scenario_item_id'],
      scenarioProviderName: json['scenario_provider_name'],
      freightForwarderId: json['freight_forwarder_id'],
      freightForwarderName: json['freight_forwarder_name'],
      shippingLineId: json['shipping_line_id'],
      shippingLineName: json['shipping_line_name'],
      shipmentType: json['shipment_type'] ?? 'Ocean FCL',
      polLocationId: json['pol_location_id'],
      polName: json['pol_name'],
      podLocationId: json['pod_location_id'],
      podName: json['pod_name'],
      bookingRequestDate: json['booking_request_date'],
      bookingConfirmationDate: json['booking_confirmation_date'],
      etd: json['etd'],
      eta: json['eta'],
      atd: json['atd'],
      departureDelayDays: json['departure_delay_days'] ?? 0,
      expectedWarehouseDays: json['expected_warehouse_days'] ?? 7,
      expectedWarehouseArrivalDate: json['expected_warehouse_arrival_date'],
      transitTimeDays: json['transit_time_days'] ?? 0,
      freeDemurrageDays: json['free_demurrage_days'] ?? 14,
      cargoCutoffDate: json['cargo_cutoff_date'],
      siCutoffDate: json['si_cutoff_date'],
      vesselName: json['vessel_name'],
      voyageNumber: json['voyage_number'],
      containerReleaseOrderNo: json['container_release_order_no'],
      freightTerms: json['freight_terms'] ?? 'Collect',
      containerMismatchReason: json['container_mismatch_reason'],
      containersData: rawCont.map((c) => ContainerAllocationModel.fromJson(c)).toList(),
      costChargesData: rawCost.map((c) => BookingChargeModel.fromJson(c)).toList(),
      quotationDetailsData: rawQuote,
      totalFreightCostUsd: (json['total_freight_cost_usd'] as num?)?.toDouble(),
      originalFreightCostUsd: (json['original_freight_cost_usd'] as num?)?.toDouble() ?? (rawQuote['original_quote_total_usd'] as num?)?.toDouble() ?? 0.0,
      costSavingsUsd: (json['cost_savings_usd'] as num?)?.toDouble() ?? (rawQuote['cost_savings_usd'] as num?)?.toDouble() ?? 0.0,
      costVarianceUsd: (json['cost_variance_usd'] as num?)?.toDouble() ?? (rawQuote['cost_variance_usd'] as num?)?.toDouble() ?? 0.0,
      savingsNotes: json['savings_notes'],
      status: json['status'] ?? 'Draft',
      owner: json['owner'] ?? '',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'booking_code': bookingCode,
      'booking_confirmation_no': bookingConfirmationNo,
      'bill_of_lading_no': billOfLadingNo,
      'import_file_id': importFileId,
      'rfq_request_id': rfqRequestId,
      'scenario_session_id': scenarioSessionId,
      'scenario_item_id': scenarioItemId,
      'scenario_provider_name': scenarioProviderName,
      'freight_forwarder_id': freightForwarderId,
      'freight_forwarder_name': freightForwarderName,
      'shipping_line_id': shippingLineId,
      'shipping_line_name': shippingLineName,
      'shipment_type': shipmentType,
      'pol_location_id': polLocationId,
      'pol_name': polName,
      'pod_location_id': podLocationId,
      'pod_name': podName,
      'etd': etd,
      'eta': eta,
      'atd': atd,
      'departure_delay_days': departureDelayDays,
      'expected_warehouse_days': expectedWarehouseDays,
      'expected_warehouse_arrival_date': expectedWarehouseArrivalDate,
      'free_demurrage_days': freeDemurrageDays,
      'cargo_cutoff_date': cargoCutoffDate,
      'si_cutoff_date': siCutoffDate,
      'vessel_name': vesselName,
      'voyage_number': voyageNumber,
      'container_release_order_no': containerReleaseOrderNo,
      'freight_terms': freightTerms,
      'container_mismatch_reason': containerMismatchReason,
      'containers_data': containersData.map((c) => c.toJson()).toList(),
      'cost_charges_data': costChargesData.map((c) => c.toJson()).toList(),
      'quotation_details_data': quotationDetailsData,
      'total_freight_cost_usd': totalFreightCostUsd,
      'original_freight_cost_usd': originalFreightCostUsd,
      'cost_savings_usd': costSavingsUsd,
      'cost_variance_usd': costVarianceUsd,
      'savings_notes': savingsNotes,
      'status': status,
      'owner': owner,
      'notes': notes,
    };
  }
}
