import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/customs_clearance_model.dart';
import '../models/clearance_expense_invoice_model.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';


final customsClearanceProvider =
    StateNotifierProvider<CustomsClearanceNotifier, AsyncValue<List<CustomsClearanceModel>>>((ref) {
  return CustomsClearanceNotifier(ref.read(dioProvider), ref: ref);
});

class CustomsClearanceNotifier extends StateNotifier<AsyncValue<List<CustomsClearanceModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  // Last filter arguments, so a refresh after a mutation keeps the screen filters (FE-10).
  bool _includeInactive = false;
  int? _importFileId;
  String? _status;
  String? _search;

  CustomsClearanceNotifier(this._dio, {Ref? ref})
      : _ref = ref,
        super(const AsyncValue.loading()) {
    fetchRecords();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CustomsClearanceNotifier disposed');
    super.dispose();
  }

  /// Reloads with the filters of the previous fetch (used after every mutation).
  Future<void> refresh() => fetchRecords(
        includeInactive: _includeInactive,
        importFileId: _importFileId,
        status: _status,
        search: _search,
      );

  void _invalidateRelated() {
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
  }

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
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{'include_inactive': includeInactive};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-clearance',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => CustomsClearanceModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CustomsClearanceModel?> authorizeBroker(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/authorize-broker',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> recordDeliveryOrderPayment(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/delivery-order-payment',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> registerDeclaration46(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/register-declaration-46',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> recordInspectionSampling(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/record-inspection-sampling',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> assessFinalDuties(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/assess-final-duties',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> recordDutyPayment(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/record-duty-payment',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> issueFinalRelease(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/issue-final-release',
        data: payload,
      );
      final record = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return record;
    } catch (e) {
      rethrow;
    }
  }

  Future<ClearanceInvoicesSummaryModel?> fetchClearanceInvoices(int importFileId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-clearance/invoices/by-file/$importFileId',
      );
      return ClearanceInvoicesSummaryModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ClearanceExpenseInvoiceModel?> createClearanceInvoice(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/invoices',
        data: payload,
      );
      final created = ClearanceExpenseInvoiceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClearanceInvoice(int invoiceId, int importFileId) async {
    try {
      await _dio.delete(
        '${ApiConstants.baseUrl}/customs-clearance/invoices/$invoiceId',
      );
      _invalidateRelated();
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> createRecord(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance',
        data: payload,
      );
      final created = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> submitDutyPayment(int recordId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/$recordId/pay-duty',
        data: payload,
      );
      final updated = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceModel?> completeRelease(int recordId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance/$recordId/complete-release',
        data: payload,
      );
      final updated = CustomsClearanceModel.fromJson(response.data);
      _invalidateRelated();
      await refresh();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteRecord(int recordId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-clearance/$recordId');
      _invalidateRelated();
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreRecord(int recordId) async {
    try {
      await _dio.patch('${ApiConstants.baseUrl}/customs-clearance/$recordId/restore');
      _invalidateRelated();
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// LOG-BOND-003: release the goods under bond (quarantine lock on).
  /// Payload: `{bond_guarantee_ref, temporary_release_date, customs_warehouse_location}`.
  Future<CustomsClearanceModel?> releaseUnderBond(int recordId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/$recordId/under-bond-release',
      data: payload,
    );
    final updated = CustomsClearanceModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return updated;
  }

  /// LOG-BOND-003: record the lab verdict. `lab_test_result` is `CONFORMING` / `NON_CONFORMING`.
  Future<CustomsClearanceModel?> recordLabTestResult(int recordId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/$recordId/lab-test-result',
      data: payload,
    );
    final updated = CustomsClearanceModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return updated;
  }
}
