import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/widgets/shipment_milestone_tracker.dart';

void main() {
  Widget createTestWidget({required ImportFileModel importFile, Locale locale = const Locale('ar')}) {
    return MaterialApp(
      locale: locale,
      home: AppLocalizationsProvider(
        locale: locale,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ShipmentMilestoneTracker(importFile: importFile),
          ),
        ),
      ),
    );
  }

  ImportFileModel createMockImportFile({
    int id = 4,
    String code = 'IMP-2026-0004',
    String customFileNumber = 'PET Stock',
    String currentModule = 'STEP_07 تخصيص وتوزيع الحاويات والـ VGM',
    String currentStage = 'Phase 3: Booking & Doc Prep',
    String nextAction = 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن',
    double progressPercent = 33.3,
    String? acidNumber = '5281534391023010013',
    String? swiftNo = 'FT/26228/KZ70Q',
    String? selectedScenario = 'Wan Hai Lines Ltd. (WAN HAI 511)',
    String status = 'Open',
    bool isCustomsReleased = false,
    String? form46No,
  }) {
    return ImportFileModel(
      importFileId: id,
      importFileCode: code,
      customFileNumber: customFileNumber,
      companyName: 'SCAS FOR CONSTRUCTION AND FINISHING',
      supplierName: 'SUZHOU YUHENG TEXTILE CO.,LTD',
      priority: 'High',
      shipmentCategory: 'Raw Materials',
      currentModule: currentModule,
      currentStage: currentStage,
      nextAction: nextAction,
      progressPercent: progressPercent,
      acidNumber: acidNumber,
      swiftNo: swiftNo,
      selectedScenario: selectedScenario,
      status: status,
      isCustomsReleased: isCustomsReleased,
      form46No: form46No,
      owner: 'Ahmed Salah',
      createdAt: '2026-08-18T10:00:00Z',
      updatedAt: '2026-09-14T10:00:00Z',
      estimatedCost: 43704.0,
      estimatedCostCurrency: 'USD',
    );
  }

  group('ShipmentMilestoneTracker Widget Tests', () {
    testWidgets('Milestone correctly shows Phase 4 (Shipment Booking) when on STEP_07', (tester) async {
      final file = createMockImportFile();

      await tester.pumpWidget(createTestWidget(importFile: file, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('PET Stock'), findsWidgets);
      expect(find.textContaining('33%'), findsOneWidget);
      expect(find.text('حجز الشحنة'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(3));
    });

    testWidgets('Milestone auto-advances to Phase 4 when ACID is issued even if stage was STEP_05', (tester) async {
      final file = createMockImportFile(
        currentModule: 'STEP_05 إصدار رقم ACID نافذة',
        currentStage: 'Phase 2: Approvals & ACID',
        nextAction: 'طلب واستخراج رقم ACID',
        acidNumber: '5281534391023010013',
      );

      await tester.pumpWidget(createTestWidget(importFile: file, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNWidgets(3));
      expect(find.text('حجز الشحنة'), findsOneWidget);
    });

    testWidgets('Closed shipment marks all phases as completed (10 check icons)', (tester) async {
      final file = createMockImportFile(
        status: 'Closed',
        progressPercent: 100.0,
      );

      await tester.pumpWidget(createTestWidget(importFile: file, locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Closed & Archived'), findsOneWidget);
      expect(find.text('Shipment Booking'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(10));
    });

    testWidgets('English localization renders correctly without Arabic text', (tester) async {
      final file = createMockImportFile();

      await tester.pumpWidget(createTestWidget(importFile: file, locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Operational Progress Milestone:'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
      expect(find.text('Shipment Booking'), findsOneWidget);
    });

    testWidgets('Mini Quick-Facts Bar displays volume, gross weight, and carrier correctly', (tester) async {
      final file = createMockImportFile();

      await tester.pumpWidget(createTestWidget(importFile: file, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('66.39 m³'), findsOneWidget);
      expect(find.textContaining('10,510 كجم'), findsOneWidget);
      expect(find.text('Wan Hai'), findsOneWidget);
    });

    testWidgets('Knowledge Gate alert displays for acoustic cargo and can be acknowledged', (tester) async {
      final file = createMockImportFile(
        customFileNumber: 'PET Acoustic Panels Stock',
      );

      bool acknowledged = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Scaffold(
              body: ShipmentMilestoneTracker(
                importFile: file,
                onKnowledgeGateAcknowledged: () {
                  acknowledged = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بوابة المعرفة والإنذار التشغيلي'), findsOneWidget);
      expect(find.textContaining('ميناء الوصول يجب أن يكون الإسكندرية حصراً'), findsOneWidget);
      expect(find.textContaining('شهادة المنشأ'), findsWidgets);

      // Tap acknowledge button
      final ackBtn = find.text('إقرار واطلاع قبل المتابعة');
      expect(ackBtn, findsOneWidget);
      await tester.tap(ackBtn);
      await tester.pumpAndSettle();

      expect(acknowledged, isTrue);
      expect(find.textContaining('تم الإقرار والالتزام باشتراطات ميناء الإسكندرية وشهادة المنشأ'), findsOneWidget);
    });
  });
}
