import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Summary metric cards displayed at the top of the Master Import Report.
class MasterReportSummaryCards extends StatelessWidget {
  final int totalFiles;
  final int openFiles;
  final int inProgressFiles;
  final double totalCost;

  const MasterReportSummaryCards({
    super.key,
    required this.totalFiles,
    required this.openFiles,
    required this.inProgressFiles,
    required this.totalCost,
  });

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: MetricCard(
        data: MetricCardData(
          title: title,
          value: value,
          icon: Icons.insights,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        _buildMetricCard(l.totalFilesMetric, '$totalFiles', AppTheme.charcoal),
        const SizedBox(width: 12),
        _buildMetricCard(l.openFilesMetric, '$openFiles', AppTheme.cobalt),
        const SizedBox(width: 12),
        _buildMetricCard(l.inProgressMetric, '$inProgressFiles', AppTheme.orange),
        const SizedBox(width: 12),
        _buildMetricCard(l.totalCostMetric, '${totalCost.toStringAsFixed(0)} \$', AppTheme.emerald),
      ],
    );
  }
}
