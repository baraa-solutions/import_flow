import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_app_update_service.dart';

ProviderContainer _container(FakeAppUpdateService fake, {DateTime? now}) {
  final c = ProviderContainer(overrides: [
    appUpdateServiceProvider.overrideWithValue(fake),
    updatePollIntervalProvider.overrideWithValue(const Duration(milliseconds: 5)),
    canInstallUpdatesProvider.overrideWithValue(true),
    updateUserIdProvider.overrideWithValue(1),
    if (now != null) updateClockProvider.overrideWithValue(() => now),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _waitFor(bool Function() cond) async {
  for (var i = 0; i < 200 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resolveBannerMode', () {
    final now = DateTime(2026, 9, 24, 12);

    test('hidden when offline, up to date, disabled, invalid signature or no check', () {
      expect(resolveBannerMode(null, null, now), UpdateBannerMode.hidden);
      expect(resolveBannerMode(offlineCheck, null, now), UpdateBannerMode.hidden);
      for (final s in [
        UpdateCheckStatus.upToDate,
        UpdateCheckStatus.disabled,
        UpdateCheckStatus.invalidSignature,
      ]) {
        final c = UpdateCheckResult(
          currentVersion: '2.1.0',
          latestVersion: '2.1.0', // up_to_date may still carry latest_version
          checkStatus: s,
        );
        expect(resolveBannerMode(c, null, now), UpdateBannerMode.hidden, reason: s.name);
      }
    });

    UpdateSnooze snoozed(String version, Duration ago) => UpdateSnooze(version: version, at: now.subtract(ago));

    test('optional is shown and hidden for 24 h after remind-me-later on that version', () {
      expect(resolveBannerMode(optionalCheck, null, now), UpdateBannerMode.optional);
      expect(resolveBannerMode(optionalCheck, snoozed('2.1.0', const Duration(hours: 1)), now), UpdateBannerMode.hidden);
      expect(
        resolveBannerMode(optionalCheck, snoozed('2.1.0', const Duration(hours: 23, minutes: 59)), now),
        UpdateBannerMode.hidden,
      );
      expect(resolveBannerMode(optionalCheck, snoozed('2.1.0', const Duration(hours: 24)), now), UpdateBannerMode.optional);
    });

    test('a snooze of an older version never hides a newer one', () {
      expect(resolveBannerMode(optionalCheck, snoozed('2.0.9', const Duration(minutes: 5)), now), UpdateBannerMode.optional);
    });

    test('mandatory ignores the snooze', () {
      expect(
        resolveBannerMode(mandatoryCheck, snoozed('2.1.0', const Duration(minutes: 1)), now),
        UpdateBannerMode.mandatory,
      );
    });

    test('ready is shown to admins only, even when snoozed or without a check', () {
      const ready = UpdateStatus(state: UpdateState.ready, version: '2.1.0');
      expect(resolveBannerMode(null, null, now, status: ready, canInstall: true), UpdateBannerMode.ready);
      expect(
        resolveBannerMode(optionalCheck, snoozed('2.1.0', const Duration(minutes: 1)), now, status: ready, canInstall: true),
        UpdateBannerMode.ready,
      );
      expect(resolveBannerMode(optionalCheck, null, now, status: ready), UpdateBannerMode.optional);
      expect(resolveBannerMode(null, null, now, status: ready), UpdateBannerMode.hidden);
    });
  });

  group('updateBannerModeProvider', () {
    test('offline check -> hidden', () async {
      final c = _container(FakeAppUpdateService(check: offlineCheck));
      await c.read(updateCheckProvider.future);
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.hidden);
    });

    test('up-to-date check -> hidden', () async {
      final c = _container(FakeAppUpdateService());
      await c.read(updateCheckProvider.future);
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.hidden);
    });

    test('mandatory stays visible after a snooze attempt', () async {
      final now = DateTime(2026, 9, 24);
      final c = _container(FakeAppUpdateService(check: mandatoryCheck), now: now);
      await c.read(updateCheckProvider.future);
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.mandatory);
    });

    test('optional hides after snooze', () async {
      final now = DateTime(2026, 9, 24);
      final c = _container(FakeAppUpdateService(check: optionalCheck), now: now);
      await c.read(updateCheckProvider.future);
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.optional);
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.hidden);
    });
  });

  group('UpdateStatusNotifier polling', () {
    test('polls while downloading/verifying and stops at ready', () async {
      final fake = FakeAppUpdateService(statuses: const [
        UpdateStatus(state: UpdateState.downloading, downloadedBytes: 10, totalBytes: 100),
        UpdateStatus(state: UpdateState.downloading, downloadedBytes: 60, totalBytes: 100),
        UpdateStatus(state: UpdateState.verifying),
        UpdateStatus(state: UpdateState.ready, version: '2.1.0'),
      ]);
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => c.read(updateStatusProvider).valueOrNull?.state == UpdateState.ready);

      expect(c.read(updateStatusProvider).value!.state, UpdateState.ready);
      expect(notifier.isPolling, isFalse);
      final callsAtReady = fake.statusCalls;
      expect(callsAtReady, 4);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.statusCalls, callsAtReady, reason: 'no more /status polls after ready');
    });

    test('stops at failed and keeps error_detail', () async {
      final fake = FakeAppUpdateService(statuses: const [
        UpdateStatus(state: UpdateState.downloading),
        UpdateStatus(
          state: UpdateState.failed,
          errorCode: 'hash_mismatch',
          errorDetail: 'الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه',
        ),
      ]);
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => c.read(updateStatusProvider).valueOrNull?.state == UpdateState.failed);

      final s = c.read(updateStatusProvider).value!;
      expect(s.errorCode, 'hash_mismatch');
      expect(s.errorDetail, isNotNull);
      expect(notifier.isPolling, isFalse);
      final calls = fake.statusCalls;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fake.statusCalls, calls);
    });

    test('idle does not poll', () async {
      final fake = FakeAppUpdateService();
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => c.read(updateStatusProvider).hasValue);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(fake.statusCalls, 1);
      expect(notifier.isPolling, isFalse);
    });

    test('retry from failed starts a new download and resumes polling', () async {
      final fake = FakeAppUpdateService(statuses: const [
        UpdateStatus(state: UpdateState.failed, errorCode: 'download_failed'),
        UpdateStatus(state: UpdateState.ready, version: '2.1.0'),
      ]);
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => c.read(updateStatusProvider).hasValue);
      await notifier.startDownload('2.1.0');
      expect(fake.calls, contains('download:2.1.0'));
      await _waitFor(() => c.read(updateStatusProvider).valueOrNull?.state == UpdateState.ready);
      expect(c.read(updateStatusProvider).value!.state, UpdateState.ready);
    });
  });

  group('invalidation after actions', () {
    test('apply invalidates updateCheckProvider and moves to installing', () async {
      final fake = FakeAppUpdateService(
        check: optionalCheck,
        statuses: const [UpdateStatus(state: UpdateState.ready, version: '2.1.0')],
      );
      final c = _container(fake);
      final sub = c.listen(updateCheckProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(updateCheckProvider.future);
      expect(fake.checkCalls, 1);

      final result = await c.read(updateStatusProvider.notifier).applyUpdate('2.1.0');
      expect(result.backupFile, 'pre_update/b.db');
      expect(c.read(updateStatusProvider).value!.state, UpdateState.installing);

      await c.read(updateCheckProvider.future);
      expect(fake.checkCalls, 2, reason: 'check re-fetched after apply');
    });

    test('download and rollback invalidate updateCheckProvider', () async {
      final fake = FakeAppUpdateService(check: optionalCheck);
      final c = _container(fake);
      final sub = c.listen(updateCheckProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(updateCheckProvider.future);

      await c.read(updateStatusProvider.notifier).startDownload('2.1.0');
      await c.read(updateCheckProvider.future);
      expect(fake.checkCalls, 2);

      await c.read(updateStatusProvider.notifier).rollback('pre_update/b.db');
      await c.read(updateCheckProvider.future);
      expect(fake.checkCalls, 3);
      expect(fake.calls, contains('rollback:pre_update/b.db'));
    });

    test('apply error is rethrown and state is unchanged', () async {
      final fake = FakeAppUpdateService(
        statuses: const [UpdateStatus(state: UpdateState.ready, version: '2.1.0')],
      )..actionError = Exception('501');
      final c = _container(fake);
      await _waitFor(() => c.read(updateStatusProvider).hasValue);
      await expectLater(c.read(updateStatusProvider.notifier).applyUpdate('2.1.0'), throwsException);
      expect(c.read(updateStatusProvider).value!.state, UpdateState.ready);
    });
  });

  test('defaultAppExit never exits under flutter test', () {
    // Would terminate the test process if the guard were missing.
    defaultAppExit();
    expect(updateExitDelay, const Duration(milliseconds: 800));
  });
}
