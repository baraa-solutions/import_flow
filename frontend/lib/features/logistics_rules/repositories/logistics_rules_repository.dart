import 'package:dio/dio.dart';
import '../models/logistics_rule.dart';

/// Repository for handling logistics operational rules network requests.
class LogisticsRulesRepository {
  final Dio dio;

  LogisticsRulesRepository(this.dio);

  Future<List<LogisticsRule>> listRules({
    String? scopeType,
    String? verificationStatus,
    bool isLatest = true,
    int page = 1,
    int size = 100,
  }) async {
    final queryParams = <String, dynamic>{
      'is_latest': isLatest,
      'page': page,
      'size': size,
    };
    if (scopeType != null && scopeType.isNotEmpty) {
      queryParams['scope_type'] = scopeType;
    }
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      queryParams['verification_status'] = verificationStatus;
    }

    final response = await dio.get(
      '/api/v1/logistics-rules',
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((item) => LogisticsRule.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<LogisticsRule> getRuleById(int id) async {
    final response = await dio.get('/api/v1/logistics-rules/$id');
    return LogisticsRule.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LogisticsRule> createRule(Map<String, dynamic> data) async {
    final response = await dio.post(
      '/api/v1/logistics-rules',
      data: data,
    );
    return LogisticsRule.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LogisticsRule> updateRule(int id, Map<String, dynamic> data) async {
    final response = await dio.put(
      '/api/v1/logistics-rules/$id',
      data: data,
    );
    return LogisticsRule.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LogisticsRule> verifyRule(int id, Map<String, dynamic> data) async {
    final response = await dio.post(
      '/api/v1/logistics-rules/$id/verify',
      data: data,
    );
    return LogisticsRule.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> exportFieldQuestions() async {
    final response = await dio.get('/api/v1/logistics-rules/export/questions');
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
