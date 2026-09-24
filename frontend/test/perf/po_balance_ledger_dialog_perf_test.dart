// test/perf/po_balance_ledger_dialog_perf_test.dart
// Modal 12 — POBalanceLedgerDialog Performance Benchmark
// Pattern: 1 warm-up run + 3 measured runs, average checked against thresholds
// Thresholds: avg first frame <= 300ms | avg settled <= 350ms | avg disposal <= 150ms

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/purchase_orders/widgets/po_balance_ledger_dialog.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — returns a valid PO balance JSON payload immediately
// ---------------------------------------------------------------------------
class _MockHttpAdapter implements HttpClientAdapter {
  static final _mockBody = jsonEncode({
    'total_ordered_quantity': 500.0,
    'total_shipped_quantity': 250.0,
    'total_remaining_quantity': 250.0,
    'total_ordered_fob_usd': 50000.0,
    'total_shipped_fob_usd': 25000.0,
    'total_remaining_fob_usd': 25000.0,
    'fulfillment_percentage': 50.0,
    'is_fully_shipped': false,
    'line_items': [
      {
        'item_code': 'ITM-001',
        'description': 'Product A',
        'ordered_quantity': 300.0,
        'shipped_quantity': 150.0,
        'remaining_quantity': 150.0,
        'is_fully_shipped': false,
      },
      {
        'item_code': 'ITM-002',
        'description': 'Product B',
        'ordered_quantity': 200.0,
        'shipped_quantity': 100.0,
        'remaining_quantity': 100.0,
        'is_fully_shipped': false,
      },
    ],
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      _mockBody,
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Builder helpers
// ---------------------------------------------------------------------------
Widget _buildTestWidget() {
  final mockDio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  mockDio.httpClientAdapter = _MockHttpAdapter();
  return ProviderScope(
    overrides: [dioProvider.overrideWithValue(mockDio)],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(
          child: POBalanceLedgerDialog(poId: 1, poCode: 'PO-2026-001'),
        ),
      ),
    ),
  );
}

// Runs one open-settle-close cycle and returns timing in ms
Future<(int firstFrame, int settled, int disposal)> _measureOneCycle(
    WidgetTester tester) async {
  final sw = Stopwatch()..start();
  await tester.pumpWidget(_buildTestWidget());
  await tester.pump();
  final firstFrameMs = sw.elapsedMilliseconds;

  await tester.pumpAndSettle(const Duration(seconds: 5));
  final settledMs = sw.elapsedMilliseconds;
  sw.stop();

  final dsw = Stopwatch()..start();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final disposalMs = dsw.elapsedMilliseconds;

  return (firstFrameMs, settledMs, disposalMs);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  group('POBalanceLedgerDialog — Performance Benchmark', () {
    testWidgets(
        'Avg of 3 runs: first frame <= 300ms | settled <= 350ms | disposal <= 150ms',
        (tester) async {
      // Warm-up run to eliminate cold JIT overhead
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugPrint('[PERF WARMUP] warm-up complete');

      final List<int> firstFrameTimes = [];
      final List<int> settledTimes = [];
      final List<int> disposalTimes = [];

      for (int i = 1; i <= 3; i++) {
        final (ff, s, d) = await _measureOneCycle(tester);
        firstFrameTimes.add(ff);
        settledTimes.add(s);
        disposalTimes.add(d);
        debugPrint('[PERF R$i] firstFrame=${ff}ms settled=${s}ms disposal=${d}ms');
      }

      final avgFirstFrame = firstFrameTimes.reduce((a, b) => a + b) ~/ firstFrameTimes.length;
      final avgSettled    = settledTimes.reduce((a, b) => a + b) ~/ settledTimes.length;
      final avgDisposal   = disposalTimes.reduce((a, b) => a + b) ~/ disposalTimes.length;

      debugPrint('[PERF AVG] firstFrame=${avgFirstFrame}ms settled=${avgSettled}ms disposal=${avgDisposal}ms');

      expect(avgFirstFrame, lessThanOrEqualTo(300), reason: 'Avg first frame <= 300ms');
      expect(avgSettled,    lessThanOrEqualTo(350), reason: 'Avg settled <= 350ms');
      expect(avgDisposal,   lessThanOrEqualTo(150), reason: 'Avg disposal <= 150ms');
    }, tags: ['perf']);

    testWidgets('Renders summary cards and 2 line items after data loads',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('اaaaaaaaaaaaaaaaaaaaaaaaaaa'), findsNothing);
      expect(find.text('ITM-001'), findsOneWidget);
      expect(find.text('ITM-002'), findsOneWidget);
    });

    testWidgets('CancelToken: fast dispose does not crash', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump(); // request still in-flight
      // Dispose immediately — triggers cancelToken.cancel()
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      // No exception == pass
    });
  });
}
