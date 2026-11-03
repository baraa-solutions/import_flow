import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

class LogisticsExceptionModel {
  final int id;
  final String exceptionCode;
  final int? importFileId;
  final int? shipmentId;
  final String exceptionType;
  final String severity;
  final String titleAr;
  final String titleEn;
  final String? description;
  final int delayImpactDays;
  final String? acidNumber;
  final String? acidOriginalExpiry;
  final String? acidAdjustedExpiry;
  final String acidImpactStatus;
  final bool delayKpiSuspended;
  final String? suspensionReason;
  final double? valuationDisputeAmount;
  final double? valuationOriginalCustomsVal;
  final double? valuationDeclaredVal;
  final String? appealStatus;
  final String? resolutionStrategy;
  final String status;
  final String? resolvedAt;
  final String createdAt;

  const LogisticsExceptionModel({
    required this.id,
    required this.exceptionCode,
    this.importFileId,
    this.shipmentId,
    required this.exceptionType,
    required this.severity,
    required this.titleAr,
    required this.titleEn,
    this.description,
    required this.delayImpactDays,
    this.acidNumber,
    this.acidOriginalExpiry,
    this.acidAdjustedExpiry,
    required this.acidImpactStatus,
    required this.delayKpiSuspended,
    this.suspensionReason,
    this.valuationDisputeAmount,
    this.valuationOriginalCustomsVal,
    this.valuationDeclaredVal,
    this.appealStatus,
    this.resolutionStrategy,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
  });

  factory LogisticsExceptionModel.fromJson(Map<String, dynamic> json) {
    return LogisticsExceptionModel(
      id: json['id'] as int,
      exceptionCode: json['exception_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int?,
      shipmentId: json['shipment_id'] as int?,
      exceptionType: json['exception_type'] as String? ?? 'OTHER',
      severity: json['severity'] as String? ?? 'MEDIUM',
      titleAr: json['title_ar'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      description: json['description'] as String?,
      delayImpactDays: json['delay_impact_days'] as int? ?? 0,
      acidNumber: json['acid_number'] as String?,
      acidOriginalExpiry: json['acid_original_expiry'] as String?,
      acidAdjustedExpiry: json['acid_adjusted_expiry'] as String?,
      acidImpactStatus: json['acid_impact_status'] as String? ?? 'NOT_AFFECTED',
      delayKpiSuspended: json['delay_kpi_suspended'] as bool? ?? false,
      suspensionReason: json['suspension_reason'] as String?,
      valuationDisputeAmount: (json['valuation_dispute_amount'] as num?)?.toDouble(),
      valuationOriginalCustomsVal: (json['valuation_original_customs_val'] as num?)?.toDouble(),
      valuationDeclaredVal: (json['valuation_declared_val'] as num?)?.toDouble(),
      appealStatus: json['appeal_status'] as String?,
      resolutionStrategy: json['resolution_strategy'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'import_file_id': importFileId,
    'shipment_id': shipmentId,
    'exception_type': exceptionType,
    'severity': severity,
    'title_ar': titleAr,
    'title_en': titleEn,
    'description': description,
    'delay_impact_days': delayImpactDays,
    'acid_number': acidNumber,
    'acid_original_expiry': acidOriginalExpiry,
    'acid_adjusted_expiry': acidAdjustedExpiry,
    'acid_impact_status': acidImpactStatus,
    'delay_kpi_suspended': delayKpiSuspended,
    'suspension_reason': suspensionReason,
    'valuation_dispute_amount': valuationDisputeAmount,
    'valuation_original_customs_val': valuationOriginalCustomsVal,
    'valuation_declared_val': valuationDeclaredVal,
    'appeal_status': appealStatus,
    'resolution_strategy': resolutionStrategy,
  };
}

class ExceptionMetricsModel {
  final int totalExceptions;
  final int openExceptions;
  final int criticalExceptions;
  final int acidImpactedCount;
  final int kpiSuspendedCount;
  final double totalDisputeAmountEgp;

  const ExceptionMetricsModel({
    required this.totalExceptions,
    required this.openExceptions,
    required this.criticalExceptions,
    required this.acidImpactedCount,
    required this.kpiSuspendedCount,
    required this.totalDisputeAmountEgp,
  });

  factory ExceptionMetricsModel.fromJson(Map<String, dynamic> json) {
    return ExceptionMetricsModel(
      totalExceptions: json['total_exceptions'] as int? ?? 0,
      openExceptions: json['open_exceptions'] as int? ?? 0,
      criticalExceptions: json['critical_exceptions'] as int? ?? 0,
      acidImpactedCount: json['acid_impacted_count'] as int? ?? 0,
      kpiSuspendedCount: json['kpi_suspended_count'] as int? ?? 0,
      totalDisputeAmountEgp: (json['total_dispute_amount_egp'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static const empty = ExceptionMetricsModel(
    totalExceptions: 0,
    openExceptions: 0,
    criticalExceptions: 0,
    acidImpactedCount: 0,
    kpiSuspendedCount: 0,
    totalDisputeAmountEgp: 0.0,
  );
}

final logisticsExceptionsProvider = FutureProvider.autoDispose<List<LogisticsExceptionModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/logistics-exceptions?size=100');
  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>?) ?? [];
  return items.map((e) => LogisticsExceptionModel.fromJson(e as Map<String, dynamic>)).toList();
});

final exceptionMetricsProvider = FutureProvider.autoDispose<ExceptionMetricsModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/logistics-exceptions/metrics');
  return ExceptionMetricsModel.fromJson(response.data as Map<String, dynamic>);
});

class LogisticsExceptionsActions {
  final Ref ref;
  LogisticsExceptionsActions(this.ref);

  Future<void> createException(Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post('${ApiConstants.baseUrl}/api/v1/logistics-exceptions', data: payload);
    ref.invalidate(logisticsExceptionsProvider);
    ref.invalidate(exceptionMetricsProvider);
  }

  Future<void> resolveAcid(int id, String adjustedDate, String status, String? notes) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/logistics-exceptions/$id/acid-resolve',
      data: {
        'acid_adjusted_expiry': adjustedDate,
        'acid_impact_status': status,
        'notes': notes,
      },
    );
    ref.invalidate(logisticsExceptionsProvider);
    ref.invalidate(exceptionMetricsProvider);
  }

  Future<void> submitValuationAppeal(int id, Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/logistics-exceptions/$id/valuation-appeal',
      data: payload,
    );
    ref.invalidate(logisticsExceptionsProvider);
    ref.invalidate(exceptionMetricsProvider);
  }

  Future<void> resolveException(int id, String strategy) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/logistics-exceptions/$id/resolve',
      data: {
        'resolution_strategy': strategy,
        'status': 'RESOLVED',
      },
    );
    ref.invalidate(logisticsExceptionsProvider);
    ref.invalidate(exceptionMetricsProvider);
  }
}

final logisticsExceptionsActionsProvider = Provider((ref) => LogisticsExceptionsActions(ref));
