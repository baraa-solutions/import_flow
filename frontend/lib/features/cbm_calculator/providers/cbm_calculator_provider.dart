import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../models/cbm_calculator_model.dart';

class CBMCalculatorState {
  final List<CBMCalculationModel> calculations;
  final bool isLoading;
  /// Last failure (raw), rendered with `ApiErrorText.of` (localized; a 403 reads as "no permission").
  final Object? error;
  final String searchQuery;
  final int? projectFilter;
  final int? poFilter;
  final bool showInactive;

  // Quick calc active result
  final Map<String, dynamic>? quickCalcResult;

  CBMCalculatorState({
    this.calculations = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.projectFilter,
    this.poFilter,
    this.showInactive = false,
    this.quickCalcResult,
  });

  CBMCalculatorState copyWith({
    List<CBMCalculationModel>? calculations,
    bool? isLoading,
    Object? error,
    String? searchQuery,
    int? projectFilter,
    int? poFilter,
    bool? showInactive,
    Map<String, dynamic>? quickCalcResult,
  }) {
    return CBMCalculatorState(
      calculations: calculations ?? this.calculations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      projectFilter: projectFilter ?? this.projectFilter,
      poFilter: poFilter ?? this.poFilter,
      showInactive: showInactive ?? this.showInactive,
      quickCalcResult: quickCalcResult ?? this.quickCalcResult,
    );
  }

  /// Localized text of the last failure.
  String errorText(AppLocalizations l10n) => ApiErrorText.of(l10n, error, fallback: l10n.operationFailed);
}

class CBMCalculatorNotifier extends StateNotifier<CBMCalculatorState> {
  final Dio _dio;
  CancelToken? _cancelToken;

  CBMCalculatorNotifier(this._dio) : super(CBMCalculatorState()) {
    fetchCalculations();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CBMCalculatorNotifier disposed');
    super.dispose();
  }

  Future<void> fetchCalculations() async {
    _cancelToken?.cancel('New fetch requested');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get(
        '/cbm-calculator',
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
      final list = data.map((json) => CBMCalculationModel.fromJson(json)).toList();
      state = state.copyWith(calculations: list, isLoading: false);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    }
  }

  Future<Map<String, dynamic>?> quickCalculate(List<CBMItemModel> items) async {
    try {
      final response = await _dio.post('/cbm-calculator/quick-calculate', data: {
        'items': items.map((i) => i.toCreateJson()).toList(),
      });
      state = state.copyWith(quickCalcResult: response.data);
      return response.data;
    } catch (e) {
      state = state.copyWith(error: e);
      return null;
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchCalculations();
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(projectFilter: projectId);
    fetchCalculations();
  }

  void setPoFilter(int? poId) {
    state = state.copyWith(poFilter: poId);
    fetchCalculations();
  }

  void toggleShowInactive(bool val) {
    state = state.copyWith(showInactive: val);
    fetchCalculations();
  }

  Future<bool> createCalculation(CBMCalculationModel calc) async {
    try {
      await _dio.post('/cbm-calculator', data: calc.toCreateJson());
      await fetchCalculations();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> updateCalculation(int calcId, Map<String, dynamic> data) async {
    try {
      await _dio.put('/cbm-calculator/$calcId', data: data);
      await fetchCalculations();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> linkToPO(int calcId, {int? poId, int? projectId}) async {
    try {
      await _dio.post('/cbm-calculator/$calcId/link', data: {
        if (poId != null) 'po_id': poId,
        if (projectId != null) 'project_id': projectId,
      });
      await fetchCalculations();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> deleteCalculation(int calcId) async {
    try {
      await _dio.delete('/cbm-calculator/$calcId');
      await fetchCalculations();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<bool> restoreCalculation(int calcId) async {
    try {
      await _dio.post('/cbm-calculator/$calcId/restore');
      await fetchCalculations();
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<CBMCalculationModel?> cloneCalculation(
    int calcId, {
    String? newCode,
    String? newTitle,
    bool copyItems = true,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/cbm-calculator/$calcId/clone',
        data: {
          if (newCode != null && newCode.isNotEmpty) 'new_code': newCode,
          if (newTitle != null && newTitle.isNotEmpty) 'new_title': newTitle,
          'copy_items': copyItems,
          if (notes != null) 'notes': notes,
        },
      );
      await fetchCalculations();
      return CBMCalculationModel.fromJson(response.data);
    } catch (e) {
      state = state.copyWith(error: e);
      return null;
    }
  }
}

/// Authenticated shared client (Bearer token injected by the interceptor).
final cbmDioProvider = Provider<Dio>((ref) {
  return ref.watch(dioProvider);
});

final cbmCalculatorProvider = StateNotifierProvider<CBMCalculatorNotifier, CBMCalculatorState>((ref) {
  final dio = ref.watch(cbmDioProvider);
  return CBMCalculatorNotifier(dio);
});
