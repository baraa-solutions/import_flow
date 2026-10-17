import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';

void main() {
  group('LandedCostSettlementModel Unit Tests (Phase 9)', () {
    test('Should parse LandedCostSettlementModel from JSON correctly', () {
      final json = {
        'settlement_id': 301,
        'settlement_code': 'LCS-2026-0001',
        'import_file_id': 15,
        'expense_invoices': [
          {
            'invoice_no': 'INV-FREIGHT-99',
            'category': 'Freight',
            'provider_name': 'Hapag-Lloyd',
            'currency': 'USD',
            'amount_fx': 1200.0,
            'exchange_rate': 50.0,
            'amount_egp': 60000.0,
            'allocation_rule': 'Volume-Based',
          }
        ],
        'total_fob_egp': 200000.0,
        'total_expenses_egp': 60000.0,
        'total_landed_cost_egp': 260000.0,
        'average_markup_factor': 1.30,
        'item_landed_costs': [
          {
            'item_code': 'ITM-01',
            'item_name': 'Steel Fittings',
            'qty': 100,
            'gross_weight_kg': 500.0,
            'cbm': 8.0,
            'fob_unit_egp': 2000.0,
            'fob_total_egp': 200000.0,
            'allocated_freight_egp': 60000.0,
            'total_landed_cost_egp': 260000.0,
            'unit_landed_cost_egp': 2600.0,
            'markup_factor': 1.30,
          }
        ],
        'status': 'Calculated',
        'accountant_name': 'Kamal',
        'is_active': true,
        'created_at': '2026-08-09T16:00:00Z',
        'updated_at': '2026-08-09T16:00:00Z',
      };

      final model = LandedCostSettlementModel.fromJson(json);

      expect(model.settlementId, 301);
      expect(model.settlementCode, 'LCS-2026-0001');
      expect(model.totalFobEgp, 200000.0);
      expect(model.totalExpensesEgp, 60000.0);
      expect(model.totalLandedCostEgp, 260000.0);
      expect(model.averageMarkupFactor, 1.30);
      expect(model.expenseInvoices.length, 1);
      expect(model.itemLandedCosts.length, 1);
      expect(model.itemLandedCosts.first.unitLandedCostEgp, 2600.0);
    });

    test('Should serialize LandedCostSettlementModel to JSON correctly', () {
      final exp = ExpenseInvoiceModel(
        invoiceNo: 'INV-TRK-01',
        category: 'Local Transport',
        providerName: 'Delta Cargo',
        currency: 'EGP',
        amountFx: 15000.0,
        exchangeRate: 1.0,
        amountEgp: 15000.0,
        allocationRule: 'Weight-Based',
      );

      final itm = ItemLandedCostModel(
        itemCode: 'ITM-02',
        itemName: 'Industrial Pumps',
        qty: 10,
        fobUnitEgp: 10000.0,
        fobTotalEgp: 100000.0,
        allocatedTransportEgp: 15000.0,
        totalLandedCostEgp: 115000.0,
        unitLandedCostEgp: 11500.0,
        markupFactor: 1.15,
      );

      final model = LandedCostSettlementModel(
        settlementId: 302,
        settlementCode: 'LCS-2026-0002',
        importFileId: 18,
        expenseInvoices: [exp],
        itemLandedCosts: [itm],
        totalFobEgp: 100000.0,
        totalExpensesEgp: 15000.0,
        totalLandedCostEgp: 115000.0,
        averageMarkupFactor: 1.15,
        createdAt: '2026-08-09T16:00:00Z',
        updatedAt: '2026-08-09T16:00:00Z',
      );

      final json = model.toJson();

      expect(json['settlement_code'], 'LCS-2026-0002');
      expect(json['total_landed_cost_egp'], 115000.0);
      expect((json['expense_invoices'] as List).length, 1);
      expect((json['item_landed_costs'] as List).length, 1);
    });

    test('Should safely parse LandedCostSettlementModel with null fields (legacy tolerance)', () {
      final json = <String, dynamic>{
        'settlement_id': null,
        'settlement_code': null,
        'import_file_id': null,
        'expense_invoices': null,
        'total_fob_egp': null,
        'total_expenses_egp': null,
        'total_landed_cost_egp': null,
        'average_markup_factor': null,
        'item_landed_costs': null,
        'status': null,
        'accountant_name': null,
        'notes': null,
        'is_active': null,
        'created_at': null,
        'updated_at': null,
      };

      final model = LandedCostSettlementModel.fromJson(json);

      expect(model.settlementId, 0);
      expect(model.settlementCode, '');
      expect(model.importFileId, 0);
      expect(model.status, 'Draft');
      expect(model.accountantName, '');
      expect(model.isActive, isTrue);
      expect(model.createdAt, '');
      expect(model.updatedAt, '');
      expect(model.expenseInvoices, isEmpty);
      expect(model.itemLandedCosts, isEmpty);
    });
  });
}
