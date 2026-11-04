import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/project_model.dart';

/// Top aggregation KPI stats bar for Screen 31: Projects & Cost Centers.
class ProjectsStatsBar extends StatelessWidget {
  final List<ProjectModel> projects;

  const ProjectsStatsBar({
    super.key,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final totalCount = projects.length;
    final openCount = projects.where((p) => p.status.toLowerCase() == 'open').length;
    final activeCount = projects.where((p) => p.isActive).length;

    final totalBudget = projects.fold<double>(
      0.0,
      (sum, p) => sum + (p.totalBudgetUsd ?? 0.0),
    );
    final totalCommitted = projects.fold<double>(
      0.0,
      (sum, p) => sum + (p.totalCommittedUsd ?? 0.0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildMetricCard(
            context,
            l10n.totalLabel,
            '$totalCount',
            AppTheme.cobalt,
            Icons.folder_outlined,
          ),
          _buildMetricCard(
            context,
            l10n.statusOpen,
            '$openCount',
            AppTheme.emerald,
            Icons.pending_actions_outlined,
          ),
          _buildMetricCard(
            context,
            l10n.projectColActive,
            '$activeCount',
            AppTheme.orange,
            Icons.check_circle_outline,
          ),
          _buildMetricCard(
            context,
            l10n.estTotalBudgetUsdLabel,
            '\$${totalBudget.toStringAsFixed(0)}',
            AppTheme.emerald,
            Icons.monetization_on_outlined,
          ),
          _buildMetricCard(
            context,
            l10n.projectCommitmentsLabel,
            '\$${totalCommitted.toStringAsFixed(0)}',
            AppTheme.cobalt,
            Icons.receipt_long_outlined,
          ),
        ];

        if (constraints.maxWidth < 700) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((c) => SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: c,
                    ))
                .toList(),
          );
        }

        return Row(
          children: cards
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: e.key == 0 ? 0 : 4,
                        end: e.key == cards.length - 1 ? 0 : 4,
                      ),
                      child: e.value,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        CopyHelper.copy(
          context,
          '$title: $value',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
