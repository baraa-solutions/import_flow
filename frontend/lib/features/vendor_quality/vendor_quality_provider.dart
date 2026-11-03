import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

class VendorQualityModel {
  final int id;
  final String assessmentCode;
  final int? vendorId;
  final String vendorName;
  final int? purchaseOrderId;
  final int? importFileId;
  final String inspectionAgency;
  final String? psiCertificateNumber;
  final String? inspectionDate;
  final String psiResult;
  final int defectsCount;
  final int criticalDefectsCount;
  final String? inspectionCertificateFile;
  final double qualityScore;
  final double deliveryTimelinessScore;
  final double documentationAccuracyScore;
  final double complianceScore;
  final double overallVendorRating;
  final String ratingGrade;
  final bool correctiveActionRequired;
  final String? correctiveActionPlan;
  final String? inspectorNotes;
  final String createdAt;

  const VendorQualityModel({
    required this.id,
    required this.assessmentCode,
    this.vendorId,
    required this.vendorName,
    this.purchaseOrderId,
    this.importFileId,
    required this.inspectionAgency,
    this.psiCertificateNumber,
    this.inspectionDate,
    required this.psiResult,
    required this.defectsCount,
    required this.criticalDefectsCount,
    this.inspectionCertificateFile,
    required this.qualityScore,
    required this.deliveryTimelinessScore,
    required this.documentationAccuracyScore,
    required this.complianceScore,
    required this.overallVendorRating,
    required this.ratingGrade,
    required this.correctiveActionRequired,
    this.correctiveActionPlan,
    this.inspectorNotes,
    required this.createdAt,
  });

  factory VendorQualityModel.fromJson(Map<String, dynamic> json) {
    return VendorQualityModel(
      id: json['id'] as int,
      assessmentCode: json['assessment_code'] as String? ?? '',
      vendorId: json['vendor_id'] as int?,
      vendorName: json['vendor_name'] as String? ?? '',
      purchaseOrderId: json['purchase_order_id'] as int?,
      importFileId: json['import_file_id'] as int?,
      inspectionAgency: json['inspection_agency'] as String? ?? 'SGS',
      psiCertificateNumber: json['psi_certificate_number'] as String?,
      inspectionDate: json['inspection_date'] as String?,
      psiResult: json['psi_result'] as String? ?? 'PENDING',
      defectsCount: json['defects_count'] as int? ?? 0,
      criticalDefectsCount: json['critical_defects_count'] as int? ?? 0,
      inspectionCertificateFile: json['inspection_certificate_file'] as String?,
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 100.0,
      deliveryTimelinessScore: (json['delivery_timeliness_score'] as num?)?.toDouble() ?? 100.0,
      documentationAccuracyScore: (json['documentation_accuracy_score'] as num?)?.toDouble() ?? 100.0,
      complianceScore: (json['compliance_score'] as num?)?.toDouble() ?? 100.0,
      overallVendorRating: (json['overall_vendor_rating'] as num?)?.toDouble() ?? 100.0,
      ratingGrade: json['rating_grade'] as String? ?? 'A',
      correctiveActionRequired: json['corrective_action_required'] as bool? ?? false,
      correctiveActionPlan: json['corrective_action_plan'] as String?,
      inspectorNotes: json['inspector_notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'vendor_id': vendorId,
    'vendor_name': vendorName,
    'purchase_order_id': purchaseOrderId,
    'import_file_id': importFileId,
    'inspection_agency': inspectionAgency,
    'psi_certificate_number': psiCertificateNumber,
    'inspection_date': inspectionDate,
    'psi_result': psiResult,
    'defects_count': defectsCount,
    'critical_defects_count': criticalDefectsCount,
    'inspection_certificate_file': inspectionCertificateFile,
    'quality_score': qualityScore,
    'delivery_timeliness_score': deliveryTimelinessScore,
    'documentation_accuracy_score': documentationAccuracyScore,
    'compliance_score': complianceScore,
    'corrective_action_required': correctiveActionRequired,
    'corrective_action_plan': correctiveActionPlan,
    'inspector_notes': inspectorNotes,
  };
}

class VendorRankingModel {
  final int? vendorId;
  final String vendorName;
  final int inspectionsCount;
  final int passedCount;
  final int failedCount;
  final double avgQualityScore;
  final double avgDeliveryTimeliness;
  final double avgDocumentationAccuracy;
  final double avgCompliance;
  final double avgOverallRating;
  final String currentGrade;

  const VendorRankingModel({
    this.vendorId,
    required this.vendorName,
    required this.inspectionsCount,
    required this.passedCount,
    required this.failedCount,
    required this.avgQualityScore,
    required this.avgDeliveryTimeliness,
    required this.avgDocumentationAccuracy,
    required this.avgCompliance,
    required this.avgOverallRating,
    required this.currentGrade,
  });

  factory VendorRankingModel.fromJson(Map<String, dynamic> json) {
    return VendorRankingModel(
      vendorId: json['vendor_id'] as int?,
      vendorName: json['vendor_name'] as String? ?? '',
      inspectionsCount: json['inspections_count'] as int? ?? 0,
      passedCount: json['passed_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      avgQualityScore: (json['avg_quality_score'] as num?)?.toDouble() ?? 100.0,
      avgDeliveryTimeliness: (json['avg_delivery_timeliness'] as num?)?.toDouble() ?? 100.0,
      avgDocumentationAccuracy: (json['avg_documentation_accuracy'] as num?)?.toDouble() ?? 100.0,
      avgCompliance: (json['avg_compliance'] as num?)?.toDouble() ?? 100.0,
      avgOverallRating: (json['avg_overall_rating'] as num?)?.toDouble() ?? 100.0,
      currentGrade: json['current_grade'] as String? ?? 'A',
    );
  }
}

final vendorQualityProvider = FutureProvider.autoDispose<List<VendorQualityModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/vendor-quality?size=100');
  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>?) ?? [];
  return items.map((e) => VendorQualityModel.fromJson(e as Map<String, dynamic>)).toList();
});

final vendorRankingsProvider = FutureProvider.autoDispose<List<VendorRankingModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/api/v1/vendor-quality/rankings');
  final data = response.data as Map<String, dynamic>;
  final items = (data['rankings'] as List<dynamic>?) ?? [];
  return items.map((e) => VendorRankingModel.fromJson(e as Map<String, dynamic>)).toList();
});

class VendorQualityActions {
  final Ref ref;
  VendorQualityActions(this.ref);

  Future<void> createAssessment(Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post('${ApiConstants.baseUrl}/api/v1/vendor-quality', data: payload);
    ref.invalidate(vendorQualityProvider);
    ref.invalidate(vendorRankingsProvider);
  }

  Future<void> uploadPsi(int id, Map<String, dynamic> payload) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '${ApiConstants.baseUrl}/api/v1/vendor-quality/$id/upload-psi',
      data: payload,
    );
    ref.invalidate(vendorQualityProvider);
    ref.invalidate(vendorRankingsProvider);
  }
}

final vendorQualityActionsProvider = Provider((ref) => VendorQualityActions(ref));
