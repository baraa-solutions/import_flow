import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/app_update/models/update_format.dart';
import 'package:frontend/features/app_update/models/update_indicator.dart';
import 'package:frontend/features/app_update/models/update_models.dart';

import 'helpers/fake_app_update_service.dart';

const _mb = 1024 * 1024;

void main() {
  const en = AppLocalizationsEn();
  const ar = AppLocalizationsAr();

  group('UpdateStatus.phase parsing', () {
    test('installer / rollback_copy / missing / unknown / null', () {
      expect(UpdateStatus.fromJson({'state': 'downloading', 'phase': 'installer'}).phase, UpdatePhase.installer);
      expect(UpdateStatus.fromJson({'state': 'verifying', 'phase': 'rollback_copy'}).phase, UpdatePhase.rollbackCopy);
      expect(UpdateStatus.fromJson({'state': 'downloading'}).phase, isNull, reason: 'older backend');
      expect(UpdateStatus.fromJson({'state': 'idle', 'phase': null}).phase, isNull);
      expect(UpdateStatus.fromJson({'state': 'idle', 'phase': 'other'}).phase, isNull);
    });

    test('isPreparingRollbackCopy only while verifying the rollback copy', () {
      expect(const UpdateStatus(state: UpdateState.verifying, phase: UpdatePhase.rollbackCopy).isPreparingRollbackCopy,
          isTrue);
      expect(const UpdateStatus(state: UpdateState.verifying).isPreparingRollbackCopy, isFalse);
      expect(const UpdateStatus(state: UpdateState.downloading, phase: UpdatePhase.rollbackCopy).isPreparingRollbackCopy,
          isFalse);
    });
  });

  group('download size uses the installer size', () {
    const installer = 180 * _mb;

    test('older backend summing installer + rollback copy -> installer size wins', () {
      const s = UpdateStatus(state: UpdateState.downloading, downloadedBytes: 90 * _mb, totalBytes: 212 * _mb);
      expect(s.displayTotalBytes(installerSizeBytes: installer), installer);
      expect(s.displayProgress(installerSizeBytes: installer), 0.5);
      expect(updateBusyText(en, s, installerSizeBytes: installer), 'Downloading… 90.0 of 180.0 MB');
    });

    test('new backend total already equals the installer', () {
      const s = UpdateStatus(
          state: UpdateState.downloading, downloadedBytes: 45 * _mb, totalBytes: installer, phase: UpdatePhase.installer);
      expect(s.displayTotalBytes(installerSizeBytes: installer), installer);
      expect(s.displayProgress(installerSizeBytes: installer), 0.25);
    });

    test('downloaded bytes are capped at the installer size', () {
      const s = UpdateStatus(state: UpdateState.downloading, downloadedBytes: 200 * _mb, totalBytes: 212 * _mb);
      expect(s.displayDownloadedBytes(installerSizeBytes: installer), installer);
      expect(s.displayProgress(installerSizeBytes: installer), 1.0);
    });

    test('unknown installer size falls back to the reported total; zero total -> indeterminate', () {
      const s = UpdateStatus(state: UpdateState.downloading, downloadedBytes: 10, totalBytes: 40);
      expect(s.displayTotalBytes(), 40);
      expect(const UpdateStatus(state: UpdateState.downloading).displayProgress(), isNull);
      expect(const UpdateStatus(state: UpdateState.downloading).displayTotalBytes(installerSizeBytes: installer),
          installer);
    });

    test('rollback copy keeps its own total', () {
      const s = UpdateStatus(
        state: UpdateState.verifying,
        phase: UpdatePhase.rollbackCopy,
        downloadedBytes: 3 * _mb,
        totalBytes: 150 * _mb,
      );
      expect(s.displayTotalBytes(installerSizeBytes: installer), 150 * _mb);
      expect(updateBusyText(en, s, installerSizeBytes: installer), 'Preparing rollback copy… 3.0 of 150.0 MB');
      expect(updateBusyText(ar, s), 'جاري تجهيز نسخة التراجع… 3.0 من 150.0 ميجابايت');
      expect(updateBusyProgress(s), 0.02);
    });

    test('rollback copy without a total -> short text, indeterminate', () {
      const s = UpdateStatus(state: UpdateState.verifying, phase: UpdatePhase.rollbackCopy);
      expect(updateBusyText(en, s), en.updatePreparingRollbackCopyShort);
      expect(updateBusyProgress(s), isNull);
    });

    test('busy text for the other states', () {
      expect(updateBusyText(en, const UpdateStatus(state: UpdateState.verifying)), en.updateVerifying);
      expect(updateBusyText(en, const UpdateStatus(state: UpdateState.backingUp)), en.updateBackingUp);
      expect(updateBusyText(en, const UpdateStatus(state: UpdateState.installing)), en.updateInstalling);
      for (final st in [UpdateState.idle, UpdateState.ready, UpdateState.failed, UpdateState.unknown]) {
        expect(updateBusyText(en, UpdateStatus(state: st)), isNull, reason: st.name);
      }
    });

    test('progressPercent floors and clamps', () {
      expect(progressPercent(null), isNull);
      expect(progressPercent(0.499), 49);
      expect(progressPercent(1.0), 100);
    });
  });

  group('resolveUpdateIndicator (state x role)', () {
    const ready = UpdateStatus(state: UpdateState.ready, version: '2.1.0');
    const failed = UpdateStatus(state: UpdateState.failed, version: '2.1.0', errorDetail: 'x');
    const downloading = UpdateStatus(state: UpdateState.downloading, version: '2.1.0', downloadedBytes: 50, totalBytes: 100);
    const rollbackCopy = UpdateStatus(
        state: UpdateState.verifying, phase: UpdatePhase.rollbackCopy, downloadedBytes: 25, totalBytes: 100);

    UpdateIndicatorKind kind(UpdateCheckResult? check, UpdateStatus? status, bool admin) =>
        resolveUpdateIndicator(check: check, status: status, canInstall: admin).kind;

    for (final admin in [true, false]) {
      final role = admin ? 'admin' : 'user';

      test('$role: nothing to show', () {
        expect(kind(null, null, admin), UpdateIndicatorKind.none);
        expect(kind(offlineCheck, UpdateStatus.idle, admin), UpdateIndicatorKind.none);
        expect(kind(FakeAppUpdateService().checkResult, UpdateStatus.idle, admin), UpdateIndicatorKind.none);
      });

      test('$role: available / mandatory', () {
        expect(kind(optionalCheck, UpdateStatus.idle, admin), UpdateIndicatorKind.available);
        expect(kind(mandatoryCheck, null, admin), UpdateIndicatorKind.mandatory);
      });

      test('$role: progress states are visible to everyone', () {
        final d = resolveUpdateIndicator(check: optionalCheck, status: downloading, canInstall: admin);
        expect(d.kind, UpdateIndicatorKind.downloading);
        expect(d.canInstall, admin);
        final r = resolveUpdateIndicator(check: optionalCheck, status: rollbackCopy, canInstall: admin);
        expect(r.kind, UpdateIndicatorKind.preparingRollback);
        expect(r.progress, 0.25);
        for (final st in [UpdateState.verifying, UpdateState.backingUp, UpdateState.installing]) {
          expect(kind(optionalCheck, UpdateStatus(state: st), admin), UpdateIndicatorKind.working, reason: st.name);
        }
      });

      test('$role: ready / failed', () {
        expect(kind(optionalCheck, ready, admin), admin ? UpdateIndicatorKind.ready : UpdateIndicatorKind.available);
        expect(kind(mandatoryCheck, ready, admin), admin ? UpdateIndicatorKind.ready : UpdateIndicatorKind.mandatory);
        expect(kind(optionalCheck, failed, admin), admin ? UpdateIndicatorKind.failed : UpdateIndicatorKind.available);
        // Staged from file (no actionable check): only admins see it.
        expect(kind(null, ready, admin), admin ? UpdateIndicatorKind.ready : UpdateIndicatorKind.none);
      });
    }

    test('download progress uses the installer size of the check', () {
      const summed = UpdateStatus(
          state: UpdateState.downloading, downloadedBytes: 212650000 ~/ 2, totalBytes: 212650000 + 150000000);
      final i = resolveUpdateIndicator(check: optionalCheck, status: summed, canInstall: true);
      expect(i.progress, 0.5);
    });

    test('mandatory flag and version are carried through busy states', () {
      final i = resolveUpdateIndicator(check: mandatoryCheck, status: downloading, canInstall: true);
      expect(i.mandatory, isTrue);
      expect(i.version, '2.1.0');
      expect(i.isBusy, isTrue);
    });
  });
}
