import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/formal_letter_model.dart';
import '../services/formal_letters_service.dart';

final formalLettersServiceProvider = Provider<FormalLettersService>((ref) {
  final dio = ref.watch(dioProvider);
  return FormalLettersService(dio);
});

class FormalLettersState {
  final List<FormalLetterTemplateInfo> templates;
  final List<FormalLetterRecordModel> history;
  final FormalLetterResponseModel? lastGenerated;
  final bool isLoading;
  final String? errorMessage;

  const FormalLettersState({
    this.templates = const [],
    this.history = const [],
    this.lastGenerated,
    this.isLoading = false,
    this.errorMessage,
  });

  FormalLettersState copyWith({
    List<FormalLetterTemplateInfo>? templates,
    List<FormalLetterRecordModel>? history,
    FormalLetterResponseModel? lastGenerated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FormalLettersState(
      templates: templates ?? this.templates,
      history: history ?? this.history,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FormalLettersNotifier extends StateNotifier<FormalLettersState> {
  final FormalLettersService _service;

  FormalLettersNotifier(this._service) : super(const FormalLettersState()) {
    fetchTemplates();
  }

  Future<void> fetchTemplates() async {
    try {
      final templates = await _service.getTemplates();
      state = state.copyWith(templates: templates);
    } catch (_) {}
  }

  Future<void> fetchHistory(int importFileId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final history = await _service.getHistory(importFileId);
      state = state.copyWith(history: history, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<FormalLetterResponseModel?> generateLetter(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _service.generateLetter(payload);
      state = state.copyWith(lastGenerated: res, isLoading: false);
      if (payload['import_file_id'] != null) {
        await fetchHistory(payload['import_file_id'] as int);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final formalLettersProvider =
    StateNotifierProvider<FormalLettersNotifier, FormalLettersState>((ref) {
  final service = ref.watch(formalLettersServiceProvider);
  return FormalLettersNotifier(service);
});
