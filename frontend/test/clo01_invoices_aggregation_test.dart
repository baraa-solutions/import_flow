import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'helpers/localized_app.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/features/financial_settlement/models/invoices_aggregation_model.dart';
import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';
import 'package:frontend/features/financial_settlement/providers/financial_settlement_provider.dart';
import 'package:frontend/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart';

class _MockFinancialSettlementNotifier extends FinancialSettlementNotifier {
  final InvoicesAggregationResponseModel mockAggregation;
  final ConfirmInvoicesSettlementResponseModel mockConfirmResponse;

  _MockFinancialSettlementNotifier(this.mockAggregation, this.mockConfirmResponse)
      : super(Dio()) {
    state = const AsyncValue.data(<LandedCostSettlementModel>[]);
  }

  @override
  Future<void> fetchSettlements({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int? skip, int? limit}) async {
    state = const AsyncValue.data(<LandedCostSettlementModel>[]);
  }

  @override
  Future<InvoicesAggregationResponseModel> fetchInvoicesAggregation(int importFileId) async {
    return mockAggregation;
  }

  @override
  Future<ConfirmInvoicesSettlementResponseModel> confirmInvoicesSettlement(
    ConfirmInvoicesSettlementRequestModel request,
  ) async {
    return mockConfirmResponse;
  }
}

void main() {
  group('CLO-01: Invoices Aggregation Models Serialization Tests', () {
    test('AggregatedInvoiceItemModel parses from JSON and serializes correctly', () {
      final json = {
        'invoice_id': 'COMM-1',
        'invoice_no': 'INV-DE-8821',
        'invoice_date': '2026-09-18',
        'party_type': 'SUPPLIER',
        'party_type_ar': 'المورد الأجنبي',
        'party_name': 'Bavaria Chemical GmbH',
        'category': 'Commercial Goods',
        'category_ar': 'قيمة البضاعة التجارية (FOB)',
        'currency': 'USD',
        'exchange_rate': 48.5,
        'amount_fc': 20000.0,
        'amount_egp': 970000.0,
        'paid_amount_egp': 970000.0,
        'remaining_amount_egp': 0.0,
        'payment_status': 'PAID',
        'payment_reference': 'SWIFT-DE-001',
        'withholding_tax_rate': 0.0,
        'withholding_tax_amount_egp': 0.0,
        'net_payable_egp': 970000.0,
        'source_module': 'Commercial Invoice',
        'notes': 'Goods invoice',
      };

      final model = AggregatedInvoiceItemModel.fromJson(json);

      expect(model.invoiceId, 'COMM-1');
      expect(model.invoiceNo, 'INV-DE-8821');
      expect(model.partyType, 'SUPPLIER');
      expect(model.amountEgp, 970000.0);
      expect(model.paymentStatus, 'PAID');

      final serialized = model.toJson();
      expect(serialized['invoice_no'], 'INV-DE-8821');
      expect(serialized['amount_egp'], 970000.0);
    });

    test('InvoicesAggregationResponseModel parses from JSON correctly', () {
      final json = {
        'import_file_id': 10,
        'import_file_code': 'IMP-2026-0010',
        'supplier_name': 'Bavaria Chemical GmbH',
        'currency': 'USD',
        'exchange_rate': 48.5,
        'total_invoices_count': 3,
        'total_amount_egp': 1100000.0,
        'total_paid_egp': 1050000.0,
        'total_remaining_egp': 50000.0,
        'total_withholding_tax_egp': 1000.0,
        'settlement_readiness_percent': 95.5,
        'financial_settlement_status': 'PENDING_SETTLEMENT',
        'parties_summary': [
          {
            'party_type': 'SUPPLIER',
            'party_type_ar': 'المورد الأجنبي',
            'party_name': 'Bavaria Chemical GmbH',
            'invoices_count': 1,
            'total_egp': 970000.0,
            'paid_egp': 970000.0,
            'remaining_egp': 0.0,
          },
        ],
        'invoices': [
          {
            'invoice_id': 'COMM-1',
            'invoice_no': 'INV-DE-8821',
            'party_type': 'SUPPLIER',
            'party_type_ar': 'المورد الأجنبي',
            'party_name': 'Bavaria Chemical GmbH',
            'category': 'Commercial Goods',
            'category_ar': 'قيمة البضاعة',
            'currency': 'USD',
            'exchange_rate': 48.5,
            'amount_fc': 20000.0,
            'amount_egp': 970000.0,
            'paid_amount_egp': 970000.0,
            'remaining_amount_egp': 0.0,
            'payment_status': 'PAID',
          },
        ],
        'unsettled_warnings': ['مستحق غير مسدد بقيمة 50,000 جنيه'],
      };

      final model = InvoicesAggregationResponseModel.fromJson(json);

      expect(model.importFileId, 10);
      expect(model.importFileCode, 'IMP-2026-0010');
      expect(model.totalInvoicesCount, 3);
      expect(model.totalAmountEgp, 1100000.0);
      expect(model.totalPaidEgp, 1050000.0);
      expect(model.totalRemainingEgp, 50000.0);
      expect(model.settlementReadinessPercent, 95.5);
      expect(model.partiesSummary.length, 1);
      expect(model.invoices.length, 1);
      expect(model.unsettledWarnings.length, 1);
    });

    test('ConfirmInvoicesSettlementRequest & Response parse JSON correctly', () {
      final req = ConfirmInvoicesSettlementRequestModel(
        importFileId: 10,
        settledBy: 'Ahmed Kamal',
        settlementNotes: 'All verified',
      );

      final reqJson = req.toJson();
      expect(reqJson['import_file_id'], 10);
      expect(reqJson['settled_by'], 'Ahmed Kamal');

      final resJson = {
        'success': true,
        'import_file_id': 10,
        'import_file_code': 'IMP-2026-0010',
        'financial_settlement_status': 'INVOICES_SETTLED',
        'financial_settlement_date': '2026-09-18',
        'invoices_count': 3,
        'total_settled_egp': 1100000.0,
        'progress_percent': 98.5,
        'current_stage': 'Stage 9: Landed Cost & File Closure',
        'current_module': 'CLO-01 Final Settlement Invoices Aggregation',
        'next_task_code': 'TSK-0902-10',
        'next_task_title': 'احتساب تكلفة الوصول الفعلية وتوزيعها على الأصناف (CLO-02)',
        'message': 'تم اعتماد تسوية فواتير الشحنة بنجاح',
      };

      final res = ConfirmInvoicesSettlementResponseModel.fromJson(resJson);
      expect(res.success, true);
      expect(res.financialSettlementStatus, 'INVOICES_SETTLED');
      expect(res.progressPercent, 98.5);
      expect(res.nextTaskCode, 'TSK-0902-10');
    });
  });

  group('CLO-01: FinalSettlementInvoicesDialog Widget Tests', () {
    late InvoicesAggregationResponseModel mockAggregation;
    late ConfirmInvoicesSettlementResponseModel mockConfirmResponse;

    setUp(() {
      mockAggregation = InvoicesAggregationResponseModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-0101',
        supplierName: 'Bavaria Chemical GmbH',
        currency: 'USD',
        exchangeRate: 48.5,
        totalInvoicesCount: 2,
        totalAmountEgp: 1020000.0,
        totalPaidEgp: 1020000.0,
        totalRemainingEgp: 0.0,
        totalWithholdingTaxEgp: 1200.0,
        settlementReadinessPercent: 100.0,
        financialSettlementStatus: 'PENDING_SETTLEMENT',
        partiesSummary: [
          InvoicesPartySummaryModel(
            partyType: 'SUPPLIER',
            partyTypeAr: 'المورد الأجنبي',
            partyName: 'Bavaria Chemical GmbH',
            invoicesCount: 1,
            totalEgp: 970000.0,
            paidEgp: 970000.0,
            remainingEgp: 0.0,
          ),
          InvoicesPartySummaryModel(
            partyType: 'CARRIER',
            partyTypeAr: 'وكيل الشحن',
            partyName: 'MSC Mediterranean Shipping',
            invoicesCount: 1,
            totalEgp: 50000.0,
            paidEgp: 50000.0,
            remainingEgp: 0.0,
          ),
        ],
        invoices: [
          AggregatedInvoiceItemModel(
            invoiceId: 'COMM-1',
            invoiceNo: 'INV-DE-8821',
            partyType: 'SUPPLIER',
            partyTypeAr: 'المورد الأجنبي',
            partyName: 'Bavaria Chemical GmbH',
            category: 'Commercial Goods',
            categoryAr: 'قيمة البضاعة التجارية (FOB)',
            currency: 'USD',
            exchangeRate: 48.5,
            amountFc: 20000.0,
            amountEgp: 970000.0,
            paidAmountEgp: 970000.0,
            remainingAmountEgp: 0.0,
            paymentStatus: 'PAID',
            paymentReference: 'SWIFT-DE-001',
            sourceModule: 'Commercial Invoice',
          ),
          AggregatedInvoiceItemModel(
            invoiceId: 'FRT-1',
            invoiceNo: 'BKG-MSC-99',
            partyType: 'CARRIER',
            partyTypeAr: 'وكيل الشحن',
            partyName: 'MSC Mediterranean Shipping',
            category: 'Ocean Freight',
            categoryAr: 'نولون الشحن الدولي',
            currency: 'USD',
            exchangeRate: 48.5,
            amountFc: 1030.93,
            amountEgp: 50000.0,
            paidAmountEgp: 50000.0,
            remainingAmountEgp: 0.0,
            paymentStatus: 'PAID',
            paymentReference: 'MSCU881921',
            sourceModule: 'Freight Booking',
          ),
        ],
        unsettledWarnings: [],
      );

      mockConfirmResponse = ConfirmInvoicesSettlementResponseModel(
        success: true,
        importFileId: 101,
        importFileCode: 'IMP-2026-0101',
        financialSettlementStatus: 'INVOICES_SETTLED',
        financialSettlementDate: '2026-09-18',
        invoicesCount: 2,
        totalSettledEgp: 1020000.0,
        progressPercent: 98.5,
        currentStage: 'Stage 9: Landed Cost & File Closure',
        currentModule: 'CLO-01 Final Settlement Invoices Aggregation',
        nextTaskCode: 'TSK-0902-101',
        nextTaskTitle: 'احتساب تكلفة الوصول الفعلية وتوزيعها على الأصناف (CLO-02)',
        message: 'تم اعتماد تسوية فواتير الشحنة بنجاح',
      );
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          financialSettlementProvider.overrideWith(
            (ref) => _MockFinancialSettlementNotifier(mockAggregation, mockConfirmResponse),
          ),
        ],
        child: localizedApp(
          locale: AppLocales.arabic,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('openDialogBtn'),
                  onPressed: () => FinalSettlementInvoicesDialog.show(
                    ctx,
                    importFileId: 101,
                    importFileCode: 'IMP-2026-0101',
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders dialog header, KPI strip, and action button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openDialogBtn')));
      await tester.pumpAndSettle();

      // Check header title
      expect(find.textContaining('CLO-01: Multi-Party Invoices Aggregation'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0101'), findsWidgets);

      // Check KPI Metric Strip
      expect(find.text('إجمالي فواتير ومصروفات الشحنة'), findsOneWidget);
      expect(find.text('إجمالي المبالغ المسددة'), findsOneWidget);
      expect(find.text('المتبقي المطلوب سداده'), findsOneWidget);
      expect(find.text('نسبة مطابقة السداد'), findsOneWidget);

      // Check Invoices rendered in table
      expect(find.text('INV-DE-8821'), findsOneWidget);
      expect(find.text('BKG-MSC-99'), findsOneWidget);
      expect(find.text('Bavaria Chemical GmbH'), findsWidgets);

      // Check confirmation button exists
      expect(find.byKey(const Key('confirmInvoicesSettlementBtn')), findsOneWidget);
    });

    testWidgets('clicking confirm button triggers settlement submission', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openDialogBtn')));
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const Key('confirmInvoicesSettlementBtn'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify snackbar feedback
      expect(find.text('تم اعتماد تسوية فواتير الشحنة بنجاح'), findsOneWidget);
    });
  });
}
