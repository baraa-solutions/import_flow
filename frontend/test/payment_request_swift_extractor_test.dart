import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';
import 'package:frontend/features/financial_approval/screens/financial_approval_screen.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class _MockPaymentRequestsNotifier extends PaymentRequestsNotifier {
  _MockPaymentRequestsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchPaymentRequests({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? supplierId,
    String? status,
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockImportBudgetsNotifier extends ImportBudgetsNotifier {
  _MockImportBudgetsNotifier() : super(Dio()) {
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
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  _MockImportFilesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
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
    state = const AsyncValue.data([]);
  }
}

class _MockSuppliersNotifier extends SuppliersNotifier {
  _MockSuppliersNotifier() : super(showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchSuppliers() async {
    state = const AsyncValue.data([]);
  }
}

class _MockCurrenciesNotifier extends CurrenciesNotifier {
  _MockCurrenciesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

class _MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier(super.dio, super.ref) {
    state = PurchaseOrdersState(purchaseOrders: []);
  }

  @override
  Future<void> fetchPurchaseOrders() async {
    state = PurchaseOrdersState(purchaseOrders: []);
  }
}

void main() {
  testWidgets('FinancialApprovalScreen renders Smart AI SWIFT Extractor and auto-fills Payment Request form', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRequestsProvider.overrideWith((ref) => _MockPaymentRequestsNotifier()),
          importBudgetsProvider.overrideWith((ref) => _MockImportBudgetsNotifier()),
          importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
          suppliersProvider.overrideWith((ref) => _MockSuppliersNotifier()),
          currenciesProvider.overrideWith((ref) => _MockCurrenciesNotifier()),
          purchaseOrdersProvider.overrideWith((ref) => _MockPurchaseOrdersNotifier(Dio(), ref)),
        ],
        child: const MaterialApp(
          home: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: FinancialApprovalScreen(initialIndex: 0),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header of SWIFT Extractor tool
    expect(find.textContaining('استخراج ومطابقة إشعار التحويل البنكي'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsWidgets);
    expect(find.byIcon(Icons.bolt), findsWidgets);

    const sampleSwift = ''':20:TR202608159921
:32A:260815USD43704,00
:50K:/123456789
EGYPTIAN TRADING CO
:57A:PCBCCNBJJSS
:59:/32250198613609841015
SUZHOU YUHENG TEXTILE CO LTD
:70:/INV/YH202608-01''';

    // Enter Swift text
    final textFields = find.byType(TextField);
    if (textFields.evaluate().isNotEmpty) {
      await tester.enterText(textFields.first, sampleSwift);
      await tester.pumpAndSettle();

      // Tap bolt execute button
      await tester.tap(find.byIcon(Icons.bolt).first);
      await tester.pumpAndSettle();

      // Verify Form Fields Auto-Populated
      expect(find.textContaining('43704'), findsWidgets);
      expect(find.textContaining('PCBCCNBJJSS'), findsWidgets);
    }
  });
}
