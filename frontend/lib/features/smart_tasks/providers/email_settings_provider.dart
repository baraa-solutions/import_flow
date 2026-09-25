import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../models/email_settings_model.dart';
import 'smart_tasks_provider.dart';

class EmailSettingsState {
  final bool isLoading;
  final bool isTesting;
  final bool isFetching;
  final bool isSaving;
  final bool isCheckingOutlook;
  final String? error;
  final EmailSettingsModel? settings;
  final EmailConnectionTestResultModel? testResult;
  final InboxFetchResultModel? fetchResult;
  final LocalOutlookStatusModel? localOutlookStatus;

  EmailSettingsState({
    this.isLoading = false,
    this.isTesting = false,
    this.isFetching = false,
    this.isSaving = false,
    this.isCheckingOutlook = false,
    this.error,
    this.settings,
    this.testResult,
    this.fetchResult,
    this.localOutlookStatus,
  });

  EmailSettingsState copyWith({
    bool? isLoading,
    bool? isTesting,
    bool? isFetching,
    bool? isSaving,
    bool? isCheckingOutlook,
    String? error,
    EmailSettingsModel? settings,
    EmailConnectionTestResultModel? testResult,
    InboxFetchResultModel? fetchResult,
    LocalOutlookStatusModel? localOutlookStatus,
  }) {
    return EmailSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isTesting: isTesting ?? this.isTesting,
      isFetching: isFetching ?? this.isFetching,
      isSaving: isSaving ?? this.isSaving,
      isCheckingOutlook: isCheckingOutlook ?? this.isCheckingOutlook,
      error: error,
      settings: settings ?? this.settings,
      testResult: testResult ?? this.testResult,
      fetchResult: fetchResult ?? this.fetchResult,
      localOutlookStatus: localOutlookStatus ?? this.localOutlookStatus,
    );
  }
}

final emailSettingsProvider =
    StateNotifierProvider<EmailSettingsNotifier, EmailSettingsState>((ref) {
  final dio = ref.read(dioProvider);
  return EmailSettingsNotifier(dio, ref);
});

class EmailSettingsNotifier extends StateNotifier<EmailSettingsState> {
  final Dio _dio;
  final Ref _ref;

  EmailSettingsNotifier(this._dio, this._ref) : super(EmailSettingsState()) {
    fetchSettings();
    checkLocalOutlookStatus();
  }

  Future<LocalOutlookStatusModel?> checkLocalOutlookStatus() async {
    state = state.copyWith(isCheckingOutlook: true);
    try {
      final response = await _dio.get('${ApiConstants.smartEmail}/local-outlook-status');
      if (response.data != null && response.data is Map<String, dynamic>) {
        final model = LocalOutlookStatusModel.fromJson(response.data);
        state = state.copyWith(isCheckingOutlook: false, localOutlookStatus: model);
        return model;
      }
    } catch (_) {
      // Ignore failure if not available
    }
    state = state.copyWith(isCheckingOutlook: false);
    return null;
  }

  Future<void> fetchSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('${ApiConstants.smartEmail}/settings');
      if (response.data != null && response.data is Map<String, dynamic>) {
        final model = EmailSettingsModel.fromJson(response.data);
        state = state.copyWith(isLoading: false, settings: model);
      } else {
        state = state.copyWith(isLoading: false, settings: null);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.message(e));
    }
  }

  Future<bool> saveSettings(EmailSettingsModel model, {String? newPassword}) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final payload = model.toJson(newPassword: newPassword);
      final response = await _dio.post('${ApiConstants.smartEmail}/settings', data: payload);
      final updatedModel = EmailSettingsModel.fromJson(response.data);
      state = state.copyWith(isSaving: false, settings: updatedModel);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: ApiError.message(e));
      return false;
    }
  }

  Future<EmailConnectionTestResultModel?> testConnection(Map<String, dynamic> testPayload) async {
    state = state.copyWith(isTesting: true, error: null, testResult: null);
    try {
      final response = await _dio.post('${ApiConstants.smartEmail}/test-connection', data: testPayload);
      final res = EmailConnectionTestResultModel.fromJson(response.data);
      state = state.copyWith(isTesting: false, testResult: res);
      return res;
    } catch (e) {
      final fail = EmailConnectionTestResultModel(
        imapConnected: false,
        imapMessage: 'خطأ أثناء اختبار الاتصال: ${ApiError.message(e)}',
        smtpConnected: false,
        smtpMessage: 'فشل إرسال طلب الاختبار',
        overallSuccess: false,
        details: ApiError.message(e),
      );
      state = state.copyWith(isTesting: false, testResult: fail, error: ApiError.message(e));
      return fail;
    }
  }

  Future<InboxFetchResultModel?> fetchInboxNow({
    int maxEmails = 20,
    String folder = 'INBOX',
    bool onlyUnseen = false,
  }) async {
    state = state.copyWith(isFetching: true, error: null, fetchResult: null);
    try {
      final response = await _dio.post(
        '${ApiConstants.smartEmail}/fetch-inbox',
        data: {
          'max_emails': maxEmails,
          'folder': folder,
          'only_unseen': onlyUnseen,
        },
      );
      final res = InboxFetchResultModel.fromJson(response.data);
      state = state.copyWith(isFetching: false, fetchResult: res);
      // Refresh tasks list and settings
      _ref.read(smartTasksProvider.notifier).fetchTasks();
      fetchSettings();
      return res;
    } catch (e) {
      state = state.copyWith(isFetching: false, error: ApiError.message(e));
      return null;
    }
  }

  Future<bool> approveAndRouteTasks(List<TaskRouteApprovalItemModel> approvedTasks) async {
    if (approvedTasks.isEmpty) return false;
    try {
      final payload = {
        'tasks': approvedTasks.map((t) => t.toJson()).toList(),
      };
      await _dio.post(
        '${ApiConstants.smartEmail}/approve-and-route-tasks',
        data: payload,
      );
      // Automatically refresh smart tasks list
      _ref.read(smartTasksProvider.notifier).fetchTasks();
      return true;
    } catch (e) {
      state = state.copyWith(error: ApiError.message(e));
      return false;
    }
  }
}
