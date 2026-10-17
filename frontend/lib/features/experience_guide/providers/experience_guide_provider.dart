import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/guide_entry_model.dart';
import '../models/smart_reference_card_model.dart';
import '../models/similar_shipment_model.dart';
import '../models/detected_pattern_model.dart';

final experienceGuideProvider =
    StateNotifierProvider<ExperienceGuideNotifier, AsyncValue<List<GuideEntryModel>>>((ref) {
  return ExperienceGuideNotifier(ref.read(dioProvider));
});

final smartReferenceCardProvider =
    FutureProvider.autoDispose.family<SmartReferenceCardModel, int>((ref, importFileId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('${ApiConstants.experienceGuide}/reference-card/$importFileId');
  return SmartReferenceCardModel.fromJson(response.data);
});

final similarShipmentsProvider =
    FutureProvider.autoDispose.family<List<SimilarShipmentModel>, int>((ref, importFileId) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('${ApiConstants.experienceGuide}/similar-shipments/$importFileId');
    final List<dynamic> data = response.data;
    return data.map((e) => SimilarShipmentModel.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});

final detectedPatternsProvider =
    FutureProvider.autoDispose<List<DetectedPatternModel>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('${ApiConstants.experienceGuide}/detected-patterns');
    final List<dynamic> data = response.data;
    return data.map((e) => DetectedPatternModel.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});

final autonomousAuditLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('${ApiConstants.experienceGuide}/autonomous/audit-log');
    final List<dynamic> data = response.data;
    return data.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class ExperienceGuideNotifier extends StateNotifier<AsyncValue<List<GuideEntryModel>>> {
  final Dio _dio;

  ExperienceGuideNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchEntries();
  }

  Future<void> fetchEntries({
    String? search,
    String? scopeType,
    String? scopeValue,
    bool? isActive,
    String? severity,
    String? department,
    String? sourceType,
    String? status,
  }) async {
    try {
      state = const AsyncValue.loading();
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (scopeType != null && scopeType.isNotEmpty) queryParams['scope_type'] = scopeType;
      if (scopeValue != null && scopeValue.isNotEmpty) queryParams['scope_value'] = scopeValue;
      if (isActive != null) queryParams['is_active'] = isActive;
      if (severity != null && severity.isNotEmpty) queryParams['severity'] = severity;
      if (department != null && department.isNotEmpty) queryParams['department'] = department;
      if (sourceType != null && sourceType.isNotEmpty) queryParams['source_type'] = sourceType;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _dio.get(
        ApiConstants.experienceGuide,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data;
      final entries = data.map((e) => GuideEntryModel.fromJson(e)).toList();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<GuideEntryModel> createEntry(Map<String, dynamic> data) async {
    final response = await _dio.post(
      ApiConstants.experienceGuide,
      data: data,
    );
    final created = GuideEntryModel.fromJson(response.data);
    await fetchEntries();
    return created;
  }

  Future<GuideEntryModel> updateEntry(int entryId, Map<String, dynamic> data) async {
    final response = await _dio.put(
      '${ApiConstants.experienceGuide}/$entryId',
      data: data,
    );
    final updated = GuideEntryModel.fromJson(response.data);
    await fetchEntries();
    return updated;
  }

  Future<bool> deleteEntry(int entryId) async {
    final response = await _dio.delete('${ApiConstants.experienceGuide}/$entryId');
    await fetchEntries();
    return response.statusCode == 200;
  }

  Future<bool> upvoteEntry(int entryId) async {
    try {
      final response = await _dio.post('${ApiConstants.experienceGuide}/$entryId/upvote');
      if (response.statusCode == 200) {
        state.whenData((entries) {
          final updated = entries.map((e) {
            if (e.entryId == entryId) {
              return GuideEntryModel.fromJson({
                ...e.toJson(),
                'upvotes': e.upvotes + 1,
              });
            }
            return e;
          }).toList();
          state = AsyncValue.data(updated);
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Section 5A: Autonomous Reference Engine Methods

  Future<ProvenanceModel?> fetchEntryProvenance(int entryId) async {
    try {
      final response = await _dio.get('${ApiConstants.experienceGuide}/$entryId/provenance');
      return ProvenanceModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<GuideEntryModel?> promoteInferredEntry(
    int entryId, {
    String? promotedBy,
    String? editedTitle,
    String? editedContent,
    String? editedSeverity,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.experienceGuide}/$entryId/promote',
        data: {
          'promoted_by': promotedBy ?? 'Authorized User',
          if (editedTitle != null && editedTitle.isNotEmpty) 'edited_title': editedTitle,
          if (editedContent != null && editedContent.isNotEmpty) 'edited_content': editedContent,
          if (editedSeverity != null && editedSeverity.isNotEmpty) 'edited_severity': editedSeverity,
        },
      );
      final promoted = GuideEntryModel.fromJson(response.data);
      await fetchEntries();
      return promoted;
    } catch (_) {
      return null;
    }
  }

  Future<GuideEntryModel?> rejectInferredEntry(
    int entryId, {
    required String rejectionReason,
    String? rejectedBy,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.experienceGuide}/$entryId/reject',
        data: {
          'rejected_by': rejectedBy ?? 'Authorized User',
          'rejection_reason': rejectionReason,
        },
      );
      final rejected = GuideEntryModel.fromJson(response.data);
      await fetchEntries();
      return rejected;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> recalculateAutonomousEngine() async {
    try {
      final response = await _dio.post('${ApiConstants.experienceGuide}/autonomous/recalculate');
      await fetchEntries();
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<List<GuideEntryModel>> searchEntries(String query) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.experienceGuide}/search',
        queryParameters: {'q': query},
      );
      final List<dynamic> data = response.data;
      return data.map((e) => GuideEntryModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Matches guide entries for an import file using its supplier, HS code,
  /// product category, ports, incoterm and file code.
  Future<GuideMatchResultModel> matchImportFile(ImportFileModel f) => matchShipment(
        supplier: f.supplierName,
        hsCode: f.hsCode,
        productCategory: f.productCategory,
        portOfLoading: f.portOfLoading,
        portOfDischarge: f.portOfDischarge,
        incoterm: f.incotermCode,
        importFileReference: f.importFileCode,
      );

  Future<GuideMatchResultModel> matchShipment({
    String? hsCode,
    String? productCategory,
    String? portOfDischarge,
    String? destinationPort,
    String? portOfLoading,
    String? supplier,
    String? countryOfOrigin,
    String? shippingLine,
    String? incoterm,
    String? paymentMethod,
    String? certificateType,
    String? customsBroker,
    String? seasonTiming,
    String? importFileReference,
  }) async {
    try {
      final finalDischarge = portOfDischarge ?? destinationPort;
      final response = await _dio.post(
        '${ApiConstants.experienceGuide}/match',
        data: {
          if (hsCode != null && hsCode.isNotEmpty) 'hs_code': hsCode,
          if (productCategory != null && productCategory.isNotEmpty) 'product_category': productCategory,
          if (finalDischarge != null && finalDischarge.isNotEmpty) 'port_of_discharge': finalDischarge,
          if (portOfLoading != null && portOfLoading.isNotEmpty) 'port_of_loading': portOfLoading,
          if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
          if (countryOfOrigin != null && countryOfOrigin.isNotEmpty) 'country_of_origin': countryOfOrigin,
          if (shippingLine != null && shippingLine.isNotEmpty) 'shipping_line': shippingLine,
          if (incoterm != null && incoterm.isNotEmpty) 'incoterm': incoterm,
          if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
          if (certificateType != null && certificateType.isNotEmpty) 'certificate_type': certificateType,
          if (customsBroker != null && customsBroker.isNotEmpty) 'customs_broker': customsBroker,
          if (seasonTiming != null && seasonTiming.isNotEmpty) 'season_timing': seasonTiming,
          if (importFileReference != null && importFileReference.isNotEmpty) 'import_file_reference': importFileReference,
        },
      );
      return GuideMatchResultModel.fromJson(response.data);
    } catch (_) {
      return GuideMatchResultModel();
    }
  }
}
