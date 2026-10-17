import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';

void main() {
  group('BK-01: Freight Booking Confirmation Tests', () {
    test('ShipmentBookingModel correctly parses confirmed booking payload', () {
      final json = {
        'booking_id': 42,
        'booking_code': 'BK-2026-0042',
        'booking_confirmation_no': 'MSC-EGY-998822',
        'import_file_id': 105,
        'import_file_code': 'IMP-2026-0105',
        'shipping_line_name': 'MSC',
        'freight_forwarder_name': 'FastForwarding Ltd',
        'shipment_type': 'Ocean FCL',
        'pol_name': 'Shanghai Port',
        'pod_name': 'Alexandria Port',
        'vessel_name': 'MSC OSCAR',
        'voyage_number': '2608W',
        'etd': '2026-08-15T12:00:00Z',
        'eta': '2026-08-30T18:00:00Z',
        'free_demurrage_days': 21,
        'containers_data': [
          {
            'container_type': '40HC',
            'quantity': 2,
            'container_numbers': ['MSCU1234567', 'MSCU7654321'],
          }
        ],
        'cost_charges_data': [
          {
            'charge_type': 'Sea Freight',
            'unit': 'Per Container',
            'quantity': 2,
            'currency': 'USD',
            'rate': 1900.0,
            'total': 3800.0,
          }
        ],
        'total_freight_cost_usd': 3800.0,
        'status': 'Confirmed',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-05T14:30:00Z',
      };

      final model = ShipmentBookingModel.fromJson(json);

      expect(model.bookingId, 42);
      expect(model.bookingCode, 'BK-2026-0042');
      expect(model.bookingConfirmationNo, 'MSC-EGY-998822');
      expect(model.shippingLineName, 'MSC');
      expect(model.vesselName, 'MSC OSCAR');
      expect(model.voyageNumber, '2608W');
      expect(model.freeDemurrageDays, 21);
      expect(model.status, 'Confirmed');
      expect(model.containersData.length, 1);
      expect(model.containersData.first.containerType, '40HC');
      expect(model.costChargesData.length, 1);
      expect(model.totalFreightCostUsd, 3800.0);
    });

    test('ShipmentBookingModel handles draft status and toJson properly', () {
      final json = {
        'booking_id': 10,
        'booking_code': 'BK-2026-0010',
        'import_file_id': 50,
        'shipping_line_name': 'CMA CGM',
        'free_demurrage_days': 14,
        'status': 'Draft',
        'is_active': true,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      };

      final model = ShipmentBookingModel.fromJson(json);
      expect(model.status, 'Draft');
      expect(model.bookingConfirmationNo, isNull);
      expect(model.freeDemurrageDays, 14);

      final exportedJson = model.toJson();
      expect(exportedJson['booking_code'], 'BK-2026-0010');
      expect(exportedJson['shipping_line_name'], 'CMA CGM');
      expect(exportedJson['free_demurrage_days'], 14);
      expect(exportedJson['status'], 'Draft');
    });

    test('ShipmentBookingModel confirms transition to Confirmed status with vessel details', () {
      final initialJson = {
        'booking_id': 77,
        'booking_code': 'BK-2026-0077',
        'import_file_id': 33,
        'shipping_line_name': 'Hapag-Lloyd',
        'free_demurrage_days': 14,
        'status': 'Draft',
        'is_active': true,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      };

      final draftModel = ShipmentBookingModel.fromJson(initialJson);
      expect(draftModel.status, 'Draft');

      // Simulate confirmation payload returned after confirmBooking API call
      final confirmedJson = Map<String, dynamic>.from(initialJson);
      confirmedJson['status'] = 'Confirmed';
      confirmedJson['booking_confirmation_no'] = 'HL-998811';
      confirmedJson['vessel_name'] = 'AL JASRAH';
      confirmedJson['voyage_number'] = '024E';
      confirmedJson['free_demurrage_days'] = 21;

      final confirmedModel = ShipmentBookingModel.fromJson(confirmedJson);
      expect(confirmedModel.status, 'Confirmed');
      expect(confirmedModel.bookingConfirmationNo, 'HL-998811');
      expect(confirmedModel.vesselName, 'AL JASRAH');
      expect(confirmedModel.voyageNumber, '024E');
      expect(confirmedModel.freeDemurrageDays, 21);
    });

    test('ShipmentBookingModel preserves null freeDemurrageDays when omitted or null', () {
      final json = {
        'booking_id': 101,
        'booking_code': 'BK-2026-0101',
        'shipping_line_name': 'MSC',
        'free_demurrage_days': null,
        'status': 'Draft',
      };

      final model = ShipmentBookingModel.fromJson(json);
      expect(model.freeDemurrageDays, isNull);
      expect(model.toJson()['free_demurrage_days'], isNull);

      final jsonWithoutKey = {
        'booking_id': 102,
        'booking_code': 'BK-2026-0102',
        'shipping_line_name': 'MSC',
        'status': 'Draft',
      };
      final model2 = ShipmentBookingModel.fromJson(jsonWithoutKey);
      expect(model2.freeDemurrageDays, isNull);
      expect(model2.toJson()['free_demurrage_days'], isNull);
    });

    test('ShipmentBookingModel preserves 0 freeDemurrageDays when agreed as zero', () {
      final json = {
        'booking_id': 103,
        'booking_code': 'BK-2026-0103',
        'shipping_line_name': 'Hapag-Lloyd',
        'free_demurrage_days': 0,
        'status': 'Draft',
      };

      final model = ShipmentBookingModel.fromJson(json);
      expect(model.freeDemurrageDays, 0);
      expect(model.toJson()['free_demurrage_days'], 0);
    });
  });
}


