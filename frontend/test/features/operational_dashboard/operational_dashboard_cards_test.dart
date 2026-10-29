import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/operational_dashboard/widgets/operational_dashboard_widgets.dart';
import 'package:frontend/features/shipment_updates/models/shipment_update_model.dart';
import 'package:frontend/features/smart_tasks/models/smart_task_model.dart';

Widget _buildTestable(Widget child) {
  return MaterialApp(
    home: AppLocalizationsProvider(
      locale: const Locale('ar'),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('Operational Dashboard Decoupled Widgets Unit/Widget Tests', () {
    testWidgets('OperationalKpiCard renders metric and responds to click', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildTestable(
          OperationalKpiCard(
            density: DisplayDensityMode.comfortable,
            title: 'إجمالي الشحنات النشطة',
            mainValue: '42',
            subtitle: 'جميع المراحل قيد التشغيل',
            icon: Icons.local_shipping,
            color: Colors.blue,
            onTap: () => tapped = true,
            clickHint: 'انقر للتفاصيل',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إجمالي الشحنات النشطة'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('جميع المراحل قيد التشغيل'), findsOneWidget);

      await tester.tap(find.text('إجمالي الشحنات النشطة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tapped, isTrue);
    });

    testWidgets('OperationalPriorityBadge renders correctly for different priority levels', (tester) async {
      await tester.pumpWidget(
        _buildTestable(
          const Column(
            children: [
              OperationalPriorityBadge(priority: 'Critical'),
              OperationalPriorityBadge(priority: 'High'),
              OperationalPriorityBadge(priority: 'Medium'),
              OperationalPriorityBadge(priority: 'Low'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationalPriorityBadge), findsNWidgets(4));
    });

    testWidgets('OperationalNextStepCard renders next step and triggers navigation callback', (tester) async {
      int? navigatedIndex;
      final shipment = ImportFileModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-001',
        companyName: 'شركة النيل للتجارة',
        supplierName: 'Shanghai Global Tech',
        currentModule: 'STEP_01',
        currentStage: 'Customs Studies',
        nextAction: 'الدراسات والاستشارات الجمركية',
        status: 'Active',
        priority: 'High',
        progressPercent: 15.0,
        createdAt: '2026-08-01',
        updatedAt: '2026-08-01',
      );

      await tester.pumpWidget(
        _buildTestable(
          OperationalNextStepCard(
            shipment: shipment,
            isArabic: true,
            onNavigate: (index) => navigatedIndex = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationalNextStepCard), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(23));
    });

    testWidgets('OperationalDailyCheckinsCard renders recent updates and triggers add callback', (tester) async {
      bool addTapped = false;
      final dummyLog = ShipmentUpdateLogModel(
        updateId: 1,
        updateCode: 'LOG-001',
        importFileId: 101,
        importFileCode: 'IMP-2026-001',
        updateCategory: 'Daily Check-in',
        targetPhase: 'Phase 1',
        phaseStatus: 'Current',
        logDate: '2026-10-29',
        note: 'تم الانتهاء من مراجعة بنود الفاتورة',
        previousCost: 0,
        newCost: 0,
        alertPriority: 'Normal',
        assignedUser: 'Admin',
        isActive: true,
        createdAt: '2026-10-29T00:00:00Z',
        createdBy: 'Admin',
      );

      await tester.pumpWidget(
        _buildTestable(
          OperationalDailyCheckinsCard(
            shipments: const [],
            logs: [dummyLog],
            isArabic: true,
            onAddDailyUpdate: () => addTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم الانتهاء من مراجعة بنود الفاتورة'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(addTapped, isTrue);
    });

    testWidgets('OperationalRiskAlertsBanner renders pending compliance and critical alerts', (tester) async {
      final criticalShipment = ImportFileModel(
        importFileId: 102,
        importFileCode: 'IMP-CRIT-999',
        companyName: 'دلتا لوجستيك',
        supplierName: 'Euro Logistics',
        currentModule: 'STEP_05',
        currentStage: 'ACID Issue',
        nextAction: 'إصدار رقم نافذة',
        status: 'Active',
        priority: 'Critical',
        progressPercent: 30.0,
        createdAt: '2026-08-01',
        updatedAt: '2026-08-01',
      );

      final complianceTask = SmartTaskModel(
        taskId: 50,
        taskCode: 'TSK-050',
        title: 'مراجعة موافقة هيئة الدواء المصرية',
        importFileId: 102,
        importFileCode: 'IMP-CRIT-999',
        taskType: 'Regulatory Compliance',
        phaseName: 'STEP_03',
        priority: 'Critical',
        assignedUser: 'Admin',
        reminderType: 'General Reminder',
        status: 'Pending',
        isAutoClosed: false,
        isActive: true,
        createdAt: '2026-08-01',
        createdBy: 'Admin',
      );

      await tester.pumpWidget(
        _buildTestable(
          OperationalRiskAlertsBanner(
            shipments: [criticalShipment],
            regTasks: [complianceTask],
            isArabic: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مراجعة موافقة هيئة الدواء المصرية'), findsOneWidget);
    });

    testWidgets('OperationalQuickActionsBar triggers correct navigation index', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(
        _buildTestable(
          OperationalQuickActionsBar(
            onNavigate: (index) => selectedIndex = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationalQuickActionButton), findsWidgets);
      // Tap the first shortcut (Projects -> 31)
      await tester.tap(find.byType(OperationalQuickActionButton).first);
      expect(selectedIndex, equals(31));
    });

    testWidgets('OperationalLifecycleBoardSummaryCard toggles phase filters', (tester) async {
      String? toggledPhase;
      final dummySummary = LifecycleBoardSummaryModel(
        phases: [
          PhaseSummaryModel(
            phaseId: 1,
            titleAr: 'المرحلة 1: التخطيط والدراسات',
            titleEn: 'Phase 1: Planning & Studies',
            colorHex: '#2980B9',
            stepCodes: ['STEP_01', 'STEP_02'],
            totalActiveShipments: 5,
            stepCounts: {'STEP_01': 2, 'STEP_02': 3},
          ),
        ],
        totalActiveFiles: 5,
        allShipments: [],
      );

      await tester.pumpWidget(
        _buildTestable(
          OperationalLifecycleBoardSummaryCard(
            boardData: dummySummary,
            isArabic: true,
            onTogglePhase: (phase) => toggledPhase = phase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationalLifecycleBoardSummaryCard), findsOneWidget);
      // Tap on Phase 1 header
      await tester.tap(find.text('المرحلة 1: التخطيط والدراسات'));
      expect(toggledPhase, equals('Phase 1'));
    });

    testWidgets('OperationalShipmentCard renders shipment info and triggers actions', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool dailyUpdateTapped = false;
      final shipment = ImportFileModel(
        importFileId: 201,
        importFileCode: 'IMP-2026-CARD',
        companyName: 'النيل للتوزيع',
        supplierName: 'Global Exporter',
        currentModule: 'STEP_07',
        currentStage: 'Container Allocation',
        nextAction: 'تخصيص الحاويات',
        status: 'Active',
        priority: 'High',
        progressPercent: 65.0,
        createdAt: '2026-08-01',
        updatedAt: '2026-08-01',
      );

      await tester.pumpWidget(
        _buildTestable(
          OperationalShipmentCard(
            shipment: shipment,
            isArabic: true,
            onRecordDailyUpdate: () => dailyUpdateTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OperationalShipmentCard), findsOneWidget);
      expect(find.text('IMP-2026-CARD'), findsWidgets);
      expect(find.text('النيل للتوزيع'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.post_add_rounded));
      await tester.pumpAndSettle();
      expect(dailyUpdateTapped, isTrue);
    });
  });
}
