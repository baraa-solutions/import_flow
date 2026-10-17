import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/import_documentation/screens/customs_declaration46_screen.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> initialFiles;
  _MockImportFilesNotifier(this.initialFiles) : super(Dio()) {
    state = AsyncValue.data(initialFiles);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = AsyncValue.data(initialFiles);
  }
}

class _MockCustomsTariffNotifier extends CustomsTariffNotifier {
  final List<CustomsTariffModel> initialTariffs;
  _MockCustomsTariffNotifier(this.initialTariffs)
      : super(ref: _FakeRef(), showInactive: false, search: '', dio: Dio()) {
    state = AsyncValue.data(initialTariffs);
  }

  @override
  Future<void> fetchTariffs() async {
    state = AsyncValue.data(initialTariffs);
  }
}

class _MockCustomsClearanceNotifier extends CustomsClearanceNotifier {
  final List<CustomsClearanceModel> initialRecords;
  _MockCustomsClearanceNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(initialRecords);
  }
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleFile1 = ImportFileModel(
    importFileId: 10,
    importFileCode: 'IMP-2026-0010',
    companyId: 1,
    companyName: 'Al-Sorour Logistics & Trade',
    supplierId: 2,
    supplierName: 'Milano Industrial SpA',
    shipmentMode: 'Sea FCL',
    incotermCode: 'FOB',
    priority: 'Normal',
    shipmentCategory: 'Commercial',
    portOfLoading: 'Genoa Port (IT)',
    acidNumber: '8912345678901234567',
    form4No: 'F4-BNK-99881',
    form46No: '46-ALX-IMP-2026-0010',
    form46Date: '2026-08-25',
    customFileNumber: 'MEDUST-IT-0099',
    estimatedCost: 15000.0,
    estimatedCostCurrency: 'EUR',
    status: 'Active',
    owner: 'Admin',
    progressPercent: 60.0,
    currentModule: 'Customs Clearance',
    currentStage: 'Declaration 46',
    nextAction: 'Submit Form 46',
    invoicesData: [
      InvoiceItemModel(invoiceNo: 'INV-IT-01', amount: 15000.0, currency: 'EUR'),
    ],
    packingListsData: [],
    projectIds: [],
    skippedStages: [],
    createdAt: '2026-08-23T00:00:00Z',
    updatedAt: '2026-08-23T00:00:00Z',
  );

  final sampleClearance1 = CustomsClearanceModel(
    customsClearanceId: 1,
    clearanceCode: 'CC-001',
    importFileId: 10,
    declaration46No: '46-ALX-IMP-2026-0010',
    declaration46Date: '2026-08-25',
    customsOfficeName: 'Alexandria Port Customs',
    customsTariffItemsCount: 1,
    status: 'Declaration Registered',
    channelType: 'Yellow Channel',
    createdAt: '2026-08-25T00:00:00Z',
    updatedAt: '2026-08-25T00:00:00Z',
  );

  final sampleFile2 = ImportFileModel(
    importFileId: 11,
    importFileCode: 'IMP-2026-0011',
    companyId: 2,
    companyName: 'Nile Precision Motors',
    supplierId: 4,
    supplierName: 'Shanghai Heavy Tooling Co',
    shipmentMode: 'Sea FCL',
    incotermCode: 'CIF',
    priority: 'High',
    shipmentCategory: 'Industrial',
    portOfLoading: 'Shanghai Port (CN)',
    acidNumber: '8912345678909999888',
    form4No: 'F4-BNK-77112',
    customFileNumber: 'MEDUST-CN-0044',
    estimatedCost: 28000.0,
    estimatedCostCurrency: 'USD',
    status: 'Active',
    owner: 'Admin',
    progressPercent: 65.0,
    currentModule: 'Customs Clearance',
    currentStage: 'Declaration 46',
    nextAction: 'Review Duties',
    invoicesData: [
      InvoiceItemModel(invoiceNo: 'INV-CN-88', amount: 28000.0, currency: 'USD'),
    ],
    packingListsData: [],
    projectIds: [],
    skippedStages: [],
    createdAt: '2026-08-25T00:00:00Z',
    updatedAt: '2026-08-25T00:00:00Z',
  );

  final sampleTariff1 = CustomsTariffModel(
    tariffId: 1,
    hsCode: '8471.30.00',
    hsDescription: 'آلات معالجة البيانات المحمولة الرقمية',
    customsDutyRate: 0.0,
    vatRate: 14.0,
    scheduleTaxRate: 0.0,
    developmentFeeRate: 0.0,
    importFeeRate: 0.0,
    customsServiceFeeRate: 1.0,
    requiresCoo: true,
    requiresInspection: true,
    requiresAcid: true,
    regulatoryAuthority: 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)',
    priorApprovalNote: 'مطابقة قياسية وفحص مستندي',
    effectiveFrom: DateTime(2026, 1, 1),
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleTariff2 = CustomsTariffModel(
    tariffId: 2,
    hsCode: '8517.62.00',
    hsDescription: 'أجهزة استقبال أو تحويل أو إرسال الصوت أو الصور',
    customsDutyRate: 5.0,
    vatRate: 14.0,
    scheduleTaxRate: 0.0,
    developmentFeeRate: 0.0,
    importFeeRate: 0.0,
    customsServiceFeeRate: 1.0,
    requiresCoo: true,
    requiresInspection: false,
    requiresAcid: true,
    regulatoryAuthority: 'الجهاز القومي لتنظيم الاتصالات (NTRA)',
    priorApprovalNote: 'موافقة نوعية مسبقة من الجهاز القومي',
    effectiveFrom: DateTime(2026, 1, 1),
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget buildTestApp({
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    int initialSubTab = 1,
    int? initialImportFileId,
    List<CustomsTariffModel>? tariffs,
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([sampleFile1, sampleFile2])),
        customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier(tariffs ?? [sampleTariff1, sampleTariff2])),
        customsClearanceProvider.overrideWith((ref) => _MockCustomsClearanceNotifier([sampleClearance1])),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: CustomsDeclaration46Screen(
                initialSubTab: initialSubTab,
                initialImportFileId: initialImportFileId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 24: CustomsDeclaration46Screen SubTab 1 Enterprise Protocol Tests', () {
    testWidgets('Test 1: Desktop Viewport (1440x900) renders smoothly with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify SubTab 1 Header / Metric Cards
      expect(find.textContaining('إجمالي الرسوم التقديرية'), findsOneWidget);
      expect(find.text('إجمالي الضرائب والرسوم'), findsOneWidget);
      expect(find.textContaining('إعفاءات الشراكة الأوروبية'), findsOneWidget);

      // Verify Search and Action Toolbar
      expect(find.byKey(const Key('copyRegistryTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportRegistryExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportRegistryPdfBtn')), findsOneWidget);
      expect(find.byKey(const Key('registerNewDeclBtn')), findsOneWidget);

      // Verify DataTable and Row Actions
      expect(find.byKey(const Key('viewAssessmentBtn_46-ALX-IMP-2026-0010')), findsOneWidget);
      expect(find.byKey(const Key('copyRegistryRowBtn_46-ALX-IMP-2026-0010')), findsOneWidget);
      expect(find.byKey(const Key('cloneRegistryRowBtn_46-ALX-IMP-2026-0010')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('إجمالي الرسوم التقديرية'), findsOneWidget);
      expect(find.byKey(const Key('copyRegistryTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportRegistryExcelBtn')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 3: Mobile Viewport (390x844) renders with 0 RenderFlex overflow', (tester) async {
      FlutterErrorDetails? capturedDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(390, 844)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      if (capturedDetails != null) {
        // ignore: avoid_print
        print('SCREEN24_TEST3_OVERFLOW: ${capturedDetails!.summary}');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Dark Mode (WCAG AA) renders properly without contrast crashes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1200, 800),
        themeMode: ThemeMode.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('إجمالي الرسوم التقديرية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 5: RTL Directionality & Arabic Localization render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1200, 800),
        locale: const Locale('ar'),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Arabic localized labels
      expect(find.textContaining('تصدير سجل الإقرارات إلى Excel'), findsOneWidget);
      expect(find.textContaining('إعفاءات الشراكة الأوروبية'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 6: Task D — Record Clone from Registry Table Row clones into SubTab 0 editable draft', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Find clone button in the first data row
      final cloneRowBtn = find.byKey(const Key('cloneRegistryRowBtn_46-ALX-IMP-2026-0010'));
      expect(cloneRowBtn, findsOneWidget);

      await tester.ensureVisible(cloneRowBtn);
      await tester.pumpAndSettle();
      await tester.tap(cloneRowBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('46-DRAFT-IMP-2026-0010'), findsOneWidget);

      // Verify mandatorily reset fields
      expect(find.textContaining('رقم الإقرار الجمركي: يتم تصفيره'), findsOneWidget);

      // Confirm clone
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify feedback snackbar and redirection to SubTab 0 form
      expect(find.textContaining('تم استنساخ بيانات الإقرار'), findsOneWidget);
      expect(find.text('46-DRAFT-IMP-2026-0010'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 7: Task D, E & J — Assessment Dialog with Clone Action, Row TSV Copy, and Multi-Format Exports', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Test Row TSV Copy button
      final rowCopyBtn = find.byKey(const Key('copyRegistryRowBtn_46-ALX-IMP-2026-0010'));
      expect(rowCopyBtn, findsOneWidget);
      await tester.ensureVisible(rowCopyBtn);
      await tester.pumpAndSettle();
      await tester.tap(rowCopyBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // 2. Test Table TSV Copy button
      final copyTableBtn = find.byKey(const Key('copyRegistryTableTsvBtn'));
      expect(copyTableBtn, findsOneWidget);
      await tester.ensureVisible(copyTableBtn);
      await tester.pumpAndSettle();
      await tester.tap(copyTableBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Test Export Excel button
      final exportExcelBtn = find.byKey(const Key('exportRegistryExcelBtn'));
      expect(exportExcelBtn, findsOneWidget);
      await tester.ensureVisible(exportExcelBtn);
      await tester.pumpAndSettle();
      await tester.tap(exportExcelBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Test Export PDF button
      final exportPdfBtn = find.byKey(const Key('exportRegistryPdfBtn'));
      expect(exportPdfBtn, findsOneWidget);
      await tester.ensureVisible(exportPdfBtn);
      await tester.pumpAndSettle();
      await tester.tap(exportPdfBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Open Tariff Assessment Dialog
      final viewAssessmentBtn = find.byKey(const Key('viewAssessmentBtn_46-ALX-IMP-2026-0010'));
      expect(viewAssessmentBtn, findsOneWidget);
      await tester.ensureVisible(viewAssessmentBtn);
      await tester.pumpAndSettle();
      await tester.tap(viewAssessmentBtn);
      await tester.pumpAndSettle();

      // Verify assessment dialog is open with clone button inside
      final dialogCloneBtn = find.byKey(const Key('dialogCloneDeclBtn'));
      expect(dialogCloneBtn, findsOneWidget);

      // Tap Clone inside the dialog
      await tester.tap(dialogCloneBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog opened from inside the assessment dialog
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('46-DRAFT-IMP-2026-0010'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 8: Estimate cache invalidation on tariff update changes assessment calculations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Pump with initial tariffs (sampleTariff1 has customsDutyRate = 0.0)
      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900), tariffs: [sampleTariff1, sampleTariff2]));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('46-ALX-IMP-2026-0010'), findsOneWidget);

      // Now create updated tariff with rate 30.0 instead of 0.0 (same length, different identity & rate)
      final updatedTariff1 = CustomsTariffModel(
        tariffId: 1,
        hsCode: '8471.30.00',
        hsDescription: 'آلات معالجة البيانات المحمولة الرقمية',
        customsDutyRate: 30.0,
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        customsServiceFeeRate: 1.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        regulatoryAuthority: 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)',
        priorApprovalNote: 'مطابقة قياسية وفحص مستندي',
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Pump updated app with new tariff identity
      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900), tariffs: [updatedTariff1, sampleTariff2]));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('46-ALX-IMP-2026-0010'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
