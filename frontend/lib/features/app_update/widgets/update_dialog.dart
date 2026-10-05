import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_feedback.dart';
import 'update_progress_section.dart';
import 'update_restarting_overlay.dart';

/// Opens the update dialog for [check]. Mandatory updates use a
/// non-dismissible dialog (no barrier tap, no Esc/back) with only
/// "install now" and "sign out".
Future<void> showUpdateDialog(BuildContext context, UpdateCheckResult check) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !check.mandatory,
    builder: (_) => UpdateDialog(check: check),
  );
}

class UpdateDialog extends ConsumerStatefulWidget {
  final UpdateCheckResult check;

  const UpdateDialog({super.key, required this.check});

  static const installKey = ValueKey('update_dialog_install');
  static const downloadKey = ValueKey('update_dialog_download');
  static const cancelKey = ValueKey('update_dialog_cancel');
  static const remindLaterKey = ValueKey('update_dialog_remind_later');
  static const signOutKey = ValueKey('update_dialog_sign_out');

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _busy = false;

  UpdateCheckResult get _check => widget.check;

  @override
  void initState() {
    super.initState();
    // Fresh status on open (a download may already be running in the backend).
    // A notifier first created by this mount's build fetches in its constructor.
    if (ref.exists(updateStatusProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(updateStatusProvider.notifier).refresh();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showUpdateErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() => _run(() async {
        await ref.read(updateStatusProvider.notifier).startDownload(_check.latestVersion!);
      });

  Future<void> _cancel() => _run(() async {
        await ref.read(updateStatusProvider.notifier).cancelDownload();
      });

  Future<void> _install(String version) => _run(() async {
        await ref.read(updateStatusProvider.notifier).applyUpdate(version);
        if (!mounted) return;
        await showRestartingAndExit(context, ref);
      });

  void _remindLater() {
    final version = _check.latestVersion;
    // Mandatory updates never offer this button; the banner ignores snoozes for them anyway.
    if (version != null && !_check.mandatory) ref.read(updateSnoozeProvider.notifier).snooze(version);
    Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final version = _check.latestVersion ?? '';
    final status = ref.watch(updateStatusProvider).valueOrNull ?? UpdateStatus.idle;
    final canInstall = ref.watch(canInstallUpdatesProvider);
    final notes = _check.releaseNotes.forLanguage(l.isArabic ? 'ar' : 'en');
    final accent = _check.mandatory ? AppTheme.crimson : AppTheme.cobalt;

    return PopScope(
      canPop: !_check.mandatory,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.updateDialogTitle(version),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.updateCurrentVersion(_check.currentVersion), style: const TextStyle(fontSize: 12)),
                if (_check.installerSizeBytes != null) ...[
                  const SizedBox(height: 4),
                  Text(formatUpdateSize(l, _check.installerSizeBytes!), style: const TextStyle(fontSize: 12)),
                ],
                if (_check.mandatory) ...[
                  const SizedBox(height: 10),
                  Text(l.updateMandatoryNotice,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.crimson, fontWeight: FontWeight.w600)),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l.updateWhatsNew, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  for (final note in notes)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 2),
                      child: Text('• $note', style: const TextStyle(fontSize: 12)),
                    ),
                ],
                UpdateProgressSection(status: status, installerSizeBytes: _check.installerSizeBytes),
                if (!canInstall) _hint(l.updateAdminOnlyNotice),
                if (canInstall && !_check.applySupported) _hint(l.updateDevModeDisabled),
              ],
            ),
          ),
        ),
        actions: _actions(l, status, canInstall, version),
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.orange)),
      );

  List<Widget> _actions(AppLocalizations l, UpdateStatus status, bool canInstall, String version) {
    final actions = <Widget>[
      if (_check.mandatory)
        AppButton(
          key: UpdateDialog.signOutKey,
          label: l.updateSignOut,
          variant: AppButtonVariant.secondary,
          icon: Icons.logout_rounded,
          onPressed: _busy ? null : _signOut,
        )
      else
        AppButton(
          key: UpdateDialog.remindLaterKey,
          label: l.updateRemindLater,
          variant: AppButtonVariant.secondary,
          onPressed: _busy ? null : _remindLater,
        ),
    ];
    if (!canInstall || !_check.applySupported) return actions;

    switch (status.state) {
      case UpdateState.downloading:
        actions.add(AppButton(
          key: UpdateDialog.cancelKey,
          label: l.updateCancel,
          variant: AppButtonVariant.danger,
          icon: Icons.cancel_rounded,
          isLoading: _busy,
          onPressed: _cancel,
        ));
      case UpdateState.verifying:
      case UpdateState.backingUp:
      case UpdateState.installing:
        actions.add(AppButton(label: l.updateInstallNow, isLoading: true, onPressed: null));
      case UpdateState.ready:
        actions.add(AppButton(
          key: UpdateDialog.installKey,
          label: l.updateInstallNow,
          variant: AppButtonVariant.success,
          icon: Icons.rocket_launch_rounded,
          isLoading: _busy,
          onPressed: () => _install(status.version ?? version),
        ));
      case UpdateState.failed:
      case UpdateState.idle:
      case UpdateState.unknown:
        actions.add(AppButton(
          key: UpdateDialog.downloadKey,
          label: status.state == UpdateState.failed ? l.updateRetry : l.updateDownloadNow,
          variant: AppButtonVariant.success,
          icon: Icons.download_rounded,
          isLoading: _busy,
          onPressed: version.isEmpty ? null : _download,
        ));
    }
    return actions;
  }
}
