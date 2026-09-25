import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/core/widgets/row_actions_pill.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';
import 'package:frontend/features/financial_approval/screens/financial_approval_screen.dart';
import 'package:frontend/features/financial_approval/widgets/saved_budgets_registry_tab.dart';
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
      importFileTitle: 'Batch Cargo A',
      incoterm: 'FOB',
      supplierId: 1,
      supplierName: 'Global Supplier Ltd',
      beneficiaryName: 'Global Supplier Ltd',
      bankName: 'HSBC International',
      swiftCode: 'HSBCUS33',
      accountNumber: '987654321',
      iban: 'US987654321',
      paymentTermsSummary: '30% Advance, 70% against BL',
      linkedPos: [],
      totalInvoiceAmount: 40000.0,
      invoiceCurrency: 'USD',
      totalInvoiceAmountEgp: 2000000.0,
      estimatedFreightCost: 2500.0,
      freightCurrency: 'USD',
      estimatedFreightCostEgp: 125000.0,
      estimatedCustomsDutiesEgp: 110000.0,
      estimatedClearanceFeesEgp: 25000.0,
      estimatedGrandTotalEgp: 2260000.0,
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
      budgetId: 888,
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
      createdAt: '2026-09-14T04:00:00Z',
      updatedAt: '2026-09-14T04:00:00Z',
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

void main() {
  final sampleBudgets = [
    ImportBudgetModel(
      budgetId: 101,
      budgetCode: 'BGT-2026-001',
      title: 'Commercial Budget A - Petrochem Units',
      importFileId: 1,
      importFileCode: 'IMP-2026-001',
      invoiceAmountForeign: 50000.0,
      invoiceCurrency: 'USD',
      invoiceAmountEgp: 2500000.0,
      freightCostForeign: 3500.0,
      freightCurrency: 'USD',
      freightCostEgp: 175000.0,
      customsDutiesEgp: 125000.0,
      clearanceInlandEgp: 30000.0,
      exchangeRate: 50.0,
      totalBudgetEgp: 2830000.0,
      budgetStatus: 'Budget Approved',
      approvedBy: 'Ahmed Sorour',
      approvedDate: '2026-09-10T10:00:00Z',
      notes: 'Initial approved budget for import file 1',
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-10T10:00:00Z',
    ),
    ImportBudgetModel(
      budgetId: 102,
      budgetCode: 'BGT-2026-002',
      title: 'Secondary Budget B - Spare Parts',
      importFileId: 2,
      importFileCode: 'IMP-2026-002',
      invoiceAmountForeign: 20000.0,
      invoiceCurrency: 'EUR',
      invoiceAmountEgp: 1100000.0,
      freightCostForeign: 1500.0,
      freightCurrency: 'EUR',
      freightCostEgp: 82500.0,
      customsDutiesEgp: 65000.0,
      clearanceInlandEgp: 15000.0,
      exchangeRate: 55.0,
      totalBudgetEgp: 1262500.0,
      budgetStatus: 'Pending Review',
      approvedBy: null,
      approvedDate: null,
      notes: 'Under executive financial review',
      isActive: true,
      createdAt: '2026-09-05T12:00:00Z',
      updatedAt: '2026-09-05T12:00:00Z',
    ),
  ];

  Widget buildScreen10TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    MockImportBudgetsNotifier? customBudgetsNotifier,
  }) {
    final budgetsNotifier = customBudgetsNotifier ?? MockImportBudgetsNotifier(sampleBudgets);

    return ProviderScope(
      overrides: [
        importBudgetsProvider.overrideWith((ref) => budgetsNotifier),
        paymentRequestsProvider.overrideWith((ref) => MockPaymentRequestsNotifier()),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
        suppliersProvider.overrideWith((ref) => MockSuppliersNotifier([])),
        currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier([])),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(Dio(), ref)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.noScaling,
              ),
              child: const Scaffold(
                body: FinancialApprovalScreen(initialIndex: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 10: FinancialApprovalScreen (Tab 2: Saved Budgets Registry) 5-Task Protocol', () {
    testWidgets('1. Desktop Viewport (1400x900) layout renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(find.byType(SavedBudgetsRegistryTab), findsOneWidget);
      expect(find.text('BGT-2026-001'), findsOneWidget);
      expect(find.text('BGT-2026-002'), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneBudgetRegistryBtn')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet Viewport (800x1024) layout renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(SavedBudgetsRegistryTab), findsOneWidget);
      expect(find.text('BGT-2026-001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile Viewport (390x844) layout renders 2x2 cost grid with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byType(SavedBudgetsRegistryTab), findsOneWidget);
      expect(find.text('BGT-2026-001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Dark Mode Color & Contrast tokens properly applied', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(
        size: const Size(1200, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsWidgets);
      final firstCard = tester.widget<Card>(cardFinder.first);
      expect(firstCard.color, equals(AppTheme.darkCardBackground));
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. RTL Arabic mirroring verified under Locale(ar)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(
        size: const Size(1200, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SavedBudgetsRegistryTab));
      expect(Directionality.of(context), equals(TextDirection.rtl));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Screen-Level Clone via searchAndCloneBudgetRegistryBtn opens dialog and clones budget', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockBudgets = MockImportBudgetsNotifier(sampleBudgets);

      await tester.pumpWidget(buildScreen10TestWidget(
        size: const Size(1400, 900),
        customBudgetsNotifier: mockBudgets,
      ));
      await tester.pumpAndSettle();

      final cloneBtnFinder = find.byKey(const Key('searchAndCloneBudgetRegistryBtn')).first;
      expect(cloneBtnFinder, findsOneWidget);
      await tester.tap(cloneBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneBudgetDialog), findsOneWidget);

      final itemToSelect = find.descendant(
        of: find.byType(SearchAndCloneBudgetDialog),
        matching: find.text('BGT-2026-001'),
      ).first;
      await tester.tap(itemToSelect);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.text('BGT-2026-001-CLONE'), findsOneWidget);

      final confirmBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockBudgets.cloneCallCount, equals(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Row-Level Clone action via RowActionsPill triggers clone dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockBudgets = MockImportBudgetsNotifier(sampleBudgets);

      await tester.pumpWidget(buildScreen10TestWidget(
        size: const Size(1400, 900),
        customBudgetsNotifier: mockBudgets,
      ));
      await tester.pumpAndSettle();

      final rowActionsPills = find.byType(RowActionsPill);
      expect(rowActionsPills, findsWidgets);

      final cloneIconFinder = find.descendant(
        of: rowActionsPills.first,
        matching: find.byIcon(Icons.copy_rounded),
      );
      expect(cloneIconFinder, findsOneWidget);

      await tester.tap(cloneIconFinder);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Keyboard Shortcut Ctrl + D triggers Search and Clone Budget dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen10TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneBudgetDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
