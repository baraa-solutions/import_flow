import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/custody_release_model.dart';
import '../services/custody_release_service.dart';

final custodyReleaseServiceProvider = Provider<CustodyReleaseService>((ref) {
  final dio = ref.watch(dioProvider);
  return CustodyReleaseService(dio);
});

class CustodyReleaseState {
  final List<CustodyReleaseDossierModel> dossiers;
  final bool isLoading;
  final String? errorMessage;
  final String? statusFilter;
  final bool? lockActiveFilter;

  const CustodyReleaseState({
    this.dossiers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.statusFilter,
    this.lockActiveFilter,
  });

  CustodyReleaseState copyWith({
    List<CustodyReleaseDossierModel>? dossiers,
    bool? isLoading,
    String? errorMessage,
    String? statusFilter,
    bool? lockActiveFilter,
  }) {
    return CustodyReleaseState(
      dossiers: dossiers ?? this.dossiers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusFilter: statusFilter ?? this.statusFilter,
      lockActiveFilter: lockActiveFilter ?? this.lockActiveFilter,
    );
  }
}

class CustodyReleaseNotifier extends StateNotifier<CustodyReleaseState> {
  final CustodyReleaseService _service;

  CustodyReleaseNotifier(this._service) : super(const CustodyReleaseState()) {
    fetchDossiers();
  }

  Future<void> fetchDossiers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.listDossiers(
        status: state.statusFilter,
        lockActive: state.lockActiveFilter,
      );
      state = state.copyWith(dossiers: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setFilter({String? status, bool? lockActive}) {
    state = state.copyWith(statusFilter: status, lockActiveFilter: lockActive);
    fetchDossiers();
  }

  Future<bool> createDossier(Map<String, dynamic> payload) async {
    try {
      await _service.createDossier(payload);
      await fetchDossiers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> freezeInWarehouse(int custodyId, Map<String, dynamic> payload) async {
    try {
      await _service.freezeInWarehouse(custodyId, payload);
      await fetchDossiers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> approveFinalClearance(int custodyId, Map<String, dynamic> payload) async {
    try {
      await _service.approveFinalClearance(custodyId, payload);
      await fetchDossiers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> reportBreach(int custodyId, Map<String, dynamic> payload) async {
    try {
      await _service.reportBreach(custodyId, payload);
      await fetchDossiers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteDossier(int custodyId) async {
    try {
      await _service.deleteDossier(custodyId);
      await fetchDossiers();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final custodyReleaseProvider =
    StateNotifierProvider<CustodyReleaseNotifier, CustodyReleaseState>((ref) {
  final service = ref.watch(custodyReleaseServiceProvider);
  return CustodyReleaseNotifier(service);
});
