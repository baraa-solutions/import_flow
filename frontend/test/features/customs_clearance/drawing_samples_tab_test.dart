import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/metric_card.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_inspection_sampling_dialog.dart';
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
    companyName: 'Test Import Corp',
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

CustomsClearanceModel _makeRecord({
  required int id,
  required int fileId,
  required bool isSampleDrawn,
  String? samplingRecordNo,
  String sampleTestStatus = 'Samples Under Testing',
  String labTestResult = 'PENDING',
  List<String> bodies = const [],
}) {
  return CustomsClearanceModel(
    customsClearanceId: id,
    clearanceCode: 'CC-$id',
    importFileId: fileId,
    declaration46No: 'DEC-$id',
    status: 'Inspection Scheduled',
    channelType: 'YELLOW',
    inspectionType: 'Physical Examination',
    inspectionResult: 'PENDING',
    assessmentStatus: 'PENDING',
    isSampleDrawn: isSampleDrawn,
    samplingRecordNo: samplingRecordNo,
    samplingDate: '2026-10-01',
    sampleTestStatus: sampleTestStatus,
    labTestResult: labTestResult,
    sampledRegulatoryBodies: bodies,
    goeicCertificateNo: isSampleDrawn ? 'GOEIC-991' : null,
    createdAt: '2026-10-01',
    updatedAt: '2026-10-01',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeFiles = [
    _makeFile(id: 10, code: 'IMP-2026-0010', supplier: 'Delta Tech'),
    _makeFile(id: 20, code: 'IMP-2026-0020', supplier: 'Sigma Corp'),
  ];

  final record1 = _makeRecord(
    id: 1,
    fileId: 10,
    isSampleDrawn: true,
    samplingRecordNo: 'R-1',
    sampleTestStatus: 'Approved',
    labTestResult: 'CONFORMING',
    bodies: ['GOEIC'],
  );

  final record2 = _makeRecord(
    id: 2,
    fileId: 20,
    isSampleDrawn: false,
    samplingRecordNo: 'R-2',
    sampleTestStatus: 'Samples Under Testing',
    labTestResult: 'PENDING',
  );

  Widget buildTestHost({
    List<CustomsClearanceModel> records = const [],
    List<ImportFileModel> files = const [],
    Locale locale = const Locale('ar'),
    VoidCallback? onRefresh,
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(files)),
      ],
      child: MaterialApp(
        home: AppLocalizationsProvider(
          locale: locale,
          child: Scaffold(
            body: DrawingSamplesAndShortageTab(
              records: records,
              onRefresh: onRefresh,
            ),
          ),
        ),
      ),
    );
  }

  group('FE07-T03: DrawingSamplesAndShortageTab Real Data Tests', () {
    testWidgets('Pumps tab with 2 records: displays only isSampleDrawn record R-1 and total KPI 1', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestHost(
          records: [record1, record2],
          files: fakeFiles,
        ),
      );
      await tester.pumpAndSettle();

      // R-1 must be visible, R-2 (sample not drawn) must NOT appear in the samples table
      expect(find.text('R-1'), findsOneWidget);
      expect(find.text('R-2'), findsNothing);

      // Real file code must be resolved
      expect(find.text('IMP-2026-0010'), findsOneWidget);

      // Total KPI must be 1, Passed KPI 1, Pending KPI 0
      final metricStrip = find.byType(MetricCardStrip);
      expect(metricStrip, findsOneWidget);
      expect(
        find.descendant(of: metricStrip, matching: find.text('1')),
        findsNWidgets(2), // Total and Passed
      );
      expect(
        find.descendant(of: metricStrip, matching: find.text('0')),
        findsOneWidget, // Pending
      );

      // Shortage section displays the empty placeholder ccShortageNotAvailable
      expect(find.text('سيتم حفظ محاضر النقص فور ربط سجل النقص بقاعدة البيانات'), findsOneWidget);
    });

    testWidgets('Add sample button opens file picker dialog and then CustomsInspectionSamplingDialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestHost(
          records: [record1, record2],
          files: fakeFiles,
        ),
      );
      await tester.pumpAndSettle();

      final addSampleBtn = find.text('تسجيل سحب عينة');
      expect(addSampleBtn, findsOneWidget);

      await tester.tap(addSampleBtn);
      await tester.pumpAndSettle();

      // The file picker dialog should be open
      expect(find.byKey(const Key('importFilePickerDropdown')), findsOneWidget);

      // Select file 1
      await tester.tap(find.byKey(const Key('importFilePickerDropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Delta Tech').last);
      await tester.pumpAndSettle();

      // Tap Continue in file picker
      await tester.tap(find.byKey(const Key('importFilePickerContinueBtn')));
      await tester.pumpAndSettle();

      // Now CustomsInspectionSamplingDialog should be opened (NOT the old showAddSampleDialog)
      expect(find.byType(CustomsInspectionSamplingDialog), findsOneWidget);
    });

    testWidgets('Renders cleanly in English mode with correct KPI titles and shortage placeholder', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestHost(
          records: [record1],
          files: fakeFiles,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drawing Samples & Shortage Tracking'), findsOneWidget);
      expect(find.text('Total Drawn Samples'), findsOneWidget);
      expect(find.text('Shortage protocols will be saved after the backend registry is added'), findsOneWidget);
    });
  });
}
