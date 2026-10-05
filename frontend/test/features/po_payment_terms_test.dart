import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/purchase_orders/utils/po_payment_terms.dart';

void main() {
  group('PoPaymentTerms.fromText maps extracted text onto the dropdown options', () {
    const cases = <String, String>{
      // Cash against documents / documentary collection (must beat the generic "cash" rule).
      'CAD': PoPaymentTerms.cashAgainstDocuments,
      'Cash Against Documents': PoPaymentTerms.cashAgainstDocuments,
      'Cash Against Documents / CAD': PoPaymentTerms.cashAgainstDocuments, // the old invalid value
      'D/P at sight': PoPaymentTerms.cashAgainstDocuments,
      'Documentary collection': PoPaymentTerms.cashAgainstDocuments,
      'تحصيل مستندي': PoPaymentTerms.cashAgainstDocuments,
      // Letter of credit.
      'L/C at sight': PoPaymentTerms.letterOfCredit,
      'Irrevocable LC 90 days': PoPaymentTerms.letterOfCredit,
      'LC at Sight / اعتماد مستندي': PoPaymentTerms.letterOfCredit, // model default / legacy
      'Letter of Credit': PoPaymentTerms.letterOfCredit,
      'اعتماد مستندي': PoPaymentTerms.letterOfCredit,
      // Open account / deferred.
      'Open Account': PoPaymentTerms.openAccount, // the old invalid value
      'O/A 60 days': PoPaymentTerms.openAccount,
      'Net 30': PoPaymentTerms.openAccount,
      '90 days after B/L date': PoPaymentTerms.openAccount,
      'حساب مفتوح': PoPaymentTerms.openAccount,
      'دفع آجل': PoPaymentTerms.openAccount,
      // Cash in advance / transfer.
      'T/T in advance': PoPaymentTerms.cashInAdvance,
      '100% TT before shipment': PoPaymentTerms.cashInAdvance,
      'Telegraphic transfer': PoPaymentTerms.cashInAdvance,
      'Prepayment': PoPaymentTerms.cashInAdvance,
      'SWIFT': PoPaymentTerms.cashInAdvance,
      'Avv.merce pronta': PoPaymentTerms.cashInAdvance,
      'تحويل سويفت مقدم': PoPaymentTerms.cashInAdvance,
    };

    cases.forEach((input, expected) {
      test('"$input" -> $expected', () => expect(PoPaymentTerms.fromText(input), expected));
    });

    test('every option maps to itself (case-insensitive)', () {
      for (final v in PoPaymentTerms.values) {
        expect(PoPaymentTerms.fromText(v), v);
        expect(PoPaymentTerms.fromText(v.toUpperCase()), v);
      }
    });

    test('unknown / empty text gives null, never a value outside the dropdown', () {
      for (final input in [null, '', '   ', 'see contract', 'شحن عاجل', 'CALCULATED ON DELIVERY']) {
        expect(PoPaymentTerms.fromText(input), isNull, reason: '"$input"');
      }
    });
  });
}
