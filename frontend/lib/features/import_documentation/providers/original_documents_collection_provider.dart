import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/original_documents_collection_model.dart';
import 'import_documentation_provider.dart' show invalidateImportDocDependents;

final originalDocsDioProvider = Provider<Dio>((ref) {
  return ref.watch(dioProvider);
});

final originalDocumentsSessionsProvider = StateNotifierProvider<
    OriginalDocumentsCollectionNotifier,
    AsyncValue<List<OriginalDocumentsCollectionSessionModel>>>((ref) {
  return OriginalDocumentsCollectionNotifier(ref.read(originalDocsDioProvider), ref);
});

class OriginalDocumentsCollectionNotifier
    extends StateNotifier<AsyncValue<List<OriginalDocumentsCollectionSessionModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;
  String? _lastStatus;
  String? _lastSearch;

  OriginalDocumentsCollectionNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchSessions();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('OriginalDocumentsCollectionNotifier disposed');
    super.dispose();
  }

  Future<void> fetchSessions({
    String? status,
    String? search,
  }) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    _lastStatus = status;
    _lastSearch = search;
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '/original-documents-collection/sessions',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> list = response.data;
      final sessions = list
          .map((json) => OriginalDocumentsCollectionSessionModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(sessions);
    } catch (e, st) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<OriginalDocumentsAutoPopulateModel> fetchAutoPopulate(int importFileId) async {
    try {
      final response = await _dio.get(
        '/original-documents-collection/auto-populate/$importFileId',
      );
      return OriginalDocumentsAutoPopulateModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<OriginalDocumentsCollectionSessionModel?> fetchSessionByFile(int importFileId) async {
    try {
      final response = await _dio.get(
        '/original-documents-collection/sessions/by-file/$importFileId',
      );
      if (response.data == null) return null;
      return OriginalDocumentsCollectionSessionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Only "no session yet" is null. Any other failure (network, 401/403,
      // 500) must surface: treating it as "no session" makes the next save
      // upsert over the existing session (FED-09).
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _afterMutation() async {
    await fetchSessions(status: _lastStatus, search: _lastSearch);
    invalidateImportDocDependents(_ref);
  }

  Future<OriginalDocumentsCollectionSessionModel> saveOrUpsertSession(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/original-documents-collection/sessions',
        data: payload,
      );
      final created = OriginalDocumentsCollectionSessionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _afterMutation();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<OriginalDocumentsCollectionSessionModel> confirmCourierReceipt(
    CourierReceiptProofRequestModel request,
  ) async {
    try {
      final response = await _dio.post(
        '/original-documents-collection/couriers/confirm-receipt',
        data: request.toJson(),
      );
      final updated = OriginalDocumentsCollectionSessionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _afterMutation();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CourierAlertsResponseModel> fetchCourierAlerts() async {
    try {
      final response = await _dio.get('/original-documents-collection/couriers/alerts');
      return CourierAlertsResponseModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CourierFlatItemModel>> fetchAllCouriers() async {
    try {
      final response = await _dio.get('/original-documents-collection/couriers/all');
      final List<dynamic> list = response.data;
      return list.map((json) => CourierFlatItemModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> downloadExcel(int importFileId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/original-documents-collection/export/excel/$importFileId',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? [];
    } catch (e) {
      rethrow;
    }
  }
}

final courierAlertsProvider = FutureProvider<CourierAlertsResponseModel>((ref) async {
  final notifier = ref.watch(originalDocumentsSessionsProvider.notifier);
  return notifier.fetchCourierAlerts();
});

final allCouriersProvider = FutureProvider<List<CourierFlatItemModel>>((ref) async {
  final notifier = ref.watch(originalDocumentsSessionsProvider.notifier);
  return notifier.fetchAllCouriers();
});

