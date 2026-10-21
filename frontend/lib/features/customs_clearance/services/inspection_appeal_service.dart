import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/inspection_appeal_model.dart';

final inspectionAppealServiceProvider = Provider<InspectionAppealService>((ref) {
  final dio = ref.watch(dioProvider);
  return InspectionAppealService(dio);
});

class InspectionAppealService {
  final Dio _dio;

  InspectionAppealService(this._dio);

  Future<List<InspectionAppealModel>> listAppeals({
    int? importFileId,
    int? clearanceId,
    String? regulatoryAuthority,
    String? appealTier,
    String? appealResult,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{
      'include_inactive': includeInactive,
    };
    if (importFileId != null) query['import_file_id'] = importFileId;
    if (clearanceId != null) query['clearance_id'] = clearanceId;
    if (regulatoryAuthority != null && regulatoryAuthority != 'All') {
      query['regulatory_authority'] = regulatoryAuthority;
    }
    if (appealTier != null && appealTier != 'All') query['appeal_tier'] = appealTier;
    if (appealResult != null && appealResult != 'All') query['appeal_result'] = appealResult;

    final response = await _dio.get('/api/v1/inspection-appeals', queryParameters: query);
    final data = response.data['items'] as List;
    return data.map((e) => InspectionAppealModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InspectionAppealModel> getAppeal(int appealId) async {
    final response = await _dio.get('/api/v1/inspection-appeals/$appealId');
    return InspectionAppealModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InspectionAppealModel> createAppeal({
    required int importFileId,
    int? clearanceId,
    required String regulatoryAuthority,
    String? sampleNumber,
    String? sampleDrawDate,
    required String initialTestResult,
    String? rejectionReason,
    String appealTier = 'FIRST_APPEAL',
    String? appealSubmissionDate,
    String? notes,
  }) async {
    final payload = {
      'import_file_id': importFileId,
      if (clearanceId != null) 'clearance_id': clearanceId,
      'regulatory_authority': regulatoryAuthority,
      if (sampleNumber != null) 'sample_number': sampleNumber,
      if (sampleDrawDate != null) 'sample_draw_date': sampleDrawDate,
      'initial_test_result': initialTestResult,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      'appeal_tier': appealTier,
      if (appealSubmissionDate != null) 'appeal_submission_date': appealSubmissionDate,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/inspection-appeals', data: payload);
    return InspectionAppealModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InspectionAppealModel> progressTier(
    int appealId, {
    required String targetTier,
    String? triplicateLabAssigned,
    String? officialLetterRef,
    String? notes,
  }) async {
    final payload = {
      'target_tier': targetTier,
      if (triplicateLabAssigned != null) 'triplicate_lab_assigned': triplicateLabAssigned,
      if (officialLetterRef != null) 'official_letter_ref': officialLetterRef,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/inspection-appeals/$appealId/progress-tier', data: payload);
    return InspectionAppealModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InspectionAppealModel> recordCommitteeDecision(
    int appealId, {
    required String appealResult,
    String? appealCommitteeDate,
    String? officialLetterRef,
    String? notes,
  }) async {
    final payload = {
      'appeal_result': appealResult,
      if (appealCommitteeDate != null) 'appeal_committee_date': appealCommitteeDate,
      if (officialLetterRef != null) 'official_letter_ref': officialLetterRef,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/inspection-appeals/$appealId/committee-decision', data: payload);
    return InspectionAppealModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InspectionAppealModel> assignTriplicateLab(
    int appealId, {
    required String triplicateLabAssigned,
    String? officialLetterRef,
    String? notes,
  }) async {
    final payload = {
      'triplicate_lab_assigned': triplicateLabAssigned,
      if (officialLetterRef != null) 'official_letter_ref': officialLetterRef,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/inspection-appeals/$appealId/triplicate-lab', data: payload);
    return InspectionAppealModel.fromJson(response.data as Map<String, dynamic>);
  }
}
