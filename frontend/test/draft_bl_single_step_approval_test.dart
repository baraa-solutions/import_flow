import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';

DraftBLReviewModel _review({
  String imp = 'Pending',
  String? impBy,
  String brk = 'Pending',
  String? brkBy,
}) =>
    DraftBLReviewModel(
      blReviewId: 1,
      blReviewCode: 'BL-1',
      draftBlNumber: 'D-1',
      comparisonMatrix: const [],
      hasDiscrepancies: false,
      hasBlockingMismatch: false,
      blockingReasons: const [],
      importerApprovalStatus: imp,
      importerApprovedBy: impBy,
      brokerApprovalStatus: brk,
      brokerApprovedBy: brkBy,
      status: 'REVIEWED_PENDING_APPROVAL',
      isActive: true,
      createdAt: '2026-10-01',
    );

void main() {
  const me = {'Sara Ali', 'sara'};

  test('neither role approved: dual-approval actions', () {
    expect(draftBlSingleStepRole(_review(), currentUserNames: me), isNull);
    expect(draftBlApprovalMode(_review(), currentUserNames: me), DraftBLApprovalMode.dual);
  });

  test('importer approved by someone else: single step completes the broker role', () {
    final r = _review(imp: 'Approved', impBy: 'Omar');
    expect(draftBlSingleStepRole(r, currentUserNames: me), 'customs_broker');
    expect(draftBlApprovalMode(r, currentUserNames: me), DraftBLApprovalMode.singleStep);
  });

  test('broker approved by someone else: single step completes the importer role', () {
    final r = _review(brk: 'Approved', brkBy: 'Omar');
    expect(draftBlSingleStepRole(r, currentUserNames: me), 'importer');
  });

  test('the caller approved the other role: no single step (server would 409)', () {
    final r = _review(imp: 'Approved', impBy: 'SARA ALI');
    expect(draftBlSingleStepRole(r, currentUserNames: me), isNull);
    expect(draftBlApprovalMode(r, currentUserNames: me), DraftBLApprovalMode.dual);
  });

  test('both approved: no single step', () {
    final r = _review(imp: 'Approved', impBy: 'A', brk: 'Approved', brkBy: 'B');
    expect(draftBlSingleStepRole(r, currentUserNames: me), isNull);
  });

  test('no review yet: no single step', () {
    expect(draftBlSingleStepRole(null, currentUserNames: me), isNull);
  });
}
