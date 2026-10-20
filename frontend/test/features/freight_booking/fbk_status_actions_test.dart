import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_ui.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('FbkUi Status & Predicates (FE04-T02)', () {
    const l = AppLocalizationsEn();

    test('FbkUi.status returns proper severity, labels and icons for all statuses', () {
      final draft = FbkUi.status(l, 'Draft');
      expect(draft.severity, AppSeverity.warning);
      expect(draft.label, 'Draft');

      final requested = FbkUi.status(l, 'Booking Requested');
      expect(requested.severity, AppSeverity.warning);
      expect(requested.label, 'Booking Requested');

      final confirmed = FbkUi.status(l, 'Confirmed');
      expect(confirmed.severity, AppSeverity.success);
      expect(confirmed.label, 'Confirmed');

      final amended = FbkUi.status(l, 'Amended');
      expect(amended.severity, AppSeverity.info);
      expect(amended.label, 'Amended');

      final sailed = FbkUi.status(l, 'Sailed');
      expect(sailed.severity, AppSeverity.info);
      expect(sailed.label, 'Sailed');

      final cancelled = FbkUi.status(l, 'Cancelled');
      expect(cancelled.severity, AppSeverity.danger);
      expect(cancelled.label, 'Cancelled');
    });

    test('canConfirm predicate allows Draft, Booking Requested, and Amended', () {
      expect(FbkUi.canConfirm('Draft'), isTrue);
      expect(FbkUi.canConfirm('Booking Requested'), isTrue);
      expect(FbkUi.canConfirm('Amended'), isTrue);
      expect(FbkUi.canConfirm('Confirmed'), isFalse);
      expect(FbkUi.canConfirm('Sailed'), isFalse);
      expect(FbkUi.canConfirm('Cancelled'), isFalse);
      expect(FbkUi.canConfirm(null), isFalse);
    });

    test('canDepart predicate allows Confirmed and Amended', () {
      expect(FbkUi.canDepart('Confirmed'), isTrue);
      expect(FbkUi.canDepart('Amended'), isTrue);
      expect(FbkUi.canDepart('Draft'), isFalse);
      expect(FbkUi.canDepart('Booking Requested'), isFalse);
      expect(FbkUi.canDepart('Sailed'), isFalse);
      expect(FbkUi.canDepart('Cancelled'), isFalse);
      expect(FbkUi.canDepart(null), isFalse);
    });

    test('canDelete predicate allows Draft, Booking Requested, and Cancelled', () {
      expect(FbkUi.canDelete('Draft'), isTrue);
      expect(FbkUi.canDelete('Booking Requested'), isTrue);
      expect(FbkUi.canDelete('Cancelled'), isTrue);
      expect(FbkUi.canDelete('Confirmed'), isFalse);
      expect(FbkUi.canDelete('Amended'), isFalse);
      expect(FbkUi.canDelete('Sailed'), isFalse);
      expect(FbkUi.canDelete(null), isFalse);
    });

    test('canCancel predicate allows all non-cancelled, non-sailed statuses', () {
      expect(FbkUi.canCancel('Draft'), isTrue);
      expect(FbkUi.canCancel('Booking Requested'), isTrue);
      expect(FbkUi.canCancel('Confirmed'), isTrue);
      expect(FbkUi.canCancel('Amended'), isTrue);
      expect(FbkUi.canCancel('Cancelled'), isFalse);
      expect(FbkUi.canCancel('Sailed'), isFalse);
      expect(FbkUi.canCancel(null), isFalse);
    });

    test('FbkFormat.fileCodeFor resolves file code accurately', () {
      final files = [
        ImportFileModel(
          importFileId: 101,
          importFileCode: 'IMP-2026-001',
          companyName: 'Acme',
          supplierName: 'Global',
          currentModule: 'ImportFiles',
          currentStage: 'Phase 4',
          nextAction: 'Booking',
          createdAt: '2026-01-01',
          updatedAt: '2026-01-02',
        ),
        ImportFileModel(
          importFileId: 102,
          importFileCode: 'IMP-2026-002',
          companyName: 'Beta',
          supplierName: 'Pacific',
          currentModule: 'ImportFiles',
          currentStage: 'Phase 4',
          nextAction: 'Booking',
          createdAt: '2026-01-01',
          updatedAt: '2026-01-02',
        ),
      ];

      expect(FbkFormat.fileCodeFor(101, files), 'IMP-2026-001');
      expect(FbkFormat.fileCodeFor(102, files), 'IMP-2026-002');
      expect(FbkFormat.fileCodeFor(999, files), isNull);
      expect(FbkFormat.fileCodeFor(null, files), isNull);
    });
  });
}
