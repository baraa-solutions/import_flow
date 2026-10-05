import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/import_requirement_model.dart';
import '../../../core/network/api_client.dart';


import '../../../core/constants/api_constants.dart';

final importRequirementsProvider = AsyncNotifierProvider<ImportRequirementsNotifier, List<ImportRequirementModel>>(() {
  return ImportRequirementsNotifier();
});

class ImportRequirementsNotifier extends AsyncNotifier<List<ImportRequirementModel>> {
  Dio get _dio => ref.read(dioProvider);
  final String _baseUrl = ApiConstants.baseUrl;
  CancelToken? _cancelToken;

  @override
  Future<List<ImportRequirementModel>> build() async {
    ref.onDispose(() {
      _cancelToken?.cancel();
    });
    return _fetchRequirements();
  }

  Future<List<ImportRequirementModel>> _fetchRequirements({int? importFileId}) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{
        'include_inactive': true,
      };
      if (importFileId != null) {
        queryParams['import_file_id'] = importFileId;
      }

      final response = await _dio.get('$_baseUrl/import-requirements', queryParameters: queryParams, cancelToken: _cancelToken);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ImportRequirementModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return [];
      }
      throw Exception('Failed to fetch import requirements: $e');
    }
  }

  Future<void> fetchByFileId(int? fileId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRequirements(importFileId: fileId));
  }

  Future<void> refreshData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRequirements());
  }

  Future<void> addRequirement(Map<String, dynamic> data) async {
    try {
      await _dio.post('$_baseUrl/import-requirements', data: data);
      await refreshData();
    } catch (e) {
      // Keep the DioException: the screen renders 403 / coded 409 details from it.
      if (e is DioException) rethrow;
      throw Exception('Failed to add requirement: $e');
    }
  }

  Future<void> updateRequirement(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put('$_baseUrl/import-requirements/$id', data: data);
      await refreshData();
    } catch (e) {
      // Keep the DioException: the screen renders 403 / coded 409 details from it.
      if (e is DioException) rethrow;
      throw Exception('Failed to update requirement: $e');
    }
  }

  Future<void> restoreRequirement(int id) async {
    try {
      await _dio.post('$_baseUrl/import-requirements/$id/restore');
      await refreshData();
    } catch (e) {
      // Keep the DioException: the screen renders 403 / coded 409 details from it.
      if (e is DioException) rethrow;
      throw Exception('Failed to restore requirement: $e');
    }
  }

  Future<ImportRequirementPrefillModel?> fetchPrefillData(int importFileId) async {
    try {
      final response = await _dio.get('$_baseUrl/import-requirements/prefill/$importFileId');
      if (response.statusCode == 200) {
        return ImportRequirementPrefillModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // 404 (inactive import file) / 403: let the screen show it.
      if (e is DioException) rethrow;
      return null;
    }
  }

  Future<void> deleteRequirement(int id) async {
    try {
      await _dio.delete('$_baseUrl/import-requirements/$id');
      await refreshData();
    } catch (e) {
      if (e is DioException) rethrow;
      throw Exception('Failed to delete requirement: $e');
    }
  }
}

