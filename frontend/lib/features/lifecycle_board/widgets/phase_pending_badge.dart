import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/lifecycle_board_model.dart';

/// 🏷️ Canonical Phase Pending Badge — ImportFlow ERP
///
/// Compact badge placed atop the 6 Phase Kanban cards to display:
/// - Count of shipments with pending steps (`pendingShipmentsCount`).
/// - Count of shipments with delayed/overdue steps (`delayedShipmentsCount`).
///
/// Complies strictly with ImportFlow ERP UI standards:
/// - Uses the unified [AppStatusBadge] from core widgets.
/// - Wrapped with [SelectionArea] for mouse text selection support.
/// - Exclusively localized through [context.l10n].
/// - Colors and paddings governed by [AppTheme].
class PhasePendingBadge extends StatelessWidget {
  /// Number of active shipments with pending steps in this phase.
  final int pendingShipmentsCount;

  /// Number of shipments with delayed steps in this phase.
  final int delayedShipmentsCount;

  /// Badge display size (defaults to small for compact phase headers).
  final AppStatusBadgeSize size;

  /// Optional click callback when tapping the badge.
  final VoidCallback? onTap;

  const PhasePendingBadge({
    super.key,
    required this.pendingShipmentsCount,
    this.delayedShipmentsCount = 0,
    this.size = AppStatusBadgeSize.small,
    this.onTap,
  });

  /// Factory constructor to create a [PhasePendingBadge] from a [PhaseSummaryModel].
  factory PhasePendingBadge.fromPhaseSummary(
    PhaseSummaryModel phase, {
    Key? key,
    int? delayedShipmentsCount,
    AppStatusBadgeSize size = AppStatusBadgeSize.small,
    VoidCallback? onTap,
  }) {
    return PhasePendingBadge(
      key: key,
      pendingShipmentsCount: phase.totalActiveShipments,
      delayedShipmentsCount: delayedShipmentsCount ?? 0,
      size: size,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Tooltip(
        message: l10n.phasePendingBadgeTooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: _buildBadgeRow(l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeRow(AppLocalizations l10n) {
    final hasDelayed = delayedShipmentsCount > 0;
    final hasPending = pendingShipmentsCount > 0;

    if (!hasDelayed && !hasPending) {
      return AppStatusBadge(
        label: l10n.phaseAllClearBadge,
        severity: AppSeverity.success,
        size: size,
        icon: Icons.check_circle_outline_rounded,
      );
    }

    if (hasDelayed && hasPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppStatusBadge(
            label: l10n.phaseDelayedCountBadge(delayedShipmentsCount),
            severity: AppSeverity.danger,
            size: size,
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(width: 4),
          AppStatusBadge(
            label: l10n.phasePendingCountBadge(pendingShipmentsCount),
            severity: AppSeverity.warning,
            size: size,
            icon: Icons.pending_actions_outlined,
          ),
        ],
      );
    }

    if (hasDelayed) {
      return AppStatusBadge(
        label: l10n.phaseDelayedCountBadge(delayedShipmentsCount),
        severity: AppSeverity.danger,
        size: size,
        icon: Icons.schedule_outlined,
      );
    }

    return AppStatusBadge(
      label: l10n.phasePendingCountBadge(pendingShipmentsCount),
      severity: AppSeverity.warning,
      size: size,
      icon: Icons.pending_actions_outlined,
    );
  }
}
