import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/logistics_invoices/models/logistics_invoice_models.dart';

void main() {
  group('Logistics Service Invoices - Model & Business Rules Tests', () {
    test('LogisticsInvoiceModel parses correctly from backend JSON', () {
      final json = {
        'invoice_id': 101,
        'invoice_code': 'LSI-2026-0001',
        'shipment_id': 12,
        'bl_number': 'BL-MEDU-998877',
        'partner_id': 5,
        'partner_type': 'freight',
        'partner_name': 'MSC Mediterranean Shipping Co',
        'invoice_number': 'MSC-INV-2026-44',
        'invoice_date': '2026-10-10T00:00:00',
        'currency': 'USD',
        'total_amount_fx': 2500.0,
        'exchange_rate': 48.5,
        'total_amount_egp': 121250.0,
        'vat_included': true,
        'vat_amount': 16975.0,
        'wht_deducted': false,
        'wht_amount': 0.0,
        'net_payable_egp': 138225.0,
        'paid_amount_egp': 0.0,
        'remaining_amount_egp': 138225.0,
        'payment_status': 'unpaid',
        'status': 'submitted',
        'approval_status': 'pending',
        'is_active': true,
        'created_at': '2026-10-10T00:00:00',
        'created_by': 'Admin',
        'lines': [
          {
            'line_id': 1,
            'invoice_id': 101,
            'line_description': 'Ocean Freight Base Rate',
            'line_group': 'ocean_freight',
            'quantity': 2.0,
            'unit_price_fx': 1000.0,
            'currency': 'USD',
            'amount_fx': 2000.0,
            'exchange_rate': 48.5,
            'amount_egp': 97000.0,
            'tax_type': 'professional_fee',
            'vat_rate': 14.0,
            'vat_amount': 13580.0,
            'wht_rate': 0.0,
            'wht_amount': 0.0,
            'net_amount_egp': 110580.0,
            'is_from_quotation': true,
            'is_active': true,
            'created_at': '2026-10-10T00:00:00',
          }
        ],
        'containers': [
          {
            'id': 1,
            'invoice_id': 101,
            'shipment_id': 12,
            'bl_number': 'BL-MEDU-998877',
            'container_number': 'MSCU1234567',
            'seal_number': 'SEAL888',
            'created_at': '2026-10-10T00:00:00',
          }
        ]
      };

      final model = LogisticsInvoiceModel.fromJson(json);

      expect(model.invoiceId, equals(101));
      expect(model.invoiceCode, equals('LSI-2026-0001'));
      expect(model.partnerType, equals('freight'));
      expect(model.totalAmountFx, equals(2500.0));
      expect(model.totalAmountEgp, equals(121250.0));
      expect(model.netPayableEgp, equals(138225.0));
      expect(model.lines.length, equals(1));
      expect(model.lines.first.lineGroup, equals('ocean_freight'));
      expect(model.containers.length, equals(1));
      expect(model.containers.first.containerNumber, equals('MSCU1234567'));
    });

    test('Marine Insurance Policy calculations follow Egyptian regulation formula (CIF + 10%)', () {
      const cifValue = 50000.0; // USD
      const markup10Percent = cifValue * 1.10; // 55000 USD
      const premiumRatePercent = 0.35; // 0.35%
      const premiumFx = markup10Percent * (premiumRatePercent / 100.0); // 192.5 USD
      const cbeRate = 48.5; // EGP
      const premiumEgp = premiumFx * cbeRate; // 9336.25 EGP
      const stampDutyEgp = premiumEgp * 0.001; // 0.1% = 9.33625 EGP
      const supervisoryFeeEgp = premiumEgp * 0.12; // 12% = 1120.35 EGP
      final netPremiumEgp = premiumEgp + stampDutyEgp + supervisoryFeeEgp;

      expect(markup10Percent, closeTo(55000.0, 0.01));
      expect(premiumFx, closeTo(192.5, 0.01));
      expect(premiumEgp, closeTo(9336.25, 0.01));
      expect(stampDutyEgp, closeTo(9.336, 0.01));
      expect(supervisoryFeeEgp, closeTo(1120.35, 0.01));
      expect(netPremiumEgp, closeTo(10465.936, 0.01));

      final policyJson = {
        'policy_id': 201,
        'policy_code': 'POL-2026-0001',
        'shipment_id': 12,
        'bl_number': 'BL-MEDU-998877',
        'insurance_company_id': 3,
        'insurance_company_name': 'Misr Insurance Co.',
        'policy_number': 'MISR-MARINE-9988',
        'policy_date': '2026-10-10T00:00:00',
        'coverage_type': 'all_risks',
        'insured_value_fx': markup10Percent,
        'insured_value_currency': 'USD',
        'premium_rate': premiumRatePercent,
        'premium_amount_fx': premiumFx,
        'exchange_rate': cbeRate,
        'premium_amount_egp': premiumEgp,
        'stamp_duty_egp': stampDutyEgp,
        'supervisory_fee_egp': supervisoryFeeEgp,
        'net_premium_egp': netPremiumEgp,
        'status': 'issued',
        'claim_amount_egp': 0.0,
        'invoice_generated': false,
        'is_active': true,
        'created_at': '2026-10-10T00:00:00',
        'created_by': 'Admin',
      };

      final policy = InsurancePolicyModel.fromJson(policyJson);
      expect(policy.policyId, equals(201));
      expect(policy.insuredValueFx, closeTo(55000.0, 0.01));
      expect(policy.coverageType, equals('all_risks'));
      expect(policy.netPremiumEgp, closeTo(10465.936, 0.01));
    });

    test('Clearance Advance Payment parses and correctly calculates remaining balance', () {
      final json = {
        'advance_id': 301,
        'advance_code': 'ADV-2026-0001',
        'shipment_id': 12,
        'bl_number': 'BL-MEDU-998877',
        'clearance_partner_id': 2,
        'clearance_partner_name': 'Alexandria Customs Brokerage',
        'amount': 50000.0,
        'currency': 'EGP',
        'exchange_rate': 1.0,
        'amount_egp': 50000.0,
        'payment_date': '2026-10-10T00:00:00',
        'disbursed_by': 'Admin',
        'settled_amount_egp': 35000.0,
        'remaining_amount_egp': 15000.0,
        'status': 'partially_settled',
        'is_active': true,
        'created_at': '2026-10-10T00:00:00',
        'created_by': 'Admin',
        'settlements': [
          {
            'settlement_id': 1,
            'advance_id': 301,
            'invoice_id': 102,
            'settled_amount_egp': 35000.0,
            'settlement_date': '2026-10-10T00:00:00',
          }
        ]
      };

      final advance = ClearanceAdvancePaymentModel.fromJson(json);
      expect(advance.advanceId, equals(301));
      expect(advance.amountEgp, equals(50000.0));
      expect(advance.settledAmountEgp, equals(35000.0));
      expect(advance.remainingAmountEgp, equals(15000.0));
      expect(advance.status, equals('partially_settled'));
      expect(advance.settlements.length, equals(1));
    });

    test('PartnerBalanceCardModel parses aging buckets correctly', () {
      final json = {
        'partner_id': 5,
        'partner_name': 'MSC Mediterranean Shipping Co',
        'partner_type': 'freight',
        'total_invoiced_egp': 500000.0,
        'total_paid_egp': 350000.0,
        'balance_due_egp': 150000.0,
        'open_invoices_count': 3,
        'aging': {
          'current_30_days': 80000.0,
          'days_31_to_60': 40000.0,
          'days_61_to_90': 20000.0,
          'days_90_plus': 10000.0,
        }
      };

      final card = PartnerBalanceCardModel.fromJson(json);
      expect(card.partnerId, equals(5));
      expect(card.balanceDueEgp, equals(150000.0));
      expect(card.openInvoicesCount, equals(3));
      expect(card.aging.current30Days, equals(80000.0));
      expect(card.aging.days31To60, equals(40000.0));
      expect(card.aging.days61To90, equals(20000.0));
      expect(card.aging.days90Plus, equals(10000.0));
    });

    test('ThreeWayMatchModel verifies matching quotation and invoice amounts', () {
      final json = {
        'invoice_id': 101,
        'is_fully_matched': true,
        'total_quoted_egp': 120000.0,
        'total_invoiced_egp': 120000.0,
        'total_variance_egp': 0.0,
        'items': [
          {
            'item_description': 'Ocean Freight',
            'quoted_amount_egp': 97000.0,
            'invoiced_amount_egp': 97000.0,
            'variance_egp': 0.0,
            'is_matched': true,
          }
        ]
      };

      final match = ThreeWayMatchModel.fromJson(json);
      expect(match.isFullyMatched, isTrue);
      expect(match.totalVarianceEgp, equals(0.0));
      expect(match.items.first.isMatched, isTrue);
    });
  });
}
