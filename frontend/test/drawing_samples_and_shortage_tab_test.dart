import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/metric_card.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/drawing_samples_and_shortage_tab.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockImportFilesNotifier extends ImportFilesNotifier {
  _MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

ImportFileModel _makeFile({
  required int id,
  required String code,
  required String supplier,
}) {
  return ImportFileModel(
    importFileId: id,
    importFileCode: code,
    companyName: 'شركة السويس للاستيراد',
    supplierName: supplier,
    shipmentMode: 'SEA',
    incotermCode: 'FOB',
    priority: 'Normal',
    shipmentCategory: 'Commercial',
    currentModule: 'Customs Clearance',
    currentStage: 'Phase 7 - Customs Clearance',
    nextAction: 'Sample Inspection',
    status: 'Open',
    createdAt: '2026-01-01',
    updatedAt: '2026-01-01',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockFiles = [
    _makeFile(id: 101, code: 'IMP-2026-0101', supplier: 'المورد الألماني'),
    _makeFile(id: 102, code: 'IMP-2026-0102', supplier: 'المورد الإيطالي'),
  ];

  final mockRecords = <CustomsClearanceModel>[
    CustomsClearanceModel(
      customsClearanceId: 1,
      clearanceCode: 'CC-1',
      importFileId: 101,
      declaration46No: 'DEC-101',
      status: 'Inspection Scheduled',
      channelType: 'YELLOW',
      inspectionType: 'Physical Examination',
      inspectionResult: 'PENDING',
      assessmentStatus: 'PENDING',
      isSampleDrawn: true,
      samplingRecordNo: 'SMP-1001',
      samplingDate: '2026-09-05',
      goeicCertificateNo: 'REC-9911',
      sampleTestStatus: 'Approved',
      labTestResult: 'CONFORMING',
      inspectionNotes: 'مطابق للمواصفات القياسية المصرية',
      sampledRegulatoryBodies: const ['GOEIC'],
      createdAt: '2026-09-05',
      updatedAt: '2026-09-05',
    ),
    CustomsClearanceModel(
      customsClearanceId: 2,
      clearanceCode: 'CC-2',
      importFileId: 102,
      declaration46No: 'DEC-102',
      status: 'Inspection Scheduled',
      channelType: 'RED',
      inspectionType: 'Physical Examination',
      inspectionResult: 'PENDING',
      assessmentStatus: 'PENDING',
      isSampleDrawn: true,
      samplingRecordNo: 'SMP-1002',
      samplingDate: '2026-09-06',
      goeicCertificateNo: 'REC-9912',
      sampleTestStatus: 'Samples Under Testing',
      labTestResult: 'PENDING',
      inspectionNotes: 'تحليل بكتيري - قيد المعايرة',
      sampledRegulatoryBodies: const ['NFSA'],
      createdAt: '2026-09-06',
      updatedAt: '2026-09-06',
    ),
  ];

  Widget buildTestWidget({
    List<CustomsClearanceModel>? records,
    Locale locale = const Locale('ar'),
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(mockFiles)),
      ],
      child: MaterialApp(
        home: AppLocalizationsProvider(
          locale: locale,
          child: Scaffold(
            body: DrawingSamplesAndShortageTab(
              records: records ?? mockRecords,
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 60: DrawingSamplesAndShortageTab Tests', () {
    testWidgets('Renders within SelectionArea and displays title and 4 export actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('سحب العينات وتتبع الفحص وعجز البضائع'), findsOneWidget);
      expect(find.text('تصدير جدول تبويب مفصول'), findsOneWidget);
      expect(find.text('تصدير جدول أكسيل'), findsOneWidget);
      expect(find.text('طباعة تقرير الفحص والعجز'), findsOneWidget);
      expect(find.text('نسخ ملف الحافظة الشامل'), findsOneWidget);
    });

    testWidgets('Displays 3 real KPI cards with proper counts and no fabricated shortage KPI', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('إجمالي العينات المسحوبة'), findsOneWidget);
      expect(find.text('عينات مطابقة للمواصفات'), findsOneWidget);
      expect(find.text('عينات قيد الفحص والتحليل'), findsOneWidget);
      // Fabricated shortage KPI must NOT be present
      expect(find.text('حالات العجز المثبتة'), findsNothing);

      final metricStrip = find.byType(MetricCardStrip);
      expect(metricStrip, findsOneWidget);
      expect(find.descendant(of: metricStrip, matching: find.text('2')), findsOneWidget); // Total
      expect(find.descendant(of: metricStrip, matching: find.text('1')), findsNWidgets(2)); // Passed & Pending
    });

    testWidgets('Displays real sample badges and resolved file codes', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Sample Record Badges
      expect(find.text('SMP-1001'), findsOneWidget);
      expect(find.text('SMP-1002'), findsOneWidget);
      expect(find.text('REC-9911'), findsOneWidget);
      expect(find.text('REC-9912'), findsOneWidget);

      // File codes resolved
      expect(find.text('IMP-2026-0101'), findsOneWidget);
      expect(find.text('IMP-2026-0102'), findsOneWidget);

      // Row summary copy buttons
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
    });

    testWidgets('Filters samples by search query', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SMP-1001'), findsOneWidget);
      expect(find.text('SMP-1002'), findsOneWidget);

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'بكتيري');
      await tester.pumpAndSettle();

      expect(find.text('SMP-1001'), findsNothing);
      expect(find.text('SMP-1002'), findsOneWidget);
    });

    testWidgets('Displays shortage empty state placeholder', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('سجل إثبات ومطابقة عجز البضائع المفرغة'), findsOneWidget);
      expect(find.text('سيتم حفظ محاضر النقص فور ربط سجل النقص بقاعدة البيانات'), findsOneWidget);
      // No Add Shortage button
      expect(find.text('إثبات محضر عجز جديد'), findsNothing);
    });

    testWidgets('Renders cleanly in English mode with 0 Arabic stacking', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Drawing Samples & Shortage Tracking'), findsOneWidget);
      expect(find.text('Export TSV'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
      expect(find.text('Print PDF Dossier'), findsOneWidget);
      expect(find.text('Copy Complete Dossier'), findsOneWidget);
      expect(find.text('Total Drawn Samples'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MetricCardStrip), matching: find.text('Compliant & Passed')),
        findsOneWidget,
      );
      expect(find.text('Pending Laboratory Analysis'), findsOneWidget);
      expect(find.text('Shortage protocols will be saved after the backend registry is added'), findsOneWidget);
    });
  });
}
