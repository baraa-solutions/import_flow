import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/clearance_expense_invoice_model.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/clearance_expenses_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CL-05: Clearance Expense Invoice Model & Serialization Tests', () {
    test('ClearanceExpenseInvoiceModel parses and serializes correctly', () {
      final json = {
        'invoice_id': 101,
        'invoice_code': 'CEXP-2026-0101',
        'import_file_id': 95,
        'customs_clearance_id': 504,
        'invoice_number': 'INV-BROKER-9988',
        'invoice_date': '2026-09-18',
        'provider_id': 12,
        'provider_name': 'شركة الصفا للتخليص الجمركي',
        'expense_category': 'Customs Broker Fees (أتعاب التخليص الجمركي)',
        'currency': 'EGP',
        'amount_fx': 15000.00,
        'exchange_rate': 1.0,
        'amount_egp': 15000.00,
        'vat_included': true,
        'vat_amount': 2100.00,
        'wht_deducted': true,
        'wht_amount': 450.00,
        'net_payable_egp': 16650.00,
        'payment_status': 'Unpaid',
        'payment_ref': 'TX-REF-001',
        'document_url': '/invoices/inv_9988.pdf',
        'allocation_rule': 'Equal',
        'notes': 'أتعاب التخليص شاملة الإقرار 46 والمعاينة',
        'is_verified': true,
        'is_active': true,
        'created_at': '2026-09-18T14:15:00Z',
        'updated_at': '2026-09-18T14:15:00Z',
      };

      final invoice = ClearanceExpenseInvoiceModel.fromJson(json);

      expect(invoice.invoiceId, 101);
      expect(invoice.invoiceCode, 'CEXP-2026-0101');
      expect(invoice.importFileId, 95);
      expect(invoice.customsClearanceId, 504);
      expect(invoice.invoiceNumber, 'INV-BROKER-9988');
      expect(invoice.invoiceDate, '2026-09-18');
      expect(invoice.providerId, 12);
      expect(invoice.providerName, 'شركة الصفا للتخليص الجمركي');
      expect(invoice.expenseCategory, 'Customs Broker Fees (أتعاب التخليص الجمركي)');
      expect(invoice.amountEgp, 15000.00);
      expect(invoice.vatIncluded, true);
      expect(invoice.vatAmount, 2100.00);
      expect(invoice.whtDeducted, true);
      expect(invoice.whtAmount, 450.00);
      expect(invoice.netPayableEgp, 16650.00);
      expect(invoice.paymentStatus, 'Unpaid');
      expect(invoice.allocationRule, 'Equal');

      final serialized = invoice.toJson();
      expect(serialized['invoice_code'], 'CEXP-2026-0101');
      expect(serialized['invoice_number'], 'INV-BROKER-9988');
      expect(serialized['amount_egp'], 15000.00);
      expect(serialized['vat_amount'], 2100.00);
      expect(serialized['wht_amount'], 450.00);
      expect(serialized['net_payable_egp'], 16650.00);
      expect(serialized['allocation_rule'], 'Equal');
    });

    test('ClearanceInvoicesSummaryModel parses and serializes correctly', () {
      final json = {
        'import_file_id': 95,
        'invoices_count': 2,
        'total_amount_egp': 25000.00,
        'total_vat_egp': 2100.00,
        'total_wht_egp': 450.00,
        'net_payable_egp': 26650.00,
        'total_clearance_fees_egp': 15000.00,
        'total_port_dues_egp': 7500.00,
        'total_handling_stevedoring_egp': 2500.00,
        'total_other_expenses_egp': 0.0,
        'invoices': [
          {
            'invoice_id': 101,
            'invoice_code': 'CEXP-2026-0101',
            'import_file_id': 95,
            'invoice_number': 'INV-101',
            'invoice_date': '2026-09-18',
            'provider_name': 'شركة الصفا',
            'expense_category': 'Customs Broker Fees (أتعاب التخليص الجمركي)',
            'amount_egp': 15000.00,
            'net_payable_egp': 16650.00,
            'created_at': '2026-09-18T14:00:00Z',
            'updated_at': '2026-09-18T14:00:00Z',
          },
        ],
      };

      final summary = ClearanceInvoicesSummaryModel.fromJson(json);

      expect(summary.importFileId, 95);
      expect(summary.invoicesCount, 2);
      expect(summary.totalAmountEgp, 25000.00);
      expect(summary.totalVatEgp, 2100.00);
      expect(summary.totalWhtEgp, 450.00);
      expect(summary.netPayableEgp, 26650.00);
      expect(summary.totalClearanceFeesEgp, 15000.00);
      expect(summary.totalPortDuesEgp, 7500.00);
      expect(summary.totalHandlingStevedoringEgp, 2500.00);
      expect(summary.invoices.length, 1);
      expect(summary.invoices[0].invoiceCode, 'CEXP-2026-0101');

      final serialized = summary.toJson();
      expect(serialized['invoices_count'], 2);
      expect(serialized['net_payable_egp'], 26650.00);
      expect((serialized['invoices'] as List).length, 1);
    });

    test('CustomsClearanceModel and ImportFileModel include CL-05 aggregate fields', () {
      final clearanceJson = {
        'customs_clearance_id': 504,
        'clearance_code': 'CLR-2026-0504',
        'import_file_id': 95,
        'total_clearance_expenses_egp': 26650.00,
        'total_port_expenses_egp': 7500.00,
        'total_handling_expenses_egp': 2500.00,
        'clearance_invoices_count': 3,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final rec = CustomsClearanceModel.fromJson(clearanceJson);
      expect(rec.totalClearanceExpensesEgp, 26650.00);
      expect(rec.totalPortExpensesEgp, 7500.00);
      expect(rec.totalHandlingExpensesEgp, 2500.00);
      expect(rec.clearanceInvoicesCount, 3);

      final recSerialized = rec.toJson();
      expect(recSerialized['total_clearance_expenses_egp'], 26650.00);
      expect(recSerialized['total_port_expenses_egp'], 7500.00);
      expect(recSerialized['total_handling_expenses_egp'], 2500.00);
      expect(recSerialized['clearance_invoices_count'], 3);

      final fileJson = {
        'import_file_id': 95,
        'import_file_code': 'IMP-2026-0095',
        'total_clearance_expenses_egp': 26650.00,
        'clearance_invoices_status': 'COMPLETED',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final file = ImportFileModel.fromJson(fileJson);
      expect(file.totalClearanceExpensesEgp, 26650.00);
      expect(file.clearanceInvoicesStatus, 'COMPLETED');

      final fileSerialized = file.toJson();
      expect(fileSerialized['total_clearance_expenses_egp'], 26650.00);
      expect(fileSerialized['clearance_invoices_status'], 'COMPLETED');
    });
  });

  group('CL-05: ClearanceExpensesDialog Widget Tests', () {
    testWidgets('Renders ClearanceExpensesDialog with KPIs, actions, and toggle form', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        customFileNumber: 'Industrial Machinery',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        portOfDischarge: 'El Dekheila Port',
        deliveryOrderNo: 'DO-2026-HAPAG-5511',
        form46No: 'DEC-2026-DKH-5511',
        currentModule: 'Phase 7 - Customs Clearance & Release',
        currentStage: 'Customs Clearance Invoices (تسجيل فواتير ومصروفات المخلص والميناء)',
        progressPercent: 96.0,
        nextAction: 'تسجيل فواتير ومصروفات المخلص والميناء (CL-05)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T14:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: ClearanceExpensesDialog(
                  file: sampleFile,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('تسجيل فواتير المخلص ومصاريف التخليص والميناء (CL-05)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0095'), findsWidgets);

      // Verify KPI Metrics
      expect(find.text('إجمالي صافي الفواتير'), findsOneWidget);
      expect(find.text('أتعاب التخليص الجمركي'), findsOneWidget);
      expect(find.text('نولون ورسوم الميناء'), findsOneWidget);
      expect(find.text('العتالة والشحن والتفريغ'), findsOneWidget);

      // Verify Action Bar
      expect(find.byKey(const Key('addClearanceInvoiceBtn')), findsOneWidget);
      expect(find.text('إضافة فاتورة جديدة'), findsOneWidget);

      // Toggle Add Form
      await tester.tap(find.byKey(const Key('addClearanceInvoiceBtn')));
      await tester.pumpAndSettle();

      // Form is now visible
      expect(find.text('تسجيل فاتورة مصروفات جديدة'), findsOneWidget);
      expect(find.byKey(const Key('invoiceProviderNameField')), findsOneWidget);
      expect(find.byKey(const Key('invoiceNumberField')), findsOneWidget);
      expect(find.byKey(const Key('invoiceCategoryDropdown')), findsOneWidget);
      expect(find.byKey(const Key('invoiceAllocationRuleDropdown')), findsOneWidget);
      expect(find.byKey(const Key('invoiceAmountField')), findsOneWidget);
      expect(find.byKey(const Key('invoiceNotesField')), findsOneWidget);
      expect(find.byKey(const Key('saveClearanceInvoiceBtn')), findsOneWidget);

      // Enter test values into the form
      await tester.enterText(find.byKey(const Key('invoiceProviderNameField')), 'شركة النصر للشحن');
      await tester.enterText(find.byKey(const Key('invoiceNumberField')), 'INV-2026-001');
      await tester.enterText(find.byKey(const Key('invoiceAmountField')), '8500.00');
      await tester.pumpAndSettle();

      expect(find.text('شركة النصر للشحن'), findsOneWidget);
      expect(find.text('INV-2026-001'), findsOneWidget);
      expect(find.text('8500.00'), findsOneWidget);

      // Verify Footer note
      expect(
        find.text('المصاريف تُرحَّل تلقائياً إلى كشف حساب تكلفة وصول الشحنة الإجمالية'),
        findsOneWidget,
      );
    });
  });
}
