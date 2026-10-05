import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/widgets/financial_ui.dart';

Map<String, dynamic> _json({Object? rate = 48.5}) => {
      'payment_id': 7,
      'payment_code': 'PAY-2026-001',
      'title': 'Advance',
      'supplier_name': 'ACME',
      'payment_type': 'ADVANCE_PAYMENT',
      'requested_amount': 100,
      'currency_code': 'EUR',
      'exchange_rate': rate,
      'requested_amount_egp': 4850,
      'due_date': '2026-10-17',
      'request_date': '2026-10-05',
      'status': 'Draft',
      'created_at': '',
      'updated_at': '',
      'import_file_code': 'IMP-2026-009',
    };

void main() {
  group('PaymentRequestModel', () {
    test('round-trips the contract fields', () {
      final m = PaymentRequestModel.fromJson(_json());
      final back = m.toJson();
      expect(back['payment_type'], 'ADVANCE_PAYMENT');
      expect(back['exchange_rate'], 48.5);
      expect(back['requested_amount'], 100.0);
      expect(back['due_date'], '2026-10-17');
      expect(PaymentRequestModel.fromJson(back).paymentCode, 'PAY-2026-001');
    });

    test('null exchange rate becomes 0.0 (no fabricated rate)', () {
      expect(PaymentRequestModel.fromJson(_json(rate: null)).exchangeRate, 0.0);
    });

    test('keeps import_file_code', () {
      expect(
          PaymentRequestModel.fromJson(_json()).importFileCode, 'IMP-2026-009');
    });
  });

  group('FinancialUi.normalizePaymentType', () {
    test('keeps codes and maps legacy labels to codes', () {
      expect(FinancialUi.normalizePaymentType('AGAINST_BL'), 'AGAINST_BL');
      expect(FinancialUi.normalizePaymentType('Advance Payment'),
          'ADVANCE_PAYMENT');
      expect(FinancialUi.normalizePaymentType('Against B/L'), 'AGAINST_BL');
      expect(FinancialUi.normalizePaymentType('Letter of Credit (L/C)'),
          'LETTER_OF_CREDIT');
      expect(FinancialUi.normalizePaymentType('Documentary Collection (CAD)'),
          'DOCUMENTARY_COLLECTION');
      expect(FinancialUi.normalizePaymentType('Final Settlement'),
          'FINAL_SETTLEMENT');
    });

    test('unknown or empty falls back to ADVANCE_PAYMENT', () {
      expect(FinancialUi.normalizePaymentType(null), 'ADVANCE_PAYMENT');
      expect(FinancialUi.normalizePaymentType('weird'), 'ADVANCE_PAYMENT');
    });
  });
}
