import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/import_file_model.dart';
import '../../../core/network/api_client.dart';

final importFilesProvider =
    StateNotifierProvider<ImportFilesNotifier, AsyncValue<List<ImportFileModel>>>((ref) {
  return ImportFilesNotifier(ref.read(dioProvider));
});

class PaginatedImportFilesState {
  final List<ImportFileModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool isLoading;
  final String? error;

  PaginatedImportFilesState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 50,
    this.totalPages = 1,
    this.isLoading = false,
    this.error,
  });

  PaginatedImportFilesState copyWith({
    List<ImportFileModel>? items,
    int? total,
    int? page,
    int? pageSize,
    int? totalPages,
    bool? isLoading,
    String? error,
  }) {
    return PaginatedImportFilesState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final paginatedImportFilesProvider =
    StateNotifierProvider<PaginatedImportFilesNotifier, PaginatedImportFilesState>((ref) {
  return PaginatedImportFilesNotifier(ref.read(dioProvider));
});

class PaginatedImportFilesNotifier extends StateNotifier<PaginatedImportFilesState> {
  final Dio _dio;
  CancelToken? _cancelToken;

  PaginatedImportFilesNotifier(this._dio) : super(PaginatedImportFilesState()) {
    fetchPage(1);
  }

  Future<void> fetchPage(int page, {
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    _cancelToken?.cancel('Cancelled by new fetchPage request');
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null);
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': state.pageSize,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (companyId != null) queryParams['company_id'] = companyId;
      if (supplierId != null) queryParams['supplier_id'] = supplierId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (owner != null && owner.isNotEmpty && owner != 'All') queryParams['owner'] = owner;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/import-files/paginated',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final data = response.data;
      final List<dynamic> itemsData = data['items'];
      final files = itemsData.map((json) => ImportFileModel.fromJson(json)).toList();
      
      state = state.copyWith(
        items: files,
        total: data['total'],
        page: data['page'],
        pageSize: data['page_size'],
        totalPages: data['total_pages'],
        isLoading: false,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Cancelled on PaginatedImportFilesNotifier dispose');
    super.dispose();
  }

  void nextPage() {
    if (state.page < state.totalPages && !state.isLoading) {
      fetchPage(state.page + 1);
    }
  }

  void prevPage() {
    if (state.page > 1 && !state.isLoading) {
      fetchPage(state.page - 1);
    }
  }
}

class ImportFilesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  ImportFilesNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchImportFiles();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('ImportFilesNotifier disposed');
    super.dispose();
  }

  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    _cancelToken?.cancel('Cancelled by new fetchImportFiles request');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (companyId != null) queryParams['company_id'] = companyId;
      if (supplierId != null) queryParams['supplier_id'] = supplierId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (owner != null && owner.isNotEmpty && owner != 'All') queryParams['owner'] = owner;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/import-files',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final files = data.map((json) => ImportFileModel.fromJson(json)).toList();
      state = AsyncValue.data(files);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ImportFileModel?> createImportFile(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files',
        data: payload,
      );
      final created = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> updateImportFile(int importFileId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/import-files/$importFileId',
        data: payload,
      );
      final updated = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteImportFile(int importFileId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/import-files/$importFileId');
      await fetchImportFiles();
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> closeShipment(int importFileId, String closureReason, String closedAtPhase) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$importFileId/close-shipment',
        data: {
          'closure_reason': closureReason,
          'closed_at_phase': closedAtPhase,
        },
      );
      final closed = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return closed;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> reopenShipment(int importFileId, String reopenReason) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$importFileId/reopen-shipment',
        data: {
          'reopen_reason': reopenReason,
        },
      );
      final reopened = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return reopened;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportMasterReportSummaryModel> fetchMasterReport() async {
    try {
      final response = await _dio.get('${ApiConstants.baseUrl}/import-files/report/master');
      return ImportMasterReportSummaryModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> holdShipment(
    int importFileId,
    String holdReason, {
    String? holdNotes,
    String? stageName,
    String? stepName,
    String? holdReasonCode,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$importFileId/hold',
        data: {
          'hold_reason': holdReason,
          if (holdReasonCode != null) 'hold_reason_code': holdReasonCode,
          if (holdNotes != null) 'hold_notes': holdNotes,
          if (stageName != null) 'stage_name': stageName,
          if (stepName != null) 'step_name': stepName,
        },
      );
      final held = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return held;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> resumeShipment(int importFileId, {String? resumeNotes}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$importFileId/resume',
        data: {
          if (resumeNotes != null) 'resume_notes': resumeNotes,
        },
      );
      final resumed = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return resumed;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> cloneImportFile(int importFileId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$importFileId/clone',
        data: payload,
      );
      final cloned = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return cloned;
    } catch (e) {
      rethrow;
    }
  }

  Future<ImportFileModel?> createPartialBatch(int parentFileId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/import-files/$parentFileId/create-partial-batch',
        data: payload,
      );
      final batch = ImportFileModel.fromJson(response.data);
      await fetchImportFiles();
      return batch;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ImportFileModel>> getPartialBatches(int importFileId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/import-files/$importFileId/partial-batches',
      );
      final List<dynamic> data = response.data;
      return data.map((json) => ImportFileModel.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}


