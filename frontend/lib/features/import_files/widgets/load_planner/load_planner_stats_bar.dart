// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Summary metrics strip displaying total packages, total weight, total volume,
/// and counts for stackable / non-stackable items.
class LoadPlannerStatsBar extends StatelessWidget {
  final int totalPkgs;
  final double totalPlanWeight;
  final double totalPlanVolume;
  final int stackableInActive;
  final int nonStackableInActive;

  const LoadPlannerStatsBar({
    super.key,
    required this.totalPkgs,
    required this.totalPlanWeight,
    required this.totalPlanVolume,
    required this.stackableInActive,
    required this.nonStackableInActive,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurface
            : AppTheme.charcoal.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildMetricPill(
            '📦',
            '$totalPkgs',
            isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            isDark: isDark,
          ),
          _buildMetricPill(
            '⚖️',
            '${totalPlanWeight.toStringAsFixed(0)} kg',
            isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            isDark: isDark,
          ),
          _buildMetricPill(
            '📐',
            '${totalPlanVolume.toStringAsFixed(3)} m³',
            isDark ? const Color(0xFFFDBA74) : const Color(0xFFB45309),
            isDark: isDark,
          ),
          _buildMetricPill(
            '✅ ${l.allStackableChip}',
            '$stackableInActive',
            isDark ? const Color(0xFF6EE7B7) : AppTheme.wcagEmerald,
            isDark: isDark,
          ),
          _buildMetricPill(
            '🚫 ${l.allNonStackableChip}',
            '$nonStackableInActive',
            isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  static Widget _buildMetricPill(
    String icon,
    String value,
    Color color, {
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(isDark ? 0.6 : 0.25)),
      ),
      child: Text.rich(
        TextSpan(
          text: '$icon ',
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
