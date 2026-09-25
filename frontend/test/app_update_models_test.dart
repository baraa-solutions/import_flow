import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/app_update/models/update_models.dart';

void main() {
  group('UpdateCheckResult.fromJson', () {
    test('parses the full §6 UpdateCheckResponse', () {
      final r = UpdateCheckResult.fromJson({
        'current_version': '2.0.3',
        'current_build': 205,
        'latest_version': '2.1.0',
        'latest_build': 210,
        'update_available': true,
        'mandatory': true,
        'release_notes': {
          'ar': ['إصلاح أمني'],
          'en': ['Security fix'],
        },
        'released_at': '2026-09-20T10:00:00Z',
        'installer_size_bytes': 212650000,
        'check_status': 'update_available',
        'last_checked_at': '2026-09-24T08:30:00Z',
        'apply_supported': true,
      });
      expect(r.currentVersion, '2.0.3');
      expect(r.currentBuild, 205);
      expect(r.latestVersion, '2.1.0');
      expect(r.latestBuild, 210);
      expect(r.updateAvailable, isTrue);
      expect(r.mandatory, isTrue);
      expect(r.releaseNotes.ar, ['إصلاح أمني']);
      expect(r.releaseNotes.en, ['Security fix']);
      expect(r.releasedAt, DateTime.utc(2026, 9, 20, 10));
      expect(r.installerSizeBytes, 212650000);
      expect(r.checkStatus, UpdateCheckStatus.updateAvailable);
      expect(r.lastCheckedAt, DateTime.utc(2026, 9, 24, 8, 30));
      expect(r.applySupported, isTrue);
      expect(r.hasActionableUpdate, isTrue);
    });

    test('nulls and missing fields fall back to safe defaults', () {
      final r = UpdateCheckResult.fromJson({
        'current_version': '2.0.3',
        'latest_version': null,
        'latest_build': null,
        'release_notes': null,
        'released_at': null,
        'installer_size_bytes': null,
        'last_checked_at': null,
      });
      expect(r.currentBuild, 0);
      expect(r.latestVersion, isNull);
      expect(r.latestBuild, isNull);
      expect(r.updateAvailable, isFalse);
      expect(r.mandatory, isFalse);
      expect(r.releaseNotes.ar, isEmpty);
      expect(r.releaseNotes.en, isEmpty);
      expect(r.releasedAt, isNull);
      expect(r.installerSizeBytes, isNull);
      expect(r.checkStatus, UpdateCheckStatus.unknown);
      expect(r.applySupported, isFalse);
      expect(r.hasActionableUpdate, isFalse);
    });

    test('empty map does not throw', () {
      final r = UpdateCheckResult.fromJson(const {});
      expect(r.currentVersion, '');
      expect(r.hasActionableUpdate, isFalse);
    });

    test('check_status values map to the enum', () {
      for (final e in {
        'up_to_date': UpdateCheckStatus.upToDate,
        'update_available': UpdateCheckStatus.updateAvailable,
        'offline': UpdateCheckStatus.offline,
        'invalid_signature': UpdateCheckStatus.invalidSignature,
        'disabled': UpdateCheckStatus.disabled,
        'something_new': UpdateCheckStatus.unknown,
      }.entries) {
        expect(UpdateCheckStatus.parse(e.key), e.value, reason: e.key);
      }
    });

    test('up_to_date carrying latest_version is not actionable', () {
      final r = UpdateCheckResult.fromJson({
        'current_version': '2.1.0',
        'latest_version': '2.1.0',
        'update_available': false,
        'check_status': 'up_to_date',
      });
      expect(r.hasActionableUpdate, isFalse);
    });

    test('offline / disabled are never actionable even if update_available leaks true', () {
      for (final s in ['offline', 'disabled', 'invalid_signature']) {
        final r = UpdateCheckResult.fromJson({
          'current_version': '2.0.3',
          'latest_version': '2.1.0',
          'update_available': true,
          'check_status': s,
        });
        expect(r.hasActionableUpdate, isFalse, reason: s);
      }
    });
  });

  group('UpdateReleaseNotes.forLanguage', () {
    const notes = UpdateReleaseNotes(ar: ['عربي'], en: ['English']);

    test('returns the notes of the UI language', () {
      expect(notes.forLanguage('ar'), ['عربي']);
      expect(notes.forLanguage('en'), ['English']);
    });

    test('falls back to the other language when empty', () {
      expect(const UpdateReleaseNotes(en: ['English']).forLanguage('ar'), ['English']);
      expect(const UpdateReleaseNotes(ar: ['عربي']).forLanguage('en'), ['عربي']);
    });
  });

  group('UpdateStatus.fromJson', () {
    test('parses states, bytes and error fields', () {
      final s = UpdateStatus.fromJson({
        'state': 'failed',
        'version': '2.1.0',
        'downloaded_bytes': 100,
        'total_bytes': 400,
        'error_code': 'hash_mismatch',
        'error_detail': 'الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه',
      });
      expect(s.state, UpdateState.failed);
      expect(s.version, '2.1.0');
      expect(s.progress, 0.25);
      expect(s.errorCode, 'hash_mismatch');
      expect(s.errorDetail, isNotEmpty);
    });

    test('nulls fall back to idle / zero / null progress', () {
      final s = UpdateStatus.fromJson({'state': null, 'downloaded_bytes': null, 'total_bytes': null});
      expect(s.state, UpdateState.unknown);
      expect(s.downloadedBytes, 0);
      expect(s.totalBytes, 0);
      expect(s.progress, isNull);
      expect(s.errorCode, isNull);
    });

    test('backing_up parses and only downloading/verifying/backing_up poll', () {
      expect(UpdateState.parse('backing_up'), UpdateState.backingUp);
      final polling = UpdateState.values.where((s) => s.isPolling).toSet();
      expect(polling, {UpdateState.downloading, UpdateState.verifying, UpdateState.backingUp});
    });
  });

  group('apply / rollback / last-result / history', () {
    test('apply and rollback 202 bodies', () {
      final a = UpdateApplyResult.fromJson({'state': 'installing', 'backup_file': 'pre_update/x.db'});
      expect(a.state, 'installing');
      expect(a.backupFile, 'pre_update/x.db');
      final r = UpdateRollbackResult.fromJson({'state': 'installing', 'restored_from': 'pre_update/x.db'});
      expect(r.restoredFrom, 'pre_update/x.db');
      expect(UpdateApplyResult.fromJson(const {}).state, 'installing');
    });

    test('last-result parses success and tolerates nulls', () {
      final ok = UpdateLastResult.fromJson({
        'result': 'success',
        'from_version': '2.0.3',
        'to_version': '2.1.0',
        'finished_at': '2026-09-24T09:00:00Z',
        'detail': null,
      });
      expect(ok.result, UpdateResultKind.success);
      expect(ok.toVersion, '2.1.0');
      expect(ok.detail, isNull);
      expect(ok.noticeKey, contains('2.1.0'));
      expect(UpdateLastResult.fromJson({'result': null}).result, UpdateResultKind.none);
    });

    test('history list parses items and ignores junk', () {
      final items = UpdateHistoryItem.listFromJson({
        'items': [
          {'ts': '2026-09-24T09:00:00Z', 'event': 'backup_ok', 'version': '2.1.0', 'detail': 'a.db'},
          'junk',
          {'event': 'check_ok'},
        ],
      });
      expect(items, hasLength(2));
      expect(items.first.event, 'backup_ok');
      expect(items.last.ts, isNull);
      expect(UpdateHistoryItem.listFromJson(null), isEmpty);
    });

    test('rollback candidate prefers last-result backup, else newest backup_ok', () {
      final fromResult = RollbackCandidate.resolve(
        const UpdateLastResult(result: UpdateResultKind.failed, backupFile: 'r.db'),
        const [],
      );
      expect(fromResult!.backupFile, 'r.db');

      final fromHistory = RollbackCandidate.resolve(const UpdateLastResult(), [
        UpdateHistoryItem(ts: DateTime.utc(2026, 9, 1), event: 'backup_ok', detail: 'old.db'),
        UpdateHistoryItem(ts: DateTime.utc(2026, 9, 20), event: 'backup_ok', detail: 'new.db'),
        UpdateHistoryItem(ts: DateTime.utc(2026, 9, 21), event: 'install_launched', detail: 'x'),
      ]);
      expect(fromHistory!.backupFile, 'new.db');
      expect(fromHistory.backupTime, DateTime.utc(2026, 9, 20));

      expect(RollbackCandidate.resolve(null, const []), isNull);
    });
      test('last-result kind: update / rollback / missing (older backend)', () {
      expect(UpdateLastResult.fromJson({'result': 'success', 'kind': 'update'}).kind, UpdateOperationKind.update);
      final rb = UpdateLastResult.fromJson({'result': 'success', 'kind': 'rollback'});
      expect(rb.kind, UpdateOperationKind.rollback);
      expect(rb.isRollback, isTrue);
      expect(rb.allowsRollback, isFalse);
      final legacy = UpdateLastResult.fromJson({'result': 'failed'});
      expect(legacy.kind, isNull);
      expect(legacy.allowsRollback, isTrue);
      expect(UpdateLastResult.fromJson({'kind': 'weird'}).kind, isNull);
      // Notices for an update and a rollback to the same version are distinct.
      expect(rb.noticeKey, isNot(UpdateLastResult.fromJson({'result': 'success', 'kind': 'update'}).noticeKey));
    });

    test('rollback candidate: none after a rollback, offered for update or missing kind', () {
      final history = [UpdateHistoryItem(ts: DateTime.utc(2026, 9, 20), event: 'backup_ok', detail: 'h.db')];
      expect(
        RollbackCandidate.resolve(
          const UpdateLastResult(result: UpdateResultKind.success, kind: UpdateOperationKind.rollback, backupFile: 'r.db'),
          history,
        ),
        isNull,
      );
      expect(
        RollbackCandidate.resolve(
          const UpdateLastResult(result: UpdateResultKind.failed, kind: UpdateOperationKind.update, backupFile: 'r.db'),
          history,
        )!.backupFile,
        'r.db',
      );
      expect(
        RollbackCandidate.resolve(const UpdateLastResult(result: UpdateResultKind.failed), history)!.backupFile,
        'h.db',
      );
    });
  });
}
