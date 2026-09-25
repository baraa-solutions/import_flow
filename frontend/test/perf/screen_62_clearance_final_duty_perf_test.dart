@Tags(['perf'])
library;

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/customs_clearance/screens/customs_clearance_screen.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpClientAdapter();
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 62: CustomsClearanceScreen (Final Duty Payment & Release) Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final testDio = _createTestDio();

      // Warm-up run
      await tester.pumpWidget(
        ProviderScope(
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
                child: CustomsClearanceScreen(initialSubTab: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: Text('Empty')))),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= 3; i++) {
        final navWatch = Stopwatch()..start();
        await tester.pumpWidget(
          ProviderScope(
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
                  child: CustomsClearanceScreen(initialSubTab: 3),
                ),
              ),
            ),
          ),
        );
        final firstFrameMs = navWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        final settledMs = navWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);
        navWatch.stop();

        // Teardown / Nav-OUT
        final outWatch = Stopwatch()..start();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Center(child: Text('Empty')))),
        );
        await tester.pumpAndSettle();
        outWatch.stop();
        navOutTimes.add(outWatch.elapsedMilliseconds);

        // ignore: avoid_print
        print('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Settled: ${settledMs}ms | Nav-OUT: ${outWatch.elapsedMilliseconds}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) / 3;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) / 3;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) / 3;

      // ignore: avoid_print
      print(
        'Screen 62 Benchmark: First Frame: ${avgFirstFrame.toStringAsFixed(1)}ms | '
        'Settled: ${avgSettled.toStringAsFixed(1)}ms | '
        'Nav-OUT: ${avgNavOut.toStringAsFixed(1)}ms',
      );

      expect(avgFirstFrame, lessThan(600), reason: 'First frame should render quickly');
      expect(avgSettled, lessThan(1200), reason: 'Screen should settle under threshold');
      expect(avgNavOut, lessThan(500), reason: 'Teardown should be rapid');
    });
  });
}
