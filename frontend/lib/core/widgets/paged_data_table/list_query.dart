import 'package:flutter/foundation.dart';

/// Represents a standardized query for fetching paginated lists from server
/// or client data sources across ImportFlow ERP tables.
///
/// Immutable query parameters:
/// - [page]: 1-based page number (defaults to 1).
/// - [pageSize]: Number of items per page (defaults to 50, maximum 200).
/// - [sort]: Sort string, e.g. "-created_at" or "supplier_name,-eta".
/// - [search]: Search query text, sent as `q=` query parameter.
/// - [filters]: Key-value filter parameters, e.g. status, company_id, date_from.
/// - [includeInactive]: Whether to include inactive/soft-deleted rows.
@immutable
class ListQuery {
  final int page;
  final int pageSize;
  final String? sort;
  final String search;
  final Map<String, Object?> filters;
  final bool includeInactive;

  const ListQuery({
    this.page = 1,
    this.pageSize = 50,
    this.sort,
    this.search = '',
    this.filters = const {},
    this.includeInactive = false,
  })  : assert(page >= 1, 'Page must be 1-based and >= 1'),
        assert(pageSize >= 1 && pageSize <= 200, 'PageSize must be between 1 and 200');

  /// Converts this query into standard query parameters map for backend endpoints.
  /// Drops null and empty filter entries and trims search text.
  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };

    if (sort != null && sort!.trim().isNotEmpty) {
      params['sort'] = sort!.trim();
    }

    final trimmedSearch = search.trim();
    if (trimmedSearch.isNotEmpty) {
      params['q'] = trimmedSearch;
    }

    if (includeInactive) {
      params['include_inactive'] = true;
    }

    for (final entry in filters.entries) {
      final value = entry.value;
      if (value != null && value != '') {
        params[entry.key] = value;
      }
    }

    return params;
  }

  /// Creates a copy of this query with modified properties.
  ListQuery copyWith({
    int? page,
    int? pageSize,
    String? sort,
    String? search,
    Map<String, Object?>? filters,
    bool? includeInactive,
  }) {
    return ListQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      includeInactive: includeInactive ?? this.includeInactive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListQuery &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.sort == sort &&
        other.search == search &&
        mapEquals(other.filters, filters) &&
        other.includeInactive == includeInactive;
  }

  @override
  int get hashCode => Object.hash(
        page,
        pageSize,
        sort,
        search,
        Object.hashAll(filters.keys),
        Object.hashAll(filters.values),
        includeInactive,
      );

  @override
  String toString() =>
      'ListQuery(page: $page, pageSize: $pageSize, sort: $sort, search: "$search", filters: $filters, includeInactive: $includeInactive)';
}
