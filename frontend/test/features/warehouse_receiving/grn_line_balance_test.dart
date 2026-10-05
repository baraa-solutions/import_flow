import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/warehouse_receiving/models/grn_line_balance.dart';
import 'package:frontend/features/warehouse_receiving/widgets/warehouse_inspection_dialog.dart';

GrnLineQuantities _q(int inv, int acc, int sh, int dm) =>
    GrnLineQuantities(invoiced: inv, accepted: acc, shortage: sh, damaged: dm);

void main() {
  group('GrnLineQuantities.balance (WR-04 rule)', () {
    test('accepted + shortage + damaged == invoiced balances', () {
      expect(_q(100, 97, 2, 1).balance, GrnLineBalance.balanced);
      expect(_q(100, 100, 0, 0).balance, GrnLineBalance.balanced);
      expect(_q(0, 0, 0, 0).balance, GrnLineBalance.balanced);
    });

    test('excess is allowed only with no shortage and no damage', () {
      expect(_q(100, 110, 0, 0).balance, GrnLineBalance.excess);
      expect(_q(100, 110, 1, 0).balance, GrnLineBalance.unbalanced);
      expect(_q(100, 110, 0, 1).balance, GrnLineBalance.unbalanced);
    });

    test('anything else does not balance', () {
      expect(_q(100, 90, 0, 0).balance, GrnLineBalance.unbalanced);
      expect(_q(100, 100, 2, 1).balance, GrnLineBalance.unbalanced);
      expect(_q(100, 100, 2, 1).isValid, isFalse);
      expect(_q(100, 100, 2, 1).difference, 3);
    });

    test('the old invented prefill (invoiced = accepted with shortage 2 / damaged 1) is rejected', () {
      expect(_q(250, 250, 2, 1).isValid, isFalse);
    });
  });

  group('parseGrnQty', () {
    test('accepts whole non-negative numbers', () {
      expect(parseGrnQty('0'), 0);
      expect(parseGrnQty(' 12 '), 12);
    });

    test('rejects empty, negative, decimal and text', () {
      expect(parseGrnQty(''), isNull);
      expect(parseGrnQty(null), isNull);
      expect(parseGrnQty('-1'), isNull);
      expect(parseGrnQty('1.5'), isNull);
      expect(parseGrnQty('abc'), isNull);
    });
  });

  group('InspectionVerdict (FE-05)', () {
    test('full acceptance is not allowed when shortage or damage is recorded', () {
      expect(InspectionVerdict.isFullAcceptanceAllowed(shortageQty: 0, damagedQty: 0), isTrue);
      expect(InspectionVerdict.isFullAcceptanceAllowed(shortageQty: 1, damagedQty: 0), isFalse);
      expect(InspectionVerdict.isFullAcceptanceAllowed(shortageQty: 0, damagedQty: 2), isFalse);
    });

    test('a saved ACCEPTED_FULL that contradicts the quantities is replaced', () {
      expect(
        InspectionVerdict.initial(saved: InspectionVerdict.acceptedFull, shortageQty: 3, damagedQty: 0),
        InspectionVerdict.acceptedWithDiscrepancy,
      );
    });

    test('a consistent saved verdict is kept, PENDING falls back to the quantities', () {
      expect(
        InspectionVerdict.initial(saved: InspectionVerdict.rejectedQuarantined, shortageQty: 3, damagedQty: 0),
        InspectionVerdict.rejectedQuarantined,
      );
      expect(InspectionVerdict.initial(saved: 'PENDING', shortageQty: 0, damagedQty: 0), InspectionVerdict.acceptedFull);
      expect(InspectionVerdict.initial(saved: null, shortageQty: 0, damagedQty: 1), InspectionVerdict.acceptedWithDiscrepancy);
    });
  });
}
