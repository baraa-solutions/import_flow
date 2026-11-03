import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Top summary metric cards and refresh button for CBM Registry.
class CbmRegistrySummaryCards extends StatelessWidget {
  final int totalCalcs;
  final int activeCalcs;
  final double totalCbmAll;
  final double totalWeightAll;
  final VoidCallback onRefresh;

  const CbmRegistrySummaryCards({
    super.key,
    required this.totalCalcs,
    required this.activeCalcs,
    required this.totalCbmAll,
    required this.totalWeightAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Container(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _histStatCard(
                  icon: Icons.folder_copy_rounded,
                  label: l.totalCalculationsMetric,
                  value: '$totalCalcs',
                  color: AppTheme.cobalt,
                ),
                _histStatCard(
                  icon: Icons.check_circle_rounded,
                  label: l.activeSessionsMetric,
                  value: '$activeCalcs',
                  color: AppTheme.emerald,
                ),
                _histStatCard(
                  icon: Icons.view_in_ar_rounded,
                  label: l.totalCbmVolumeMetric,
                  value: '${totalCbmAll.toStringAsFixed(2)} m³',
                  color: AppTheme.wcagOrange,
                ),
                _histStatCard(
                  icon: Icons.scale_rounded,
                  label: l.totalGrossWeightRegistryMetric,
                  value: '${totalWeightAll.toStringAsFixed(0)} kg',
                  color: AppTheme.cobalt,
                ),
              ],
            ),
            AppButton(
              label: l.refreshRegistry,
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _histStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
