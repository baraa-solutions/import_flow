import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/trade_finance_model.dart';

final selectedFinanceFileIdProvider = StateProvider<int?>((ref) => null);
final selectedInstrumentIdProvider = StateProvider<int?>((ref) => null);
final selectedTradeFinanceTabProvider = StateProvider<int>((ref) => 0);

final tradeFinanceInstrumentsProvider = FutureProvider.autoDispose<List<FinanceInstrument>>((ref) async {
  final dio = ref.watch(dioProvider);
  final fileId = ref.watch(selectedFinanceFileIdProvider);

  final queryParams = <String, dynamic>{
    'limit': 50,
  };
  if (fileId != null) queryParams['import_file_id'] = fileId;

  try {
    final response = await dio.get('/api/v1/trade-finance/instruments', queryParameters: queryParams);
    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      final list = data['items'] as List;
      return list.map((it) => FinanceInstrument.fromJson(it as Map<String, dynamic>)).toList();
    }
    return [];
  } catch (e) {
    rethrow;
  }
});

final activeInstrumentProvider = Provider.autoDispose<FinanceInstrument?>((ref) {
  final instruments = ref.watch(tradeFinanceInstrumentsProvider).value ?? [];
  final selectedId = ref.watch(selectedInstrumentIdProvider);

  if (selectedId != null) {
    try {
      return instruments.firstWhere((i) => i.id == selectedId);
    } catch (_) {}
  }
  return instruments.isNotEmpty ? instruments.first : null;
});
