import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../models/po_system_message.dart';
import '../models/purchase_order_model.dart';

class POUpdateResult {
  final bool isSuccess;
  final bool isConflict;
  /// Server-sent text of a concurrent-edit conflict (409 with a detail object).
  final String? errorMessage;
  final Map<String, dynamic>? conflictDetails;
  /// The raw failure (DioException or other); render with `ApiErrorText.of`.
  final Object? error;

  POUpdateResult.success()
      : isSuccess = true,
        isConflict = false,
        errorMessage = null,
        conflictDetails = null,
        error = null;

  POUpdateResult.conflict(this.conflictDetails, [this.errorMessage])
      : isSuccess = false,
        isConflict = true,
        error = null;

  POUpdateResult.error(this.error)
      : isSuccess = false,
        isConflict = false,
        errorMessage = null,
        conflictDetails = null;
}

class PurchaseOrdersState {
  final List<PurchaseOrderModel> purchaseOrders;
  final bool isLoading;
  /// Last failure (raw): shown through `ApiErrorText.of(l10n, error)` so it is localized and a 403 reads as "no permission".
  final Object? error;
  final String searchQuery;
  final String? statusFilter;
  final int? projectFilter;
  final bool showInactive;

  PurchaseOrdersState({
    this.purchaseOrders = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter,
    this.projectFilter,
    this.showInactive = false,
  });

  PurchaseOrdersState copyWith({
    List<PurchaseOrderModel>? purchaseOrders,
    bool? isLoading,
    Object? error,
    String? searchQuery,
    String? statusFilter,
    int? projectFilter,
    bool? showInactive,
  }) {
    return PurchaseOrdersState(
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      projectFilter: projectFilter ?? this.projectFilter,
      showInactive: showInactive ?? this.showInactive,
    );
  }
}

class PurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> {
  final Dio _dio;
  final Ref _ref;
  CancelToken? _cancelToken;

  PurchaseOrdersNotifier(this._dio, this._ref) : super(PurchaseOrdersState()) {
    fetchPurchaseOrders();
  }

  Future<void> fetchPurchaseOrders() async {
    _cancelToken?.cancel('New purchase orders fetch initiated');
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get(
        ApiConstants.purchaseOrders,
        cancelToken: _cancelToken,
        queryParameters: {
          'include_inactive': state.showInactive,
          if (state.statusFilter != null && state.statusFilter!.isNotEmpty) 'status': state.statusFilter,
          if (state.projectFilter != null) 'project_id': state.projectFilter,
          if (state.searchQuery.isNotEmpty) 'search': state.searchQuery,
        },
      );
      final List data = response.data;
      final list = data.map((json) => PurchaseOrderModel.fromJson(json)).toList();
      state = state.copyWith(purchaseOrders: list, isLoading: false);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchPurchaseOrders();
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
    fetchPurchaseOrders();
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(projectFilter: projectId);
    fetchPurchaseOrders();
  }

  void toggleShowInactive(bool val) {
    state = state.copyWith(showInactive: val);
    fetchPurchaseOrders();
  }

  /// Reloads the PO list and every provider whose data embeds PO balances
  /// (projects, import files, shipping scenarios). Call after any successful
  /// PO write, including bulk operations done outside this notifier (Excel import).
  Future<void> refreshAfterMutation() async {
    await fetchPurchaseOrders();
    _ref.read(projectsProvider.notifier).fetchProjects();
    _ref.read(importFilesProvider.notifier).fetchImportFiles();
    _ref.read(shippingScenariosProvider.notifier).fetchSessions();
  }

  /// Returns null on success, otherwise the failure (render with `ApiErrorText.of`).
  /// A failed save is reported to the caller only: `state.error` is the LIST-load error and
  /// would replace the PO table behind the dialog with an error page (e.g. on a 403).
  Future<Object?> createPurchaseOrder(PurchaseOrderModel po) async {
    try {
      await _dio.post(ApiConstants.purchaseOrders, data: po.toJson());
      await refreshAfterMutation();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<POUpdateResult> updatePurchaseOrder(int poId, Map<String, dynamic> data) async {
    try {
      await _dio.put('${ApiConstants.purchaseOrders}/$poId', data: data);
      await refreshAfterMutation();
      return POUpdateResult.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final responseData = e.response?.data;
        final detail = responseData is Map ? responseData['detail'] : null;
        // Coded 409s (PO_ITEMS_ALLOCATED, PO_NUMBER_TAKEN) are plain errors; only the
        // optimistic-concurrency detail carries `current_version`.
        if (detail is Map && detail.containsKey('current_version')) {
          final conflictMap = Map<String, dynamic>.from(detail);
          final msg = conflictMap['message'] as String?;
          return POUpdateResult.conflict(conflictMap, msg);
        }
      }
      // Reported to the caller only (see createPurchaseOrder).
      return POUpdateResult.error(e);
    } catch (e) {
      return POUpdateResult.error(e);
    }
  }

  /// Records a partial shipment against a PO. Over-allocation is allowed: the returned
  /// result carries an OVER_SHIPPED warning for the UI to show. Throws on failure
  /// (render with `ApiErrorText.of`).
  Future<POAllocationResult> allocateShipment(int poId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('${ApiConstants.purchaseOrders}/$poId/allocations', data: payload);
      await refreshAfterMutation();
      return POAllocationResult.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    }
  }

  /// Ids of PO lines that have recorded shipments (best effort: empty when the balance
  /// cannot be read; the backend still refuses to remove such lines with a 409).
  Future<Set<int>> fetchAllocatedItemIds(int poId) async {
    try {
      final response = await _dio.get('${ApiConstants.purchaseOrders}/$poId/balance');
      final lines = (response.data is Map ? response.data['line_items_balance'] : null) as List? ?? const [];
      return {
        for (final l in lines)
          if (l is Map && (l['shipped_qty'] as num? ?? 0) > 0 && l['item_id'] is num) (l['item_id'] as num).toInt(),
      };
    } catch (_) {
      return <int>{};
    }
  }

  /// Packing-list validation report of a PO (coded `messages` twin of errors + warnings).
  Future<POPackingListReport> fetchPackingListReport(int poId) async {
    final response = await _dio.get('${ApiConstants.purchaseOrders}/$poId/packing-list-report');
    return POPackingListReport.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<bool> deletePurchaseOrder(int poId) async {
    try {
      await _dio.delete('${ApiConstants.purchaseOrders}/$poId');
      await refreshAfterMutation();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> restorePurchaseOrder(int poId) async {
    try {
      await _dio.post('${ApiConstants.purchaseOrders}/$poId/restore');
      await refreshAfterMutation();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<PurchaseOrderModel?> clonePurchaseOrder(int poId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.purchaseOrders}/$poId/clone',
        data: payload,
      );
      final cloned = PurchaseOrderModel.fromJson(response.data);
      await refreshAfterMutation();
      return cloned;
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow; // the caller renders it with ApiErrorText
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('PurchaseOrdersNotifier disposed');
    super.dispose();
  }
}

final purchaseOrdersProvider = StateNotifierProvider<PurchaseOrdersNotifier, PurchaseOrdersState>((ref) {
  final dio = ref.watch(dioProvider);
  return PurchaseOrdersNotifier(dio, ref);
});
