import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'app_update_panel.dart';
import 'update_dialog.dart';

/// Always-visible update state for the sidebar footer (never hidden by
/// "remind me later"). Tapping opens the update dialog (or the updates panel
/// for a file-staged update without a check result).
///
/// [compact] renders a small dot / ring for the collapsed rail.
/// Users without `system.update` get the same pill as information only, with
/// the tooltip "An administrator must install this update".
class UpdateIndicatorPill extends ConsumerWidget {
  const UpdateIndicatorPill({super.key, this.compact = false, this.padding = EdgeInsetsDirectional.zero});

  final bool compact;

  /// Outer padding, applied only while the pill is visible (no gap when up to date).
  final EdgeInsetsGeometry padding;

  static const pillKey = ValueKey('update_indicator_pill');

  /// Upper bound of the full pill (the label ellipsizes beyond it).
  static const double maxPillWidth = 170;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicator = ref.watch(updateIndicatorProvider);
    if (!indicator.isVisible) return const SizedBox.shrink();

    final l = context.l10n;
    final check = ref.watch(updateCheckProvider).valueOrNull;
    final status = ref.watch(updateStatusProvider).valueOrNull ?? UpdateStatus.idle;
    final color = _color(indicator);
    final tooltip = _tooltip(l, indicator, status, check);

    final pill = Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: pillKey,
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(context, check),
            child: compact ? _dot(indicator, color) : _pill(l, indicator, color),
          ),
        ),
      ),
    );
    return padding == EdgeInsetsDirectional.zero ? pill : Padding(padding: padding, child: pill);
  }

  void _open(BuildContext context, UpdateCheckResult? check) {
    if (check != null && check.hasActionableUpdate) {
      showUpdateDialog(context, check);
    } else {
      showAppUpdatePanelDialog(context);
    }
  }

  static Color _color(UpdateIndicator i) {
    switch (i.kind) {
      case UpdateIndicatorKind.ready:
        return AppTheme.emerald;
      case UpdateIndicatorKind.mandatory:
      case UpdateIndicatorKind.failed:
        return AppTheme.crimson;
      case UpdateIndicatorKind.available:
      case UpdateIndicatorKind.downloading:
      case UpdateIndicatorKind.preparingRollback:
      case UpdateIndicatorKind.working:
        return i.mandatory ? AppTheme.crimson : AppTheme.cobalt;
      case UpdateIndicatorKind.none:
        return AppTheme.charcoal;
    }
  }

  static String _label(AppLocalizations l, UpdateIndicator i) {
    final v = i.version ?? '';
    switch (i.kind) {
      case UpdateIndicatorKind.available:
        return l.updatePillAvailable(v);
      case UpdateIndicatorKind.mandatory:
        return l.updatePillMandatory(v);
      case UpdateIndicatorKind.downloading:
        final pct = progressPercent(i.progress);
        return pct == null ? l.updatePillWorking : l.updatePillDownloading('$pct');
      case UpdateIndicatorKind.preparingRollback:
        return l.updatePreparingRollbackCopyShort;
      case UpdateIndicatorKind.working:
        return l.updatePillWorking;
      case UpdateIndicatorKind.ready:
        return l.updatePillReady;
      case UpdateIndicatorKind.failed:
        return l.updateFailed;
      case UpdateIndicatorKind.none:
        return '';
    }
  }

  static String _tooltip(AppLocalizations l, UpdateIndicator i, UpdateStatus status, UpdateCheckResult? check) {
    final v = i.version ?? '';
    final String main;
    switch (i.kind) {
      case UpdateIndicatorKind.available:
        main = l.updateAvailableBanner(v);
      case UpdateIndicatorKind.mandatory:
        main = l.updateMandatoryBanner(v);
      case UpdateIndicatorKind.downloading:
      case UpdateIndicatorKind.preparingRollback:
      case UpdateIndicatorKind.working:
        main = updateBusyText(l, status, installerSizeBytes: check?.installerSizeBytes) ?? l.updatePillWorking;
      case UpdateIndicatorKind.ready:
        main = l.updateReadySnack(v);
      case UpdateIndicatorKind.failed:
        final detail = status.errorDetail;
        main = detail == null ? l.updateFailed : '${l.updateFailed}: $detail';
      case UpdateIndicatorKind.none:
        main = '';
    }
    return i.canInstall ? main : '$main\n${l.updateAdminRequiredTooltip}';
  }

  Widget _leading(UpdateIndicator i, Color fg, double size) {
    if (i.isBusy) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: i.progress,
          strokeWidth: 2,
          backgroundColor: fg.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }
    final IconData icon = switch (i.kind) {
      UpdateIndicatorKind.ready => Icons.rocket_launch_rounded,
      UpdateIndicatorKind.failed => Icons.error_outline_rounded,
      UpdateIndicatorKind.mandatory => Icons.priority_high_rounded,
      _ => Icons.arrow_upward_rounded,
    };
    return Icon(icon, size: size, color: fg);
  }

  Widget _pill(AppLocalizations l, UpdateIndicator i, Color color) {
    const fg = AppTheme.cloudWhite;
    // Bounded so the pill also works as a non-flex child of a Row.
    return Container(
      constraints: const BoxConstraints(maxWidth: maxPillWidth),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _leading(i, fg, 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _label(l, i),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(UpdateIndicator i, Color color) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(4),
      child: i.isBusy
          ? _leading(i, color, 12)
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
    );
  }
}
