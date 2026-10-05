import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_app_update_service.dart';

/// Mutable clock shared by the container and the test.
class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

final _testUserId = StateProvider<int?>((ref) => 1);

ProviderContainer _container(_Clock clock, {FakeAppUpdateService? fake}) {
  final c = ProviderContainer(overrides: [
    updateClockProvider.overrideWithValue(clock.call),
    updateUserIdProvider.overrideWith((ref) => ref.watch(_testUserId)),
    canInstallUpdatesProvider.overrideWithValue(true),
    appUpdateServiceProvider.overrideWithValue(fake ?? FakeAppUpdateService(check: optionalCheck)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  final t0 = DateTime.utc(2026, 9, 29, 8);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UpdateSnooze encode/decode', () {
    test('round-trips version|timestamp', () {
      final s = UpdateSnooze(version: '2.1.0', at: t0);
      expect(s.encode(), '2.1.0|2026-09-29T08:00:00.000Z');
      expect(UpdateSnooze.decode(s.encode()), s);
    });

    test('rejects malformed values', () {
      expect(UpdateSnooze.decode(null), isNull);
      expect(UpdateSnooze.decode(''), isNull);
      expect(UpdateSnooze.decode('2.1.0'), isNull);
      expect(UpdateSnooze.decode('|2026-09-29T08:00:00Z'), isNull);
      expect(UpdateSnooze.decode('2.1.0|not-a-date'), isNull);
    });

    test('hides only its own version and only for 24 h', () {
      final s = UpdateSnooze(version: '2.1.0', at: t0);
      expect(s.hides('2.1.0', t0.add(const Duration(hours: 23, minutes: 59))), isTrue);
      expect(s.hides('2.1.0', t0.add(const Duration(hours: 24))), isFalse);
      expect(s.hides('2.2.0', t0), isFalse);
      expect(s.hides(null, t0), isFalse);
    });
  });

  group('UpdateSnoozeNotifier', () {
    test('snooze is stored per version and per user', () async {
      final c = _container(_Clock(t0));
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      expect(c.read(updateSnoozeProvider), UpdateSnooze(version: '2.1.0', at: t0));
      expect((await _prefs()).getString('app_update_snooze_1'), '2.1.0|2026-09-29T08:00:00.000Z');
    });

    test('survives a new ProviderContainer (app restart)', () async {
      final clock = _Clock(t0);
      final first = _container(clock);
      await first.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      first.dispose();

      clock.now = t0.add(const Duration(hours: 3));
      final second = _container(clock);
      await second.read(updateSnoozeProvider.notifier).loaded;
      expect(second.read(updateSnoozeProvider)?.version, '2.1.0');
      expect(second.read(updateSnoozeProvider.notifier).hasExpiryTimer, isTrue);
    });

    test('an expired stored snooze is dropped on load', () async {
      SharedPreferences.setMockInitialValues({'app_update_snooze_1': '2.1.0|2026-09-28T08:00:00.000Z'});
      final c = _container(_Clock(t0));
      await c.read(updateSnoozeProvider.notifier).loaded;
      expect(c.read(updateSnoozeProvider), isNull);
      expect((await _prefs()).containsKey('app_update_snooze_1'), isFalse);
    });

    test('a newer version clears the snooze (memory and prefs)', () async {
      final c = _container(_Clock(t0));
      final n = c.read(updateSnoozeProvider.notifier);
      await n.snooze('2.1.0');
      await n.retainOnly('2.1.0');
      expect(c.read(updateSnoozeProvider)?.version, '2.1.0', reason: 'same version keeps it');
      await n.retainOnly('2.2.0');
      expect(c.read(updateSnoozeProvider), isNull);
      expect((await _prefs()).containsKey('app_update_snooze_1'), isFalse);
      expect(n.hasExpiryTimer, isFalse);
    });

    test('mandatory ignores the snooze; the banner provider shows it', () async {
      final c = _container(_Clock(t0), fake: FakeAppUpdateService(check: mandatoryCheck));
      await c.read(updateCheckProvider.future);
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      expect(c.read(updateBannerModeProvider), UpdateBannerMode.mandatory);
    });

    test('user switch resets the snooze and loads the new user\'s own', () async {
      SharedPreferences.setMockInitialValues({'app_update_snooze_2': '2.0.9|2026-09-29T07:00:00.000Z'});
      final c = _container(_Clock(t0));
      final n = c.read(updateSnoozeProvider.notifier);
      await n.snooze('2.1.0');

      c.read(_testUserId.notifier).state = 2;
      await _flush();
      await n.loaded;
      expect(c.read(updateSnoozeProvider)?.version, '2.0.9', reason: 'user 2 never snoozed 2.1.0');
      expect((await _prefs()).getString('app_update_snooze_1'), startsWith('2.1.0|'),
          reason: 'switching users keeps the other user\'s own snooze');
    });

    test('logout resets memory only; the same user gets the snooze back after signing in again', () async {
      final clock = _Clock(t0);
      final c = _container(clock);
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');

      c.read(_testUserId.notifier).state = null; // logout / session expiry
      await _flush();
      expect(c.read(updateSnoozeProvider), isNull);
      expect((await _prefs()).getString('app_update_snooze_1'), startsWith('2.1.0|'));

      clock.now = t0.add(const Duration(hours: 2));
      c.read(_testUserId.notifier).state = 1;
      await _flush();
      await c.read(updateSnoozeProvider.notifier).loaded;
      expect(c.read(updateSnoozeProvider)?.version, '2.1.0');
      expect(c.read(updateSnoozeProvider.notifier).hasExpiryTimer, isTrue);
    });

    test('logout then another user: no carry-over', () async {
      final c = _container(_Clock(t0));
      await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      c.read(_testUserId.notifier).state = null;
      await _flush();
      c.read(_testUserId.notifier).state = 3;
      await _flush();
      await c.read(updateSnoozeProvider.notifier).loaded;
      expect(c.read(updateSnoozeProvider), isNull);
    });
  });

  testWidgets('snooze ends exactly 24 h later (one-shot timer, fake clock)', (tester) async {
    final clock = _Clock(t0);
    final c = _container(clock);
    await c.read(updateCheckProvider.future);
    await c.read(updateSnoozeProvider.notifier).snooze('2.1.0');
    expect(c.read(updateBannerModeProvider), UpdateBannerMode.hidden);

    clock.now = t0.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    await tester.pump(const Duration(hours: 23, minutes: 59, seconds: 59));
    expect(c.read(updateSnoozeProvider), isNotNull);

    clock.now = t0.add(const Duration(hours: 24));
    await tester.pump(const Duration(seconds: 1));
    expect(c.read(updateSnoozeProvider), isNull);
    expect(c.read(updateBannerModeProvider), UpdateBannerMode.optional,
        reason: 'the banner returns at 24 h, not at the next 24 h re-check (~48 h bug)');
    c.dispose();
  });

  testWidgets('a restored snooze expires after the remaining time only', (tester) async {
    SharedPreferences.setMockInitialValues({'app_update_snooze_1': '2.1.0|2026-09-28T10:00:00.000Z'});
    final clock = _Clock(t0); // 22 h after the snooze -> 2 h left
    final c = _container(clock);
    await c.read(updateSnoozeProvider.notifier).loaded;
    expect(c.read(updateSnoozeProvider), isNotNull);

    await tester.pump(const Duration(hours: 1, minutes: 59));
    expect(c.read(updateSnoozeProvider), isNotNull);
    clock.now = t0.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(c.read(updateSnoozeProvider), isNull);
    c.dispose();
  });
}
