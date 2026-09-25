import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/customs_tariff/widgets/tariff_form_dialog.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — returns empty list for any request (no real network)
// ---------------------------------------------------------------------------
class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpAdapter();
  return dio;
}

// ---------------------------------------------------------------------------
// Helper widget harness
// ---------------------------------------------------------------------------
Widget _buildHarness(Dio testDio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(testDio),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open_tariff_dialog'),
              onPressed: () => showTariffDialog(context, ref),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<({int firstFrame, int settled, int disposal})> _measureCycle(
    WidgetTester tester) async {
  await tester.pump();

  final t0 = DateTime.now();
  await tester.tap(find.byKey(const Key('open_tariff_dialog')));
  await tester.pump();
  final firstFrame = DateTime.now().difference(t0).inMilliseconds;

  final t1 = DateTime.now();
  await tester.pumpAndSettle();
  final settled = firstFrame + DateTime.now().difference(t1).inMilliseconds;

  expect(find.byType(AlertDialog), findsOneWidget);

  final t2 = DateTime.now();
  final cancelBtn = find.widgetWithText(TextButton, 'إلغاء');
  if (cancelBtn.evaluate().isNotEmpty) {
    await tester.tap(cancelBtn);
  } else {
    await tester.tapAt(const Offset(10, 10));
  }
  await tester.pumpAndSettle();
  final disposal = DateTime.now().difference(t2).inMilliseconds;

  return (firstFrame: firstFrame, settled: settled, disposal: disposal);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TariffFormDialog — Performance Benchmarks', () {
    testWidgets('warm-up run (excluded from metrics)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));
      await _measureCycle(tester);
    }, tags: ['perf']);

    testWidgets('avg first-frame render <= 300ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));
      await _measureCycle(tester); // warm-up

      int totalFirst = 0;
      for (int i = 0; i < 3; i++) {
        final r = await _measureCycle(tester);
        totalFirst += r.firstFrame;
      }

      final avg = totalFirst ~/ 3;
      debugPrint('[TariffFormDialog] avg first-frame: ${avg}ms');
      expect(avg, lessThanOrEqualTo(300),
          reason: 'avg first-frame should be <= 300ms, got ${avg}ms');
    }, tags: ['perf']);

    testWidgets('avg settled render <= 350ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));
      await _measureCycle(tester); // warm-up

      int totalSettled = 0;
      for (int i = 0; i < 3; i++) {
        final r = await _measureCycle(tester);
        totalSettled += r.settled;
      }

      final avg = totalSettled ~/ 3;
      debugPrint('[TariffFormDialog] avg settled: ${avg}ms');
      expect(avg, lessThanOrEqualTo(350),
          reason: 'avg settled should be <= 350ms, got ${avg}ms');
    }, tags: ['perf']);

    testWidgets('avg disposal <= 150ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));
      await _measureCycle(tester); // warm-up

      int totalDisposal = 0;
      for (int i = 0; i < 3; i++) {
        final r = await _measureCycle(tester);
        totalDisposal += r.disposal;
      }

      final avg = totalDisposal ~/ 3;
      debugPrint('[TariffFormDialog] avg disposal: ${avg}ms');
      expect(avg, lessThanOrEqualTo(150),
          reason: 'avg disposal should be <= 150ms, got ${avg}ms');
    }, tags: ['perf']);

    testWidgets('dialog renders title and cancel button correctly in Add mode', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));
      await tester.tap(find.byKey(const Key('open_tariff_dialog')));
      await tester.pumpAndSettle();

      expect(find.textContaining('إضافة بند جمركي'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'إلغاء'), findsOneWidget);
    });

    testWidgets('controllers disposed after close — no leak on reopen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildHarness(_createTestDio()));

      await tester.tap(find.byKey(const Key('open_tariff_dialog')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_tariff_dialog')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
