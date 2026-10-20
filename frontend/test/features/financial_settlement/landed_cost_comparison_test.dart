import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_settlement/models/actual_landed_cost_model.dart';

void main() {
  group('Landed Cost Comparison - Backend Money & No Client Formulas (ACC2-T16)', () {
    test('does not produce 4,900% when estimated_cost is 10,000 USD and FOB is 500,000 EGP', () {
      // Simulating backend response with 10,000 USD estimate and 500,000 EGP actual FOB
      final json = <String, dynamic>{
        'import_file_id': 1,
        'currency': 'USD',
        'exchange_rate': 50.0,
        'actual_total_fob_egp': 500000.0,
        'actual_total_expenses_egp': 16250.0,
        'estimated_total_landed_cost_egp': 500000.0,
        'actual_total_landed_cost_egp': 516250.0,
        'landed_variance_egp': 16250.0,
        'landed_variance_pct': 3.25,
        'variance_status': 'OVER_BUDGET',
      };

      final model = ActualLandedCostCalculationResponseModel.fromJson(json);

      // Backend variance is read directly; client formula ((500,000 - 10,000) / 10,000 * 100 = 4,900%) is NOT used
      expect(model.landedVariancePct, equals(3.25));
      expect(model.landedVariancePct, isNot(equals(4900.0)));
      expect(model.totalFobEgp, equals(500000.0));
    });

    test('handles null variance when estimate is unavailable without dividing by zero or estimatedCost', () {
      final json = <String, dynamic>{
        'import_file_id': 2,
        'actual_total_fob_egp': 200000.0,
        'actual_total_expenses_egp': 50000.0,
        'actual_total_landed_cost_egp': 250000.0,
        'estimated_total_landed_cost_egp': null,
        'landed_variance_egp': null,
        'landed_variance_pct': null,
        'variance_status': 'NO_ESTIMATE',
      };

      final model = ActualLandedCostCalculationResponseModel.fromJson(json);

      expect(model.landedVariancePct, isNull);
      expect(model.estimatedTotalLandedCostEgp, isNull);
      expect(model.varianceStatus, equals('NO_ESTIMATE'));
    });
  });
}
