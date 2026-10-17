import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../inland_transport/providers/inland_transport_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/demurrage_model.dart';

class DemurrageState {
  final List<DemurragePolicyModel> policies;
  final List<DemurrageTrackingModel> trackings;
  final DemurrageSimulationResultModel? simulationResult;
  final FreeDaysAgreementModel? activeAgreement;
  final bool isLoading;
  final String? error;

  /// The raw failure behind [error]; screens render it with `ApiErrorText.of`
  /// so the backend Arabic detail and 403s reach the user.
  final Object? errorObject;

  final int policiesTotalCount;
  final bool policiesHasMore;
  final bool policiesIsLoadingMore;
  final int trackingsTotalCount;
  final bool trackingsHasMore;
  final bool trackingsIsLoadingMore;

  const DemurrageState({
    this.policies = const [],
    this.trackings = const [],
    this.simulationResult,
    this.activeAgreement,
    this.isLoading = false,
    this.error,
    this.errorObject,
    this.policiesTotalCount = 0,
    this.policiesHasMore = false,
    this.policiesIsLoadingMore = false,
    this.trackingsTotalCount = 0,
    this.trackingsHasMore = false,
    this.trackingsIsLoadingMore = false,
  });

  DemurrageState copyWith({
    List<DemurragePolicyModel>? policies,
    List<DemurrageTrackingModel>? trackings,
    DemurrageSimulationResultModel? simulationResult,
    FreeDaysAgreementModel? activeAgreement,
    bool? isLoading,
    String? error,
    Object? errorObject,
    int? policiesTotalCount,
    bool? policiesHasMore,
    bool? policiesIsLoadingMore,
    int? trackingsTotalCount,
    bool? trackingsHasMore,
    bool? trackingsIsLoadingMore,
  }) {
    return DemurrageState(
      policies: policies ?? this.policies,
      trackings: trackings ?? this.trackings,
      simulationResult: simulationResult ?? this.simulationResult,
      activeAgreement: activeAgreement ?? this.activeAgreement,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorObject: errorObject,
      policiesTotalCount: policiesTotalCount ?? this.policiesTotalCount,
      policiesHasMore: policiesHasMore ?? this.policiesHasMore,
      policiesIsLoadingMore: policiesIsLoadingMore ?? this.policiesIsLoadingMore,
      trackingsTotalCount: trackingsTotalCount ?? this.trackingsTotalCount,
      trackingsHasMore: trackingsHasMore ?? this.trackingsHasMore,
      trackingsIsLoadingMore: trackingsIsLoadingMore ?? this.trackingsIsLoadingMore,
    );
  }
}

class DemurrageNotifier extends StateNotifier<DemurrageState> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  int _policiesSkip = 0;
  int _trackingsSkip = 0;
  static const int _pageSize = 200;

  String? _lastPoliciesCarrierName;
  String? _lastPoliciesContainerType;

  int? _lastTrackingsImportFileId;
  String? _lastTrackingsCarrierName;
  String? _lastTrackingsStatus;

  /// [_dio] must be the authenticated client from `dioProvider`.
  DemurrageNotifier(this._dio, [this._ref]) : super(const DemurrageState());

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        fetchPolicies(),
        fetchTrackings(),
      ]);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
    }
  }

  Future<void> fetchPolicies({
    String? carrierName,
    String? containerType,
    int skip = 0,
    int limit = _pageSize,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final isInitial = skip == 0;
    if (isInitial) {
      _policiesSkip = 0;
      _lastPoliciesCarrierName = carrierName;
      _lastPoliciesContainerType = containerType;
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(policiesIsLoadingMore: true, error: null);
    }

    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (carrierName != null && carrierName.isNotEmpty) queryParams['carrier_name'] = carrierName;
      if (containerType != null && containerType.isNotEmpty) queryParams['container_type'] = containerType;

      final res = await _dio.get(
        '/demurrage-detention/policies',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );
      if (res.data is List) {
        final policies = (res.data as List)
            .map((e) => DemurragePolicyModel.fromJson(e))
            .toList();
        final totalHeader = res.headers.value('x-total-count');
        final total = totalHeader != null ? int.tryParse(totalHeader) ?? policies.length : policies.length;

        final merged = isInitial ? policies : [...state.policies, ...policies];
        _policiesSkip = merged.length;

        state = state.copyWith(
          policies: merged,
          isLoading: false,
          policiesIsLoadingMore: false,
          policiesTotalCount: total,
          policiesHasMore: merged.length < total,
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        policiesIsLoadingMore: false,
        error: ApiError.message(e),
        errorObject: e,
      );
    }
  }

  Future<void> loadMorePolicies() async {
    if (state.isLoading || state.policiesIsLoadingMore || !state.policiesHasMore) return;
    await fetchPolicies(
      carrierName: _lastPoliciesCarrierName,
      containerType: _lastPoliciesContainerType,
      skip: _policiesSkip,
      limit: _pageSize,
    );
  }

  Future<void> fetchTrackings({
    int? importFileId,
    String? carrierName,
    String? status,
    int skip = 0,
    int limit = _pageSize,
  }) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final isInitial = skip == 0;
    if (isInitial) {
      _trackingsSkip = 0;
      _lastTrackingsImportFileId = importFileId;
      _lastTrackingsCarrierName = carrierName;
      _lastTrackingsStatus = status;
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(trackingsIsLoadingMore: true, error: null);
    }

    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (carrierName != null && carrierName.isNotEmpty) queryParams['carrier_name'] = carrierName;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final res = await _dio.get(
        '/demurrage-detention/trackings',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );
      if (res.data is List) {
        final trackings = (res.data as List)
            .map((e) => DemurrageTrackingModel.fromJson(e))
            .toList();
        final totalHeader = res.headers.value('x-total-count');
        final total = totalHeader != null ? int.tryParse(totalHeader) ?? trackings.length : trackings.length;

        final merged = isInitial ? trackings : [...state.trackings, ...trackings];
        _trackingsSkip = merged.length;

        state = state.copyWith(
          trackings: merged,
          isLoading: false,
          trackingsIsLoadingMore: false,
          trackingsTotalCount: total,
          trackingsHasMore: merged.length < total,
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        trackingsIsLoadingMore: false,
        error: ApiError.message(e),
        errorObject: e,
      );
    }
  }

  Future<void> loadMoreTrackings() async {
    if (state.isLoading || state.trackingsIsLoadingMore || !state.trackingsHasMore) return;
    await fetchTrackings(
      importFileId: _lastTrackingsImportFileId,
      carrierName: _lastTrackingsCarrierName,
      status: _lastTrackingsStatus,
      skip: _trackingsSkip,
      limit: _pageSize,
    );
  }

  Future<DemurrageSimulationResultModel?> simulateCalculation(Map<String, dynamic> requestPayload) async {
    try {
      final res = await _dio.post('/demurrage-detention/simulate', data: requestPayload);
      if (res.data is Map<String, dynamic>) {
        final result = DemurrageSimulationResultModel.fromJson(res.data);
        state = state.copyWith(simulationResult: result);
        return result;
      }
    } catch (e) {
      state = state.copyWith(error: ApiError.message(e), errorObject: e);
      rethrow;
    }
    return null;
  }

  Future<bool> createTracking(Map<String, dynamic> trackingData) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/demurrage-detention/trackings', data: trackingData);
      await fetchTrackings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
      return false;
    }
  }

  Future<bool> updateTrackingDates(int trackingId, {String? gateOutDate, String? emptyReturnDate}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final payload = <String, dynamic>{};
      if (gateOutDate != null) payload['gate_out_date'] = gateOutDate;
      if (emptyReturnDate != null) payload['empty_return_date'] = emptyReturnDate;

      await _dio.put('/demurrage-detention/trackings/$trackingId', data: payload);
      await fetchTrackings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> pushToSettlement(int trackingId, {int? importFileId}) async {
    try {
      final payload = <String, dynamic>{'tracking_id': trackingId};
      if (importFileId != null) {
        payload['import_file_id'] = importFileId;
      }
      final res = await _dio.post(
        '/demurrage-detention/trackings/push-to-settlement',
        data: payload,
      );
      _ref?.invalidate(importFilesProvider);
      _ref?.invalidate(lifecycleBoardSummaryProvider);
      await fetchTrackings();
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      state = state.copyWith(error: ApiError.message(e), errorObject: e);
      return null;
    }
  }

  Future<bool> createPolicy(Map<String, dynamic> policyData) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/demurrage-detention/policies', data: policyData);
      await fetchPolicies();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
      return false;
    }
  }

  Future<FreeDaysAgreementModel?> fetchFreeDaysAgreement(int importFileId) async {
    try {
      final res = await _dio.get('/demurrage-detention/free-days-agreement/$importFileId');
      if (res.data is Map<String, dynamic>) {
        final agreement = FreeDaysAgreementModel.fromJson(res.data);
        state = state.copyWith(activeAgreement: agreement);
        return agreement;
      }
    } catch (e) {
      // Only "no agreement registered yet" (404) is quiet; surface the rest.
      if (e is DioException && e.response?.statusCode == 404) return null;
      state = state.copyWith(error: ApiError.message(e), errorObject: e);
      return null;
    }
    return null;
  }

  Future<FreeDaysAgreementModel?> registerFreeDaysAgreement(Map<String, dynamic> agreementData) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.post(
        '/demurrage-detention/free-days-agreement',
        data: agreementData,
      );
      if (res.data is Map<String, dynamic>) {
        final agreement = FreeDaysAgreementModel.fromJson(res.data);
        state = state.copyWith(activeAgreement: agreement, isLoading: false);

        // Invalidate dependent providers per ERP auto-refresh rules
        _ref?.invalidate(importFilesProvider);
        _ref?.invalidate(smartTasksProvider);
        _ref?.invalidate(freightBookingProvider);
        _ref?.invalidate(lifecycleBoardSummaryProvider);

        // Refresh trackings to reflect newly calculated free days
        await fetchTrackings();
        return agreement;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
      rethrow;
    }
    return null;
  }

  Future<ContainerRadarOverviewModel?> fetchRadarOverview() async {
    try {
      final res = await _dio.get('/demurrage-detention/radar-overview');
      if (res.data is Map<String, dynamic>) {
        return ContainerRadarOverviewModel.fromJson(res.data);
      }
    } catch (e) {
      state = state.copyWith(error: ApiError.message(e), errorObject: e);
    }
    return null;
  }

  Future<EmptyContainerReturnResponseModel?> recordEmptyContainerReturn(
      EmptyContainerReturnSubmitModel submitModel) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.post(
        '/demurrage-detention/empty-container-return',
        data: submitModel.toJson(),
      );
      if (res.data is Map<String, dynamic>) {
        final responseModel =
            EmptyContainerReturnResponseModel.fromJson(res.data);
        state = state.copyWith(isLoading: false);

        // Invalidate dependent providers per ERP auto-refresh rules
        _ref?.invalidate(importFilesProvider);
        _ref?.invalidate(containerRadarOverviewProvider);
        _ref?.invalidate(smartTasksProvider);
        _ref?.invalidate(inlandTransportProvider);
        _ref?.invalidate(lifecycleBoardSummaryProvider);

        await fetchTrackings();
        return responseModel;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e), errorObject: e);
      rethrow;
    }
    return null;
  }
}

final demurrageProvider = StateNotifierProvider<DemurrageNotifier, DemurrageState>((ref) {
  return DemurrageNotifier(ref.read(dioProvider), ref);
});

final containerRadarOverviewProvider = FutureProvider.autoDispose<ContainerRadarOverviewModel>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/demurrage-detention/radar-overview');
  if (res.data is Map<String, dynamic>) {
    return ContainerRadarOverviewModel.fromJson(res.data);
  }
  throw Exception('Failed to load container demurrage radar overview');
});
