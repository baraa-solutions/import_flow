import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/lifecycle_board_model.dart';

/// 📊 Canonical Shipment KPI Metric Bar — ImportFlow ERP
///
/// Compact, smart, horizontal KPI metric bar displaying critical operational
/// signals for import shipments:
/// 1. Health Score % badge (`AppStatusBadge`) with gradient-like severity.
/// 2. Free Time Burn % with remaining days indicator (Green > 7d, Orange 3-7d, Red < 3d).
/// 3. Overdue & Blocker indicators.
/// 4. Optional Cost Variance % indicator.
///
/// Adheres strictly to ImportFlow ERP canonical UI standards:
/// - Wrapped in [SelectionArea] for desktop mouse text selection.
/// - Uses [AppTheme] surfaces, borders, and severity palettes.
/// - Exclusively relies on [context.l10n] for all text labels and tooltips.
class ShipmentKpiMetricBar extends StatelessWidget {
  /// Operational Health Score percentage (0.0 to 100.0).
  final double? healthScorePercent;

  /// Days of container free time remaining before demurrage starts accruing.
  final int? freeDaysRemaining;

  /// Total contractual free time days granted by the carrier.
  final int? freeDaysTotal;

  /// Optional explicit free time burn percentage (0.0 to 100.0).
  final double? freeTimeBurnPercent;

  /// Number of overdue lifecycle steps or milestones.
  final int overdueStepsCount;

  /// Number of active operational blockers or bottlenecks.
  final int blockersCount;

  /// Variance percentage between actual cost and estimated budget (e.g. +5.2% or -1.5%).
  final double? costVariancePercent;

  /// Whether to use compact padding and small badge sizes.
  final bool isDense;

  /// Optional click callback when tapping the metric bar.
  final VoidCallback? onTap;

  const ShipmentKpiMetricBar({
    super.key,
    this.healthScorePercent,
    this.freeDaysRemaining,
    this.freeDaysTotal,
    this.freeTimeBurnPercent,
    this.overdueStepsCount = 0,
    this.blockersCount = 0,
    this.costVariancePercent,
    this.isDense = false,
    this.onTap,
  });

  /// Factory constructor to create a [ShipmentKpiMetricBar] from a live tracking item.
  factory ShipmentKpiMetricBar.fromTrackingItem(
    LiveLogisticsTrackingItemModel item, {
    Key? key,
    int overdueStepsCount = 0,
    int blockersCount = 0,
    double? costVariancePercent,
    bool isDense = false,
    VoidCallback? onTap,
  }) {
    final parsedScore = double.tryParse(
      item.operationalHealthScore.replaceAll('%', '').trim(),
    );
    final fallbackScore = item.operationalHealthScore.toUpperCase() == 'OPTIMAL'
        ? 100.0
        : (item.operationalHealthScore.toUpperCase() == 'CRITICAL' ? 30.0 : 70.0);

    return ShipmentKpiMetricBar(
      key: key,
      healthScorePercent: parsedScore ?? fallbackScore,
      freeDaysRemaining: item.freeDaysRemaining,
      freeDaysTotal: item.freeDaysTotal,
      overdueStepsCount: overdueStepsCount,
      blockersCount: blockersCount,
      costVariancePercent: costVariancePercent,
      isDense: isDense,
      onTap: onTap,
    );
  }

  /// Factory constructor to create a [ShipmentKpiMetricBar] from a stage card.
  factory ShipmentKpiMetricBar.fromShipmentCard(
    ShipmentStageCardModel shipment, {
    Key? key,
    double? healthScorePercent,
    int? freeDaysRemaining,
    int? freeDaysTotal,
    int overdueStepsCount = 0,
    int blockersCount = 0,
    double? costVariancePercent,
    bool isDense = false,
    VoidCallback? onTap,
  }) {
    return ShipmentKpiMetricBar(
      key: key,
      healthScorePercent: healthScorePercent ?? (shipment.status == 'On-Hold' ? 35.0 : 90.0),
      freeDaysRemaining: freeDaysRemaining,
      freeDaysTotal: freeDaysTotal,
      overdueStepsCount: overdueStepsCount,
      blockersCount: blockersCount > 0 ? blockersCount : (shipment.status == 'On-Hold' ? 1 : 0),
      costVariancePercent: costVariancePercent,
      isDense: isDense,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badgeSize = isDense ? AppStatusBadgeSize.small : AppStatusBadgeSize.medium;

    return SelectionArea(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDense ? 6 : 8,
              vertical: isDense ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Health Score Badge
                _buildHealthScoreBadge(context, l10n, badgeSize),

                // 2. Free Time Burn Badge (if available)
                if (freeDaysRemaining != null || freeTimeBurnPercent != null)
                  _buildFreeTimeBurnBadge(context, l10n, badgeSize),

                // 3. Blockers / Overdue Badge
                _buildBlockersOverdueBadge(context, l10n, badgeSize),

                // 4. Cost Variance Badge (if present)
                if (costVariancePercent != null)
                  _buildCostVarianceBadge(context, l10n, badgeSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthScoreBadge(
    BuildContext context,
    AppLocalizations l10n,
    AppStatusBadgeSize size,
  ) {
    final score = (healthScorePercent ?? 100.0).clamp(0.0, 100.0);
    final severity = score >= 80.0
        ? AppSeverity.success
        : (score >= 50.0 ? AppSeverity.warning : AppSeverity.danger);

    return Tooltip(
      message: l10n.kpiHealthScoreTooltip,
      child: AppStatusBadge(
        label: l10n.kpiHealthScoreValue(score.toInt()),
        severity: severity,
        size: size,
        icon: Icons.speed_rounded,
      ),
    );
  }

  Widget _buildFreeTimeBurnBadge(
    BuildContext context,
    AppLocalizations l10n,
    AppStatusBadgeSize size,
  ) {
    final remainingDays = freeDaysRemaining ?? 0;

    // Compute burn percentage
    final double burn;
    if (freeTimeBurnPercent != null) {
      burn = freeTimeBurnPercent!.clamp(0.0, 100.0);
    } else if (freeDaysTotal != null && freeDaysTotal! > 0) {
      final used = (freeDaysTotal! - remainingDays).clamp(0, freeDaysTotal!);
      burn = ((used / freeDaysTotal!) * 100.0).clamp(0.0, 100.0);
    } else {
      burn = remainingDays <= 0 ? 100.0 : (remainingDays <= 3 ? 80.0 : (remainingDays <= 7 ? 60.0 : 25.0));
    }

    // Severity color coding per KPI Master Contract:
    // Red (Critical): burn > 75% OR remainingDays <= 3.
    // Yellow (Warning): burn > 50% (51-75%) OR remainingDays between 4 and 7.
    // Green (Safe): burn <= 50% OR remainingDays > 7.
    final AppSeverity severity;
    if (burn > 75.0 || remainingDays <= 3) {
      severity = AppSeverity.danger;
    } else if (burn > 50.0 || remainingDays <= 7) {
      severity = AppSeverity.warning;
    } else {
      severity = AppSeverity.success;
    }

    return Tooltip(
      message: l10n.kpiFreeTimeBurnTooltip,
      child: AppStatusBadge(
        label: l10n.kpiFreeTimeBurnValue(burn.toInt(), remainingDays),
        severity: severity,
        size: size,
        icon: Icons.timer_outlined,
      ),
    );
  }

  Widget _buildBlockersOverdueBadge(
    BuildContext context,
    AppLocalizations l10n,
    AppStatusBadgeSize size,
  ) {
    final AppSeverity severity;
    final String label;
    final IconData icon;

    if (blockersCount > 0) {
      severity = AppSeverity.danger;
      label = l10n.kpiBlockersCountBadge(blockersCount);
      icon = Icons.block_rounded;
    } else if (overdueStepsCount > 0) {
      severity = AppSeverity.warning;
      label = l10n.kpiOverdueCountBadge(overdueStepsCount);
      icon = Icons.warning_amber_rounded;
    } else {
      severity = AppSeverity.success;
      label = l10n.kpiNoBlockersBadge;
      icon = Icons.check_circle_outline_rounded;
    }

    return Tooltip(
      message: l10n.kpiBlockersTooltip,
      child: AppStatusBadge(
        label: label,
        severity: severity,
        size: size,
        icon: icon,
      ),
    );
  }

  Widget _buildCostVarianceBadge(
    BuildContext context,
    AppLocalizations l10n,
    AppStatusBadgeSize size,
  ) {
    final variance = costVariancePercent!;
    final sign = variance > 0.0 ? '+' : '';

    // Severity color coding per KPI Master Contract:
    // Green (Safe): variance <= +-3.0%
    // Yellow (Warning): variance between +3.1% and +5.0%
    // Red (Critical): variance > +5.0%
    final AppSeverity severity;
    if (variance > 5.0) {
      severity = AppSeverity.danger;
    } else if (variance > 3.0) {
      severity = AppSeverity.warning;
    } else {
      severity = AppSeverity.success;
    }

    return Tooltip(
      message: l10n.kpiCostVarianceTooltip,
      child: AppStatusBadge(
        label: l10n.kpiCostVarianceValue(sign, variance),
        severity: severity,
        size: size,
        icon: variance > 0.0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      ),
    );
  }
}
