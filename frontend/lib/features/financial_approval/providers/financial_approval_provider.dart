import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/financial_approval_model.dart';

final paymentRequestsProvider = StateNotifierProvider<PaymentRequestsNotifier,
    AsyncValue<List<PaymentRequestModel>>>((ref) {
  return PaymentRequestsNotifier(
    ref.watch(dioProvider),
    ref,
    ref.watch(uploadDioProvider),
  );
});

class PaymentRequestsNotifier
    extends StateNotifier<AsyncValue<List<PaymentRequestModel>>> {
  final Ref? ref;
  final Dio _dio;
  final Dio _uploadDio;
  CancelToken? _cancelToken;

  /// Filters of the last list fetch; every mutation re-fetches with them so the
  /// user's search / status filter is not silently reset.
  bool _includeInactive = false;
  String? _search;
  int? _poId;
  int? _supplierId;
  String? _status;

  /// The backend advances the import-file lifecycle on create / approve / pay /
  /// reconcile, so the import files list must be reloaded too.
  void _invalidateImportFiles() {
    final r = ref;
    if (r == null) return;
    try {
      r.invalidate(importFilesProvider);
    } catch (_) {
      // Notifier already disposed (screen closed mid-request): nothing to refresh.
    }
  }

  /// The first argument must be the authenticated client from `dioProvider`;
  /// [uploadDio] (multipart) defaults to it when omitted.
  PaymentRequestsNotifier(this._dio, [this.ref, Dio? uploadDio])
      : _uploadDio = uploadDio ?? _dio,
        super(const AsyncValue.loading()) {
    fetchPaymentRequests();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Provider disposed');
    super.dispose();
  }

  Future<void> fetchPaymentRequests({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? supplierId,
    String? status,
  }) async {
    _includeInactive = includeInactive;
    _search = search;
    _poId = poId;
    _supplierId = supplierId;
    _status = status;
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (poId != null) queryParams['po_id'] = poId;
      if (supplierId != null) queryParams['supplier_id'] = supplierId;
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final requests =
          data.map((json) => PaymentRequestModel.fromJson(json)).toList();
      state = AsyncValue.data(requests);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  /// Re-fetch the list with the filters of the last fetch.
  Future<void> _refresh() => fetchPaymentRequests(
        includeInactive: _includeInactive,
        search: _search,
        poId: _poId,
        supplierId: _supplierId,
        status: _status,
      );

  Future<PaymentRequestModel?> createPaymentRequest(
      Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests',
        data: payload,
      );
      final created = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> updatePaymentRequest(
      int paymentId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId',
        data: payload,
      );
      final updated = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> clonePaymentRequest(
      int paymentId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId/clone',
        data: payload,
      );
      final cloned = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return cloned;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> approvePaymentRequest(int paymentId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId/approve',
      );
      final approved = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return approved;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> executePayment(int paymentId,
      {String? swiftRef}) async {
    try {
      final cleanRef = swiftRef?.trim();
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId/pay',
        queryParameters: (cleanRef != null && cleanRef.isNotEmpty)
            ? {'swift_reference_no': cleanRef}
            : null,
      );
      final paid = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return paid;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> reconcileSwift({
    required int paymentId,
    required String swiftReferenceNo,
    required String swiftReceiptDate,
    required double swiftTransferredAmount,
    String swiftTransferredCurrency = 'USD',
    String? swiftReconciliationNotes,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId/reconcile-swift',
        data: {
          'swift_reference_no': swiftReferenceNo,
          'swift_receipt_date': swiftReceiptDate,
          'swift_transferred_amount': swiftTransferredAmount,
          'swift_transferred_currency': swiftTransferredCurrency,
          if (swiftReconciliationNotes != null &&
              swiftReconciliationNotes.isNotEmpty)
            'swift_reconciliation_notes': swiftReconciliationNotes,
        },
      );
      final reconciled = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return reconciled;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> smartExtractSwift({
    required String rawText,
    int? targetPaymentId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/smart-extract',
        data: {
          'raw_text': rawText,
          if (targetPaymentId != null) 'target_payment_id': targetPaymentId,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> smartExtractSwiftFromFile({
    required Uint8List fileBytes,
    required String filename,
    int? targetPaymentId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
        if (targetPaymentId != null) 'target_payment_id': targetPaymentId,
      });
      final response = await _uploadDio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/smart-extract-file',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> smartReconcileSwift({
    required int paymentId,
    String? rawText,
    required String swiftReferenceNo,
    required String swiftReceiptDate,
    required double swiftTransferredAmount,
    String swiftTransferredCurrency = 'USD',
    String? bankName,
    String? swiftCode,
    String? ibanAccountNo,
    String? swiftReconciliationNotes,
    bool autoExecute = true,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/smart-reconcile',
        data: {
          'payment_id': paymentId,
          if (rawText != null) 'raw_text': rawText,
          'swift_reference_no': swiftReferenceNo,
          'swift_receipt_date': swiftReceiptDate,
          'swift_transferred_amount': swiftTransferredAmount,
          'swift_transferred_currency': swiftTransferredCurrency,
          if (bankName != null) 'bank_name': bankName,
          if (swiftCode != null) 'swift_code': swiftCode,
          if (ibanAccountNo != null) 'iban_account_no': ibanAccountNo,
          if (swiftReconciliationNotes != null)
            'swift_reconciliation_notes': swiftReconciliationNotes,
          'auto_execute': autoExecute,
        },
      );
      final reconciled = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return reconciled;
    } catch (e) {
      rethrow;
    }
  }

  Future<SwiftBatchModel> getSwiftBatch(int batchId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId',
      );
      return SwiftBatchModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<SwiftBatchModel> updateSwiftBatchField({
    required int batchId,
    required String fieldKey,
    required String value,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId/field/$fieldKey',
        data: {'value': value},
      );
      return SwiftBatchModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<SwiftBatchModel> reExtractSwiftBatchField({
    required int batchId,
    required String fieldKey,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId/re-extract-field/$fieldKey',
      );
      return SwiftBatchModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmSwiftBatchReview({
    required int batchId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId/confirm',
        data: <String, dynamic>{},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> matchReviewedSwiftBatch({
    required int batchId,
    int? targetPaymentId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId/match',
        queryParameters: {
          if (targetPaymentId != null) 'target_payment_id': targetPaymentId,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentRequestModel?> reconcileReviewedSwiftBatch({
    required int batchId,
    required int paymentId,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/swift/review-batch/$batchId/reconcile',
        data: {
          'payment_id': paymentId,
          'auto_execute': true,
          if (notes != null) 'notes': notes,
        },
      );
      final reconciled = PaymentRequestModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return reconciled;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeletePaymentRequest(int paymentId) async {
    try {
      await _dio.delete(
          '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId');
      await _refresh();
      _invalidateImportFiles();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restorePaymentRequest(int paymentId) async {
    try {
      await _dio.post(
          '${ApiConstants.baseUrl}/financial-approval/payment-requests/$paymentId/restore');
      await _refresh();
      _invalidateImportFiles();
    } catch (e) {
      rethrow;
    }
  }
}

final importBudgetsProvider = StateNotifierProvider<ImportBudgetsNotifier,
    AsyncValue<List<ImportBudgetModel>>>((ref) {
  return ImportBudgetsNotifier(ref.watch(dioProvider), ref);
});

class ImportBudgetsNotifier
    extends StateNotifier<AsyncValue<List<ImportBudgetModel>>> {
  final Ref? ref;
  final Dio _dio;
  CancelToken? _cancelToken;

  bool _includeInactive = false;
  String? _search;
  int? _poId;
  String? _budgetStatus;

  /// Budget writes advance the import-file lifecycle on the backend.
  void _invalidateImportFiles() {
    final r = ref;
    if (r == null) return;
    try {
      r.invalidate(importFilesProvider);
    } catch (_) {
      // Notifier already disposed (screen closed mid-request): nothing to refresh.
    }
  }

  Future<void> _refresh() => fetchImportBudgets(
        includeInactive: _includeInactive,
        search: _search,
        poId: _poId,
        budgetStatus: _budgetStatus,
      );

  ImportBudgetsNotifier(this._dio, [this.ref])
      : super(const AsyncValue.loading()) {
    fetchImportBudgets();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Provider disposed');
    super.dispose();
  }

  Future<void> fetchImportBudgets({
    bool includeInactive = false,
    String? search,
    int? poId,
    String? budgetStatus,
  }) async {
    _includeInactive = includeInactive;
    _search = search;
    _poId = poId;
    _budgetStatus = budgetStatus;
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (poId != null) queryParams['po_id'] = poId;
      if (budgetStatus != null &&
          budgetStatus.isNotEmpty &&
          budgetStatus != 'All') {
        queryParams['budget_status'] = budgetStatus;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final budgets =
          data.map((json) => ImportBudgetModel.fromJson(json)).toList();
      state = AsyncValue.data(budgets);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ImportBudgetModel?> createImportBudget(
      Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets',
        data: payload,
      );
      final created = ImportBudgetModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportBudgetModel?> updateImportBudget(
      int budgetId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId',
        data: payload,
      );
      final updated = ImportBudgetModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteImportBudget(int budgetId) async {
    try {
      await _dio.delete(
          '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId');
      await _refresh();
      _invalidateImportFiles();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreImportBudget(int budgetId) async {
    try {
      await _dio.post(
          '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/restore');
      await _refresh();
      _invalidateImportFiles();
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportBudgetModel?> approveImportBudget(int budgetId) async {
    try {
      // The approver is the signed-in user, resolved by the backend.
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/approve',
      );
      final approved = ImportBudgetModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      try {
        ref?.invalidate(paymentRequestsProvider);
      } catch (_) {
        // Notifier already disposed: nothing to refresh.
      }
      return approved;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportBudgetModel?> cloneImportBudget(
      int budgetId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/clone',
        data: payload,
      );
      final cloned = ImportBudgetModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return cloned;
    } catch (e) {
      rethrow;
    }
  }

  Future<BudgetPrefillModel?> fetchBudgetPrefill(int importFileId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-approval/prefill/$importFileId',
      );
      return BudgetPrefillModel.fromJson(response.data);
    } catch (e) {
      // Surface backend errors (e.g. 400 FA_FX_RATE_MISSING) to the caller.
      rethrow;
    }
  }

  Future<BudgetSyncResultModel?> syncBudgetWithUpstream(int budgetId,
      {String? justificationNote}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (justificationNote != null && justificationNote.trim().isNotEmpty) {
        queryParams['justification_note'] = justificationNote.trim();
      }
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/sync',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final result = BudgetSyncResultModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportBudgetModel?> overrideBudgetVariance(
      int budgetId, String justificationNote) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/override-variance',
        data: {'justification_note': justificationNote},
      );
      final updated = ImportBudgetModel.fromJson(response.data);
      await _refresh();
      _invalidateImportFiles();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<BudgetVarianceLogModel>> fetchBudgetVarianceLogs(
      int budgetId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/financial-approval/import-budgets/$budgetId/variance-logs',
      );
      final List<dynamic> data = response.data;
      return data.map((json) => BudgetVarianceLogModel.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
