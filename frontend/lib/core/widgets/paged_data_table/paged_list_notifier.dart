import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'list_query.dart';
import 'page_result.dart';

/// State representation for paginated list notifiers.
@immutable
class PagedListState<T> {
  final ListQuery query;
  /// Last successfully loaded page. Kept while subsequent pages load to avoid flickering.
  final PageResult<T>? data;
  final bool isLoading;
  /// Error object if the last fetch failed.
  final Object? error;

  const PagedListState({
    this.query = const ListQuery(),
    this.data,
    this.isLoading = false,
    this.error,
  });

  PagedListState<T> copyWith({
    ListQuery? query,
    PageResult<T>? Function()? data,
    bool? isLoading,
    Object? Function()? error,
  }) {
    return PagedListState<T>(
      query: query ?? this.query,
      data: data != null ? data() : this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedListState<T> &&
        other.query == query &&
        other.data == data &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(query, data, isLoading, error);

  @override
  String toString() =>
      'PagedListState(query: $query, items: ${data?.items.length}, total: ${data?.total}, isLoading: $isLoading, error: $error)';
}

/// Abstract contract for fetching paginated items from a remote or local data source.
abstract class PagedSource<T> {
  Future<PageResult<T>> fetchPage(ListQuery query, {CancelToken? cancelToken});
}

/// Server-side paginated data source that queries a REST endpoint with standard parameters.
class ServerPagedSource<T> implements PagedSource<T> {
  final Dio dio;
  final String path;
  final T Function(Map<String, dynamic> itemJson) fromJson;

  ServerPagedSource({
    required this.dio,
    required this.path,
    required this.fromJson,
  });

  @override
  Future<PageResult<T>> fetchPage(ListQuery query, {CancelToken? cancelToken}) async {
    final response = await dio.get(
      path,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );

    final rawData = response.data;
    if (rawData == null) {
      return PageResult.empty(pageSize: query.pageSize);
    }

    final Map<String, dynamic> jsonMap;
    if (rawData is Map<String, dynamic>) {
      jsonMap = rawData;
    } else if (rawData is Map) {
      jsonMap = Map<String, dynamic>.from(rawData);
    } else {
      throw FormatException('Unexpected response data format for paginated list: ${rawData.runtimeType}');
    }

    return PageResult.fromJson(jsonMap, fromJson);
  }
}

/// Client-side paginated data source that slices, filters, and sorts in memory.
///
/// Useful for small datasets or transitional phases before backend /paginated routes land.
class ClientPagedSource<T> implements PagedSource<T> {
  final Future<List<T>> Function() fetchAll;
  final bool Function(T item, String query)? searchMatcher;
  final Comparator<T>? Function(String sortKey)? sortComparator;
  final bool Function(T item, Map<String, Object?> filters)? filterMatcher;

  ClientPagedSource({
    required this.fetchAll,
    this.searchMatcher,
    this.sortComparator,
    this.filterMatcher,
  });

  factory ClientPagedSource.fromList(
    List<T> items, {
    bool Function(T item, String query)? searchMatcher,
    Comparator<T>? Function(String sortKey)? sortComparator,
    bool Function(T item, Map<String, Object?> filters)? filterMatcher,
  }) {
    return ClientPagedSource<T>(
      fetchAll: () async => items,
      searchMatcher: searchMatcher,
      sortComparator: sortComparator,
      filterMatcher: filterMatcher,
    );
  }

  @override
  Future<PageResult<T>> fetchPage(ListQuery query, {CancelToken? cancelToken}) async {
    final allItems = await fetchAll();
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );
    }

    Iterable<T> filtered = allItems;

    // 1. Search matching
    final trimmedSearch = query.search.trim().toLowerCase();
    if (trimmedSearch.isNotEmpty && searchMatcher != null) {
      filtered = filtered.where((item) => searchMatcher!(item, trimmedSearch));
    }

    // 2. Custom filters matching
    if (query.filters.isNotEmpty && filterMatcher != null) {
      filtered = filtered.where((item) => filterMatcher!(item, query.filters));
    }

    final list = filtered.toList();

    // 3. Sorting
    final sortSpec = query.sort?.trim();
    if (sortSpec != null && sortSpec.isNotEmpty && sortComparator != null) {
      final isDesc = sortSpec.startsWith('-');
      final sortKey = isDesc ? sortSpec.substring(1) : sortSpec;
      final comparator = sortComparator!(sortKey);

      if (comparator != null) {
        if (isDesc) {
          list.sort((a, b) => comparator(b, a));
        } else {
          list.sort(comparator);
        }
      }
    }

    // 4. Slicing
    final total = list.length;
    final totalPages = query.pageSize > 0 ? (total / query.pageSize).ceil() : 0;
    final startIndex = (query.page - 1) * query.pageSize;

    List<T> pagedItems;
    if (startIndex >= total || startIndex < 0) {
      pagedItems = <T>[];
    } else {
      final endIndex = (startIndex + query.pageSize).clamp(0, total);
      pagedItems = list.sublist(startIndex, endIndex);
    }

    return PageResult<T>(
      items: pagedItems,
      total: total,
      page: query.page,
      pageSize: query.pageSize,
      totalPages: totalPages,
    );
  }
}

/// Abstract StateNotifier managing a paginated list lifecycle.
///
/// Handles automatic debounced search (350ms), page resets on query updates,
/// cancellation of inflight requests, and preservation of data during reload.
abstract class PagedListNotifier<T> extends StateNotifier<PagedListState<T>> {
  final PagedSource<T> source;
  CancelToken? _cancelToken;
  Timer? _debounceTimer;

  PagedListNotifier(
    this.source, {
    ListQuery initialQuery = const ListQuery(),
  }) : super(PagedListState<T>(query: initialQuery)) {
    load();
  }

  /// Cancels previous pending request and fetches the current page.
  /// Keeps existing `data` in state to prevent UI flicker while loading.
  Future<void> load() async {
    _cancelToken?.cancel('new_request_initiated');
    final cancel = CancelToken();
    _cancelToken = cancel;

    state = state.copyWith(
      isLoading: true,
      error: () => null,
    );

    try {
      final result = await source.fetchPage(state.query, cancelToken: cancel);
      if (cancel.isCancelled) return;

      state = state.copyWith(
        data: () => result,
        isLoading: false,
        error: () => null,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return; // Ignore cancelled requests
      }
      state = state.copyWith(
        isLoading: false,
        error: () => e,
      );
    }
  }

  /// Refreshes the list reusing the current query and page.
  Future<void> refresh() => load();

  /// Updates search text with a 350ms debounce and resets page to 1.
  void setSearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      final newQuery = state.query.copyWith(search: q, page: 1);
      state = state.copyWith(query: newQuery);
      load();
    });
  }

  /// Sets or clears a filter property and resets page to 1.
  void setFilter(String key, Object? value) {
    final updatedFilters = Map<String, Object?>.from(state.query.filters);
    if (value == null || value == '') {
      updatedFilters.remove(key);
    } else {
      updatedFilters[key] = value;
    }

    final newQuery = state.query.copyWith(
      filters: updatedFilters,
      page: 1,
    );
    state = state.copyWith(query: newQuery);
    load();
  }

  /// Sets the sort expression (e.g. "-created_at") and resets page to 1.
  void setSort(String? sort) {
    final newQuery = state.query.copyWith(
      sort: sort,
      page: 1,
    );
    state = state.copyWith(query: newQuery);
    load();
  }

  /// Navigates to a specific page without altering filters or search.
  void setPage(int page) {
    if (page == state.query.page) return;
    final newQuery = state.query.copyWith(page: page);
    state = state.copyWith(query: newQuery);
    load();
  }

  /// Updates page size (25, 50, 100) and resets page to 1.
  void setPageSize(int size) {
    if (size == state.query.pageSize) return;
    final newQuery = state.query.copyWith(pageSize: size, page: 1);
    state = state.copyWith(query: newQuery);
    load();
  }

  /// Toggles inclusion of inactive records and resets page to 1.
  void setIncludeInactive(bool include) {
    if (include == state.query.includeInactive) return;
    final newQuery = state.query.copyWith(includeInactive: include, page: 1);
    state = state.copyWith(query: newQuery);
    load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel('notifier_disposed');
    super.dispose();
  }
}

/// Standard concrete implementation of [PagedListNotifier] for direct usage.
class DefaultPagedListNotifier<T> extends PagedListNotifier<T> {
  DefaultPagedListNotifier(
    super.source, {
    super.initialQuery,
  });
}
