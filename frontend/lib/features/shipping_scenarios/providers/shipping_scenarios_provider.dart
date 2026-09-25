import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/shipping_scenario_model.dart';

class ShippingScenariosState {
  final List<ShippingEvaluationModel> sessions;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final int? projectFilter;
  final int? poFilter;
  final bool showInactive;

  ShippingScenariosState({
    this.sessions = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.projectFilter,
    this.poFilter,
    this.showInactive = false,
  });

  ShippingScenariosState copyWith({
    List<ShippingEvaluationModel>? sessions,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    int? projectFilter,
    int? poFilter,
    bool? showInactive,
  }) {
    return ShippingScenariosState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      projectFilter: projectFilter ?? this.projectFilter,
      poFilter: poFilter ?? this.poFilter,
      showInactive: showInactive ?? this.showInactive,
    );
  }
}

class ShippingScenariosNotifier extends StateNotifier<ShippingScenariosState> {
  final Dio _dio;
  CancelToken? _cancelToken;

  ShippingScenariosNotifier(this._dio) : super(ShippingScenariosState()) {
    fetchSessions();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('ShippingScenariosNotifier disposed');
    super.dispose();
  }

  Future<void> fetchSessions() async {
    _cancelToken?.cancel('New fetch requested');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get(
        '/shipping-scenarios',
        queryParameters: {
          'include_inactive': state.showInactive,
          if (state.projectFilter != null) 'project_id': state.projectFilter,
          if (state.poFilter != null) 'po_id': state.poFilter,
          if (state.searchQuery.isNotEmpty) 'search': state.searchQuery,
        },
        cancelToken: cancelToken,
      );
      if (cancelToken.isCancelled) return;
      final List data = response.data;
      final list = data.map((json) => ShippingEvaluationModel.fromJson(json)).toList();
      state = state.copyWith(sessions: list, isLoading: false);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load shipping evaluation studies: ${e.toString()}',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchSessions();
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(projectFilter: projectId);
    fetchSessions();
  }

  void setPoFilter(int? poId) {
    state = state.copyWith(poFilter: poId);
    fetchSessions();
  }

  void toggleShowInactive(bool val) {
    state = state.copyWith(showInactive: val);
    fetchSessions();
  }

  Future<bool> createSession(ShippingEvaluationModel session) async {
    try {
      await _dio.post('/shipping-scenarios', data: session.toCreateJson());
      await fetchSessions();
      return true;
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          msg = data['detail'].toString();
        }
      }
      state = state.copyWith(errorMessage: msg);
      return false;
    }
  }

  Future<bool> updateSession(int sessionId, Map<String, dynamic> data) async {
    try {
      await _dio.put('/shipping-scenarios/$sessionId', data: data);
      await fetchSessions();
      return true;
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          msg = data['detail'].toString();
        }
      }
      state = state.copyWith(errorMessage: msg);
      return false;
    }
  }

  Future<bool> deleteSession(int sessionId) async {
    try {
      await _dio.delete('/shipping-scenarios/$sessionId');
      await fetchSessions();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete evaluation session: ${e.toString()}');
      return false;
    }
  }

  Future<bool> restoreSession(int sessionId) async {
    try {
      await _dio.post('/shipping-scenarios/$sessionId/restore');
      await fetchSessions();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to restore evaluation session: ${e.toString()}');
      return false;
    }
  }

  Future<ShippingEvaluationModel?> cloneSession(
    int sessionId, {
    String? newTitle,
    DateTime? cargoReadyDate,
    bool unlinkImportFile = true,
    bool unlinkPo = true,
    bool copyCarrierOptions = true,
    String? remarks,
  }) async {
    try {
      final response = await _dio.post(
        '/shipping-scenarios/$sessionId/clone',
        data: {
          if (newTitle != null && newTitle.trim().isNotEmpty) 'new_title': newTitle.trim(),
          if (cargoReadyDate != null) 'cargo_ready_date': cargoReadyDate.toIso8601String().substring(0, 10),
          'unlink_import_file': unlinkImportFile,
          'unlink_po': unlinkPo,
          'copy_carrier_options': copyCarrierOptions,
          if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        },
      );
      await fetchSessions();
      if (response.data is Map<String, dynamic>) {
        return ShippingEvaluationModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          msg = data['detail'].toString();
        }
      }
      state = state.copyWith(errorMessage: msg);
      return null;
    }
  }
}

/// Authenticated shared client (Bearer token injected by the interceptor).
final shippingScenariosDioProvider = Provider<Dio>((ref) {
  return ref.watch(dioProvider);
});

final shippingScenariosProvider =
    StateNotifierProvider<ShippingScenariosNotifier, ShippingScenariosState>((ref) {
  final dio = ref.watch(shippingScenariosDioProvider);
  return ShippingScenariosNotifier(dio);
});
