import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/comprehensive_report/models/comprehensive_dossier_model.dart';
import 'package:frontend/features/comprehensive_report/services/comprehensive_dossier_service.dart';
import 'package:frontend/features/comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

class _MockComprehensiveDossierService extends ComprehensiveDossierService {
  final ComprehensiveShipmentDossierModel mockDossier;
  final DossierExportConfirmResponseModel mockConfirmResponse;

  _MockComprehensiveDossierService(this.mockDossier, this.mockConfirmResponse)
      : super(Dio());

  @override
  Future<ComprehensiveShipmentDossierModel> fetchComprehensiveDossier(int importFileId) async {
    return mockDossier;
  }

  @override
  Future<DossierExportConfirmResponseModel> confirmDossierExport(
      DossierExportConfirmRequestModel request) async {
    return mockConfirmResponse;
  }
}

void main() {
  final sampleSections = [
    DossierSectionSummaryModel(
      sectionCode: 'SEC-01',
      sectionNameEn: 'Purchase Orders & Specs',
      sectionNameAr: 'أوامر الشراء ومواصفات البضاعة',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'po_count': 1, 'fob_total_usd': 15000.0},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-02',
      sectionNameEn: 'Bank Financing & Form 4',
      sectionNameAr: 'التمويل المصرفي ونموذج 4',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'form4_no': 'FORM4-9981'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-03',
      sectionNameEn: 'ACID & Nafeza Single Window',
      sectionNameAr: 'النافذة الواحدة والرقم التعريفي ACID',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'acid_number': 'ACID-2026-9901'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-04',
      sectionNameEn: 'International Freight & Shipping',
      sectionNameAr: 'الشحن الدولي وتتبع الباخرة',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'bl_number': 'MAEU-88712'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-05',
      sectionNameEn: 'CargoX Blockchain Hub',
      sectionNameAr: 'التوثيق الرقمي وسلسلة الكتل CargoX',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'cargox_envelopes': 2},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-06',
      sectionNameEn: 'Customs Declaration & Inspection',
      sectionNameAr: 'الإفراج الجمركي والشهادة 46 ك.م',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'declaration_46_no': 'DEC46-98112'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-07',
      sectionNameEn: 'Inland Transport & Delivery',
      sectionNameAr: 'النقل البري الداخلي وتتبع الشاحنات',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'trips_count': 2},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-08',
      sectionNameEn: 'Warehouse Receiving & GRN',
      sectionNameAr: 'الفحص المخزني وإذن الإضافة GRN',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'grn_code': 'GRN-4420'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-09',
      sectionNameEn: 'Empty Container Return & EIR',
      sectionNameAr: 'إعادة الحاويات الفارغة وإيصالات EIR',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'eir_numbers': 'EIR-88991'},
    ),
    DossierSectionSummaryModel(
      sectionCode: 'SEC-10',
      sectionNameEn: 'Financial Settlement & Landed Cost',
      sectionNameAr: 'التكلفة الفعلية والتسوية المالية الشاملة',
      status: 'COMPLETED',
      statusAr: 'مكتمل وموثق',
      details: {'actual_landed_cost_egp': 295000.0},
    ),
  ];

  final sampleDossier = ComprehensiveShipmentDossierModel(
    importFileId: 44,
    importFileCode: 'IMP-2026-0044',
    companyName: 'شركة سرور الدولية للتوريدات',
    supplierName: 'Bavaria Chemical GmbH',
    brokerName: 'مكتب النصر للتخليص الجمركي',
    customFileNumber: 'CUST-2026-0044',
    status: 'Ready for Closure',
    currentStage: 'Stage 9: Landed Cost & File Closure',
    currentModule: 'CLO-03 Comprehensive Dossier Export',
    nextAction: 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
    progressPercent: 99.0,
    createdAt: '2026-09-18T10:00:00Z',
    updatedAt: '2026-09-18T17:00:00Z',
    shipmentMode: 'Sea FCL',
    incotermCode: 'FOB',
    shipmentCategory: 'Raw Materials',
    priority: 'High',
    totalPackages: 200,
    grossWeightKg: 5000.0,
    totalCbm: 12.5,
    totalFobFc: 15000.0,
    totalFobEgp: 750000.0,
    fobCurrency: 'USD',
    acidNumber: 'ACID-2026-9901',
    form4No: 'FORM4-9981',
    customsDeclarationNo: 'DEC46-98112',
    warehouseGrnCode: 'GRN-4420',
    emptyContainersEirNumbers: 'EIR-88991',
    actualLandedCostTotalEgp: 295000.0,
    actualLandedCostMarkupFactor: 1.18,
    actualLandedCostVarianceEgp: -5000.0,
    actualLandedCostVariancePct: -1.67,
    financialSettlementStatus: 'SETTLED',
    financialSettlementInvoicesCount: 3,
    financialSettlementTotalEgp: 45000.0,
    sections: sampleSections,
    closureReadiness: {
      'SEC-01': true,
      'SEC-02': true,
      'SEC-03': true,
      'SEC-04': true,
      'SEC-05': true,
      'SEC-06': true,
      'SEC-07': true,
      'SEC-08': true,
      'SEC-09': true,
      'SEC-10': true,
    },
  );

  final sampleConfirmResponse = DossierExportConfirmResponseModel(
    success: true,
    importFileId: 44,
    importFileCode: 'IMP-2026-0044',
    progressPercent: 99.5,
    currentStage: 'Stage 10: Import File Closure & Archival',
    currentModule: 'CLO-04 Official File Closure & Digital Archival',
    dossierExportedAt: '2026-09-18T18:00:00Z',
    dossierExportedBy: 'أحمد كمال (المراقب المالي وسلاسل الإمداد)',
    nextTaskCode: 'TSK-0904-44',
    nextTaskTitle: 'الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)',
    message: 'تم تصدير واعتماد الملف الشامل للشحنة IMP-2026-0044 بنجاح.',
  );

  final sampleFile = ImportFileModel(
    importFileId: 44,
    importFileCode: 'IMP-2026-0044',
    companyName: 'شركة سرور الدولية للتوريدات',
    supplierName: 'Bavaria Chemical GmbH',
    currentStage: 'Stage 9: Landed Cost & File Closure',
    currentModule: 'CLO-03 Comprehensive Dossier Export',
    nextAction: 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
    progressPercent: 99.0,
    createdAt: '2026-09-18T10:00:00Z',
    updatedAt: '2026-09-18T17:00:00Z',
    actualLandedCostTotalEgp: 295000.0,
    actualLandedCostMarkupFactor: 1.18,
    actualLandedCostVarianceEgp: -5000.0,
    actualLandedCostVariancePct: -1.67,
    emptyContainersEirNumbers: 'EIR-88991',
    dossierExportedAt: null,
    dossierExportedBy: null,
  );

  group('CLO-03: Models and Serialization Unit Tests', () {
    test('DossierSectionSummaryModel serialization & deserialization', () {
      final section = sampleSections.first;
      final json = section.toJson();
      final parsed = DossierSectionSummaryModel.fromJson(json);

      expect(parsed.sectionCode, equals('SEC-01'));
      expect(parsed.sectionNameAr, equals('أوامر الشراء ومواصفات البضاعة'));
      expect(parsed.status, equals('COMPLETED'));
      expect(parsed.statusAr, equals('مكتمل وموثق'));
      expect(parsed.details['po_count'], equals(1));
    });

    test('ComprehensiveShipmentDossierModel serialization & KPIs', () {
      final json = sampleDossier.toJson();
      final parsed = ComprehensiveShipmentDossierModel.fromJson(json);

      expect(parsed.importFileId, equals(44));
      expect(parsed.importFileCode, equals('IMP-2026-0044'));
      expect(parsed.sections.length, equals(10));
      expect(parsed.actualLandedCostTotalEgp, equals(295000.0));
      expect(parsed.actualLandedCostMarkupFactor, equals(1.18));
      expect(parsed.sections.last.sectionCode, equals('SEC-10'));
      expect(parsed.closureReadiness['SEC-01'], isTrue);
    });

    test('DossierExportConfirmRequest & Response models roundtrip', () {
      final req = DossierExportConfirmRequestModel(
        importFileId: 44,
        exportedBy: 'أحمد كمال (المراقب المالي وسلاسل الإمداد)',
        exportFormat: 'PDF & Excel Full Bundle',
        notes: 'مكتمل ومراجع مع إدارة المراجعة الداخلية',
      );
      final reqJson = req.toJson();
      expect(reqJson['import_file_id'], equals(44));
      expect(reqJson['exported_by'], equals('أحمد كمال (المراقب المالي وسلاسل الإمداد)'));
      expect(reqJson['export_format'], equals('PDF & Excel Full Bundle'));

      final respJson = sampleConfirmResponse.toJson();
      final parsedResp = DossierExportConfirmResponseModel.fromJson(respJson);
      expect(parsedResp.success, isTrue);
      expect(parsedResp.progressPercent, equals(99.5));
      expect(parsedResp.currentStage, contains('Stage 10'));
      expect(parsedResp.nextTaskCode, equals('TSK-0904-44'));
      expect(parsedResp.nextTaskTitle, contains('CLO-04'));
    });

    test('ImportFileModel retains dossierExportedAt and dossierExportedBy', () {
      final updatedFile = ImportFileModel(
        importFileId: sampleFile.importFileId,
        importFileCode: sampleFile.importFileCode,
        companyName: sampleFile.companyName,
        supplierName: sampleFile.supplierName,
        currentStage: 'Stage 10: Import File Closure & Archival',
        currentModule: 'CLO-04 Official File Closure',
        nextAction: 'الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)',
        createdAt: sampleFile.createdAt,
        updatedAt: '2026-09-18T18:00:00Z',
        dossierExportedAt: '2026-09-18T18:00:00Z',
        dossierExportedBy: 'أحمد كمال (المراقب المالي وسلاسل الإمداد)',
      );

      final json = updatedFile.toJson();
      expect(json['dossier_exported_at'], equals('2026-09-18T18:00:00Z'));
      expect(json['dossier_exported_by'], equals('أحمد كمال (المراقب المالي وسلاسل الإمداد)'));

      final parsed = ImportFileModel.fromJson(json);
      expect(parsed.dossierExportedAt, equals('2026-09-18T18:00:00Z'));
      expect(parsed.dossierExportedBy, equals('أحمد كمال (المراقب المالي وسلاسل الإمداد)'));
    });
  });

  group('CLO-03: ComprehensiveDossierExportDialog Widget Tests', () {
    testWidgets('Renders KPI strip, 10 sections, export buttons, and confirmation workflow',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = _MockComprehensiveDossierService(
        sampleDossier,
        sampleConfirmResponse,
      );

      Widget createTestWidget() {
        return ProviderScope(
          overrides: [
            comprehensiveDossierServiceProvider.overrideWithValue(mockService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    key: const Key('openDossierModalBtn'),
                    onPressed: () => ComprehensiveDossierExportDialog.show(
                      ctx,
                      file: sampleFile,
                    ),
                    child: const Text('Open Dossier Modal'),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.byKey(const Key('openDossierModalBtn')));
      await tester.pumpAndSettle();

      // 1. Verify Dialog Header
      expect(find.text('إصدار وتصدير التقرير والملف الشامل (CLO-03)'), findsOneWidget);
      expect(find.byKey(const Key('comprehensiveDossierCloseBtn')), findsOneWidget);

      // 2. Verify KPI Banner
      expect(find.text('قيمة البضاعة FOB'), findsOneWidget);
      expect(find.text('تكلفة الوصول الفعلية'), findsOneWidget);
      expect(find.text('الانحراف المالي'), findsOneWidget);
      expect(find.text('حالة الملف والجاهزية'), findsOneWidget);

      // 3. Verify Export Buttons Strip
      expect(find.byKey(const Key('exportDossierPdfBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportDossierExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportDossierTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyDossierClipboardBtn')), findsOneWidget);

      // 4. Verify 10-Phase Readiness Sections are listed
      expect(find.text('SEC-01: أوامر الشراء ومواصفات البضاعة'), findsOneWidget);
      expect(find.text('SEC-02: التمويل المصرفي ونموذج 4'), findsOneWidget);
      expect(find.text('SEC-03: النافذة الواحدة والرقم التعريفي ACID'), findsOneWidget);
      expect(find.text('SEC-10: التكلفة الفعلية والتسوية المالية الشاملة'), findsOneWidget);

      // 5. Verify Confirmation Form & Action Buttons
      expect(find.byKey(const Key('dossierExportFormatDropdown')), findsOneWidget);
      expect(find.byKey(const Key('dossierExportedByField')), findsOneWidget);
      expect(find.byKey(const Key('dossierExportNotesField')), findsOneWidget);
      expect(find.byKey(const Key('confirmDossierExportBtn')), findsOneWidget);

      // 6. Enter the signer (no sample name is prefilled any more), notes, and confirm export
      await tester.ensureVisible(find.byKey(const Key('dossierExportedByField')));
      await tester.enterText(find.byKey(const Key('dossierExportedByField')), 'Finance Controller');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('dossierExportNotesField')));
      await tester.enterText(
        find.byKey(const Key('dossierExportNotesField')),
        'تم تدقيق الملف الشامل بواسطة الإدارة المالية والمخزنية دون أي ملاحظات.',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('confirmDossierExportBtn')));
      await tester.tap(find.byKey(const Key('confirmDossierExportBtn')));
      await tester.pumpAndSettle();

      // 7. Verify Success SnackBar message
      expect(
        find.text('تم تصدير واعتماد الملف الشامل للشحنة IMP-2026-0044 بنجاح.'),
        findsOneWidget,
      );
    });
  });
}
