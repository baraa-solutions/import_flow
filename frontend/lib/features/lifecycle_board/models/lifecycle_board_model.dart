import '../../../core/localization/system_messages/system_message_renderer.dart';
import '../../../core/localization/app_localizations.dart';

class PhaseSummaryModel {
  final int phaseId;
  final String titleEn;
  final String titleAr;
  final String colorHex;
  final List<String> stepCodes;
  final int totalActiveShipments;
  final Map<String, int> stepCounts;

  PhaseSummaryModel({
    required this.phaseId,
    required this.titleEn,
    required this.titleAr,
    required this.colorHex,
    required this.stepCodes,
    required this.totalActiveShipments,
    required this.stepCounts,
  });

  factory PhaseSummaryModel.fromJson(Map<String, dynamic> json) {
    return PhaseSummaryModel(
      phaseId: json['phase_id'] ?? 1,
      titleEn: json['title_en'] ?? '',
      titleAr: json['title_ar'] ?? '',
      colorHex: json['color_hex'] ?? '#3498DB',
      stepCodes: List<String>.from(json['step_codes'] ?? []),
      totalActiveShipments: json['total_active_shipments'] ?? 0,
      stepCounts: Map<String, int>.from(json['step_counts'] ?? {}),
    );
  }
}

class ShipmentStageCardModel {
  final String importFileCode;
  final String companyName;
  final String supplierName;
  final String? poNumber;
  final String? shipmentMode;
  final String? incotermCode;
  final String? priority;
  final double? estimatedCost;
  final String? estimatedCostCurrency;
  final String stepCode;
  final String stepNameEn;
  final String stepNameAr;
  final String? previousStepCode;
  final String? previousStepNameEn;
  final String? previousStepNameAr;
  final String? nextStepCode;
  final String? nextStepNameEn;
  final String? nextStepNameAr;
  final String status;
  final String? startedAt;
  final String? notes;
  /// System message code of [notes] (null for legacy rows / user notes).
  final String? msgCode;
  final Map<String, dynamic>? msgParams;

  ShipmentStageCardModel({
    required this.importFileCode,
    required this.companyName,
    required this.supplierName,
    this.poNumber,
    this.shipmentMode,
    this.incotermCode,
    this.priority,
    this.estimatedCost,
    this.estimatedCostCurrency,
    required this.stepCode,
    required this.stepNameEn,
    required this.stepNameAr,
    this.previousStepCode,
    this.previousStepNameEn,
    this.previousStepNameAr,
    this.nextStepCode,
    this.nextStepNameEn,
    this.nextStepNameAr,
    required this.status,
    this.startedAt,
    this.notes,
    this.msgCode,
    this.msgParams,
  });

  /// [notes] in the user's language; the stored text when there is no usable code.
  String? localizedNotes(AppLocalizations l10n) =>
      SystemMessageRenderer.tryRender(code: msgCode, params: msgParams, part: SystemMessagePart.note, l10n: l10n) ??
      notes;

  factory ShipmentStageCardModel.fromJson(Map<String, dynamic> json) {
    return ShipmentStageCardModel(
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      poNumber: json['po_number'],
      shipmentMode: json['shipment_mode'],
      incotermCode: json['incoterm_code'],
      priority: json['priority'],
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      estimatedCostCurrency: json['estimated_cost_currency'],
      stepCode: json['step_code'] ?? '',
      stepNameEn: json['step_name_en'] ?? '',
      stepNameAr: json['step_name_ar'] ?? '',
      previousStepCode: json['previous_step_code'],
      previousStepNameEn: json['previous_step_name_en'],
      previousStepNameAr: json['previous_step_name_ar'],
      nextStepCode: json['next_step_code'],
      nextStepNameEn: json['next_step_name_en'],
      nextStepNameAr: json['next_step_name_ar'],
      status: json['status'] ?? 'In-Progress',
      startedAt: json['started_at'],
      notes: json['notes'],
      msgCode: SystemMessageRenderer.parseCode(json['msg_code']),
      msgParams: SystemMessageRenderer.parseParams(json['msg_params']),
    );
  }
}

class LifecycleBoardSummaryModel {
  final List<PhaseSummaryModel> phases;
  final int totalActiveFiles;
  final List<ShipmentStageCardModel> allShipments;

  LifecycleBoardSummaryModel({
    required this.phases,
    required this.totalActiveFiles,
    required this.allShipments,
  });

  factory LifecycleBoardSummaryModel.fromJson(Map<String, dynamic> json) {
    return LifecycleBoardSummaryModel(
      phases: (json['phases'] as List<dynamic>?)
              ?.map((e) => PhaseSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalActiveFiles: json['total_active_files'] ?? 0,
      allShipments: (json['all_shipments'] as List<dynamic>?)
              ?.map((e) => ShipmentStageCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class LiveLogisticsTrackingItemModel {
  final int importFileId;
  final String importFileCode;
  final String companyName;
  final String supplierName;
  final String? poNumber;
  final String? shipmentMode;
  final String? incotermCode;
  final String? priority;

  // Voyage & Logistics
  final String? blNumber;
  final String? carrierName;
  final String? vesselName;
  final String? polName;
  final String? podName;
  final String? etd;
  final String? eta;
  final int? etaCountdownDays;
  final String arrivalStatus;

  // Demurrage & Free Time
  final String? demurrageTrackingCode;
  final String demurrageStatus;
  final int? freeDaysTotal;
  final int? freeDaysRemaining;
  final int usedFreeDays;
  final String demurrageRiskLevel;
  final double accumulatedDemurrageFx;
  final double accumulatedDemurrageEgp;

  // Regulatory Testing & Samples
  final String sampleTestStatus;
  final String? regulatoryAgency;
  final String? labReceiptNumber;
  final int? sampleResultCountdownDays;

  // Document Readiness
  final double docReadinessPercent;
  final int verifiedDocumentsCount;
  final int totalRequiredDocuments;
  final List<String> missingDocuments;

  // Health Score & Stage
  final String operationalHealthScore;
  final String currentStepCode;
  final String currentStepNameAr;
  final String currentStepNameEn;
  final String nextAction;
  /// NA_* system message code of [nextAction] (null for legacy rows).
  final String? nextActionCode;
  final Map<String, dynamic>? nextActionParams;

  LiveLogisticsTrackingItemModel({
    required this.importFileId,
    required this.importFileCode,
    required this.companyName,
    required this.supplierName,
    this.poNumber,
    this.shipmentMode,
    this.incotermCode,
    this.priority,
    this.blNumber,
    this.carrierName,
    this.vesselName,
    this.polName,
    this.podName,
    this.etd,
    this.eta,
    this.etaCountdownDays,
    required this.arrivalStatus,
    this.demurrageTrackingCode,
    required this.demurrageStatus,
    this.freeDaysTotal,
    this.freeDaysRemaining,
    required this.usedFreeDays,
    this.demurrageRiskLevel = 'Unknown',
    required this.accumulatedDemurrageFx,
    required this.accumulatedDemurrageEgp,
    required this.sampleTestStatus,
    this.regulatoryAgency,
    this.labReceiptNumber,
    this.sampleResultCountdownDays,
    required this.docReadinessPercent,
    required this.verifiedDocumentsCount,
    required this.totalRequiredDocuments,
    required this.missingDocuments,
    required this.operationalHealthScore,
    required this.currentStepCode,
    required this.currentStepNameAr,
    required this.currentStepNameEn,
    required this.nextAction,
    this.nextActionCode,
    this.nextActionParams,
  });

  factory LiveLogisticsTrackingItemModel.fromJson(Map<String, dynamic> json) {
    return LiveLogisticsTrackingItemModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      poNumber: json['po_number'],
      shipmentMode: json['shipment_mode'],
      incotermCode: json['incoterm_code'],
      priority: json['priority'],
      blNumber: json['bl_number'],
      carrierName: json['carrier_name'],
      vesselName: json['vessel_name'],
      polName: json['pol_name'],
      podName: json['pod_name'],
      etd: json['etd'],
      eta: json['eta'],
      etaCountdownDays: json['eta_countdown_days'],
      arrivalStatus: json['arrival_status'] ?? 'Pre-Shipment',
      demurrageTrackingCode: json['demurrage_tracking_code'],
      demurrageStatus: json['demurrage_status'] ?? 'No Active Session',
      freeDaysTotal: json['free_days_total'],
      freeDaysRemaining: json['free_days_remaining'],
      usedFreeDays: json['used_free_days'] ?? 0,
      demurrageRiskLevel: json['demurrage_risk_level'] ?? 'Unknown',
      accumulatedDemurrageFx: (json['accumulated_demurrage_fx'] as num?)?.toDouble() ?? 0.0,
      accumulatedDemurrageEgp: (json['accumulated_demurrage_egp'] as num?)?.toDouble() ?? 0.0,
      sampleTestStatus: json['sample_test_status'] ?? 'Not Applicable',
      regulatoryAgency: json['regulatory_agency'],
      labReceiptNumber: json['lab_receipt_number'],
      sampleResultCountdownDays: json['sample_result_countdown_days'],
      docReadinessPercent: (json['doc_readiness_percent'] as num?)?.toDouble() ?? 0.0,
      verifiedDocumentsCount: json['verified_documents_count'] ?? 0,
      totalRequiredDocuments: json['total_required_documents'] ?? 7,
      missingDocuments: json['missing_documents'] is List
          ? (json['missing_documents'] as List).map((e) => e.toString()).toList()
          : (json['missing_documents'] is String && (json['missing_documents'] as String).trim().isNotEmpty
              ? [json['missing_documents'].toString().trim()]
              : []),
      operationalHealthScore: json['operational_health_score'] ?? 'Optimal',
      currentStepCode: json['current_step_code'] ?? 'STEP_01',
      currentStepNameAr: json['current_step_name_ar'] ?? '',
      currentStepNameEn: json['current_step_name_en'] ?? '',
      nextAction: json['next_action'] ?? '',
      nextActionCode: SystemMessageRenderer.parseCode(json['next_action_code']),
      nextActionParams: SystemMessageRenderer.parseParams(json['next_action_params']),
    );
  }
}

class LiveLogisticsSummaryModel {
  final int totalActiveShipments;
  final int inTransitCount;
  final int inPortCount;
  final int highRiskDemurrageCount;
  final int underSampleTestingCount;
  final int incompleteDocumentsCount;
  final List<LiveLogisticsTrackingItemModel> items;

  LiveLogisticsSummaryModel({
    required this.totalActiveShipments,
    required this.inTransitCount,
    required this.inPortCount,
    required this.highRiskDemurrageCount,
    required this.underSampleTestingCount,
    required this.incompleteDocumentsCount,
    required this.items,
  });

  factory LiveLogisticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return LiveLogisticsSummaryModel(
      totalActiveShipments: json['total_active_shipments'] ?? 0,
      inTransitCount: json['in_transit_count'] ?? 0,
      inPortCount: json['in_port_count'] ?? 0,
      highRiskDemurrageCount: json['high_risk_demurrage_count'] ?? 0,
      underSampleTestingCount: json['under_sample_testing_count'] ?? 0,
      incompleteDocumentsCount: json['incomplete_documents_count'] ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => LiveLogisticsTrackingItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory LiveLogisticsSummaryModel.empty() {
    return LiveLogisticsSummaryModel(
      totalActiveShipments: 0,
      inTransitCount: 0,
      inPortCount: 0,
      highRiskDemurrageCount: 0,
      underSampleTestingCount: 0,
      incompleteDocumentsCount: 0,
      items: [],
    );
  }
}

