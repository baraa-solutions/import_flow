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
}
