import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/freight_booking_model.dart';
import '../models/shipment_eta_tracking_log_model.dart';
import '../../../core/network/api_client.dart';


import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';


final freightBookingProvider =
    StateNotifierProvider<FreightBookingNotifier, AsyncValue<List<ShipmentBookingModel>>>((ref) {
  return FreightBookingNotifier(ref.read(dioProvider), ref);
});

class FreightBookingNotifier extends StateNotifier<AsyncValue<List<ShipmentBookingModel>>> {
  final Dio _dio;
  final Ref? _ref;
  CancelToken? _cancelToken;

  FreightBookingNotifier(this._dio, [this._ref]) : super(const AsyncValue.loading()) {
    fetchBookings();
  }

  void _invalidateRelatedProviders() {
    _ref?.invalidate(importFilesProvider);
    _ref?.invalidate(smartTasksProvider);
  }

  @override
  void dispose() {
    _cancelToken?.cancel('FreightBookingNotifier disposed');
    super.dispose();
  }

  int? totalCount;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  // Filters of the last fetch, reused by loadMore so the next page matches the visible list.
  bool _lastIncludeInactive = false;
  int? _lastImportFileId;
  String? _lastStatus;
  String? _lastSearch;

  bool get hasMore => totalCount != null && (state.valueOrNull?.length ?? 0) < totalCount!;

  Future<void> fetchBookings({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
    int skip = 0,
    int limit = 200,
  }) async {
    _lastIncludeInactive = includeInactive;
    _lastImportFileId = importFileId;
    _lastStatus = status;
    _lastSearch = search;
    _cancelToken?.cancel('Cancelled by new fetchBookings request');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
        'skip': skip,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/freight-booking',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final totalHeader = response.headers.value('x-total-count');
      if (totalHeader != null) {
        totalCount = int.tryParse(totalHeader);
      }

      final List data = response.data;
      final list = data.map((json) => ShipmentBookingModel.fromJson(json)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore({
    bool? includeInactive,
    int? importFileId,
    String? status,
    String? search,
    int limit = 200,
  }) async {
    includeInactive ??= _lastIncludeInactive;
    importFileId ??= _lastImportFileId;
    status ??= _lastStatus;
    search ??= _lastSearch;
    if (_isLoadingMore || !hasMore) return;
    final currentList = state.valueOrNull ?? [];
    _isLoadingMore = true;
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
        'skip': currentList.length,
        'limit': limit,
      };
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/freight-booking',
        queryParameters: queryParams,
      );

      final totalHeader = response.headers.value('x-total-count');
      if (totalHeader != null) {
        totalCount = int.tryParse(totalHeader);
      }

      final List data = response.data;
      final nextItems = data.map((json) => ShipmentBookingModel.fromJson(json)).toList();
      state = AsyncValue.data([...currentList, ...nextItems]);
    } catch (e) {
      // Keep existing data on pagination failure
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    await fetchBookings(
      includeInactive: _lastIncludeInactive,
      importFileId: _lastImportFileId,
      status: _lastStatus,
      search: _lastSearch,
    );
  }

  Future<ShipmentBookingModel?> createBooking(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/freight-booking',
        data: payload,
      );
      final created = ShipmentBookingModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await refresh();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<ShipmentBookingModel?> updateBooking(int bookingId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/freight-booking/$bookingId',
        data: payload,
      );
      final updated = ShipmentBookingModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await refresh();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<ShipmentBookingModel?> confirmBooking(int bookingId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/freight-booking/$bookingId/confirm',
        data: payload,
      );
      final confirmed = ShipmentBookingModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await refresh();
      return confirmed;
    } catch (e) {
      rethrow;
    }
  }

  Future<ShipmentBookingModel?> confirmDepartureAndBol(int bookingId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/freight-booking/$bookingId/depart',
        data: payload,
      );
      final departed = ShipmentBookingModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await refresh();
      return departed;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteBooking(int bookingId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/freight-booking/$bookingId');
      _invalidateRelatedProviders();
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreBooking(int bookingId) async {
    try {
      await _dio.patch('${ApiConstants.baseUrl}/freight-booking/$bookingId/restore');
      _invalidateRelatedProviders();
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ShipmentEtaTrackingLogModel>> fetchEtaTrackingLogs(int bookingId) async {
    try {
      final response = await _dio.get('${ApiConstants.baseUrl}/freight-booking/bookings/$bookingId/eta-tracking-logs');
      return (response.data as List).map((j) => ShipmentEtaTrackingLogModel.fromJson(j)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ShipmentEtaTrackingLogModel> createEtaTrackingLog(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('${ApiConstants.baseUrl}/freight-booking/eta-tracking-logs', data: payload);
      final log = ShipmentEtaTrackingLogModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await fetchBookings();
      return log;
    } catch (e) {
      rethrow;
    }
  }

  Future<ShipmentEtaTrackingLogModel> confirmAta(int bookingId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('${ApiConstants.baseUrl}/freight-booking/bookings/$bookingId/confirm-ata', data: payload);
      final log = ShipmentEtaTrackingLogModel.fromJson(response.data);
      _invalidateRelatedProviders();
      await fetchBookings();
      return log;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateAirWeight(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/freight-booking/calculate-air-weight',
        data: payload,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}

final etaTrackingLogsProvider = FutureProvider.family<List<ShipmentEtaTrackingLogModel>, int>((ref, bookingId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/freight-booking/bookings/$bookingId/eta-tracking-logs');
  return (response.data as List).map((j) => ShipmentEtaTrackingLogModel.fromJson(j)).toList();
});

