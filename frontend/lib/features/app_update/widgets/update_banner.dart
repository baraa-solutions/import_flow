import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_dialog.dart';

/// Home-screen update notice (plan §4.5 step 2, §4.6, §4.7).
///
/// - Re-checks on mount and every 24 h.
/// - Hidden when offline / up to date / disabled / invalid signature.
/// - Optional update: dismissible ("remind me later", back after 24 h).
/// - Mandatory update: not dismissible, and the non-dismissible dialog opens
///   once per version automatically.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key, this.recheckInterval = const Duration(hours: 24)});

  final Duration recheckInterval;

  static const detailsKey = ValueKey('update_banner_details');
  static const remindLaterKey = ValueKey('update_banner_remind_later');

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  Timer? _recheckTimer;
  String? _mandatoryDialogShownFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(updateCheckProvider);
    });
    _recheckTimer = Timer.periodic(widget.recheckInterval, (_) {
      if (mounted) ref.invalidate(updateCheckProvider);
    });
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  void _openDialog(UpdateCheckResult check) {
    if (check.mandatory) _mandatoryDialogShownFor = check.latestVersion;
    showUpdateDialog(context, check);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(updateBannerModeProvider);
    final check = ref.watch(updateCheckProvider).valueOrNull;

    if (mode == UpdateBannerMode.mandatory &&
        check != null &&
        _mandatoryDialogShownFor != check.latestVersion) {
      _mandatoryDialogShownFor = check.latestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showUpdateDialog(context, check);
      });
    }

    if (mode == UpdateBannerMode.hidden || check == null) return const SizedBox.shrink();

    final l = context.l10n;
    final mandatory = mode == UpdateBannerMode.mandatory;
    final color = mandatory ? AppTheme.crimson : AppTheme.cobalt;
    final version = check.latestVersion ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: mandatory ? AppTheme.crimsonLight : AppTheme.cobaltLight,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Icon(mandatory ? Icons.warning_amber_rounded : Icons.system_update_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mandatory ? l.updateMandatoryBanner(version) : l.updateAvailableBanner(version),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            key: UpdateBanner.detailsKey,
            label: l.updateViewDetails,
            size: AppButtonSize.small,
            variant: mandatory ? AppButtonVariant.danger : AppButtonVariant.primary,
            icon: Icons.info_outline_rounded,
            onPressed: () => _openDialog(check),
          ),
          if (!mandatory) ...[
            const SizedBox(width: 8),
            AppButton(
              key: UpdateBanner.remindLaterKey,
              label: l.updateRemindLater,
              size: AppButtonSize.small,
              variant: AppButtonVariant.ghost,
              onPressed: () => ref.read(updateBannerDismissedProvider.notifier).state =
                  ref.read(updateClockProvider)(),
            ),
          ],
        ],
      ),
    );
  }
}
