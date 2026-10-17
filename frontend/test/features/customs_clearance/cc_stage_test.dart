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
    String paymentStatus = 'Pending Payment',
    String status = 'Under Customs Clearance',
    String? releasePermitNo,
    bool quarantineLock = false,
    bool isUnderBond = false,
  }) {
    return CustomsClearanceModel(
      customsClearanceId: id,
      clearanceCode: code,
      importFileId: 10,
      nafezaClaimNumber: claimNo,
      actualDutyTotal: actualDuty,
      totalDutyPayable: totalPayable,
      paymentStatus: paymentStatus,
      status: status,
      releasePermitNo: releasePermitNo,
      quarantineLock: quarantineLock,
      isUnderBondRelease: isUnderBond,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    );
  }

  group('CcStatus pure helper unit tests', () {
    test('isPaid recognises standard and legacy paid payment statuses', () {
      final cases = [
        (status: 'Paid & Verified', expected: true),
        (status: 'Paid', expected: true),
        (status: 'Duties Paid', expected: true),
        (status: 'Pending Payment', expected: false),
        (status: 'Payment Requested', expected: false),
        (status: 'Unpaid', expected: false),
        (status: '', expected: false),
      ];

      for (final c in cases) {
        final record = buildRecord(paymentStatus: c.status);
        expect(
          CcStatus.isPaid(record),
          c.expected,
          reason: 'Expected isPaid for "${c.status}" to be ${c.expected}',
        );
      }
    });

    test('isAssessed requires non-empty claim number and positive effective duty', () {
      final cases = [
        (claim: 'CLM-01', actual: 50000.0, payable: 0.0, expected: true),
        (claim: 'CLM-01', actual: 0.0, payable: 50000.0, expected: true),
        (claim: 'CLM-01', actual: 0.0, payable: 0.0, expected: false),
        (claim: null, actual: 50000.0, payable: 50000.0, expected: false),
        (claim: '', actual: 50000.0, payable: 50000.0, expected: false),
        (claim: '   ', actual: 0.0, payable: 0.0, expected: false),
      ];

      for (final c in cases) {
        final record = buildRecord(
          claimNo: c.claim,
          actualDuty: c.actual,
          totalPayable: c.payable,
        );
        expect(
          CcStatus.isAssessed(record),
          c.expected,
          reason: 'Expected isAssessed(claim: ${c.claim}, actual: ${c.actual}) to be ${c.expected}',
        );
      }
    });

    test('isReleased recognises Final Release status or non-empty permit number', () {
      final cases = [
        (status: 'Final Release Granted', permit: null, expected: true),
        (status: 'Final Release Granted', permit: 'REL-2026-001', expected: true),
        (status: 'Duty Paid', permit: 'REL-2026-001', expected: true),
        (status: 'Duty Paid', permit: null, expected: false),
        (status: 'Duty Paid', permit: '', expected: false),
        (status: 'Under Customs Clearance', permit: null, expected: false),
      ];

      for (final c in cases) {
        final record = buildRecord(status: c.status, releasePermitNo: c.permit);
        expect(
          CcStatus.isReleased(record),
          c.expected,
          reason: 'Expected isReleased(status: ${c.status}, permit: ${c.permit}) to be ${c.expected}',
        );
      }
    });

    test('canPay gates payment strictly: assessed && !isPaid && !isReleased', () {
      final cases = [
        // Case: unassessed -> cannot pay
        (
          desc: 'unassessed record',
          claim: null,
          duty: 0.0,
          paid: 'Pending Payment',
          status: 'Under Customs Clearance',
          permit: null,
          expected: false,
        ),
        // Case: assessed, unpaid, unreleased -> CAN pay
        (
          desc: 'assessed unpaid unreleased record',
          claim: 'CLM-01',
          duty: 45000.0,
          paid: 'Pending Payment',
          status: 'Customs Duties Assessed',
          permit: null,
          expected: true,
        ),
        // Case: assessed, already paid -> cannot pay again
        (
          desc: 'assessed already paid record',
          claim: 'CLM-01',
          duty: 45000.0,
          paid: 'Paid & Verified',
          status: 'Duty Paid',
          permit: null,
          expected: false,
        ),
        // Case: assessed, unpaid but already released -> cannot pay after release
        (
          desc: 'assessed unpaid but already released record',
          claim: 'CLM-01',
          duty: 45000.0,
          paid: 'Pending Payment',
          status: 'Final Release Granted',
          permit: 'REL-001',
          expected: false,
        ),
      ];

      for (final c in cases) {
        final record = buildRecord(
          claimNo: c.claim,
          actualDuty: c.duty,
          paymentStatus: c.paid,
          status: c.status,
          releasePermitNo: c.permit,
        );
        expect(
          CcStatus.canPay(record),
          c.expected,
          reason: 'canPay failed for: ${c.desc}',
        );
      }
    });

    test('canRelease gates final release strictly: isPaid && !quarantineLock && !isReleased', () {
      final cases = [
        // Case: unpaid -> cannot release
        (
          desc: 'unpaid record',
          paid: 'Pending Payment',
          lock: false,
          status: 'Under Customs Clearance',
          permit: null,
          expected: false,
        ),
        // Case: paid, no quarantine lock, not released -> CAN release
        (
          desc: 'paid without quarantine lock',
          paid: 'Paid & Verified',
          lock: false,
          status: 'Duty Paid',
          permit: null,
          expected: true,
        ),
        // Case: legacy paid, no quarantine lock -> CAN release
        (
          desc: 'legacy Paid without quarantine lock',
          paid: 'Paid',
          lock: false,
          status: 'Duty Paid',
          permit: null,
          expected: true,
        ),
        // Case: paid, but quarantine-locked -> cannot release
        (
          desc: 'paid with quarantine lock',
          paid: 'Paid & Verified',
          lock: true,
          status: 'Under Bond Released',
          permit: null,
          expected: false,
        ),
        // Case: paid, unlocked, but already released -> cannot re-release
        (
          desc: 'already released',
          paid: 'Paid & Verified',
          lock: false,
          status: 'Final Release Granted',
          permit: 'REL-001',
          expected: false,
        ),
      ];

      for (final c in cases) {
        final record = buildRecord(
          paymentStatus: c.paid,
          quarantineLock: c.lock,
          status: c.status,
          releasePermitNo: c.permit,
        );
        expect(
          CcStatus.canRelease(record),
          c.expected,
          reason: 'canRelease failed for: ${c.desc}',
        );
      }
    });

    test('canUnderBond gates under-bond release: !isReleased && !isUnderBondRelease', () {
      final cases = [
        (isUnderBond: false, status: 'Under Customs Clearance', permit: null, expected: true),
        (isUnderBond: true, status: 'Under Bond Released', permit: null, expected: false),
        (isUnderBond: false, status: 'Final Release Granted', permit: null, expected: false),
        (isUnderBond: false, status: 'Duty Paid', permit: 'REL-01', expected: false),
      ];

      for (final c in cases) {
        final record = buildRecord(
          isUnderBond: c.isUnderBond,
          status: c.status,
          releasePermitNo: c.permit,
        );
        expect(
          CcStatus.canUnderBond(record),
          c.expected,
          reason: 'canUnderBond failed for underBond=${c.isUnderBond}, status=${c.status}',
        );
      }
    });

    test('canRecordLab allows recording lab result only when under bond with quarantine lock', () {
      final cases = [
        (isUnderBond: true, lock: true, expected: true),
        (isUnderBond: true, lock: false, expected: false),
        (isUnderBond: false, lock: true, expected: false),
        (isUnderBond: false, lock: false, expected: false),
      ];

      for (final c in cases) {
        final record = buildRecord(
          isUnderBond: c.isUnderBond,
          quarantineLock: c.lock,
        );
        expect(
          CcStatus.canRecordLab(record),
          c.expected,
          reason: 'canRecordLab failed for underBond=${c.isUnderBond}, lock=${c.lock}',
        );
      }
    });
  });
}
