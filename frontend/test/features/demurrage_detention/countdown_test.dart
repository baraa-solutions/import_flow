import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';

void main() {
  test('simulation result keeps status code for l10n countdown', () {
    final r = DemurrageSimulationResultModel.fromJson({'status_badge': 'WARNING', 'demurrage_free_days': 14, 'demurrage_days_consumed': 12});
    expect(r.statusBadge, 'WARNING');
    expect(r.demurrageFreeDays - r.demurrageDaysConsumed, 2);
  });
}
