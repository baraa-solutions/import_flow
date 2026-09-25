@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/cbm_calculator/screens/cbm_calculator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 3: CBMCalculatorScreen Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

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
                  child: CBMCalculatorScreen(),
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
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );

        await tester.pumpAndSettle();
        outWatch.stop();
        final navOutMs = outWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);

        debugPrint('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Nav-IN (Settled): ${settledMs}ms | Nav-OUT: ${navOutMs}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) ~/ navInFirstFrameTimes.length;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ navInSettledTimes.length;
      final avgOut = navOutTimes.reduce((a, b) => a + b) ~/ navOutTimes.length;

      debugPrint('=== Summary Screen 3 Diagnostics ===');
      debugPrint('Average Nav-IN First Frame: ${avgFirstFrame}ms');
      debugPrint('Average Nav-IN Settled Interactive: ${avgSettled}ms');
      debugPrint('Average Nav-OUT Disposal: ${avgOut}ms');

      expect(avgFirstFrame, greaterThanOrEqualTo(0));
    });
  });
}
