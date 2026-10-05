import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/file_closure_model.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';


final fileClosureProvider =
    StateNotifierProvider<FileClosureNotifier, AsyncValue<List<ImportFileClosureModel>>>((ref) {
  return FileClosureNotifier(ref.read(dioProvider), ref);
});

class FileClosureNotifier extends StateNotifier<AsyncValue<List<ImportFileClosureModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  FileClosureNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchClosures();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('FileClosureNotifier disposed');
    super.dispose();
  }

  Future<void> fetchClosures({
    bool includeInactive = false,
    int? importFileId,
    String? search,
  }) async {
    _cancelToken?.cancel('New fetch started');
    _cancelToken = CancelToken();

    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final queryParams = <String, dynamic>{'include_inactive': includeInactive};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/file-closure',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List data = response.data;
      final list = data.map((json) => ImportFileClosureModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  /// Every closure write changes the file status and its tasks: refresh both lists.
  void _invalidateRelated() {
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
  }

  Future<ImportFileClosureModel?> closeImportFile(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/file-closure',
      data: payload,
    );
    final created = ImportFileClosureModel.fromJson(response.data);
    _invalidateRelated();
    await fetchClosures();
    return created;
  }

  Future<void> softDeleteClosure(int closureId) async {
    await _dio.delete('${ApiConstants.baseUrl}/file-closure/$closureId');
    _invalidateRelated();
    await fetchClosures();
  }

  Future<void> restoreClosure(int closureId) async {
    await _dio.patch('${ApiConstants.baseUrl}/file-closure/$closureId/restore');
    _invalidateRelated();
    await fetchClosures();
  }

  Future<ClosurePrecheckResponseModel> fetchClosurePrecheck(int importFileId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/file-closure/closure-precheck/$importFileId',
    );
    return ClosurePrecheckResponseModel.fromJson(response.data);
  }

  Future<OfficialClosureCertificateResponseModel> officialCloseImportFile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/file-closure/official-close',
      data: payload,
    );
    final certificate =
        OfficialClosureCertificateResponseModel.fromJson(response.data);
    _invalidateRelated();
    await fetchClosures();
    return certificate;
  }
}

