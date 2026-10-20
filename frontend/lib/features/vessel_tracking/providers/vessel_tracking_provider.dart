import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/vessel_tracking_model.dart';

final vesselTrackingRadarProvider = StateNotifierProvider<
    VesselTrackingRadarNotifier, AsyncValue<LiveRadarOverviewModel>>((ref) {
  return VesselTrackingRadarNotifier(ref.read(dioProvider));
});

class VesselTrackingRadarNotifier
    extends StateNotifier<AsyncValue<LiveRadarOverviewModel>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  VesselTrackingRadarNotifier(this._dio)
      : super(const AsyncValue.loading()) {
    fetchRadarOverview();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('VesselTrackingRadarNotifier disposed');
    super.dispose();
  }

  Future<void> fetchRadarOverview() async {
    _cancelToken?.cancel('New fetchRadarOverview request');
    _cancelToken = CancelToken();

    try {
      state = const AsyncValue.loading();
      final response = await _dio.get(
        ApiConstants.vesselTrackingRadar,
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final model = LiveRadarOverviewModel.fromJson(
            response.data as Map<String, dynamic>);
        state = AsyncValue.data(model);
      } else {
        state = AsyncValue.error(
          'فشل تحميل بيانات رادار تتبع السفن (${response.statusCode})',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<ShipmentTrackingModel?> simulateStep({
    required int importFileId,
    double hoursAdvance = 4.0,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.vesselTracking}/simulate-step/$importFileId',
        queryParameters: {'hours_advance': hoursAdvance},
      );

      if (response.statusCode == 200 && response.data != null) {
        final updated = ShipmentTrackingModel.fromJson(
            response.data as Map<String, dynamic>);
        // Refresh full overview to sync metrics
        await fetchRadarOverview();
        return updated;
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  Future<ShipmentTrackingModel?> confirmArrival({
    required int importFileId,
    DateTime? actualArrivalDate,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.vesselConfirmArrival(importFileId),
        data: {
          if (actualArrivalDate != null)
            'actual_arrival_date': actualArrivalDate.toIso8601String(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final updated = ShipmentTrackingModel.fromJson(
            response.data as Map<String, dynamic>);
        // Refresh full overview to sync metrics
        await fetchRadarOverview();
        return updated;
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }
}

