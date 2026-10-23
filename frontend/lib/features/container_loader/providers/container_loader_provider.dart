import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/container_loader_model.dart';
import '../services/container_loader_service.dart';

final containerLoaderServiceProvider = Provider<ContainerLoaderService>((ref) {
  final dio = ref.watch(dioProvider);
  return ContainerLoaderService(dio);
});

class ContainerLoaderState {
  final List<ContainerSpecModel> specs;
  final ContainerLoaderEvaluationResultModel? evaluationResult;
  final bool isLoading;
  final String? errorMessage;

  const ContainerLoaderState({
    this.specs = const [],
    this.evaluationResult,
    this.isLoading = false,
    this.errorMessage,
  });

  ContainerLoaderState copyWith({
    List<ContainerSpecModel>? specs,
    ContainerLoaderEvaluationResultModel? evaluationResult,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ContainerLoaderState(
      specs: specs ?? this.specs,
      evaluationResult: evaluationResult ?? this.evaluationResult,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ContainerLoaderNotifier extends StateNotifier<ContainerLoaderState> {
  final ContainerLoaderService _service;

  ContainerLoaderNotifier(this._service) : super(const ContainerLoaderState()) {
    fetchSpecs();
  }

  Future<void> fetchSpecs() async {
    try {
      final specs = await _service.getSpecs();
      state = state.copyWith(specs: specs);
    } catch (_) {}
  }

  Future<ContainerLoaderEvaluationResultModel?> evaluateLoading(Map<String, dynamic> request) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _service.evaluateLoading(request);
      state = state.copyWith(evaluationResult: result, isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final containerLoaderProvider =
    StateNotifierProvider<ContainerLoaderNotifier, ContainerLoaderState>((ref) {
  final service = ref.watch(containerLoaderServiceProvider);
  return ContainerLoaderNotifier(service);
});
