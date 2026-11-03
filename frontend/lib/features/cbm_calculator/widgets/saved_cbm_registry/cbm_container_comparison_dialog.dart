import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Container comparison dialog comparing stackable vs non-stackable packaging scenarios.
class CbmContainerComparisonDialog extends StatelessWidget {
  final ContainerDualRecommendationResult dualRec;
  final double totalCbm;
  final double totalWeightKg;

  const CbmContainerComparisonDialog({
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
      builder: (dialogCtx) => CbmContainerComparisonDialog(
        dualRec: dualRec,
        totalCbm: totalCbm,
        totalWeightKg: totalWeightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: DefaultTabController(
        length: 2,
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : null,
          title: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.cbmContainerComparisonTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${l.totalCbmVolumeMetric}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.cobalt,
                        fontWeight: FontWeight.w600,
                      ),
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
                  color: isDark
                      ? AppTheme.darkElevatedSurface
                      : AppTheme.charcoal,
                  child: TabBar(
                    indicatorColor: AppTheme.cobalt,
                    labelColor: AppTheme.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.layers),
                        text: l.allStackableOption,
                      ),
                      Tab(
                        icon: const Icon(Icons.view_array),
                        text: l.allNonStackableOption,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildComparisonTable(
                        context,
                        dualRec.stackableResult,
                      ),
                      _buildComparisonTable(
                        context,
                        dualRec.nonStackableResult,
                      ),
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
      ),
    );
  }

  Widget _buildComparisonTable(
    BuildContext context,
    ContainerRecommendationResult rec,
  ) {
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
              color: rec.isStackable
                  ? (isDark
                      ? AppTheme.emerald.withValues(alpha: 0.15)
                      : AppTheme.emerald.withValues(alpha: 0.1))
                  : (isDark
                      ? AppTheme.orange.withValues(alpha: 0.15)
                      : AppTheme.orange.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: rec.isStackable
                    ? AppTheme.emerald
                    : (isDark ? AppTheme.orange : AppTheme.wcagOrange),
              ),
            ),
            child: Text(
              '${l.approvedRecommendation}: ${isArabic ? rec.recommendationSummary : rec.recommendationSummaryEn}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rec.isStackable
                    ? AppTheme.emerald
                    : (isDark ? AppTheme.orange : AppTheme.wcagOrange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkCardBackground
                      : AppTheme.charcoal.withValues(alpha: 0.08),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l.containerSpecCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l.cbmRequiredContainerCount,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l.cbmSpaceUtilizationPercent,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l.weightUtilizationCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l.recommendationCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final int count = detail['reqCount'] as int;
                final double volUtil = detail['spaceUtil'] as double;
                final double weightUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: isBest
                      ? BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.12),
                        )
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isBest
                                  ? AppTheme.emerald
                                  : (isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.charcoal),
                            ),
                          ),
                          Text(
                            '${l.cbmVolumeMetric}: ${spec.internalVolumeCbm} CBM | ${l.grossWtPerUnitCol}: ${spec.maxPayloadKg} kg',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '$count x ${spec.code}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isBest
                              ? AppTheme.emerald
                              : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${volUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: volUtil > 90
                              ? AppTheme.emerald
                              : AppTheme.orange,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${weightUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: weightUtil > 90
                              ? AppTheme.emerald
                              : AppTheme.orange,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isBest
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l.bestOptionBadge,
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : Text(
                              l.viableAlternative,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textMuted,
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
