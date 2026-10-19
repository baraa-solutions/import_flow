import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/services/financial_export_service.dart';

ImportBudgetModel _budget({required double rate}) =>
    ImportBudgetModel.fromJson({
      'budget_id': 1,
      'budget_code': 'BGT-2026-001',
      'title': 't',
      'budget_status': 'Draft',
      'exchange_rate': rate,
    });

void main() {
  test(
      'budget export prints "-" instead of a fabricated 50 when no rate is stored',
      () {
    final text =
        FinancialExportService.generateBudgetWhatsAppText(_budget(rate: 0));
    expect(text, contains('- EGP'));
    expect(text, isNot(contains('50.0 EGP')));
  });

  test('budget export prints the stored rate', () {
    final text =
        FinancialExportService.generateBudgetWhatsAppText(_budget(rate: 48.25));
    expect(text, contains('48.25 EGP'));
  });

  test('budget export prints stored freight_cost_egp without rate multiplication', () {
    final b = ImportBudgetModel.fromJson({
      'budget_id': 1,
      'budget_code': 'BGT-2026-001',
      'title': 't',
      'budget_status': 'Draft',
      'exchange_rate': 48.5,
      'freight_cost_foreign': 1000.0,
      'freight_currency': 'EUR',
      'freight_cost_egp': 52800.0,
      'total_budget_egp': 52800.0,
    });
    final text = FinancialExportService.generateBudgetWhatsAppText(b);
    expect(text, contains('52800.00 EGP'));
    expect(text, isNot(contains('48500.00')));
  });
}
