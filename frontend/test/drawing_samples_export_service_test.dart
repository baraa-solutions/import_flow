import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/services/drawing_samples_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrawingSamplesExportService Tests', () {
    final mockSamples = [
      CustomsClearanceModel(
        customsClearanceId: 1,
        clearanceCode: 'CC-001',
        importFileId: 101,
        samplingRecordNo: 'SMP-001',
        sampledRegulatoryBodies: ['GOEIC'],
        samplingDate: '2026-09-01',
        goeicCertificateNo: 'RCP-9821',
        sampleTestStatus: 'Approved',
        labTestResult: 'PASSED',
        inspectionNotes: 'مطابق تماماً للمواصفة القياسية المصرية',
        createdAt: '2026-09-01T10:00:00',
        updatedAt: '2026-09-01T10:00:00',
      ),
      CustomsClearanceModel(
        customsClearanceId: 2,
        clearanceCode: 'CC-002',
        importFileId: 102,
        samplingRecordNo: 'SMP-002',
        sampledRegulatoryBodies: ['NFSA'],
        samplingDate: '2026-09-02',
        goeicCertificateNo: 'RCP-9822',
        sampleTestStatus: 'Pending',
        labTestResult: 'PENDING',
        inspectionNotes: 'بانتظار ظهور نتيجة الزرع',
        createdAt: '2026-09-02T10:00:00',
        updatedAt: '2026-09-02T10:00:00',
      ),
    ];

    final mockShortages = [
      {
        'shortage_id': 'SHR-001',
        'container_no': 'MSCU-1234567',
        'item_desc': 'محركات كهربائية صناعية',
        'manifest_qty': '100',
        'landed_qty': '96',
        'shortage_qty': '4',
        'shortage_pct': '4.0',
        'action': 'DEDUCT_DUTY',
        'notes': 'تم إثبات كسر قفل الحاوية وسقوط 4 طرود بالميناء',
      },
      {
        'shortage_id': 'SHR-002',
        'container_no': 'TGHU-7654321',
        'item_desc': 'صمامات ضغط هيدروليكية',
        'manifest_qty': '50',
        'landed_qty': '48',
        'shortage_qty': '2',
        'shortage_pct': '4.0',
        'action': 'CARRIER_CLAIM',
        'notes': 'مطالبة التوكيل الملاحي',
      },
    ];

    testWidgets('exportSamplesToTsv outputs UTF-8 BOM and correct headers and rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final tsv = DrawingSamplesExportService.exportSamplesToTsv(context, mockSamples);

      expect(tsv.startsWith('\uFEFF'), isTrue);
      expect(tsv.contains('SMP-001'), isTrue);
      expect(tsv.contains('RCP-9821'), isTrue);
      expect(tsv.contains('SMP-002'), isTrue);
      expect(tsv.contains('\t'), isTrue);
    });

    testWidgets('exportShortagesToTsv outputs UTF-8 BOM and shortage entries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final tsv = DrawingSamplesExportService.exportShortagesToTsv(context, mockShortages);

      expect(tsv.startsWith('\uFEFF'), isTrue);
      expect(tsv.contains('SHR-001'), isTrue);
      expect(tsv.contains('MSCU-1234567'), isTrue);
      expect(tsv.contains('4.0%'), isTrue);
      expect(tsv.contains('\t'), isTrue);
    });

    testWidgets('exportSamplesToCsv outputs UTF-8 BOM and CSV structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('en'),
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final csv = DrawingSamplesExportService.exportSamplesToCsv(context, mockSamples);

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('Sample ID'), isTrue);
      expect(csv.contains('SMP-001'), isTrue);
      expect(csv.contains(','), isTrue);
    });

    testWidgets('exportShortagesToCsv outputs UTF-8 BOM and CSV structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('en'),
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final csv = DrawingSamplesExportService.exportShortagesToCsv(context, mockShortages);

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('Protocol ID'), isTrue);
      expect(csv.contains('SHR-001'), isTrue);
      expect(csv.contains(','), isTrue);
    });

    testWidgets('buildDrawingSamplesDossier generates formatted comprehensive dossier', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final dossier = DrawingSamplesExportService.buildDrawingSamplesDossier(
        context: context,
        samples: mockSamples,
        shortages: mockShortages,
      );

      expect(dossier.contains('IMPORTFLOW ERP'), isTrue);
      expect(dossier.contains('SMP-001'), isTrue);
      expect(dossier.contains('SHR-001'), isTrue);
      expect(dossier.contains('MSCU-1234567'), isTrue);
    });
  });
}
