import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';

/// 📦 Container Comparison Dialog for CBM and Load Planning
///
/// Displays dual-mode container options (Stackable vs Non-Stackable) with detailed space & weight metrics.
class ContainerComparisonDialog extends StatelessWidget {
  final ContainerDualRecommendationResult dualRec;
  final double totalCbm;
  final double totalWeightKg;

  const ContainerComparisonDialog({
    super.key,
    required this.dualRec,
    required this.totalCbm,
    required this.totalWeightKg,
  });

  static void show(
    BuildContext context, {
    required ContainerDualRecommendationResult dualRec,
    required double totalCbm,
    required double totalWeightKg,
  }) {
    showDialog(
      context: context,
      builder: (context) => SelectionArea(
        child: ContainerComparisonDialog(
          dualRec: dualRec,
          totalCbm: totalCbm,
          totalWeightKg: totalWeightKg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.containerOptionsAnalysis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  Text(
                    '${l.totalShipmentSummary}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                    style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 750,
          height: 480,
          child: Column(
            children: [
              Container(
                color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                child: TabBar(
                  indicatorColor: AppTheme.cobalt,
                  labelColor: AppTheme.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(icon: const Icon(Icons.layers), text: l.stackableOption),
                    Tab(icon: const Icon(Icons.view_array), text: l.nonStackableOption),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildComparisonTable(context, dualRec.stackableResult),
                    _buildComparisonTable(context, dualRec.nonStackableResult),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context, ContainerRecommendationResult rec) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable ? AppTheme.emerald.withValues(alpha: 0.1) : AppTheme.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: rec.isStackable ? AppTheme.emerald : AppTheme.wcagOrange),
            ),
            child: Text(
              '${l.approvedRecommendation}: ${isArabic ? rec.recommendationSummary : rec.recommendationSummaryEn}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rec.isStackable ? AppTheme.emerald : (isDark ? AppTheme.orange : AppTheme.wcagOrange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.08)),
                children: [
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.containerSpecCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.requiredCountCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.spaceUtilizationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.weightUtilizationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                  Padding(padding: const EdgeInsets.all(8.0), child: Text(l.recommendationCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final int count = detail['reqCount'] as int;
                final double volUtil = detail['spaceUtil'] as double;
                final double weightUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;
                final rowSummary = '${spec.name} | $count x ${spec.code} | Vol: ${volUtil.toStringAsFixed(1)}% | Wt: ${weightUtil.toStringAsFixed(1)}%';

                return TableRow(
                  decoration: isBest ? BoxDecoration(color: AppTheme.emerald.withValues(alpha: isDark ? 0.2 : 0.12)) : null,
                  children: [
                    CopyableTableCell(
                      value: '${spec.name} (${spec.internalVolumeCbm} CBM | ${spec.maxPayloadKg} kg)',
                      rowSummary: rowSummary,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(spec.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isBest ? AppTheme.emerald : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            Text('${l.totalCbmVolumeMetric}: ${spec.internalVolumeCbm} CBM | Max: ${spec.maxPayloadKg} kg', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    CopyableTableCell(
                      value: '$count x ${spec.code}',
                      rowSummary: rowSummary,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('$count x ${spec.code}', style: TextStyle(fontWeight: FontWeight.bold, color: isBest ? AppTheme.emerald : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      ),
                    ),
                    CopyableTableCell(
                      value: '${volUtil.toStringAsFixed(1)}%',
                      rowSummary: rowSummary,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${volUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: volUtil > 90 ? AppTheme.emerald : AppTheme.orange)),
                      ),
                    ),
                    CopyableTableCell(
                      value: '${weightUtil.toStringAsFixed(1)}%',
                      rowSummary: rowSummary,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${weightUtil.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: weightUtil > 90 ? AppTheme.emerald : AppTheme.orange)),
                      ),
                    ),
                    CopyableTableCell(
                      value: isBest ? l.bestOptionBadge : l.viableAlternative,
                      rowSummary: rowSummary,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: isBest
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(4)),
                                child: Text(l.bestOptionBadge, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              )
                            : Text(l.viableAlternative, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
