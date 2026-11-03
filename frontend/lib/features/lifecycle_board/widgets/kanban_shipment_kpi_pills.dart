import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Compact shipment KPI row pills designed specifically for EnterpriseDataTable cell rendering.
class KanbanShipmentRowKpiPills extends StatelessWidget {
  final double? healthPercent;
  final int? freeDaysRemaining;
  final double accumulatedOverdue;
  final bool isOnHold;

  const KanbanShipmentRowKpiPills({
    super.key,
    this.healthPercent,
    this.freeDaysRemaining,
    this.accumulatedOverdue = 0.0,
    this.isOnHold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    // 1. Health / Readiness Pill
    final healthVal = healthPercent ?? 100.0;
    final healthColor = healthVal >= 80.0
        ? AppTheme.emerald
        : (healthVal >= 50.0 ? AppTheme.orange : AppTheme.crimson);

    // 2. Free Time Pill: Green (>7d), Orange (4-7d), Red (<=3d)
    final freeDays = freeDaysRemaining;
    final freeColor = (freeDays == null || freeDays > 7)
        ? AppTheme.emerald
        : (freeDays >= 4 ? AppTheme.orange : AppTheme.crimson);

    final hasOverdue = accumulatedOverdue > 0;

    return SelectionArea(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Health / Readiness Pill
          Tooltip(
            message: isAr ? 'مؤشر صحة واكتمال الملف' : 'Operational Health & Readiness',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: healthColor.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.health_and_safety_outlined, size: 10, color: healthColor),
                  const SizedBox(width: 2),
                  Text(
                    '${healthVal.toInt()}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: healthColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 3),

          // Free Time Pill
          if (freeDays != null) ...[
            Tooltip(
              message: isAr ? 'أيام السماح المتبقية' : 'Remaining Free Days',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: freeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: freeColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 10, color: freeColor),
                    const SizedBox(width: 2),
                    Text(
                      isAr ? '$freeDays ي' : '${freeDays}d',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: freeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 3),
          ],

          // Overdue Pill / Hold Pill
          if (hasOverdue)
            Tooltip(
              message: isAr ? 'غرامات أرضيات متراكمة' : 'Accumulated Demurrage',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.crimson, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 10, color: AppTheme.crimson),
                    const SizedBox(width: 2),
                    Text(
                      '\$${accumulatedOverdue.toInt()}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.crimson,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isOnHold)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.crimson, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_circle_outline, size: 10, color: AppTheme.crimson),
                  const SizedBox(width: 2),
                  Text(
                    isAr ? 'معلق' : 'Hold',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crimson,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
