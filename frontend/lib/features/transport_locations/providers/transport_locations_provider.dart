import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/paged_data_table/list_query.dart';
import '../../../core/widgets/paged_data_table/paged_list_notifier.dart';
import '../models/transport_location_model.dart';

/// Live Server-Paged provider for Transport Locations virtualization and server pagination
final transportLocationsPagedProvider = StateNotifierProvider.autoDispose<
    DefaultPagedListNotifier<TransportLocationModel>,
    PagedListState<TransportLocationModel>>((ref) {
  final dio = ref.watch(dioProvider);
  final memoryLocations = ref.watch(transportLocationsProvider).asData?.value ?? <TransportLocationModel>[];

  final PagedSource<TransportLocationModel> source = memoryLocations.isNotEmpty
      ? ClientPagedSource<TransportLocationModel>.fromList(
          memoryLocations,
          searchMatcher: (loc, query) =>
              loc.locationName.toLowerCase().contains(query.toLowerCase()) ||
              loc.unLocode.toLowerCase().contains(query.toLowerCase()) ||
              loc.city.toLowerCase().contains(query.toLowerCase()) ||
              loc.country.toLowerCase().contains(query.toLowerCase()),
        )
      : ServerPagedSource<TransportLocationModel>(
          dio: dio,
          path: '${ApiConstants.baseUrl}/transport-locations/paginated',
          fromJson: TransportLocationModel.fromJson,
        );

  final notifier = DefaultPagedListNotifier<TransportLocationModel>(
    source,
    initialQuery: const ListQuery(page: 1, pageSize: 50, sort: 'un_locode', includeInactive: true),
  );

  notifier.load();
  return notifier;
});

final transportLocationsProvider =
    StateNotifierProvider<TransportLocationsNotifier, AsyncValue<List<TransportLocationModel>>>((ref) {
  return TransportLocationsNotifier(ref.read(dioProvider));
});

class TransportLocationsNotifier extends StateNotifier<AsyncValue<List<TransportLocationModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  TransportLocationsNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchLocations();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('TransportLocationsNotifier disposed');
    super.dispose();
  }

  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {
    _cancelToken?.cancel('Cancelled by new fetchLocations request');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (locationType != null && locationType.isNotEmpty && locationType != 'All') {
        queryParams['location_type'] = locationType;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/transport-locations',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );
      final List data = response.data as List;
      final locations = data.map((json) => TransportLocationModel.fromJson(json)).toList();
      state = AsyncValue.data(locations);
    } catch (err, stack) {
      if (err is DioException && CancelToken.isCancel(err)) return;
      state = AsyncValue.error(err, stack);
    }
  }

  Future<bool> createLocation(TransportLocationModel model) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/transport-locations',
        data: model.toJson(),
      );
      await fetchLocations();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<bool> updateLocation(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '${ApiConstants.baseUrl}/transport-locations/$id',
        data: data,
      );
      await fetchLocations();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<bool> toggleActive(int id, bool currentStatus) async {
    try {
      if (currentStatus) {
        await _dio.delete('${ApiConstants.baseUrl}/transport-locations/$id');
      } else {
        await _dio.post('${ApiConstants.baseUrl}/transport-locations/$id/restore');
      }
      await fetchLocations();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadExcelLocations(List<int> bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/transport-locations/import-excel',
        data: formData,
      );
      await fetchLocations();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw e.response?.data?['detail']?.toString() ?? 'Failed to upload Excel file.';
    } catch (e) {
      throw 'An error occurred during file upload: ${e.toString()}';
    }
  }
}
