import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/item_supplier_catalog_model.dart';
import '../models/master_item_model.dart';
import '../repositories/master_items_repository.dart';

/// State representation for Master Items catalog list
@immutable
class MasterItemsState {
  final List<MasterItemModel> items;
  final int total;
  final String searchQuery;
  final String? selectedCategory;
  final int skip;
  final int limit;

  const MasterItemsState({
    this.items = const [],
    this.total = 0,
    this.searchQuery = '',
    this.selectedCategory,
    this.skip = 0,
    this.limit = 100,
  });

  bool get hasMore => (skip + items.length) < total;

  MasterItemsState copyWith({
    List<MasterItemModel>? items,
    int? total,
    String? searchQuery,
    String? selectedCategory,
    bool clearCategory = false,
    int? skip,
    int? limit,
  }) {
    return MasterItemsState(
      items: items ?? this.items,
      total: total ?? this.total,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterItemsState &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          searchQuery == other.searchQuery &&
          selectedCategory == other.selectedCategory &&
          skip == other.skip &&
          limit == other.limit &&
          listEquals(items, other.items);

  @override
  int get hashCode =>
      total.hashCode ^
      searchQuery.hashCode ^
      selectedCategory.hashCode ^
      skip.hashCode ^
      limit.hashCode ^
      items.length.hashCode;
}

/// Central Master Items Provider with AutoDispose & Debounced Search
final masterItemsProvider =
    AutoDisposeAsyncNotifierProvider<MasterItemsNotifier, MasterItemsState>(() {
  return MasterItemsNotifier();
});

/// AsyncNotifier managing the Master Items state with debouncing,
/// request cancellation, and single source of truth mutations.
class MasterItemsNotifier extends AutoDisposeAsyncNotifier<MasterItemsState> {
  MasterItemsRepository get _repository =>
      ref.read(masterItemsRepositoryProvider);

  CancelToken? _cancelToken;
  Timer? _debounceTimer;

  @override
  FutureOr<MasterItemsState> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _cancelToken?.cancel('master_items_provider_disposed');
    });

    return _fetchItems(const MasterItemsState());
  }

  /// Internal fetcher using repository and CancelToken
  Future<MasterItemsState> _fetchItems(MasterItemsState currentState) async {
    _cancelToken?.cancel('new_master_items_request_initiated');
    _cancelToken = CancelToken();

    try {
      final result = await _repository.fetchMasterItems(
        search: currentState.searchQuery,
        category: currentState.selectedCategory,
        skip: currentState.skip,
        limit: currentState.limit,
        cancelToken: _cancelToken,
      );

      return currentState.copyWith(
        items: result.items,
        total: result.total,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return currentState;
      }
      rethrow;
    }
  }

  /// Debounced Search (default 350ms delay).
  /// Cancels pending timer and in-flight HTTP request.
  void setSearchQuery(
    String query, {
    Duration debounceDuration = const Duration(milliseconds: 350),
  }) {
    _debounceTimer?.cancel();

    final current = state.value ?? const MasterItemsState();
    final updatedState = current.copyWith(
      searchQuery: query,
      skip: 0,
    );

    // Keep current items during debounce typing to avoid flickering
    state = AsyncValue.data(updatedState);

    _debounceTimer = Timer(debounceDuration, () async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _fetchItems(updatedState));
    });
  }

  /// Filter by product category and reset pagination
  Future<void> setCategory(String? category) async {
    _debounceTimer?.cancel();
    final current = state.value ?? const MasterItemsState();
    final updatedState = current.copyWith(
      selectedCategory: category,
      clearCategory: category == null || category == 'All',
      skip: 0,
    );

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchItems(updatedState));
  }

  /// Navigate / paginate items
  Future<void> setPage(int skip) async {
    final current = state.value ?? const MasterItemsState();
    final updatedState = current.copyWith(skip: skip);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchItems(updatedState));
  }

  /// Refresh items keeping current filters
  Future<void> refresh() async {
    _debounceTimer?.cancel();
    final current = state.value ?? const MasterItemsState();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchItems(current));
  }

  /// Create a new item and refresh list
  Future<MasterItemModel> createItem(Map<String, dynamic> data) async {
    final created = await _repository.createMasterItem(data);
    await refresh();
    return created;
  }

  /// Update an existing item and update local state / reload
  Future<MasterItemModel> updateItem(
    int itemId,
    Map<String, dynamic> data,
  ) async {
    final updated = await _repository.updateMasterItem(itemId, data);
    final current = state.value;
    if (current != null) {
      final updatedList = current.items.map((i) {
        return i.itemId == itemId ? updated : i;
      }).toList();
      state = AsyncValue.data(current.copyWith(items: updatedList));
    } else {
      await refresh();
    }
    return updated;
  }

  /// Soft-delete an item and refresh list
  Future<void> deleteItem(int itemId) async {
    await _repository.deleteMasterItem(itemId);
    final current = state.value;
    if (current != null) {
      final updatedList = current.items.where((i) => i.itemId != itemId).toList();
      state = AsyncValue.data(current.copyWith(
        items: updatedList,
        total: current.total > 0 ? current.total - 1 : 0,
      ));
    } else {
      await refresh();
    }
  }

  /// Link an item to a supplier
  Future<ItemSupplierCatalogModel> linkSupplier(
    Map<String, dynamic> data,
  ) async {
    final linked = await _repository.linkSupplier(data);
    ref.invalidate(itemSuppliersProvider(linked.itemId));
    return linked;
  }
}

// ── Ancillary Selectors & Family Providers ──────────────────────

/// Currently selected Master Item ID for master-detail views
final selectedMasterItemIdProvider = StateProvider<int?>((ref) => null);

/// Single Master Item Provider (Auto-disposed family)
final singleMasterItemProvider =
    FutureProvider.family.autoDispose<MasterItemModel, int>((ref, itemId) async {
  final repo = ref.watch(masterItemsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return repo.getMasterItem(itemId, cancelToken: cancelToken);
});

/// Suppliers linked to a specific Master Item (Auto-disposed family)
final itemSuppliersProvider = FutureProvider.family.autoDispose<
    List<ItemSupplierCatalogModel>, int>((ref, itemId) async {
  final repo = ref.watch(masterItemsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return repo.fetchItemSuppliers(itemId, cancelToken: cancelToken);
});

