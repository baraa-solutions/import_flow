import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/system_parameter_model.dart';
import '../services/system_parameters_service.dart';

final systemParametersServiceProvider = Provider<SystemParametersService>((ref) {
  final dio = ref.watch(dioProvider);
  return SystemParametersService(dio);
});

class SystemParametersState {
  final List<SystemParameterModel> parameters;
  final bool isLoading;
  final String? errorMessage;

  const SystemParametersState({
    this.parameters = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SystemParametersState copyWith({
    List<SystemParameterModel>? parameters,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SystemParametersState(
      parameters: parameters ?? this.parameters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SystemParametersNotifier extends StateNotifier<SystemParametersState> {
  final SystemParametersService _service;

  SystemParametersNotifier(this._service) : super(const SystemParametersState()) {
    fetchParameters();
  }

  Future<void> fetchParameters() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.getParameters();
      state = state.copyWith(parameters: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> updateParameter({
    required String key,
    required String value,
    required String justification,
  }) async {
    try {
      final updated = await _service.updateParameter(
        key: key,
        value: value,
        justification: justification,
      );
      final list = state.parameters.map((p) => p.paramKey == key ? updated : p).toList();
      state = state.copyWith(parameters: list);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final systemParametersProvider =
    StateNotifierProvider<SystemParametersNotifier, SystemParametersState>((ref) {
  final service = ref.watch(systemParametersServiceProvider);
  return SystemParametersNotifier(service);
});
