import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/air_freight/models/air_freight_models.dart';
import 'package:frontend/features/air_freight/utils/air_weight_calculator.dart';

void main() {
  group('AirWeightCalculator', () {
    test('volumetric wins: 100x50x60 cm x2 / 6000 = 100 kg', () {
      final r = AirWeightCalculator.calculate([
        const AirPackageInput(length: 100, width: 50, height: 60, quantity: 2, grossWeight: 20),
      ]);
      expect(r.grossKg, 40);
      expect(r.volumetricKg, 100);
      expect(r.chargeableKg, 100);
      expect(r.volumeCbm, 0.6);
      expect(r.pieces, 2);
      expect(r.isVolumetricBasis, isTrue);
    });

    test('units are normalised (mm / m / lb) before calculating', () {
      final mm = AirWeightCalculator.calculate([
        const AirPackageInput(length: 1000, width: 500, height: 600, dimensionUnit: 'mm', quantity: 2),
      ]);
      final m = AirWeightCalculator.calculate([
        const AirPackageInput(length: 1, width: 0.5, height: 0.6, dimensionUnit: 'm', quantity: 2),
      ]);
      expect(mm.volumetricKg, 100);
      expect(m.volumetricKg, 100);
      expect(AirWeightCalculator.toKg(100, 'lb'), closeTo(45.359237, 1e-9));
      expect(() => AirWeightCalculator.toCm(1, 'inch'), throwsArgumentError);
    });

    test('gross wins with the courier divisor', () {
      final r = AirWeightCalculator.calculate([
        const AirPackageInput(length: 20, width: 20, height: 20, grossWeight: 22.0462, weightUnit: 'lb'),
      ], divisor: 5000);
      expect(r.volumetricKg, 1.6);
      expect(r.grossKg, 10);
      expect(r.chargeableKg, 10);
      expect(r.isVolumetricBasis, isFalse);
    });

    test('unknown dimensions or divisor give zero volumetric; total gross fills unweighed packages', () {
      expect(AirWeightCalculator.volumetricKg(const AirPackageInput(length: 0, width: 10, height: 10), 6000), 0);
      expect(AirWeightCalculator.volumetricKg(const AirPackageInput(length: 10, width: 10, height: 10), 0), 0);
      final r = AirWeightCalculator.calculate([
        const AirPackageInput(length: 10, width: 10, height: 10),
      ], totalGrossKg: 5);
      expect(r.chargeableKg, 5);
      expect(AirWeightCalculator.calculate(const []).chargeableKg, 0);
    });
  });

  group('AwbNumber', () {
    test('valid number with separators', () {
      expect(AwbNumber.validationCode('176-1234 5675'), isNull);
      expect(AwbNumber.isValid('17612345675'), isTrue);
      expect(AwbNumber.format('17612345675'), '176-12345675');
    });

    test('format and check digit errors match backend codes', () {
      expect(AwbNumber.validationCode('176-1234567'), 'AIR_AWB_FORMAT_INVALID');
      expect(AwbNumber.validationCode('176-1234567A'), 'AIR_AWB_FORMAT_INVALID');
      expect(AwbNumber.validationCode('176-12345676'), 'AIR_AWB_CHECK_DIGIT_INVALID');
      expect(AwbNumber.validationCode(''), isNull);
      expect(AwbNumber.isValid(''), isFalse);
    });
  });

  group('models', () {
    test('AirShipmentRecord.fromJson parses weights, packages and storage', () {
      final r = AirShipmentRecord.fromJson({
        'air_record_id': 5,
        'air_record_code': 'AWB-000005',
        'import_file_id': 1,
        'shipment_mode': 'AIR',
        'mawb_number': '17612345675',
        'flight_date': '2026-11-10',
        'gross_weight_kg': 40,
        'chargeable_weight_kg': 100.0,
        'package_lines': [
          {
            'length': 100,
            'width': 50,
            'height': 60,
            'dimension_unit': 'cm',
            'quantity': 2,
            'gross_weight': 20,
            'weight_unit': 'kg',
          },
        ],
        'storage': {
          'status': 'CHARGEABLE',
          'free_days': 3,
          'free_until': '2026-11-12',
          'days_remaining': -3,
          'chargeable_days': 3,
        },
      });
      expect(r.displayAwb, '176-12345675');
      expect(r.flightDate, DateTime(2026, 11, 10));
      expect(r.grossWeightKg, 40.0);
      expect(r.packageLines.single.quantity, 2);
      expect(r.storage!.chargeableDays, 3);
      expect(isoDate(r.storage!.freeUntil), '2026-11-12');
    });

    test('DraftAwbReview.fromJson parses the checklist', () {
      final review = DraftAwbReview.fromJson({
        'awb_review_id': 1,
        'awb_review_code': 'AWBR-000001',
        'air_record_id': 5,
        'version_number': 2,
        'status': 'REVISION_REQUIRED',
        'has_blocking_mismatch': true,
        'open_discrepancies_count': 1,
        'checklist_data': [
          {'check': 'pieces_count', 'status': 'MISMATCH', 'blocking': true, 'draft_value': 3, 'system_value': 2},
        ],
      });
      expect(review.isDecided, isFalse);
      expect(review.checklist.single.draftValue, '3');
      expect(awbCheckLabelsAr.containsKey(review.checklist.single.check), isTrue);
    });

    test('sub-mode lists mirror the backend taxonomy', () {
      expect(airSubModes['AIR'], contains('GENERAL_CARGO'));
      expect(airSubModes['COURIER'], ['EXPRESS', 'POSTAL']);
      for (final subs in airSubModes.values) {
        for (final s in subs) {
          expect(subModeLabelsAr.containsKey(s), isTrue, reason: s);
        }
      }
    });
  });
}
