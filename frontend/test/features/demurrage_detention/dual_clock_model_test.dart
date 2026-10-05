import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';

void main() {
  test('DualClockModel maps the real backend DualClockResponse keys', () {
    final m = DualClockModel.fromJson({
      'tracking_id': 7,
      'tracking_code': 'DND-2026-0001',
      'bill_of_lading_no': 'BL1',
      'discharge_date': '2026-01-01',
      'carrier_clock': {
        'carrier_name': 'MSC',
        'free_days_allowed': 14,
        'days_consumed': 16,
        'days_remaining': -2,
        'accrued_demurrage_fx': 560.5,
        'currency': 'USD',
        'status': 'OVERDUE_DEMURRAGE',
      },
      'port_storage_clock': {
        'port_name': 'Alexandria',
        'storage_free_days': 5,
        'days_consumed': 4,
        'days_remaining': 1,
        'hours_until_penalties': 24,
        'daily_rate_egp': 250.0,
        'accrued_storage_egp': 0.0,
        'is_critical_72h_warning': true,
        'status': 'CRITICAL_72H_ALERT',
      },
      'overall_alert_level': 'ACTION_REQUIRED',
      'summary_ar': 'x',
    });
    expect(m.carrierClock.isOverdue, isTrue);
    expect(m.carrierClock.overdueDays, 2);
    expect(m.carrierClock.accruedDemurrageFx, 560.5);
    expect(m.portStorageClock.isCritical72hWarning, isTrue);
    expect(m.portStorageClock.hoursUntilPenalties, 24);
    expect(m.portStorageClock.overdueDays, 0);
    expect(m.overallAlertLevel, DualClockModel.alertActionRequired);
  });
}
