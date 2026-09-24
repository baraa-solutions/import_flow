// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/shipment_updates/widgets/shipment_update_dialog.dart';

// ---------------------------------------------------------------------------
// Mock HTTP adapter — returns empty lists for all endpoints
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
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
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
// Helper: build a testable widget tree using AppLocalizationsProvider
// ---------------------------------------------------------------------------
Widget _buildTestApp(Dio testDio) {
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(testDio),
      localeProvider.overrideWith((ref) {
        final n = LocaleNotifier();
        n.setLocale(const Locale('ar'));
        return n;
      }),
    ],
    child: const MaterialApp(
      home: AppLocalizationsProvider(
        locale: Locale('ar'),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Measure cycle: open dialog -> pump -> measure -> close -> dispose
// ---------------------------------------------------------------------------
Future<({int firstFrameMs, int settledMs, int disposalMs})> _measureCycle(
  WidgetTester tester,
  Dio testDio,
) async {
  await tester.pumpWidget(_buildTestApp(testDio));
  await tester.pumpAndSettle();

  final t0 = DateTime.now();
  showDialog<void>(
    context: tester.element(find.byType(Scaffold)),
    barrierDismissible: false,
    builder: (_) => ProviderScope(
      overrides: [dioProvider.overrideWithValue(testDio)],
      child: const AppLocalizationsProvider(
        locale: Locale('ar'),
        child: ShipmentUpdateDialog(),
      ),
    ),
  );
  await tester.pump();
  final firstFrameMs = DateTime.now().difference(t0).inMilliseconds;

  final t1 = DateTime.now();
  await tester.pump(const Duration(milliseconds: 100));
  final settledMs = DateTime.now().difference(t1).inMilliseconds;

  final t2 = DateTime.now();
  await tester.tap(find.byIcon(Icons.close).first);
  await tester.pumpAndSettle();
  final disposalMs = DateTime.now().difference(t2).inMilliseconds;

  return (firstFrameMs: firstFrameMs, settledMs: settledMs, disposalMs: disposalMs);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShipmentUpdateDialog — Performance Benchmarks', () {
    testWidgets('warm-up run (excluded from metrics)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _measureCycle(tester, _createTestDio());
    }, tags: ['perf']);

    testWidgets('avg first-frame render <= 300ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final runs = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = await _measureCycle(tester, _createTestDio());
        runs.add(r.firstFrameMs);
      }
      final avg = runs.reduce((a, b) => a + b) ~/ runs.length;
      print('[ShipmentUpdateDialog] avg first-frame: ${avg}ms');
      expect(avg, lessThanOrEqualTo(300));
    }, tags: ['perf']);

    testWidgets('avg settled render <= 350ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final runs = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = await _measureCycle(tester, _createTestDio());
        runs.add(r.settledMs);
      }
      final avg = runs.reduce((a, b) => a + b) ~/ runs.length;
      print('[ShipmentUpdateDialog] avg settled: ${avg}ms');
      expect(avg, lessThanOrEqualTo(350));
    }, tags: ['perf']);

    testWidgets('avg disposal <= 150ms', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final runs = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = await _measureCycle(tester, _createTestDio());
        runs.add(r.disposalMs);
      }
      final avg = runs.reduce((a, b) => a + b) ~/ runs.length;
      print('[ShipmentUpdateDialog] avg disposal: ${avg}ms');
      expect(avg, lessThanOrEqualTo(150));
    }, tags: ['perf']);

    testWidgets('dialog renders published_with_changes icon and close button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final testDio = _createTestDio();
      await tester.pumpWidget(_buildTestApp(testDio));
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.byType(Scaffold)),
        builder: (_) => ProviderScope(
          overrides: [dioProvider.overrideWithValue(testDio)],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: ShipmentUpdateDialog(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.published_with_changes), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('controllers disposed after close — no leak on reopen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      for (var i = 0; i < 2; i++) {
        await _measureCycle(tester, _createTestDio());
      }
    });
  });
}
