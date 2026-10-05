import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_clearance_quotations/models/customs_clearance_quotation_model.dart';

void main() {
  test('toJson sends the provider that was set, with no fallback provider', () {
    final q = CustomsClearanceQuotationItemModel(
      providerId: 42,
      providerName: 'Broker X',
      clearanceFee: 100,
      totalCost: 100,
    );
    expect(q.toJson()['provider_id'], 42);
  });

  test('fromJson leaves a missing provider as 0 (never as provider 1)', () {
    final q = CustomsClearanceQuotationItemModel.fromJson({'total_cost': 5});
    expect(q.providerId, 0);
    expect(q.providerId, isNot(1));
    expect(q.totalCost, 5.0);
  });
}
