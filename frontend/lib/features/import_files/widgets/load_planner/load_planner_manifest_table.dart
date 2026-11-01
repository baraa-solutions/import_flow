// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import 'load_planner_export_helper.dart';

/// Packing list summary table with constrained height and sticky scrollable header.
/// Shows per-container placed items, total gross weight, space utilization %, and operational status.
class LoadPlannerManifestTable extends StatelessWidget {
  final List<ContainerPackingResult> plan;
  final ScrollController tableScrollController;

  const LoadPlannerManifestTable({
    super.key,
    required this.plan,
    required this.tableScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // Sticky Header
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkElevatedSurface
                  : AppTheme.charcoal.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    l.containerSpecType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    l.packingListItemsCol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l.totalGrossWeightFromPl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l.spaceUtilizationPercent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    l.currentPhaseStage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Body
          Expanded(
            child: Scrollbar(
              controller: tableScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: tableScrollController,
                child: Column(
                  children: plan.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final res = entry.value;
                    final placedIds = res.placedItemsSummary;
                    final double spaceUtil = res.spec.internalVolumeCbm > 0
                        ? (res.totalVolume / res.spec.internalVolumeCbm) * 100
                        : 0.0;
                    final statusText = LoadPlannerExportHelper.getPlanStatusText(res, l);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              res.containerCode == 'FAILED'
                                  ? l.containerLoadFailed
                                  : '$idx: ${res.spec.code}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: res.containerCode == 'FAILED'
                                    ? (isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson)
                                    : (isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              placedIds.isEmpty ? '-' : placedIds,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              res.containerCode == 'FAILED'
                                  ? '-'
                                  : '${res.totalWeight.toStringAsFixed(0)} kg',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${spaceUtil.toStringAsFixed(1)}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: statusText.contains(l.containerLoadFailed) ||
                                        statusText.contains('فشل') ||
                                        statusText.contains('Failed')
                                    ? (isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson)
                                    : (statusText.contains(l.allNonStackableChip) ||
                                            statusText.contains('غير قابل') ||
                                            statusText.contains('Non-Stackable')
                                        ? (isDark ? const Color(0xFFFCD34D) : AppTheme.wcagOrange)
                                        : (isDark ? const Color(0xFF6EE7B7) : AppTheme.wcagEmerald)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
