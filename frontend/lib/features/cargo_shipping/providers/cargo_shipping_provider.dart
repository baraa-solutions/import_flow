import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/cargo_shipping_model.dart';
import '../../../core/network/api_client.dart';


final cargoShippingProvider =
    StateNotifierProvider<CargoShippingNotifier, AsyncValue<List<CargoShippingModel>>>((ref) {
  return CargoShippingNotifier(ref.read(dioProvider));
});

class CargoShippingNotifier extends StateNotifier<AsyncValue<List<CargoShippingModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  CargoShippingNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchRecords();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CargoShippingNotifier disposed');
    super.dispose();
  }

  int? totalCount;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  // Filters of the last fetch, reused by loadMore so the next page matches the visible list.
  bool _lastIncludeInactive = true;
  int? _lastImportFileId;
  String? _lastStatus;
  String? _lastSearch;

  bool get hasMore => totalCount != null && (state.valueOrNull?.length ?? 0) < totalCount!;

  Future<void> fetchRecords({
    bool includeInactive = true,
    int? importFileId,
    String? status,
    String? search,
    int skip = 0,
    int limit = 200,
  }) async {
    _lastIncludeInactive = includeInactive;
    _lastImportFileId = importFileId;
    _lastStatus = status;
    _lastSearch = search;
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
        'skip': skip,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/cargo-shipping',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final totalHeader = response.headers.value('x-total-count');
      if (totalHeader != null) {
        totalCount = int.tryParse(totalHeader);
      }

      final List data = response.data;
      final list = data.map((json) => CargoShippingModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore({
    bool? includeInactive,
    int? importFileId,
    String? status,
    String? search,
    int limit = 200,
  }) async {
    includeInactive ??= _lastIncludeInactive;
    importFileId ??= _lastImportFileId;
    status ??= _lastStatus;
    search ??= _lastSearch;
    if (_isLoadingMore || !hasMore) return;
    final currentList = state.valueOrNull ?? [];
    _isLoadingMore = true;
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
        'skip': currentList.length,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/cargo-shipping',
        queryParameters: queryParams,
      );

      final totalHeader = response.headers.value('x-total-count');
      if (totalHeader != null) {
        totalCount = int.tryParse(totalHeader);
      }

      final List data = response.data;
      final nextItems = data.map((json) => CargoShippingModel.fromJson(json)).toList();
      state = AsyncValue.data([...currentList, ...nextItems]);
    } catch (e) {
      // Keep existing data on pagination failure
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<CargoShippingModel?> createRecord(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping',
        data: payload,
      );
      final created = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> updateRecord(int recordId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId',
        data: payload,
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> updateContainerTracking(
    int recordId,
    String containerNo,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId/containers/$containerNo/loading-tracking',
        data: payload,
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> updateLclTracking(
    int recordId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId/loading-tracking/lcl',
        data: payload,
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> submitLevel1Approval(int recordId, String approvedBy, bool approved, {String? notes}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId/approval/level1',
        data: {'approved_by': approvedBy, 'approved': approved, 'notes': notes},
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> submitLevel2Approval(int recordId, String approvedBy, bool approved, {String? notes}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId/approval/level2',
        data: {'approved_by': approvedBy, 'approved': approved, 'notes': notes},
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> runCargoXChecklist(int recordId) async {
    try {
      final response = await _dio.post('${ApiConstants.baseUrl}/cargo-shipping/$recordId/cargox/run-checklist');
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> advanceCargoXStage(int recordId, String targetStage) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-shipping/$recordId/cargox/advance-stage',
        queryParameters: {'target_stage': targetStage},
      );
      final updated = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteRecord(int recordId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/cargo-shipping/$recordId');
      await fetchRecords();
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoShippingModel?> restoreRecord(int recordId) async {
    try {
      final response = await _dio.post('${ApiConstants.baseUrl}/cargo-shipping/$recordId/restore');
      final restored = CargoShippingModel.fromJson(response.data);
      await fetchRecords();
      return restored;
    } catch (e) {
      rethrow;
    }
  }
}
