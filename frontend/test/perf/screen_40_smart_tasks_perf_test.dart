@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/smart_tasks/screens/smart_tasks_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 40: SmartTasksScreen Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      // Warm-up run
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
                child: SmartTasksScreen(),
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
                  child: SmartTasksScreen(),
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

      debugPrint('Screen 40 Benchmark: First Frame: ${avgFirstFrame.toStringAsFixed(1)}ms | Settled: ${avgSettled.toStringAsFixed(1)}ms | Nav-OUT: ${avgNavOut.toStringAsFixed(1)}ms');

      expect(avgFirstFrame, lessThan(1000), reason: 'Nav-IN First Frame must be under 1000ms');
      expect(avgSettled, lessThan(1200), reason: 'Nav-IN Settled must be under 1200ms');
      expect(avgNavOut, lessThan(300), reason: 'Nav-OUT must be under 300ms');
    });
  });
}
