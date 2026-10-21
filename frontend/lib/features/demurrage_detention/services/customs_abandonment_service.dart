import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/customs_abandonment_model.dart';

final customsAbandonmentServiceProvider = Provider<CustomsAbandonmentService>((ref) {
  final dio = ref.watch(dioProvider);
  return CustomsAbandonmentService(dio);
});

class CustomsAbandonmentService {
  final Dio _dio;

  CustomsAbandonmentService(this._dio);

  Future<List<CustomsAbandonmentRadarModel>> listRadars({
    String? riskLevel,
    String? portType,
    String? abandonmentStatus,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (riskLevel != null && riskLevel != 'All') query['risk_level'] = riskLevel;
    if (portType != null && portType != 'All') query['port_type'] = portType;
    if (abandonmentStatus != null && abandonmentStatus != 'All') query['abandonment_status'] = abandonmentStatus;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await _dio.get('/api/v1/customs-abandonment', queryParameters: query);
    final data = response.data as List;
    return data.map((e) => CustomsAbandonmentRadarModel.fromJson(e)).toList();
  }

  Future<CustomsAbandonmentSummaryModel> getSummary() async {
    final response = await _dio.get('/api/v1/customs-abandonment/summary');
    return CustomsAbandonmentSummaryModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> recalculate() async {
    final response = await _dio.post('/api/v1/customs-abandonment/recalculate');
    return Map<String, dynamic>.from(response.data);
  }

  Future<CustomsAbandonmentRadarModel> requestExtension(
    int radarId, {
    required String reason,
    int requestedDays = 30,
    String? extensionRequestRef,
    String? actionPlan,
  }) async {
    final response = await _dio.post(
      '/api/v1/customs-abandonment/$radarId/request-extension',
      data: {
        'reason': reason,
        'requested_days': requestedDays,
        'extension_request_ref': extensionRequestRef,
        'action_plan': actionPlan,
      },
    );
    return CustomsAbandonmentRadarModel.fromJson(response.data);
  }

  Future<CustomsAbandonmentRadarModel> grantExtension(
    int radarId, {
    required String extensionGrantedUntil,
    String? officialApprovalRef,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/api/v1/customs-abandonment/$radarId/grant-extension',
      data: {
        'extension_granted_until': extensionGrantedUntil,
        'official_approval_ref': officialApprovalRef,
        'notes': notes,
      },
    );
    return CustomsAbandonmentRadarModel.fromJson(response.data);
  }

  Future<ExtensionLetterDraftModel> getLetterDraft(int radarId) async {
    final response = await _dio.get('/api/v1/customs-abandonment/$radarId/letter-draft');
    return ExtensionLetterDraftModel.fromJson(response.data);
  }
}
