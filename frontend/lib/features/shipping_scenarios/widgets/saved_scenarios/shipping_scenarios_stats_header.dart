import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/master_data_toolbar.dart';
import '../../models/shipping_scenario_model.dart';

class ShippingScenariosStatsHeader extends StatelessWidget {
  final List<ShippingEvaluationModel> sessions;
  final VoidCallback onRefresh;

  const ShippingScenariosStatsHeader({
    super.key,
    required this.sessions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSessions = sessions.length;
    final activeSessions = sessions.where((s) => s.isActive).length;
    final avgTransitAll = totalSessions > 0
        ? sessions.fold<double>(0, (sum, s) => sum + s.avgExpectedTransitDays) / totalSessions
        : 0.0;
    final withRecommendation = sessions
        .where((s) => s.recommendedScenarioProvider != null && s.recommendedScenarioProvider!.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                    label: l.totalStudiesMetric,
                    value: '$totalSessions',
                    color: AppTheme.cobalt,
                  ),
                  _histStatCard(
                    icon: Icons.check_circle_rounded,
                    label: l.activeStatus,
                    value: '$activeSessions',
                    color: AppTheme.emerald,
                  ),
                  _histStatCard(
                    icon: Icons.schedule_rounded,
                    label: l.avgTransitMetric,
                    value: avgTransitAll > 0 ? '${avgTransitAll.toStringAsFixed(1)} d' : '-',
                    color: AppTheme.cobaltBorder,
                  ),
                  _histStatCard(
                    icon: Icons.recommend_rounded,
                    label: l.withRecommendationMetric,
                    value: '$withRecommendation',
                    color: AppTheme.orange,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: MasterDataToolbarWidget(
            moduleEndpoint: 'shipping-evaluations',
            title: 'Shipping_Evaluations',
            onRefreshNeeded: onRefresh,
          ),
        ),
      ],
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
              CopyableText(
                value,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
