import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/expense_catalog_model.dart';
import '../services/expense_catalog_service.dart';

final expenseCatalogServiceProvider = Provider<ExpenseCatalogService>((ref) {
  final dio = ref.watch(dioProvider);
  return ExpenseCatalogService(dio);
});

class ExpenseCatalogState {
  final List<ExpenseCatalogModel> items;
  final List<BrokerMappingModel> brokerMappings;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedCategory;
  final String searchQuery;

  const ExpenseCatalogState({
    this.items = const [],
    this.brokerMappings = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory,
    this.searchQuery = '',
  });

  ExpenseCatalogState copyWith({
    List<ExpenseCatalogModel>? items,
    List<BrokerMappingModel>? brokerMappings,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return ExpenseCatalogState(
      items: items ?? this.items,
      brokerMappings: brokerMappings ?? this.brokerMappings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ExpenseCatalogNotifier extends StateNotifier<ExpenseCatalogState> {
  final ExpenseCatalogService _service;

  ExpenseCatalogNotifier(this._service) : super(const ExpenseCatalogState()) {
    fetchItems();
    fetchBrokerMappings();
  }

  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.listItems(
        category: state.selectedCategory,
        search: state.searchQuery,
        activeOnly: false,
      );
      state = state.copyWith(items: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchBrokerMappings({String? brokerName}) async {
    try {
      final mappings = await _service.listBrokerMappings(brokerName: brokerName);
      state = state.copyWith(brokerMappings: mappings);
    } catch (_) {}
  }

  void filterCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
    fetchItems();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    fetchItems();
  }

  Future<bool> createItem(Map<String, dynamic> payload) async {
    try {
      await _service.createItem(payload);
      await fetchItems();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateItem(String code, Map<String, dynamic> payload) async {
    try {
      await _service.updateItem(code, payload);
      await fetchItems();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> addPattern(String code, String pattern) async {
    try {
      await _service.addPattern(code, pattern);
      await fetchItems();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deactivateItem(String code) async {
    try {
      await _service.deactivateItem(code);
      await fetchItems();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteBrokerMapping(String? brokerName, String rawItemName) async {
    try {
      await _service.deleteBrokerMapping(brokerName, rawItemName);
      await fetchBrokerMappings();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final expenseCatalogProvider =
    StateNotifierProvider<ExpenseCatalogNotifier, ExpenseCatalogState>((ref) {
  final service = ref.watch(expenseCatalogServiceProvider);
  return ExpenseCatalogNotifier(service);
});
