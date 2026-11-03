import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/broker_custody_model.dart';

final selectedBrokerAdvanceIdProvider = StateProvider<int?>((ref) => null);

final brokerAdvanceListProvider = FutureProvider.autoDispose<List<CustomsBrokerAdvanceModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/api/v1/broker-custody/customs-advances');
    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      final list = data['items'] as List;
      return list.map((item) => CustomsBrokerAdvanceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  } catch (e) {
    rethrow;
  }
});

final activeBrokerAdvanceProvider = FutureProvider.autoDispose<CustomsBrokerAdvanceModel?>((ref) async {
  final selectedId = ref.watch(selectedBrokerAdvanceIdProvider);
  if (selectedId == null) return null;

  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/api/v1/broker-custody/customs-advances/$selectedId');
    return CustomsBrokerAdvanceModel.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    rethrow;
  }
});

final activeAdvanceReconciliationProvider = FutureProvider.autoDispose<CustomsSettlementVarianceModel?>((ref) async {
  final selectedId = ref.watch(selectedBrokerAdvanceIdProvider);
  if (selectedId == null) return null;

  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/api/v1/broker-custody/customs-advances/$selectedId/reconciliation');
    return CustomsSettlementVarianceModel.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return null;
  }
});
