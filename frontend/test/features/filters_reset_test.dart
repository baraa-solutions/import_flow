import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/cbm_calculator/providers/cbm_calculator_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/shipping_scenarios/providers/shipping_scenarios_provider.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  RequestOptions? get lastGet => requests.reversed.firstWhere(
        (r) => r.method == 'GET',
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late _RecordingAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    await _settle();
  });

  tearDown(() => container.dispose());

  group('FE01-T08: Filters can be reset to "All" via sentinel copyWith', () {
    test('purchaseOrdersProvider: setStatusFilter and setProjectFilter reset to null', () async {
      final notifier = container.read(purchaseOrdersProvider.notifier);
      await _settle();

      // 1. Set status filter to APPROVED
      notifier.setStatusFilter('APPROVED');
      await _settle();
      expect(container.read(purchaseOrdersProvider).statusFilter, 'APPROVED');
      expect(adapter.lastGet?.queryParameters['status'], 'APPROVED');

      // 2. Reset status filter to null (All)
      notifier.setStatusFilter(null);
      await _settle();
      expect(container.read(purchaseOrdersProvider).statusFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('status'), isFalse);

      // 3. Set project filter
      notifier.setProjectFilter(42);
      await _settle();
      expect(container.read(purchaseOrdersProvider).projectFilter, 42);
      expect(adapter.lastGet?.queryParameters['project_id'], 42);

      // 4. Reset project filter to null (All)
      notifier.setProjectFilter(null);
      await _settle();
      expect(container.read(purchaseOrdersProvider).projectFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('project_id'), isFalse);
    });

    test('cbmCalculatorProvider: setProjectFilter and setPoFilter reset to null', () async {
      final notifier = container.read(cbmCalculatorProvider.notifier);
      await _settle();

      // 1. Set project filter
      notifier.setProjectFilter(10);
      await _settle();
      expect(container.read(cbmCalculatorProvider).projectFilter, 10);
      expect(adapter.lastGet?.queryParameters['project_id'], 10);

      // 2. Reset project filter to null
      notifier.setProjectFilter(null);
      await _settle();
      expect(container.read(cbmCalculatorProvider).projectFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('project_id'), isFalse);

      // 3. Set po filter
      notifier.setPoFilter(20);
      await _settle();
      expect(container.read(cbmCalculatorProvider).poFilter, 20);
      expect(adapter.lastGet?.queryParameters['po_id'], 20);

      // 4. Reset po filter to null
      notifier.setPoFilter(null);
      await _settle();
      expect(container.read(cbmCalculatorProvider).poFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('po_id'), isFalse);
    });

    test('shippingScenariosProvider: setProjectFilter and setPoFilter reset to null', () async {
      final notifier = container.read(shippingScenariosProvider.notifier);
      await _settle();

      // 1. Set project filter
      notifier.setProjectFilter(15);
      await _settle();
      expect(container.read(shippingScenariosProvider).projectFilter, 15);
      expect(adapter.lastGet?.queryParameters['project_id'], 15);

      // 2. Reset project filter to null
      notifier.setProjectFilter(null);
      await _settle();
      expect(container.read(shippingScenariosProvider).projectFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('project_id'), isFalse);

      // 3. Set po filter
      notifier.setPoFilter(25);
      await _settle();
      expect(container.read(shippingScenariosProvider).poFilter, 25);
      expect(adapter.lastGet?.queryParameters['po_id'], 25);

      // 4. Reset po filter to null
      notifier.setPoFilter(null);
      await _settle();
      expect(container.read(shippingScenariosProvider).poFilter, isNull);
      expect(adapter.lastGet?.queryParameters.containsKey('po_id'), isFalse);
    });
  });
}
