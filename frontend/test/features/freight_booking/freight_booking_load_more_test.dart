import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/widgets/list_load_more_footer.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/freight_booking/providers/freight_booking_provider.dart';

/// Serves /freight-booking pages of a 3-row registry and records every query.
class _Adapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> calls = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    calls.add(Map<String, dynamic>.from(o.queryParameters));
    final skip = o.queryParameters['skip'] as int;
    final ids = skip == 0 ? [1, 2] : [3];
    return ResponseBody.fromString(
      '[${ids.map((i) => '{"booking_id":$i,"booking_code":"BKG-$i"}').join(',')}]',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-total-count': ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle(FreightBookingNotifier n) async {
  for (var i = 0; i < 100 && n.state.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('loadMore reuses the filters of the last fetch and appends the next page', () async {
    final adapter = _Adapter();
    final n = FreightBookingNotifier(Dio()..httpClientAdapter = adapter);
    await _settle(n);

    await n.fetchBookings(status: 'Confirmed', search: 'MSC', importFileId: 7);
    await _settle(n);
    expect(n.state.value!.length, 2);
    expect(n.hasMore, isTrue);

    await n.loadMore();
    expect(n.state.value!.length, 3);
    expect(n.hasMore, isFalse);
    final last = adapter.calls.last;
    expect(last['skip'], 2);
    expect(last['status'], 'Confirmed');
    expect(last['search'], 'MSC');
    expect(last['import_file_id'], 7);
  });

  testWidgets('ListLoadMoreFooter shows loaded of total and calls onLoadMore', (tester) async {
    var calls = 0;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocales.localizationsDelegates,
        supportedLocales: AppLocales.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ListLoadMoreFooter(loaded: 2, total: 3, hasMore: true, onLoadMore: () async => calls++),
        ),
      ),
    ));
    expect(find.textContaining(RegExp(r'2\D+3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('listLoadMoreBtn')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('ListLoadMoreFooter renders nothing when everything is loaded', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocales.localizationsDelegates,
      supportedLocales: AppLocales.supportedLocales,
      home: Scaffold(
        body: ListLoadMoreFooter(loaded: 3, total: 3, hasMore: false, onLoadMore: () async {}),
      ),
    ));
    expect(find.byKey(const Key('listLoadMoreBtn')), findsNothing);
  });

  test('customs clearance model keeps a missing inspection_result as null (no invented Conforming)', () {
    final m = CustomsClearanceModel.fromJson({'clearance_id': 1, 'import_file_id': 1});
    expect(m.inspectionResult, isNull);
  });
}
