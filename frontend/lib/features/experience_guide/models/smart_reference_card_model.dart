import 'guide_entry_model.dart';
import '../../comprehensive_report/models/comprehensive_dossier_model.dart';

class SmartReferenceCardModel {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;
  final Map<String, dynamic> productSummary;
  final Map<String, dynamic> routeSummary;
  final Map<String, dynamic> criticalDates;
  final Map<String, dynamic> documentStatus;
  final List<GuideEntryModel> matchedGuideEntries;
  final Map<String, dynamic> costSummary;

  SmartReferenceCardModel({
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
    this.productSummary = const {},
    this.routeSummary = const {},
    this.criticalDates = const {},
    this.documentStatus = const {},
    this.matchedGuideEntries = const [],
    this.costSummary = const {},
  });

  factory SmartReferenceCardModel.fromJson(Map<String, dynamic> json) {
    var rawEntries = json['matched_guide_entries'] as List<dynamic>? ?? [];
    return SmartReferenceCardModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      customFileNumber: json['custom_file_number'],
      productSummary: (json['product_summary'] as Map<String, dynamic>?) ?? {},
      routeSummary: (json['route_summary'] as Map<String, dynamic>?) ?? {},
      criticalDates: (json['critical_dates'] as Map<String, dynamic>?) ?? {},
      documentStatus: (json['document_status'] as Map<String, dynamic>?) ?? {},
      matchedGuideEntries: rawEntries.map((e) => GuideEntryModel.fromJson(e as Map<String, dynamic>)).toList(),
      costSummary: (json['cost_summary'] as Map<String, dynamic>?) ?? {},
    );
  }

  factory SmartReferenceCardModel.fromDossier(ComprehensiveShipmentDossierModel dossier) {
    final carrier = (dossier.smartReferenceCard?['route_summary']?['shipping_line'] as String?) ??
        (dossier.containers.isNotEmpty ? (dossier.containers.first['carrier_name']?.toString() ?? '') : '');
    final isReady = dossier.closureReadiness['is_ready_for_closure'] ?? (dossier.progressPercent >= 100.0);

    if (dossier.smartReferenceCard != null && dossier.smartReferenceCard!.isNotEmpty) {
      final base = SmartReferenceCardModel.fromJson(dossier.smartReferenceCard!);
      return SmartReferenceCardModel(
        importFileId: base.importFileId != 0 ? base.importFileId : dossier.importFileId,
        importFileCode: base.importFileCode.isNotEmpty ? base.importFileCode : dossier.importFileCode,
        customFileNumber: base.customFileNumber ?? dossier.customFileNumber,
        productSummary: {
          ...base.productSummary,
          if (!base.productSummary.containsKey('total_cbm') || base.totalCbm == 0)
            'total_cbm': dossier.totalCbm,
          if (!base.productSummary.containsKey('total_gross_weight_kg') || base.totalGrossWeightKg == 0)
            'total_gross_weight_kg': dossier.grossWeightKg,
          if (!base.productSummary.containsKey('total_net_weight_kg') || base.totalNetWeightKg == 0)
            'total_net_weight_kg': dossier.netWeightKg ?? 0.0,
          if (!base.productSummary.containsKey('packages_count') || base.packagesCount == 0)
            'packages_count': dossier.totalPackages,
        },
        routeSummary: {
          ...base.routeSummary,
          if (base.originPort == 'غير محدد' && dossier.portOfLoading != null)
            'origin_port': dossier.portOfLoading,
          if (dossier.portOfDischarge != null)
            'destination_port': dossier.portOfDischarge,
          if (base.carrier.isEmpty && carrier.isNotEmpty)
            'shipping_line': carrier,
        },
        criticalDates: {
          ...base.criticalDates,
          if (!base.criticalDates.containsKey('target_free_days'))
            'target_free_days': dossier.targetFreeDays,
        },
        documentStatus: {
          ...base.documentStatus,
          if (dossier.acidNumber != null) 'acid_number': dossier.acidNumber,
          if (dossier.form4No != null) 'form4_no': dossier.form4No,
        },
        matchedGuideEntries: base.matchedGuideEntries,
        costSummary: {
          ...base.costSummary,
          if (dossier.actualLandedCostTotalEgp > 0)
            'actual_invoiced_cost': dossier.actualLandedCostTotalEgp,
          if (dossier.actualLandedCostVarianceEgp != 0)
            'variance_amount': dossier.actualLandedCostVarianceEgp,
          if (dossier.actualLandedCostVariancePct != 0)
            'variance_percentage': dossier.actualLandedCostVariancePct,
        },
      );
    }
    return SmartReferenceCardModel(
      importFileId: dossier.importFileId,
      importFileCode: dossier.importFileCode,
      customFileNumber: dossier.customFileNumber,
      productSummary: {
        'hs_code': '',
        'product_category': dossier.commodity ?? '',
        'total_cbm': dossier.totalCbm,
        'total_gross_weight_kg': dossier.grossWeightKg,
        'total_net_weight_kg': dossier.netWeightKg ?? 0.0,
        'packages_count': dossier.totalPackages,
      },
      routeSummary: {
        'origin_port': dossier.portOfLoading ?? 'Shanghai Port',
        'destination_port': dossier.portOfDischarge,
        'shipping_line': carrier,
        'incoterm_code': dossier.incotermCode,
        'shipment_mode': dossier.shipmentMode,
      },
      criticalDates: {
        'target_free_days': dossier.targetFreeDays,
      },
      documentStatus: {
        'is_complete': isReady,
        'acid_number': dossier.acidNumber,
        'form4_no': dossier.form4No,
      },
      matchedGuideEntries: const [],
      costSummary: {
        'actual_invoiced_cost': dossier.actualLandedCostTotalEgp,
        'variance_amount': dossier.actualLandedCostVarianceEgp,
        'variance_percentage': dossier.actualLandedCostVariancePct,
        'currency': 'EGP',
      },
    );
  }

  // Convenient helper getters
  String get hsCode => (productSummary['hs_code'] as String?) ?? '';
  String get productCategory => (productSummary['product_category'] as String?) ?? '';
  double get totalCbm => (productSummary['total_cbm'] as num?)?.toDouble() ?? 0.0;
  double get totalGrossWeightKg => (productSummary['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0;
  double get totalNetWeightKg => (productSummary['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0;
  int get packagesCount => (productSummary['packages_count'] as num?)?.toInt() ?? 0;

  List<String> get allHsCodes {
    final list = productSummary['all_hs_codes'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => e.toString()).toList();
    }
    if (hsSummaries.isNotEmpty) {
      return hsSummaries.map((e) => e.hsCode).toList();
    }
    if (hsCode.isNotEmpty) {
      return [hsCode];
    }
    return [];
  }

  List<HsCodeSummaryModel> get hsSummaries {
    final list = productSummary['hs_summaries'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.map((e) => HsCodeSummaryModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  String get originPort => (routeSummary['origin_port'] as String?) ?? 'غير محدد';
  String get destinationPort => (routeSummary['destination_port'] as String?) ?? 'ميناء الإسكندرية';
  String get carrier => (routeSummary['shipping_line'] as String?) ?? '';

  int get freeDays => (criticalDates['target_free_days'] as num?)?.toInt() ?? 21;
  String get freeTimeStatus => (criticalDates['free_time_status'] as String?) ?? '';

  bool get isDocsComplete => documentStatus['is_complete'] as bool? ?? false;
  bool get hasCooAttached => documentStatus['has_coo_attached'] as bool? ?? false;
  bool get isCooRequired => documentStatus['is_coo_required'] as bool? ?? false;
  List<String> get attachedDocuments => (documentStatus['attached_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  List<String> get pendingDocuments => (documentStatus['pending_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

  double get estimatedCost => (costSummary['estimated_cost'] as num?)?.toDouble() ?? 0.0;
  double get actualCost => (costSummary['actual_invoiced_cost'] as num?)?.toDouble() ?? 0.0;
  double get varianceAmount => (costSummary['variance_amount'] as num?)?.toDouble() ?? 0.0;
  double get variancePercentage => (costSummary['variance_percentage'] as num?)?.toDouble() ?? 0.0;
  String get currency => (costSummary['currency'] as String?) ?? 'USD';
}

class HsCodeSummaryModel {
  final String hsCode;
  final String description;
  final double cbm;
  final double grossWeightKg;
  final double netWeightKg;
  final int packagesCount;
  final double quantityPcs;

  HsCodeSummaryModel({
    required this.hsCode,
    required this.description,
    required this.cbm,
    required this.grossWeightKg,
    required this.netWeightKg,
    required this.packagesCount,
    required this.quantityPcs,
  });

  factory HsCodeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HsCodeSummaryModel(
      hsCode: (json['hs_code'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      cbm: (json['cbm'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      packagesCount: (json['packages_count'] as num?)?.toInt() ?? 0,
      quantityPcs: (json['quantity_pcs'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

