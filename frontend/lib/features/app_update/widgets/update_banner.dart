import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_dialog.dart';
import 'update_restarting_overlay.dart';

/// Slim home-screen update strip. Pure view: the re-check timer, the mandatory
/// auto-dialog and the "ready" SnackBar live in `UpdateNotifierHost`.
///
/// Shown only for
/// - a mandatory update (crimson, not dismissible),
/// - an optional update that is not snoozed for its version ("remind me later"),
/// - an update that is downloaded and ready (emerald, "Install now", admins).
/// While a download runs the text is replaced by an inline progress bar.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  static const detailsKey = ValueKey('update_banner_details');
  static const remindLaterKey = ValueKey('update_banner_remind_later');
  static const installKey = ValueKey('update_banner_install');
  static const progressKey = ValueKey('update_banner_progress');

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _installing = false;

  Future<void> _install(String version) async {
    if (_installing) return;
    setState(() => _installing = true);
    final ok = await installUpdateAndRestart(context, ref, version);
    if (mounted && !ok) setState(() => _installing = false);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(updateBannerModeProvider);
    if (mode == UpdateBannerMode.hidden) return const SizedBox.shrink();

    final l = context.l10n;
    final check = ref.watch(updateCheckProvider).valueOrNull;
    final status = ref.watch(updateStatusProvider).valueOrNull ?? UpdateStatus.idle;

    if (mode == UpdateBannerMode.ready) {
      final version = status.version ?? check?.latestVersion ?? '';
      return _strip(
        color: AppTheme.emerald,
        background: AppTheme.emeraldLight,
        icon: Icons.verified_rounded,
        body: _text(l.updateReadyBanner(version), AppTheme.emerald),
        actions: [
          AppButton(
            key: UpdateBanner.installKey,
            label: l.updateInstallNow,
            size: AppButtonSize.small,
            variant: AppButtonVariant.success,
            icon: Icons.rocket_launch_rounded,
            isLoading: _installing,
            onPressed: version.isEmpty ? null : () => _install(version),
          ),
        ],
      );
    }

    if (check == null) return const SizedBox.shrink();
    final mandatory = mode == UpdateBannerMode.mandatory;
    final color = mandatory ? AppTheme.crimson : AppTheme.cobalt;
    final version = check.latestVersion ?? '';
    final busyText = updateBusyText(l, status, installerSizeBytes: check.installerSizeBytes);

    return _strip(
      color: color,
      background: mandatory ? AppTheme.crimsonLight : AppTheme.cobaltLight,
      icon: mandatory ? Icons.warning_amber_rounded : Icons.system_update_rounded,
      body: busyText == null
          ? _text(mandatory ? l.updateMandatoryBanner(version) : l.updateAvailableBanner(version), color)
          : _inlineProgress(busyText, updateBusyProgress(status, installerSizeBytes: check.installerSizeBytes), color),
      actions: [
        AppButton(
          key: UpdateBanner.detailsKey,
          label: l.updateViewDetails,
          size: AppButtonSize.small,
          variant: mandatory ? AppButtonVariant.danger : AppButtonVariant.primary,
          icon: Icons.info_outline_rounded,
          onPressed: () => showUpdateDialog(context, check),
        ),
        if (!mandatory)
          AppButton(
            key: UpdateBanner.remindLaterKey,
            label: l.updateRemindLater,
            size: AppButtonSize.small,
            variant: AppButtonVariant.ghost,
            onPressed: version.isEmpty ? null : () => ref.read(updateSnoozeProvider.notifier).snooze(version),
          ),
      ],
    );
  }

  Widget _text(String text, Color color) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
      );

  Widget _inlineProgress(String text, double? value, Color color) {
    return Row(
      key: UpdateBanner.progressKey,
      children: [
        Flexible(child: _text(text, color)),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppTheme.cloudWhite,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _strip({
    required Color color,
    required Color background,
    required IconData icon,
    required Widget body,
    required List<Widget> actions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: body),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
