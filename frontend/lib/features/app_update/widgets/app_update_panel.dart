import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_dialog.dart';
import 'update_feedback.dart';
import 'update_from_file_button.dart';
import 'update_restarting_overlay.dart';
import 'update_rollback_dialog.dart';

/// Opens [AppUpdatePanel] in a dialog (used from the System / production-sync
/// screen, whose header has no room for the full card).
Future<void> showAppUpdatePanelDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: const SizedBox(width: 520, child: AppUpdatePanel()),
      actions: [
        AppButton(
          label: ctx.l10n.updateClose,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// "Application updates" card for the System screen: check result (including
/// "last successful check" when offline), check now, open the update dialog,
/// and — for `system.update` holders — update from file and rollback.
class AppUpdatePanel extends ConsumerStatefulWidget {
  const AppUpdatePanel({super.key});

  static const checkNowKey = ValueKey('app_update_panel_check_now');
  static const rollbackKey = ValueKey('app_update_panel_rollback');

  @override
  ConsumerState<AppUpdatePanel> createState() => _AppUpdatePanelState();
}

class _AppUpdatePanelState extends ConsumerState<AppUpdatePanel> {
  bool _checking = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    // Providers first created by this mount's build fetch on creation; only
    // results cached before this mount are re-fetched.
    final checkExisted = ref.exists(updateCheckProvider);
    final statusExisted = ref.exists(updateStatusProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (checkExisted) ref.invalidate(updateCheckProvider);
      if (statusExisted && ref.read(canInstallUpdatesProvider)) {
        ref.read(updateStatusProvider.notifier).refresh();
      }
    });
  }

  /// Installs a staged (e.g. USB) update that is already `ready`.
  Future<void> _installStaged(String version) async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      await ref.read(updateStatusProvider.notifier).applyUpdate(version);
      if (!mounted) return;
      await showRestartingAndExit(context, ref);
    } catch (e) {
      if (mounted) showUpdateErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(appUpdateServiceProvider).check(force: true);
      ref.invalidate(updateCheckProvider);
      await ref.read(updateCheckProvider.future);
    } catch (e) {
      if (mounted) showUpdateErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _statusText(AppLocalizations l, UpdateCheckResult c) {
    if (c.hasActionableUpdate) {
      return c.mandatory
          ? l.updateMandatoryBanner(c.latestVersion!)
          : l.updateAvailableBanner(c.latestVersion!);
    }
    switch (c.checkStatus) {
      case UpdateCheckStatus.offline:
      case UpdateCheckStatus.disabled:
        final last = c.lastCheckedAt == null ? l.updateNeverChecked : formatUpdateTimestamp(c.lastCheckedAt);
        return l.updateCheckOffline(last);
      case UpdateCheckStatus.invalidSignature:
        return l.updateInvalidSignature;
      default:
        return l.updateUpToDate(c.currentVersion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final checkAsync = ref.watch(updateCheckProvider);
    final check = checkAsync.valueOrNull;
    final canInstall = ref.watch(canInstallUpdatesProvider);
    // No rollback right after a rollback (last-result kind == "rollback").
    final canRollback = canInstall &&
        (ref.watch(lastUpdateResultProvider).valueOrNull?.allowsRollback ?? true);
    final status = canInstall ? ref.watch(updateStatusProvider).valueOrNull : null;
    final stagedVersion =
        status != null && status.state == UpdateState.ready ? status.version : null;

    final String text;
    final Color color;
    if (check == null) {
      text = checkAsync.hasError ? updateErrorText(l, checkAsync.error) : l.updateNeverChecked;
      color = checkAsync.hasError ? AppTheme.crimson : AppTheme.charcoal;
    } else {
      text = _statusText(l, check);
      color = check.hasActionableUpdate
          ? (check.mandatory ? AppTheme.crimson : AppTheme.cobalt)
          : (check.checkStatus == UpdateCheckStatus.upToDate ? AppTheme.emerald : AppTheme.orange);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.updateSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
          if (check != null && canInstall && !check.applySupported) ...[
            const SizedBox(height: 4),
            Text(l.updateDevModeDisabled, style: const TextStyle(fontSize: 12, color: AppTheme.orange)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                key: AppUpdatePanel.checkNowKey,
                label: l.updateCheckNow,
                size: AppButtonSize.small,
                icon: Icons.refresh_rounded,
                isLoading: _checking,
                onPressed: _checkNow,
              ),
              if (check != null && check.hasActionableUpdate)
                AppButton(
                  label: l.updateViewDetails,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.success,
                  icon: Icons.system_update_rounded,
                  onPressed: () => showUpdateDialog(context, check),
                ),
              if (stagedVersion != null)
                AppButton(
                  label: l.updateInstallNow,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.success,
                  icon: Icons.rocket_launch_rounded,
                  isLoading: _installing,
                  onPressed: () => _installStaged(stagedVersion),
                ),
              if (canInstall) const UpdateFromFileButton(),
              if (canRollback)
                AppButton(
                  key: AppUpdatePanel.rollbackKey,
                  label: l.updateRollback,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.danger,
                  icon: Icons.restore_rounded,
                  onPressed: () => showUpdateRollbackDialog(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
