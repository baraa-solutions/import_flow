import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/docs_customs_approval_model.dart';
import '../models/docs_customs_approval_session_model.dart';
import 'import_documentation_provider.dart' show invalidateImportDocDependents;

final docsCustomsApprovalProvider =
    StateNotifierProvider<DocsCustomsApprovalNotifier, AsyncValue<List<CustomsDocumentApprovalModel>>>((ref) {
  return DocsCustomsApprovalNotifier(ref.read(dioProvider), ref);
});

final discrepancyTicketsProvider =
    StateNotifierProvider<DiscrepancyTicketsNotifier, AsyncValue<List<DiscrepancyRectificationTicketModel>>>((ref) {
  return DiscrepancyTicketsNotifier(ref.read(dioProvider), ref);
});

class DocsCustomsApprovalNotifier extends StateNotifier<AsyncValue<List<CustomsDocumentApprovalModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;
  int? _lastImportFileId;
  String? _lastOverallStatus;
  String? _lastSearch;

  DocsCustomsApprovalNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchApprovals();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> fetchApprovals({
    int? importFileId,
    String? overallStatus,
    String? search,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _lastImportFileId = importFileId;
    _lastOverallStatus = overallStatus;
    _lastSearch = search;
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'include_inactive': false};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (overallStatus != null && overallStatus.isNotEmpty && overallStatus != 'All') {
        queryParams['overall_status'] = overallStatus;
      }
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/docs-customs-approval',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => CustomsDocumentApprovalModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  /// Reloads with the query the screen last used (FED-13) and refreshes the
  /// providers that depend on the approval state. [importFileId] overrides the
  /// remembered file when the mutation knows it.
  Future<void> _afterMutation({int? importFileId}) async {
    await fetchApprovals(
      importFileId: importFileId ?? _lastImportFileId,
      overallStatus: _lastOverallStatus,
      search: _lastSearch,
    );
    invalidateImportDocDependents(_ref);
  }

  Future<void> autoGenerateChecklist(int importFileId) async {
    try {
      await _dio.post('${ApiConstants.baseUrl}/docs-customs-approval/auto-generate/$importFileId');
      await _afterMutation(importFileId: importFileId);
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsDocumentApprovalModel?> submitCommercialReview({
    required int approvalId,
    required String reviewerName,
    required String status,
    String? notes,
    int? importFileId,
    int? version,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/$approvalId/commercial-review',
        data: {
          'reviewer_name': reviewerName,
          'status': status,
          'notes': notes,
          if (version != null) 'version': version,
        },
      );
      final updated = CustomsDocumentApprovalModel.fromJson(response.data);
      await _afterMutation(importFileId: importFileId);
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsDocumentApprovalModel?> submitCustomsBrokerReview({
    required int approvalId,
    required String brokerName,
    required String reviewerName,
    required String status,
    String? notes,
    int? importFileId,
    int? version,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/$approvalId/customs-review',
        data: {
          'broker_name': brokerName,
          'reviewer_name': reviewerName,
          'status': status,
          'notes': notes,
          if (version != null) 'version': version,
        },
      );
      final updated = CustomsDocumentApprovalModel.fromJson(response.data);
      await _afterMutation(importFileId: importFileId);
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CrossDocumentMatrixResultModel> runMatrixCheck(int importFileId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/matrix-check/$importFileId',
      );
      return CrossDocumentMatrixResultModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

class DiscrepancyTicketsNotifier extends StateNotifier<AsyncValue<List<DiscrepancyRectificationTicketModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;
  int? _lastImportFileId;
  String? _lastStatus;
  String? _lastSeverity;
  String? _lastSearch;

  DiscrepancyTicketsNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchTickets();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> fetchTickets({
    int? importFileId,
    String? status,
    String? severity,
    String? search,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _lastImportFileId = importFileId;
    _lastStatus = status;
    _lastSeverity = severity;
    _lastSearch = search;
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'include_inactive': false};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (severity != null && severity.isNotEmpty && severity != 'All') {
        queryParams['severity'] = severity;
      }
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/docs-customs-approval/tickets/list',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => DiscrepancyRectificationTicketModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _afterMutation({int? importFileId}) async {
    await fetchTickets(
      importFileId: importFileId ?? _lastImportFileId,
      status: _lastStatus,
      severity: _lastSeverity,
      search: _lastSearch,
    );
    invalidateImportDocDependents(_ref);
  }

  Future<DiscrepancyRectificationTicketModel?> createTicket(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/tickets',
        data: payload,
      );
      final created = DiscrepancyRectificationTicketModel.fromJson(response.data);
      await _afterMutation(importFileId: payload['import_file_id'] as int?);
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<DiscrepancyRectificationTicketModel?> resolveTicket(
    int ticketId,
    Map<String, dynamic> payload, {
    int? importFileId,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/tickets/$ticketId/resolve',
        data: payload,
      );
      final resolved = DiscrepancyRectificationTicketModel.fromJson(response.data);
      await _afterMutation(importFileId: importFileId);
      return resolved;
    } catch (e) {
      rethrow;
    }
  }
}

final docsCustomsApprovalSessionsProvider =
    StateNotifierProvider<DocsCustomsApprovalSessionsNotifier, AsyncValue<List<DocsCustomsApprovalSessionModel>>>((ref) {
  return DocsCustomsApprovalSessionsNotifier(ref.read(dioProvider), ref);
});

class DocsCustomsApprovalSessionsNotifier
    extends StateNotifier<AsyncValue<List<DocsCustomsApprovalSessionModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;
  int? _lastImportFileId;
  bool? _lastIsDraft;
  String? _lastSearch;

  DocsCustomsApprovalSessionsNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchSessions();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> fetchSessions({
    int? importFileId,
    bool? isDraft,
    String? search,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _lastImportFileId = importFileId;
    _lastIsDraft = isDraft;
    _lastSearch = search;
    try {
      state = const AsyncValue.loading();
      final queryParams = <String, dynamic>{};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (isDraft != null) queryParams['is_draft'] = isDraft;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/docs-customs-approval/sessions',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => DocsCustomsApprovalSessionModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _afterMutation() async {
    await fetchSessions(importFileId: _lastImportFileId, isDraft: _lastIsDraft, search: _lastSearch);
    invalidateImportDocDependents(_ref);
  }

  Future<DocsCustomsApprovalSessionModel> createSession(Map<String, dynamic> sessionData) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/docs-customs-approval/sessions',
        data: sessionData,
      );
      final created = DocsCustomsApprovalSessionModel.fromJson(response.data as Map<String, dynamic>);
      await _afterMutation();
      return created;
    } catch (e) {
      rethrow;
    }
  }
}
