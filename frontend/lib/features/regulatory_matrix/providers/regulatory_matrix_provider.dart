import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/regulatory_requirement.dart';

final regulatoryAgencyFilterProvider = StateProvider<String?>((ref) => null);
final regulatoryTimingFilterProvider = StateProvider<String?>((ref) => null);
final regulatorySearchQueryProvider = StateProvider<String>((ref) => '');

final regulatoryMatrixListProvider = FutureProvider.autoDispose<List<RegulatoryRequirement>>((ref) async {
  final dio = ref.watch(dioProvider);
  final agency = ref.watch(regulatoryAgencyFilterProvider);
  final timing = ref.watch(regulatoryTimingFilterProvider);
  final search = ref.watch(regulatorySearchQueryProvider);

  final queryParams = <String, dynamic>{
    'limit': 200,
  };
  if (agency != null && agency.isNotEmpty) queryParams['agency_code'] = agency;
  if (timing != null && timing.isNotEmpty) queryParams['stage_timing'] = timing;
  if (search.isNotEmpty) queryParams['search'] = search;

  try {
    final response = await dio.get('/api/v1/regulatory-matrix', queryParameters: queryParams);
    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      final list = data['items'] as List;
      return list.map((item) => RegulatoryRequirement.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  } catch (e) {
    // Return empty list or rethrow for riverpod error state
    rethrow;
  }
});
