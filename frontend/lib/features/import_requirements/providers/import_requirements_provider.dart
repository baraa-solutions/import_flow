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

  /// Evaluates whether an HS Code is subject to adaptive shelf-life & consumer labeling rules.
  /// Chapters 01-24: Food & Agricultural
  /// Chapter 30: Pharmaceuticals & Medical Supplies
  /// Chapter 33: Cosmetics & Essential Oils
  /// Chapter 38: Chemical products with finite shelf-life
  static bool isPerishableOrConsumerGoods(String hsCode) {
    final clean = hsCode.replaceAll('.', '').trim();
    if (clean.length < 2) return false;
    final prefix = clean.substring(0, 2);
    final prefixNum = int.tryParse(prefix);
    if (prefixNum != null && prefixNum >= 1 && prefixNum <= 24) return true;
    return prefix == '30' || prefix == '33' || prefix == '38';
  }

  /// Validates whether the HS Code is covered in the company's import card commodity groups.
  static bool isCommodityGroupCovered(String hsCode, List<String> registeredGroups) {
    if (registeredGroups.isEmpty) return true; // Default permissive if not configured
    final clean = hsCode.replaceAll('.', '').trim();
    if (clean.length < 2) return true;
    final chapter = clean.substring(0, 2);
    return registeredGroups.any((g) => g.contains(chapter) || g.contains(clean.substring(0, clean.length >= 4 ? 4 : 2)));
  }

  /// Determines whether the shipment is cleared and ready for ACID application on Nafeza/CargoX.
  static bool assessPreAcidReadiness({
    required bool cargoxVerified,
    required bool decree43Ok,
    required bool commodityGroupMatched,
  }) {
    return cargoxVerified && decree43Ok && commodityGroupMatched;
  }
}
