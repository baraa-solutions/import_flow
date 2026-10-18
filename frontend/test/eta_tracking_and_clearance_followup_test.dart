import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/models/shipment_eta_tracking_log_model.dart';
import 'package:frontend/features/customs_clearance/models/clearance_followup_log_model.dart';

void main() {
  group('ShipmentEtaTrackingLogModel & ShipmentBookingModel Tests', () {
    test('ShipmentEtaTrackingLogModel parses JSON correctly', () {
      final json = {
        'log_id': 12,
        'booking_id': 1,
        'import_file_id': 101,
        'tracking_date': '2026-10-18T10:00:00Z',
        'vessel_location': 'Bab El-Mandeb / Red Sea',
        'current_eta': '2026-10-23T12:00:00Z',
        'delay_days': 3,
        'remarks': 'Storm in transit causing 3-day delay',
        'is_ata_confirmed': false,
        'confirmed_ata': null,
        'created_at': '2026-10-18T10:05:00Z',
        'created_by': 'LogisticsOfficer',
      };

      final model = ShipmentEtaTrackingLogModel.fromJson(json);
      expect(model.logId, 12);
      expect(model.bookingId, 1);
      expect(model.vesselLocation, 'Bab El-Mandeb / Red Sea');
      expect(model.delayDays, 3);
      expect(model.isAtaConfirmed, isFalse);

      final out = model.toJson();
      expect(out['delay_days'], 3);
      expect(out['vessel_location'], 'Bab El-Mandeb / Red Sea');
    });

    test('ShipmentBookingModel parses ata and isAtaConfirmed', () {
      final json = {
        'booking_id': 1,
        'booking_code': 'BKG-2026-0001',
        'shipment_type': 'Ocean FCL',
        'status': 'Arrived',
        'ata': '2026-10-22T14:30:00Z',
        'is_ata_confirmed': true,
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-22T14:30:00Z',
      };

      final model = ShipmentBookingModel.fromJson(json);
      expect(model.bookingId, 1);
      expect(model.isAtaConfirmed, isTrue);
      expect(model.ata, '2026-10-22T14:30:00Z');
      expect(model.status, 'Arrived');
    });
  });

  group('ClearanceFollowupLogModel Tests', () {
    test('ClearanceFollowupLogModel parses JSON correctly and serializes', () {
      final json = {
        'log_id': 5,
        'customs_clearance_id': 1,
        'import_file_id': 101,
        'followup_seq': 2,
        'followup_date': '2026-10-24T09:00:00Z',
        'authority_type': 'Customs Valuation Committee',
        'official_contact': 'Mr. Sameh Farag',
        'status_summary': 'Valuation approved as per commercial invoice',
        'action_required': 'Proceed to Form 4 duty payment',
        'next_visit_date': '2026-10-25T10:00:00Z',
        'is_completed': true,
        'created_at': '2026-10-24T09:15:00Z',
        'created_by': 'CustomsBroker',
      };

      final model = ClearanceFollowupLogModel.fromJson(json);
      expect(model.logId, 5);
      expect(model.followupSeq, 2);
      expect(model.authorityType, 'Customs Valuation Committee');
      expect(model.officialContact, 'Mr. Sameh Farag');
      expect(model.isCompleted, isTrue);

      final out = model.toJson();
      expect(out['followup_seq'], 2);
      expect(out['is_completed'], isTrue);
    });
  });
}
