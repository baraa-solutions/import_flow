import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/shipping_scenarios/models/shipping_scenario_model.dart';

void main() {
  group('Demurrage and Shipping Scenario Model Extensions', () {
    test('DemurrageTrackingModel parses terminal and ancillary fees accurately', () {
      final json = {
        'tracking_id': 101,
        'tracking_code': 'TRK-2026-001',
        'import_file_id': 42,
        'import_file_code': 'IMP-2026-042',
        'carrier_id': 5,
        'carrier_name': 'MSC',
        'terminal_id': 12,
        'terminal_name': 'Alexandria Container Terminal (ACCHCO)',
        'bill_of_lading_no': 'MEDU123456789',
        'port_name': 'Alexandria Port',
        'discharge_date': '2026-10-01',
        'currency': 'USD',
        'exchange_rate': 49.5,
        'ancillary_fees': [
          {'fee_name': 'Terminal Inspection', 'fee_amount': 75.0, 'currency': 'USD', 'amount_usd': 75.0},
          {'fee_name': 'Weighing Fee', 'fee_amount': 500.0, 'currency': 'EGP', 'amount_egp': 500.0},
        ],
        'total_ancillary_usd': 75.0,
        'total_ancillary_egp': 500.0,
        'total_demurrage_fx': 120.0,
        'total_detention_fx': 0.0,
        'total_storage_egp': 1500.0,
        'total_cost_egp': 7940.0,
        'status': 'Demurrage Incurred',
        'is_pushed_to_settlement': false,
        'containers': [],
      };

      final model = DemurrageTrackingModel.fromJson(json);
      expect(model.carrierId, 5);
      expect(model.terminalId, 12);
      expect(model.terminalName, 'Alexandria Container Terminal (ACCHCO)');
      expect(model.ancillaryFees.length, 2);
      expect(model.totalAncillaryUsd, 75.0);
      expect(model.totalAncillaryEgp, 500.0);
    });

    test('DemurrageSimulationResultModel parses storage fee fx and tier breakdown', () {
      final json = {
        'demurrage_days_consumed': 16,
        'demurrage_free_days': 14,
        'demurrage_days_overdue': 2,
        'demurrage_fee_fx': 80.0,
        'demurrage_expiry_date': '2026-10-15',
        'detention_days_consumed': 0,
        'detention_free_days': 7,
        'detention_days_overdue': 0,
        'detention_fee_fx': 0.0,
        'storage_days_consumed': 8,
        'storage_free_days': 5,
        'storage_days_overdue': 3,
        'storage_fee_fx': 45.0,
        'storage_fee_egp': 2250.0,
        'storage_currency': 'USD',
        'storage_tier_breakdown': [
          {'tier_name': 'الأيام 1 - 3', 'rate_per_day': 15.0, 'days_applied': 3, 'tier_cost': 45.0}
        ],
        'total_fee_fx': 125.0,
        'total_cost_egp': 6250.0,
        'status_badge': 'DEMURRAGE_INCURRED',
        'countdown_summary_ar': '🚨 غرامة أرضيات سارية',
        'breakdown_details': [],
      };

      final sim = DemurrageSimulationResultModel.fromJson(json);
      expect(sim.storageFeeFx, 45.0);
      expect(sim.storageCurrency, 'USD');
      expect(sim.storageTierBreakdown.length, 1);
      expect(sim.storageTierBreakdown.first['days_applied'], 3);
    });

    test('ShippingScenarioItemModel preserves server computed totals without local conversion', () {
      final json = {
        'scenario_id': 1,
        'import_file_id': 10,
        'scenario_name': 'Fast Air Freight',
        'route_type': 'Air',
        'origin_country': 'Germany',
        'origin_port': 'Frankfurt',
        'destination_country': 'Egypt',
        'destination_port': 'Cairo Airport',
        'carrier_name': 'EgyptAir Cargo',
        'total_transit_days': 3,
        'total_cost_egp': 85000.0,
        'freight_total_amount': 1500.0,
        'total_quotation_amount': 1750.0,
        'totals_rate_date': '2026-10-19',
        'quotation_currency': 'USD',
      };

      final scenario = ShippingScenarioItemModel.fromJson(json);
      expect(scenario.freightTotalAmount, 1500.0);
      expect(scenario.totalQuotationAmount, 1750.0);
      expect(scenario.totalsRateDate, '2026-10-19');

      final copied = scenario.copyWith(freightTotalAmount: 1600.0);
      expect(copied.freightTotalAmount, 1600.0);
      expect(copied.totalsRateDate, '2026-10-19');
    });

    test('Terminal, Carrier, and RatesHistoryModel parse correctly', () {
      final json = {
        'terminal_rates': [
          {
            'rate_id': 1,
            'terminal_id': 10,
            'container_type': '40ft DRY',
            'free_days': 7,
            'storage_tiers': [
              {'from_day': 8, 'to_day': 14, 'rate_per_day': 36.0},
              {'from_day': 15, 'to_day': 21, 'rate_per_day': 40.0},
              {'from_day': 22, 'to_day': null, 'rate_per_day': 45.0},
            ],
            'currency': 'USD',
            'imo_free_days': 1,
            'imo_rate_multiplier': 2.0,
            'effective_date': '2026-01-01',
            'is_active': true,
          }
        ],
        'carrier_rates': [
          {
            'rate_id': 2,
            'carrier_id': 20,
            'container_type': '40ft High Cube',
            'demurrage_free_days_standard': 14,
            'detention_free_days_standard': 7,
            'demurrage_tiers': [
              {'from_day': 1, 'to_day': 7, 'rate_per_day': 40.0},
              {'from_day': 8, 'to_day': 14, 'rate_per_day': 70.0},
              {'from_day': 15, 'to_day': 21, 'rate_per_day': 120.0},
              {'from_day': 22, 'to_day': null, 'rate_per_day': 165.0},
            ],
            'detention_tiers': [
              {'from_day': 1, 'to_day': 7, 'rate_per_day': 35.0},
            ],
            'currency': 'USD',
            'effective_date': '2026-01-01',
            'is_active': true,
          }
        ],
      };

      final history = RatesHistoryModel.fromJson(json);
      expect(history.terminalRates.length, 1);
      final tRate = history.terminalRates.first;
      expect(tRate.terminalId, 10);
      expect(tRate.freeDays, 7);
      expect(tRate.storageTiers.length, 3);
      expect(tRate.storageTiers[0].ratePerDay, 36.0);
      expect(tRate.storageTiers[2].ratePerDay, 45.0);

      expect(history.carrierRates.length, 1);
      final cRate = history.carrierRates.first;
      expect(cRate.carrierId, 20);
      expect(cRate.demurrageFreeDaysStandard, 14);
      expect(cRate.demurrageTiers.length, 4);
      expect(cRate.demurrageTiers[3].ratePerDay, 165.0);
    });
  });
}

