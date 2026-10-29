import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item_price_history_model.dart';
import '../models/item_price_trends_model.dart';
import '../repositories/master_items_repository.dart';
import 'master_items_provider.dart';

/// Item Price Trends Family Provider (AutoDisposeAsyncNotifier)
/// Manages procurement price trends and landed cost analytics per item ID.
final itemPriceTrendsProvider = AutoDisposeAsyncNotifierProviderFamily<
    ItemPriceTrendsNotifier, ItemPriceTrendsModel, int>(() {
  return ItemPriceTrendsNotifier();
});

/// AsyncNotifier managing price history analytics, min/max/average stats,
/// and recording new historical purchase order entries.
class ItemPriceTrendsNotifier
    extends AutoDisposeFamilyAsyncNotifier<ItemPriceTrendsModel, int> {
  MasterItemsRepository get _repository =>
      ref.read(masterItemsRepositoryProvider);

  CancelToken? _cancelToken;

  @override
  FutureOr<ItemPriceTrendsModel> build(int arg) async {
    ref.onDispose(() {
      _cancelToken?.cancel('item_price_trends_provider_disposed');
    });

    return _fetchTrends(arg);
  }

  Future<ItemPriceTrendsModel> _fetchTrends(int itemId) async {
    _cancelToken?.cancel('new_price_trends_request');
    _cancelToken = CancelToken();

    try {
      return await _repository.fetchPriceTrends(
        itemId,
        cancelToken: _cancelToken,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // If cancelled, keep existing value or rethrow
        final previous = state.value;
        if (previous != null) return previous;
      }
      rethrow;
    }
  }

  /// Manually trigger a refresh for the current item price trends
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTrends(arg));
  }

  /// Record a historical purchase order unit price and reload trends
  Future<ItemPriceHistoryModel> recordPriceHistory(
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['item_id'] = arg;

    final recorded = await _repository.recordPriceHistory(payload);
    await refresh();
    return recorded;
  }
}

/// Convenience selector that watches price trends for the currently selected item
final selectedItemPriceTrendsProvider =
    FutureProvider.autoDispose<ItemPriceTrendsModel?>((ref) async {
  final selectedId = ref.watch(selectedMasterItemIdProvider);
  if (selectedId == null) return null;

  return ref.watch(itemPriceTrendsProvider(selectedId).future);
});
