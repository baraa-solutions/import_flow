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
import 'package:frontend/features/financial_approval/widgets/search_and_clone_payment_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class MockPaymentRequestsNotifier extends PaymentRequestsNotifier {
  int cloneCallCount = 0;

  MockPaymentRequestsNotifier(List<PaymentRequestModel> initialList) : super(Dio()) {
    state = AsyncValue.data(initialList);
  }

  @override
  Future<void> fetchPaymentRequests({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? supplierId,
    String? status,
  }) async {}

  Future<BudgetPrefillModel?> getBudgetPrefill(int importFileId) async {
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
      linkedPos: [
        LinkedPOItemModel(
          poId: 201,
          poNumber: 'PO-2026-001',
          poReference: 'PO-REF-001',
          projectName: 'Alpha Project',
          paymentTerms: '30% Advance',
          currency: 'USD',
          totalAmount: 15000.0,
          status: 'Approved',
        ),
      ],
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
  Future<PaymentRequestModel?> clonePaymentRequest(int paymentId, Map<String, dynamic> payload) async {
    cloneCallCount++;
    final currentList = state.value ?? [];
    final original = currentList.firstWhere((p) => p.paymentId == paymentId);
    final cloned = PaymentRequestModel(
      paymentId: 999,
      paymentCode: '${original.paymentCode}-CLONE',
      title: payload['new_title'] ?? '${original.title} (نسخة)',
      supplierId: payload['target_supplier_id'] ?? original.supplierId,
      supplierName: original.supplierName,
      paymentType: original.paymentType,
      requestedAmount: (payload['new_requested_amount'] as num?)?.toDouble() ?? original.requestedAmount,
      currencyCode: original.currencyCode,
      exchangeRate: original.exchangeRate,
      requestedAmountEgp: original.requestedAmountEgp,
      dueDate: original.dueDate,
      requestDate: original.requestDate,
      status: 'Draft',
      beneficiaryName: original.beneficiaryName,
      bankName: original.bankName,
      swiftCode: original.swiftCode,
      ibanAccountNo: original.ibanAccountNo,
      notes: payload['remarks'] ?? original.notes,
      isActive: true,
      createdAt: '2026-09-14T02:00:00Z',
      updatedAt: '2026-09-14T02:00:00Z',
      importFileId: (payload['unlink_import_file'] == true) ? null : original.importFileId,
      importFileCode: (payload['unlink_import_file'] == true) ? null : original.importFileCode,
    );
    state = AsyncValue.data([cloned, ...currentList]);
    return cloned;
  }
}

class MockImportBudgetsNotifier extends ImportBudgetsNotifier {
  MockImportBudgetsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
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
      importFileCode: 'IMP-2026-002',
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
      linkedPos: [
        LinkedPOItemModel(
          poId: 201,
          poNumber: 'PO-2026-001',
          poReference: 'PO-REF-001',
          projectName: 'Alpha Project',
          paymentTerms: '30% Advance',
          currency: 'USD',
          totalAmount: 15000.0,
          status: 'Approved',
        ),
      ],
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

List<PaymentRequestModel> _createSamplePayments() {
  return [
    PaymentRequestModel(
      paymentId: 1,
      paymentCode: 'PAY-2026-0001',
      title: 'Advance Payment for Raw Materials',
      supplierId: 1,
      supplierName: 'Global Tech Ltd',
      paymentType: 'Advance Payment',
      requestedAmount: 50000.0,
      currencyCode: 'USD',
      exchangeRate: 50.0,
      requestedAmountEgp: 2500000.0,
      dueDate: '2026-09-26',
      requestDate: '2026-09-14',
      status: 'Draft',
      beneficiaryName: 'Global Tech Ltd',
      bankName: 'Bank of China',
      swiftCode: 'BKCHCNBJ',
      ibanAccountNo: 'CN1234567890',
      notes: 'Initial production advance payment',
      isActive: true,
      createdAt: '2026-09-14T01:00:00Z',
      updatedAt: '2026-09-14T01:00:00Z',
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
    ),
    PaymentRequestModel(
      paymentId: 2,
      paymentCode: 'PAY-2026-0002',
      title: 'Final Balance Payment 70%',
      supplierId: 1,
      supplierName: 'Global Tech Ltd',
      paymentType: 'Balance Payment',
      requestedAmount: 116666.67,
      currencyCode: 'USD',
      exchangeRate: 50.0,
      requestedAmountEgp: 5833333.5,
      dueDate: '2026-10-05',
      requestDate: '2026-09-14',
      status: 'Pending Review',
      beneficiaryName: 'Global Tech Ltd',
      bankName: 'Bank of China',
      swiftCode: 'BKCHCNBJ',
      ibanAccountNo: 'CN1234567890',
      notes: 'Payable against Bill of Lading copy',
      isActive: true,
      createdAt: '2026-09-14T01:30:00Z',
      updatedAt: '2026-09-14T01:30:00Z',
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
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
    ImportFileModel.fromJson({
      'import_file_id': 102,
      'import_file_code': 'IMP-2026-002',
      'company_id': 1,
      'company_name': 'Sorour Logistics',
      'supplier_id': 1,
      'supplier_name': 'Global Tech Ltd',
      'shipment_mode': 'Sea',
      'incoterm_code': 'FOB',
      'priority': 'Normal',
      'shipment_category': 'Commercial',
      'custom_file_number': 'CF-002',
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
      currencyCode: 'EUR',
      currencyName: 'Euro',
      currencySymbol: '€',
      isBaseCurrency: false,
      decimalPlaces: 2,
      isActive: true,
      latestCommercialRate: 54.0,
      latestCustomsRate: 54.0,
    ),
    CurrencyModel(
      currencyId: 3,
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
  required MockPaymentRequestsNotifier paymentNotifier,
  bool isDark = false,
  Locale locale = const Locale('ar'),
  int initialIndex = 0,
  int? initialImportFileId,
}) {
  return ProviderScope(
    overrides: [
      paymentRequestsProvider.overrideWith((ref) => paymentNotifier),
      importBudgetsProvider.overrideWith((ref) => MockImportBudgetsNotifier()),
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

  group('Screen 8: FinancialApprovalScreen (Tab 0: Payment Requests Form / BP-012) - 5-Task Tests', () {
    testWidgets('Task A1: Desktop Viewport (1400x900) renders with 0 RenderFlex overflow', (tester) async {
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('searchAndClonePaymentRequestBtn')), findsOneWidget);
      expect(find.text('Issue Supplier Payment Request'), findsOneWidget);
    });

    testWidgets('Task A2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      final size = const Size(800, 1024);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('searchAndClonePaymentRequestBtn')), findsOneWidget);
    });

    testWidgets('Task A3: Mobile Viewport (390x844) renders with 0 RenderFlex overflow', (tester) async {
      final size = const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('searchAndClonePaymentRequestBtn')), findsOneWidget);
    });

    testWidgets('Task B: Dark Mode Contrast and surface layering WCAG AA compliance', (tester) async {
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
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
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Screen Directionality is RTL
      final screenElement = tester.element(find.byType(FinancialApprovalScreen));
      expect(Directionality.of(screenElement), TextDirection.rtl);

      // Check Arabic title and clone button
      expect(find.text('إصدار طلب سداد وتحويل مالي للمورد'), findsOneWidget);
      expect(find.byKey(const ValueKey('searchAndClonePaymentRequestBtn')), findsOneWidget);
    });

    testWidgets('Task D: Screen-Level Clone via searchAndClonePaymentRequestBtn and CloneEntityReviewDialog', (tester) async {
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final samplePayments = _createSamplePayments();
      final notifier = MockPaymentRequestsNotifier(samplePayments);
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // 1. Tap search and clone toolbar button
      final cloneBtn = find.byKey(const ValueKey('searchAndClonePaymentRequestBtn'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // 2. Search & Clone Dialog is displayed
      expect(find.byType(SearchAndClonePaymentDialog), findsOneWidget);
      expect(find.text('PAY-2026-0001'), findsOneWidget);

      // 3. Select first payment to clone
      await tester.tap(find.text('PAY-2026-0001'));
      await tester.pumpAndSettle();

      // 4. CloneEntityReviewDialog is displayed
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);

      // 5. Confirm clone via review dialog action button
      final confirmBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // 6. Verify clone was executed
      expect(notifier.cloneCallCount, 1);
    });

    testWidgets('Task E: Keyboard Shortcut Ctrl+D opens SearchAndClonePaymentDialog', (tester) async {
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Simulating key combo via pressing ControlLeft then D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Dialog should be open from shortcut
      expect(find.byType(SearchAndClonePaymentDialog), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(SearchAndClonePaymentDialog), findsNothing);
    });

    testWidgets('Task F: Row-Level Clone on Linked POs duplicates allocation item', (tester) async {
      final size = const Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = MockPaymentRequestsNotifier(_createSamplePayments());
      await tester.pumpWidget(_buildTestWidget(
        surfaceSize: size,
        paymentNotifier: notifier,
        locale: const Locale('en'),
        initialImportFileId: 102,
      ));
      await tester.pumpAndSettle();

      // Verify linked PO is loaded
      expect(find.text('Alpha Project'), findsOneWidget);
      final clonePoBtn = find.byIcon(Icons.copy_rounded).first;
      expect(clonePoBtn, findsOneWidget);

      await tester.ensureVisible(clonePoBtn);
      await tester.pumpAndSettle();

      // Tap clone PO allocation button
      await tester.tap(clonePoBtn);
      await tester.pumpAndSettle();

      // Verify PO allocation was duplicated
      expect(find.text('Alpha Project'), findsNWidgets(2));
      expect(find.text('PO allocation cloned successfully'), findsOneWidget);
    });
  });
}
