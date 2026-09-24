import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_client.dart';
import '../models/step_config_model.dart';

class StepConfigState {
  final bool isLoading;
  final bool isSaving;
  final List<StepConfigModel> configs;
  final int? selectedPhaseFilter;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  const StepConfigState({
    this.isLoading = false,
    this.isSaving = false,
    this.configs = const [],
    this.selectedPhaseFilter,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  List<StepConfigModel> get filteredConfigs {
    return configs.where((c) {
      if (selectedPhaseFilter != null && c.phaseId != selectedPhaseFilter) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchCode = c.stepCode.toLowerCase().contains(q);
        final matchAr = c.stepNameAr.toLowerCase().contains(q);
        final matchEn = c.stepNameEn.toLowerCase().contains(q);
        final matchPolicy = c.skipPolicy.toLowerCase().contains(q);
        if (!matchCode && !matchAr && !matchEn && !matchPolicy) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  StepConfigState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<StepConfigModel>? configs,
    int? selectedPhaseFilter,
    bool clearPhaseFilter = false,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
  }) {
    return StepConfigState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      configs: configs ?? this.configs,
      selectedPhaseFilter: clearPhaseFilter
          ? null
          : (selectedPhaseFilter ?? this.selectedPhaseFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class StepConfigNotifier extends StateNotifier<StepConfigState> {
  final Dio _dio;

  // The role is taken from the JWT by the backend; [ref] is kept for API
  // compatibility with existing callers.
  // ignore: avoid_unused_constructor_parameters
  StepConfigNotifier(this._dio, Ref ref) : super(const StepConfigState()) {
    fetchConfigs();
  }

  Future<void> fetchConfigs() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/lifecycle-board/step-configs',
      );
      if (response.data is List) {
        final list = (response.data as List)
            .map((item) =>
                StepConfigModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(configs: list, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر جلب إعدادات تصنيف المراحل: ${ApiError.message(e)}',
      );
    }
  }

  void setFilterPhase(int? phaseId) {
    if (phaseId == null) {
      state = state.copyWith(clearPhaseFilter: true);
    } else {
      state = state.copyWith(selectedPhaseFilter: phaseId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> updateStepConfig({
    required String stepCode,
    String? skipPolicy,
    List<String>? reasonCategories,
    List<String>? approverRoles,
    bool? supportsPendingReference,
    required String justification,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final payload = <String, dynamic>{
        'justification': justification.trim(),
      };
      if (skipPolicy != null) payload['skip_policy'] = skipPolicy;
      if (reasonCategories != null) {
        payload['reason_categories'] = reasonCategories;
      }
      if (approverRoles != null) payload['approver_roles'] = approverRoles;
      if (supportsPendingReference != null) {
        payload['supports_pending_reference'] = supportsPendingReference;
      }

      final response = await _dio.put(
        '${ApiConstants.baseUrl}/lifecycle-board/step-configs/$stepCode',
        data: payload,
      );

      final updated =
          StepConfigModel.fromJson(response.data as Map<String, dynamic>);
      final updatedList = state.configs.map((c) {
        return c.stepCode == stepCode ? updated : c;
      }).toList();

      state = state.copyWith(
        configs: updatedList,
        isSaving: false,
        successMessage:
            'تم تحديث تصنيف وسياسة المرحلة $stepCode وتوثيق السجل الرقابي بنجاح.',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'فشل تعديل سياسة المرحلة: ${ApiError.message(e)}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'خطأ غير متوقع: $e',
      );
      return false;
    }
  }

  Future<List<StepConfigAuditLogModel>> fetchAuditLogs(String stepCode) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/lifecycle-board/step-configs/$stepCode/audit-logs',
      );
      if (response.data is List) {
        return (response.data as List)
            .map((item) => StepConfigAuditLogModel.fromJson(
                item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> registerPendingReference({
    required String importFileCode,
    required String stepCode,
    required String referenceNumber,
    required String reasonText,
    String? expectedCompletionDate,
  }) async {
    try {
      final payload = {
        'import_file_code': importFileCode,
        'step_code': stepCode,
        'reference_number': referenceNumber.trim(),
        'reason_text': reasonText.trim(),
        'expected_completion_date': expectedCompletionDate,
      };

      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/register-pending-reference',
        data: payload,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final stepConfigProvider =
    StateNotifierProvider<StepConfigNotifier, StepConfigState>((ref) {
  final dio = ref.watch(dioProvider);
  return StepConfigNotifier(dio, ref);
});
