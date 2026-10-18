import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/lifecycle_board/models/timeline_snapshot_model.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';

void main() {
  group('TimelineSnapshotModel & TimelineSummaryModel Tests', () {
    test('TimelineSnapshotModel deserializes correctly from backend JSON', () {
      final json = {
        'id': 101,
        'import_file_id': 4,
        'stage_code': 'STAGE_14',
        'stage_name': 'سداد الرسوم الجمركية وفورمة 4',
        'phase_number': 4,
        'phase_name': 'الكشف والتثمين وسداد الرسوم',
        'planned_start_date': '2026-10-18',
        'planned_end_date': '2026-10-20',
        'actual_start_date': '2026-10-18',
        'actual_end_date': null,
        'duration_days': 2.0,
        'sla_days': 2,
        'variance_days': 1.0,
        'status': 'DELAYED',
        'is_bottleneck': true,
        'delay_reason': 'تأخرت المرحلة بمقدار 1 أيام عن SLA',
        'event_details_json': {
          'claim_number': 'CLM-2026-0044',
          'duty_amount': 85000.0,
        },
        'last_synced_at': '2026-10-18T20:00:00Z',
      };

      final model = TimelineSnapshotModel.fromJson(json);

      expect(model.id, 101);
      expect(model.importFileId, 4);
      expect(model.stageCode, 'STAGE_14');
      expect(model.phaseNumber, 4);
      expect(model.status, 'DELAYED');
      expect(model.isBottleneck, true);
      expect(model.varianceDays, 1.0);
      expect(model.eventDetailsJson?['claim_number'], 'CLM-2026-0044');
    });

    test('TimelineSummaryModel aggregates 25 stages correctly', () {
      final json = {
        'import_file_id': 4,
        'import_file_code': 'IMP-2026-0004',
        'total_stages': 25,
        'completed_stages': 12,
        'in_progress_stages': 1,
        'delayed_stages': 2,
        'bottlenecks_count': 1,
        'current_stage_code': 'STAGE_13',
        'current_stage_name': 'اعتماد تقرير الفحص ومطابقة الواردات',
        'snapshots': [
          {
            'id': 1,
            'import_file_id': 4,
            'stage_code': 'STAGE_01',
            'stage_name': 'فتح الملف ودراسة العقد',
            'phase_number': 1,
            'phase_name': 'التعاقد والمستندات',
            'status': 'COMPLETED',
            'is_bottleneck': false,
          },
          {
            'id': 2,
            'import_file_id': 4,
            'stage_code': 'STAGE_14',
            'stage_name': 'سداد الرسوم الجمركية وفورمة 4',
            'phase_number': 4,
            'phase_name': 'الكشف والتثمين وسداد الرسوم',
            'status': 'DELAYED',
            'is_bottleneck': true,
          },
        ],
      };

      final summary = TimelineSummaryModel.fromJson(json);

      expect(summary.importFileId, 4);
      expect(summary.importFileCode, 'IMP-2026-0004');
      expect(summary.totalStages, 25);
      expect(summary.completedStages, 12);
      expect(summary.delayedStages, 2);
      expect(summary.bottlenecksCount, 1);
      expect(summary.snapshots.length, 2);
      expect(summary.snapshots.first.stageCode, 'STAGE_01');
      expect(summary.snapshots.last.isBottleneck, true);
    });
  });

  group('CustomsClearanceModel Pre-Form 4 Fields Tests', () {
    test('Parses tariffCodingDate, bankLinkAcceptedDate, dutyPaymentRequestedDate', () {
      final json = {
        'customs_clearance_id': 88,
        'clearance_code': 'CLR-2026-0088',
        'import_file_id': 4,
        'tariff_coding_date': '2026-10-18',
        'bank_link_accepted_date': '2026-10-18',
        'duty_payment_requested_date': '2026-10-18',
        'nafeza_claim_number': 'CLM-88990',
        'created_at': '2026-10-18T10:00:00Z',
        'updated_at': '2026-10-18T12:00:00Z',
      };

      final model = CustomsClearanceModel.fromJson(json);

      expect(model.customsClearanceId, 88);
      expect(model.tariffCodingDate, '2026-10-18');
      expect(model.bankLinkAcceptedDate, '2026-10-18');
      expect(model.dutyPaymentRequestedDate, '2026-10-18');
      expect(model.nafezaClaimNumber, 'CLM-88990');

      final serialized = model.toJson();
      expect(serialized['tariff_coding_date'], '2026-10-18');
      expect(serialized['bank_link_accepted_date'], '2026-10-18');
      expect(serialized['duty_payment_requested_date'], '2026-10-18');
    });
  });
}
