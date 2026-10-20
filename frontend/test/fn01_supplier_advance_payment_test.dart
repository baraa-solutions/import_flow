import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'helpers/localized_app.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/widgets/supplier_advance_payment_dialog.dart';

void main() {
  group('FN-01: Supplier Advance Payment Request Tests', () {
    test(
        'PaymentRequestModel handles advance_percentage and smart_task_code serialization',
        () {
      final json = {
        'payment_id': 101,
        'payment_code': 'PAY-2026-000101',
        'title': 'Advance Payment 30% - IMP-2026-0004 - Global Steel Co',
        'import_file_id': 4,
        'po_id': 12,
        'supplier_id': 8,
        'supplier_name': 'Global Steel Co',
        'project_id': 2,
        'payment_type': 'Advance Payment',
        'requested_amount': 30000.0,
        'currency_code': 'USD',
        'exchange_rate': 50.0,
        'requested_amount_egp': 1500000.0,
        'advance_percentage': 30.0,
        'smart_task_code': 'TASK-2026-0088',
        'due_date': '2026-09-25',
        'request_date': '2026-09-17',
        'status': 'Pending Approval',
        'beneficiary_name': 'Global Steel Co',
        'bank_name': 'Industrial & Commercial Bank',
        'swift_code': 'ICBKCNBJ',
        'iban_account_no': 'CN001122334455',
        'is_active': true,
        'created_at': '2026-09-17T12:00:00',
        'updated_at': '2026-09-17T12:00:00',
        'import_file_code': 'IMP-2026-0004',
      };

      final model = PaymentRequestModel.fromJson(json);

      expect(model.paymentId, 101);
      expect(model.paymentCode, 'PAY-2026-000101');
      expect(model.advancePercentage, 30.0);
      expect(model.smartTaskCode, 'TASK-2026-0088');
      expect(model.requestedAmount, 30000.0);
      expect(model.requestedAmountEgp, 1500000.0);
      expect(model.status, 'Pending Approval');
      expect(model.swiftCode, 'ICBKCNBJ');
      expect(model.ibanAccountNo, 'CN001122334455');

      final serialized = model.toJson();
      expect(serialized['advance_percentage'], 30.0);
      expect(serialized['smart_task_code'], 'TASK-2026-0088');
      expect(serialized['status'], 'Pending Approval');
      expect(serialized['requested_amount_egp'], 1500000.0);
    });

    test('Advance payment percentage math and EGP conversions', () {
      const fobTotal = 100000.0;
      const rate = 50.0;

      final testCases = [
        {'pct': 10.0, 'expectedForeign': 10000.0, 'expectedEgp': 500000.0},
        {'pct': 20.0, 'expectedForeign': 20000.0, 'expectedEgp': 1000000.0},
        {'pct': 30.0, 'expectedForeign': 30000.0, 'expectedEgp': 1500000.0},
        {'pct': 50.0, 'expectedForeign': 50000.0, 'expectedEgp': 2500000.0},
        {'pct': 100.0, 'expectedForeign': 100000.0, 'expectedEgp': 5000000.0},
        {'pct': 25.5, 'expectedForeign': 25500.0, 'expectedEgp': 1275000.0},
      ];

      for (final tc in testCases) {
        final pct = tc['pct'] as double;
        final foreignAmt = fobTotal * (pct / 100.0);
        final egpAmt = foreignAmt * rate;

        expect(foreignAmt, tc['expectedForeign']);
        expect(egpAmt, tc['expectedEgp']);
      }
    });

    testWidgets(
        'SupplierAdvancePaymentDialog renders correctly and calculates percentage amounts',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: const Scaffold(
              body: SupplierAdvancePaymentDialog(
                importFileId: 4,
                importFileCode: 'IMP-2026-0004',
                fileTitle: 'PET Raw Materials',
                supplierId: 8,
                supplierName: 'Sinopec Plastics Global',
                projectId: 2,
                totalAmountForeign: 80000.0,
                currency: 'USD',
              ),
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header and badges (dialog localizes via Localizations.localeOf -> en_US in tests)
      expect(find.text('Supplier Advance Payment (FN-01)'), findsOneWidget);
      expect(find.text('IMP-2026-0004'), findsOneWidget);
      expect(find.textContaining('Sinopec Plastics Global'), findsWidgets);

      // Verify choice chips for percentages
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Verify workflow informational banner
      expect(find.textContaining('STEP_04'), findsWidgets);
      expect(find.textContaining('Finance Officer'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(
          find.text('Issue Payment Request & Notify Finance'), findsOneWidget);

      // No fallback FX rate: the rate field starts empty and must be entered.
      await tester.enterText(
          find.byKey(const ValueKey('advanceExchangeRateField')), '50');
      await tester.pump();

      // Tap 50% ChoiceChip and check recalculation
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      // 50% of 80,000 USD is 40000.00
      expect(find.text('40000.00'), findsOneWidget);
      // EGP equivalent: 40,000 * 50 = 2,000,000.00
      expect(find.textContaining('2000000.00 EGP'), findsOneWidget);

      // Tap 10% ChoiceChip and check recalculation
      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();

      // 10% of 80,000 USD is 8000.00
      expect(find.text('8000.00'), findsOneWidget);
      // EGP equivalent: 8,000 * 50 = 400,000.00
      expect(find.textContaining('400000.00 EGP'), findsOneWidget);
    });
  });
}
