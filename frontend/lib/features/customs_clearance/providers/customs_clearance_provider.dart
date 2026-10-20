import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/customs_clearance_model.dart';
import '../models/clearance_expense_invoice_model.dart';
import '../models/clearance_followup_log_model.dart';
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

  /// Fetches a single clearance record by ID (read-only live load for details view).
  Future<CustomsClearanceModel> getRecord(int recordId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/customs-clearance/$recordId',
    );
    return CustomsClearanceModel.fromJson(response.data);
  }

  /// Records item tax coding on Nafeza platform (TASK-BE-10).
  Future<CustomsClearanceModel?> recordTariffCoding({
    required int customsClearanceId,
    required String tariffCodingDate,
    String? notes,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/tariff-coding',
      data: {
        'customs_clearance_id': customsClearanceId,
        'tariff_coding_date': tariffCodingDate,
        'notes': notes,
      },
    );
    final updated = CustomsClearanceModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return updated;
  }

  /// Records bank linkage acceptance on Nafeza (TASK-BE-10).
  Future<CustomsClearanceModel?> recordBankLinkAccepted({
    required int customsClearanceId,
    required String bankLinkAcceptedDate,
    String? bankName,
    String? notes,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/bank-link-accepted',
      data: {
        'customs_clearance_id': customsClearanceId,
        'bank_link_accepted_date': bankLinkAcceptedDate,
        'bank_name': bankName,
        'notes': notes,
      },
    );
    final updated = CustomsClearanceModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return updated;
  }

  /// Submits duty payment request / Form 4 with Nafeza claim number (TASK-BE-10).
  Future<CustomsClearanceModel?> requestDutyPayment({
    required int customsClearanceId,
    required String dutyPaymentRequestedDate,
    String? nafezaClaimNumber,
    double? estimatedDutyAmount,
    String? notes,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/request-duty-payment',
      data: {
        'customs_clearance_id': customsClearanceId,
        'duty_payment_requested_date': dutyPaymentRequestedDate,
        'nafeza_claim_number': nafezaClaimNumber,
        'estimated_duty_amount': estimatedDutyAmount,
        'notes': notes,
      },
    );
    final updated = CustomsClearanceModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return updated;
  }

  /// Fetches the sequential field follow-up logs for a customs clearance record (TASK-BE-12).
  Future<List<ClearanceFollowupLogModel>> fetchFollowupLogs(int customsClearanceId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/customs-clearance/$customsClearanceId/followup-logs',
    );
    return (response.data as List).map((j) => ClearanceFollowupLogModel.fromJson(j)).toList();
  }

  /// Creates a new field customs clearance follow-up log (TASK-BE-12).
  Future<ClearanceFollowupLogModel> createFollowupLog(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/customs-clearance/followup-logs',
      data: payload,
    );
    final log = ClearanceFollowupLogModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return log;
  }

  /// Marks a customs clearance follow-up log as completed (TASK-BE-12).
  Future<ClearanceFollowupLogModel> completeFollowupLog(int logId) async {
    final response = await _dio.patch(
      '${ApiConstants.baseUrl}/customs-clearance/followup-logs/$logId/complete',
    );
    final log = ClearanceFollowupLogModel.fromJson(response.data);
    _invalidateRelated();
    await refresh();
    return log;
  }
}

/// Provider for loading clearance follow-up logs for a specific record.
final clearanceFollowupLogsProvider =
    FutureProvider.family<List<ClearanceFollowupLogModel>, int>((ref, customsClearanceId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '${ApiConstants.baseUrl}/customs-clearance/$customsClearanceId/followup-logs',
  );
  return (response.data as List).map((j) => ClearanceFollowupLogModel.fromJson(j)).toList();
});


