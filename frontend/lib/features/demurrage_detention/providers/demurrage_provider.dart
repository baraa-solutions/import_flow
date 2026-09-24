import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
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

  const DemurrageState({
    this.policies = const [],
    this.trackings = const [],
    this.simulationResult,
    this.activeAgreement,
    this.isLoading = false,
    this.error,
  });

  DemurrageState copyWith({
    List<DemurragePolicyModel>? policies,
    List<DemurrageTrackingModel>? trackings,
    DemurrageSimulationResultModel? simulationResult,
    FreeDaysAgreementModel? activeAgreement,
    bool? isLoading,
    String? error,
  }) {
    return DemurrageState(
      policies: policies ?? this.policies,
      trackings: trackings ?? this.trackings,
      simulationResult: simulationResult ?? this.simulationResult,
      activeAgreement: activeAgreement ?? this.activeAgreement,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DemurrageNotifier extends StateNotifier<DemurrageState> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchPolicies({String? carrierName}) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final res = await _dio.get(
        '/demurrage-detention/policies',
        queryParameters: carrierName != null ? {'carrier_name': carrierName} : null,
        cancelToken: _cancelToken,
      );
      if (res.data is List) {
        final policies = (res.data as List)
            .map((e) => DemurragePolicyModel.fromJson(e))
            .toList();
        state = state.copyWith(policies: policies, isLoading: false);
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTrackings({int? importFileId, String? carrierName, String? status}) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final queryParams = <String, dynamic>{};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (carrierName != null) queryParams['carrier_name'] = carrierName;
      if (status != null) queryParams['status'] = status;

      final res = await _dio.get(
        '/demurrage-detention/trackings',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        cancelToken: _cancelToken,
      );
      if (res.data is List) {
        final trackings = (res.data as List)
            .map((e) => DemurrageTrackingModel.fromJson(e))
            .toList();
        state = state.copyWith(trackings: trackings, isLoading: false);
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
      state = state.copyWith(error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> pushToSettlement(int trackingId, {int? importFileId}) async {
    try {
      final res = await _dio.post(
        '/demurrage-detention/trackings/push-to-settlement',
        data: {'tracking_id': trackingId, 'import_file_id': importFileId},
      );
      await fetchTrackings();
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      state = state.copyWith(error: e.toString());
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
    } catch (_) {
      // If none registered yet, return null quietly
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

        // Refresh trackings to reflect newly calculated free days
        await fetchTrackings();
        return agreement;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(error: e.toString());
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

        await fetchTrackings();
        return responseModel;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
