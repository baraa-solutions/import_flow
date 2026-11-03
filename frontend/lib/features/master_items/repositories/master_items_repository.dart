import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../models/item_price_history_model.dart';
import '../models/item_price_trends_model.dart';
import '../models/item_supplier_catalog_model.dart';
import '../models/master_item_model.dart';

/// Network Exception for Master Items API operations.
/// Surfaces clean error descriptions and HTTP status codes to callers.
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const NetworkException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Central Provider for Master Items Repository.
final masterItemsRepositoryProvider = Provider<MasterItemsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MasterItemsRepository(dio);
});

/// Master Items Repository (MD-ITEM-001)
/// Handles REST API requests to backend /api/v1/master-items endpoints.
class MasterItemsRepository {
  final Dio _dio;
  final String _endpoint = '${ApiConstants.baseUrl}/master-items';

  MasterItemsRepository(this._dio);

  // ── Master Items CRUD ──────────────────────────────────────────

  /// Fetch list of master items with optional search and category filters.
  Future<MasterItemListModel> fetchMasterItems({
    String? search,
    String? category,
    int skip = 0,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (category != null && category.trim().isNotEmpty && category != 'All') {
        queryParams['category'] = category.trim();
      }

      final response = await _dio.get(
        _endpoint,
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      return MasterItemListModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _toNetworkException(e, fallback: 'فشل تحميل قائمة الأصناف');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ غير متوقع أثناء تحميل الأصناف: $e',
        originalError: e,
      );
    }
  }

  /// Get single master item by ID.
  Future<MasterItemModel> getMasterItem(
    int itemId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_endpoint/$itemId',
        cancelToken: cancelToken,
      );
      return MasterItemModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _toNetworkException(e, fallback: 'فشل تحميل بيانات الصنف رقم $itemId');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ غير متوقع أثناء استرجاع بيانات الصنف: $e',
        originalError: e,
      );
    }
  }

  /// Create a new master item.
  Future<MasterItemModel> createMasterItem(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(_endpoint, data: data);
      return MasterItemModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toNetworkException(e, fallback: 'فشل إنشاء الصنف الجديد');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء حفظ الصنف الجديد: $e',
        originalError: e,
      );
    }
  }

  /// Update an existing master item.
  Future<MasterItemModel> updateMasterItem(
    int itemId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('$_endpoint/$itemId', data: data);
      return MasterItemModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toNetworkException(e, fallback: 'فشل تحديث بيانات الصنف رقم $itemId');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء تحديث الصنف: $e',
        originalError: e,
      );
    }
  }

  /// Soft-delete a master item.
  Future<void> deleteMasterItem(int itemId) async {
    try {
      await _dio.delete('$_endpoint/$itemId');
    } on DioException catch (e) {
      throw _toNetworkException(e, fallback: 'فشل حذف أو تعطيل الصنف رقم $itemId');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء تعطيل الصنف: $e',
        originalError: e,
      );
    }
  }

  // ── Supplier Catalog Linkages ─────────────────────────────────

  /// Link an item to an overseas supplier with quote details.
  Future<ItemSupplierCatalogModel> linkSupplier(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('$_endpoint/supplier-link', data: data);
      return ItemSupplierCatalogModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _toNetworkException(e, fallback: 'فشل ربط الصنف بالمورد');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء ربط الصنف بالمورد: $e',
        originalError: e,
      );
    }
  }

  /// List all suppliers and quotes linked to an item.
  Future<List<ItemSupplierCatalogModel>> fetchItemSuppliers(
    int itemId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_endpoint/$itemId/suppliers',
        cancelToken: cancelToken,
      );
      final rawList = response.data as List<dynamic>? ?? [];
      return rawList
          .map((item) => ItemSupplierCatalogModel.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _toNetworkException(e, fallback: 'فشل تحميل قائمة موردي الصنف');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء جلب موردي الصنف: $e',
        originalError: e,
      );
    }
  }

  // ── Price History & Trends ────────────────────────────────────

  /// Record a historical purchase order unit price for an item.
  Future<ItemPriceHistoryModel> recordPriceHistory(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('$_endpoint/price-history', data: data);
      return ItemPriceHistoryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _toNetworkException(e, fallback: 'فشل تسجيل السعر التاريخي للصنف');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء تسجيل السعر التاريخي: $e',
        originalError: e,
      );
    }
  }

  /// Analyze historical price trends and landed cost markup for an item.
  Future<ItemPriceTrendsModel> fetchPriceTrends(
    int itemId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_endpoint/$itemId/price-trends',
        cancelToken: cancelToken,
      );
      return ItemPriceTrendsModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _toNetworkException(e, fallback: 'فشل تحميل تحليلات أسعار الصنف');
    } catch (e) {
      throw NetworkException(
        message: 'حدث خطأ أثناء تحليل أسعار الصنف: $e',
        originalError: e,
      );
    }
  }

  // ── Error Parser Helper ───────────────────────────────────────

  NetworkException _toNetworkException(
    DioException e, {
    required String fallback,
  }) {
    final status = e.response?.statusCode;
    final parsedMsg = ApiError.message(e, fallback: fallback);
    return NetworkException(
      message: parsedMsg,
      statusCode: status,
      originalError: e,
    );
  }
}
