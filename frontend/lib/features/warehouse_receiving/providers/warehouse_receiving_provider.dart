import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/warehouse_receiving_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import 'goods_in_transit_provider.dart';
import '../../import_files/providers/payment_pathway_provider.dart';

final warehouseReceivingProvider =
    StateNotifierProvider<WarehouseReceivingNotifier, AsyncValue<List<WarehouseReceivingModel>>>((ref) {
  return WarehouseReceivingNotifier(ref.read(dioProvider), ref);
});

class WarehouseReceivingNotifier extends StateNotifier<AsyncValue<List<WarehouseReceivingModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  WarehouseReceivingNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchRecords();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('WarehouseReceivingNotifier disposed');
    super.dispose();
  }

  // Last filters, re-applied after a mutation (FE-15).
  bool _includeInactive = false;
  int? _importFileId;
  String? _status;
  String? _search;

  void _invalidateRelated() {
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
    _ref?.invalidate(goodsInTransitProvider);
    // A GRN is evidence of the Open Account milestones.
    _ref?.invalidate(paymentPathwayStatusProvider);
  }

  Future<void> _refetch() => fetchRecords(
        includeInactive: _includeInactive,
        importFileId: _importFileId,
        status: _status,
        search: _search,
      );

  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
  }) async {
    _includeInactive = includeInactive;
    _importFileId = importFileId;
    _status = status;
    _search = search;
    _cancelToken?.cancel('Cancelled by new fetchRecords request');
    _cancelToken = CancelToken();

    // Preserve previous data during refresh if available
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }

    try {
      final queryParams = <String, dynamic>{'include_inactive': includeInactive};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/warehouse-receiving',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => WarehouseReceivingModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<WarehouseReceivingModel?> createRecord(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/warehouse-receiving',
      data: payload,
    );
    final created = WarehouseReceivingModel.fromJson(response.data);
    _invalidateRelated();
    await _refetch();
    return created;
  }

  Future<WarehouseReceivingModel?> updateRecord(int recordId, Map<String, dynamic> payload) async {
    final response = await _dio.put(
      '${ApiConstants.baseUrl}/warehouse-receiving/$recordId',
      data: payload,
    );
    final updated = WarehouseReceivingModel.fromJson(response.data);
    _invalidateRelated();
    await _refetch();
    return updated;
  }

  Future<WarehouseReceivingModel?> reportDiscrepancy(int recordId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/warehouse-receiving/$recordId/report-discrepancy',
      data: payload,
    );
    final updated = WarehouseReceivingModel.fromJson(response.data);
    _invalidateRelated();
    await _refetch();
    return updated;
  }

  Future<WarehouseReceivingModel?> submitInspectionProtocol(int recordId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/warehouse-receiving/$recordId/inspection-protocol',
      data: payload,
    );
    final updated = WarehouseReceivingModel.fromJson(response.data);
    _invalidateRelated();
    await _refetch();
    return updated;
  }

  Future<void> softDeleteRecord(int recordId) async {
    await _dio.delete('${ApiConstants.baseUrl}/warehouse-receiving/$recordId');
    _invalidateRelated();
    await _refetch();
  }

  Future<void> restoreRecord(int recordId) async {
    await _dio.patch('${ApiConstants.baseUrl}/warehouse-receiving/$recordId/restore');
    _invalidateRelated();
    await _refetch();
  }
}
