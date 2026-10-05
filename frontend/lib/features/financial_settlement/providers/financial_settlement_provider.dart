import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/financial_settlement_model.dart';
import '../models/estimated_landed_cost_model.dart';
import '../models/invoices_aggregation_model.dart';
import '../models/actual_landed_cost_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../../core/network/api_client.dart';


final financialSettlementProvider =
    StateNotifierProvider<FinancialSettlementNotifier, AsyncValue<List<LandedCostSettlementModel>>>((ref) {
  return FinancialSettlementNotifier(ref.read(dioProvider), ref);
});

class FinancialSettlementNotifier extends StateNotifier<AsyncValue<List<LandedCostSettlementModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  FinancialSettlementNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchSettlements();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('FinancialSettlementNotifier disposed');
    super.dispose();
  }

  Future<void> fetchSettlements({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
  }) async {
    _cancelToken?.cancel('Cancelled by new fetchSettlements request');
    _cancelToken = CancelToken();

    // Preserve previous data during background search/refresh if available
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }

    try {
      final queryParams = <String, dynamic>{'include_inactive': includeInactive};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-settlement',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => LandedCostSettlementModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<LandedCostSettlementModel?> createSettlement(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement',
        data: payload,
      );
      final created = LandedCostSettlementModel.fromJson(response.data);
      await fetchSettlements();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<LandedCostSettlementModel?> recalculateSettlement(int settlementId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement/$settlementId/recalculate',
      );
      final updated = LandedCostSettlementModel.fromJson(response.data);
      await fetchSettlements();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteSettlement(int settlementId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/financial-settlement/$settlementId');
      await fetchSettlements();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreSettlement(int settlementId) async {
    try {
      await _dio.patch('${ApiConstants.baseUrl}/financial-settlement/$settlementId/restore');
      await fetchSettlements();
    } catch (e) {
      rethrow;
    }
  }

  Future<OdooJournalEntryModel> fetchOdooJournalEntry(int settlementId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-settlement/$settlementId/odoo-journal-entry',
      );
      return OdooJournalEntryModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> downloadOdooCsv(int settlementId) async {
    try {
      final response = await _dio.get<String>(
        '${ApiConstants.baseUrl}/financial-settlement/$settlementId/export-odoo-csv',
      );
      return response.data ?? '';
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> downloadOdooExcel(int settlementId) async {
    try {
      final response = await _dio.get<List<int>>(
        '${ApiConstants.baseUrl}/financial-settlement/$settlementId/export-odoo-excel',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? [];
    } catch (e) {
      rethrow;
    }
  }

  Future<EstimatedLandedCostSimulationModel> simulateEstimatedLandedCost(
    int importFileId, [
    Map<String, dynamic>? overrides,
  ]) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement/simulate-file/$importFileId',
        data: overrides ?? {},
      );
      return EstimatedLandedCostSimulationModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<InvoicesAggregationResponseModel> fetchInvoicesAggregation(int importFileId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-settlement/invoices-aggregation/$importFileId',
      );
      return InvoicesAggregationResponseModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ConfirmInvoicesSettlementResponseModel> confirmInvoicesSettlement(
    ConfirmInvoicesSettlementRequestModel request,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement/confirm-invoices-settlement',
        data: request.toJson(),
      );
      final result = ConfirmInvoicesSettlementResponseModel.fromJson(response.data);
      _invalidateDependents();
      await fetchSettlements();
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// A confirm / approve advances the file lifecycle and closes smart tasks, so
  /// every list that shows that state must reload.
  void _invalidateDependents() {
    final ref = _ref;
    if (ref == null) return;
    ref.invalidate(importFilesProvider);
    ref.invalidate(lifecycleBoardSummaryProvider);
    ref.invalidate(smartTasksProvider);
  }

  Future<ActualLandedCostCalculationResponseModel> calculateActualLandedCost(
    int importFileId, {
    String allocationPreference = 'Value-Based',
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement/calculate-actual-landed-cost/$importFileId',
        data: {
          'allocation_preference': allocationPreference,
          if (notes != null) 'notes': notes,
        },
      );
      return ActualLandedCostCalculationResponseModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ApproveActualLandedCostResponseModel> approveActualLandedCost({
    required int importFileId,
    // Kept for source compatibility: the server records the signed-in user and
    // ignores any client-supplied approver, so it is not sent.
    required String approvedBy,
    String allocationPreference = 'Value-Based',
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-settlement/approve-actual-landed-cost',
        data: {
          'import_file_id': importFileId,
          'allocation_preference': allocationPreference,
          if (notes != null) 'notes': notes,
        },
      );
      final result = ApproveActualLandedCostResponseModel.fromJson(response.data);
      _invalidateDependents();
      await fetchSettlements();
      return result;
    } catch (e) {
      rethrow;
    }
  }
}



