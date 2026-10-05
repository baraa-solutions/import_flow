import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_dialog.dart';
import 'update_restarting_overlay.dart';

/// Invisible (zero-size) owner of the update notifications. Mount it once on
/// the home screen OUTSIDE the focus-mode check so that focus mode never hides
/// a mandatory update.
///
/// - Re-checks `GET /check` (and refreshes `GET /status`) on mount and every
///   [recheckInterval].
/// - Opens the non-dismissible mandatory update dialog once per version.
/// - Shows a one-time "update vX is ready" SnackBar with an Install action to
///   administrators (once per version and user, remembered across restarts).
/// - Drops a "remind me later" that belongs to an older version as soon as a
///   newer release is published.
class UpdateNotifierHost extends ConsumerStatefulWidget {
  const UpdateNotifierHost({super.key, this.recheckInterval = const Duration(hours: 24)});

  final Duration recheckInterval;

  static const readySnackInstallKey = ValueKey('update_ready_snack_install');

  @override
  ConsumerState<UpdateNotifierHost> createState() => _UpdateNotifierHostState();
}

class _UpdateNotifierHostState extends ConsumerState<UpdateNotifierHost> {
  Timer? _recheckTimer;
  String? _mandatoryDialogShownFor;
  String? _readyHandledFor;

  @override
  void initState() {
    super.initState();
    // A provider still loading (created in this frame, e.g. by the sidebar pill
    // that builds before this host) is already fetching fresh data; only a
    // completed (possibly stale) result needs a re-fetch.
    final container = ProviderScope.containerOf(context, listen: false);
    final checkExisted =
        container.exists(updateCheckProvider) && !container.read(updateCheckProvider).isLoading;
    final statusExisted =
        container.exists(updateStatusProvider) && !container.read(updateStatusProvider).isLoading;
    if (checkExisted || statusExisted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (checkExisted) ref.invalidate(updateCheckProvider);
        if (statusExisted) ref.read(updateStatusProvider.notifier).refresh();
      });
    }
    _recheckTimer = Timer.periodic(widget.recheckInterval, (_) {
      if (!mounted) return;
      ref.invalidate(updateCheckProvider);
      ref.read(updateStatusProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  void _maybeShowMandatoryDialog(UpdateCheckResult? check) {
    if (check == null || !check.hasActionableUpdate || !check.mandatory) return;
    if (_mandatoryDialogShownFor == check.latestVersion) return;
    _mandatoryDialogShownFor = check.latestVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUpdateDialog(context, check);
    });
  }

  void _maybeAnnounceReady(UpdateStatus? status, bool canInstall, int? userId) {
    final version = status?.version;
    if (!canInstall || status?.state != UpdateState.ready || version == null) return;
    final key = '${userId ?? ''}|$version';
    if (_readyHandledFor == key) return;
    _readyHandledFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceReady(userId, version));
  }

  Future<void> _announceReady(int? userId, String version) async {
    final store = ref.read(updateReadyAnnouncementStoreProvider);
    if (await store.lastAnnounced(userId) == version) return;
    await store.markAnnounced(userId, version);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l = context.l10n;
    messenger.showSnackBar(SnackBar(
      content: Text(l.updateReadySnack(version)),
      backgroundColor: AppTheme.emerald,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        key: UpdateNotifierHost.readySnackInstallKey,
        label: l.updateInstallNow,
        textColor: AppTheme.cloudWhite,
        onPressed: () {
          if (mounted) installUpdateAndRestart(context, ref, version);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UpdateCheckResult>>(updateCheckProvider, (_, next) {
      final check = next.valueOrNull;
      if (check != null && check.hasActionableUpdate) {
        ref.read(updateSnoozeProvider.notifier).retainOnly(check.latestVersion);
      }
    });

    final check = ref.watch(updateCheckProvider).valueOrNull;
    final status = ref.watch(updateStatusProvider).valueOrNull;
    final canInstall = ref.watch(canInstallUpdatesProvider);
    final userId = ref.watch(updateUserIdProvider);

    _maybeShowMandatoryDialog(check);
    _maybeAnnounceReady(status, canInstall, userId);
    return const SizedBox.shrink();
  }
}
