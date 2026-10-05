import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/purchase_orders/utils/po_hs_tariff_matcher.dart';

typedef _Tariff = ({int id, String hs});

void main() {
  const List<_Tariff> tariffs = [
    (id: 1, hs: '8415820010'),
    (id: 2, hs: '8415820090'),
    (id: 3, hs: '8419.50.80'),
    (id: 4, hs: '84145925'),
  ];
  String hsOf(_Tariff t) => t.hs;

  group('matchTariffForPrintedHs', () {
    test('an 8-digit printed code is not linked to a 10-digit national line by prefix', () {
      // Field bug: invoice V1/2539 printed 84158200 and the dialog showed 8415820010.
      expect(matchTariffForPrintedHs('84158200', tariffs, hsOf), isNull);
    });

    test('a 4-digit heading never picks the first row of the chapter', () {
      expect(matchTariffForPrintedHs('8415', tariffs, hsOf), isNull);
    });

    test('exact code links, punctuation ignored', () {
      expect(matchTariffForPrintedHs('8415820010', tariffs, hsOf)?.id, 1);
      expect(matchTariffForPrintedHs('84195080', tariffs, hsOf)?.id, 3);
      expect(matchTariffForPrintedHs('8414.59.25', tariffs, hsOf)?.id, 4);
    });

    test('a longer printed code is not linked to a shorter tariff row', () {
      expect(matchTariffForPrintedHs('8414592510', tariffs, hsOf), isNull);
    });

    test('empty or missing code links nothing', () {
      expect(matchTariffForPrintedHs(null, tariffs, hsOf), isNull);
      expect(matchTariffForPrintedHs('  ', tariffs, hsOf), isNull);
    });
  });
}
