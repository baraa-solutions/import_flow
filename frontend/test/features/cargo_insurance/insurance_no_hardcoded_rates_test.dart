import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cargo_insurance/models/cargo_insurance_model.dart';

void main() {
  test('calculation result has no client-side rate fallbacks', () {
    final r = InsuranceCalculationResultModel.fromJson({});
    expect(r.baseRate, 0.0);
    expect(r.taxRate, 0.0);
    expect(r.issuanceFee, 0.0);
  });
}
