import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/expense_catalog_model.dart';

class ExpenseCatalogService {
  final Dio _dio;

  ExpenseCatalogService(this._dio);

  Future<List<ExpenseCatalogModel>> listItems({
    String? category,
    String? search,
    bool activeOnly = false,
  }) async {
    final queryParams = <String, dynamic>{
      'active_only': activeOnly,
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _dio.get(
      ApiConstants.expenseCatalog,
      queryParameters: queryParams,
    );
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => ExpenseCatalogModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ExpenseCatalogModel> createItem(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      ApiConstants.expenseCatalog,
      data: payload,
    );
    return ExpenseCatalogModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExpenseCatalogModel> updateItem(String code, Map<String, dynamic> payload) async {
    final response = await _dio.put(
      '${ApiConstants.expenseCatalog}/$code',
      data: payload,
    );
    return ExpenseCatalogModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> addPattern(String code, String pattern) async {
    await _dio.post(
      '${ApiConstants.expenseCatalog}/$code/patterns',
      data: {'pattern': pattern},
    );
  }

  Future<void> deactivateItem(String code) async {
    await _dio.delete('${ApiConstants.expenseCatalog}/$code');
  }

  Future<List<BrokerMappingModel>> listBrokerMappings({String? brokerName}) async {
    final queryParams = <String, dynamic>{};
    if (brokerName != null && brokerName.isNotEmpty) {
      queryParams['broker_name'] = brokerName;
    }
    final response = await _dio.get(
      '${ApiConstants.expenseCatalog}/broker-mappings/all',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => BrokerMappingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> deleteBrokerMapping(String? brokerName, String rawItemName) async {
    await _dio.delete(
      '${ApiConstants.expenseCatalog}/broker-mappings/forget',
      queryParameters: {
        if (brokerName != null && brokerName.isNotEmpty) 'broker_name': brokerName,
        'raw_item_name': rawItemName,
      },
    );
  }
}
