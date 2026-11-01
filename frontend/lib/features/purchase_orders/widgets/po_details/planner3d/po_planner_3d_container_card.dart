import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../../../core/widgets/container_load_plan_painter.dart';
import 'po_planner_3d_items_table.dart';

class PoPlanner3dContainerCard extends StatelessWidget {
  final int pIdx;
  final ContainerPackingResult res;
  final String viewProjection;

  const PoPlanner3dContainerCard({
    super.key,
    required this.pIdx,
    required this.res,
    required this.viewProjection,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (res.containerCode == 'FAILED') {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.crimsonLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                res.failureReason ?? l.packingFailureTitle,
                style: const TextStyle(
                  color: AppTheme.crimson,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
    final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l.containerCardHeader(
                      pIdx + 1,
                      res.spec.code,
                      res.placedItems.length,
                      spacePct.toStringAsFixed(1),
                      weightPct.toStringAsFixed(1),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.internalDimensionsLabel(
                      res.spec.internalLength.toStringAsFixed(0),
                      res.spec.internalWidth.toStringAsFixed(0),
                      res.spec.internalHeight.toStringAsFixed(0),
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (viewProjection == 'both') ...[
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(
                    plan: res,
                    isTopView: false,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(
                    plan: res,
                    isTopView: true,
                  ),
                ),
              ),
            ] else ...[
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: ContainerLoadPlanPainter(
                    plan: res,
                    isTopView: viewProjection == 'top',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            PoPlanner3dItemsTable(res: res),
          ],
        ),
      ),
    );
  }
}
