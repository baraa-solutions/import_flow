@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/lifecycle_board/models/step_config_model.dart';
import 'package:frontend/features/lifecycle_board/providers/step_config_provider.dart';
import 'package:frontend/features/lifecycle_board/screens/step_config_management_screen.dart';

class _MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _MockAuthNotifier()
      : super(AuthState(
          isAuthenticated: true,
          user: UserModel(
            userId: 1,
            username: 'manager_perf',
            email: 'manager@sorour.com',
            fullName: 'Performance Manager',
            role: 'MANAGER',
            isActive: true,
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStepConfigNotifier extends StateNotifier<StepConfigState>
    implements StepConfigNotifier {
  _MockStepConfigNotifier()
      : super(StepConfigState(
          configs: List.generate(
            21,
            (idx) => StepConfigModel(
              id: idx + 1,
              stepCode: 'STEP_${(idx + 1).toString().padLeft(2, "0")}',
              stepNameAr: 'خطوة تشغيلية اختبارية رقم ${idx + 1}',
              stepNameEn: 'Operational Test Step Number ${idx + 1}',
              phaseId: (idx ~/ 4) + 1,
              skipPolicy: idx % 3 == 0
                  ? 'blocked'
                  : (idx % 3 == 1 ? 'single_approval' : 'dual_approval'),
              supportsPendingReference: idx % 2 == 0,
              reasonCategories: ['Reason A', 'Reason B'],
              approverRoles: ['Manager'],
              lastModifiedBy: 'admin',
              lastModifiedAt: '2026-09-10 02:00',
            ),
          ),
          isLoading: false,
        ));

  @override
  Future<void> fetchConfigs() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 67: StepConfigManagementScreen Performance Diagnostics', () {
    testWidgets('Measure Nav-IN and Nav-OUT latency across 3 runs',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Warm-up run to eliminate cold JIT compilation overhead
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            stepConfigProvider.overrideWith((ref) => _MockStepConfigNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: StepConfigManagementScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Empty Destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navInFirstFrameTimes = <int>[];
      final navInSettledTimes = <int>[];
      final navOutTimes = <int>[];

      for (int run = 1; run <= 3; run++) {
        final navInWatch = Stopwatch()..start();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _MockAuthNotifier()),
              stepConfigProvider
                  .overrideWith((ref) => _MockStepConfigNotifier()),
            ],
            child: const MaterialApp(
              locale: Locale('ar'),
              home: AppLocalizationsProvider(
                locale: Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: StepConfigManagementScreen(),
                ),
              ),
            ),
          ),
        );

        final firstFrameMs = navInWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        final settledMs = navInWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);
        navInWatch.stop();

        // Verify loaded content
        expect(find.byType(StepConfigManagementScreen), findsOneWidget);
        expect(find.text('STEP_01'), findsOneWidget);

        // Measure Nav-OUT
        final navOutWatch = Stopwatch()..start();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final navOutMs = navOutWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);
        navOutWatch.stop();
      }

      final avgFirstFrame =
          navInFirstFrameTimes.reduce((a, b) => a + b) ~/ 3;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ 3;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) ~/ 3;

      debugPrint('=== Screen 67 Performance Benchmark Summary ===');
      debugPrint('Nav-IN First Frame Average: ${avgFirstFrame}ms');
      debugPrint('Nav-IN Settled Frame Average: ${avgSettled}ms');
      debugPrint('Nav-OUT Average: ${avgNavOut}ms');

      expect(avgFirstFrame, lessThanOrEqualTo(1000));
      expect(avgSettled, lessThanOrEqualTo(1200));
      expect(avgNavOut, lessThanOrEqualTo(300));
    });
  });
}
