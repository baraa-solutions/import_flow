import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../po_resolved_metrics.dart';

class PoPlanner3dFleetBanner extends StatelessWidget {
  final String fleetSummary;
  final int totalPkgs;
  final int stackableInActive;
  final int nonStackableInActive;
  final double totalPlanWeight;
  final double totalPlanVolume;

  const PoPlanner3dFleetBanner({
    super.key,
    required this.fleetSummary,
    required this.totalPkgs,
    required this.stackableInActive,
    required this.nonStackableInActive,
    required this.totalPlanWeight,
    required this.totalPlanVolume,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.12),
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 6),
              Text(
                l.requiredContainersSummary(fleetSummary),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.cobalt,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : null,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
              const SizedBox(width: 6),
              Text(
                l.totalWeightSummary(POResolvedMetrics.formatWeight(totalPlanWeight)),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
