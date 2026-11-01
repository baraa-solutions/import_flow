import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';
import 'dynamic_report_builder_constants.dart';

/// KPI Summary bar displaying aggregated statistics for the current report view.
class DynamicReportSummaryBar extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final int activeColumnCount;
  final int masterColumnCount;
  final ReportTemplateMode templateMode;
  final List<ImportFileModel> filteredFiles;

  const DynamicReportSummaryBar({
    super.key,
    required this.totalCount,
    required this.filteredCount,
    required this.activeColumnCount,
    required this.masterColumnCount,
    required this.templateMode,
    required this.filteredFiles,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final releasedCount = filteredFiles.where((f) => f.isCustomsReleased).length;
    final underClearanceCount =
        filteredFiles.where((f) => f.status == 'Under Clearance').length;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.black12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Matching Shipments Count
            _buildMetricItem(
              icon: Icons.inventory_2_outlined,
              iconColor: AppTheme.cobalt,
              label: l.matchingShipments,
              value: '$filteredCount / $totalCount',
            ),

            const SizedBox(width: 4),

            // Customs Released Count
            _buildMetricItem(
              icon: Icons.check_circle_outline,
              iconColor: AppTheme.emerald,
              label: l.dynCustomsReleased,
              value: '$releasedCount',
            ),

            const SizedBox(width: 4),

            // Under Clearance Count
            _buildMetricItem(
              icon: Icons.hourglass_top_outlined,
              iconColor: AppTheme.orange,
              label: l.dynCustomsUnderClearance,
              value: '$underClearanceCount',
            ),

            const SizedBox(width: 4),

            // Active Columns Badge
            _buildMetricItem(
              icon: Icons.view_column_outlined,
              iconColor: AppTheme.charcoal,
              label: DynamicReportBuilderConstants.getTemplateTitle(context, templateMode),
              value: l.dynActiveColumnsCount(activeColumnCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
