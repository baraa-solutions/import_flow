import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/theme/density_provider.dart';
import 'dashboard_card_drilldown_dialog.dart';

/// Standalone KPI Card for Operational Dashboard metrics.
class OperationalKpiCard extends StatelessWidget {
  final DisplayDensityMode density;
  final String title;
  final String mainValue;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<DrillDownItem> records;
  final VoidCallback onTap;
  final String clickHint;
  final double cardWidth;

  const OperationalKpiCard({
    super.key,
    required this.density,
    required this.title,
    required this.mainValue,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.records = const [],
    required this.onTap,
    required this.clickHint,
    this.cardWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardPad = density.isUltraCompact ? 8.0 : (density.isCompact ? 10.0 : 14.0);

    return SizedBox(
      width: cardWidth,
      child: Tooltip(
        message: clickHint,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.all(cardPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(density.metricTitleFontSize),
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(density.isUltraCompact ? 4 : 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, color: color, size: density.metricIconSize),
                      ),
                    ],
                  ),
                  SizedBox(height: density.isUltraCompact ? 4 : 8),
                  Row(
                    children: [
                      Expanded(
                        child: CopyableText(
                          mainValue,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(density.metricValueFontSize),
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          showIcon: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: density.buttonIconSize - 2,
                        color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  SizedBox(height: density.isUltraCompact ? 2 : 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(density.tableCellSecondaryFontSize),
                      color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
