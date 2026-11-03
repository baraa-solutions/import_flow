import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/file_closure/models/file_closure_model.dart';
import 'package:frontend/features/file_closure/providers/file_closure_provider.dart';
import 'package:frontend/features/file_closure/widgets/official_file_closure_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

class _MockFileClosureNotifier extends FileClosureNotifier {
  final ClosurePrecheckResponseModel mockPrecheck;
  final OfficialClosureCertificateResponseModel mockCertificate;
  bool officialCloseCalled = false;
  Map<String, dynamic>? lastPayload;

  _MockFileClosureNotifier({
    required this.mockPrecheck,
    required this.mockCertificate,
  }) : super(Dio());

  @override
  Future<ClosurePrecheckResponseModel> fetchClosurePrecheck(int importFileId) async {
    return mockPrecheck;
  }

  @override
  Future<OfficialClosureCertificateResponseModel> officialCloseImportFile(
    Map<String, dynamic> payload,
  ) async {
    officialCloseCalled = true;
    lastPayload = payload;
    return mockCertificate;
  }
}

void main() {
  final samplePrecheckPass = ClosurePrecheckResponseModel(
    importFileId: 46,
    importFileCode: 'IMP-2026-0046',
    companyName: 'Sorour Import & Export Co.',
    supplierName: 'Hamburg Tools GmbH',
    canClose: true,
    blockingReasons: [],
    warnings: ['يرجى مراجعة إيصال تسليم الحاويات قبل الأرشفة.'],
    checklistStatus: {
      'docs_verified': true,
      'customs_cleared': true,
      'warehouse_received': true,
      'landed_cost_settled': true,
      'dossier_exported': true,
      'empty_containers_returned': true,
      'tasks_closed': true,
    },
    actualLandedCostEgp: 654000.0,
    actualMarkupFactor: 1.345,
    dossierExportedAt: '2026-09-18T18:30:00Z',
    dossierExportedBy: 'Finance Controller',
    emptyContainersReturnedAt: '2026-09-18T17:00:00Z',
    certificateCodePreview: 'CLR-2026-0046',
  );

  final samplePrecheckBlocked = ClosurePrecheckResponseModel(
    importFileId: 46,
    importFileCode: 'IMP-2026-0046',
    companyName: 'Sorour Import & Export Co.',
    supplierName: 'Hamburg Tools GmbH',
    canClose: false,
    blockingReasons: [
      'لم يتم استخراج الإفراج الجمركي النهائي للرسالة (Customs Final Release Permit).',
      'لم يتم تسجيل استلام الشحنة بالمخزن وإصدار إذن إضافة (Warehouse GRN).',
      'لم يتم احتساب واعتماد تسوية التكلفة الاستيرادية الشاملة (Actual Landed Cost Settled).',
      'لم يتم تصدير واعتماد الملف الشامل للرسالة (Comprehensive Shipment Dossier Export - CLO-03).',
    ],
    warnings: [],
    checklistStatus: {
      'docs_verified': true,
      'customs_cleared': false,
      'warehouse_received': false,
      'landed_cost_settled': false,
      'dossier_exported': false,
      'empty_containers_returned': false,
      'tasks_closed': true,
    },
    actualLandedCostEgp: 0.0,
    actualMarkupFactor: 1.0,
    certificateCodePreview: 'CLR-2026-0046',
  );

  final sampleCertificate = OfficialClosureCertificateResponseModel(
    success: true,
    closureId: 101,
    closureCode: 'CLR-2026-0046',
    importFileId: 46,
    importFileCode: 'IMP-2026-0046',
    companyName: 'Sorour Import & Export Co.',
    supplierName: 'Hamburg Tools GmbH',
    auditorName: 'Kamal (Internal Auditor)',
    archiveLocation: 'Central Secure Digital Archive Vault - 2026/Volume-A',
    archivalNotes: 'Verified and ready for closing',
    closedAt: '2026-09-18T19:00:00Z',
    status: 'Closed',
    progressPercent: 100.0,
    currentStage: 'Archived & Closed (Certificate: CLR-2026-0046)',
    currentModule: 'Phase 10 - Import File Closure & Historical Archive',
    nextAction: 'File Archived - Read-Only Historical State',
    message: 'تم إغلاق الملف الاستيرادي IMP-2026-0046 رسمياً بنجاح بنسبة إنجاز 100%.',
  );

  final sampleFile = ImportFileModel(
    importFileId: 46,
    importFileCode: 'IMP-2026-0046',
    companyName: 'Sorour Import & Export Co.',
    supplierName: 'Hamburg Tools GmbH',
    status: 'Ready for Closure',
    currentStage: 'Stage 10: Import File Closure & Archival',
    currentModule: 'Phase 10 - Comprehensive Dossier Export & Digital Archiving',
    nextAction: 'الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)',
    progressPercent: 99.5,
    createdAt: '2026-09-18T10:00:00Z',
    updatedAt: '2026-09-18T18:00:00Z',
    shipmentMode: 'Sea FCL',
    incotermCode: 'FOB',
    shipmentCategory: 'Finished Products',
    priority: 'High',
  );

  group('CLO-04 Models Unit Tests', () {
    test('ClosurePrecheckResponseModel parses successfully from JSON', () {
      final json = {
        'import_file_id': 46,
        'import_file_code': 'IMP-2026-0046',
        'company_name': 'Sorour Co.',
        'supplier_name': 'Hamburg GmbH',
        'can_close': true,
        'blocking_reasons': ['Missing customs'],
        'warnings': ['Missing EIR'],
        'checklist_status': {'customs_cleared': true, 'warehouse_received': false},
        'actual_landed_cost_egp': 540000.0,
        'actual_markup_factor': 1.25,
        'dossier_exported_at': '2026-09-18T12:00:00Z',
        'dossier_exported_by': 'Auditor A',
        'empty_containers_returned_at': null,
        'certificate_code_preview': 'CLR-2026-0046',
      };

      final model = ClosurePrecheckResponseModel.fromJson(json);
      expect(model.importFileId, 46);
      expect(model.canClose, true);
      expect(model.blockingReasons.length, 1);
      expect(model.warnings.length, 1);
      expect(model.checklistStatus['customs_cleared'], true);
      expect(model.checklistStatus['warehouse_received'], false);
      expect(model.actualLandedCostEgp, 540000.0);
      expect(model.actualMarkupFactor, 1.25);
      expect(model.certificateCodePreview, 'CLR-2026-0046');
    });

    test('OfficialClosureCertificateResponseModel parses successfully from JSON', () {
      final json = {
        'success': true,
        'closure_id': 88,
        'closure_code': 'CLR-2026-0088',
        'import_file_id': 46,
        'import_file_code': 'IMP-2026-0046',
        'company_name': 'Sorour Co.',
        'supplier_name': 'Hamburg GmbH',
        'auditor_name': 'Kamal',
        'archive_location': 'Digital Vault',
        'archival_notes': 'Archived successfully',
        'closed_at': '2026-09-18T18:00:00Z',
        'status': 'Closed',
        'progress_percent': 100.0,
        'current_stage': 'Archived & Closed',
        'current_module': 'Phase 10',
        'next_action': 'File Archived',
        'message': 'Closed OK',
      };

      final model = OfficialClosureCertificateResponseModel.fromJson(json);
      expect(model.success, true);
      expect(model.closureCode, 'CLR-2026-0088');
      expect(model.progressPercent, 100.0);
      expect(model.status, 'Closed');
      expect(model.auditorName, 'Kamal');
    });
  });

  group('CLO-04 OfficialFileClosureDialog Widget Tests', () {
    testWidgets('Displays 6-pillar audit badges, certificate preview, and allows closure when canClose=true', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockNotifier = _MockFileClosureNotifier(
        mockPrecheck: samplePrecheckPass,
        mockCertificate: sampleCertificate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileClosureProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OfficialFileClosureDialog(file: sampleFile),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Title & Subtitle
      expect(find.text('الإغلاق الرسمي والأرشفة الرقمية (CLO-04)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0046'), findsWidgets);

      // Verify 6 Pillars
      expect(find.text('1. الإفراج الجمركي'), findsOneWidget);
      expect(find.text('2. إذن إضافة المخزن'), findsOneWidget);
      expect(find.text('3. تسوية التكلفة الفعلية'), findsOneWidget);
      expect(find.text('4. تصدير الملف الشامل'), findsOneWidget);
      expect(find.text('5. تسليم الحاويات للخط الملاحي'), findsOneWidget);
      expect(find.text('6. إغلاق المهام'), findsOneWidget);

      // Verify Certificate Preview
      expect(find.text('CLR-2026-0046'), findsOneWidget);
      // The certificate can only be exported AFTER the server closed the file (plan FE-07):
      // the pre-close view never offers it.
      expect(find.byKey(const Key('exportClosureCertificateBtn')), findsNothing);

      // Verify Form fields
      expect(find.byKey(const Key('closureAuditorNameField')), findsOneWidget);
      expect(find.byKey(const Key('closureArchiveLocationField')), findsOneWidget);

      // Verify Confirm Button is active
      final confirmBtn = find.byKey(const Key('confirmOfficialClosureBtn'));
      expect(confirmBtn, findsOneWidget);

      // No fabricated defaults any more (plan FE-08): the user supplies the real auditor and vault.
      await tester.enterText(find.byKey(const Key('closureAuditorNameField')), 'Kamal');
      await tester.enterText(find.byKey(const Key('closureArchiveLocationField')), 'Digital Vault A-1');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify officialClose was called
      expect(mockNotifier.officialCloseCalled, true);
      expect(mockNotifier.lastPayload?['import_file_id'], 46);
      expect(mockNotifier.lastPayload?['is_draft'], false);

      // The dialog switched to the closed view: certificate export + lesson are offered now.
      expect(find.byKey(const Key('exportClosureCertificateBtn')), findsOneWidget);
      expect(find.byKey(const Key('closureDoneBtn')), findsOneWidget);
    });

    testWidgets('Disables confirm button and shows red alert box when canClose=false', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockNotifier = _MockFileClosureNotifier(
        mockPrecheck: samplePrecheckBlocked,
        mockCertificate: sampleCertificate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileClosureProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OfficialFileClosureDialog(file: sampleFile),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Blocking Box
      expect(find.text('متطلبات إغلاق إلزامية معلقة (يجب استيفاؤها أولاً):'), findsOneWidget);
      expect(find.textContaining('لم يتم استخراج الإفراج الجمركي'), findsOneWidget);

      // Confirm button disabled
      final confirmBtnFinder = find.byKey(const Key('confirmOfficialClosureBtn'));
      expect(confirmBtnFinder, findsOneWidget);
      final AppButton btn = tester.widget(confirmBtnFinder);
      expect(btn.onPressed, isNull);
    });
  });
}
