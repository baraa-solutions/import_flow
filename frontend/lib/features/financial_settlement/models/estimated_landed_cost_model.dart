import 'actual_landed_cost_model.dart' show SettlementMessageModel;

class EstimatedLandedCostItemModel {
  final int lineNo;
  final String itemCode;
  final String itemName;
  final String hsCode;
  final double qty;
  final double unitPriceFc;
  final double fobTotalFc;
  final double fobUnitEgp;
  final double fobTotalEgp;
  final double allocatedFreightEgp;
  final double allocatedInsuranceEgp;
  final double allocatedCustomsDutyEgp;
  final double allocatedVatEgp;
  final double allocatedClearanceAndPortEgp;
  final double allocatedInlandTransportEgp;
  final double allocatedOtherEgp;
  final double totalExpensesAllocatedEgp;
  final double totalLandedCostEgp;
  final double unitLandedCostEgp;
  final double unitLandedCostFc;
  final double markupFactor;
  final double markupPercent;

  EstimatedLandedCostItemModel({
    required this.lineNo,
    required this.itemCode,
    required this.itemName,
    required this.hsCode,
    required this.qty,
    required this.unitPriceFc,
    required this.fobTotalFc,
    required this.fobUnitEgp,
    required this.fobTotalEgp,
    this.allocatedFreightEgp = 0.0,
    this.allocatedInsuranceEgp = 0.0,
    this.allocatedCustomsDutyEgp = 0.0,
    this.allocatedVatEgp = 0.0,
    this.allocatedClearanceAndPortEgp = 0.0,
    this.allocatedInlandTransportEgp = 0.0,
    this.allocatedOtherEgp = 0.0,
    this.totalExpensesAllocatedEgp = 0.0,
    this.totalLandedCostEgp = 0.0,
    this.unitLandedCostEgp = 0.0,
    this.unitLandedCostFc = 0.0,
    this.markupFactor = 1.0,
    this.markupPercent = 0.0,
  });

  factory EstimatedLandedCostItemModel.fromJson(Map<String, dynamic> json) {
    return EstimatedLandedCostItemModel(
      lineNo: json['line_no'] ?? 1,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      hsCode: json['hs_code'] ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 1.0,
      unitPriceFc: (json['unit_price_fc'] as num?)?.toDouble() ?? 0.0,
      fobTotalFc: (json['fob_total_fc'] as num?)?.toDouble() ?? 0.0,
      fobUnitEgp: (json['fob_unit_egp'] as num?)?.toDouble() ?? 0.0,
      fobTotalEgp: (json['fob_total_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedFreightEgp: (json['allocated_freight_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedInsuranceEgp: (json['allocated_insurance_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedCustomsDutyEgp: (json['allocated_customs_duty_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedVatEgp: (json['allocated_vat_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedClearanceAndPortEgp: (json['allocated_clearance_and_port_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedInlandTransportEgp: (json['allocated_inland_transport_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedOtherEgp: (json['allocated_other_egp'] as num?)?.toDouble() ?? 0.0,
      totalExpensesAllocatedEgp: (json['total_expenses_allocated_egp'] as num?)?.toDouble() ?? 0.0,
      totalLandedCostEgp: (json['total_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      unitLandedCostEgp: (json['unit_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      unitLandedCostFc: (json['unit_landed_cost_fc'] as num?)?.toDouble() ?? 0.0,
      markupFactor: (json['markup_factor'] as num?)?.toDouble() ?? 1.0,
      markupPercent: (json['markup_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'line_no': lineNo,
      'item_code': itemCode,
      'item_name': itemName,
      'hs_code': hsCode,
      'qty': qty,
      'unit_price_fc': unitPriceFc,
      'fob_total_fc': fobTotalFc,
      'fob_unit_egp': fobUnitEgp,
      'fob_total_egp': fobTotalEgp,
      'allocated_freight_egp': allocatedFreightEgp,
      'allocated_insurance_egp': allocatedInsuranceEgp,
      'allocated_customs_duty_egp': allocatedCustomsDutyEgp,
      'allocated_vat_egp': allocatedVatEgp,
      'allocated_clearance_and_port_egp': allocatedClearanceAndPortEgp,
      'allocated_inland_transport_egp': allocatedInlandTransportEgp,
      'allocated_other_egp': allocatedOtherEgp,
      'total_expenses_allocated_egp': totalExpensesAllocatedEgp,
      'total_landed_cost_egp': totalLandedCostEgp,
      'unit_landed_cost_egp': unitLandedCostEgp,
      'unit_landed_cost_fc': unitLandedCostFc,
      'markup_factor': markupFactor,
      'markup_percent': markupPercent,
    };
  }
}

class EstimatedLandedCostExpenseItemModel {
  final String category;
  final String description;
  final double amountFc;
  final String currency;
  final double amountEgp;
  final bool isEstimated;
  final String source;
  final String allocationRule;

  EstimatedLandedCostExpenseItemModel({
    required this.category,
    required this.description,
    this.amountFc = 0.0,
    this.currency = 'EGP',
    this.amountEgp = 0.0,
    this.isEstimated = true,
    this.source = 'Standard Estimate',
    this.allocationRule = 'Value-Based',
  });

  factory EstimatedLandedCostExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return EstimatedLandedCostExpenseItemModel(
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      amountFc: (json['amount_fc'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      isEstimated: json['is_estimated'] ?? true,
      source: json['source'] ?? 'Standard Estimate',
      allocationRule: json['allocation_rule'] ?? 'Value-Based',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'amount_fc': amountFc,
      'currency': currency,
      'amount_egp': amountEgp,
      'is_estimated': isEstimated,
      'source': source,
      'allocation_rule': allocationRule,
    };
  }
}

class EstimatedLandedCostSimulationModel {
  final int importFileId;
  final String importFileCode;
  final String currency;
  final double exchangeRate;
  final String incoterm;
  final double totalFobFc;
  final double totalFobEgp;
  final double totalFreightEgp;
  final double totalInsuranceEgp;
  final double totalCustomsAndTaxesEgp;
  final double totalClearanceAndPortEgp;
  final double totalInlandTransportEgp;
  final double totalOtherExpensesEgp;
  final double totalExpensesEgp;
  final double totalLandedCostEgp;
  final double totalLandedCostFc;
  final double averageMarkupFactor;
  final double averageMarkupPercent;
  final List<EstimatedLandedCostExpenseItemModel> expensesBreakdown;
  final List<EstimatedLandedCostItemModel> itemsBreakdown;
  final String executiveSummaryAr;
  final double totalCustomsDutyEgp;
  final double totalVatAndFeesEgp;
  final List<SettlementMessageModel> messages;

  EstimatedLandedCostSimulationModel({
    required this.importFileId,
    required this.importFileCode,
    required this.currency,
    required this.exchangeRate,
    required this.incoterm,
    required this.totalFobFc,
    required this.totalFobEgp,
    required this.totalFreightEgp,
    required this.totalInsuranceEgp,
    required this.totalCustomsAndTaxesEgp,
    required this.totalClearanceAndPortEgp,
    required this.totalInlandTransportEgp,
    required this.totalOtherExpensesEgp,
    required this.totalExpensesEgp,
    required this.totalLandedCostEgp,
    required this.totalLandedCostFc,
    required this.averageMarkupFactor,
    required this.averageMarkupPercent,
    this.expensesBreakdown = const [],
    this.itemsBreakdown = const [],
    required this.executiveSummaryAr,
    this.totalCustomsDutyEgp = 0.0,
    this.totalVatAndFeesEgp = 0.0,
    this.messages = const [],
  });

  factory EstimatedLandedCostSimulationModel.fromJson(Map<String, dynamic> json) {
    return EstimatedLandedCostSimulationModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      currency: json['currency'] ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      incoterm: json['incoterm'] ?? 'FOB',
      totalFobFc: (json['total_fob_fc'] as num?)?.toDouble() ?? 0.0,
      totalFobEgp: (json['total_fob_egp'] as num?)?.toDouble() ?? 0.0,
      totalFreightEgp: (json['total_freight_egp'] as num?)?.toDouble() ?? 0.0,
      totalInsuranceEgp: (json['total_insurance_egp'] as num?)?.toDouble() ?? 0.0,
      totalCustomsAndTaxesEgp: (json['total_customs_and_taxes_egp'] as num?)?.toDouble() ?? 0.0,
      totalClearanceAndPortEgp: (json['total_clearance_and_port_egp'] as num?)?.toDouble() ?? 0.0,
      totalInlandTransportEgp: (json['total_inland_transport_egp'] as num?)?.toDouble() ?? 0.0,
      totalOtherExpensesEgp: (json['total_other_expenses_egp'] as num?)?.toDouble() ?? 0.0,
      totalExpensesEgp: (json['total_expenses_egp'] as num?)?.toDouble() ?? 0.0,
      totalLandedCostEgp: (json['total_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      totalLandedCostFc: (json['total_landed_cost_fc'] as num?)?.toDouble() ?? 0.0,
      averageMarkupFactor: (json['average_markup_factor'] as num?)?.toDouble() ?? 1.0,
      averageMarkupPercent: (json['average_markup_percent'] as num?)?.toDouble() ?? 0.0,
      expensesBreakdown: (json['expenses_breakdown'] as List<dynamic>?)
              ?.map((e) => EstimatedLandedCostExpenseItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itemsBreakdown: (json['items_breakdown'] as List<dynamic>?)
              ?.map((e) => EstimatedLandedCostItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      executiveSummaryAr: json['executive_summary_ar'] ?? '',
      totalCustomsDutyEgp: (json['total_customs_duty_egp'] as num?)?.toDouble() ?? 0.0,
      totalVatAndFeesEgp: (json['total_vat_and_fees_egp'] as num?)?.toDouble() ?? 0.0,
      messages: SettlementMessageModel.listFrom(json['messages']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'incoterm': incoterm,
      'total_fob_fc': totalFobFc,
      'total_fob_egp': totalFobEgp,
      'total_freight_egp': totalFreightEgp,
      'total_insurance_egp': totalInsuranceEgp,
      'total_customs_and_taxes_egp': totalCustomsAndTaxesEgp,
      'total_clearance_and_port_egp': totalClearanceAndPortEgp,
      'total_inland_transport_egp': totalInlandTransportEgp,
      'total_other_expenses_egp': totalOtherExpensesEgp,
      'total_expenses_egp': totalExpensesEgp,
      'total_landed_cost_egp': totalLandedCostEgp,
      'total_landed_cost_fc': totalLandedCostFc,
      'average_markup_factor': averageMarkupFactor,
      'average_markup_percent': averageMarkupPercent,
      'expenses_breakdown': expensesBreakdown.map((e) => e.toJson()).toList(),
      'items_breakdown': itemsBreakdown.map((e) => e.toJson()).toList(),
      'executive_summary_ar': executiveSummaryAr,
      'total_customs_duty_egp': totalCustomsDutyEgp,
      'total_vat_and_fees_egp': totalVatAndFeesEgp,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class EstimatedLandedCostSimulationRequestModel {
  final double? exchangeRateOverride;
  final double? freightAmountEgpOverride;
  final double? insuranceAmountEgpOverride;
  final double? clearanceFeesEgpOverride;
  final double? portHandlingEgpOverride;
  final double? inlandTransportEgpOverride;
  final double? bankFeesEgpOverride;
  final double? otherExpensesEgpOverride;
  final String allocationPreference;

  EstimatedLandedCostSimulationRequestModel({
    this.exchangeRateOverride,
    this.freightAmountEgpOverride,
    this.insuranceAmountEgpOverride,
    this.clearanceFeesEgpOverride,
    this.portHandlingEgpOverride,
    this.inlandTransportEgpOverride,
    this.bankFeesEgpOverride,
    this.otherExpensesEgpOverride,
    this.allocationPreference = 'Value-Based',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'allocation_preference': allocationPreference,
    };
    if (exchangeRateOverride != null) map['exchange_rate_override'] = exchangeRateOverride;
    if (freightAmountEgpOverride != null) map['freight_amount_egp_override'] = freightAmountEgpOverride;
    if (insuranceAmountEgpOverride != null) map['insurance_amount_egp_override'] = insuranceAmountEgpOverride;
    if (clearanceFeesEgpOverride != null) map['clearance_fees_egp_override'] = clearanceFeesEgpOverride;
    if (portHandlingEgpOverride != null) map['port_handling_egp_override'] = portHandlingEgpOverride;
    if (inlandTransportEgpOverride != null) map['inland_transport_egp_override'] = inlandTransportEgpOverride;
    if (bankFeesEgpOverride != null) map['bank_fees_egp_override'] = bankFeesEgpOverride;
    if (otherExpensesEgpOverride != null) map['other_expenses_egp_override'] = otherExpensesEgpOverride;
    return map;
  }
}
