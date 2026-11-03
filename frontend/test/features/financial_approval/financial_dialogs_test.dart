import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/widgets/budget_details_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/budget_email_share_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/budget_whatsapp_share_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/duplicate_budget_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/payment_email_share_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/payment_request_details_dialog.dart';
import 'package:frontend/features/financial_approval/widgets/payment_whatsapp_share_dialog.dart';

Widget _buildTestApp({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: const Locale('ar'),
        child: Scaffold(body: child),
      ),
    ),
  );
}

PaymentRequestModel _createSamplePayment() {
  return PaymentRequestModel.fromJson({
    'payment_id': 101,
    'payment_code': 'PAY-2026-000101',
    'title': 'دفعة مقدمة للمورد',
    'import_file_id': 12,
    'import_file_code': 'IMP-2026-0012',
    'po_id': 5,
    'supplier_id': 3,
    'supplier_name': 'Shanghai Machinery Co.',
    'project_id': 1,
    'payment_type': 'Advance Payment',
    'requested_amount': 25000.0,
    'currency_code': 'USD',
    'exchange_rate': 49.00,
    'requested_amount_egp': 1225000.0,
    'advance_percentage': 30.0,
    'smart_task_code': 'TASK-2026-0050',
    'due_date': '2026-11-01',
    'request_date': '2026-10-25',
    'status': 'Approved',
    'beneficiary_name': 'Shanghai Machinery Co.',
    'bank_name': 'Bank of China',
    'swift_code': 'BKCHCN2S',
    'iban_account_no': 'CN66BKCH000011112222',
    'is_active': true,
    'created_at': '2026-10-25T10:00:00',
    'updated_at': '2026-10-25T12:00:00',
  });
}

ImportBudgetModel _createSampleBudget() {
  return ImportBudgetModel.fromJson({
    'budget_id': 55,
    'budget_code': 'BGT-2026-000055',
    'title': 'ميزانية استيراد خط إنتاج',
    'import_file_id': 12,
    'import_file_code': 'IMP-2026-0012',
    'po_id': 5,
    'fob_amount': 50000.0,
    'fob_currency': 'USD',
    'fob_fx_rate': 49.00,
    'fob_egp': 2450000.0,
    'freight_amount': 3000.0,
    'freight_currency': 'USD',
    'freight_fx_rate': 49.00,
    'freight_egp': 147000.0,
    'customs_duty_egp': 250000.0,
    'vat_egp': 343000.0,
    'clearance_cost_egp': 35000.0,
    'other_expenses_egp': 15000.0,
    'total_budget_egp': 3245000.0,
    'budget_status': 'Draft',
    'created_by': 'Admin',
    'created_at': '2026-10-28T09:00:00',
    'updated_at': '2026-10-28T09:00:00',
    'is_active': true,
  });
}

BudgetPrefillModel _createSamplePrefill() {
  return BudgetPrefillModel(
    importFileId: 12,
    importFileCode: 'IMP-2026-0012',
    importFileTitle: 'شحنة ماكينات تصنيع',
    incoterm: 'FOB',
    supplierId: 3,
    supplierName: 'Shanghai Machinery Co.',
    paymentTermsSummary: '30% Advance, 70% against BL',
    linkedPos: [],
    totalInvoiceAmount: 50000.0,
    invoiceCurrency: 'USD',
    totalInvoiceAmountEgp: 2450000.0,
    estimatedFreightCost: 3000.0,
    freightCurrency: 'USD',
    estimatedFreightCostEgp: 147000.0,
    estimatedCustomsDutiesEgp: 250000.0,
    estimatedClearanceFeesEgp: 35000.0,
    estimatedGrandTotalEgp: 3245000.0,
    exchangeRate: 49.00,
  );
}

void main() {
  group('Isolated Financial Dialogs Component Tests', () {
    testWidgets('DuplicateBudgetDialog renders details and triggers cancel callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool cancelCalled = false;
      final sampleBudget = _createSampleBudget();

      await tester.pumpWidget(
        _buildTestApp(
          child: DuplicateBudgetDialog(
            existingBudget: sampleBudget,
            onCancelSelection: () => cancelCalled = true,
            onReviewSyncLiveCosts: () {},
            onViewAndPrintBudget: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BGT-2026-000055'), findsWidgets);
      expect(find.textContaining('ميزانية استيراد خط إنتاج'), findsWidgets);

      final cancelBtn = find.text('إلغاء التحديد');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
      expect(cancelCalled, isTrue);
    });

    testWidgets('DuplicateBudgetDialog triggers review and sync callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool reviewSyncCalled = false;
      final sampleBudget = _createSampleBudget();

      await tester.pumpWidget(
        _buildTestApp(
          child: DuplicateBudgetDialog(
            existingBudget: sampleBudget,
            onCancelSelection: () {},
            onReviewSyncLiveCosts: () => reviewSyncCalled = true,
            onViewAndPrintBudget: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final syncBtn = find.byIcon(Icons.sync);
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();
      expect(reviewSyncCalled, isTrue);
    });

    testWidgets('DuplicateBudgetDialog triggers view and print callback', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool viewPrintCalled = false;
      final sampleBudget = _createSampleBudget();

      await tester.pumpWidget(
        _buildTestApp(
          child: DuplicateBudgetDialog(
            existingBudget: sampleBudget,
            onCancelSelection: () {},
            onReviewSyncLiveCosts: () {},
            onViewAndPrintBudget: () => viewPrintCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final printBtn = find.byIcon(Icons.print);
      expect(printBtn, findsOneWidget);
      await tester.tap(printBtn);
      await tester.pumpAndSettle();
      expect(viewPrintCalled, isTrue);
    });

    testWidgets('PaymentWhatsAppShareDialog renders preview text and copy action', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final samplePayment = _createSamplePayment();

      await tester.pumpWidget(
        _buildTestApp(
          child: PaymentWhatsAppShareDialog(payment: samplePayment),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PAY-2026-000101'), findsWidgets);
      expect(find.byIcon(Icons.copy), findsWidgets);
      expect(find.byIcon(Icons.open_in_new), findsWidgets);
    });

    testWidgets('PaymentEmailShareDialog renders email fields and actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final samplePayment = _createSamplePayment();

      await tester.pumpWidget(
        _buildTestApp(
          child: PaymentEmailShareDialog(payment: samplePayment),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PAY-2026-000101'), findsWidgets);
      expect(find.byIcon(Icons.email), findsWidgets);
      expect(find.byIcon(Icons.copy), findsWidgets);
      expect(find.byIcon(Icons.send), findsWidgets);
    });

    testWidgets('BudgetWhatsAppShareDialog renders budget details and send action', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleBudget = _createSampleBudget();

      await tester.pumpWidget(
        _buildTestApp(
          child: BudgetWhatsAppShareDialog(budget: sampleBudget),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BGT-2026-000055'), findsWidgets);
      expect(find.byIcon(Icons.copy), findsWidgets);
      expect(find.byIcon(Icons.open_in_new), findsWidgets);
    });

    testWidgets('BudgetEmailShareDialog renders budget email text and dispatch action', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleBudget = _createSampleBudget();

      await tester.pumpWidget(
        _buildTestApp(
          child: BudgetEmailShareDialog(budget: sampleBudget),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BGT-2026-000055'), findsWidgets);
      expect(find.byIcon(Icons.email), findsWidgets);
      expect(find.byIcon(Icons.copy), findsWidgets);
      expect(find.byIcon(Icons.send), findsWidgets);
    });

    testWidgets('PaymentRequestDetailsDialog renders details and responds to action', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool swiftNavTriggered = false;
      final samplePayment = _createSamplePayment();

      await tester.pumpWidget(
        _buildTestApp(
          child: PaymentRequestDetailsDialog(
            payment: samplePayment,
            onOpenSwiftReconciliation: () => swiftNavTriggered = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('PAY-2026-000101'), findsWidgets);
      expect(find.textContaining('Shanghai Machinery Co.'), findsWidgets);

      // Verify SWIFT reconciliation trigger button
      final swiftReconcileBtn = find.byIcon(Icons.auto_awesome);
      expect(swiftReconcileBtn, findsOneWidget);
      await tester.tap(swiftReconcileBtn);
      await tester.pumpAndSettle();
      expect(swiftNavTriggered, isTrue);
    });

    testWidgets('BudgetDetailsDialog renders budget breakdown and total amount', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleBudget = _createSampleBudget();
      final samplePrefill = _createSamplePrefill();

      await tester.pumpWidget(
        _buildTestApp(
          child: BudgetDetailsDialog(
            budget: sampleBudget,
            prefill: samplePrefill,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BGT-2026-000055'), findsWidgets);
      expect(find.textContaining('ميزانية استيراد خط إنتاج'), findsWidgets);
      expect(find.textContaining('3245000.00 EGP'), findsWidgets);
      expect(find.byIcon(Icons.print), findsWidgets);
      expect(find.byIcon(Icons.table_chart), findsWidgets);
      expect(find.byIcon(Icons.chat), findsWidgets);
    });
  });
}
