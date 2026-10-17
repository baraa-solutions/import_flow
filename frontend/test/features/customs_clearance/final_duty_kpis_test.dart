import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_ui.dart';

void main() {
  CustomsClearanceModel buildRecord({
    int id = 1,
    String code = 'CLR-2026-0001',
    String? claimNo,
    double? actualDuty,
    double? totalPayable,
    double? estimatedDuty,
    double? varianceAmount,
    double? paidAmount,
    String paymentStatus = 'Unpaid',
    String status = 'Under Customs Clearance',
  }) {
    return CustomsClearanceModel(
      customsClearanceId: id,
      clearanceCode: code,
      importFileId: 10,
      nafezaClaimNumber: claimNo,
      actualDutyTotal: actualDuty,
      totalDutyPayable: totalPayable,
      estimatedDutyTotal: estimatedDuty,
      dutyVarianceAmount: varianceAmount,
      dutyPaidAmount: paidAmount,
      paymentStatus: paymentStatus,
      status: status,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    );
  }

  group('FinalDutyKpis calculation unit tests', () {
    test('Empty records list yields all zeroes', () {
      final kpis = FinalDutyKpis.from([]);
      expect(kpis.outstanding, equals(0.0));
      expect(kpis.totalPaid, equals(0.0));
      expect(kpis.pendingCount, equals(0));
      expect(kpis.netVariance, equals(0.0));
    });

    test('Paid 1000 vs assessed 1200 sets totalPaid to 1000 and outstanding to 0', () {
      final record = buildRecord(
        claimNo: 'CLM-01',
        actualDuty: 1200.0,
        paidAmount: 1000.0,
        paymentStatus: 'Paid & Verified',
      );

      final kpis = FinalDutyKpis.from([record]);
      expect(kpis.totalPaid, equals(1000.0));
      expect(kpis.outstanding, equals(0.0));
      expect(kpis.pendingCount, equals(0));
    });

    test('Assessed 1200 unpaid sets outstanding to 1200 and increments pendingCount', () {
      final record = buildRecord(
        claimNo: 'CLM-02',
        actualDuty: 1200.0,
        paymentStatus: 'Payment Requested',
      );

      final kpis = FinalDutyKpis.from([record]);
      expect(kpis.outstanding, equals(1200.0));
      expect(kpis.totalPaid, equals(0.0));
      expect(kpis.pendingCount, equals(1));
    });

    test('Unassessed unpaid record is NOT counted in outstanding duties', () {
      final record = buildRecord(
        claimNo: null,
        actualDuty: 500.0,
        paymentStatus: 'Unpaid',
      );

      final kpis = FinalDutyKpis.from([record]);
      expect(kpis.outstanding, equals(0.0));
      expect(kpis.totalPaid, equals(0.0));
      expect(kpis.pendingCount, equals(1));
    });

    test('Recognises legacy "Paid" and "Duties Paid" payment statuses', () {
      final rec1 = buildRecord(
        id: 1,
        paidAmount: 2500.0,
        paymentStatus: 'Paid',
      );
      final rec2 = buildRecord(
        id: 2,
        paidAmount: 3500.0,
        paymentStatus: 'Duties Paid',
      );

      final kpis = FinalDutyKpis.from([rec1, rec2]);
      expect(kpis.totalPaid, equals(6000.0));
      expect(kpis.outstanding, equals(0.0));
      expect(kpis.pendingCount, equals(0));
    });

    test('Net variance only accumulates rows with estimatedDutyTotal > 0', () {
      final withEstimate = buildRecord(
        id: 1,
        estimatedDuty: 10000.0,
        varianceAmount: 450.0,
      );
      final zeroEstimate = buildRecord(
        id: 2,
        estimatedDuty: 0.0,
        varianceAmount: 300.0,
      );
      final nullEstimate = buildRecord(
        id: 3,
        estimatedDuty: null,
        varianceAmount: 200.0,
      );

      final kpis = FinalDutyKpis.from([withEstimate, zeroEstimate, nullEstimate]);
      expect(kpis.netVariance, equals(450.0));
    });

    test('Mixed multi-record ledger produces exact expected KPI totals', () {
      final records = [
        // Paid record (assessed 5000, paid 4800, estimate 4500, variance +500)
        buildRecord(
          id: 1,
          claimNo: 'CLM-01',
          actualDuty: 5000.0,
          paidAmount: 4800.0,
          estimatedDuty: 4500.0,
          varianceAmount: 500.0,
          paymentStatus: 'Paid & Verified',
        ),
        // Assessed unpaid record (assessed 3200, estimate 3000, variance +200)
        buildRecord(
          id: 2,
          claimNo: 'CLM-02',
          actualDuty: 3200.0,
          estimatedDuty: 3000.0,
          varianceAmount: 200.0,
          paymentStatus: 'Payment Requested',
        ),
        // Unassessed record (no claim, estimate 0)
        buildRecord(
          id: 3,
          claimNo: null,
          actualDuty: 1000.0,
          estimatedDuty: 0.0,
          varianceAmount: 1000.0,
          paymentStatus: 'Unpaid',
        ),
      ];

      final kpis = FinalDutyKpis.from(records);
      expect(kpis.totalPaid, equals(4800.0));
      expect(kpis.outstanding, equals(3200.0));
      expect(kpis.pendingCount, equals(2));
      expect(kpis.netVariance, equals(700.0)); // 500 + 200 (id 3 ignored since est == 0)
    });
  });
}
