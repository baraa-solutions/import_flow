import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/update_indicator.dart';
import '../models/update_models.dart';
import '../services/app_update_service.dart';
import 'update_snooze_providers.dart';

export '../models/update_indicator.dart';
export 'update_snooze_providers.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.watch(dioProvider));
});

/// `GET /check`. Fetched fresh when `UpdateNotifierHost` mounts (re-checked if already cached) and every 24 h; it is also
/// invalidated after download / apply / rollback.
final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  return ref.watch(appUpdateServiceProvider).check();
});

/// `GET /last-result`: drives the one-time post-update notice.
final lastUpdateResultProvider = FutureProvider<UpdateLastResult>((ref) async {
  return ref.watch(appUpdateServiceProvider).lastResult();
});

/// `GET /history` (needs `system.update`).
final updateHistoryProvider = FutureProvider.autoDispose<List<UpdateHistoryItem>>((ref) async {
  return ref.watch(appUpdateServiceProvider).history();
});

/// The backup a rollback would restore, or null when none is known.
/// History is admin-only; a 403 there just means "no candidate from history".
final rollbackCandidateProvider = FutureProvider.autoDispose<RollbackCandidate?>((ref) async {
  final service = ref.watch(appUpdateServiceProvider);
  final last = await service.lastResult();
  if (!last.allowsRollback) return null; // the last operation was a rollback
  List<UpdateHistoryItem> history = const [];
  if (last.backupFile == null) {
    try {
      history = await service.history();
    } catch (_) {
      history = const [];
    }
  }
  return RollbackCandidate.resolve(last, history);
});

/// Install / rollback need `system.update`, which the backend grants to ADMIN
/// only (plan §4.9). The backend still enforces it (403 -> SnackBar).
final canInstallUpdatesProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).user?.isAdmin ?? false;
});

// ── Banner visibility ────────────────────────────────────────────────────────

enum UpdateBannerMode { hidden, optional, mandatory, ready }

/// Pure rule behind the slim banner:
/// - an update already downloaded and verified -> ready (admins only)
/// - no verified newer release (offline, up to date, bad signature, disabled) -> hidden
/// - mandatory -> always shown, never dismissible, snooze ignored
/// - optional -> hidden while "remind me later" is active for this version
UpdateBannerMode resolveBannerMode(
  UpdateCheckResult? check,
  UpdateSnooze? snooze,
  DateTime now, {
  UpdateStatus? status,
  bool canInstall = false,
}) {
  if (canInstall && status?.state == UpdateState.ready) return UpdateBannerMode.ready;
  if (check == null || !check.hasActionableUpdate) return UpdateBannerMode.hidden;
  if (check.mandatory) return UpdateBannerMode.mandatory;
  if (snooze != null && snooze.hides(check.latestVersion, now)) return UpdateBannerMode.hidden;
  return UpdateBannerMode.optional;
}

final updateBannerModeProvider = Provider<UpdateBannerMode>((ref) {
  final canInstall = ref.watch(canInstallUpdatesProvider);
  return resolveBannerMode(
    ref.watch(updateCheckProvider).valueOrNull,
    ref.watch(updateSnoozeProvider),
    ref.watch(updateClockProvider)(),
    status: ref.watch(updateStatusProvider).valueOrNull,
    canInstall: canInstall,
  );
});

/// Sidebar pill state (see [resolveUpdateIndicator]).
final updateIndicatorProvider = Provider<UpdateIndicator>((ref) {
  return resolveUpdateIndicator(
    check: ref.watch(updateCheckProvider).valueOrNull,
    status: ref.watch(updateStatusProvider).valueOrNull,
    canInstall: ref.watch(canInstallUpdatesProvider),
  );
});

// ── Download / apply state machine ───────────────────────────────────────────

/// `/status` poll interval while downloading / verifying / backing up.
final updatePollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

/// Rebuilt when the signed-in user changes: logout disposes the notifier (and
/// its poll timer), and nothing is fetched while signed out, so a stale poll
/// can never hit `/status` with an expired session (401 -> session-expired loop).
final updateStatusProvider =
    StateNotifierProvider<UpdateStatusNotifier, AsyncValue<UpdateStatus>>((ref) {
  return UpdateStatusNotifier(
    ref,
    ref.watch(appUpdateServiceProvider),
    ref.watch(updatePollIntervalProvider),
    signedIn: ref.watch(updateUserIdProvider) != null,
  );
});

/// Only network failures (no response) and 5xx are worth retrying mid-download;
/// 401 / 403 / 4xx mean the session or permission is gone.
bool isTransientUpdateError(Object error) {
  if (error is! DioException) return false;
  final code = error.response?.statusCode;
  return code == null || code >= 500;
}

/// Mirrors the backend state machine. Polls `GET /status` only while the state
/// is downloading / verifying / backing_up and stops at any other state.
/// Action methods rethrow Dio errors so the UI can show the backend `detail`.
class UpdateStatusNotifier extends StateNotifier<AsyncValue<UpdateStatus>> {
  final Ref _ref;
  final AppUpdateService _service;
  final Duration _interval;
  final bool _signedIn;
  Timer? _timer;

  UpdateStatusNotifier(this._ref, this._service, this._interval, {bool signedIn = true})
      : _signedIn = signedIn,
        super(signedIn ? const AsyncValue.loading() : const AsyncValue.data(UpdateStatus.idle)) {
    if (_signedIn) refresh();
  }

  /// True while a poll is scheduled (exposed for tests).
  bool get isPolling => _timer?.isActive ?? false;

  Future<void> refresh() async {
    _timer?.cancel();
    if (!_signedIn || !mounted) return;
    try {
      final status = await _service.status();
      if (!mounted) return;
      _apply(status);
    } catch (e, st) {
      if (!mounted) return;
      final previous = state.valueOrNull;
      if (previous != null && previous.state.isPolling && isTransientUpdateError(e)) {
        // Network blip / 5xx mid-download: keep the last known progress and retry.
        _timer = Timer(_interval, refresh);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void _apply(UpdateStatus status) {
    _timer?.cancel();
    state = AsyncValue.data(status);
    if (status.state.isPolling) {
      _timer = Timer(_interval, refresh);
    }
  }

  Future<void> startDownload(String version) async {
    final status = await _service.download(version);
    if (!mounted) return;
    _apply(status);
    _ref.invalidate(updateCheckProvider);
  }

  Future<void> cancelDownload() async {
    final status = await _service.cancel();
    if (!mounted) return;
    _apply(status);
  }

  Future<UpdateApplyResult> applyUpdate(String version) async {
    final result = await _service.apply(version);
    if (mounted) _apply(UpdateStatus(state: UpdateState.installing, version: version));
    _ref.invalidate(updateCheckProvider);
    _ref.invalidate(lastUpdateResultProvider);
    return result;
  }

  Future<UpdateStatus> stageLocal({required String manifestPath, required String installerPath}) async {
    final status = await _service.stageLocal(manifestPath: manifestPath, installerPath: installerPath);
    if (mounted) _apply(status);
    _ref.invalidate(updateCheckProvider);
    return status;
  }

  Future<UpdateRollbackResult> rollback(String backupFile) async {
    final result = await _service.rollback(backupFile);
    if (mounted) _apply(const UpdateStatus(state: UpdateState.installing));
    _ref.invalidate(updateCheckProvider);
    _ref.invalidate(lastUpdateResultProvider);
    return result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ── Process exit after apply / rollback ──────────────────────────────────────

/// Delay between showing the "restarting" overlay and closing the app, so the
/// installer's taskkill doesn't race the UI.
const Duration updateExitDelay = Duration(milliseconds: 800);

/// Closes the app so the installer can replace the binaries. Never exits under
/// `flutter test` or on web.
void defaultAppExit() {
  if (kIsWeb) return;
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  exit(0);
}

final appExitProvider = Provider<void Function()>((ref) => defaultAppExit);

// ── One-time "update ready" SnackBar ─────────────────────────────────────────

/// Remembers, per user, the last version whose "ready to install" SnackBar was
/// shown, so it appears once per version (also across restarts).
class UpdateReadyAnnouncementStore {
  static const keyPrefix = 'app_update_ready_announced_';

  static String keyFor(int? userId) => '$keyPrefix${userId ?? 'anonymous'}';

  Future<String?> lastAnnounced(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyFor(userId));
  }

  Future<void> markAnnounced(int? userId, String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(userId), version);
  }
}

final updateReadyAnnouncementStoreProvider =
    Provider<UpdateReadyAnnouncementStore>((ref) => UpdateReadyAnnouncementStore());

// ── One-time post-update notice ──────────────────────────────────────────────

/// Remembers which `last-result` was already shown (not a secret, so
/// SharedPreferences is fine).
class UpdateNoticeStore {
  static const _key = 'app_update_last_notice_key';

  Future<String?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> markSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, key);
  }
}

final updateNoticeStoreProvider = Provider<UpdateNoticeStore>((ref) => UpdateNoticeStore());
