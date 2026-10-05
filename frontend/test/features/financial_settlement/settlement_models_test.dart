import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_settlement/models/financial_settlement_model.dart';
import 'package:frontend/features/financial_settlement/models/invoices_aggregation_model.dart';
import 'package:frontend/features/financial_settlement/widgets/settlement_form_dialog.dart';
import 'package:frontend/features/recalculation/models/recalculation_model.dart';

void main() {
  group('ItemLandedCostModel', () {
    test('keeps a decimal quantity (2.5 is not truncated to 2)', () {
      final item = ItemLandedCostModel.fromJson({
        'item_code': 'A',
        'item_name': 'Valve',
        'qty': 2.5,
      });
      expect(item.qty, 2.5);
      expect(item.qtyLabel, '2.5');
    });

    test('integer quantity renders without a trailing .0', () {
      final item = ItemLandedCostModel.fromJson({'qty': 100});
      expect(item.qty, 100.0);
      expect(item.qtyLabel, '100');
    });

    test('missing weight / cbm default to zero, not invented values', () {
      final item = ItemLandedCostModel.fromJson({'item_code': 'A'});
      expect(item.grossWeightKg, 0.0);
      expect(item.cbm, 0.0);
    });

    test('create json carries only user-entered fields', () {
      final json = ItemLandedCostModel(
        itemCode: 'A',
        itemName: 'Valve',
        qty: 2.5,
        grossWeightKg: 0,
        cbm: 0,
        fobUnitEgp: 10,
      ).toCreateJson();
      expect(json.keys.toSet(), {'item_code', 'item_name', 'qty', 'gross_weight_kg', 'cbm', 'fob_unit_egp'});
      expect(json['qty'], 2.5);
    });
  });

  group('ExpenseInvoiceModel', () {
    test('has no fabricated 48.5 / 50.0 / USD defaults', () {
      final inv = ExpenseInvoiceModel.fromJson({'invoice_no': 'I-1', 'provider_name': 'P'});
      expect(inv.exchangeRate, 0.0);
      expect(inv.currency, '');
      expect(inv.amountEgp, 0.0);
    });

    test('amount_egp is never derived from fx * rate on the client', () {
      final inv = ExpenseInvoiceModel.fromJson({'amount_fx': 100, 'exchange_rate': 50});
      expect(inv.amountEgp, 0.0);
    });

    test('create json omits amount_egp and omits an unset exchange rate', () {
      final json = ExpenseInvoiceModel(
        invoiceNo: 'I-1',
        providerName: 'P',
        currency: 'EUR',
        amountFx: 100,
      ).toCreateJson();
      expect(json.containsKey('amount_egp'), isFalse);
      expect(json.containsKey('exchange_rate'), isFalse);
      expect(json['currency'], 'EUR');

      final withRate = ExpenseInvoiceModel(
        invoiceNo: 'I-1',
        providerName: 'P',
        currency: 'EUR',
        amountFx: 100,
        exchangeRate: 55.5,
      ).toCreateJson();
      expect(withRate['exchange_rate'], 55.5);
      expect(withRate.containsKey('amount_egp'), isFalse);
    });
  });

  test('settlement accountant has no hard-coded default name', () {
    final s = LandedCostSettlementModel.fromJson({
      'settlement_id': 1,
      'import_file_id': 2,
    });
    expect(s.accountantName, '');
  });

  test('aggregation response has no 48.5 default rate', () {
    final res = InvoicesAggregationResponseModel.fromJson({});
    expect(res.exchangeRate, 0.0);
  });

  test('confirm request does not send settled_by unless set', () {
    expect(
      ConfirmInvoicesSettlementRequestModel(importFileId: 7).toJson().containsKey('settled_by'),
      isFalse,
    );
  });

  group('create payload', () {
    test('sends no fabricated weight / cbm / currency / rate and no amount_egp', () {
      final payload = buildSettlementCreatePayload(
        importFileId: 9,
        invoice: ExpenseInvoiceModel(
          invoiceNo: 'I-1',
          providerName: 'P',
          currency: 'USD',
          amountFx: 1000,
        ),
        item: ItemLandedCostModel(itemCode: 'A', itemName: 'N', qty: 0.5, fobUnitEgp: 5),
      );
      final inv = (payload['expense_invoices'] as List).first as Map;
      final itm = (payload['item_landed_costs'] as List).first as Map;
      expect(payload['import_file_id'], 9);
      expect(inv.containsKey('amount_egp'), isFalse);
      expect(inv.containsKey('exchange_rate'), isFalse);
      expect(inv['currency'], 'USD');
      expect(itm['gross_weight_kg'], 0.0);
      expect(itm['cbm'], 0.0);
      expect(itm['qty'], 0.5);
    });

    test('parseSettlementNumber handles empty, comma and invalid input', () {
      expect(parseSettlementNumber(''), isNull);
      expect(parseSettlementNumber(null), isNull);
      expect(parseSettlementNumber('abc'), isNull);
      expect(parseSettlementNumber('2,5'), 2.5);
      expect(parseSettlementNumber(' 10 '), 10.0);
    });
  });

  group('recalculation models', () {
    test('parse additive message_code / params / applied_changes', () {
      final r = RecalculationApplyResult.fromJson({
        'target_entity_type': 'financial_settlement',
        'target_entity_id': 1,
        'action_taken': 'auto_updated',
        'revision_created': false,
        'log_id': 3,
        'message_ar': 'x',
        'message_code': 'RECALC_APPLIED',
        'params': {'threshold': 10},
        'applied_changes': [
          {'field': 'freight'}
        ],
      });
      expect(r.messageCode, 'RECALC_APPLIED');
      expect(r.params['threshold'], 10);
      expect(r.appliedChanges, hasLength(1));
    });

    test('old server payload without the new fields still parses', () {
      final r = RecalculationApplyResult.fromJson({'log_id': 1});
      expect(r.messageCode, isNull);
      expect(r.appliedChanges, isEmpty);
    });
  });
}
