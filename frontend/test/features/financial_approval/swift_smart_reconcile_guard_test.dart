import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';
import 'package:frontend/features/financial_approval/screens/swift_reconciliation_screen.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';

class FakePaymentRequestsNotifier extends PaymentRequestsNotifier {
  bool smartReconcileSwiftCalled = false;
  bool reconcileReviewedSwiftBatchCalled = false;
  bool reconcileSwiftCalled = false;
  Map<String, dynamic>? nextExtractResult;

  FakePaymentRequestsNotifier(List<PaymentRequestModel> initialPayments)
      : super(Dio()) {
    state = AsyncValue.data(initialPayments);
  }

  @override
  Future<void> fetchPaymentRequests({
    bool includeInactive = false,
    String? search,
    int? poId,
    int? supplierId,
    String? status,
  }) async {
    // Keep initialized data in state without making HTTP calls
  }

  @override
  Future<Map<String, dynamic>> smartExtractSwift({
    required String rawText,
    int? targetPaymentId,
  }) async {
    if (nextExtractResult != null) return nextExtractResult!;
    return {'success': false, 'error': 'No mock result configured'};
  }

  @override
  Future<PaymentRequestModel?> smartReconcileSwift({
    required int paymentId,
    String? rawText,
    required String swiftReferenceNo,
    required String swiftReceiptDate,
    required double swiftTransferredAmount,
    String swiftTransferredCurrency = 'USD',
    String? bankName,
    String? swiftCode,
    String? ibanAccountNo,
    String? swiftReconciliationNotes,
    bool autoExecute = true,
  }) async {
    smartReconcileSwiftCalled = true;
    return null;
  }

  @override
  Future<PaymentRequestModel?> reconcileReviewedSwiftBatch({
    required int batchId,
    required int paymentId,
    String? notes,
  }) async {
    reconcileReviewedSwiftBatchCalled = true;
    return null;
  }

  @override
  Future<PaymentRequestModel?> reconcileSwift({
    required int paymentId,
    required String swiftReferenceNo,
    required String swiftReceiptDate,
    required double swiftTransferredAmount,
    String swiftTransferredCurrency = 'USD',
    String? swiftReconciliationNotes,
  }) async {
    reconcileSwiftCalled = true;
    return null;
  }
}

class FakeCurrenciesNotifier extends CurrenciesNotifier {
  FakeCurrenciesNotifier() : super(Dio()) {
    state = AsyncValue.data([
      CurrencyModel(
        currencyId: 1,
        currencyCode: 'USD',
        currencyName: 'US Dollar',
        currencySymbol: '\$',
        isBaseCurrency: false,
        exchangeRates: [],
      ),
      CurrencyModel(
        currencyId: 2,
        currencyCode: 'EUR',
        currencyName: 'Euro',
        currencySymbol: '€',
        isBaseCurrency: false,
        exchangeRates: [],
      ),
    ]);
  }

  @override
  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {}
}

class FakeImportFilesNotifier extends ImportFilesNotifier {
  FakeImportFilesNotifier() : super(Dio()) {
    state = const AsyncValue.data(<ImportFileModel>[]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    String? status,
    int? companyId,
    int? supplierId,
    String? owner,
  }) async {}
}

PaymentRequestModel _createSamplePayment() {
  return PaymentRequestModel(
    paymentId: 101,
    paymentCode: 'PAY-2026-001',
    title: 'Test Payment Request',
    supplierName: 'SUZHOU YUHENG TEXTILE CO., LTD',
    paymentType: 'Advance Payment',
    requestedAmount: 43704.0,
    currencyCode: 'USD',
    requestedAmountEgp: 2185200.0,
    dueDate: '2026-08-30',
    requestDate: '2026-08-01',
    status: 'APPROVED',
    swiftCode: 'PCBCCNBJJSS',
    ibanAccountNo: '32250198613609841015',
    createdAt: '2026-08-01',
    updatedAt: '2026-08-01',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SWIFT Smart Reconcile Guards (FE02-T01)', () {
    Future<void> testMissingFieldGuard({
      required WidgetTester tester,
      required Map<String, dynamic> parsedSwift,
      required String expectedMissingFieldName,
    }) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final samplePayment = _createSamplePayment();
      final fakeNotifier = FakePaymentRequestsNotifier([samplePayment]);

      fakeNotifier.nextExtractResult = {
        'success': true,
        'parsed_swift': parsedSwift,
        'matched_payment_request': samplePayment.toJson(),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentRequestsProvider.overrideWith((ref) => fakeNotifier),
            currenciesProvider.overrideWith((ref) => FakeCurrenciesNotifier()),
            importFilesProvider.overrideWith((ref) => FakeImportFilesNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(body: SwiftReconciliationScreen()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rawTextField = find.byType(TextField).first;
      await tester.enterText(rawTextField, 'Sample SWIFT raw text');
      await tester.pumpAndSettle();

      final extractBtn = find.widgetWithText(AppButton, 'Extract from Text');
      expect(extractBtn, findsOneWidget);
      await tester.tap(extractBtn);
      await tester.pumpAndSettle();

      ScaffoldMessenger.of(tester.element(extractBtn)).clearSnackBars();
      await tester.pumpAndSettle();

      final reconcileBtn =
          find.widgetWithText(AppButton, 'Confirm Match & Reconcile Payment');
      expect(reconcileBtn, findsOneWidget);
      await tester.ensureVisible(reconcileBtn);
      await tester.pumpAndSettle();

      await tester.tap(reconcileBtn);
      await tester.pumpAndSettle();

      expect(fakeNotifier.smartReconcileSwiftCalled, isFalse);
      expect(fakeNotifier.reconcileReviewedSwiftBatchCalled, isFalse);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining(expectedMissingFieldName),
        ),
        findsOneWidget,
      );
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(
        snackBar.backgroundColor,
        anyOf(equals(AppTheme.orange), equals(AppTheme.wcagOrange)),
      );
    }

    testWidgets(
        'Missing transaction_reference blocks reconciliation with orange SnackBar',
        (tester) async {
      await testMissingFieldGuard(
        tester: tester,
        parsedSwift: {
          'value_date': '2026-08-18',
          'amount': 43704.0,
          'currency': 'USD',
          'beneficiary_bank_swift': 'PCBCCNBJJSS',
          'beneficiary_account_or_iban': '32250198613609841015',
        },
        expectedMissingFieldName: 'SWIFT reference',
      );
    });

    testWidgets(
        'Missing value_date blocks reconciliation with orange SnackBar',
        (tester) async {
      await testMissingFieldGuard(
        tester: tester,
        parsedSwift: {
          'transaction_reference': 'FT2608189999',
          'amount': 43704.0,
          'currency': 'USD',
          'beneficiary_bank_swift': 'PCBCCNBJJSS',
          'beneficiary_account_or_iban': '32250198613609841015',
        },
        expectedMissingFieldName: 'Value date',
      );
    });

    testWidgets(
        'Missing or zero amount blocks reconciliation with orange SnackBar',
        (tester) async {
      await testMissingFieldGuard(
        tester: tester,
        parsedSwift: {
          'transaction_reference': 'FT2608189999',
          'value_date': '2026-08-18',
          'amount': 0.0,
          'currency': 'USD',
          'beneficiary_bank_swift': 'PCBCCNBJJSS',
          'beneficiary_account_or_iban': '32250198613609841015',
        },
        expectedMissingFieldName: 'Amount',
      );
    });

    testWidgets(
        'Missing currency blocks reconciliation with orange SnackBar',
        (tester) async {
      await testMissingFieldGuard(
        tester: tester,
        parsedSwift: {
          'transaction_reference': 'FT2608189999',
          'value_date': '2026-08-18',
          'amount': 43704.0,
          'beneficiary_bank_swift': 'PCBCCNBJJSS',
          'beneficiary_account_or_iban': '32250198613609841015',
        },
        expectedMissingFieldName: 'Currency',
      );
    });

    testWidgets(
        'Manual dialog for payment with no SWIFT data starts empty and does not call reconcileSwift when saved empty',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final samplePayment = _createSamplePayment();
      final fakeNotifier = FakePaymentRequestsNotifier([samplePayment]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentRequestsProvider.overrideWith((ref) => fakeNotifier),
            currenciesProvider.overrideWith((ref) => FakeCurrenciesNotifier()),
            importFilesProvider.overrideWith((ref) => FakeImportFilesNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(body: SwiftReconciliationScreen()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final registerBtn = find.widgetWithText(AppButton, 'Register SWIFT');
      expect(registerBtn, findsOneWidget);
      await tester.ensureVisible(registerBtn);
      await tester.pumpAndSettle();
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      final saveBtn = find.widgetWithText(
          AppButton, 'Save & Reconcile SWIFT (Sync Shipment)');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(fakeNotifier.reconcileSwiftCalled, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    test('Source-scan guard: no invented data or USD fallbacks in swift_reconciliation_screen', () {
      final candidates = [
        File('lib/features/financial_approval/screens/swift_reconciliation_screen.dart'),
        File('frontend/lib/features/financial_approval/screens/swift_reconciliation_screen.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => candidates.first,
      );
      expect(file.existsSync(), isTrue, reason: 'swift_reconciliation_screen.dart must exist');

      // The screen was split: its dialogs and upload flow now live under
      // widgets/swift_reconciliation/. Scan the screen together with those parts.
      final partsDir = Directory(
          file.path.replaceFirst('screens/swift_reconciliation_screen.dart', 'widgets/swift_reconciliation'));
      expect(partsDir.existsSync(), isTrue, reason: 'widgets/swift_reconciliation/ must exist');
      final parts = partsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final content = [file, ...parts].map((f) => f.readAsStringSync()).join('\n');

      // Must not invent SWIFT transaction reference
      expect(content.contains("'SWIFT-\${DateTime.now().millisecondsSinceEpoch}'"), isFalse,
          reason: 'Must never invent a dummy SWIFT reference');

      // Must not default to current date when value_date is missing
      expect(content.contains("DateTime.now().toString().substring(0, 10)"), isFalse,
          reason: 'Must never default value_date to today');

      // Must not use hardcoded subtitle as notes
      expect(content.contains("storedText.swiftScreenSubtitle"), isFalse,
          reason: 'Must not use generic screen subtitle as reconciliation notes');
      expect(content.contains("l10n.swiftScreenSubtitle"), isFalse,
          reason: 'Must not use generic screen subtitle as reconciliation notes');

      // Must not use raw currencyController or default to 'USD'
      expect(content.contains("currencyController"), isFalse,
          reason: 'Manual dialog must use SearchableDropdownField for currency');
      expect(content.contains("? currencyController.text.trim() : 'USD'"), isFalse,
          reason: 'Must not fallback currency to USD');

      // Must contain missing fields validation & batch check
      expect(content.contains("swiftReconcileMissingFields"), isTrue,
          reason: 'Must validate and report missing SWIFT fields');
      expect(content.contains("swiftBatchNotConfirmed"), isTrue,
          reason: 'Must block unconfirmed batch reconciliation');
    });
  });
}
