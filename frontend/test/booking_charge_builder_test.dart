import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/services/booking_charge_builder.dart';

void main() {
  group('BookingChargeBuilder Tests (BE45-T01)', () {
    test('40GP container allocation produces charge tagged with 40GP', () {
      final containers = [
        ContainerAllocationModel(containerType: '40GP', quantity: 2),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftQty: 2,
        container40ftCur: 'USD',
      );

      expect(result.hasError, isFalse);
      expect(result.has40ftMismatch, isFalse);
      expect(result.has20ftMismatch, isFalse);
      expect(result.charges.length, 1);

      final charge = result.charges.first;
      expect(charge.chargeType, 'Sea Freight 40ft');
      expect(charge.containerType, '40GP');
      expect(charge.quantity, 2.0);
      expect(charge.rate, 2000.0);
      expect(charge.total, 4000.0);
    });

    test('45HC container allocation produces charge tagged with 45HC', () {
      final containers = [
        ContainerAllocationModel(containerType: '45HC', quantity: 1),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container40ftApp: true,
        container40ftPrice: 2400.0,
        container40ftQty: 1,
        container40ftCur: 'USD',
      );

      expect(result.hasError, isFalse);
      expect(result.charges.length, 1);
      final charge = result.charges.first;
      expect(charge.chargeType, 'Sea Freight 40ft');
      expect(charge.containerType, '45HC');
      expect(charge.quantity, 1.0);
      expect(charge.total, 2400.0);
    });

    test('Quote with both sizes tags each charge with matching container type', () {
      final containers = [
        ContainerAllocationModel(containerType: '40GP', quantity: 2),
        ContainerAllocationModel(containerType: '20RF', quantity: 1),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftQty: 2,
        container40ftCur: 'USD',
        container20ftApp: true,
        container20ftPrice: 1200.0,
        container20ftQty: 1,
        container20ftCur: 'USD',
      );

      expect(result.hasError, isFalse);
      expect(result.charges.length, 2);

      final c40 = result.charges.firstWhere((c) => c.chargeType == 'Sea Freight 40ft');
      expect(c40.containerType, '40GP');
      expect(c40.quantity, 2.0);
      expect(c40.total, 4000.0);

      final c20 = result.charges.firstWhere((c) => c.chargeType == 'Sea Freight 20ft');
      expect(c20.containerType, '20RF');
      expect(c20.quantity, 1.0);
      expect(c20.total, 1200.0);
    });

    test('Size-class change (40HC quote with 20GP equipment) never silently drops line and returns mismatch error', () {
      // Example A from review: quote has 2 x 40ft, but containers allocated as 20GP
      final containers = [
        ContainerAllocationModel(containerType: '20GP', quantity: 2),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftQty: 2,
        container40ftCur: 'USD',
      );

      // Line MUST NOT be silently dropped: kept so freight total is not understated
      expect(result.charges.any((c) => c.chargeType == 'Sea Freight 40ft'), isTrue);
      final c40 = result.charges.firstWhere((c) => c.chargeType == 'Sea Freight 40ft');
      expect(c40.total, 4000.0);

      // Must report mismatch error so the save can be blocked
      expect(result.hasError, isTrue);
      expect(result.has40ftMismatch, isTrue);
      expect(result.has20ftMismatch, isFalse);
    });

    test('Mixed quote size-class change (Example B from review) flags missing 40ft container and tags 20ft strictly', () {
      // Example B from review: quote has 2 x 40ft @ 2000 and 1 x 20ft @ 1200.
      // Equipment changed to [20RF x2, 20GP x1].
      final containers = [
        ContainerAllocationModel(containerType: '20RF', quantity: 2),
        ContainerAllocationModel(containerType: '20GP', quantity: 1),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftQty: 2,
        container40ftCur: 'USD',
        container20ftApp: true,
        container20ftPrice: 1200.0,
        container20ftQty: 1,
        container20ftCur: 'USD',
      );

      // 40ft line is kept (not dropped)
      expect(result.charges.any((c) => c.chargeType == 'Sea Freight 40ft'), isTrue);
      // 20ft line is present and strictly tagged with a 20xx type
      expect(result.charges.any((c) => c.chargeType == 'Sea Freight 20ft'), isTrue);
      final c20 = result.charges.firstWhere((c) => c.chargeType == 'Sea Freight 20ft');
      expect(c20.containerType, '20RF');

      // 40ft container is missing from allocations -> error must block save
      expect(result.hasError, isTrue);
      expect(result.has40ftMismatch, isTrue);
    });

    test('20ft quote with 40HC equipment flags mismatch and retains 20ft freight line', () {
      final containers = [
        ContainerAllocationModel(containerType: '40HC', quantity: 1),
      ];

      final result = BookingChargeBuilder.buildCharges(
        containers: containers,
        container20ftApp: true,
        container20ftPrice: 1500.0,
        container20ftQty: 1,
        container20ftCur: 'USD',
      );

      expect(result.hasError, isTrue);
      expect(result.has20ftMismatch, isTrue);
      expect(result.has40ftMismatch, isFalse);
      expect(result.charges.any((c) => c.chargeType == 'Sea Freight 20ft'), isTrue);
    });
  });
}
