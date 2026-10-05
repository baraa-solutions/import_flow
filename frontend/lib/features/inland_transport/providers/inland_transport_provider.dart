import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/inland_transport_model.dart';

final inlandTransportProvider =
    StateNotifierProvider<InlandTransportNotifier, AsyncValue<List<InlandTransportModel>>>((ref) {
  final dio = ref.read(dioProvider);
  return InlandTransportNotifier(dio, ref);
});

class InlandTransportNotifier extends StateNotifier<AsyncValue<List<InlandTransportModel>>> {
  final Dio _dio;
  final Ref? _ref;

  InlandTransportNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchBookings();
  }

  Future<void> fetchBookings({int? importFileId}) async {
    try {
      state = const AsyncValue.loading();
      final queryParams = <String, dynamic>{'include_inactive': false};
      if (importFileId != null) queryParams['import_file_id'] = importFileId;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/inland-transport/bookings',
        queryParameters: queryParams,
      );

      final list = (response.data as List<dynamic>)
          .map((e) => InlandTransportModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<InlandTransportModel?> fetchBookingByFile(int importFileId) async {
    // FE-06: null only for a 200 with an empty body; every error is rethrown so the
    // caller shows it instead of the empty "create booking" form.
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/inland-transport/bookings/by-file/$importFileId',
    );
    final data = response.data;
    if (data is! Map) return null;
    return InlandTransportModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<InlandTransportModel?> createBooking(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/inland-transport/bookings',
      data: payload,
    );
    final created = InlandTransportModel.fromJson(response.data as Map<String, dynamic>);
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
    await fetchBookings();
    return created;
  }

  Future<InlandTransportModel?> recordGateOut(int transportId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/inland-transport/bookings/$transportId/gate-out',
      data: payload,
    );
    final updated = InlandTransportModel.fromJson(response.data as Map<String, dynamic>);
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
    await fetchBookings();
    return updated;
  }

  Future<InlandTransportModel?> recordWarehouseArrival(int transportId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/inland-transport/bookings/$transportId/warehouse-arrival',
      data: payload,
    );
    final updated = InlandTransportModel.fromJson(response.data as Map<String, dynamic>);
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
    await fetchBookings();
    return updated;
  }

  Future<void> deleteBooking(int transportId) async {
    await _dio.delete(
      '${ApiConstants.baseUrl}/inland-transport/bookings/$transportId',
    );
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
    await fetchBookings();
  }
}
