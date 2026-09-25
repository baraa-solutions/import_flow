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
import 'package:frontend/features/production_sync/screens/production_sync_screen.dart';
import 'package:frontend/features/production_sync/services/local_process_sync_service.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200, headers: {
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

class _MockLocalProcessSyncService implements LocalProcessSyncService {
  @override
  String get projectRoot => 'mock_root';
  @override
  String get devDbPath => 'mock_dev.db';
  @override
  String get prodDbPath => 'mock_prod.db';
  @override
  String get backupsPath => 'mock_backups';

  @override
  LocalDbStats getDbStats(String dbPath) => const LocalDbStats(
        exists: true,
        dbPath: 'mock.db',
        sizeKb: 1024,
        mtime: '2026-09-08 12:00',
      );

  @override
  List<LocalBackupEntry> listBackups() => const [
        LocalBackupEntry(
          filename: 'mock_b1.db',
          filepath: 'mock_backups/mock_b1.db',
          sizeKb: 1024,
          mtime: '2026-09-08 12:00',
          tag: 'dev',
        ),
      ];

  @override
  Future<int> compareDatabases({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  }) async {
    onDiffSummary?.call(const SyncDiffSummary(
      exists: true,
      targetExists: true,
      totalNewRecords: 0,
      tablesWithDiff: 0,
      tables: [],
    ));
    return 0;
  }

  @override
  Future<int> createManualBackup({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 59: ProductionSyncScreen Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      final testDio = _createTestDio();
      final mockService = _MockLocalProcessSyncService();

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
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ProductionSyncScreen(service: mockService),
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
            child: MaterialApp(
              home: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ProductionSyncScreen(service: mockService),
                ),
              ),
            ),
          ),
        );
        final firstFrameMs = navWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);
        await tester.pumpAndSettle();
        navWatch.stop();
        final settledMs = navWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);

        final outWatch = Stopwatch()..start();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Center(child: Text('Empty')))),
        );
        await tester.pumpAndSettle();
        outWatch.stop();
        final navOutMs = outWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);

        debugPrint('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Settled: ${settledMs}ms | Nav-OUT: ${navOutMs}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) / navInFirstFrameTimes.length;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) / navInSettledTimes.length;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) / navOutTimes.length;

      debugPrint('Screen 59 Benchmark: First Frame: ${avgFirstFrame.toStringAsFixed(1)}ms | Settled: ${avgSettled.toStringAsFixed(1)}ms | Nav-OUT: ${avgNavOut.toStringAsFixed(1)}ms');

      expect(avgFirstFrame, lessThan(300), reason: 'Nav-IN First Frame must be under 300ms');
      expect(avgSettled, lessThan(350), reason: 'Nav-IN Settled must be under 350ms');
      expect(avgNavOut, lessThan(150), reason: 'Nav-OUT must be under 150ms');
    });
  });
}
