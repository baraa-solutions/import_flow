import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/shipment_update_model.dart';

class ShipmentUpdatesState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<ShipmentUpdateLogModel> logs;
  final List<PhaseInspectionModel> inspectedPhases;
  final int? selectedFileId;
  final int totalCount;
  final bool hasMore;

  ShipmentUpdatesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.logs = const [],
    this.inspectedPhases = const [],
    this.selectedFileId,
    this.totalCount = 0,
    this.hasMore = false,
  });

  ShipmentUpdatesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<ShipmentUpdateLogModel>? logs,
    List<PhaseInspectionModel>? inspectedPhases,
    int? selectedFileId,
    int? totalCount,
    bool? hasMore,
  }) {
    return ShipmentUpdatesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      logs: logs ?? this.logs,
      inspectedPhases: inspectedPhases ?? this.inspectedPhases,
      selectedFileId: selectedFileId ?? this.selectedFileId,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final shipmentUpdatesProvider =
    StateNotifierProvider<ShipmentUpdatesNotifier, ShipmentUpdatesState>((ref) {
  return ShipmentUpdatesNotifier(ref.read(dioProvider));
});

class ShipmentUpdatesNotifier extends StateNotifier<ShipmentUpdatesState> {
  final Dio _dio;
  CancelToken? _cancelToken;
  int _currentSkip = 0;
  static const int _pageSize = 200;
  int? _lastImportFileId;
  String? _lastCategory;
  String? _lastTargetPhase;
  String? _lastSearch;

  ShipmentUpdatesNotifier(this._dio) : super(ShipmentUpdatesState()) {
    fetchLogs();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> fetchLogs({
    int? importFileId,
    String? updateCategory,
    String? targetPhase,
    String? search,
    int skip = 0,
    int limit = _pageSize,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final isInitial = skip == 0;
    if (isInitial) {
      _currentSkip = 0;
      _lastImportFileId = importFileId;
      _lastCategory = updateCategory;
      _lastTargetPhase = targetPhase;
      _lastSearch = search;
      state = state.copyWith(isLoading: true, error: null, selectedFileId: importFileId);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (updateCategory != null && updateCategory.isNotEmpty && updateCategory != 'All') queryParams['update_category'] = updateCategory;
      if (targetPhase != null && targetPhase.isNotEmpty && targetPhase != 'All') queryParams['target_phase'] = targetPhase;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final res = await _dio.get('${ApiConstants.baseUrl}/shipment-updates', queryParameters: queryParams, cancelToken: _cancelToken);
      final list = (res.data as List).map((x) => ShipmentUpdateLogModel.fromJson(x)).toList();

      final totalHeader = res.headers.value('x-total-count');
      final total = totalHeader != null ? int.tryParse(totalHeader) ?? list.length : list.length;

      final merged = isInitial ? list : [...state.logs, ...list];
      _currentSkip = merged.length;

      List<PhaseInspectionModel> inspections = state.inspectedPhases;
      if (isInitial && importFileId != null) {
        final resInsp = await _dio.get('${ApiConstants.baseUrl}/shipment-updates/inspect/$importFileId', cancelToken: _cancelToken);
        inspections = (resInsp.data as List).map((x) => PhaseInspectionModel.fromJson(x)).toList();
      }

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        logs: merged,
        inspectedPhases: inspections,
        totalCount: total,
        hasMore: merged.length < total,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await fetchLogs(
      importFileId: _lastImportFileId,
      updateCategory: _lastCategory,
      targetPhase: _lastTargetPhase,
      search: _lastSearch,
      skip: _currentSkip,
      limit: _pageSize,
    );
  }

  Future<ShipmentUpdateLogModel?> createLog(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('${ApiConstants.baseUrl}/shipment-updates', data: payload);
      final created = ShipmentUpdateLogModel.fromJson(res.data);
      await fetchLogs(importFileId: state.selectedFileId);
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLog(int updateId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/shipment-updates/$updateId');
      await fetchLogs(importFileId: state.selectedFileId);
    } catch (e) {
      rethrow;
    }
  }
}
