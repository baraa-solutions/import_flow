import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/customs_clearance_quotation_model.dart';

final customsClearanceQuotationsProvider =
    StateNotifierProvider<CustomsClearanceQuotationsNotifier, AsyncValue<List<CustomsClearanceRFQModel>>>((ref) {
  return CustomsClearanceQuotationsNotifier(ref.watch(dioProvider));
});

class CustomsClearanceQuotationsNotifier extends StateNotifier<AsyncValue<List<CustomsClearanceRFQModel>>> {
  final Dio _dio;

  CustomsClearanceQuotationsNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchRFQs();
  }

  Future<void> fetchRFQs({
    String? status,
    String? portName,
    int? importFileId,
    int? limit,
    int? skip,
  }) async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'include_inactive': false};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (portName != null && portName.isNotEmpty) queryParams['port_name'] = portName;
      if (importFileId != null) queryParams['import_file_id'] = importFileId;
      if (limit != null) queryParams['limit'] = limit;
      if (skip != null) queryParams['skip'] = skip;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data;
      final rfqs = data.map((json) => CustomsClearanceRFQModel.fromJson(json)).toList();
      state = AsyncValue.data(rfqs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CustomsClearanceRFQModel> createRFQ(CustomsClearanceRFQModel rfq) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs',
        data: rfq.toCreateJson(),
      );
      final created = CustomsClearanceRFQModel.fromJson(response.data);
      await fetchRFQs();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceRFQModel> updateRFQ(int rfqId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs/$rfqId',
        data: data,
      );
      final updated = CustomsClearanceRFQModel.fromJson(response.data);
      await fetchRFQs();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRFQ(int rfqId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs/$rfqId');
      await fetchRFQs();
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsClearanceQuotationItemModel> addQuotation(int rfqId, CustomsClearanceQuotationItemModel quote) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs/$rfqId/quotations',
        data: quote.toJson(),
      );
      final created = CustomsClearanceQuotationItemModel.fromJson(response.data);
      await fetchRFQs();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> awardQuotation(int rfqId, int quotationId, {String? notes}) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/rfqs/$rfqId/award',
        data: {'quotation_id': quotationId, if (notes != null) 'notes': notes},
      );
      await fetchRFQs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteQuotation(int quotationId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-clearance-quotations/quotations/$quotationId');
      await fetchRFQs();
    } catch (e) {
      rethrow;
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Clearance Price List Master Provider
// ─────────────────────────────────────────────────────────────────────────────

final clearancePriceListProvider =
    StateNotifierProvider<ClearancePriceListNotifier, AsyncValue<List<ClearancePriceListItemModel>>>((ref) {
  return ClearancePriceListNotifier(ref.watch(dioProvider));
});

class ClearancePriceListNotifier extends StateNotifier<AsyncValue<List<ClearancePriceListItemModel>>> {
  final Dio _dio;

  ClearancePriceListNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchPriceList();
  }

  Future<void> fetchPriceList({
    int? providerId,
    String? portName,
    String? serviceCategory,
  }) async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'include_inactive': false};
      if (providerId != null) queryParams['provider_id'] = providerId;
      if (portName != null && portName.isNotEmpty) queryParams['port_name'] = portName;
      if (serviceCategory != null && serviceCategory.isNotEmpty) queryParams['service_category'] = serviceCategory;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/price-list',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data;
      final items = data.map((json) => ClearancePriceListItemModel.fromJson(json)).toList();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ClearancePriceListItemModel> createPriceItem(ClearancePriceListItemModel item) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/price-list',
        data: item.toCreateJson(),
      );
      final created = ClearancePriceListItemModel.fromJson(response.data);
      await fetchPriceList();
      return created;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePriceItem(int itemId, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '${ApiConstants.baseUrl}/customs-clearance-quotations/price-list/$itemId',
        data: data,
      );
      await fetchPriceList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePriceItem(int itemId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-clearance-quotations/price-list/$itemId');
      await fetchPriceList();
    } catch (e) {
      rethrow;
    }
  }
}
