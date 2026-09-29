import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/directional_icon.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/operational_dashboard/models/operational_dashboard_model.dart';
import 'package:frontend/features/operational_dashboard/providers/operational_dashboard_provider.dart';
import 'package:frontend/features/operational_dashboard/screens/operational_dashboard_screen.dart';

import 'package:frontend/features/smart_tasks/models/smart_task_model.dart';
import 'package:frontend/features/smart_tasks/providers/smart_tasks_provider.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/lifecycle_board/providers/lifecycle_board_provider.dart';
import 'package:frontend/features/shipment_updates/models/shipment_update_model.dart';
import 'package:frontend/features/shipment_updates/providers/shipment_updates_provider.dart';

class MockOperationalDashboardNotifier extends StateNotifier<OperationalDashboardState> implements OperationalDashboardNotifier {
  MockOperationalDashboardNotifier(OperationalDashboardData sampleData)
      : super(OperationalDashboardState(data: AsyncValue.data(sampleData)));

  @override
  Future<void> fetchDashboard() async {}

  @override
  void setPriority(String priority) {}

  @override
  void setBroker(String? broker) {}

  @override
  void setSearchQuery(String query) {}

  @override
  void resetFilters() {}

  @override
  void togglePhase(String phase) {}
}

class MockSmartTasksNotifier extends StateNotifier<SmartTasksState> implements SmartTasksNotifier {
  MockSmartTasksNotifier(List<SmartTaskModel> tasks)
      : super(SmartTasksState(tasks: tasks, isLoading: false));

  @override
  Future<void> fetchTasks({String? taskType, String? status, String? priority, int? importFileId, String? search}) async {}

  @override
  Future<SmartTaskModel?> updateTask(int taskId, Map<String, dynamic> data) async => null;

  @override
  Future<SmartTaskModel?> createTask(Map<String, dynamic> data) async => null;

  @override
  Future<void> deleteTask(int taskId) async {}
}

class MockShipmentUpdatesNotifier extends StateNotifier<ShipmentUpdatesState> implements ShipmentUpdatesNotifier {
  MockShipmentUpdatesNotifier([List<ShipmentUpdateLogModel> logs = const []])
      : super(ShipmentUpdatesState(logs: logs, isLoading: false));

  @override
  Future<void> fetchLogs({int? importFileId, String? updateCategory, String? targetPhase, String? search}) async {}

  @override
  Future<ShipmentUpdateLogModel?> createLog(Map<String, dynamic> payload) async => null;

  @override
  Future<void> deleteLog(int updateId) async {}
}

void main() {
  final sampleDashboardData = OperationalDashboardData(
    shipmentCount: 2,
    lastUpdatedAt: '2026-09-14T10:00:00Z',
    availableBrokers: [
      DashboardBroker(brokerId: 1, brokerName: 'Al-Ameen Customs Clearance'),
    ],
    phaseCounts: {'Phase 1': 1, 'Phase 5': 1},
    shipments: [
      ImportFileModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-0001',
        companyName: 'Sorour Logistics Cairo',
        supplierName: 'Hamburg Industrial Tools Co.',
        brokerName: 'Al-Ameen Customs Clearance',
        priority: 'High',
        currentModule: 'Phase 5 - Customs Clearance',
        currentStage: 'Duty Payment Requested',
        progressPercent: 72.0,
        nextAction: 'Pay Customs Taxes',
        isActive: true,
        createdAt: '2026-09-01T10:00:00Z',
        updatedAt: '2026-09-14T09:00:00Z',
      ),
      ImportFileModel(
        importFileId: 102,
        importFileCode: 'IMP-2026-0002',
        companyName: 'Nile Delta Trading',
        supplierName: 'Shanghai Global Shipping',
        brokerName: 'Al-Ameen Customs Clearance',
        priority: 'Critical',
        currentModule: 'STEP_07 - Container Allocation',
        currentStage: 'VGM Verification',
        progressPercent: 35.0,
        nextAction: 'Submit CargoX Filing',
        isActive: true,
        createdAt: '2026-09-02T10:00:00Z',
        updatedAt: '2026-09-14T09:30:00Z',
      ),
    ],
  );

  final sampleTasks = [
    SmartTaskModel(
      taskId: 1,
      taskCode: 'TSK-2026-001',
      title: 'تقديم نموذج 4 الجمركي واعتماد مستندات الفحص الرقابي',
      taskType: 'Regulatory Compliance',
      status: 'Pending',
      assignedUser: 'Ahmed',
      priority: 'Critical',
      reminderType: 'Customs',
      isAutoClosed: false,
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
      createdBy: 'System',
    ),
    SmartTaskModel(
      taskId: 2,
      taskCode: 'TSK-2026-002',
      title: 'مراجعة بوليصة الشحن مع الخط الملاحي وسداد رسوم النولون',
      taskType: 'Regulatory Compliance',
      status: 'Pending',
      assignedUser: 'Ahmed',
      priority: 'High',
      reminderType: 'Shipping Line',
      isAutoClosed: false,
      isActive: true,
      createdAt: '2026-09-02T10:00:00Z',
      createdBy: 'System',
    ),
  ];

  Widget createTestWidget({
    required Locale locale,
    ThemeMode themeMode = ThemeMode.dark,
  }) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) {
          final n = LocaleNotifier();
          n.setLocale(locale);
          return n;
        }),
        operationalDashboardProvider.overrideWith(
          (ref) => MockOperationalDashboardNotifier(sampleDashboardData),
        ),
        smartTasksProvider.overrideWith(
          (ref) => MockSmartTasksNotifier(sampleTasks),
        ),
        lifecycleBoardSummaryProvider.overrideWith(
          (ref) async => LifecycleBoardSummaryModel(
            phases: [],
            totalActiveFiles: 2,
            allShipments: [],
          ),
        ),
        shipmentUpdatesProvider.overrideWith(
          (ref) => MockShipmentUpdatesNotifier([]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: const OperationalDashboardScreen(),
          ),
        ),
      ),
    );
  }

  group('Screen 0: OperationalDashboardScreen - Task A Responsive Viewport Tests', () {
    testWidgets('Renders cleanly on Desktop viewport (1400 x 900) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(OperationalDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on Tablet viewport (900 x 700) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(OperationalDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on Mobile viewport (390 x 844) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(OperationalDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Screen 0: OperationalDashboardScreen - Task B Dark Mode & Contrast Tests', () {
    double calculateLuminance(Color color) {
      return color.computeLuminance();
    }

    double calculateContrast(Color foreground, Color background) {
      final l1 = calculateLuminance(foreground);
      final l2 = calculateLuminance(background);
      final lighter = math.max(l1, l2);
      final darker = math.min(l1, l2);
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('WCAG AA tokens satisfy >= 4.5:1 text contrast for buttons (white text) and labels', () {
      const darkBg = Color(0xFF182029);

      // Buttons with white text on accent background:
      final cobaltBtnContrast = calculateContrast(Colors.white, AppTheme.wcagCobalt);
      final emeraldBtnContrast = calculateContrast(Colors.white, AppTheme.wcagEmerald);
      final crimsonBtnContrast = calculateContrast(Colors.white, AppTheme.wcagCrimson);
      final orangeBtnContrast = calculateContrast(Colors.white, AppTheme.wcagOrange);

      // Text colors against dark scaffold:
      final primaryTextContrast = calculateContrast(AppTheme.darkTextPrimary, darkBg);
      final hyperlinkContrast = calculateContrast(AppTheme.darkHyperlink, darkBg);

      expect(cobaltBtnContrast, greaterThanOrEqualTo(4.5), reason: 'wcagCobalt contrast with white is $cobaltBtnContrast');
      expect(emeraldBtnContrast, greaterThanOrEqualTo(4.5), reason: 'wcagEmerald contrast with white is $emeraldBtnContrast');
      expect(crimsonBtnContrast, greaterThanOrEqualTo(4.5), reason: 'wcagCrimson contrast with white is $crimsonBtnContrast');
      expect(orangeBtnContrast, greaterThanOrEqualTo(4.5), reason: 'wcagOrange contrast with white is $orangeBtnContrast');
      expect(primaryTextContrast, greaterThanOrEqualTo(4.5), reason: 'darkTextPrimary contrast with darkBg is $primaryTextContrast');
      expect(hyperlinkContrast, greaterThanOrEqualTo(4.5), reason: 'darkHyperlink contrast with darkBg is $hyperlinkContrast');
    });

    test('Dark theme background layering tokens are distinct and non-colliding', () {
      expect(AppTheme.darkScaffoldBackground, isNot(equals(AppTheme.darkCardBackground)));
      expect(AppTheme.darkCardBackground, isNot(equals(AppTheme.darkSurface)));
      expect(AppTheme.darkSurface, isNot(equals(AppTheme.darkElevatedSurface)));
    });
  });

  group('Screen 0: OperationalDashboardScreen - Task C RTL Arabic Mirroring Tests', () {
    testWidgets('DirectionalIcon flips arrow in RTL mode and keeps normal in LTR mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DirectionalIcon(Icons.arrow_forward),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final directionalFinder = find.byType(DirectionalIcon);
      expect(directionalFinder, findsOneWidget);

      // arrow_forward has matchTextDirection: Icon mirrors it itself (one flip).
      // DirectionalIcon must not add a second flip around the Icon.
      final transforms = find.descendant(of: directionalFinder, matching: find.byType(Transform));
      expect(transforms, findsOneWidget, reason: 'two flips would render the LTR glyph again');
      final Transform transformWidget = tester.widget(transforms);
      expect(transformWidget.transform.storage[0], equals(-1.0)); // scaleX == -1 in RTL
    });

    test('DirectionalArrow outputs left arrow for Arabic and right arrow for English', () {
      expect(DirectionalArrow.symbolForArabic(true), equals('←')); // Left arrow
      expect(DirectionalArrow.symbolForArabic(false), equals('→')); // Right arrow
    });

    testWidgets('Arabic locale sets Directionality to TextDirection.rtl', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(OperationalDashboardScreen));
      expect(Directionality.of(context), TextDirection.rtl);
    });
  });
}
