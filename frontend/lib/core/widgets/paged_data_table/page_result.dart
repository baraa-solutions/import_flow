import 'package:flutter/foundation.dart';

/// Standard response envelope for paginated list results.
///
/// Designed to deserialize backend payloads adhering to:
/// `{ "items": [...], "total": 1234, "page": 1, "page_size": 50, "total_pages": 25 }`
@immutable
class PageResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  /// Factory constructor to deserialize backend JSON response.
  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> itemJson) fromJsonItem,
  ) {
    final rawItems = json['items'];
    final itemsList = (rawItems is List)
        ? rawItems
            .map((e) => fromJsonItem(
                e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
            .toList()
        : <T>[];

    final total = (json['total'] as num?)?.toInt() ?? itemsList.length;
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final pageSize = (json['page_size'] as num?)?.toInt() ??
        (itemsList.isEmpty ? 50 : itemsList.length);

    int calculatedTotalPages;
    if (json['total_pages'] != null) {
      calculatedTotalPages = (json['total_pages'] as num).toInt();
    } else {
      calculatedTotalPages = pageSize > 0 ? (total / pageSize).ceil() : 0;
    }

    return PageResult<T>(
      items: itemsList,
      total: total,
      page: page,
      pageSize: pageSize,
      totalPages: calculatedTotalPages,
    );
  }

  /// Empty page result convenience factory.
  factory PageResult.empty({int pageSize = 50}) => PageResult<T>(
        items: const [],
        total: 0,
        page: 1,
        pageSize: pageSize,
        totalPages: 0,
      );

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageResult<T> &&
        listEquals(other.items, items) &&
        other.total == total &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.totalPages == totalPages;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        total,
        page,
        pageSize,
        totalPages,
      );

  @override
  String toString() =>
      'PageResult(items: ${items.length}, total: $total, page: $page/$totalPages, pageSize: $pageSize)';
}
