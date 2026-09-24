import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/lifecycle_board/screens/lifecycle_board_screen.dart';
import 'package:frontend/features/lifecycle_board/services/lifecycle_board_export_service.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 48: LifecycleBoardScreen Performance & Export Diagnostics', () {
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
                child: LifecycleBoardScreen(),
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
                  child: LifecycleBoardScreen(),
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

      debugPrint('Screen 48 Benchmark: First Frame: ${avgFirstFrame.toStringAsFixed(1)}ms | Settled: ${avgSettled.toStringAsFixed(1)}ms | Nav-OUT: ${avgNavOut.toStringAsFixed(1)}ms');

      expect(avgFirstFrame, lessThan(400), reason: 'Nav-IN First Frame must be responsive');
      expect(avgSettled, lessThan(600), reason: 'Nav-IN Settled must be responsive');
      expect(avgNavOut, lessThan(200), reason: 'Nav-OUT must be responsive');
    }, tags: ['perf']);

    testWidgets('Export service dossier generation verification', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));

      final testShipment = ShipmentStageCardModel(
        importFileCode: 'IMP-2026-001',
        companyName: 'Test Company',
        supplierName: 'Test Supplier',
        poNumber: 'PO-999',
        shipmentMode: 'FCL',
        incotermCode: 'CIF',
        priority: 'NORMAL',
        estimatedCost: 50000,
        estimatedCostCurrency: 'USD',
        stepCode: 'STEP_04',
        stepNameEn: 'Customs Clearance',
        stepNameAr: 'التخليص الجمركي',
        status: 'Active',
        notes: 'Test notes',
      );

      final testPhase = PhaseSummaryModel(
        phaseId: 1,
        titleAr: 'المرحلة الأولى',
        titleEn: 'Phase 1',
        colorHex: '#3498DB',
        stepCodes: ['STEP_01', 'STEP_02', 'STEP_03', 'STEP_04'],
        stepCounts: {'STEP_04': 1},
        totalActiveShipments: 1,
      );

      final kanbanDossier = LifecycleBoardExportService.buildKanbanDossierText(
        context: context,
        shipments: [testShipment],
        phases: [testPhase],
        filterTitle: 'جميع الشحنات',
      );

      expect(kanbanDossier, contains('IMP-2026-001'));
      expect(kanbanDossier, contains('Test Company'));
      expect(kanbanDossier, contains('اعتماد الميزانية'));

      final testRadarItem = LiveLogisticsTrackingItemModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        companyName: 'Test Company',
        supplierName: 'Test Supplier',
        carrierName: 'Maersk',
        vesselName: 'Ever Given',
        blNumber: 'BL-123456',
        polName: 'Shanghai',
        podName: 'Alexandria',
        eta: '2026-09-20',
        etaCountdownDays: 11,
        arrivalStatus: 'In Transit',
        demurrageStatus: 'OK',
        demurrageRiskLevel: 'Safe',
        accumulatedDemurrageFx: 0,
        accumulatedDemurrageEgp: 0,
        freeDaysRemaining: 14,
        freeDaysTotal: 14,
        usedFreeDays: 0,
        sampleTestStatus: 'Approved',
        docReadinessPercent: 100.0,
        verifiedDocumentsCount: 5,
        totalRequiredDocuments: 5,
        missingDocuments: [],
        operationalHealthScore: '100',
        currentStepCode: 'STEP_04',
        currentStepNameAr: 'التخليص الجمركي',
        currentStepNameEn: 'Customs Clearance',
        nextAction: 'None',
        shipmentMode: 'FCL',
        incotermCode: 'CIF',
        priority: 'NORMAL',
      );

      final radarDossier = LifecycleBoardExportService.buildRadarDossierText(
        context: context,
        items: [testRadarItem],
      );

      expect(radarDossier, contains('IMP-2026-001'));
      expect(radarDossier, contains('Maersk'));
      expect(radarDossier, contains('BL-123456'));
    });
  });
}
