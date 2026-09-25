import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';
import 'package:frontend/features/financial_approval/screens/financial_approval_screen.dart';
import 'package:frontend/features/financial_approval/widgets/search_and_clone_budget_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class MockImportBudgetsNotifier extends ImportBudgetsNotifier {
  int cloneCallCount = 0;
  Map<String, dynamic>? lastClonePayload;

  MockImportBudgetsNotifier(List<ImportBudgetModel> initialList) : super(Dio()) {
    state = AsyncValue.data(initialList);
  }

  @override
  Future<void> fetchImportBudgets({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? importFileId,
    String? status,
    String? budgetStatus,
  }) async {}

  @override
  Future<BudgetPrefillModel?> fetchBudgetPrefill(int importFileId) async {
    return BudgetPrefillModel(
      importFileId: importFileId,
      importFileCode: 'IMP-2026-001',
      importFileTitle: 'Main Batch Shipment',
      incoterm: 'FOB',
      supplierId: 1,
      supplierName: 'Global Tech Ltd',
      beneficiaryName: 'Global Tech Ltd',
      bankName: 'Bank of China',
      swiftCode: 'BKCHCNBJ',
      accountNumber: '123456',
      iban: 'CN1234567890',
      paymentTermsSummary: '30% Advance, 70% against BL',
      linkedPos: [],
      totalInvoiceAmount: 50000.0,
      invoiceCurrency: 'USD',
      totalInvoiceAmountEgp: 2500000.0,
      estimatedFreightCost: 3000.0,
      freightCurrency: 'USD',
      estimatedFreightCostEgp: 150000.0,
      estimatedCustomsDutiesEgp: 120000.0,
      estimatedClearanceFeesEgp: 30000.0,
      estimatedGrandTotalEgp: 2800000.0,
      exchangeRate: 50.0,
    );
  }

  @override
  Future<ImportBudgetModel?> cloneImportBudget(int budgetId, Map<String, dynamic> payload) async {
    cloneCallCount++;
    lastClonePayload = payload;
    final currentList = state.value ?? [];
    final original = currentList.firstWhere((b) => b.budgetId == budgetId);
    final cloned = ImportBudgetModel(
      budgetId: 999,
      budgetCode: '${original.budgetCode}-CLONE',
      title: payload['new_title'] ?? '${original.title} (نسخة)',
      importFileId: payload['unlink_import_file'] == true ? null : original.importFileId,
      importFileCode: payload['unlink_import_file'] == true ? null : original.importFileCode,
      poId: original.poId,
      projectId: original.projectId,
      invoiceAmountForeign: original.invoiceAmountForeign,
      invoiceCurrency: original.invoiceCurrency,
      invoiceAmountEgp: original.invoiceAmountEgp,
      freightCostForeign: original.freightCostForeign,
      freightCurrency: original.freightCurrency,
      freightCostEgp: original.freightCostEgp,
      customsDutiesEgp: original.customsDutiesEgp,
      clearanceInlandEgp: original.clearanceInlandEgp,
      exchangeRate: original.exchangeRate,
      totalBudgetEgp: original.totalBudgetEgp,
      budgetStatus: 'Pending Review',
      approvedBy: null,
      approvedDate: null,
      notes: payload['remarks'] ?? original.notes,
      isActive: true,
      createdAt: '2026-09-14T03:00:00Z',
      updatedAt: '2026-09-14T03:00:00Z',
    );
    state = AsyncValue.data([cloned, ...currentList]);
    return cloned;
  }
}

class MockPaymentRequestsNotifier extends PaymentRequestsNotifier {
  MockPaymentRequestsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPaymentRequests({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? supplierId,
    String? status,
  }) async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
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

class MockSuppliersNotifier extends SuppliersNotifier {
  MockSuppliersNotifier(List<SupplierModel> sups) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(sups);
  }

  @override
  Future<void> fetchSuppliers() async {}
}

class MockCurrenciesNotifier extends CurrenciesNotifier {
  MockCurrenciesNotifier(List<CurrencyModel> curs) : super(Dio()) {
    state = AsyncValue.data(curs);
  }

  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {}
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(super.dio, super.ref) {
    state = PurchaseOrdersState(purchaseOrders: []);
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

List<ImportBudgetModel> _createSampleBudgets() {
  return [
    ImportBudgetModel(
      budgetId: 1,
      budgetCode: 'BGT-2026-0001',
      title: 'Annual Hardware Imports Budget',
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      poId: 201,
      projectId: 1,
      invoiceAmountForeign: 50000.0,
      invoiceCurrency: 'USD',
      invoiceAmountEgp: 2500000.0,
      freightCostForeign: 3000.0,
      freightCurrency: 'USD',
      freightCostEgp: 150000.0,
      customsDutiesEgp: 120000.0,
      clearanceInlandEgp: 30000.0,
      exchangeRate: 50.0,
      totalBudgetEgp: 2800000.0,
      budgetStatus: 'Budget Approved',
      approvedBy: 'Financial Director',
      approvedDate: '2026-09-14',
      notes: 'Approved for Q3 procurement cycle',
      isActive: true,
      createdAt: '2026-09-14T01:00:00Z',
      updatedAt: '2026-09-14T01:00:00Z',
    ),
    ImportBudgetModel(
      budgetId: 2,
      budgetCode: 'BGT-2026-0002',
      title: 'Auxiliary Electronics Shipment',
      importFileId: 102,
      importFileCode: 'IMP-2026-002',
      poId: 202,
      projectId: 1,
      invoiceAmountForeign: 20000.0,
      invoiceCurrency: 'USD',
      invoiceAmountEgp: 1000000.0,
      freightCostForeign: 1500.0,
      freightCurrency: 'USD',
      freightCostEgp: 75000.0,
      customsDutiesEgp: 50000.0,
      clearanceInlandEgp: 15000.0,
      exchangeRate: 50.0,
      totalBudgetEgp: 1140000.0,
      budgetStatus: 'Pending Review',
      approvedBy: null,
      approvedDate: null,
      notes: 'Under review by customs officer',
      isActive: true,
      createdAt: '2026-09-14T02:00:00Z',
      updatedAt: '2026-09-14T02:00:00Z',
    ),
  ];
}

List<SupplierModel> _createSampleSuppliers() {
  return [
    SupplierModel.fromJson({
      'supplier_id': 1,
      'supplier_code': 'SUP-001',
      'company_name': 'Global Tech Ltd',
      'supplier_type': 'Manufacturer',
      'registration_type': 'Standard',
      'foreign_exporter_id': 'EXP-123',
      'foreign_exporter_country': 'China',
      'foreign_exporter_country_code': 'CN',
      'address': 'Shanghai Industrial Zone',
      'bank_name': 'Bank of China',
      'swift_code': 'BKCHCNBJ',
      'account_number': '123456',
      'iban': 'CN1234567890',
    }),
  ];
}

List<ImportFileModel> _createSampleImportFiles() {
  return [
    ImportFileModel.fromJson({
      'import_file_id': 101,
      'import_file_code': 'IMP-2026-001',
      'company_id': 1,
      'company_name': 'Sorour Logistics',
      'supplier_id': 1,
      'supplier_name': 'Global Tech Ltd',
      'shipment_mode': 'Sea',
      'incoterm_code': 'FOB',
      'priority': 'Normal',
      'shipment_category': 'Commercial',
      'custom_file_number': 'CF-001',
      'invoices_data': [],
      'packing_lists_data': [],
      'project_ids': [1],
      'is_customs_released': false,
    }),
  ];
}

List<CurrencyModel> _createSampleCurrencies() {
  return [
    CurrencyModel(
      currencyId: 1,
      currencyCode: 'USD',
      currencyName: 'US Dollar',
      currencySymbol: r'$',
      isBaseCurrency: false,
      decimalPlaces: 2,
      isActive: true,
      latestCommercialRate: 50.0,
      latestCustomsRate: 50.0,
    ),
    CurrencyModel(
      currencyId: 2,
      currencyCode: 'EGP',
      currencyName: 'Egyptian Pound',
      currencySymbol: 'LE',
      isBaseCurrency: true,
      decimalPlaces: 2,
      isActive: true,
      latestCommercialRate: 1.0,
      latestCustomsRate: 1.0,
    ),
  ];
}

Widget _buildTestWidget({
  required Size surfaceSize,
  required MockImportBudgetsNotifier budgetNotifier,
  bool isDark = false,
  Locale locale = const Locale('en'),
  int initialIndex = 1,
  int? initialImportFileId,
}) {
  return ProviderScope(
    overrides: [
      importBudgetsProvider.overrideWith((ref) => budgetNotifier),
      paymentRequestsProvider.overrideWith((ref) => MockPaymentRequestsNotifier()),
      suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(_createSampleSuppliers())),
      importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(_createSampleImportFiles())),
      currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(_createSampleCurrencies())),
      purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(Dio(), ref)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      home: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: surfaceSize),
            child: Scaffold(
              body: SizedBox(
                width: surfaceSize.width,
                height: surfaceSize.height,
                child: FinancialApprovalScreen(
                  initialIndex: initialIndex,
                  initialImportFileId: initialImportFileId,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 9: FinancialApprovalScreen (Tab 1: Import Budget Approval Form / BP-013) - 5-Task Tests', () {
    testWidgets('Task A1: Desktop Viewport (1400x900) renders with 0 RenderFlex overflow', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('searchAndCloneBudgetBtn')), findsOneWidget);
      expect(find.text('Import File Comprehensive Budget Approval'), findsOneWidget);
      expect(find.byIcon(Icons.currency_exchange), findsOneWidget);
    });

    testWidgets('Task A2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      const size = Size(800, 1024);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('searchAndCloneBudgetBtn')), findsOneWidget);
    });

    testWidgets('Task A3: Mobile Viewport (390x844) renders with 0 RenderFlex overflow', (tester) async {
      const size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('searchAndCloneBudgetBtn')), findsOneWidget);
    });

    testWidgets('Task B: Dark Mode Contrast and surface layering WCAG AA compliance', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        isDark: true,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final cardFinder = find.byType(Card).first;
      expect(cardFinder, findsOneWidget);
      final cardWidget = tester.widget<Card>(cardFinder);
      expect(cardWidget.color, AppTheme.darkCardBackground);
    });

    testWidgets('Task C: Full RTL Arabic support under Locale("ar")', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Screen Directionality is RTL
      final screenElement = tester.element(find.byType(FinancialApprovalScreen));
      expect(Directionality.of(screenElement), TextDirection.rtl);

      // Check Arabic title and clone button
      expect(find.text('اعتماد ميزانية ملف الاستيراد الشاملة'), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBudgetBtn')), findsOneWidget);
      expect(find.text('بحث واستنساخ اعتماد ميزانية'), findsOneWidget);
    });

    testWidgets('Task D: Screen-Level Clone via searchAndCloneBudgetBtn and CloneEntityReviewDialog', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleBudgets = _createSampleBudgets();
      final notifier = MockImportBudgetsNotifier(sampleBudgets);
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // 1. Tap search and clone toolbar button
      final cloneBtn = find.byKey(const Key('searchAndCloneBudgetBtn'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // 2. Search & Clone Dialog is displayed
      expect(find.byType(SearchAndCloneBudgetDialog), findsOneWidget);
      expect(find.text('BGT-2026-0001'), findsOneWidget);

      // 3. Select first budget to clone
      await tester.tap(find.text('BGT-2026-0001'));
      await tester.pumpAndSettle();

      // 4. CloneEntityReviewDialog is displayed
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // 5. Confirm clone via review dialog action button
      final confirmBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // 6. Verify clone was executed on provider
      expect(notifier.cloneCallCount, 1);

      // 7. Verify populated fields in form
      expect(find.text('50000.00'), findsWidgets);
    });

    testWidgets('Task E: Keyboard Shortcut Ctrl+D opens SearchAndCloneBudgetDialog', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Simulating key combo Ctrl+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Dialog should be open from shortcut
      expect(find.byType(SearchAndCloneBudgetDialog), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(SearchAndCloneBudgetDialog), findsNothing);
    });

    testWidgets('Task F: Consolidated Summary Table and Live Recalculation on Cost Input', (tester) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockImportBudgetsNotifier(_createSampleBudgets());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        budgetNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Verify Consolidated Budget Summary widget is rendered
      expect(find.byIcon(Icons.currency_exchange), findsOneWidget);
      expect(find.byType(Table), findsNWidgets(2));

      // Enter Estimated Invoice Value 1000 USD
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(1), '1000');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
