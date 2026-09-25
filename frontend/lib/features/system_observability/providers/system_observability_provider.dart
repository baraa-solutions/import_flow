import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../models/system_observability_model.dart';

final autoRefreshObservabilityProvider = StateProvider<bool>((ref) => false);

final systemMetricsProvider = FutureProvider.autoDispose<SystemMetricsModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/system/observability/metrics');
  return SystemMetricsModel.fromJson(response.data);
});

final databaseHealthProvider = FutureProvider.autoDispose<DatabaseHealthModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/system/observability/database');
  return DatabaseHealthModel.fromJson(response.data);
});

final domainRadarProvider = FutureProvider.autoDispose<DomainRadarModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/system/observability/domain-radar');
  return DomainRadarModel.fromJson(response.data);
});

final recentTrafficProvider = FutureProvider.autoDispose<List<RecentTrafficItemModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/system/observability/recent-traffic', queryParameters: {'limit': 30});
  final rawList = response.data as List<dynamic>? ?? [];
  return rawList.map((e) => RecentTrafficItemModel.fromJson(e)).toList();
});

class DeepHealthStateNotifier extends StateNotifier<AsyncValue<DeepHealthCheckModel?>> {
  final Dio _dio;
  DeepHealthStateNotifier(this._dio) : super(const AsyncValue.data(null));

  Future<void> runProbe() async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get('/system/health/deep');
      final model = DeepHealthCheckModel.fromJson(response.data);
      state = AsyncValue.data(model);
    } catch (e, st) {
      // Admin-only route: surface the backend detail (e.g. 403) as the error.
      state = AsyncValue.error(ApiError.message(e), st);
    }
  }
}

final deepHealthProbeProvider =
    StateNotifierProvider.autoDispose<DeepHealthStateNotifier, AsyncValue<DeepHealthCheckModel?>>((ref) {
  final dio = ref.watch(dioProvider);
  return DeepHealthStateNotifier(dio);
});
