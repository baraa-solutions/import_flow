/// First numeric value found under any of [keys] (backend name first, then the
/// legacy client name), else [fallback].
double _numOf(Map<String, dynamic> json, List<String> keys, double fallback) {
  for (final k in keys) {
    final v = json[k];
    if (v is num) return v.toDouble();
  }
  return fallback;
}

double? _optNumOf(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is num) return v.toDouble();
  }
  return null;
}

String _strOf(Map<String, dynamic> json, List<String> keys, String fallback) {
  for (final k in keys) {
    final v = json[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return fallback;
}

/// Maps backend variance codes (SAVING / INCREASED / UNDER_BUDGET / OVER_BUDGET /
/// ON_BUDGET / NO_ESTIMATE) and legacy ones to FAVORABLE / UNFAVORABLE / MATCHED / NO_ESTIMATE.
String normalizeVarianceStatus(String? raw) {
  switch (raw) {
    case 'NO_ESTIMATE':
      return 'NO_ESTIMATE';
    case 'SAVING':
    case 'UNDER_BUDGET':
    case 'FAVORABLE':
      return 'FAVORABLE';
    case 'INCREASED':
    case 'OVER_BUDGET':
    case 'UNFAVORABLE':
      return 'UNFAVORABLE';
    default:
      return 'MATCHED';
  }
}

/// Language-neutral backend message (`code` + `params`), rendered by the UI via l10n.
class SettlementMessageModel {
  final String code;
  final Map<String, dynamic> params;
  final String severity;

  const SettlementMessageModel({
    required this.code,
    this.params = const {},
    this.severity = 'warning',
  });

  factory SettlementMessageModel.fromJson(Map<String, dynamic> json) {
    return SettlementMessageModel(
      code: json['code']?.toString() ?? '',
      params: (json['params'] as Map?)?.cast<String, dynamic>() ?? const {},
      severity: json['severity']?.toString() ?? 'warning',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'params': params, 'severity': severity};

  static List<SettlementMessageModel> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SettlementMessageModel.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

String _statusFromVariance(double v) {
  if (v > 0) return 'UNFAVORABLE';
  if (v < 0) return 'FAVORABLE';
  return 'MATCHED';
}

class ActualLandedCostCategoryBreakdownModel {
  final String category;
  final String categoryAr;
  final double? estimatedAmountEgp;
  final double actualAmountEgp;
  final double? varianceEgp;
  final double? variancePct;
  final String varianceStatus;
  final int invoicesCount;
  final String sourceNote;

  ActualLandedCostCategoryBreakdownModel({
    required this.category,
    required this.categoryAr,
    this.estimatedAmountEgp,
    required this.actualAmountEgp,
    this.varianceEgp,
    this.variancePct,
    required this.varianceStatus,
    required this.invoicesCount,
    required this.sourceNote,
  });

  factory ActualLandedCostCategoryBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ActualLandedCostCategoryBreakdownModel(
      category: json['category'] ?? '',
      categoryAr: json['category_ar'] ?? '',
      estimatedAmountEgp: _optNumOf(json, ['estimated_egp', 'estimated_amount_egp']),
      actualAmountEgp: _numOf(json, ['actual_egp', 'actual_amount_egp'], 0.0),
      varianceEgp: (json['variance_egp'] as num?)?.toDouble(),
      variancePct: (json['variance_pct'] as num?)?.toDouble(),
      varianceStatus: json['variance_status'] != null
          ? normalizeVarianceStatus(json['variance_status']?.toString())
          : (json['variance_egp'] != null
              ? _statusFromVariance((json['variance_egp'] as num).toDouble())
              : 'NO_ESTIMATE'),
      invoicesCount: (json['invoices_count'] as num?)?.toInt() ?? 0,
      sourceNote: json['source_note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'category_ar': categoryAr,
      'estimated_amount_egp': estimatedAmountEgp,
      'actual_amount_egp': actualAmountEgp,
      'variance_egp': varianceEgp,
      'variance_pct': variancePct,
      'variance_status': varianceStatus,
      'invoices_count': invoicesCount,
      'source_note': sourceNote,
    };
  }
}

class ActualLandedCostItemLineModel {
  final int poItemId;
  final String itemCode;
  final String itemNameAr;
  final String hsCode;
  final double quantity;
  final String unitOfMeasure;
  final double fobUnitPriceFc;
  final double fobTotalFc;
  final double fobTotalEgp;
  final String currency;
  final double grossWeightKg;
  final double cbm;
  final double allocatedFreightEgp;
  final double allocatedInsuranceEgp;
  final double allocatedCustomsDutiesEgp;
  final double allocatedTaxesFeesEgp;
  final double allocatedClearanceBrokerageEgp;
  final double allocatedPortHandlingEgp;
  final double allocatedInlandTransportEgp;
  final double allocatedOtherExpensesEgp;
  final double totalActualLandedCostEgp;
  final double actualUnitLandedCostEgp;
  final double? estimatedUnitLandedCostEgp;
  final double? unitCostVarianceEgp;
  final double? unitCostVariancePct;
  final double markupFactor;
  final String varianceStatus;

  ActualLandedCostItemLineModel({
    required this.poItemId,
    required this.itemCode,
    required this.itemNameAr,
    required this.hsCode,
    required this.quantity,
    required this.unitOfMeasure,
    required this.fobUnitPriceFc,
    required this.fobTotalFc,
    required this.fobTotalEgp,
    required this.currency,
    required this.grossWeightKg,
    required this.cbm,
    required this.allocatedFreightEgp,
    required this.allocatedInsuranceEgp,
    required this.allocatedCustomsDutiesEgp,
    required this.allocatedTaxesFeesEgp,
    required this.allocatedClearanceBrokerageEgp,
    required this.allocatedPortHandlingEgp,
    required this.allocatedInlandTransportEgp,
    required this.allocatedOtherExpensesEgp,
    required this.totalActualLandedCostEgp,
    required this.actualUnitLandedCostEgp,
    this.estimatedUnitLandedCostEgp,
    this.unitCostVarianceEgp,
    this.unitCostVariancePct,
    required this.markupFactor,
    required this.varianceStatus,
  });

  factory ActualLandedCostItemLineModel.fromJson(Map<String, dynamic> json) {
    return ActualLandedCostItemLineModel(
      poItemId: (json['po_item_id'] as num?)?.toInt() ?? 0,
      itemCode: json['item_code'] ?? '',
      itemNameAr: _strOf(json, ['item_name', 'item_name_ar'], ''),
      hsCode: json['hs_code'] ?? '',
      quantity: _numOf(json, ['qty', 'quantity'], 0.0),
      unitOfMeasure: json['unit_of_measure'] ?? 'PCS',
      fobUnitPriceFc: _numOf(json, ['fob_unit_price_fc', 'fob_unit_egp'], 0.0),
      fobTotalFc: (json['fob_total_fc'] as num?)?.toDouble() ?? 0.0,
      fobTotalEgp: (json['fob_total_egp'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      cbm: (json['cbm'] as num?)?.toDouble() ?? 0.0,
      allocatedFreightEgp: (json['allocated_freight_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedInsuranceEgp: (json['allocated_insurance_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedCustomsDutiesEgp: _numOf(json, ['allocated_customs_duty_egp', 'allocated_customs_duties_egp'], 0.0),
      allocatedTaxesFeesEgp: _numOf(json, ['allocated_vat_egp', 'allocated_taxes_fees_egp'], 0.0),
      allocatedClearanceBrokerageEgp: _numOf(json, ['allocated_clearance_egp', 'allocated_clearance_brokerage_egp'], 0.0),
      allocatedPortHandlingEgp: (json['allocated_port_handling_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedInlandTransportEgp: (json['allocated_inland_transport_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedOtherExpensesEgp: _numOf(json, ['allocated_other_egp', 'allocated_other_expenses_egp'], 0.0),
      totalActualLandedCostEgp: (json['total_actual_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      actualUnitLandedCostEgp: (json['actual_unit_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      estimatedUnitLandedCostEgp: (json['estimated_unit_landed_cost_egp'] as num?)?.toDouble(),
      unitCostVarianceEgp: (json['unit_cost_variance_egp'] as num?)?.toDouble(),
      unitCostVariancePct: (json['unit_cost_variance_pct'] as num?)?.toDouble(),
      markupFactor: _numOf(json, ['actual_markup_factor', 'markup_factor'], 1.0),
      varianceStatus: normalizeVarianceStatus(
          (json['item_variance_status'] ?? json['variance_status'])?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'po_item_id': poItemId,
      'item_code': itemCode,
      'item_name_ar': itemNameAr,
      'hs_code': hsCode,
      'quantity': quantity,
      'unit_of_measure': unitOfMeasure,
      'fob_unit_price_fc': fobUnitPriceFc,
      'fob_total_fc': fobTotalFc,
      'fob_total_egp': fobTotalEgp,
      'currency': currency,
      'gross_weight_kg': grossWeightKg,
      'cbm': cbm,
      'allocated_freight_egp': allocatedFreightEgp,
      'allocated_insurance_egp': allocatedInsuranceEgp,
      'allocated_customs_duties_egp': allocatedCustomsDutiesEgp,
      'allocated_taxes_fees_egp': allocatedTaxesFeesEgp,
      'allocated_clearance_brokerage_egp': allocatedClearanceBrokerageEgp,
      'allocated_port_handling_egp': allocatedPortHandlingEgp,
      'allocated_inland_transport_egp': allocatedInlandTransportEgp,
      'allocated_other_expenses_egp': allocatedOtherExpensesEgp,
      'total_actual_landed_cost_egp': totalActualLandedCostEgp,
      'actual_unit_landed_cost_egp': actualUnitLandedCostEgp,
      'estimated_unit_landed_cost_egp': estimatedUnitLandedCostEgp,
      'unit_cost_variance_egp': unitCostVarianceEgp,
      'unit_cost_variance_pct': unitCostVariancePct,
      'markup_factor': markupFactor,
      'variance_status': varianceStatus,
    };
  }
}

class ActualLandedCostCalculationResponseModel {
  final int importFileId;
  final String importFileCode;
  final String financialSettlementStatus;
  final String? currency;
  final double fxRate;
  final String allocationPreference;
  final double totalFobEgp;
  final double totalActualExpensesEgp;
  final double actualTotalLandedCostEgp;
  final double actualMarkupFactor;
  final double? estimatedTotalLandedCostEgp;
  final double? landedVarianceEgp;
  final double? landedVariancePct;
  final String varianceStatus;
  final String varianceStatusAr;
  final List<ActualLandedCostCategoryBreakdownModel> categoriesBreakdown;
  final List<ActualLandedCostItemLineModel> itemsBreakdown;
  final String summaryNotes;
  final double reconciliationDifferenceEgp;
  final List<SettlementMessageModel> messages;

  ActualLandedCostCalculationResponseModel({
    required this.importFileId,
    required this.importFileCode,
    required this.financialSettlementStatus,
    this.currency,
    required this.fxRate,
    required this.allocationPreference,
    required this.totalFobEgp,
    required this.totalActualExpensesEgp,
    required this.actualTotalLandedCostEgp,
    required this.actualMarkupFactor,
    this.estimatedTotalLandedCostEgp,
    this.landedVarianceEgp,
    this.landedVariancePct,
    required this.varianceStatus,
    required this.varianceStatusAr,
    required this.categoriesBreakdown,
    required this.itemsBreakdown,
    required this.summaryNotes,
    this.reconciliationDifferenceEgp = 0.0,
    this.messages = const [],
  });

  factory ActualLandedCostCalculationResponseModel.fromJson(Map<String, dynamic> json) {
    var rawCategories = json['categories_breakdown'] as List<dynamic>? ?? [];
    var rawItems = json['items_breakdown'] as List<dynamic>? ?? [];

    return ActualLandedCostCalculationResponseModel(
      importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      financialSettlementStatus: json['financial_settlement_status'] ?? '',
      currency: json['currency']?.toString(),
      fxRate: _numOf(json, ['exchange_rate', 'fx_rate'], 0.0),
      allocationPreference: json['allocation_preference'] ?? 'Value-Based',
      totalFobEgp: _numOf(json, ['actual_total_fob_egp', 'total_fob_egp'], 0.0),
      totalActualExpensesEgp: _numOf(json, ['actual_total_expenses_egp', 'total_actual_expenses_egp'], 0.0),
      actualTotalLandedCostEgp: (json['actual_total_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      actualMarkupFactor: (json['actual_markup_factor'] as num?)?.toDouble() ?? 1.0,
      estimatedTotalLandedCostEgp: (json['estimated_total_landed_cost_egp'] as num?)?.toDouble(),
      landedVarianceEgp: (json['landed_variance_egp'] as num?)?.toDouble(),
      landedVariancePct: (json['landed_variance_pct'] as num?)?.toDouble(),
      varianceStatus: normalizeVarianceStatus(json['variance_status']?.toString()),
      varianceStatusAr: json['variance_status_ar']?.toString() ?? '',
      reconciliationDifferenceEgp: (json['reconciliation_difference_egp'] as num?)?.toDouble() ?? 0.0,
      messages: SettlementMessageModel.listFrom(json['messages']),
      categoriesBreakdown: rawCategories
          .map((c) => ActualLandedCostCategoryBreakdownModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      itemsBreakdown: rawItems
          .map((i) => ActualLandedCostItemLineModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      summaryNotes: json['summary_notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'financial_settlement_status': financialSettlementStatus,
      'currency': currency,
      'fx_rate': fxRate,
      'allocation_preference': allocationPreference,
      'total_fob_egp': totalFobEgp,
      'total_actual_expenses_egp': totalActualExpensesEgp,
      'actual_total_landed_cost_egp': actualTotalLandedCostEgp,
      'actual_markup_factor': actualMarkupFactor,
      'estimated_total_landed_cost_egp': estimatedTotalLandedCostEgp,
      'landed_variance_egp': landedVarianceEgp,
      'landed_variance_pct': landedVariancePct,
      'variance_status': varianceStatus,
      'variance_status_ar': varianceStatusAr,
      'categories_breakdown': categoriesBreakdown.map((c) => c.toJson()).toList(),
      'items_breakdown': itemsBreakdown.map((i) => i.toJson()).toList(),
      'summary_notes': summaryNotes,
      'reconciliation_difference_egp': reconciliationDifferenceEgp,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class ApproveActualLandedCostResponseModel {
  final bool success;
  final int importFileId;
  final String importFileCode;
  final int? settlementId;
  final String? settlementCode;
  final String financialSettlementStatus;
  final double actualLandedCostTotalEgp;
  final double actualLandedCostMarkupFactor;
  final double? landedVarianceEgp;
  final double? landedVariancePct;
  final String varianceStatus;
  final double progressPercent;
  final String currentStage;
  final String currentModule;
  final String nextTaskCode;
  final String nextTaskTitle;
  final String message;

  ApproveActualLandedCostResponseModel({
    required this.success,
    required this.importFileId,
    required this.importFileCode,
    this.settlementId,
    this.settlementCode,
    required this.financialSettlementStatus,
    required this.actualLandedCostTotalEgp,
    required this.actualLandedCostMarkupFactor,
    this.landedVarianceEgp,
    this.landedVariancePct,
    required this.varianceStatus,
    required this.progressPercent,
    required this.currentStage,
    required this.currentModule,
    required this.nextTaskCode,
    required this.nextTaskTitle,
    required this.message,
  });

  factory ApproveActualLandedCostResponseModel.fromJson(Map<String, dynamic> json) {
    return ApproveActualLandedCostResponseModel(
      success: json['success'] ?? false,
      importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      settlementId: (json['settlement_id'] as num?)?.toInt(),
      settlementCode: json['settlement_code'],
      financialSettlementStatus: json['financial_settlement_status'] ?? '',
      actualLandedCostTotalEgp: (json['actual_landed_cost_total_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostMarkupFactor: (json['actual_landed_cost_markup_factor'] as num?)?.toDouble() ?? 1.0,
      landedVarianceEgp: (json['landed_variance_egp'] as num?)?.toDouble(),
      landedVariancePct: (json['landed_variance_pct'] as num?)?.toDouble(),
      varianceStatus: json['variance_status'] ?? 'MATCHED',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      currentStage: json['current_stage'] ?? '',
      currentModule: json['current_module'] ?? '',
      nextTaskCode: json['next_task_code'] ?? '',
      nextTaskTitle: json['next_task_title'] ?? '',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'settlement_id': settlementId,
      'settlement_code': settlementCode,
      'financial_settlement_status': financialSettlementStatus,
      'actual_landed_cost_total_egp': actualLandedCostTotalEgp,
      'actual_landed_cost_markup_factor': actualLandedCostMarkupFactor,
      'landed_variance_egp': landedVarianceEgp,
      'landed_variance_pct': landedVariancePct,
      'variance_status': varianceStatus,
      'progress_percent': progressPercent,
      'current_stage': currentStage,
      'current_module': currentModule,
      'next_task_code': nextTaskCode,
      'next_task_title': nextTaskTitle,
      'message': message,
    };
  }
}
