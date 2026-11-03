import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';

/// Summary cards and KPI metrics for PO Reconciliation.
/// Displays match statistics, invoice total, package counts, weights, and volumes.
class PoReconciliationSummaryCard extends StatelessWidget {
  final double totalAmount;
  final double totalPackages;
  final double totalGrossWeight;
  final double totalNetWeight;
  final double totalCbm;
  final String currencyStr;
  final Map<String, dynamic>? extractedData;

  const PoReconciliationSummaryCard({
    super.key,
    required this.totalAmount,
    required this.totalPackages,
    required this.totalGrossWeight,
    required this.totalNetWeight,
    required this.totalCbm,
    this.currencyStr = r'$',
    this.extractedData,
  });

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    const cardBg = AppTheme.white;
    final labelColor = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: labelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Optional match rate breakdown from extracted comparison data
    Widget? matchStatsBanner;
    if (extractedData != null) {
      final headerDiscrepancies = extractedData!['header_discrepancies'] as List<dynamic>? ?? [];
      final critCount = extractedData!['critical_discrepancies_count'] as int? ?? 0;
      final warnCount = extractedData!['warning_discrepancies_count'] as int? ?? 0;
      final totalChecks = headerDiscrepancies.length;
      final matchedCount = headerDiscrepancies.where((d) => (d as Map)['status'] == 'MATCH').length;
      final matchPct = totalChecks > 0 ? (matchedCount / totalChecks * 100).toInt() : 100;

      matchStatsBanner = Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics_rounded, size: 18, color: AppTheme.cobalt),
                const SizedBox(width: 6),
                Text(
                  '${context.l10n.poRecMatchStatusMatched}: $matchPct%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.cobalt),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 4),
                Text(
                  '$matchedCount / $totalChecks ${context.l10n.idocAItemsCount(totalChecks)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                ),
              ],
            ),
            if (critCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.crimson),
                  const SizedBox(width: 4),
                  Text(
                    '$critCount ${context.l10n.poRecMatchStatusCritical}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                  ),
                ],
              ),
            if (warnCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.orange),
                  const SizedBox(width: 4),
                  Text(
                    '$warnCount ${context.l10n.poRecMatchStatusWarning}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matchStatsBanner != null) matchStatsBanner,
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 950;
            final kpiCards = [
              _buildSummaryCard(
                context,
                title: l.poRecKpiTotalInvoice,
                value: '${totalAmount.toStringAsFixed(2)} $currencyStr',
                icon: Icons.monetization_on,
                color: AppTheme.cobalt,
              ),
              _buildSummaryCard(
                context,
                title: l.poRecKpiTotalPackages,
                value: '${totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                icon: Icons.all_inbox,
                color: AppTheme.charcoal,
              ),
              _buildSummaryCard(
                context,
                title: l.poRecKpiTotalGrossWeight,
                value: '${_formatWeight(totalGrossWeight)} ${l.poRecKgUnit}',
                icon: Icons.scale,
                color: AppTheme.orange,
              ),
              _buildSummaryCard(
                context,
                title: l.poRecKpiTotalNetWeight,
                value: '${_formatWeight(totalNetWeight)} ${l.poRecKgUnit}',
                icon: Icons.fitness_center,
                color: AppTheme.emerald,
              ),
              _buildSummaryCard(
                context,
                title: l.poRecKpiTotalCbm,
                value: '${totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                icon: Icons.view_in_ar,
                color: AppTheme.cobalt,
              ),
            ];

            if (isDesktop) {
              return Row(
                children: kpiCards
                    .map((c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: c,
                          ),
                        ))
                    .toList(),
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kpiCards
                  .map((c) => SizedBox(
                        width: constraints.maxWidth > 550
                            ? (constraints.maxWidth - 24) / 2
                            : constraints.maxWidth,
                        child: c,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
