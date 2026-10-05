import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/cargo_insurance_model.dart';

final cargoInsuranceProvider =
    StateNotifierProvider<CargoInsuranceNotifier, AsyncValue<List<CargoInsuranceModel>>>((ref) {
  return CargoInsuranceNotifier(ref.read(dioProvider));
});

class CargoInsuranceNotifier extends StateNotifier<AsyncValue<List<CargoInsuranceModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  CargoInsuranceNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchCertificates();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CargoInsuranceNotifier disposed');
    super.dispose();
  }

  /// Page size sent as `limit` (backend default 50, max 100).
  static const int pageSize = 50;

  int _total = 0;
  bool _isLoadingMore = false;
  int? _filterImportFileId;
  String? _filterStatus;
  String? _filterSearch;

  /// Total number of certificates matching the active filters (backend `total`).
  int get total => _total;

  /// True while a "load more" request is running.
  bool get isLoadingMore => _isLoadingMore;

  /// More certificates exist on the server than are currently loaded.
  bool get hasMore => (state.valueOrNull?.length ?? 0) < _total;

  Map<String, dynamic> _query({required int skip}) {
    final queryParams = <String, dynamic>{'skip': skip, 'limit': pageSize};
    if (_filterImportFileId != null) queryParams['import_file_id'] = _filterImportFileId;
    final status = _filterStatus;
    if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;
    final search = _filterSearch;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    return queryParams;
  }

  /// Loads the first page (resets paging) with the given filters.
  Future<void> fetchCertificates({
    int? importFileId,
    String? status,
    String? search,
  }) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    _filterImportFileId = importFileId;
    _filterStatus = status;
    _filterSearch = search;
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates',
        queryParameters: _query(skip: 0),
        cancelToken: _cancelToken,
      );

      final List items = response.data['items'] ?? [];
      final list = items.map((json) => CargoInsuranceModel.fromJson(json)).toList();
      _total = (response.data['total'] as num?)?.toInt() ?? list.length;
      state = AsyncValue.data(list);
    } on DioException catch (e, stack) {
      if (CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Appends the next page to the loaded list (no-op when everything is loaded).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    final token = _cancelToken ?? CancelToken();
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates',
        queryParameters: _query(skip: current.length),
        cancelToken: token,
      );
      final List items = response.data['items'] ?? [];
      final more = items.map((json) => CargoInsuranceModel.fromJson(json)).toList();
      _total = (response.data['total'] as num?)?.toInt() ?? _total;
      if (more.isEmpty) {
        // Server returned nothing new: stop asking for more.
        _total = current.length;
      }
      state = AsyncValue.data([...current, ...more]);
    } on DioException catch (e, stack) {
      if (CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<InsuranceCalculationResultModel> calculateInsurance(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-insurance/calculate',
        data: payload,
      );
      return InsuranceCalculationResultModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoInsuranceModel> createCertificate(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates',
        data: payload,
      );
      final created = CargoInsuranceModel.fromJson(response.data);
      await fetchCertificates();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoInsuranceModel> updateCertificate(int certificateId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates/$certificateId',
        data: payload,
      );
      final updated = CargoInsuranceModel.fromJson(response.data);
      await fetchCertificates();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<CargoInsuranceModel> issueCertificate(int certificateId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates/$certificateId/issue',
      );
      final issued = CargoInsuranceModel.fromJson(response.data);
      await fetchCertificates();
      return issued;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCertificate(int certificateId) async {
    try {
      await _dio.delete(
        '${ApiConstants.baseUrl}/cargo-insurance/certificates/$certificateId',
      );
      await fetchCertificates();
    } catch (e) {
      rethrow;
    }
  }
}
