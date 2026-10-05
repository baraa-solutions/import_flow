import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_provider.dart';

/// Injected clock so the 24 h "remind me later" window is testable.
final updateClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Signed-in user id (null when signed out). A separate provider so tests can
/// switch users without building the real auth notifier.
final updateUserIdProvider = Provider<int?>((ref) {
  return ref.watch(authProvider.select((s) => s.user?.userId));
});

const Duration updateRemindLaterWindow = Duration(hours: 24);

/// "Remind me later" for one optional version.
@immutable
class UpdateSnooze {
  final String version;
  final DateTime at;

  const UpdateSnooze({required this.version, required this.at});

  DateTime get until => at.add(updateRemindLaterWindow);

  bool isActiveAt(DateTime now) => now.isBefore(until);

  /// True when this snooze hides [version] at [now]. A snooze never hides
  /// another (newer) version.
  bool hides(String? version, DateTime now) => version != null && version == this.version && isActiveAt(now);

  /// `version|ISO-8601 UTC timestamp` (same style as `UpdateNoticeStore`).
  String encode() => '$version|${at.toUtc().toIso8601String()}';

  static UpdateSnooze? decode(String? raw) {
    if (raw == null) return null;
    final i = raw.lastIndexOf('|');
    if (i <= 0) return null;
    final at = DateTime.tryParse(raw.substring(i + 1));
    if (at == null) return null;
    return UpdateSnooze(version: raw.substring(0, i), at: at);
  }

  @override
  bool operator ==(Object other) =>
      other is UpdateSnooze && other.version == version && other.at.isAtSameMomentAs(at);

  @override
  int get hashCode => Object.hash(version, at.microsecondsSinceEpoch);

  @override
  String toString() => 'UpdateSnooze($version, $at)';
}

/// Persists the snooze per user in SharedPreferences (not a secret).
class UpdateSnoozeStore {
  static const keyPrefix = 'app_update_snooze_';

  static String keyFor(int? userId) => '$keyPrefix${userId ?? 'anonymous'}';

  Future<UpdateSnooze?> read(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateSnooze.decode(prefs.getString(keyFor(userId)));
  }

  Future<void> write(int? userId, UpdateSnooze snooze) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(userId), snooze.encode());
  }

  Future<void> clear(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(userId));
  }
}

final updateSnoozeStoreProvider = Provider<UpdateSnoozeStore>((ref) => UpdateSnoozeStore());

/// The signed-in user's snooze, or null. Survives restarts and logout/login
/// (SharedPreferences, keyed per user), ends exactly 24 h after "remind me
/// later" through a one-shot timer, and never carries over to another user.
final updateSnoozeProvider = StateNotifierProvider<UpdateSnoozeNotifier, UpdateSnooze?>((ref) {
  final notifier = UpdateSnoozeNotifier(
    store: ref.watch(updateSnoozeStoreProvider),
    clock: ref.watch(updateClockProvider),
    userId: ref.read(updateUserIdProvider),
  );
  ref.listen<int?>(updateUserIdProvider, (previous, next) => notifier.switchUser(previous, next));
  return notifier;
});

class UpdateSnoozeNotifier extends StateNotifier<UpdateSnooze?> {
  final UpdateSnoozeStore _store;
  final DateTime Function() _clock;
  int? _userId;
  Timer? _expiry;

  /// Bumped by every local change so a slower pending read never overwrites it.
  int _generation = 0;
  Future<void> _loading = Future<void>.value();

  UpdateSnoozeNotifier({
    required UpdateSnoozeStore store,
    required DateTime Function() clock,
    required int? userId,
  })  : _store = store,
        _clock = clock,
        _userId = userId,
        super(null) {
    _load();
  }

  /// Completes when the stored snooze of the current user has been read.
  Future<void> get loaded => _loading;

  /// True while the expiry timer is scheduled (exposed for tests).
  bool get hasExpiryTimer => _expiry?.isActive ?? false;

  void _load() {
    final generation = ++_generation;
    final userId = _userId;
    _loading = () async {
      final stored = await _store.read(userId);
      if (!mounted || generation != _generation || stored == null) return;
      if (!stored.isActiveAt(_clock())) {
        await _store.clear(userId);
        return;
      }
      _set(stored);
    }();
  }

  void _set(UpdateSnooze? snooze) {
    _expiry?.cancel();
    _expiry = null;
    if (snooze != null) {
      final remaining = snooze.until.difference(_clock());
      if (remaining <= Duration.zero) {
        state = null;
        return;
      }
      _expiry = Timer(remaining, _expire);
    }
    state = snooze;
  }

  void _expire() {
    _expiry = null;
    if (!mounted) return;
    state = null;
    unawaited(_store.clear(_userId));
  }

  /// "Remind me later" for [version]. Only offered for optional updates; the
  /// banner ignores it for mandatory ones anyway.
  Future<void> snooze(String version) async {
    _generation++;
    final snooze = UpdateSnooze(version: version, at: _clock());
    _set(snooze);
    await _store.write(_userId, snooze);
  }

  /// Drops a snooze that belongs to another version (a newer release was
  /// published), so the new version is announced right away.
  Future<void> retainOnly(String? latestVersion) async {
    await _loading; // the check can arrive before the stored snooze was read
    if (!mounted) return;
    final current = state;
    if (current == null || latestVersion == null || current.version == latestVersion) return;
    _generation++;
    _set(null);
    await _store.clear(_userId);
  }

  /// Logout / session expiry / user switch only reset the in-memory state:
  /// snoozes are stored per user, so the next user starts from their own and
  /// the same user gets theirs back after signing in again (within 24 h).
  void switchUser(int? previous, int? next) {
    if (previous == next) return;
    _generation++;
    _set(null);
    _userId = next;
    if (next != null) _load();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }
}
