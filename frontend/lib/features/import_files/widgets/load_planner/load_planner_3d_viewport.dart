import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/widgets/container_load_plan_painter.dart';

/// 3D Container visual renderings viewport.
/// Displays side view (left wall removed) and top view (roof removed)
/// wrapped in a RepaintBoundary for high-fidelity export capture.
class LoadPlanner3dViewport extends StatelessWidget {
  final List<ContainerPackingResult> plan;
  final GlobalKey visualKey;

  const LoadPlanner3dViewport({
    super.key,
    required this.plan,
    required this.visualKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return RepaintBoundary(
      key: visualKey,
      child: ListView.builder(
        itemCount: plan.length,
        itemBuilder: (ctx, pIdx) {
          final res = plan[pIdx];
          if (res.containerCode == 'FAILED') {
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                '${l.oversizedItemsWarning}: ${res.unplacedItems.map((u) => u.itemId).join(', ')}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            color: isDark ? AppTheme.darkCardBackground : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l.containerLayoutTitle(pIdx + 1, res.spec.name, res.spec.code),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l.woodenFloorPallets,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.amber.shade200 : Colors.brown,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${l.internalDimensionsPrefix}: ${res.spec.internalLength.toStringAsFixed(0)} x ${res.spec.internalWidth.toStringAsFixed(0)} x ${res.spec.internalHeight.toStringAsFixed(0)} cm',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Side View (Left Wall Removed) - High Fidelity Realistic Container
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                      child: Container(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Top View (Roof Removed)
                  Container(
                    height: 145,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                      child: Container(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
