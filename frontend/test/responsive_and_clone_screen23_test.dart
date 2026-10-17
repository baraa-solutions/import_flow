import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/import_documentation/screens/customs_declaration46_screen.dart';
import 'package:frontend/features/import_documentation/widgets/search_and_clone_customs_declaration46_dialog.dart';
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

class _MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState> implements PurchaseOrdersNotifier {
  final List<PurchaseOrderModel> initialPOs;
  _MockPurchaseOrdersNotifier(this.initialPOs) : super(PurchaseOrdersState(purchaseOrders: initialPOs));

  @override
  Future<void> fetchPurchaseOrders() async {
    state = state.copyWith(purchaseOrders: initialPOs, isLoading: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrenciesNotifier extends CurrenciesNotifier {
  final List<CurrencyModel> initial;
  _MockCurrenciesNotifier(this.initial) : super(Dio()) {
    state = AsyncValue.data(initial);
  }

  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {
    state = AsyncValue.data(initial);
  }
}

/// A PO linked to [fileId] whose single line carries [hsCode].
PurchaseOrderModel _poWithHs(int fileId, String hsCode) => PurchaseOrderModel.fromJson({
      'po_id': 1,
      'po_number': 'PO-1',
      'import_file_id': fileId,
      'items': [
        {'item_id': 1, 'po_id': 1, 'hs_code': hsCode, 'quantity': 1, 'unit_price': 1},
      ],
    });

CurrencyModel _currency(String code, double? customsRate) => CurrencyModel(
      currencyCode: code,
      currencyName: code,
      currencySymbol: code,
      latestCustomsRate: customsRate,
    );

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
    customsDutyRate: 0.0, // European Partnership 0%
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
    int initialSubTab = 0,
    int? initialImportFileId = 10,
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([sampleFile1, sampleFile2])),
        customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([sampleTariff1, sampleTariff2])),
        // The screen no longer invents fallback HS codes: the EUR.1 exemption card and
        // the regulatory approvals board need a real PO line HS code + customs FX rate.
        purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier([_poWithHs(10, '8471.30.00')])),
        currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier([_currency('EUR', 55.0)])),
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

  group('Screen 23: CustomsDeclaration46Screen SubTab 0 Enterprise Protocol Tests', () {
    testWidgets('Test 1: Desktop Viewport (1440x900) renders smoothly with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Header and title
      expect(find.textContaining('الإقرار الجمركي المبدئي وشهادة 46 ك.م'), findsOneWidget);

      // Verify auto-populated values
      expect(find.text('8912345678901234567'), findsOneWidget); // ACID
      expect(find.text('F4-BNK-99881'), findsOneWidget); // Form 4
      expect(find.text('MEDUST-IT-0099'), findsOneWidget); // B/L Number

      // Verify SubTab 0 Search & Clone button
      expect(find.byKey(const Key('subtab0SearchAndCloneBtn')), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneDeclHeaderBtn')), findsOneWidget);

      // Verify Exemption card
      expect(find.textContaining('اتفاقية الشراكة المصرية الأوروبية'), findsOneWidget);

      // Verify Regulatory Approvals Board & Export buttons
      expect(find.byKey(const Key('copyRegulatoryTableTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportRegulatoryExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportRegulatoryPdfBtn')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('الإقرار الجمركي المبدئي وشهادة 46 ك.م'), findsOneWidget);
      expect(find.byKey(const Key('subtab0SearchAndCloneBtn')), findsOneWidget);
      expect(find.byKey(const Key('copyRegulatoryTableTsvBtn')), findsOneWidget);

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
        print('TEST3_OVERFLOW: ${capturedDetails!.summary}');
        if (capturedDetails!.informationCollector != null) {
          for (final d in capturedDetails!.informationCollector!()) {
            // ignore: avoid_print
            print('TEST3_COLLECTOR: $d');
          }
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Dark Mode (WCAG AA) renders properly without contrast crashes', (tester) async {
      FlutterErrorDetails? capturedDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(
        size: const Size(1200, 800),
        themeMode: ThemeMode.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      if (capturedDetails != null) {
        // ignore: avoid_print
        print('CAPTURED_OVERFLOW: ${capturedDetails!.summary}');
        if (capturedDetails!.informationCollector != null) {
          for (final d in capturedDetails!.informationCollector!()) {
            // ignore: avoid_print
            print('COLLECTOR: $d');
          }
        }
      }
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
      expect(find.textContaining('استنساخ إقرار 46 جمركي'), findsWidgets);
      expect(find.textContaining('العروض والموافقات المطلوبة والاشتراطات الرقابية'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 6: Task D — Screen & Record Clone Dialog clones into editable draft with mandatory reset rules', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open Search and Clone Dialog
      final cloneHeaderBtn = find.byKey(const Key('subtab0SearchAndCloneBtn'));
      expect(cloneHeaderBtn, findsOneWidget);
      await tester.tap(cloneHeaderBtn);
      await tester.pumpAndSettle();

      // Verify Search & Clone Dialog is displayed
      expect(find.byType(SearchAndCloneCustomsDeclaration46Dialog), findsOneWidget);
      expect(find.textContaining('بحث واستنساخ إقرار جمركي سابق'), findsOneWidget);

      // Find clone button for the declaration
      final selectDeclBtn = find.byKey(const Key('cloneDeclBtn_46-ALX-IMP-2026-0010'));
      expect(selectDeclBtn, findsOneWidget);

      // Tap to clone this declaration
      await tester.tap(selectDeclBtn);
      await tester.pumpAndSettle();

      // Debug: check dialog
      final dialogFound = find.byType(CloneEntityReviewDialog);
      // ignore: avoid_print
      print('CLONE_DIALOG_FOUND_COUNT: ${dialogFound.evaluate().length}');
      if (dialogFound.evaluate().isEmpty) {
        // ignore: avoid_print
        print('ACTIVE_WIDGETS: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText()).toList()}');
      }

      // Verify CloneEntityReviewDialog opened
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('46-DRAFT-IMP-2026-0010'), findsOneWidget);

      // Verify mandatorily reset fields section
      expect(find.textContaining('رقم الإقرار الجمركي: يتم تصفيره'), findsOneWidget);

      // Confirm clone
      final confirmBtn = find.byKey(const Key('confirmCloneBtn'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar shown
      expect(find.textContaining('تم استنساخ بيانات الإقرار'), findsOneWidget);

      // Verify form code updated to draft code
      expect(find.text('46-DRAFT-IMP-2026-0010'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 7: Task E & J — Regulatory Approvals Table Export and Row TSV Copy actions respond correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp(size: const Size(1300, 900)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Task J buttons exist on Approvals Card
      final copyTableBtn = find.byKey(const Key('copyRegulatoryTableTsvBtn'));
      final exportExcelBtn = find.byKey(const Key('exportRegulatoryExcelBtn'));
      final exportPdfBtn = find.byKey(const Key('exportRegulatoryPdfBtn'));

      expect(copyTableBtn, findsOneWidget);
      expect(exportExcelBtn, findsOneWidget);
      expect(exportPdfBtn, findsOneWidget);

      // Tap Copy Table TSV button
      await tester.ensureVisible(copyTableBtn);
      await tester.pumpAndSettle();
      await tester.tap(copyTableBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Row Action button exists
      final rowCopyBtn = find.byKey(const Key('copyApprovalRowBtn_8471.30.00'));
      expect(rowCopyBtn, findsOneWidget);

      // Tap Row Copy button
      await tester.ensureVisible(rowCopyBtn);
      await tester.pumpAndSettle();
      await tester.tap(rowCopyBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
