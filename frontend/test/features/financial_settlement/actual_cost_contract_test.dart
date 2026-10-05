import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_settlement/models/actual_landed_cost_model.dart';
import 'package:frontend/features/financial_settlement/models/invoices_aggregation_model.dart';

void main() {
  // Shape of ActualLandedCostCalculationResponse (modules/financial_settlement/schemas.py).
  final backendSample = <String, dynamic>{
    'import_file_id': 44,
    'import_file_code': 'IMP-2026-0044',
    'supplier_name': 'ACME',
    'currency': 'USD',
    'exchange_rate': 48.25,
    'actual_total_fob_egp': 482500.0,
    'actual_total_expenses_egp': 90000.5,
    'estimated_total_landed_cost_egp': 560000.0,
    'actual_total_landed_cost_egp': 572500.5,
    'landed_variance_egp': 12500.5,
    'landed_variance_pct': 2.23,
    'actual_markup_factor': 1.186,
    'variance_status': 'OVER_BUDGET',
    'variance_status_ar': 'تجاوز',
    'reconciliation_difference_egp': 0.02,
    'messages': [
      {'code': 'SETTLEMENT_UNPAID_INVOICE', 'params': {'party_name': 'Maersk', 'amount': 1500.0, 'invoice_no': 'INV-9'}, 'severity': 'warning'},
      {'code': 'SOME_NEW_CODE'},
    ],
    'categories_breakdown': [
      {'category': 'Freight', 'category_ar': 'نولون', 'estimated_egp': 100.0, 'actual_egp': 120.0, 'variance_egp': 20.0, 'variance_pct': 20.0, 'invoices_count': 2},
    ],
    'items_breakdown': [
      {
        'line_no': 1,
        'item_code': 'ITM-1',
        'item_name': 'Valve',
        'hs_code': '8481.80',
        'qty': 10.0,
        'fob_unit_egp': 100.0,
        'fob_total_egp': 1000.0,
        'allocated_customs_duty_egp': 50.0,
        'allocated_vat_egp': 20.0,
        'total_actual_landed_cost_egp': 1200.0,
        'actual_unit_landed_cost_egp': 120.0,
        'actual_markup_factor': 1.2,
        'estimated_unit_landed_cost_egp': 110.0,
        'unit_cost_variance_pct': 9.09,
        'item_variance_status': 'INCREASED',
      },
    ],
  };

  test('parses the backend field names (no more zeros)', () {
    final m = ActualLandedCostCalculationResponseModel.fromJson(backendSample);
    expect(m.fxRate, 48.25);
    expect(m.totalFobEgp, 482500.0);
    expect(m.totalActualExpensesEgp, 90000.5);
    expect(m.reconciliationDifferenceEgp, 0.02);
    expect(m.varianceStatus, 'UNFAVORABLE');
    final cat = m.categoriesBreakdown.single;
    expect(cat.estimatedAmountEgp, 100.0);
    expect(cat.actualAmountEgp, 120.0);
    expect(cat.varianceStatus, 'UNFAVORABLE');
    final item = m.itemsBreakdown.single;
    expect(item.itemNameAr, 'Valve');
    expect(item.quantity, 10.0);
    expect(item.allocatedCustomsDutiesEgp, 50.0);
    expect(item.markupFactor, 1.2);
    expect(item.varianceStatus, 'UNFAVORABLE');
  });

  test('messages are parsed with code, params and severity', () {
    final m = ActualLandedCostCalculationResponseModel.fromJson(backendSample);
    expect(m.messages.length, 2);
    expect(m.messages.first.code, 'SETTLEMENT_UNPAID_INVOICE');
    expect(m.messages.first.params['invoice_no'], 'INV-9');
    expect(m.messages.last.severity, 'warning');
  });

  test('legacy client names still parse and messages default to empty', () {
    final m = ActualLandedCostCalculationResponseModel.fromJson({
      'fx_rate': 50.0,
      'total_fob_egp': 10.0,
      'total_actual_expenses_egp': 5.0,
    });
    expect(m.fxRate, 50.0);
    expect(m.totalFobEgp, 10.0);
    expect(m.totalActualExpensesEgp, 5.0);
    expect(m.messages, isEmpty);
  });

  test('aggregation response keeps messages and legacy warnings', () {
    final m = InvoicesAggregationResponseModel.fromJson({
      'import_file_id': 1,
      'import_file_code': 'IMP-1',
      'supplier_name': 'S',
      'unsettled_warnings': ['legacy'],
      'messages': [
        {'code': 'PAYMENT_STATUS_UNKNOWN', 'params': {'invoice_no': 'X'}}
      ],
    });
    expect(m.unsettledWarnings, ['legacy']);
    expect(m.messages.single.code, 'PAYMENT_STATUS_UNKNOWN');
  });
}
