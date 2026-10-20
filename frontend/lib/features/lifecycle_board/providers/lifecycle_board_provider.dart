import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/lifecycle_board_model.dart';
import '../models/timeline_snapshot_model.dart';
import '../../../core/network/api_client.dart';

/// Extracts the human-readable `detail` message from a FastAPI error response.
/// Falls back to a generic message when the response body is unavailable.
String _extractErrorDetail(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (e.message != null && e.message!.isNotEmpty) return e.message!;
  }
  return e.toString();
}


final lifecycleBoardSummaryProvider =
    FutureProvider.autoDispose<LifecycleBoardSummaryModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('lifecycleBoardSummaryProvider disposed'));
  final response = await dio.get(
    '${ApiConstants.baseUrl}/lifecycle-board/summary',
    cancelToken: cancelToken,
  );
  return LifecycleBoardSummaryModel.fromJson(response.data);
});

final liveLogisticsTrackingProvider =
    FutureProvider.autoDispose<LiveLogisticsSummaryModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('liveLogisticsTrackingProvider disposed'));
  final response = await dio.get(
    '${ApiConstants.baseUrl}/lifecycle-board/live-tracking',
    cancelToken: cancelToken,
  );
  return LiveLogisticsSummaryModel.fromJson(response.data);
});

final timelineSnapshotsProvider =
    FutureProvider.family.autoDispose<TimelineSummaryModel, int>((ref, importFileId) async {
  final dio = ref.watch(dioProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('timelineSnapshotsProvider disposed'));
  final response = await dio.get(
    '${ApiConstants.baseUrl}/lifecycle-board/files/$importFileId/timeline-snapshots',
    cancelToken: cancelToken,
  );
  return TimelineSummaryModel.fromJson(response.data);
});

class LifecycleBoardNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final Dio _dio;

  /// Last error detail from the backend (Arabic message from FastAPI HTTPException).
  /// Null when last operation succeeded.
  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  LifecycleBoardNotifier(this.ref, this._dio) : super(const AsyncValue.data(null));

  Future<bool> advanceStep({
    required String importFileCode,
    required String currentStepCode,
    required List<String> nextStepCodes,
    String? notes,
    Map<String, dynamic>? actionData,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/advance',
        data: {
          'import_file_code': importFileCode,
          'current_step_code': currentStepCode,
          'next_step_codes': nextStepCodes,
          'notes': notes,
          'action_data': actionData,
        },
      );
      _lastErrorMessage = null;
      state = const AsyncValue.data(null);
      ref.invalidate(lifecycleBoardSummaryProvider);
      return true;
    } catch (e, st) {
      _lastErrorMessage = _extractErrorDetail(e);
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> skipStep({
    required String importFileCode,
    required String currentStepCode,
    required String skipReason,
    List<String> nextStepCodes = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/skip',
        data: {
          'import_file_code': importFileCode,
          'current_step_code': currentStepCode,
          'skip_reason': skipReason,
          'next_step_codes': nextStepCodes,
        },
      );
      _lastErrorMessage = null;
      state = const AsyncValue.data(null);
      ref.invalidate(lifecycleBoardSummaryProvider);
      return true;
    } catch (e, st) {
      _lastErrorMessage = _extractErrorDetail(e);
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setMultiActiveStages({
    required String importFileCode,
    required List<String> activeStepCodes,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/stages/set-active',
        data: {
          'import_file_code': importFileCode,
          'active_step_codes': activeStepCodes,
          'notes': notes,
        },
      );
      _lastErrorMessage = null;
      state = const AsyncValue.data(null);
      ref.invalidate(lifecycleBoardSummaryProvider);
      return true;
    } catch (e, st) {
      _lastErrorMessage = _extractErrorDetail(e);
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Triggers full 25-stage operational timeline synchronization (TASK-BE-09).
  Future<bool> syncFileTimeline(int importFileId) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/lifecycle-board/files/$importFileId/sync-timeline',
      );
      _lastErrorMessage = null;
      state = const AsyncValue.data(null);
      ref.invalidate(timelineSnapshotsProvider(importFileId));
      ref.invalidate(lifecycleBoardSummaryProvider);
      return true;
    } catch (e, st) {
      _lastErrorMessage = _extractErrorDetail(e);
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final lifecycleBoardActionProvider =
    StateNotifierProvider<LifecycleBoardNotifier, AsyncValue<void>>((ref) {
  return LifecycleBoardNotifier(ref, ref.read(dioProvider));
});
