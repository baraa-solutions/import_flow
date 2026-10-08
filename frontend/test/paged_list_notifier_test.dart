import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/paged_data_table/list_query.dart';
import 'package:frontend/core/widgets/paged_data_table/page_result.dart';
import 'package:frontend/core/widgets/paged_data_table/paged_list_notifier.dart';

class _TestItem {
  final int id;
  final String name;
  final String status;
  final int score;

  const _TestItem({
    required this.id,
    required this.name,
    required this.status,
    required this.score,
  });

  factory _TestItem.fromJson(Map<String, dynamic> json) => _TestItem(
        id: json['id'] as int,
        name: json['name'] as String,
        status: json['status'] as String,
        score: json['score'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'score': score,
      };
}

void main() {
  group('ListQuery unit tests', () {
    test('default query parameters are well-formed', () {
      const query = ListQuery();
      expect(query.page, 1);
      expect(query.pageSize, 50);
      expect(query.sort, isNull);
      expect(query.search, '');
      expect(query.filters, isEmpty);
      expect(query.includeInactive, isFalse);

      final params = query.toQueryParameters();
      expect(params, {
        'page': 1,
        'page_size': 50,
      });
    });

    test('toQueryParameters drops empty filters and trims search', () {
      const query = ListQuery(
        page: 2,
        pageSize: 25,
        sort: '-created_at',
        search: '  egyptian customs  ',
        filters: {
          'status': 'Active',
          'empty_val': '',
          'null_val': null,
          'company_id': 102,
        },
        includeInactive: true,
      );

      final params = query.toQueryParameters();
      expect(params, {
        'page': 2,
        'page_size': 25,
        'sort': '-created_at',
        'q': 'egyptian customs',
        'status': 'Active',
        'company_id': 102,
        'include_inactive': true,
      });
      expect(params.containsKey('empty_val'), isFalse);
      expect(params.containsKey('null_val'), isFalse);
    });

    test('copyWith updates specified fields and preserves others', () {
      const query = ListQuery(page: 1, pageSize: 50, search: 'test');
      final updated = query.copyWith(page: 3, sort: 'name');
      expect(updated.page, 3);
      expect(updated.pageSize, 50);
      expect(updated.search, 'test');
      expect(updated.sort, 'name');
    });
  });

  group('PageResult unit tests', () {
    test('fromJson deserializes standard backend envelope', () {
      final json = {
        'items': [
          {'id': 1, 'name': 'Item A', 'status': 'Open', 'score': 10},
          {'id': 2, 'name': 'Item B', 'status': 'Closed', 'score': 20},
        ],
        'total': 120,
        'page': 2,
        'page_size': 50,
        'total_pages': 3,
      };

      final result = PageResult<_TestItem>.fromJson(
        json,
        (itemMap) => _TestItem.fromJson(itemMap),
      );

      expect(result.items.length, 2);
      expect(result.items.first.name, 'Item A');
      expect(result.total, 120);
      expect(result.page, 2);
      expect(result.pageSize, 50);
      expect(result.totalPages, 3);
      expect(result.hasNextPage, isTrue);
      expect(result.hasPreviousPage, isTrue);
    });

    test('calculates totalPages if backend omits total_pages', () {
      final json = {
        'items': [
          {'id': 1, 'name': 'A', 'status': 'Open', 'score': 5},
        ],
        'total': 1234,
        'page': 1,
        'page_size': 50,
      };

      final result = PageResult<_TestItem>.fromJson(
        json,
        (itemMap) => _TestItem.fromJson(itemMap),
      );

      // 1234 / 50 = 24.68 -> 25
      expect(result.totalPages, 25);
    });
  });

  group('ClientPagedSource unit tests', () {
    final sampleItems = List.generate(
      1234,
      (i) => _TestItem(
        id: i + 1,
        name: 'Item ${i + 1}',
        status: (i % 2 == 0) ? 'Open' : 'Closed',
        score: (i * 7) % 500,
      ),
    );

    final source = ClientPagedSource<_TestItem>.fromList(
      sampleItems,
      searchMatcher: (item, q) => item.name.toLowerCase().contains(q),
      sortComparator: (key) {
        if (key == 'score') return (a, b) => a.score.compareTo(b.score);
        if (key == 'id') return (a, b) => a.id.compareTo(b.id);
        return null;
      },
      filterMatcher: (item, filters) {
        if (filters.containsKey('status') && item.status != filters['status']) {
          return false;
        }
        return true;
      },
    );

    test('Acceptance criteria: 1,234 items returns page 1 with 50 items, total 1234, totalPages 25', () async {
      final res = await source.fetchPage(const ListQuery(page: 1, pageSize: 50));
      expect(res.items.length, 50);
      expect(res.total, 1234);
      expect(res.page, 1);
      expect(res.pageSize, 50);
      expect(res.totalPages, 25);
      expect(res.items.first.id, 1);
      expect(res.items.last.id, 50);
    });

    test('slices last page correctly (page 25 has 34 items)', () async {
      final res = await source.fetchPage(const ListQuery(page: 25, pageSize: 50));
      expect(res.items.length, 34);
      expect(res.total, 1234);
      expect(res.page, 25);
      expect(res.items.first.id, 1201);
      expect(res.items.last.id, 1234);
    });

    test('filters by search term', () async {
      final res = await source.fetchPage(const ListQuery(search: 'Item 100', pageSize: 50));
      // Matches "Item 100", "Item 1000", "Item 1001", ... "Item 1009"
      expect(res.items.any((item) => item.name == 'Item 100'), isTrue);
      expect(res.total, 11);
    });

    test('filters by custom filter map', () async {
      final res = await source.fetchPage(
        const ListQuery(filters: {'status': 'Closed'}, pageSize: 50),
      );
      expect(res.items.every((item) => item.status == 'Closed'), isTrue);
      // 1234 items, half are closed -> 617
      expect(res.total, 617);
    });

    test('sorts ascending and descending', () async {
      final ascRes = await source.fetchPage(
        const ListQuery(sort: 'score', pageSize: 10),
      );
      expect(ascRes.items.first.score <= ascRes.items[1].score, isTrue);

      final descRes = await source.fetchPage(
        const ListQuery(sort: '-score', pageSize: 10),
      );
      expect(descRes.items.first.score >= descRes.items[1].score, isTrue);
    });
  });

  group('ServerPagedSource unit tests', () {
    test('sends query parameters and parses envelope from Dio', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.path, '/api/v1/test/paginated');
        expect(options.queryParameters['page'], 2);
        expect(options.queryParameters['page_size'], 50);
        expect(options.queryParameters['sort'], '-created_at');
        expect(options.queryParameters['q'], 'abc');
        expect(options.queryParameters['status'], 'Open');

        return ResponseBody.fromString(
          '{"items":[{"id":101,"name":"Server A","status":"Open","score":99}],"total":1,"page":2,"page_size":50,"total_pages":1}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final source = ServerPagedSource<_TestItem>(
        dio: dio,
        path: '/api/v1/test/paginated',
        fromJson: (j) => _TestItem.fromJson(j),
      );

      final result = await source.fetchPage(const ListQuery(
        page: 2,
        pageSize: 50,
        sort: '-created_at',
        search: 'abc',
        filters: {'status': 'Open'},
      ));

      expect(result.items.length, 1);
      expect(result.items.first.name, 'Server A');
      expect(result.total, 1);
      expect(result.page, 2);
    });
  });

  group('PagedListNotifier unit tests', () {
    test('initializes and loads page 1 automatically', () async {
      final source = ClientPagedSource<_TestItem>.fromList([
        const _TestItem(id: 1, name: 'First', status: 'Active', score: 100),
      ]);

      final notifier = DefaultPagedListNotifier<_TestItem>(source);

      // Initial state is loading or loads synchronously/microtask
      await pumpEventQueue();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.data, isNotNull);
      expect(notifier.state.data!.items.length, 1);
      expect(notifier.state.data!.items.first.name, 'First');
      expect(notifier.state.error, isNull);

      notifier.dispose();
    });

    test('setFilter updates query, resets page to 1, and reloads', () async {
      final items = [
        const _TestItem(id: 1, name: 'A', status: 'Open', score: 10),
        const _TestItem(id: 2, name: 'B', status: 'Closed', score: 20),
      ];

      final source = ClientPagedSource<_TestItem>.fromList(
        items,
        filterMatcher: (item, filters) =>
            !filters.containsKey('status') || item.status == filters['status'],
      );

      final notifier = DefaultPagedListNotifier<_TestItem>(
        source,
        initialQuery: const ListQuery(page: 2, pageSize: 1),
      );
      await pumpEventQueue();

      notifier.setFilter('status', 'Open');
      expect(notifier.state.query.page, 1);
      expect(notifier.state.query.filters['status'], 'Open');

      await pumpEventQueue();
      expect(notifier.state.data!.items.length, 1);
      expect(notifier.state.data!.items.first.name, 'A');

      // Acceptance criteria: refresh keeps query and status=Open
      await notifier.refresh();
      expect(notifier.state.query.filters['status'], 'Open');
      expect(notifier.state.data!.items.first.status, 'Open');

      notifier.dispose();
    });

    test('error keeps existing data to avoid UI flickering', () async {
      var shouldFail = false;

      final source = _ControllablePagedSource<_TestItem>(
        fetch: (query) async {
          if (shouldFail) {
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              error: 'Server timeout',
            );
          }
          return const PageResult<_TestItem>(
            items: [_TestItem(id: 1, name: 'Good', status: 'Open', score: 1)],
            total: 1,
            page: 1,
            pageSize: 50,
            totalPages: 1,
          );
        },
      );

      final notifier = DefaultPagedListNotifier<_TestItem>(source);
      await pumpEventQueue();

      expect(notifier.state.data, isNotNull);
      expect(notifier.state.data!.items.first.name, 'Good');
      expect(notifier.state.error, isNull);

      // Now trigger error
      shouldFail = true;
      await notifier.refresh();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      // Data is still preserved!
      expect(notifier.state.data, isNotNull);
      expect(notifier.state.data!.items.first.name, 'Good');

      notifier.dispose();
    });

    test('setSearch debounces quick consecutive keystrokes into single fetch', () async {
      var fetchCallCount = 0;

      final source = _ControllablePagedSource<_TestItem>(
        fetch: (query) async {
          fetchCallCount++;
          return const PageResult<_TestItem>(
            items: [],
            total: 0,
            page: 1,
            pageSize: 50,
            totalPages: 0,
          );
        },
      );

      final notifier = DefaultPagedListNotifier<_TestItem>(source);
      await pumpEventQueue();
      expect(fetchCallCount, 1); // initial load

      // Simulate user typing "cargo" rapidly
      notifier.setSearch('c');
      notifier.setSearch('ca');
      notifier.setSearch('car');
      notifier.setSearch('carg');
      notifier.setSearch('cargo');

      // Still 1 call because 350ms hasn't passed
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fetchCallCount, 1);

      // Wait out remaining debounce duration (> 350ms)
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(fetchCallCount, 2); // exactly one additional request sent!
      expect(notifier.state.query.search, 'cargo');

      notifier.dispose();
    });
  });
}

class _ControllablePagedSource<T> implements PagedSource<T> {
  final Future<PageResult<T>> Function(ListQuery query) fetch;

  _ControllablePagedSource({required this.fetch});

  @override
  Future<PageResult<T>> fetchPage(ListQuery query, {CancelToken? cancelToken}) =>
      fetch(query);
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
