import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/update_models.dart';
import '../services/app_update_service.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref.watch(dioProvider));
});

/// `GET /check`. Fetched fresh on the banner mount (re-checked if already cached) and every 24 h; it is also
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

/// Injected clock so the 24 h "remind me later" window is testable.
final updateClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// When the user pressed "remind me later" (session memory; the banner returns
/// after 24 h or on the next app start).
final updateBannerDismissedProvider = StateProvider<DateTime?>((ref) => null);

const Duration updateRemindLaterWindow = Duration(hours: 24);

enum UpdateBannerMode { hidden, optional, mandatory }

/// Pure rule behind the banner (plan §4.6/§4.7):
/// - no verified newer release (offline, up to date, bad signature, disabled) -> hidden
/// - mandatory -> always shown, never dismissible
/// - optional -> hidden for 24 h after "remind me later"
UpdateBannerMode resolveBannerMode(UpdateCheckResult? check, DateTime? dismissedAt, DateTime now) {
  if (check == null || !check.hasActionableUpdate) return UpdateBannerMode.hidden;
  if (check.mandatory) return UpdateBannerMode.mandatory;
  if (dismissedAt != null && now.difference(dismissedAt) < updateRemindLaterWindow) {
    return UpdateBannerMode.hidden;
  }
  return UpdateBannerMode.optional;
}

final updateBannerModeProvider = Provider<UpdateBannerMode>((ref) {
  final check = ref.watch(updateCheckProvider).valueOrNull;
  final dismissedAt = ref.watch(updateBannerDismissedProvider);
  final now = ref.watch(updateClockProvider)();
  return resolveBannerMode(check, dismissedAt, now);
});

// ── Download / apply state machine ───────────────────────────────────────────

/// `/status` poll interval while downloading / verifying / backing up.
final updatePollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

final updateStatusProvider =
    StateNotifierProvider<UpdateStatusNotifier, AsyncValue<UpdateStatus>>((ref) {
  return UpdateStatusNotifier(
    ref,
    ref.watch(appUpdateServiceProvider),
    ref.watch(updatePollIntervalProvider),
  );
});

/// Mirrors the backend state machine. Polls `GET /status` only while the state
/// is downloading / verifying / backing_up and stops at any other state.
/// Action methods rethrow Dio errors so the UI can show the backend `detail`.
class UpdateStatusNotifier extends StateNotifier<AsyncValue<UpdateStatus>> {
  final Ref _ref;
  final AppUpdateService _service;
  final Duration _interval;
  Timer? _timer;

  UpdateStatusNotifier(this._ref, this._service, this._interval) : super(const AsyncValue.loading()) {
    refresh();
  }

  /// True while a poll is scheduled (exposed for tests).
  bool get isPolling => _timer?.isActive ?? false;

  Future<void> refresh() async {
    _timer?.cancel();
    try {
      final status = await _service.status();
      if (!mounted) return;
      _apply(status);
    } catch (e, st) {
      if (!mounted) return;
      final previous = state.valueOrNull;
      if (previous != null && previous.state.isPolling) {
        // Transient failure mid-download: keep the last known progress and retry.
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
