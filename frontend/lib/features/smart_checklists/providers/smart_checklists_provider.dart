import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/checklist_item_model.dart';

class SmartChecklistState {
  final ChecklistSummaryModel? summary;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String selectedPhase; // 'ALL', 'PRE_SHIPMENT', 'IN_TRANSIT', 'PORT_ARRIVAL', 'CLEARANCE', 'POST_CLEARANCE'
  final String selectedRole; // 'ALL', 'COORDINATOR', 'SUPPLIER', 'CUSTOMS_BROKER', 'SHIPPING_LINE'

  const SmartChecklistState({
    this.summary,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.selectedPhase = 'ALL',
    this.selectedRole = 'ALL',
  });

  SmartChecklistState copyWith({
    ChecklistSummaryModel? summary,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    String? selectedPhase,
    String? selectedRole,
  }) {
    return SmartChecklistState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      selectedPhase: selectedPhase ?? this.selectedPhase,
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }

  List<ChecklistItemModel> get filteredItems {
    if (summary == null) return [];
    return summary!.items.where((item) {
      final matchPhase = (selectedPhase == 'ALL') || (item.phaseCode == selectedPhase);
      final matchRole = (selectedRole == 'ALL') || (item.responsibleRole == selectedRole);
      return matchPhase && matchRole;
    }).toList();
  }
}

class SmartChecklistNotifier extends StateNotifier<SmartChecklistState> {
  final Dio _dio;

  /// [_dio] must be the authenticated client from `dioProvider`.
  SmartChecklistNotifier(this._dio) : super(const SmartChecklistState());

  Future<void> fetchChecklist(int fileId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('${ApiConstants.importFiles}/$fileId/checklist');
      if (response.statusCode == 200 && response.data != null) {
        final summary = ChecklistSummaryModel.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(summary: summary, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: 'تعذر جلب قائمة التحقق');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> autoSync(int fileId) async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      await _dio.post('${ApiConstants.importFiles}/$fileId/checklist/auto-sync');
      await fetchChecklist(fileId);
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }

  Future<bool> toggleItem({
    required int fileId,
    required int itemId,
    required String newStatus,
    String? notes,
    String? verifiedBy,
  }) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.importFiles}/$fileId/checklist/$itemId/toggle',
        data: {
          'status': newStatus,
          'notes': notes,
          'verified_by': verifiedBy ?? 'Kamal',
        },
      );
      if (response.statusCode == 200) {
        await fetchChecklist(fileId);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> overrideItem({
    required int fileId,
    required int itemId,
    required String reason,
    String? authorizedBy,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.importFiles}/$fileId/checklist/$itemId/override',
        data: {
          'reason': reason,
          'authorized_by': authorizedBy ?? 'Operations Manager',
        },
      );
      if (response.statusCode == 200) {
        await fetchChecklist(fileId);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void setPhaseFilter(String phase) {
    state = state.copyWith(selectedPhase: phase);
  }

  void setRoleFilter(String role) {
    state = state.copyWith(selectedRole: role);
  }
}

final smartChecklistProvider =
    StateNotifierProvider.autoDispose<SmartChecklistNotifier, SmartChecklistState>((ref) {
  return SmartChecklistNotifier(ref.watch(dioProvider));
});
