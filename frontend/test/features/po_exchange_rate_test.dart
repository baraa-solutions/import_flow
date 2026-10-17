import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_fx_rate.dart';

void main() {
  group('PO Exchange Rate Logic Tests (FE01-T03)', () {
    final sampleRates = [
      ExchangeRateModel(
        rateId: 1,
        currencyId: 2, // EUR
        commercialRate: 50.0,
        customsRate: 50.0,
        effectiveDate: '2026-01-01',
      ),
      ExchangeRateModel(
        rateId: 2,
        currencyId: 2, // EUR
        commercialRate: 52.5,
        customsRate: 52.0,
        effectiveDate: '2026-03-01',
      ),
      ExchangeRateModel(
        rateId: 3,
        currencyId: 2, // EUR
        commercialRate: 55.0,
        customsRate: 54.5,
        effectiveDate: '2026-06-01',
      ),
    ];

    test('Test 1: Order date before all available rates yields null', () {
      final orderDate = DateTime(2025, 12, 15);
      final rate = pickCommercialRate(sampleRates, orderDate);
      expect(rate, isNull, reason: 'Date before all rates must not default to any rate');
    });

    test('Test 2: Order date matching exact effective date yields that rate', () {
      final orderDate = DateTime(2026, 3, 1);
      final rate = pickCommercialRate(sampleRates, orderDate);
      expect(rate, 52.5, reason: 'Exact effective date match must return that specific commercial rate');
    });

    test('Test 3: Order date between effective dates yields the previous active rate', () {
      final orderDate = DateTime(2026, 4, 15);
      final rate = pickCommercialRate(sampleRates, orderDate);
      expect(rate, 52.5, reason: 'Date between 2026-03-01 and 2026-06-01 must pick 2026-03-01 rate');
    });

    test('Test 4: Order date after all effective dates yields the latest available rate', () {
      final orderDate = DateTime(2026, 8, 1);
      final rate = pickCommercialRate(sampleRates, orderDate);
      expect(rate, 55.0);
    });

    test('Test 5: Empty or null rates list yields null', () {
      expect(pickCommercialRate(null, DateTime.now()), isNull);
      expect(pickCommercialRate([], DateTime.now()), isNull);
    });

    test('Test 6: PurchaseOrderModel.fromJson without exchange_rate yields null', () {
      final json = {
        'po_id': 100,
        'po_number': 'PO-TEST-001',
        'project_id': 1,
        'company_id': 1,
        'supplier_id': 1,
        'incoterm_id': 1,
        'currency_id': 2,
        // no exchange_rate key
      };

      final po = PurchaseOrderModel.fromJson(json);
      expect(po.exchangeRate, isNull,
          reason: 'PO model fromJson without exchange_rate must not default to 1.0');
    });

    test('Test 7: Grep-guard asserting zero instances of hardcoded 1.0 fallbacks in po_form_dialog', () {
      final candidates = [
        File('lib/features/purchase_orders/widgets/po_form_dialog.dart'),
        File('frontend/lib/features/purchase_orders/widgets/po_form_dialog.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => candidates.first,
      );
      expect(file.existsSync(), isTrue, reason: 'po_form_dialog.dart must exist');

      final content = file.readAsStringSync();

      expect(content.contains('po?.exchangeRate ?? 1.0'), isFalse,
          reason: 'po_form_dialog must not default po?.exchangeRate to 1.0');
      expect(content.contains('_rateCtrl.text.trim()) ?? 1.0'), isFalse,
          reason: 'po_form_dialog must not fallback _rateCtrl parse to 1.0');
      expect(content.contains("'Exchange Rate (سعر الصرف)'"), isFalse,
          reason: 'po_form_dialog must not use hardcoded bilingual exchange rate label');
      expect(content.contains("validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null"), isFalse,
          reason: 'po_form_dialog must use l.requiredField instead of literal Required');
    });
  });
}
