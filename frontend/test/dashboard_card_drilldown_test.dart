import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/operational_dashboard/widgets/dashboard_card_drilldown_dialog.dart';
import 'package:frontend/features/smart_tasks/models/smart_task_model.dart';

void main() {
  group('Task E — Operational Dashboard Actionable Summary Cards & Drill-Down Tests', () {
    late List<ImportFileModel> sampleShipments;
    late List<SmartTaskModel> sampleTasks;
    const lAr = AppLocalizationsAr();
    const lEn = AppLocalizationsEn();
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    setUp(() {
      sampleShipments = [
        ImportFileModel(
          importFileId: 101,
          importFileCode: 'IMP-2026-0001',
          customFileNumber: 'PET Raw Pellets',
          companyName: 'Alpha Plastic Industries',
          supplierName: 'Sino Chemical Corp',
          brokerName: 'Al-Ameen Clearance',
          priority: 'High',
          shipmentCategory: 'Raw Materials',
          currentModule: 'Phase 2: Approvals & ACID',
          currentStage: 'STEP_04',
          nextAction: 'STEP_05',
          status: 'Under Process',
          owner: 'Ahmed Kamal',
          createdAt: '2026-09-01T10:00:00Z',
          updatedAt: '2026-09-02T10:00:00Z',
          requiredEta: '2026-09-25',
          estimatedCost: 150000.0,
          estimatedCostCurrency: 'EGP',
          form4No: '',
          acidNumber: '1234567890123456789',
          form46No: null,
          selectedScenario: 'Maersk Line / Vessel 44',
          portOfDischarge: 'Alexandria Port',
        ),
        ImportFileModel(
          importFileId: 102,
          importFileCode: 'IMP-2026-0002',
          customFileNumber: 'Industrial Machinery Spares',
          companyName: 'Modern Engineering Co',
          supplierName: 'Bavaria Heavy Tools',
          brokerName: 'Delta Brokerage',
          priority: 'Critical',
          shipmentCategory: 'Equipment',
          currentModule: 'Phase 5: Clearance & Release',
          currentStage: 'STEP_13',
          nextAction: 'STEP_14',
          status: 'Under Process',
          owner: 'Sara Hassan',
          createdAt: '2026-09-05T10:00:00Z',
          updatedAt: '2026-09-06T10:00:00Z',
          requiredEta: '2026-09-12',
          estimatedCost: 85000.0,
          estimatedCostCurrency: 'USD',
          form4No: 'F4-8899',
          form4RequestDate: '2026-09-02',
          acidNumber: null,
          form46No: null,
          selectedScenario: 'Hapag-Lloyd / Express 9',
          portOfDischarge: 'Damietta Port',
        ),
        ImportFileModel(
          importFileId: 103,
          importFileCode: 'IMP-2026-0003',
          customFileNumber: null,
          companyName: 'Delta Foods',
          supplierName: 'Anatolia Agro',
          brokerName: null,
          priority: 'Medium',
          shipmentCategory: 'Food',
          currentModule: 'Phase 10: Import File Closure',
          currentStage: 'STEP_21',
          nextAction: 'None',
          status: 'Closed',
          owner: 'Mohamed Ali',
          createdAt: '2026-08-01T10:00:00Z',
          updatedAt: '2026-08-20T10:00:00Z',
          requiredEta: null,
          estimatedCost: 0.0,
          estimatedCostCurrency: 'EGP',
          form4No: 'F4-1111',
          acidNumber: '9876543210987654321',
          form46No: '46-999',
        ),
      ];

      sampleTasks = [
        SmartTaskModel(
          taskId: 1,
          taskCode: 'TSK-001',
          title: 'Review CargoX Electronic Bills',
          taskType: 'System Generated',
          importFileId: 101,
          importFileCode: 'IMP-2026-0001',
          phaseName: 'Phase 4: CargoX & Banking',
          assignedUser: 'Ahmed Kamal',
          priority: 'High',
          reminderType: 'Document Review',
          dueDate: todayStr,
          status: 'Pending',
          isAutoClosed: false,
          isActive: true,
          createdAt: '2026-09-10T08:00:00Z',
          createdBy: 'System',
        ),
        SmartTaskModel(
          taskId: 2,
          taskCode: 'TSK-002',
          title: 'Confirm Form 4 Issuance with Bank Misr',
          taskType: 'Manual To-Do',
          importFileId: 102,
          importFileCode: 'IMP-2026-0002',
          phaseName: 'Phase 4: CargoX & Banking',
          assignedUser: 'Sara Hassan',
          priority: 'Critical',
          reminderType: 'Bank Form 4',
          dueDate: '2026-09-18',
          status: 'In Progress',
          isAutoClosed: false,
          isActive: true,
          createdAt: '2026-09-08T09:00:00Z',
          createdBy: 'Sara Hassan',
        ),
        SmartTaskModel(
          taskId: 3,
          taskCode: 'TSK-003',
          title: 'Archived historical checklist',
          taskType: 'System Generated',
          importFileId: 103,
          importFileCode: 'IMP-2026-0003',
          phaseName: 'Phase 10',
          assignedUser: 'Mohamed Ali',
          priority: 'Low',
          reminderType: 'General',
          dueDate: todayStr,
          status: 'Completed',
          isAutoClosed: true,
          isActive: true,
          createdAt: '2026-08-10T10:00:00Z',
          createdBy: 'System',
        ),
      ];
    });

    test('100% Mathematical Match: Card counts strictly equal drill-down record lengths', () {
      for (final cardType in DashboardCardType.values) {
        final records = DashboardDrillDownHelper.getRecords(
          type: cardType,
          shipments: sampleShipments,
          tasks: sampleTasks,
          isArabic: true,
          l: lAr,
        );

        // Verify count is strictly non-negative and matches exact length
        expect(records.length, greaterThanOrEqualTo(0));

        switch (cardType) {
          case DashboardCardType.todaysTasks:
            // Only 1 task is due today and not completed (TSK-001)
            expect(records.length, 1);
            expect(records.first.id, '1');
            break;

          case DashboardCardType.pendingTasks:
            // 2 tasks are pending or in progress (TSK-001 and TSK-002)
            expect(records.length, 2);
            break;

          case DashboardCardType.upcomingShipments:
            // 2 active shipments (IMP-0001 and IMP-0002, IMP-0003 is Closed)
            expect(records.length, 2);
            break;

          case DashboardCardType.arrivingThisWeek:
            // IMP-0001 has ETA, IMP-0002 has ETA and is in Phase 5
            expect(records.length, 2);
            break;

          case DashboardCardType.etaChanges:
            // 2 shipments have requiredEta set
            expect(records.length, 2);
            break;

          case DashboardCardType.waitingForPayment:
            // IMP-0001 is in Phase 2 with estimatedCost > 0 and empty form4No
            expect(records.length, 1);
            expect(records.first.shipmentCode, 'IMP-2026-0001');
            break;

          case DashboardCardType.waitingForForm4:
            // IMP-0001 has form4No == ''
            expect(records.length, 1);
            expect(records.first.shipmentCode, 'IMP-2026-0001');
            break;

          case DashboardCardType.pendingRequirements:
            // IMP-0001 missing form46No, IMP-0002 missing acidNumber & form46No
            expect(records.length, 2);
            break;

          case DashboardCardType.highPriorityAlerts:
            // IMP-0001 (High) and IMP-0002 (Critical)
            expect(records.length, 2);
            break;
        }
      }
    });

    test('Verification of What / Who / By When across all record items', () {
      for (final cardType in DashboardCardType.values) {
        final records = DashboardDrillDownHelper.getRecords(
          type: cardType,
          shipments: sampleShipments,
          tasks: sampleTasks,
          isArabic: true,
          l: lAr,
        );

        for (final record in records) {
          // WHAT must never be empty
          expect(record.title.trim().isNotEmpty, isTrue, reason: 'Record title must not be empty');
          // WHO must never be empty
          expect(record.who.trim().isNotEmpty, isTrue, reason: 'Responsible party must not be empty');
          // BY WHEN must never be empty
          expect(record.byWhen.trim().isNotEmpty, isTrue, reason: 'By when must not be empty');
          // STATUS must never be empty
          expect(record.status.trim().isNotEmpty, isTrue, reason: 'Status must not be empty');
        }
      }
    });

    test('Human-Readable Name Resolution (Task D) in Drill-Down Records', () {
      final upcoming = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.upcomingShipments,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );

      // IMP-2026-0001 has custom name 'PET Raw Pellets'
      final item1 = upcoming.firstWhere((r) => r.shipmentCode == 'IMP-2026-0001');
      expect(item1.title, contains('PET Raw Pellets'));
      expect(item1.title, contains('(IMP-2026-0001)'));

      // Next action should resolve step names to human Arabic names
      expect(item1.nextAction, isNot(contains('STEP_05')));

      // Status should resolve phase names to human Arabic names
      expect(item1.status, contains('المرحلة الثانية'));
    });

    test('Data Gaps Explicit Logging (Never hide or fabricate missing DB fields)', () {
      // 1. Today's Tasks has exact time HH:mm gap
      final todays = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.todaysTasks,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );
      expect(todays.first.dataGaps, contains(lAr.drillDownTimeDataGap));

      // 2. Pending Tasks has pending reason code gap
      final pending = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.pendingTasks,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );
      expect(pending.first.dataGaps, contains(lAr.drillDownPendingReasonDataGap));

      // 3. ETA Changes has historical ETA changes log gap
      final etaChanges = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.etaChanges,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );
      expect(etaChanges.first.dataGaps, contains(lAr.drillDownEtaChangeDataGap));

      // 4. Waiting For Payment has bank payment deadline gap
      final payments = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.waitingForPayment,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );
      expect(payments.first.dataGaps, contains(lAr.drillDownPaymentDeadlineDataGap));

      // 5. Upcoming Shipments has NO data gap (100% complete)
      final upcoming = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.upcomingShipments,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );
      expect(upcoming.first.dataGaps, isEmpty);
    });

    test('English Localization support for all 9 cards', () {
      for (final cardType in DashboardCardType.values) {
        final records = DashboardDrillDownHelper.getRecords(
          type: cardType,
          shipments: sampleShipments,
          tasks: sampleTasks,
          isArabic: false,
          l: lEn,
        );

        for (final r in records) {
          expect(r.who, isNot(contains('المسؤول')));
          expect(r.byWhen.trim().isNotEmpty, isTrue);
        }
      }
    });

    testWidgets('DashboardCardDrillDownDialog renders empty state properly when 0 records', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      DashboardCardDrillDownDialog.show(
                        context: context,
                        title: 'تنبيهات عالية الأولوية',
                        icon: Icons.warning_amber,
                        themeColor: Colors.red,
                        records: [],
                        isArabic: true,
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is open with 0 items badge
      expect(find.text('تنبيهات عالية الأولوية'), findsOneWidget);
      expect(find.text('0 عنصر'), findsOneWidget);

      // Verify empty state is displayed
      expect(find.text('لا توجد سجلات حالياً'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد سجلات حالياً'), findsNothing);
    });

    testWidgets('DashboardCardDrillDownDialog displays records with What/Who/By When and search filter', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final records = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.upcomingShipments,
        shipments: sampleShipments,
        tasks: sampleTasks,
        isArabic: true,
        l: lAr,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context);
                  return ElevatedButton(
                    onPressed: () {
                      DashboardCardDrillDownDialog.show(
                        context: context,
                        title: l.kpiUpcomingShipments,
                        icon: Icons.near_me,
                        themeColor: Colors.green,
                        records: records,
                        isArabic: true,
                      );
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify header and count badge (2 items)
      expect(find.text('2 عنصر'), findsOneWidget);

      // Verify records are present
      expect(find.textContaining('PET Raw Pellets'), findsWidgets);
      expect(find.textContaining('Industrial Machinery Spares'), findsWidgets);

      // Search filter test: type 'Industrial'
      await tester.enterText(find.byType(TextField), 'Industrial');
      await tester.pumpAndSettle();

      // Only Industrial record is shown
      expect(find.textContaining('Industrial Machinery Spares'), findsWidgets);
      expect(find.textContaining('PET Raw Pellets'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Both records visible again
      expect(find.textContaining('PET Raw Pellets'), findsWidgets);
      expect(find.textContaining('Industrial Machinery Spares'), findsWidgets);
    });

    test('Task D: todaysTasks and pendingTasks resolve human-readable names and avoid code duplicates', () {
      // Add a raw task with [IMP-2026-0004] (STEP_03) ...
      final tasksWithRaw = [
        ...sampleTasks,
        SmartTaskModel(
          taskId: 4,
          taskCode: 'TSK-004',
          title: '[IMP-2026-0001] (STEP_03) مراجعة اشتراطات الاستيراد والموافقات الرقابية',
          taskType: 'System Generated',
          importFileId: 101,
          importFileCode: 'IMP-2026-0001',
          phaseName: 'Phase 1: Planning & Studies',
          assignedUser: 'Ahmed Kamal',
          priority: 'High',
          reminderType: 'Regulatory',
          dueDate: todayStr,
          status: 'Pending',
          isAutoClosed: false,
          isActive: true,
          createdAt: '2026-09-10T08:00:00Z',
          createdBy: 'System',
        ),
      ];

      // Arabic resolution
      final recordsAr = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.todaysTasks,
        shipments: sampleShipments,
        tasks: tasksWithRaw,
        isArabic: true,
        l: lAr,
      );

      final rawItemAr = recordsAr.firstWhere((r) => r.id == '4');
      // 1. Title cleaned of [IMP-2026-0001] and (STEP_03)
      expect(rawItemAr.title, 'مراجعة اشتراطات الاستيراد والموافقات الرقابية');
      expect(rawItemAr.title, isNot(contains('[IMP-2026-0001]')));
      expect(rawItemAr.title, isNot(contains('STEP_03')));

      // 2. Subtitle has localized task type
      expect(rawItemAr.subtitle, 'توليد آلي من النظام');

      // 3. Status has localized status
      expect(rawItemAr.status, 'معلقة');

      // 4. Shipment title resolved cleanly
      expect(rawItemAr.shipmentTitle, 'PET Raw Pellets');

      // 5. Badge format has no duplicate code: "PET Raw Pellets (IMP-2026-0001)"
      final badgeStr = DashboardCardDrillDownDialog.formatBadgeShipment(rawItemAr);
      expect(badgeStr, 'PET Raw Pellets (IMP-2026-0001)');
      expect(badgeStr, isNot(contains('(IMP-2026-0001) (IMP-2026-0001)')));

      // English resolution
      final recordsEn = DashboardDrillDownHelper.getRecords(
        type: DashboardCardType.todaysTasks,
        shipments: sampleShipments,
        tasks: tasksWithRaw,
        isArabic: false,
        l: lEn,
      );

      final rawItemEn = recordsEn.firstWhere((r) => r.id == '4');
      expect(rawItemEn.title, 'Review Import Requirements & Regulatory Approvals');
      expect(rawItemEn.subtitle, 'System Generated');
      expect(rawItemEn.status, 'Pending');
    });

    test('Task D: formatBadgeShipment never duplicates code when custom name is absent or equals code', () {
      final itemNoCustom = DrillDownItem(
        id: '1',
        title: 'Task 1',
        who: 'Owner',
        byWhen: 'Today',
        status: 'Open',
        shipmentCode: 'IMP-2026-0003',
        shipmentTitle: 'IMP-2026-0003',
      );
      expect(DashboardCardDrillDownDialog.formatBadgeShipment(itemNoCustom), 'IMP-2026-0003');

      final itemNullTitle = DrillDownItem(
        id: '2',
        title: 'Task 2',
        who: 'Owner',
        byWhen: 'Today',
        status: 'Open',
        shipmentCode: 'IMP-2026-0003',
        shipmentTitle: null,
      );
      expect(DashboardCardDrillDownDialog.formatBadgeShipment(itemNullTitle), 'IMP-2026-0003');

      final itemAlreadyContains = DrillDownItem(
        id: '3',
        title: 'Task 3',
        who: 'Owner',
        byWhen: 'Today',
        status: 'Open',
        shipmentCode: 'IMP-2026-0001',
        shipmentTitle: 'PET Raw Pellets (IMP-2026-0001)',
      );
      expect(DashboardCardDrillDownDialog.formatBadgeShipment(itemAlreadyContains), 'PET Raw Pellets (IMP-2026-0001)');
    });
  });
}

