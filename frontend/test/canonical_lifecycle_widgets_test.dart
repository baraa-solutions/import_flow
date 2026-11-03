import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/lifecycle_board/widgets/phase_pending_badge.dart';
import 'package:frontend/features/lifecycle_board/widgets/shipment_kpi_metric_bar.dart';
import 'package:frontend/features/lifecycle_board/widgets/step_action_dialog.dart';

Widget _buildTestBoilerplate({
  required Widget child,
  Locale locale = const Locale('ar'),
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: locale,
    supportedLocales: AppLocales.supportedLocales,
    localizationsDelegates: AppLocales.localizationsDelegates,
    home: AppLocalizationsProvider(
      locale: locale,
      child: Directionality(
        textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('Canonical Lifecycle UI Localization Tests', () {
    late AppLocalizations ar;
    late AppLocalizations en;

    setUp(() {
      ar = const AppLocalizationsAr();
      en = const AppLocalizationsEn();
    });

    test('KPI and phase pending badge localization keys in Arabic and English', () {
      expect(ar.kpiHealthScoreTitle, isNotEmpty);
      expect(en.kpiHealthScoreTitle, isNotEmpty);
      expect(ar.kpiHealthScoreValue(85), contains('85'));
      expect(en.kpiHealthScoreValue(85), contains('85'));
      expect(ar.kpiHealthScoreTooltip, isNotEmpty);
      expect(en.kpiHealthScoreTooltip, isNotEmpty);

      expect(ar.kpiFreeTimeBurnTitle, isNotEmpty);
      expect(en.kpiFreeTimeBurnTitle, isNotEmpty);
      expect(ar.kpiFreeTimeBurnValue(40, 10), contains('40'));
      expect(ar.kpiFreeTimeBurnValue(40, 10), contains('10'));
      expect(en.kpiFreeTimeBurnValue(40, 10), contains('40'));
      expect(en.kpiFreeTimeBurnValue(40, 10), contains('10'));
      expect(ar.kpiFreeTimeBurnTooltip, isNotEmpty);
      expect(en.kpiFreeTimeBurnTooltip, isNotEmpty);

      expect(ar.kpiBlockersAndOverdueTitle, isNotEmpty);
      expect(en.kpiBlockersAndOverdueTitle, isNotEmpty);
      expect(ar.kpiOverdueCountBadge(3), contains('3'));
      expect(en.kpiOverdueCountBadge(3), contains('3'));
      expect(ar.kpiBlockersCountBadge(2), contains('2'));
      expect(en.kpiBlockersCountBadge(2), contains('2'));
      expect(ar.kpiNoBlockersBadge, isNotEmpty);
      expect(en.kpiNoBlockersBadge, isNotEmpty);

      expect(ar.kpiCostVarianceTitle, isNotEmpty);
      expect(en.kpiCostVarianceTitle, isNotEmpty);
      expect(ar.kpiCostVarianceValue('+', 5.2), contains('+5.2%'));
      expect(en.kpiCostVarianceValue('+', 5.2), contains('+5.2%'));

      expect(ar.phasePendingShipmentsTitle, isNotEmpty);
      expect(en.phasePendingShipmentsTitle, isNotEmpty);
      expect(ar.phasePendingCountBadge(4), contains('4'));
      expect(en.phasePendingCountBadge(4), contains('4'));
      expect(ar.phaseDelayedCountBadge(2), contains('2'));
      expect(en.phaseDelayedCountBadge(2), contains('2'));
      expect(ar.phaseAllClearBadge, isNotEmpty);
      expect(en.phaseAllClearBadge, isNotEmpty);
      expect(ar.phasePendingBadgeTooltip, isNotEmpty);
      expect(en.phasePendingBadgeTooltip, isNotEmpty);
    });
  });

  group('ShipmentKpiMetricBar Widget Tests', () {
    testWidgets('renders all 4 indicators and is wrapped in SelectionArea', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(
            healthScorePercent: 92.0,
            freeDaysRemaining: 10,
            freeDaysTotal: 14,
            overdueStepsCount: 0,
            blockersCount: 0,
            costVariancePercent: 4.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsOneWidget);

      // Verify AppStatusBadge count (Health, FreeTime, Blockers/Overdue, CostVariance)
      expect(find.byType(AppStatusBadge), findsNWidgets(4));

      // Check text values
      expect(find.textContaining('92%'), findsOneWidget);
      expect(find.textContaining('10'), findsOneWidget);
      expect(find.textContaining('+4.5%'), findsOneWidget);
    });

    testWidgets('free time severity coloring: green (>7d), orange (3-7d), red (<3d)', (tester) async {
      // 1. Green (>7 days)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(
            healthScorePercent: 85.0,
            freeDaysRemaining: 12,
            freeDaysTotal: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgesGreen = tester.widgetList<AppStatusBadge>(find.byType(AppStatusBadge)).toList();
      // Second badge is Free Time Burn
      expect(badgesGreen[1].severity, equals(AppSeverity.success));

      // 2. Orange (3-7 days)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(
            healthScorePercent: 85.0,
            freeDaysRemaining: 5,
            freeDaysTotal: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgesOrange = tester.widgetList<AppStatusBadge>(find.byType(AppStatusBadge)).toList();
      expect(badgesOrange[1].severity, equals(AppSeverity.warning));

      // 3. Red (<3 days)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(
            healthScorePercent: 85.0,
            freeDaysRemaining: 1,
            freeDaysTotal: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgesRed = tester.widgetList<AppStatusBadge>(find.byType(AppStatusBadge)).toList();
      expect(badgesRed[1].severity, equals(AppSeverity.danger));
    });

    testWidgets('health score gradient severity: >=80% success, 50-79% warning, <50% danger', (tester) async {
      // Success (>=80%)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(healthScorePercent: 85.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppStatusBadge>(find.byType(AppStatusBadge).first).severity, equals(AppSeverity.success));

      // Warning (50-79%)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(healthScorePercent: 65.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppStatusBadge>(find.byType(AppStatusBadge).first).severity, equals(AppSeverity.warning));

      // Danger (<50%)
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const ShipmentKpiMetricBar(healthScorePercent: 40.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppStatusBadge>(find.byType(AppStatusBadge).first).severity, equals(AppSeverity.danger));
    });

    testWidgets('factory fromTrackingItem parses data accurately', (tester) async {
      final item = LiveLogisticsTrackingItemModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-001',
        companyName: 'Sorour Importers',
        supplierName: 'Global Supplier Ltd',
        arrivalStatus: 'In-Port',
        demurrageStatus: 'Active',
        freeDaysTotal: 14,
        freeDaysRemaining: 4,
        usedFreeDays: 10,
        accumulatedDemurrageFx: 0.0,
        accumulatedDemurrageEgp: 0.0,
        sampleTestStatus: 'Passed',
        docReadinessPercent: 100.0,
        verifiedDocumentsCount: 7,
        totalRequiredDocuments: 7,
        missingDocuments: [],
        operationalHealthScore: '95%',
        currentStepCode: 'STEP_13',
        currentStepNameAr: 'الإفراج الجمركي',
        currentStepNameEn: 'Customs Clearance',
        nextAction: 'Final Inspection',
      );

      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: ShipmentKpiMetricBar.fromTrackingItem(
            item,
            overdueStepsCount: 1,
            costVariancePercent: -2.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShipmentKpiMetricBar), findsOneWidget);
      expect(find.textContaining('95%'), findsOneWidget);
      expect(find.textContaining('4'), findsOneWidget);
      expect(find.textContaining('-2.0%'), findsOneWidget);
    });
  });

  group('PhasePendingBadge Widget Tests', () {
    testWidgets('renders all-clear badge when delayed and pending are 0', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const PhasePendingBadge(
            pendingShipmentsCount: 0,
            delayedShipmentsCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
      final badge = tester.widget<AppStatusBadge>(find.byType(AppStatusBadge));
      expect(badge.severity, equals(AppSeverity.success));
    });

    testWidgets('renders delayed and pending badges when both > 0', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const PhasePendingBadge(
            pendingShipmentsCount: 5,
            delayedShipmentsCount: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppStatusBadge), findsNWidgets(2));
      final badges = tester.widgetList<AppStatusBadge>(find.byType(AppStatusBadge)).toList();
      expect(badges[0].severity, equals(AppSeverity.danger));
      expect(badges[1].severity, equals(AppSeverity.warning));
    });

    testWidgets('factory fromPhaseSummary works properly', (tester) async {
      final phase = PhaseSummaryModel(
        phaseId: 1,
        titleEn: 'Preparation',
        titleAr: 'التجهيز المبدئي',
        colorHex: '#3498DB',
        stepCodes: ['STEP_01', 'STEP_02'],
        totalActiveShipments: 8,
        stepCounts: {'STEP_01': 5, 'STEP_02': 3},
      );

      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: PhasePendingBadge.fromPhaseSummary(
            phase,
            delayedShipmentsCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhasePendingBadge), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsNWidgets(2));
    });
  });

  group('StepActionDialog Widget Structure Tests', () {
    testWidgets('Dialog is wrapped in SelectionArea and uses AppStatusBadge for stepCode', (tester) async {
      final shipment = ShipmentStageCardModel(
        importFileCode: 'IMP-2026-999',
        companyName: 'Al-Amal Trading',
        supplierName: 'Siemens AG',
        stepCode: 'STEP_05',
        stepNameEn: 'ACID Issuance',
        stepNameAr: 'استخراج الرقم التعريفي ACID',
        status: 'In-Progress',
      );

      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: StepActionDialog(
            shipment: shipment,
            allPhases: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top level dialog must be wrapped in SelectionArea
      expect(find.byType(SelectionArea), findsAtLeastNWidgets(1));

      // Uses AppStatusBadge for the step code badge in header
      expect(find.byType(AppStatusBadge), findsOneWidget);
      final badge = tester.widget<AppStatusBadge>(find.byType(AppStatusBadge));
      expect(badge.label, equals('STEP_05'));
      expect(badge.severity, equals(AppSeverity.info));
    });
  });
}
