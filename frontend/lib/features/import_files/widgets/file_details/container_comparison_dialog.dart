// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/container_requirement_engine.dart';

/// 📊 Container Options Analysis and Comparison Dialog
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
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double totalCbm,
    double totalWeightKg,
  ) {
    showDialog(
      context: context,
      builder: (context) => ContainerComparisonDialog(
        dualRec: dualRec,
        totalCbm: totalCbm,
        totalWeightKg: totalWeightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;

    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.containerOptionsAnalysisTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${l.totalShipmentSummary}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 820,
            height: 500,
            child: Column(
              children: [
                Container(
                  color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                  child: TabBar(
                    indicatorColor: AppTheme.cobalt,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(icon: const Icon(Icons.layers), text: l.containerStackableTab),
                      Tab(icon: const Icon(Icons.view_array), text: l.containerNonStackableTab),
                      Tab(icon: const Icon(Icons.shuffle), text: l.containerMixedTab),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildComparisonTable(context, dualRec.stackableResult, isDark: isDark),
                      _buildComparisonTable(context, dualRec.nonStackableResult, isDark: isDark),
                      _buildComparisonTable(context, dualRec.stackableResult, isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.closeDiagramBtn)),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(
    BuildContext context,
    ContainerRecommendationResult rec, {
    bool isDark = false,
  }) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable
                  ? (isDark ? AppTheme.emerald.withValues(alpha: 0.2) : AppTheme.emerald.withValues(alpha: 0.1))
                  : (isDark ? AppTheme.orange.withValues(alpha: 0.2) : AppTheme.orange.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: rec.isStackable ? AppTheme.emerald : AppTheme.orange,
              ),
            ),
            child: Text(
              '${l.approvedRecommendationPrefix}: ${rec.recommendationSummary}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rec.isStackable
                    ? (isDark ? Colors.green.shade300 : AppTheme.emerald)
                    : (isDark ? Colors.orange.shade300 : AppTheme.orange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.containerSpecType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.requiredCount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.effectiveCapacityCbm, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.spaceUtilizationPercent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.weightUtilizationPercent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final reqCount = detail['reqCount'] as int;
                final effVol = detail['effectiveVolumeCbm'] as double;
                final spaceUtil = detail['spaceUtil'] as double;
                final payloadUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isBest
                        ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.2) : AppTheme.cobalt.withValues(alpha: 0.08))
                        : null,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          if (isBest) const Icon(Icons.star, color: Colors.amber, size: 16),
                          if (isBest) const SizedBox(width: 4),
                          Text(
                            '${spec.code} (${spec.name})',
                            style: TextStyle(
                              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                              color: isBest
                                  ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt)
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '$reqCount',
                        style: TextStyle(
                          fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${effVol.toStringAsFixed(1)} m³',
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${spaceUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: spaceUtil > 80 ? (isDark ? Colors.green.shade300 : Colors.green) : (isDark ? AppTheme.darkTextPrimary : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${payloadUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: payloadUtil > 80 ? (isDark ? Colors.green.shade300 : Colors.green) : (isDark ? AppTheme.darkTextPrimary : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
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
