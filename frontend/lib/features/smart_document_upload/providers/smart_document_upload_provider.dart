import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/smart_document_upload_model.dart';
import '../services/smart_document_upload_service.dart';

final smartDocumentUploadServiceProvider = Provider<SmartDocumentUploadService>((ref) {
  final dio = ref.watch(dioProvider);
  return SmartDocumentUploadService(dio);
});

class SmartDocumentUploadState {
  final List<UploadSessionModel> sessions;
  final List<String> supportedModules;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedModuleFilter;

  const SmartDocumentUploadState({
    this.sessions = const [],
    this.supportedModules = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedModuleFilter,
  });

  SmartDocumentUploadState copyWith({
    List<UploadSessionModel>? sessions,
    List<String>? supportedModules,
    bool? isLoading,
    String? errorMessage,
    String? selectedModuleFilter,
  }) {
    return SmartDocumentUploadState(
      sessions: sessions ?? this.sessions,
      supportedModules: supportedModules ?? this.supportedModules,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedModuleFilter: selectedModuleFilter ?? this.selectedModuleFilter,
    );
  }
}

class SmartDocumentUploadNotifier extends StateNotifier<SmartDocumentUploadState> {
  final SmartDocumentUploadService _service;

  SmartDocumentUploadNotifier(this._service) : super(const SmartDocumentUploadState()) {
    fetchSessions();
    fetchSupportedModules();
  }

  Future<void> fetchSessions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.listSessions(moduleName: state.selectedModuleFilter);
      state = state.copyWith(sessions: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchSupportedModules() async {
    try {
      final modules = await _service.listSupportedModules();
      state = state.copyWith(supportedModules: modules);
    } catch (_) {}
  }

  void filterModule(String? module) {
    state = state.copyWith(selectedModuleFilter: module);
    fetchSessions();
  }

  Future<bool> deleteSession(int sessionId) async {
    try {
      await _service.deleteSession(sessionId);
      await fetchSessions();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> parseRawText(String module, String text) async {
    try {
      final res = await _service.parseRawText(module, text);
      await fetchSessions();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> crossCheckInvoiceVsBL({
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> blData,
    double tolerance = 3.0,
  }) async {
    try {
      return await _service.crossCheckInvoiceVsBL(
        invoiceData: invoiceData,
        blData: blData,
        tolerance: tolerance,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }
}

final smartDocumentUploadProvider =
    StateNotifierProvider<SmartDocumentUploadNotifier, SmartDocumentUploadState>((ref) {
  final service = ref.watch(smartDocumentUploadServiceProvider);
  return SmartDocumentUploadNotifier(service);
});
